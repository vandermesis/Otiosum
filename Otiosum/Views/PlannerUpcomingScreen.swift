import SwiftUI

struct FutureScreen: View {
    let plans: [(Date, DayPlan)]
    let budget: DailyBudgetSnapshot
    let calendarService: SystemCalendarService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Future")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("A readable forecast with focus blocks, guardrails, and protected energy.")
                        .foregroundStyle(.secondary)

                    if calendarService.isLoading {
                        ProgressView("Refreshing events")
                    }

                    ForEach(plans, id: \.0) { day, plan in
                        FutureDayCard(day: day, plan: plan, budget: budget)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
            }
            .background(PlannerBackground(simple: false))
        }
    }
}

private struct FutureDayCard: View {
    let day: Date
    let plan: DayPlan
    let budget: DailyBudgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(day.formatted(.dateTime.weekday(.wide).day().month()))
                .font(.headline)

            if plan.warnings.isEmpty == false {
                VStack(spacing: 8) {
                    ForEach(plan.warnings) { warning in
                        WarningCard(warning: warning)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Planned blocks")
                    .font(.subheadline.bold())
                if plan.allBlocks.isEmpty {
                    CalmEmptyState(
                        title: "Open space",
                        message: "No blocks scheduled for this day yet."
                    )
                } else {
                    ForEach(plan.allBlocks.prefix(6)) { block in
                        MiniBlockRow(block: block)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Protected & balance")
                    .font(.subheadline.bold())
                BudgetSummaryCard(summary: plan.budgetSummary, budget: budget)
                if plan.protectedBlocks.isEmpty {
                    Text("No upcoming protected blocks")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(plan.protectedBlocks.prefix(4)) { block in
                        MiniBlockRow(block: block)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
        )
    }
}
