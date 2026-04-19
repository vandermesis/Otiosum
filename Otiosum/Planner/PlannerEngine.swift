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

        let protectedBlocks = makeProtectedBlocks(
            for: day,
            template: template,
            budget: budget,
            endOfDay: endOfDay
        )

        let calendarBlocks = makeCalendarBlocks(
            for: day,
            calendarEvents: calendarEvents,
            calendarLinks: calendarLinks,
            startOfDay: startOfDay,
            endOfDay: endOfDay
        )

        let allDayCalendarBlocks = calendarBlocks.filter(\.isAllDay)
        let timedCalendarBlocks = calendarBlocks.filter { !$0.isAllDay }

        var allBlocks = (protectedBlocks + timedCalendarBlocks).sorted(by: blockSort)
        var overflowIssues: [OverflowIssue] = []

        let scheduledItems = localItems
            .filter { item in
                guard let scheduledDay = item.scheduledDay else { return false }
                return calendar.isDate(scheduledDay, inSameDayAs: day) && item.isArchived == false
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
            case .overflow(let issue):
                overflowIssues.append(issue)
            }
        }

        let adjusted = applyOverrunIfNeeded(
            to: allBlocks,
            itemLookup: Dictionary(uniqueKeysWithValues: localItems.map { ($0.id, $0) }),
            context: context,
            day: day,
            template: template,
            sleepBoundary: sleepBoundary,
            endOfDay: endOfDay
        )

        let finalBlocks = decorateStatuses(adjusted.blocks + allDayCalendarBlocks, context: context)
        overflowIssues.append(contentsOf: adjusted.overflowIssues)

        let budgetSummary = makeBudgetSummary(
            blocks: finalBlocks,
            budget: budget
        )

        let warnings = makeWarnings(
            blocks: finalBlocks,
            overflowIssues: overflowIssues,
            shiftProposals: adjusted.shiftProposals,
            budgetSummary: budgetSummary,
            budget: budget,
            template: template,
            sleepBoundary: sleepBoundary
        )

        let incompleteBlocks = finalBlocks
            .filter { $0.isCompleted == false && $0.isAllDay == false }
            .sorted(by: blockSort)

        let nowBlock = incompleteBlocks.last(where: { context.now >= $0.start && context.now < $0.end })
        let nextBlock = incompleteBlocks.first(where: { $0.start > context.now && $0.isProtected == false })
        let laterBlocks = incompleteBlocks.filter { block in
            block.isProtected == false && block.id != nowBlock?.id && block.id != nextBlock?.id && block.start >= context.now
        }
        let protectedUpcoming = incompleteBlocks.filter { $0.isProtected && $0.start >= context.now }

        return DayPlan(
            day: day,
            allBlocks: finalBlocks,
            nowBlock: nowBlock,
            nextBlock: nextBlock,
            laterBlocks: laterBlocks,
            protectedBlocks: protectedUpcoming,
            warnings: warnings,
            overflowIssues: deduplicated(overflowIssues),
            shiftProposals: deduplicated(adjusted.shiftProposals),
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
        let limit = item.forceAfterBedtime ? endOfDay : sleepBoundary
        var candidateStart = calendar.date(on: day, minutesFromStartOfDay: startMinutes)

        while candidateStart < endOfDay {
            let candidateEnd = candidateStart.adding(minutes: duration)
            if candidateEnd > limit {
                return .overflow(
                    OverflowIssue(
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
                status: item.isCompleted ? .complete : .upcoming,
                confidence: item.isCompleted ? 1 : 0.7
            )
            return .scheduled(block)
        }

        return .overflow(
            OverflowIssue(
                itemID: item.id,
                title: item.title,
                message: "This can wait. The day is already full.",
                displacedCategory: nil,
                suggestedDate: calendar.date(byAdding: .day, value: 1, to: day) ?? day
            )
        )
    }

    private func applyOverrunIfNeeded(
        to blocks: [PlannedBlock],
        itemLookup: [UUID: EventSnapshot],
        context: InferenceContext,
        day: Date,
        template: DayTemplateSnapshot,
        sleepBoundary: Date,
        endOfDay: Date
    ) -> OverrunResult {
        let sortedBlocks = blocks.sorted(by: blockSort)
        guard
            let activeIndex = sortedBlocks.lastIndex(where: { block in
                block.source == .local
                    && block.isCompleted == false
                    && block.isProtected == false
                    && block.start <= context.now
            })
        else {
            return OverrunResult(blocks: sortedBlocks, overflowIssues: [], shiftProposals: [], warnings: [])
        }

        let activeBlock = sortedBlocks[activeIndex]
        guard var extendedEnd = inferenceEngine.overrunEnd(
            for: activeBlock,
            now: context.now,
            context: context,
            transitionBufferMinutes: template.transitionBufferMinutes
        ) else {
            return OverrunResult(blocks: sortedBlocks, overflowIssues: [], shiftProposals: [], warnings: [])
        }

        var warnings: [GuardrailWarning] = []
        if let immovableConflict = sortedBlocks.dropFirst(activeIndex + 1).first(where: { block in
            block.start < extendedEnd && (block.isProtected || block.flexibility == .locked)
        }) {
            extendedEnd = immovableConflict.start
            warnings.append(
                GuardrailWarning(
                    message: "A fixed block is coming up soon.",
                    detail: "Otiosum kept \(immovableConflict.title) in place so you do not need to rush more than necessary.",
                    severity: .calm
                )
            )
        }

        guard extendedEnd > activeBlock.end else {
            return OverrunResult(blocks: sortedBlocks, overflowIssues: [], shiftProposals: [], warnings: warnings)
        }

        var result = Array(sortedBlocks.prefix(activeIndex))
        let extendedActive = shifted(block: activeBlock, start: activeBlock.start, end: extendedEnd)
        result.append(extendedActive)

        var overflowIssues: [OverflowIssue] = []
        var shiftProposals: [CalendarShiftProposal] = []
        var runningEnd = extendedActive.end

        for block in sortedBlocks.dropFirst(activeIndex + 1) {
            if block.start >= runningEnd {
                result.append(block)
                runningEnd = block.end
                continue
            }

            let proposedStart = runningEnd
            let proposedEnd = proposedStart.addingTimeInterval(block.end.timeIntervalSince(block.start))

            if block.source == .calendar {
                if block.flexibility == .askBeforeMove {
                    shiftProposals.append(
                        CalendarShiftProposal(
                            calendarEventID: block.calendarEventID ?? "",
                            title: block.title,
                            currentStart: block.start,
                            currentEnd: block.end,
                            suggestedStart: proposedStart,
                            suggestedEnd: proposedEnd
                        )
                    )
                }

                if block.flexibility == .locked {
                    result.append(block)
                    runningEnd = block.end
                    continue
                }

                result.append(shifted(block: block, start: proposedStart, end: proposedEnd))
                runningEnd = proposedEnd
                continue
            }

            if block.isProtected {
                result.append(block)
                runningEnd = block.end
                continue
            }

            let forceAfterBedtime = itemLookup[block.itemID]?.forceAfterBedtime ?? false
            if proposedEnd > sleepBoundary && forceAfterBedtime == false {
                overflowIssues.append(
                    OverflowIssue(
                        itemID: block.itemID,
                        title: block.title,
                        message: "Not enough room today. This would cut into sleep or recovery.",
                        displacedCategory: .sleep,
                        suggestedDate: calendar.date(byAdding: .day, value: 1, to: day) ?? day
                    )
                )
                continue
            }

            let clampedEnd = min(proposedEnd, endOfDay)
            result.append(shifted(block: block, start: proposedStart, end: clampedEnd))
            runningEnd = clampedEnd.adding(minutes: template.transitionBufferMinutes)
        }

        return OverrunResult(
            blocks: result.sorted(by: blockSort),
            overflowIssues: overflowIssues,
            shiftProposals: shiftProposals.filter { $0.calendarEventID.isEmpty == false },
            warnings: warnings
        )
    }

    private func decorateStatuses(
        _ blocks: [PlannedBlock],
        context: InferenceContext
    ) -> [PlannedBlock] {
        blocks.map { block in
            let assessment = inferenceEngine.assess(block: block, now: context.now, context: context)
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
                isCompleted: block.isCompleted,
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
            flexibility: .locked,
            symbolName: symbol,
            tintToken: tintToken,
            notes: "",
            isAllDay: false,
            protectedCategory: category,
            isCompleted: false,
            status: .protectedTime,
            confidence: 1
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
            .filter { $0.isProtected == false }
            .reduce(0) { $0 + $1.durationMinutes }
        let restMinutes = blocks
            .filter { $0.protectedCategory == .rest }
            .reduce(0) { $0 + $1.durationMinutes }
        let sleepMinutesProtected = Int(budget.minimumSleepHours * 60)
        let scheduledCount = blocks.filter { $0.isProtected == false }.count

        return BudgetUsageSummary(
            workMinutes: workMinutes,
            restMinutes: restMinutes,
            sleepMinutesProtected: sleepMinutesProtected,
            scheduledCount: scheduledCount
        )
    }

    private func makeWarnings(
        blocks: [PlannedBlock],
        overflowIssues: [OverflowIssue],
        shiftProposals: [CalendarShiftProposal],
        budgetSummary: BudgetUsageSummary,
        budget: DailyBudgetSnapshot,
        template: DayTemplateSnapshot,
        sleepBoundary: Date
    ) -> [GuardrailWarning] {
        var warnings: [GuardrailWarning] = []

        if overflowIssues.isEmpty == false {
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
                    detail: "Consider leaving some ideas in the jar so the timeline stays gentle.",
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

    private func deduplicated(_ issues: [OverflowIssue]) -> [OverflowIssue] {
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
    case overflow(OverflowIssue)
}

private struct OverrunResult {
    var blocks: [PlannedBlock]
    var overflowIssues: [OverflowIssue]
    var shiftProposals: [CalendarShiftProposal]
    var warnings: [GuardrailWarning]
}
