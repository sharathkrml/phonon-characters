import SwiftUI

/// A character drawn rather than photographed: ink silhouette, per-character palette, an emblem,
/// a halo that reacts to the voice, and a mouth driven by real playback amplitude.
struct PortraitView: View {
    let character: Persona
    let level: Float
    let listening: Bool
    let speaking: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30.0, paused: reduceMotion)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height)
                let palette = character.palette
                let pulse = CGFloat(level)
                let breathe = reduceMotion ? 0 : sin(time * 0.85) * 0.006
                let blink = !reduceMotion && time.truncatingRemainder(dividingBy: 5.4) < 0.13

                ZStack {
                    // Aura
                    Circle()
                        .fill(RadialGradient(
                            colors: [palette.aura.opacity(0.38), palette.aura.opacity(0.08), .clear],
                            center: .center,
                            startRadius: side * 0.05,
                            endRadius: side * 0.5
                        ))
                        .frame(width: side * 0.9, height: side * 0.9)
                        .scaleEffect(1 + pulse * 0.075 + breathe)
                        .blur(radius: 20)

                    Circle()
                        .strokeBorder(palette.accent.opacity(0.22), lineWidth: 1)
                        .frame(width: side * 0.76, height: side * 0.76)
                        .scaleEffect(1 + pulse * 0.045)

                    Circle()
                        .stroke(palette.ink.opacity(0.14), style: StrokeStyle(lineWidth: 1, dash: [2, 7]))
                        .frame(width: side * 0.9, height: side * 0.9)
                        .rotationEffect(.degrees(reduceMotion ? 0 : time * 2.5))

                    // Neck, then shoulders
                    RoundedRectangle(cornerRadius: side * 0.035, style: .continuous)
                        .fill(palette.ink)
                        .frame(width: side * 0.15, height: side * 0.16)
                        .offset(y: side * 0.11)

                    ShouldersShape()
                        .fill(LinearGradient(
                            colors: [palette.ink, palette.ink.opacity(0.84)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: side * 0.92, height: side * 0.54)
                        .offset(y: side * 0.32)

                    // Emblem on the chest
                    ZStack {
                        Circle()
                            .fill(palette.paper.opacity(0.95))
                            .overlay(Circle().strokeBorder(palette.ink.opacity(0.7), lineWidth: 1.5))
                        Image(systemName: character.emblem.symbol)
                            .font(.system(size: side * 0.052, weight: .medium))
                            .foregroundStyle(palette.ink)
                    }
                    .frame(width: side * 0.125, height: side * 0.125)
                    .offset(y: side * 0.30)

                    // Head
                    Circle()
                        .fill(palette.paper)
                        .overlay(Circle().strokeBorder(palette.ink, lineWidth: max(2.2, side * 0.009)))
                        .frame(width: side * 0.46, height: side * 0.46)
                        .offset(y: -side * 0.08)

                    // Hair sits on the crown, over the head outline.
                    HairCapShape()
                        .fill(palette.ink)
                        .frame(width: side * 0.47, height: side * 0.19)
                        .offset(y: -side * 0.265)

                    HairStrandsShape(style: hairStyle)
                        .stroke(palette.ink, style: StrokeStyle(lineWidth: max(1.8, side * 0.005), lineCap: .round))
                        .frame(width: side * 0.52, height: side * 0.28)
                        .offset(y: -side * 0.16)

                    // Face
                    HStack(spacing: side * 0.085) {
                        Eye(blink: blink, color: palette.ink, side: side)
                        Eye(blink: blink, color: palette.ink, side: side)
                    }
                    .offset(y: -side * 0.125)

                    Capsule()
                        .fill(palette.ink.opacity(0.35))
                        .frame(width: max(1.6, side * 0.008), height: side * 0.032)
                        .offset(y: -side * 0.06)

                    Capsule()
                        .fill(palette.ink)
                        .frame(
                            width: side * (0.052 + pulse * 0.045),
                            height: max(2.4, side * (0.007 + pulse * 0.048))
                        )
                        .offset(y: -side * 0.028)

                    if listening {
                        Circle()
                            .strokeBorder(palette.accent, lineWidth: 2)
                            .frame(width: side * 0.78, height: side * 0.78)
                            .scaleEffect(0.96 + CGFloat(level) * 0.1)
                            .opacity(0.85)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: 0.84),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(character.name). \(character.tagline).")
        .accessibilityValue(listening ? "Listening" : (speaking ? "Speaking" : "Idle"))
    }

    private var hairStyle: Int {
        abs(character.id.hashValue) % 3
    }
}

private struct Eye: View {
    let blink: Bool
    let color: Color
    let side: CGFloat

    var body: some View {
        Capsule()
            .fill(color)
            .frame(width: side * 0.021, height: blink ? max(1.6, side * 0.004) : side * 0.015)
    }
}

private struct ShouldersShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.01, y: h * 0.96))
        path.addCurve(
            to: CGPoint(x: w * 0.35, y: h * 0.26),
            control1: CGPoint(x: w * 0.03, y: h * 0.58),
            control2: CGPoint(x: w * 0.14, y: h * 0.30)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.18),
            control1: CGPoint(x: w * 0.41, y: h * 0.24),
            control2: CGPoint(x: w * 0.45, y: h * 0.20)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.65, y: h * 0.26),
            control1: CGPoint(x: w * 0.55, y: h * 0.20),
            control2: CGPoint(x: w * 0.59, y: h * 0.24)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.99, y: h * 0.96),
            control1: CGPoint(x: w * 0.86, y: h * 0.30),
            control2: CGPoint(x: w * 0.97, y: h * 0.58)
        )
        path.addLine(to: CGPoint(x: w * 0.99, y: h))
        path.addLine(to: CGPoint(x: w * 0.01, y: h))
        path.closeSubpath()
        return path
    }
}

