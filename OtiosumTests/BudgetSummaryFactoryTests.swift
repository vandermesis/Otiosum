import Foundation
import Testing
@testable import Otiosum

struct BudgetSummaryFactoryTests {
    @Test("Budget summary counts incomplete timed work and routine rest")
    func countsIncompleteTimedWorkAndRoutineRest() {
        let start = Date(timeIntervalSinceReferenceDate: 500_000)
        let blocks = [
            block(title: "Focus", start: start, duration: 45),
            block(title: "Done", start: start.adding(minutes: 60), duration: 30, isCompleted: true),
            block(title: "Recovery", start: start.adding(minutes: 120), duration: 40, routineRole: .rest),
            block(title: "All day", start: start, duration: 24 * 60, isAllDay: true)
        ]

        let summary = BudgetSummaryFactory().makeSummary(blocks: blocks, budget: .default)

        #expect(summary.workMinutes == 85)
        #expect(summary.restMinutes == 40)
        #expect(summary.sleepMinutesRoutine == 480)
        #expect(summary.scheduledCount == 2)
    }

    private func block(
        title: String,
        start: Date,
        duration: Int,
        routineRole: RoutineRole? = nil,
        isCompleted: Bool = false,
        isAllDay: Bool = false
    ) -> PlannedBlock {
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
            isAllDay: isAllDay,
            routineRole: routineRole,
            isCompleted: isCompleted,
            status: isCompleted ? .complete : .upcoming,
            confidence: 0.7
        )
    }
}
