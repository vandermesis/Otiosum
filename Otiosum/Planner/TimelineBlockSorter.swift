import Foundation

enum TimelineBlockSorter {
    nonisolated static func areInTimelineOrder(_ lhs: PlannedBlock, _ rhs: PlannedBlock) -> Bool {
        if lhs.start == rhs.start {
            return lhs.end < rhs.end
        }

        return lhs.start < rhs.start
    }
}
