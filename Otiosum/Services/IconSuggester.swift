import Foundation

enum IconSuggester {
    static func suggest(for title: String) -> IconSuggestion {
        suggestions(for: title, limit: 1).first ?? fallback
    }

    static func suggestions(
        for title: String,
        limit: Int = 3
    ) -> [IconSuggestion] {
        let resolvedLimit = max(1, limit)
        let query = NormalizedQuery(title)

        guard query.isEmpty == false else {
            return [fallback]
        }

        let rankedMatches: [RankedIconSuggestion] = catalog.compactMap { entry -> RankedIconSuggestion? in
                let score = score(entry, query: query)
                guard score > 0 else { return nil }
                return RankedIconSuggestion(score: score, suggestion: entry.iconSuggestion)
            }
            .sorted()

        let rankedSuggestions = rankedMatches.reduce(into: [IconSuggestion]()) { suggestions, ranked in
                guard suggestions.contains(ranked.suggestion) == false else { return }
                suggestions.append(ranked.suggestion)
            }

        if rankedSuggestions.isEmpty {
            return [fallback]
        }

        var limitedSuggestions = Array(rankedSuggestions.prefix(resolvedLimit))
        if limitedSuggestions.count < resolvedLimit, limitedSuggestions.contains(fallback) == false {
            limitedSuggestions.append(fallback)
        }

        return limitedSuggestions
    }

    private static let fallback = IconSuggestion(symbolName: "calendar", tintToken: "sky", emoji: "🗓️")

    private static func score(_ entry: IconCatalogEntry, query: NormalizedQuery) -> Int {
        let termScores = entry.searchTerms.map { score($0, query: query) }
        let bestTermScore = termScores.max() ?? 0
        guard bestTermScore > 0 else { return 0 }
        return bestTermScore
    }

    private static func score(_ term: NormalizedTerm, query: NormalizedQuery) -> Int {
        if query.normalizedText == term.text {
            return 140
        }

        if query.tokens == term.tokens {
            return 120
        }

        if query.normalizedText.localizedStandardContains(term.text) {
            return 105
        }

        if query.tokens.contains(where: { $0 == term.text }) {
            return 100
        }

        if term.tokens.isEmpty == false, term.tokens.allSatisfy(query.tokens.contains) {
            return 92
        }

        if term.tokens.contains(where: { query.tokens.contains($0) }) {
            return 74
        }

        if query.tokens.contains(where: { $0.hasPrefix(term.text) || term.text.hasPrefix($0) }) {
            return 58
        }

        if query.normalizedText.localizedStandardContains(term.text.replacing(" ", with: "")) {
            return 44
        }

        return 0
    }

    private static let catalog: [IconCatalogEntry] = [
        IconCatalogEntry(
            symbolName: "bed.double.fill",
            tintToken: "indigo",
            emoji: "🛏️",
            terms: ["sleep", "bed", "nap", "rest early", "go to bed"],
            synonyms: ["bedtime", "sleeping", "power nap"]
        ),
        IconCatalogEntry(
            symbolName: "fork.knife",
            tintToken: "peach",
            emoji: "🍽️",
            terms: ["eat", "meal", "lunch", "breakfast", "dinner", "food"],
            synonyms: ["snack", "brunch", "supper", "cook", "groceries"]
        ),
        IconCatalogEntry(
            symbolName: "sofa.fill",
            tintToken: "sand",
            emoji: "🛋️",
            terms: ["rest", "relax", "quiet", "pause", "recover"],
            synonyms: ["reset", "unwind", "downtime", "break"]
        ),
        IconCatalogEntry(
            symbolName: "figure.walk",
            tintToken: "lime",
            emoji: "🏃",
            terms: ["walk", "run", "gym", "workout", "exercise"],
            synonyms: ["stretch", "fitness", "jog", "movement", "cardio"]
        ),
        IconCatalogEntry(
            symbolName: "person.crop.circle.badge.clock",
            tintToken: "sky",
            emoji: "📅",
            terms: ["call", "meeting", "doctor", "therapy", "appointment"],
            synonyms: ["checkup", "session", "consultation", "visit", "interview"]
        ),
        IconCatalogEntry(
            symbolName: "sparkles",
            tintToken: "amber",
            emoji: "💡",
            terms: ["idea", "brainstorm", "think", "plan"],
            synonyms: ["concept", "outline", "draft", "vision", "notes"]
        ),
        IconCatalogEntry(
            symbolName: "star.fill",
            tintToken: "violet",
            emoji: "✨",
            terms: ["music", "read", "book", "movie", "play"],
            synonyms: ["podcast", "game", "watch", "listen", "creative"]
        ),
        IconCatalogEntry(
            symbolName: "house.fill",
            tintToken: "sage",
            emoji: "🏠",
            terms: ["home", "clean", "laundry", "dish"],
            synonyms: ["tidy", "chores", "kitchen", "vacuum", "organize"]
        ),
        IconCatalogEntry(
            symbolName: "laptopcomputer",
            tintToken: "teal",
            emoji: "💻",
            terms: ["code", "write", "focus", "work", "email"],
            synonyms: ["deep work", "project", "review", "study", "admin"]
        ),
        IconCatalogEntry(
            symbolName: "cart.fill",
            tintToken: "mint",
            emoji: "🛒",
            terms: ["shop", "store", "buy", "pickup"],
            synonyms: ["errand", "market", "pharmacy", "target"]
        )
    ]
}

private struct RankedIconSuggestion: Comparable {
    let score: Int
    let suggestion: IconSuggestion

    static func < (lhs: RankedIconSuggestion, rhs: RankedIconSuggestion) -> Bool {
        if lhs.score == rhs.score {
            return lhs.suggestion.symbolName < rhs.suggestion.symbolName
        }
        return lhs.score > rhs.score
    }
}

private struct IconCatalogEntry {
    let iconSuggestion: IconSuggestion
    let searchTerms: [NormalizedTerm]

    init(
        symbolName: String,
        tintToken: String,
        emoji: String,
        terms: [String],
        synonyms: [String] = []
    ) {
        self.iconSuggestion = IconSuggestion(symbolName: symbolName, tintToken: tintToken, emoji: emoji)
        self.searchTerms = NormalizedTerm.makeAll(terms + synonyms)
    }
}

private struct NormalizedQuery {
    let normalizedText: String
    let tokens: [String]

    init(_ rawValue: String) {
        let tokens = rawValue
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }
        self.tokens = tokens
        self.normalizedText = tokens.joined(separator: " ")
    }

    var isEmpty: Bool {
        normalizedText.isEmpty
    }
}

private struct NormalizedTerm {
    let text: String
    let tokens: [String]

    init(_ rawValue: String) {
        let query = NormalizedQuery(rawValue)
        self.text = query.normalizedText
        self.tokens = query.tokens
    }

    static func makeAll(_ values: [String]) -> [NormalizedTerm] {
        values
            .map { NormalizedTerm($0) }
            .filter { $0.text.isEmpty == false }
    }
}
