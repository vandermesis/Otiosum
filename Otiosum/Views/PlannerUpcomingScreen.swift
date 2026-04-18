import SwiftUI

struct UpcomingScreen: View {
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
