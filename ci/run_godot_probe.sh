#!/usr/bin/env bash
set -uo pipefail

SCRIPT_PATH="$1"
PASS_MARKER="$2"
LOG_FILE="$(mktemp)"

set +e
godot --headless --path . --script "$SCRIPT_PATH" 2>&1 | tee "$LOG_FILE"
GODOT_STATUS=${PIPESTATUS[0]}
set -e

if [[ $GODOT_STATUS -ne 0 ]]; then
  echo "Godot exited with status $GODOT_STATUS" >&2
  exit 1
fi

if grep -Eq 'SCRIPT ERROR:|ERROR: Failed to load script|P1_[A-Z0-9_]+_(FAIL|TIMEOUT)' "$LOG_FILE"; then
  echo "Probe emitted a script/load/failure error despite process exit 0." >&2
  exit 1
fi

if ! grep -Fq "$PASS_MARKER" "$LOG_FILE"; then
  echo "Expected PASS marker missing: $PASS_MARKER" >&2
  exit 1
fi
