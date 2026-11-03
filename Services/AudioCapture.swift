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
final class AudioCapture: @unchecked Sendable {
    // Start/stop are serialized on `queue`; the tap reads immutable format fields.
    // A fresh engine per hold: reusing one after stop + a device switch can leave a stale
    // tap/format and kill the process on the second hold.
    private var engine: AVAudioEngine?
    /// Start/stop run here so a slow audio device cannot block the main thread.
    private let queue = DispatchQueue(label: "phonon.capture")
    private var converter: AVAudioConverter?
    /// The format the current converter was built from. The device can change between holds.
    private var converterFormat: AVAudioFormat?
    private let converterLock = NSLock()
    private var targetFormat: AVAudioFormat?
    private var running = false
    private var onPCM: ((Data) -> Void)?

    func start(sampleRate: Double, deviceUID: String = "", onPCM: @escaping (Data) -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try self.startNow(sampleRate: sampleRate, deviceUID: deviceUID, onPCM: onPCM)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func startNow(sampleRate: Double, deviceUID: String, onPCM: @escaping (Data) -> Void) throws {
        guard !running else { return }
        self.onPCM = onPCM

        engine?.stop()
        let engine = AVAudioEngine()
        self.engine = engine

        let input = engine.inputNode
        if let volume = AudioDevices.inputVolume(forUID: deviceUID), volume < 0.25 {
            let target: Float = 0.9
            if AudioDevices.setInputVolume(target, forUID: deviceUID) {
                DebugLog.write("input volume raised \(volume) -> \(target) uid=\(deviceUID)")
            }
        }
        if !deviceUID.isEmpty, let deviceID = AudioDevices.deviceID(forUID: deviceUID) {
            do {
                try input.auAudioUnit.setDeviceID(deviceID)
                DebugLog.write("select input uid=\(deviceUID) device=\(deviceID)")
            } catch {
                DebugLog.write("select input failed uid=\(deviceUID): \(error.localizedDescription)")
            }
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
        ), AVAudioConverter(from: format, to: target) != nil else {
            throw AudioCaptureError.converter
        }

        self.targetFormat = target
        converterLock.lock()
        converter = nil
        converterFormat = nil
        converterLock.unlock()
        DebugLog.write("capture format \(format.sampleRate)Hz \(format.channelCount)ch")

        // Install without a format: the node's own format can change after a device switch,
        // and passing a stale one is what raised the Objective-C exception and aborted.
        input.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            self?.process(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            self.engine = nil
            throw error
        }
        running = true
        DebugLog.write("audio capture started")
    }

    /// Non-blocking: teardown is queued behind any in-flight start.
    func stop() {
        queue.async { [weak self] in
            guard let self, self.running else { return }
            self.running = false
            self.engine?.inputNode.removeTap(onBus: 0)
            self.engine?.stop()
            self.engine = nil
            self.converterLock.lock()
            self.converter = nil
            self.converterFormat = nil
            self.converterLock.unlock()
            self.onPCM = nil
        }
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        guard running, let targetFormat else { return }

        let inputFormat = buffer.format
        converterLock.lock()
        if converter == nil
            || converterFormat?.sampleRate != inputFormat.sampleRate
            || converterFormat?.channelCount != inputFormat.channelCount {
            converter = AVAudioConverter(from: inputFormat, to: targetFormat)
            converterFormat = inputFormat
        }
        let converter = converter
        converterLock.unlock()
        guard let converter else { return }

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
