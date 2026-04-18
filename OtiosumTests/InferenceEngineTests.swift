import Foundation
import Testing
@testable import Otiosum

struct InferenceEngineTests {
    private let engine = InferenceEngine()

    @Test("Completed blocks are always marked complete")
    func completedBlockAssessment() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let block = makeBlock(
            start: now.addingTimeInterval(-300),
            end: now.addingTimeInterval(300),
            isCompleted: true
        )

        let assessment = engine.assess(
            block: block,
            now: now,
            context: InferenceContext(now: now, isSceneActive: true, lastUserInteraction: now)
        )

        #expect(assessment.status == .complete)
        #expect(assessment.confidence == 1)
    }

    @Test("Protected blocks are marked as protected time")
    func protectedBlockAssessment() {
        let now = Date(timeIntervalSinceReferenceDate: 2_000)
        let block = makeBlock(
            start: now.addingTimeInterval(-600),
            end: now.addingTimeInterval(600),
            source: .template,
            kind: .protectedTime,
            protectedCategory: .rest
        )

        let assessment = engine.assess(
            block: block,
            now: now,
            context: InferenceContext(now: now, isSceneActive: false, lastUserInteraction: nil)
        )

        #expect(assessment.status == .protectedTime)
        #expect(assessment.confidence == 1)
    }

    @Test("Active block gets likely in progress with interaction confidence boost")
    func activeBlockAssessment() {
        let now = Date(timeIntervalSinceReferenceDate: 3_600)
        let block = makeBlock(
            start: now.addingTimeInterval(-120),
            end: now.addingTimeInterval(900)
        )

        let assessment = engine.assess(
            block: block,
            now: now,
            context: InferenceContext(now: now, isSceneActive: true, lastUserInteraction: now.addingTimeInterval(-45))
        )

        #expect(assessment.status == .likelyInProgress)
        #expect(assessment.confidence == 0.97)
    }

    @Test("Recently ended blocks are marked gently late")
    func gentlyLateAssessment() {
        let now = Date(timeIntervalSinceReferenceDate: 8_000)
        let block = makeBlock(
            start: now.addingTimeInterval(-2_700),
            end: now.addingTimeInterval(-900)
        )

        let assessment = engine.assess(
            block: block,
            now: now,
            context: InferenceContext(now: now, isSceneActive: false, lastUserInteraction: nil)
        )

        #expect(assessment.status == .gentlyLate)
        #expect(abs(assessment.confidence - 0.6666666666666666) < 0.0001)
    }

    @Test("Far past blocks become waiting")
    func waitingAssessment() {
        let now = Date(timeIntervalSinceReferenceDate: 20_000)
        let block = makeBlock(
            start: now.addingTimeInterval(-10_000),
            end: now.addingTimeInterval(-8_000)
        )

        let assessment = engine.assess(
            block: block,
            now: now,
            context: InferenceContext(now: now, isSceneActive: false, lastUserInteraction: nil)
        )

        #expect(assessment.status == .waiting)
        #expect(assessment.confidence == 0.3)
    }

    @Test("Overrun returns nil when confidence is too low")
    func overrunRequiresConfidence() {
        let now = Date(timeIntervalSinceReferenceDate: 30_000)
        let block = makeBlock(
            start: now.addingTimeInterval(-7_200),
            end: now.addingTimeInterval(-5_400)
        )

        let overrunEnd = engine.overrunEnd(
            for: block,
            now: now,
            context: InferenceContext(now: now, isSceneActive: false, lastUserInteraction: nil),
            transitionBufferMinutes: 10
        )

        #expect(overrunEnd == nil)
    }

    @Test("Overrun rounds up to five minutes and applies transition buffer")
    func overrunRoundingAndBuffer() throws {
        let blockStart = Date(timeIntervalSinceReferenceDate: 40_000)
        let blockEnd = blockStart.adding(minutes: 30)
        let now = blockEnd.adding(minutes: 2)
        let block = makeBlock(start: blockStart, end: blockEnd)

        let overrunEnd = engine.overrunEnd(
            for: block,
            now: now,
            context: InferenceContext(now: now, isSceneActive: true, lastUserInteraction: now),
            transitionBufferMinutes: 10
        )

        let resolvedOverrunEnd = try #require(overrunEnd)
        let expected = Date(timeIntervalSinceReferenceDate: 42_600)
        #expect(resolvedOverrunEnd == expected)
    }

    private func makeBlock(
        start: Date,
        end: Date,
        source: PlannerItemSource = .local,
        kind: PlannerItemKind = .task,
        flexibility: PlannerFlexibility = .flexible,
        protectedCategory: ProtectedCategory? = nil,
        isCompleted: Bool = false
    ) -> PlannedBlock {
        PlannedBlock(
            id: UUID(),
            itemID: UUID(),
            calendarEventID: nil,
            title: "Block",
            start: start,
            end: end,
            source: source,
            kind: kind,
            flexibility: flexibility,
            symbolName: "checklist",
            tintToken: "mint",
            notes: "",
            protectedCategory: protectedCategory,
            isCompleted: isCompleted,
            status: .upcoming,
            confidence: 0.5
        )
    }
}
