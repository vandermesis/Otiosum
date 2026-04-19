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
                    Tab("Now", systemImage: "sun.max.fill", value: PlannerTab.today) {
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
                            }
                        )
                    }

                    Tab("Future", systemImage: "calendar", value: PlannerTab.upcoming) {
                        FutureScreen(
                            plans: upcomingPlans,
                            budget: budgetSnapshot,
                            calendarService: viewModel.calendarService
                        )
                    }

                    if let template, let budget {
                        Tab("Settings", systemImage: "slider.horizontal.3", value: PlannerTab.settings) {
                            SettingsScreen(
                                template: template,
                                budget: budget,
                                calendarService: viewModel.calendarService
                            )
                        }
                    }
                }
                .tint(.black)
                .background(PlannerBackground(simple: budgetSnapshot.useSimplifiedMode))
                .highPriorityGesture(tabSwipeGesture)
                .tabViewBottomAccessory(isEnabled: viewModel.selectedTab == .today) {
                    NowQuickActionsAccessory(
                        quickCapture: todayQuickCaptureBinding,
                        quickStartMinutes: todayQuickStartMinutesBinding,
                        onCapture: {
                            viewModel.captureQuickItem(
                                from: .today,
                                modelContext: modelContext,
                                template: templateSnapshot
                            )
                        },
                        onSomedayTap: {
                            isSomedaySheetPresented = true
                        }
                    )
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

    private var todayQuickStartMinutesBinding: Binding<Int?> {
        Binding(
            get: { viewModel.todayQuickStartMinutes },
            set: { viewModel.todayQuickStartMinutes = $0 }
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

private struct NowQuickActionsAccessory: View {
    @Binding var quickCapture: String
    @Binding var quickStartMinutes: Int?
    let onCapture: () -> Void
    let onSomedayTap: () -> Void

    var body: some View {
        CompactAccessoryLayout(
            quickCapture: $quickCapture,
            quickStartMinutes: $quickStartMinutes,
            onCapture: onCapture,
            onSomedayTap: onSomedayTap
        )
    }
}

private struct CompactAccessoryLayout: View {
    @Binding var quickCapture: String
    @Binding var quickStartMinutes: Int?
    let onCapture: () -> Void
    let onSomedayTap: () -> Void
    @State private var isStartPickerPresented = false
    @State private var startTimeSelection = Date.now

    var body: some View {
        HStack(spacing: 10) {
            TextField("Quick add", text: $quickCapture)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .onSubmit(onCapture)
                .accessibilityIdentifier("now-quick-add-field")
                .frame(maxWidth: .infinity)

            Button {
                isStartPickerPresented = true
            } label: {
                Image(systemName: "clock")
                    .font(.footnote)
            }
            .buttonStyle(.bordered)
            .clipShape(.circle)
            .overlay(Circle().strokeBorder(.primary.opacity(0.15), lineWidth: 1))
            .accessibilityLabel("Set start time")
            .accessibilityValue(startTimeText)
            .accessibilityIdentifier("now-quick-start-time-button")

            Button(action: onCapture) {
                Image(systemName: "plus")
                    .font(.footnote.bold())
            }
            .buttonStyle(.borderedProminent)
            .clipShape(.circle)
                .accessibilityIdentifier("now-quick-add-button")

            Button(action: onSomedayTap) {
                Image(systemName: "archivebox")
                    .font(.footnote)
            }
                .buttonStyle(.bordered)
                .clipShape(.circle)
                .accessibilityIdentifier("now-someday-sheet-button")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onAppear {
            startTimeSelection = dateFromMinutes(quickStartMinutes) ?? Date.now
        }
        .sheet(isPresented: $isStartPickerPresented) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    DatePicker(
                        "Start",
                        selection: $startTimeSelection,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                }
                .padding(16)
                .navigationTitle("Start time")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Apply") {
                            quickStartMinutes = startTimeSelection.minutesSinceStartOfDay(using: .current)
                            isStartPickerPresented = false
                        }
                        .accessibilityIdentifier("now-quick-start-time-apply")
                    }
                }
            }
            .presentationDetents([.height(320)])
        }
    }

    private var startTimeText: String {
        let date = dateFromMinutes(quickStartMinutes) ?? Date.now
        return date.formatted(.dateTime.hour().minute())
    }

    private func dateFromMinutes(_ minutes: Int?) -> Date? {
        guard let minutes else { return nil }
        return Calendar.current.date(on: .now, minutesFromStartOfDay: minutes)
    }
}
