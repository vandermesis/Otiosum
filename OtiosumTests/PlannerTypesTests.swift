import Foundation
import Testing
@testable import Otiosum

struct PlannerTypesTests {

    // MARK: - Enum titles

    @Test("Every PreferredTimeWindow case has a human-readable title")
    func preferredTimeWindowTitles() {
        #expect(PreferredTimeWindow.anytime.title == "Any time")
        #expect(PreferredTimeWindow.morning.title == "Morning")
        #expect(PreferredTimeWindow.afternoon.title == "Afternoon")
        #expect(PreferredTimeWindow.evening.title == "Evening")
        #expect(PreferredTimeWindow.night.title == "Night")
    }

    @Test("Every RoutineRole case has a human-readable title")
    func routineRoleTitles() {
        #expect(RoutineRole.sleep.title == "Sleep")
        #expect(RoutineRole.meal.title == "Meal")
        #expect(RoutineRole.rest.title == "Recovery")
        #expect(RoutineRole.workWindow.title == "Work window")
        #expect(RoutineRole.workout.title == "Workout")
    }

    @Test("Every TooMuchTodayChoice case has a human-readable title")
    func tooMuchTodayChoiceTitles() {
        #expect(TooMuchTodayChoice.nextSuitableDay.title == "Move to Another Day")
        #expect(TooMuchTodayChoice.saveForLater.title == "Save for Later")
        #expect(TooMuchTodayChoice.keepAnyway.title == "Keep Today")
    }

    @Test("Every CalendarShiftDecision case has a human-readable title")
    func calendarShiftDecisionTitles() {
        #expect(CalendarShiftDecision.moveOnlyInOtiosum.title == "Move in Planner Only")
        #expect(CalendarShiftDecision.editRealEvent.title == "Change Calendar Event")
        #expect(CalendarShiftDecision.keepFixed.title == "Keep Current Time")
    }

    @Test("Every DropLane case has a human-readable title")
    func dropLaneTitles() {
        #expect(DropLane.morning.title == "Morning lane")
        #expect(DropLane.afternoon.title == "Afternoon lane")
        #expect(DropLane.evening.title == "Evening lane")
        #expect(DropLane.night.title == "Night lane")
    }

    @Test("DropLane.timeWindow maps each lane to the matching PreferredTimeWindow")
    func dropLaneTimeWindowMapping() {
        #expect(DropLane.morning.timeWindow == .morning)
        #expect(DropLane.afternoon.timeWindow == .afternoon)
        #expect(DropLane.evening.timeWindow == .evening)
        #expect(DropLane.night.timeWindow == .night)
    }

    // MARK: - Date / Calendar extensions

    @Test("Date.adding(minutes:) shifts by the requested number of minutes")
    func dateAddingMinutes() {
        let reference = Date(timeIntervalSinceReferenceDate: 0)

        #expect(reference.adding(minutes: 0) == reference)
        #expect(reference.adding(minutes: 30).timeIntervalSince(reference) == 30 * 60)
        #expect(reference.adding(minutes: -15).timeIntervalSince(reference) == -15 * 60)
    }

    @Test("Date.minutesSinceStartOfDay returns whole minutes from the calendar's start of day")
    func dateMinutesSinceStartOfDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let day = calendar.date(from: DateComponents(year: 2026, month: 5, day: 22))!

        #expect(day.minutesSinceStartOfDay(using: calendar) == 0)
        #expect(day.adding(minutes: 9 * 60 + 30).minutesSinceStartOfDay(using: calendar) == 9 * 60 + 30)
        #expect(day.adding(minutes: 23 * 60 + 59).minutesSinceStartOfDay(using: calendar) == 23 * 60 + 59)
    }

    @Test("Calendar.date(on:minutesFromStartOfDay:) round-trips with minutesSinceStartOfDay")
    func calendarDateOnMinutesRoundTrip() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let day = calendar.date(from: DateComponents(year: 2026, month: 5, day: 22))!

        for minutes in [0, 1, 60, 9 * 60 + 30, 23 * 60 + 59] {
            let result = calendar.date(on: day, minutesFromStartOfDay: minutes)
            #expect(result.minutesSinceStartOfDay(using: calendar) == minutes)
        }
    }

    @Test("Date.startOfDay(using:) honours the supplied calendar's time zone")
    func dateStartOfDayUsesCalendarTimeZone() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let midUTC = utc.date(from: DateComponents(year: 2026, month: 5, day: 22, hour: 12))!

        #expect(midUTC.startOfDay(using: utc) == utc.date(from: DateComponents(year: 2026, month: 5, day: 22)))
    }

    // MARK: - PlannedBlock duration

    @Test("PlannedBlock.durationMinutes returns whole minutes between start and end")
    func plannedBlockDurationMinutesExact() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let block = makeBlock(start: start, end: start.addingTimeInterval(45 * 60))

        #expect(block.durationMinutes == 45)
    }

    @Test("PlannedBlock.durationMinutes truncates sub-minute remainders toward zero")
    func plannedBlockDurationMinutesTruncates() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let truncatesUp = makeBlock(start: start, end: start.addingTimeInterval(30 * 60 + 45))
        let zero = makeBlock(start: start, end: start.addingTimeInterval(59))

        #expect(truncatesUp.durationMinutes == 30)
        #expect(zero.durationMinutes == 0)
    }

    private func makeBlock(start: Date, end: Date) -> PlannedBlock {
        PlannedBlock(
            id: UUID(),
            itemID: UUID(),
            calendarEventID: nil,
            title: "Block",
            start: start,
            end: end,
            source: .local,
            flexibility: .flexible,
            symbolName: "star",
            tintToken: "blue",
            notes: "",
            isAllDay: false,
            routineRole: nil,
            isCompleted: false,
            isStarted: false,
            status: .upcoming,
            confidence: 1
        )
    }
}
