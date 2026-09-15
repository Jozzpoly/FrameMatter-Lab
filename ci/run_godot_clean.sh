#!/usr/bin/env bash
set -uo pipefail

SCRIPT_PATH="$1"
LOG_FILE="$(mktemp)"

set +e
godot --headless --path . --script "$SCRIPT_PATH" 2>&1 | tee "$LOG_FILE"
GODOT_STATUS=${PIPESTATUS[0]}
set -e

if [[ $GODOT_STATUS -ne 0 ]]; then
  echo "Godot probe exited with status $GODOT_STATUS: $SCRIPT_PATH" >&2
  exit 1
fi

if grep -Eq 'SCRIPT ERROR:|ERROR: Failed to load script|Parse Error:|Compile Error:' "$LOG_FILE"; then
  echo "Godot probe emitted a script parse/compile/load error despite process exit 0: $SCRIPT_PATH" >&2
  exit 1
fi
