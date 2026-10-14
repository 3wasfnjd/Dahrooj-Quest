extends RefCounted
## Bowling (stages/bowling.js): a straight roll knocks pins (counted, clacking), the fallen ones
## are swept after the roll; a gutter ball misses; a blaster shot topples a pin.


static func _setup(sfx: Array, counts: Array, events: Array, extra: Array) -> Array:
	var st := BowlingStage.new()
	var b := Ball.new()
	var ctx := GameCtx.new()
	ctx.ball = b
	ctx.sfx = func(n, k, _p): sfx.append([n, k])
	ctx.add_count = func(m, r): counts.append([m, r])
	ctx.toast = func(t): extra.append(["toast", t])
	ctx.ch_progress = func(id, v): extra.append(["ch", id, v])
	st.ctx = ctx
	b.set_stage(st, "bowling")
	b.event.connect(func(k, _d): events.append(k))
	return [st, b]


static func _down(st: BowlingStage) -> int:
	return st.pins_state().filter(func(p): return p.down).size()


static func run(check: Callable) -> void:
	# A straight roll down the middle.
	var sfx: Array = []
	var counts: Array = []
	var events: Array = []
	var extra: Array = []
	var sb := _setup(sfx, counts, events, extra)
	var st: BowlingStage = sb[0]
	var b: Ball = sb[1]
	b.pos = Vector3(0, Ball.BR + 0.2, -1.0)
	b.throw_with(Vector3(0, 0, -11))
	var knocked_in_flight := 0
	for i in 72 * 12:
		b.step(1.0 / 72.0)
		if b.shot:
			knocked_in_flight = st.knocked
		if not b.shot and i > 10:
			break
	check.call(knocked_in_flight >= 3, "bowling: a straight roll knocks pins down (%d)" % knocked_in_flight)
	check.call(counts.size() == knocked_in_flight and counts.all(func(c): return c[0] == "bowling"), "bowling: each fallen pin is counted (%d)" % counts.size())
	check.call(sfx.any(func(s): return s[0] == "bowling_clack"), "bowling: the pins clack")
	check.call(not events.has("miss"), "bowling: a roll that touched the pins is no laughing miss")
	if knocked_in_flight >= 10:
		check.call(events.has("success") and JuiceText.showing(st).any(func(j: JuiceText) -> bool: return j.kind == "banner" and j.text == "سترايك!"), "bowling: a strike cheers with a festive «سترايك!» banner")
		check.call(st.frame().roll == 0 and _down(st) == 0, "bowling: after a strike a fresh rack stands")
	else:
		var gone := st.pins_state().filter(func(p): return p.gone).size()
		check.call(st.frame().roll == 1 and gone == knocked_in_flight, "bowling: after the first roll the fallen pins are swept (%d gone)" % gone)
	st.free()

	# A strike while the player already holds the next Dahrooj: the roll goes on as part of
	# the volley (main.gd re-grab -> ball.another()) and the strike still counts.
	sfx = []
	counts = []
	events = []
	extra = []
	sb = _setup(sfx, counts, events, extra)
	st = sb[0]
	b = sb[1]
	b.pos = Vector3(0, Ball.BR + 0.2, -1.0)
	b.throw_with(Vector3(0, 0, -11))
	for i in 20:
		b.step(1.0 / 72.0)
	b.another()
	b.held = true
	b.shot = false
	var forced := false
	for i in 72 * 10:
		b.step(1.0 / 72.0)
		# Once the rolling volley ball has hit the rack, topple whatever it left standing.
		if not forced and st.knocked > 0:
			forced = true
			for pin in st.pins:
				pin.down = true
	var struck := extra.any(func(e): return e[0] == "ch" and e[1] == "strike1")
	check.call(forced and struck, "bowling: a strike rolled while the next Dahrooj is already in hand still counts")
	st.free()

	# A gutter ball: wide of the pins, nothing touched -> a miss.
	sfx = []
	counts = []
	events = []
	extra = []
	sb = _setup(sfx, counts, events, extra)
	st = sb[0]
	b = sb[1]
	b.pos = Vector3(0, Ball.BR + 0.2, -1.0)
	b.throw_with(Vector3(1.4, 0, -11))
	for i in 72 * 6:
		b.step(1.0 / 72.0)
		if events.has("miss"):
			break
	check.call(events.has("miss") and st.knocked == 0 and counts.is_empty(), "bowling: a ball wide of the pins misses (knocked %d)" % st.knocked)
	st.free()

	# The blaster: a shot at the head pin's mesh pushes it over.
	sfx = []
	counts = []
	events = []
	extra = []
	sb = _setup(sfx, counts, events, extra)
	st = sb[0]
	b = sb[1]
	var head: Dictionary = st.pins[0]
	var took := st.shoot(head.body, head.x + Vector3(0, 0.3, 0.15), Vector3(0, 0, -1))
	check.call(took and not head.sleep, "bowling: a blaster shot hits a pin and wakes it")
	check.call(not st.shoot(st, Vector3.ZERO, Vector3.FORWARD), "bowling: a shot that hits no pin is not taken")
	for i in 72 * 3:
		b.step(1.0 / 72.0)
	check.call(head.down and st.knocked >= 1, "bowling: the shot pin falls (%d down)" % st.knocked)
	st.free()
