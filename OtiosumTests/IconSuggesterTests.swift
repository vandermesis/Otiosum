import Foundation
import Testing
@testable import Otiosum

struct IconSuggesterTests {
    @Test(
        "Keyword mappings return expected icon suggestions",
        arguments: [
            ("sleep early", "bed.double.fill", "indigo", "🛏️"),
            ("lunch break", "fork.knife", "peach", "🍽️"),
            ("quiet reset", "sofa.fill", "sand", "🛋️"),
            ("workout", "figure.walk", "lime", "🏃"),
            ("doctor appointment", "person.crop.circle.badge.clock", "sky", "📅"),
            ("brainstorm", "sparkles", "amber", "💡"),
            ("read", "star.fill", "violet", "✨"),
            ("laundry", "house.fill", "sage", "🏠"),
            ("code review", "laptopcomputer", "teal", "💻"),
            ("pick up groceries", "fork.knife", "peach", "🍽️")
        ]
    )
    func keywordMappings(
        title: String,
        expectedSymbol: String,
        expectedTint: String,
        expectedEmoji: String
    ) {
        let suggestion = IconSuggester.suggest(for: title)

        #expect(suggestion.symbolName == expectedSymbol)
        #expect(suggestion.tintToken == expectedTint)
        #expect(suggestion.emoji == expectedEmoji)
    }

    @Test("Fallback suggestion is stable when no keyword matches")
    func fallbackSuggestion() {
        let suggestion = IconSuggester.suggest(for: "xylophone")

        #expect(suggestion.symbolName == "calendar")
        #expect(suggestion.tintToken == "sky")
        #expect(suggestion.emoji == "🗓️")
    }

    @Test("Trimmed and lowercased titles still match mappings")
    func trimsAndLowercasesInput() {
        let suggestion = IconSuggester.suggest(for: "   SLEEP   ")

        #expect(suggestion.symbolName == "bed.double.fill")
    }

    @Test("The strongest match wins over a weaker partial match")
    func strongestMatchWins() {
        let suggestion = IconSuggester.suggest(for: "plan lunch")

        #expect(suggestion.symbolName == "fork.knife")
        #expect(suggestion.tintToken == "peach")
    }

    @Test("Suggestions are ranked with the strongest match first")
    func suggestionsAreRanked() {
        let suggestions = IconSuggester.suggestions(for: "doctor appointment")

        #expect(suggestions.first?.symbolName == "person.crop.circle.badge.clock")
    }

    @Test("Suggestions append fallback when requested limit exceeds direct matches")
    func suggestionsAppendFallback() {
        let suggestions = IconSuggester.suggestions(for: "deep work review", limit: 3)

        #expect(suggestions.first?.symbolName == "laptopcomputer")
        #expect(suggestions.contains { $0.symbolName == "calendar" })
    }
}
