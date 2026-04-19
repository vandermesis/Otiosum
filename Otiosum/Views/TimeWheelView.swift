import SwiftUI

struct TimeWheelView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let day: Date
    let blocks: [PlannedBlock]
    let warnings: [GuardrailWarning]
    let currentBlockID: UUID?
    let nextBlockID: UUID?
    let showsHeader: Bool
    let timelineDraft: TimelineDraftTask?
    let onDropSomedayItem: ((UUID, Date) -> Bool)?
    let onRescheduleBlock: ((PlannedBlock, Date) -> Void)?
    let onAdjustBlockDuration: ((PlannedBlock, Int) -> Void)?
    let onQuickAction: ((PlannedBlock, TimelineQuickAction) -> Void)?
    let onTimelineDraftMoved: ((Date) -> Void)?

    @State private var scrollAnchorDate: Date?
    @State private var dragState: TimelineDragState?
    @State private var snapFeedbackToken = 0
    @State private var invalidDropFeedbackToken = 0
    @State private var invalidDropMessage: String?

    private let calendar = Calendar.current
    private let slotMinutes = 5
    private let pointsPerMinute: CGFloat = 2.2
    // Keep the timeline window finite so SwiftUI doesn't build hundreds of thousands of rows.
    private let visibleDayRange: Int = 3

    init(
        day: Date = .now,
        blocks: [PlannedBlock] = [],
        warnings: [GuardrailWarning] = [],
        currentBlockID: UUID? = nil,
        nextBlockID: UUID? = nil,
        showsHeader: Bool = true,
        timelineDraft: TimelineDraftTask? = nil,
        onDropSomedayItem: ((UUID, Date) -> Bool)? = nil,
        onRescheduleBlock: ((PlannedBlock, Date) -> Void)? = nil,
        onAdjustBlockDuration: ((PlannedBlock, Int) -> Void)? = nil,
        onQuickAction: ((PlannedBlock, TimelineQuickAction) -> Void)? = nil,
        onTimelineDraftMoved: ((Date) -> Void)? = nil
    ) {
        self.day = day
        self.blocks = blocks
        self.warnings = warnings
        self.currentBlockID = currentBlockID
        self.nextBlockID = nextBlockID
        self.showsHeader = showsHeader
        self.timelineDraft = timelineDraft
        self.onDropSomedayItem = onDropSomedayItem
        self.onRescheduleBlock = onRescheduleBlock
        self.onAdjustBlockDuration = onAdjustBlockDuration
        self.onQuickAction = onQuickAction
        self.onTimelineDraftMoved = onTimelineDraftMoved
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            let range = timelineRange(reference: now)

            GeometryReader { proxy in
                let laneWidth = max(proxy.size.width - 124, 180)

                ZStack(alignment: .bottomTrailing) {
                    ScrollView(.vertical) {
                        TimelineCanvasView(
                            range: range,
                            now: now,
                            blocks: visibleBlocks(in: range),
                            slotMinutes: slotMinutes,
                            pointsPerMinute: pointsPerMinute,
                            laneWidth: laneWidth,
                            warnings: warnings,
                            currentBlockID: currentBlockID,
                            nextBlockID: nextBlockID,
                            showsHeader: showsHeader,
                            calendar: calendar,
                            dragState: dragState,
                            timelineDraft: timelineDraft,
                            onDropSomedayItem: { itemID, date in
                                let didHandle = onDropSomedayItem?(itemID, roundedDate(date, stepMinutes: slotMinutes)) ?? false
                                if didHandle == false {
                                    showInvalidDropMessage("Couldn’t place this Someday item.")
                                }
                                return didHandle
                            },
                            onDragChanged: { block, proposedStart in
                                handleDragChanged(for: block, proposedStart: proposedStart, in: range)
                            },
                            onDragEnded: { block in
                                handleDragEnded(for: block)
                            },
                            onAdjustDuration: { block, deltaMinutes in
                                handleAdjustDuration(for: block, deltaMinutes: deltaMinutes)
                            },
                            onQuickAction: { block, action in
                                handleQuickAction(for: block, action: action)
                            },
                            onTimelineDraftMoved: { proposedStart in
                                onTimelineDraftMoved?(roundedDate(proposedStart, stepMinutes: slotMinutes))
                            }
                        )
                    }
                    .scrollIndicators(.hidden)
                    .defaultScrollAnchor(.center)
                    .scrollPosition(id: $scrollAnchorDate, anchor: .center)
                    .background(PlannerBackground(simple: false))

                    if let invalidDropMessage {
                        TimelineDropMessageView(message: invalidDropMessage)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .padding(.top, 10)
                            .padding(.horizontal, 12)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    if shouldShowBackToNow(for: now) {
                        Button("Back to Now", systemImage: "scope") {
                            jumpToNow(using: now)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 12)
                        .padding(.trailing, 12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .accessibilityHint("Centers the timeline around the current time")
                    }
                }
                .overlay(alignment: .center) {
                    TimelineCenterNowLine(date: scrollAnchorDate ?? now)
                }
                .onAppear {
                    jumpToNow(using: now)
                }
                .onChange(of: day) { _, _ in
                    dragState = nil
                    jumpToNow(using: now)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: snapFeedbackToken)
        .sensoryFeedback(.error, trigger: invalidDropFeedbackToken)
    }

    private func timelineRange(reference: Date) -> ClosedRange<Date> {
        let referenceDayStart = calendar.startOfDay(for: reference)
        let start = calendar.date(byAdding: .day, value: -visibleDayRange, to: referenceDayStart) ?? referenceDayStart
        let end = calendar.date(byAdding: .day, value: visibleDayRange + 1, to: referenceDayStart) ?? referenceDayStart
        return start...end
    }

    private func visibleBlocks(in range: ClosedRange<Date>) -> [PlannedBlock] {
        blocks.filter { block in
            block.end > range.lowerBound && block.start < range.upperBound
        }
    }

    private func shouldShowBackToNow(for now: Date) -> Bool {
        guard let anchor = scrollAnchorDate else { return false }
        return abs(anchor.timeIntervalSince(roundedDate(now, stepMinutes: slotMinutes))) > (20 * 60)
    }

    private func jumpToNow(using now: Date) {
        let target = roundedDate(now, stepMinutes: slotMinutes)

        if reduceMotion {
            scrollAnchorDate = target
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                scrollAnchorDate = target
            }
        }
    }

    private func handleDragChanged(
        for block: PlannedBlock,
        proposedStart: Date,
        in range: ClosedRange<Date>
    ) {
        guard isDraggable(block) else { return }

        let latestStart = range.upperBound.addingTimeInterval(-block.end.timeIntervalSince(block.start))
        let bounded = min(max(proposedStart, range.lowerBound), latestStart)
        let snapped = roundedDate(bounded, stepMinutes: slotMinutes)

        let conflict = fixedConflict(for: block, proposedStart: snapped)

        if dragState?.blockID != block.id {
            dragState = TimelineDragState(
                blockID: block.id,
                originalStart: block.start,
                proposedStart: snapped,
                conflictingBlockTitle: conflict?.title
            )
            snapFeedbackToken += 1
            return
        }

        if dragState?.proposedStart != snapped {
            dragState?.proposedStart = snapped
            snapFeedbackToken += 1
        }

        dragState?.conflictingBlockTitle = conflict?.title
    }

    private func handleDragEnded(for block: PlannedBlock) {
        guard let dragState, dragState.blockID == block.id else { return }

        if let conflictingBlockTitle = dragState.conflictingBlockTitle {
            invalidDropFeedbackToken += 1
            let message = "Can’t place over \(conflictingBlockTitle)."
            showInvalidDropMessage(message)
            self.dragState = nil
            return
        }

        invalidDropMessage = nil

        if dragState.proposedStart != dragState.originalStart {
            onRescheduleBlock?(block, dragState.proposedStart)
        }

        self.dragState = nil
    }

    private func handleAdjustDuration(for block: PlannedBlock, deltaMinutes: Int) {
        guard isDraggable(block) else { return }
        guard deltaMinutes != 0 else { return }
        onAdjustBlockDuration?(block, deltaMinutes)
    }

    private func handleQuickAction(for block: PlannedBlock, action: TimelineQuickAction) {
        guard block.source == .local else { return }
        onQuickAction?(block, action)
    }

    private func isDraggable(_ block: PlannedBlock) -> Bool {
        block.source == .local && block.isProtected == false && block.isCompleted == false
    }

    private func fixedConflict(for movingBlock: PlannedBlock, proposedStart: Date) -> PlannedBlock? {
        let proposedEnd = proposedStart.addingTimeInterval(movingBlock.end.timeIntervalSince(movingBlock.start))

        return blocks.first { block in
            guard block.id != movingBlock.id else { return false }
            guard block.isAllDay == false else { return false }
            let fixed = block.isProtected || block.source == .calendar || block.flexibility == .locked
            guard fixed else { return false }
            return proposedStart < block.end && proposedEnd > block.start
        }
    }

    private func showInvalidDropMessage(_ message: String) {
        if reduceMotion {
            invalidDropMessage = message
        } else {
            withAnimation(.easeOut(duration: 0.2)) {
                invalidDropMessage = message
            }
        }

        Task {
            try? await Task.sleep(for: .seconds(2.2))
            guard invalidDropMessage == message else { return }

            if reduceMotion {
                invalidDropMessage = nil
            } else {
                withAnimation(.easeOut(duration: 0.25)) {
                    invalidDropMessage = nil
                }
            }
        }
    }

    private func roundedDate(_ date: Date, stepMinutes: Int) -> Date {
        let minute = calendar.component(.minute, from: date)
        let snappedMinute = ((minute + (stepMinutes / 2)) / stepMinutes) * stepMinutes
        var normalized = calendar.date(bySetting: .minute, value: snappedMinute % 60, of: date) ?? date
        normalized = calendar.date(bySetting: .second, value: 0, of: normalized) ?? normalized

        if snappedMinute >= 60 {
            return calendar.date(byAdding: .hour, value: 1, to: normalized) ?? normalized
        }

        return normalized
    }
}

private struct TimelineCanvasView: View {
    let range: ClosedRange<Date>
    let now: Date
    let blocks: [PlannedBlock]
    let slotMinutes: Int
    let pointsPerMinute: CGFloat
    let laneWidth: CGFloat
    let warnings: [GuardrailWarning]
    let currentBlockID: UUID?
    let nextBlockID: UUID?
    let showsHeader: Bool
    let calendar: Calendar
    let dragState: TimelineDragState?
    let timelineDraft: TimelineDraftTask?
    let onDropSomedayItem: (UUID, Date) -> Bool
    let onDragChanged: (PlannedBlock, Date) -> Void
    let onDragEnded: (PlannedBlock) -> Void
    let onAdjustDuration: (PlannedBlock, Int) -> Void
    let onQuickAction: (PlannedBlock, TimelineQuickAction) -> Void
    let onTimelineDraftMoved: (Date) -> Void

    private var slots: [Date] {
        strideDates(from: range.lowerBound, through: range.upperBound, everyMinutes: slotMinutes)
    }

    private var allDayBlocks: [PlannedBlock] {
        blocks.filter { $0.source == .calendar && $0.isAllDay }
    }

    private var timedBlocks: [PlannedBlock] {
        blocks.filter { !($0.source == .calendar && $0.isAllDay) }
    }

    private var totalHeight: CGFloat {
        CGFloat(slots.count) * slotHeight
    }

    private var slotHeight: CGFloat {
        CGFloat(slotMinutes) * pointsPerMinute
    }

    private var gapItems: [TimelineGapItem] {
        let sortedBlocks = timedBlocks.sorted { $0.start < $1.start }
        guard sortedBlocks.count > 1 else { return [] }

        let defaultTips = [
            "Hydration break",
            "Transition gently",
            "Small reset",
            "Review next step"
        ]

        var tipIndex = 0
        var warningIndex = 0
        var items: [TimelineGapItem] = []

        for pair in zip(sortedBlocks, sortedBlocks.dropFirst()) {
            let gapMinutes = Int(pair.1.start.timeIntervalSince(pair.0.end) / 60)
            guard gapMinutes >= 35 else { continue }

            let center = pair.0.end.addingTimeInterval(pair.1.start.timeIntervalSince(pair.0.end) / 2)

            if warningIndex < warnings.count {
                let warning = warnings[warningIndex]
                warningIndex += 1
                items.append(
                    TimelineGapItem(
                        date: center,
                        title: warning.message,
                        detail: warning.detail,
                        isWarning: true
                    )
                )
            } else {
                let tip = defaultTips[tipIndex % defaultTips.count]
                tipIndex += 1
                items.append(
                    TimelineGapItem(
                        date: center,
                        title: tip,
                        detail: "This open space can lower pressure before the next block.",
                        isWarning: false
                    )
                )
            }
        }

        return items
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                if showsHeader {
                    TimelineLegendView(now: now)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }

                ForEach(slots, id: \.self) { slot in
                    let style = TimelineGridStyle.make(for: slot, calendar: calendar)
                    TimelineTickRow(
                        style: style,
                        slotHeight: slotHeight
                    )
                    .id(slot)
                }
            }
            .scrollTargetLayout()

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: showsHeader ? 52 : 0)

                ZStack(alignment: .topLeading) {
                    ForEach(allDayBlocks) { block in
                        TimelineAllDayBackgroundBand(block: block, width: laneWidth)
                            .offset(x: 96, y: yOffset(for: block.start))
                            .frame(height: height(for: block), alignment: .top)
                    }

                    ForEach(gapItems) { gap in
                        TimelineGapCard(item: gap)
                            .offset(x: 96, y: yOffset(for: gap.date))
                    }

                    ForEach(timedBlocks) { block in
                        blockLayer(for: block)
                    }

                    if let timelineDraft {
                        TimelineDraftGhostCapsule(
                            draft: timelineDraft,
                            width: laneWidth,
                            pointsPerMinute: pointsPerMinute,
                            onMoveByMinutes: { deltaMinutes in
                                let proposed = timelineDraft.startDate.addingTimeInterval(TimeInterval(deltaMinutes * 60))
                                onTimelineDraftMoved(snappedDate(proposed))
                            }
                        )
                        .offset(x: 96, y: yOffset(for: timelineDraft.startDate))
                        .frame(height: 66, alignment: .top)
                    }

                    if let dragState, let block = timedBlocks.first(where: { $0.id == dragState.blockID }) {
                        TimelineDragTimeLabel(
                            date: dragState.proposedStart,
                            conflictTitle: dragState.conflictingBlockTitle
                        )
                        .offset(x: 96, y: yOffset(for: dragState.proposedStart) - 26)

                        TimelineDragGhostCapsule(
                            width: laneWidth,
                            height: max(height(for: block), 44),
                            isInvalid: dragState.conflictingBlockTitle != nil
                        )
                        .offset(x: 96, y: yOffset(for: dragState.proposedStart))
                    }
                }
            }
            .frame(height: totalHeight + (showsHeader ? 52 : 0), alignment: .top)
        }
        .frame(maxWidth: .infinity, minHeight: totalHeight + (showsHeader ? 52 : 0), alignment: .top)
        .dropDestination(for: String.self) { droppedIDs, location in
            guard let rawID = droppedIDs.first, let itemID = UUID(uuidString: rawID) else {
                return false
            }

            return onDropSomedayItem(itemID, date(at: location))
        }
    }

    @ViewBuilder
    private func blockLayer(for block: PlannedBlock) -> some View {
        let isDraggingBlock = dragState?.blockID == block.id

        if isDraggingBlock {
            TimelineTaskCapsule(
                block: block,
                now: now,
                width: laneWidth,
                pointsPerMinute: pointsPerMinute,
                isCurrent: block.id == currentBlockID,
                isNext: block.id == nextBlockID,
                draggable: true,
                height: max(height(for: block), 44),
                onDragChanged: { proposed in
                    onDragChanged(block, proposed)
                },
                onDragEnded: {
                    onDragEnded(block)
                },
                onResizeEnded: { deltaMinutes in
                    onAdjustDuration(block, deltaMinutes)
                },
                onQuickAction: { action in
                    onQuickAction(block, action)
                }
            )
            .opacity(0.35)
            .offset(x: 96, y: yOffset(for: block.start))
        } else {
            TimelineTaskCapsule(
                block: block,
                now: now,
                width: laneWidth,
                pointsPerMinute: pointsPerMinute,
                isCurrent: block.id == currentBlockID,
                isNext: block.id == nextBlockID,
                draggable: block.source == .local && block.isProtected == false && block.isCompleted == false,
                height: max(height(for: block), 44),
                onDragChanged: { proposed in
                    onDragChanged(block, proposed)
                },
                onDragEnded: {
                    onDragEnded(block)
                },
                onResizeEnded: { deltaMinutes in
                    onAdjustDuration(block, deltaMinutes)
                },
                onQuickAction: { action in
                    onQuickAction(block, action)
                }
            )
            .offset(x: 96, y: yOffset(for: block.start))
        }
    }

    private func height(for block: PlannedBlock) -> CGFloat {
        CGFloat(max(block.durationMinutes, slotMinutes)) * pointsPerMinute
    }

    private func yOffset(for date: Date) -> CGFloat {
        let clampedDate = min(max(date, range.lowerBound), range.upperBound)
        let minutes = clampedDate.timeIntervalSince(range.lowerBound) / 60
        return CGFloat(minutes) * pointsPerMinute
    }

    private func date(at location: CGPoint) -> Date {
        let y = max(location.y - (showsHeader ? 52 : 0), 0)
        let minutes = Double(y / pointsPerMinute)
        let raw = range.lowerBound.addingTimeInterval(minutes * 60)
        return snappedDate(raw)
    }

    private func snappedDate(_ date: Date) -> Date {
        let raw = min(max(date, range.lowerBound), range.upperBound)
        let snappedMinute = (calendar.component(.minute, from: raw) / slotMinutes) * slotMinutes
        var snapped = calendar.date(bySetting: .minute, value: snappedMinute, of: raw) ?? raw
        snapped = calendar.date(bySetting: .second, value: 0, of: snapped) ?? snapped
        return snapped
    }

    private func strideDates(from start: Date, through end: Date, everyMinutes step: Int) -> [Date] {
        var dates: [Date] = []
        var current = start

        while current <= end {
            dates.append(current)
            current = current.addingTimeInterval(TimeInterval(step * 60))
        }

        return dates
    }
}

