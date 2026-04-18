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
            ("code review", "laptopcomputer", "teal", "💻")
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

    @Test("Fallback suggestion depends on item kind when no keyword matches")
    func fallbackByKind() {
        let eventSuggestion = IconSuggester.suggest(for: "xylophone", kind: .event)
        let ideaSuggestion = IconSuggester.suggest(for: "xylophone", kind: .idea)
        let protectedSuggestion = IconSuggester.suggest(for: "xylophone", kind: .protectedTime)
        let taskSuggestion = IconSuggester.suggest(for: "xylophone", kind: .task)

        #expect(eventSuggestion.symbolName == "calendar")
        #expect(eventSuggestion.tintToken == "sky")
        #expect(eventSuggestion.emoji == "🗓️")

        #expect(ideaSuggestion.symbolName == "lightbulb")
        #expect(ideaSuggestion.tintToken == "amber")
        #expect(ideaSuggestion.emoji == "💡")

        #expect(protectedSuggestion.symbolName == "heart")
        #expect(protectedSuggestion.tintToken == "rose")
        #expect(protectedSuggestion.emoji == "🫶")

        #expect(taskSuggestion.symbolName == "checklist")
        #expect(taskSuggestion.tintToken == "mint")
        #expect(taskSuggestion.emoji == "✓")
    }

    @Test("Trimmed and lowercased titles still match mappings")
    func trimsAndLowercasesInput() {
        let suggestion = IconSuggester.suggest(for: "   SLEEP   ")

        #expect(suggestion.symbolName == "bed.double.fill")
    }

    @Test("The first matching keyword mapping wins")
    func firstMatchWins() {
        let suggestion = IconSuggester.suggest(for: "plan lunch")

        #expect(suggestion.symbolName == "fork.knife")
        #expect(suggestion.tintToken == "peach")
    }
}
