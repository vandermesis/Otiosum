import SwiftUI

struct TimeWheelView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let day: Date
    let blocks: [PlannedBlock]
    let showsHeader: Bool
    let onRescheduleBlock: ((PlannedBlock, Date) -> Void)?

    @State private var scrollAnchorDate: Date?
    @State private var dragState: TimelineDragState?
    @State private var snapFeedbackToken = 0
    @State private var invalidDropFeedbackToken = 0
    @State private var invalidDropMessage: String?

    private let calendar = Calendar.current
    private let slotMinutes = 5
    private let pointsPerMinute: CGFloat = 2.2
    private let visibleHourRange: Double = 12

    init(
        day: Date = .now,
        blocks: [PlannedBlock] = [],
        showsHeader: Bool = true,
        onRescheduleBlock: ((PlannedBlock, Date) -> Void)? = nil
    ) {
        self.day = day
        self.blocks = blocks
        self.showsHeader = showsHeader
        self.onRescheduleBlock = onRescheduleBlock
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            let range = timelineRange(for: day)

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
                            showsHeader: showsHeader,
                            calendar: calendar,
                            dragState: dragState,
                            onDragChanged: { block, proposedStart in
                                handleDragChanged(for: block, proposedStart: proposedStart, in: range)
                            },
                            onDragEnded: { block in
                                handleDragEnded(for: block)
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
                        .padding(16)
                        .accessibilityHint("Centers the timeline around the current time")
                    }
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

    private func timelineRange(for date: Date) -> ClosedRange<Date> {
        let dayStart = calendar.startOfDay(for: date)
        let start = dayStart.addingTimeInterval(-visibleHourRange * 60 * 60)
        let end = dayStart.addingTimeInterval((24 + visibleHourRange) * 60 * 60)
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

    private func isDraggable(_ block: PlannedBlock) -> Bool {
        block.source == .local && block.isProtected == false && block.isCompleted == false
    }

    private func fixedConflict(for movingBlock: PlannedBlock, proposedStart: Date) -> PlannedBlock? {
        let proposedEnd = proposedStart.addingTimeInterval(movingBlock.end.timeIntervalSince(movingBlock.start))

        return blocks.first { block in
            guard block.id != movingBlock.id else { return false }
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
    let showsHeader: Bool
    let calendar: Calendar
    let dragState: TimelineDragState?
    let onDragChanged: (PlannedBlock, Date) -> Void
    let onDragEnded: (PlannedBlock) -> Void

    private var slots: [Date] {
        strideDates(from: range.lowerBound, through: range.upperBound, everyMinutes: slotMinutes)
    }

    private var totalHeight: CGFloat {
        CGFloat(slots.count) * slotHeight
    }

    private var slotHeight: CGFloat {
        CGFloat(slotMinutes) * pointsPerMinute
    }

    private var nowOffset: CGFloat {
        yOffset(for: now)
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
                    TimelineTickRow(
                        date: slot,
                        isMajor: calendar.component(.minute, from: slot) == 0,
                        isQuarterHour: calendar.component(.minute, from: slot).isMultiple(of: 15),
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
                    ForEach(blocks) { block in
                        blockLayer(for: block)
                    }

                    TimelineNowMarker()
                        .offset(x: 84, y: nowOffset)

                    if let dragState, let block = blocks.first(where: { $0.id == dragState.blockID }) {
                        TimelineDragTimeLabel(
                            date: dragState.proposedStart,
                            conflictTitle: dragState.conflictingBlockTitle
                        )
                        .offset(x: 96, y: yOffset(for: dragState.proposedStart) - 26)

                        TimelineDragGhostCapsule(
                            width: laneWidth,
                            isInvalid: dragState.conflictingBlockTitle != nil
                        )
                        .offset(x: 96, y: yOffset(for: dragState.proposedStart))
                        .frame(height: max(height(for: block), 44), alignment: .top)
                    }
                }
            }
            .frame(height: totalHeight + (showsHeader ? 52 : 0), alignment: .top)
        }
        .frame(maxWidth: .infinity, minHeight: totalHeight + (showsHeader ? 52 : 0), alignment: .top)
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
                draggable: true,
                onDragChanged: { proposed in
                    onDragChanged(block, proposed)
                },
                onDragEnded: {
                    onDragEnded(block)
                }
            )
            .opacity(0.35)
            .offset(x: 96, y: yOffset(for: block.start))
            .frame(height: max(height(for: block), 44), alignment: .top)
        } else {
            TimelineTaskCapsule(
                block: block,
                now: now,
                width: laneWidth,
                pointsPerMinute: pointsPerMinute,
                draggable: block.source == .local && block.isProtected == false && block.isCompleted == false,
                onDragChanged: { proposed in
                    onDragChanged(block, proposed)
                },
                onDragEnded: {
                    onDragEnded(block)
                }
            )
            .offset(x: 96, y: yOffset(for: block.start))
            .frame(height: max(height(for: block), 44), alignment: .top)
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
    let date: Date
    let isMajor: Bool
    let isQuarterHour: Bool
    let slotHeight: CGFloat

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(isMajor ? .caption.bold() : .caption2)
                .foregroundStyle(isMajor ? .primary : .secondary)
                .frame(width: 72, alignment: .trailing)

            Rectangle()
                .fill(lineColor)
                .frame(height: isMajor ? 1 : 0.5)

            Spacer(minLength: 0)
        }
        .frame(height: slotHeight)
        .accessibilityHidden(true)
    }

    private var lineColor: Color {
        if isMajor {
            return .primary.opacity(0.25)
        }

        if isQuarterHour {
            return .primary.opacity(0.13)
        }

        return .primary.opacity(0.08)
    }

    private var label: String {
        if isMajor {
            return date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
        }

        if isQuarterHour {
            return date.formatted(.dateTime.minute(.twoDigits))
        }

        return ""
    }
}

private struct TimelineTaskCapsule: View {
    let block: PlannedBlock
    let now: Date
    let width: CGFloat
    let pointsPerMinute: CGFloat
    let draggable: Bool
    let onDragChanged: (Date) -> Void
    let onDragEnded: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            PlannerIcon(symbolName: block.symbolName, tintToken: block.tintToken, compact: true)

            Text(shortTitle)
                .font(.subheadline)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: statusSymbol)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .frame(width: width, height: 44, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .contentShape(.rect)
        .gesture(dragGesture)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(draggable ? "Drag up or down to move this task" : "Fixed task")
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

    private var shortTitle: String {
        String(block.title.prefix(18))
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

    private var accessibilityLabel: String {
        block.title
    }

    private var accessibilityValue: String {
        let span = "\(block.start.formatted(.dateTime.hour().minute())) to \(block.end.formatted(.dateTime.hour().minute()))"

        if block.isCompleted {
            return "\(span), completed"
        }

        if now > block.end {
            return "\(span), overdue"
        }

        if now >= block.start && now <= block.end {
            return "\(span), active"
        }

        return "\(span), upcoming"
    }
}

private struct TimelineNowMarker: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)

            Rectangle()
                .fill(Color.red.opacity(0.6))
                .frame(height: 1.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("Current time")
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
    let isInvalid: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
            .foregroundStyle((isInvalid ? Color.red : .primary).opacity(0.5))
            .frame(width: width, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill((isInvalid ? Color.red : .white).opacity(0.22))
            )
            .allowsHitTesting(false)
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
