import Foundation
import SwiftData

enum AppConfiguration {
    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST")
    }

    static var hasDeterministicTimelineTask: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_TIMELINE_TASK")
    }

    @MainActor
    static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            Item.self,
            Event.self,
            CalendarLink.self,
            DayTemplate.self,
            DailyBudget.self,
            IconCatalogSymbol.self
        ])

        if isUITesting {
            let inMemoryConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )

            do {
                return try makeSeededContainer(
                    schema: schema,
                    configuration: inMemoryConfiguration,
                    seedUITestDataIfNeeded: true
                )
            } catch {
                fatalError("Could not create UI test ModelContainer: \(error)")
            }
        }

        do {
            let storeURL = try persistentStoreURL()
            let persistentConfiguration = ModelConfiguration(
                "OtiosumStore",
                schema: schema,
                url: storeURL
            )

            do {
                return try makeSeededContainer(
                    schema: schema,
                    configuration: persistentConfiguration,
                    seedUITestDataIfNeeded: false
                )
            } catch {
                try resetPersistentStore(at: storeURL)
                return try makeSeededContainer(
                    schema: schema,
                    configuration: persistentConfiguration,
                    seedUITestDataIfNeeded: false
                )
            }
        } catch {
            // Last-resort fallback keeps app launch resilient if persistent recovery failed.
            let fallbackConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )

            do {
                return try makeSeededContainer(
                    schema: schema,
                    configuration: fallbackConfiguration,
                    seedUITestDataIfNeeded: false
                )
            } catch {
                fatalError("Could not create fallback ModelContainer: \(error)")
            }
        }
    }

    @MainActor
    private static func makeSeededContainer(
        schema: Schema,
        configuration: ModelConfiguration,
        seedUITestDataIfNeeded: Bool
    ) throws -> ModelContainer {
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        try seedDefaultsIfNeeded(in: context)

        if seedUITestDataIfNeeded {
            try seedUITestData(in: context)
        }

        return container
    }

    private static func persistentStoreURL() throws -> URL {
        let directory = URL.applicationSupportDirectory
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory.appending(path: "Otiosum.store")
    }
    
    private static func resetPersistentStore(at storeURL: URL) throws {
        let fileManager = FileManager.default
        let companionURLs = [
            storeURL,
            URL(fileURLWithPath: storeURL.path() + "-shm"),
            URL(fileURLWithPath: storeURL.path() + "-wal")
        ]

        for url in companionURLs where fileManager.fileExists(atPath: url.path()) {
            try fileManager.removeItem(at: url)
        }
    }

    @MainActor
    static func seedDefaultsIfNeeded(in context: ModelContext) throws {
        try IconCatalogDatabase.prepareIfNeeded(in: context)

        if try context.fetch(FetchDescriptor<DayTemplate>()).isEmpty {
            context.insert(DayTemplate())
        }

        if try context.fetch(FetchDescriptor<DailyBudget>()).isEmpty {
            context.insert(DailyBudget())
        }

        try context.save()
    }

    @MainActor
    private static func seedUITestData(in context: ModelContext) throws {
        try clearExistingPlannerData(in: context)
        try seedDefaultsIfNeeded(in: context)

        let template = try context.fetch(FetchDescriptor<DayTemplate>()).first ?? DayTemplate()
        if template.modelContext == nil {
            context.insert(template)
        }

        let today = Calendar.current.startOfDay(for: .now)

        let focusIcon = IconSuggester.suggest(for: "Write proposal")
        let relaxIcon = IconSuggester.suggest(for: "Relax")
        let callIcon = IconSuggester.suggest(for: "Call therapist")
        let ideaIcon = IconSuggester.suggest(for: "Idea garden")

        context.insert(
            Event(
                title: "Write proposal",
                source: .local,
                suggestedIcon: focusIcon.symbolName,
                tintToken: focusIcon.tintToken,
                targetDurationMinutes: 45,
                minimumDurationMinutes: 30,
                scheduledDay: today,
                preferredStartMinutes: max(template.wakeUpMinutes + 30, 9 * 60),
                preferredTimeWindow: .morning,
                flexibility: .flexible,
                isSavedForLater: false
            )
        )

        context.insert(
            Event(
                title: "Call therapist",
                source: .local,
                suggestedIcon: callIcon.symbolName,
                tintToken: callIcon.tintToken,
                targetDurationMinutes: 30,
                minimumDurationMinutes: 30,
                scheduledDay: today,
                preferredStartMinutes: 15 * 60,
                preferredTimeWindow: .afternoon,
                flexibility: .askBeforeMove,
                isSavedForLater: false
            )
        )

        context.insert(
            Event(
                title: "Relax",
                source: .local,
                suggestedIcon: relaxIcon.symbolName,
                tintToken: relaxIcon.tintToken,
                targetDurationMinutes: 30,
                minimumDurationMinutes: 20,
                scheduledDay: today,
                preferredStartMinutes: 18 * 60,
                preferredTimeWindow: .evening,
                flexibility: .flexible,
                isSavedForLater: false
            )
        )

        context.insert(
            Event(
                title: "Idea garden",
                source: .local,
                suggestedIcon: ideaIcon.symbolName,
                tintToken: ideaIcon.tintToken,
                targetDurationMinutes: 30,
                minimumDurationMinutes: 15,
                scheduledDay: nil,
                preferredStartMinutes: nil,
                preferredTimeWindow: .anytime,
                flexibility: .flexible,
                isSavedForLater: true
            )
        )

        if hasDeterministicTimelineTask {
            let now = Date.now
            let currentMinutes = now.minutesSinceStartOfDay(using: .current)
            let roundedMinutes = ((currentMinutes + 2) / 5) * 5
            let timelineIcon = IconSuggester.suggest(for: "UI timeline task")

            context.insert(
                Event(
                    title: "UI Timeline Task",
                    source: .local,
                    suggestedIcon: timelineIcon.symbolName,
                    tintToken: timelineIcon.tintToken,
                    targetDurationMinutes: 30,
                    minimumDurationMinutes: 15,
                    scheduledDay: today,
                    preferredStartMinutes: roundedMinutes,
                    preferredTimeWindow: .anytime,
                    flexibility: .flexible,
                    isSavedForLater: false
                )
            )
        }

        try context.save()
    }

    @MainActor
    private static func clearExistingPlannerData(in context: ModelContext) throws {
        try context.delete(model: Event.self)
        try context.delete(model: CalendarLink.self)
    }
}
