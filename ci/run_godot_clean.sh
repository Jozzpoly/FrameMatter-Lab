#!/usr/bin/env bash
set -uo pipefail

SCRIPT_PATH="$1"
LOG_FILE="$(mktemp)"
trap 'rm -f "$LOG_FILE"' EXIT

set +e
godot --headless --path . --script "$SCRIPT_PATH" 2>&1 | tee "$LOG_FILE"
GODOT_STATUS=${PIPESTATUS[0]}
set -e

if [[ $GODOT_STATUS -ne 0 ]]; then
  echo "Godot probe exited with status $GODOT_STATUS: $SCRIPT_PATH" >&2
  exit 1
fi

# Historical probes now obey the same evidence floor as P1: a nominally
# successful process may not hide an engine/script ERROR. Warnings remain
# visible evidence; any ERROR must be investigated or explicitly redesigned.
if grep -Eq '^ERROR:|SCRIPT ERROR:' "$LOG_FILE"; then
  echo "Godot probe emitted an engine/script error despite process exit 0: $SCRIPT_PATH" >&2
  exit 1
fi
