import Foundation

struct RoutineBlockFactory {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func makeBlocks(
        for day: Date,
        template: DayTemplateSnapshot,
        budget: DailyBudgetSnapshot,
        endOfDay: Date
    ) -> [PlannedBlock] {
        var blocks: [PlannedBlock] = []
        let mealDuration = budget.mealDurationMinutes

        blocks.append(
            makeBlock(
                title: "Breakfast",
                symbol: "fork.knife",
                tintToken: "peach",
                role: .meal,
                day: day,
                startMinutes: template.breakfastMinutes,
                durationMinutes: mealDuration
            )
        )
        blocks.append(
            makeBlock(
                title: "Lunch",
                symbol: "fork.knife",
                tintToken: "peach",
                role: .meal,
                day: day,
                startMinutes: template.lunchMinutes,
                durationMinutes: mealDuration
            )
        )
        blocks.append(
            makeBlock(
                title: "Dinner",
                symbol: "fork.knife",
                tintToken: "peach",
                role: .meal,
                day: day,
                startMinutes: template.dinnerMinutes,
                durationMinutes: mealDuration
            )
        )
        blocks.append(
            makeBlock(
                title: "Recovery",
                symbol: "leaf.fill",
                tintToken: "sage",
                role: .rest,
                day: day,
                startMinutes: template.quietStartMinutes,
                durationMinutes: template.quietDurationMinutes
            )
        )
        blocks.append(
            makeBlock(
                title: "Sleep",
                symbol: "bed.double.fill",
                tintToken: "indigo",
                role: .sleep,
                day: day,
                startMinutes: template.sleepStartMinutes,
                end: endOfDay
            )
        )

        if template.includeWorkout {
            blocks.append(
                makeBlock(
                    title: "Workout",
                    symbol: "figure.walk",
                    tintToken: "lime",
                    role: .workout,
                    day: day,
                    startMinutes: template.workoutMinutes,
                    durationMinutes: template.workoutDurationMinutes
                )
            )
        }

        return blocks.sorted { lhs, rhs in
            if lhs.start == rhs.start {
                return lhs.end < rhs.end
            }
            return lhs.start < rhs.start
        }
    }

    private func makeBlock(
        title: String,
        symbol: String,
        tintToken: String,
        role: RoutineRole,
        day: Date,
        startMinutes: Int,
        durationMinutes: Int? = nil,
        end: Date? = nil
    ) -> PlannedBlock {
        let start = calendar.date(on: day, minutesFromStartOfDay: startMinutes)
        let endDate = end ?? start.adding(minutes: durationMinutes ?? 30)
        return PlannedBlock(
            id: UUID(),
            itemID: UUID(),
            calendarEventID: nil,
            title: title,
            start: start,
            end: endDate,
            source: .template,
            flexibility: .flexible,
            symbolName: symbol,
            tintToken: tintToken,
            notes: "",
            isAllDay: false,
            routineRole: role,
            isCompleted: false,
            isStarted: false,
            status: .upcoming,
            confidence: 0.7
        )
    }
}
