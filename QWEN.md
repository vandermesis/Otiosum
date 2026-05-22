# Otiosum — Project Context

## Overview
Otiosum is a SwiftUI iOS daily planner app featuring calendar integration, routine templates, and intelligent time-slot scheduling. The app orchestrates local tasks, system calendar events, and day-templates into a coherent daily plan with guardrail warnings and conflict resolution.

## Architecture

```
Views (SwiftUI)
  → ViewModels (PlannerShellViewModel, PlannerViewModel)
    → PlannerStore (@Observable, @MainActor)
      → PlannerEngine / TimelineScheduler / Services
        → SwiftData Models
```

### Directory Structure
```
Otiosum/
├── App.swift              — App entry point, SwiftData container
├── Models/
│   └── PlannerModels.swift — SwiftData @Model classes
├── Planner/
│   ├── PlannerTypes.swift      — Domain enums and snapshot structs
│   ├── PlannerEngine.swift     — Core planning algorithm
│   ├── PlannerStore.swift      — @Observable state management
│   └── TimelineScheduler.swift — Time-slot scheduling with sleep protection
├── Views/                  — SwiftUI screens (Today, Upcoming, Jar, Settings, TimeWheel)
└── Services/
    ├── SystemCalendarService   — EventKit calendar bridge
    ├── IconSuggester           — SF Symbol icon suggestions
    ├── InferenceEngine         — Progress/status inference
    └── IconCatalogDatabase     — SF Symbols database
```

## Core Domain Types (PlannerTypes.swift)

### Enums
- **PlannerItemSource** — `local`, `calendar`, `template`
- **PlannerFlexibility** — `locked`, `flexible`, `askBeforeMove`
- **PreferredTimeWindow** — `morning`, `afternoon`, `evening`, `night`
- **RoutineRole** — `sleep`, `meal`, `rest`, `workWindow`, `workout`
- **InferredProgressStatus** — Inferred task completion state
- **GuardrailSeverity** — Warning severity levels

### Snapshot Structs
- **EventSnapshot** — Read-only view of an event for planning
- **PlannedBlock** — A scheduled block in the timeline (start, duration, content)
- **DayPlan** — Full daily plan with ordered blocks and warnings

## SwiftData Models (PlannerModels.swift)

| Model | Purpose |
|-------|---------|
| **Event** | Core event/task entity with title, time, flexibility, source |
| **CalendarLink** | Bridges EventKit external events to local planning |
| **DayTemplate** | Reusable routine templates (sleep, meals, work windows) |
| **DailyBudget** | Time/energy budget constraints per day |
| **IconCatalogSymbol** | Cached SF Symbol metadata for icon picker |
| **Item** | Placeholder, not yet used |

## Key Components

### PlannerEngine
`PlannerEngine.plan()` orchestrates the daily planning pipeline:
1. Collects template blocks (routines)
2. Fetches calendar events via SystemCalendarService
3. Gathers local items from SwiftData
4. Runs conflict resolution and guardrail checks
5. Delegates time-slot assignment to TimelineScheduler
6. Returns a `DayPlan` with ordered blocks and warnings

### PlannerStore
`@Observable` store on `@MainActor` managing:
- UI state and planning results
- Quick capture flow (add tasks from Today screen)
- Event CRUD operations
- Calendar permission/decision handling
- "Too much today" threshold prompts

### TimelineScheduler
Handles time-slot assignment with:
- Sleep collision detection and protection
- Block compaction (minimizing gaps)
- Flexibility-aware scheduling (locked blocks anchor first)

## Build & Test Commands

Run from repository root (`/Users/vandermesis/Developer/Otiosum`):

```bash
# Build
xcodebuild -project Otiosum.xcodeproj -scheme Otiosum -configuration Debug build

# All tests (unit + UI)
xcodebuild -project Otiosum.xcodeproj -scheme Otiosum -destination 'platform=iOS Simulator,name=iPhone 17' test

# Unit tests only (faster)
xcodebuild -project Otiosum.xcodeproj -scheme Otiosum -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:OtiosumTests
```

## Coding Conventions
- **Indentation:** 4 spaces
- **Naming:** `UpperCamelCase` for types, `lowerCamelCase` for members
- **File structure:** One primary type per file, domain-specific names (e.g., `PlannerStore`, `IconSuggester`)
- **SwiftUI:** Small dedicated views, tested planner logic in view models/services
- **Accessibility:** Stable accessibility identifiers on interactive elements
- **Dependencies:** No new third-party packages without discussion

## Testing
- **Unit tests:** Swift Testing (`@Test`, `#expect`) in `OtiosumTests/`
- **UI tests:** XCTest in `OtiosumUITests/`
- Name tests after observable behavior
- Keep fixtures deterministic (especially for date/calendar/planner ordering logic)
- Add/update tests when changing `Planner/`, `Services/`, or user-visible flows

## Agent Skill Reference
When working on this codebase, reference these Axiom skills as applicable:
- **axiom-build** — Build failures, Xcode issues, simulator problems
- **axiom-swiftui** — Views, navigation, layout, animations, SwiftUI patterns
- **axiom-testing** — Unit/UI tests, test architecture, Swift Testing vs XCTest
- **axiom-concurrency** — Async/await, actors, `@MainActor`, `Sendable`
- **axiom-data** — SwiftData, Core Data, persistence, migrations
- **axiom-design** — HIG, Liquid Glass, SF Symbols, typography
- **axiom-accessibility** — VoiceOver, Dynamic Type, contrast, WCAG

## Commit & PR Conventions
- Short, imperative summaries (e.g., `Fix UI test`, `Remove event kinds`)
- One behavior or refactor per commit
- PRs should include: summary, linked issue, test evidence (exact commands), screenshots for UI changes
