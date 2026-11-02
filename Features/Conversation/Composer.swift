import SwiftUI

struct Composer: View {
    @ObservedObject var model: ConversationModel
    @Binding var draft: String
    @FocusState private var focused: Bool

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !model.isBusy
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text(model.isListening ? "Listening" : "Your message")
                    .font(Theme.body(10.5, weight: .semibold))
                    .tracking(1.3)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.inkSoft)
                Spacer()
                Text(hintText)
                    .font(Theme.body(10.5))
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(.horizontal, 6)

            HStack(spacing: 12) {
                if model.isListening {
                    listening
                } else {
                    field
                }
                trailing
            }
            .padding(.horizontal, 16)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.paper.opacity(model.isListening ? 0.98 : 0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(
                                model.isListening
                                    ? model.character.palette.accent.opacity(0.7)
                                    : Theme.ink.opacity(focused ? 0.45 : 0.22),
                                lineWidth: model.isListening ? 1.6 : 1
                            )
                    )
                    .shadow(color: .black.opacity(0.05), radius: 12, y: 5)
            )
        }
        .animation(.easeOut(duration: 0.18), value: model.isListening)
        .onAppear {
            DispatchQueue.main.async { focused = true }
        }
    }

    private var field: some View {
        TextField(
            "",
            text: $draft,
            prompt: Text(prompt)
                .foregroundColor(Theme.inkSoft)
        )
        .textFieldStyle(.plain)
        .font(Theme.body(14.5))
        .foregroundStyle(Theme.ink)
        .tint(model.character.palette.ink)
        .focused($focused)
        .onSubmit(submit)
        .accessibilityLabel("Message to \(model.character.name)")
    }

    private var prompt: String {
        "Say something to \(firstName)…"
    }

    private var firstName: String { model.character.shortName }

    private var hintText: String {
        if model.isListening { return "Release to send" }
        let hasDraft = !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasDraft { return canSend ? "Return to send" : "Reply in progress" }
        return model.ears.engineInstalled ? "Space to talk" : "Ears not installed"
    }

    private var listening: some View {
        HStack(spacing: 10) {
            Waveform(level: model.micLevel, tint: model.character.palette.aura)
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    if model.transcriber.committed.isEmpty && model.transcriber.current.isEmpty {
                        Text("Listening…")
                            .font(Theme.body(14))
                            .foregroundStyle(Theme.inkSoft.opacity(0.75))
                    } else {
                        Text(model.transcriber.committed.isEmpty ? "" : model.transcriber.committed + " ")
                            .foregroundStyle(Theme.ink)
                        Text(model.transcriber.current)
                            .foregroundStyle(Theme.ink.opacity(0.55))
                    }
                }
                .font(Theme.body(14))
                .lineLimit(1)
            }
            .scrollIndicators(.never)
            .defaultScrollAnchor(.trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("Listening. \(model.transcriber.text)")
    }

    @ViewBuilder
    private var trailing: some View {
        if model.isListening {
            HoldMicButton(active: true, onPress: {}, onRelease: model.endPushToTalk)
                .accessibilityLabel("Release to send")
        } else {
            HStack(spacing: 8) {
                HoldMicButton(
                    active: false,
                    onPress: model.beginPushToTalk,
                    onRelease: model.endPushToTalk
                )
                .accessibilityLabel("Hold to talk")
                .help(model.ears.engineInstalled ? "Hold to talk (or hold Space)" : "Install Ears to talk")

                if canSend {
                    Button(action: submit) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.paper)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(model.character.palette.ink))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return, modifiers: [])
                    .help("Send")
                }
            }
        }
    }

    private func submit() {
        guard canSend else { return }
        let text = draft
        draft = ""
        model.send(text)
    }
}

private struct HoldMicButton: View {
    let active: Bool
    let onPress: () -> Void
    let onRelease: () -> Void
    @State private var pressing = false

    var body: some View {
        Image(systemName: active ? "waveform" : "mic.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(active ? Theme.paper : Theme.ink.opacity(0.8))
            .frame(width: 32, height: 32)
            .background(
                Circle().fill(active ? Theme.ink : Theme.ink.opacity(0.06))
            )
            .contentShape(Circle())
            .onLongPressGesture(minimumDuration: 0.01, maximumDistance: .infinity) {
            } onPressingChanged: { isPressing in
                if isPressing, !pressing {
                    pressing = true
                    onPress()
                } else if !isPressing, pressing {
                    pressing = false
                    onRelease()
                }
            }
            .accessibilityAddTraits(.isButton)
    }
}

private struct Waveform: View {
    let level: Float
    let tint: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(0..<4) { index in
                    let wobble = 0.5 + 0.5 * sin(time * 8 + Double(index) * 1.7)
                    let height = 4 + CGFloat(max(level, 0.12)) * 18 * CGFloat(wobble)
                    Capsule()
                        .fill(tint.opacity(0.9))
                        .frame(width: 2.5, height: height)
                }
            }
            .frame(width: 24, height: 24)
        }
        .accessibilityHidden(true)
    }
}
