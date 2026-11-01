import SwiftUI

struct EarsRow: View {
    @ObservedObject var ears: EarsEngine
    @State private var confirmingDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle().fill(Theme.ink.opacity(0.05))
                    Image(systemName: "ear")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.ink.opacity(0.75))
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 7) {
                        Text("Ears")
                            .font(Theme.body(14, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("optional")
                            .font(Theme.body(9.5, weight: .semibold))
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .foregroundStyle(Theme.inkSoft)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Theme.ink.opacity(0.06)))
                    }
                    Text("Phonon-2.5 English · live speech-to-text · 158 MB model")
                        .font(Theme.body(11.5))
                        .foregroundStyle(Theme.inkSoft)
                }

                Spacer(minLength: 12)
                trailing
            }

            statusLine
        }
        .padding(.vertical, 4)
        .confirmationDialog(
            "Remove the ears engine?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Remove engine and model", role: .destructive) {
                ears.remove()
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("This frees about 600 MB. The engine installs again next time you enable the microphone.")
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch ears.state {
        case .absent, .failed:
            Button {
                ears.install()
            } label: {
                Text(ears.state.isFailed ? "Retry" : "Install")
                    .font(Theme.body(11.5, weight: .semibold))
                    .foregroundStyle(Theme.paper)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Theme.ink.opacity(0.85)))
            }
            .buttonStyle(.plain)

        case .installing:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Installing…").font(Theme.body(11)).foregroundStyle(Theme.inkSoft)
            }

        case .starting:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Starting…").font(Theme.body(11)).foregroundStyle(Theme.inkSoft)
            }

        case .ready, .readyEngine:
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: 0x4C7A3A))
                Button("Delete") { confirmingDelete = true }
                    .font(Theme.body(11, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch ears.state {
        case .absent:
            Text("Adds a 470 MB runtime on first enable, then a 158 MB English model.")
                .font(Theme.body(10.5))
                .foregroundStyle(Theme.inkSoft.opacity(0.8))

        case .installing(let phase):
            VStack(alignment: .leading, spacing: 3) {
                Text(phase)
                    .font(Theme.body(10.5))
                    .foregroundStyle(Theme.inkSoft)
                Text("One-time setup. Logs are in Application Support/PhononCharacters/Logs.")
                    .font(Theme.body(9.5))
                    .foregroundStyle(Theme.inkSoft.opacity(0.7))
            }

        case .readyEngine:
            Text("Installed · starts when you hold Space")
                .font(Theme.body(10.5))
                .foregroundStyle(Theme.inkSoft.opacity(0.8))

        case .ready:
            Text("Running · \(ears.detail)")
                .font(Theme.body(10.5))
                .foregroundStyle(Color(hex: 0x4C7A3A).opacity(0.85))

        case .starting:
            Text("First listen downloads the model and compiles Metal shaders, about a minute.")
                .font(Theme.body(10.5))
                .foregroundStyle(Theme.inkSoft.opacity(0.8))

        case .failed(let message):
            Text(message)
                .font(Theme.body(10.5))
                .foregroundStyle(.red.opacity(0.8))
                .lineLimit(3)
        }
    }
}

extension EarsEngine.State {
    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}
