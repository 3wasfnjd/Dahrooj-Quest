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
