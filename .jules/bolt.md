## 2026-10-27 - Single-pass category and source count aggregation in ExportPage
**Learning:** `ExportPage.build` was running separate full-collection passes: `.any(isSyntheticRecord)`, `.any(!isSyntheticRecord)`, `.where().map().toSet()` for available categories and sources, and then for *every* individual filter chip (14 categories + all unique sources), running `widget.records.where(...).length`. For large record sets, this repeated full O(N) traversals $14 + S + 4$ times per build and allocated dozens of closure iterators.
**Action:** In a single pass over `widget.records`, track real/synthetic presence and increment category and source frequency counters simultaneously. Read directly from the count maps during filter chip rendering.

## 2026-11-03 - Single-pass numeric stats and fast-path parsing for cardiac rhythm cards
**Learning:** In cardiac analysis components such as `HeartRhythmAnalysisCard`, computing summary metrics (latest, longitudinal average, and peak) across resting, walking, workout, and HRV categories previously generated multiple intermediate arrays (`.map().whereType<double>().toList()` and spread collections `[...resting, ...general, ...walking]`) and invoked ad-hoc regular expressions (`RegExp(r'[^\d.]')`) repeatedly on every build frame.
**Action:** Compute latest, sum/average, and peak in a single-pass accumulator record per category, and fast-path numeric parsing using `parseHealthRecordValue` with a hoisted fallback regex instead of per-item pattern instantiations.

## 2026-10-26 - Index-based string trimming instead of regexes for number formatting
**Learning:** `formatSensibleNumber` is executed hundreds of times across chart painters, list row renderings, aggregations, and export generation. Using sequential `RegExp` replacements (`replaceFirst(RegExp(r'0+$'))` and `replaceFirst(RegExp(r'\.$'))`) for every formatted floating-point number triggered repeated regex pattern matching and intermediate string allocations in the hot rendering path.
**Action:** Fast-path `value is int` directly to `.toString()` and perform backward index-based trimming with `fixed.codeUnitAt` rather than evaluating regular expressions on formatted decimal strings.

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

## 2026-10-24 - Pre-filter target series keys during health import signal analysis
**Learning:** Signal analysis evaluates whether imported readings trigger trend threshold changes or multi-reading directional patterns across historical health records. Parsing numbers, allocating reading wrappers, grouping, and sorting every metric series in `allRecords` incurs significant CPU and heap allocation overhead, even though only series containing at least one newly imported record can ever produce a signal.
**Action:** Single-pass `newlyImported` records to collect category counts and relevant series keys, and use `relevantKeys.contains(key)` to skip non-matching records when processing `allRecords`.

## 2026-10-24 - Streaming selection for top-K recent health records
**Learning:** Copying and sorting the entire `records` collection using `[...records]..sort(...)` to pick only the top 4 recent entries during `OverviewPage` widget builds allocates full array copies on the heap and incurs O(N log N) sorting overhead on every UI render frame.
**Action:** Use a streaming single-pass insertion array (`selectLatestRecords`) to track top-K elements in O(N) time with minimal allocations.

## 2026-10-24 - Hoist context parsing regex and fast-path string checks on health records
**Learning:** `HealthRecord.measurementContext` was instantiating and compiling a new case-insensitive regular expression on every access when `record.notes` was populated. Because `measurementContext` is queried across trend series point mapping, context chip generation, and point filtering, re-compiling the regex on every record note introduced CPU overhead.
**Action:** Hoist pattern expressions into top-level static regexes and guard them with fast-path substring containment checks (`contains('context:')`) before invoking the regex engine.
