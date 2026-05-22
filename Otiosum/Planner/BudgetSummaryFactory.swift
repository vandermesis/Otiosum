import Foundation

struct BudgetSummaryFactory {
    func makeSummary(
        blocks: [PlannedBlock],
        budget: DailyBudgetSnapshot
    ) -> BudgetUsageSummary {
        let workMinutes = blocks
            .filter { $0.isAllDay == false && $0.isCompleted == false }
            .reduce(0) { $0 + $1.durationMinutes }
        let restMinutes = blocks
            .filter { $0.routineRole == .rest }
            .reduce(0) { $0 + $1.durationMinutes }
        let sleepMinutesRoutine = Int(budget.minimumSleepHours * 60)
        let scheduledCount = blocks.filter { $0.isAllDay == false && $0.isCompleted == false }.count

        return BudgetUsageSummary(
            workMinutes: workMinutes,
            restMinutes: restMinutes,
            sleepMinutesRoutine: sleepMinutesRoutine,
            scheduledCount: scheduledCount
        )
    }
}
