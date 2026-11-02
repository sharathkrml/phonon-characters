import Foundation

/// The silhouette fields that make one ink character look unlike the next. Everything the
/// face does — mouth, blink, brows — is shared code in `InkFace`.
struct CharacterLook: Equatable, Hashable {
    enum Head: Equatable { case oval, long, round, heavy, wide, blob }
    enum Hair: Equatable { case cap, long, bun, wild, bald, hood }
    enum Brow: Equatable { case thin, level, heavy, arch }
    enum Eyes: Equatable { case round, narrow, wide, hollow }
    enum Beard: Equatable { case none, full, chin, mustache, tusks }
    enum Ears: Equatable { case round, pointed, long }
    enum Accessory: Equatable { case none, tricorn, widebrim, wizardHat, helm, crown, horns, halo }
    enum Shoulders: Equatable { case broad, narrow, hunched }

    var head: Head = .oval
    var hair: Hair = .cap
    var brow: Brow = .level
    var eyes: Eyes = .round
    var beard: Beard = .none
    var ears: Ears = .round
    var accessory: Accessory = .none
    var shoulders: Shoulders = .broad

    private static let table: [String: CharacterLook] = [
        "silas": CharacterLook(head: .oval, hair: .long, brow: .heavy, eyes: .narrow,
                               beard: .full, ears: .round, accessory: .tricorn, shoulders: .broad),
        "morwenna": CharacterLook(head: .long, hair: .wild, brow: .thin, eyes: .narrow,
                                  beard: .none, ears: .pointed, accessory: .none, shoulders: .narrow),
        "mortlake": CharacterLook(head: .heavy, hair: .cap, brow: .heavy, eyes: .narrow,
                                  beard: .full, ears: .round, accessory: .widebrim, shoulders: .broad),
        "azgorath": CharacterLook(head: .long, hair: .bald, brow: .heavy, eyes: .narrow,
                                  beard: .chin, ears: .pointed, accessory: .horns, shoulders: .broad),
        "fennick": CharacterLook(head: .oval, hair: .cap, brow: .level, eyes: .wide,
                                 beard: .none, ears: .pointed, accessory: .none, shoulders: .narrow),
        "thing": CharacterLook(head: .blob, hair: .hood, brow: .thin, eyes: .hollow,
                               beard: .none, ears: .round, accessory: .none, shoulders: .hunched),
        "vyrmathrax": CharacterLook(head: .wide, hair: .bald, brow: .heavy, eyes: .narrow,
                                    beard: .tusks, ears: .long, accessory: .horns, shoulders: .hunched),
        "grub": CharacterLook(head: .heavy, hair: .bald, brow: .heavy, eyes: .round,
                              beard: .tusks, ears: .round, accessory: .none, shoulders: .hunched),
        "aldric": CharacterLook(head: .long, hair: .long, brow: .thin, eyes: .narrow,
                                beard: .full, ears: .round, accessory: .wizardHat, shoulders: .narrow),
        "snowqueen": CharacterLook(head: .oval, hair: .long, brow: .thin, eyes: .narrow,
                                   beard: .none, ears: .round, accessory: .crown, shoulders: .narrow),
        "bramwell": CharacterLook(head: .round, hair: .bald, brow: .arch, eyes: .round,
                                  beard: .mustache, ears: .round, accessory: .helm, shoulders: .broad),
        "godmother": CharacterLook(head: .round, hair: .bun, brow: .arch, eyes: .wide,
                                   beard: .none, ears: .round, accessory: .halo, shoulders: .narrow),
    ]

    static func of(_ id: String) -> CharacterLook {
        if let look = table[id] { return look }
        assertionFailure("No CharacterLook for persona \(id)")
        return CharacterLook(head: .oval, hair: .cap, brow: .level, eyes: .round,
                             beard: .none, ears: .round, accessory: .none, shoulders: .broad)
    }
}

#if DEBUG
extension CharacterLook {
    static func selfCheck() {
        for persona in Persona.all {
            assert(table[persona.id] != nil, "Missing look for \(persona.id)")
        }
    }
}
#endif
