import AppKit
import Vision

let url = URL(fileURLWithPath: CommandLine.arguments[1])
guard let image = NSImage(contentsOf: url) else { exit(2) }
var rect = CGRect(origin: .zero, size: image.size)
guard let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { exit(3) }

let request = VNDetectFaceLandmarksRequest()
try VNImageRequestHandler(cgImage: cg).perform([request])
guard let face = request.results?.first, let landmarks = face.landmarks else {
    print("{}")
    exit(0)
}

let bb = face.boundingBox

func rect(_ region: VNFaceLandmarkRegion2D?) -> (Double, Double, Double, Double)? {
    guard let region else { return nil }
    let xs = region.normalizedPoints.map { bb.origin.x + Double($0.x) * Double(bb.width) }
    let ys = region.normalizedPoints.map { bb.origin.y + Double($0.y) * Double(bb.height) }
    let x = xs.min() ?? 0
    let y = ys.min() ?? 0
    return (x, 1 - (ys.max() ?? 0), (xs.max() ?? 0) - x, (ys.max() ?? 0) - y)
}

func json(_ r: (Double, Double, Double, Double), padX: Double = 0, padY: Double = 0) -> String {
    let x = max(0, r.0 - padX)
    let y = max(0, r.1 - padY)
    let w = min(1 - x, r.2 + padX * 2)
    let h = min(1 - y, r.3 + padY * 2)
    return String(format: "{\"x\":%.4f,\"y\":%.4f,\"w\":%.4f,\"h\":%.4f}", x, y, w, h)
}

guard let mouth = rect(landmarks.outerLips),
      let left = rect(landmarks.leftEye),
      let right = rect(landmarks.rightEye)
else {
    print("{}")
    exit(0)
}

print("{\"mouth\":\(json(mouth, padX: 0.02, padY: 0.015)),\"eyes\":[\(json(left, padX: 0.012, padY: 0.012)),\(json(right, padX: 0.012, padY: 0.012))]}")
