import SwiftData
import SwiftUI

struct SettingsScreen: View {
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
