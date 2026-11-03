import AVFoundation
import AudioToolbox
import CoreAudio
import Foundation
import IOKit

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

    /// The built-in mic is dead while the lid is shut. Suggesting it in clamshell mode sends
    /// the user from one silent device to another.
    static var builtInMicUnavailable: Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        let property = IORegistryEntryCreateCFProperty(
            service,
            "AppleClamshellState" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue()
        return (property as? Bool) ?? false
    }

    static func name(for uid: String) -> String? {
        inputs().first { $0.id == uid }?.name
    }

    /// Input gain is the system's, not the app's. A device left near zero looks like a dead mic,
    /// so capture raises it to a usable level before opening the stream.
    static func inputVolume(forUID uid: String) -> Float? {
        guard let id = resolvedID(uid) else { return nil }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Float = 0
        var size = UInt32(MemoryLayout<Float>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value)
        return status == noErr ? value : nil
    }

    @discardableResult
    static func setInputVolume(_ value: Float, forUID uid: String) -> Bool {
        guard let id = resolvedID(uid) else { return false }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var level = min(max(value, 0), 1)
        let size = UInt32(MemoryLayout<Float>.size)
        return AudioObjectSetPropertyData(id, &address, 0, nil, size, &level) == noErr
    }

    private static func resolvedID(_ uid: String) -> AudioDeviceID? {
        if !uid.isEmpty { return deviceID(forUID: uid) }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &id
        )
        return status == noErr && id != 0 ? id : nil
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
