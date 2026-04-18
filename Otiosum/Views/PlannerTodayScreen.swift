import SwiftUI

struct TodayScreen: View {
    @Binding var day: Date
    @Binding var quickCapture: String

    let plan: DayPlan
    let budget: DailyBudgetSnapshot
    let calendarService: SystemCalendarService
    let somedayItems: [PlannableItem]
    let onRequestCalendarAccess: () -> Void
    let onCapture: () -> Void
    let onScheduleSomedayItem: (PlannableItem, DropLane) -> Void
    let onDropSomedayItem: (UUID, Date) -> Bool
    let onRescheduleBlock: (PlannedBlock, Date) -> Void

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
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

                NowBottomDrawer(
                    quickCapture: $quickCapture,
                    somedayItems: somedayItems,
                    onCapture: onCapture,
                    onScheduleSomedayItem: onScheduleSomedayItem
                )
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

private struct NowBottomDrawer: View {
    @Binding var quickCapture: String
    let somedayItems: [PlannableItem]
    let onCapture: () -> Void
    let onScheduleSomedayItem: (PlannableItem, DropLane) -> Void

    @State private var isExpanded = false
    @State private var mode: DrawerMode = .both

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Quick Actions")
                    .font(.headline)
                Spacer()
                Button(isExpanded ? "Collapse" : "Expand", systemImage: isExpanded ? "chevron.down" : "chevron.up") {
                    withAnimation(.easeInOut(duration: 0.24)) {
                        isExpanded.toggle()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            if isExpanded {
                Picker("Drawer Mode", selection: $mode) {
                    Text("Both").tag(DrawerMode.both)
                    Text("Quick Add").tag(DrawerMode.quickAdd)
                    Text("Someday").tag(DrawerMode.someday)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }

            VStack(spacing: 12) {
                if mode != .someday {
                    HStack(spacing: 10) {
                        TextField("One word is enough", text: $quickCapture)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.done)
                            .onSubmit(onCapture)
                            .accessibilityIdentifier("now-quick-add-field")

                        Button("Add", systemImage: "plus.circle.fill", action: onCapture)
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("now-quick-add-button")
                    }
                }

                if mode != .quickAdd && isExpanded {
                    SomedayDrawerContent(items: somedayItems, onSchedule: onScheduleSomedayItem)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxHeight: isExpanded ? 360 : 120)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
    }
}

private enum DrawerMode: String, CaseIterable, Identifiable {
    case both
    case quickAdd
    case someday

    var id: String { rawValue }
}
