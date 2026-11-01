import AVFoundation
import AudioToolbox
import CoreAudio
import Foundation

struct AudioInput: Identifiable, Hashable {
    let id: String
    let name: String
    let isDefault: Bool
}

enum AudioDevices {
    static func inputs() -> [AudioInput] {
        let defaultUID = AVCaptureDevice.default(for: .audio)?.uniqueID
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        )
        return session.devices.map {
            AudioInput(id: $0.uniqueID, name: $0.localizedName, isDefault: $0.uniqueID == defaultUID)
        }
    }

    static var builtInUID: String? {
        inputs().first {
            $0.id == "BuiltInMicrophoneDevice" || $0.name.localizedCaseInsensitiveContains("MacBook")
        }?.id
    }

    static func name(for uid: String) -> String? {
        inputs().first { $0.id == uid }?.name
    }

    /// Translate an `AVCaptureDevice` unique ID (the CoreAudio device UID) to an AudioDeviceID.
    static func deviceID(forUID uid: String) -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslateUIDToDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var cfUID = uid as CFString
        let status = withUnsafeMutablePointer(to: &cfUID) { pointer in
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                UInt32(MemoryLayout<CFString>.size),
                pointer,
                &size,
                &deviceID
            )
        }
        return status == noErr && deviceID != 0 ? deviceID : nil
    }
}
