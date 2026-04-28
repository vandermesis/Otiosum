import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class PlannerStore {
    var selectedDay: Date = .now
    var todayQuickCapture: String = ""
    var pendingTooMuchToday: PendingTooMuchTodayState?
    var pendingCalendarShift: PendingCalendarShiftState?
    var lastUserInteraction: Date?
    var didSeedDefaults = false

    let calendarService = SystemCalendarService()

    func ensureSeedData(in modelContext: ModelContext) throws {
        try IconCatalogDatabase.prepareIfNeeded(in: modelContext)
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

    func captureQuickEvent(
        modelContext: ModelContext,
        day: Date,
        template: DayTemplateSnapshot,
        defaultDurationMinutes: Int = 30,
        preferredStartDate: Date? = nil
    ) {
        let title = todayQuickCapture.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else { return }

        let icon = IconSuggester.suggest(for: title)
        let resolvedPreferredStartMinutes: Int?
        if let preferredStartDate {
            resolvedPreferredStartMinutes = max(0, min(23 * 60 + 55, preferredStartDate.minutesSinceStartOfDay(using: .current)))
        } else {
            resolvedPreferredStartMinutes = roundedStartMinutes(template: template)
        }
        let event = Event(
            title: title.capitalizedSentence,
            source: .local,
            suggestedIcon: icon.symbolName,
            tintToken: icon.tintToken,
            targetDurationMinutes: max(15, defaultDurationMinutes),
            minimumDurationMinutes: 15,
            scheduledDay: day,
            preferredStartMinutes: resolvedPreferredStartMinutes,
            preferredTimeWindow: inferredWindow(for: day, startMinutes: resolvedPreferredStartMinutes ?? 0),
            flexibility: .flexible,
            notes: "",
            isCompleted: false,
            isSavedForLater: false
        )

        modelContext.insert(event)
        try? modelContext.save()
        todayQuickCapture = ""
    }

    func restoreLaterEvent(
        _ event: Event,
        lane: DropLane,
        on day: Date,
        modelContext: ModelContext
    ) {
        event.isSavedForLater = false
        event.scheduledDay = day
        event.preferredTimeWindow = lane.timeWindow
        event.preferredStartMinutes = lane.timeWindow.startMinutes
        event.forceAfterBedtime = false
        try? modelContext.save()
    }

    func saveQuickEventForLater(modelContext: ModelContext) {
        let title = todayQuickCapture.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else { return }

        let icon = IconSuggester.suggest(for: title)
        let event = Event(
            title: title.capitalizedSentence,
            source: .local,
            suggestedIcon: icon.symbolName,
            tintToken: icon.tintToken,
            targetDurationMinutes: 30,
            minimumDurationMinutes: 15,
            scheduledDay: nil,
            preferredStartMinutes: nil,
            preferredTimeWindow: .anytime,
            flexibility: .flexible,
            notes: "",
            isCompleted: false,
            isSavedForLater: true
        )

        modelContext.insert(event)
        try? modelContext.save()
        todayQuickCapture = ""
    }

    func moveEventLater(
        _ event: Event,
        by minutes: Int = 30,
        on day: Date,
        modelContext: ModelContext
    ) {
        event.scheduledDay = day
        event.preferredStartMinutes = (event.preferredStartMinutes ?? roundedStartMinutes(template: .default)) + minutes
        event.isSavedForLater = false
        try? modelContext.save()
    }

    func rescheduleEvent(
        _ event: Event,
        to start: Date,
        modelContext: ModelContext
    ) {
        let calendar = Calendar.current
        event.scheduledDay = calendar.startOfDay(for: start)
        event.preferredStartMinutes = max(0, min(23 * 60 + 55, start.minutesSinceStartOfDay(using: calendar)))
        event.preferredTimeWindow = inferredWindow(for: start)
        event.isSavedForLater = false
        event.forceAfterBedtime = false
        try? modelContext.save()
    }

    func toggleCompletion(
        _ event: Event,
        modelContext: ModelContext
    ) {
        event.isCompleted.toggle()
        try? modelContext.save()
    }

    func setCompletion(
        _ event: Event,
        isCompleted: Bool,
        modelContext: ModelContext
    ) {
        event.isCompleted = isCompleted
        try? modelContext.save()
    }

    func startEventNow(
        _ event: Event,
        at start: Date = .now,
        modelContext: ModelContext
    ) {
        let calendar = Calendar.current
        event.scheduledDay = calendar.startOfDay(for: start)
        event.preferredStartMinutes = max(0, min(23 * 60 + 55, start.minutesSinceStartOfDay(using: calendar)))
        event.preferredTimeWindow = inferredWindow(for: start)
        event.isCompleted = false
        event.isSavedForLater = false
        event.forceAfterBedtime = false
        try? modelContext.save()
    }

    func adjustDuration(
        for event: Event,
        by deltaMinutes: Int,
        modelContext: ModelContext
    ) {
        let minDuration = max(15, event.minimumDurationMinutes)
        let adjusted = event.targetDurationMinutes + deltaMinutes
        event.targetDurationMinutes = min(240, max(minDuration, adjusted))
        try? modelContext.save()
    }

    func saveEventForLater(
        _ event: Event,
        modelContext: ModelContext
    ) {
        event.isSavedForLater = true
        event.scheduledDay = nil
        event.forceAfterBedtime = false
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

        if let issue = plan.tooMuchTodayIssues.first {
            pendingTooMuchToday = PendingTooMuchTodayState(
                itemID: issue.itemID,
                title: issue.title,
                message: issue.message,
                suggestedDate: issue.suggestedDate,
                displacedCategory: issue.displacedCategory,
                defaultChoice: .nextSuitableDay
            )
        } else {
            pendingTooMuchToday = nil
        }

        if let proposal = plan.shiftProposals.first {
            pendingCalendarShift = PendingCalendarShiftState(proposal: proposal)
        } else {
            pendingCalendarShift = nil
        }
    }

    func applyTooMuchTodayChoice(
        _ choice: TooMuchTodayChoice,
        modelContext: ModelContext
    ) {
        guard
            let pendingTooMuchToday,
            let event = findEvent(with: pendingTooMuchToday.itemID, in: modelContext)
        else {
            self.pendingTooMuchToday = nil
            return
        }

        switch choice {
        case .nextSuitableDay:
            event.scheduledDay = pendingTooMuchToday.suggestedDate
            event.preferredStartMinutes = nil
            event.forceAfterBedtime = false
            event.isSavedForLater = false
        case .saveForLater:
            event.scheduledDay = nil
            event.isSavedForLater = true
            event.forceAfterBedtime = false
        case .keepAnyway:
            event.scheduledDay = selectedDay
            event.forceAfterBedtime = true
            event.isSavedForLater = false
        }

        try? modelContext.save()
        self.pendingTooMuchToday = nil
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
        let selectedStart = calendar.startOfDay(for: day)
        let start = calendar.date(byAdding: .day, value: -3, to: selectedStart) ?? selectedStart
        let end = calendar.date(byAdding: .day, value: 4, to: selectedStart) ?? selectedStart.adding(minutes: 4 * 24 * 60)
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

    private func findEvent(
        with id: UUID,
        in modelContext: ModelContext
    ) -> Event? {
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate { event in
                event.id == id
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

    private func inferredWindow(for day: Date, startMinutes: Int) -> PreferredTimeWindow {
        let date = Calendar.current.date(on: day, minutesFromStartOfDay: startMinutes)
        return inferredWindow(for: date)
    }
}

struct PendingTooMuchTodayState: Identifiable {
    let id = UUID()
    let itemID: UUID
    let title: String
    let message: String
    let suggestedDate: Date
    let displacedCategory: ProtectedCategory?
    let defaultChoice: TooMuchTodayChoice
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
