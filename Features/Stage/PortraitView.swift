import SwiftUI

/// The character on stage: a full-bleed painted portrait when one exists, the ink fallback
/// otherwise. The image keeps its original composition; only the bottom edge fades into the page.
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
                    if let art = PortraitArt.load(character.id) {
                        PortraitImage(
                            art: art,
                            level: CGFloat(level),
                            listening: listening,
                            time: time,
                            reduceMotion: reduceMotion
                        )
                        .shadow(color: palette.ink.opacity(0.55), radius: 28, y: 10)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                    } else {
                        // The procedural face is ink on paper, so it sits on a parchment halo
                        // instead of the painted backdrop.
                        Circle()
                            .fill(RadialGradient(
                                colors: [palette.paper, palette.paper.opacity(0.85), .clear],
                                center: .center,
                                startRadius: side * 0.05,
                                endRadius: side * 0.5
                            ))
                            .frame(width: side, height: side)

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

private let portraitFade = LinearGradient(
    stops: [
        .init(color: .black, location: 0),
        .init(color: .black, location: 0.84),
        .init(color: .clear, location: 1),
    ],
    startPoint: .top,
    endPoint: .bottom
)
