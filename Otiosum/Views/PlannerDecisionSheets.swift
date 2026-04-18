import SwiftUI

struct OverflowDecisionSheet: View {
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

struct CalendarShiftDecisionSheet: View {
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
