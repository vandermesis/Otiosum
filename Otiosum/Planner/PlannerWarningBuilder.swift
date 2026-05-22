import Foundation

struct PlannerWarningBuilder {
    func makeWarnings(
        blocks: [PlannedBlock],
        tooMuchTodayIssues: [TooMuchTodayIssue],
        shiftProposals: [CalendarShiftProposal],
        budgetSummary: BudgetUsageSummary,
        budget: DailyBudgetSnapshot,
        template: DayTemplateSnapshot,
        sleepBoundary: Date
    ) -> [GuardrailWarning] {
        var warnings: [GuardrailWarning] = []

        if tooMuchTodayIssues.isEmpty == false {
            warnings.append(
                GuardrailWarning(
                    message: "Not enough room today.",
                    detail: "Otiosum found items that would cut into sleep or recovery. You can move them gently instead of squeezing more in.",
                    severity: .attention
                )
            )
        }

        if shiftProposals.isEmpty == false {
            warnings.append(
                GuardrailWarning(
                    message: "A calendar shift needs your choice.",
                    detail: "A synced event was moved in the local plan so the day stays calm. Decide whether to keep that change local or update Calendar too.",
                    severity: .calm
                )
            )
        }

        if budgetSummary.workMinutes > budget.targetWorkMinutes {
            warnings.append(
                GuardrailWarning(
                    message: "This day is carrying a lot.",
                    detail: "Planned work is above the target. Protecting recovery may make tomorrow feel easier.",
                    severity: .calm
                )
            )
        }

        if budgetSummary.scheduledCount > budget.maxFocusItems {
            warnings.append(
                GuardrailWarning(
                    message: "This is already a full list.",
                    detail: "Consider leaving some ideas for later so the timeline stays gentle.",
                    severity: .calm
                )
            )
        }

        let afterSleep = blocks.filter { $0.end > sleepBoundary }
        if afterSleep.isEmpty == false {
            warnings.append(
                GuardrailWarning(
                    message: "Protect sleep?",
                    detail: "Some items drifted past bedtime. Otiosum can move them instead of packing the night tighter.",
                    severity: .attention
                )
            )
        }

        if template.quietDurationMinutes < budget.minimumRestMinutes {
            warnings.append(
                GuardrailWarning(
                    message: "Quiet time is below the rest target.",
                    detail: "You can expand recovery time in Settings whenever the day feels too compressed.",
                    severity: .calm
                )
            )
        }

        return warnings
    }
}
