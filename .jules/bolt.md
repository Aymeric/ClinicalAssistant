## 2026-10-01 - Hoisting RegExp in Dart models and trend utilities
**Learning:** Instantiating `RegExp` in frequently called Dart functions (such as number/unit formatting or parsing reference ranges) causes regex compilation overhead on every invocation. Hoisting regex patterns to top-level `final` variables avoids re-compilation while remaining thread-safe and clear.
**Action:** Always check if `RegExp` is defined inside a hot function in Dart, and hoist it to a top-level `final` variable.
