# Otiosum Project Memory

This file is durable project context for future Codex sessions.

## Working Preferences
- Answer the user in Polish.
- Prefer focused, scoped changes over broad rewrites.
- Read local project notes before making design, tooling, or architecture changes.
- Update the relevant project memory file after every significant project change,
  especially when adding architecture decisions, design direction, reusable
  components, workflow preferences, or tool constraints.
- Preserve user changes in the worktree; never revert unrelated files.
- Keep generated artifacts organized under `Artifacts/` unless the user asks for a
  different destination.

## Project Shape
- `Otiosum` is a SwiftUI iOS app target.
- Core planning logic lives under `Otiosum/Planner`.
- UI screens and components live under `Otiosum/Views`.
- Services and integrations live under `Otiosum/Services`.
- Unit tests use Swift Testing in `OtiosumTests`; UI tests use XCTest in
  `OtiosumUITests`.

## Persistent Notes
- Use `.codex/decisions.md` for stable architecture and product decisions.
- Use `.codex/design-notes.md` for visual language, components, and design tokens.
- Use `.codex/tool-notes.md` for Sketch MCP, Xcode, simulator, and other tooling
  constraints, including the current MCP server and skill inventory snapshot.
