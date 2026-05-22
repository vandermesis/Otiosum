import Foundation
import Testing
@testable import Otiosum

struct PlanningDayBoundsTests {
    private let calendar = PlanningDayBoundsTests.calendar

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }()

    @Test("Bounds normalize any date to its calendar day")
    func boundsNormalizeDateToCalendarDay() throws {
        let input = try makeDate(year: 2026, month: 5, day: 22, hour: 14, minute: 45)
        let expectedStart = try makeDate(year: 2026, month: 5, day: 22)
        let expectedEnd = try makeDate(year: 2026, month: 5, day: 23)

        let bounds = PlanningDayBounds.make(for: input, template: .default, calendar: calendar)

        #expect(bounds.startOfDay == expectedStart)
        #expect(bounds.endOfDay == expectedEnd)
    }

    @Test("Sleep boundary follows template sleep start minutes")
    func sleepBoundaryUsesTemplateMinutes() throws {
        let day = try makeDate(year: 2026, month: 5, day: 22)
        let template = DayTemplateSnapshot(
            wakeUpMinutes: 7 * 60,
            sleepStartMinutes: 23 * 60 + 15,
            breakfastMinutes: 8 * 60,
            lunchMinutes: 12 * 60,
            dinnerMinutes: 18 * 60,
            quietStartMinutes: 20 * 60,
            quietDurationMinutes: 30,
            workoutMinutes: 17 * 60,
            workoutDurationMinutes: 45,
            includeWorkout: true,
            transitionBufferMinutes: 10
        )

        let bounds = PlanningDayBounds.make(for: day, template: template, calendar: calendar)

        #expect(bounds.sleepBoundary == day.adding(minutes: 23 * 60 + 15))
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0
    ) throws -> Date {
        try #require(
            calendar.date(
                from: DateComponents(
                    calendar: calendar,
                    timeZone: calendar.timeZone,
                    year: year,
                    month: month,
                    day: day,
                    hour: hour,
                    minute: minute
                )
            )
        )
    }
}
