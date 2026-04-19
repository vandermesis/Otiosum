import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class PlannerShellViewModel {
    var selectedTab: PlannerTab {
        get { store.selectedTab }
        set { store.selectedTab = newValue }
    }

    var selectedDay: Date {
        get { store.selectedDay }
        set { store.selectedDay = newValue }
    }

    var todayQuickCapture: String {
        get { store.todayQuickCapture }
        set { store.todayQuickCapture = newValue }
    }

    var todayQuickStartMinutes: Int? {
        get { store.todayQuickStartMinutes }
        set { store.todayQuickStartMinutes = newValue }
    }

    var timelineDraft: TimelineDraftTask? {
        get { store.timelineDraft }
        set { store.timelineDraft = newValue }
    }

    var jarQuickCapture: String {
        get { store.jarQuickCapture }
        set { store.jarQuickCapture = newValue }
    }

    var pendingOverflow: PendingOverflowState? {
        get { store.pendingOverflow }
        set { store.pendingOverflow = newValue }
    }

    var pendingCalendarShift: PendingCalendarShiftState? {
        get { store.pendingCalendarShift }
        set { store.pendingCalendarShift = newValue }
    }

    var calendarService: SystemCalendarService { store.calendarService }

    private let store: PlannerStore
    private let plannerViewModel: PlannerViewModel

    init(
        store: PlannerStore,
        plannerViewModel: PlannerViewModel
    ) {
        self.store = store
        self.plannerViewModel = plannerViewModel
    }

    convenience init() {
        self.init(
            store: PlannerStore(),
            plannerViewModel: PlannerViewModel()
        )
    }

    func registerInteraction() {
        store.registerInteraction()
    }

    func ensureSeedData(in modelContext: ModelContext) throws {
        try store.ensureSeedData(in: modelContext)
    }

    func inferenceContext(sceneIsActive: Bool) -> InferenceContext {
        store.inferenceContext(sceneIsActive: sceneIsActive)
    }

    func templateSnapshot(from templates: [DayTemplate]) -> DayTemplateSnapshot {
        plannerViewModel.templateSnapshot(from: templates)
    }

    func budgetSnapshot(from budgets: [DailyBudget]) -> DailyBudgetSnapshot {
        plannerViewModel.budgetSnapshot(from: budgets)
    }

    func itemLookup(from items: [PlannableItem]) -> [UUID: PlannableItem] {
        plannerViewModel.itemLookup(from: items)
    }

    func makeSelectedDayPlan(
        items: [PlannableItem],
        calendarLinks: [CalendarLink],
        template: DayTemplateSnapshot,
        budget: DailyBudgetSnapshot,
        sceneIsActive: Bool
    ) -> DayPlan {
        plannerViewModel.makeDayPlan(
            day: selectedDay,
            items: items,
            calendarEvents: calendarService.events(for: selectedDay),
            calendarLinks: calendarLinks,
            template: template,
            budget: budget,
            context: inferenceContext(sceneIsActive: sceneIsActive)
        )
    }

    func makeUpcomingPlans(
        items: [PlannableItem],
        calendarLinks: [CalendarLink],
        template: DayTemplateSnapshot,
        budget: DailyBudgetSnapshot,
        sceneIsActive: Bool
    ) -> [(Date, DayPlan)] {
        plannerViewModel.makeUpcomingPlans(
            selectedDay: selectedDay,
            items: items,
            calendarLinks: calendarLinks,
            template: template,
            budget: budget,
            calendarEventsForDay: { day in
                self.calendarService.events(for: day)
            },
            contextForDay: { _ in
                self.inferenceContext(sceneIsActive: sceneIsActive)
            }
        )
    }

    func promptKey(for plan: DayPlan) -> String {
        plannerViewModel.makePromptKey(for: plan)
    }

    func captureQuickItem(
        from context: QuickCaptureContext,
        modelContext: ModelContext,
        template: DayTemplateSnapshot
    ) {
        store.captureQuickItem(
            from: context,
            modelContext: modelContext,
            day: selectedDay,
            template: template
        )
    }

    func beginTimelineDraft(from context: QuickCaptureContext, template: DayTemplateSnapshot) {
        registerInteraction()
        store.beginTimelineDraft(fromQuickAdd: context, on: selectedDay, template: template)
    }

    func updateTimelineDraftStart(_ start: Date) {
        registerInteraction()
        store.updateTimelineDraftStart(start)
    }

    func confirmTimelineDraft(modelContext: ModelContext) {
        registerInteraction()
        store.confirmTimelineDraft(modelContext: modelContext)
    }

    func cancelTimelineDraft() {
        store.cancelTimelineDraft()
    }

    func addQuickItemToSomeday(modelContext: ModelContext) {
        registerInteraction()
        store.addQuickItemToSomeday(modelContext: modelContext)
    }

    func scheduleJarItem(
        item: PlannableItem,
        lane: DropLane,
        modelContext: ModelContext
    ) {
        registerInteraction()
        store.scheduleJarItem(item: item, lane: lane, on: selectedDay, modelContext: modelContext)
    }

    func scheduleSomedayItem(
        _ item: PlannableItem,
        at date: Date,
        modelContext: ModelContext
    ) {
        registerInteraction()
        store.rescheduleItem(item, to: date, modelContext: modelContext)
    }

    func toggleCompletion(
        for block: PlannedBlock,
        itemLookup: [UUID: PlannableItem],
        modelContext: ModelContext
    ) {
        registerInteraction()
        guard let item = itemLookup[block.itemID] else { return }
        store.toggleCompletion(item, modelContext: modelContext)
    }

    func moveItemLater(
        for block: PlannedBlock,
        itemLookup: [UUID: PlannableItem],
        modelContext: ModelContext
    ) {
        registerInteraction()
        guard let item = itemLookup[block.itemID] else { return }
        store.moveItemLater(item, on: selectedDay, modelContext: modelContext)
    }

    func returnToJar(
        for block: PlannedBlock,
        itemLookup: [UUID: PlannableItem],
        modelContext: ModelContext
    ) {
        registerInteraction()
        guard let item = itemLookup[block.itemID] else { return }
        store.returnToJar(item, modelContext: modelContext)
    }

    func rescheduleBlock(
        _ block: PlannedBlock,
        to start: Date,
        itemLookup: [UUID: PlannableItem],
        modelContext: ModelContext
    ) {
        registerInteraction()
        guard block.source == .local, block.isProtected == false else { return }
        guard let item = itemLookup[block.itemID] else { return }
        store.rescheduleItem(item, to: start, modelContext: modelContext)
    }

    func adjustDuration(
        for block: PlannedBlock,
        by deltaMinutes: Int,
        itemLookup: [UUID: PlannableItem],
        modelContext: ModelContext
    ) {
        registerInteraction()
        guard block.source == .local, block.isProtected == false else { return }
        guard let item = itemLookup[block.itemID] else { return }
        store.adjustDuration(for: item, by: deltaMinutes, modelContext: modelContext)
    }

    func markStartedNow(
        for block: PlannedBlock,
        itemLookup: [UUID: PlannableItem],
        modelContext: ModelContext
    ) {
        registerInteraction()
        guard block.source == .local, block.isProtected == false else { return }
        guard let item = itemLookup[block.itemID] else { return }
        store.startItemNow(item, modelContext: modelContext)
    }

    func setCompletion(
        for block: PlannedBlock,
        isCompleted: Bool,
        itemLookup: [UUID: PlannableItem],
        modelContext: ModelContext
    ) {
        registerInteraction()
        guard block.source == .local else { return }
        guard let item = itemLookup[block.itemID] else { return }
        store.setCompletion(item, isCompleted: isCompleted, modelContext: modelContext)
    }

    func updateCalendarFlexibility(
        for block: PlannedBlock,
        flexibility: PlannerFlexibility,
        modelContext: ModelContext
    ) {
        registerInteraction()
        guard let calendarEventID = block.calendarEventID else { return }

        store.updateCalendarFlexibility(
            for: calendarEventID,
            title: block.title,
            flexibility: flexibility,
            modelContext: modelContext
        )
    }

    func refreshPrompts(
        for plan: DayPlan,
        modelContext: ModelContext
    ) {
        store.refreshPrompts(for: plan, modelContext: modelContext)
    }

    func applyOverflowChoice(
        _ choice: OverflowChoice,
        modelContext: ModelContext
    ) {
        store.applyOverflowChoice(choice, modelContext: modelContext)
    }

    func applyCalendarDecision(
        _ decision: CalendarShiftDecision,
        modelContext: ModelContext
    ) async {
        await store.applyCalendarDecision(decision, modelContext: modelContext)
        await refreshCalendar()
    }

    func refreshCalendar() async {
        await calendarService.refreshEvents(covering: store.calendarRefreshInterval(around: selectedDay))
    }

    func requestCalendarAccess() async {
        await calendarService.requestFullAccess()
        await refreshCalendar()
    }
}
