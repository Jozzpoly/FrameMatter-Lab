#!/usr/bin/env bash
set -uo pipefail

LOG_FILE="$(mktemp)"
set +e
godot --headless --path . --editor --quit 2>&1 | tee "$LOG_FILE"
GODOT_STATUS=${PIPESTATUS[0]}
set -e

if [[ $GODOT_STATUS -ne 0 ]]; then
  echo "Godot import exited with status $GODOT_STATUS" >&2
  exit 1
fi

if grep -Eq 'SCRIPT ERROR:|ERROR: Failed to load script|Parse Error:|Compile Error:' "$LOG_FILE"; then
  echo "Godot import reported script parse/compile/load errors despite process exit 0." >&2
  exit 1
fi

echo "GODOT_IMPORT_GATE_PASS"
