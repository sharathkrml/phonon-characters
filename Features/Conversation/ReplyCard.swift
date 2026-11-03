import SwiftUI

struct ReplyCard: View {
    @ObservedObject var model: ConversationModel

    @State private var replyTextHeight: CGFloat = 0

    private var reply: ConversationModel.Message? { model.latestReply }
    private var echo: String? { model.lastUserMessage }

    /// Padding and the optional "you said" line around the scrolling reply.
    private var chromeHeight: CGFloat {
        (12 + 12) + (echo == nil ? 0 : 30)
    }

    private var cardHeight: CGFloat {
        min(max(chromeHeight + max(replyTextHeight, 23), 78), 180)
    }

    private var textViewport: CGFloat {
        max(20, cardHeight - chromeHeight)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let echo {
                Text("“\(echo)”")
                    .font(Theme.body(11.5))
                    .foregroundStyle(Theme.inkSoft.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.bottom, 8)

                Rectangle()
                    .fill(Theme.gilt.opacity(0.4))
                    .frame(height: 1)
                    .padding(.bottom, 8)
            }

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
                        colors: [Theme.parchment.opacity(0), Theme.parchment.opacity(0.96)],
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
                        .foregroundStyle(Theme.giltDeep)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Theme.parchment))
                        .padding(.trailing, 2)
                        .padding(.bottom, 2)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight, alignment: .topLeading)
        .onPreferenceChange(ReplyTextHeightKey.self) { replyTextHeight = $0 }
    }

    @ViewBuilder
    private var replyText: some View {
        if let reply, !reply.text.isEmpty {
            Text(reply.text)
                .font(Theme.display(16))
                .lineSpacing(5)
                .foregroundStyle(Theme.ink)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(emptyText)
                .font(Theme.display(15))
                .italic()
                .lineSpacing(4.5)
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
