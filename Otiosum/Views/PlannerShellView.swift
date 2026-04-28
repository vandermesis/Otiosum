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
    @State private var isLaterSheetPresented = false
    @State private var isSettingsPresented = false
    @State private var timelineCenterDate = Date.now
    @FocusState private var isQuickCaptureFocused: Bool

    private var template: DayTemplate? { templates.first }
    private var budget: DailyBudget? { budgets.first }
    private var templateSnapshot: DayTemplateSnapshot { viewModel.templateSnapshot(from: templates) }
    private var budgetSnapshot: DailyBudgetSnapshot { viewModel.budgetSnapshot(from: budgets) }
    private var eventLookup: [UUID: Event] { viewModel.eventLookup(from: items) }
    private var timelineDayPlans: [(Date, DayPlan)] {
        viewModel.makeTimelinePlans(
            items: items,
            calendarLinks: calendarLinks,
            template: templateSnapshot,
            budget: budgetSnapshot,
            sceneIsActive: scenePhase == .active
        )
    }

    private var selectedDayPlan: DayPlan {
        timelineDayPlans.first { entry in
            Calendar.current.isDate(entry.0, inSameDayAs: viewModel.selectedDay)
        }?.1 ?? viewModel.makeSelectedDayPlan(
            items: items,
            calendarLinks: calendarLinks,
            template: templateSnapshot,
            budget: budgetSnapshot,
            sceneIsActive: scenePhase == .active
        )
    }

    private var timelineBlocks: [PlannedBlock] {
        timelineDayPlans
            .flatMap { $0.1.allBlocks }
            .sorted { lhs, rhs in
                if lhs.start == rhs.start {
                    return lhs.end < rhs.end
                }
                return lhs.start < rhs.start
            }
    }

    private var laterEvents: [Event] {
        items.filter { $0.isSavedForLater || $0.scheduledDay == nil }
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
                        timelineBlocks: timelineBlocks,
                        budget: budgetSnapshot,
                        calendarService: viewModel.calendarService,
                        onOpenLater: {
                            isLaterSheetPresented = true
                        },
                        onOpenSettings: {
                            isSettingsPresented = true
                        },
                        onRequestCalendarAccess: {
                            Task {
                                await viewModel.requestCalendarAccess()
                            }
                        },                        
                        onDropLaterItem: { itemID, date in
                            guard let event = eventLookup[itemID] else { return false }
                            viewModel.scheduleLaterEvent(event, at: date, modelContext: modelContext)
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
                    .toolbar(.hidden, for: .navigationBar)
                    .safeAreaInset(edge: .bottom) {
                        QuickCaptureToolbarContent(
                            text: todayQuickCaptureBinding,
                            isTextFieldFocused: $isQuickCaptureFocused,
                            suggestion: todayQuickCaptureSuggestion,
                            onAddToToday: {
                                isQuickCaptureFocused = false
                                addSearchTextToTimeline(
                                    templateSnapshot: templateSnapshot,
                                    budgetSnapshot: budgetSnapshot
                                )
                            },
                            onAddToLater: {
                                isQuickCaptureFocused = false
                                addSearchTextToLaterIfNeeded()
                            }
                        )
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 10)
                        .background {
                            Rectangle()
                                .fill(.clear)
                                .background(.thinMaterial.opacity(0.001))
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
        .sheet(item: pendingTooMuchTodayBinding) { pendingTooMuchToday in
            TooMuchTodayDecisionSheet(
                state: pendingTooMuchToday,
                onChoose: { choice in
                    viewModel.applyTooMuchTodayChoice(choice, modelContext: modelContext)
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
        .sheet(isPresented: $isLaterSheetPresented) {
            NavigationStack {
                LaterDrawerContent(items: laterEvents) { item, lane in
                    viewModel.restoreLaterEvent(item, lane: lane, modelContext: modelContext)
                }
                .padding(16)
                .navigationTitle("Later")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            isLaterSheetPresented = false
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

    private var pendingTooMuchTodayBinding: Binding<PendingTooMuchTodayState?> {
        Binding(
            get: { viewModel.pendingTooMuchToday },
            set: { viewModel.pendingTooMuchToday = $0 }
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

    private func addSearchTextToLaterIfNeeded() {
        guard viewModel.todayQuickCapture.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }
        viewModel.saveQuickEventForLater(modelContext: modelContext)
    }
}

private struct QuickCaptureToolbarContent: View {
    @Binding var text: String
    let isTextFieldFocused: FocusState<Bool>.Binding
    let suggestion: IconSuggestion?
    let onAddToToday: () -> Void
    let onAddToLater: () -> Void

    private var hasText: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add Task")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(alignment: .bottom, spacing: 10) {
                QuickCaptureField(
                    text: $text,
                    isTextFieldFocused: isTextFieldFocused,
                    suggestion: suggestion,
                    onSubmit: onAddToToday
                )

                Button("Add to Today") {
                    onAddToToday()
                }
                .buttonStyle(.borderedProminent)
                .disabled(hasText == false)
                .controlSize(.large)
                .accessibilityIdentifier("quick-add-today")
            }

            Button("Save for Later", systemImage: "archivebox") {
                onAddToLater()
            }
            .buttonStyle(.bordered)
            .disabled(hasText == false)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("quick-add-later")
        }
        .padding(12)
        .background(.regularMaterial, in: .rect(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.48), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.05), radius: 18, y: 6)
    }
}

private struct QuickCaptureField: View {
    @Binding var text: String
    let isTextFieldFocused: FocusState<Bool>.Binding
    let suggestion: IconSuggestion?
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.and.pencil")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField("One short phrase", text: $text)
                .focused(isTextFieldFocused)
                .submitLabel(.done)
                .onSubmit(onSubmit)
                .accessibilityIdentifier("quick-add-field")

            if let suggestion {
                PlannerIcon(symbolName: suggestion.symbolName, tintToken: suggestion.tintToken, compact: true)
                    .accessibilityLabel(Text("Suggested icon"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 54)
        .background(.background.opacity(0.92), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(.separator.opacity(0.35), lineWidth: 1)
        }
    }
}

#Preview {
    PlannerShellView()
        .modelContainer(AppConfiguration.makeModelContainer())
}
