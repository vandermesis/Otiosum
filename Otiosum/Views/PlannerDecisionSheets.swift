import SwiftUI

struct TooMuchTodayDecisionSheet: View {
    let state: PendingTooMuchTodayState
    let onChoose: (TooMuchTodayChoice) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Today is already full") {
                    Text(state.title)
                        .font(.headline)
                    Text(state.message)
                        .foregroundStyle(.secondary)
                }

                Section("Choose the gentlest next step") {
                    ForEach(TooMuchTodayChoice.allCases) { choice in
                        Button(choice.title) {
                            onChoose(choice)
                        }
                    }
                }
            }
            .navigationTitle("Too Much Today")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

struct CalendarShiftDecisionSheet: View {
    let state: PendingCalendarShiftState
    let onChoose: (CalendarShiftDecision) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Calendar event") {
                    Text(state.proposal.title)
                        .font(.headline)
                    Text("Today was adjusted to protect the rest of the day.")
                        .foregroundStyle(.secondary)
                    Text("Suggested time: \(state.proposal.suggestedStart.formatted(.dateTime.hour().minute())) - \(state.proposal.suggestedEnd.formatted(.dateTime.hour().minute()))")
                        .font(.footnote)
                }

                Section("Choose how to handle it") {
                    ForEach(CalendarShiftDecision.allCases) { decision in
                        Button(decision.title) {
                            onChoose(decision)
                        }
                    }
                }
            }
            .navigationTitle("Calendar Change")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}
