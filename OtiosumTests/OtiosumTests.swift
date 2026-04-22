//
//  OtiosumTests.swift
//  OtiosumTests
//
//  Created by Marek Skrzelowski on 16/04/2026.
//

import Foundation
import Testing
@testable import Otiosum

struct OtiosumTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }()

    @Test(
        "Tick style chooses the right tier for each boundary",
        arguments: [
            (2026, 1, 1, 0, 0, 0, TimeWheelTickTier.year),
            (2026, 2, 1, 0, 0, 0, TimeWheelTickTier.month),
            (2026, 2, 2, 0, 0, 0, TimeWheelTickTier.day),
            (2026, 2, 2, 11, 0, 0, TimeWheelTickTier.hour),
            (2026, 2, 2, 11, 5, 0, TimeWheelTickTier.minute),
            (2026, 2, 2, 11, 5, 20, TimeWheelTickTier.tenSecond),
            (2026, 2, 2, 11, 5, 21, TimeWheelTickTier.second)
        ]
    )
    func tickTierClassification(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        second: Int,
        expectedTier: TimeWheelTickTier
    ) throws {
        let date = try makeDate(year: year, month: month, day: day, hour: hour, minute: minute, second: second)

        let style = TimeWheelTickStyle.make(for: date, calendar: calendar)

        #expect(tierIdentifier(style.tier) == tierIdentifier(expectedTier))
    }

    @Test("Major ticks expose labels while second ticks stay unlabeled")
    func labelRules() throws {
        let monthTickDate = try makeDate(year: 2026, month: 3, day: 1, hour: 0, minute: 0, second: 0)
        let secondTickDate = try makeDate(year: 2026, month: 3, day: 1, hour: 0, minute: 0, second: 1)

        let monthStyle = TimeWheelTickStyle.make(for: monthTickDate, calendar: calendar)
        let secondStyle = TimeWheelTickStyle.make(for: secondTickDate, calendar: calendar)

        #expect(monthStyle.label.isEmpty == false)
        #expect(secondStyle.label.isEmpty)
    }

    @Test("Tick lengths and thicknesses match the visual spec")
    func visualScaleValues() throws {
        let dayTickDate = try makeDate(year: 2026, month: 3, day: 2, hour: 0, minute: 0, second: 0)
        let tenSecondTickDate = try makeDate(year: 2026, month: 3, day: 2, hour: 10, minute: 11, second: 20)

        let dayStyle = TimeWheelTickStyle.make(for: dayTickDate, calendar: calendar)
        let tenSecondStyle = TimeWheelTickStyle.make(for: tenSecondTickDate, calendar: calendar)

        #expect(approximatelyEqual(dayStyle.lengthFactor, 0.18))
        #expect(approximatelyEqual(dayStyle.thickness, 4))
        #expect(approximatelyEqual(tenSecondStyle.lengthFactor, 0.10))
        #expect(approximatelyEqual(tenSecondStyle.thickness, 2))
    }

    @Test(
        "Timeline grid marks month/day/hour boundaries correctly",
        arguments: [
            (2026, 4, 1, 0, 0, "month"),
            (2026, 4, 2, 0, 0, "day"),
            (2026, 4, 2, 9, 0, "hour"),
            (2026, 4, 2, 9, 15, "quarterHour"),
            (2026, 4, 2, 9, 5, "minor")
        ]
    )
    func timelineGridBoundaryClassification(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        expectedTier: String
    ) throws {
        let date = try makeDate(year: year, month: month, day: day, hour: hour, minute: minute, second: 0)
        let style = TimelineGridStyle.make(for: date, calendar: calendar)

        #expect(timelineGridTierIdentifier(style.tier) == expectedTier)
    }

    @Test("Timeline grid labels boundaries and quarter hours while minor rows stay as ticks")
    func timelineGridLabelRules() throws {
        let dayStart = try makeDate(year: 2026, month: 4, day: 3, hour: 0, minute: 0, second: 0)
        let quarterHourTick = try makeDate(year: 2026, month: 4, day: 3, hour: 0, minute: 15, second: 0)
        let minorTick = try makeDate(year: 2026, month: 4, day: 3, hour: 0, minute: 5, second: 0)

        let dayStartStyle = TimelineGridStyle.make(for: dayStart, calendar: calendar)
        let quarterHourStyle = TimelineGridStyle.make(for: quarterHourTick, calendar: calendar)
        let minorStyle = TimelineGridStyle.make(for: minorTick, calendar: calendar)

        #expect(dayStartStyle.label.isEmpty == false)
        #expect(dayStartStyle.contextLabel != nil)
        #expect(quarterHourStyle.label.isEmpty == false)
        #expect(quarterHourStyle.contextLabel == nil)
        #expect(minorStyle.label.isEmpty)
        #expect(minorStyle.contextLabel == nil)
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        second: Int
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
                    minute: minute,
                    second: second
                )
            ),
            "Expected to create deterministic test date."
        )
    }

    private func approximatelyEqual(_ lhs: CGFloat, _ rhs: CGFloat, tolerance: CGFloat = 0.0001) -> Bool {
        abs(lhs - rhs) <= tolerance
    }

    private func tierIdentifier(_ tier: TimeWheelTickTier) -> String {
        switch tier {
        case .year:
            "year"
        case .month:
            "month"
        case .day:
            "day"
        case .hour:
            "hour"
        case .minute:
            "minute"
        case .tenSecond:
            "tenSecond"
        case .second:
            "second"
        }
    }

    private func timelineGridTierIdentifier(_ tier: TimelineGridTier) -> String {
        switch tier {
        case .month:
            "month"
        case .day:
            "day"
        case .hour:
            "hour"
        case .quarterHour:
            "quarterHour"
        case .minor:
            "minor"
        }
    }
}
