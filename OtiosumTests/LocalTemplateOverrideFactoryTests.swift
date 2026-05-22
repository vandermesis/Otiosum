import Foundation
import Testing
@testable import Otiosum

struct LocalTemplateOverrideFactoryTests {
    private let factory = LocalTemplateOverrideFactory(calendar: LocalTemplateOverrideFactoryTests.calendar)

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }()

    @Test("Factory replaces matching template block with local override block")
    func replacesMatchingTemplateBlock() throws {
        let day = try makeDate(year: 2026, month: 5, day: 22)
        let overrideID = UUID()
        let templateBlock = makeBlock(
            title: "Breakfast",
            start: day.adding(minutes: 8 * 60),
            durationMinutes: 40,
            routineRole: .meal
        )
        let override = makeItem(
            id: overrideID,
            title: "Breakfast",
            day: day,
            preferredStartMinutes: 9 * 60,
            durationMinutes: 30,
            routineRole: .meal
        )

        let result = factory.makeOverrides(
            localItems: [override],
            day: day,
            templateBlocks: [templateBlock],
            endOfDay: day.adding(minutes: 24 * 60)
        )

        #expect(result.overrideItemIDs == [overrideID])
        #expect(result.remainingTemplateBlocks.isEmpty)

        let overrideBlock = try #require(result.overrideBlocks.first)
        #expect(overrideBlock.itemID == overrideID)
        #expect(overrideBlock.source == .local)
        #expect(overrideBlock.start == day.adding(minutes: 9 * 60))
        #expect(overrideBlock.end == day.adding(minutes: 9 * 60 + 30))
    }

    @Test("Factory keeps nonmatching template blocks")
    func keepsNonmatchingTemplateBlocks() throws {
        let day = try makeDate(year: 2026, month: 5, day: 22)
        let templateBlock = makeBlock(
            title: "Lunch",
            start: day.adding(minutes: 12 * 60),
            durationMinutes: 40,
            routineRole: .meal
        )
        let override = makeItem(
            id: UUID(),
            title: "Workout",
            day: day,
            preferredStartMinutes: 9 * 60,
            durationMinutes: 30,
            routineRole: .workout
        )

        let result = factory.makeOverrides(
            localItems: [override],
            day: day,
            templateBlocks: [templateBlock],
            endOfDay: day.adding(minutes: 24 * 60)
        )

        #expect(result.overrideItemIDs.isEmpty)
        #expect(result.overrideBlocks.isEmpty)
        #expect(result.remainingTemplateBlocks == [templateBlock])
    }

    @Test("Factory ignores saved, unscheduled, and different-day items")
    func ignoresItemsThatCannotOverrideTemplate() throws {
        let day = try makeDate(year: 2026, month: 5, day: 22)
        let otherDay = day.adding(minutes: 24 * 60)
        let templateBlock = makeBlock(
            title: "Breakfast",
            start: day.adding(minutes: 8 * 60),
            durationMinutes: 40,
            routineRole: .meal
        )
        let ignoredItems = [
            makeItem(id: UUID(), title: "Breakfast", day: nil, preferredStartMinutes: 9 * 60, durationMinutes: 30, routineRole: .meal),
            makeItem(id: UUID(), title: "Breakfast", day: otherDay, preferredStartMinutes: 9 * 60, durationMinutes: 30, routineRole: .meal),
            makeItem(id: UUID(), title: "Breakfast", day: day, preferredStartMinutes: 9 * 60, durationMinutes: 30, routineRole: nil),
            makeItem(id: UUID(), title: "Breakfast", day: day, preferredStartMinutes: 9 * 60, durationMinutes: 30, routineRole: .meal, isSavedForLater: true)
        ]

        let result = factory.makeOverrides(
            localItems: ignoredItems,
            day: day,
            templateBlocks: [templateBlock],
            endOfDay: day.adding(minutes: 24 * 60)
        )

        #expect(result.overrideItemIDs.isEmpty)
        #expect(result.overrideBlocks.isEmpty)
        #expect(result.remainingTemplateBlocks == [templateBlock])
    }

    private func makeItem(
        id: UUID,
        title: String,
        day: Date?,
        preferredStartMinutes: Int,
        durationMinutes: Int,
        routineRole: RoutineRole?,
        isSavedForLater: Bool = false
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
            routineRole: routineRole,
            notes: "",
            isCompleted: false,
            orderHint: 1,
            isSavedForLater: isSavedForLater,
            forceAfterBedtime: false
        )
    }

    private func makeBlock(
        title: String,
        start: Date,
        durationMinutes: Int,
        routineRole: RoutineRole?
    ) -> PlannedBlock {
        PlannedBlock(
            id: UUID(),
            itemID: UUID(),
            calendarEventID: nil,
            title: title,
            start: start,
            end: start.adding(minutes: durationMinutes),
            source: .template,
            flexibility: .flexible,
            symbolName: "star",
            tintToken: "sky",
            notes: "",
            isAllDay: false,
            routineRole: routineRole,
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
