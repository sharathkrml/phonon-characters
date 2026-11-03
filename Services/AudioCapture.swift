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

/// Microphone capture as mono PCM16 at the rate the ASR model expects.
///
/// AVAudioEngine is not used here on purpose: its input node locks onto the *system default*
/// device's format, and switching to a mic with another sample rate fails to start with
/// com.apple.coreaudio.avfaudio -10868 (format not supported). AVCaptureSession selects the
/// device per app and resamples to `audioSettings` for us.
final class AudioCapture: NSObject, @unchecked Sendable {
    private let queue = DispatchQueue(label: "phonon.capture")
    private var session: AVCaptureSession?
    private var onPCM: ((Data) -> Void)?
    private var sampleRate: Double = 16_000
    /// nil until the first buffer proves the delivered format is what the ASR stream expects.
    private var formatOK: Bool?
    private var running = false

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
        guard let device = Self.device(forUID: deviceUID) else {
            throw AudioCaptureError.noInput
        }
        if let volume = AudioDevices.inputVolume(forUID: deviceUID), volume < 0.25 {
            let target: Float = 0.9
            if AudioDevices.setInputVolume(target, forUID: deviceUID) {
                DebugLog.write("input volume raised \(volume) -> \(target) uid=\(deviceUID)")
            }
        }

        let session = AVCaptureSession()
        let input = try AVCaptureDeviceInput(device: device)
        let output = AVCaptureAudioDataOutput()
        output.audioSettings = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        output.setSampleBufferDelegate(self, queue: queue)

        guard session.canAddInput(input), session.canAddOutput(output) else {
            throw AudioCaptureError.noInput
        }
        session.addInput(input)
        session.addOutput(output)

        self.sampleRate = sampleRate
        self.onPCM = onPCM
        self.formatOK = nil
        self.session = session
        session.startRunning()
        guard session.isRunning else {
            self.session = nil
            self.onPCM = nil
            throw AudioCaptureError.noInput
        }
        running = true
        DebugLog.write("capture device=\(device.uniqueID) rate=\(sampleRate)")
        DebugLog.write("audio capture started")
    }

    /// Non-blocking: teardown is queued behind any in-flight start.
    func stop() {
        queue.async { [weak self] in
            guard let self, self.running else { return }
            self.running = false
            self.onPCM = nil
            self.formatOK = nil
            self.session?.stopRunning()
            self.session = nil
        }
    }

    private static func device(forUID uid: String) -> AVCaptureDevice? {
        if !uid.isEmpty {
            if let device = AVCaptureDevice(uniqueID: uid) { return device }
            DebugLog.write("saved input missing uid=\(uid); using system default")
        }
        return AVCaptureDevice.default(for: .audio)
    }
}

extension AudioCapture: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard running, let onPCM else { return }

        if formatOK == nil {
            let format = CMSampleBufferGetFormatDescription(sampleBuffer)
                .flatMap { CMAudioFormatDescriptionGetStreamBasicDescription($0)?.pointee }
            formatOK = format.map {
                $0.mSampleRate == sampleRate && $0.mChannelsPerFrame == 1 && $0.mBitsPerChannel == 16
            } ?? false
            DebugLog.write(
                "capture format \(format?.mSampleRate ?? 0)Hz \(format?.mChannelsPerFrame ?? 0)ch "
                    + "\(format?.mBitsPerChannel ?? 0)bit ok=\(formatOK == true)"
            )
        }
        // Never feed the transcriber a format it was not configured for.
        guard formatOK == true else { return }

        guard let block = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        var length = 0
        var pointer: UnsafeMutablePointer<Int8>?
        guard CMBlockBufferGetDataPointer(
            block,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &length,
            dataPointerOut: &pointer
        ) == noErr, let pointer, length > 0 else { return }

        onPCM(Data(bytes: pointer, count: length))
    }
}

enum AudioCaptureError: LocalizedError {
    case noInput

    var errorDescription: String? {
        switch self {
        case .noInput: "No microphone input was found."
        }
    }
}
