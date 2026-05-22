import SwiftUI
import UIKit

private enum TimelineLayoutMetrics {
    static let labelColumnWidth: CGFloat = 54
    static let laneLeadingInset: CGFloat = 60
    static let laneTrailingInset: CGFloat = 10
    static let scaleToLaneSpacing: CGFloat = 1
    static let readHeadWidth: CGFloat = 170
    static let readHeadLeadingInset: CGFloat = 4
    static let gapCardHeight: CGFloat = 62
    static let gapCardVerticalPadding: CGFloat = 8
}

private struct TimelineViewportContentKey: Equatable {
    let rangeLowerBound: Date
    let rangeUpperBound: Date
    let now: Date
    let blockStates: [TimelineViewportBlockState]
    let dragBlockID: UUID?
    let laneWidth: CGFloat
}

private struct TimelineViewportBlockState: Equatable {
    let id: UUID
    let title: String
    let start: Date
    let end: Date
    let isCompleted: Bool
    let isStarted: Bool
}

private struct TimelineJumpRequest: Equatable {
    let id: Int
    let date: Date
}

struct TimeWheelView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let day: Date
    let blocks: [PlannedBlock]
    let warnings: [GuardrailWarning]
    let currentBlockID: UUID?
    let nextBlockID: UUID?
    let showsHeader: Bool
    let onDropLaterItem: ((UUID, Date) -> Bool)?
    let onRescheduleBlock: ((PlannedBlock, Date) -> Void)?
    let onAdjustBlockDuration: ((PlannedBlock, Int) -> Void)?
    let onQuickAction: ((PlannedBlock, TimelineQuickAction) -> Void)?
    let onCenterDateChanged: ((Date) -> Void)?

    @State private var currentCenterDate: Date?
    @State private var rangeReferenceDate: Date?
    @State private var lastReportedCenterDate: Date?
    @State private var pendingNowJumpRequest: TimelineJumpRequest?
    @State private var nextJumpRequestID = 0
    @State private var dragState: TimelineDragState?
    @State private var snapFeedbackToken = 0
    @State private var invalidDropFeedbackToken = 0
    @State private var invalidDropMessage: String?

    private let calendar = Calendar.current
    private let scrollCoordinator = TimelineScrollCoordinator()
    private let slotMinutes = 5
    private let centerReportMinutes = 30
    private let pointsPerMinute: CGFloat = 2.2
    private let headerHeight: CGFloat = 52
    // Keep the timeline window finite so SwiftUI doesn't build hundreds of thousands of rows.
    private let visibleDayRange: Int = 3

    init(
        day: Date = .now,
        blocks: [PlannedBlock] = [],
        warnings: [GuardrailWarning] = [],
        currentBlockID: UUID? = nil,
        nextBlockID: UUID? = nil,
        showsHeader: Bool = true,
        onDropLaterItem: ((UUID, Date) -> Bool)? = nil,
        onRescheduleBlock: ((PlannedBlock, Date) -> Void)? = nil,
        onAdjustBlockDuration: ((PlannedBlock, Int) -> Void)? = nil,
        onQuickAction: ((PlannedBlock, TimelineQuickAction) -> Void)? = nil,
        onCenterDateChanged: ((Date) -> Void)? = nil
    ) {
        self.day = day
        self.blocks = blocks
        self.warnings = warnings
        self.currentBlockID = currentBlockID
        self.nextBlockID = nextBlockID
        self.showsHeader = showsHeader
        self.onDropLaterItem = onDropLaterItem
        self.onRescheduleBlock = onRescheduleBlock
        self.onAdjustBlockDuration = onAdjustBlockDuration
        self.onQuickAction = onQuickAction
        self.onCenterDateChanged = onCenterDateChanged
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            let rangeReference = rangeReferenceDate ?? day
            let range = scrollCoordinator.timelineRange(reference: rangeReference, visibleDayRange: visibleDayRange)

            GeometryReader { proxy in
                let laneWidth = max(
                    proxy.size.width - TimelineLayoutMetrics.laneLeadingInset - TimelineLayoutMetrics.laneTrailingInset,
                    180
                )
                let roundedNow = roundedDate(now, stepMinutes: slotMinutes)
                let contentKey = TimelineViewportContentKey(
                    rangeLowerBound: range.lowerBound,
                    rangeUpperBound: range.upperBound,
                    now: roundedNow,
                    blockStates: visibleBlocks(in: range).map { block in
                        TimelineViewportBlockState(
                            id: block.id,
                            title: block.title,
                            start: block.start,
                            end: block.end,
                            isCompleted: block.isCompleted,
                            isStarted: block.isStarted
                        )
                    },
                    dragBlockID: dragState?.blockID,
                    laneWidth: laneWidth
                )

                ZStack(alignment: .bottomTrailing) {
                    TimelineScrollViewport(
                        range: range,
                        scrollCoordinator: scrollCoordinator,
                        pointsPerMinute: pointsPerMinute,
                        headerHeight: showsHeader ? headerHeight : 0,
                        centerStepMinutes: slotMinutes,
                        centerDate: currentCenterDate ?? roundedNow,
                        pendingJumpRequest: pendingNowJumpRequest,
                        contentKey: contentKey,
                        onCenterDateChanged: { centerDate in
                            currentCenterDate = roundedDate(centerDate, stepMinutes: slotMinutes)
                        },
                        onDisplayDayChanged: { visibleDay in
                            handleVisibleDayChanged(visibleDay, currentRangeReference: rangeReference)
                        },
                        onPendingJumpHandled: {
                            pendingNowJumpRequest = nil
                        },
                        content: {
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
                                onDropLaterItem: { itemID, date in
                                    let didHandle = onDropLaterItem?(itemID, roundedDate(date, stepMinutes: slotMinutes)) ?? false
                                    if didHandle == false {
                                        showInvalidDropMessage("Couldn’t place this Later item.")
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
                                }
                            )
                        }
                    )
                    .background(PlannerBackground(simple: false))

                    if let invalidDropMessage {
                        TimelineDropMessageView(message: invalidDropMessage)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .padding(.top, 10)
                            .padding(.horizontal, 12)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .overlay(alignment: .center) {
                    TimelineCenterNowLine(
                        date: currentCenterDate ?? now
                    )
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .trailing) {
                    if shouldShowBackToNow(for: now) {
                        Button("Back to Now", systemImage: "arrow.clockwise") {
                            requestJumpToNow(using: now)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .padding(.trailing, 12)
                        .accessibilityHint("Centers the timeline around the current time")
                    }
                }
                .onAppear {
                    requestJumpToNow(using: now)
                }
                .onChange(of: day) { _, _ in
                    dragState = nil
                    currentCenterDate = nil
                    rangeReferenceDate = day
                    lastReportedCenterDate = nil
                    requestJumpToNow(using: now)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: snapFeedbackToken)
        .sensoryFeedback(.error, trigger: invalidDropFeedbackToken)
    }

    private func visibleBlocks(in range: ClosedRange<Date>) -> [PlannedBlock] {
        blocks.filter { block in
            block.end > range.lowerBound && block.start < range.upperBound
        }
    }

    private func centeredAllDayTitles(for date: Date) -> [String] {
        let dayStart = calendar.startOfDay(for: date)
        let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        return blocks
            .filter { block in
                block.source == .calendar && block.isAllDay && block.end > dayStart && block.start < nextDayStart
            }
            .map(\.title)
            .reduce(into: [String]()) { titles, title in
                if titles.contains(title) == false {
                    titles.append(title)
                }
            }
    }

    private func shouldShowBackToNow(for now: Date) -> Bool {
        guard let anchor = currentCenterDate else { return false }
        return abs(anchor.timeIntervalSince(roundedDate(now, stepMinutes: slotMinutes))) > (20 * 60)
    }

    private func requestJumpToNow(using now: Date) {
        let target = roundedDate(now, stepMinutes: slotMinutes)
        rangeReferenceDate = target
        currentCenterDate = target
        reportCenterDateIfNeeded(target)
        nextJumpRequestID += 1
        pendingNowJumpRequest = TimelineJumpRequest(id: nextJumpRequestID, date: target)
    }

    private func handleVisibleDayChanged(_ visibleDay: Date, currentRangeReference: Date) {
        let displayDay = scrollCoordinator.displayDay(for: visibleDay)

        if scrollCoordinator.shouldRecenterRange(
            currentReference: currentRangeReference,
            candidateCenter: displayDay,
            visibleDayRange: visibleDayRange
        ) {
            rangeReferenceDate = displayDay
        }

        reportCenterDateIfNeeded(displayDay)
    }

    private func reportCenterDateIfNeeded(_ centerDate: Date) {
        guard scrollCoordinator.shouldReportCenterDate(
            lastReported: lastReportedCenterDate,
            candidateCenter: centerDate,
            stepMinutes: centerReportMinutes
        ) else { return }

        let reportDate = scrollCoordinator.reportDate(for: centerDate, stepMinutes: centerReportMinutes)
        lastReportedCenterDate = reportDate
        onCenterDateChanged?(reportDate)
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
        guard block.source == .local || (block.source == .template && action == .startNow) else { return }
        onQuickAction?(block, action)
    }

    private func isDraggable(_ block: PlannedBlock) -> Bool {
        (block.source == .local || block.source == .template) && block.isCompleted == false && block.isStarted == false
    }

    private func fixedConflict(for movingBlock: PlannedBlock, proposedStart: Date) -> PlannedBlock? {
        let proposedEnd = proposedStart.addingTimeInterval(movingBlock.end.timeIntervalSince(movingBlock.start))

        return blocks.first { block in
            guard block.id != movingBlock.id else { return false }
            guard block.isAllDay == false else { return false }
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

private struct TimelineScrollViewport<Content: View>: UIViewControllerRepresentable {
    let range: ClosedRange<Date>
    let scrollCoordinator: TimelineScrollCoordinator
    let pointsPerMinute: CGFloat
    let headerHeight: CGFloat
    let centerStepMinutes: Int
    let centerDate: Date
    let pendingJumpRequest: TimelineJumpRequest?
    let contentKey: TimelineViewportContentKey
    let onCenterDateChanged: (Date) -> Void
    let onDisplayDayChanged: (Date) -> Void
    let onPendingJumpHandled: () -> Void
    @ViewBuilder let content: () -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> TimelineScrollHostingController<Content> {
        let controller = TimelineScrollHostingController(rootView: content())
        controller.scrollView.delegate = context.coordinator
        controller.scrollView.showsVerticalScrollIndicator = false
        controller.scrollView.alwaysBounceVertical = true
        context.coordinator.controller = controller
        context.coordinator.parent = self
        return controller
    }

    func updateUIViewController(_ controller: TimelineScrollHostingController<Content>, context: Context) {
        context.coordinator.parent = self
        let hasPendingJump = pendingJumpRequest != nil
        let preservedCenterDate = context.coordinator.range == range || hasPendingJump
            ? nil
            : context.coordinator.centerDate(for: controller.scrollView)

        if context.coordinator.contentKey != contentKey {
            controller.hostingController.rootView = content()
            controller.hostingController.view.invalidateIntrinsicContentSize()
            controller.view.setNeedsLayout()
            context.coordinator.contentKey = contentKey
        }

        if context.coordinator.range != range {
            context.coordinator.range = range
        }

        if let pendingJumpRequest, context.coordinator.handledJumpRequestID != pendingJumpRequest.id {
            context.coordinator.handledJumpRequestID = pendingJumpRequest.id
            context.coordinator.hasPositionedInitialCenter = true
            context.coordinator.scheduleScroll(to: pendingJumpRequest.date, animated: false, controller: controller) {
                onPendingJumpHandled()
            }
        } else if let preservedCenterDate {
            context.coordinator.scheduleScroll(to: preservedCenterDate, animated: false, controller: controller)
        } else if context.coordinator.hasPositionedInitialCenter == false {
            context.coordinator.hasPositionedInitialCenter = true
            context.coordinator.scheduleScroll(to: centerDate, animated: false, controller: controller)
        }
    }

    static func dismantleUIViewController(_ controller: TimelineScrollHostingController<Content>, coordinator: Coordinator) {
        coordinator.invalidateScheduledScrolls()
        controller.scrollView.delegate = nil
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: TimelineScrollViewport
        weak var controller: TimelineScrollHostingController<Content>?
        var contentKey: TimelineViewportContentKey?
        var range: ClosedRange<Date>?
        var handledJumpRequestID: Int?
        var hasPositionedInitialCenter = false
        private var lastCenterDate: Date?
        private var lastDisplayDay: Date?
        private var isProgrammaticScroll = false
        private var scheduledScrollID = 0

        init(parent: TimelineScrollViewport) {
            self.parent = parent
            self.range = parent.range
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard isProgrammaticScroll == false else { return }
            reportCenterDate(for: scrollView)
        }

        func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
            isProgrammaticScroll = false
            reportCenterDate(for: scrollView)
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            reportCenterDate(for: scrollView)
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if decelerate == false {
                reportCenterDate(for: scrollView)
            }
        }

        func centerDate(for scrollView: UIScrollView) -> Date {
            parent.scrollCoordinator.date(
                atContentOffsetY: Double(scrollView.contentOffset.y),
                in: range ?? parent.range,
                containerHeight: Double(scrollView.bounds.height),
                headerHeight: Double(parent.headerHeight),
                pointsPerMinute: Double(parent.pointsPerMinute)
            )
        }

        func scheduleScroll(
            to date: Date,
            animated: Bool,
            controller: TimelineScrollHostingController<Content>,
            afterScroll: (() -> Void)? = nil
        ) {
            scheduledScrollID += 1
            let requestID = scheduledScrollID

            Task { @MainActor [weak self, weak controller] in
                await Task.yield()
                guard let self, let controller, scheduledScrollID == requestID else { return }

                for _ in 0..<4 {
                    controller.view.layoutIfNeeded()
                    controller.hostingController.view.layoutIfNeeded()

                    let hasScrollableContent = controller.scrollView.bounds.height > 0
                        && controller.scrollView.contentSize.height > controller.scrollView.bounds.height
                    if hasScrollableContent {
                        break
                    }

                    await Task.yield()
                    guard scheduledScrollID == requestID else { return }
                }

                guard scheduledScrollID == requestID else { return }

                scroll(to: date, animated: animated)
                afterScroll?()
            }
        }

        func invalidateScheduledScrolls() {
            scheduledScrollID += 1
        }

        func scroll(to date: Date, animated: Bool) {
            guard let controller else { return }
            let boundedY = parent.scrollCoordinator.boundedContentOffsetY(
                centering: date,
                in: range ?? parent.range,
                containerHeight: Double(controller.scrollView.bounds.height),
                headerHeight: Double(parent.headerHeight),
                pointsPerMinute: Double(parent.pointsPerMinute)
            )
            isProgrammaticScroll = animated
            controller.scrollView.setContentOffset(CGPoint(x: 0, y: boundedY), animated: animated)
            if animated == false {
                isProgrammaticScroll = false
                reportCenterDate(for: controller.scrollView)
            } else {
                Task { @MainActor [weak self, weak scrollView = controller.scrollView] in
                    try? await Task.sleep(for: .milliseconds(350))
                    guard let self, let scrollView else { return }
                    isProgrammaticScroll = false
                    reportCenterDate(for: scrollView)
                }
            }
        }

        private func reportCenterDate(for scrollView: UIScrollView) {
            let centerDate = parent.scrollCoordinator.reportDate(for: centerDate(for: scrollView), stepMinutes: parent.centerStepMinutes)
            let displayDay = parent.scrollCoordinator.displayDay(for: centerDate)

            if lastCenterDate != centerDate {
                lastCenterDate = centerDate
                parent.onCenterDateChanged(centerDate)
            }

            if lastDisplayDay != displayDay {
                lastDisplayDay = displayDay
                parent.onDisplayDayChanged(displayDay)
            }
        }
    }
}

private final class TimelineScrollHostingController<Content: View>: UIViewController {
    let scrollView = UIScrollView()
    let hostingController: UIHostingController<Content>

    init(rootView: Content) {
        self.hostingController = UIHostingController(rootView: rootView)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.accessibilityIdentifier = "timeline-scroll-view"
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        addChild(hostingController)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            hostingController.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostingController.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
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
    let onDropLaterItem: (UUID, Date) -> Bool
    let onDragChanged: (PlannedBlock, Date) -> Void
    let onDragEnded: (PlannedBlock) -> Void
    let onAdjustDuration: (PlannedBlock, Int) -> Void
    let onQuickAction: (PlannedBlock, TimelineQuickAction) -> Void

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
            let gapHeight = CGFloat(gapMinutes) * pointsPerMinute
            guard gapHeight >= TimelineLayoutMetrics.gapCardHeight + (TimelineLayoutMetrics.gapCardVerticalPadding * 2) else {
                continue
            }

            if warningIndex < warnings.count {
                let warning = warnings[warningIndex]
                warningIndex += 1
                items.append(
                    TimelineGapItem(
                        start: pair.0.end,
                        end: pair.1.start,
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
                        start: pair.0.end,
                        end: pair.1.start,
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
            LazyVStack(spacing: 0) {
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
                }
            }

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: showsHeader ? 52 : 0)

                ZStack(alignment: .topLeading) {
                    ForEach(allDayBlocks) { block in
                        TimelineAllDayBackgroundBand(block: block, width: laneWidth)
                            .offset(x: TimelineLayoutMetrics.laneLeadingInset, y: yOffset(for: block.start))
                            .frame(height: height(for: block), alignment: .top)
                    }

                    ForEach(gapItems) { gap in
                        TimelineGapCard(item: gap, width: laneWidth)
                            .frame(height: TimelineLayoutMetrics.gapCardHeight)
                            .offset(x: TimelineLayoutMetrics.laneLeadingInset, y: gapYOffset(for: gap))
                    }

                    ForEach(timedBlocks) { block in
                        blockLayer(for: block)
                    }

                    if let dragState, let block = timedBlocks.first(where: { $0.id == dragState.blockID }) {
                        TimelineDragTimeLabel(
                            date: dragState.proposedStart,
                            conflictTitle: dragState.conflictingBlockTitle
                        )
                        .offset(x: TimelineLayoutMetrics.laneLeadingInset, y: yOffset(for: dragState.proposedStart) - 26)

                        TimelineDragGhostCapsule(
                            width: laneWidth,
                            height: max(height(for: block), 44),
                            isInvalid: dragState.conflictingBlockTitle != nil
                        )
                        .offset(x: TimelineLayoutMetrics.laneLeadingInset, y: yOffset(for: dragState.proposedStart))
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

            return onDropLaterItem(itemID, date(at: location))
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
            .offset(x: TimelineLayoutMetrics.laneLeadingInset, y: yOffset(for: block.start))
        } else {
            TimelineTaskCapsule(
                block: block,
                now: now,
                width: laneWidth,
                pointsPerMinute: pointsPerMinute,
                isCurrent: block.id == currentBlockID,
                isNext: block.id == nextBlockID,
                draggable: isDraggable(block),
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
            .offset(x: TimelineLayoutMetrics.laneLeadingInset, y: yOffset(for: block.start))
        }
    }

    private func height(for block: PlannedBlock) -> CGFloat {
        CGFloat(max(block.durationMinutes, slotMinutes)) * pointsPerMinute
    }

    private func isDraggable(_ block: PlannedBlock) -> Bool {
        (block.source == .local || block.source == .template) && block.isCompleted == false && block.isStarted == false
    }

    private func yOffset(for date: Date) -> CGFloat {
        let clampedDate = min(max(date, range.lowerBound), range.upperBound)
        let minutes = clampedDate.timeIntervalSince(range.lowerBound) / 60
        return CGFloat(minutes) * pointsPerMinute
    }

    private func gapYOffset(for gap: TimelineGapItem) -> CGFloat {
        let start = yOffset(for: gap.start)
        let end = yOffset(for: gap.end)
        let availableHeight = max(end - start, 0)
        let centeredOffset = max((availableHeight - TimelineLayoutMetrics.gapCardHeight) / 2, 0)
        return start + centeredOffset
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
        .accessibilityHidden(true)
    }
}

private struct TimelineTickRow: View {
    let style: TimelineGridStyle
    let slotHeight: CGFloat

    var body: some View {
        HStack(spacing: TimelineLayoutMetrics.scaleToLaneSpacing) {
            VStack(alignment: .trailing, spacing: 0) {
                if let contextLabel = style.contextLabel {
                    Text(contextLabel)
                        .font(contextFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if style.label.isEmpty {
                    Rectangle()
                        .fill(labelColor.opacity(0.75))
                        .frame(width: 8, height: max(style.lineThickness, 1))
                        .padding(.top, contextLabelTopPadding)
                } else {
                    Text(style.label)
                        .font(timeFont)
                        .monospacedDigit()
                        .foregroundStyle(labelColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .allowsTightening(true)
                }
            }
            .frame(width: TimelineLayoutMetrics.labelColumnWidth, alignment: .trailing)
            .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(lineColor.opacity(style.lineOpacity))
                .frame(height: style.lineThickness)

            Spacer(minLength: 0)
        }
        .frame(height: slotHeight)
        .accessibilityHidden(true)
    }

    private var contextFont: Font {
        .caption2
    }

    private var contextLabelTopPadding: CGFloat {
        style.contextLabel == nil ? 0 : 2
    }

    private var timeFont: Font {
        switch style.tier {
        case .month, .day:
            .caption.bold()
        case .hour:
            .caption.bold()
        case .quarterHour:
            .caption
        case .minor:
            .caption2
        }
    }

    private var labelColor: Color {
        switch style.tier {
        case .month, .day, .hour:
            .primary
        case .quarterHour:
            .secondary
        case .minor:
            .secondary.opacity(0.7)
        }
    }

    private var lineColor: Color {
        switch style.tier {
        case .month, .day, .hour:
            .primary
        case .quarterHour, .minor:
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
                    TimelineTag(text: "Now", tint: tintColor(token: block.tintToken))
                } else if isNext {
                    TimelineTag(text: "Next", tint: .secondary)
                }

                if block.source == .local || block.source == .template {
                    timelineActionButton
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
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(borderColor, lineWidth: isCurrent ? 2 : 1)
        )
        .contentShape(.rect)
        .simultaneousGesture(dragGesture)
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
                let rawDelta = Int((value.translation.height / pointsPerMinute).rounded())
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

        if block.isStarted {
            return now >= block.end ? "checkmark.circle.fill" : "play.circle.fill"
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
            return tintColor(token: block.tintToken).opacity(0.85)
        }

        if isNext {
            return Color.primary.opacity(0.3)
        }

        if block.isCompleted {
            return .green.opacity(0.5)
        }

        if block.isStarted {
            return tintColor(token: block.tintToken).opacity(0.85)
        }

        if now > block.end {
            return .red.opacity(0.5)
        }

        if draggable {
            return .black.opacity(0.2)
        }

        return .black.opacity(0.12)
    }

    @ViewBuilder
    private var timelineActionButton: some View {
        if block.isCompleted || (block.isStarted && now >= block.end) {
            Button("Undo", systemImage: "arrow.uturn.backward") {
                onQuickAction(.markUndone)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityIdentifier("timeline-task-undo-\(block.title.testingIdentifier)")
        } else if block.isStarted {
            Button("Done", systemImage: "checkmark") {
                onQuickAction(.markDone)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(tintColor(token: block.tintToken))
            .accessibilityIdentifier("timeline-task-done-\(block.title.testingIdentifier)")
        } else {
            Button("Start", systemImage: "play.fill") {
                onQuickAction(.startNow)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityIdentifier("timeline-task-start-\(block.title.testingIdentifier)")
        }
    }

    private var backgroundColor: Color {
        if isCurrent {
            return tintColor(token: block.tintToken).opacity(0.12)
        }

        return Color.white.opacity(0.9)
    }

}

private struct TimelineGapCard: View {
    let item: TimelineGapItem
    let width: CGFloat

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
        .frame(width: width, alignment: .leading)
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
        .accessibilityHidden(true)
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
        Color.clear
            .frame(height: 52)
            .overlay(alignment: .center) {
                HStack(spacing: TimelineLayoutMetrics.scaleToLaneSpacing) {
                    Text(title)
                        .font(.caption.bold())
                        .monospacedDigit()
                        .lineLimit(1)
                        .hidden()
                        .overlay(alignment: .center) {
                            Text(title)
                                .font(.title3.bold())
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 6)
                                .glassEffect(.clear)
                                .shadow(color: Color.black.opacity(0.08), radius: 12, y: 4)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .frame(width: TimelineLayoutMetrics.labelColumnWidth, alignment: .trailing)

                    Rectangle()
                        .fill(markerLineColor)
                        .frame(height: 1.5)
                }
            }
            .allowsHitTesting(false)
            .accessibilityLabel("Timeline center")
            .accessibilityValue(accessibilityValue)
            .accessibilityIdentifier("timeline-center-time")
    }

    private var markerLineColor: Color {
        Color(red: 0.36, green: 0.56, blue: 0.40).opacity(0.45)
    }

    private var title: String {
        return date.formatted(.dateTime.hour().minute())
    }

    private var accessibilityValue: String {
        date.formatted(.dateTime.weekday(.wide).month(.wide).day().hour().minute())
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
        .accessibilityHidden(true)
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
    let start: Date
    let end: Date
    let title: String
    let detail: String
    let isWarning: Bool
}
