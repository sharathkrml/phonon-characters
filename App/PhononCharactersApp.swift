import SwiftUI

@main
struct PhononCharactersApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var models = ModelStore()
    @StateObject private var ears = EarsEngine()
    @StateObject private var prefs = Preferences.shared

    init() {
        #if DEBUG
        MouthTrack.selfCheck()
        CharacterLook.selfCheck()
        CharacterScene.selfCheck()
        #endif
    }

    var body: some Scene {
        WindowGroup("Phonon Characters") {
            ZStack {
                if models.coreReady && prefs.onboarded {
                    RootStage(models: models, ears: ears)
                } else {
                    OnboardingView(models: models, ears: ears)
                }
            }
            .frame(minWidth: 980, minHeight: 700)
            .preferredColorScheme(.light)
        }
        .defaultSize(width: 1180, height: 820)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Character") {
                Button("Previous Character") {
                    NotificationCenter.default.post(name: .previousCharacter, object: nil)
                }
                .keyboardShortcut(.leftArrow, modifiers: [])
                Button("Next Character") {
                    NotificationCenter.default.post(name: .nextCharacter, object: nil)
                }
                .keyboardShortcut(.rightArrow, modifiers: [])
            }
        }

        Settings {
            SettingsView(models: models, ears: ears)
        }
    }
}

private struct RootStage: View {
    @ObservedObject var models: ModelStore
    @ObservedObject var ears: EarsEngine
    @StateObject private var model: ConversationModel

    init(models: ModelStore, ears: EarsEngine) {
        self.models = models
        self.ears = ears
        _model = StateObject(wrappedValue: ConversationModel(models: models, ears: ears))
    }

    var body: some View {
        StageView(model: model)
            .onReceive(NotificationCenter.default.publisher(for: .previousCharacter)) { _ in
                model.step(-1)
            }
            .onReceive(NotificationCenter.default.publisher(for: .nextCharacter)) { _ in
                model.step(1)
            }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated { EarsEngine.stopAll() }
        LlamaServerRegistry.stopAll()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .aqua)
        // SwiftUI restores the last window frame, which can live on a display that is
        // currently asleep or disconnected. Bring the stage back to the active screen.
        for delay in [0.4, 1.2] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                Self.pullWindowOntoMainScreen()
            }
        }
    }

    private static func pullWindowOntoMainScreen() {
        guard let main = NSScreen.main?.visibleFrame,
              let window = NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain })
        else { return }
        if main.contains(CGPoint(x: window.frame.midX, y: window.frame.midY)) { return }
        window.setFrame(
            NSRect(
                x: main.midX - window.frame.width / 2,
                y: main.midY - window.frame.height / 2,
                width: window.frame.width,
                height: window.frame.height
            ),
            display: true
        )
    }
}

extension Notification.Name {
    static let previousCharacter = Notification.Name("phonon.previousCharacter")
    static let nextCharacter = Notification.Name("phonon.nextCharacter")
}
