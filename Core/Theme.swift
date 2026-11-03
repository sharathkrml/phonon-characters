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

    /// The dialogue plate: warmer and lighter than the page so it reads as parchment.
    static let parchment = Color(hex: 0xF9F1E1)
    static let parchmentDeep = Color(hex: 0xEADCC2)

    /// A single gold for every character. Character accents are too pale (Snow Queen) or too
    /// dark (Azgorath) to work as the frame, so gilt stays constant and accents only glow.
    static let giltLight = Color(hex: 0xF4E3B0)
    static let giltDeep = Color(hex: 0x9A7128)
    static let ready = Color(hex: 0x6FA84F)
    static let ember = Color(hex: 0xC0552F)

    static var gilt: LinearGradient {
        LinearGradient(
            colors: [giltLight, Color(hex: 0xD3A54C), giltDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    /// Nameplate and title type: wider and heavier than body copy, so it reads as a game title.
    static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .serif).width(.expanded)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func label(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// The painted world behind a character: their own palette, top to floor, with a vignette.
struct StageBackdrop: View {
    let palette: CharacterPalette

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: palette.ink, location: 0),
                    .init(color: palette.ink.opacity(0.94), location: 0.45),
                    .init(color: palette.aura.opacity(0.68), location: 0.76),
                    .init(color: palette.ink.opacity(0.96), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [palette.aura.opacity(0.55), .clear],
                center: .init(x: 0.5, y: 0.36),
                startRadius: 10,
                endRadius: 640
            )
            RadialGradient(
                colors: [.clear, .black.opacity(0.42)],
                center: .center,
                startRadius: 280,
                endRadius: 940
            )
            Grain()
                .opacity(0.05)
                .blendMode(.overlay)
        }
        .ignoresSafeArea()
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
