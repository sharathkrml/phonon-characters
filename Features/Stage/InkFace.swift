import SwiftUI

/// A character drawn from ink paths instead of a photograph. Every feature is geometry, so
/// the mouth can follow the words: no pasted-on lips, no photo mouth that never matches.
struct InkFace: View {
    let look: CharacterLook
    let palette: CharacterPalette
    let mouth: MouthShape
    let level: CGFloat
    let listening: Bool
    let time: TimeInterval
    let reduceMotion: Bool
    let breeze: CGFloat

    private var seed: Int { abs(look.hashValue % 24) }

    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let breathe = reduceMotion || listening ? 0 : sin(time * 0.85) * 0.006
            let sway = reduceMotion || listening ? 0 : sin(time * 0.45) * 0.55
            let gust = reduceMotion ? 0 : CGFloat(sin(time * 1.35)) * 0.006 * breeze
            let blinkPeriod = 4.4 + Double(seed) / 12
            let blink = !reduceMotion && time.truncatingRemainder(dividingBy: blinkPeriod) < 0.12

            var c = context
            let origin = CGPoint(x: (size.width - s) / 2, y: (size.height - s) / 2)
            c.translateBy(x: origin.x + s / 2, y: origin.y + s)
            c.rotate(by: .degrees(sway))
            let scale = 1 + level * 0.014 + breathe
            c.scaleBy(x: scale, y: scale)
            c.translateBy(x: -s / 2, y: -s)

            var painter = InkPainter(
                c: c,
                s: s,
                look: look,
                palette: palette,
                mouth: mouth,
                level: level,
                listening: listening,
                blinking: blink,
                seed: seed,
                gust: gust
            )
            painter.draw()
        }
    }
}

// MARK: - The drawing

private struct InkPainter {
    var c: GraphicsContext
    let s: CGFloat
    let look: CharacterLook
    let palette: CharacterPalette
    let mouth: MouthShape
    let level: CGFloat
    let listening: Bool
    let blinking: Bool
    let seed: Int
    let gust: CGFloat

    // Normalized layout: the head sits high, the bust fills the bottom edge.
    private var cx: CGFloat { 0.5 }
    private var cy: CGFloat { 0.43 }

    private var headWidth: CGFloat {
        switch look.head {
        case .oval, .heavy: 0.205
        case .long: 0.175
        case .round: 0.225
        case .wide: 0.245
        case .blob: 0.235
        }
    }

    private var headHeight: CGFloat {
        switch look.head {
        case .oval: 0.25
        case .long: 0.285
        case .round: 0.22
        case .heavy: 0.24
        case .wide: 0.225
        case .blob: 0.185
        }
    }

    private var jaw: CGFloat {
        switch look.head {
        case .heavy: 1.14
        case .wide: 1.10
        case .long: 0.90
        case .blob: 1.04
        default: 1.0
        }
    }

    var rx: CGFloat { headWidth }
    var ry: CGFloat { headHeight }

    private var eyeY: CGFloat { cy - ry * 0.10 }
    private var eyeDX: CGFloat { rx * 0.40 }
    private var mouthY: CGFloat { cy + ry * 0.56 }

    private var ink: Color { palette.ink }
    private var paper: Color { palette.paper }

