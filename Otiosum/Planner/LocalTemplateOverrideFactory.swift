import Foundation

struct LocalTemplateOverrideResult: Equatable, Sendable {
    let remainingTemplateBlocks: [PlannedBlock]
    let overrideBlocks: [PlannedBlock]
    let overrideItemIDs: Set<UUID>
}

struct LocalTemplateOverrideFactory {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func makeOverrides(
        localItems: [EventSnapshot],
        day: Date,
        templateBlocks: [PlannedBlock],
        endOfDay: Date
    ) -> LocalTemplateOverrideResult {
        let overrides = matchingTemplateOverrides(
            in: localItems,
            day: day,
            templateBlocks: templateBlocks
        )
        let overrideBlocks = overrides.map {
            makeOverrideBlock(item: $0, day: day, endOfDay: endOfDay)
        }
        let remainingTemplateBlocks = templateBlocks.filter { block in
            overrides.contains { override in
                override.title == block.title && override.routineRole == block.routineRole
            } == false
        }

        return LocalTemplateOverrideResult(
            remainingTemplateBlocks: remainingTemplateBlocks,
            overrideBlocks: overrideBlocks,
            overrideItemIDs: Set(overrides.map(\.id))
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

    private func makeOverrideBlock(
        item: EventSnapshot,
        day: Date,
        endOfDay: Date
    ) -> PlannedBlock {
        let startMinutes = item.preferredStartMinutes ?? item.preferredTimeWindow.startMinutes
        let duration = max(item.targetDurationMinutes, item.minimumDurationMinutes)
        let start = calendar.date(on: day, minutesFromStartOfDay: startMinutes)
        let end = min(start.adding(minutes: duration), endOfDay)

        return PlannedBlock(
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
}
