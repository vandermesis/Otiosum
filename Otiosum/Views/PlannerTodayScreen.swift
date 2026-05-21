import SwiftUI

struct TodayScreen: View {
    @Binding var day: Date

    let plan: DayPlan
    let timelineTitleDate: Date
    let timelineBlocks: [PlannedBlock]
    let budget: DailyBudgetSnapshot
    let calendarService: SystemCalendarService
    let onOpenLater: () -> Void
    let onOpenSettings: () -> Void
    let onRequestCalendarAccess: () -> Void
    let onDropLaterItem: (UUID, Date) -> Bool
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
                onDropLaterItem: onDropLaterItem,
                onRescheduleBlock: onRescheduleBlock,
                onAdjustBlockDuration: onAdjustBlockDuration,
                onQuickAction: onQuickAction,
                onCenterDateChanged: onCenterDateChanged
            )
            .ignoresSafeArea(edges: .vertical)

            VStack(spacing: 10) {
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
        .navigationTitle(timelineTitleDate.formatted(.dateTime.weekday(.wide).day().month()))
        .navigationSubtitle(navigationSubtitle(for: plan))
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Settings", systemImage: "gearshape") {
                    onOpenSettings()
                }
                .accessibilityIdentifier("today-open-settings")

                Button("Later", systemImage: "archivebox") {
                    onOpenLater()
                }
                .accessibilityIdentifier("today-open-later")
            }
        }
    }

    private func navigationSubtitle(for plan: DayPlan) -> String {
        guard let nowBlock = plan.nowBlock else {
            return "Open right now: There is room to start gently."
        }

        return "Now: \(nowBlock.title), \(timeRange(for: nowBlock))"
    }

    private func timeRange(for block: PlannedBlock) -> String {
        "\(block.start.formatted(.dateTime.hour().minute())) - \(block.end.formatted(.dateTime.hour().minute()))"
    }
}

private struct NowTimelineSection: View {
    let day: Date
    let plan: DayPlan
    let timelineBlocks: [PlannedBlock]
    let onDropLaterItem: (UUID, Date) -> Bool
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
            onDropLaterItem: onDropLaterItem,
            onRescheduleBlock: onRescheduleBlock,
            onAdjustBlockDuration: onAdjustBlockDuration,
            onQuickAction: onQuickAction,
            onCenterDateChanged: onCenterDateChanged
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
