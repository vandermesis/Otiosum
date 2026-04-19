import Foundation
import SwiftData
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
        let suggestion = IconSuggester.suggest(for: "cotoro")

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

    @Test("Longer user words still match planner-specific synonyms")
    func longerWordsStillMatch() {
        #expect(IconSuggester.suggest(for: "writing review").symbolName == "laptopcomputer")
        #expect(IconSuggester.suggest(for: "grocery shopping").symbolName == "fork.knife")
        #expect(IconSuggester.suggest(for: "appointments").symbolName == "person.crop.circle.badge.clock")
    }

    @Test("Natural language nouns map to sane semantic icons")
    func naturalLanguageExamples() {
        #expect(IconSuggester.suggest(for: "car").symbolName == "car")
        #expect(IconSuggester.suggest(for: "milk").symbolName == "fork.knife")
        #expect(IconSuggester.suggest(for: "woman").symbolName == "person.fill")
        #expect(IconSuggester.suggest(for: "coke").symbolName == "fork.knife")
        #expect(IconSuggester.suggest(for: "movie").symbolName == "star.fill")
        #expect(IconSuggester.suggest(for: "film").symbolName == "star.fill")
        #expect(IconSuggester.suggest(for: "sing").symbolName == "music.note")
        #expect(IconSuggester.suggest(for: "music").symbolName == "music.note")
    }

    @Test("Generated SF Symbols remain reachable without scoring the full catalog")
    func generatedSymbolCandidatesStillWork() {
        let suggestion = IconSuggester.suggest(for: "pencil")

        #expect(suggestion.symbolName.localizedStandardContains("pencil"))
        #expect(suggestion.symbolName != "calendar")
    }

    @Test("Bundled SF Symbols import into SwiftData on first bootstrap")
    @MainActor
    func importsBundledCatalogIntoSwiftData() throws {
        let schema = Schema([
            Item.self,
            Event.self,
            CalendarLink.self,
            DayTemplate.self,
            DailyBudget.self,
            IconCatalogSymbol.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        try AppConfiguration.seedDefaultsIfNeeded(in: context)

        let descriptor = FetchDescriptor<IconCatalogSymbol>(
            predicate: #Predicate { symbol in
                symbol.symbolName == "pencil"
            }
        )

        #expect(try context.fetch(descriptor).isEmpty == false)
    }
}
