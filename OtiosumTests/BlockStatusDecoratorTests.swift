import Foundation
import Testing
@testable import Otiosum

struct BlockStatusDecoratorTests {
    private let decorator = BlockStatusDecorator()

    @Test("Started block is completed when its end has passed")
    func startedBlockCompletesAfterEnd() {
        let now = Date(timeIntervalSinceReferenceDate: 10_000)
        let block = makeBlock(
            start: now.adding(minutes: -45),
            durationMinutes: 30,
            isStarted: true
        )

        let decorated = decorator.decorate(
            blocks: [block],
            context: InferenceContext(now: now, isSceneActive: true, lastUserInteraction: nil)
        )

        #expect(decorated.first?.isCompleted == true)
        #expect(decorated.first?.isStarted == false)
    }

    @Test("Started block stays started before its end")
    func startedBlockStaysStartedBeforeEnd() {
        let now = Date(timeIntervalSinceReferenceDate: 20_000)
        let block = makeBlock(
            start: now.adding(minutes: -10),
            durationMinutes: 30,
            isStarted: true
        )

        let decorated = decorator.decorate(
            blocks: [block],
            context: InferenceContext(now: now, isSceneActive: true, lastUserInteraction: nil)
        )

        #expect(decorated.first?.isCompleted == false)
        #expect(decorated.first?.isStarted == true)
    }

    @Test("Decorated blocks are sorted by start and then end")
    func decoratedBlocksAreSorted() {
        let now = Date(timeIntervalSinceReferenceDate: 30_000)
        let later = makeBlock(title: "Later", start: now.adding(minutes: 30), durationMinutes: 30)
        let shorter = makeBlock(title: "Shorter", start: now, durationMinutes: 15)
        let longer = makeBlock(title: "Longer", start: now, durationMinutes: 30)

        let decorated = decorator.decorate(
            blocks: [later, longer, shorter],
            context: InferenceContext(now: now, isSceneActive: true, lastUserInteraction: nil)
        )

        #expect(decorated.map(\.title) == ["Shorter", "Longer", "Later"])
    }

    private func makeBlock(
        title: String = "Task",
        start: Date,
        durationMinutes: Int,
        isCompleted: Bool = false,
        isStarted: Bool = false
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
            symbolName: "circle",
            tintToken: "teal",
            notes: "",
            isAllDay: false,
            routineRole: nil,
            isCompleted: isCompleted,
            isStarted: isStarted,
            status: isCompleted ? .complete : .upcoming,
            confidence: 0.7
        )
    }
}
