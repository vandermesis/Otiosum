import SwiftData
import SwiftUI

struct PlannerShellView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \PlannableItem.createdAt) private var items: [PlannableItem]
    @Query(sort: \CalendarLink.updatedAt) private var calendarLinks: [CalendarLink]
    @Query(sort: \DayTemplate.key) private var templates: [DayTemplate]
    @Query(sort: \DailyBudget.key) private var budgets: [DailyBudget]

    @State private var viewModel = PlannerShellViewModel()

    private var template: DayTemplate? { templates.first }
    private var budget: DailyBudget? { budgets.first }
    private var templateSnapshot: DayTemplateSnapshot { viewModel.templateSnapshot(from: templates) }
    private var budgetSnapshot: DailyBudgetSnapshot { viewModel.budgetSnapshot(from: budgets) }
    private var itemLookup: [UUID: PlannableItem] { viewModel.itemLookup(from: items) }

    private var selectedDayPlan: DayPlan {
        viewModel.makeSelectedDayPlan(
            items: items,
            calendarLinks: calendarLinks,
            template: templateSnapshot,
            budget: budgetSnapshot,
            sceneIsActive: scenePhase == .active
        )
    }

    private var upcomingPlans: [(Date, DayPlan)] {
        viewModel.makeUpcomingPlans(
            items: items,
            calendarLinks: calendarLinks,
            template: templateSnapshot,
            budget: budgetSnapshot,
            sceneIsActive: scenePhase == .active
        )
    }

    private var somedayItems: [PlannableItem] {
        items.filter { $0.isInJar || $0.scheduledDay == nil }
    }

    private var promptKey: String {
        viewModel.promptKey(for: selectedDayPlan)
    }

    var body: some View {
        Group {
            if template == nil || budget == nil {
                ProgressView("Preparing planner")
                    .task {
                        try? viewModel.ensureSeedData(in: modelContext)
                    }
            } else {
                TabView(selection: selectedTabBinding) {
                    TodayScreen(
                        day: selectedDayBinding,
                        quickCapture: todayQuickCaptureBinding,
                        plan: selectedDayPlan,
                        budget: budgetSnapshot,
                        calendarService: viewModel.calendarService,
                        somedayItems: somedayItems,
                        onRequestCalendarAccess: {
                            Task {
                                await viewModel.requestCalendarAccess()
                            }
                        },
                        onCapture: {
                            viewModel.captureQuickItem(
                                from: .today,
                                modelContext: modelContext,
                                template: templateSnapshot
                            )
                        },
                        onScheduleSomedayItem: { item, lane in
                            viewModel.scheduleJarItem(
                                item: item,
                                lane: lane,
                                modelContext: modelContext
                            )
                        },
                        onDropSomedayItem: { itemID, date in
                            guard let item = itemLookup[itemID] else { return false }
                            viewModel.scheduleSomedayItem(item, at: date, modelContext: modelContext)
                            return true
                        },
                        onRescheduleBlock: { block, start in
                            viewModel.rescheduleBlock(
                                block,
                                to: start,
                                itemLookup: itemLookup,
                                modelContext: modelContext
                            )
                        }
                    )
                    .tag(PlannerTab.today)
                    .tabItem {
                        Label("Now", systemImage: "sun.max.fill")
                    }

                    FutureScreen(
                        plans: upcomingPlans,
                        budget: budgetSnapshot,
                        calendarService: viewModel.calendarService
                    )
                    .tag(PlannerTab.upcoming)
                    .tabItem {
                        Label("Future", systemImage: "calendar")
                    }

                    if let template, let budget {
                        SettingsScreen(
                            template: template,
                            budget: budget,
                            calendarService: viewModel.calendarService
                        )
                        .tag(PlannerTab.settings)
                        .tabItem {
                            Label("Settings", systemImage: "slider.horizontal.3")
                        }
                    }
                }
                .tint(.black)
                .background(PlannerBackground(simple: budgetSnapshot.useSimplifiedMode))
                .highPriorityGesture(tabSwipeGesture)
            }
        }
        .task {
            try? viewModel.ensureSeedData(in: modelContext)
            await viewModel.refreshCalendar()
        }
        .task(id: viewModel.selectedDay) {
            await viewModel.refreshCalendar()
        }
        .task(id: promptKey) {
            viewModel.refreshPrompts(for: selectedDayPlan, modelContext: modelContext)
        }
        .onChange(of: scenePhase) { _, _ in
            viewModel.registerInteraction()
        }
        .sheet(item: pendingOverflowBinding) { pendingOverflow in
            OverflowDecisionSheet(
                state: pendingOverflow,
                onChoose: { choice in
                    viewModel.applyOverflowChoice(choice, modelContext: modelContext)
                }
            )
        }
        .sheet(item: pendingCalendarShiftBinding) { pendingCalendarShift in
            CalendarShiftDecisionSheet(
                state: pendingCalendarShift,
                onChoose: { decision in
                    Task {
                        await viewModel.applyCalendarDecision(decision, modelContext: modelContext)
                    }
                }
            )
        }
    }

    private var selectedDayBinding: Binding<Date> {
        Binding(
            get: { viewModel.selectedDay },
            set: { viewModel.selectedDay = $0 }
        )
    }

    private var todayQuickCaptureBinding: Binding<String> {
        Binding(
            get: { viewModel.todayQuickCapture },
            set: { viewModel.todayQuickCapture = $0 }
        )
    }

    private var selectedTabBinding: Binding<PlannerTab> {
        Binding(
            get: { viewModel.selectedTab },
            set: {
                viewModel.selectedTab = $0
                viewModel.registerInteraction()
            }
        )
    }

    private var tabSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }

                if value.translation.width < -60 {
                    moveToAdjacentTab(forward: true)
                } else if value.translation.width > 60 {
                    moveToAdjacentTab(forward: false)
                }
            }
    }

    private func moveToAdjacentTab(forward: Bool) {
        let allTabs: [PlannerTab] = [.today, .upcoming, .settings]
        guard let currentIndex = allTabs.firstIndex(of: viewModel.selectedTab) else { return }

        let nextIndex = forward ? currentIndex + 1 : currentIndex - 1
        guard allTabs.indices.contains(nextIndex) else { return }

        viewModel.selectedTab = allTabs[nextIndex]
        viewModel.registerInteraction()
    }

    private var pendingOverflowBinding: Binding<PendingOverflowState?> {
        Binding(
            get: { viewModel.pendingOverflow },
            set: { viewModel.pendingOverflow = $0 }
        )
    }

    private var pendingCalendarShiftBinding: Binding<PendingCalendarShiftState?> {
        Binding(
            get: { viewModel.pendingCalendarShift },
            set: { viewModel.pendingCalendarShift = $0 }
        )
    }
}
