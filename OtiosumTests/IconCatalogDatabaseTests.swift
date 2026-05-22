import Foundation
import Testing
@testable import Otiosum

struct IconCatalogDatabaseTests {

    // MARK: - IconCatalogEntry

    @Test("IconCatalogEntry merges primary terms and synonyms into searchTerms")
    func searchTermsMergeTermsAndSynonyms() {
        let entry = IconCatalogEntry(
            symbolName: "test.symbol",
            tintToken: "indigo",
            emoji: "🧪",
            terms: ["alpha", "beta"],
            synonyms: ["gamma", "delta"]
        )

        #expect(entry.searchTerms == ["alpha", "beta", "gamma", "delta"])
    }

    @Test("IconCatalogEntry defaults to no synonyms when none are supplied")
    func searchTermsWithoutSynonyms() {
        let entry = IconCatalogEntry(
            symbolName: "test.symbol",
            tintToken: "indigo",
            emoji: "🧪",
            terms: ["alpha"]
        )

        #expect(entry.searchTerms == ["alpha"])
    }

    // MARK: - generatedCandidates filtering

    @Test("Generated candidates are empty when every query token is shorter than three characters")
    func generatedCandidatesRequiresThreeCharTokens() {
        #expect(IconCatalogDatabase.generatedCandidates(matching: []).isEmpty)
        #expect(IconCatalogDatabase.generatedCandidates(matching: ["a", "to", "x"]).isEmpty)
    }

    @Test("Generated candidates never include symbols that are overridden by planner overrides")
    func generatedCandidatesSkipsOverrides() {
        let overrideNames = Set(IconCatalogDatabase.curatedEntries.map(\.symbolName))
        let probeTokens = ["bed", "fork", "sofa", "house", "music", "laptopcomputer"]

        for token in probeTokens {
            let results = IconCatalogDatabase.generatedCandidates(matching: [token])
            for result in results {
                #expect(
                    overrideNames.contains(result.symbolName) == false,
                    "Generated results for '\(token)' must not include override symbol \(result.symbolName)"
                )
            }
        }
    }

    // MARK: - Curated overrides

    @Test("Each curated override exposes the expected SF Symbol, tint, and emoji")
    func curatedOverrideMetadata() throws {
        let expectations: [(String, String, String)] = [
            ("bed.double.fill", "indigo", "🛏️"),
            ("fork.knife", "peach", "🍽️"),
            ("sofa.fill", "sand", "🛋️"),
            ("figure.walk", "lime", "🏃"),
            ("car", "sky", "🚗"),
            ("person.crop.circle.badge.clock", "sky", "📅"),
            ("person.fill", "sky", "👤"),
            ("sparkles", "amber", "💡"),
            ("music.note", "violet", "🎵"),
            ("star.fill", "violet", "✨"),
            ("house.fill", "sage", "🏠"),
            ("laptopcomputer", "teal", "💻"),
            ("cart.fill", "mint", "🛒")
        ]

        for (symbol, tint, emoji) in expectations {
            let entry = try #require(
                IconCatalogDatabase.curatedEntries.first { $0.symbolName == symbol },
                "Expected curated entry for \(symbol)"
            )
            #expect(entry.iconSuggestion.tintToken == tint)
            #expect(entry.iconSuggestion.emoji == emoji)
        }
    }

    @Test("Curated entries roll synonyms into searchTerms next to primary terms")
    func curatedSynonymsAreSearchable() throws {
        let bed = try #require(
            IconCatalogDatabase.curatedEntries.first { $0.symbolName == "bed.double.fill" }
        )

        #expect(bed.searchTerms.contains("sleep"))
        #expect(bed.searchTerms.contains("bedtime"))
        #expect(bed.searchTerms.contains("power nap"))
    }
}
