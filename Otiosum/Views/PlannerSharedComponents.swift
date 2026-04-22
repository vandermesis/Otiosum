import SwiftUI

struct DayHeader: View {
    let day: Date

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Now")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text(day.formatted(.dateTime.weekday(.wide).day().month()))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

struct CaptureComposer: View {
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

struct SpotlightCard: View {
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

struct WarningCard: View {
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

struct DropLaneSection: View {
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

struct DropLaneCard: View {
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

struct ScheduleSection: View {
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

struct ScheduleBlockCard: View {
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

struct ProtectedTimeSection: View {
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

struct BudgetSummaryCard: View {
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

struct SummaryMetric: View {
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

struct MiniBlockRow: View {
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

struct JarBallCard: View {
    let item: Event

    var body: some View {
        let icon = IconSuggestion(symbolName: item.suggestedIcon, tintToken: item.tintToken, emoji: "•")

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PlannerIcon(symbolName: icon.symbolName, tintToken: icon.tintToken)
                Spacer()
                Text("Archive")
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

struct PlannerMessageCard: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 14) {
                PlannerMessageIcon()
                PlannerMessageText(title: title, message: message)
                Spacer(minLength: 0)
                PlannerMessageAction(title: actionTitle, action: action)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 14) {
                    PlannerMessageIcon()
                    PlannerMessageText(title: title, message: message)
                }
                PlannerMessageAction(title: actionTitle, action: action)
            }
        }
        .padding(16)
        .background(.background.opacity(0.74), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.55), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
    }
}

private struct PlannerMessageIcon: View {
    var body: some View {
        Image(systemName: "calendar.badge.clock")
            .font(.title3)
            .foregroundStyle(.tint)
            .frame(width: 44, height: 44)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct PlannerMessageText: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
    }
}

private struct PlannerMessageAction: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, systemImage: "link") {
            action()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }
}

struct CalmEmptyState: View {
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
