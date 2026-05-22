import Foundation

struct LocalBlockFactoryResult: Equatable, Sendable {
    let blocks: [PlannedBlock]
    let tooMuchTodayIssues: [TooMuchTodayIssue]
}

struct LocalBlockFactory {
    private let calendar: Calendar
    private let itemPlacer: LocalItemTimelinePlacer

    init(
        calendar: Calendar = .current,
        itemPlacer: LocalItemTimelinePlacer? = nil
    ) {
        self.calendar = calendar
        self.itemPlacer = itemPlacer ?? LocalItemTimelinePlacer(calendar: calendar)
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
            let placement = itemPlacer.place(
                item: item,
                day: day,
                existingBlocks: allBlocks,
                template: template,
                endOfDay: endOfDay
            )

            if let block = placement.block {
                allBlocks.append(block)
                allBlocks.sort(by: TimelineBlockSorter.areInTimelineOrder)
            }

            if let issue = placement.tooMuchTodayIssue {
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

    private func localItemSort(_ lhs: EventSnapshot, _ rhs: EventSnapshot) -> Bool {
        let lhsStart = lhs.preferredStartMinutes ?? lhs.preferredTimeWindow.startMinutes
        let rhsStart = rhs.preferredStartMinutes ?? rhs.preferredTimeWindow.startMinutes

        if lhsStart == rhsStart {
            return lhs.orderHint < rhs.orderHint
        }

        return lhsStart < rhsStart
    }

}
