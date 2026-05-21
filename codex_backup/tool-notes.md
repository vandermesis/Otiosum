# Otiosum Tool Notes

Known tool constraints and stable usage patterns.

## Available MCP Servers and Tools
This project has several MCP/tool families available in Codex. Availability can
vary by session, so verify with `tool_search` or the current tool list when a
task depends on a specific server.

### Primary Tool Choices for Otiosum
- `mcp__xcode__`: use for Xcode-aware Swift work when available, especially
  `DocumentationSearch`, `RenderPreview`, and `ExecuteSnippet`.
- XcodeBuildMCP skills/tools: use for build, run, simulator debugging, ETTrace,
  and memory graph workflows when the task needs an app-level iOS workflow.
- `mcp__sketch__`: use for Sketch document inspection, generation, export, and
  visual design work. See the Sketch MCP constraints below.
- Figma MCP/app tools: use when the user provides Figma links, asks for Figma
  design work, Code Connect, design systems, or web-to-Figma capture. Always use
  the `figma:figma-use` skill before Figma writes.
- Browser Use plugin or Playwright skill: use for real browser inspection,
  screenshots, and local web UI verification. Prefer Browser Use when the user
  explicitly asks to open or inspect a browser target.
- `mcp__node_repl__`: use for JavaScript execution, quick data transforms,
  rendering checks, and reusable Node REPL state.
- Zeplin MCP: use when the user provides Zeplin screen/component URLs or needs
  Zeplin assets downloaded.
- GitHub plugin/skills: use for PRs, issues, CI triage, publishing, and review
  comment workflows.
- Documents, Presentations, and Spreadsheets plugins: use for `.docx`, slide
  decks, and spreadsheet tasks respectively.
- `codex_app.automation_update`: use for reminders, monitors, repeated tasks,
  and thread wakeups.

### Skill Inventory Snapshot
Observed local skill inventory on 2026-04-28:
- 99 local/system skills across `/Users/vandermesis/.codex/skills` and
  `/Users/vandermesis/.agents/skills`.
- 34 plugin-provided skills under `/Users/vandermesis/.codex/plugins/cache`.
- Key Otiosum-relevant skill groups include Swift/SwiftUI, SwiftData, Swift
  concurrency, Swift Testing, iOS 26 platform, iOS HIG/accessibility/security,
  App Intents, widgets, StoreKit, CloudKit, MapKit, HealthKit, Core ML,
  debugging/instruments, Sketch implementation, Figma, GitHub, Browser Use,
  documents, presentations, and spreadsheets.

When a task matches a skill, read that skill's `SKILL.md` before acting. Do not
bulk-load all skills; open only the relevant file(s).

## Sketch MCP
When generating or editing Sketch documents through Sketch MCP, use the stable
subset of the Sketch JavaScript API.

### Text Layer Constraints
- Create text layers with `fontFamily`, `fontSize`, and `textColor` only.
- Do not pass numeric `fontWeight` in the `Text` style object; it can trigger
  Objective-C runtime errors.
- Do not pass `alignment` in the `Text` style object during layer creation; it can
  also trigger Objective-C runtime errors.
- Avoid naming helper functions `T`; that name can collide with Sketch's plugin
  runtime. Prefer explicit names like `tx`, `makeText`, or `textLayer`.

### Sketch Generation Practices
- Use named frames, groups, and layers so manual refinement remains easy.
- Create component pages and Symbol Masters for reusable UI when practical.
- Create token/reference pages for colors, typography notes, and source images.
- If using Apple iOS UI Kit documents as guidance, inspect them live through Sketch
  MCP first, then recreate app-specific components rather than flattening PNGs into
  a single image layer.
- For exports, always pass both `output` and `filename` options.

## Local Build Tools
- Use `xcodebuild` from the repository root for builds and tests unless a task
  specifically requires Xcode UI/debugger tooling.
- Prefer non-interactive shell commands.
