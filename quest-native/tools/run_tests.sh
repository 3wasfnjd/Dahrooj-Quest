#!/usr/bin/env bash
# Headless test suite (rules, goal, volley, park, main scene).
# Usage: tools/run_tests.sh [-- --report=out.txt]
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --xr-mode off --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --xr-mode off --path . res://tests/run_tests.tscn "$@" 2>&1 | grep -v "OpenXR-Loader"
exit "${PIPESTATUS[0]}"
