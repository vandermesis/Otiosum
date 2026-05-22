import EventKit
import Foundation
import Testing
@testable import Otiosum

@MainActor
struct SystemCalendarServiceTests {

    // MARK: - canReadEvents

    @Test("canReadEvents is true for fullAccess status")
    func canReadEventsForFullAccess() {
        let service = SystemCalendarService()

        service.authorizationStatus = .fullAccess
        #expect(service.canReadEvents)
    }

    @Test("canReadEvents is false for non-read authorization statuses")
    func canReadEventsForBlockedStates() {
        let service = SystemCalendarService()
        let blocked: [EKAuthorizationStatus] = [.denied, .restricted, .notDetermined, .writeOnly]

        for status in blocked {
            service.authorizationStatus = status
            #expect(service.canReadEvents == false, "\(status) should not grant read access")
        }
    }

    // MARK: - events(for:)

    @Test("events(for:) returns an empty array before refreshEvents has populated the cache")
    func eventsForUnknownDayIsEmpty() {
        let service = SystemCalendarService()
        let day = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 22))!

        #expect(service.events(for: day).isEmpty)
    }

    // MARK: - CalendarServiceError

    @Test("CalendarServiceError.noAccess exposes a user-facing description")
    func noAccessErrorDescription() {
        #expect(CalendarServiceError.noAccess.errorDescription == "Calendar access is not available.")
    }

    @Test("CalendarServiceError.missingEvent exposes a user-facing description")
    func missingEventErrorDescription() {
        #expect(CalendarServiceError.missingEvent.errorDescription == "The calendar event is no longer available.")
    }

    // MARK: - dayEntriesSpanning

    @Test("Single-day events report exactly one day entry")
    func dayEntriesSingleDay() {
        let calendar = utcCalendar()
        let day = calendar.date(from: DateComponents(year: 2026, month: 5, day: 22))!
        let snapshot = CalendarEventSnapshot(
            id: "evt",
            title: "Lunch",
            start: day.addingTimeInterval(12 * 3_600),
            end: day.addingTimeInterval(13 * 3_600),
            notes: "",
            isAllDay: false
        )
        let interval = DateInterval(
            start: day.addingTimeInterval(-2 * 86_400),
            end: day.addingTimeInterval(2 * 86_400)
        )

        let entries = SystemCalendarService.dayEntriesSpanning(snapshot, within: interval, calendar: calendar)

        #expect(entries == [day])
    }

    @Test("Multi-day events report one entry per calendar day they span")
    func dayEntriesMultiDay() {
        let calendar = utcCalendar()
        let day1 = calendar.date(from: DateComponents(year: 2026, month: 5, day: 22))!
        let day2 = calendar.date(byAdding: .day, value: 1, to: day1)!
        let day3 = calendar.date(byAdding: .day, value: 2, to: day1)!
        let snapshot = CalendarEventSnapshot(
            id: "evt",
            title: "Retreat",
            start: day1.addingTimeInterval(22 * 3_600),
            end: day3.addingTimeInterval(10 * 3_600),
            notes: "",
            isAllDay: false
        )
        let interval = DateInterval(
            start: day1.addingTimeInterval(-86_400),
            end: day3.addingTimeInterval(2 * 86_400)
        )

        let entries = SystemCalendarService.dayEntriesSpanning(snapshot, within: interval, calendar: calendar)

        #expect(entries == [day1, day2, day3])
    }

    @Test("Events outside the interval are clamped to the interval bounds")
    func dayEntriesClampsToInterval() {
        let calendar = utcCalendar()
        let day1 = calendar.date(from: DateComponents(year: 2026, month: 5, day: 22))!
        let day2 = calendar.date(byAdding: .day, value: 1, to: day1)!
        let day3 = calendar.date(byAdding: .day, value: 2, to: day1)!

        let snapshot = CalendarEventSnapshot(
            id: "evt",
            title: "Conference",
            start: day1.addingTimeInterval(-2 * 86_400),
            end: day3.addingTimeInterval(2 * 86_400),
            notes: "",
            isAllDay: false
        )
        let interval = DateInterval(
            start: day1.addingTimeInterval(8 * 3_600),
            end: day2.addingTimeInterval(20 * 3_600)
        )

        let entries = SystemCalendarService.dayEntriesSpanning(snapshot, within: interval, calendar: calendar)

        #expect(entries == [day1, day2])
    }

    @Test("All-day events (start of day → start of next day) include both day buckets")
    func dayEntriesAllDayInclusiveEndBoundary() {
        let calendar = utcCalendar()
        let day1 = calendar.date(from: DateComponents(year: 2026, month: 5, day: 22))!
        let day2 = calendar.date(byAdding: .day, value: 1, to: day1)!

        let snapshot = CalendarEventSnapshot(
            id: "evt",
            title: "Holiday",
            start: day1,
            end: day2,
            notes: "",
            isAllDay: true
        )
        let interval = DateInterval(
            start: day1.addingTimeInterval(-86_400),
            end: day2.addingTimeInterval(86_400)
        )

        let entries = SystemCalendarService.dayEntriesSpanning(snapshot, within: interval, calendar: calendar)

        #expect(entries == [day1, day2])
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
}
