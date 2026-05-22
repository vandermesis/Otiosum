import Foundation

struct LocalScheduledItemSelector {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func scheduledItems(
        from localItems: [EventSnapshot],
        day: Date,
        excludingItemIDs: Set<UUID>
    ) -> [EventSnapshot] {
        localItems
            .filter { item in
                guard let scheduledDay = item.scheduledDay else { return false }
                return calendar.isDate(scheduledDay, inSameDayAs: day)
                    && item.isSavedForLater == false
                    && excludingItemIDs.contains(item.id) == false
            }
            .sorted(by: localItemSort)
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
