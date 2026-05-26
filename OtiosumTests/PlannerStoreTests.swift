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
            displacedRole: .sleep,
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
            displacedRole: .sleep,
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
            displacedRole: .rest,
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

    @Test("Starting template block creates local event")
    func startTemplateBlockCreatesLocalEvent() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()
        let originalStart = Date(timeIntervalSinceReferenceDate: 150_000)
        let block = PlannedBlock(
            id: UUID(),
            itemID: UUID(),
            calendarEventID: nil,
            title: "Breakfast",
            start: originalStart,
            end: originalStart.adding(minutes: 40),
            source: .template,
            flexibility: .locked,
            symbolName: "fork.knife",
            tintToken: "peach",
            notes: "",
            isAllDay: false,
            routineRole: .meal,
            isCompleted: false,
            status: .upcoming,
            confidence: 1
        )
        let start = Date(timeIntervalSinceReferenceDate: 160_000)

        store.startTemplateBlockNow(block, at: start, modelContext: modelContext)

        let items = try modelContext.fetch(FetchDescriptor<Event>())
        let item = try #require(items.first)
        let calendar = Calendar.current
        #expect(items.count == 1)
        #expect(item.title == "Breakfast")
        #expect(item.source == .local)
        #expect(item.routineRole == .meal)
        #expect(item.scheduledDay == calendar.startOfDay(for: start))
        #expect(item.preferredStartMinutes == start.minutesSinceStartOfDay(using: calendar))
        #expect(item.targetDurationMinutes == 40)
    }

    @Test("Starting template block keeps its timeline position")
    func startTemplateBlockKeepsTimelinePosition() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()
        let calendar = Calendar.current
        let blockStart = calendar.date(
            bySettingHour: 12,
            minute: 30,
            second: 0,
            of: Date(timeIntervalSinceReferenceDate: 170_000)
        ) ?? Date(timeIntervalSinceReferenceDate: 170_000)
        let block = PlannedBlock(
            id: UUID(),
            itemID: UUID(),
            calendarEventID: nil,
            title: "Lunch",
            start: blockStart,
            end: blockStart.adding(minutes: 40),
            source: .template,
            flexibility: .locked,
            symbolName: "fork.knife",
            tintToken: "peach",
            notes: "",
            isAllDay: false,
            routineRole: .meal,
            isCompleted: false,
            status: .upcoming,
            confidence: 1
        )

        store.startTemplateBlockNow(block, modelContext: modelContext)

        let item = try #require(try modelContext.fetch(FetchDescriptor<Event>()).first)
        #expect(item.scheduledDay == calendar.startOfDay(for: blockStart))
        #expect(item.preferredStartMinutes == blockStart.minutesSinceStartOfDay(using: calendar))
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
            displacedRole: .sleep,
            suggestedDate: now
        )
        let tooMuchTodayIssue2 = TooMuchTodayIssue(
            itemID: UUID(),
            title: "Too much today two",
            message: "Second",
            displacedRole: .rest,
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
            warnings: [],
            tooMuchTodayIssues: [tooMuchTodayIssue1, tooMuchTodayIssue2],
            shiftProposals: [shift1, shift2],
            budgetSummary: BudgetUsageSummary(workMinutes: 0, restMinutes: 0, sleepMinutesRoutine: 0, scheduledCount: 0)
        )

        let modelContext = try makeModelContext()
        store.refreshPrompts(for: plan, modelContext: modelContext)

        #expect(store.pendingTooMuchToday?.itemID == tooMuchTodayIssue1.itemID)
        #expect(store.pendingCalendarShift?.proposal.calendarEventID == "A")
    }

    @Test("Moving event later adds offset minutes and lifts saved-for-later flag")
    func moveEventLaterAddsOffset() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()
        let day = Calendar.current.startOfDay(for: Date(timeIntervalSinceReferenceDate: 210_000))
        let item = Event(
            title: "Push out",
            suggestedIcon: "clock",
            tintToken: "sky",
            scheduledDay: day,
            preferredStartMinutes: 9 * 60,
            isSavedForLater: true
        )
        modelContext.insert(item)
        try modelContext.save()

        store.moveEventLater(item, by: 45, on: day, modelContext: modelContext)

        #expect(item.scheduledDay == day)
        #expect(item.preferredStartMinutes == 9 * 60 + 45)
        #expect(item.isSavedForLater == false)
    }

    @Test("Moving event later seeds preferred start from now when previously absent")
    func moveEventLaterSeedsStartMinutesWhenNil() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()
        let day = Calendar.current.startOfDay(for: Date(timeIntervalSinceReferenceDate: 220_000))
        let item = Event(
            title: "Free floater",
            suggestedIcon: "clock",
            tintToken: "sky",
            scheduledDay: nil,
            preferredStartMinutes: nil
        )
        modelContext.insert(item)
        try modelContext.save()

        store.moveEventLater(item, on: day, modelContext: modelContext)

        #expect(item.scheduledDay == day)
        let resolved = try #require(item.preferredStartMinutes)
        #expect(resolved >= DayTemplateSnapshot.default.wakeUpMinutes + 30)
    }

    @Test("Toggling completion on an unfinished started event completes it and clears started")
    func toggleCompletionMarksComplete() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()
        let item = Event(
            title: "Wrap up",
            suggestedIcon: "checkmark",
            tintToken: "mint",
            isCompleted: false,
            isStarted: true
        )
        modelContext.insert(item)
        try modelContext.save()

        store.toggleCompletion(item, modelContext: modelContext)

        #expect(item.isCompleted)
        #expect(item.isStarted == false)
    }

    @Test("Toggling a completed event un-completes it without restoring started")
    func toggleCompletionUncompletes() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()
        let item = Event(
            title: "Redo",
            suggestedIcon: "arrow.uturn.left",
            tintToken: "sky",
            isCompleted: true,
            isStarted: false
        )
        modelContext.insert(item)
        try modelContext.save()

        store.toggleCompletion(item, modelContext: modelContext)

        #expect(item.isCompleted == false)
        #expect(item.isStarted == false)
    }

    @Test("setCompletion writes the requested value and clears started when completing")
    func setCompletionForwardsValueAndClearsStarted() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()
        let item = Event(
            title: "Manual finish",
            suggestedIcon: "checkmark",
            tintToken: "mint",
            isCompleted: false,
            isStarted: true
        )
        modelContext.insert(item)
        try modelContext.save()

        store.setCompletion(item, isCompleted: true, modelContext: modelContext)
        #expect(item.isCompleted)
        #expect(item.isStarted == false)

        store.setCompletion(item, isCompleted: false, modelContext: modelContext)
        #expect(item.isCompleted == false)
        #expect(item.isStarted == false)
    }

    @Test("Saving an event for Later clears scheduling and forceAfterBedtime")
    func saveEventForLaterClearsSchedule() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()
        let item = Event(
            title: "Stash",
            suggestedIcon: "tray",
            tintToken: "sage",
            scheduledDay: Date(timeIntervalSinceReferenceDate: 230_000),
            preferredStartMinutes: 14 * 60,
            isSavedForLater: false,
            forceAfterBedtime: true
        )
        modelContext.insert(item)
        try modelContext.save()

        store.saveEventForLater(item, modelContext: modelContext)

        #expect(item.isSavedForLater)
        #expect(item.scheduledDay == nil)
        #expect(item.forceAfterBedtime == false)
    }

    @Test("Updating calendar flexibility creates a CalendarLink when none exists")
    func updateCalendarFlexibilityCreatesLink() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()

        store.updateCalendarFlexibility(
            for: "evt-new",
            title: "Standup",
            flexibility: .locked,
            modelContext: modelContext
        )

        let links = try modelContext.fetch(FetchDescriptor<CalendarLink>())
        let link = try #require(links.first)
        #expect(links.count == 1)
        #expect(link.calendarEventID == "evt-new")
        #expect(link.title == "Standup")
        #expect(link.flexibility == .locked)
    }

    @Test("Updating calendar flexibility updates an existing link, refreshes title and timestamp")
    func updateCalendarFlexibilityUpdatesExistingLink() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()
        let originalUpdate = Date(timeIntervalSinceReferenceDate: 240_000)
        let existing = CalendarLink(
            calendarEventID: "evt-existing",
            title: "Old title",
            flexibility: .askBeforeMove,
            editPolicy: .askEveryTime,
            updatedAt: originalUpdate
        )
        modelContext.insert(existing)
        try modelContext.save()

        store.updateCalendarFlexibility(
            for: "evt-existing",
            title: "New title",
            flexibility: .flexible,
            modelContext: modelContext
        )

        let links = try modelContext.fetch(FetchDescriptor<CalendarLink>())
        #expect(links.count == 1)
        #expect(existing.title == "New title")
        #expect(existing.flexibility == .flexible)
        #expect(existing.updatedAt > originalUpdate)
    }

    @Test("moveOnlyInOtiosum calendar decision writes overrides without touching EventKit")
    func applyCalendarDecisionMoveOnlyInOtiosum() async throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()
        let proposal = CalendarShiftProposal(
            calendarEventID: "evt-move",
            title: "Sync",
            currentStart: Date(timeIntervalSinceReferenceDate: 300_000),
            currentEnd: Date(timeIntervalSinceReferenceDate: 301_800),
            suggestedStart: Date(timeIntervalSinceReferenceDate: 303_600),
            suggestedEnd: Date(timeIntervalSinceReferenceDate: 305_400)
        )
        store.pendingCalendarShift = PendingCalendarShiftState(proposal: proposal)

        await store.applyCalendarDecision(.moveOnlyInOtiosum, modelContext: modelContext)

        let link = try #require(try modelContext.fetch(FetchDescriptor<CalendarLink>()).first)
        #expect(link.calendarEventID == "evt-move")
        #expect(link.flexibility == .flexible)
        #expect(link.editPolicy == .localOnly)
        #expect(link.localOverrideStart == proposal.suggestedStart)
        #expect(link.localOverrideEnd == proposal.suggestedEnd)
        #expect(store.pendingCalendarShift == nil)
    }

    @Test("keepFixed calendar decision locks the link and clears overrides")
    func applyCalendarDecisionKeepFixed() async throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()
        let preexisting = CalendarLink(
            calendarEventID: "evt-keep",
            title: "Sync",
            flexibility: .flexible,
            editPolicy: .localOnly,
            localOverrideStart: Date(timeIntervalSinceReferenceDate: 310_000),
            localOverrideEnd: Date(timeIntervalSinceReferenceDate: 311_800)
        )
        modelContext.insert(preexisting)
        try modelContext.save()

        let proposal = CalendarShiftProposal(
            calendarEventID: "evt-keep",
            title: "Sync",
            currentStart: Date(timeIntervalSinceReferenceDate: 312_000),
            currentEnd: Date(timeIntervalSinceReferenceDate: 313_800),
            suggestedStart: Date(timeIntervalSinceReferenceDate: 314_000),
            suggestedEnd: Date(timeIntervalSinceReferenceDate: 315_800)
        )
        store.pendingCalendarShift = PendingCalendarShiftState(proposal: proposal)

        await store.applyCalendarDecision(.keepFixed, modelContext: modelContext)

        #expect(preexisting.flexibility == .locked)
        #expect(preexisting.editPolicy == .askEveryTime)
        #expect(preexisting.localOverrideStart == nil)
        #expect(preexisting.localOverrideEnd == nil)
        #expect(store.pendingCalendarShift == nil)
    }

    @Test("editRealEvent records an error and clears the prompt when calendar access is denied")
    func applyCalendarDecisionEditRealEventFailure() async throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()
        let proposal = CalendarShiftProposal(
            calendarEventID: "evt-edit",
            title: "Sync",
            currentStart: Date(timeIntervalSinceReferenceDate: 320_000),
            currentEnd: Date(timeIntervalSinceReferenceDate: 321_800),
            suggestedStart: Date(timeIntervalSinceReferenceDate: 322_000),
            suggestedEnd: Date(timeIntervalSinceReferenceDate: 323_800)
        )
        store.pendingCalendarShift = PendingCalendarShiftState(proposal: proposal)

        await store.applyCalendarDecision(.editRealEvent, modelContext: modelContext)

        #expect(store.calendarService.lastErrorMessage != nil)
        let link = try #require(try modelContext.fetch(FetchDescriptor<CalendarLink>()).first)
        #expect(link.localOverrideStart == nil)
        #expect(link.localOverrideEnd == nil)
        #expect(store.pendingCalendarShift == nil)
    }

    @Test(
        "Quick capture maps preferred start hour to its inferred time window",
        arguments: [
            (8, PreferredTimeWindow.morning),
            (11, PreferredTimeWindow.morning),
            (12, PreferredTimeWindow.afternoon),
            (16, PreferredTimeWindow.afternoon),
            (17, PreferredTimeWindow.evening),
            (20, PreferredTimeWindow.evening),
            (21, PreferredTimeWindow.night),
            (23, PreferredTimeWindow.night)
        ]
    )
    func captureQuickEventInferredWindow(hour: Int, expected: PreferredTimeWindow) throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()
        try store.ensureSeedData(in: modelContext)

        let calendar = Calendar.current
        let day = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 400_000))
        let anchor = try #require(calendar.date(byAdding: .hour, value: hour, to: day))

        store.todayQuickCapture = "Window probe \(hour)"
        store.captureQuickEvent(
            modelContext: modelContext,
            day: day,
            template: .default,
            preferredStartDate: anchor
        )

        let item = try #require(try modelContext.fetch(FetchDescriptor<Event>()).first)
        #expect(item.preferredTimeWindow == expected)
    }

    @Test("Started events are completed when their scheduled end passes")
    func completeFinishedStartedEvents() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()
        let now = Date(timeIntervalSinceReferenceDate: 200_000)
        let finished = Event(
            title: "Finished",
            suggestedIcon: "checkmark",
            tintToken: "mint",
            targetDurationMinutes: 30,
            scheduledDay: Calendar.current.startOfDay(for: now),
            preferredStartMinutes: now.adding(minutes: -45).minutesSinceStartOfDay(using: .current),
            isCompleted: false,
            isStarted: true
        )
        let active = Event(
            title: "Active",
            suggestedIcon: "play",
            tintToken: "teal",
            targetDurationMinutes: 30,
            scheduledDay: Calendar.current.startOfDay(for: now),
            preferredStartMinutes: now.adding(minutes: -10).minutesSinceStartOfDay(using: .current),
            isCompleted: false,
            isStarted: true
        )

        modelContext.insert(finished)
        modelContext.insert(active)
        try modelContext.save()

        store.completeFinishedStartedEvents(now: now, modelContext: modelContext)

        #expect(finished.isCompleted)
        #expect(finished.isStarted == false)
        #expect(active.isCompleted == false)
        #expect(active.isStarted)
    }

    private func makeModelContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: OtiosumSchemaV1.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: OtiosumMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }
}
