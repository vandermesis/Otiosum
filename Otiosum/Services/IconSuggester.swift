import Foundation
import NaturalLanguage

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

        let candidates = IconCatalogDatabase.curatedEntries + IconCatalogDatabase.generatedCandidates(matching: query.tokens)

        let rankedMatches = candidates
            .compactMap { entry -> RankedIconSuggestion? in
                let score = score(entry, query: query)
                guard score > 0 else { return nil }
                return RankedIconSuggestion(score: score, suggestion: entry.iconSuggestion)
            }
            .sorted()

        let suggestions = rankedMatches.reduce(into: [IconSuggestion]()) { results, ranked in
            guard results.contains(ranked.suggestion) == false else { return }
            results.append(ranked.suggestion)
        }

        guard suggestions.isEmpty == false else {
            return [fallback]
        }

        var limited = Array(suggestions.prefix(resolvedLimit))
        if limited.count < resolvedLimit, limited.contains(fallback) == false {
            limited.append(fallback)
        }

        return limited
    }

    private static let fallback = IconSuggestion(symbolName: "calendar", tintToken: "sky", emoji: "🗓️")
    private static let wordEmbedding = NLEmbedding.wordEmbedding(for: .english)

    private static func score(_ entry: IconCatalogEntry, query: NormalizedQuery) -> Int {
        let lexicalScore = entry.searchTerms
            .map(NormalizedTerm.init)
            .map { score($0, query: query) }
            .max() ?? 0

        let semanticScore = semanticScore(for: entry, query: query)

        guard lexicalScore > 0 || semanticScore > 0 else { return 0 }
        return max(lexicalScore, semanticScore) + entry.priority
    }

    private static func score(_ term: NormalizedTerm, query: NormalizedQuery) -> Int {
        if query.normalizedText == term.text {
            return 140
        }

        if query.tokens == term.tokens {
            return 120
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

        if query.tokens.contains(where: { token in
            hasMorphologicalMatch(token: token, term: term.text)
        }) {
            return 68
        }

        if term.text.count >= 4, query.tokens.contains(where: { token in
            token.count >= 4 && (token.hasPrefix(term.text) || term.text.hasPrefix(token))
        }) {
            return 58
        }

        return 0
    }

    private static func hasMorphologicalMatch(token: String, term: String) -> Bool {
        guard token.count >= 4, term.count >= 4 else { return false }
        if token == term { return true }

        return tokenVariants(token).contains(term) || tokenVariants(term).contains(token)
    }

    private static func tokenVariants(_ token: String) -> Set<String> {
        var variants: Set<String> = [token]

        if token.hasSuffix("ies"), token.count > 3 {
            variants.insert(String(token.dropLast(3)) + "y")
        }

        if token.hasSuffix("ing"), token.count > 4 {
            let stem = String(token.dropLast(3))
            variants.insert(stem)
            variants.insert(stem + "e")
        }

        if token.hasSuffix("ed"), token.count > 3 {
            let stem = String(token.dropLast(2))
            variants.insert(stem)
            variants.insert(stem + "e")
        }

        if token.hasSuffix("es"), token.count > 3 {
            variants.insert(String(token.dropLast(2)))
        }

        if token.hasSuffix("s"), token.count > 2 {
            variants.insert(String(token.dropLast()))
        }

        return variants
    }

    private static func semanticScore(for entry: IconCatalogEntry, query: NormalizedQuery) -> Int {
        guard entry.priority > 0 else { return 0 }
        guard let wordEmbedding else { return 0 }

        let queryTokens = query.tokens.filter { $0.count >= 3 && wordEmbedding.contains($0) }
        guard queryTokens.isEmpty == false else { return 0 }

        let entryTokens = entry.searchTerms
            .flatMap(LinguisticNormalizer.normalizedTokens(in:))
            .filter { $0.count >= 3 && wordEmbedding.contains($0) }

        guard entryTokens.isEmpty == false else { return 0 }

        var bestDistance = Double.greatestFiniteMagnitude
        for queryToken in queryTokens {
            for entryToken in entryTokens {
                let distance = wordEmbedding.distance(between: queryToken, and: entryToken, distanceType: .cosine)
                if distance < bestDistance {
                    bestDistance = distance
                }
            }
        }

        return switch bestDistance {
        case ..<0.65:
            78
        case ..<0.8:
            64
        case ..<0.95:
            52
        default:
            0
        }
    }
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

private struct NormalizedQuery {
    let normalizedText: String
    let tokens: [String]

    nonisolated init(_ rawValue: String) {
        let tokens = LinguisticNormalizer.normalizedTokens(in: rawValue)
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

    nonisolated init(_ rawValue: String) {
        let query = NormalizedQuery(rawValue)
        self.text = query.normalizedText
        self.tokens = query.tokens
    }
}

private enum LinguisticNormalizer {
    nonisolated static func normalizedTokens(in text: String) -> [String] {
        let lowered = text.lowercased()
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = lowered

        var tokens: [String] = []
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinContractions]
        let range = lowered.startIndex..<lowered.endIndex

        tagger.enumerateTags(in: range, unit: .word, scheme: .lemma, options: options) { tag, tokenRange in
            let rawToken = String(lowered[tokenRange])
            let normalized = tag?.rawValue ?? rawToken
            if normalized.isEmpty == false {
                tokens.append(normalized)
            }
            return true
        }

        return tokens
    }
}
