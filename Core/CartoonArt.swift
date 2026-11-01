import AppKit
import ImageIO

struct FaceLayout: Decodable {
    struct Rect: Decodable {
        let x: Double
        let y: Double
        let w: Double
        let h: Double
    }

    let mouth: Rect
    let eyes: [Rect]
}

/// One rendered cartoon portrait plus the face layout that drives the jaw.
struct CartoonArt {
    let image: CGImage
    let face: FaceLayout?

    private final class Box {
        let art: CartoonArt
        init(_ art: CartoonArt) { self.art = art }
    }

    private static let cache: NSCache<NSString, Box> = {
        let cache = NSCache<NSString, Box>()
        cache.countLimit = 6
        return cache
    }()

    static func load(_ id: String) -> CartoonArt? {
        if let cached = cache.object(forKey: id as NSString) {
            return cached.art
        }
        guard let base = image(id, "cartoon") else { return nil }
        let art = CartoonArt(
            image: base,
            face: layout(id)
        )
        cache.setObject(Box(art), forKey: id as NSString)
        return art
    }

    private static func image(_ id: String, _ name: String) -> CGImage? {
        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: "png",
            subdirectory: "Characters/\(id)"
        ), let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func layout(_ id: String) -> FaceLayout? {
        guard let url = Bundle.main.url(
            forResource: "face",
            withExtension: "json",
            subdirectory: "Characters/\(id)"
        ), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(FaceLayout.self, from: data)
    }
}
