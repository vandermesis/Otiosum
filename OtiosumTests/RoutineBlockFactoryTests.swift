import Foundation
import Testing
@testable import Otiosum

struct RoutineBlockFactoryTests {
    private let factory = RoutineBlockFactory(calendar: RoutineBlockFactoryTests.calendar)

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }()

    @Test("Routine factory builds default routine blocks from settings")
    func buildsDefaultRoutineBlocks() throws {
        let day = try makeDate(year: 2026, month: 5, day: 22)
        let endOfDay = day.adding(minutes: 24 * 60)

        let blocks = factory.makeBlocks(
            for: day,
            template: .default,
            budget: .default,
            endOfDay: endOfDay
        )

        #expect(blocks.map(\.title) == ["Breakfast", "Lunch", "Workout", "Dinner", "Recovery", "Sleep"])
        #expect(blocks.allSatisfy { $0.source == .template })
        #expect(blocks.first { $0.title == "Sleep" }?.end == endOfDay)
        #expect(blocks.first { $0.title == "Breakfast" }?.durationMinutes == DailyBudgetSnapshot.default.mealDurationMinutes)
    }

    @Test("Routine factory omits workout when disabled")
    func omitsWorkoutWhenDisabled() throws {
        let day = try makeDate(year: 2026, month: 5, day: 22)
        let template = DayTemplateSnapshot(
            wakeUpMinutes: DayTemplateSnapshot.default.wakeUpMinutes,
            sleepStartMinutes: DayTemplateSnapshot.default.sleepStartMinutes,
            breakfastMinutes: DayTemplateSnapshot.default.breakfastMinutes,
            lunchMinutes: DayTemplateSnapshot.default.lunchMinutes,
            dinnerMinutes: DayTemplateSnapshot.default.dinnerMinutes,
            quietStartMinutes: DayTemplateSnapshot.default.quietStartMinutes,
            quietDurationMinutes: DayTemplateSnapshot.default.quietDurationMinutes,
            workoutMinutes: DayTemplateSnapshot.default.workoutMinutes,
            workoutDurationMinutes: DayTemplateSnapshot.default.workoutDurationMinutes,
            includeWorkout: false,
            transitionBufferMinutes: DayTemplateSnapshot.default.transitionBufferMinutes
        )

        let blocks = factory.makeBlocks(
            for: day,
            template: template,
            budget: .default,
            endOfDay: day.adding(minutes: 24 * 60)
        )

        #expect(blocks.contains { $0.routineRole == .workout } == false)
    }

    private func makeDate(year: Int, month: Int, day: Int) throws -> Date {
        try #require(
            Self.calendar.date(
                from: DateComponents(
                    calendar: Self.calendar,
                    timeZone: Self.calendar.timeZone,
                    year: year,
                    month: month,
                    day: day
                )
            )
        )
    }
}
