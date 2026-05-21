# Otiosum Design Notes

Durable visual and interaction notes for design work.

## Product Direction
- Otiosum is a calm planning app focused on today, future planning, energy budget,
  protected time, and a later/jar backlog.
- UI should feel native, quiet, and task-focused rather than like a marketing page.
- Prefer dense but readable screens, strong hierarchy, and restrained decoration.

## Visual Language
- Use SF Pro style hierarchy with large iOS titles, compact body text, and clear
  secondary metadata.
- Favor soft off-white surfaces, subtle blue/green accent colors, and rounded iOS
  content areas.
- Preserve recurring concepts as reusable components: timeline row, energy budget,
  warning banner, action sheet, bottom composer, settings section, and jar list
  section.
- For iOS 26-inspired design work, use Apple iOS UI Kit guidance where available:
  Dynamic Island-safe status area, large rounded controls, segmented controls,
  bottom action sheets over dimmed content, and content-area buttons.

## Sketch Design Artifacts
- Keep generated Sketch documents structured with named pages, frames, groups,
  symbols/components, color tokens, and source references.
- Do not flatten app screens into PNG-only mockups unless the user explicitly asks
  for a raster reference sheet.

## 2026-04-28 Native Today Color Exploration
- Created `Artifacts/Otiosum-Today-Native-Color-Variants.sketch` as a native
  iOS-style redesign of the Today timeline screen.
- Direction: translate custom card-heavy controls toward Apple HIG/iOS 26 UI Kit
  patterns: large NavigationStack title, toolbar actions, inset grouped list rows,
  TextField composer, bordered/prominent buttons, and SF Symbol references.
- Avoid custom image assets in this direction. Keep icon layers named with
  `SF Symbol / <symbol-name>` so implementation can map them to
  `Image(systemName:)`.
- Proposed color directions:
  - Glacier Blue: most system-native and action-oriented.
  - Cypress Teal: closest to current calm/wellness tone but cooler and less
    custom-green.
  - Graphite Fig: more distinctive and reflective, with lower productivity-tool
    feel.
