#!/usr/bin/env bash
# Headless test suite (rules, goal, volley, park, main scene).
# Usage: tools/run_tests.sh [-- --report=out.txt]
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
# A fresh user:// for every run, so a save left by play or an earlier run never changes results.
TEST_DATA="$(mktemp -d)"
trap 'rm -rf "$TEST_DATA"' EXIT
export XDG_DATA_HOME="$TEST_DATA"
"$GODOT" --headless --xr-mode off --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --xr-mode off --path . res://tests/run_tests.tscn "$@" 2>&1 | grep -v "OpenXR-Loader"
exit "${PIPESTATUS[0]}"
