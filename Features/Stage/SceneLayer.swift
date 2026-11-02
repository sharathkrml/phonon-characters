import SwiftUI

/// The scenery behind a character: a low-contrast backdrop, one prop, drifting motes and a
/// couple of wind strokes. Everything is ink geometry, seeded per character, so the stage is
/// never quite still even when the character is.
struct SceneLayer: View {
    let scene: CharacterScene
    let palette: CharacterPalette
    let level: CGFloat
    let time: TimeInterval
    let reduceMotion: Bool

    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            var c = context
            c.translateBy(x: (size.width - s) / 2, y: (size.height - s) / 2)
            var painter = ScenePainter(
                c: c,
                s: s,
                scene: scene,
                palette: palette,
                level: level,
                time: reduceMotion ? 0 : time
            )
            painter.draw()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ScenePainter {
    var c: GraphicsContext
    let s: CGFloat
    let scene: CharacterScene
    let palette: CharacterPalette
    let level: CGFloat
    let time: TimeInterval

    private var ink: Color { palette.ink }
    private var accent: Color { palette.accent }
    private var breeze: CGFloat { scene.breeze * (1 + level * 0.9) }
    private var sway: CGFloat { CGFloat(sin(time * 1.2)) * 0.010 * breeze }

    private var side: CGFloat { scene.seed % 2 == 0 ? -1 : 1 }
    private var px: CGFloat { 0.5 + side * 0.35 }

    private func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x * s, y: y * s)
    }

    private mutating func stroke(_ path: Path, alpha: Double, width: CGFloat = 0.0022) {
        c.stroke(
            path,
            with: .color(ink.opacity(min(0.55, alpha * 1.6))),
            style: StrokeStyle(lineWidth: max(1, width * s), lineCap: .round, lineJoin: .round)
        )
    }

    /// Deterministic layout without `hashValue`, which changes between launches.
    private func random(_ index: Int, _ salt: Int) -> CGFloat {
        var x = UInt64(truncatingIfNeeded: index &* 374_761_393 &+ salt &* 668_265_263 &+ scene.seed &* 2_246_822_519)
        x = (x ^ (x >> 13)) &* 1_274_126_177
        return CGFloat((x ^ (x >> 16)) % 10_000) / 10_000
    }

    mutating func draw() {
        backdrop()
        motes()
        prop()
        wind()
    }

    // MARK: - Backdrop

    private mutating func backdrop() {
        switch scene.backdrop {
        case .sea: sea()
        case .forest: forest()
        case .hills: hills()
        case .inferno: inferno()
        case .void: voidField()
        case .cave: cave()
        case .tower: tower()
        case .ice: ice()
        case .field: field()
        case .garden: garden()
        }
    }

    private mutating func sea() {
        let horizon: CGFloat = 0.70
        var line = Path()
        line.move(to: point(-0.05, horizon))
        line.addLine(to: point(1.05, horizon))
        stroke(line, alpha: 0.16, width: 0.0024)

        for row in 0..<3 {
            let y = horizon + 0.035 + CGFloat(row) * 0.045
            var wave = Path()
            wave.move(to: point(-0.05, y))
            var x: CGFloat = -0.05
            while x < 1.05 {
                wave.addQuadCurve(to: point(x + 0.10, y), control: point(x + 0.05, y - 0.012))
                x += 0.10
            }
            stroke(wave, alpha: 0.10 - Double(row) * 0.02, width: 0.0018)
        }
    }

    private mutating func forest() {
        for i in 0..<7 {
            let x = 0.08 + CGFloat(i) * 0.14
            let top = 0.48 + CGFloat((i * 7 + scene.seed) % 5) * 0.03
            var trunk = Path()
            trunk.move(to: point(x, 0.78))
            trunk.addLine(to: point(x, top))
            stroke(trunk, alpha: 0.08, width: 0.0016)

            let canopy = Path(ellipseIn: CGRect(
                x: (x - 0.07) * s, y: top * s, width: 0.14 * s, height: 0.12 * s
            ))
            c.fill(canopy, with: .color(ink.opacity(0.085)))
        }
        var floorLine = Path()
        floorLine.move(to: point(-0.05, 0.80))
        floorLine.addLine(to: point(1.05, 0.80))
        stroke(floorLine, alpha: 0.10)
    }

    private mutating func hills() {
        for (i, lift) in [CGFloat(0), 0.06].enumerated() {
            var path = Path()
            path.move(to: point(-0.05, 0.78))
            path.addQuadCurve(to: point(0.55, 0.72 - lift), control: point(0.20, 0.58 - lift))
            path.addQuadCurve(to: point(1.05, 0.78), control: point(0.85, 0.60 - lift))
            path.addLine(to: point(1.05, 0.92))
            path.addLine(to: point(-0.05, 0.92))
            path.closeSubpath()
            c.fill(path, with: .color(ink.opacity(i == 0 ? 0.05 : 0.04)))
        }
    }

    private mutating func inferno() {
        let glow = Path(ellipseIn: CGRect(x: 0.18 * s, y: 0.40 * s, width: 0.64 * s, height: 0.50 * s))
        c.fill(glow, with: .radialGradient(
            Gradient(colors: [accent.opacity(0.306), .clear]),
            center: point(0.5, 0.68),
            startRadius: 0,
            endRadius: s * 0.32
        ))

        var ridge = Path()
        ridge.move(to: point(-0.05, 0.78))
        for i in 0...8 {
            let x = CGFloat(i) / 8 * 1.1 - 0.05
            let y = 0.74 + CGFloat((i * 3 + scene.seed) % 3) * 0.018
            ridge.addLine(to: point(x, y))
        }
        ridge.addLine(to: point(1.05, 0.95))
        ridge.addLine(to: point(-0.05, 0.95))
        ridge.closeSubpath()
        c.fill(ridge, with: .color(ink.opacity(0.119)))

        for i in 0..<3 {
            let x = 0.30 + CGFloat(i) * 0.18
            var heat = Path()
            heat.move(to: point(x, 0.80))
            heat.addQuadCurve(to: point(x + 0.02, 0.56), control: point(x - 0.04, 0.68))
            stroke(heat, alpha: 0.08, width: 0.0016)
        }
    }

    private mutating func voidField() {
        for i in 0..<3 {
            let inset = 0.10 + CGFloat(i) * 0.09
            let ring = Path(ellipseIn: CGRect(
                x: (0.08 + inset) * s,
                y: (0.56 + inset * 0.5) * s,
                width: (0.84 - inset * 2) * s,
                height: (0.20 - inset) * s
            ))
            stroke(ring, alpha: 0.05, width: 0.0016)
        }
        var floorLine = Path()
        floorLine.move(to: point(0.18, 0.80))
        floorLine.addLine(to: point(0.82, 0.80))
        stroke(floorLine, alpha: 0.08)
    }

    private mutating func cave() {
        var mouth = Path()
        mouth.move(to: point(-0.05, 0.86))
        mouth.addQuadCurve(to: point(0.5, 0.20), control: point(0.05, 0.30))
        mouth.addQuadCurve(to: point(1.05, 0.86), control: point(0.95, 0.30))
        stroke(mouth, alpha: 0.10, width: 0.0022)

        for i in 0..<5 {
            let x = 0.16 + CGFloat(i) * 0.17
            let drop = 0.06 + CGFloat((i * 5 + scene.seed) % 4) * 0.02
            var tooth = Path()
            tooth.move(to: point(x - 0.025, 0.02))
            tooth.addLine(to: point(x, drop))
            tooth.addLine(to: point(x + 0.025, 0.02))
            tooth.closeSubpath()
            c.fill(tooth, with: .color(ink.opacity(0.119)))
        }

        var floorLine = Path()
        floorLine.move(to: point(-0.05, 0.84))
        floorLine.addLine(to: point(1.05, 0.84))
        stroke(floorLine, alpha: 0.09)
    }

    private mutating func tower() {
        for side in [-1.0, 1.0] as [CGFloat] {
            let x = 0.5 + side * 0.30
            var arch = Path()
            arch.move(to: point(x - 0.055, 0.70))
            arch.addLine(to: point(x - 0.055, 0.34))
            arch.addQuadCurve(to: point(x + 0.055, 0.34), control: point(x, 0.20))
            arch.addLine(to: point(x + 0.055, 0.70))
            stroke(arch, alpha: 0.09, width: 0.0018)
        }
        var floorLine = Path()
        floorLine.move(to: point(-0.05, 0.80))
        floorLine.addLine(to: point(1.05, 0.80))
        stroke(floorLine, alpha: 0.10)
    }

    private mutating func ice() {
        for i in 0..<5 {
            let x = 0.06 + CGFloat(i) * 0.21
            let peak = 0.50 + CGFloat((i * 4 + scene.seed) % 4) * 0.035
            var spire = Path()
            spire.move(to: point(x - 0.06, 0.80))
            spire.addLine(to: point(x, peak))
            spire.addLine(to: point(x + 0.06, 0.80))
            spire.closeSubpath()
            c.fill(spire, with: .color(accent.opacity(0.17)))
            stroke(spire, alpha: 0.10, width: 0.0016)
        }
        var floorLine = Path()
        floorLine.move(to: point(-0.05, 0.80))
        floorLine.addLine(to: point(1.05, 0.80))
        stroke(floorLine, alpha: 0.10)
    }

    private mutating func field() {
        var ridge = Path()
        ridge.move(to: point(-0.05, 0.78))
        ridge.addQuadCurve(to: point(0.5, 0.74), control: point(0.24, 0.70))
        ridge.addQuadCurve(to: point(1.05, 0.78), control: point(0.78, 0.71))
        stroke(ridge, alpha: 0.10)

        for i in 0..<12 {
            let x = 0.04 + CGFloat(i) * 0.082
            let lift = CGFloat((i * 3 + scene.seed) % 3) * 0.012
            var tuft = Path()
            tuft.move(to: point(x, 0.86))
            tuft.addQuadCurve(to: point(x + 0.008, 0.82 - lift), control: point(x - 0.008, 0.84))
            stroke(tuft, alpha: 0.08, width: 0.0014)
        }
    }

    private mutating func garden() {
        var hedge = Path()
        hedge.move(to: point(-0.05, 0.80))
        var x: CGFloat = -0.05
        while x < 1.05 {
            hedge.addQuadCurve(to: point(x + 0.12, 0.80), control: point(x + 0.06, 0.74))
            x += 0.12
        }
        stroke(hedge, alpha: 0.10)

        for i in 0..<6 {
            let roseX = 0.12 + CGFloat(i) * 0.15
            let roseY = 0.74 + CGFloat((i * 7 + scene.seed) % 3) * 0.014
            let rose = Path(ellipseIn: CGRect(
                x: (roseX - 0.008) * s, y: roseY * s, width: 0.016 * s, height: 0.016 * s
            ))
            c.fill(rose, with: .color(accent.opacity(0.374)))
        }
    }

    // MARK: - Prop

    private mutating func prop() {
        switch scene.prop {
        case .mast: mast()
        case .rocks: rocks()
        case .yew: yew()
        case .spire: spire()
        case .tree: tree()
        case .bulb: bulb()
        case .stalagmites: stalagmites()
        case .mushrooms: mushrooms()
        case .shelf: shelf()
        case .icicles: icicles()
        case .banner: banner()
        case .arch: arch()
        }
    }

    private mutating func mast() {
        let top: CGFloat = 0.26
        var pole = Path()
        pole.move(to: point(px, 0.88))
        pole.addLine(to: point(px, top))
        stroke(pole, alpha: 0.16, width: 0.0026)

        var yard = Path()
        yard.move(to: point(px - 0.11, top + 0.10))
        yard.addLine(to: point(px + 0.11, top + 0.10))
        stroke(yard, alpha: 0.14, width: 0.0020)

        var sail = Path()
        sail.move(to: point(px - 0.10, top + 0.11))
        sail.addQuadCurve(to: point(px + 0.10, top + 0.11), control: point(px + 0.02, top + 0.20))
        sail.addQuadCurve(to: point(px - 0.10, top + 0.11), control: point(px - 0.02, top + 0.24))
        c.fill(sail, with: .color(palette.paper.opacity(0.55)))
        stroke(sail, alpha: 0.10, width: 0.0016)

        var rig = Path()
        rig.move(to: point(px, top))
        rig.addLine(to: point(px - 0.16, 0.84))
        rig.move(to: point(px, top))
        rig.addLine(to: point(px + 0.16, 0.84))
        stroke(rig, alpha: 0.08, width: 0.0014)
    }

    private mutating func rocks() {
        for (i, width) in [CGFloat(0.13), 0.09].enumerated() {
            let x = px + (i == 0 ? -0.03 : 0.06)
            let y: CGFloat = i == 0 ? 0.72 : 0.76
            var rock = Path()
            rock.move(to: point(x - width, y))
            rock.addQuadCurve(to: point(x + width, y), control: point(x + width * 0.2, y - width * 1.3))
            rock.closeSubpath()
            c.fill(rock, with: .color(ink.opacity(0.136)))
            stroke(rock, alpha: 0.10, width: 0.0018)
        }
    }

    private mutating func yew() {
        var trunk = Path()
        trunk.move(to: point(px, 0.80))
        trunk.addLine(to: point(px, 0.42))
        stroke(trunk, alpha: 0.14, width: 0.0022)

        for i in 0..<4 {
            let dx = (CGFloat(i) - 1.5) * 0.035 + sway
            let dy = 0.36 + CGFloat(i % 2) * 0.03
            let canopy = Path(ellipseIn: CGRect(
                x: (px + dx - 0.055) * s, y: dy * s, width: 0.11 * s, height: 0.09 * s
            ))
            c.fill(canopy, with: .color(ink.opacity(0.119)))
        }

        for i in 0..<3 {
            let x = px - 0.05 + CGFloat(i) * 0.05
            var strand = Path()
            strand.move(to: point(x, 0.38))
            strand.addQuadCurve(to: point(x + 0.01, 0.50), control: point(x + 0.02 + sway, 0.44))
            stroke(strand, alpha: 0.07, width: 0.0012)
        }
    }

    private mutating func spire() {
        for i in 0..<2 {
            let x = px + CGFloat(i) * 0.07
            let peak: CGFloat = 0.14 + CGFloat(i) * 0.08
            var shard = Path()
            shard.move(to: point(x - 0.035, 0.80))
            shard.addLine(to: point(x, peak))
            shard.addLine(to: point(x + 0.035, 0.80))
            shard.closeSubpath()
            c.fill(shard, with: .color(ink.opacity(0.17)))
            stroke(shard, alpha: 0.12, width: 0.0016)
        }
    }

    private mutating func tree() {
        var trunk = Path()
        trunk.move(to: point(px - 0.012, 0.80))
        trunk.addLine(to: point(px - 0.008, 0.42))
        trunk.move(to: point(px + 0.012, 0.80))
        trunk.addLine(to: point(px + 0.008, 0.42))
        stroke(trunk, alpha: 0.14, width: 0.0022)

        var branch = Path()
        branch.move(to: point(px, 0.52))
        branch.addLine(to: point(px + 0.05, 0.40))
        stroke(branch, alpha: 0.10, width: 0.0016)

        for i in 0..<3 {
            let dx = (CGFloat(i) - 1) * 0.055 + sway
            let dy: CGFloat = 0.28 + (i == 1 ? 0.02 : 0)
            let canopy = Path(ellipseIn: CGRect(
                x: (px + dx - 0.07) * s, y: dy * s, width: 0.14 * s, height: 0.12 * s
            ))
            c.fill(canopy, with: .color(accent.opacity(0.17)))
        }
    }

    private mutating func bulb() {
        let swing = sway * 2
        var cord = Path()
        cord.move(to: point(px, 0.02))
        cord.addQuadCurve(to: point(px + swing, 0.26), control: point(px + swing * 0.4, 0.14))
        stroke(cord, alpha: 0.12, width: 0.0016)

        let glow = Path(ellipseIn: CGRect(
            x: (px + swing - 0.07) * s, y: 0.20 * s, width: 0.14 * s, height: 0.14 * s
        ))
        c.fill(glow, with: .radialGradient(
            Gradient(colors: [accent.opacity(0.306), .clear]),
            center: point(px + swing, 0.27),
            startRadius: 0,
            endRadius: s * 0.08
        ))

        let glass = Path(ellipseIn: CGRect(
            x: (px + swing - 0.022) * s, y: 0.25 * s, width: 0.044 * s, height: 0.055 * s
        ))
        c.fill(glass, with: .color(palette.paper.opacity(0.9)))
        stroke(glass, alpha: 0.16, width: 0.0018)
    }

    private mutating func stalagmites() {
        for i in 0..<3 {
            let x = px + (CGFloat(i) - 1) * 0.05
            let peak: CGFloat = 0.34 + CGFloat(i % 2) * 0.08
            var tooth = Path()
            tooth.move(to: point(x - 0.032, 0.80))
            tooth.addLine(to: point(x, peak))
            tooth.addLine(to: point(x + 0.032, 0.80))
            tooth.closeSubpath()
            c.fill(tooth, with: .color(ink.opacity(0.153)))
            stroke(tooth, alpha: 0.10, width: 0.0014)
        }
    }

    private mutating func mushrooms() {
        for i in 0..<2 {
            let x = px + (CGFloat(i) - 0.5) * 0.07
            let y: CGFloat = 0.72 - CGFloat(i) * 0.03
            var stem = Path()
            stem.move(to: point(x, y))
            stem.addLine(to: point(x, y - 0.09))
            stroke(stem, alpha: 0.12, width: 0.0018)

            var cap = Path()
            cap.move(to: point(x - 0.04, y - 0.09))
            cap.addQuadCurve(to: point(x + 0.04, y - 0.09), control: point(x, y - 0.16))
            cap.closeSubpath()
            c.fill(cap, with: .color(accent.opacity(0.34)))
            stroke(cap, alpha: 0.12, width: 0.0014)
        }
    }

    private mutating func shelf() {
        var board = Path()
        board.move(to: point(px - 0.11, 0.54))
        board.addLine(to: point(px + 0.11, 0.54))
        board.move(to: point(px - 0.11, 0.42))
        board.addLine(to: point(px + 0.11, 0.42))
        stroke(board, alpha: 0.14, width: 0.0022)

        for i in 0..<7 {
            let x = px - 0.095 + CGFloat(i) * 0.027
            let height = 0.06 + CGFloat((i * 3 + scene.seed) % 4) * 0.012
            var book = Path()
            book.move(to: point(x, 0.535))
            book.addLine(to: point(x, 0.535 - height))
            book.addLine(to: point(x + 0.018, 0.535 - height))
            book.addLine(to: point(x + 0.018, 0.535))
            c.fill(book, with: .color(ink.opacity(i % 3 == 0 ? 0.10 : 0.06)))
            stroke(book, alpha: 0.08, width: 0.0012)
        }
    }

    private mutating func icicles() {
        for i in 0..<4 {
            let x = px + (CGFloat(i) - 1.5) * 0.045
            let drop = 0.16 + CGFloat((i * 3 + scene.seed) % 4) * 0.03
            var icicle = Path()
            icicle.move(to: point(x - 0.014, 0.02))
            icicle.addLine(to: point(x, drop))
            icicle.addLine(to: point(x + 0.014, 0.02))
            icicle.closeSubpath()
            c.fill(icicle, with: .color(accent.opacity(0.374)))
            stroke(icicle, alpha: 0.14, width: 0.0014)
        }
    }

    private mutating func banner() {
        var pole = Path()
        pole.move(to: point(px, 0.80))
        pole.addLine(to: point(px, 0.18))
        stroke(pole, alpha: 0.14, width: 0.0022)

        var arm = Path()
        arm.move(to: point(px - 0.10, 0.21))
        arm.addLine(to: point(px + 0.03, 0.21))
        stroke(arm, alpha: 0.12, width: 0.0018)

        let flap = sway * 2
        var cloth = Path()
        cloth.move(to: point(px - 0.10, 0.21))
        cloth.addQuadCurve(to: point(px - 0.07 + flap, 0.46), control: point(px - 0.14 + flap, 0.34))
        cloth.addLine(to: point(px - 0.03 + flap, 0.40))
        cloth.addLine(to: point(px + 0.02 + flap, 0.44))
        cloth.addLine(to: point(px + 0.03, 0.21))
        cloth.closeSubpath()
        c.fill(cloth, with: .color(accent.opacity(0.272)))
        stroke(cloth, alpha: 0.12, width: 0.0016)

        let charge = Path(ellipseIn: CGRect(
            x: (px - 0.045 + flap * 0.5) * s, y: 0.27 * s, width: 0.028 * s, height: 0.028 * s
        ))
        c.fill(charge, with: .color(palette.paper.opacity(0.8)))
        stroke(charge, alpha: 0.14, width: 0.0012)
    }

    private mutating func arch() {
        var curve = Path()
        curve.addArc(
            center: point(px, 0.50),
            radius: 0.13 * s,
            startAngle: .degrees(180),
            endAngle: .degrees(360),
            clockwise: false
        )
        stroke(curve, alpha: 0.14, width: 0.0026)

        var left = Path()
        left.move(to: point(px - 0.13, 0.50))
        left.addLine(to: point(px - 0.13, 0.80))
        var right = Path()
        right.move(to: point(px + 0.13, 0.50))
        right.addLine(to: point(px + 0.13, 0.80))
        stroke(left, alpha: 0.12, width: 0.0022)
        stroke(right, alpha: 0.12, width: 0.0022)

        for i in 0..<8 {
            let angle = CGFloat(i) / 8 * .pi
            let x = px - cos(angle) * 0.13 + sway
            let y = 0.50 - sin(angle) * 0.13
            let leaf = Path(ellipseIn: CGRect(
                x: (x - 0.009) * s, y: (y - 0.009) * s, width: 0.018 * s, height: 0.018 * s
            ))
            c.fill(leaf, with: .color(accent.opacity(0.306)))
        }
    }

    // MARK: - Motes

    private var rising: Bool {
        switch scene.motes {
        case .spray, .bubbles, .embers, .sparks: true
        default: false
        }
    }

    private mutating func motes() {
        for i in 0..<30 {
            let baseX = random(i, 1)
            let phase = random(i, 2) * 6.283
            let speed = 0.03 + random(i, 3) * 0.05
            let drift = 0.006 + random(i, 4) * 0.012
            let x = baseX + CGFloat(sin(time * 0.6 + Double(phase))) * drift * breeze
            let progress = random(i, 5) + CGFloat(time) * speed * (rising ? -1 : 1)
            let y = 0.02 + (progress - floor(progress)) * 0.76
            drawMote(at: CGPoint(x: x, y: y), phase: phase)
        }
    }

    private mutating func drawMote(at p: CGPoint, phase: CGFloat) {
        switch scene.motes {
        case .leaves:
            let leaf = Path(ellipseIn: CGRect(
                x: (p.x - 0.009) * s, y: (p.y - 0.005) * s, width: 0.018 * s, height: 0.010 * s
            ))
            c.fill(leaf, with: .color(accent.opacity(0.595)))

        case .snow:
            let dot = Path(ellipseIn: CGRect(
                x: (p.x - 0.0045) * s, y: (p.y - 0.0045) * s, width: 0.009 * s, height: 0.009 * s
            ))
            c.fill(dot, with: .color(palette.paper.opacity(0.9)))
            c.stroke(dot, with: .color(accent.opacity(0.85)), lineWidth: 0.8)

        case .embers, .sparks:
            let dot = Path(ellipseIn: CGRect(
                x: (p.x - 0.0035) * s, y: (p.y - 0.0035) * s, width: 0.007 * s, height: 0.007 * s
            ))
            c.fill(dot, with: .color(accent.opacity(0.85)))

        case .spray, .bubbles:
            let dot = Path(ellipseIn: CGRect(
                x: (p.x - 0.004) * s, y: (p.y - 0.004) * s, width: 0.008 * s, height: 0.008 * s
            ))
            c.stroke(dot, with: .color(accent.opacity(0.595)), lineWidth: 1)

        case .fireflies:
            let pulse = 0.35 + 0.35 * (0.5 + 0.5 * sin(time * 2 + Double(phase)))
            let glow = Path(ellipseIn: CGRect(
                x: (p.x - 0.012) * s, y: (p.y - 0.012) * s, width: 0.024 * s, height: 0.024 * s
            ))
            c.fill(glow, with: .color(accent.opacity(0.18 * pulse)))
            let dot = Path(ellipseIn: CGRect(
                x: (p.x - 0.003) * s, y: (p.y - 0.003) * s, width: 0.006 * s, height: 0.006 * s
            ))
            c.fill(dot, with: .color(accent.opacity(pulse)))

        case .dust, .ash, .pollen:
            let dot = Path(ellipseIn: CGRect(
                x: (p.x - 0.003) * s, y: (p.y - 0.003) * s, width: 0.006 * s, height: 0.006 * s
            ))
            c.fill(dot, with: .color(ink.opacity(0.272)))

        case .sparkles:
            let size: CGFloat = 0.010
            var star = Path()
            star.move(to: CGPoint(x: (p.x - size) * s, y: p.y * s))
            star.addLine(to: CGPoint(x: (p.x + size) * s, y: p.y * s))
            star.move(to: CGPoint(x: p.x * s, y: (p.y - size) * s))
            star.addLine(to: CGPoint(x: p.x * s, y: (p.y + size) * s))
            let pulse = 0.35 + 0.35 * (0.5 + 0.5 * sin(time * 1.6 + Double(phase)))
            c.stroke(star, with: .color(accent.opacity(pulse)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }
    }

    // MARK: - Wind

    private mutating func wind() {
        guard scene.breeze > 0.3 else { return }
        for i in 0..<3 {
            let y = 0.24 + CGFloat(i) * 0.18
            let offset = (CGFloat(time) * 0.02 + CGFloat(i) * 0.37)
                .truncatingRemainder(dividingBy: 1.4) - 0.2
            var gust = Path()
            gust.move(to: point(offset, y))
            gust.addQuadCurve(to: point(offset + 0.18, y - 0.006), control: point(offset + 0.09, y - 0.022))
            stroke(gust, alpha: 0.09 * Double(scene.breeze), width: 0.0016)
        }
    }
}
