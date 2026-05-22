import Foundation
import Testing
@testable import Otiosum

struct LocalBlockFactoryTests {
    private let factory = LocalBlockFactory(calendar: LocalBlockFactoryTests.calendar)

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }()

    @Test("Scheduled local items are placed after existing timeline conflicts")
    func scheduledItemsAvoidExistingBlocks() throws {
        let day = try makeDate(year: 2026, month: 5, day: 22)
        let itemID = UUID()
        let localItem = makeItem(
            id: itemID,
            title: "Write",
            day: day,
            preferredStartMinutes: 9 * 60,
            durationMinutes: 30
        )
        let fixedBlock = makeBlock(
            title: "Breakfast",
            start: day.adding(minutes: 9 * 60),
            durationMinutes: 40,
            source: .template,
            routineRole: .meal
        )

        let result = factory.makeBlocks(
            for: day,
            localItems: [localItem],
            templateBlocks: [],
            fixedBlocks: [fixedBlock],
            template: .default,
            endOfDay: day.adding(minutes: 24 * 60)
        )

        let localBlock = try #require(result.blocks.first { $0.itemID == itemID })
        #expect(localBlock.start >= fixedBlock.end)
        #expect(result.tooMuchTodayIssues.isEmpty)
    }

    @Test("Local routine overrides replace matching template blocks")
    func localRoutineOverridesReplaceMatchingTemplateBlocks() throws {
        let day = try makeDate(year: 2026, month: 5, day: 22)
        let overrideID = UUID()
        let breakfastTemplate = makeBlock(
            title: "Breakfast",
            start: day.adding(minutes: 8 * 60),
            durationMinutes: 40,
            source: .template,
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

        let result = factory.makeBlocks(
            for: day,
            localItems: [override],
            templateBlocks: [breakfastTemplate],
            fixedBlocks: [],
            template: .default,
            endOfDay: day.adding(minutes: 24 * 60)
        )

        let breakfastBlocks = result.blocks.filter { $0.title == "Breakfast" }
        let breakfast = try #require(breakfastBlocks.first)
        #expect(breakfastBlocks.count == 1)
        #expect(breakfast.itemID == overrideID)
        #expect(breakfast.source == .local)
        #expect(breakfast.start == day.adding(minutes: 9 * 60))
    }

    @Test("Local placement returns Too Much Today when no room remains")
    func localPlacementReportsOverflow() throws {
        let day = try makeDate(year: 2026, month: 5, day: 22)
        let itemID = UUID()
        let lateItem = makeItem(
            id: itemID,
            title: "Late task",
            day: day,
            preferredStartMinutes: 23 * 60 + 45,
            durationMinutes: 30
        )

        let result = factory.makeBlocks(
            for: day,
            localItems: [lateItem],
            templateBlocks: [],
            fixedBlocks: [],
            template: .default,
            endOfDay: day.adding(minutes: 24 * 60)
        )

        #expect(result.blocks.isEmpty)
        #expect(result.tooMuchTodayIssues.first?.itemID == itemID)
    }

    private func makeItem(
        id: UUID,
        title: String,
        day: Date,
        preferredStartMinutes: Int,
        durationMinutes: Int,
        routineRole: RoutineRole? = nil
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
            isSavedForLater: false,
            forceAfterBedtime: false
        )
    }

    private func makeBlock(
        title: String,
        start: Date,
        durationMinutes: Int,
        source: PlannerItemSource,
        routineRole: RoutineRole?
    ) -> PlannedBlock {
        PlannedBlock(
            id: UUID(),
            itemID: UUID(),
            calendarEventID: nil,
            title: title,
            start: start,
            end: start.adding(minutes: durationMinutes),
            source: source,
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
