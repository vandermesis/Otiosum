import SwiftUI

struct TodayScreen: View {
    @Binding var day: Date

    let plan: DayPlan
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
        ZStack {
            PlannerBackground(simple: budget.useSimplifiedMode)

            VStack(spacing: 14) {
                PlannerMainHeader(
                    day: day,
                    plan: plan,
                    onOpenArchive: onOpenArchive,
                    onOpenSettings: onOpenSettings
                )
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
                    onRescheduleBlock: onRescheduleBlock,
                    onAdjustBlockDuration: onAdjustBlockDuration,
                    onQuickAction: onQuickAction,
                    onCenterDateChanged: onCenterDateChanged
                )
                .padding(.horizontal, 18)
            }
        }
    }
}

private struct PlannerMainHeader: View {
    let day: Date
    let plan: DayPlan
    let onOpenArchive: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Now")
                    .font(.largeTitle.bold())
                Text(day.formatted(.dateTime.weekday(.wide).day().month()))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let nowBlock = plan.nowBlock {
                PlannerHeaderStatus(block: nowBlock)
            }

            HStack(spacing: 8) {
                Button("Archive", systemImage: "archivebox") {
                    onOpenArchive()
                }
                .buttonStyle(.bordered)
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier("now-open-someday")

                Button("Settings", systemImage: "gearshape") {
                    onOpenSettings()
                }
                .buttonStyle(.bordered)
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier("now-open-settings")
            }
        }
    }
}

private struct PlannerHeaderStatus: View {
    let block: PlannedBlock

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Label(block.title, systemImage: block.symbolName)
                .font(.caption)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.thinMaterial, in: Capsule())
                .accessibilityLabel("Current task: \(block.title)")

            Text("Active")
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.thinMaterial, in: Capsule())
                .accessibilityLabel("A task is active")
        }
    }
}

private struct NowTimelineSection: View {
    let day: Date
    let plan: DayPlan
    let onDropSomedayItem: (UUID, Date) -> Bool
    let onRescheduleBlock: (PlannedBlock, Date) -> Void
    let onAdjustBlockDuration: (PlannedBlock, Int) -> Void
    let onQuickAction: (PlannedBlock, TimelineQuickAction) -> Void
    let onCenterDateChanged: (Date) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TimeWheelView(
                day: day,
                blocks: plan.allBlocks,
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
            .frame(maxWidth: .infinity)
            .frame(minHeight: 560)
            .containerRelativeFrame(.vertical, count: 100, span: 72, spacing: 0)
            .clipShape(.rect(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.62), lineWidth: 1)
            )
        }
        .padding(1)
        .background(.white.opacity(0.28), in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 18, y: 10)
    }
}
