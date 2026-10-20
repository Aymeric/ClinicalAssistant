## 2026-10-24 - Fast-path direct numeric parsing before regex evaluation
**Learning:** In Flutter/Dart apps processing large collections of health metrics, running `RegExp.hasMatch` on every record value before attempting `double.tryParse` creates regex execution overhead across rendering, signal analysis, and trend calculation hot loops.
**Action:** Always attempt `double.tryParse` first for standard numeric values, and reserve grouped number regex pattern matching for inputs that actually contain commas.

## 2026-10-24 - Cache reference range parsing and fast-path exact unit comparisons
**Learning:** Reference range parsing uses multiple named-group regular expressions (`_referenceRangePattern` and `_referenceThresholdPattern`) that run on every lab record during chart painting, lab result summaries, and signal analysis. Caching parsed ranges in a bounded FIFO map and using direct equality checks before regex whitespace normalization drastically reduces CPU overhead.
**Action:** Cache parsed reference range objects by `(sourceText, expectedUnit)` and perform fast equality checks on unit strings before falling back to regex whitespace normalization.

## 2026-10-24 - Cache clinical guideline mapping and avoid inline RegExp compilation
**Learning:** `ClinicalGuidelineCatalog.findRelatedGuidelines` evaluates token sets, LOINC mappings, and multiple string pattern checks for every record row rendered in lists and detail sheets. Instantiating local `RegExp` objects on every evaluation causes regex compilation thrashing.
**Action:** Extract RegExp patterns into static fields and cache mapping results in a bounded FIFO cache map.
