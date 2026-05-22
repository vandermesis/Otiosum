import Foundation
import Testing
@testable import Otiosum

struct TooMuchTodayIssueDeduplicatorTests {
    @Test("Deduplicator keeps first issue for each item")
    func keepsFirstIssueForEachItem() {
        let itemID = UUID()
        let day = Date(timeIntervalSinceReferenceDate: 700_000)
        let issues = [
            issue(itemID: itemID, title: "First", date: day),
            issue(itemID: UUID(), title: "Other", date: day.adding(minutes: 10)),
            issue(itemID: itemID, title: "Duplicate", date: day.adding(minutes: 20))
        ]

        let deduplicated = TooMuchTodayIssueDeduplicator().deduplicate(issues)

        #expect(deduplicated.map(\.title) == ["First", "Other"])
    }

    @Test("Deduplicator preserves issue order")
    func preservesIssueOrder() {
        let day = Date(timeIntervalSinceReferenceDate: 700_000)
        let issues = [
            issue(itemID: UUID(), title: "One", date: day),
            issue(itemID: UUID(), title: "Two", date: day.adding(minutes: 10)),
            issue(itemID: UUID(), title: "Three", date: day.adding(minutes: 20))
        ]

        let deduplicated = TooMuchTodayIssueDeduplicator().deduplicate(issues)

        #expect(deduplicated.map(\.title) == ["One", "Two", "Three"])
    }

    private func issue(itemID: UUID, title: String, date: Date) -> TooMuchTodayIssue {
        TooMuchTodayIssue(
            itemID: itemID,
            title: title,
            message: "Too much",
            displacedRole: .sleep,
            suggestedDate: date
        )
    }
}
