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
                Picker("Input", selection: $prefs.inputDeviceUID) {
                    Text("System default").tag("")
                    ForEach(devices) { device in
                        Text(device.isDefault ? "\(device.name) (default)" : device.name)
                            .tag(device.id)
                    }
                }
                .onAppear { devices = AudioDevices.inputs() }

                Text("Used when you hold Space. A change applies on the next hold. The same list is in the footer of the stage.")
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
        .frame(width: 560, height: 640)
        .preferredColorScheme(.light)
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
