## 2026-10-04 - Code formatting check in CI
**Learning:** CI checks include `dart format --output=none --set-exit-if-changed .` which fails if any Dart file in the repository is not formatted with standard `dart format`.
**Action:** Always run `dart format .` on all files before submitting changes.

## 2026-10-05 - PIN Keypad Progress Live Region
**Learning:** Keypad dot indicators without semantics fail to inform screen reader users of input progress. Wrapping the dot row in `Semantics(label: '${_enteredPin.length} of 4 digits entered', liveRegion: true, child: ExcludeSemantics(...))` provides real-time accessibility feedback on digit entry.
**Action:** Always wrap visual PIN / step progress indicators in a live region Semantics widget with ExcludeSemantics on decorative child dots.