private struct TimelineLegendView: View {
    let now: Date

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Timeline")
                    .font(.headline)
                Text(now.formatted(.dateTime.weekday(.wide).day().month().hour().minute()))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Now centered")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct TimelineTickRow: View {
    let style: TimelineGridStyle
    let slotHeight: CGFloat

    var body: some View {
        HStack(spacing: 10) {
            Text(style.label)
                .font(labelFont)
                .foregroundStyle(labelColor)
                .frame(width: 72, alignment: .trailing)

            Rectangle()
                .fill(lineColor.opacity(style.lineOpacity))
                .frame(height: style.lineThickness)

            Spacer(minLength: 0)
        }
        .frame(height: slotHeight)
        .accessibilityHidden(true)
    }

    private var labelFont: Font {
        switch style.tier {
        case .month, .day:
            .caption.bold()
        case .hour:
            .caption
        case .quarterHour, .minor:
            .caption2
        }
    }

    private var labelColor: Color {
        switch style.tier {
        case .month, .day:
            .indigo
        case .hour:
            .primary
        case .quarterHour:
            .blue
        case .minor:
            .secondary
        }
    }

    private var lineColor: Color {
        switch style.tier {
        case .month:
            .teal
        case .day:
            .indigo
        case .hour:
            .primary
        case .quarterHour:
            .blue
        case .minor:
            .secondary
        }
    }
}

