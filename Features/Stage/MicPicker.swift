import SwiftUI

/// Crash-safe input picker for the microphone used by hold-Space.
/// A native `Menu` triggers a SwiftUI hit-testing crash on macOS 27, so this uses a popover.
struct MicPicker: View {
    @ObservedObject var prefs = Preferences.shared
    @State private var devices: [AudioInput] = []
    @State private var showing = false

    var body: some View {
        Button {
            devices = AudioDevices.inputs()
            showing = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "mic")
                Text(currentName)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .opacity(0.55)
            }
            .frame(maxWidth: 220, alignment: .leading)
            .font(Theme.body(11))
            .foregroundStyle(isMissing ? Color(hex: 0xB4543A) : Theme.inkSoft)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Choose the microphone input")
        .onAppear { devices = AudioDevices.inputs() }
        .popover(isPresented: $showing, arrowEdge: .bottom) {
            picker
        }
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Microphone")
                .font(Theme.body(10.5, weight: .semibold))
                .tracking(1.3)
                .textCase(.uppercase)
                .foregroundStyle(Theme.inkSoft)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

            if isMissing {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: 0xB4543A))
                    Text("Saved input is unavailable")
                        .font(Theme.body(11))
                        .foregroundStyle(Theme.inkSoft)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }

            ScrollView {
                VStack(spacing: 2) {
                    row(uid: "", name: "System default", detail: nil)

                    ForEach(devices) { device in
                        row(
                            uid: device.id,
                            name: device.name,
                            detail: device.isDefault ? "system default" : nil
                        )
                    }

                    if devices.isEmpty {
                        Text("No microphone inputs found")
                            .font(Theme.body(11))
                            .foregroundStyle(Theme.inkSoft)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 6)
            }
            .scrollIndicators(.never)
            .frame(height: listHeight)
        }
        .frame(width: 280)
        .background(Theme.paper)
    }

    private var listHeight: CGFloat {
        let rows = devices.count + 1
        return min(CGFloat(max(rows, 2)) * 32 + 8, 320)
    }

    private func row(uid: String, name: String, detail: String?) -> some View {
        MicRow(selected: prefs.inputDeviceUID == uid, title: name, detail: detail) {
            prefs.inputDeviceUID = uid
            showing = false
        }
    }

    private var isMissing: Bool {
        !prefs.inputDeviceUID.isEmpty && !devices.contains { $0.id == prefs.inputDeviceUID }
    }

    private var currentName: String {
        if prefs.inputDeviceUID.isEmpty { return "System default" }
        if isMissing { return "Input unavailable" }
        return devices.first { $0.id == prefs.inputDeviceUID }?.name ?? "Input unavailable"
    }
}

private struct MicRow: View {
    let selected: Bool
    let title: String
    let detail: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12))
                    .foregroundStyle(selected ? Theme.ink.opacity(0.8) : Theme.inkSoft.opacity(0.45))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let detail {
                        Text(detail)
                            .font(Theme.body(10))
                            .foregroundStyle(Theme.inkSoft)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Theme.ink.opacity(selected ? 0.06 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
