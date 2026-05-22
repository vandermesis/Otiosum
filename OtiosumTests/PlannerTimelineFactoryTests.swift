import Foundation
import Testing
@testable import Otiosum

struct PlannerTimelineFactoryTests {
    private let factory = PlannerTimelineFactory(calendar: PlannerTimelineFactoryTests.calendar)

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }()

    @Test("Factory includes all-day calendar blocks in final timeline")
    func includesAllDayCalendarBlocks() throws {
        let day = try makeDate(year: 2026, month: 5, day: 22)
        let calendarEvent = CalendarEventSnapshot(
            id: "all-day",
            title: "Holiday",
            start: day,
            end: day.adding(minutes: 24 * 60),
            notes: "",
            isAllDay: true
        )

        let result = factory.makeTimeline(
            for: day,
            localItems: [],
            calendarEvents: [calendarEvent],
            calendarLinks: [],
            template: .default,
            budget: .default,
            bounds: PlanningDayBounds.make(for: day, template: .default, calendar: Self.calendar),
            context: InferenceContext(now: day.adding(minutes: 9 * 60), isSceneActive: true, lastUserInteraction: nil)
        )

        let allDayBlock = try #require(result.blocks.first { $0.calendarEventID == "all-day" })
        #expect(allDayBlock.isAllDay)
        #expect(allDayBlock.title == "Holiday")
    }

    @Test("Factory schedules local items around fixed calendar blocks")
    func schedulesLocalItemsAroundFixedCalendarBlocks() throws {
        let day = try makeDate(year: 2026, month: 5, day: 22)
        let itemID = UUID()
        let localItem = makeItem(
            id: itemID,
            day: day,
            preferredStartMinutes: 9 * 60,
            durationMinutes: 30
        )
        let calendarEvent = CalendarEventSnapshot(
            id: "standup",
            title: "Standup",
            start: day.adding(minutes: 9 * 60),
            end: day.adding(minutes: 9 * 60 + 30),
            notes: "",
            isAllDay: false
        )

        let result = factory.makeTimeline(
            for: day,
            localItems: [localItem],
            calendarEvents: [calendarEvent],
            calendarLinks: [],
            template: .default,
            budget: .default,
            bounds: PlanningDayBounds.make(for: day, template: .default, calendar: Self.calendar),
            context: InferenceContext(now: day.adding(minutes: 8 * 60), isSceneActive: true, lastUserInteraction: nil)
        )

        let localBlock = try #require(result.blocks.first { $0.itemID == itemID })
        #expect(localBlock.start >= calendarEvent.end)
        #expect(result.tooMuchTodayIssues.isEmpty)
    }

    private func makeItem(
        id: UUID,
        day: Date,
        preferredStartMinutes: Int,
        durationMinutes: Int
    ) -> EventSnapshot {
        EventSnapshot(
            id: id,
            title: "Task",
            source: .local,
            suggestedIcon: "star",
            tintToken: "sky",
            targetDurationMinutes: durationMinutes,
            minimumDurationMinutes: durationMinutes,
            scheduledDay: day,
            preferredStartMinutes: preferredStartMinutes,
            preferredTimeWindow: .anytime,
            flexibility: .flexible,
            calendarEventID: nil,
            routineRole: nil,
            notes: "",
            isCompleted: false,
            orderHint: 1,
            isSavedForLater: false,
            forceAfterBedtime: false
        )
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
