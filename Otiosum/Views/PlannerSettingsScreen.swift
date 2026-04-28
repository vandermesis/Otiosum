import SwiftData
import SwiftUI

struct SettingsScreen: View {
    @Bindable var template: DayTemplate
    @Bindable var budget: DailyBudget
    let calendarService: SystemCalendarService

    var body: some View {
        Form {
            Section("Focus budget") {
                Stepper("Focus items per day: \(budget.maxFocusItems)", value: $budget.maxFocusItems, in: 2...10)
                Stepper("Transition buffer: \(template.transitionBufferMinutes)m", value: $template.transitionBufferMinutes, in: 5...45, step: 5)
                Stepper("Add Task default: \(budget.quickAddDefaultDurationMinutes)m", value: $budget.quickAddDefaultDurationMinutes, in: 15...180, step: 5)
            }

            Section("Protected time") {
                Stepper("Wake up: \(template.wakeUpMinutes.timeLabel)", value: $template.wakeUpMinutes, in: 300...720, step: 15)
                Stepper("Sleep starts: \(template.sleepStartMinutes.timeLabel)", value: $template.sleepStartMinutes, in: 1_080...1_410, step: 15)
                Stepper("Quiet time: \(template.quietStartMinutes.timeLabel)", value: $template.quietStartMinutes, in: 960...1_320, step: 15)
                Stepper("Recovery block: \(template.quietDurationMinutes)m", value: $template.quietDurationMinutes, in: 30...240, step: 15)
                Stepper("Lunch starts: \(template.lunchMinutes.timeLabel)", value: $template.lunchMinutes, in: 660...900, step: 15)
                Stepper("Dinner starts: \(template.dinnerMinutes.timeLabel)", value: $template.dinnerMinutes, in: 960...1_260, step: 15)
                Toggle("Protect workout time", isOn: $template.includeWorkout)
                if template.includeWorkout {
                    Stepper("Workout starts: \(template.workoutMinutes.timeLabel)", value: $template.workoutMinutes, in: 360...1_260, step: 15)
                }
            }

            Section("Calendar") {
                Label(
                    calendarService.canReadEvents ? "Calendar connected" : "Calendar not connected",
                    systemImage: calendarService.canReadEvents ? "checkmark.circle.fill" : "calendar.badge.exclamationmark"
                )
                .foregroundStyle(calendarService.canReadEvents ? .green : .primary)

                Stepper("Work target: \(budget.targetWorkMinutes)m", value: $budget.targetWorkMinutes, in: 120...600, step: 15)
                Stepper("Minimum sleep: \(budget.minimumSleepHours.formatted(.number.precision(.fractionLength(0...1))))h", value: $budget.minimumSleepHours, in: 6...10, step: 0.5)

                if let lastErrorMessage = calendarService.lastErrorMessage {
                    Text(lastErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Simplified mode") {
                Toggle("Simplified presentation", isOn: $budget.useSimplifiedMode)
                Toggle("Low-notification mode", isOn: $budget.lowNotificationMode)
            }
        }
        .navigationTitle("Settings")
    }
}
