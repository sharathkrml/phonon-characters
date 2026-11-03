import AVFoundation
import Foundation

/// Weather sounds made from noise instead of recordings, so the app carries no audio assets.
/// Every buffer is a plain 16-bit mono WAV, looped by `StageAudio` at a low level under the voice.
enum StageSounds {
    static let sampleRate = 22_050

    static func loopData(for effect: StageEffect) -> Data? {
        switch effect {
        case .rain, .storm: wav(rain(seconds: 6))
        case .snow: wav(wind(seconds: 6, cutoff: 420, gust: 0.5))
        case .wind: wav(wind(seconds: 6, cutoff: 300, gust: 1))
        case .embers: wav(crackle(seconds: 6))
        case .fog, .sparkle: nil
        }
    }

    static func sparkleData() -> Data { wav(shimmer(seconds: 2.6)) }

    static func thunderData() -> Data { wav(thunder(seconds: 3.6)) }

    // MARK: - Voices

    /// Filtered hiss plus a slow roar. Two bands keep it from reading as flat static.
    private static func rain(seconds: Double) -> [Float] {
        let count = Int(seconds * Double(sampleRate))
        var rng = Rng(0x5A17_0001)
        var high = OnePole(cutoff: 700)
        var body = OnePole(cutoff: 5_200)
        var roar = OnePole(cutoff: 180)
        var out = [Float]()
        out.reserveCapacity(count)

        for i in 0..<count {
            let white = rng.bipolar()
            let hiss = body.low(white - high.low(white))
            let t = Float(i) / Float(sampleRate)
            let swell = 0.88 + 0.12 * sin(t * 0.8)
            // A rare close droplet, so the loop has some grain.
            let drop = rng.unit() < 0.00008 ? rng.bipolar() * 0.35 : 0
            out.append((hiss * swell + roar.low(white) * 0.9 + drop) * 0.5)
        }
        return finish(out)
    }

    /// Leaky brown noise through a low pass, opening and closing with a slow gust.
    private static func wind(seconds: Double, cutoff: Float, gust: Float) -> [Float] {
        let count = Int(seconds * Double(sampleRate))
        var rng = Rng(0x5A17_0002)
        var low = OnePole(cutoff: cutoff)
        var brown: Float = 0
        var out = [Float]()
        out.reserveCapacity(count)

        for i in 0..<count {
            let white = rng.bipolar()
            brown = brown * 0.996 + white * 0.02
            let t = Float(i) / Float(sampleRate)
            let swell = 0.55 + 0.45 * sin(2 * .pi * 0.07 * t + sin(2 * .pi * 0.017 * t) * 1.4)
            out.append(low.low(brown) * (0.6 + gust * swell) * 4)
        }
        return finish(out)
    }

    /// A low fire bed with sparse crackles.
    private static func crackle(seconds: Double) -> [Float] {
        let count = Int(seconds * Double(sampleRate))
        var rng = Rng(0x5A17_0003)
        var low = OnePole(cutoff: 260)
        var brown: Float = 0
        var click: Float = 0
        var out = [Float]()
        out.reserveCapacity(count)

        for _ in 0..<count {
            let white = rng.bipolar()
            brown = brown * 0.995 + white * 0.015
            if rng.unit() < 0.0016 { click = rng.bipolar() }
            click *= 0.9
            out.append(low.low(brown) * 2.2 + click * 0.45)
        }
        return finish(out)
    }

    /// Brown noise with an initial crack, a long rumble and a little sub.
    private static func thunder(seconds: Double) -> [Float] {
        let count = Int(seconds * Double(sampleRate))
        var rng = Rng(0x5A17_0004)
        var low = OnePole(cutoff: 150)
        var brown: Float = 0
        var out = [Float]()
        out.reserveCapacity(count)

        for i in 0..<count {
            let white = rng.bipolar()
            let t = Float(i) / Float(sampleRate)
            brown = brown * 0.998 + white * 0.02
            let crack = t < 0.12 ? white * exp(-t * 38) : 0
            let rumble = low.low(brown) * exp(-t * 0.85) * 4.5
            let sub = sin(2 * .pi * 43 * t) * exp(-t * 1.15) * 0.22
            out.append(crack * 0.7 + rumble + sub)
        }
        return finish(out, peak: 0.95, fadeEdges: false)
    }

    /// Three detuned partials with a short decay: a stage "ting" for sparkle.
    private static func shimmer(seconds: Double) -> [Float] {
        let count = Int(seconds * Double(sampleRate))
        var out = [Float]()
        out.reserveCapacity(count)

        for i in 0..<count {
            let t = Float(i) / Float(sampleRate)
            let env = exp(-t * 1.9) + 0.5 * exp(-max(0, t - 0.38) * 2.4)
            let tone = sin(2 * .pi * 1_046.5 * t) * 0.5
                + sin(2 * .pi * 1_568 * t) * 0.3
                + sin(2 * .pi * 2_093 * t) * 0.2
            out.append(tone * env * 0.35)
        }
        return finish(out)
    }

