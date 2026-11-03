import SwiftUI

/// Weather over the stage, drawn in front of the portrait so it works with the painted art.
/// Everything is ink geometry; Reduce Motion stills the particles and drops the lightning.
struct StageFXLayer: View {
    let effect: StageEffect
    let strength: Double
    let palette: CharacterPalette
    let startedAt: Date

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 24.0)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(startedAt))
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate

            ZStack {
                wash
                Canvas { context, size in
                    var painter = FXPainter(
                        context: context,
                        size: size,
                        effect: effect,
                        palette: palette,
                        level: strength,
                        time: time,
                        elapsed: elapsed,
                        reduceMotion: reduceMotion
                    )
                    painter.draw()
                }
                if effect == .storm, !reduceMotion {
                    Rectangle()
                        .fill(.white)
                        .opacity(FXPainter.flash(at: elapsed))
                        .blendMode(.plusLighter)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A quiet palette wash so the room changes, not just the air in front of it.
    private var wash: some View {
        LinearGradient(
            colors: [
                tint.opacity(0.16 * strength),
                .clear,
                tint.opacity(0.09 * strength),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .blendMode(.plusLighter)
    }

    private var tint: Color {
        switch effect {
        case .embers: Color(hex: 0xE8913F)
        case .snow, .fog: palette.paper
        case .sparkle: palette.accent
        case .rain, .storm, .wind: palette.aura
        }
    }
}

/// The manual effects rail: the active character's own abilities, low-contrast until hovered.
struct StageFXRail: View {
    let abilities: [StageAbility]
    let active: StageEffect?
    let onPick: (StageEffect) -> Void

    @State private var hovering = false

    var body: some View {
        VStack(spacing: 5) {
            ForEach(abilities, id: \.effect) { ability in
                Button {
                    onPick(ability.effect)
                } label: {
                    Image(systemName: ability.effect.symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.parchment.opacity(active == ability.effect ? 1 : 0.58))
                        .frame(width: 26, height: 26)
                        .background(
                            Circle().fill(
                                active == ability.effect
                                    ? Color.black.opacity(0.62)
                                    : Color.black.opacity(0.24)
                            )
                        )
                        .overlay(
                            Circle().strokeBorder(
                                active == ability.effect
                                    ? Theme.giltLight.opacity(0.85)
                                    : Theme.parchment.opacity(0.10),
                                lineWidth: 0.8
                            )
                        )
                }
                .buttonStyle(.plain)
                .help("\(ability.name.capitalized) — say “\(ability.example)”")
                .accessibilityLabel("\(ability.name). Try saying: \(ability.example)")
                .accessibilityAddTraits(active == ability.effect ? [.isSelected] : [])
            }
        }
        .padding(6)
        .background(Capsule().fill(.black.opacity(0.18)))
        .overlay(Capsule().strokeBorder(Theme.parchment.opacity(0.08), lineWidth: 0.7))
        .opacity(hovering ? 1 : 0.62)
        .onHover { hovering = $0 }
        .animation(.easeInOut(duration: 0.2), value: hovering)
    }
}

private struct FXPainter {
    var context: GraphicsContext
    let size: CGSize
    let effect: StageEffect
    let palette: CharacterPalette
    let level: Double
    let time: TimeInterval
    let elapsed: TimeInterval
    let reduceMotion: Bool

    private var unit: CGFloat { min(size.width, size.height) }
    private var strength: CGFloat { CGFloat(0.7 + 0.3 * max(0, min(1, level))) }
    private var seed: UInt64 {
        effect.rawValue.utf8.reduce(1) { $0 &* 31 &+ UInt64($1) }
    }

    mutating func draw() {
        switch effect {
        case .rain: rain(count: 130, speed: 0.55, slant: 0.12, alpha: 0.22)
        case .storm:
            rain(count: 200, speed: 0.9, slant: 0.22, alpha: 0.26)
            bolt()
        case .snow: snow()
        case .fog: fog()
        case .embers: embers()
        case .sparkle: sparkle()
        case .wind: wind()
        }
    }

    // MARK: - Rain

    private mutating func rain(count: Int, speed: Double, slant: CGFloat, alpha: Double) {
        var path = Path()
        let lines = Int(Double(count) * Double(strength))
        for i in 0..<lines {
            let base = random(i, 1)
            let phase = random(i, 2)
            let length = 0.018 + random(i, 3) * 0.030
            let y = CGFloat((Double(phase) + time * speed).truncatingRemainder(dividingBy: 1.2)) - 0.1
            let x = base * size.width + y * size.height * slant
            path.move(to: CGPoint(x: x, y: y * size.height))
            path.addLine(to: CGPoint(
                x: x + slant * length * size.height,
                y: (y + length) * size.height
            ))
        }
        context.stroke(
            path,
            with: .color(palette.paper.opacity(alpha)),
            style: StrokeStyle(lineWidth: 1, lineCap: .round)
        )
    }

    // MARK: - Snow

    private mutating func snow() {
        var flakes = Path()
        let count = Int(150 * Double(strength))
        for i in 0..<count {
            let base = random(i, 1)
            let speed = 0.045 + Double(random(i, 2)) * 0.055
            let y = CGFloat((Double(random(i, 3)) + time * speed).truncatingRemainder(dividingBy: 1.1)) - 0.05
            let sway = sin(time * 0.4 + Double(random(i, 4)) * 6.28) * 0.014
            let x = base + CGFloat(sway)
            let r = (0.0014 + random(i, 5) * 0.0022) * unit
            flakes.addEllipse(in: CGRect(
                x: x * size.width - r,
                y: y * size.height - r,
                width: r * 2,
                height: r * 2
            ))
        }
        context.fill(flakes, with: .color(palette.paper.opacity(0.78)))
    }

    // MARK: - Fog

    private mutating func fog() {
        for band in 0..<4 {
            let y = 0.50 + CGFloat(band) * 0.11
            let drift = CGFloat(sin(time * 0.05 + Double(band) * 1.7)) * 0.05
            for puff in 0..<5 {
                let x = drift + CGFloat(puff) * 0.24 - 0.14
                    + CGFloat(random(band * 5 + puff, 1)) * 0.08
                let rect = CGRect(
                    x: x * size.width,
                    y: y * size.height,
                    width: 0.38 * size.width,
                    height: 0.085 * size.height
                )
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(palette.paper.opacity(0.045 + Double(band) * 0.008))
                )
            }
        }
    }

    // MARK: - Embers

    private mutating func embers() {
        var warm = Path()
        var bright = Path()
        let count = Int(85 * Double(strength))
        for i in 0..<count {
            let base = random(i, 1)
            let speed = 0.035 + Double(random(i, 2)) * 0.045
            let y = 1.06 - CGFloat((Double(random(i, 3)) + time * speed).truncatingRemainder(dividingBy: 1.12))
            let sway = sin(time * 0.9 + Double(random(i, 4)) * 6.28) * 0.022
            let x = base + CGFloat(sway)
            let r = (0.0012 + random(i, 5) * 0.0020) * unit
            let dot = CGRect(x: x * size.width - r, y: y * size.height - r, width: r * 2, height: r * 2)
            if i % 3 == 0 {
                bright.addEllipse(in: dot.insetBy(dx: -r * 0.6, dy: -r * 0.6))
            } else {
                warm.addEllipse(in: dot)
            }
        }
        context.fill(warm, with: .color(Color(hex: 0xE8913F).opacity(0.55)))
        context.fill(bright, with: .color(Color(hex: 0xFFC061).opacity(0.85)))
    }

    // MARK: - Sparkle

    private mutating func sparkle() {
        var stars = Path()
        let count = Int(65 * Double(strength))
        for i in 0..<count {
            let x = random(i, 1) * 0.96 + 0.02
            let y = random(i, 2) * 0.78 + 0.06
            let sway = CGFloat(sin(time * 0.5 + Double(random(i, 3)) * 6.28)) * 0.012
            let radius = (0.004 + random(i, 4) * 0.007) * unit
            let center = CGPoint(x: (x + sway) * size.width, y: y * size.height)
            stars.move(to: CGPoint(x: center.x - radius, y: center.y))
            stars.addLine(to: CGPoint(x: center.x + radius, y: center.y))
            stars.move(to: CGPoint(x: center.x, y: center.y - radius))
            stars.addLine(to: CGPoint(x: center.x, y: center.y + radius))
        }
        context.stroke(
            stars,
            with: .color(palette.accent.opacity(0.72)),
            style: StrokeStyle(lineWidth: 1, lineCap: .round)
        )
    }

    // MARK: - Wind

    private mutating func wind() {
        var gust = Path()
        let count = Int(14 * Double(strength))
        for i in 0..<count {
            let y = 0.14 + random(i, 1) * 0.72
            let offset = CGFloat((time * 0.16 + Double(i) * 0.19).truncatingRemainder(dividingBy: 1.5)) - 0.25
            let lift = (random(i, 2) - 0.5) * 0.012
            gust.move(to: CGPoint(x: offset * size.width, y: y * size.height))
            gust.addQuadCurve(
                to: CGPoint(x: (offset + 0.24) * size.width, y: (y + lift) * size.height),
                control: CGPoint(x: (offset + 0.12) * size.width, y: (y - 0.026) * size.height)
            )
        }
        context.stroke(
            gust,
            with: .color(palette.paper.opacity(0.14)),
            style: StrokeStyle(lineWidth: 1, lineCap: .round)
        )
    }

    // MARK: - Lightning

    static func flash(at elapsed: TimeInterval) -> Double {
        guard elapsed > 0.5 else { return 0 }
        let phase = (elapsed - 0.5).truncatingRemainder(dividingBy: 6.5)
        if phase < 0.07 { return 0.30 }
        if phase > 0.13, phase < 0.19 { return 0.13 }
        return 0
    }

    private mutating func bolt() {
        guard !reduceMotion, Self.flash(at: elapsed) > 0 else { return }
        let cycle = Int((elapsed - 0.5) / 6.5)
        var x = random(cycle, 21)
        var y: CGFloat = -0.03
        var path = Path()
        path.move(to: CGPoint(x: x * size.width, y: y * size.height))
        for step in 0..<7 {
            x += (random(cycle * 7 + step, 22) - 0.5) * 0.06
            y += 0.07 + random(cycle * 7 + step, 23) * 0.035
            path.addLine(to: CGPoint(x: x * size.width, y: y * size.height))
        }
        context.stroke(
            path,
            with: .color(.white.opacity(0.35)),
            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
        )
        context.stroke(
            path,
            with: .color(.white.opacity(0.9)),
            style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
        )
    }

    /// Deterministic layout: same stage, same launch, no `hashValue`.
    private func random(_ index: Int, _ salt: Int) -> CGFloat {
        var x = UInt64(truncatingIfNeeded: index &* 374_761_393 &+ salt &* 668_265_263)
        x &+= seed &* 2_246_822_519
        x = (x ^ (x >> 13)) &* 1_274_126_177
        return CGFloat((x ^ (x >> 16)) % 10_000) / 10_000
    }
}
