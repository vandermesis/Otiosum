import Foundation

struct TimelineBlockClassification: Equatable, Sendable {
    let nowBlock: PlannedBlock?
    let nextBlock: PlannedBlock?
    let laterBlocks: [PlannedBlock]
}

struct TimelineBlockClassifier {
    func classify(
        blocks: [PlannedBlock],
        now: Date
    ) -> TimelineBlockClassification {
        let incompleteBlocks = blocks
            .filter { $0.isCompleted == false && $0.isAllDay == false }
            .sorted(by: blockSort)

        let nowBlock = incompleteBlocks.last(where: { now >= $0.start && now < $0.end })
        let nextBlock = incompleteBlocks.first(where: { $0.start > now })
        let laterBlocks = incompleteBlocks.filter { block in
            block.id != nowBlock?.id && block.id != nextBlock?.id && block.start >= now
        }

        return TimelineBlockClassification(
            nowBlock: nowBlock,
            nextBlock: nextBlock,
            laterBlocks: laterBlocks
        )
    }

    private func blockSort(_ lhs: PlannedBlock, _ rhs: PlannedBlock) -> Bool {
        if lhs.start == rhs.start {
            return lhs.end < rhs.end
        }

        return lhs.start < rhs.start
    }
}
