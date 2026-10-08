## 2026-10-24 - Fast-path direct numeric parsing before regex evaluation
**Learning:** In Flutter/Dart apps processing large collections of health metrics, running `RegExp.hasMatch` on every record value before attempting `double.tryParse` creates regex execution overhead across rendering, signal analysis, and trend calculation hot loops.
**Action:** Always attempt `double.tryParse` first for standard numeric values, and reserve grouped number regex pattern matching for inputs that actually contain commas.

## 2026-10-25 - Single-pass value parsing and memoization of reference ranges in health trends
**Learning:** `buildHealthTrendSeries` and `buildLatestLabResultSummaries` previously re-parsed record numeric values multiple times during grouping and candidate extraction. Additionally, parsing reference range strings using complex regex with named capture groups ran repeatedly on identical strings across records.
**Action:** Construct `HealthTrendPoint` instances once during initial iteration to reuse parsed numeric values, and cache parsed reference ranges in a bounded lookup table.
