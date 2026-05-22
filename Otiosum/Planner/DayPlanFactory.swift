import Foundation

struct DayPlanFactory {
    private let issueDeduplicator: TooMuchTodayIssueDeduplicator

    init(issueDeduplicator: TooMuchTodayIssueDeduplicator = TooMuchTodayIssueDeduplicator()) {
        self.issueDeduplicator = issueDeduplicator
    }

    func makePlan(
        day: Date,
        blocks: [PlannedBlock],
        tooMuchTodayIssues: [TooMuchTodayIssue],
        shiftProposals: [CalendarShiftProposal],
        budget: DailyBudgetSnapshot,
        template: DayTemplateSnapshot,
        sleepBoundary: Date,
        context: InferenceContext
    ) -> DayPlan {
        let budgetSummary = BudgetSummaryFactory().makeSummary(
            blocks: blocks,
            budget: budget
        )

        let warnings = PlannerWarningBuilder().makeWarnings(
            blocks: blocks,
            tooMuchTodayIssues: tooMuchTodayIssues,
            shiftProposals: shiftProposals,
            budgetSummary: budgetSummary,
            budget: budget,
            template: template,
            sleepBoundary: sleepBoundary
        )

        let classification = TimelineBlockClassifier().classify(
            blocks: blocks,
            now: context.now
        )

        return DayPlan(
            day: day,
            allBlocks: blocks,
            nowBlock: classification.nowBlock,
            nextBlock: classification.nextBlock,
            laterBlocks: classification.laterBlocks,
            warnings: warnings,
            tooMuchTodayIssues: issueDeduplicator.deduplicate(tooMuchTodayIssues),
            shiftProposals: shiftProposals,
            budgetSummary: budgetSummary
        )
    }
}
