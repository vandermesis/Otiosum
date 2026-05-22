import Foundation
import Testing
@testable import Otiosum

struct TimelineScrollCoordinatorTests {
    private let coordinator = TimelineScrollCoordinator(calendar: TimelineScrollCoordinatorTests.calendar)

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }()

    @Test("Timeline range is finite around the reference day")
    func timelineRangeIsFiniteAroundReferenceDay() throws {
        let reference = try makeDate(year: 2026, month: 5, day: 22, hour: 12)
        let expectedLowerBound = try makeDate(year: 2026, month: 5, day: 19)
        let expectedUpperBound = try makeDate(year: 2026, month: 5, day: 26)

        let range = coordinator.timelineRange(reference: reference, visibleDayRange: 3)

        #expect(range.lowerBound == expectedLowerBound)
        #expect(range.upperBound == expectedUpperBound)
    }

    @Test("Timeline range recenters only near loaded edges")
    func timelineRangeRecentersOnlyNearLoadedEdges() throws {
        let reference = try makeDate(year: 2026, month: 5, day: 22)
        let centerDay = try makeDate(year: 2026, month: 5, day: 22, hour: 12)
        let nearLowerEdge = try makeDate(year: 2026, month: 5, day: 20, hour: 12)
        let nearUpperEdge = try makeDate(year: 2026, month: 5, day: 25, hour: 12)

        #expect(coordinator.shouldRecenterRange(currentReference: reference, candidateCenter: centerDay, visibleDayRange: 3) == false)
        #expect(coordinator.shouldRecenterRange(currentReference: reference, candidateCenter: nearLowerEdge, visibleDayRange: 3))
        #expect(coordinator.shouldRecenterRange(currentReference: reference, candidateCenter: nearUpperEdge, visibleDayRange: 3))
    }

    @Test("Center date reporting is throttled to report step")
    func centerDateReportingIsThrottledToReportStep() throws {
        let lastReported = try makeDate(year: 2026, month: 5, day: 22, hour: 10)
        let sameReportWindow = try makeDate(year: 2026, month: 5, day: 22, hour: 10, minute: 29)
        let nextReportWindow = try makeDate(year: 2026, month: 5, day: 22, hour: 10, minute: 30)
        let expectedNextReport = try makeDate(year: 2026, month: 5, day: 22, hour: 10, minute: 30)

        #expect(coordinator.shouldReportCenterDate(lastReported: lastReported, candidateCenter: sameReportWindow, stepMinutes: 30) == false)
        #expect(coordinator.shouldReportCenterDate(lastReported: lastReported, candidateCenter: nextReportWindow, stepMinutes: 30))
        #expect(coordinator.reportDate(for: nextReportWindow, stepMinutes: 30) == expectedNextReport)
    }

    @Test("Display day ignores time within the day")
    func displayDayIgnoresTimeWithinTheDay() throws {
        let date = try makeDate(year: 2026, month: 5, day: 22, hour: 23, minute: 45)
        let dayStart = try makeDate(year: 2026, month: 5, day: 22)

        #expect(coordinator.displayDay(for: date) == dayStart)
    }

    @Test("Content offset round trips the center date")
    func contentOffsetRoundTripsCenterDate() throws {
        let reference = try makeDate(year: 2026, month: 5, day: 22, hour: 12)
        let range = coordinator.timelineRange(reference: reference, visibleDayRange: 3)
        let centerDate = try makeDate(year: 2026, month: 5, day: 22, hour: 14, minute: 35)

        let offsetY = coordinator.contentOffsetY(
            centering: centerDate,
            in: range,
            containerHeight: 800,
            headerHeight: 52,
            pointsPerMinute: 2.2
        )
        let roundTrippedDate = coordinator.date(
            atContentOffsetY: offsetY,
            in: range,
            containerHeight: 800,
            headerHeight: 52,
            pointsPerMinute: 2.2
        )

        #expect(abs(roundTrippedDate.timeIntervalSince(centerDate)) < 0.1)
    }

    @Test("Back to now offset is bounded to the scrollable content")
    func backToNowOffsetIsBoundedToScrollableContent() throws {
        let reference = try makeDate(year: 2026, month: 5, day: 22, hour: 12)
        let range = coordinator.timelineRange(reference: reference, visibleDayRange: 3)
        let now = try makeDate(year: 2026, month: 5, day: 22, hour: 12)

        let offsetY = coordinator.boundedContentOffsetY(
            centering: now,
            in: range,
            containerHeight: 800,
            headerHeight: 52,
            pointsPerMinute: 2.2
        )
        let maxOffsetY = coordinator.contentHeight(
            for: range,
            headerHeight: 52,
            pointsPerMinute: 2.2
        ) - 800

        #expect(offsetY >= 0)
        #expect(offsetY <= maxOffsetY)
    }

    @Test("Recentered range preserves visible center date")
    func recenteredRangePreservesVisibleCenterDate() throws {
        let originalReference = try makeDate(year: 2026, month: 5, day: 22, hour: 12)
        let newReference = try makeDate(year: 2026, month: 5, day: 19, hour: 12)
        let originalRange = coordinator.timelineRange(reference: originalReference, visibleDayRange: 3)
        let newRange = coordinator.timelineRange(reference: newReference, visibleDayRange: 3)
        let visibleCenter = try makeDate(year: 2026, month: 5, day: 20, hour: 9, minute: 25)

        let originalOffsetY = coordinator.contentOffsetY(
            centering: visibleCenter,
            in: originalRange,
            containerHeight: 800,
            headerHeight: 52,
            pointsPerMinute: 2.2
        )
        let centerBeforeRecenter = coordinator.date(
            atContentOffsetY: originalOffsetY,
            in: originalRange,
            containerHeight: 800,
            headerHeight: 52,
            pointsPerMinute: 2.2
        )
        let newOffsetY = coordinator.contentOffsetY(
            centering: centerBeforeRecenter,
            in: newRange,
            containerHeight: 800,
            headerHeight: 52,
            pointsPerMinute: 2.2
        )
        let centerAfterRecenter = coordinator.date(
            atContentOffsetY: newOffsetY,
            in: newRange,
            containerHeight: 800,
            headerHeight: 52,
            pointsPerMinute: 2.2
        )

        #expect(abs(centerAfterRecenter.timeIntervalSince(visibleCenter)) < 0.1)
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0
    ) throws -> Date {
        try #require(
            Self.calendar.date(
                from: DateComponents(
                    calendar: Self.calendar,
                    timeZone: Self.calendar.timeZone,
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
