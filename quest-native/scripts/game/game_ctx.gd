class_name GameCtx
extends RefCounted
## What a stage may use from the game (the web reference's `ctx`, complete-game.js):
## the ball, sounds, scores, challenges, messages and confetti. The runtime fills
## the callables; stages call them and never reach into the runtime directly.

var ball: Ball
var time := 0.0  # game seconds (Ball.time)
var lang := "ar"
var counts := {}  # mode id -> score this session (ctx.counts)
var ch_state := {}  # challenge id -> value (store.data.challenges)

## sfx(name: String, k: float, pos: Vector3) — the reference sound functions by name:
## thump, squeak, pew, splash, boom, whoosh, swish, chime, start_pop, and stage
## sounds named "<stage>_<function>" (e.g. "cans_clang"). pos in game units.
var sfx: Callable = func(_n, _k, _p): pass
## add_count(mode: String, reset: bool) — ctx.addCount.
var add_count: Callable = func(_m, _r): pass
## ch_progress(id: String, value: int) — ctx.chProgress (challenge progress).
var ch_progress: Callable = func(_id, _v): pass
## tally(id: String, n: int) — n more toward a lifetime challenge, saved a little later
## (for counts that move fast).
var tally: Callable = func(_id, _n): pass
## penalty(mode: String, points: int, at: Vector3) -> int — something attacking the player got
## through (an invader at the line, a minion bouncing off you, a meteor landing at your feet):
## the session score drops by up to `points` (never below 0; records, the lifetime total and
## the challenges keep what they have). Returns the points taken. at: game units.
var penalty: Callable = func(_m, _p, _a): return 0
## nibble(mode: String, points: int, at: Vector3) -> int — the same, for the small, frequent
## things that get through (a meteor hitting the ground, a mole ducking back unwhacked, a
## climber planting his flag): the score drops the same way, with a lighter touch (a small grey
## «-10» where it happened, a soft bump; no red flash). Returns the points taken.
var nibble: Callable = func(_m, _p, _a): return 0
## toast(text: String) — ctx.toast (a notification card).
var toast: Callable = func(_t): pass
## confetti(pos: Vector3, radius: float, elevation: float, scale: float) — confetti.pop.
var confetti: Callable = func(_p, _r, _e, _s): pass


func t(ar: String, en: String) -> String:
	return en if lang == "en" else ar


## ctx.ar: Arabic-Indic digits.
static func ar_digits(n) -> String:
	var s := str(n)
	var out := ""
	for ch in s:
		out += "٠١٢٣٤٥٦٧٨٩"[int(ch)] if ch >= "0" and ch <= "9" else ch
	return out


## A whole number with its thousands grouped: "12,500", or in Arabic-Indic digits with the
## Arabic thousands separator, "١٢٬٥٠٠".
static func grouped(n: int, arabic := false) -> String:
	var digits := str(absi(n))
	var out := ""
	var k := 0
	for i in range(digits.length() - 1, -1, -1):
		if k > 0 and k % 3 == 0:
			out = ("٬" if arabic else ",") + out
		out = digits[i] + out
		k += 1
	if n < 0:
		out = "-" + out
	return ar_digits(out) if arabic else out
