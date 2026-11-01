import SwiftUI

struct StageView: View {
    @ObservedObject var model: ConversationModel
    @ObservedObject var prefs = Preferences.shared

    @State private var draft = ""

    private var character: Persona { model.character }

    var body: some View {
        GeometryReader { geo in
            let portraitSide = min(geo.size.width * 0.44, max(280, geo.size.height - 370), 470)

            ZStack {
                PaperBackground(tint: character.palette.paper)
                    .animation(.easeInOut(duration: 0.5), value: character.id)

                VStack(spacing: 0) {
                    header
                    portrait(side: portraitSide)
                    Spacer(minLength: 0)
                }
                .padding(.top, 22)

                chevrons

                VStack(spacing: 10) {
                    Spacer(minLength: 0)
                    banner
                    if let echo = model.lastUserMessage, !model.isListening {
                        HStack {
                            Spacer()
                            Text(echo)
                                .font(Theme.body(12))
                                .foregroundStyle(Theme.ink.opacity(0.78))
                                .lineLimit(2)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Theme.paper.opacity(0.85))
                                        .overlay(Capsule().strokeBorder(Theme.ink.opacity(0.10), lineWidth: 1))
                                )
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, 30)
                        .padding(.bottom, 2)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    HStack(alignment: .bottom, spacing: 22) {
                        ReplyCard(model: model)
                            .frame(maxWidth: 520)
                        Spacer(minLength: 18)
                        Composer(model: model, draft: $draft)
                            .frame(width: 400)
                    }
                    .padding(.horizontal, 30)
                    footer
                }
                .padding(.bottom, 16)
            }
        }
        .background(WindowMarker().frame(width: 0, height: 0))
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
                .foregroundStyle(Theme.inkSoft.opacity(0.85))
        }
        .padding(.top, 6)
    }

    private func portrait(side: CGFloat) -> some View {
        PortraitView(
            character: character,
            level: model.isListening ? model.micLevel : model.phonon.level,
            listening: model.isListening,
            speaking: model.isSpeaking
        )
        .id(character.id)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .frame(width: side, height: side)
        .padding(.top, 2)
    }

    private var chevrons: some View {
        HStack {
            ChevronButton(direction: .left) { model.step(-1) }
                .accessibilityLabel("Previous character")
            Spacer()
            ChevronButton(direction: .right) { model.step(1) }
                .accessibilityLabel("Next character")
        }
        .padding(.horizontal, 34)
        .offset(y: -30)
    }

    @ViewBuilder
    private var banner: some View {
        if let error = model.errorText {
            Banner(text: error, tint: .red) { model.errorText = nil }
        } else if let hint = model.hint {
            Banner(text: hint, tint: character.palette.aura) { model.hint = nil }
        } else if model.busyLoading {
            Banner(text: "Waking the brain — the first load takes a few seconds.", tint: character.palette.aura, dismissible: false) {}
        } else if model.isListening && model.ears.state.isBusy {
            Banner(text: "Waking the ears — the first listen downloads 158 MB and compiles shaders.", tint: character.palette.aura, dismissible: false) {}
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text(model.isListening
                 ? "Release to send · Esc to cancel"
                 : "Hold Space to talk · ← → change character · Esc stops speech")
                .font(Theme.body(11))
                .foregroundStyle(Theme.inkSoft.opacity(0.8))
            Spacer()
            MicPicker()
            Text("On-device · private")
                .font(Theme.body(11, weight: .medium))
                .foregroundStyle(Theme.inkSoft.opacity(0.65))
        }
        .padding(.horizontal, 34)
    }
}

private struct ChevronButton: View {
    enum Direction { case left, right }

    let direction: Direction
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Theme.paper.opacity(hovering ? 0.95 : 0.65))
                    .overlay(Circle().strokeBorder(Theme.ink.opacity(hovering ? 0.5 : 0.25), lineWidth: 1.2))
                    .shadow(color: .black.opacity(hovering ? 0.08 : 0.03), radius: 8, y: 3)
                Image(systemName: direction == .left ? "chevron.left" : "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.75))
                    .offset(x: direction == .left ? -1 : 1)
            }
            .frame(width: 46, height: 46)
            .scaleEffect(hovering ? 1.06 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: hovering)
    }
}

private struct Banner: View {
    let text: String
    let tint: Color
    let dismissible: Bool
    let dismiss: () -> Void

    init(text: String, tint: Color, dismissible: Bool = true, dismiss: @escaping () -> Void) {
        self.text = text
        self.tint = tint
        self.dismissible = dismissible
        self.dismiss = dismiss
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(tint).frame(width: 7, height: 7)
            Text(text)
                .font(Theme.body(12))
                .foregroundStyle(Theme.ink.opacity(0.85))
                .lineLimit(2)
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
