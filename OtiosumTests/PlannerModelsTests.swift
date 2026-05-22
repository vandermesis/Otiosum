import Foundation
import Testing
@testable import Otiosum

@MainActor
struct PlannerModelsTests {

    // MARK: - Event enum-backed accessor fallbacks

    @Test("Event.source falls back to .local when sourceRaw is malformed")
    func eventSourceFallsBackToLocal() {
        let event = Event(title: "x", source: .calendar, suggestedIcon: "star", tintToken: "blue")
        event.sourceRaw = "not-a-real-source"

        #expect(event.source == .local)
    }

    @Test("Event.flexibility falls back to .flexible when flexibilityRaw is malformed")
    func eventFlexibilityFallsBackToFlexible() {
        let event = Event(
            title: "x",
            suggestedIcon: "star",
            tintToken: "blue",
            flexibility: .locked
        )
        event.flexibilityRaw = "wat"

        #expect(event.flexibility == .flexible)
    }

    @Test("Event.preferredTimeWindow falls back to .anytime when raw is malformed")
    func eventPreferredTimeWindowFallsBackToAnytime() {
        let event = Event(
            title: "x",
            suggestedIcon: "star",
            tintToken: "blue",
            preferredTimeWindow: .morning
        )
        event.preferredTimeWindowRaw = "midmorning"

        #expect(event.preferredTimeWindow == .anytime)
    }

    @Test("Event.routineRole returns nil for malformed or absent raw values")
    func eventRoutineRoleFallsBackToNil() {
        let event = Event(
            title: "x",
            suggestedIcon: "star",
            tintToken: "blue",
            routineRole: .meal
        )

        event.routineRoleRaw = "snack"
        #expect(event.routineRole == nil)

        event.routineRoleRaw = nil
        #expect(event.routineRole == nil)
    }

    @Test("CalendarLink enum-backed accessors fall back to safe defaults")
    func calendarLinkAccessorsFallBack() {
        let link = CalendarLink(calendarEventID: "evt", title: "Meeting", flexibility: .locked, editPolicy: .systemCalendar)

        link.flexibilityRaw = "spaghetti"
        link.editPolicyRaw = "n/a"

        #expect(link.flexibility == .askBeforeMove)
        #expect(link.editPolicy == .askEveryTime)
    }

    // MARK: - CalendarLink setter bumps updatedAt

    @Test("Setting CalendarLink.flexibility bumps updatedAt")
    func calendarLinkFlexibilitySetterBumpsUpdatedAt() {
        let link = CalendarLink(calendarEventID: "evt", title: "Meeting")
        let pastDate = Date(timeIntervalSince1970: 0)
        link.updatedAt = pastDate

        link.flexibility = .locked

        #expect(link.updatedAt > pastDate)
        #expect(Date().timeIntervalSince(link.updatedAt) < 5)
    }

    @Test("Setting CalendarLink.editPolicy bumps updatedAt")
    func calendarLinkEditPolicySetterBumpsUpdatedAt() {
        let link = CalendarLink(calendarEventID: "evt", title: "Meeting")
        let pastDate = Date(timeIntervalSince1970: 0)
        link.updatedAt = pastDate

        link.editPolicy = .systemCalendar

        #expect(link.updatedAt > pastDate)
        #expect(Date().timeIntervalSince(link.updatedAt) < 5)
    }

    // MARK: - Snapshot round-trips

    @Test("Event.snapshot mirrors every stored field on the model")
    func eventSnapshotRoundTrip() {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let event = Event(
            id: UUID(),
            title: "Deep work",
            source: .local,
            suggestedIcon: "brain",
            tintToken: "indigo",
            targetDurationMinutes: 75,
            minimumDurationMinutes: 30,
            scheduledDay: day,
            preferredStartMinutes: 9 * 60,
            preferredTimeWindow: .morning,
            flexibility: .askBeforeMove,
            calendarEventID: "cal-42",
            routineRole: .workWindow,
            notes: "draft proposal",
            isCompleted: true,
            isStarted: true,
            orderHint: 0.5,
            isSavedForLater: false,
            forceAfterBedtime: false
        )

        let snapshot = event.snapshot

        #expect(snapshot.id == event.id)
        #expect(snapshot.title == event.title)
        #expect(snapshot.source == .local)
        #expect(snapshot.suggestedIcon == event.suggestedIcon)
        #expect(snapshot.tintToken == event.tintToken)
        #expect(snapshot.targetDurationMinutes == event.targetDurationMinutes)
        #expect(snapshot.minimumDurationMinutes == event.minimumDurationMinutes)
        #expect(snapshot.scheduledDay == day)
        #expect(snapshot.preferredStartMinutes == event.preferredStartMinutes)
        #expect(snapshot.preferredTimeWindow == .morning)
        #expect(snapshot.flexibility == .askBeforeMove)
        #expect(snapshot.calendarEventID == "cal-42")
        #expect(snapshot.routineRole == .workWindow)
        #expect(snapshot.notes == event.notes)
        #expect(snapshot.isCompleted)
        #expect(snapshot.isStarted)
        #expect(snapshot.orderHint == 0.5)
        #expect(snapshot.isSavedForLater == false)
        #expect(snapshot.forceAfterBedtime == false)
    }

