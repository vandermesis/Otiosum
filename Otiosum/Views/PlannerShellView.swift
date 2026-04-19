import SwiftData
import SwiftUI

struct PlannerShellView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \Event.createdAt) private var items: [Event]
    @Query(sort: \CalendarLink.updatedAt) private var calendarLinks: [CalendarLink]
    @Query(sort: \DayTemplate.key) private var templates: [DayTemplate]
    @Query(sort: \DailyBudget.key) private var budgets: [DailyBudget]

    @State private var viewModel = PlannerShellViewModel()
    @State private var isSomedaySheetPresented = false
    @State private var isSettingsPresented = false
    @State private var timelineCenterDate = Date.now

    private var template: DayTemplate? { templates.first }
    private var budget: DailyBudget? { budgets.first }
    private var templateSnapshot: DayTemplateSnapshot { viewModel.templateSnapshot(from: templates) }
    private var budgetSnapshot: DailyBudgetSnapshot { viewModel.budgetSnapshot(from: budgets) }
    private var eventLookup: [UUID: Event] { viewModel.eventLookup(from: items) }

    private var selectedDayPlan: DayPlan {
        viewModel.makeSelectedDayPlan(
            items: items,
            calendarLinks: calendarLinks,
            template: templateSnapshot,
            budget: budgetSnapshot,
            sceneIsActive: scenePhase == .active
        )
    }

    private var archivedEvents: [Event] {
        items.filter { $0.isArchived || $0.scheduledDay == nil }
    }

    private var promptKey: String {
        viewModel.promptKey(for: selectedDayPlan)
    }

    private var todayQuickCaptureSuggestion: IconSuggestion? {
        viewModel.todayQuickCaptureSuggestion
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
                            guard let event = eventLookup[itemID] else { return false }
                            viewModel.scheduleArchivedEvent(event, at: date, modelContext: modelContext)
                            return true
                        },
                        onRescheduleBlock: { block, start in
                            viewModel.rescheduleBlock(
                                block,
                                to: start,
                                itemLookup: eventLookup,
                                modelContext: modelContext
                            )
                        },
                        onAdjustBlockDuration: { block, deltaMinutes in
                            viewModel.adjustDuration(
                                for: block,
                                by: deltaMinutes,
                                itemLookup: eventLookup,
                                modelContext: modelContext
                            )
                        },
                        onQuickAction: { block, action in
                            switch action {
                            case .startNow:
                                viewModel.markStartedNow(
                                    for: block,
                                    itemLookup: eventLookup,
                                    modelContext: modelContext
                                )
                            case .markDone:
                                viewModel.setCompletion(
                                    for: block,
                                    isCompleted: true,
                                    itemLookup: eventLookup,
                                    modelContext: modelContext
                                )
                            case .markUndone:
                                viewModel.setCompletion(
                                    for: block,
                                    isCompleted: false,
                                    itemLookup: eventLookup,
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
                            Button("Archive", systemImage: "archivebox") {
                                isSomedaySheetPresented = true
                            }
                            .accessibilityIdentifier("now-open-someday")

                            Button("Settings", systemImage: "gearshape") {
                                isSettingsPresented = true
                            }
                            .accessibilityIdentifier("now-open-settings")
                        }
                        ToolbarItemGroup(placement: .bottomBar) {
                            QuickCaptureToolbarContent(
                                text: todayQuickCaptureBinding,
                                suggestion: todayQuickCaptureSuggestion,
                                onAddToToday: {
                                    addSearchTextToTimeline(
                                        templateSnapshot: templateSnapshot,
                                        budgetSnapshot: budgetSnapshot
                                    )
                                },
                                onAddToArchive: {
                                    addSearchTextToArchiveIfNeeded()
                                }
                            )
                        }
                    }
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
                SomedayDrawerContent(items: archivedEvents) { item, lane in
                    viewModel.restoreArchivedEvent(item, lane: lane, modelContext: modelContext)
                }
                .padding(16)
                .navigationTitle("Archive")
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
        viewModel.captureQuickEvent(
            modelContext: modelContext,
            template: templateSnapshot,
            defaultDurationMinutes: budgetSnapshot.quickAddDefaultDurationMinutes,
            preferredStartDate: preferredStartDate
        )
    }

    private func addSearchTextToArchiveIfNeeded() {
        guard viewModel.todayQuickCapture.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }
        viewModel.archiveQuickEvent(modelContext: modelContext)
    }
}

private struct QuickCaptureToolbarContent: View {
    @Binding var text: String
    let suggestion: IconSuggestion?
    let onAddToToday: () -> Void
    let onAddToArchive: () -> Void

    private var hasText: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        HStack(spacing: 12) {
            TextField("Add", text: $text)
                .submitLabel(.done)
                .onSubmit(onAddToToday)
                .accessibilityIdentifier("quick-add-field")

            if let suggestion {
                PlannerIcon(symbolName: suggestion.symbolName, tintToken: suggestion.tintToken, compact: true)
                    .accessibilityLabel(Text("Suggested icon"))
            }

            Button("Add", systemImage: "plus") {
                onAddToToday()
            }
            .disabled(hasText == false)
            .accessibilityIdentifier("quick-add-today")

            Button("Archive", systemImage: "archivebox") {
                onAddToArchive()
            }
            .disabled(hasText == false)
            .accessibilityIdentifier("quick-add-someday")
        }
    }
}