/// A soft cap of hair sitting over the top of the head.
private struct HairCapShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: 0, y: h * 0.92))
        path.addCurve(
            to: CGPoint(x: w, y: h * 0.92),
            control1: CGPoint(x: w * 0.02, y: -h * 0.16),
            control2: CGPoint(x: w * 0.98, y: -h * 0.16)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: h * 0.92),
            control1: CGPoint(x: w * 0.76, y: h * 0.52),
            control2: CGPoint(x: w * 0.24, y: h * 0.52)
        )
        path.closeSubpath()
        return path
    }
}

private struct HairStrandsShape: Shape {
    let style: Int

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        switch style {
        case 0:
            path.move(to: CGPoint(x: w * 0.06, y: h * 0.18))
            path.addQuadCurve(to: CGPoint(x: w * 0.05, y: h * 0.78), control: CGPoint(x: w * 0.0, y: h * 0.5))
            path.move(to: CGPoint(x: w * 0.16, y: h * 0.16))
            path.addQuadCurve(to: CGPoint(x: w * 0.14, y: h * 0.95), control: CGPoint(x: w * 0.04, y: h * 0.58))
        case 1:
            path.move(to: CGPoint(x: w * 0.94, y: h * 0.18))
            path.addQuadCurve(to: CGPoint(x: w * 0.95, y: h * 0.8), control: CGPoint(x: w, y: h * 0.5))
            path.move(to: CGPoint(x: w * 0.84, y: h * 0.16))
            path.addQuadCurve(to: CGPoint(x: w * 0.86, y: h * 0.96), control: CGPoint(x: w * 0.96, y: h * 0.6))
        default:
            path.move(to: CGPoint(x: w * 0.05, y: h * 0.22))
            path.addQuadCurve(to: CGPoint(x: w * 0.12, y: h * 0.92), control: CGPoint(x: w * 0.05, y: h * 0.6))
            path.move(to: CGPoint(x: w * 0.95, y: h * 0.22))
            path.addQuadCurve(to: CGPoint(x: w * 0.88, y: h * 0.92), control: CGPoint(x: w * 0.95, y: h * 0.6))
        }
        return path
    }
}
