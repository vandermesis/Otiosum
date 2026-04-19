import Foundation
import SwiftData

@Model
final class PlannableItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var kindRaw: String
    var sourceRaw: String
    var suggestedIcon: String
    var tintToken: String
    var targetDurationMinutes: Int
    var minimumDurationMinutes: Int
    var scheduledDay: Date?
    var preferredStartMinutes: Int?
    var preferredTimeWindowRaw: String
    var flexibilityRaw: String
    var calendarEventID: String?
    var protectedCategoryRaw: String?
    var notes: String
    var isCompleted: Bool
    var createdAt: Date
    var orderHint: Double
    var isInJar: Bool
    var forceAfterBedtime: Bool

    init(
        id: UUID = UUID(),
        title: String,
        kind: PlannerItemKind = .task,
        source: PlannerItemSource = .local,
        suggestedIcon: String,
        tintToken: String,
        targetDurationMinutes: Int = 30,
        minimumDurationMinutes: Int = 15,
        scheduledDay: Date? = nil,
        preferredStartMinutes: Int? = nil,
        preferredTimeWindow: PreferredTimeWindow = .anytime,
        flexibility: PlannerFlexibility = .flexible,
        calendarEventID: String? = nil,
        protectedCategory: ProtectedCategory? = nil,
        notes: String = "",
        isCompleted: Bool = false,
        createdAt: Date = .now,
        orderHint: Double = .random(in: 0..<1_000_000),
        isInJar: Bool = false,
        forceAfterBedtime: Bool = false
    ) {
        self.id = id
        self.title = title
        self.kindRaw = kind.rawValue
        self.sourceRaw = source.rawValue
        self.suggestedIcon = suggestedIcon
        self.tintToken = tintToken
        self.targetDurationMinutes = targetDurationMinutes
        self.minimumDurationMinutes = minimumDurationMinutes
        self.scheduledDay = scheduledDay
        self.preferredStartMinutes = preferredStartMinutes
        self.preferredTimeWindowRaw = preferredTimeWindow.rawValue
        self.flexibilityRaw = flexibility.rawValue
        self.calendarEventID = calendarEventID
        self.protectedCategoryRaw = protectedCategory?.rawValue
        self.notes = notes
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.orderHint = orderHint
        self.isInJar = isInJar
        self.forceAfterBedtime = forceAfterBedtime
    }

    var kind: PlannerItemKind {
        get { PlannerItemKind(rawValue: kindRaw) ?? .task }
        set { kindRaw = newValue.rawValue }
    }

    var source: PlannerItemSource {
        get { PlannerItemSource(rawValue: sourceRaw) ?? .local }
        set { sourceRaw = newValue.rawValue }
    }

    var preferredTimeWindow: PreferredTimeWindow {
        get { PreferredTimeWindow(rawValue: preferredTimeWindowRaw) ?? .anytime }
        set { preferredTimeWindowRaw = newValue.rawValue }
    }

    var flexibility: PlannerFlexibility {
        get { PlannerFlexibility(rawValue: flexibilityRaw) ?? .flexible }
        set { flexibilityRaw = newValue.rawValue }
    }

    var protectedCategory: ProtectedCategory? {
        get {
            guard let protectedCategoryRaw else { return nil }
            return ProtectedCategory(rawValue: protectedCategoryRaw)
        }
        set { protectedCategoryRaw = newValue?.rawValue }
    }

    var snapshot: PlannerItemSnapshot {
        PlannerItemSnapshot(
            id: id,
            title: title,
            kind: kind,
            source: source,
            suggestedIcon: suggestedIcon,
            tintToken: tintToken,
            targetDurationMinutes: targetDurationMinutes,
            minimumDurationMinutes: minimumDurationMinutes,
            scheduledDay: scheduledDay,
            preferredStartMinutes: preferredStartMinutes,
            preferredTimeWindow: preferredTimeWindow,
            flexibility: flexibility,
            calendarEventID: calendarEventID,
            protectedCategory: protectedCategory,
            notes: notes,
            isCompleted: isCompleted,
            orderHint: orderHint,
            isInJar: isInJar,
            forceAfterBedtime: forceAfterBedtime
        )
    }
}

@Model
final class CalendarLink {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var calendarEventID: String
    var title: String
    var flexibilityRaw: String
    var editPolicyRaw: String
    var localOverrideStart: Date?
    var localOverrideEnd: Date?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        calendarEventID: String,
        title: String,
        flexibility: PlannerFlexibility = .askBeforeMove,
        editPolicy: CalendarEditPolicy = .askEveryTime,
        localOverrideStart: Date? = nil,
        localOverrideEnd: Date? = nil,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.calendarEventID = calendarEventID
        self.title = title
        self.flexibilityRaw = flexibility.rawValue
        self.editPolicyRaw = editPolicy.rawValue
        self.localOverrideStart = localOverrideStart
        self.localOverrideEnd = localOverrideEnd
        self.updatedAt = updatedAt
    }

    var flexibility: PlannerFlexibility {
        get { PlannerFlexibility(rawValue: flexibilityRaw) ?? .askBeforeMove }
        set {
            flexibilityRaw = newValue.rawValue
            updatedAt = .now
        }
    }

    var editPolicy: CalendarEditPolicy {
        get { CalendarEditPolicy(rawValue: editPolicyRaw) ?? .askEveryTime }
        set {
            editPolicyRaw = newValue.rawValue
            updatedAt = .now
        }
    }

    var snapshot: CalendarLinkSnapshot {
        CalendarLinkSnapshot(
            id: id,
            calendarEventID: calendarEventID,
            flexibility: flexibility,
            editPolicy: editPolicy,
            localOverrideStart: localOverrideStart,
            localOverrideEnd: localOverrideEnd
        )
    }
}

