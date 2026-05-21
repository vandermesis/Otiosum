# Otiosum Decisions

Record durable product and engineering decisions here. Keep entries short and
specific enough that a future agent can act on them.

## Current Decisions
- Keep planner domain behavior in `Otiosum/Planner`; avoid moving planning rules
  into SwiftUI view files.
- Keep accessibility identifiers stable and structured. Existing examples include
  `quick-add-field` and `timeline-task-done-<id>`.
- Prefer deterministic tests with fixed dates/calendars and explicit launch
  arguments for UI setup, such as `UITEST` and `UITEST_TIMELINE_TASK`.
- Recent commit style is short and imperative, for example `Fix simulator crash`
  or `Quick add icon suggestion`.

## Decision Log Template
Use this format for future decisions:

```md
### YYYY-MM-DD - Decision title
Decision:
Context:
Consequences:
```
