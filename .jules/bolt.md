## 2026-10-24 - Fast-path direct numeric parsing before regex evaluation
**Learning:** In Flutter/Dart apps processing large collections of health metrics, running `RegExp.hasMatch` on every record value before attempting `double.tryParse` creates regex execution overhead across rendering, signal analysis, and trend calculation hot loops.
**Action:** Always attempt `double.tryParse` first for standard numeric values, and reserve grouped number regex pattern matching for inputs that actually contain commas.

## 2026-10-25 - Single-pass point parsing and frequency map grouping in Flutter builds
**Learning:** In Flutter widget build loops over large collections, repeated linear filtering (`records.where`) for pinned metrics and category counts creates $O(P \times N)$ and $O(C \times N)$ iteration overhead per frame build. Additionally, creating intermediate `HealthRecord` groups before converting to `HealthTrendPoint` parses record values twice.
**Action:** Always group records into a map and parse values into `HealthTrendPoint` in a single pass during initial grouping, and use frequency maps for category counts in UI builds.
