import SwiftUI

/// The character on stage. One renderer now: ink paths in `InkFace`, framed by the aura,
/// the emblem badge and the listening ring.
struct PortraitView: View {
    let character: Persona
    let level: Float
    let mouth: MouthShape
    let listening: Bool
    let speaking: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 24.0)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height)
                let palette = character.palette
                let scene = CharacterScene.of(character.id)
                let breathe = reduceMotion ? 0 : sin(time * 0.85) * 0.006

                ZStack {
                    PortraitAura(
                        palette: palette,
                        side: side,
                        pulse: CGFloat(level),
                        breathe: breathe,
                        time: time,
                        reduceMotion: reduceMotion
                    )

                    SceneLayer(
                        scene: scene,
                        palette: palette,
                        level: CGFloat(level),
                        time: time,
                        reduceMotion: reduceMotion
                    )

                    InkFace(
                        look: CharacterLook.of(character.id),
                        palette: palette,
                        mouth: mouth,
                        level: CGFloat(level),
                        listening: listening,
                        time: time,
                        reduceMotion: reduceMotion,
                        breeze: scene.breeze
                    )
                    .frame(width: side, height: side)

                    PortraitEmblem(symbol: character.emblem.symbol, side: side, palette: palette)

                    if listening {
                        ListeningRing(palette: palette, side: side, level: level)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .mask(portraitFade)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(character.name). \(character.tagline).")
        .accessibilityValue(listening ? "Listening" : (speaking ? "Speaking" : "Idle"))
    }
}

// MARK: - Shared pieces

private struct PortraitEmblem: View {
    let symbol: String
    let side: CGFloat
    let palette: CharacterPalette

    var body: some View {
        ZStack {
            Circle()
                .fill(palette.paper.opacity(0.95))
                .overlay(Circle().strokeBorder(palette.ink.opacity(0.7), lineWidth: 1.5))
            Image(systemName: symbol)
                .font(.system(size: side * 0.052, weight: .medium))
                .foregroundStyle(palette.ink)
        }
        .frame(width: side * 0.11, height: side * 0.11)
        .offset(y: side * 0.33)
    }
}

private struct PortraitAura: View {
    let palette: CharacterPalette
    let side: CGFloat
    let pulse: CGFloat
    let breathe: CGFloat
    let time: TimeInterval
    let reduceMotion: Bool

    var body: some View {
        ZStack {
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
        }
    }
}

private struct ListeningRing: View {
    let palette: CharacterPalette
    let side: CGFloat
    let level: Float

    var body: some View {
        Circle()
            .strokeBorder(palette.accent, lineWidth: 2)
            .frame(width: side * 0.78, height: side * 0.78)
            .scaleEffect(0.96 + CGFloat(level) * 0.1)
            .opacity(0.85)
    }
}

private let portraitFade = LinearGradient(
    stops: [
        .init(color: .black, location: 0),
        .init(color: .black, location: 0.84),
        .init(color: .clear, location: 1),
    ],
    startPoint: .top,
    endPoint: .bottom
)
