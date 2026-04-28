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

    @Test("Saving quick capture for Later creates an unscheduled Later event and clears input")
    func saveQuickEventForLater() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()
        try store.ensureSeedData(in: modelContext)

        store.todayQuickCapture = "read chapter"
        store.saveQuickEventForLater(modelContext: modelContext)

        let items = try modelContext.fetch(FetchDescriptor<Event>())
        let item = try #require(items.first)

        #expect(item.title == "Read chapter")
        #expect(item.isSavedForLater)
        #expect(item.scheduledDay == nil)
        #expect(item.preferredStartMinutes == nil)
        #expect(item.preferredTimeWindow == .anytime)
        #expect(store.todayQuickCapture.isEmpty)
    }

    @Test("Applying save-for-Later Too Much Today choice updates event and clears pending state")
    func applyTooMuchTodayChoiceSaveForLater() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()
        let item = Event(
            title: "Late task",
            suggestedIcon: "moon.stars",
            tintToken: "indigo",
            scheduledDay: Date(timeIntervalSinceReferenceDate: 60_000),
            isSavedForLater: false,
            forceAfterBedtime: true
        )
        modelContext.insert(item)
        try modelContext.save()

        store.pendingTooMuchToday = PendingTooMuchTodayState(
            itemID: item.id,
            title: item.title,
            message: "Not enough room",
            suggestedDate: Date(timeIntervalSinceReferenceDate: 70_000),
            displacedCategory: .sleep,
            defaultChoice: .nextSuitableDay
        )

        store.applyTooMuchTodayChoice(.saveForLater, modelContext: modelContext)

        #expect(item.isSavedForLater)
        #expect(item.scheduledDay == nil)
        #expect(item.forceAfterBedtime == false)
        #expect(store.pendingTooMuchToday == nil)
    }

    @Test("Applying keep-anyway overflow choice keeps item scheduled on selected day")
    func applyTooMuchTodayChoiceKeepAnyway() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()
        let selectedDay = Date(timeIntervalSinceReferenceDate: 80_000)
        store.selectedDay = selectedDay

        let item = Event(
            title: "Packed evening",
            suggestedIcon: "calendar",
            tintToken: "sky",
            scheduledDay: nil,
            isSavedForLater: true,
            forceAfterBedtime: false
        )
        modelContext.insert(item)
        try modelContext.save()

        store.pendingTooMuchToday = PendingTooMuchTodayState(
            itemID: item.id,
            title: item.title,
            message: "Not enough room",
            suggestedDate: Date(timeIntervalSinceReferenceDate: 81_000),
            displacedCategory: .sleep,
            defaultChoice: .nextSuitableDay
        )

        store.applyTooMuchTodayChoice(.keepAnyway, modelContext: modelContext)

        #expect(item.scheduledDay == selectedDay)
        #expect(item.forceAfterBedtime)
        #expect(item.isSavedForLater == false)
        #expect(store.pendingTooMuchToday == nil)
    }

    @Test("Applying move-another-day overflow choice reschedules item and clears archive state")
    func applyTooMuchTodayChoiceMoveAnotherDay() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()
        let suggestedDate = Date(timeIntervalSinceReferenceDate: 82_000)
        let item = Event(
            title: "Move me tomorrow",
            suggestedIcon: "calendar",
            tintToken: "sky",
            scheduledDay: nil,
            preferredStartMinutes: 21 * 60,
            isSavedForLater: true,
            forceAfterBedtime: true
        )
        modelContext.insert(item)
        try modelContext.save()

        store.pendingTooMuchToday = PendingTooMuchTodayState(
            itemID: item.id,
            title: item.title,
            message: "Not enough room",
            suggestedDate: suggestedDate,
            displacedCategory: .rest,
            defaultChoice: .nextSuitableDay
        )

        store.applyTooMuchTodayChoice(.nextSuitableDay, modelContext: modelContext)

        #expect(item.scheduledDay == suggestedDate)
        #expect(item.preferredStartMinutes == nil)
        #expect(item.isSavedForLater == false)
        #expect(item.forceAfterBedtime == false)
        #expect(store.pendingTooMuchToday == nil)
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
            isSavedForLater: true,
            forceAfterBedtime: true
        )

        modelContext.insert(item)
        try modelContext.save()

        store.rescheduleEvent(item, to: start, modelContext: modelContext)

        let calendar = Calendar.current
        #expect(item.scheduledDay == calendar.startOfDay(for: start))
        #expect(item.preferredStartMinutes == start.minutesSinceStartOfDay(using: calendar))
        #expect(item.isSavedForLater == false)
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
            isSavedForLater: true
        )
        modelContext.insert(item)
        try modelContext.save()

        let start = Date(timeIntervalSinceReferenceDate: 140_000)
        store.startEventNow(item, at: start, modelContext: modelContext)

        let calendar = Calendar.current
        #expect(item.scheduledDay == calendar.startOfDay(for: start))
        #expect(item.preferredStartMinutes == start.minutesSinceStartOfDay(using: calendar))
        #expect(item.isCompleted == false)
        #expect(item.isSavedForLater == false)
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

    @Test("Saving quick event for Later creates Later event from today input")
    func saveQuickEventForLaterFromTodayInput() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()
        try store.ensureSeedData(in: modelContext)

        store.todayQuickCapture = "later maybe"
        store.saveQuickEventForLater(modelContext: modelContext)

        let items = try modelContext.fetch(FetchDescriptor<Event>())
        let item = try #require(items.first)
        #expect(item.title == "Later maybe")
        #expect(item.isSavedForLater)
        #expect(item.scheduledDay == nil)
        #expect(store.todayQuickCapture.isEmpty)
    }

    @Test("Restoring a Later item assigns it to Today and the chosen lane")
    func restoreLaterEventUsesChosenLane() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()
        let day = Calendar.current.startOfDay(for: Date(timeIntervalSinceReferenceDate: 170_000))
        let item = Event(
            title: "Read later",
            suggestedIcon: "book",
            tintToken: "sky",
            scheduledDay: nil,
            preferredStartMinutes: nil,
            isSavedForLater: true
        )
        modelContext.insert(item)
        try modelContext.save()

        store.restoreLaterEvent(item, lane: .evening, on: day, modelContext: modelContext)

        #expect(item.isSavedForLater == false)
        #expect(item.scheduledDay == day)
        #expect(item.preferredTimeWindow == .evening)
        #expect(item.preferredStartMinutes == PreferredTimeWindow.evening.startMinutes)
        #expect(item.forceAfterBedtime == false)
    }

    @Test("Refresh prompts picks the first Too Much Today issue and first shift proposal")
    func refreshPromptsSelectsFirstEntries() throws {
        let store = PlannerStore()
        let now = Date(timeIntervalSinceReferenceDate: 90_000)

        let tooMuchTodayIssue1 = TooMuchTodayIssue(
            itemID: UUID(),
            title: "Too much today one",
            message: "First",
            displacedCategory: .sleep,
            suggestedDate: now
        )
        let tooMuchTodayIssue2 = TooMuchTodayIssue(
            itemID: UUID(),
            title: "Too much today two",
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
            tooMuchTodayIssues: [tooMuchTodayIssue1, tooMuchTodayIssue2],
            shiftProposals: [shift1, shift2],
            budgetSummary: BudgetUsageSummary(workMinutes: 0, restMinutes: 0, sleepMinutesProtected: 0, scheduledCount: 0)
        )

        let modelContext = try makeModelContext()
        store.refreshPrompts(for: plan, modelContext: modelContext)

        #expect(store.pendingTooMuchToday?.itemID == tooMuchTodayIssue1.itemID)
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
