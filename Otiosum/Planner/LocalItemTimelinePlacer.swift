import Foundation

struct LocalItemPlacementResult: Equatable, Sendable {
    let block: PlannedBlock?
    let tooMuchTodayIssue: TooMuchTodayIssue?
}

struct LocalItemTimelinePlacer {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func place(
        item: EventSnapshot,
        day: Date,
        existingBlocks: [PlannedBlock],
        template: DayTemplateSnapshot,
        endOfDay: Date
    ) -> LocalItemPlacementResult {
        let startMinutes = max(
            item.preferredStartMinutes ?? item.preferredTimeWindow.startMinutes,
            template.wakeUpMinutes
        )
        let duration = max(item.targetDurationMinutes, item.minimumDurationMinutes)
        var candidateStart = calendar.date(on: day, minutesFromStartOfDay: startMinutes)

        while candidateStart < endOfDay {
            let candidateEnd = candidateStart.adding(minutes: duration)
            if candidateEnd > endOfDay {
                return LocalItemPlacementResult(
                    block: nil,
                    tooMuchTodayIssue: TooMuchTodayIssue(
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

            return LocalItemPlacementResult(
                block: makeBlock(
                    item: item,
                    start: candidateStart,
                    end: candidateEnd
                ),
                tooMuchTodayIssue: nil
            )
        }

        return LocalItemPlacementResult(
            block: nil,
            tooMuchTodayIssue: TooMuchTodayIssue(
                itemID: item.id,
                title: item.title,
                message: "This can wait. The day is already full.",
                displacedRole: nil,
                suggestedDate: calendar.date(byAdding: .day, value: 1, to: day) ?? day
            )
        )
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
}
