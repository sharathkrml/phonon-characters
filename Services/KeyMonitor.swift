import AppKit
import SwiftUI

/// Space is push-to-talk unless the caret is in a text field with content. Arrows switch
/// characters, Escape stops the character mid-sentence.
final class KeyMonitor {
    var onSpaceDown: (() -> Void)?
    var onSpaceUp: (() -> Void)?
    var onEscape: (() -> Bool)?
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?

    private var monitor: Any?
    private var spaceConsumed = false

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self else { return event }
            return self.handle(event)
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        spaceConsumed = false
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        if event.type == .keyUp {
            if event.keyCode == 49, spaceConsumed {
                spaceConsumed = false
                onSpaceUp?()
                return nil
            }
            return event
        }

        guard event.keyCode == 49 || event.keyCode == 53 || event.keyCode == 123 || event.keyCode == 124 else {
            return event
        }

        // Another window (Settings) or a real text edit owns the keyboard.
        if isEditingText { return event }
        if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty { return event }

        switch event.keyCode {
        case 49:
            if event.isARepeat { return spaceConsumed ? nil : event }
            spaceConsumed = true
            onSpaceDown?()
            return nil

        case 53:
            if onEscape?() == true { return nil }
            return event

        case 123:
            onPrevious?()
            return nil

        case 124:
            onNext?()
            return nil

        default:
            return event
        }
    }

    /// True when a focused field editor holds text, or when the key window is not our stage.
    private var isEditingText: Bool {
        guard let window = NSApp.keyWindow else { return true }
        if window.title.localizedCaseInsensitiveContains("settings") { return true }
        guard let responder = window.firstResponder as? NSTextView else { return false }
        return !responder.string.isEmpty || responder.hasMarkedText()
    }
}

/// Tags the main window so the key monitor can ignore Settings and panels.
struct WindowMarker: NSViewRepresentable {
    static let identifier = "phonon-stage"

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            Self.tag(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            Self.tag(nsView.window)
        }
    }

    private static func tag(_ window: NSWindow?) {
        guard let window else { return }
        window.identifier = NSUserInterfaceItemIdentifier(identifier)
        guard let main = NSScreen.main?.visibleFrame else { return }
        let centre = CGPoint(x: window.frame.midX, y: window.frame.midY)
        if !main.contains(centre) {
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
}
