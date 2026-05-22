import Foundation
import Testing
@testable import Otiosum

struct CalendarBlockFactoryTests {
    private let factory = CalendarBlockFactory()

    @Test("Calendar factory applies local overrides and link flexibility")
    func appliesOverridesAndFlexibility() throws {
        let day = Date(timeIntervalSinceReferenceDate: 300_000)
        let startOfDay = Calendar.current.startOfDay(for: day)
        let endOfDay = startOfDay.adding(minutes: 24 * 60)
        let eventStart = startOfDay.adding(minutes: 10 * 60)
        let overrideStart = startOfDay.adding(minutes: 11 * 60)
        let overrideEnd = startOfDay.adding(minutes: 11 * 60 + 45)
        let event = CalendarEventSnapshot(
            id: "calendar-1",
            title: "Team Standup",
            start: eventStart,
            end: eventStart.adding(minutes: 30),
            notes: "Bring updates",
            isAllDay: false
        )
        let link = CalendarLinkSnapshot(
            id: UUID(),
            calendarEventID: "calendar-1",
            flexibility: .flexible,
            editPolicy: .localOnly,
            localOverrideStart: overrideStart,
            localOverrideEnd: overrideEnd
        )

        let block = try #require(
            factory.makeBlocks(
                for: day,
                calendarEvents: [event],
                calendarLinks: [link],
                startOfDay: startOfDay,
                endOfDay: endOfDay
            ).first
        )

        #expect(block.calendarEventID == "calendar-1")
        #expect(block.start == overrideStart)
        #expect(block.end == overrideEnd)
        #expect(block.flexibility == .flexible)
        #expect(block.notes == "Bring updates")
    }

    @Test("Calendar factory clamps events to visible day")
    func clampsEventsToVisibleDay() throws {
        let day = Date(timeIntervalSinceReferenceDate: 400_000)
        let startOfDay = Calendar.current.startOfDay(for: day)
        let endOfDay = startOfDay.adding(minutes: 24 * 60)
        let event = CalendarEventSnapshot(
            id: "calendar-2",
            title: "Overnight",
            start: startOfDay.adding(minutes: -60),
            end: endOfDay.adding(minutes: 60),
            notes: "",
            isAllDay: false
        )

        let block = try #require(
            factory.makeBlocks(
                for: day,
                calendarEvents: [event],
                calendarLinks: [],
                startOfDay: startOfDay,
                endOfDay: endOfDay
            ).first
        )

        #expect(block.start == startOfDay)
        #expect(block.end == endOfDay)
        #expect(block.flexibility == .askBeforeMove)
    }
}
