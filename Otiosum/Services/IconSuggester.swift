import Foundation

enum IconSuggester {
    static func suggest(for title: String, kind: PlannerItemKind = .task) -> IconSuggestion {
        let lowercased = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let mapping = keywordMappings.first { mapping in
            mapping.keywords.contains { lowercased.contains($0) }
        }

        if let mapping {
            return IconSuggestion(symbolName: mapping.symbolName, tintToken: mapping.tintToken, emoji: mapping.emoji)
        }

        switch kind {
        case .event:
            return IconSuggestion(symbolName: "calendar", tintToken: "sky", emoji: "🗓️")
        case .idea:
            return IconSuggestion(symbolName: "lightbulb", tintToken: "amber", emoji: "💡")
        case .protectedTime:
            return IconSuggestion(symbolName: "heart", tintToken: "rose", emoji: "🫶")
        case .task:
            return IconSuggestion(symbolName: "checklist", tintToken: "mint", emoji: "✓")
        }
    }

    private static let keywordMappings: [KeywordMapping] = [
        KeywordMapping(keywords: ["sleep", "bed", "nap"], symbolName: "bed.double.fill", tintToken: "indigo", emoji: "🛏️"),
        KeywordMapping(keywords: ["eat", "meal", "lunch", "breakfast", "dinner", "food"], symbolName: "fork.knife", tintToken: "peach", emoji: "🍽️"),
        KeywordMapping(keywords: ["rest", "relax", "quiet", "pause", "recover"], symbolName: "sofa.fill", tintToken: "sand", emoji: "🛋️"),
        KeywordMapping(keywords: ["walk", "run", "gym", "workout", "exercise"], symbolName: "figure.walk", tintToken: "lime", emoji: "🏃"),
        KeywordMapping(keywords: ["call", "meeting", "doctor", "therapy", "appointment"], symbolName: "person.crop.circle.badge.clock", tintToken: "sky", emoji: "📅"),
        KeywordMapping(keywords: ["idea", "brainstorm", "think", "plan"], symbolName: "sparkles", tintToken: "amber", emoji: "💡"),
        KeywordMapping(keywords: ["music", "read", "book", "movie", "play"], symbolName: "star.fill", tintToken: "violet", emoji: "✨"),
        KeywordMapping(keywords: ["home", "clean", "laundry", "dish"], symbolName: "house.fill", tintToken: "sage", emoji: "🏠"),
        KeywordMapping(keywords: ["code", "write", "focus", "work", "email"], symbolName: "laptopcomputer", tintToken: "teal", emoji: "💻")
    ]
}

private struct KeywordMapping {
    let keywords: [String]
    let symbolName: String
    let tintToken: String
    let emoji: String
}
