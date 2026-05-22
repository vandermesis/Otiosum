import Foundation
import Testing
@testable import Otiosum

struct TimelineBlockClassifierTests {
    private let classifier = TimelineBlockClassifier()

    @Test("Classifier selects current, next, and later incomplete timed blocks")
    func selectsCurrentNextAndLaterBlocks() {
        let now = Date(timeIntervalSinceReferenceDate: 10_000)
        let current = makeBlock(
            title: "Current",
            start: now.adding(minutes: -10),
            durationMinutes: 30
        )
        let next = makeBlock(
            title: "Next",
            start: now.adding(minutes: 40),
            durationMinutes: 30
        )
        let later = makeBlock(
            title: "Later",
            start: now.adding(minutes: 90),
            durationMinutes: 30
        )

        let result = classifier.classify(blocks: [later, next, current], now: now)

        #expect(result.nowBlock == current)
        #expect(result.nextBlock == next)
        #expect(result.laterBlocks == [later])
    }

    @Test("Classifier ignores completed and all-day blocks")
    func ignoresCompletedAndAllDayBlocks() {
        let now = Date(timeIntervalSinceReferenceDate: 20_000)
        let completed = makeBlock(
            title: "Completed",
            start: now.adding(minutes: -10),
            durationMinutes: 30,
            isCompleted: true
        )
        let allDay = makeBlock(
            title: "All day",
            start: now.adding(minutes: 20),
            durationMinutes: 24 * 60,
            isAllDay: true
        )
        let next = makeBlock(
            title: "Next",
            start: now.adding(minutes: 40),
            durationMinutes: 30
        )

        let result = classifier.classify(blocks: [completed, allDay, next], now: now)

        #expect(result.nowBlock == nil)
        #expect(result.nextBlock == next)
        #expect(result.laterBlocks.isEmpty)
    }

    @Test("Classifier treats a block ending exactly now as past")
    func blockEndingExactlyNowIsPast() {
        let now = Date(timeIntervalSinceReferenceDate: 30_000)
        let ended = makeBlock(
            title: "Ended",
            start: now.adding(minutes: -30),
            durationMinutes: 30
        )
        let next = makeBlock(
            title: "Next",
            start: now.adding(minutes: 15),
            durationMinutes: 30
        )

        let result = classifier.classify(blocks: [ended, next], now: now)

        #expect(result.nowBlock == nil)
        #expect(result.nextBlock == next)
        #expect(result.laterBlocks.isEmpty)
    }

    private func makeBlock(
        title: String,
        start: Date,
        durationMinutes: Int,
        isCompleted: Bool = false,
        isAllDay: Bool = false
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
            isAllDay: isAllDay,
            routineRole: nil,
            isCompleted: isCompleted,
            status: .upcoming,
            confidence: 0.7
        )
    }
}
