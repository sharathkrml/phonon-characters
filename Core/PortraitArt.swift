import AppKit
import ImageIO

/// One rendered portrait. The art carries the expression; nothing is overlaid on the face.
struct PortraitArt {
    let image: NSImage

    private final class Box {
        let art: PortraitArt
        init(_ art: PortraitArt) { self.art = art }
    }

    private static let cache: NSCache<NSString, Box> = {
        let cache = NSCache<NSString, Box>()
        cache.countLimit = 6
        return cache
    }()

    /// Downsampled once per size, so the roster can show twelve faces without decoding
    /// twelve 1504×1046 images.
    private static let thumbnails: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 40
        return cache
    }()

    static func thumbnail(_ id: String, size: CGFloat) -> NSImage? {
        let key = "\(id)-\(Int(size))" as NSString
        if let cached = thumbnails.object(forKey: key) { return cached }
        guard let url = Bundle.main.url(
            forResource: "portrait",
            withExtension: "png",
            subdirectory: "Characters/\(id)"
        ), let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(size * 2),
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
        thumbnails.setObject(image, forKey: key)
        return image
    }

    static func load(_ id: String) -> PortraitArt? {
        if let cached = cache.object(forKey: id as NSString) {
            return cached.art
        }
        guard let image = image(id) else { return nil }
        let art = PortraitArt(image: image)
        cache.setObject(Box(art), forKey: id as NSString)
        return art
    }

    private static func image(_ id: String) -> NSImage? {
        guard let url = Bundle.main.url(
            forResource: "portrait",
            withExtension: "png",
            subdirectory: "Characters/\(id)"
        ) else { return nil }
        return NSImage(contentsOf: url)
    }
}
