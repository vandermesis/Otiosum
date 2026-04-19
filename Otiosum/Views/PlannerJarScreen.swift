import SwiftUI

struct SomedayDrawerContent: View {
    let items: [Event]
    let onSchedule: (Event, DropLane) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Archive")
                    .font(.headline)
                Spacer()
                Text("\(items.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            if items.isEmpty {
                CalmEmptyState(
                    title: "Archive is clear",
                    message: "Archive events with Quick Add and restore them when you want them back on the timeline."
                )
            } else {
                ScrollView(.vertical) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 92), spacing: 14)],
                        spacing: 14
                    ) {
                        ForEach(items) { item in
                            SomedayItemBall(item: item) {
                                onSchedule(item, lane(for: item))
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 560)
                .scrollIndicators(.hidden)
            }
        }
    }

    private func lane(for item: Event) -> DropLane {
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

private struct SomedayItemBall: View {
    let item: Event
    let onAddToNow: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(tintColor(token: item.tintToken).opacity(0.22))
                    .frame(width: 72, height: 72)

                PlannerIcon(symbolName: item.suggestedIcon, tintToken: item.tintToken, compact: false)
            }
            .overlay(Circle().strokeBorder(Color.white.opacity(0.65), lineWidth: 1))

            Text(item.title)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Button(action: onAddToNow) {
                Image(systemName: "plus")
                    .font(.caption.bold())
            }
            .buttonStyle(.borderedProminent)
            .clipShape(.circle)
            .accessibilityIdentifier("someday-add-\(item.title.testingIdentifier)")
        }
        .padding(.vertical, 6)
        .draggable(item.id.uuidString)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("someday-item-\(item.title.testingIdentifier)")
    }
}