    private func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x * s, y: y * s)
    }

    private func len(_ v: CGFloat) -> CGFloat { v * s }

    private var strokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: max(1.1, len(0.0026)), lineCap: .round, lineJoin: .round)
    }

    // MARK: Order

    mutating func draw() {
        shoulders()
        hairBack()
        head()
        ears()
        beardMass()
        hairFront()
        face()
        mouthShape()
        facialHairFront()
        accessoryBack()
        accessoryFront()
    }

    // MARK: Body

    private var shoulderX: CGFloat {
        switch look.shoulders {
        case .broad: 0.29
        case .narrow: 0.38
        case .hunched: 0.25
        }
    }

    private var shoulderY: CGFloat {
        switch look.shoulders {
        case .broad: 0.72
        case .narrow: 0.77
        case .hunched: 0.65
        }
    }

    mutating func shoulders() {
        var torso = Path()
        torso.move(to: pt(0.02, 1.02))
        torso.addCurve(
            to: pt(shoulderX, shoulderY),
            control1: pt(0.04, shoulderY + 0.12),
            control2: pt(shoulderX - 0.11, shoulderY + 0.01)
        )
        torso.addCurve(
            to: pt(0.44, shoulderY - 0.045),
            control1: pt(shoulderX + 0.04, shoulderY - 0.02),
            control2: pt(0.40, shoulderY - 0.035)
        )
        torso.addLine(to: pt(0.56, shoulderY - 0.045))
        torso.addCurve(
            to: pt(1 - shoulderX, shoulderY),
            control1: pt(0.60, shoulderY - 0.035),
            control2: pt(0.96 - shoulderX, shoulderY - 0.02)
        )
        torso.addCurve(
            to: pt(0.98, 1.02),
            control1: pt(1 - shoulderX + 0.11, shoulderY + 0.01),
            control2: pt(0.96, shoulderY + 0.12)
        )
        torso.addLine(to: pt(0.98, 1.05))
        torso.addLine(to: pt(0.02, 1.05))
        torso.closeSubpath()

        c.fill(torso, with: .color(paper))
        inkLine(torso, width: max(1.4, len(0.0035)))
    }

    // MARK: Head

    private func headPath(scaleX: CGFloat = 1, scaleY: CGFloat = 1) -> Path {
        let r = rx * scaleX
        let v = ry * scaleY
        var path = Path()
        let top = pt(cx, cy - v)
        let bottom = pt(cx, cy + v)
        path.move(to: top)
        path.addCurve(
            to: pt(cx + r, cy - v * 0.12),
            control1: pt(cx + r * 0.62, cy - v),
            control2: pt(cx + r, cy - v * 0.58)
        )
        path.addCurve(
            to: pt(cx + r * jaw, cy + v * 0.62),
            control1: pt(cx + r, cy + v * 0.26),
            control2: pt(cx + r * jaw, cy + v * 0.45)
        )
        path.addCurve(
            to: bottom,
            control1: pt(cx + r * jaw * 0.85, cy + v * 0.88),
            control2: pt(cx + r * 0.45, cy + v)
        )
        path.addCurve(
            to: pt(cx - r * jaw, cy + v * 0.62),
            control1: pt(cx - r * 0.45, cy + v),
            control2: pt(cx - r * jaw * 0.85, cy + v * 0.88)
        )
        path.addCurve(
            to: pt(cx - r, cy - v * 0.12),
            control1: pt(cx - r * jaw, cy + v * 0.45),
            control2: pt(cx - r, cy + v * 0.26)
        )
        path.addCurve(
            to: top,
            control1: pt(cx - r, cy - v * 0.58),
            control2: pt(cx - r * 0.62, cy - v)
        )
        path.closeSubpath()
        return path
    }

    mutating func head() {
        if look.hair == .hood { return }
        let path = headPath()
        c.fill(path, with: .color(paper))
        inkLine(path, width: max(1.6, len(0.0038)))
    }

    mutating func ears() {
        guard look.hair != .hood, look.accessory != .horns else { return }
        for side in [-1.0, 1.0] as [CGFloat] {
            let x = cx + side * rx * 0.98
            var ear = Path()
            switch look.ears {
            case .round:
                ear.addArc(
                    center: pt(x, cy + 0.005),
                    radius: len(rx * 0.16),
                    startAngle: .degrees(side > 0 ? -75 : 105),
                    endAngle: .degrees(side > 0 ? 75 : 255),
                    clockwise: false
                )
            case .pointed, .long:
                let reach: CGFloat = look.ears == .long ? 0.30 : 0.20
                let lift: CGFloat = look.ears == .long ? 0.12 : 0.075
                ear.move(to: pt(x, cy - 0.03))
                ear.addQuadCurve(
                    to: pt(x + side * rx * reach, cy - lift),
                    control: pt(x + side * rx * 0.22, cy - lift * 0.6)
                )
                ear.addQuadCurve(
                    to: pt(x, cy + 0.06),
                    control: pt(x + side * rx * 0.15, cy + 0.05)
                )
            }
            c.fill(ear, with: .color(paper))
            inkLine(ear, width: max(1.2, len(0.0026)))
        }
    }

    // MARK: Hair

    mutating func hairBack() {
        switch look.hair {
        case .long:
            var mass = Path()
            mass.move(to: pt(cx - rx * 0.90, cy - ry * 0.70))
            mass.addCurve(
                to: pt(cx - rx * 1.24, cy + ry * 0.55),
                control1: pt(cx - rx * 1.30, cy - ry * 0.25),
                control2: pt(cx - rx * 1.34, cy + ry * 0.12)
            )
            mass.addQuadCurve(
                to: pt(cx - rx * 1.00, cy + ry * 1.30),
                control: pt(cx - rx * 1.32, cy + ry * 1.02)
            )
            mass.addQuadCurve(
                to: pt(cx - rx * 0.58, cy + ry * 1.18),
                control: pt(cx - rx * 0.84, cy + ry * 1.44)
            )
            mass.addLine(to: pt(cx + rx * 0.58, cy + ry * 1.18))
            mass.addQuadCurve(
                to: pt(cx + rx * 1.00, cy + ry * 1.30),
                control: pt(cx + rx * 0.84, cy + ry * 1.44)
            )
            mass.addQuadCurve(
                to: pt(cx + rx * 1.24, cy + ry * 0.55),
                control: pt(cx + rx * 1.32, cy + ry * 1.02)
            )
            mass.addCurve(
                to: pt(cx + rx * 0.90, cy - ry * 0.70),
                control1: pt(cx + rx * 1.34, cy + ry * 0.12),
                control2: pt(cx + rx * 1.30, cy - ry * 0.25)
            )
            mass.closeSubpath()
            c.fill(mass, with: .color(ink.opacity(0.92)))
        case .wild:
            var mass = Path()
            let points = 13
            for i in 0...points {
                let t = CGFloat(i) / CGFloat(points)
                let angle = CGFloat.pi * (0.01 + 0.98 * t)
                let length: CGFloat = i % 2 == 0 ? 1.00 : (1.06 + 0.09 * CGFloat((seed >> i) & 3))
                let x = cx - cos(angle) * rx * length
                let y = cy - sin(angle) * ry * (length - 0.04)
                if i == 0 { mass.move(to: pt(x, y)) } else { mass.addLine(to: pt(x, y)) }
            }
            mass.addLine(to: pt(cx + rx * 1.02, cy + ry * 0.60))
            mass.addLine(to: pt(cx - rx * 0.86, cy + ry * 0.72))
            mass.addLine(to: pt(cx - rx * 1.02, cy + ry * 0.60))
            mass.closeSubpath()
            c.fill(mass, with: .color(ink.opacity(0.92)))
        case .bun:
            let bun = Path(ellipseIn: CGRect(
                x: (cx + rx * 0.20 - rx * 0.30) * s,
                y: (cy - ry * 1.16) * s,
                width: rx * 0.60 * s,
                height: rx * 0.56 * s
            ))
            c.fill(bun, with: .color(ink.opacity(0.92)))
            inkLine(bun, width: max(1.2, len(0.0024)))
        default:
            break
        }
    }

    private func capPath(outset: CGFloat) -> Path {
        let r = rx * (1 + outset)
        let v = ry * (1 + outset)
        var p = Path()
        p.move(to: pt(cx - r, cy - v * 0.30))
        p.addCurve(
            to: pt(cx, cy - v),
            control1: pt(cx - r, cy - v * 0.86),
            control2: pt(cx - r * 0.60, cy - v)
        )
        p.addCurve(
            to: pt(cx + r, cy - v * 0.30),
            control1: pt(cx + r * 0.60, cy - v),
            control2: pt(cx + r, cy - v * 0.86)
        )
        p.addCurve(
            to: pt(cx, cy - v * 0.34),
            control1: pt(cx + r * 0.80, cy - v * 0.62),
            control2: pt(cx + r * 0.42, cy - v * 0.26)
        )
        p.addCurve(
            to: pt(cx - r, cy - v * 0.30),
            control1: pt(cx - r * 0.42, cy - v * 0.26),
            control2: pt(cx - r * 0.80, cy - v * 0.62)
        )
        p.closeSubpath()
        return p
    }

    mutating func hairFront() {
        switch look.hair {
        case .cap:
            let path = capPath(outset: 0.035)
            c.fill(path, with: .color(ink.opacity(0.92)))
            inkLine(path, width: max(1.2, len(0.0026)))
        case .long:
            let path = capPath(outset: 0.045)
            c.fill(path, with: .color(ink.opacity(0.92)))
            inkLine(path, width: max(1.2, len(0.0026)))
            for side in [-1.0, 1.0] as [CGFloat] {
                var strand = Path()
                strand.move(to: pt(cx + side * rx * 0.88, cy - ry * 0.45))
                strand.addQuadCurve(
                    to: pt(cx + side * rx * 1.12 + gust, cy + ry * 0.55),
                    control: pt(cx + side * rx * 1.30 + gust, cy)
                )
                inkLine(strand, width: max(1.1, len(0.0022)), alpha: 0.75)
            }
        case .wild:
            let base = capPath(outset: 0.04)
            c.fill(base, with: .color(ink.opacity(0.92)))
        case .bun:
            let path = capPath(outset: 0.03)
            c.fill(path, with: .color(ink.opacity(0.92)))
        case .bald:
            var shine = Path()
            shine.move(to: pt(cx - rx * 0.34, cy - ry * 0.78))
            shine.addQuadCurve(
                to: pt(cx + rx * 0.10, cy - ry * 0.90),
                control: pt(cx - rx * 0.12, cy - ry * 0.96)
            )
            inkLine(shine, width: max(1.0, len(0.0018)), alpha: 0.35)
        case .hood:
            hood()
        }
    }

    private mutating func hood() {
        var outer = Path()
        outer.move(to: pt(cx - rx * 1.10 + gust, 0.95))
        outer.addCurve(
            to: pt(cx - rx * 0.55 + gust, cy - ry * 0.75),
            control1: pt(cx - rx * 1.18 + gust, cy + ry * 0.30),
            control2: pt(cx - rx * 1.02 + gust, cy - ry * 0.36)
        )
        outer.addQuadCurve(
            to: pt(cx + rx * 0.55 + gust, cy - ry * 0.75),
            control: pt(cx + gust, cy - ry * 1.02)
        )
        outer.addCurve(
            to: pt(cx + rx * 1.10 + gust, 0.95),
            control1: pt(cx + rx * 1.02 + gust, cy - ry * 0.36),
            control2: pt(cx + rx * 1.18 + gust, cy + ry * 0.30)
        )
        outer.addQuadCurve(
            to: pt(cx - rx * 1.10 + gust, 0.95),
            control: pt(cx + gust, 0.88)
        )
        outer.closeSubpath()

        var opening = Path()
        opening.addEllipse(in: CGRect(
            x: (cx - rx * 0.76) * s,
            y: (cy - ry * 0.92) * s,
            width: rx * 1.52 * s,
            height: ry * 1.78 * s
        ))

        var combined = outer
        combined.addPath(opening)
        c.fill(combined, with: .color(ink.opacity(0.94)), style: FillStyle(eoFill: true))
        inkLine(outer, width: max(1.6, len(0.0036)))
    }

    // MARK: Face

    mutating func face() {
        let lift: CGFloat = listening ? -0.012 : 0
        brows(lift: lift)
        eyes()
        nose()

        // A soft blush so the paper face is not entirely flat.
        for side in [-1.0, 1.0] as [CGFloat] {
            let blush = Path(ellipseIn: CGRect(
                x: (cx + side * rx * 0.62 - rx * 0.15) * s,
                y: (cy + ry * 0.26) * s,
                width: rx * 0.30 * s,
                height: ry * 0.13 * s
            ))
            c.fill(blush, with: .color(palette.accent.opacity(0.07)))
        }
    }

    private mutating func brows(lift: CGFloat) {
        for side in [-1.0, 1.0] as [CGFloat] {
            let inner = cx + side * eyeDX * 0.45
            let outer = cx + side * (eyeDX + rx * 0.26)
            let y = eyeY - ry * 0.24 + lift
            var brow = Path()
            brow.move(to: pt(outer, y + (look.brow == .heavy ? 0.008 : 0)))
            switch look.brow {
            case .thin:
                brow.addQuadCurve(to: pt(inner, y + 0.004), control: pt(cx + side * eyeDX, y - 0.008))
                inkLine(brow, width: max(1.0, len(0.0018)), alpha: 0.9)
            case .level:
                brow.addQuadCurve(to: pt(inner, y), control: pt(cx + side * eyeDX, y - 0.004))
                inkLine(brow, width: max(1.3, len(0.0026)))
            case .heavy:
                brow.addQuadCurve(to: pt(inner, y + 0.012), control: pt(cx + side * eyeDX, y + 0.004))
                inkLine(brow, width: max(1.9, len(0.0042)))
            case .arch:
                brow.addQuadCurve(to: pt(inner, y + 0.006), control: pt(cx + side * eyeDX, y - 0.018))
                inkLine(brow, width: max(1.2, len(0.0022)))
            }
        }
    }

    private mutating func eyes() {
        for side in [-1.0, 1.0] as [CGFloat] {
            let ex = cx + side * eyeDX
            let spread: CGFloat = listening ? 1.06 : 1
            let width = rx * (look.eyes == .wide ? 0.28 : 0.25) * spread
            var height = ry * 0.085 * spread
            if look.eyes == .narrow { height *= 0.72 }

            let rect = CGRect(
                x: (ex - width) * s,
                y: (eyeY - height) * s,
                width: width * 2 * s,
                height: height * 2 * s
            )
            let opening = Path(ellipseIn: rect)

            if blinking {
                var line = Path()
                line.move(to: pt(ex - width * 0.95, eyeY))
                line.addQuadCurve(
                    to: pt(ex + width * 0.95, eyeY),
                    control: pt(ex, eyeY + height * 0.9)
                )
                inkLine(line, width: max(1.5, len(0.0028)))
                continue
            }

            if look.eyes == .hollow {
                c.fill(opening, with: .color(Color(hex: 0x0B090D)))
                let gleam = Path(ellipseIn: CGRect(
                    x: (ex - width * 0.30) * s,
                    y: (eyeY - height * 0.55) * s,
                    width: width * 0.30 * s,
                    height: height * 0.45 * s
                ))
                c.fill(gleam, with: .color(palette.accent.opacity(0.5)))
                continue
            }

            c.fill(opening, with: .color(paper))
            let radius = min(width, height) * 0.82
            c.drawLayer { layer in
                layer.clip(to: opening)
                let iris = Path(ellipseIn: CGRect(
                    x: (ex - radius) * s,
                    y: (eyeY - radius) * s,
                    width: radius * 2 * s,
                    height: radius * 2 * s
                ))
                layer.fill(iris, with: .color(ink.opacity(0.92)))

                let shine = Path(ellipseIn: CGRect(
                    x: (ex - radius * 0.55) * s,
                    y: (eyeY - radius * 0.65) * s,
                    width: radius * 0.55 * s,
                    height: radius * 0.45 * s
                ))
                layer.fill(shine, with: .color(paper.opacity(0.92)))
            }

            var lid = Path()
            lid.move(to: pt(ex - width, eyeY))
            lid.addQuadCurve(to: pt(ex + width, eyeY), control: pt(ex, eyeY - height * 2.1))
            inkLine(lid, width: max(1.4, len(0.0028)))
        }
    }

    private mutating func nose() {
        var nose = Path()
        nose.move(to: pt(cx - 0.002, eyeY + ry * 0.16))
        nose.addQuadCurve(
            to: pt(cx - 0.012, mouthY - 0.055),
            control: pt(cx - 0.020, mouthY - 0.14)
        )
        nose.addQuadCurve(
            to: pt(cx + 0.014, mouthY - 0.048),
            control: pt(cx + 0.006, mouthY - 0.036)
        )
        inkLine(nose, width: max(1.1, len(0.0022)), alpha: 0.85)
    }

    // MARK: Beard

    private var hasBeardMass: Bool {
        look.beard == .full || look.beard == .chin
    }

    private mutating func beardMass() {
        switch look.beard {
        case .full:
            var mass = Path()
            mass.move(to: pt(cx - rx * 1.02, cy - ry * 0.10))
            mass.addCurve(
                to: pt(cx - rx * 0.55, cy + ry * 0.98),
                control1: pt(cx - rx * 1.06, cy + ry * 0.55),
                control2: pt(cx - rx * 0.92, cy + ry * 0.86)
            )
            mass.addCurve(
                to: pt(cx + rx * 0.55, cy + ry * 0.98),
                control1: pt(cx - rx * 0.20 + gust, cy + ry * 1.10),
                control2: pt(cx + rx * 0.20 + gust, cy + ry * 1.10)
            )
            mass.addCurve(
                to: pt(cx + rx * 1.02, cy - ry * 0.10),
                control1: pt(cx + rx * 0.92, cy + ry * 0.86),
                control2: pt(cx + rx * 1.06, cy + ry * 0.55)
            )
            mass.addCurve(
                to: pt(cx - rx * 1.02, cy - ry * 0.10),
                control1: pt(cx + rx * 0.70, cy + ry * 0.20),
                control2: pt(cx - rx * 0.70, cy + ry * 0.20)
            )
            mass.closeSubpath()
            c.fill(mass, with: .color(ink.opacity(0.88)))
            inkLine(mass, width: max(1.4, len(0.003)))
        case .chin:
            var mass = Path()
            mass.move(to: pt(cx - 0.058, mouthY + 0.010))
            mass.addQuadCurve(
                to: pt(cx + 0.058, mouthY + 0.010),
                control: pt(cx, mouthY + 0.030)
            )
            mass.addQuadCurve(
                to: pt(cx - 0.058, mouthY + 0.010),
                control: pt(cx, mouthY + 0.115)
            )
            mass.closeSubpath()
            c.fill(mass, with: .color(ink.opacity(0.85)))
            inkLine(mass, width: max(1.2, len(0.0024)))
        default:
            break
        }
    }

    private mutating func facialHairFront() {
        guard look.beard == .mustache || look.beard == .full || look.beard == .tusks else { return }
        if look.beard == .tusks {
            for side in [-1.0, 1.0] as [CGFloat] {
                let x = cx + side * 0.062
                var tusk = Path()
                tusk.move(to: pt(x, mouthY + 0.030))
                tusk.addLine(to: pt(x + side * 0.012, mouthY - 0.026))
                tusk.addLine(to: pt(x + side * 0.026, mouthY + 0.026))
                tusk.closeSubpath()
                c.fill(tusk, with: .color(paper))
                inkLine(tusk, width: max(1.2, len(0.0024)))
            }
            return
        }

        for side in [-1.0, 1.0] as [CGFloat] {
            var mustache = Path()
            mustache.move(to: pt(cx + side * 0.008, mouthY - 0.012))
            mustache.addQuadCurve(
                to: pt(cx + side * 0.062 + gust * 0.6, mouthY - 0.010),
                control: pt(cx + side * 0.040, mouthY - 0.040)
            )
            mustache.addQuadCurve(
                to: pt(cx + side * 0.008, mouthY - 0.012),
                control: pt(cx + side * 0.036, mouthY + 0.006)
            )
            mustache.closeSubpath()
            c.fill(mustache, with: .color(ink.opacity(0.90)))
        }
    }

    // MARK: Mouth

    private func mouthPath() -> Path {
        let w = 0.058 * (0.80 + 0.55 * mouth.wide)
        let h = 0.010 + 0.078 * mouth.open
        let corner = mouthY + h * 0.10
        var p = Path()
        p.move(to: pt(cx - w, corner))
        p.addCurve(
            to: pt(cx, mouthY - h * 0.42),
            control1: pt(cx - w * 0.62, mouthY - h * 0.52),
            control2: pt(cx - w * 0.20, mouthY - h * 0.56)
        )
        p.addCurve(
            to: pt(cx + w, corner),
            control1: pt(cx + w * 0.20, mouthY - h * 0.56),
            control2: pt(cx + w * 0.62, mouthY - h * 0.52)
        )
        p.addCurve(
            to: pt(cx, mouthY + h * 0.62),
            control1: pt(cx + w * 0.60, mouthY + h * 0.66),
            control2: pt(cx + w * 0.26, mouthY + h * 0.80)
        )
        p.addCurve(
            to: pt(cx - w, corner),
            control1: pt(cx - w * 0.26, mouthY + h * 0.80),
            control2: pt(cx - w * 0.60, mouthY + h * 0.66)
        )
        p.closeSubpath()
        return p
    }

    mutating func mouthShape() {
        let w = 0.058 * (0.80 + 0.55 * mouth.wide)
        let path = mouthPath()

        // A paper edge keeps the lips legible inside a dark beard without a white muzzle.
        if hasBeardMass {
            let halo: CGFloat = mouth.open > 0.06 ? 0.006 : 0.004
            c.stroke(
                path,
                with: .color(paper),
                style: StrokeStyle(lineWidth: max(2, len(halo)), lineCap: .round, lineJoin: .round)
            )
        }

        guard mouth.open > 0.06 else {
            var lips = Path()
            lips.move(to: pt(cx - w * 0.86, mouthY))
            lips.addQuadCurve(
                to: pt(cx + w * 0.86, mouthY),
                control: pt(cx, mouthY + 0.007)
            )
            inkLine(lips, width: max(1.5, len(0.003)), alpha: 0.92)
            return
        }

        c.fill(path, with: .color(ink.opacity(0.92)))

        // Teeth, clipped to the open mouth.
        c.drawLayer { layer in
            layer.clip(to: path)
            let teeth = Path(CGRect(
                x: (cx - w) * s,
                y: (mouthY - 0.030) * s,
                width: w * 2 * s,
                height: 0.022 * s
            ))
            layer.fill(teeth, with: .color(paper.opacity(0.94)))

            if mouth.open > 0.55 {
                let tongue = Path(ellipseIn: CGRect(
                    x: (cx - w * 0.55) * s,
                    y: (mouthY + 0.020) * s,
                    width: w * 1.10 * s,
                    height: 0.030 * s
                ))
                layer.fill(tongue, with: .color(Color(hex: 0x9E4A44).opacity(0.85)))
            }
        }

        inkLine(path, width: max(1.4, len(0.0028)))
    }

    // MARK: Accessories

    private var hatY: CGFloat { cy - ry * 0.72 }

    mutating func accessoryBack() {
        switch look.accessory {
        case .horns:
            for side in [-1.0, 1.0] as [CGFloat] {
                let x = cx + side * rx * 0.88
                var horn = Path()
                horn.move(to: pt(x, cy - ry * 0.26))
                horn.addCurve(
                    to: pt(x + side * rx * 0.46, cy - 0.40),
                    control1: pt(x + side * rx * 0.02, cy - 0.24),
                    control2: pt(x + side * rx * 0.16, cy - 0.36)
                )
                horn.addCurve(
                    to: pt(x + side * rx * 0.14, cy - ry * 0.38),
                    control1: pt(x + side * rx * 0.22, cy - 0.32),
                    control2: pt(x + side * rx * 0.16, cy - ry * 0.68)
                )
                horn.closeSubpath()
                c.fill(horn, with: .color(ink.opacity(0.92)))
                inkLine(horn, width: max(1.4, len(0.0028)))
            }
        case .halo:
            let halo = Path(ellipseIn: CGRect(
                x: (cx - rx * 0.62) * s,
                y: (cy - ry * 1.62) * s,
                width: rx * 1.24 * s,
                height: ry * 0.34 * s
            ))
            c.fill(halo, with: .color(palette.accent.opacity(0.12)))
            c.stroke(halo, with: .color(palette.accent), lineWidth: max(1.8, len(0.0034)))
        default:
            break
        }
    }

    mutating func accessoryFront() {
        switch look.accessory {
        case .tricorn:
            var brim = Path()
            brim.move(to: pt(0.22, hatY + 0.055))
            brim.addCurve(
                to: pt(cx, hatY - 0.055),
                control1: pt(0.28, hatY - 0.030),
                control2: pt(0.40, hatY - 0.070)
            )
            brim.addCurve(
                to: pt(0.78, hatY + 0.055),
                control1: pt(0.60, hatY - 0.070),
                control2: pt(0.72, hatY - 0.030)
            )
            brim.addCurve(
                to: pt(0.22, hatY + 0.055),
                control1: pt(0.66, hatY + 0.090),
                control2: pt(0.34, hatY + 0.090)
            )
            brim.closeSubpath()
            c.fill(brim, with: .color(ink.opacity(0.94)))
            inkLine(brim, width: max(1.4, len(0.003)))

            var band = Path()
            band.move(to: pt(cx - rx * 0.62, hatY + 0.020))
            band.addQuadCurve(
                to: pt(cx + rx * 0.62, hatY + 0.020),
                control: pt(cx, hatY + 0.046)
            )
            c.stroke(band, with: .color(palette.accent.opacity(0.9)), lineWidth: max(1.8, len(0.0034)))

        case .widebrim:
            var crown = Path()
            crown.move(to: pt(cx - rx * 0.62, hatY + 0.030))
            crown.addCurve(
                to: pt(cx + rx * 0.62, hatY + 0.030),
                control1: pt(cx - rx * 0.52, hatY - 0.115),
                control2: pt(cx + rx * 0.52, hatY - 0.115)
            )
            crown.closeSubpath()
            c.fill(crown, with: .color(ink.opacity(0.94)))
            let brim = Path(ellipseIn: CGRect(
                x: (cx - rx * 1.52) * s,
                y: (hatY + 0.012) * s,
                width: rx * 3.04 * s,
                height: ry * 0.30 * s
            ))
            c.fill(brim, with: .color(ink.opacity(0.94)))
            inkLine(brim, width: max(1.4, len(0.003)))

        case .wizardHat:
            var brim = Path()
            brim.move(to: pt(cx - rx * 1.45, hatY + 0.030))
            brim.addQuadCurve(
                to: pt(cx + rx * 1.45, hatY + 0.030),
                control: pt(cx, hatY - 0.040)
            )
            brim.addQuadCurve(
                to: pt(cx - rx * 1.45, hatY + 0.030),
                control: pt(cx, hatY + 0.090)
            )
            brim.closeSubpath()
            c.fill(brim, with: .color(ink.opacity(0.94)))

            var cone = Path()
            cone.move(to: pt(cx - rx * 0.80, hatY + 0.030))
            cone.addQuadCurve(
                to: pt(cx + rx * 0.62, hatY - 0.40),
                control: pt(cx + rx * 0.05, hatY - 0.28)
            )
            cone.addQuadCurve(
                to: pt(cx + rx * 0.80, hatY + 0.030),
                control: pt(cx + rx * 0.36, hatY - 0.10)
            )
            cone.closeSubpath()
            c.fill(cone, with: .color(ink.opacity(0.94)))
            inkLine(cone, width: max(1.4, len(0.003)))

        case .helm:
            var dome = Path()
            dome.move(to: pt(cx - rx * 1.00, cy - ry * 0.34))
            dome.addCurve(
                to: pt(cx + rx * 1.00, cy - ry * 0.34),
                control1: pt(cx - rx * 0.92, cy - ry * 1.10),
                control2: pt(cx + rx * 0.92, cy - ry * 1.10)
            )
            dome.addLine(to: pt(cx + rx * 0.96, cy - ry * 0.30))
            dome.addLine(to: pt(cx - rx * 0.96, cy - ry * 0.30))
            dome.closeSubpath()
            c.fill(dome, with: .color(ink.opacity(0.94)))
            inkLine(dome, width: max(1.4, len(0.003)))

            var guardPath = Path()
            guardPath.move(to: pt(cx - 0.012, cy - ry * 0.34))
            guardPath.addLine(to: pt(cx - 0.012, cy - ry * 0.02))
            guardPath.addLine(to: pt(cx + 0.012, cy - ry * 0.02))
            guardPath.addLine(to: pt(cx + 0.012, cy - ry * 0.34))
            c.fill(guardPath, with: .color(ink.opacity(0.94)))

            var crest = Path()
            crest.move(to: pt(cx - 0.020, cy - ry * 1.02))
            crest.addQuadCurve(
                to: pt(cx + 0.012, cy - ry * 1.42),
                control: pt(cx + 0.045, cy - ry * 1.28)
            )
            crest.addQuadCurve(
                to: pt(cx + 0.038, cy - ry * 1.00),
                control: pt(cx + 0.048, cy - ry * 1.20)
            )
            crest.closeSubpath()
            c.fill(crest, with: .color(palette.accent.opacity(0.9)))
            inkLine(crest, width: max(1.2, len(0.0024)))

        case .crown:
            var crown = Path()
            let base = cy - ry * 0.86
            crown.move(to: pt(cx - rx * 0.62, base + 0.055))
            crown.addLine(to: pt(cx - rx * 0.62, base - 0.010))
            crown.addLine(to: pt(cx - rx * 0.30, base + 0.028))
            crown.addLine(to: pt(cx, base - 0.035))
            crown.addLine(to: pt(cx + rx * 0.30, base + 0.028))
            crown.addLine(to: pt(cx + rx * 0.62, base - 0.010))
            crown.addLine(to: pt(cx + rx * 0.62, base + 0.055))
            crown.closeSubpath()
            c.fill(crown, with: .color(paper))
            inkLine(crown, width: max(1.4, len(0.0028)))
            for spot in [CGFloat(-0.30), 0, 0.30] {
                let gem = Path(ellipseIn: CGRect(
                    x: (cx + rx * spot - 0.012) * s,
                    y: (base + 0.006) * s,
                    width: 0.024 * s,
                    height: 0.024 * s
                ))
                c.fill(gem, with: .color(palette.accent.opacity(0.85)))
            }

        default:
            break
        }
    }

    // MARK: Ink

    private mutating func inkLine(_ path: Path, width: CGFloat, alpha: Double = 1) {
        c.stroke(
            path,
            with: .color(ink.opacity(alpha)),
            style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        )
        // A second, offset pass reads as a drawn line rather than a vector edge.
        c.drawLayer { layer in
            layer.translateBy(x: 0.7, y: -0.5)
            layer.stroke(
                path,
                with: .color(ink.opacity(alpha * 0.24)),
                style: StrokeStyle(lineWidth: width * 0.6, lineCap: .round, lineJoin: .round)
            )
        }
    }
}
