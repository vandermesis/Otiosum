import Foundation
import SwiftData
import Testing
@testable import Otiosum

@MainActor
struct PlannerStoreTests {
    @Test("Seed data inserts default template and budget once")
    func ensureSeedDataIsIdempotent() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()

        try store.ensureSeedData(in: modelContext)
        try store.ensureSeedData(in: modelContext)

        let templates = try modelContext.fetch(FetchDescriptor<DayTemplate>())
        let budgets = try modelContext.fetch(FetchDescriptor<DailyBudget>())

        #expect(templates.count == 1)
        #expect(budgets.count == 1)
        #expect(store.didSeedDefaults)
    }

    @Test("Calendar refresh interval covers the visible timeline range")
    func calendarRefreshIntervalCoversVisibleTimelineRange() throws {
        let store = PlannerStore()
        let calendar = Calendar.current
        let selectedDay = try #require(calendar.date(from: DateComponents(year: 2026, month: 4, day: 22)))

        let interval = store.calendarRefreshInterval(around: selectedDay)

        #expect(interval.start == calendar.date(byAdding: .day, value: -3, to: selectedDay))
        #expect(interval.end == calendar.date(byAdding: .day, value: 4, to: selectedDay))
    }

    @Test("Archiving quick capture creates an unscheduled archived event and clears input")
    func archiveQuickEvent() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()
        try store.ensureSeedData(in: modelContext)

        store.todayQuickCapture = "read chapter"
        store.archiveQuickEvent(modelContext: modelContext)

        let items = try modelContext.fetch(FetchDescriptor<Event>())
        let item = try #require(items.first)

        #expect(item.title == "Read chapter")
        #expect(item.isArchived)
        #expect(item.scheduledDay == nil)
        #expect(item.preferredStartMinutes == nil)
        #expect(item.preferredTimeWindow == .anytime)
        #expect(store.todayQuickCapture.isEmpty)
    }

    @Test("Applying archive overflow choice updates event and clears pending state")
    func applyOverflowChoiceArchive() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()
        let item = Event(
            title: "Late task",
            suggestedIcon: "moon.stars",
            tintToken: "indigo",
            scheduledDay: Date(timeIntervalSinceReferenceDate: 60_000),
            isArchived: false,
            forceAfterBedtime: true
        )
        modelContext.insert(item)
        try modelContext.save()

        store.pendingOverflow = PendingOverflowState(
            itemID: item.id,
            title: item.title,
            message: "Not enough room",
            suggestedDate: Date(timeIntervalSinceReferenceDate: 70_000),
            displacedCategory: .sleep,
            defaultChoice: .nextSuitableDay
        )

        store.applyOverflowChoice(.returnToJar, modelContext: modelContext)

        #expect(item.isArchived)
        #expect(item.scheduledDay == nil)
        #expect(item.forceAfterBedtime == false)
        #expect(store.pendingOverflow == nil)
    }

    @Test("Applying keep-anyway overflow choice keeps item scheduled on selected day")
    func applyOverflowChoiceKeepAnyway() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()
        let selectedDay = Date(timeIntervalSinceReferenceDate: 80_000)
        store.selectedDay = selectedDay

        let item = Event(
            title: "Packed evening",
            suggestedIcon: "calendar",
            tintToken: "sky",
            scheduledDay: nil,
            isArchived: true,
            forceAfterBedtime: false
        )
        modelContext.insert(item)
        try modelContext.save()

        store.pendingOverflow = PendingOverflowState(
            itemID: item.id,
            title: item.title,
            message: "Not enough room",
            suggestedDate: Date(timeIntervalSinceReferenceDate: 81_000),
            displacedCategory: .sleep,
            defaultChoice: .nextSuitableDay
        )

        store.applyOverflowChoice(.keepAnyway, modelContext: modelContext)

        #expect(item.scheduledDay == selectedDay)
        #expect(item.forceAfterBedtime)
        #expect(item.isArchived == false)
        #expect(store.pendingOverflow == nil)
    }

    @Test("Rescheduling event updates day, start, and clears archive state")
    func rescheduleEventUpdatesTimingFields() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()

        let start = Date(timeIntervalSinceReferenceDate: 100_000)
        let item = Event(
            title: "Move me",
            suggestedIcon: "calendar",
            tintToken: "sky",
            scheduledDay: nil,
            preferredStartMinutes: nil,
            isArchived: true,
            forceAfterBedtime: true
        )

        modelContext.insert(item)
        try modelContext.save()

        store.rescheduleEvent(item, to: start, modelContext: modelContext)

        let calendar = Calendar.current
        #expect(item.scheduledDay == calendar.startOfDay(for: start))
        #expect(item.preferredStartMinutes == start.minutesSinceStartOfDay(using: calendar))
        #expect(item.isArchived == false)
        #expect(item.forceAfterBedtime == false)
    }

    @Test("Today quick capture uses selected start minutes")
    func captureQuickItemFromTodayUsesSelectedStart() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()
        try store.ensureSeedData(in: modelContext)

        let day = Calendar.current.startOfDay(for: Date(timeIntervalSinceReferenceDate: 120_000))
        let preferredStart = Calendar.current.date(byAdding: .minute, value: 14 * 60 + 30, to: day) ?? day
        store.todayQuickCapture = "plan sprint"

        store.captureQuickEvent(
            modelContext: modelContext,
            day: day,
            template: .default,
            preferredStartDate: preferredStart
        )

        let items = try modelContext.fetch(FetchDescriptor<Event>())
        let item = try #require(items.first)

        #expect(item.title == "Plan sprint")
        #expect(item.scheduledDay == day)
        #expect(item.preferredStartMinutes == 14 * 60 + 30)
        #expect(item.preferredTimeWindow == .afternoon)
    }

    @Test("Adjusting item duration clamps to valid bounds")
    func adjustItemDurationClamps() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()

        let item = Event(
            title: "Stretch duration",
            suggestedIcon: "clock",
            tintToken: "sky",
            targetDurationMinutes: 30,
            minimumDurationMinutes: 15
        )
        modelContext.insert(item)
        try modelContext.save()

        store.adjustDuration(for: item, by: 300, modelContext: modelContext)
        #expect(item.targetDurationMinutes == 240)

        store.adjustDuration(for: item, by: -400, modelContext: modelContext)
        #expect(item.targetDurationMinutes == 15)
    }

    @Test("Starting event now reschedules and clears completion")
    func startEventNowReschedules() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()

        let originalDate = Date(timeIntervalSinceReferenceDate: 130_000)
        let item = Event(
            title: "Start now task",
            suggestedIcon: "play.fill",
            tintToken: "mint",
            scheduledDay: originalDate,
            preferredStartMinutes: 8 * 60,
            isCompleted: true,
            isArchived: true
        )
        modelContext.insert(item)
        try modelContext.save()

        let start = Date(timeIntervalSinceReferenceDate: 140_000)
        store.startEventNow(item, at: start, modelContext: modelContext)

        let calendar = Calendar.current
        #expect(item.scheduledDay == calendar.startOfDay(for: start))
        #expect(item.preferredStartMinutes == start.minutesSinceStartOfDay(using: calendar))
        #expect(item.isCompleted == false)
        #expect(item.isArchived == false)
    }

    @Test("Quick add from Today uses provided timeline anchor and configured default duration")
    func captureQuickItemFromTodayUsesAnchorAndDuration() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()
        try store.ensureSeedData(in: modelContext)

        let day = Calendar.current.startOfDay(for: Date(timeIntervalSinceReferenceDate: 160_000))
        let anchor = Calendar.current.date(byAdding: .hour, value: 14, to: day) ?? day
        store.todayQuickCapture = "focus block"
        store.captureQuickEvent(
            modelContext: modelContext,
            day: day,
            template: .default,
            defaultDurationMinutes: 45,
            preferredStartDate: anchor
        )

        let items = try modelContext.fetch(FetchDescriptor<Event>())
        let item = try #require(items.first)
        #expect(item.title == "Focus block")
        #expect(item.scheduledDay == day)
        #expect(item.preferredStartMinutes == anchor.minutesSinceStartOfDay(using: .current))
        #expect(item.targetDurationMinutes == 45)
        #expect(store.todayQuickCapture.isEmpty)
    }

    @Test("Archiving quick event creates archived event from today input")
    func archiveQuickEventFromTodayInput() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()
        try store.ensureSeedData(in: modelContext)

        store.todayQuickCapture = "someday maybe"
        store.archiveQuickEvent(modelContext: modelContext)

        let items = try modelContext.fetch(FetchDescriptor<Event>())
        let item = try #require(items.first)
        #expect(item.title == "Someday maybe")
        #expect(item.isArchived)
        #expect(item.scheduledDay == nil)
        #expect(store.todayQuickCapture.isEmpty)
    }

    @Test("Refresh prompts picks the first overflow and first shift proposal")
    func refreshPromptsSelectsFirstEntries() throws {
        let store = PlannerStore()
        let now = Date(timeIntervalSinceReferenceDate: 90_000)

        let overflow1 = OverflowIssue(
            itemID: UUID(),
            title: "Overflow one",
            message: "First",
            displacedCategory: .sleep,
            suggestedDate: now
        )
        let overflow2 = OverflowIssue(
            itemID: UUID(),
            title: "Overflow two",
            message: "Second",
            displacedCategory: .rest,
            suggestedDate: now.adding(minutes: 60)
        )

        let shift1 = CalendarShiftProposal(
            calendarEventID: "A",
            title: "Event A",
            currentStart: now,
            currentEnd: now.adding(minutes: 30),
            suggestedStart: now.adding(minutes: 15),
            suggestedEnd: now.adding(minutes: 45)
        )
        let shift2 = CalendarShiftProposal(
            calendarEventID: "B",
            title: "Event B",
            currentStart: now,
            currentEnd: now.adding(minutes: 30),
            suggestedStart: now.adding(minutes: 20),
            suggestedEnd: now.adding(minutes: 50)
        )

        let plan = DayPlan(
            day: now,
            allBlocks: [],
            nowBlock: nil,
            nextBlock: nil,
            laterBlocks: [],
            protectedBlocks: [],
            warnings: [],
            overflowIssues: [overflow1, overflow2],
            shiftProposals: [shift1, shift2],
            budgetSummary: BudgetUsageSummary(workMinutes: 0, restMinutes: 0, sleepMinutesProtected: 0, scheduledCount: 0)
        )

        let modelContext = try makeModelContext()
        store.refreshPrompts(for: plan, modelContext: modelContext)

        #expect(store.pendingOverflow?.itemID == overflow1.itemID)
        #expect(store.pendingCalendarShift?.proposal.calendarEventID == "A")
    }

    private func makeModelContext() throws -> ModelContext {
        let schema = Schema([
            Item.self,
            Event.self,
            CalendarLink.self,
            DayTemplate.self,
            DailyBudget.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }
}
