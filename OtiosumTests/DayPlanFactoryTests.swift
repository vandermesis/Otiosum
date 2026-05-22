import Foundation
import Testing
@testable import Otiosum

struct DayPlanFactoryTests {
    @Test("Factory classifies blocks and deduplicates issues")
    func classifiesBlocksAndDeduplicatesIssues() {
        let day = Date(timeIntervalSinceReferenceDate: 900_000)
        let now = day.adding(minutes: 9 * 60 + 15)
        let currentBlock = block(title: "Current", start: day.adding(minutes: 9 * 60), duration: 30)
        let nextBlock = block(title: "Next", start: day.adding(minutes: 10 * 60), duration: 30)
        let itemID = UUID()
        let issues = [
            issue(itemID: itemID, title: "First", date: day),
            issue(itemID: itemID, title: "Duplicate", date: day.adding(minutes: 10))
        ]

        let plan = DayPlanFactory().makePlan(
            day: day,
            blocks: [nextBlock, currentBlock],
            tooMuchTodayIssues: issues,
            shiftProposals: [],
            budget: .default,
            template: .default,
            sleepBoundary: day.adding(minutes: 22 * 60),
            context: InferenceContext(now: now, isSceneActive: true, lastUserInteraction: now)
        )

        #expect(plan.nowBlock?.id == currentBlock.id)
        #expect(plan.nextBlock?.id == nextBlock.id)
        #expect(plan.tooMuchTodayIssues.map(\.title) == ["First"])
        #expect(plan.budgetSummary.scheduledCount == 2)
    }

    @Test("Factory builds warnings from budget and sleep pressure")
    func buildsWarningsFromBudgetAndSleepPressure() {
        let day = Date(timeIntervalSinceReferenceDate: 900_000)
        let sleepBoundary = day.adding(minutes: 22 * 60)
        let lateBlock = block(title: "Late", start: sleepBoundary.adding(minutes: 10), duration: 30)
        let budget = DailyBudgetSnapshot(
            minimumSleepHours: 8,
            minimumRestMinutes: 60,
            targetWorkMinutes: 15,
            maxFocusItems: 0,
            mealDurationMinutes: 40,
            workoutTargetMinutes: 45,
            quickAddDefaultDurationMinutes: 30,
            lowNotificationMode: true,
            useSimplifiedMode: false
        )

        let plan = DayPlanFactory().makePlan(
            day: day,
            blocks: [lateBlock],
            tooMuchTodayIssues: [],
            shiftProposals: [],
            budget: budget,
            template: .default,
            sleepBoundary: sleepBoundary,
            context: InferenceContext(now: day.adding(minutes: 8 * 60), isSceneActive: true, lastUserInteraction: nil)
        )

        #expect(plan.warnings.contains { $0.message == "This day is carrying a lot." })
        #expect(plan.warnings.contains { $0.message == "This is already a full list." })
        #expect(plan.warnings.contains { $0.message == "Protect sleep?" })
    }

    private func block(title: String, start: Date, duration: Int) -> PlannedBlock {
        PlannedBlock(
            id: UUID(),
            itemID: UUID(),
            calendarEventID: nil,
            title: title,
            start: start,
            end: start.adding(minutes: duration),
            source: .local,
            flexibility: .flexible,
            symbolName: "circle",
            tintToken: "teal",
            notes: "",
            isAllDay: false,
            routineRole: nil,
            isCompleted: false,
            status: .upcoming,
            confidence: 0.7
        )
    }

    private func issue(itemID: UUID, title: String, date: Date) -> TooMuchTodayIssue {
        TooMuchTodayIssue(
            itemID: itemID,
            title: title,
            message: "Too much",
            displacedRole: .sleep,
            suggestedDate: date
        )
    }
}
