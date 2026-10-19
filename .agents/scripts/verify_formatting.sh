#!/usr/bin/env bash
# Consume stdin payload
cat > /dev/null

# Move to workspace root (parent of .agents)
WORKSPACE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$WORKSPACE_DIR" || exit 0

# Check formatting
if dart format --output=none --set-exit-if-changed . > /dev/null 2>&1; then
  echo "{}"
else
  echo '{"decision": "continue", "reason": "Dart formatting verification failed. Unformatted Dart code detected. Please run `dart format .` before finishing."}'
fi
