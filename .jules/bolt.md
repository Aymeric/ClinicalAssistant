## 2026-02-23 - Reuse Compiled RegExp Instances in Hot Paths
**Learning:** Instantiating `RegExp(...)` inside hot functions (such as `parseHealthRecordValue`, `formatSensibleNumber`, `parseHealthReferenceRange`, and `_parseFhirDate`) forces the Dart VM to repeatedly recompile regular expression patterns, introducing CPU overhead and GC pressure.
**Action:** Use top-level or `static final` compiled `RegExp` instances for frequently executed patterns across health record processing, trends parsing, and FHIR import/export.
