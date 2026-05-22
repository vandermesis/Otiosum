import Foundation

struct LocalBlockFactoryResult: Equatable, Sendable {
    let blocks: [PlannedBlock]
    let tooMuchTodayIssues: [TooMuchTodayIssue]
}

struct LocalBlockFactory {
    private let calendar: Calendar
    private let itemPlacer: LocalItemTimelinePlacer
    private let templateOverrideFactory: LocalTemplateOverrideFactory

    init(
        calendar: Calendar = .current,
        itemPlacer: LocalItemTimelinePlacer? = nil,
        templateOverrideFactory: LocalTemplateOverrideFactory? = nil
    ) {
        self.calendar = calendar
        self.itemPlacer = itemPlacer ?? LocalItemTimelinePlacer(calendar: calendar)
        self.templateOverrideFactory = templateOverrideFactory ?? LocalTemplateOverrideFactory(calendar: calendar)
    }

    func makeBlocks(
        for day: Date,
        localItems: [EventSnapshot],
        templateBlocks: [PlannedBlock],
        fixedBlocks: [PlannedBlock],
        template: DayTemplateSnapshot,
        endOfDay: Date
    ) -> LocalBlockFactoryResult {
        let templateOverrides = templateOverrideFactory.makeOverrides(
            localItems: localItems,
            day: day,
            templateBlocks: templateBlocks,
            endOfDay: endOfDay
        )

        var allBlocks = (templateOverrides.remainingTemplateBlocks + fixedBlocks + templateOverrides.overrideBlocks)
            .sorted(by: TimelineBlockSorter.areInTimelineOrder)
        var tooMuchTodayIssues: [TooMuchTodayIssue] = []

        let scheduledItems = localItems
            .filter { item in
                guard let scheduledDay = item.scheduledDay else { return false }
                return calendar.isDate(scheduledDay, inSameDayAs: day)
                    && item.isSavedForLater == false
                    && templateOverrides.overrideItemIDs.contains(item.id) == false
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

    private func localItemSort(_ lhs: EventSnapshot, _ rhs: EventSnapshot) -> Bool {
        let lhsStart = lhs.preferredStartMinutes ?? lhs.preferredTimeWindow.startMinutes
        let rhsStart = rhs.preferredStartMinutes ?? rhs.preferredTimeWindow.startMinutes

        if lhsStart == rhsStart {
            return lhs.orderHint < rhs.orderHint
        }

        return lhsStart < rhsStart
    }

}
