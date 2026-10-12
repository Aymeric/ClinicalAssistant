## 2026-10-24 - Fast-path direct numeric parsing before regex evaluation
**Learning:** In Flutter/Dart apps processing large collections of health metrics, running `RegExp.hasMatch` on every record value before attempting `double.tryParse` creates regex execution overhead across rendering, signal analysis, and trend calculation hot loops.
**Action:** Always attempt `double.tryParse` first for standard numeric values, and reserve grouped number regex pattern matching for inputs that actually contain commas.

## 2026-10-25 - Non-numeric lab records act as tombstones for older numeric flags
**Learning:** In lab summary evaluations, non-numeric results (e.g. "Not detected") recorded after numeric values must be tracked during candidate selection. Omitting non-numeric records from candidate tracking during fast-path filtering causes older numeric records to be mistakenly flagged as active trends.
**Action:** Always track candidate series across all records before filtering out non-numeric values for trend calculations.
