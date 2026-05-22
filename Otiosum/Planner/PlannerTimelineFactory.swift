import Foundation

struct PlannerTimelineResult: Equatable, Sendable {
    let blocks: [PlannedBlock]
    let tooMuchTodayIssues: [TooMuchTodayIssue]
}

struct PlannerTimelineFactory {
    private let calendar: Calendar
    private let statusDecorator: BlockStatusDecorator

    init(
        calendar: Calendar = .current,
        statusDecorator: BlockStatusDecorator = BlockStatusDecorator()
    ) {
        self.calendar = calendar
        self.statusDecorator = statusDecorator
    }

    func makeTimeline(
        for day: Date,
        localItems: [EventSnapshot],
        calendarEvents: [CalendarEventSnapshot],
        calendarLinks: [CalendarLinkSnapshot],
        template: DayTemplateSnapshot,
        budget: DailyBudgetSnapshot,
        bounds: PlanningDayBounds,
        context: InferenceContext
    ) -> PlannerTimelineResult {
        let templateBlocks = RoutineBlockFactory(calendar: calendar).makeBlocks(
            for: day,
            template: template,
            budget: budget,
            endOfDay: bounds.endOfDay
        )
        let calendarBlocks = CalendarBlockFactory().makeBlocks(
            for: day,
            calendarEvents: calendarEvents,
            calendarLinks: calendarLinks,
            startOfDay: bounds.startOfDay,
            endOfDay: bounds.endOfDay
        )

        let allDayCalendarBlocks = calendarBlocks.filter(\.isAllDay)
        let timedCalendarBlocks = calendarBlocks.filter { !$0.isAllDay }

        let localBlocks = LocalBlockFactory(calendar: calendar).makeBlocks(
            for: day,
            localItems: localItems,
            templateBlocks: templateBlocks,
            fixedBlocks: timedCalendarBlocks,
            template: template,
            endOfDay: bounds.endOfDay
        )
        var tooMuchTodayIssues = localBlocks.tooMuchTodayIssues

        let scheduled = TimelineScheduler(calendar: calendar).schedule(
            blocks: localBlocks.blocks,
            now: context.now,
            day: day,
            transitionBufferMinutes: template.transitionBufferMinutes
        )

        let finalBlocks = statusDecorator.decorate(
            blocks: scheduled.blocks + allDayCalendarBlocks,
            context: context
        )
        tooMuchTodayIssues.append(contentsOf: scheduled.sleepCollisionIssues)

        return PlannerTimelineResult(
            blocks: finalBlocks,
            tooMuchTodayIssues: tooMuchTodayIssues
        )
    }
}
