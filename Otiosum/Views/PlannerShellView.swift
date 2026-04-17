import SwiftData
import SwiftUI

struct PlannerShellView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \PlannableItem.createdAt) private var items: [PlannableItem]
    @Query(sort: \CalendarLink.updatedAt) private var calendarLinks: [CalendarLink]
    @Query(sort: \DayTemplate.key) private var templates: [DayTemplate]
    @Query(sort: \DailyBudget.key) private var budgets: [DailyBudget]

    @State private var store = PlannerStore()

    private let plannerEngine = PlannerEngine()

    private var template: DayTemplate? { templates.first }
    private var budget: DailyBudget? { budgets.first }
    private var templateSnapshot: DayTemplateSnapshot { template?.snapshot ?? .default }
    private var budgetSnapshot: DailyBudgetSnapshot { budget?.snapshot ?? .default }
    private var itemLookup: [UUID: PlannableItem] {
        Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    }

    private var selectedDayPlan: DayPlan {
        plannerEngine.plan(
            for: store.selectedDay,
            localItems: items.map(\.snapshot),
            calendarEvents: store.calendarService.events(for: store.selectedDay),
            calendarLinks: calendarLinks.map(\.snapshot),
            template: templateSnapshot,
            budget: budgetSnapshot,
            context: store.inferenceContext(sceneIsActive: scenePhase == .active)
        )
    }

    private var upcomingPlans: [(Date, DayPlan)] {
        let calendar = Calendar.current
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: store.selectedDay)) else {
                return nil
            }

            let plan = plannerEngine.plan(
                for: day,
                localItems: items.map(\.snapshot),
                calendarEvents: store.calendarService.events(for: day),
                calendarLinks: calendarLinks.map(\.snapshot),
                template: templateSnapshot,
                budget: budgetSnapshot,
                context: store.inferenceContext(sceneIsActive: scenePhase == .active)
            )
            return (day, plan)
        }
    }

    private var promptKey: String {
        let overflow = selectedDayPlan.overflowIssues.map(\.itemID.uuidString).joined(separator: ",")
        let shifts = selectedDayPlan.shiftProposals.map(\.calendarEventID).joined(separator: ",")
        return "\(overflow)|\(shifts)|\(selectedDayPlan.warnings.count)"
    }

    var body: some View {
        Group {
            if template == nil || budget == nil {
                ProgressView("Preparing planner")
                    .task {
                        try? store.ensureSeedData(in: modelContext)
                    }
            } else {
                TabView(selection: selectedTabBinding) {
                    TodayScreen(
                        day: $store.selectedDay,
                        quickCapture: $store.todayQuickCapture,
                        plan: selectedDayPlan,
                        budget: budgetSnapshot,
                        calendarService: store.calendarService,
                        onRequestCalendarAccess: requestCalendarAccess,
                        onCapture: {
                            store.captureQuickItem(
                                from: .today,
                                modelContext: modelContext,
                                day: store.selectedDay,
                                template: templateSnapshot
                            )
                        },
                        onToggleComplete: { block in
                            store.registerInteraction()
                            if let item = itemLookup[block.itemID] {
                                store.toggleCompletion(item, modelContext: modelContext)
                            }
                        },
                        onMoveLater: { block in
                            store.registerInteraction()
                            if let item = itemLookup[block.itemID] {
                                store.moveItemLater(item, on: store.selectedDay, modelContext: modelContext)
                            }
                        },
                        onReturnToJar: { block in
                            store.registerInteraction()
                            if let item = itemLookup[block.itemID] {
                                store.returnToJar(item, modelContext: modelContext)
                            }
                        },
                        onCalendarFlexibility: { block, flexibility in
                            store.registerInteraction()
                            guard let calendarEventID = block.calendarEventID else { return }
                            store.updateCalendarFlexibility(
                                for: calendarEventID,
                                title: block.title,
                                flexibility: flexibility,
                                modelContext: modelContext
                            )
                        }
                    )
                    .tag(PlannerTab.today)
                    .tabItem {
                        Label("Today", systemImage: "sun.max.fill")
                    }

                    JarScreen(
                        items: items.filter { $0.isInJar || $0.scheduledDay == nil },
                        quickCapture: $store.jarQuickCapture,
                        onCapture: {
                            store.captureQuickItem(
                                from: .jar,
                                modelContext: modelContext,
                                day: store.selectedDay,
                                template: templateSnapshot
                            )
                        },
                        onSchedule: { item, lane in
                            store.registerInteraction()
                            store.scheduleJarItem(item: item, lane: lane, on: store.selectedDay, modelContext: modelContext)
                        }
                    )
                    .tag(PlannerTab.jar)
                    .tabItem {
                        Label("Jar", systemImage: "circle.grid.3x3.fill")
                    }

                    UpcomingScreen(
                        plans: upcomingPlans,
                        calendarService: store.calendarService
                    )
                    .tag(PlannerTab.upcoming)
                    .tabItem {
                        Label("Upcoming", systemImage: "calendar")
                    }

                    TimeWheelView()
                        .tag(PlannerTab.time)
                        .tabItem {
                            Label("Time", systemImage: "clock.arrow.circlepath")
                        }

                    if let template, let budget {
                        SettingsScreen(
                            template: template,
                            budget: budget,
                            calendarService: store.calendarService
                        )
                        .tag(PlannerTab.settings)
                        .tabItem {
                            Label("Settings", systemImage: "slider.horizontal.3")
                        }
                    }
                }
                .tint(.black)
                .background(PlannerBackground(simple: budgetSnapshot.useSimplifiedMode))
            }
        }
        .task {
            try? store.ensureSeedData(in: modelContext)
            await refreshCalendar()
        }
        .task(id: store.selectedDay) {
            await refreshCalendar()
        }
        .task(id: promptKey) {
            store.refreshPrompts(for: selectedDayPlan, modelContext: modelContext)
        }
        .onChange(of: scenePhase) { _, _ in
            store.registerInteraction()
        }
        .sheet(item: pendingOverflowBinding) { pendingOverflow in
            OverflowDecisionSheet(
                state: pendingOverflow,
                onChoose: { choice in
                    store.applyOverflowChoice(choice, modelContext: modelContext)
                }
            )
        }
        .sheet(item: pendingCalendarShiftBinding) { pendingCalendarShift in
            CalendarShiftDecisionSheet(
                state: pendingCalendarShift,
                onChoose: { decision in
                    Task {
                        await store.applyCalendarDecision(decision, modelContext: modelContext)
                        await refreshCalendar()
                    }
                }
            )
        }
    }

    private var selectedTabBinding: Binding<PlannerTab> {
        Binding(
            get: { store.selectedTab },
            set: {
                store.selectedTab = $0
                store.registerInteraction()
            }
        )
    }

    private var pendingOverflowBinding: Binding<PendingOverflowState?> {
        Binding(
            get: { store.pendingOverflow },
            set: { store.pendingOverflow = $0 }
        )
    }

    private var pendingCalendarShiftBinding: Binding<PendingCalendarShiftState?> {
        Binding(
            get: { store.pendingCalendarShift },
            set: { store.pendingCalendarShift = $0 }
        )
    }

    private func refreshCalendar() async {
        await store.calendarService.refreshEvents(covering: store.calendarRefreshInterval(around: store.selectedDay))
    }

    private func requestCalendarAccess() {
        Task {
            await store.calendarService.requestFullAccess()
            await refreshCalendar()
        }
    }
}

