import Foundation

struct TooMuchTodayIssueDeduplicator {
    func deduplicate(_ issues: [TooMuchTodayIssue]) -> [TooMuchTodayIssue] {
        var seen = Set<UUID>()
        return issues.filter { seen.insert($0.itemID).inserted }
    }
}
