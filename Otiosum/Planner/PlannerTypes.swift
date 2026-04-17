import Foundation

enum PlannerTab: String, CaseIterable, Identifiable, Sendable {
    case today
    case jar
    case upcoming
    case time
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .jar: "Jar"
        case .upcoming: "Upcoming"
        case .time: "Time"
        case .settings: "Settings"
        }
    }
}

enum PlannerItemKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case task
    case event
    case idea
    case protectedTime

    var id: String { rawValue }
}

enum PlannerItemSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case local
    case calendar
    case template

    var id: String { rawValue }
}

enum PlannerFlexibility: String, Codable, CaseIterable, Identifiable, Sendable {
    case locked
    case flexible
    case askBeforeMove

    var id: String { rawValue }
}

enum PreferredTimeWindow: String, Codable, CaseIterable, Identifiable, Sendable {
    case anytime
    case morning
    case afternoon
    case evening
    case night

    var id: String { rawValue }

    var title: String {
        switch self {
        case .anytime: "Any time"
        case .morning: "Morning"
        case .afternoon: "Afternoon"
        case .evening: "Evening"
        case .night: "Night"
        }
    }

    var startMinutes: Int {
        switch self {
        case .anytime: 9 * 60
        case .morning: 8 * 60
        case .afternoon: 13 * 60
        case .evening: 18 * 60
        case .night: 21 * 60
        }
    }

    var endMinutes: Int {
        switch self {
        case .anytime: 20 * 60
        case .morning: 12 * 60
        case .afternoon: 17 * 60
        case .evening: 21 * 60
        case .night: 23 * 60 + 30
        }
    }
}

enum ProtectedCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case sleep
    case meal
    case rest
    case workWindow
    case workout

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sleep: "Sleep"
        case .meal: "Meal"
        case .rest: "Recovery"
        case .workWindow: "Work window"
        case .workout: "Workout"
        }
    }
}

enum OverflowChoice: String, Codable, CaseIterable, Identifiable, Sendable {
    case nextSuitableDay
    case returnToJar
    case keepAnyway

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nextSuitableDay: "Move to another day"
        case .returnToJar: "Return to jar"
        case .keepAnyway: "Keep anyway"
        }
    }
}

enum CalendarShiftDecision: String, Codable, CaseIterable, Identifiable, Sendable {
    case moveOnlyInOtiosum
    case editRealEvent
    case keepFixed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .moveOnlyInOtiosum: "Move only in Otiosum"
        case .editRealEvent: "Edit Calendar event"
        case .keepFixed: "Keep fixed"
        }
    }
}

enum CalendarEditPolicy: String, Codable, CaseIterable, Identifiable, Sendable {
    case askEveryTime
    case localOnly
    case systemCalendar

    var id: String { rawValue }
}

enum InferredProgressStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case upcoming
    case likelyInProgress
    case gentlyLate
    case complete
    case protectedTime
    case waiting

    var id: String { rawValue }
}

enum GuardrailSeverity: String, Codable, CaseIterable, Identifiable, Sendable {
    case calm
    case attention

    var id: String { rawValue }
}

enum QuickCaptureContext: String, Codable, CaseIterable, Identifiable, Sendable {
    case today
    case jar

    var id: String { rawValue }
}

enum DropLane: String, CaseIterable, Identifiable, Sendable {
    case morning
    case afternoon
    case evening
    case night

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning: "Morning lane"
        case .afternoon: "Afternoon lane"
        case .evening: "Evening lane"
        case .night: "Night lane"
        }
    }

    var timeWindow: PreferredTimeWindow {
        switch self {
        case .morning: .morning
        case .afternoon: .afternoon
        case .evening: .evening
        case .night: .night
        }
    }
}

struct IconSuggestion: Equatable, Sendable {
    let symbolName: String
    let tintToken: String
    let emoji: String
}

struct PlannerItemSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let kind: PlannerItemKind
    let source: PlannerItemSource
    let suggestedIcon: String
    let tintToken: String
    let targetDurationMinutes: Int
    let minimumDurationMinutes: Int
    let scheduledDay: Date?
    let preferredStartMinutes: Int?
    let preferredTimeWindow: PreferredTimeWindow
    let flexibility: PlannerFlexibility
    let calendarEventID: String?
    let protectedCategory: ProtectedCategory?
    let notes: String
    let isCompleted: Bool
    let orderHint: Double
    let isInJar: Bool
    let forceAfterBedtime: Bool

    var isProtected: Bool {
        protectedCategory != nil || kind == .protectedTime || source == .template
    }
}

struct CalendarEventSnapshot: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let notes: String
    let isAllDay: Bool
}

struct CalendarLinkSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let calendarEventID: String
    let flexibility: PlannerFlexibility
    let editPolicy: CalendarEditPolicy
    let localOverrideStart: Date?
    let localOverrideEnd: Date?
}

