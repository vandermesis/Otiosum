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
    @State private var isSomedaySheetPresented = false
    @State private var isSettingsPresented = false
    @State private var timelineCenterDate = Date.now
    @State private var isSearchPresented = false

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
                NavigationStack {
                    TodayScreen(
                        day: selectedDayBinding,
                        plan: selectedDayPlan,
                        budget: budgetSnapshot,
                        calendarService: viewModel.calendarService,
                        onRequestCalendarAccess: {
                            Task {
                                await viewModel.requestCalendarAccess()
                            }
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
                        },
                        onAdjustBlockDuration: { block, deltaMinutes in
                            viewModel.adjustDuration(
                                for: block,
                                by: deltaMinutes,
                                itemLookup: itemLookup,
                                modelContext: modelContext
                            )
                        },
                        onQuickAction: { block, action in
                            switch action {
                            case .startNow:
                                viewModel.markStartedNow(
                                    for: block,
                                    itemLookup: itemLookup,
                                    modelContext: modelContext
                                )
                            case .markDone:
                                viewModel.setCompletion(
                                    for: block,
                                    isCompleted: true,
                                    itemLookup: itemLookup,
                                    modelContext: modelContext
                                )
                            case .markUndone:
                                viewModel.setCompletion(
                                    for: block,
                                    isCompleted: false,
                                    itemLookup: itemLookup,
                                    modelContext: modelContext
                                )
                            }
                        },
                        onCenterDateChanged: { centerDate in
                            timelineCenterDate = centerDate
                        }
                    )
                    .toolbar {
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            Button("Someday", systemImage: "archivebox") {
                                isSomedaySheetPresented = true
                            }
                            .accessibilityIdentifier("now-open-someday")

                            Button("Settings", systemImage: "gearshape") {
                                isSettingsPresented = true
                            }
                            .accessibilityIdentifier("now-open-settings")
                        }
                        ToolbarItemGroup(placement: .bottomBar) {
                            TextField("", text: todayQuickCaptureBinding)

                            Button("Someday", systemImage: "archivebox") {

                            }
                        }


//                        DefaultToolbarItem(kind: .search, placement: .bottomBar)
                    }
                }
                .searchable(
                    text: todayQuickCaptureBinding,
                    isPresented: $isSearchPresented,
                    placement: .toolbar,
                    prompt: "Add"
                )
                .onSubmit(of: .search) {
                    addSearchTextToTimeline(templateSnapshot: templateSnapshot, budgetSnapshot: budgetSnapshot)
                }
                .onChange(of: isSearchPresented) { wasPresented, isPresented in
                    guard wasPresented, isPresented == false else { return }
                    addSearchTextToSomedayIfNeeded()
                }
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
        .sheet(isPresented: $isSomedaySheetPresented) {
            NavigationStack {
                SomedayDrawerContent(items: somedayItems) { item, lane in
                    viewModel.scheduleJarItem(
                        item: item,
                        lane: lane,
                        modelContext: modelContext
                    )
                }
                .padding(16)
                .navigationTitle("Someday")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            isSomedaySheetPresented = false
                        }
                    }
                }
            }
            .presentationDetents([.height(700), .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isSettingsPresented) {
            if let template, let budget {
                NavigationStack {
                    SettingsScreen(
                        template: template,
                        budget: budget,
                        calendarService: viewModel.calendarService
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                isSettingsPresented = false
                            }
                        }
                    }
                }
            }
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

    private func addSearchTextToTimeline(
        templateSnapshot: DayTemplateSnapshot,
        budgetSnapshot: DailyBudgetSnapshot
    ) {
        guard viewModel.todayQuickCapture.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }
        let preferredStartDate = timelineCenterDate.adding(minutes: 5)
        viewModel.captureQuickItem(
            from: .today,
            modelContext: modelContext,
            template: templateSnapshot,
            defaultDurationMinutes: budgetSnapshot.quickAddDefaultDurationMinutes,
            preferredStartDate: preferredStartDate
        )
    }

    private func addSearchTextToSomedayIfNeeded() {
        guard viewModel.todayQuickCapture.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }
        viewModel.addQuickItemToSomeday(modelContext: modelContext)
    }
}
