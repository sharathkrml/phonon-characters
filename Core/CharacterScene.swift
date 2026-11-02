import Foundation

/// The room each character stands in. A scene is a handful of fields drawn by `SceneLayer`
/// from reusable shapes, so a backdrop is code rather than an image.
struct CharacterScene: Equatable {
    enum Backdrop: Equatable {
        case sea, forest, hills, inferno, void, cave, tower, ice, field, garden
    }
    enum Prop: Equatable {
        case mast, rocks, yew, spire, tree, bulb, stalagmites, mushrooms, shelf, icicles, banner, arch
    }
    enum Motes: Equatable {
        case spray, bubbles, leaves, embers, fireflies, dust, ash, pollen, sparks, snow, sparkles
    }

    var backdrop: Backdrop
    var prop: Prop
    var motes: Motes
    var breeze: CGFloat = 0.5
    /// Fixed per character so the layout and motes do not reshuffle between launches.
    var seed: Int = 1

    private static let table: [String: CharacterScene] = [
        "silas": .init(backdrop: .sea, prop: .mast, motes: .spray, breeze: 0.9, seed: 2),
        "morwenna": .init(backdrop: .sea, prop: .rocks, motes: .bubbles, breeze: 0.4, seed: 5),
        "mortlake": .init(backdrop: .hills, prop: .yew, motes: .leaves, breeze: 0.5, seed: 3),
        "azgorath": .init(backdrop: .inferno, prop: .spire, motes: .embers, breeze: 0.7, seed: 7),
        "fennick": .init(backdrop: .forest, prop: .tree, motes: .fireflies, breeze: 0.6, seed: 4),
        "thing": .init(backdrop: .void, prop: .bulb, motes: .dust, breeze: 0.2, seed: 9),
        "vyrmathrax": .init(backdrop: .cave, prop: .stalagmites, motes: .ash, breeze: 0.3, seed: 6),
        "grub": .init(backdrop: .field, prop: .mushrooms, motes: .pollen, breeze: 0.5, seed: 8),
        "aldric": .init(backdrop: .tower, prop: .shelf, motes: .sparks, breeze: 0.25, seed: 11),
        "snowqueen": .init(backdrop: .ice, prop: .icicles, motes: .snow, breeze: 1.0, seed: 12),
        "bramwell": .init(backdrop: .field, prop: .banner, motes: .dust, breeze: 0.7, seed: 10),
        "godmother": .init(backdrop: .garden, prop: .arch, motes: .sparkles, breeze: 0.4, seed: 13),
    ]

    static func of(_ id: String) -> CharacterScene {
        if let scene = table[id] { return scene }
        assertionFailure("No CharacterScene for persona \(id)")
        return CharacterScene(backdrop: .hills, prop: .yew, motes: .dust, breeze: 0.4, seed: 1)
    }
}

#if DEBUG
extension CharacterScene {
    static func selfCheck() {
        for persona in Persona.all {
            assert(table[persona.id] != nil, "Missing scene for \(persona.id)")
        }
    }
}
#endif
