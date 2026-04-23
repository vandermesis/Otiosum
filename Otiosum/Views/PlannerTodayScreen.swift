import SwiftUI

struct TodayScreen: View {
    @Binding var day: Date

    let plan: DayPlan
    let timelineBlocks: [PlannedBlock]
    let budget: DailyBudgetSnapshot
    let calendarService: SystemCalendarService
    let onOpenArchive: () -> Void
    let onOpenSettings: () -> Void
    let onRequestCalendarAccess: () -> Void
    let onDropSomedayItem: (UUID, Date) -> Bool
    let onRescheduleBlock: (PlannedBlock, Date) -> Void
    let onAdjustBlockDuration: (PlannedBlock, Int) -> Void
    let onQuickAction: (PlannedBlock, TimelineQuickAction) -> Void
    let onCenterDateChanged: (Date) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            PlannerBackground(simple: budget.useSimplifiedMode)

            NowTimelineSection(
                day: day,
                plan: plan,
                timelineBlocks: timelineBlocks,
                onDropSomedayItem: onDropSomedayItem,
                onRescheduleBlock: onRescheduleBlock,
                onAdjustBlockDuration: onAdjustBlockDuration,
                onQuickAction: onQuickAction,
                onCenterDateChanged: onCenterDateChanged
            )
            .ignoresSafeArea(edges: .vertical)

            VStack(spacing: 10) {
                TimelineActionOverlay(
                    onOpenArchive: onOpenArchive,
                    onOpenSettings: onOpenSettings
                )

                if calendarService.canReadEvents == false {
                    PlannerMessageCard(
                        title: "Calendar is optional",
                        message: "Connect it when you want protected synced events to appear in the timeline.",
                        actionTitle: "Connect Calendar",
                        action: onRequestCalendarAccess
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

private struct TimelineActionOverlay: View {
    let onOpenArchive: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button("Archive", systemImage: "archivebox") {
                onOpenArchive()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .frame(width: 44, height: 44)
            .accessibilityIdentifier("now-open-someday")

            Button("Settings", systemImage: "gearshape") {
                onOpenSettings()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .frame(width: 44, height: 44)
            .accessibilityIdentifier("now-open-settings")
        }
        .padding(6)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(0.48), lineWidth: 1)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct NowTimelineSection: View {
    let day: Date
    let plan: DayPlan
    let timelineBlocks: [PlannedBlock]
    let onDropSomedayItem: (UUID, Date) -> Bool
    let onRescheduleBlock: (PlannedBlock, Date) -> Void
    let onAdjustBlockDuration: (PlannedBlock, Int) -> Void
    let onQuickAction: (PlannedBlock, TimelineQuickAction) -> Void
    let onCenterDateChanged: (Date) -> Void

    var body: some View {
        TimeWheelView(
            day: day,
            blocks: timelineBlocks,
            warnings: plan.warnings,
            currentBlockID: plan.nowBlock?.id,
            nextBlockID: plan.nextBlock?.id,
            showsHeader: false,
            onDropSomedayItem: onDropSomedayItem,
            onRescheduleBlock: onRescheduleBlock,
            onAdjustBlockDuration: onAdjustBlockDuration,
            onQuickAction: onQuickAction,
            onCenterDateChanged: onCenterDateChanged
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
