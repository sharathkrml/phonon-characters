import Foundation

/// Asks the brain to direct the stage. The model gets real tools and chooses one itself; this
/// is a separate call so the spoken reply stays clean and no tool syntax reaches the voice.
enum StageBrain {
    static func choose(port: Int, character: Persona, message: String) async -> (effect: StageEffect, strength: Double)? {
        guard port > 0 else { return nil }
        let abilities = StageEffect.abilities(for: character.id)
        guard !abilities.isEmpty else { return nil }

        let catalog = abilities
            .map { "- \($0.effect.rawValue): \($0.name) — visitor says \"\($0.example)\"" }
            .joined(separator: "\n")

        let system = """
        You are the stage crew for \(character.name), \(character.tagline). The character can \
        do exactly these things:
        \(catalog)

        Call set_stage_effect when the visitor asks what the character can do, asks for a \
        demonstration, or explicitly asks for one of these abilities. Use keep_stage_calm for \
        greetings, small talk, grief, fear, stories and ordinary questions.
        """

        let setEffect = BrainTool(
            name: "set_stage_effect",
            description: "Bring one of this character's abilities onto the stage. Call when the visitor asks what the character can do, asks for a demonstration, or explicitly asks for one of the abilities.",
            parameters: [
                "type": "object",
                "properties": [
                    "effect": [
                        "type": "string",
                        "enum": abilities.map(\.effect.rawValue),
                    ],
                    "strength": ["type": "number", "minimum": 0, "maximum": 1],
                ],
                "required": ["effect", "strength"],
                "additionalProperties": false,
            ]
        )

        // Without an explicit "do nothing" tool the small model summons weather for "hello".
        // Making calm a real choice is what fixed the false calls in testing.
        let keepCalm = BrainTool(
            name: "keep_stage_calm",
            description: "Use this when no stage effect is wanted: greetings, small talk, grief, fear, stories, ordinary questions, or anything that is not a request to see a power.",
            parameters: [
                "type": "object",
                "properties": [String: Any](),
                "additionalProperties": false,
            ]
        )

        guard let call = await BrainClient.completeToolCall(
            port: port,
            system: system,
            user: message,
            tools: [setEffect, keepCalm]
        ) else { return nil }

        guard call.name == "set_stage_effect",
              let raw = call.arguments["effect"] as? String,
              let effect = StageEffect(rawValue: raw)
        else { return nil }

        let strength = (call.arguments["strength"] as? NSNumber)?.doubleValue ?? 0.8
        return (effect, min(max(strength, 0.35), 1))
    }

    /// Appended to the persona's system prompt when the visitor asks what the character can do,
    /// so the spoken answer names the real abilities and teaches the visitor the words to use.
    static func capabilityBrief(for character: Persona) -> String {
        let abilities = StageEffect.abilities(for: character.id)
        let names = spokenList(abilities.map(\.name))
        let example = abilities.first?.example ?? ""
        return """
        The visitor just asked what you can do. Say this, only lightly reworded into your own \
        voice, keeping every ability and the example line: "I can \(names). Say '\(example)' and \
        I will do it." Change nothing else: add no other abilities, no questions, no offers, and \
        no notes about the answer or when it ends. Never mention effects, weather controls, JSON \
        or the stage.
        """
    }

    private static func spokenList(_ items: [String]) -> String {
        guard let last = items.last else { return "" }
        if items.count == 1 { return last }
        return items.dropLast().joined(separator: ", ") + " and " + last
    }
}
