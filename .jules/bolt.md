## 2026-10-24 - Fast-path direct numeric parsing before regex evaluation
**Learning:** In Flutter/Dart apps processing large collections of health metrics, running `RegExp.hasMatch` on every record value before attempting `double.tryParse` creates regex execution overhead across rendering, signal analysis, and trend calculation hot loops.
**Action:** Always attempt `double.tryParse` first for standard numeric values, and reserve grouped number regex pattern matching for inputs that actually contain commas.

## 2026-10-24 - Bounded caching of reference range parsing and single-pass trend grouping
**Learning:** Parsing complex reference range regexes repeatedly across large health record collections creates heavy regex execution and object allocation overhead during chart builds and lab result summary calculations.
**Action:** Cache parsed reference ranges in a bounded map cache, short-circuit unit equality checks, and parse numeric record values in a single pass during trend grouping.
