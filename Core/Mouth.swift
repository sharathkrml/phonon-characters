import Foundation

/// How open and how spread the mouth is. `open` is the jaw drop, `wide` the lip spread;
/// a narrow `wide` with a high `open` reads as "o", a wide one as "a".
struct MouthShape: Equatable {
    var open: Double = 0
    var wide: Double = 0.45

    static let closed = MouthShape(open: 0, wide: 0.45)

    func mixed(_ other: MouthShape, _ t: Double) -> MouthShape {
        MouthShape(
            open: open + (other.open - open) * t,
            wide: wide + (other.wide - wide) * t
        )
    }

    /// Which mouth shape a letter is drawn with. Crude on purpose: no phonemizer needed
    /// for a face this size.
    static func shape(for character: Character) -> MouthShape {
        switch character.lowercased().first {
        case "a": MouthShape(open: 0.92, wide: 0.62)
        case "e": MouthShape(open: 0.55, wide: 0.95)
        case "i", "y": MouthShape(open: 0.30, wide: 0.90)
        case "o": MouthShape(open: 0.72, wide: 0.18)
        case "u", "w": MouthShape(open: 0.45, wide: 0.16)
        case "m", "b", "p": .closed
        case "f", "v": MouthShape(open: 0.12, wide: 0.72)
        case "l", "r", "n", "d", "t": MouthShape(open: 0.36, wide: 0.52)
        case "s", "z", "c", "k", "g", "j", "x", "q", "h": MouthShape(open: 0.20, wide: 0.58)
        default: .closed
        }
    }
}

/// The mouth shapes of one line of speech, advanced only while audio is actually audible.
/// Gating on voiced frames keeps the lips on the words even though playback lags generation.
struct MouthTrack {
    private let shapes: [MouthShape]
    private var index = 0
    private var carry = 0.0

    private static let secondsPerShape = 0.080

    init(text: String) {
        shapes = text.map(MouthShape.shape(for:))
    }

    var current: MouthShape {
        shapes.indices.contains(index) ? shapes[index] : .closed
    }

    mutating func advance(voiced: Bool, dt: Double) -> MouthShape {
        guard !shapes.isEmpty else { return .closed }
        guard voiced else { return .closed }
        carry += dt
        while carry >= Self.secondsPerShape {
            carry -= Self.secondsPerShape
            // Loop the line: playback can outlast our estimate, and a mouth that freezes
            // shut mid-sentence looks worse than one that keeps moving.
            index = (index + 1) % shapes.count
        }
        return current
    }
}

#if DEBUG
extension MouthTrack {
    static func selfCheck() {
        assert(MouthShape.shape(for: "m").open == 0, "m should close the lips")
        assert(MouthShape.shape(for: "a").open > 0.6, "a should open the mouth")
        assert(MouthShape.shape(for: " ").open == 0, "spaces keep the mouth shut")

        var track = MouthTrack(text: "am")
        assert(track.advance(voiced: true, dt: 0.001).open > 0.6, "starts on a")
        _ = track.advance(voiced: true, dt: 0.082)
        assert(track.current.open == 0, "should have moved on to m")
        assert(track.advance(voiced: false, dt: 0.2).open == 0, "silence closes the mouth")
        _ = track.advance(voiced: true, dt: 0.082 * 5)
        assert(track.current.open > 0.6, "loops back to the start rather than freezing")
    }
}
#endif
