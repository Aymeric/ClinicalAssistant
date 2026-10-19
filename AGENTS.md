# Agent Guidelines & Rules

## Code Quality, Formatting & Static Analysis
This project strictly enforces standard Dart formatting and clean static analysis across all code, matching CI checks.

Whenever you create or modify any Dart code:
1. Run `dart format .` (or `dart format <path_to_file>`) on modified files.
2. Verify formatting before completing the task:
   ```bash
   dart format --output=none --set-exit-if-changed .
   ```
3. Verify static analysis with fatal warnings and fatal infos before completing:
   ```bash
   flutter analyze --fatal-infos --fatal-warnings
   ```
4. Never leave unformatted code or analyzer issues in the repository.
