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

        let templateProtectedBlocks = makeProtectedBlocks(
            for: day,
            template: template,
            budget: budget,
            endOfDay: endOfDay
        )
        let protectedTemplateOverrides = localItems.filter { item in
            guard let scheduledDay = item.scheduledDay else { return false }
            return item.source == .local
                && item.protectedCategory != nil
                && item.isSavedForLater == false
                && calendar.isDate(scheduledDay, inSameDayAs: day)
                && templateProtectedBlocks.contains { block in
                    block.title == item.title && block.protectedCategory == item.protectedCategory
                }
        }
        let protectedTemplateOverrideIDs = Set(protectedTemplateOverrides.map(\.id))
        let localProtectedOverrideBlocks = protectedTemplateOverrides.map {
            makeLocalProtectedOverrideBlock(item: $0, day: day, endOfDay: endOfDay)
        }
        let protectedBlocks = templateProtectedBlocks
        .filter { block in
            protectedTemplateOverrides.contains { override in
                override.title == block.title && override.protectedCategory == block.protectedCategory
            } == false
        }

        let calendarBlocks = makeCalendarBlocks(
            for: day,
            calendarEvents: calendarEvents,
            calendarLinks: calendarLinks,
            startOfDay: startOfDay,
            endOfDay: endOfDay
        )

        let allDayCalendarBlocks = calendarBlocks.filter(\.isAllDay)
        let timedCalendarBlocks = calendarBlocks.filter { !$0.isAllDay }

        var allBlocks = (protectedBlocks + timedCalendarBlocks + localProtectedOverrideBlocks).sorted(by: blockSort)
        var tooMuchTodayIssues: [TooMuchTodayIssue] = []

        let scheduledItems = localItems
            .filter { item in
                guard let scheduledDay = item.scheduledDay else { return false }
                return calendar.isDate(scheduledDay, inSameDayAs: day)
                    && item.isSavedForLater == false
                    && protectedTemplateOverrideIDs.contains(item.id) == false
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

        let budgetSummary = makeBudgetSummary(
            blocks: finalBlocks,
            budget: budget
        )

        let warnings = makeWarnings(
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
            protectedBlocks: [],
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
                        displacedCategory: item.forceAfterBedtime ? nil : .sleep,
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
                protectedCategory: item.protectedCategory,
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
                displacedCategory: nil,
                suggestedDate: calendar.date(byAdding: .day, value: 1, to: day) ?? day
            )
        )
    }

    private func makeLocalProtectedOverrideBlock(
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
            protectedCategory: item.protectedCategory,
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
                protectedCategory: block.protectedCategory,
                isCompleted: resolvedCompletion,
                isStarted: resolvedCompletion ? false : block.isStarted,
                status: assessment.status,
                confidence: assessment.confidence
            )
        }
        .sorted(by: blockSort)
    }

    private func makeProtectedBlocks(
        for day: Date,
        template: DayTemplateSnapshot,
        budget: DailyBudgetSnapshot,
        endOfDay: Date
    ) -> [PlannedBlock] {
        var blocks: [PlannedBlock] = []
        let mealDuration = budget.mealDurationMinutes

        let breakfast = makeProtectedBlock(
            title: "Breakfast",
            symbol: "fork.knife",
            tintToken: "peach",
            category: .meal,
            day: day,
            startMinutes: template.breakfastMinutes,
            durationMinutes: mealDuration
        )
        let lunch = makeProtectedBlock(
            title: "Lunch",
            symbol: "fork.knife",
            tintToken: "peach",
            category: .meal,
            day: day,
            startMinutes: template.lunchMinutes,
            durationMinutes: mealDuration
        )
        let dinner = makeProtectedBlock(
            title: "Dinner",
            symbol: "fork.knife",
            tintToken: "peach",
            category: .meal,
            day: day,
            startMinutes: template.dinnerMinutes,
            durationMinutes: mealDuration
        )
        let quiet = makeProtectedBlock(
            title: "Recovery",
            symbol: "leaf.fill",
            tintToken: "sage",
            category: .rest,
            day: day,
            startMinutes: template.quietStartMinutes,
            durationMinutes: template.quietDurationMinutes
        )
        let sleep = makeProtectedBlock(
            title: "Sleep",
            symbol: "bed.double.fill",
            tintToken: "indigo",
            category: .sleep,
            day: day,
            startMinutes: template.sleepStartMinutes,
            end: endOfDay
        )

        blocks.append(contentsOf: [breakfast, lunch, dinner, quiet, sleep])

        if template.includeWorkout {
            blocks.append(
                makeProtectedBlock(
                    title: "Workout",
                    symbol: "figure.walk",
                    tintToken: "lime",
                    category: .workout,
                    day: day,
                    startMinutes: template.workoutMinutes,
                    durationMinutes: template.workoutDurationMinutes
                )
            )
        }

        return blocks.sorted(by: blockSort)
    }

    private func makeProtectedBlock(
        title: String,
        symbol: String,
        tintToken: String,
        category: ProtectedCategory,
        day: Date,
        startMinutes: Int,
        durationMinutes: Int? = nil,
        end: Date? = nil
    ) -> PlannedBlock {
        let start = calendar.date(on: day, minutesFromStartOfDay: startMinutes)
        let endDate = end ?? start.adding(minutes: durationMinutes ?? 30)
        return PlannedBlock(
            id: UUID(),
            itemID: UUID(),
            calendarEventID: nil,
            title: title,
            start: start,
            end: endDate,
            source: .template,
            flexibility: .flexible,
            symbolName: symbol,
            tintToken: tintToken,
            notes: "",
            isAllDay: false,
            protectedCategory: category,
            isCompleted: false,
            isStarted: false,
            status: .upcoming,
            confidence: 0.7
        )
    }

    private func makeCalendarBlocks(
        for day: Date,
        calendarEvents: [CalendarEventSnapshot],
        calendarLinks: [CalendarLinkSnapshot],
        startOfDay: Date,
        endOfDay: Date
    ) -> [PlannedBlock] {
        let linksByEventID = Dictionary(uniqueKeysWithValues: calendarLinks.map { ($0.calendarEventID, $0) })

        return calendarEvents.map { event in
            let link = linksByEventID[event.id]
            let icon = IconSuggester.suggest(for: event.title)
            let start = max(link?.localOverrideStart ?? event.start, startOfDay)
            let end = min(link?.localOverrideEnd ?? event.end, endOfDay)

            return PlannedBlock(
                id: UUID(),
                itemID: UUID(),
                calendarEventID: event.id,
                title: event.title,
                start: start,
                end: max(start.adding(minutes: 15), end),
                source: .calendar,
                flexibility: link?.flexibility ?? .askBeforeMove,
                symbolName: icon.symbolName,
                tintToken: icon.tintToken,
                notes: event.notes,
                isAllDay: event.isAllDay,
                protectedCategory: nil,
                isCompleted: false,
                isStarted: false,
                status: .upcoming,
                confidence: 0.7
            )
        }
        .sorted(by: blockSort)
    }

    private func makeBudgetSummary(
        blocks: [PlannedBlock],
        budget: DailyBudgetSnapshot
    ) -> BudgetUsageSummary {
        let workMinutes = blocks
            .filter { $0.isAllDay == false && $0.isCompleted == false }
            .reduce(0) { $0 + $1.durationMinutes }
        let restMinutes = blocks
            .filter { $0.protectedCategory == .rest }
            .reduce(0) { $0 + $1.durationMinutes }
        let sleepMinutesProtected = Int(budget.minimumSleepHours * 60)
        let scheduledCount = blocks.filter { $0.isAllDay == false && $0.isCompleted == false }.count

        return BudgetUsageSummary(
            workMinutes: workMinutes,
            restMinutes: restMinutes,
            sleepMinutesProtected: sleepMinutesProtected,
            scheduledCount: scheduledCount
        )
    }

    private func makeWarnings(
        blocks: [PlannedBlock],
        tooMuchTodayIssues: [TooMuchTodayIssue],
        shiftProposals: [CalendarShiftProposal],
        budgetSummary: BudgetUsageSummary,
        budget: DailyBudgetSnapshot,
        template: DayTemplateSnapshot,
        sleepBoundary: Date
    ) -> [GuardrailWarning] {
        var warnings: [GuardrailWarning] = []

        if tooMuchTodayIssues.isEmpty == false {
            warnings.append(
                GuardrailWarning(
                    message: "Not enough room today.",
                    detail: "Otiosum found items that would cut into sleep or recovery. You can move them gently instead of squeezing more in.",
                    severity: .attention
                )
            )
        }

        if shiftProposals.isEmpty == false {
            warnings.append(
                GuardrailWarning(
                    message: "A calendar shift needs your choice.",
                    detail: "A synced event was moved in the local plan so the day stays calm. Decide whether to keep that change local or update Calendar too.",
                    severity: .calm
                )
            )
        }

        if budgetSummary.workMinutes > budget.targetWorkMinutes {
            warnings.append(
                GuardrailWarning(
                    message: "This day is carrying a lot.",
                    detail: "Planned work is above the target. Protecting recovery may make tomorrow feel easier.",
                    severity: .calm
                )
            )
        }

        if budgetSummary.scheduledCount > budget.maxFocusItems {
            warnings.append(
                GuardrailWarning(
                    message: "This is already a full list.",
                    detail: "Consider leaving some ideas for later so the timeline stays gentle.",
                    severity: .calm
                )
            )
        }

        let afterSleep = blocks.filter { $0.isProtected == false && $0.end > sleepBoundary }
        if afterSleep.isEmpty == false {
            warnings.append(
                GuardrailWarning(
                    message: "Protect sleep?",
                    detail: "Some items drifted past bedtime. Otiosum can move them instead of packing the night tighter.",
                    severity: .attention
                )
            )
        }

        if template.quietDurationMinutes < budget.minimumRestMinutes {
            warnings.append(
                GuardrailWarning(
                    message: "Quiet time is below the rest target.",
                    detail: "You can expand recovery time in Settings whenever the day feels too compressed.",
                    severity: .calm
                )
            )
        }

        return warnings
    }

    private func overlaps(
        start: Date,
        end: Date,
        with block: PlannedBlock
    ) -> Bool {
        start < block.end && end > block.start
    }

    private func shifted(
        block: PlannedBlock,
        start: Date,
        end: Date
    ) -> PlannedBlock {
        PlannedBlock(
            id: block.id,
            itemID: block.itemID,
            calendarEventID: block.calendarEventID,
            title: block.title,
            start: start,
            end: end,
            source: block.source,
            flexibility: block.flexibility,
            symbolName: block.symbolName,
            tintToken: block.tintToken,
            notes: block.notes,
            isAllDay: block.isAllDay,
            protectedCategory: block.protectedCategory,
            isCompleted: block.isCompleted,
            isStarted: block.isStarted,
            status: block.status,
            confidence: block.confidence
        )
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
            if lhs.isProtected == rhs.isProtected {
                return lhs.end < rhs.end
            }
            return lhs.isProtected
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
