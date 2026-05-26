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

        if hasDeterministicTimelineTask {
            try seedDeterministicTimelineTask(in: context, template: template, today: today)
            return
        }

        // Use a wall-clock-neutral template so that running UI tests late in the day
        // doesn't surface overdue routine blocks as TooMuchToday sheets that cover
        // the toolbar and block UI interactions.
        applyUITestTemplate(template, in: context)

        // Scheduled-day events are intentionally not seeded here for the same reason:
        // their fixed times would become overdue whenever tests ran past those times.
        let ideaIcon = IconSuggester.suggest(for: "Idea garden")

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

        try context.save()
    }

    @MainActor
    private static func applyUITestTemplate(
        _ template: DayTemplate,
        in context: ModelContext
    ) {
        template.wakeUpMinutes = 0
        template.sleepStartMinutes = 24 * 60
        template.breakfastMinutes = 8 * 60
        template.lunchMinutes = 12 * 60
        template.dinnerMinutes = 18 * 60
        template.quietDurationMinutes = 0
        template.workoutDurationMinutes = 0
        template.includeWorkout = false
        template.transitionBufferMinutes = 0

        if let budget = try? context.fetch(FetchDescriptor<DailyBudget>()).first {
            budget.mealDurationMinutes = 0
        }
    }

    @MainActor
    private static func seedDeterministicTimelineTask(
        in context: ModelContext,
        template: DayTemplate,
        today: Date
    ) throws {
        applyUITestTemplate(template, in: context)

        let now = Date.now
        let currentMinutes = now.minutesSinceStartOfDay(using: .current)
        let startMinutes = min(max(currentMinutes - 5, 0), (24 * 60) - 30)
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
                preferredStartMinutes: startMinutes,
                preferredTimeWindow: .anytime,
                flexibility: .flexible,
                isStarted: true,
                orderHint: -1,
                isSavedForLater: false,
                forceAfterBedtime: true
            )
        )

        try context.save()
    }

    @MainActor
    private static func clearExistingPlannerData(in context: ModelContext) throws {
        try context.delete(model: Event.self)
        try context.delete(model: CalendarLink.self)
    }
}