private struct TodayScreen: View {
    @Binding var day: Date
    @Binding var quickCapture: String

    let plan: DayPlan
    let budget: DailyBudgetSnapshot
    let calendarService: SystemCalendarService
    let onRequestCalendarAccess: () -> Void
    let onCapture: () -> Void
    let onToggleComplete: (PlannedBlock) -> Void
    let onMoveLater: (PlannedBlock) -> Void
    let onReturnToJar: (PlannedBlock) -> Void
    let onCalendarFlexibility: (PlannedBlock, PlannerFlexibility) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    DayHeader(day: $day)

                    CaptureComposer(
                        title: "Quick add",
                        placeholder: "One word is enough",
                        text: $quickCapture,
                        buttonTitle: "Place in today",
                        onSubmit: onCapture
                    )

                    if calendarService.canReadEvents == false {
                        PlannerMessageCard(
                            title: "Bring in your calendar when you want",
                            message: "Otiosum already works with local tasks. If you connect Calendar, synced events will be protected in the plan too.",
                            actionTitle: "Connect Calendar",
                            action: onRequestCalendarAccess
                        )
                    }

                    if let nowBlock = plan.nowBlock {
                        SpotlightCard(title: "Now", block: nowBlock)
                    } else {
                        CalmEmptyState(
                            title: "Nothing urgent right now",
                            message: "The planner is keeping some open space."
                        )
                    }

