import SwiftUI

struct ReplyCard: View {
    @ObservedObject var model: ConversationModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var reply: ConversationModel.Message? { model.latestReply }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text("Reply from AI")
                    .font(Theme.body(10.5, weight: .semibold))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.inkSoft)

                if model.isBusy {
                    StreamingDots(tint: model.character.palette.aura)
                }

                Spacer()

                if model.isBusy {
                    Button {
                        model.interrupt()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.inkSoft)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Theme.ink.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                    .help("Stop the character")
                    .accessibilityLabel("Stop speaking")
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    Group {
                        if let reply, !reply.text.isEmpty {
                            Text(reply.text)
                                .font(Theme.display(15))
                                .lineSpacing(4.5)
                                .foregroundStyle(Theme.ink)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text(emptyText)
                                .font(Theme.display(14.5))
                                .italic()
                                .lineSpacing(4)
                                .foregroundStyle(Theme.inkSoft.opacity(0.75))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .id("bottom")
                }
                .scrollIndicators(.never)
                .onChange(of: reply?.text) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .frame(minWidth: 360, maxWidth: .infinity, minHeight: 168, maxHeight: 168, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.paper.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Theme.ink.opacity(0.14), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.045), radius: 14, y: 6)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reply from \(model.character.name)")
    }

    private var emptyText: String {
        if !model.models.voiceReady {
            return "Download the voice to hear your character."
        }
        if !model.models.brainReady {
            return "Download the brain and \(firstName) can answer."
        }
        return "Hold Space and speak, or type a message below."
    }

    private var firstName: String { model.character.shortName }
}

private struct StreamingDots: View {
    let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.35)) { context in
            let tick = Int(context.date.timeIntervalSinceReferenceDate * 3) % 3
            HStack(spacing: 3) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(tint.opacity(reduceMotion ? 0.6 : (index == tick ? 0.95 : 0.3)))
                        .frame(width: 4, height: 4)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
