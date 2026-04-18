import SwiftUI

struct SomedayDrawerContent: View {
    let items: [PlannableItem]
    let onSchedule: (PlannableItem, DropLane) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Someday")
                    .font(.headline)
                Spacer()
                Text("\(items.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            if items.isEmpty {
                CalmEmptyState(
                    title: "Someday is clear",
                    message: "Add ideas with Quick Add and move them here when you want less pressure."
                )
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 10) {
                        ForEach(items) { item in
                            SomedayItemCard(item: item) {
                                onSchedule(item, lane(for: item))
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 240)
                .scrollIndicators(.hidden)
            }
        }
    }

    private func lane(for item: PlannableItem) -> DropLane {
        switch item.preferredTimeWindow {
        case .morning: return .morning
        case .afternoon: return .afternoon
        case .evening: return .evening
        case .night: return .night
        case .anytime:
            let hour = Calendar.current.component(.hour, from: .now)
            switch hour {
            case ..<12: return .morning
            case 12..<17: return .afternoon
            case 17..<21: return .evening
            default: return .night
            }
        }
    }
}

private struct SomedayItemCard: View {
    let item: PlannableItem
    let onAddToNow: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            PlannerIcon(symbolName: item.suggestedIcon, tintToken: item.tintToken, compact: true)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline)
                    .lineLimit(1)

                Text(item.kind == .idea ? "Idea" : "Task")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Add", systemImage: "plus.circle.fill", action: onAddToNow)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityIdentifier("someday-add-\(item.title.testingIdentifier)")
        }
        .padding(12)
        .draggable(item.id.uuidString)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("someday-item-\(item.title.testingIdentifier)")
    }
}
