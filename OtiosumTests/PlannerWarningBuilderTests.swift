import Foundation
import Testing
@testable import Otiosum

struct PlannerWarningBuilderTests {
    @Test("Warning builder reports overload and sleep pressure")
    func reportsOverloadAndSleepPressure() {
        let day = Date(timeIntervalSinceReferenceDate: 600_000)
        let sleepBoundary = day.adding(minutes: 22 * 60)
        let lateBlock = block(title: "Late", start: sleepBoundary.adding(minutes: 10), duration: 30)
        let issue = TooMuchTodayIssue(
            itemID: UUID(),
            title: "Late",
            message: "Too much",
            displacedRole: .sleep,
            suggestedDate: day.adding(minutes: 24 * 60)
        )
        let summary = BudgetUsageSummary(
            workMinutes: 500,
            restMinutes: 20,
            sleepMinutesRoutine: 480,
            scheduledCount: 8
        )

        let warnings = PlannerWarningBuilder().makeWarnings(
            blocks: [lateBlock],
            tooMuchTodayIssues: [issue],
            shiftProposals: [],
            budgetSummary: summary,
            budget: .default,
            template: .default,
            sleepBoundary: sleepBoundary
        )

        #expect(warnings.contains { $0.message == "Not enough room today." })
        #expect(warnings.contains { $0.message == "This day is carrying a lot." })
        #expect(warnings.contains { $0.message == "This is already a full list." })
        #expect(warnings.contains { $0.message == "Protect sleep?" })
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
}
