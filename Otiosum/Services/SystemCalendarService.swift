import EventKit
import Foundation
import Observation

@MainActor
@Observable
final class SystemCalendarService {
    var authorizationStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    var isLoading = false
    var lastErrorMessage: String?

    private let eventStore = EKEventStore()
    private let calendar = Calendar.current
    private var dayCache: [String: [CalendarEventSnapshot]] = [:]

    func events(for day: Date) -> [CalendarEventSnapshot] {
        dayCache[cacheKey(for: day), default: []]
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    func requestFullAccess() async {
        do {
            _ = try await eventStore.requestFullAccessToEvents()
            refreshAuthorizationStatus()
        } catch {
            lastErrorMessage = error.localizedDescription
            refreshAuthorizationStatus()
        }
    }

    func refreshEvents(covering interval: DateInterval) async {
        refreshAuthorizationStatus()

        guard canReadEvents else {
            dayCache.removeAll()
            return
        }

        isLoading = true
        defer { isLoading = false }

        let predicate = eventStore.predicateForEvents(withStart: interval.start, end: interval.end, calendars: nil)
        let events = eventStore.events(matching: predicate)
            .sorted { lhs, rhs in
                if lhs.startDate == rhs.startDate {
                    return lhs.endDate < rhs.endDate
                }
                return lhs.startDate < rhs.startDate
            }

        dayCache.removeAll()
        for event in events {
            let snapshot = CalendarEventSnapshot(
                id: event.eventIdentifier,
                title: event.title?.isEmpty == false ? event.title ?? "Calendar event" : "Calendar event",
                start: event.startDate,
                end: event.endDate,
                notes: event.notes ?? "",
                isAllDay: event.isAllDay
            )

            for day in dayEntries(for: snapshot, within: interval) {
                dayCache[cacheKey(for: day), default: []].append(snapshot)
            }
        }
    }

    func moveEvent(
        calendarEventID: String,
        to interval: DateInterval
    ) async throws {
        guard canReadEvents else {
            throw CalendarServiceError.noAccess
        }

        guard let event = eventStore.event(withIdentifier: calendarEventID) else {
            throw CalendarServiceError.missingEvent
        }

        event.startDate = interval.start
        event.endDate = interval.end

        try eventStore.save(event, span: .thisEvent, commit: true)
    }

    var canReadEvents: Bool {
        switch authorizationStatus {
        case .authorized, .fullAccess:
            true
        default:
            false
        }
    }

    private func dayEntries(for snapshot: CalendarEventSnapshot, within interval: DateInterval) -> [Date] {
        var days: [Date] = []
        var cursor = max(snapshot.start, interval.start).startOfDay(using: calendar)
        let end = min(snapshot.end, interval.end)

        while cursor <= end {
            days.append(cursor)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = nextDay
        }

        return days
    }

    private func cacheKey(for day: Date) -> String {
        let start = calendar.startOfDay(for: day)
        return String(Int(start.timeIntervalSince1970))
    }
}

enum CalendarServiceError: LocalizedError {
    case noAccess
    case missingEvent

    var errorDescription: String? {
        switch self {
        case .noAccess:
            "Calendar access is not available."
        case .missingEvent:
            "The calendar event is no longer available."
        }
    }
}
