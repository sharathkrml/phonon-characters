import AVFoundation
import Foundation

enum MicPermission {
    static func request(timeout: TimeInterval = 45) async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        DebugLog.write("mic authorization status=\(status.rawValue)")
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withTaskGroup(of: Bool.self) { group in
                group.addTask {
                    await withCheckedContinuation { continuation in
                        AVCaptureDevice.requestAccess(for: .audio) { granted in
                            continuation.resume(returning: granted)
                        }
                    }
                }
                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    return false
                }
                let result = await group.next() ?? false
                group.cancelAll()
                return result
            }
        default:
            return false
        }
    }
}

/// Microphone tap converted to mono PCM16 at the rate the ASR model expects.
final class AudioCapture {
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var targetFormat: AVAudioFormat?
    private var inputFormat: AVAudioFormat?
    private var running = false
    private var onPCM: ((Data) -> Void)?

    func start(sampleRate: Double, deviceUID: String = "", onPCM: @escaping (Data) -> Void) throws {
        guard !running else { return }
        self.onPCM = onPCM

        let input = engine.inputNode
        if !deviceUID.isEmpty, let unit = input.audioUnit, let deviceID = AudioDevices.deviceID(forUID: deviceUID) {
            var id = deviceID
            let status = AudioUnitSetProperty(
                unit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &id,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )
            DebugLog.write("select input uid=\(deviceUID) status=\(status)")
        }

        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw AudioCaptureError.noInput
        }
        guard let target = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: true
        ), let converter = AVAudioConverter(from: format, to: target) else {
            throw AudioCaptureError.converter
        }

        self.inputFormat = format
        self.targetFormat = target
        self.converter = converter

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.process(buffer)
        }
        engine.prepare()
        try engine.start()
        running = true
    }

    func stop() {
        guard running else { return }
        running = false
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil
        onPCM = nil
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        guard running,
              let converter,
              let targetFormat,
              let inputFormat else { return }

        let ratio = targetFormat.sampleRate / inputFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var supplied = false
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, outStatus in
            if supplied {
                outStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard status != .error,
              output.frameLength > 0,
              let samples = output.int16ChannelData?[0]
        else { return }

        let data = Data(bytes: samples, count: Int(output.frameLength) * MemoryLayout<Int16>.size)
        onPCM?(data)
    }
}

enum AudioCaptureError: LocalizedError {
    case noInput
    case converter

    var errorDescription: String? {
        switch self {
        case .noInput: "No microphone input was found."
        case .converter: "Could not prepare the microphone audio."
        }
    }
}
