import Foundation

struct PlanningDayBounds: Equatable, Sendable {
    let startOfDay: Date
    let endOfDay: Date
    let sleepBoundary: Date

    static func make(
        for day: Date,
        template: DayTemplateSnapshot,
        calendar: Calendar = .current
    ) -> PlanningDayBounds {
        let startOfDay = calendar.startOfDay(for: day)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.adding(minutes: 24 * 60)
        let sleepBoundary = calendar.date(on: startOfDay, minutesFromStartOfDay: template.sleepStartMinutes)

        return PlanningDayBounds(
            startOfDay: startOfDay,
            endOfDay: endOfDay,
            sleepBoundary: sleepBoundary
        )
    }
}
