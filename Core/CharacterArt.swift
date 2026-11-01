import AppKit

/// Illustrated layers for one character. Files live in `Resources/Characters/<id>/`.
/// A missing or incomplete set makes `load` return nil, so `PortraitView` keeps the drawn fallback.
struct CharacterArt {
    let base: NSImage
    let mouthSmall: NSImage
    let mouthMedium: NSImage
    let mouthWide: NSImage
    let eyesClosed: NSImage

    private final class Box {
        let art: CharacterArt
        init(_ art: CharacterArt) { self.art = art }
    }

    private static let cache: NSCache<NSString, Box> = {
        let cache = NSCache<NSString, Box>()
        cache.countLimit = 6
        return cache
    }()

    static func load(_ id: String) -> CharacterArt? {
        if let cached = cache.object(forKey: id as NSString) {
            return cached.art
        }
        guard let base = image(id, "base"),
              let small = image(id, "mouth-small"),
              let medium = image(id, "mouth-medium"),
              let wide = image(id, "mouth-wide"),
              let closed = image(id, "eyes-closed")
        else { return nil }

        let art = CharacterArt(
            base: base,
            mouthSmall: small,
            mouthMedium: medium,
            mouthWide: wide,
            eyesClosed: closed
        )
        cache.setObject(Box(art), forKey: id as NSString)
        return art
    }

    private static func image(_ id: String, _ name: String) -> NSImage? {
        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: "png",
            subdirectory: "Characters/\(id)"
        ) else { return nil }
        return NSImage(contentsOf: url)
    }
}
