# Agent Guidelines & Rules

## Code Formatting Verification
This project strictly enforces standard Dart formatting across all code.

Whenever you create or modify any Dart code:
1. Run `dart format .` (or `dart format <path_to_file>`) on modified files.
2. Verify formatting before completing the task:
   ```bash
   dart format --output=none --set-exit-if-changed .
   ```
3. Never leave unformatted Dart code in the repository.
