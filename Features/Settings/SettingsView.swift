import SwiftUI

struct SettingsView: View {
    @ObservedObject var models: ModelStore
    @ObservedObject var ears: EarsEngine
    @ObservedObject var prefs = Preferences.shared
    @State private var devices: [AudioInput] = []

    var body: some View {
        Form {
            Section {
                ForEach(ModelCatalog.all) { package in
                    ModelRow(package: package, models: models, compact: true)
                }
                EarsRow(ears: ears)
            } header: {
                Text("Models")
            } footer: {
                Text("Stored in ~/Library/Application Support/PhononCharacters. Deleting stops the model and frees the space; it downloads again next time.")
                    .font(.system(size: 10.5))
            }

            Section("Microphone") {
                VStack(alignment: .leading, spacing: 2) {
                    inputRow(uid: "", name: "System default")
                    ForEach(devices) { device in
                        inputRow(
                            uid: device.id,
                            name: device.isDefault ? "\(device.name) (system default)" : device.name
                        )
                    }
                }
                .onAppear { devices = AudioDevices.inputs() }

                Text("Used when you hold Space. A change applies on the next hold. The footer button on the stage cycles the same list.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }

            Section("Voice") {
                Toggle("Speak replies aloud", isOn: $prefs.autoSpeak)
                Text("Turn this off for silent, text-only replies. The microphone still works.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Phonon Characters")
                        .font(.system(size: 13, weight: .semibold))
                    Text("A local character stage. Nothing you type or say leaves this Mac.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Divider()
                    credit("Voices", "Phonon 31M by Gradium (Apache 2.0)")
                    credit("Brain", "LFM3 1.7B by Liquid AI (LFM Open License)")
                    credit("Ears", "Phonon-2.5 English by Fermion Research (CC-BY-4.0)")
                    credit("Runtime", "llama.cpp (MIT) · Phonon runtime (MIT / Apache 2.0) · Fermion engine (Apache 2.0)")
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(PaperBackground())
        .tint(Theme.giltDeep)
        .frame(width: 560, height: 640)
        .preferredColorScheme(.light)
    }

    private func inputRow(uid: String, name: String) -> some View {
        Button {
            prefs.inputDeviceUID = uid
        } label: {
            HStack(spacing: 9) {
                Image(systemName: prefs.inputDeviceUID == uid ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13))
                    .foregroundStyle(prefs.inputDeviceUID == uid ? Theme.ink.opacity(0.8) : Theme.inkSoft.opacity(0.45))
                Text(name)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.ink.opacity(0.85))
                Spacer(minLength: 8)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func credit(_ title: String, _ detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .leading)
            Text(detail)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
        }
    }
}
