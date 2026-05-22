import Foundation

struct LocalBlockFactoryResult: Equatable, Sendable {
    let blocks: [PlannedBlock]
    let tooMuchTodayIssues: [TooMuchTodayIssue]
}

struct LocalBlockFactory {
    private let itemPlacer: LocalItemTimelinePlacer
    private let templateOverrideFactory: LocalTemplateOverrideFactory
    private let scheduledItemSelector: LocalScheduledItemSelector

    init(
        calendar: Calendar = .current,
        itemPlacer: LocalItemTimelinePlacer? = nil,
        templateOverrideFactory: LocalTemplateOverrideFactory? = nil,
        scheduledItemSelector: LocalScheduledItemSelector? = nil
    ) {
        self.itemPlacer = itemPlacer ?? LocalItemTimelinePlacer(calendar: calendar)
        self.templateOverrideFactory = templateOverrideFactory ?? LocalTemplateOverrideFactory(calendar: calendar)
        self.scheduledItemSelector = scheduledItemSelector ?? LocalScheduledItemSelector(calendar: calendar)
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

        let scheduledItems = scheduledItemSelector.scheduledItems(
            from: localItems,
            day: day,
            excludingItemIDs: templateOverrides.overrideItemIDs
        )

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

}
