import Foundation
import Testing
@testable import Otiosum

struct TimelineBlockSorterTests {
    @Test("Sorter orders blocks by start time")
    func ordersByStartTime() {
        let start = Date(timeIntervalSinceReferenceDate: 800_000)
        let blocks = [
            block(title: "Second", start: start.adding(minutes: 30), duration: 15),
            block(title: "First", start: start, duration: 15)
        ]

        let sorted = blocks.sorted(by: TimelineBlockSorter.areInTimelineOrder)

        #expect(sorted.map(\.title) == ["First", "Second"])
    }

    @Test("Sorter orders equal starts by shorter end time")
    func ordersEqualStartsByEndTime() {
        let start = Date(timeIntervalSinceReferenceDate: 800_000)
        let blocks = [
            block(title: "Long", start: start, duration: 60),
            block(title: "Short", start: start, duration: 15)
        ]

        let sorted = blocks.sorted(by: TimelineBlockSorter.areInTimelineOrder)

        #expect(sorted.map(\.title) == ["Short", "Long"])
    }

    private func block(title: String, start: Date, duration: Int) -> PlannedBlock {
        PlannedBlock(
            id: UUID(),
            itemID: UUID(),
            calendarEventID: nil,
            title: title,
            start: start,
            end: start.adding(minutes: duration),
            source: .local,
            flexibility: .flexible,
            symbolName: "circle",
            tintToken: "teal",
            notes: "",
            isAllDay: false,
            routineRole: nil,
            isCompleted: false,
            status: .upcoming,
            confidence: 0.7
        )
    }
}
