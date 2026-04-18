import SwiftUI

struct TodayScreen: View {
    @Binding var day: Date
    @Binding var quickCapture: String

    let plan: DayPlan
    let budget: DailyBudgetSnapshot
    let calendarService: SystemCalendarService
    let onRequestCalendarAccess: () -> Void
    let onCapture: () -> Void
    let onToggleComplete: (PlannedBlock) -> Void
    let onMoveLater: (PlannedBlock) -> Void
    let onReturnToJar: (PlannedBlock) -> Void
    let onCalendarFlexibility: (PlannedBlock, PlannerFlexibility) -> Void
    let onRescheduleBlock: (PlannedBlock, Date) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    DayHeader(day: $day)

                    CaptureComposer(
                        title: "Quick add",
                        placeholder: "One word is enough",
                        text: $quickCapture,
                        buttonTitle: "Place in today",
                        onSubmit: onCapture
                    )

                    if calendarService.canReadEvents == false {
                        PlannerMessageCard(
                            title: "Bring in your calendar when you want",
                            message: "Otiosum already works with local tasks. If you connect Calendar, synced events will be protected in the plan too.",
                            actionTitle: "Connect Calendar",
                            action: onRequestCalendarAccess
                        )
                    }

                    if let nowBlock = plan.nowBlock {
                        SpotlightCard(title: "Now", block: nowBlock)
                    } else {
                        CalmEmptyState(
                            title: "Nothing urgent right now",
                            message: "The planner is keeping some open space."
                        )
                    }

                    if let nextBlock = plan.nextBlock {
                        SpotlightCard(title: "Next", block: nextBlock)
                    }

                    if plan.warnings.isEmpty == false {
                        VStack(spacing: 10) {
                            ForEach(plan.warnings) { warning in
                                WarningCard(warning: warning)
                            }
                        }
                    }

                    TodayTimelineSection(
                        day: day,
                        blocks: plan.allBlocks,
                        onRescheduleBlock: onRescheduleBlock
                    )

                    DropLaneSection()

                    ScheduleSection(
                        title: "Later",
                        subtitle: "Flexible blocks that can move without shame.",
                        blocks: plan.laterBlocks,
                        onToggleComplete: onToggleComplete,
                        onMoveLater: onMoveLater,
                        onReturnToJar: onReturnToJar,
                        onCalendarFlexibility: onCalendarFlexibility
                    )

                    ProtectedTimeSection(plan: plan, budget: budget)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
            }
            .background(PlannerBackground(simple: budget.useSimplifiedMode))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct TodayTimelineSection: View {
    let day: Date
    let blocks: [PlannedBlock]
    let onRescheduleBlock: (PlannedBlock, Date) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Timeline")
                .font(.title3.bold())
            Text("Now stays centered so one glance shows what came before and what is next.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            TimeWheelView(
                day: day,
                blocks: blocks,
                showsHeader: false,
                onRescheduleBlock: onRescheduleBlock
            )
                .frame(height: 540)
                .clipShape(.rect(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
                )
        }
        .padding(16)
        .background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
