import AVFoundation
import Foundation
import PhononTTS

/// Plays Phonon's 24 kHz mono chunks and reports what is actually coming out of the speaker,
/// so the portrait's mouth moves in sync with the audio rather than with generation.
final class VoicePlayer: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: Phonon.sampleRate, channels: 1)!
    private let onLevel: @Sendable (Float) -> Void

    init(onLevel: @escaping @Sendable (Float) -> Void) throws {
        self.onLevel = onLevel
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)

        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [onLevel] buffer, _ in
            guard let data = buffer.floatChannelData?[0] else { return }
            let frames = Int(buffer.frameLength)
            guard frames > 0 else { onLevel(0); return }
            var sum: Float = 0
            for i in 0..<frames {
                let v = data[i]
                sum += v * v
            }
            let rms = sqrt(sum / Float(frames))
            onLevel(min(1, rms * 5.5))
        }

        try engine.start()
        node.play()
    }

    deinit {
        node.stop()
        engine.stop()
    }

    func enqueue(_ samples: [Float]) {
        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))
        else { return }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            buffer.floatChannelData![0].update(from: source.baseAddress!, count: samples.count)
        }
        node.scheduleBuffer(buffer)
    }

    func stop() {
        node.stop()
        node.play()
    }
}

@MainActor
final class PhononService: ObservableObject {
    @Published private(set) var isLoaded = false
    @Published private(set) var isLoading = false
    @Published private(set) var level: Float = 0
    @Published private(set) var mouth = MouthShape.closed
    @Published private(set) var currentVoice = ""
    @Published private(set) var loadNote: String?
    /// Audio seconds generated per second of compute for the last utterance.
    @Published private(set) var voiceSpeed: Double?

    private var phonon: Phonon?
    private var player: VoicePlayer?
    private var track: MouthTrack?
    private var lastTick = Date()

    func loadIfNeeded() async throws {
        if isLoaded { return }
        guard PhononModels.isInstalled() else {
            throw PhononError(description: "The voice model is not installed yet.")
        }
        isLoading = true
        loadNote = Phonon.needsCompiling(PhononModels.defaultDirectory)
            ? "Warming up the voice — first launch compiles the model."
            : nil
        defer {
            isLoading = false
            loadNote = nil
        }
        let loaded = try await Phonon.load(models: PhononModels.defaultDirectory, language: .english)
        let player = try VoicePlayer { [weak self] value in
            Task { @MainActor in
                guard let self else { return }
                let smoothed = max(value, self.level * 0.55)
                self.level = smoothed < 0.02 ? 0 : smoothed
                self.advanceMouth(voiced: smoothed > 0.05)
            }
        }
        self.phonon = loaded
        self.player = player
        self.isLoaded = true
    }

    func setVoice(_ voice: String) async throws {
        let phonon = try await ready()
        guard currentVoice != voice else { return }
        try await phonon.setVoice(voice)
        currentVoice = voice
    }

    /// Speaks one sentence. Returns statistics; audio itself may still be playing.
    @discardableResult
    func speak(_ text: String, voice: String) async throws -> SpeechStats? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let phonon = try await ready()
        try await setVoice(voice)
        guard let player else { return nil }
        track = MouthTrack(text: trimmed)
        lastTick = Date()
        let stats = try await phonon.speak(trimmed) { chunk in
            player.enqueue(chunk)
        }
        voiceSpeed = stats.realtimeFactor
        return stats
    }

    func stop() {
        player?.stop()
        level = 0
        track = nil
        mouth = .closed
    }

    /// Playback ended on its own; the audio tap stops with it, so close the lips here.
    func finishSpeaking() {
        track = nil
        mouth = .closed
    }

    func unload() {
        stop()
        phonon = nil
        player = nil
        isLoaded = false
        currentVoice = ""
    }

    /// Lips follow the words, but only while there is audio to hear: the reply text is known
    /// long before playback catches up, so voiced frames are the clock.
    private func advanceMouth(voiced: Bool) {
        guard var track else {
            mouth = .closed
            return
        }
        let now = Date()
        let dt = min(now.timeIntervalSince(lastTick), 0.1)
        lastTick = now
        let shape = track.advance(voiced: voiced, dt: dt)
        self.track = track
        mouth = mouth.mixed(shape, 0.55)
    }

    private func ready() async throws -> Phonon {
        try await loadIfNeeded()
        guard let phonon else { throw PhononError(description: "The voice engine did not start.") }
        return phonon
    }
}
