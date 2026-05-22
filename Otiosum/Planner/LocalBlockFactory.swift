import Foundation

struct LocalBlockFactoryResult: Equatable, Sendable {
    let blocks: [PlannedBlock]
    let tooMuchTodayIssues: [TooMuchTodayIssue]
}

struct LocalBlockFactory {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func makeBlocks(
        for day: Date,
        localItems: [EventSnapshot],
        templateBlocks: [PlannedBlock],
        fixedBlocks: [PlannedBlock],
        template: DayTemplateSnapshot,
        endOfDay: Date
    ) -> LocalBlockFactoryResult {
        let templateOverrides = matchingTemplateOverrides(
            in: localItems,
            day: day,
            templateBlocks: templateBlocks
        )
        let templateOverrideIDs = Set(templateOverrides.map(\.id))
        let localTemplateOverrideBlocks = templateOverrides.map {
            makeLocalTemplateOverrideBlock(item: $0, day: day, endOfDay: endOfDay)
        }
        let routineBlocks = templateBlocks.filter { block in
            templateOverrides.contains { override in
                override.title == block.title && override.routineRole == block.routineRole
            } == false
        }

        var allBlocks = (routineBlocks + fixedBlocks + localTemplateOverrideBlocks)
            .sorted(by: TimelineBlockSorter.areInTimelineOrder)
        var tooMuchTodayIssues: [TooMuchTodayIssue] = []

        let scheduledItems = localItems
            .filter { item in
                guard let scheduledDay = item.scheduledDay else { return false }
                return calendar.isDate(scheduledDay, inSameDayAs: day)
                    && item.isSavedForLater == false
                    && templateOverrideIDs.contains(item.id) == false
            }
            .sorted(by: localItemSort)

        for item in scheduledItems {
            switch place(
                item: item,
                day: day,
                existingBlocks: allBlocks,
                template: template,
                endOfDay: endOfDay
            ) {
            case .scheduled(let block):
                allBlocks.append(block)
                allBlocks.sort(by: TimelineBlockSorter.areInTimelineOrder)
            case .tooMuchToday(let issue):
                tooMuchTodayIssues.append(issue)
            }
        }

        return LocalBlockFactoryResult(
            blocks: allBlocks,
            tooMuchTodayIssues: tooMuchTodayIssues
        )
    }

    private func matchingTemplateOverrides(
        in localItems: [EventSnapshot],
        day: Date,
        templateBlocks: [PlannedBlock]
    ) -> [EventSnapshot] {
        localItems.filter { item in
            guard let scheduledDay = item.scheduledDay else { return false }
            return item.source == .local
                && item.routineRole != nil
                && item.isSavedForLater == false
                && calendar.isDate(scheduledDay, inSameDayAs: day)
                && templateBlocks.contains { block in
                    block.title == item.title && block.routineRole == item.routineRole
                }
        }
    }

    private func place(
        item: EventSnapshot,
        day: Date,
        existingBlocks: [PlannedBlock],
        template: DayTemplateSnapshot,
        endOfDay: Date
    ) -> LocalPlacementResult {
        let startMinutes = max(
            item.preferredStartMinutes ?? item.preferredTimeWindow.startMinutes,
            template.wakeUpMinutes
        )
        let duration = max(item.targetDurationMinutes, item.minimumDurationMinutes)
        var candidateStart = calendar.date(on: day, minutesFromStartOfDay: startMinutes)

        while candidateStart < endOfDay {
            let candidateEnd = candidateStart.adding(minutes: duration)
            if candidateEnd > endOfDay {
                return .tooMuchToday(
                    TooMuchTodayIssue(
                        itemID: item.id,
                        title: item.title,
                        message: item.forceAfterBedtime
                            ? "There is no calm slot left today."
                            : "Not enough room today. This would cut into sleep or recovery.",
                        displacedRole: item.forceAfterBedtime ? nil : .sleep,
                        suggestedDate: calendar.date(byAdding: .day, value: 1, to: day) ?? day
                    )
                )
            }

            if let conflict = existingBlocks.first(where: { overlaps(start: candidateStart, end: candidateEnd, with: $0) }) {
                candidateStart = conflict.end.adding(minutes: template.transitionBufferMinutes)
                continue
            }

            return .scheduled(
                makeBlock(
                    item: item,
                    start: candidateStart,
                    end: candidateEnd
                )
            )
        }

        return .tooMuchToday(
            TooMuchTodayIssue(
                itemID: item.id,
                title: item.title,
                message: "This can wait. The day is already full.",
                displacedRole: nil,
                suggestedDate: calendar.date(byAdding: .day, value: 1, to: day) ?? day
            )
        )
    }

    private func makeLocalTemplateOverrideBlock(
        item: EventSnapshot,
        day: Date,
        endOfDay: Date
    ) -> PlannedBlock {
        let startMinutes = item.preferredStartMinutes ?? item.preferredTimeWindow.startMinutes
        let duration = max(item.targetDurationMinutes, item.minimumDurationMinutes)
        let start = calendar.date(on: day, minutesFromStartOfDay: startMinutes)
        let end = min(start.adding(minutes: duration), endOfDay)

        return makeBlock(item: item, start: start, end: end)
    }

    private func makeBlock(
        item: EventSnapshot,
        start: Date,
        end: Date
    ) -> PlannedBlock {
        PlannedBlock(
            id: item.id,
            itemID: item.id,
            calendarEventID: item.calendarEventID,
            title: item.title,
            start: start,
            end: end,
            source: item.source,
            flexibility: item.flexibility,
            symbolName: item.suggestedIcon,
            tintToken: item.tintToken,
            notes: item.notes,
            isAllDay: false,
            routineRole: item.routineRole,
            isCompleted: item.isCompleted,
            isStarted: item.isStarted,
            status: item.isCompleted ? .complete : .upcoming,
            confidence: item.isCompleted ? 1 : 0.7
        )
    }

    private func overlaps(
        start: Date,
        end: Date,
        with block: PlannedBlock
    ) -> Bool {
        start < block.end && end > block.start
    }

    private func localItemSort(_ lhs: EventSnapshot, _ rhs: EventSnapshot) -> Bool {
        let lhsStart = lhs.preferredStartMinutes ?? lhs.preferredTimeWindow.startMinutes
        let rhsStart = rhs.preferredStartMinutes ?? rhs.preferredTimeWindow.startMinutes

        if lhsStart == rhsStart {
            return lhs.orderHint < rhs.orderHint
        }

        return lhsStart < rhsStart
    }

}

private enum LocalPlacementResult {
    case scheduled(PlannedBlock)
    case tooMuchToday(TooMuchTodayIssue)
}
