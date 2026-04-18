import SwiftUI

struct TodayScreen: View {
    @Binding var day: Date

    let plan: DayPlan
    let budget: DailyBudgetSnapshot
    let calendarService: SystemCalendarService
    let onRequestCalendarAccess: () -> Void
    let onDropSomedayItem: (UUID, Date) -> Bool
    let onRescheduleBlock: (PlannedBlock, Date) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                PlannerBackground(simple: budget.useSimplifiedMode)

                VStack(spacing: 12) {
                    DayHeader(day: $day)
                        .padding(.horizontal, 18)
                        .padding(.top, 10)

                    if calendarService.canReadEvents == false {
                        PlannerMessageCard(
                            title: "Calendar is optional",
                            message: "Connect it when you want protected synced events to appear in the timeline.",
                            actionTitle: "Connect Calendar",
                            action: onRequestCalendarAccess
                        )
                        .padding(.horizontal, 18)
                    }

                    NowTimelineSection(
                        day: day,
                        plan: plan,
                        onDropSomedayItem: onDropSomedayItem,
                        onRescheduleBlock: onRescheduleBlock
                    )
                        .padding(.horizontal, 18)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct NowTimelineSection: View {
    let day: Date
    let plan: DayPlan
    let onDropSomedayItem: (UUID, Date) -> Bool
    let onRescheduleBlock: (PlannedBlock, Date) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Now")
                .font(.title3.bold())
            Text("A single view of what is active, what is next, and where open space is available.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            TimeWheelView(
                day: day,
                blocks: plan.allBlocks,
                warnings: plan.warnings,
                currentBlockID: plan.nowBlock?.id,
                nextBlockID: plan.nextBlock?.id,
                showsHeader: false,
                onDropSomedayItem: onDropSomedayItem,
                onRescheduleBlock: onRescheduleBlock
            )
            .frame(minHeight: 620)
            .clipShape(.rect(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
            )
        }
    }
}