    @Test("CalendarLink.snapshot mirrors stored fields")
    func calendarLinkSnapshotRoundTrip() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(3_600)
        let link = CalendarLink(
            id: UUID(),
            calendarEventID: "evt-9",
            title: "Workshop",
            flexibility: .locked,
            editPolicy: .systemCalendar,
            localOverrideStart: start,
            localOverrideEnd: end
        )

        let snapshot = link.snapshot

        #expect(snapshot.id == link.id)
        #expect(snapshot.calendarEventID == "evt-9")
        #expect(snapshot.flexibility == .locked)
        #expect(snapshot.editPolicy == .systemCalendar)
        #expect(snapshot.localOverrideStart == start)
        #expect(snapshot.localOverrideEnd == end)
    }

    @Test("DayTemplate.snapshot mirrors stored fields")
    func dayTemplateSnapshotRoundTrip() {
        let template = DayTemplate(
            id: UUID(),
            key: "custom",
            wakeUpMinutes: 6 * 60,
            sleepStartMinutes: 23 * 60,
            breakfastMinutes: 7 * 60,
            lunchMinutes: 12 * 60 + 30,
            dinnerMinutes: 19 * 60,
            quietStartMinutes: 20 * 60 + 30,
            quietDurationMinutes: 45,
            workoutMinutes: 17 * 60,
            workoutDurationMinutes: 30,
            includeWorkout: false,
            transitionBufferMinutes: 5
        )

        let snapshot = template.snapshot

        #expect(snapshot.wakeUpMinutes == 6 * 60)
        #expect(snapshot.sleepStartMinutes == 23 * 60)
        #expect(snapshot.breakfastMinutes == 7 * 60)
        #expect(snapshot.lunchMinutes == 12 * 60 + 30)
        #expect(snapshot.dinnerMinutes == 19 * 60)
        #expect(snapshot.quietStartMinutes == 20 * 60 + 30)
        #expect(snapshot.quietDurationMinutes == 45)
        #expect(snapshot.workoutMinutes == 17 * 60)
        #expect(snapshot.workoutDurationMinutes == 30)
        #expect(snapshot.includeWorkout == false)
        #expect(snapshot.transitionBufferMinutes == 5)
    }

    @Test("DailyBudget.snapshot mirrors stored fields")
    func dailyBudgetSnapshotRoundTrip() {
        let budget = DailyBudget(
            id: UUID(),
            key: "custom",
            minimumSleepHours: 7.5,
            minimumRestMinutes: 90,
            targetWorkMinutes: 5 * 60,
            maxFocusItems: 4,
            mealDurationMinutes: 30,
            workoutTargetMinutes: 60,
            quickAddDefaultDurationMinutes: 20,
            lowNotificationMode: false,
            useSimplifiedMode: true
        )

        let snapshot = budget.snapshot

        #expect(snapshot.minimumSleepHours == 7.5)
        #expect(snapshot.minimumRestMinutes == 90)
        #expect(snapshot.targetWorkMinutes == 5 * 60)
        #expect(snapshot.maxFocusItems == 4)
        #expect(snapshot.mealDurationMinutes == 30)
        #expect(snapshot.workoutTargetMinutes == 60)
        #expect(snapshot.quickAddDefaultDurationMinutes == 20)
        #expect(snapshot.lowNotificationMode == false)
        #expect(snapshot.useSimplifiedMode)
    }
}
