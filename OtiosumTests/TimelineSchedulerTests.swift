import Foundation
import Testing
@testable import Otiosum

struct TimelineSchedulerTests {
    private let scheduler = TimelineScheduler(calendar: TimelineSchedulerTests.calendar)

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }()

    @Test("Overdue unstarted task is pushed to current time")
    func overdueUnstartedTaskIsPushedToCurrentTime() throws {
        let day = try makeDate(year: 2026, month: 5, day: 21)
        let task = block(title: "Launch", start: day.adding(minutes: 9 * 60), duration: 30)
        let now = day.adding(minutes: 10 * 60 + 2)

        let result = scheduler.schedule(
            blocks: [task],
            now: now,
            day: day,
            transitionBufferMinutes: 0
        )

        let scheduled = try #require(result.blocks.first)
        #expect(scheduled.start == day.adding(minutes: 10 * 60 + 5))
        assertNoOverlap(result.blocks)
    }

    @Test("Pushed task cascades into following task")
    func pushedTaskCascadesIntoFollowingTask() throws {
        let day = try makeDate(year: 2026, month: 5, day: 21)
        let launch = block(title: "Launch", start: day.adding(minutes: 9 * 60), duration: 30)
        let workout = block(title: "Workout", start: day.adding(minutes: 9 * 60 + 30), duration: 45, source: .template)
        let now = day.adding(minutes: 10 * 60 + 2)

        let result = scheduler.schedule(
            blocks: [launch, workout],
            now: now,
            day: day,
            transitionBufferMinutes: 0
        )

        let scheduledLaunch = try #require(result.blocks.first { $0.title == "Launch" })
        let scheduledWorkout = try #require(result.blocks.first { $0.title == "Workout" })
        #expect(scheduledLaunch.start == day.adding(minutes: 10 * 60 + 5))
        #expect(scheduledWorkout.start == scheduledLaunch.end)
        assertNoOverlap(result.blocks)
    }

    @Test("Started task is not pushed by current time")
    func startedTaskIsNotPushedByCurrentTime() throws {
        let day = try makeDate(year: 2026, month: 5, day: 21)
        let task = block(title: "Launch", start: day.adding(minutes: 9 * 60), duration: 30, isStarted: true)
        let now = day.adding(minutes: 10 * 60 + 2)

        let result = scheduler.schedule(
            blocks: [task],
            now: now,
            day: day,
            transitionBufferMinutes: 0
        )

        let scheduled = try #require(result.blocks.first)
        #expect(scheduled.start == task.start)
        assertNoOverlap(result.blocks)
    }

    @Test("Pushing sleep creates a sleep collision decision")
    func pushingSleepCreatesSleepCollisionDecision() throws {
        let day = try makeDate(year: 2026, month: 5, day: 21)
        let launchID = UUID()
        let launch = block(id: launchID, title: "Launch", start: day.adding(minutes: 22 * 60), duration: 90)
        let sleep = block(title: "Sleep", start: day.adding(minutes: 23 * 60), duration: 60, routineRole: .sleep)
        let now = day.adding(minutes: 22 * 60 + 45)

        let result = scheduler.schedule(
            blocks: [launch, sleep],
            now: now,
            day: day,
            transitionBufferMinutes: 0
        )

        let scheduledLaunch = try #require(result.blocks.first { $0.title == "Launch" })
        let scheduledSleep = try #require(result.blocks.first { $0.title == "Sleep" })
        #expect(scheduledSleep.start >= scheduledLaunch.end)
        #expect(result.sleepCollisionIssues.count == 1)
        #expect(result.sleepCollisionIssues.first?.itemID == launchID)
        #expect(result.sleepCollisionIssues.first?.title == "Launch")
        assertNoOverlap(result.blocks)
    }

    @Test("Manual move to occupied space is rejected without moving other tasks")
    func manualMoveToOccupiedSpaceIsRejected() throws {
        let day = try makeDate(year: 2026, month: 5, day: 21)
        let launch = block(title: "Launch", start: day.adding(minutes: 10 * 60), duration: 30)
        let workout = block(title: "Workout", start: day.adding(minutes: 11 * 60), duration: 45)
        let proposedStart = day.adding(minutes: 11 * 60 + 15)

        let result = scheduler.moveResult(
            for: launch,
            to: proposedStart,
            among: [launch, workout]
        )

        #expect(result.canMove == false)
        #expect(result.conflictingBlock?.title == "Workout")
    }

    @Test("Manual move to free space is accepted")
    func manualMoveToFreeSpaceIsAccepted() throws {
        let day = try makeDate(year: 2026, month: 5, day: 21)
        let launch = block(title: "Launch", start: day.adding(minutes: 10 * 60), duration: 30)
        let workout = block(title: "Workout", start: day.adding(minutes: 11 * 60), duration: 45)
        let proposedStart = day.adding(minutes: 12 * 60)

        let result = scheduler.moveResult(
            for: launch,
            to: proposedStart,
            among: [launch, workout]
        )

        #expect(result.canMove)
        #expect(result.conflictingBlock == nil)
    }

    @Test("Dropping unscheduled task into occupied space is rejected")
    func dropIntoOccupiedSpaceIsRejected() throws {
        let day = try makeDate(year: 2026, month: 5, day: 21)
        let itemID = UUID()
        let workout = block(title: "Workout", start: day.adding(minutes: 11 * 60), duration: 45)
        let proposedStart = day.adding(minutes: 11 * 60 + 15)

        let conflict = scheduler.conflict(
            for: itemID,
            proposedStart: proposedStart,
            durationMinutes: 30,
            among: [workout]
        )

        #expect(conflict?.title == "Workout")
    }

    private func block(
        id: UUID = UUID(),
        title: String,
        start: Date,
        duration: Int,
        source: PlannerItemSource = .local,
        routineRole: RoutineRole? = nil,
        isCompleted: Bool = false,
        isStarted: Bool = false
    ) -> PlannedBlock {
        PlannedBlock(
            id: id,
            itemID: id,
            calendarEventID: nil,
            title: title,
            start: start,
            end: start.adding(minutes: duration),
            source: source,
            flexibility: .flexible,
            symbolName: "circle",
            tintToken: "teal",
            notes: "",
            isAllDay: false,
            routineRole: routineRole,
            isCompleted: isCompleted,
            isStarted: isStarted,
            status: isCompleted ? .complete : .upcoming,
            confidence: 0.7
        )
    }

    private func assertNoOverlap(_ blocks: [PlannedBlock]) {
        let sorted = blocks.filter { !$0.isAllDay }.sorted { $0.start < $1.start }
        for pair in zip(sorted, sorted.dropFirst()) {
            #expect(pair.0.end <= pair.1.start)
        }
    }

    private func makeDate(year: Int, month: Int, day: Int) throws -> Date {
        try #require(
            Self.calendar.date(
                from: DateComponents(
                    calendar: Self.calendar,
                    timeZone: Self.calendar.timeZone,
                    year: year,
                    month: month,
                    day: day
                )
            )
        )
    }
}
