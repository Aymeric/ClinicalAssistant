## 2026-09-30 - Top-Level RegExp Caching in Dart Data Processing
**Learning:** In Dart, instantiating `RegExp` inside functions or loops repeatedly compiles the regex state machine during dataset iteration.
**Action:** Extract reusable `RegExp` instances to top-level `final` variables in data models and calculation modules.
