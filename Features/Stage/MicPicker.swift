import SwiftUI

/// Quick input switcher for the microphone used by hold-Space.
struct MicPicker: View {
    @ObservedObject var prefs = Preferences.shared
    @State private var devices: [AudioInput] = []

    var body: some View {
        Menu {
            Button {
                prefs.inputDeviceUID = ""
            } label: {
                if prefs.inputDeviceUID.isEmpty {
                    Label("System default", systemImage: "checkmark")
                } else {
                    Text("System default")
                }
            }

            if !devices.isEmpty { Divider() }

            ForEach(devices) { device in
                Button {
                    prefs.inputDeviceUID = device.id
                } label: {
                    if prefs.inputDeviceUID == device.id {
                        Label(device.name, systemImage: "checkmark")
                    } else {
                        Text(device.name)
                    }
                }
            }

            Divider()
            Button("Refresh inputs") { devices = AudioDevices.inputs() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "mic")
                Text(currentName)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 150, alignment: .leading)
            }
            .font(Theme.body(11))
            .foregroundStyle(Theme.inkSoft.opacity(0.85))
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Choose the microphone used for push-to-talk")
        .onAppear { devices = AudioDevices.inputs() }
    }

    private var currentName: String {
        if prefs.inputDeviceUID.isEmpty { return "Default input" }
        return devices.first { $0.id == prefs.inputDeviceUID }?.name ?? "Microphone"
    }
}
