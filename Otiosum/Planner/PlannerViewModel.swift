import Foundation

struct PlannerViewModel {
    private let plannerEngine: PlannerEngine

    init(plannerEngine: PlannerEngine = PlannerEngine()) {
        self.plannerEngine = plannerEngine
    }

    func templateSnapshot(from templates: [DayTemplate]) -> DayTemplateSnapshot {
        templates.first?.snapshot ?? .default
    }

    func budgetSnapshot(from budgets: [DailyBudget]) -> DailyBudgetSnapshot {
        budgets.first?.snapshot ?? .default
    }

    func itemLookup(from items: [Event]) -> [UUID: Event] {
        Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    }

    func makeDayPlan(
        day: Date,
        items: [Event],
        calendarEvents: [CalendarEventSnapshot],
        calendarLinks: [CalendarLink],
        template: DayTemplateSnapshot,
        budget: DailyBudgetSnapshot,
        context: InferenceContext
    ) -> DayPlan {
        plannerEngine.plan(
            for: day,
            localItems: items.map(\.snapshot),
            calendarEvents: calendarEvents,
            calendarLinks: calendarLinks.map(\.snapshot),
            template: template,
            budget: budget,
            context: context
        )
    }

    func makeUpcomingPlans(
        selectedDay: Date,
        items: [Event],
        calendarLinks: [CalendarLink],
        template: DayTemplateSnapshot,
        budget: DailyBudgetSnapshot,
        calendarEventsForDay: (Date) -> [CalendarEventSnapshot],
        contextForDay: (Date) -> InferenceContext,
        dayCount: Int = 7
    ) -> [(Date, DayPlan)] {
        let calendar = Calendar.current

        return (0..<dayCount).compactMap { offset in
            guard
                let day = calendar.date(
                    byAdding: .day,
                    value: offset,
                    to: calendar.startOfDay(for: selectedDay)
                )
            else {
                return nil
            }

            let plan = makeDayPlan(
                day: day,
                items: items,
                calendarEvents: calendarEventsForDay(day),
                calendarLinks: calendarLinks,
                template: template,
                budget: budget,
                context: contextForDay(day)
            )

            return (day, plan)
        }
    }

    func makePromptKey(for plan: DayPlan) -> String {
        let overflow = plan.overflowIssues.map(\.itemID.uuidString).joined(separator: ",")
        let shifts = plan.shiftProposals.map(\.calendarEventID).joined(separator: ",")
        return "\(overflow)|\(shifts)|\(plan.warnings.count)"
    }
}
