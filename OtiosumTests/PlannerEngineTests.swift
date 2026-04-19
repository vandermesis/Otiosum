import Foundation
import SwiftData
import Testing
@testable import Otiosum

struct PlannerEngineTests {
    private let engine = PlannerEngine(calendar: PlannerEngineTests.calendar)

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }()

    @Test("Planner keeps scheduled blocks from overlapping")
    func scheduleAvoidsCollisions() throws {
        let day = try makeDate(year: 2026, month: 4, day: 20, hour: 0, minute: 0)
        let items = [
            EventSnapshot(
                id: UUID(),
                title: "Write",
                source: .local,
                suggestedIcon: "laptopcomputer",
                tintToken: "teal",
                targetDurationMinutes: 60,
                minimumDurationMinutes: 30,
                scheduledDay: day,
                preferredStartMinutes: 9 * 60,
                preferredTimeWindow: .morning,
                flexibility: .flexible,
                calendarEventID: nil,
                protectedCategory: nil,
                notes: "",
                isCompleted: false,
                orderHint: 1,
                isArchived: false,
                forceAfterBedtime: false
            ),
            EventSnapshot(
                id: UUID(),
                title: "Reply",
                source: .local,
                suggestedIcon: "envelope",
                tintToken: "sky",
                targetDurationMinutes: 30,
                minimumDurationMinutes: 15,
                scheduledDay: day,
                preferredStartMinutes: 9 * 60 + 30,
                preferredTimeWindow: .morning,
                flexibility: .flexible,
                calendarEventID: nil,
                protectedCategory: nil,
                notes: "",
                isCompleted: false,
                orderHint: 2,
                isArchived: false,
                forceAfterBedtime: false
            )
        ]

        let plan = engine.plan(
            for: day,
            localItems: items,
            calendarEvents: [],
            calendarLinks: [],
            template: .default,
            budget: .default,
            context: InferenceContext(now: day.adding(minutes: 8 * 60), isSceneActive: true, lastUserInteraction: day.adding(minutes: 8 * 60))
        )

        let nonProtectedBlocks = plan.allBlocks.filter { $0.isProtected == false }
        for pair in zip(nonProtectedBlocks, nonProtectedBlocks.dropFirst()) {
            #expect(pair.0.end <= pair.1.start)
        }
    }

    @Test("Overrun shifts later flexible work and creates a calendar shift proposal")
    func overrunShiftsLaterBlocks() throws {
        let day = try makeDate(year: 2026, month: 4, day: 20, hour: 0, minute: 0)
        let activeItemID = UUID()
        let trailingItemID = UUID()

        let items = [
            EventSnapshot(
                id: activeItemID,
                title: "Deep focus",
                source: .local,
                suggestedIcon: "laptopcomputer",
                tintToken: "teal",
                targetDurationMinutes: 30,
                minimumDurationMinutes: 30,
                scheduledDay: day,
                preferredStartMinutes: 10 * 60,
                preferredTimeWindow: .morning,
                flexibility: .flexible,
                calendarEventID: nil,
                protectedCategory: nil,
                notes: "",
                isCompleted: false,
                orderHint: 1,
                isArchived: false,
                forceAfterBedtime: false
            ),
            EventSnapshot(
                id: trailingItemID,
                title: "Inbox",
                source: .local,
                suggestedIcon: "tray.full",
                tintToken: "mint",
                targetDurationMinutes: 30,
                minimumDurationMinutes: 15,
                scheduledDay: day,
                preferredStartMinutes: 10 * 60 + 45,
                preferredTimeWindow: .morning,
                flexibility: .flexible,
                calendarEventID: nil,
                protectedCategory: nil,
                notes: "",
                isCompleted: false,
                orderHint: 2,
                isArchived: false,
                forceAfterBedtime: false
            )
        ]

        let calendarEvent = CalendarEventSnapshot(
            id: "calendar-1",
            title: "Check-in",
            start: day.adding(minutes: 11 * 60),
            end: day.adding(minutes: 11 * 60 + 30),
            notes: "",
            isAllDay: false
        )

        let plan = engine.plan(
            for: day,
            localItems: items,
            calendarEvents: [calendarEvent],
            calendarLinks: [
                CalendarLinkSnapshot(
                    id: UUID(),
                    calendarEventID: "calendar-1",
                    flexibility: .askBeforeMove,
                    editPolicy: .askEveryTime,
                    localOverrideStart: nil,
                    localOverrideEnd: nil
                )
            ],
            template: .default,
            budget: .default,
            context: InferenceContext(
                now: day.adding(minutes: 11 * 60 + 10),
                isSceneActive: true,
                lastUserInteraction: day.adding(minutes: 11 * 60 + 8)
            )
        )

        let activeBlock = try #require(plan.allBlocks.first(where: { $0.itemID == activeItemID }))
        let trailingBlock = try #require(plan.allBlocks.first(where: { $0.itemID == trailingItemID }))

        #expect(activeBlock.end > day.adding(minutes: 10 * 60 + 30))
        #expect(trailingBlock.start >= activeBlock.end)
        #expect(plan.shiftProposals.contains(where: { $0.calendarEventID == "calendar-1" }))
    }

    @Test("Planner warns when a new item would cut into bedtime")
    func bedtimeOverflowProducesWarning() throws {
        let day = try makeDate(year: 2026, month: 4, day: 20, hour: 0, minute: 0)
        let lateItem = EventSnapshot(
            id: UUID(),
            title: "Late task",
            source: .local,
            suggestedIcon: "moon.stars",
            tintToken: "indigo",
            targetDurationMinutes: 120,
            minimumDurationMinutes: 60,
            scheduledDay: day,
            preferredStartMinutes: 21 * 60 + 30,
            preferredTimeWindow: .night,
            flexibility: .flexible,
            calendarEventID: nil,
            protectedCategory: nil,
            notes: "",
            isCompleted: false,
            orderHint: 1,
            isArchived: false,
            forceAfterBedtime: false
        )

        let plan = engine.plan(
            for: day,
            localItems: [lateItem],
            calendarEvents: [],
            calendarLinks: [],
            template: .default,
            budget: .default,
            context: InferenceContext(now: day.adding(minutes: 20 * 60), isSceneActive: true, lastUserInteraction: day.adding(minutes: 20 * 60))
        )

        #expect(plan.overflowIssues.contains(where: { $0.itemID == lateItem.id }))
        #expect(plan.warnings.contains(where: { $0.message == "Not enough room today." }))
    }

    @MainActor
    @Test("Quick capture from Today creates a scheduled 30 minute item")
    func quickCaptureDefaults() throws {
        let schema = Schema([
            Item.self,
            Event.self,
            CalendarLink.self,
            DayTemplate.self,
            DailyBudget.self
        ])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let store = PlannerStore()

        try store.ensureSeedData(in: context)
        store.todayQuickCapture = "walk"

        store.captureQuickEvent(
            modelContext: context,
            day: PlannerEngineTests.calendar.startOfDay(for: .now),
            template: .default
        )

        let items = try context.fetch(FetchDescriptor<Event>())
        let captured = try #require(items.first)

        #expect(captured.title == "Walk")
        #expect(captured.targetDurationMinutes == 30)
        #expect(captured.isArchived == false)
        #expect(captured.scheduledDay != nil)
    }

    @Test("Icon suggestion is deterministic for calming categories")
    func iconSuggestionMapping() {
        let suggestion = IconSuggester.suggest(for: "sleep early")
        #expect(suggestion.symbolName == "bed.double.fill")
        #expect(suggestion.tintToken == "indigo")
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) throws -> Date {
        try #require(
            Self.calendar.date(
                from: DateComponents(
                    calendar: Self.calendar,
                    timeZone: Self.calendar.timeZone,
                    year: year,
                    month: month,
                    day: day,
                    hour: hour,
                    minute: minute
                )
            )
        )
    }
}
