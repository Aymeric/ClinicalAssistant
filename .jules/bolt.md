## 2026-10-24 - Fast-path direct numeric parsing before regex evaluation
**Learning:** In Flutter/Dart apps processing large collections of health metrics, running `RegExp.hasMatch` on every record value before attempting `double.tryParse` creates regex execution overhead across rendering, signal analysis, and trend calculation hot loops.
**Action:** Always attempt `double.tryParse` first for standard numeric values, and reserve grouped number regex pattern matching for inputs that actually contain commas.

## 2026-10-24 - Cache reference range parsing and fast-path exact unit comparisons
**Learning:** Reference range parsing uses multiple named-group regular expressions (`_referenceRangePattern` and `_referenceThresholdPattern`) that run on every lab record during chart painting, lab result summaries, and signal analysis. Caching parsed ranges in a bounded FIFO map and using direct equality checks before regex whitespace normalization drastically reduces CPU overhead.
**Action:** Cache parsed reference range objects by `(sourceText, expectedUnit)` and perform fast equality checks on unit strings before falling back to regex whitespace normalization.

## 2026-10-24 - Cache clinical guideline matching and replace list scans with map lookups
**Learning:** Health record list rows and detail widgets evaluate `ClinicalGuidelineCatalog.hasRelatedGuidelines` during rendering. Querying static guideline catalogs using `.where().firstOrNull` linear list iteration and per-call regex tokenization causes repeated string parsing and regex execution on every list render and widget update.
**Action:** Use static ID-indexed maps for static catalog lookups, compile regexes statically, and cache pure relation query results in a bounded map.

## 2026-10-24 - Single-pass candidate tracking for series summary calculations
**Learning:** Grouping records into lists and sorting each list to find the latest record per series ID allocates candidate list objects and incurs O(N log N) sorting overhead during overview page builds.
**Action:** Use a `Map<String, Record>` with streaming O(1) timestamp comparison to track the latest record per series ID in a single pass over records.

## 2026-10-24 - Single-pass bounds calculation and allocation-free custom painter loops
**Learning:** `CustomPainter.paint` runs on every animation frame and gesture interaction. Creating temporary lists via spread literals (`[...]`), `.map()`, and `List.generate()` in `paint()` causes heap allocations and garbage collection pressure during chart dragging and inspection.
**Action:** Compute min/max chart bounds in a single pass over existing collections without intermediate list allocations, and perform direct inline index lookups instead of generating index arrays on every paint frame.

## 2026-10-24 - Pre-compute workout window boundaries and map lookups for activity sample aggregation
**Learning:** During health data imports, associating activity samples with workouts executed `workouts.where().toList()` and recalculated workout start/end `DateTime`s in UTC and max duration bounds on every activity sample point. With thousands of activity samples, this incurred O(N * M) redundant `DateTime` conversions and array allocations.
**Action:** Pre-compute workout window boundaries (`_WorkoutWindow`) and map workouts by UUID once prior to the activity sample iteration loop.

## 2026-10-24 - Streaming selection for top-K recent health records
**Learning:** Copying and sorting the entire `records` collection using `[...records]..sort(...)` to pick only the top 4 recent entries during `OverviewPage` widget builds allocates full array copies on the heap and incurs O(N log N) sorting overhead on every UI render frame.
**Action:** Use a streaming single-pass insertion array (`selectLatestRecords`) to track top-K elements in O(N) time with minimal allocations.
