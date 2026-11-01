import Foundation
import Combine

/// Small, observable preferences. UserDefaults is the store so a relaunch keeps state.
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    @Published var autoSpeak: Bool { didSet { defaults.set(autoSpeak, forKey: "autoSpeak") } }
    @Published var onboarded: Bool { didSet { defaults.set(onboarded, forKey: "onboarded") } }
    @Published var selectedCharacterID: String { didSet { defaults.set(selectedCharacterID, forKey: "selectedCharacterID") } }
    /// Empty means "system default input".
    @Published var inputDeviceUID: String { didSet { defaults.set(inputDeviceUID, forKey: "inputDeviceUID") } }

    private init() {
        autoSpeak = defaults.object(forKey: "autoSpeak") as? Bool ?? true
        onboarded = defaults.bool(forKey: "onboarded")
        selectedCharacterID = defaults.string(forKey: "selectedCharacterID") ?? Persona.all[0].id
        if defaults.object(forKey: "inputDeviceUID") != nil {
            inputDeviceUID = defaults.string(forKey: "inputDeviceUID") ?? ""
        } else {
            // Prefer the built-in mic: docks, webcams and virtual drivers are often silent.
            inputDeviceUID = AudioDevices.builtInUID ?? ""
        }
    }
}
