import Testing
import Foundation
@testable import Otiosum

@Suite("Planner Logic & ViewModel Tests")
@MainActor
struct PlannerTests {
    
    // MARK: - Helpers
    private var calendar: Calendar { .current }
    
    private func date(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
    
    private func makeEvent(
        id: UUID = UUID(),
        title: String,
        scheduledDay: Date?,
        preferredStartMinutes: Int? = nil,
        preferredTimeWindow: PreferredTimeWindow = .anytime,
        targetDuration: Int = 30,
        forceAfterBedtime: Bool = false
    ) -> EventSnapshot {
        EventSnapshot(
            id: id,
            title: title,
            source: .local,
            suggestedIcon: "pencil",
            tintToken: "blue",
            targetDurationMinutes: targetDuration,
            minimumDurationMinutes: 15,
            scheduledDay: scheduledDay,
            preferredStartMinutes: preferredStartMinutes,
            preferredTimeWindow: preferredTimeWindow,
            flexibility: .flexible,
            calendarEventID: nil,
            protectedCategory: nil,
            notes: "",
            isCompleted: false,
            orderHint: 0.5,
            isSavedForLater: false,
            forceAfterBedtime: forceAfterBedtime
        )
    }
    
    // MARK: - PlannerEngine Tests
    
    @Test("Protected blocks are generated from default template")
    func testProtectedBlocksGeneration() async throws {
        let engine = PlannerEngine()
        let day = date(year: 2024, month: 1, day: 1)
        let context = InferenceContext(now: day, isSceneActive: true, lastUserInteraction: nil)
        
        let plan = engine.plan(
            for: day,
            localItems: [],
            calendarEvents: [],
            calendarLinks: [],
            template: .default,
            budget: .default,
            context: context
        )
        
        #expect(plan.allBlocks.contains { $0.title == "Breakfast" && $0.protectedCategory == .meal })
        #expect(plan.allBlocks.contains { $0.title == "Lunch" && $0.protectedCategory == .meal })
        #expect(plan.allBlocks.contains { $0.title == "Dinner" && $0.protectedCategory == .meal })
        #expect(plan.allBlocks.contains { $0.title == "Recovery" && $0.protectedCategory == .rest })
        #expect(plan.allBlocks.contains { $0.title == "Sleep" && $0.protectedCategory == .sleep })
        #expect(plan.allBlocks.contains { $0.title == "Workout" && $0.protectedCategory == .workout })
    }
    
    @Test("Local items are scheduled within preferred time window")
    func testLocalItemScheduling() async throws {
        let engine = PlannerEngine()
        let day = date(year: 2024, month: 1, day: 1)
        let context = InferenceContext(now: day, isSceneActive: true, lastUserInteraction: nil)
        
        let item = makeEvent(title: "Morning Focus", scheduledDay: day, preferredTimeWindow: .morning)
        
        let plan = engine.plan(
            for: day,
            localItems: [item],
            calendarEvents: [],
            calendarLinks: [],
            template: .default,
            budget: .default,
            context: context
        )
        
        #expect(plan.allBlocks.contains { $0.title == "Morning Focus" && $0.source == .local })
    }
    
    @Test("Too much today issue is raised when sleep boundary is crossed")
    func testTooMuchTodayIssue() async throws {
        let engine = PlannerEngine()
        let day = date(year: 2024, month: 1, day: 1)
        let context = InferenceContext(now: day, isSceneActive: true, lastUserInteraction: nil)
        
        // Item scheduled late at night that would cut into sleep/recovery
        let lateItem = makeEvent(
            title: "Late Night Crunch",
            scheduledDay: day,
            preferredStartMinutes: 23 * 60,
            targetDuration: 120,
            forceAfterBedtime: false
        )
        
        let plan = engine.plan(
            for: day,
            localItems: [lateItem],
            calendarEvents: [],
            calendarLinks: [],
            template: .default,
            budget: .default,
            context: context
        )
        
        #expect(plan.tooMuchTodayIssues.contains { $0.itemID == lateItem.id })
    }
    
    @Test("Budget warning is generated when work exceeds target")
    func testBudgetWarningOnOverwork() async throws {
        let engine = PlannerEngine()
        let day = date(year: 2024, month: 1, day: 1)
        let context = InferenceContext(now: day, isSceneActive: true, lastUserInteraction: nil)
        
        var items: [EventSnapshot] = []
        for i in 0..<8 {
            items.append(makeEvent(
                title: "Heavy Task \(i)",
                scheduledDay: day,
                targetDuration: 60,
                forceAfterBedtime: true
            ))
        }
        let tightBudget = DailyBudgetSnapshot(
            minimumSleepHours: DailyBudgetSnapshot.default.minimumSleepHours,
            minimumRestMinutes: DailyBudgetSnapshot.default.minimumRestMinutes,
            targetWorkMinutes: 5 * 60,
            maxFocusItems: DailyBudgetSnapshot.default.maxFocusItems,
            mealDurationMinutes: DailyBudgetSnapshot.default.mealDurationMinutes,
            workoutTargetMinutes: DailyBudgetSnapshot.default.workoutTargetMinutes,
            quickAddDefaultDurationMinutes: DailyBudgetSnapshot.default.quickAddDefaultDurationMinutes,
            lowNotificationMode: DailyBudgetSnapshot.default.lowNotificationMode,
            useSimplifiedMode: DailyBudgetSnapshot.default.useSimplifiedMode
        )
        
        let plan = engine.plan(
            for: day,
            localItems: items,
            calendarEvents: [],
            calendarLinks: [],
            template: .default,
            budget: tightBudget,
            context: context
        )
        
        #expect(plan.warnings.contains { $0.message == "This day is carrying a lot." })
    }
    
    @Test("Calendar events are included in the plan")
    func testCalendarEventsIntegration() async throws {
        let engine = PlannerEngine()
        let day = date(year: 2024, month: 1, day: 1)
        let context = InferenceContext(now: day, isSceneActive: true, lastUserInteraction: nil)
        
        let calEvent = CalendarEventSnapshot(
            id: "cal-1",
            title: "Team Standup",
            start: day.adding(minutes: 9 * 60),
            end: day.adding(minutes: 9 * 60 + 30),
            notes: "",
            isAllDay: false
        )
        
        let plan = engine.plan(
            for: day,
            localItems: [],
            calendarEvents: [calEvent],
            calendarLinks: [],
            template: .default,
            budget: .default,
            context: context
        )
        
        #expect(plan.allBlocks.contains { $0.title == "Team Standup" && $0.source == .calendar })
    }
    
    // MARK: - ViewModel Tests
    
    @Test("ViewModel returns default snapshots for empty model arrays")
    func testViewModelDefaultSnapshots() async throws {
        let viewModel = PlannerViewModel()
        
        #expect(viewModel.templateSnapshot(from: []) == .default)
        #expect(viewModel.budgetSnapshot(from: []) == .default)
    }
    
    @Test("ViewModel correctly converts models to snapshots")
    func testViewModelModelConversion() async throws {
        let viewModel = PlannerViewModel()
        
        let template = DayTemplate(
            id: UUID(), key: "custom",
            wakeUpMinutes: 6 * 60, sleepStartMinutes: 23 * 60,
            breakfastMinutes: 7 * 60, lunchMinutes: 12 * 60, dinnerMinutes: 19 * 60,
            quietStartMinutes: 20 * 60, quietDurationMinutes: 45,
            workoutMinutes: 17 * 60, workoutDurationMinutes: 30,
            includeWorkout: false, transitionBufferMinutes: 5
        )
        
        let snapshot = viewModel.templateSnapshot(from: [template])
        #expect(snapshot.wakeUpMinutes == 6 * 60)
        #expect(snapshot.includeWorkout == false)
    }

    @Test("Shell timeline plans follow the visible center day")
    func testShellTimelinePlansFollowVisibleCenterDay() async throws {
        let shellViewModel = PlannerShellViewModel()
        let calendar = Calendar.current
        let selectedDay = date(year: 2026, month: 4, day: 22)
        let centerDate = date(year: 2026, month: 5, day: 10)
        shellViewModel.selectedDay = selectedDay

        let plans = shellViewModel.makeTimelinePlans(
            items: [],
            calendarLinks: [],
            template: .default,
            budget: .default,
            sceneIsActive: true,
            timelineCenterDate: centerDate
        )

        #expect(plans.count == 7)
        #expect(plans.first?.0 == calendar.date(byAdding: .day, value: -3, to: centerDate))
        #expect(plans.last?.0 == calendar.date(byAdding: .day, value: 3, to: centerDate))
    }
    
    // MARK: - Type & Utility Tests
    
    @Test("PreferredTimeWindow computed properties match expected minutes")
    func testTimeWindowProperties() async throws {
        #expect(PreferredTimeWindow.morning.startMinutes == 8 * 60)
        #expect(PreferredTimeWindow.afternoon.endMinutes == 17 * 60)
        #expect(PreferredTimeWindow.night.startMinutes == 21 * 60)
    }
    
    @Test("IconCatalogSymbol normalizes names correctly")
    func testIconNormalization() async throws {
        #expect(IconCatalogSymbol.makeNormalizedName(from: "house.fill") == "house fill")
        #expect(IconCatalogSymbol.makeNormalizedName(from: "person.2.circle") == "person 2 circle")
        #expect(IconCatalogSymbol.makeNormalizedName(from: "ALREADY_LOWER") == "already_lower")
    }
}
