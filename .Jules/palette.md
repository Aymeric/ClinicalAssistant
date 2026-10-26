## 2026-10-04 - Code formatting check in CI
**Learning:** CI checks include `dart format --output=none --set-exit-if-changed .` which fails if any Dart file in the repository is not formatted with standard `dart format`.
**Action:** Always run `dart format .` on all files before submitting changes.

## 2026-10-25 - Live Region Semantics for PIN Keypad Progress
**Learning:** Custom PIN dots indicators lack screen reader feedback when digits are typed or cleared. Wrapping the indicator in a `Semantics` widget with `liveRegion: true` and an explicit entry count label (`${_enteredPin.length} of 4 digits entered`) provides real-time progress announcements for assistive technologies.
**Action:** Always wrap non-text progress or state indicators in live-region `Semantics` for instant screen reader feedback.

## 2026-10-26 - Accessible Custom Preset Chips with Tooltip and Semantics
**Learning:** Custom chip controls built with Material/InkWell that display abbreviated text (such as "7D", "30D", "1Y") lack tooltip context on hover and button/selection semantics for screen readers.
**Action:** Wrap custom chip controls in `Tooltip` and `Semantics(button: true, selected: selected, label: ...)` to expand abbreviations for assistive technologies and mouse hover.

## 2026-10-27 - Exclude Child Semantics When Setting Custom Summary Label
**Learning:** When wrapping a complex card or composite widget tree in `Semantics(label: ..., button: true)` to provide a consolidated summary for screen readers, omitting `excludeSemantics: true` causes screen readers to read both the custom summary label and the individual child `Text` widgets, leading to duplicate announcements.
**Action:** Always set `excludeSemantics: true` on parent `Semantics` widgets that supply a complete custom summary label over composite UI elements.

## 2026-10-28 - Structured Semantics Label for Complex Health Record Rows
**Learning:** List items representing health records contain multiple pieces of context (title, value, out-of-range status, category, date, source, guidelines). Constructing a single, comma-separated structured string for `Semantics(label: ..., button: onTap != null, excludeSemantics: true)` provides screen readers with a cohesive sentence-like summary instead of disjointed fragments when navigating record lists.
**Action:** Aggregate complex list row metadata into a structured, comma-separated `Semantics` label when wrapping interactive list items.
