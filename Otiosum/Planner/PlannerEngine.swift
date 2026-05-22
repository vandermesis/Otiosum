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
        let templateOverrides = localItems.filter { item in
            guard let scheduledDay = item.scheduledDay else { return false }
            return item.source == .local
                && item.routineRole != nil
                && item.isSavedForLater == false
                && calendar.isDate(scheduledDay, inSameDayAs: day)
                && templateBlocks.contains { block in
                    block.title == item.title && block.routineRole == item.routineRole
                }
        }
        let templateOverrideIDs = Set(templateOverrides.map(\.id))
        let localTemplateOverrideBlocks = templateOverrides.map {
            makeLocalTemplateOverrideBlock(item: $0, day: day, endOfDay: endOfDay)
        }
        let routineBlocks = templateBlocks
        .filter { block in
            templateOverrides.contains { override in
                override.title == block.title && override.routineRole == block.routineRole
            } == false
        }

        let calendarBlocks = CalendarBlockFactory().makeBlocks(
            for: day,
            calendarEvents: calendarEvents,
            calendarLinks: calendarLinks,
            startOfDay: startOfDay,
            endOfDay: endOfDay
        )

        let allDayCalendarBlocks = calendarBlocks.filter(\.isAllDay)
        let timedCalendarBlocks = calendarBlocks.filter { !$0.isAllDay }

        var allBlocks = (routineBlocks + timedCalendarBlocks + localTemplateOverrideBlocks).sorted(by: blockSort)
        var tooMuchTodayIssues: [TooMuchTodayIssue] = []

        let scheduledItems = localItems
            .filter { item in
                guard let scheduledDay = item.scheduledDay else { return false }
                return calendar.isDate(scheduledDay, inSameDayAs: day)
                    && item.isSavedForLater == false
                    && templateOverrideIDs.contains(item.id) == false
            }
            .sorted(by: localItemSort)

        for item in scheduledItems {
            switch place(
                item: item,
                day: day,
                existingBlocks: allBlocks,
                template: template,
                budget: budget,
                sleepBoundary: sleepBoundary,
                endOfDay: endOfDay
            ) {
            case .scheduled(let block):
                allBlocks.append(block)
                allBlocks.sort(by: blockSort)
            case .tooMuchToday(let issue):
                tooMuchTodayIssues.append(issue)
            }
        }

        let scheduled = TimelineScheduler(calendar: calendar).schedule(
            blocks: allBlocks,
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

        let incompleteBlocks = finalBlocks
            .filter { $0.isCompleted == false && $0.isAllDay == false }
            .sorted(by: blockSort)

        let nowBlock = incompleteBlocks.last(where: { context.now >= $0.start && context.now < $0.end })
        let nextBlock = incompleteBlocks.first(where: { $0.start > context.now })
        let laterBlocks = incompleteBlocks.filter { block in
            block.id != nowBlock?.id && block.id != nextBlock?.id && block.start >= context.now
        }

        return DayPlan(
            day: day,
            allBlocks: finalBlocks,
            nowBlock: nowBlock,
            nextBlock: nextBlock,
            laterBlocks: laterBlocks,
            warnings: warnings,
            tooMuchTodayIssues: deduplicated(tooMuchTodayIssues),
            shiftProposals: [],
            budgetSummary: budgetSummary
        )
    }

    private func place(
        item: EventSnapshot,
        day: Date,
        existingBlocks: [PlannedBlock],
        template: DayTemplateSnapshot,
        budget: DailyBudgetSnapshot,
        sleepBoundary: Date,
        endOfDay: Date
    ) -> PlacementResult {
        let startMinutes = max(
            item.preferredStartMinutes ?? item.preferredTimeWindow.startMinutes,
            template.wakeUpMinutes
        )
        let duration = max(item.targetDurationMinutes, item.minimumDurationMinutes)
        let limit = endOfDay
        var candidateStart = calendar.date(on: day, minutesFromStartOfDay: startMinutes)

        while candidateStart < endOfDay {
            let candidateEnd = candidateStart.adding(minutes: duration)
            if candidateEnd > limit {
                return .tooMuchToday(
                    TooMuchTodayIssue(
                        itemID: item.id,
                        title: item.title,
                        message: item.forceAfterBedtime
                            ? "There is no calm slot left today."
                            : "Not enough room today. This would cut into sleep or recovery.",
                        displacedRole: item.forceAfterBedtime ? nil : .sleep,
                        suggestedDate: calendar.date(byAdding: .day, value: 1, to: day) ?? day
                    )
                )
            }

            if let conflict = existingBlocks.first(where: { overlaps(start: candidateStart, end: candidateEnd, with: $0) }) {
                candidateStart = conflict.end.adding(minutes: template.transitionBufferMinutes)
                continue
            }

            let block = PlannedBlock(
                id: item.id,
                itemID: item.id,
                calendarEventID: item.calendarEventID,
                title: item.title,
                start: candidateStart,
                end: candidateEnd,
                source: item.source,
                flexibility: item.flexibility,
                symbolName: item.suggestedIcon,
                tintToken: item.tintToken,
                notes: item.notes,
                isAllDay: false,
                routineRole: item.routineRole,
                isCompleted: item.isCompleted,
                isStarted: item.isStarted,
                status: item.isCompleted ? .complete : .upcoming,
                confidence: item.isCompleted ? 1 : 0.7
            )
            return .scheduled(block)
        }

        return .tooMuchToday(
            TooMuchTodayIssue(
                itemID: item.id,
                title: item.title,
                message: "This can wait. The day is already full.",
                displacedRole: nil,
                suggestedDate: calendar.date(byAdding: .day, value: 1, to: day) ?? day
            )
        )
    }

    private func makeLocalTemplateOverrideBlock(
        item: EventSnapshot,
        day: Date,
        endOfDay: Date
    ) -> PlannedBlock {
        let startMinutes = item.preferredStartMinutes ?? item.preferredTimeWindow.startMinutes
        let duration = max(item.targetDurationMinutes, item.minimumDurationMinutes)
        let start = calendar.date(on: day, minutesFromStartOfDay: startMinutes)
        let end = min(start.adding(minutes: duration), endOfDay)

        return PlannedBlock(
            id: item.id,
            itemID: item.id,
            calendarEventID: item.calendarEventID,
            title: item.title,
            start: start,
            end: end,
            source: item.source,
            flexibility: item.flexibility,
            symbolName: item.suggestedIcon,
            tintToken: item.tintToken,
            notes: item.notes,
            isAllDay: false,
            routineRole: item.routineRole,
            isCompleted: item.isCompleted,
            isStarted: item.isStarted,
            status: item.isCompleted ? .complete : .upcoming,
            confidence: item.isCompleted ? 1 : 0.7
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

    private func overlaps(
        start: Date,
        end: Date,
        with block: PlannedBlock
    ) -> Bool {
        start < block.end && end > block.start
    }

    private func localItemSort(_ lhs: EventSnapshot, _ rhs: EventSnapshot) -> Bool {
        let lhsStart = lhs.preferredStartMinutes ?? lhs.preferredTimeWindow.startMinutes
        let rhsStart = rhs.preferredStartMinutes ?? rhs.preferredTimeWindow.startMinutes

        if lhsStart == rhsStart {
            return lhs.orderHint < rhs.orderHint
        }

        return lhsStart < rhsStart
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

    private func deduplicated(_ proposals: [CalendarShiftProposal]) -> [CalendarShiftProposal] {
        var seen = Set<String>()
        return proposals.filter { seen.insert($0.calendarEventID).inserted }
    }
}

private enum PlacementResult {
    case scheduled(PlannedBlock)
    case tooMuchToday(TooMuchTodayIssue)
}
