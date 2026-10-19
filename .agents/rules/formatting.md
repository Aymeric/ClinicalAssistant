# Code Formatting & Static Analysis Verification Rule

## Scope
This rule applies to all Dart code (`.dart` files) in this workspace.

## Requirements
Whenever any Dart file is created, edited, or refactored:
1. **Auto-Format**: Run `dart format .` (or `dart format <path_to_file>`) using `run_command` immediately after modifying Dart files.
2. **Verify Formatting**: Ensure formatting complies with standard Dart guidelines by verifying with:
   ```bash
   dart format --output=none --set-exit-if-changed .
   ```
3. **Verify Static Analysis**: Ensure code passes strict analysis matching CI:
   ```bash
   flutter analyze --fatal-infos --fatal-warnings
   ```
4. **No Unformatted Code or Lints**: Never conclude a response or mark a task as complete if any Dart file has unformatted code or analyzer warnings/infos.