private struct TimelineTaskCapsule: View {
    let block: PlannedBlock
    let now: Date
    let width: CGFloat
    let pointsPerMinute: CGFloat
    let isCurrent: Bool
    let isNext: Bool
    let draggable: Bool
    let height: CGFloat
    let onDragChanged: (Date) -> Void
    let onDragEnded: () -> Void
    let onResizeEnded: (Int) -> Void
    let onQuickAction: (TimelineQuickAction) -> Void

    @State private var resizeDeltaMinutes = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                PlannerIcon(symbolName: block.symbolName, tintToken: block.tintToken, compact: true)

                Text(shortTitle)
                    .font(.subheadline)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isCurrent {
                    TimelineTag(text: "Now", tint: .red)
                } else if isNext {
                    TimelineTag(text: "Next", tint: .blue)
                }

                if block.source == .local {
                    HStack(spacing: 4) {
                        if block.isCompleted {
                            Button {
                                onQuickAction(.markUndone)
                            } label: {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                    .font(.caption)
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.plain)
                            .contentShape(.rect)
                            .accessibilityIdentifier("timeline-task-undo-\(block.title.testingIdentifier)")
                        } else {
                            Button {
                                onQuickAction(.startNow)
                            } label: {
                                Image(systemName: "play.circle.fill")
                                    .font(.caption)
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.plain)
                            .contentShape(.rect)
                            .accessibilityIdentifier("timeline-task-start-\(block.title.testingIdentifier)")

                            Button {
                                onQuickAction(.markDone)
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.plain)
                            .contentShape(.rect)
                            .accessibilityIdentifier("timeline-task-done-\(block.title.testingIdentifier)")
                        }
                    }
                    .foregroundStyle(.secondary)
                } else {
                    Image(systemName: statusSymbol)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                }
            }

            if draggable {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.and.down")
                        .font(.caption2)
                    Capsule()
                        .fill(.secondary.opacity(0.35))
                        .frame(width: 64, height: 8)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.5), in: Capsule())
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityLabel("Resize task duration")
                .gesture(resizeGesture)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: width, height: max(effectiveHeight, 44), alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(borderColor, lineWidth: isCurrent ? 2 : 1)
        )
        .contentShape(.rect)
        .highPriorityGesture(dragGesture)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("timeline-task-\(block.title.testingIdentifier)")
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard draggable else { return }
                let deltaMinutes = value.translation.height / pointsPerMinute
                let proposed = block.start.addingTimeInterval(TimeInterval(deltaMinutes * 60))
                onDragChanged(proposed)
            }
            .onEnded { _ in
                guard draggable else { return }
                onDragEnded()
            }
    }

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard draggable else { return }
                let rawDelta = Int((-value.translation.height / pointsPerMinute).rounded())
                resizeDeltaMinutes = nearestStep(rawDelta, step: 5)
            }
            .onEnded { _ in
                guard draggable else { return }
                let delta = resizeDeltaMinutes
                resizeDeltaMinutes = 0
                onResizeEnded(delta)
            }
    }

    private var effectiveHeight: CGFloat {
        height + CGFloat(resizeDeltaMinutes) * pointsPerMinute
    }

    private var shortTitle: String {
        String(block.title.prefix(18))
    }

    private func nearestStep(_ minutes: Int, step: Int) -> Int {
        guard step > 1 else { return minutes }
        return Int((Double(minutes) / Double(step)).rounded()) * step
    }

    private var statusSymbol: String {
        if block.isCompleted {
            return "checkmark.circle.fill"
        }

        if now > block.end {
            return "exclamationmark.circle"
        }

        if now >= block.start && now <= block.end {
            return "play.circle.fill"
        }

        return draggable ? "arrow.up.and.down.circle" : "circle"
    }

    private var borderColor: Color {
        if isCurrent {
            return .red.opacity(0.85)
        }

        if isNext {
            return .blue.opacity(0.65)
        }

        if block.isCompleted {
            return .green.opacity(0.5)
        }

        if now > block.end {
            return .red.opacity(0.5)
        }

        if draggable {
            return .black.opacity(0.2)
        }

        return .black.opacity(0.12)
    }

}

