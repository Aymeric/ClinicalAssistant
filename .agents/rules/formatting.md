# Code Formatting Verification Rule

## Scope
This rule applies to all Dart code (`.dart` files) in this workspace.

## Requirements
Whenever any Dart file is created, edited, or refactored:
1. **Auto-Format**: Run `dart format .` (or `dart format <path_to_file>`) using `run_command` immediately after modifying Dart files.
2. **Verify Formatting**: Ensure formatting complies with standard Dart guidelines by verifying with:
   ```bash
   dart format --output=none --set-exit-if-changed .
   ```
3. **No Unformatted Code**: Never conclude a response or mark a task as complete if any Dart file has unformatted code or formatting discrepancies.
4. **Static Analysis & Syntax Check**: If formatting reports any issues or fails, inspect and resolve syntax or formatting errors before concluding.
