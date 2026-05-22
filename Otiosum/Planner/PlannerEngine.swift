import Foundation

struct PlannerEngine {
    private let calendar: Calendar
    private let timelineFactory: PlannerTimelineFactory
    private let dayPlanFactory: DayPlanFactory

    init(
        calendar: Calendar = .current,
        timelineFactory: PlannerTimelineFactory? = nil,
        dayPlanFactory: DayPlanFactory = DayPlanFactory()
    ) {
        self.calendar = calendar
        self.timelineFactory = timelineFactory ?? PlannerTimelineFactory(calendar: calendar)
        self.dayPlanFactory = dayPlanFactory
    }

    func plan(
        for day: Date,
        localItems: [EventSnapshot],
        calendarEvents: [CalendarEventSnapshot],
        calendarLinks: [CalendarLinkSnapshot],
        template: DayTemplateSnapshot,
        budget: DailyBudgetSnapshot,
        context: InferenceContext
    ) -> DayPlan {
        let bounds = PlanningDayBounds.make(
            for: day,
            template: template,
            calendar: calendar
        )

        let timeline = timelineFactory.makeTimeline(
            for: day,
            localItems: localItems,
            calendarEvents: calendarEvents,
            calendarLinks: calendarLinks,
            template: template,
            budget: budget,
            bounds: bounds,
            context: context
        )

        return dayPlanFactory.makePlan(
            day: day,
            blocks: timeline.blocks,
            tooMuchTodayIssues: timeline.tooMuchTodayIssues,
            shiftProposals: [],
            budget: budget,
            template: template,
            sleepBoundary: bounds.sleepBoundary,
            context: context
        )
    }
}
