import Foundation

struct TimelineScrollCoordinator {
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func timelineRange(reference: Date, visibleDayRange: Int) -> ClosedRange<Date> {
        let referenceDayStart = calendar.startOfDay(for: reference)
        let start = calendar.date(byAdding: .day, value: -visibleDayRange, to: referenceDayStart) ?? referenceDayStart
        let end = calendar.date(byAdding: .day, value: visibleDayRange + 1, to: referenceDayStart) ?? referenceDayStart
        return start...end
    }

    func shouldRecenterRange(
        currentReference: Date,
        candidateCenter: Date,
        visibleDayRange: Int
    ) -> Bool {
        let range = timelineRange(reference: currentReference, visibleDayRange: visibleDayRange)
        let candidateDay = calendar.startOfDay(for: candidateCenter)
        let lowerThreshold = calendar.date(byAdding: .day, value: 1, to: range.lowerBound) ?? range.lowerBound
        let upperThreshold = calendar.date(byAdding: .day, value: -1, to: range.upperBound) ?? range.upperBound

        return candidateDay <= lowerThreshold || candidateDay >= upperThreshold
    }

    func displayDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    func reportDate(for date: Date, stepMinutes: Int) -> Date {
        let dayStart = calendar.startOfDay(for: date)
        let minutesSinceDayStart = Int(date.timeIntervalSince(dayStart) / 60)
        let snappedMinutes = (minutesSinceDayStart / stepMinutes) * stepMinutes
        return calendar.date(byAdding: .minute, value: snappedMinutes, to: dayStart) ?? date
    }

    func shouldReportCenterDate(
        lastReported: Date?,
        candidateCenter: Date,
        stepMinutes: Int
    ) -> Bool {
        let candidateReportDate = reportDate(for: candidateCenter, stepMinutes: stepMinutes)
        return lastReported != candidateReportDate
    }

    func contentHeight(
        for range: ClosedRange<Date>,
        headerHeight: Double,
        pointsPerMinute: Double
    ) -> Double {
        let timelineMinutes = range.upperBound.timeIntervalSince(range.lowerBound) / 60
        return max(headerHeight + (timelineMinutes * pointsPerMinute), 0)
    }

    func contentOffsetY(
        centering date: Date,
        in range: ClosedRange<Date>,
        containerHeight: Double,
        headerHeight: Double,
        pointsPerMinute: Double
    ) -> Double {
        let clampedDate = min(max(date, range.lowerBound), range.upperBound)
        let minutes = clampedDate.timeIntervalSince(range.lowerBound) / 60
        return headerHeight + (minutes * pointsPerMinute) - (containerHeight / 2)
    }

    func boundedContentOffsetY(
        centering date: Date,
        in range: ClosedRange<Date>,
        containerHeight: Double,
        headerHeight: Double,
        pointsPerMinute: Double
    ) -> Double {
        let offsetY = contentOffsetY(
            centering: date,
            in: range,
            containerHeight: containerHeight,
            headerHeight: headerHeight,
            pointsPerMinute: pointsPerMinute
        )
        let maxOffsetY = max(
            contentHeight(for: range, headerHeight: headerHeight, pointsPerMinute: pointsPerMinute) - containerHeight,
            0
        )
        return min(max(offsetY, 0), maxOffsetY)
    }

    func date(
        atContentOffsetY offsetY: Double,
        in range: ClosedRange<Date>,
        containerHeight: Double,
        headerHeight: Double,
        pointsPerMinute: Double
    ) -> Date {
        let timelineY = offsetY + (containerHeight / 2) - headerHeight
        let minutes = timelineY / pointsPerMinute
        return range.lowerBound.addingTimeInterval(minutes * 60)
    }
}
