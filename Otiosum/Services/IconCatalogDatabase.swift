import Foundation
import SwiftData

struct IconCatalogEntry: Sendable {
    let iconSuggestion: IconSuggestion
    let searchTerms: [String]
    let priority: Int

    nonisolated init(
        symbolName: String,
        tintToken: String,
        emoji: String,
        terms: [String],
        synonyms: [String] = [],
        priority: Int = 0
    ) {
        self.iconSuggestion = IconSuggestion(symbolName: symbolName, tintToken: tintToken, emoji: emoji)
        self.searchTerms = terms + synonyms
        self.priority = priority
    }

    var symbolName: String {
        iconSuggestion.symbolName
    }
}

private struct GeneratedCatalogRecord: Sendable {
    let entry: IconCatalogEntry
    let normalizedName: String
}

private struct GeneratedCatalog: Sendable {
    let recordsBySymbol: [String: GeneratedCatalogRecord]
    let symbolsByToken: [String: Set<String>]
}

private final class GeneratedCatalogCache: @unchecked Sendable {
    private let lock = NSLock()
    private var catalog: GeneratedCatalog

    init(initialCatalog: GeneratedCatalog) {
        self.catalog = initialCatalog
    }

    func snapshot() -> GeneratedCatalog {
        lock.lock()
        defer { lock.unlock() }
        return catalog
    }

    func replace(with catalog: GeneratedCatalog) {
        lock.lock()
        defer { lock.unlock() }
        self.catalog = catalog
    }
}

enum IconCatalogDatabase {
    static let curatedEntries = plannerOverrides

    private static let overriddenSymbolNames = Set(plannerOverrides.map(\.symbolName))
    private static let cache = GeneratedCatalogCache(
        initialCatalog: makeGeneratedCatalog(from: bundledSymbolNames())
    )

    @MainActor
    static func prepareIfNeeded(in context: ModelContext) throws {
        let symbolNames = try storedSymbolNames(in: context)
        let generatedCatalog = makeGeneratedCatalog(from: symbolNames)
        cache.replace(with: generatedCatalog)
    }

    static func generatedCandidates(matching queryTokens: [String]) -> [IconCatalogEntry] {
        let searchableTokens = Set(queryTokens.filter { $0.count >= 3 })
        guard searchableTokens.isEmpty == false else { return [] }

        let catalog = cache.snapshot()
        let matchingSymbols = searchableTokens.reduce(into: Set<String>()) { result, token in
            if let indexedSymbols = catalog.symbolsByToken[token] {
                result.formUnion(indexedSymbols)
            }

            let textMatches = catalog.recordsBySymbol.compactMap { symbolName, record in
                record.normalizedName.localizedStandardContains(token) ? symbolName : nil
            }
            result.formUnion(textMatches)
        }

        return matchingSymbols
            .compactMap { catalog.recordsBySymbol[$0]?.entry }
            .sorted { $0.symbolName < $1.symbolName }
    }

    @MainActor
    private static func storedSymbolNames(in context: ModelContext) throws -> [String] {
        let descriptor = FetchDescriptor<IconCatalogSymbol>(
            sortBy: [SortDescriptor(\.symbolName)]
        )
        let storedSymbols = try context.fetch(descriptor)

        if storedSymbols.isEmpty == false {
            return storedSymbols.map(\.symbolName)
        }

        return try importBundledSymbols(into: context)
    }

    @MainActor
    private static func importBundledSymbols(into context: ModelContext) throws -> [String] {
        let symbolNames = bundledSymbolNames()
        guard symbolNames.isEmpty == false else { return [] }

        for (index, symbolName) in symbolNames.enumerated() {
            context.insert(IconCatalogSymbol(symbolName: symbolName))

            if index > 0, index.isMultiple(of: 500) {
                try context.save()
            }
        }

        try context.save()
        return symbolNames
    }

