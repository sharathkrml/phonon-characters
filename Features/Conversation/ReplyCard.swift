import SwiftUI

struct ReplyCard: View {
    @ObservedObject var model: ConversationModel

    @State private var replyTextHeight: CGFloat = 0

    private var reply: ConversationModel.Message? { model.latestReply }
    private var echo: String? { model.lastUserMessage }

    /// Padding, header row and the optional "you said" line around the scrolling reply.
    private var chromeHeight: CGFloat {
        (14 + 16) + (24 + 10) + (echo == nil ? 0 : 33)
    }

    private var cardHeight: CGFloat {
        min(max(chromeHeight + max(replyTextHeight, 22.5), 96), 200)
    }

    private var textViewport: CGFloat {
        max(20, cardHeight - chromeHeight)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let echo {
                Text("You said: \(echo)")
                    .font(Theme.body(11.5))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.bottom, 8)

                InkRule(opacity: 0.08)
                    .padding(.bottom, 8)
            }

            headerRow
                .frame(height: 24)
                .padding(.bottom, 10)

            ScrollView {
                replyText
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(key: ReplyTextHeightKey.self, value: proxy.size.height)
                        }
                    )
            }
            .scrollIndicators(.never)
            .frame(height: textViewport, alignment: .top)
            .overlay(alignment: .bottom) {
                if replyTextHeight > textViewport + 1 {
                    LinearGradient(
                        colors: [Theme.paper.opacity(0), Theme.paper.opacity(0.96)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 22)
                    .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if replyTextHeight > textViewport + 1 {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Theme.paper))
                        .padding(.trailing, 2)
                        .padding(.bottom, 2)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.paper.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Theme.ink.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.045), radius: 14, y: 6)
        )
        .onPreferenceChange(ReplyTextHeightKey.self) { replyTextHeight = $0 }
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(model.character.shortName)
                .font(Theme.body(10.5, weight: .semibold))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.inkSoft)
                .accessibilityAddTraits(.isHeader)

            if reply?.streaming == true {
                StreamingDots(tint: model.character.palette.aura)
            }

            if model.isBusy {
                Button {
                    model.interrupt()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Theme.ink.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help("Stop the character")
                .accessibilityLabel("Stop the character")
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var replyText: some View {
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
                .foregroundStyle(Theme.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var emptyText: String {
        if model.phase == .thinking {
            return "\(firstName) is thinking…"
        }
        if !model.models.voiceReady {
            return "Download the voice to hear your character."
        }
        if !model.models.brainReady {
            return "Download the brain and \(firstName) can answer."
        }
        return "Hold Space and speak, or type a message."
    }

    private var firstName: String { model.character.shortName }
}

private struct ReplyTextHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
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
