#!/usr/bin/env bash
# Renders every Meta Horizon Store image of quest-native/store/ from the real game
# (xvfb + OpenGL 3, the desktop camera of scenes/main.tscn). Each picture is drawn at twice
# its size and scaled down (smooth edges); the title is drawn the game's way (title_card.gd).
# Usage: tools/store/build_art.sh [only-these-names...]   e.g. build_art.sh icon hero
# Needs: godot 4.6.3, xvfb-run, python3 + Pillow. Not part of the APK (tools/* is excluded).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
STORE="$ROOT/store"
TMP="${TMPDIR:-/tmp}/dahrooj-store-art"
mkdir -p "$STORE/art" "$STORE/screenshots" "$STORE/screenshots/ar" "$TMP"
SHOOT="$HERE/shoot.sh"
TITLE="$HERE/title.sh"
WANT=" $* "
want() { [ "$WANT" = "  " ] || [[ "$WANT" == *" $1 "* ]]; }

# shrink <in 2x png> <out png> <w> <h>: Lanczos down to the exact size, 24-bit RGB.
shrink() {
  python3 - "$1" "$2" "$3" "$4" <<'EOF'
import sys
from PIL import Image
src, dst, w, h = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
im = Image.open(src).convert("RGB").resize((w, h), Image.LANCZOS)
im.save(dst, optimize=True)
EOF
}

# still <name> <w> <h> <args...>: a 2x render, scaled to w x h in $TMP/<name>.png
still() {
  local name="$1" w="$2" h="$3"; shift 3
  "$SHOOT" "$((w * 2))x$((h * 2))" "$TMP/$name@2x.png" "$@"
  shrink "$TMP/$name@2x.png" "$TMP/$name.png" "$w" "$h"
}

CROWD="--mode=goal --hide_stage --hud=0 --t=1"

# --- branded art (title in the centre safe area) -------------------------------------------
if want landscape; then
  still landscape 2560 1440 $CROWD --extras_json=res://tools/store/crowd_wide.json --cam=0,1.35,3.4 --look=0,1.6,-8 --fov=55
  "$TITLE" 2560x1440 "$STORE/art/cover_landscape_2560x1440.png" --bg="$TMP/landscape.png" --cy=0.38 --px=300 --glow=0.35
fi
if want hero; then
  still hero 3000 900 $CROWD --extras_json=res://tools/store/crowd_hero.json --cam=0,1.0,6.3 --look=0,1.5,-8 --fov=30
  "$TITLE" 3000x900 "$STORE/art/hero_3000x900.png" --bg="$TMP/hero.png" --cy=0.47 --px=270 --glow=0.35
fi
if want square; then
  still square 1440 1440 $CROWD --extras_json=res://tools/store/crowd_tall.json --cam=0,1.6,4.3 --look=0,1.6,-8 --fov=58
  "$TITLE" 1440x1440 "$STORE/art/cover_square_1440x1440.png" --bg="$TMP/square.png" --cy=0.35 --px=250 --glow=0.35
fi
if want portrait; then
  still portrait 1008 1440 $CROWD --extras_json=res://tools/store/crowd_tall.json --cam=0,1.6,4.7 --look=0,1.75,-8 --fov=64
  "$TITLE" 1008x1440 "$STORE/art/cover_portrait_1008x1440.png" --bg="$TMP/portrait.png" --cy=0.32 --px=205 --glow=0.35
fi
if want trailer; then
  # Pop Frenzy a moment later than screenshot 01; the title sits in the open sky left of centre.
  still trailer 2560 1440 --mode=frenzy --t=7.5 --hud=0 --cam=0,3.2,1 --look=0,4.6,-10 --fire=8 --fire_at=5.5 --fire_every=0.2 --shot_style=firework --aim=0,4,-8
  "$TITLE" 2560x1440 "$STORE/art/trailer_cover_2560x1440.png" --bg="$TMP/trailer.png" --cx=0.45 --cy=0.33 --px=210 --glow=0.35
fi
if want logo; then
  # Transparent; the title fills the frame inside 20% top/bottom and 10% side margins.
  "$TITLE" 2560x1440 "$STORE/art/logo_transparent_2560x1440.png" --transparent --cy=0.5 --px=490
fi
if want small; then
  still small 1280 720 $CROWD --extras_json=res://tools/store/crowd_wide.json --cam=0,1.35,3.4 --look=0,1.6,-8 --fov=55
  "$TITLE" 1280x720 "$STORE/art/small_landscape_1280x720.png" --bg="$TMP/small.png" --cy=0.38 --px=150 --glow=0.35
fi
# --- icon (no text, square corners, full bleed) --------------------------------------------
if want icon; then
  still icon 1024 1024 $CROWD --extras_json=res://tools/store/icon.json --cam=0.05,0.2,1.45 --look=0.02,0.28,0 --fov=30
  cp "$TMP/icon.png" "$STORE/art/icon_1024x1024.png"
  shrink "$TMP/icon.png" "$STORE/art/icon_512x512.png" 512 512
fi

# --- screenshots: the game as played, no added text ----------------------------------------
SS="$STORE/screenshots"
shot() { local name="$1"; shift; still "ss_$name" 2560 1440 "$@" && cp "$TMP/ss_$name.png" "$SS/$name.png"; }
# Pop Frenzy is random from run to run: render it a few times and keep the best (store/screenshots).
want ss1 && shot 01_pop_frenzy --mode=frenzy --t=6 --hud=0 --cam=0,3.2,1 --look=0,4.6,-10 --fire=8 --fire_at=4 --fire_every=0.2 --shot_style=firework --aim=0,4,-8
want ss2 && shot 02_dahrooj_rain --mode=rain --t=7 --cam=0,2.2,1 --look=0,0.6,-5 --fire=4 --fire_at=6.2 --shot_style=bubble --aim=0,1.5,-6
want ss3 && shot 03_giant_dahrooj --mode=giant --t=7 --hud=0 --cam=0,3.2,1 --look=0,4,-10 --fire=4 --fire_at=6.0 --fire_every=0.12 --shot_style=bubble --aim=0,4.5,-10
want ss4 && shot 04_dahrooj_gallery --mode=gallery --t=8 --hud=0 --cam=0,3.2,0.6 --look=0,3.0,-10 --fire=4 --fire_at=7.2 --fire_every=0.1 --shot_style=bubble --aim=0,2.2,-10 --spread=3
want ss5 && shot 05_dahrooj_fort --mode=castle --t=9 --hud=0 --cam=0,3.2,1.5 --look=0,3,-10
want ss6 && shot 06_balance_tabletop --mode=balance --t=3 --cam=0,2.6,1.6 --look=0,0.8,-1.5
want ss7 && shot 07_menu_modes --mode=goal --t=2 --menu=modes --fov=46 --cam=0,3.2,1 --look=0,1.3,-10
want ss8 && shot 08_summit_climb --mode=climb --t=5 --cam=0,3.0,-6 --look=0,3.5,-11.3
if want ss_ar; then
  still ss_ar_modes 2560 1440 --lang=ar --mode=goal --t=2 --menu=modes --fov=46 --cam=0,3.2,1 --look=0,1.3,-10 \
    && cp "$TMP/ss_ar_modes.png" "$SS/ar/07_menu_modes_ar.png"
fi
ls -la "$STORE/art" "$SS" "$SS/ar"
