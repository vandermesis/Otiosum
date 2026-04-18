import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class PlannerStore {
    var selectedTab: PlannerTab = .today
    var selectedDay: Date = .now
    var todayQuickCapture: String = ""
    var jarQuickCapture: String = ""
    var pendingOverflow: PendingOverflowState?
    var pendingCalendarShift: PendingCalendarShiftState?
    var lastUserInteraction: Date?
    var didSeedDefaults = false

    let calendarService = SystemCalendarService()

    func ensureSeedData(in modelContext: ModelContext) throws {
        guard didSeedDefaults == false else { return }

        let templates = try modelContext.fetch(FetchDescriptor<DayTemplate>())
        if templates.isEmpty {
            modelContext.insert(DayTemplate())
        }

        let budgets = try modelContext.fetch(FetchDescriptor<DailyBudget>())
        if budgets.isEmpty {
            modelContext.insert(DailyBudget())
        }

        didSeedDefaults = true
        try modelContext.save()
    }

    func registerInteraction() {
        lastUserInteraction = .now
    }

    func inferenceContext(sceneIsActive: Bool) -> InferenceContext {
        InferenceContext(
            now: .now,
            isSceneActive: sceneIsActive,
            lastUserInteraction: lastUserInteraction
        )
    }

    func captureQuickItem(
        from context: QuickCaptureContext,
        modelContext: ModelContext,
        day: Date,
        template: DayTemplateSnapshot
    ) {
        let rawTitle: String
        switch context {
        case .today:
            rawTitle = todayQuickCapture
        case .jar:
            rawTitle = jarQuickCapture
        }

        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else { return }

        let icon = IconSuggester.suggest(for: title)
        let item = PlannableItem(
            title: title.capitalizedSentence,
            kind: title.lowercased().contains("idea") ? .idea : .task,
            source: .local,
            suggestedIcon: icon.symbolName,
            tintToken: icon.tintToken,
            targetDurationMinutes: 30,
            minimumDurationMinutes: 15,
            scheduledDay: context == .today ? day : nil,
            preferredStartMinutes: context == .today ? roundedStartMinutes(template: template) : nil,
            preferredTimeWindow: context == .today ? inferredWindow(for: .now) : .anytime,
            flexibility: .flexible,
            notes: "",
            isCompleted: false,
            isInJar: context == .jar
        )

        modelContext.insert(item)
        try? modelContext.save()

        switch context {
        case .today:
            todayQuickCapture = ""
        case .jar:
            jarQuickCapture = ""
        }
    }

    func scheduleJarItem(
        item: PlannableItem,
        lane: DropLane,
        on day: Date,
        modelContext: ModelContext
    ) {
        item.isInJar = false
        item.scheduledDay = day
        item.preferredTimeWindow = lane.timeWindow
        item.preferredStartMinutes = lane.timeWindow.startMinutes
        item.forceAfterBedtime = false
        try? modelContext.save()
    }

    func moveItemLater(
        _ item: PlannableItem,
        by minutes: Int = 30,
        on day: Date,
        modelContext: ModelContext
    ) {
        item.scheduledDay = day
        item.preferredStartMinutes = (item.preferredStartMinutes ?? roundedStartMinutes(template: .default)) + minutes
        item.isInJar = false
        try? modelContext.save()
    }

    func rescheduleItem(
        _ item: PlannableItem,
        to start: Date,
        modelContext: ModelContext
    ) {
        let calendar = Calendar.current
        item.scheduledDay = calendar.startOfDay(for: start)
        item.preferredStartMinutes = max(0, min(23 * 60 + 55, start.minutesSinceStartOfDay(using: calendar)))
        item.preferredTimeWindow = inferredWindow(for: start)
        item.isInJar = false
        item.forceAfterBedtime = false
        try? modelContext.save()
    }

    func toggleCompletion(
        _ item: PlannableItem,
        modelContext: ModelContext
    ) {
        item.isCompleted.toggle()
        try? modelContext.save()
    }

    func returnToJar(
        _ item: PlannableItem,
        modelContext: ModelContext
    ) {
        item.isInJar = true
        item.scheduledDay = nil
        item.forceAfterBedtime = false
        try? modelContext.save()
    }

    func updateCalendarFlexibility(
        for calendarEventID: String,
        title: String,
        flexibility: PlannerFlexibility,
        modelContext: ModelContext
    ) {
        let link = calendarLink(for: calendarEventID, title: title, modelContext: modelContext)
        link.flexibility = flexibility
        try? modelContext.save()
    }

    func refreshPrompts(
        for plan: DayPlan,
        modelContext: ModelContext
    ) {
        _ = modelContext

        if let issue = plan.overflowIssues.first {
            pendingOverflow = PendingOverflowState(
                itemID: issue.itemID,
                title: issue.title,
                message: issue.message,
                suggestedDate: issue.suggestedDate,
                displacedCategory: issue.displacedCategory,
                defaultChoice: .nextSuitableDay
            )
        } else {
            pendingOverflow = nil
        }

        if let proposal = plan.shiftProposals.first {
            pendingCalendarShift = PendingCalendarShiftState(proposal: proposal)
        } else {
            pendingCalendarShift = nil
        }
    }

    func applyOverflowChoice(
        _ choice: OverflowChoice,
        modelContext: ModelContext
    ) {
        guard
            let pendingOverflow,
            let item = findItem(with: pendingOverflow.itemID, in: modelContext)
        else {
            self.pendingOverflow = nil
            return
        }

        switch choice {
        case .nextSuitableDay:
            item.scheduledDay = pendingOverflow.suggestedDate
            item.preferredStartMinutes = nil
            item.forceAfterBedtime = false
            item.isInJar = false
        case .returnToJar:
            item.scheduledDay = nil
            item.isInJar = true
            item.forceAfterBedtime = false
        case .keepAnyway:
            item.scheduledDay = selectedDay
            item.forceAfterBedtime = true
            item.isInJar = false
        }

        try? modelContext.save()
        self.pendingOverflow = nil
    }

    func applyCalendarDecision(
        _ decision: CalendarShiftDecision,
        modelContext: ModelContext
    ) async {
        guard let pendingCalendarShift else { return }

        let proposal = pendingCalendarShift.proposal
        let link = calendarLink(
            for: proposal.calendarEventID,
            title: proposal.title,
            modelContext: modelContext
        )

        switch decision {
        case .moveOnlyInOtiosum:
            link.flexibility = .flexible
            link.editPolicy = .localOnly
            link.localOverrideStart = proposal.suggestedStart
            link.localOverrideEnd = proposal.suggestedEnd
        case .editRealEvent:
            do {
                try await calendarService.moveEvent(
                    calendarEventID: proposal.calendarEventID,
                    to: DateInterval(start: proposal.suggestedStart, end: proposal.suggestedEnd)
                )
                link.flexibility = .flexible
                link.editPolicy = .systemCalendar
                link.localOverrideStart = proposal.suggestedStart
                link.localOverrideEnd = proposal.suggestedEnd
            } catch {
                calendarService.lastErrorMessage = error.localizedDescription
            }
        case .keepFixed:
            link.flexibility = .locked
            link.editPolicy = .askEveryTime
            link.localOverrideStart = nil
            link.localOverrideEnd = nil
        }

        try? modelContext.save()
        self.pendingCalendarShift = nil
    }

    func calendarRefreshInterval(around day: Date) -> DateInterval {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start.adding(minutes: 7 * 24 * 60)
        return DateInterval(start: start, end: end)
    }

    private func calendarLink(
        for calendarEventID: String,
        title: String,
        modelContext: ModelContext
    ) -> CalendarLink {
        let descriptor = FetchDescriptor<CalendarLink>(
            predicate: #Predicate { link in
                link.calendarEventID == calendarEventID
            }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.title = title
            return existing
        }

        let newLink = CalendarLink(calendarEventID: calendarEventID, title: title)
        modelContext.insert(newLink)
        return newLink
    }

    private func findItem(
        with id: UUID,
        in modelContext: ModelContext
    ) -> PlannableItem? {
        let descriptor = FetchDescriptor<PlannableItem>(
            predicate: #Predicate { item in
                item.id == id
            }
        )

        return try? modelContext.fetch(descriptor).first
    }

    private func roundedStartMinutes(template: DayTemplateSnapshot) -> Int {
        let now = Date()
        let currentMinutes = now.minutesSinceStartOfDay(using: .current)
        let rounded = ((currentMinutes + 14) / 15) * 15
        return max(template.wakeUpMinutes, rounded)
    }

    private func inferredWindow(for date: Date) -> PreferredTimeWindow {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case ..<12:
            return .morning
        case 12..<17:
            return .afternoon
        case 17..<21:
            return .evening
        default:
            return .night
        }
    }
}

struct PendingOverflowState: Identifiable {
    let id = UUID()
    let itemID: UUID
    let title: String
    let message: String
    let suggestedDate: Date
    let displacedCategory: ProtectedCategory?
    let defaultChoice: OverflowChoice
}

struct PendingCalendarShiftState: Identifiable {
    let id = UUID()
    let proposal: CalendarShiftProposal
}

private extension String {
    var capitalizedSentence: String {
        guard isEmpty == false else { return self }
        return prefix(1).capitalized + dropFirst()
    }
}
