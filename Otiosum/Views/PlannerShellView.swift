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
                        timelineDraft: viewModel.timelineDraft,
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
                        onTimelineDraftMoved: { start in
                            viewModel.updateTimelineDraftStart(start)
                        },
                        onConfirmTimelineDraft: {
                            viewModel.confirmTimelineDraft(modelContext: modelContext)
                        },
                        onCancelTimelineDraft: {
                            viewModel.cancelTimelineDraft()
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
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    NowQuickAddComposer(
                        quickCapture: todayQuickCaptureBinding,
                        isDraftingTimeline: viewModel.timelineDraft != nil,
                        onAddToTimeline: {
                            viewModel.beginTimelineDraft(from: .today, template: templateSnapshot)
                        },
                        onAddToSomeday: {
                            viewModel.addQuickItemToSomeday(modelContext: modelContext)
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
}

private struct NowQuickAddComposer: View {
    @Binding var quickCapture: String
    let isDraftingTimeline: Bool
    let onAddToTimeline: () -> Void
    let onAddToSomeday: () -> Void

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            TextField("Quick add", text: $quickCapture)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .focused($isTextFieldFocused)
                .onSubmit(onAddToTimeline)
                .accessibilityIdentifier("now-quick-add-field")
                .frame(maxWidth: .infinity)

            Button(action: onAddToTimeline) {
                Image(systemName: "plus")
                    .font(.footnote.bold())
            }
            .buttonStyle(.borderedProminent)
            .clipShape(.circle)
            .disabled(isDraftingTimeline)
            .accessibilityIdentifier("now-quick-add-button")
            .accessibilityLabel("Add to timeline")

            Button(action: onAddToSomeday) {
                Image(systemName: "archivebox")
                    .font(.footnote)
            }
            .buttonStyle(.bordered)
            .clipShape(.circle)
            .disabled(isDraftingTimeline)
            .accessibilityIdentifier("now-someday-sheet-button")
            .accessibilityLabel("Save to someday")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
}
