import SwiftUI

/// Crash-safe input switcher for the microphone used by hold-Space.
/// A native `Menu` triggers a SwiftUI hit-testing crash on macOS 27, so this cycles instead.
struct MicPicker: View {
    @ObservedObject var prefs = Preferences.shared
    @State private var devices: [AudioInput] = []

    var body: some View {
        Button(action: advance) {
            HStack(spacing: 5) {
                Image(systemName: "mic")
                Text(currentName)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 160, alignment: .leading)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 9, weight: .semibold))
                    .opacity(0.55)
            }
            .font(Theme.body(11))
            .foregroundStyle(Theme.inkSoft.opacity(0.85))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Click to switch microphone input")
        .onAppear { devices = AudioDevices.inputs() }
    }

    private var options: [(uid: String, name: String)] {
        [("", "Default input")] + devices.map { ($0.id, $0.name) }
    }

    private var currentName: String {
        if prefs.inputDeviceUID.isEmpty { return "Default input" }
        return devices.first { $0.id == prefs.inputDeviceUID }?.name ?? "Microphone"
    }

    private func advance() {
        devices = AudioDevices.inputs()
        let all = options
        guard !all.isEmpty else { return }
        if let index = all.firstIndex(where: { $0.uid == prefs.inputDeviceUID }) {
            prefs.inputDeviceUID = all[(index + 1) % all.count].uid
        } else {
            prefs.inputDeviceUID = all[0].uid
        }
    }
}
