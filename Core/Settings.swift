import Foundation
import Combine

/// Small, observable preferences. UserDefaults is the store so a relaunch keeps state.
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    @Published var autoSpeak: Bool { didSet { defaults.set(autoSpeak, forKey: "autoSpeak") } }
    @Published var stageEffects: Bool { didSet { defaults.set(stageEffects, forKey: "stageEffects") } }
    @Published var onboarded: Bool { didSet { defaults.set(onboarded, forKey: "onboarded") } }
    @Published var selectedCharacterID: String { didSet { defaults.set(selectedCharacterID, forKey: "selectedCharacterID") } }
    /// Empty means "system default input".
    @Published var inputDeviceUID: String { didSet { defaults.set(inputDeviceUID, forKey: "inputDeviceUID") } }
    /// The last microphone that actually produced signal, used as the fallback suggestion.
    @Published var lastWorkingInputUID: String { didSet { defaults.set(lastWorkingInputUID, forKey: "lastWorkingInputUID") } }

    private init() {
        autoSpeak = defaults.object(forKey: "autoSpeak") as? Bool ?? true
        stageEffects = defaults.object(forKey: "stageEffects") as? Bool ?? true
        onboarded = defaults.bool(forKey: "onboarded")
        selectedCharacterID = defaults.string(forKey: "selectedCharacterID") ?? Persona.all[0].id
        lastWorkingInputUID = defaults.string(forKey: "lastWorkingInputUID") ?? ""
        if defaults.object(forKey: "inputDeviceUID") != nil {
            inputDeviceUID = defaults.string(forKey: "inputDeviceUID") ?? ""
        } else {
            // Prefer the built-in mic: docks, webcams and virtual drivers are often silent.
            inputDeviceUID = AudioDevices.builtInUID ?? ""
        }
    }
}
