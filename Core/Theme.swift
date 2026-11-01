import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

struct CharacterPalette: Equatable {
    let ink: Color
    let aura: Color
    let accent: Color
    let paper: Color

    static func make(_ ink: UInt32, _ aura: UInt32, _ accent: UInt32, paper: UInt32 = 0xF6F0E4) -> CharacterPalette {
        CharacterPalette(ink: Color(hex: ink), aura: Color(hex: aura), accent: Color(hex: accent), paper: Color(hex: paper))
    }
}

enum Theme {
    static let paper = Color(hex: 0xF6F0E4)
    static let paperDeep = Color(hex: 0xE7DDCB)
    static let ink = Color(hex: 0x201B16)
    static let inkSoft = Color(hex: 0x6E6458)
    static let hairline = Color(hex: 0x201B16, opacity: 0.12)

    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// Warm paper with a soft vignette and a deterministic grain. Cheap enough to sit under everything.
struct PaperBackground: View {
    var tint: Color = Theme.paper

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [tint, Theme.paperDeep.opacity(0.75), tint],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [.white.opacity(0.5), .clear],
                center: .init(x: 0.42, y: 0.38),
                startRadius: 20,
                endRadius: 780
            )
            RadialGradient(
                colors: [.clear, .black.opacity(0.10)],
                center: .center,
                startRadius: 320,
                endRadius: 980
            )
            Grain()
                .opacity(0.055)
                .blendMode(.multiply)
        }
        .ignoresSafeArea()
    }
}

private struct Grain: View {
    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
            func random() -> CGFloat {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                return CGFloat((seed >> 33) & 0xFFFF) / 65535
            }
            for _ in 0..<1100 {
                let x = random() * size.width
                let y = random() * size.height
                let r = 0.35 + random() * 0.85
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.black.opacity(0.5)))
            }
        }
        .drawingGroup()
        .allowsHitTesting(false)
    }
}

/// A 1 px rule that reads as ink rather than a UI border.
struct InkRule: View {
    var opacity: Double = 0.14
    var body: some View {
        Rectangle()
            .fill(Theme.ink.opacity(opacity))
            .frame(height: 1)
    }
}
