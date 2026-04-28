import SwiftUI

struct TodayScreen: View {
    @Binding var day: Date

    let plan: DayPlan
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
                TodayHeaderOverlay(
                    day: day,
                    plan: plan,
                    onOpenLater: onOpenLater,
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

private struct TodayHeaderOverlay: View {
    let day: Date
    let plan: DayPlan
    let onOpenLater: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today")
                        .font(.system(.largeTitle, design: .rounded).bold())
                    Text(day.formatted(.dateTime.weekday(.wide).day().month()))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button("Settings", systemImage: "gearshape") {
                        onOpenSettings()
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(width: 48, height: 48)
                    .clipShape(.circle)
                    .accessibilityIdentifier("today-open-settings")

                    Button("Later", systemImage: "archivebox") {
                        onOpenLater()
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(width: 48, height: 48)
                    .clipShape(.circle)
                    .accessibilityIdentifier("today-open-later")
                }
            }

            TodayStatusCard(plan: plan)
        }
    }
}

private struct TodayStatusCard: View {
    let plan: DayPlan

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(plan.nowBlock == nil ? "Open right now" : "Now")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(plan.nowBlock?.title ?? "There is room to start gently.")
                    .font(.headline)
                if let nowBlock = plan.nowBlock {
                    Text(timeRange(for: nowBlock))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(plan.nextBlock == nil ? "Later" : "Next")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(plan.nextBlock?.title ?? "Nothing urgent is queued.")
                    .font(.subheadline)
                    .multilineTextAlignment(.trailing)
                if plan.warnings.isEmpty == false {
                    Text("\(plan.warnings.count) gentle check\(plan.warnings.count == 1 ? "" : "s")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: .rect(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.48), lineWidth: 1)
        }
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
