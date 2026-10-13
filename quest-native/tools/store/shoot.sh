#!/usr/bin/env bash
# One store image from the real game: tools/store/shoot.sh WxH out.png [-- store_shot args]
# (see store_shot.gd). Needs xvfb-run and Godot 4.6.3 on PATH (or $GODOT).
set -uo pipefail
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
# A user:// of its own, so the renders never touch the game's real save (or the tests').
export XDG_DATA_HOME="${TMPDIR:-/tmp}/dahrooj-store-userdata"
RES="$1"; OUT="$2"; shift 2
timeout 900 xvfb-run -a -s "-screen 0 6200x3400x24" "$GODOT" --xr-mode off --rendering-driver opengl3 \
  --fixed-fps 30 --resolution "$RES" --path . res://tools/store/store_shot.tscn -- --xr=0 --out="$OUT" "$@" 2>&1 \
  | grep -E "store_shot|SCRIPT ERROR|ERROR: .*res://|Parse Error" | head -20
