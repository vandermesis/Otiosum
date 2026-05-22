import Foundation

struct BlockStatusDecorator {
    private let inferenceEngine: InferenceEngine

    init(inferenceEngine: InferenceEngine = InferenceEngine()) {
        self.inferenceEngine = inferenceEngine
    }

    func decorate(
        blocks: [PlannedBlock],
        context: InferenceContext
    ) -> [PlannedBlock] {
        blocks.map { block in
            let assessment = inferenceEngine.assess(block: block, now: context.now, context: context)
            let resolvedCompletion = block.isCompleted || (block.isStarted && context.now >= block.end)
            return PlannedBlock(
                id: block.id,
                itemID: block.itemID,
                calendarEventID: block.calendarEventID,
                title: block.title,
                start: block.start,
                end: block.end,
                source: block.source,
                flexibility: block.flexibility,
                symbolName: block.symbolName,
                tintToken: block.tintToken,
                notes: block.notes,
                isAllDay: block.isAllDay,
                routineRole: block.routineRole,
                isCompleted: resolvedCompletion,
                isStarted: resolvedCompletion ? false : block.isStarted,
                status: assessment.status,
                confidence: assessment.confidence
            )
        }
        .sorted(by: TimelineBlockSorter.areInTimelineOrder)
    }
}
