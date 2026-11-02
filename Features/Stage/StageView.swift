import SwiftUI

struct StageView: View {
    @ObservedObject var model: ConversationModel
    @ObservedObject var prefs = Preferences.shared

    @State private var draft = ""

    private var character: Persona { model.character }

    var body: some View {
        GeometryReader { geo in
            let contentWidth = min(geo.size.width, 1180)
            let portraitSide = min(contentWidth * 0.44, max(280, geo.size.height - 370), 470)

            ZStack {
                PaperBackground(tint: character.palette.paper)

                VStack(spacing: 0) {
                    header
                    portraitStage(side: portraitSide)
                    Spacer(minLength: 16)

                    VStack(spacing: 10) {
                        banner
                        HStack(alignment: .bottom, spacing: 24) {
                            ReplyCard(model: model)
                            Composer(model: model, draft: $draft)
                                .frame(width: 420)
                        }
                        .padding(.horizontal, 30)
                    }

                    Spacer(minLength: 12)
                    footer
                }
                .frame(width: contentWidth)
                .padding(.top, 22)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { model.activate() }
        .onDisappear { model.deactivate() }
        .animation(.easeInOut(duration: 0.35), value: character.id)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(character.name)
                .font(Theme.display(31))
                .tracking(0.6)
                .foregroundStyle(Theme.ink)
                .contentTransition(.opacity)

            Text(character.tagline)
                .font(Theme.body(12.5, weight: .medium))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(.top, 6)
    }

    private func portraitStage(side: CGFloat) -> some View {
        ZStack {
            PortraitView(
                character: character,
                level: model.isListening ? model.micLevel : model.phonon.level,
                mouth: model.phonon.mouth,
                listening: model.isListening,
                speaking: model.isSpeaking
            )
            .id(character.id)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .frame(width: side, height: side)
            .allowsHitTesting(false)

            HStack {
                ChevronButton(direction: .left) { model.step(-1) }
                    .accessibilityLabel("Previous character")
                Spacer()
                ChevronButton(direction: .right) { model.step(1) }
                    .accessibilityLabel("Next character")
            }
            .frame(width: side + 140, height: 46)
        }
        .frame(width: side + 140, height: side)
        .padding(.top, 2)
    }

    @ViewBuilder
    private var banner: some View {
        if let error = model.errorText {
            Banner(text: error, tint: .red) { model.errorText = nil }
        } else if let hint = model.hint {
            Banner(
                text: hint,
                tint: character.palette.aura,
                actionTitle: hintActionTitle,
                action: model.suggestedInputUID == nil ? nil : { model.useSuggestedInput() }
            ) { model.hint = nil }
        } else if model.busyLoading {
            Banner(text: "Waking the brain — the first load takes a few seconds.", tint: character.palette.aura, dismissible: false) {}
        } else if model.isListening && model.ears.state.isBusy {
            Banner(text: "Waking the ears — the first listen downloads 158 MB and compiles shaders.", tint: character.palette.aura, dismissible: false) {}
        }
    }

    private var hintActionTitle: String? {
        guard let uid = model.suggestedInputUID else { return nil }
        let name = AudioDevices.name(for: uid) ?? "built-in mic"
        return "Use \(name)"
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text(footerHint)
                .font(Theme.body(11))
                .foregroundStyle(Theme.inkSoft)
            Spacer()
            MicPicker()
            Text("On-device · private")
                .font(Theme.body(11, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(.horizontal, 30)
    }

    private var footerHint: String {
        if model.isListening {
            return "Release to send · Esc to cancel"
        }
        if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return model.isBusy ? "Reply in progress · Esc stops speech" : "Return to send · Esc stops speech"
        }
        return "Hold Space to talk · ← → change character · Esc stops speech"
    }
}

private struct ChevronButton: View {
    enum Direction { case left, right }

    let direction: Direction
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Theme.paper.opacity(0.65))
                    .overlay(Circle().strokeBorder(Theme.ink.opacity(0.25), lineWidth: 1.2))
                    .shadow(color: .black.opacity(0.03), radius: 8, y: 3)
                Image(systemName: direction == .left ? "chevron.left" : "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.75))
                    .offset(x: direction == .left ? -1 : 1)
            }
            .frame(width: 46, height: 46)
        }
        .buttonStyle(.plain)
    }
}

private struct Banner: View {
    let text: String
    let tint: Color
    let actionTitle: String?
    let action: (() -> Void)?
    let dismissible: Bool
    let dismiss: () -> Void

    init(
        text: String,
        tint: Color,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        dismissible: Bool = true,
        dismiss: @escaping () -> Void
    ) {
        self.text = text
        self.tint = tint
        self.actionTitle = actionTitle
        self.action = action
        self.dismissible = dismissible
        self.dismiss = dismiss
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(tint).frame(width: 7, height: 7)
            Text(text)
                .font(Theme.body(12))
                .foregroundStyle(Theme.ink.opacity(0.9))
                .lineLimit(2)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(Theme.body(11.5, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .buttonStyle(.plain)
            }
            if dismissible {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.inkSoft)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Capsule().fill(Theme.paper.opacity(0.92))
                .overlay(Capsule().strokeBorder(tint.opacity(0.25), lineWidth: 1))
        )
        .padding(.horizontal, 30)
    }
}
