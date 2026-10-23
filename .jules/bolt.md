## 2026-10-24 - Fast-path direct numeric parsing before regex evaluation
**Learning:** In Flutter/Dart apps processing large collections of health metrics, running `RegExp.hasMatch` on every record value before attempting `double.tryParse` creates regex execution overhead across rendering, signal analysis, and trend calculation hot loops.
**Action:** Always attempt `double.tryParse` first for standard numeric values, and reserve grouped number regex pattern matching for inputs that actually contain commas.

## 2026-10-24 - Cache reference range parsing and fast-path exact unit comparisons
**Learning:** Reference range parsing uses multiple named-group regular expressions (`_referenceRangePattern` and `_referenceThresholdPattern`) that run on every lab record during chart painting, lab result summaries, and signal analysis. Caching parsed ranges in a bounded FIFO map and using direct equality checks before regex whitespace normalization drastically reduces CPU overhead.
**Action:** Cache parsed reference range objects by `(sourceText, expectedUnit)` and perform fast equality checks on unit strings before falling back to regex whitespace normalization.

## 2026-10-24 - Cache clinical guideline matching and replace list scans with map lookups
**Learning:** Health record list rows and detail widgets evaluate `ClinicalGuidelineCatalog.hasRelatedGuidelines` during rendering. Querying static guideline catalogs using `.where().firstOrNull` linear list iteration and per-call regex tokenization causes repeated string parsing and regex execution on every list render and widget update.
**Action:** Use static ID-indexed maps for static catalog lookups, compile regexes statically, and cache pure relation query results in a bounded map.

## 2026-10-24 - Single-pass latest record tracking in lab result summarization
**Learning:** Re-grouping lab records into candidate lists and sorting each list (`O(M log M)`) during lab summary generation introduced unnecessary collection allocations and double iteration overhead across rendering loops on the Overview page.
**Action:** Track the single latest record per series ID in a map in O(N) time during a single pass over health records rather than constructing and sorting candidate lists.