private struct TimelineGapCard: View {
    let item: TimelineGapItem

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: item.isWarning ? "exclamationmark.triangle.fill" : "sparkles")
                .font(.caption)
                .foregroundStyle(item.isWarning ? .orange : .mint)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.caption.bold())
                Text(item.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(8)
        .frame(width: 220, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill((item.isWarning ? Color.orange : .mint).opacity(0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder((item.isWarning ? Color.orange : .mint).opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.title)
        .accessibilityValue(item.detail)
    }
}

private struct TimelineTag: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint)
    }
}

private struct TimelineCenterNowLine: View {
    let date: Date

    var body: some View {
        HStack(spacing: 8) {
            Text(date.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.red.opacity(0.35), lineWidth: 1)
                )
                .frame(width: 84, alignment: .trailing)

            Rectangle()
                .fill(Color.red.opacity(0.6))
                .frame(height: 1.5)
        }
        .padding(.horizontal, 8)
        .allowsHitTesting(false)
        .accessibilityLabel("Timeline center")
        .accessibilityValue(date.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
    }
}

private struct TimelineDropMessageView: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
            Text(message)
                .font(.footnote)
                .lineLimit(2)
                .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.red.opacity(0.85),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

private struct TimelineDragGhostCapsule: View {
    let width: CGFloat
    let height: CGFloat
    let isInvalid: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
            .foregroundStyle((isInvalid ? Color.red : .primary).opacity(0.5))
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill((isInvalid ? Color.red : .white).opacity(0.22))
            )
            .allowsHitTesting(false)
    }
}

