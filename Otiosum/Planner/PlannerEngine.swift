import Foundation

struct PlannerEngine {
    private let calendar: Calendar
    private let inferenceEngine: InferenceEngine

    init(
        calendar: Calendar = .current,
        inferenceEngine: InferenceEngine = InferenceEngine()
    ) {
        self.calendar = calendar
        self.inferenceEngine = inferenceEngine
    }

    func plan(
        for day: Date,
        localItems: [EventSnapshot],
        calendarEvents: [CalendarEventSnapshot],
        calendarLinks: [CalendarLinkSnapshot],
        template: DayTemplateSnapshot,
        budget: DailyBudgetSnapshot,
        context: InferenceContext
    ) -> DayPlan {
        let startOfDay = calendar.startOfDay(for: day)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.adding(minutes: 24 * 60)
        let sleepBoundary = calendar.date(on: day, minutesFromStartOfDay: template.sleepStartMinutes)

        let templateBlocks = RoutineBlockFactory(calendar: calendar).makeBlocks(
            for: day,
            template: template,
            budget: budget,
            endOfDay: endOfDay
        )
        let calendarBlocks = CalendarBlockFactory().makeBlocks(
            for: day,
            calendarEvents: calendarEvents,
            calendarLinks: calendarLinks,
            startOfDay: startOfDay,
            endOfDay: endOfDay
        )

        let allDayCalendarBlocks = calendarBlocks.filter(\.isAllDay)
        let timedCalendarBlocks = calendarBlocks.filter { !$0.isAllDay }

        let localBlocks = LocalBlockFactory(calendar: calendar).makeBlocks(
            for: day,
            localItems: localItems,
            templateBlocks: templateBlocks,
            fixedBlocks: timedCalendarBlocks,
            template: template,
            endOfDay: endOfDay
        )
        var tooMuchTodayIssues = localBlocks.tooMuchTodayIssues

        let scheduled = TimelineScheduler(calendar: calendar).schedule(
            blocks: localBlocks.blocks,
            now: context.now,
            day: day,
            transitionBufferMinutes: template.transitionBufferMinutes
        )

        let finalBlocks = decorateStatuses(scheduled.blocks + allDayCalendarBlocks, context: context)
        tooMuchTodayIssues.append(contentsOf: scheduled.sleepCollisionIssues)

        let budgetSummary = BudgetSummaryFactory().makeSummary(
            blocks: finalBlocks,
            budget: budget
        )

        let warnings = PlannerWarningBuilder().makeWarnings(
            blocks: finalBlocks,
            tooMuchTodayIssues: tooMuchTodayIssues,
            shiftProposals: [],
            budgetSummary: budgetSummary,
            budget: budget,
            template: template,
            sleepBoundary: sleepBoundary
        )

        let classification = TimelineBlockClassifier().classify(
            blocks: finalBlocks,
            now: context.now
        )

        return DayPlan(
            day: day,
            allBlocks: finalBlocks,
            nowBlock: classification.nowBlock,
            nextBlock: classification.nextBlock,
            laterBlocks: classification.laterBlocks,
            warnings: warnings,
            tooMuchTodayIssues: deduplicated(tooMuchTodayIssues),
            shiftProposals: [],
            budgetSummary: budgetSummary
        )
    }

    private func decorateStatuses(
        _ blocks: [PlannedBlock],
        context: InferenceContext
    ) -> [PlannedBlock] {
        blocks.map { block in
            let assessment = inferenceEngine.assess(block: block, now: context.now, context: context)
            let resolvedCompletion = block.isCompleted || (block.isStarted && context.now >= block.end)
            return PlannedBlock(
                id: block.id,
                itemID: block.itemID,
                calendarEventID: block.calendarEventID,
                title: block.title,
                start: block.start,
                end: block.end,
                source: block.source,
                flexibility: block.flexibility,
                symbolName: block.symbolName,
                tintToken: block.tintToken,
                notes: block.notes,
                isAllDay: block.isAllDay,
                routineRole: block.routineRole,
                isCompleted: resolvedCompletion,
                isStarted: resolvedCompletion ? false : block.isStarted,
                status: assessment.status,
                confidence: assessment.confidence
            )
        }
        .sorted(by: blockSort)
    }

    private func blockSort(_ lhs: PlannedBlock, _ rhs: PlannedBlock) -> Bool {
        if lhs.start == rhs.start {
            return lhs.end < rhs.end
        }

        return lhs.start < rhs.start
    }

    private func deduplicated(_ issues: [TooMuchTodayIssue]) -> [TooMuchTodayIssue] {
        var seen = Set<UUID>()
        return issues.filter { seen.insert($0.itemID).inserted }
    }
}
