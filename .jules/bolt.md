## 2026-10-24 - Fast-path direct numeric parsing before regex evaluation
**Learning:** In Flutter/Dart apps processing large collections of health metrics, running `RegExp.hasMatch` on every record value before attempting `double.tryParse` creates regex execution overhead across rendering, signal analysis, and trend calculation hot loops.
**Action:** Always attempt `double.tryParse` first for standard numeric values, and reserve grouped number regex pattern matching for inputs that actually contain commas.

## 2026-10-25 - Single-pass pinned metrics lookup over pre-sorted records
**Learning:** Filtering and sorting a large records list inside a loop for each pinned series ID creates $O(P \times N)$ string formatting, filtering, and sorting overhead on widget rebuilds.
**Action:** Leverage pre-sorted record lists (e.g. newest-first) and construct a lookup map in a single $O(N)$ pass with early-exit when extracting latest metrics by series ID.
