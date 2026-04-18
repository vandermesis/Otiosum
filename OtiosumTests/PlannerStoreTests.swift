import Foundation
import SwiftData
import Testing
@testable import Otiosum

@MainActor
struct PlannerStoreTests {
    @Test("Seed data inserts default template and budget once")
    func ensureSeedDataIsIdempotent() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()

        try store.ensureSeedData(in: modelContext)
        try store.ensureSeedData(in: modelContext)

        let templates = try modelContext.fetch(FetchDescriptor<DayTemplate>())
        let budgets = try modelContext.fetch(FetchDescriptor<DailyBudget>())

        #expect(templates.count == 1)
        #expect(budgets.count == 1)
        #expect(store.didSeedDefaults)
    }

    @Test("Jar quick capture creates an unscheduled jar item and clears input")
    func captureQuickItemFromJar() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()
        try store.ensureSeedData(in: modelContext)

        store.jarQuickCapture = "read chapter"
        store.captureQuickItem(
            from: .jar,
            modelContext: modelContext,
            day: Date(timeIntervalSinceReferenceDate: 50_000),
            template: .default
        )

        let items = try modelContext.fetch(FetchDescriptor<PlannableItem>())
        let item = try #require(items.first)

        #expect(item.title == "Read chapter")
        #expect(item.isInJar)
        #expect(item.scheduledDay == nil)
        #expect(item.preferredStartMinutes == nil)
        #expect(item.preferredTimeWindow == .anytime)
        #expect(store.jarQuickCapture.isEmpty)
    }

    @Test("Applying return-to-jar overflow choice updates item and clears pending state")
    func applyOverflowChoiceReturnToJar() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()
        let item = PlannableItem(
            title: "Late task",
            suggestedIcon: "moon.stars",
            tintToken: "indigo",
            scheduledDay: Date(timeIntervalSinceReferenceDate: 60_000),
            isInJar: false,
            forceAfterBedtime: true
        )
        modelContext.insert(item)
        try modelContext.save()

        store.pendingOverflow = PendingOverflowState(
            itemID: item.id,
            title: item.title,
            message: "Not enough room",
            suggestedDate: Date(timeIntervalSinceReferenceDate: 70_000),
            displacedCategory: .sleep,
            defaultChoice: .nextSuitableDay
        )

        store.applyOverflowChoice(.returnToJar, modelContext: modelContext)

        #expect(item.isInJar)
        #expect(item.scheduledDay == nil)
        #expect(item.forceAfterBedtime == false)
        #expect(store.pendingOverflow == nil)
    }

    @Test("Applying keep-anyway overflow choice keeps item scheduled on selected day")
    func applyOverflowChoiceKeepAnyway() throws {
        let modelContext = try makeModelContext()
        let store = PlannerStore()
        let selectedDay = Date(timeIntervalSinceReferenceDate: 80_000)
        store.selectedDay = selectedDay

        let item = PlannableItem(
            title: "Packed evening",
            suggestedIcon: "calendar",
            tintToken: "sky",
            scheduledDay: nil,
            isInJar: true,
            forceAfterBedtime: false
        )
        modelContext.insert(item)
        try modelContext.save()

        store.pendingOverflow = PendingOverflowState(
            itemID: item.id,
            title: item.title,
            message: "Not enough room",
            suggestedDate: Date(timeIntervalSinceReferenceDate: 81_000),
            displacedCategory: .sleep,
            defaultChoice: .nextSuitableDay
        )

        store.applyOverflowChoice(.keepAnyway, modelContext: modelContext)

        #expect(item.scheduledDay == selectedDay)
        #expect(item.forceAfterBedtime)
        #expect(item.isInJar == false)
        #expect(store.pendingOverflow == nil)
    }

    @Test("Refresh prompts picks the first overflow and first shift proposal")
    func refreshPromptsSelectsFirstEntries() throws {
        let store = PlannerStore()
        let now = Date(timeIntervalSinceReferenceDate: 90_000)

        let overflow1 = OverflowIssue(
            itemID: UUID(),
            title: "Overflow one",
            message: "First",
            displacedCategory: .sleep,
            suggestedDate: now
        )
        let overflow2 = OverflowIssue(
            itemID: UUID(),
            title: "Overflow two",
            message: "Second",
            displacedCategory: .rest,
            suggestedDate: now.adding(minutes: 60)
        )

        let shift1 = CalendarShiftProposal(
            calendarEventID: "A",
            title: "Event A",
            currentStart: now,
            currentEnd: now.adding(minutes: 30),
            suggestedStart: now.adding(minutes: 15),
            suggestedEnd: now.adding(minutes: 45)
        )
        let shift2 = CalendarShiftProposal(
            calendarEventID: "B",
            title: "Event B",
            currentStart: now,
            currentEnd: now.adding(minutes: 30),
            suggestedStart: now.adding(minutes: 20),
            suggestedEnd: now.adding(minutes: 50)
        )

        let plan = DayPlan(
            day: now,
            allBlocks: [],
            nowBlock: nil,
            nextBlock: nil,
            laterBlocks: [],
            protectedBlocks: [],
            warnings: [],
            overflowIssues: [overflow1, overflow2],
            shiftProposals: [shift1, shift2],
            budgetSummary: BudgetUsageSummary(workMinutes: 0, restMinutes: 0, sleepMinutesProtected: 0, scheduledCount: 0)
        )

        let modelContext = try makeModelContext()
        store.refreshPrompts(for: plan, modelContext: modelContext)

        #expect(store.pendingOverflow?.itemID == overflow1.itemID)
        #expect(store.pendingCalendarShift?.proposal.calendarEventID == "A")
    }

    private func makeModelContext() throws -> ModelContext {
        let schema = Schema([
            Item.self,
            PlannableItem.self,
            CalendarLink.self,
            DayTemplate.self,
            DailyBudget.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }
}
