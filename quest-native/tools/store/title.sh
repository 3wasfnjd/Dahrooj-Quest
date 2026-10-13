#!/usr/bin/env bash
# The title over a picture: tools/store/title.sh WxH out.png [-- title_card args] (see title_card.gd).
set -uo pipefail
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
# A user:// of its own, so the renders never touch the game's real save (or the tests').
export XDG_DATA_HOME="${TMPDIR:-/tmp}/dahrooj-store-userdata"
RES="$1"; OUT="$2"; shift 2
timeout 300 xvfb-run -a -s "-screen 0 9400x3400x24" "$GODOT" --xr-mode off --rendering-driver opengl3 \
  --resolution "$RES" --path . res://tools/store/title_card.tscn -- --out="$OUT" "$@" 2>&1 \
  | grep -E "title_card|SCRIPT ERROR|ERROR: .*res://|Parse Error" | head -20
