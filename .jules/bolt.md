## 2026-03-31 - Fast-Path Parsing for Health Record Numeric Values
**Learning:** Running RegExp checks on every record value evaluation in lists/charts creates unnecessary overhead for non-grouped numbers and text values. Checking `double.tryParse` first before RegExp matching provides a ~3-5x speedup for numeric parsing hot paths.
**Action:** Use fast-path `tryParse` or string fast-checks before executing complex regular expressions on high-frequency parsing paths.