struct DayTemplateSnapshot: Equatable, Sendable {
    let wakeUpMinutes: Int
    let sleepStartMinutes: Int
    let breakfastMinutes: Int
    let lunchMinutes: Int
    let dinnerMinutes: Int
    let quietStartMinutes: Int
    let quietDurationMinutes: Int
    let workoutMinutes: Int
    let workoutDurationMinutes: Int
    let includeWorkout: Bool
    let transitionBufferMinutes: Int

    static let `default` = DayTemplateSnapshot(
        wakeUpMinutes: 7 * 60 + 30,
        sleepStartMinutes: 22 * 60 + 30,
        breakfastMinutes: 8 * 60 + 15,
        lunchMinutes: 13 * 60,
        dinnerMinutes: 19 * 60,
        quietStartMinutes: 20 * 60 + 30,
        quietDurationMinutes: 60,
        workoutMinutes: 17 * 60 + 30,
        workoutDurationMinutes: 45,
        includeWorkout: true,
        transitionBufferMinutes: 10
    )
}

struct DailyBudgetSnapshot: Equatable, Sendable {
    let minimumSleepHours: Double
    let minimumRestMinutes: Int
    let targetWorkMinutes: Int
    let maxFocusItems: Int
    let mealDurationMinutes: Int
    let workoutTargetMinutes: Int
    let lowNotificationMode: Bool
    let useSimplifiedMode: Bool

    static let `default` = DailyBudgetSnapshot(
        minimumSleepHours: 8,
        minimumRestMinutes: 120,
        targetWorkMinutes: 6 * 60,
        maxFocusItems: 5,
        mealDurationMinutes: 40,
        workoutTargetMinutes: 45,
        lowNotificationMode: true,
        useSimplifiedMode: false
    )
}

struct PlannedBlock: Identifiable, Equatable, Sendable {
    let id: UUID
    let itemID: UUID
    let calendarEventID: String?
    let title: String
    let start: Date
    let end: Date
    let source: PlannerItemSource
    let kind: PlannerItemKind
    let flexibility: PlannerFlexibility
    let symbolName: String
    let tintToken: String
    let notes: String
    let protectedCategory: ProtectedCategory?
    let isCompleted: Bool
    let status: InferredProgressStatus
    let confidence: Double

    var durationMinutes: Int {
        Int(end.timeIntervalSince(start) / 60)
    }

    var isProtected: Bool {
        protectedCategory != nil || kind == .protectedTime || source == .template
    }
}

struct GuardrailWarning: Identifiable, Equatable, Sendable {
    let id = UUID()
    let message: String
    let detail: String
    let severity: GuardrailSeverity
}

struct OverflowIssue: Identifiable, Equatable, Sendable {
    let id = UUID()
    let itemID: UUID
    let title: String
    let message: String
    let displacedCategory: ProtectedCategory?
    let suggestedDate: Date
}

struct CalendarShiftProposal: Identifiable, Equatable, Sendable {
    let id = UUID()
    let calendarEventID: String
    let title: String
    let currentStart: Date
    let currentEnd: Date
    let suggestedStart: Date
    let suggestedEnd: Date
}

struct BudgetUsageSummary: Equatable, Sendable {
    let workMinutes: Int
    let restMinutes: Int
    let sleepMinutesProtected: Int
    let scheduledCount: Int
}

struct DayPlan: Equatable, Sendable {
    let day: Date
    let allBlocks: [PlannedBlock]
    let nowBlock: PlannedBlock?
    let nextBlock: PlannedBlock?
    let laterBlocks: [PlannedBlock]
    let protectedBlocks: [PlannedBlock]
    let warnings: [GuardrailWarning]
    let overflowIssues: [OverflowIssue]
    let shiftProposals: [CalendarShiftProposal]
    let budgetSummary: BudgetUsageSummary
}

struct InferenceContext: Equatable, Sendable {
    let now: Date
    let isSceneActive: Bool
    let lastUserInteraction: Date?
}

struct InferenceAssessment: Equatable, Sendable {
    let status: InferredProgressStatus
    let confidence: Double
}

extension Date {
    func startOfDay(using calendar: Calendar) -> Date {
        calendar.startOfDay(for: self)
    }

    func minutesSinceStartOfDay(using calendar: Calendar) -> Int {
        Int(timeIntervalSince(calendar.startOfDay(for: self)) / 60)
    }

    func adding(minutes: Int) -> Date {
        addingTimeInterval(TimeInterval(minutes * 60))
    }
}

extension Calendar {
    func date(on day: Date, minutesFromStartOfDay minutes: Int) -> Date {
        startOfDay(for: day).addingTimeInterval(TimeInterval(minutes * 60))
    }
}
