import SwiftUI

/// The look every dialogue plate shares: warm parchment, a double gilt border, a deep shadow.
private struct PlateSurface: ViewModifier {
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Theme.parchment, Theme.parchmentDeep],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.gilt, lineWidth: 1.6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius - 6, style: .continuous)
                    .strokeBorder(Theme.ink.opacity(0.10), lineWidth: 0.8)
                    .padding(5)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: .black.opacity(0.38), radius: 26, y: 12)
    }
}

extension View {
    func plate(radius: CGFloat = 24) -> some View {
        modifier(PlateSurface(radius: radius))
    }
}

/// A ribbon with notched ends, used for hint banners.
struct BannerShape: Shape {
    var notch: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let n = min(notch, rect.width / 4)
        path.move(to: CGPoint(x: n, y: 0))
        path.addLine(to: CGPoint(x: rect.width - n, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width - n, y: rect.height))
        path.addLine(to: CGPoint(x: n, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

/// A small gold medallion carrying the character's emblem.
struct EmblemBadge: View {
    let emblem: Emblem
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            Circle().fill(Theme.ink.opacity(0.72))
            Circle().strokeBorder(Theme.gilt, lineWidth: 1.4)
            Image(systemName: emblem.symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(Theme.giltLight)
        }
        .frame(width: size, height: size)
    }
}

/// A key you can press, for the HUD footer.
struct KeyCap: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(Theme.label(10, weight: .semibold))
            .foregroundStyle(Theme.parchment)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Theme.parchment.opacity(0.12)))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Theme.parchment.opacity(0.22), lineWidth: 0.7)
            )
    }
}

struct StreamingDots: View {
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