    private static func makeGeneratedCatalog(from allSymbolNames: [String]) -> GeneratedCatalog {
        let recordsBySymbol = Dictionary(
            uniqueKeysWithValues: allSymbolNames
                .filter { overriddenSymbolNames.contains($0) == false }
                .map { symbolName in
                    let terms = searchTerms(for: symbolName)
                    let record = GeneratedCatalogRecord(
                        entry: IconCatalogEntry(
                            symbolName: symbolName,
                            tintToken: tintToken(for: terms),
                            emoji: emoji(for: terms),
                            terms: terms
                        ),
                        normalizedName: IconCatalogSymbol.makeNormalizedName(from: symbolName)
                    )
                    return (symbolName, record)
                }
        )

        let symbolsByToken = recordsBySymbol.reduce(into: [String: Set<String>]()) { result, pair in
            let (symbolName, record) = pair
            let tokens = Set(
                record.entry.searchTerms
                    .flatMap { term in
                        term.split(separator: " ").map { String($0).lowercased() }
                    }
                    .filter { $0.count >= 3 }
            )

            for token in tokens {
                result[token, default: []].insert(symbolName)
            }
        }

        return GeneratedCatalog(recordsBySymbol: recordsBySymbol, symbolsByToken: symbolsByToken)
    }

    private static func bundledSymbolNames() -> [String] {
        guard let fileURL = bundledSymbolsFileURL() else { return [] }
        guard let fileContents = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }

