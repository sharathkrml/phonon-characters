import SwiftUI
import AppKit

struct StageView: View {
    @ObservedObject var model: ConversationModel
    @ObservedObject var prefs = Preferences.shared

    @State private var draft = ""

    private var character: Persona { model.character }

    var body: some View {
        GeometryReader { geo in
            let contentWidth = min(geo.size.width - 52, 1180)

            ZStack {
                StageBackdrop(palette: character.palette)

                characterStage(size: geo.size)

                if let effect = model.stageEffect {
                    StageFXLayer(
                        effect: effect,
                        strength: model.stageStrength,
                        palette: character.palette,
                        startedAt: model.stageStartedAt
                    )
                    .transition(.opacity.animation(.easeInOut(duration: 0.9)))
                }

                topScrim

                StageFXRail(
                    abilities: StageEffect.abilities(for: character.id),
                    active: model.stageEffect
                ) { model.toggleStage($0) }
                .padding(.trailing, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)

                VStack(spacing: 0) {
                    hud

                    Spacer(minLength: 12)

                    VStack(spacing: 8) {
                        banner
                        dialoguePlate
                        RosterRail(
                            characters: Persona.all,
                            selected: model.selectedIndex,
                            onSelect: model.select
                        )
                        footer
                    }
                }
                .frame(width: contentWidth)
                .padding(.horizontal, 26)
                .padding(.top, 34)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { model.activate() }
        .onDisappear { model.deactivate() }
        .animation(.easeInOut(duration: 0.35), value: character.id)
    }

    // MARK: - Stage

    private func characterStage(size: CGSize) -> some View {
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
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    private var topScrim: some View {
        LinearGradient(colors: [.black.opacity(0.34), .clear], startPoint: .top, endPoint: .bottom)
            .frame(height: 110)
            .frame(maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)
    }

    // MARK: - HUD

    private var hud: some View {
        HStack(spacing: 6) {
            logoMark
            Text("Phonon Characters")
                .font(Theme.label(9.5))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(Theme.parchment.opacity(0.72))
                .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
            Spacer()
            statusChip("Voice", ready: model.models.voiceReady, value: model.phonon.voiceSpeed.map(factor))
            statusChip("Brain", ready: model.models.brainReady, value: model.brainSpeed.map(tokens))
            statusChip("Ears", ready: model.ears.engineInstalled, value: model.earsSpeed.map(factor))
        }
    }

    private func tokens(_ speed: Double) -> String {
        speed >= 100 ? String(format: "%.0f tok/s", speed) : String(format: "%.1f tok/s", speed)
    }

    private func factor(_ value: Double) -> String {
        value >= 10 ? String(format: "%.0f×", value) : String(format: "%.1f×", value)
    }

    private static let logoImage = Bundle.main
        .url(forResource: "LogoMark", withExtension: "png")
        .flatMap(NSImage.init(contentsOf:))

    private var logoMark: some View {
        Group {
            if let image = Self.logoImage {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
            } else {
                Color.clear
            }
        }
        .frame(width: 28, height: 28)
        .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
        .accessibilityLabel("Phonon Characters")
    }

    private func statusChip(_ label: String, ready: Bool, value: String? = nil) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(ready ? Theme.ready : Theme.parchment.opacity(0.35))
                .frame(width: 6, height: 6)
            Text(label)
                .font(Theme.label(9.5))
                .tracking(1.1)
                .textCase(.uppercase)
            if let value {
                Text(value)
                    .font(Theme.label(9.5).monospacedDigit())
                    .foregroundStyle(Theme.parchment.opacity(0.45))
            }
        }
        .foregroundStyle(Theme.parchment.opacity(0.72))
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(.black.opacity(0.24)))
        .overlay(Capsule().strokeBorder(Theme.parchment.opacity(0.10), lineWidth: 0.7))
    }

    // MARK: - Dialogue plate

    private var dialoguePlate: some View {
        VStack(spacing: 0) {
            nameplate
            ReplyCard(model: model)
            Rectangle()
                .fill(Theme.gilt.opacity(0.45))
                .frame(height: 1)
                .padding(.horizontal, 18)
            Composer(model: model, draft: $draft)
        }
        .plate()
    }

    private var nameplate: some View {
        HStack(spacing: 12) {
            EmblemBadge(emblem: character.emblem, size: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text(character.name)
                    .font(Theme.title(19))
                    .tracking(0.5)
                    .foregroundStyle(Theme.parchment)
                Text(character.tagline)
                    .font(Theme.label(9.5))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.parchment.opacity(0.62))
            }

            Spacer(minLength: 12)

            if model.isBusy {
                Button {
                    model.interrupt()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.parchment)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Theme.parchment.opacity(0.14)))
                }
                .buttonStyle(.plain)
                .help("Stop the character")
                .accessibilityLabel("Stop the character")
            }

            phaseBadge
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [character.palette.ink, character.palette.aura],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    @ViewBuilder
    private var phaseBadge: some View {
        if model.isListening || model.phase != .idle {
            HStack(spacing: 6) {
                Circle()
                    .fill(character.palette.accent)
                    .frame(width: 6, height: 6)
                Text(phaseText)
                    .font(Theme.label(9.5))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.parchment.opacity(0.8))
                if model.latestReply?.streaming == true {
                    StreamingDots(tint: Theme.parchment)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(Theme.parchment.opacity(0.10)))
        }
    }

    private var phaseText: String {
        if model.isListening { return "Listening" }
        switch model.phase {
        case .thinking: return "Thinking"
        case .speaking: return "Speaking"
        default: return "Ready"
        }
    }

    // MARK: - Banner

    @ViewBuilder
    private var banner: some View {
        if let error = model.errorText {
            Banner(text: error, tint: Theme.ember) { model.errorText = nil }
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

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 6) {
            footerHint
            Spacer(minLength: 12)
            MicPicker()
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 8, weight: .semibold))
                Text("On-device")
                    .font(Theme.label(10))
            }
            .foregroundStyle(Theme.parchment.opacity(0.5))
        }
        .padding(.horizontal, 6)
    }

    @ViewBuilder
    private var footerHint: some View {
        if model.isListening {
            KeyCap("Esc")
            hint("cancel")
        } else if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            KeyCap("Return")
            hint("send")
            KeyCap("Esc")
            hint("stop speech")
        } else {
            KeyCap("Space")
            hint("hold to talk")
            KeyCap("← →")
            hint("change character")
            KeyCap("Esc")
            hint("stop speech")
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(Theme.label(10))
            .foregroundStyle(Theme.parchment.opacity(0.55))
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
                    .font(Theme.label(11.5, weight: .bold))
                    .foregroundStyle(Theme.giltDeep)
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
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Ribbon())
        .padding(.horizontal, 30)
    }
}

private struct Ribbon: View {
    var body: some View {
        BannerShape(notch: 10)
            .fill(LinearGradient(
                colors: [Theme.parchment, Theme.parchmentDeep],
                startPoint: .top,
                endPoint: .bottom
            ))
            .overlay(
                BannerShape(notch: 10)
                    .stroke(Theme.gilt, lineWidth: 1.2)
            )
            .shadow(color: .black.opacity(0.28), radius: 12, y: 5)
    }
}
