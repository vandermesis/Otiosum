import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class PlannerShellViewModel {
    var selectedDay: Date {
        get { store.selectedDay }
        set { store.selectedDay = newValue }
    }

    var todayQuickCapture: String {
        get { store.todayQuickCapture }
        set { store.todayQuickCapture = newValue }
    }

    var todayQuickCaptureSuggestion: IconSuggestion? {
        let title = todayQuickCapture.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else { return nil }
        return IconSuggester.suggest(for: title)
    }

    var todayQuickCaptureSuggestions: [IconSuggestion] {
        let title = todayQuickCapture.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else { return [] }
        return IconSuggester.suggestions(for: title)
    }

    var pendingTooMuchToday: PendingTooMuchTodayState? {
        get { store.pendingTooMuchToday }
        set { store.pendingTooMuchToday = newValue }
    }

    var pendingCalendarShift: PendingCalendarShiftState? {
        get { store.pendingCalendarShift }
        set { store.pendingCalendarShift = newValue }
    }

    var calendarService: SystemCalendarService { store.calendarService }

    private let store: PlannerStore
    private let plannerViewModel: PlannerViewModel
    @ObservationIgnored private var timelinePlansCache: TimelinePlansCache?

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

    func completeFinishedStartedEvents(modelContext: ModelContext) {
        store.completeFinishedStartedEvents(modelContext: modelContext)
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

    func eventLookup(from items: [Event]) -> [UUID: Event] {
        plannerViewModel.itemLookup(from: items)
    }

    func makeSelectedDayPlan(
        items: [Event],
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
        items: [Event],
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

    func makeTimelinePlans(
        items: [Event],
        calendarLinks: [CalendarLink],
        template: DayTemplateSnapshot,
        budget: DailyBudgetSnapshot,
        sceneIsActive: Bool,
        timelineCenterDate: Date
    ) -> [(Date, DayPlan)] {
        let calendar = Calendar.current
        let centerStart = calendar.startOfDay(for: timelineCenterDate)
        let days = (-3...3).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: centerStart)
        }
        let calendarEventsByDay = days.map { day in
            CalendarEventsForDay(day: day, events: calendarService.events(for: day))
        }
        let context = roundedInferenceContext(sceneIsActive: sceneIsActive)
        let key = TimelinePlansCacheKey(
            timelineCenterDay: centerStart,
            items: items.map(\.snapshot),
            calendarLinks: calendarLinks.map(\.snapshot),
            template: template,
            budget: budget,
            context: context,
            calendarEventsByDay: calendarEventsByDay
        )

        if let timelinePlansCache, timelinePlansCache.key == key {
            return timelinePlansCache.plans
        }

        let plans = plannerViewModel.makeTimelinePlans(
            selectedDay: centerStart,
            items: items,
            calendarLinks: calendarLinks,
            template: template,
            budget: budget,
            calendarEventsForDay: { day in
                calendarEventsByDay.first { calendar.isDate($0.day, inSameDayAs: day) }?.events ?? []
            },
            contextForDay: { _ in
                context
            }
        )
        timelinePlansCache = TimelinePlansCache(key: key, plans: plans)
        return plans
    }

    private func roundedInferenceContext(sceneIsActive: Bool) -> InferenceContext {
        let context = inferenceContext(sceneIsActive: sceneIsActive)
        return InferenceContext(
            now: context.now.roundedToNearestThirtySeconds,
            isSceneActive: context.isSceneActive,
            lastUserInteraction: context.lastUserInteraction
        )
    }

    func promptKey(for plan: DayPlan) -> String {
        plannerViewModel.makePromptKey(for: plan)
    }

    func captureQuickEvent(
        modelContext: ModelContext,
        template: DayTemplateSnapshot,
        defaultDurationMinutes: Int = 30,
        preferredStartDate: Date? = nil
    ) {
        store.captureQuickEvent(
            modelContext: modelContext,
            day: selectedDay,
            template: template,
            defaultDurationMinutes: defaultDurationMinutes,
            preferredStartDate: preferredStartDate
        )
    }

    func saveQuickEventForLater(modelContext: ModelContext) {
        registerInteraction()
        store.saveQuickEventForLater(modelContext: modelContext)
    }

    func restoreLaterEvent(
        _ event: Event,
        lane: DropLane,
        modelContext: ModelContext
    ) {
        registerInteraction()
        store.restoreLaterEvent(event, lane: lane, on: selectedDay, modelContext: modelContext)
    }

    func scheduleLaterEvent(
        _ event: Event,
        at date: Date,
        modelContext: ModelContext
    ) {
        registerInteraction()
        store.rescheduleEvent(event, to: date, modelContext: modelContext)
    }

    func toggleCompletion(
        for block: PlannedBlock,
        itemLookup: [UUID: Event],
        modelContext: ModelContext
    ) {
        registerInteraction()
        guard let event = itemLookup[block.itemID] else { return }
        store.toggleCompletion(event, modelContext: modelContext)
    }

    func moveItemLater(
        for block: PlannedBlock,
        itemLookup: [UUID: Event],
        modelContext: ModelContext
    ) {
        registerInteraction()
        guard let event = itemLookup[block.itemID] else { return }
        store.moveEventLater(event, on: selectedDay, modelContext: modelContext)
    }

    func saveEventForLater(
        for block: PlannedBlock,
        itemLookup: [UUID: Event],
        modelContext: ModelContext
    ) {
        registerInteraction()
        guard let event = itemLookup[block.itemID] else { return }
        store.saveEventForLater(event, modelContext: modelContext)
    }

    func rescheduleBlock(
        _ block: PlannedBlock,
        to start: Date,
        itemLookup: [UUID: Event],
        modelContext: ModelContext
    ) {
        registerInteraction()
        if block.source == .template {
            store.scheduleTemplateBlock(block, to: start, modelContext: modelContext)
        } else if block.source == .local, let event = itemLookup[block.itemID] {
            store.rescheduleEvent(event, to: start, modelContext: modelContext)
        }
    }

    func adjustDuration(
        for block: PlannedBlock,
        by deltaMinutes: Int,
        itemLookup: [UUID: Event],
        modelContext: ModelContext
    ) {
        registerInteraction()
        guard block.source == .local else { return }
        guard let event = itemLookup[block.itemID] else { return }
        store.adjustDuration(for: event, by: deltaMinutes, modelContext: modelContext)
    }

    func markStartedNow(
        for block: PlannedBlock,
        itemLookup: [UUID: Event],
        modelContext: ModelContext
    ) {
        registerInteraction()
        if block.source == .template {
            store.startTemplateBlockNow(block, modelContext: modelContext)
        } else if block.source == .local, let event = itemLookup[block.itemID] {
            store.startEventNow(event, modelContext: modelContext)
        }
    }

    func setCompletion(
        for block: PlannedBlock,
        isCompleted: Bool,
        itemLookup: [UUID: Event],
        modelContext: ModelContext
    ) {
        registerInteraction()
        guard block.source == .local else { return }
        guard let event = itemLookup[block.itemID] else { return }
        store.setCompletion(event, isCompleted: isCompleted, modelContext: modelContext)
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

    func applyTooMuchTodayChoice(
        _ choice: TooMuchTodayChoice,
        modelContext: ModelContext
    ) {
        store.applyTooMuchTodayChoice(choice, modelContext: modelContext)
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

    func refreshCalendar(around day: Date) async {
        await calendarService.refreshEvents(covering: store.calendarRefreshInterval(around: day))
    }

    func requestCalendarAccess() async {
        await calendarService.requestFullAccess()
        await refreshCalendar()
    }
}

private struct TimelinePlansCache {
    let key: TimelinePlansCacheKey
    let plans: [(Date, DayPlan)]
}

private struct TimelinePlansCacheKey: Equatable {
    let timelineCenterDay: Date
    let items: [EventSnapshot]
    let calendarLinks: [CalendarLinkSnapshot]
    let template: DayTemplateSnapshot
    let budget: DailyBudgetSnapshot
    let context: InferenceContext
    let calendarEventsByDay: [CalendarEventsForDay]
}

private struct CalendarEventsForDay: Equatable {
    let day: Date
    let events: [CalendarEventSnapshot]
}

private extension Date {
    var roundedToNearestThirtySeconds: Date {
        let interval = timeIntervalSinceReferenceDate
        let rounded = (interval / 30).rounded() * 30
        return Date(timeIntervalSinceReferenceDate: rounded)
    }
}
