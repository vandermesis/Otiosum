import Foundation
import Testing
@testable import Otiosum

@MainActor
struct PlannerShellViewModelTests {
    @Test("Quick-capture suggestion is nil when the field is empty")
    func suggestionIsNilForEmptyInput() {
        let viewModel = PlannerShellViewModel()
        viewModel.todayQuickCapture = ""

        #expect(viewModel.todayQuickCaptureSuggestion == nil)
        #expect(viewModel.todayQuickCaptureSuggestions.isEmpty)
    }

    @Test("Quick-capture suggestion is nil when the field is only whitespace")
    func suggestionIsNilForWhitespace() {
        let viewModel = PlannerShellViewModel()
        viewModel.todayQuickCapture = "   \n\t  "

        #expect(viewModel.todayQuickCaptureSuggestion == nil)
        #expect(viewModel.todayQuickCaptureSuggestions.isEmpty)
    }

    @Test("Quick-capture suggestion returns the deterministic suggester output for real input")
    func suggestionMatchesIconSuggester() {
        let viewModel = PlannerShellViewModel()
        viewModel.todayQuickCapture = "go for a walk"

        let expected = IconSuggester.suggest(for: "go for a walk")
        #expect(viewModel.todayQuickCaptureSuggestion == expected)
        #expect(viewModel.todayQuickCaptureSuggestions.first == expected)
    }

    @Test("Quick-capture suggestion ignores leading and trailing whitespace")
    func suggestionTrimsInput() {
        let viewModel = PlannerShellViewModel()
        viewModel.todayQuickCapture = "  workout  "

        let expected = IconSuggester.suggest(for: "workout")
        #expect(viewModel.todayQuickCaptureSuggestion == expected)
    }

    @Test("Quick-capture suggestion list returns a ranked set for real input")
    func suggestionsListIsRanked() {
        let viewModel = PlannerShellViewModel()
        viewModel.todayQuickCapture = "lunch with friend"

        let suggestions = viewModel.todayQuickCaptureSuggestions
        #expect(suggestions.isEmpty == false)
        #expect(suggestions.first == IconSuggester.suggest(for: "lunch with friend"))
    }

    @Test("Upcoming plans cover seven days starting at the selected day")
    func upcomingPlansSpanSevenDaysFromSelection() {
        let viewModel = PlannerShellViewModel()
        let calendar = Calendar.current
        let selectedDay = calendar.date(from: DateComponents(year: 2026, month: 5, day: 22)) ?? .now
        viewModel.selectedDay = selectedDay

        let plans = viewModel.makeUpcomingPlans(
            items: [],
            calendarLinks: [],
            template: .default,
            budget: .default,
            sceneIsActive: true
        )

        #expect(plans.count == 7)
        #expect(plans.first?.0 == calendar.startOfDay(for: selectedDay))
        #expect(plans.last?.0 == calendar.date(byAdding: .day, value: 6, to: calendar.startOfDay(for: selectedDay)))
    }

    @Test("Upcoming plan days are in chronological order with one-day stride")
    func upcomingPlanDaysAreSequential() {
        let viewModel = PlannerShellViewModel()
        let calendar = Calendar.current
        let selectedDay = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1)) ?? .now
        viewModel.selectedDay = selectedDay

        let plans = viewModel.makeUpcomingPlans(
            items: [],
            calendarLinks: [],
            template: .default,
            budget: .default,
            sceneIsActive: true
        )

        for (offset, entry) in plans.enumerated() {
            let expected = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: selectedDay))
            #expect(entry.0 == expected)
        }
    }

    @Test("Timeline plans are stable across repeated calls with identical inputs")
    func timelinePlansAreStableAcrossCalls() {
        let viewModel = PlannerShellViewModel()
        let calendar = Calendar.current
        let selectedDay = calendar.date(from: DateComponents(year: 2026, month: 4, day: 22)) ?? .now
        let centerDate = calendar.date(from: DateComponents(year: 2026, month: 5, day: 10)) ?? selectedDay
        viewModel.selectedDay = selectedDay

        let first = viewModel.makeTimelinePlans(
            items: [],
            calendarLinks: [],
            template: .default,
            budget: .default,
            sceneIsActive: true,
            timelineCenterDate: centerDate
        )
        let second = viewModel.makeTimelinePlans(
            items: [],
            calendarLinks: [],
            template: .default,
            budget: .default,
            sceneIsActive: true,
            timelineCenterDate: centerDate
        )

        #expect(first.count == second.count)
        #expect(first.count == 7)
        for (lhs, rhs) in zip(first, second) {
            #expect(lhs.0 == rhs.0)
            #expect(lhs.1 == rhs.1)
        }
    }
}
