import Foundation
import Testing
@testable import Otiosum

@MainActor
struct PlannerViewModelTests {

    // MARK: - Helpers

    private var calendar: Calendar { .current }

    private func date(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func emptyBudgetSummary() -> BudgetUsageSummary {
        BudgetUsageSummary(
            workMinutes: 0,
            restMinutes: 0,
            sleepMinutesRoutine: 0,
            scheduledCount: 0
        )
    }

    private func makeDayPlan(
        day: Date = Date(timeIntervalSinceReferenceDate: 0),
        warnings: [GuardrailWarning] = [],
        tooMuchTodayIssues: [TooMuchTodayIssue] = [],
        shiftProposals: [CalendarShiftProposal] = []
    ) -> DayPlan {
        DayPlan(
            day: day,
            allBlocks: [],
            nowBlock: nil,
            nextBlock: nil,
            laterBlocks: [],
            warnings: warnings,
            tooMuchTodayIssues: tooMuchTodayIssues,
            shiftProposals: shiftProposals,
            budgetSummary: emptyBudgetSummary()
        )
    }

    private func makeWarning(message: String = "warn") -> GuardrailWarning {
        GuardrailWarning(message: message, detail: "", severity: .calm)
    }

    private func makeIssue(itemID: UUID, suggestedDate: Date = .distantFuture) -> TooMuchTodayIssue {
        TooMuchTodayIssue(
            itemID: itemID,
            title: "issue",
            message: "",
            displacedRole: nil,
            suggestedDate: suggestedDate
        )
    }

    private func makeShift(calendarEventID: String) -> CalendarShiftProposal {
        let now = Date(timeIntervalSinceReferenceDate: 0)
        return CalendarShiftProposal(
            calendarEventID: calendarEventID,
            title: "shift",
            currentStart: now,
            currentEnd: now.addingTimeInterval(1_800),
            suggestedStart: now.addingTimeInterval(3_600),
            suggestedEnd: now.addingTimeInterval(5_400)
        )
    }

    // MARK: - makePromptKey

    @Test("Prompt key for an empty plan is the canonical neutral string")
    func promptKeyForEmptyPlan() {
        let viewModel = PlannerViewModel()
        let plan = makeDayPlan()

        #expect(viewModel.makePromptKey(for: plan) == "||0")
    }

    @Test("Prompt key encodes issue itemIDs, shift IDs, and warning count")
    func promptKeyEncodesFields() {
        let viewModel = PlannerViewModel()
        let firstIssue = UUID()
        let secondIssue = UUID()
        let plan = makeDayPlan(
            warnings: [makeWarning(), makeWarning(message: "two")],
            tooMuchTodayIssues: [makeIssue(itemID: firstIssue), makeIssue(itemID: secondIssue)],
            shiftProposals: [makeShift(calendarEventID: "cal-1"), makeShift(calendarEventID: "cal-2")]
        )

        let expected = "\(firstIssue.uuidString),\(secondIssue.uuidString)|cal-1,cal-2|2"
        #expect(viewModel.makePromptKey(for: plan) == expected)
    }

    @Test("Prompt key is deterministic across repeated calls with the same plan")
    func promptKeyIsDeterministic() {
        let viewModel = PlannerViewModel()
        let plan = makeDayPlan(
            warnings: [makeWarning()],
            tooMuchTodayIssues: [makeIssue(itemID: UUID())],
            shiftProposals: [makeShift(calendarEventID: "evt")]
        )

        #expect(viewModel.makePromptKey(for: plan) == viewModel.makePromptKey(for: plan))
    }

    @Test("Prompt key differs when warning count or contents change")
    func promptKeyIsSensitiveToChanges() {
        let viewModel = PlannerViewModel()
        let sharedIssueID = UUID()
        let basePlan = makeDayPlan(
            warnings: [makeWarning()],
            tooMuchTodayIssues: [makeIssue(itemID: sharedIssueID)],
            shiftProposals: [makeShift(calendarEventID: "evt")]
        )

        let extraWarning = makeDayPlan(
            warnings: [makeWarning(), makeWarning(message: "second")],
            tooMuchTodayIssues: [makeIssue(itemID: sharedIssueID)],
            shiftProposals: [makeShift(calendarEventID: "evt")]
        )
        let differentIssue = makeDayPlan(
            warnings: [makeWarning()],
            tooMuchTodayIssues: [makeIssue(itemID: UUID())],
            shiftProposals: [makeShift(calendarEventID: "evt")]
        )
        let differentShift = makeDayPlan(
            warnings: [makeWarning()],
            tooMuchTodayIssues: [makeIssue(itemID: sharedIssueID)],
            shiftProposals: [makeShift(calendarEventID: "other-evt")]
        )

        let baseKey = viewModel.makePromptKey(for: basePlan)
        #expect(baseKey != viewModel.makePromptKey(for: extraWarning))
        #expect(baseKey != viewModel.makePromptKey(for: differentIssue))
        #expect(baseKey != viewModel.makePromptKey(for: differentShift))
    }

    // MARK: - makeUpcomingPlans

    @Test("Upcoming plans honour a custom dayCount")
    func upcomingPlansHonourCustomDayCount() {
        let viewModel = PlannerViewModel()
        let selectedDay = date(year: 2026, month: 5, day: 22)
        let context = InferenceContext(now: selectedDay, isSceneActive: true, lastUserInteraction: nil)

        let threeDay = viewModel.makeUpcomingPlans(
            selectedDay: selectedDay,
            items: [],
            calendarLinks: [],
            template: .default,
            budget: .default,
            calendarEventsForDay: { _ in [] },
            contextForDay: { _ in context },
            dayCount: 3
        )

        #expect(threeDay.count == 3)
        #expect(threeDay.first?.0 == calendar.startOfDay(for: selectedDay))
        #expect(threeDay.last?.0 == calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: selectedDay)))

        let fourteenDay = viewModel.makeUpcomingPlans(
            selectedDay: selectedDay,
            items: [],
            calendarLinks: [],
            template: .default,
            budget: .default,
            calendarEventsForDay: { _ in [] },
            contextForDay: { _ in context },
            dayCount: 14
        )
        #expect(fourteenDay.count == 14)
    }

    @Test("Upcoming plans return an empty array for a zero dayCount")
    func upcomingPlansAreEmptyForZeroDayCount() {
        let viewModel = PlannerViewModel()
        let selectedDay = date(year: 2026, month: 5, day: 22)
        let context = InferenceContext(now: selectedDay, isSceneActive: true, lastUserInteraction: nil)

        let plans = viewModel.makeUpcomingPlans(
            selectedDay: selectedDay,
            items: [],
            calendarLinks: [],
            template: .default,
            budget: .default,
            calendarEventsForDay: { _ in [] },
            contextForDay: { _ in context },
            dayCount: 0
        )

        #expect(plans.isEmpty)
    }

    @Test("Upcoming plans pass the day under generation to the calendar and context closures")
    func upcomingPlansForwardDayToClosures() {
        let viewModel = PlannerViewModel()
        let selectedDay = date(year: 2026, month: 5, day: 22)
        let context = InferenceContext(now: selectedDay, isSceneActive: true, lastUserInteraction: nil)
        let expectedDays = (0..<5).compactMap {
            calendar.date(byAdding: .day, value: $0, to: calendar.startOfDay(for: selectedDay))
        }

        var receivedDays: [Date] = []
        _ = viewModel.makeUpcomingPlans(
            selectedDay: selectedDay,
            items: [],
            calendarLinks: [],
            template: .default,
            budget: .default,
            calendarEventsForDay: { day in
                receivedDays.append(day)
                return []
            },
            contextForDay: { _ in context },
            dayCount: 5
        )

        #expect(receivedDays == expectedDays)
    }

    // MARK: - itemLookup

    @Test("Item lookup keys events by id")
    func itemLookupKeysByID() {
        let viewModel = PlannerViewModel()
        let first = Event(title: "First", suggestedIcon: "star", tintToken: "blue")
        let second = Event(title: "Second", suggestedIcon: "moon", tintToken: "purple")

        let lookup = viewModel.itemLookup(from: [first, second])

        #expect(lookup.count == 2)
        #expect(lookup[first.id] === first)
        #expect(lookup[second.id] === second)
    }

    @Test("Item lookup of an empty array returns an empty dictionary")
    func itemLookupHandlesEmptyInput() {
        let viewModel = PlannerViewModel()
        #expect(viewModel.itemLookup(from: []).isEmpty)
    }
}
