import SwiftUI

/// A painted portrait that breathes and sways with the voice. The full image is kept at its
/// natural aspect ratio, so the character's original composition is preserved.
struct PortraitImage: View {
    let art: PortraitArt
    let level: CGFloat
    let listening: Bool
    let time: TimeInterval
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { proxy in
            let breathe = reduceMotion || listening ? 0 : sin(time * 0.85) * 0.006
            let sway = reduceMotion || listening ? 0 : sin(time * 0.45) * 0.55

            Image(nsImage: art.image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .scaleEffect(1 + level * 0.014 + breathe)
                .rotationEffect(.degrees(sway), anchor: .bottom)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
