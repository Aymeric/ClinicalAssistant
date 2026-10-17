## 2026-10-24 - Fast-path direct numeric parsing before regex evaluation
**Learning:** In Flutter/Dart apps processing large collections of health metrics, running `RegExp.hasMatch` on every record value before attempting `double.tryParse` creates regex execution overhead across rendering, signal analysis, and trend calculation hot loops.
**Action:** Always attempt `double.tryParse` first for standard numeric values, and reserve grouped number regex pattern matching for inputs that actually contain commas.

## 2026-10-25 - Single-pass HealthTrendPoint grouping and fast-path sorted checks
**Learning:** Constructing `HealthTrendPoint` directly during initial group partitioning prevents redundant numeric parsing and eliminates intermediate `List<HealthRecord>` allocations. Additionally, checking if `HealthTrendPoint` series are already sorted before calling `List.sort` avoids unnecessary $O(N \log N)$ operations and list clones.
**Action:** Parse numeric record values once during mapping and check chronological order before re-sorting already ordered time-series collections.
