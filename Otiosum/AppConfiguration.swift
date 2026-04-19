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
            PlannableItem.self,
            CalendarLink.self,
            DayTemplate.self,
            DailyBudget.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isUITesting
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            try seedDefaultsIfNeeded(in: context)

            if isUITesting {
                try seedUITestData(in: context)
            }

            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    @MainActor
    static func seedDefaultsIfNeeded(in context: ModelContext) throws {
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
            PlannableItem(
                title: "Write proposal",
                kind: .task,
                source: .local,
                suggestedIcon: focusIcon.symbolName,
                tintToken: focusIcon.tintToken,
                targetDurationMinutes: 45,
                minimumDurationMinutes: 30,
                scheduledDay: today,
                preferredStartMinutes: max(template.wakeUpMinutes + 30, 9 * 60),
                preferredTimeWindow: .morning,
                flexibility: .flexible,
                isInJar: false
            )
        )

        context.insert(
            PlannableItem(
                title: "Call therapist",
                kind: .event,
                source: .local,
                suggestedIcon: callIcon.symbolName,
                tintToken: callIcon.tintToken,
                targetDurationMinutes: 30,
                minimumDurationMinutes: 30,
                scheduledDay: today,
                preferredStartMinutes: 15 * 60,
                preferredTimeWindow: .afternoon,
                flexibility: .askBeforeMove,
                isInJar: false
            )
        )

        context.insert(
            PlannableItem(
                title: "Relax",
                kind: .task,
                source: .local,
                suggestedIcon: relaxIcon.symbolName,
                tintToken: relaxIcon.tintToken,
                targetDurationMinutes: 30,
                minimumDurationMinutes: 20,
                scheduledDay: today,
                preferredStartMinutes: 18 * 60,
                preferredTimeWindow: .evening,
                flexibility: .flexible,
                isInJar: false
            )
        )

        context.insert(
            PlannableItem(
                title: "Idea garden",
                kind: .idea,
                source: .local,
                suggestedIcon: ideaIcon.symbolName,
                tintToken: ideaIcon.tintToken,
                targetDurationMinutes: 30,
                minimumDurationMinutes: 15,
                scheduledDay: nil,
                preferredStartMinutes: nil,
                preferredTimeWindow: .anytime,
                flexibility: .flexible,
                isInJar: true
            )
        )

        if hasDeterministicTimelineTask {
            let now = Date.now
            let currentMinutes = now.minutesSinceStartOfDay(using: .current)
            let roundedMinutes = ((currentMinutes + 2) / 5) * 5
            let timelineIcon = IconSuggester.suggest(for: "UI timeline task")

            context.insert(
                PlannableItem(
                    title: "UI Timeline Task",
                    kind: .task,
                    source: .local,
                    suggestedIcon: timelineIcon.symbolName,
                    tintToken: timelineIcon.tintToken,
                    targetDurationMinutes: 30,
                    minimumDurationMinutes: 15,
                    scheduledDay: today,
                    preferredStartMinutes: roundedMinutes,
                    preferredTimeWindow: .anytime,
                    flexibility: .flexible,
                    isInJar: false
                )
            )
        }

        try context.save()
    }

    @MainActor
    private static func clearExistingPlannerData(in context: ModelContext) throws {
        try context.delete(model: PlannableItem.self)
        try context.delete(model: CalendarLink.self)
    }
}
