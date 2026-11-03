import SwiftUI

struct Composer: View {
    @ObservedObject var model: ConversationModel
    @Binding var draft: String
    @FocusState private var focused: Bool

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !model.isBusy
    }

    var body: some View {
        HStack(spacing: 10) {
            // Both stay mounted: swapping an AppKit-backed TextField/ScrollView in and out
            // leaves a stale NSViewResponder that crashes hit-testing on macOS 27.
            ZStack(alignment: .leading) {
                field
                    .opacity(model.isListening ? 0 : 1)
                    .disabled(model.isListening)
                    .allowsHitTesting(!model.isListening)
                listening
                    .opacity(model.isListening ? 1 : 0)
                    .allowsHitTesting(model.isListening)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.paper.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                model.isListening
                                    ? model.character.palette.accent.opacity(0.85)
                                    : Theme.ink.opacity(focused ? 0.35 : 0.14),
                                lineWidth: model.isListening ? 1.6 : 1
                            )
                    )
            )

            trailing
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .animation(.easeOut(duration: 0.18), value: model.isListening)
        .onChange(of: model.isListening) { _, listening in
            focused = !listening
        }
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
        .font(Theme.body(14))
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

    private var listening: some View {
        HStack(spacing: 10) {
            if model.isListening {
                Waveform(level: model.micLevel, tint: model.character.palette.aura)
            } else {
                Color.clear.frame(width: 24, height: 24)
            }

            if model.transcriber.committed.isEmpty && model.transcriber.current.isEmpty {
                Text("Listening…")
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.inkSoft.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 0) {
                        Text(model.transcriber.committed.isEmpty ? "" : model.transcriber.committed + " ")
                            .foregroundStyle(Theme.ink)
                        Text(model.transcriber.current)
                            .foregroundStyle(Theme.ink.opacity(0.55))
                    }
                    .font(Theme.body(14))
                    .lineLimit(1)
                }
                .scrollIndicators(.never)
                .defaultScrollAnchor(.trailing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("Listening. \(model.transcriber.text)")
    }

    @ViewBuilder
    private var trailing: some View {
        HStack(spacing: 8) {
            HoldMicButton(
                active: model.isListening,
                tint: model.character.palette.aura,
                accent: model.character.palette.accent,
                onPress: model.beginPushToTalk,
                onRelease: model.endPushToTalk
            )
            .accessibilityLabel(model.isListening ? "Release to send" : "Hold to talk")
            .help(model.ears.engineInstalled ? "Hold to talk (or hold Space)" : "Install Ears to talk")

            if canSend && !model.isListening {
                Button(action: submit) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(Theme.gilt)
                                .overlay(Circle().strokeBorder(Theme.ink.opacity(0.15), lineWidth: 0.8))
                        )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: [])
                .help("Send")
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
    let tint: Color
    let accent: Color
    let onPress: () -> Void
    let onRelease: () -> Void
    @State private var pressing = false

    var body: some View {
        Image(systemName: active ? "waveform" : "mic.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(active ? Theme.ink : Theme.ink.opacity(0.8))
            .frame(width: 34, height: 34)
            .background(
                Circle().fill(
                    active
                        ? AnyShapeStyle(LinearGradient(colors: [accent, tint], startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(Theme.ink.opacity(0.07))
                )
            )
            .overlay(
                Circle().strokeBorder(
                    active ? AnyShapeStyle(Theme.gilt) : AnyShapeStyle(Theme.ink.opacity(0.12)),
                    lineWidth: 1
                )
            )
            .shadow(color: active ? accent.opacity(0.45) : .clear, radius: 8)
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
                    let height = 7 + CGFloat(max(level, 0.12)) * 16 * CGFloat(wobble)
                    Capsule()
                        .fill(tint.opacity(0.9))
                        .frame(width: 3, height: height)
                }
            }
            .frame(width: 24, height: 24)
        }
        .accessibilityHidden(true)
    }
}