@Model
final class DayTemplate {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var key: String
    var wakeUpMinutes: Int
    var sleepStartMinutes: Int
    var breakfastMinutes: Int
    var lunchMinutes: Int
    var dinnerMinutes: Int
    var quietStartMinutes: Int
    var quietDurationMinutes: Int
    var workoutMinutes: Int
    var workoutDurationMinutes: Int
    var includeWorkout: Bool
    var transitionBufferMinutes: Int

    init(
        id: UUID = UUID(),
        key: String = "default",
        wakeUpMinutes: Int = DayTemplateSnapshot.default.wakeUpMinutes,
        sleepStartMinutes: Int = DayTemplateSnapshot.default.sleepStartMinutes,
        breakfastMinutes: Int = DayTemplateSnapshot.default.breakfastMinutes,
        lunchMinutes: Int = DayTemplateSnapshot.default.lunchMinutes,
        dinnerMinutes: Int = DayTemplateSnapshot.default.dinnerMinutes,
        quietStartMinutes: Int = DayTemplateSnapshot.default.quietStartMinutes,
        quietDurationMinutes: Int = DayTemplateSnapshot.default.quietDurationMinutes,
        workoutMinutes: Int = DayTemplateSnapshot.default.workoutMinutes,
        workoutDurationMinutes: Int = DayTemplateSnapshot.default.workoutDurationMinutes,
        includeWorkout: Bool = DayTemplateSnapshot.default.includeWorkout,
        transitionBufferMinutes: Int = DayTemplateSnapshot.default.transitionBufferMinutes
    ) {
        self.id = id
        self.key = key
        self.wakeUpMinutes = wakeUpMinutes
        self.sleepStartMinutes = sleepStartMinutes
        self.breakfastMinutes = breakfastMinutes
        self.lunchMinutes = lunchMinutes
        self.dinnerMinutes = dinnerMinutes
        self.quietStartMinutes = quietStartMinutes
        self.quietDurationMinutes = quietDurationMinutes
        self.workoutMinutes = workoutMinutes
        self.workoutDurationMinutes = workoutDurationMinutes
        self.includeWorkout = includeWorkout
        self.transitionBufferMinutes = transitionBufferMinutes
    }

    var snapshot: DayTemplateSnapshot {
        DayTemplateSnapshot(
            wakeUpMinutes: wakeUpMinutes,
            sleepStartMinutes: sleepStartMinutes,
            breakfastMinutes: breakfastMinutes,
            lunchMinutes: lunchMinutes,
            dinnerMinutes: dinnerMinutes,
            quietStartMinutes: quietStartMinutes,
            quietDurationMinutes: quietDurationMinutes,
            workoutMinutes: workoutMinutes,
            workoutDurationMinutes: workoutDurationMinutes,
            includeWorkout: includeWorkout,
            transitionBufferMinutes: transitionBufferMinutes
        )
    }
}

@Model
final class DailyBudget {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var key: String
    var minimumSleepHours: Double
    var minimumRestMinutes: Int
    var targetWorkMinutes: Int
    var maxFocusItems: Int
    var mealDurationMinutes: Int
    var workoutTargetMinutes: Int
    var quickAddDefaultDurationMinutes: Int
    var lowNotificationMode: Bool
    var useSimplifiedMode: Bool

    init(
        id: UUID = UUID(),
        key: String = "default",
        minimumSleepHours: Double = DailyBudgetSnapshot.default.minimumSleepHours,
        minimumRestMinutes: Int = DailyBudgetSnapshot.default.minimumRestMinutes,
        targetWorkMinutes: Int = DailyBudgetSnapshot.default.targetWorkMinutes,
        maxFocusItems: Int = DailyBudgetSnapshot.default.maxFocusItems,
        mealDurationMinutes: Int = DailyBudgetSnapshot.default.mealDurationMinutes,
        workoutTargetMinutes: Int = DailyBudgetSnapshot.default.workoutTargetMinutes,
        quickAddDefaultDurationMinutes: Int = DailyBudgetSnapshot.default.quickAddDefaultDurationMinutes,
        lowNotificationMode: Bool = DailyBudgetSnapshot.default.lowNotificationMode,
        useSimplifiedMode: Bool = DailyBudgetSnapshot.default.useSimplifiedMode
    ) {
        self.id = id
        self.key = key
        self.minimumSleepHours = minimumSleepHours
        self.minimumRestMinutes = minimumRestMinutes
        self.targetWorkMinutes = targetWorkMinutes
        self.maxFocusItems = maxFocusItems
        self.mealDurationMinutes = mealDurationMinutes
        self.workoutTargetMinutes = workoutTargetMinutes
        self.quickAddDefaultDurationMinutes = quickAddDefaultDurationMinutes
        self.lowNotificationMode = lowNotificationMode
        self.useSimplifiedMode = useSimplifiedMode
    }

    var snapshot: DailyBudgetSnapshot {
        DailyBudgetSnapshot(
            minimumSleepHours: minimumSleepHours,
            minimumRestMinutes: minimumRestMinutes,
            targetWorkMinutes: targetWorkMinutes,
            maxFocusItems: maxFocusItems,
            mealDurationMinutes: mealDurationMinutes,
            workoutTargetMinutes: workoutTargetMinutes,
            quickAddDefaultDurationMinutes: quickAddDefaultDurationMinutes,
            lowNotificationMode: lowNotificationMode,
            useSimplifiedMode: useSimplifiedMode
        )
    }
}

// Keep the original placeholder model in the schema so local dev stores can open cleanly
// while the new planner models take over the actual app behavior.
@Model
final class Item {
    var timestamp: Date

    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