                    if let nextBlock = plan.nextBlock {
                        SpotlightCard(title: "Next", block: nextBlock)
                    }

                    if plan.warnings.isEmpty == false {
                        VStack(spacing: 10) {
                            ForEach(plan.warnings) { warning in
                                WarningCard(warning: warning)
                            }
                        }
                    }

                    DropLaneSection()

                    ScheduleSection(
                        title: "Later",
                        subtitle: "Flexible blocks that can move without shame.",
                        blocks: plan.laterBlocks,
                        onToggleComplete: onToggleComplete,
                        onMoveLater: onMoveLater,
                        onReturnToJar: onReturnToJar,
                        onCalendarFlexibility: onCalendarFlexibility
                    )

                    ProtectedTimeSection(plan: plan, budget: budget)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
            }
            .background(PlannerBackground(simple: budget.useSimplifiedMode))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct JarScreen: View {
    let items: [PlannableItem]
    @Binding var quickCapture: String
    let onCapture: () -> Void
    let onSchedule: (PlannableItem, DropLane) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Jar")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("Loose ideas, future events, and maybes can stay here until you want them.")
                        .foregroundStyle(.secondary)

                    CaptureComposer(
                        title: "Drop in a thought",
                        placeholder: "Todo, idea, event for later",
                        text: $quickCapture,
                        buttonTitle: "Keep in jar",
                        onSubmit: onCapture
                    )

                    if items.isEmpty {
                        CalmEmptyState(
                            title: "The jar is light",
                            message: "Add ideas here so today does not have to carry everything at once."
                        )
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                            ForEach(items) { item in
                                JarBallCard(item: item)
                                    .draggable(item.id.uuidString)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Drag into today")
                            .font(.headline)
                        ForEach(DropLane.allCases) { lane in
                            Button {
                                if let item = items.first {
                                    onSchedule(item, lane)
                                }
                            } label: {
                                HStack {
                                    Text(lane.title)
                                    Spacer()
                                    Text(lane.timeWindow.title)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(14)
                                .background(Color.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(lane.title)
                            .accessibilityIdentifier("schedule-lane-\(lane.rawValue)")
                            .dropDestination(for: String.self) { droppedIDs, _ in
                                guard let droppedID = droppedIDs.first,
                                      let uuid = UUID(uuidString: droppedID),
                                      let item = items.first(where: { $0.id == uuid })
                                else {
                                    return false
                                }

                                onSchedule(item, lane)
                                return true
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
            }
            .background(PlannerBackground(simple: false))
        }
    }
}

private struct UpcomingScreen: View {
    let plans: [(Date, DayPlan)]
    let calendarService: SystemCalendarService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Upcoming")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("A calm seven-day agenda so nothing sneaks up on you.")
                        .foregroundStyle(.secondary)

                    if calendarService.isLoading {
                        ProgressView("Refreshing events")
                    }

                    ForEach(plans, id: \.0) { day, plan in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(day.formatted(.dateTime.weekday(.wide).day().month()))
                                .font(.headline)
                            ForEach(plan.allBlocks.prefix(4)) { block in
                                MiniBlockRow(block: block)
                            }
                            if plan.allBlocks.isEmpty {
                                Text("Open space")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
            }
            .background(PlannerBackground(simple: false))
        }
    }
}

private struct SettingsScreen: View {
    @Bindable var template: DayTemplate
    @Bindable var budget: DailyBudget
    let calendarService: SystemCalendarService

    var body: some View {
        NavigationStack {
            Form {
                Section("Healthy rhythm") {
                    Stepper("Wake up: \(template.wakeUpMinutes.timeLabel)", value: $template.wakeUpMinutes, in: 300...720, step: 15)
                    Stepper("Sleep starts: \(template.sleepStartMinutes.timeLabel)", value: $template.sleepStartMinutes, in: 1_080...1_410, step: 15)
                    Stepper("Quiet time: \(template.quietStartMinutes.timeLabel)", value: $template.quietStartMinutes, in: 960...1_320, step: 15)
                    Stepper("Recovery minutes: \(template.quietDurationMinutes)", value: $template.quietDurationMinutes, in: 30...240, step: 15)
                }

                Section("Meals and movement") {
                    Stepper("Breakfast: \(template.breakfastMinutes.timeLabel)", value: $template.breakfastMinutes, in: 360...720, step: 15)
                    Stepper("Lunch: \(template.lunchMinutes.timeLabel)", value: $template.lunchMinutes, in: 660...900, step: 15)
                    Stepper("Dinner: \(template.dinnerMinutes.timeLabel)", value: $template.dinnerMinutes, in: 960...1_260, step: 15)
                    Toggle("Protect workout time", isOn: $template.includeWorkout)
                    if template.includeWorkout {
                        Stepper("Workout: \(template.workoutMinutes.timeLabel)", value: $template.workoutMinutes, in: 360...1_260, step: 15)
                    }
                }

                Section("Guardrails") {
                    Stepper("Minimum sleep hours: \(budget.minimumSleepHours.formatted(.number.precision(.fractionLength(0...1))))", value: $budget.minimumSleepHours, in: 6...10, step: 0.5)
                    Stepper("Work target minutes: \(budget.targetWorkMinutes)", value: $budget.targetWorkMinutes, in: 120...600, step: 15)
                    Stepper("Focus items per day: \(budget.maxFocusItems)", value: $budget.maxFocusItems, in: 2...10)
                    Toggle("Low-notification mode", isOn: $budget.lowNotificationMode)
                    Toggle("Simplified presentation", isOn: $budget.useSimplifiedMode)
                }

                Section("Calendar") {
                    Label(
                        calendarService.canReadEvents ? "Calendar connected" : "Calendar not connected",
                        systemImage: calendarService.canReadEvents ? "checkmark.circle.fill" : "calendar.badge.exclamationmark"
                    )
                    .foregroundStyle(calendarService.canReadEvents ? .green : .primary)
                    if let lastErrorMessage = calendarService.lastErrorMessage {
                        Text(lastErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

private struct DayHeader: View {
    @Binding var day: Date

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text(day.formatted(.dateTime.weekday(.wide).day().month()))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    shiftDay(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }

                Button("Now") {
                    day = .now
                }

                Button {
                    shiftDay(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.white.opacity(0.72))
            .foregroundStyle(.black)
        }
    }

    private func shiftDay(by amount: Int) {
        day = Calendar.current.date(byAdding: .day, value: amount, to: day) ?? day
    }
}

private struct CaptureComposer: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let buttonTitle: String
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            HStack(spacing: 12) {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit(onSubmit)
                Button(buttonTitle, action: onSubmit)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct SpotlightCard: View {
    let title: String
    let block: PlannedBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 14) {
                PlannerIcon(symbolName: block.symbolName, tintToken: block.tintToken)
                VStack(alignment: .leading, spacing: 6) {
                    Text(block.title)
                        .font(.title3.weight(.semibold))
                    Text("\(block.start.formatted(.dateTime.hour().minute())) - \(block.end.formatted(.dateTime.hour().minute()))")
                        .foregroundStyle(.secondary)
                    if block.status == .gentlyLate {
                        Text("This is taking longer than planned, so later blocks are sliding with it.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

private struct WarningCard: View {
    let warning: GuardrailWarning

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: warning.severity == .attention ? "moon.zzz.fill" : "leaf.circle.fill")
                .foregroundStyle(warning.severity == .attention ? Color.orange : Color.green)
            VStack(alignment: .leading, spacing: 4) {
                Text(warning.message)
                    .font(.headline)
                Text(warning.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct DropLaneSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Drop from the jar")
                .font(.headline)
            Text("Drag a ball into one of these lanes to place it gently into today.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ForEach(DropLane.allCases) { lane in
                    DropLaneCard(lane: lane)
                }
            }
        }
    }
}

private struct DropLaneCard: View {
    let lane: DropLane

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(lane.timeWindow.title)
                .font(.headline)
            Text(lane.title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityIdentifier("drop-lane-\(lane.rawValue)")
    }
}

private struct ScheduleSection: View {
    let title: String
    let subtitle: String
    let blocks: [PlannedBlock]
    let onToggleComplete: (PlannedBlock) -> Void
    let onMoveLater: (PlannedBlock) -> Void
    let onReturnToJar: (PlannedBlock) -> Void
    let onCalendarFlexibility: (PlannedBlock, PlannerFlexibility) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if blocks.isEmpty {
                CalmEmptyState(
                    title: "Space is still available",
                    message: "This part of the day is intentionally light."
                )
            } else {
                ForEach(blocks) { block in
                    ScheduleBlockCard(
                        block: block,
                        onToggleComplete: onToggleComplete,
                        onMoveLater: onMoveLater,
                        onReturnToJar: onReturnToJar,
                        onCalendarFlexibility: onCalendarFlexibility
                    )
                }
            }
        }
    }
}

private struct ScheduleBlockCard: View {
    let block: PlannedBlock
    let onToggleComplete: (PlannedBlock) -> Void
    let onMoveLater: (PlannedBlock) -> Void
    let onReturnToJar: (PlannedBlock) -> Void
    let onCalendarFlexibility: (PlannedBlock, PlannerFlexibility) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                PlannerIcon(symbolName: block.symbolName, tintToken: block.tintToken)
                VStack(alignment: .leading, spacing: 4) {
                    Text(block.title)
                        .font(.headline)
                    Text("\(block.start.formatted(.dateTime.hour().minute())) - \(block.end.formatted(.dateTime.hour().minute()))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusPill(status: block.status)
            }

            HStack(spacing: 10) {
                if block.source == .local {
                    Button(block.isCompleted ? "Undo" : "Done") {
                        onToggleComplete(block)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Later") {
                        onMoveLater(block)
                    }
                    .buttonStyle(.bordered)

                    Button("Jar") {
                        onReturnToJar(block)
                    }
                    .buttonStyle(.bordered)
                } else if block.source == .calendar {
                    Menu("Calendar rules") {
                        Button("Keep fixed") {
                            onCalendarFlexibility(block, .locked)
                        }
                        Button("Ask before move") {
                            onCalendarFlexibility(block, .askBeforeMove)
                        }
                        Button("Flexible in Otiosum") {
                            onCalendarFlexibility(block, .flexible)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct ProtectedTimeSection: View {
    let plan: DayPlan
    let budget: DailyBudgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Protected time")
                .font(.title3.weight(.semibold))
            BudgetSummaryCard(summary: plan.budgetSummary, budget: budget)
            ForEach(plan.protectedBlocks) { block in
                MiniBlockRow(block: block)
            }
        }
    }
}

private struct BudgetSummaryCard: View {
    let summary: BudgetUsageSummary
    let budget: DailyBudgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Healthy balance")
                .font(.headline)
            HStack {
                SummaryMetric(title: "Work", value: "\(summary.workMinutes)m / \(budget.targetWorkMinutes)m")
                SummaryMetric(title: "Rest", value: "\(summary.restMinutes)m / \(budget.minimumRestMinutes)m")
                SummaryMetric(title: "Sleep", value: "\(Int(budget.minimumSleepHours))h")
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct SummaryMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MiniBlockRow: View {
    let block: PlannedBlock

    var body: some View {
        HStack(spacing: 10) {
            PlannerIcon(symbolName: block.symbolName, tintToken: block.tintToken, compact: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(block.title)
                    .font(.subheadline.weight(.semibold))
                Text("\(block.start.formatted(.dateTime.hour().minute())) - \(block.end.formatted(.dateTime.hour().minute()))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct JarBallCard: View {
    let item: PlannableItem

    var body: some View {
        let icon = IconSuggestion(symbolName: item.suggestedIcon, tintToken: item.tintToken, emoji: "•")

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PlannerIcon(symbolName: icon.symbolName, tintToken: icon.tintToken)
                Spacer()
                Text(item.kind == .idea ? "Idea" : "Jar")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(item.title)
                .font(.headline)
            if let scheduledDay = item.scheduledDay {
                Text(scheduledDay.formatted(.dateTime.weekday(.abbreviated).day().month()))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(minHeight: 150, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.85), tintColor(token: item.tintToken).opacity(0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.title)
        .accessibilityIdentifier("jar-ball-\(item.title.testingIdentifier)")
    }
}

private struct PlannerMessageCard: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct CalmEmptyState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct OverflowDecisionSheet: View {
    let state: PendingOverflowState
    let onChoose: (OverflowChoice) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Not enough room today") {
                    Text(state.title)
                        .font(.headline)
                    Text(state.message)
                        .foregroundStyle(.secondary)
                }

                Section("Choose what feels best") {
                    ForEach(OverflowChoice.allCases) { choice in
                        Button(choice.title) {
                            onChoose(choice)
                        }
                    }
                }
            }
            .navigationTitle("Overflow")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

private struct CalendarShiftDecisionSheet: View {
    let state: PendingCalendarShiftState
    let onChoose: (CalendarShiftDecision) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Synced event") {
                    Text(state.proposal.title)
                        .font(.headline)
                    Text("Otiosum moved this later so the day stays calm.")
                        .foregroundStyle(.secondary)
                    Text("Suggested time: \(state.proposal.suggestedStart.formatted(.dateTime.hour().minute())) - \(state.proposal.suggestedEnd.formatted(.dateTime.hour().minute()))")
                        .font(.footnote)
                }

                Section("Apply change") {
                    ForEach(CalendarShiftDecision.allCases) { decision in
                        Button(decision.title) {
                            onChoose(decision)
                        }
                    }
                }
            }
            .navigationTitle("Calendar shift")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

private struct PlannerBackground: View {
    let simple: Bool

    var body: some View {
        Group {
            if simple {
                Color(red: 0.96, green: 0.95, blue: 0.92)
                    .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.94, blue: 0.85),
                        Color(red: 0.88, green: 0.95, blue: 0.92),
                        Color(red: 0.84, green: 0.90, blue: 0.97)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
    }
}

private struct PlannerIcon: View {
    let symbolName: String
    let tintToken: String
    var compact: Bool = false

    var body: some View {
        Image(systemName: symbolName)
            .font(compact ? .subheadline.weight(.semibold) : .title3.weight(.semibold))
            .foregroundStyle(tintColor(token: tintToken))
            .frame(width: compact ? 28 : 42, height: compact ? 28 : 42)
            .background(tintColor(token: tintToken).opacity(0.14), in: RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous))
    }
}

private struct StatusPill: View {
    let status: InferredProgressStatus

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.8), in: Capsule())
    }

    private var title: String {
        switch status {
        case .upcoming: "Upcoming"
        case .likelyInProgress: "Likely active"
        case .gentlyLate: "Sliding later"
        case .complete: "Done"
        case .protectedTime: "Protected"
        case .waiting: "Waiting"
        }
    }
}

private func tintColor(token: String) -> Color {
    switch token {
    case "peach":
        Color(red: 0.90, green: 0.58, blue: 0.34)
    case "indigo":
        Color(red: 0.37, green: 0.41, blue: 0.78)
    case "sage":
        Color(red: 0.46, green: 0.62, blue: 0.50)
    case "lime":
        Color(red: 0.52, green: 0.71, blue: 0.22)
    case "sky":
        Color(red: 0.29, green: 0.58, blue: 0.84)
    case "amber":
        Color(red: 0.90, green: 0.70, blue: 0.20)
    case "violet":
        Color(red: 0.62, green: 0.48, blue: 0.82)
    case "teal":
        Color(red: 0.24, green: 0.62, blue: 0.62)
    case "sand":
        Color(red: 0.71, green: 0.64, blue: 0.52)
    case "mint":
        Color(red: 0.21, green: 0.67, blue: 0.54)
    default:
        Color(red: 0.40, green: 0.55, blue: 0.78)
    }
}

private extension Int {
    var timeLabel: String {
        let hours = self / 60
        let minutes = self % 60
        return String(format: "%02d:%02d", hours, minutes)
    }
}

private extension String {
    var testingIdentifier: String {
        replacingOccurrences(of: " ", with: "-").lowercased()
    }
}
