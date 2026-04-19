import SwiftUI

struct TodayScreen: View {
    @Binding var day: Date

    let plan: DayPlan
    let budget: DailyBudgetSnapshot
    let calendarService: SystemCalendarService
    let timelineDraft: TimelineDraftTask?
    let onRequestCalendarAccess: () -> Void
    let onDropSomedayItem: (UUID, Date) -> Bool
    let onRescheduleBlock: (PlannedBlock, Date) -> Void
    let onAdjustBlockDuration: (PlannedBlock, Int) -> Void
    let onQuickAction: (PlannedBlock, TimelineQuickAction) -> Void
    let onTimelineDraftMoved: (Date) -> Void
    let onConfirmTimelineDraft: () -> Void
    let onCancelTimelineDraft: () -> Void

    var body: some View {
        ZStack {
            PlannerBackground(simple: budget.useSimplifiedMode)

            VStack(spacing: 12) {
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
                    timelineDraft: timelineDraft,
                    onDropSomedayItem: onDropSomedayItem,
                    onRescheduleBlock: onRescheduleBlock,
                    onAdjustBlockDuration: onAdjustBlockDuration,
                    onQuickAction: onQuickAction,
                    onTimelineDraftMoved: onTimelineDraftMoved,
                    onConfirmTimelineDraft: onConfirmTimelineDraft,
                    onCancelTimelineDraft: onCancelTimelineDraft
                )
                .padding(.horizontal, 18)
            }
        }
    }
}

private struct NowTimelineSection: View {
    let day: Date
    let plan: DayPlan
    let timelineDraft: TimelineDraftTask?
    let onDropSomedayItem: (UUID, Date) -> Bool
    let onRescheduleBlock: (PlannedBlock, Date) -> Void
    let onAdjustBlockDuration: (PlannedBlock, Int) -> Void
    let onQuickAction: (PlannedBlock, TimelineQuickAction) -> Void
    let onTimelineDraftMoved: (Date) -> Void
    let onConfirmTimelineDraft: () -> Void
    let onCancelTimelineDraft: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TimeWheelView(
                day: day,
                blocks: plan.allBlocks,
                warnings: plan.warnings,
                currentBlockID: plan.nowBlock?.id,
                nextBlockID: plan.nextBlock?.id,
                showsHeader: false,
                timelineDraft: timelineDraft,
                onDropSomedayItem: onDropSomedayItem,
                onRescheduleBlock: onRescheduleBlock,
                onAdjustBlockDuration: onAdjustBlockDuration,
                onQuickAction: onQuickAction,
                onTimelineDraftMoved: onTimelineDraftMoved
            )
            .frame(minHeight: 620)
            .clipShape(.rect(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
            )

            if timelineDraft != nil {
                HStack(spacing: 10) {
                    Button("Cancel", systemImage: "xmark.circle", action: onCancelTimelineDraft)
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("timeline-draft-cancel")

                    Button("Place Task", systemImage: "checkmark.circle.fill", action: onConfirmTimelineDraft)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("timeline-draft-confirm")
                }
            }
        }
    }
}