private struct TimelineDraftGhostCapsule: View {
    let draft: TimelineDraftTask
    let width: CGFloat
    let pointsPerMinute: CGFloat
    let onMoveByMinutes: (Int) -> Void

    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        HStack(spacing: 8) {
            PlannerIcon(symbolName: draft.symbolName, tintToken: draft.tintToken, compact: true)
            Text(draft.title)
                .font(.subheadline)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: width, height: 64, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.blue.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [6, 4]))
                .foregroundStyle(Color.blue.opacity(0.7))
        )
        .offset(y: dragOffset.height)
        .gesture(
            DragGesture(minimumDistance: 2)
                .updating($dragOffset) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    let deltaMinutes = Int((value.translation.height / pointsPerMinute).rounded())
                    onMoveByMinutes(deltaMinutes)
                }
        )
        .accessibilityIdentifier("timeline-draft-ghost")
    }
}

private struct TimelineAllDayBackgroundBand: View {
    let block: PlannedBlock
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: block.symbolName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(block.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(width: width, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tintColor(token: block.tintToken).opacity(0.13))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tintColor(token: block.tintToken).opacity(0.2), lineWidth: 1)
        )
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("All day event")
        .accessibilityValue(block.title)
    }
}

private struct TimelineDragTimeLabel: View {
    let date: Date
    let conflictTitle: String?

    var body: some View {
        Text(labelText)
            .font(.caption.bold())
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.9), in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder((conflictTitle == nil ? Color.primary : .red).opacity(0.2), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }

    private var labelText: String {
        guard let conflictTitle else {
            return date.formatted(.dateTime.hour().minute())
        }

        return "Conflict: \(conflictTitle)"
    }
}

private struct TimelineDragState {
    let blockID: UUID
    let originalStart: Date
    var proposedStart: Date
    var conflictingBlockTitle: String?
}
private struct TimelineGapItem: Identifiable {
    let id = UUID()
    let date: Date
    let title: String
    let detail: String
    let isWarning: Bool
}