    // MARK: - Format

    private static func finish(_ samples: [Float], peak: Float = 0.85, fadeEdges: Bool = true) -> [Float] {
        var out = samples
        let loudest = out.reduce(0) { max($0, abs($1)) }
        guard loudest > 0 else { return out }
        let gain = peak / loudest
        for i in out.indices { out[i] *= gain }

        guard fadeEdges else { return out }
        let fade = min(Int(0.04 * Double(sampleRate)), out.count / 2)
        guard fade > 0 else { return out }
        for i in 0..<fade {
            let g = Float(i) / Float(fade)
            out[i] *= g
            out[out.count - 1 - i] *= g
        }
        return out
    }

    private static func wav(_ samples: [Float]) -> Data {
        var data = Data()
        let bytes = UInt32(samples.count * 2)

        func put<T: FixedWidthInteger>(_ value: T) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }

        data.append(contentsOf: Array("RIFF".utf8))
        put(UInt32(36) + bytes)
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        put(UInt32(16))
        put(UInt16(1))
        put(UInt16(1))
        put(UInt32(sampleRate))
        put(UInt32(sampleRate * 2))
        put(UInt16(2))
        put(UInt16(16))
        data.append(contentsOf: Array("data".utf8))
        put(bytes)

        data.reserveCapacity(data.count + Int(bytes))
        for sample in samples {
            let value = Int16(max(-1, min(1, sample)) * 32_767)
            put(UInt16(bitPattern: value))
        }
        return data
    }

    // MARK: - Small DSP

    private struct OnePole {
        private var y: Float = 0
        private let a: Float

        init(cutoff: Float) {
            a = 1 - exp(-2 * .pi * cutoff / Float(StageSounds.sampleRate))
        }

        mutating func low(_ x: Float) -> Float {
            y += a * (x - y)
            return y
        }
    }

    /// SplitMix64: deterministic noise so a scene sounds the same each launch.
    private struct Rng {
        private var state: UInt64

        init(_ seed: UInt64) { state = seed }

        mutating func bipolar() -> Float {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            z ^= z >> 31
            return Float(z >> 40) / 8_388_608 - 1
        }

        mutating func unit() -> Float {
            (bipolar() + 1) / 2
        }
    }
}

/// Owns the ambience players. One loop at a time; a new effect fades the old one out.
@MainActor
final class StageAudio {
    private var ambient: AVAudioPlayer?
    private var cache: [String: Data] = [:]
    private var thunderTask: Task<Void, Never>?
    private var fadeTask: Task<Void, Never>?

    func play(_ effect: StageEffect, strength: Double) {
        thunderTask?.cancel()
        thunderTask = nil
        fadeTask?.cancel()
        fadeTask = nil
        fadeOut(ambient)
        ambient = nil

        let level = Float(0.10 + 0.10 * max(0, min(1, strength)))

        if effect == .sparkle {
            oneShot(StageSounds.sparkleData(), volume: level * 1.4)
            return
        }
        guard let data = loopData(for: effect),
              let player = try? AVAudioPlayer(data: data)
        else { return }

        player.numberOfLoops = -1
        player.volume = 0
        player.prepareToPlay()
        player.play()
        ambient = player

        fadeTask = Task { [weak player] in
            for step in 1...12 {
                try? await Task.sleep(nanoseconds: 40_000_000)
                guard let player, player.isPlaying else { return }
                player.volume = level * Float(step) / 12
            }
        }

        if effect == .storm {
            thunderTask = Task { [weak self] in
                for delay in [1, 9] as [UInt64] {
                    try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
                    guard !Task.isCancelled, let self else { return }
                    self.oneShot(StageSounds.thunderData(), volume: 0.24)
                }
            }
        }
    }

    func stop() {
        thunderTask?.cancel()
        thunderTask = nil
        fadeOut(ambient)
        ambient = nil
    }

    private func oneShot(_ data: Data, volume: Float) {
        guard let player = try? AVAudioPlayer(data: data) else { return }
        player.volume = volume
        player.prepareToPlay()
        player.play()
    }

    private func loopData(for effect: StageEffect) -> Data? {
        if let cached = cache[effect.rawValue] { return cached }
        guard let data = StageSounds.loopData(for: effect) else { return nil }
        cache[effect.rawValue] = data
        return data
    }

    private func fadeOut(_ player: AVAudioPlayer?) {
        guard let player else { return }
        let start = player.volume
        Task {
            for step in 1...12 {
                try? await Task.sleep(nanoseconds: 50_000_000)
                guard player.isPlaying else { return }
                player.volume = start * Float(12 - step) / 12
            }
            player.stop()
        }
    }
}
