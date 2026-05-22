import Foundation

struct CalendarBlockFactory {
    func makeBlocks(
        for day: Date,
        calendarEvents: [CalendarEventSnapshot],
        calendarLinks: [CalendarLinkSnapshot],
        startOfDay: Date,
        endOfDay: Date
    ) -> [PlannedBlock] {
        let linksByEventID = Dictionary(uniqueKeysWithValues: calendarLinks.map { ($0.calendarEventID, $0) })

        return calendarEvents.map { event in
            let link = linksByEventID[event.id]
            let icon = IconSuggester.suggest(for: event.title)
            let start = max(link?.localOverrideStart ?? event.start, startOfDay)
            let end = min(link?.localOverrideEnd ?? event.end, endOfDay)

            return PlannedBlock(
                id: UUID(),
                itemID: UUID(),
                calendarEventID: event.id,
                title: event.title,
                start: start,
                end: max(start.adding(minutes: 15), end),
                source: .calendar,
                flexibility: link?.flexibility ?? .askBeforeMove,
                symbolName: icon.symbolName,
                tintToken: icon.tintToken,
                notes: event.notes,
                isAllDay: event.isAllDay,
                routineRole: nil,
                isCompleted: false,
                isStarted: false,
                status: .upcoming,
                confidence: 0.7
            )
        }
        .sorted { lhs, rhs in
            if lhs.start == rhs.start {
                return lhs.end < rhs.end
            }
            return lhs.start < rhs.start
        }
    }
}
