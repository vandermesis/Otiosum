import SwiftUI

struct JarScreen: View {
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
