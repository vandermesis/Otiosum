import Foundation
import Testing
@testable import Otiosum

struct LocalItemTimelinePlacerTests {
    private let placer = LocalItemTimelinePlacer(calendar: LocalItemTimelinePlacerTests.calendar)

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }()

    @Test("Placer schedules item at preferred start when space is free")
    func schedulesItemAtPreferredStart() throws {
        let day = try makeDate(year: 2026, month: 5, day: 22)
        let itemID = UUID()
        let item = makeItem(
            id: itemID,
            title: "Write",
            day: day,
            preferredStartMinutes: 9 * 60,
            durationMinutes: 30
        )

        let result = placer.place(
            item: item,
            day: day,
            existingBlocks: [],
            template: .default,
            endOfDay: day.adding(minutes: 24 * 60)
        )

        let block = try #require(result.block)
        #expect(block.itemID == itemID)
        #expect(block.start == day.adding(minutes: 9 * 60))
        #expect(result.tooMuchTodayIssue == nil)
    }

    @Test("Placer moves item after conflicting block")
    func movesItemAfterConflict() throws {
        let day = try makeDate(year: 2026, month: 5, day: 22)
        let itemID = UUID()
        let item = makeItem(
            id: itemID,
            title: "Write",
            day: day,
            preferredStartMinutes: 9 * 60,
            durationMinutes: 30
        )
        let existingBlock = makeBlock(
            title: "Breakfast",
            start: day.adding(minutes: 9 * 60),
            durationMinutes: 40
        )

        let result = placer.place(
            item: item,
            day: day,
            existingBlocks: [existingBlock],
            template: .default,
            endOfDay: day.adding(minutes: 24 * 60)
        )

        let block = try #require(result.block)
        #expect(block.start == existingBlock.end.adding(minutes: DayTemplateSnapshot.default.transitionBufferMinutes))
        #expect(result.tooMuchTodayIssue == nil)
    }

    @Test("Placer reports Too Much Today when item does not fit")
    func reportsTooMuchTodayWhenItemDoesNotFit() throws {
        let day = try makeDate(year: 2026, month: 5, day: 22)
        let itemID = UUID()
        let item = makeItem(
            id: itemID,
            title: "Late task",
            day: day,
            preferredStartMinutes: 23 * 60 + 45,
            durationMinutes: 30
        )

        let result = placer.place(
            item: item,
            day: day,
            existingBlocks: [],
            template: .default,
            endOfDay: day.adding(minutes: 24 * 60)
        )

        #expect(result.block == nil)
        #expect(result.tooMuchTodayIssue?.itemID == itemID)
        #expect(result.tooMuchTodayIssue?.displacedRole == .sleep)
    }

    private func makeItem(
        id: UUID,
        title: String,
        day: Date,
        preferredStartMinutes: Int,
        durationMinutes: Int
    ) -> EventSnapshot {
        EventSnapshot(
            id: id,
            title: title,
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

    private func makeBlock(
        title: String,
        start: Date,
        durationMinutes: Int
    ) -> PlannedBlock {
        PlannedBlock(
            id: UUID(),
            itemID: UUID(),
            calendarEventID: nil,
            title: title,
            start: start,
            end: start.adding(minutes: durationMinutes),
            source: .local,
            flexibility: .flexible,
            symbolName: "star",
            tintToken: "sky",
            notes: "",
            isAllDay: false,
            routineRole: nil,
            isCompleted: false,
            status: .upcoming,
            confidence: 0.7
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