        return fileContents
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }

    private static func bundledSymbolsFileURL() -> URL? {
        let bundles = Bundle.allBundles + Bundle.allFrameworks
        for bundle in bundles {
            if let fileURL = bundle.url(forResource: "SFSymbolsDB", withExtension: "txt") {
                return fileURL
            }
        }

        let currentDirectory = URL(filePath: FileManager.default.currentDirectoryPath)
        let parentDirectory = currentDirectory.deletingLastPathComponent()
        let grandparentDirectory = parentDirectory.deletingLastPathComponent()
        let fallbackURLs = [
            currentDirectory.appending(path: "SFSymbolsDB.txt"),
            currentDirectory.appending(path: "Otiosum/SFSymbolsDB.txt"),
            parentDirectory.appending(path: "SFSymbolsDB.txt"),
            parentDirectory.appending(path: "Otiosum/SFSymbolsDB.txt"),
            grandparentDirectory.appending(path: "SFSymbolsDB.txt")
        ]

        return fallbackURLs.first { FileManager.default.fileExists(atPath: $0.path()) }
    }

    private static let plannerOverrides: [IconCatalogEntry] = [
        IconCatalogEntry(
            symbolName: "bed.double.fill",
            tintToken: "indigo",
            emoji: "🛏️",
            terms: ["sleep", "bed", "nap", "rest early", "go to bed"],
            synonyms: ["bedtime", "sleeping", "power nap"],
            priority: 100
        ),
        IconCatalogEntry(
            symbolName: "fork.knife",
            tintToken: "peach",
            emoji: "🍽️",
            terms: ["eat", "meal", "lunch", "breakfast", "dinner", "food"],
            synonyms: ["snack", "brunch", "supper", "cook", "groceries", "grocery", "milk", "coke", "cola", "soda", "drink", "beverage", "coffee", "tea", "juice"],
            priority: 100
        ),
        IconCatalogEntry(
            symbolName: "sofa.fill",
            tintToken: "sand",
            emoji: "🛋️",
            terms: ["rest", "relax", "quiet", "pause", "recover"],
            synonyms: ["reset", "unwind", "downtime", "break"],
            priority: 100
        ),
        IconCatalogEntry(
            symbolName: "figure.walk",
            tintToken: "lime",
            emoji: "🏃",
            terms: ["walk", "run", "gym", "workout", "exercise"],
            synonyms: ["stretch", "fitness", "jog", "movement", "cardio"],
            priority: 100
        ),
        IconCatalogEntry(
            symbolName: "car",
            tintToken: "sky",
            emoji: "🚗",
            terms: ["car", "vehicle", "drive", "commute", "ride"],
            synonyms: ["driving", "parking", "gas", "fuel", "traffic", "trip"],
            priority: 115
        ),
        IconCatalogEntry(
            symbolName: "person.crop.circle.badge.clock",
            tintToken: "sky",
            emoji: "📅",
            terms: ["call", "meeting", "doctor", "therapy", "appointment"],
            synonyms: ["checkup", "session", "consultation", "visit", "interview"],
            priority: 100
        ),
        IconCatalogEntry(
            symbolName: "person.fill",
            tintToken: "sky",
            emoji: "👤",
            terms: ["woman", "women", "man", "men", "person", "people"],
            synonyms: ["girl", "girls", "boy", "boys", "lady", "ladies", "female", "male", "friend", "mom", "mother", "dad", "father"],
            priority: 112
        ),
        IconCatalogEntry(
            symbolName: "sparkles",
            tintToken: "amber",
            emoji: "💡",
            terms: ["idea", "brainstorm", "think", "plan"],
            synonyms: ["concept", "outline", "draft", "vision", "notes"],
            priority: 100
        ),
        IconCatalogEntry(
            symbolName: "music.note",
            tintToken: "violet",
            emoji: "🎵",
            terms: ["music", "song", "sing", "melody", "choir"],
            synonyms: ["singing", "songs", "karaoke", "playlist", "album", "vocal", "vocals"],
            priority: 112
        ),
        IconCatalogEntry(
            symbolName: "star.fill",
            tintToken: "violet",
            emoji: "✨",
            terms: ["read", "book", "movie", "film", "cinema"],
            synonyms: ["watch", "screening", "theater", "theatre", "creative"],
            priority: 100
        ),
        IconCatalogEntry(
            symbolName: "house.fill",
            tintToken: "sage",
            emoji: "🏠",
            terms: ["home", "clean", "laundry", "dish"],
            synonyms: ["tidy", "chores", "kitchen", "vacuum", "organize"],
            priority: 100
        ),
        IconCatalogEntry(
            symbolName: "laptopcomputer",
            tintToken: "teal",
            emoji: "💻",
            terms: ["code", "write", "focus", "work", "email"],
            synonyms: ["deep work", "project", "review", "study", "admin"],
            priority: 100
        ),
        IconCatalogEntry(
            symbolName: "cart.fill",
            tintToken: "mint",
            emoji: "🛒",
            terms: ["shop", "store", "buy", "pickup"],
            synonyms: ["errand", "market", "pharmacy", "target"],
            priority: 100
        )
    ]

    nonisolated private static func searchTerms(for symbolName: String) -> [String] {
        let tokens = symbolName
            .split(separator: ".")
            .map(String.init)
            .filter { ignoredTokens.contains($0) == false }
            .filter { $0.count >= 3 }

        let uniqueTokens = tokens.reduce(into: [String]()) { result, token in
            guard result.contains(token) == false else { return }
            result.append(token)
        }

        guard uniqueTokens.isEmpty == false else { return [symbolName] }

        var terms = uniqueTokens
        terms.append(uniqueTokens.joined(separator: " "))
        return terms
    }

    nonisolated private static func tintToken(for terms: [String]) -> String {
        let tokenSet = Set(terms)

        if tokenSet.intersection(["bed", "sleep", "moon", "night"]).isEmpty == false { return "indigo" }
        if tokenSet.intersection(["fork", "knife", "cart", "bag", "pill", "drink", "food"]).isEmpty == false { return "peach" }
        if tokenSet.intersection(["sofa", "heart", "leaf", "pawprint"]).isEmpty == false { return "sand" }
        if tokenSet.intersection(["figure", "run", "walk", "bicycle", "dumbbell"]).isEmpty == false { return "lime" }
        if tokenSet.intersection(["calendar", "clock", "phone", "video", "envelope", "person", "car"]).isEmpty == false { return "sky" }
        if tokenSet.intersection(["sparkles", "lightbulb"]).isEmpty == false { return "amber" }
        if tokenSet.intersection(["book", "music", "play", "gamecontroller", "movie", "film"]).isEmpty == false { return "violet" }
        if tokenSet.intersection(["house", "washer", "dishwasher"]).isEmpty == false { return "sage" }
        if tokenSet.intersection(["laptopcomputer", "desktopcomputer", "keyboard", "pencil", "document", "folder", "briefcase", "checklist"]).isEmpty == false { return "teal" }
        return "mint"
    }

    nonisolated private static func emoji(for terms: [String]) -> String {
        switch tintToken(for: terms) {
        case "indigo":
            "🛏️"
        case "peach":
            "🍽️"
        case "sand":
            "🛋️"
        case "lime":
            "🏃"
        case "sky":
            "📅"
        case "amber":
            "💡"
        case "violet":
            "✨"
        case "sage":
            "🏠"
        case "teal":
            "💻"
        default:
            "•"
        }
    }

    nonisolated private static let ignoredTokens: Set<String> = [
        "and", "fill", "circle", "square", "rectangle", "triangle", "badge", "slash",
        "crop", "left", "right", "up", "down", "forward", "backward", "portrait"
    ]
}
