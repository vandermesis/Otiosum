import Foundation
import Testing
@testable import Otiosum

struct LocalScheduledItemSelectorTests {
    private let selector = LocalScheduledItemSelector(calendar: LocalScheduledItemSelectorTests.calendar)

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }()

    @Test("Selector keeps only items scheduled for the visible day")
    func keepsOnlyItemsForVisibleDay() throws {
        let day = try makeDate(year: 2026, month: 5, day: 22)
        let nextDay = day.adding(minutes: 24 * 60)
        let selectedID = UUID()
        let excludedID = UUID()
        let items = [
            makeItem(id: selectedID, day: day, preferredStartMinutes: 9 * 60, orderHint: 1),
            makeItem(id: excludedID, day: nextDay, preferredStartMinutes: 9 * 60, orderHint: 2),
            makeItem(id: UUID(), day: nil, preferredStartMinutes: 9 * 60, orderHint: 3)
        ]

        let selected = selector.scheduledItems(
            from: items,
            day: day,
            excludingItemIDs: []
        )

        #expect(selected.map(\.id) == [selectedID])
        #expect(selected.contains { $0.id == excludedID } == false)
    }

    @Test("Selector ignores saved and template override items")
    func ignoresSavedAndTemplateOverrideItems() throws {
        let day = try makeDate(year: 2026, month: 5, day: 22)
        let selectedID = UUID()
        let overrideID = UUID()
        let items = [
            makeItem(id: selectedID, day: day, preferredStartMinutes: 9 * 60, orderHint: 1),
            makeItem(id: overrideID, day: day, preferredStartMinutes: 10 * 60, orderHint: 2),
            makeItem(id: UUID(), day: day, preferredStartMinutes: 11 * 60, orderHint: 3, isSavedForLater: true)
        ]

        let selected = selector.scheduledItems(
            from: items,
            day: day,
            excludingItemIDs: [overrideID]
        )

        #expect(selected.map(\.id) == [selectedID])
    }

    @Test("Selector orders by preferred start and then order hint")
    func ordersByPreferredStartAndOrderHint() throws {
        let day = try makeDate(year: 2026, month: 5, day: 22)
        let firstID = UUID()
        let secondID = UUID()
        let thirdID = UUID()
        let items = [
            makeItem(id: thirdID, day: day, preferredStartMinutes: 10 * 60, orderHint: 1),
            makeItem(id: secondID, day: day, preferredStartMinutes: 9 * 60, orderHint: 2),
            makeItem(id: firstID, day: day, preferredStartMinutes: 9 * 60, orderHint: 1)
        ]

        let selected = selector.scheduledItems(
            from: items,
            day: day,
            excludingItemIDs: []
        )

        #expect(selected.map(\.id) == [firstID, secondID, thirdID])
    }

    private func makeItem(
        id: UUID,
        day: Date?,
        preferredStartMinutes: Int,
        orderHint: Double,
        isSavedForLater: Bool = false
    ) -> EventSnapshot {
        EventSnapshot(
            id: id,
            title: "Task",
            source: .local,
            suggestedIcon: "star",
            tintToken: "sky",
            targetDurationMinutes: 30,
            minimumDurationMinutes: 30,
            scheduledDay: day,
            preferredStartMinutes: preferredStartMinutes,
            preferredTimeWindow: .anytime,
            flexibility: .flexible,
            calendarEventID: nil,
            routineRole: nil,
            notes: "",
            isCompleted: false,
            orderHint: orderHint,
            isSavedForLater: isSavedForLater,
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
