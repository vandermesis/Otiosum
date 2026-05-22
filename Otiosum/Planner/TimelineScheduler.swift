import Foundation

struct TimelineScheduleResult: Equatable, Sendable {
    let blocks: [PlannedBlock]
    let sleepCollisionIssues: [TooMuchTodayIssue]
}

struct TimelineMoveResult: Equatable, Sendable {
    let block: PlannedBlock
    let proposedStart: Date
    let canMove: Bool
    let conflictingBlock: PlannedBlock?
}

struct TimelineScheduler {
    private let calendar: Calendar
    private let stepMinutes: Int
    private let issueDeduplicator: TooMuchTodayIssueDeduplicator

    init(
        calendar: Calendar = .current,
        stepMinutes: Int = 5,
        issueDeduplicator: TooMuchTodayIssueDeduplicator = TooMuchTodayIssueDeduplicator()
    ) {
        self.calendar = calendar
        self.stepMinutes = stepMinutes
        self.issueDeduplicator = issueDeduplicator
    }

    func schedule(
        blocks: [PlannedBlock],
        now: Date,
        day: Date,
        transitionBufferMinutes: Int
    ) -> TimelineScheduleResult {
        let dayStart = calendar.startOfDay(for: day)
        guard calendar.isDate(now, inSameDayAs: dayStart) else {
            return TimelineScheduleResult(blocks: compacted(blocks, transitionBufferMinutes: transitionBufferMinutes), sleepCollisionIssues: [])
        }

        let sortedBlocks = blocks.sorted(by: TimelineBlockSorter.areInTimelineOrder)
        guard let pushIndex = sortedBlocks.firstIndex(where: { shouldPushByCurrentTime($0, now: now) }) else {
            return TimelineScheduleResult(blocks: compacted(sortedBlocks, transitionBufferMinutes: transitionBufferMinutes), sleepCollisionIssues: [])
        }

        var result = Array(sortedBlocks.prefix(pushIndex))
        let roundedNow = roundUp(now)
        var sleepCollisionIssues: [TooMuchTodayIssue] = []
        var runningEnd = roundedNow
        var sleepPressureSource: PlannedBlock?

        for block in sortedBlocks.dropFirst(pushIndex) {
            let duration = block.end.timeIntervalSince(block.start)
            let proposedStart = max(block.start, runningEnd)
            let proposedEnd = proposedStart.addingTimeInterval(duration)

            if isSleep(block) == false && block.source == .local && proposedStart != block.start {
                sleepPressureSource = block
            }

            if isSleep(block), proposedStart != block.start {
                let source = sleepPressureSource ?? block
                sleepCollisionIssues.append(
                    TooMuchTodayIssue(
                        itemID: source.itemID,
                        title: source.title,
                        message: "This plan is starting to push sleep.",
                        displacedRole: .sleep,
                        suggestedDate: calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
                    )
                )
            }

            let shiftedBlock = shifted(
                block: block,
                start: proposedStart,
                end: proposedEnd
            )
            result.append(shiftedBlock)
            runningEnd = proposedEnd.adding(minutes: transitionBufferMinutes)
        }

        return TimelineScheduleResult(
            blocks: compacted(result, transitionBufferMinutes: transitionBufferMinutes),
            sleepCollisionIssues: issueDeduplicator.deduplicate(sleepCollisionIssues)
        )
    }

    func moveResult(
        for movingBlock: PlannedBlock,
        to proposedStart: Date,
        among blocks: [PlannedBlock]
    ) -> TimelineMoveResult {
        let conflict = conflict(
            for: movingBlock.itemID,
            proposedStart: proposedStart,
            durationMinutes: movingBlock.durationMinutes,
            among: blocks
        )

        return TimelineMoveResult(
            block: movingBlock,
            proposedStart: proposedStart,
            canMove: conflict == nil,
            conflictingBlock: conflict
        )
    }

    func conflict(
        for itemID: UUID,
        proposedStart: Date,
        durationMinutes: Int,
        among blocks: [PlannedBlock]
    ) -> PlannedBlock? {
        let proposedEnd = proposedStart.adding(minutes: durationMinutes)
        return blocks.first { block in
            guard block.itemID != itemID else { return false }
            guard block.isAllDay == false else { return false }
            return proposedStart < block.end && proposedEnd > block.start
        }
    }

    private func compacted(
        _ blocks: [PlannedBlock],
        transitionBufferMinutes: Int
    ) -> [PlannedBlock] {
        var result: [PlannedBlock] = []
        var runningEnd: Date?

        for block in blocks.sorted(by: TimelineBlockSorter.areInTimelineOrder) {
            guard block.isAllDay == false else {
                result.append(block)
                continue
            }

            let duration = block.end.timeIntervalSince(block.start)
            let start = runningEnd.map { max(block.start, $0) } ?? block.start
            let end = start.addingTimeInterval(duration)
            result.append(shifted(block: block, start: start, end: end))
            runningEnd = end.adding(minutes: transitionBufferMinutes)
        }

        return result.sorted(by: TimelineBlockSorter.areInTimelineOrder)
    }

    private func shouldPushByCurrentTime(_ block: PlannedBlock, now: Date) -> Bool {
        block.isAllDay == false
            && block.isCompleted == false
            && block.isStarted == false
            && block.source != .calendar
            && block.start <= now
    }

    private func isSleep(_ block: PlannedBlock) -> Bool {
        block.routineRole == .sleep || block.title.localizedCaseInsensitiveCompare("Sleep") == .orderedSame
    }

    private func shifted(
        block: PlannedBlock,
        start: Date,
        end: Date
    ) -> PlannedBlock {
        PlannedBlock(
            id: block.id,
            itemID: block.itemID,
            calendarEventID: block.calendarEventID,
            title: block.title,
            start: start,
            end: end,
            source: block.source,
            flexibility: block.flexibility,
            symbolName: block.symbolName,
            tintToken: block.tintToken,
            notes: block.notes,
            isAllDay: block.isAllDay,
            routineRole: block.routineRole,
            isCompleted: block.isCompleted,
            isStarted: block.isStarted,
            status: block.status,
            confidence: block.confidence
        )
    }

    private func roundUp(_ date: Date) -> Date {
        let interval = TimeInterval(stepMinutes * 60)
        let rounded = ceil(date.timeIntervalSinceReferenceDate / interval) * interval
        return Date(timeIntervalSinceReferenceDate: rounded)
    }

}
