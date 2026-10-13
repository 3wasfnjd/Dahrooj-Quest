extends RefCounted
## Slime: a thrown Dahrooj sticks to the goo wall and to the ground and melts over time; the
## next lands on a blob and stacks; the impact speed changes his face; a shot pops a blob (and
## what sits on it); the cap dissolves the oldest; the target's rings score; the tower of 5;
## an earlier throw of a volley sticks too and leaves the volley.


static func _fly(b: Ball, from: Vector3, v: Vector3, limit := 3.0) -> bool:
	b.respawn()
	b.pos = from
	b.throw_with(v)
	var t := 0.0
	while t < limit and b.shot:
		b.step(1.0 / 72.0)
		t += 1.0 / 72.0
	return not b.shot


static func _wait(st: SlimeStage, b: Ball, secs: float) -> void:
	for i in int(secs * 72.0):
		st.update(b, 1.0 / 72.0)


static func run(check: Callable) -> void:
	var sfx: Array = []
	var extra: Array = []
	var ch := {}
	var st := SlimeStage.new()
	var b := Ball.new()
	var ctx := GameCtx.new()
	ctx.ball = b
	ctx.sfx = func(n, k, _p): sfx.append([n, k])
	ctx.toast = func(t): extra.append(["toast", t])
	ctx.ch_progress = func(id, v): ch[id] = maxi(int(ch.get(id, 0)), int(v))
	ctx.confetti = func(p, _r, _e, _s): extra.append(["confetti", p])
	st.ctx = ctx
	b.set_stage(st, "slime")
	st.update(b, 1.0 / 72.0)
	check.call(st.board.visible and st.blobs.is_empty(), "slime: the goo wall stands, nothing stuck yet")

	# The wall: he sticks and melts.
	var ok := _fly(b, Vector3(0.5, 3.3, -6.0), Vector3(0, 2.5, -13.0))
	check.call(ok and st.blobs.size() == 1 and not b.shot, "slime: a throw at the wall sticks (and a new Dahrooj comes to the hand)")
	var w: Dictionary = st.blobs[0]
	var ws := st.blob_state(w)
	check.call(ws.kind == "wall" and (ws.n as Vector3).is_equal_approx(Vector3.BACK) and absf((ws.anchor as Vector3).z - SlimeStage.WALL_Z) < 0.05,
		"slime: stuck flat on the wall's face, facing out")
	check.call(sfx.any(func(s): return s[0] == "splash") and sfx.any(func(s): return s[0] == "squeak") and not st.drops.is_empty(),
		"slime: a wet splat (splash, squeak) and goo droplets fly")
	var m0: float = ws.m
	var s0: float = ws.S
	_wait(st, b, 3.0)
	var ws2 := st.blob_state(w)
	check.call(float(ws2.m) > m0 + 0.3 and float(ws2.H) < 2.0 * SlimeStage.R * 0.6 and float(ws2.S) > s0 * 1.15, "slime: he melts over time (%.2f -> %.2f), sagging and spreading" % [m0, ws2.m])
	check.call((ws2.anchor as Vector3).y < (ws.anchor as Vector3).y and not (w.drips as Array).is_empty(), "slime: on a wall he slides down a little and drips")
	check.call(int(ws.ring) >= 0 and st.slime_state().score == int(SlimeStage.RING_PTS[ws.ring]), "slime: points for the ring he stuck in (ring %d)" % ws.ring)

	# The ground.
	ok = _fly(b, Vector3(3.0, 2.0, -4.0), Vector3(0, 0, -2.0))
	var f: Dictionary = st.blobs[st.blobs.size() - 1]
	check.call(ok and st.blobs.size() == 2 and f.kind == "floor" and (f.n as Vector3).is_equal_approx(Vector3.UP) and absf((f.anchor as Vector3).y) < 0.01,
		"slime: on the ground too")
	var fm: float = f.m
	_wait(st, b, 2.0)
	check.call(float(f.m) > fm + 0.2, "slime: and melts into a puddle there")

	# A second lands on the first and stacks.
	var top: Vector3 = (f.anchor as Vector3) + Vector3.UP * (float(f.H) + 2.0)
	ok = _fly(b, top, Vector3(0, -1.0, 0))
	var s2: Dictionary = st.blobs[st.blobs.size() - 1]
	check.call(ok and s2.kind == "blob" and int(s2.parent) == int(f.id) and int(s2.level) == 2 and (s2.anchor as Vector3).y > 0.1,
		"slime: the next lands on the blob and sticks on top (level 2)")
	check.call(st.slime_state().tower == 2 and int(ch.get("slime5", 0)) == 2, "slime: the pile counter reads 2")
	var before_y: float = (s2.anchor as Vector3).y
	_wait(st, b, 2.0)
	check.call((s2.anchor as Vector3).y < before_y + 0.01 and (s2.anchor as Vector3).y > 0.05, "slime: the pile stays standing as the base melts")

	# Impact speed changes the face.
	var soft := st.stick(Vector3(-3, 0, -6), Vector3.UP, Vector3(0, -4, -1), "floor")
	var mid := st.stick(Vector3(-1.5, 0, -6), Vector3.UP, Vector3(0, -9, -3), "floor")
	var hard := st.stick(Vector3(1.5, 0, -6), Vector3.UP, Vector3(0, -12, -6), "floor")
	var crash := st.stick(Vector3(4.5, 0, -6), Vector3.UP, Vector3(0, -15, -10), "floor")
	var e := [st.blob_state(soft).eyes, st.blob_state(mid).eyes, st.blob_state(hard).eyes]
	check.call(e[0] == "wide" and e[1] == "cross" and e[2] == "" and st.blob_state(hard).face == "closed",
		"slime: soft = eyes pop wide, medium = cross-eyed, hard = squeezed shut %s" % [e])
	_wait(st, b, 0.6)
	check.call(String(st.blob_state(crash).eyes).begins_with("dizzy"), "slime: a crash goes swirly-dizzy after the squeeze")
	check.call(float(crash.smear) > float(soft.smear), "slime: the splat is smeared the way he came in")
	_wait(st, b, 6.0)
	var calm := st.blob_state(soft)
	check.call(calm.eyes in ["sleepy", "blink"] and calm.face == "joy", "slime: settled, a sleepy melted smile (%s)" % calm.eyes)

	# A shot pops a blob, and what sits on it.
	st.draw()
	var proxy: MeshInstance3D = null
	for p: MeshInstance3D in st._proxies:
		if p.visible and int(p.get_meta("blob", 0)) == int(f.id):
			proxy = p
	var live0: int = st.slime_state().live
	var took := proxy != null and st.shoot(proxy, proxy.position, Vector3.FORWARD)
	_wait(st, b, 0.5)
	check.call(took and proxy.layers == 0 and st.slime_state().popped == 2 and st.slime_state().live == live0 - 2 and int(ch.get("pop20", 0)) >= 1,
		"slime: a shot pops the blob and the one stacked on it (%d popped)" % st.slime_state().popped)
	check.call(not st.shoot(st.board.get_node("Panel"), Vector3.ZERO, Vector3.FORWARD), "slime: a shot at the wall pops nothing")

	# The cap: the oldest free one dissolves.
	var first_id: int = st.blobs[0].id
	for i in 30:
		st.stick(Vector3(-6.0 + (i % 6) * 2.4, 0, -3.0 - floori(i / 6.0) * 1.5), Vector3.UP, Vector3(0, -6, 0), "floor")
	check.call(st.slime_state().live == SlimeStage.CAP, "slime: at most %d blobs (%d)" % [SlimeStage.CAP, st.slime_state().live])
	_wait(st, b, 1.0)
	check.call(not st._by_id.has(first_id) and st.blobs.size() <= SlimeStage.SLOTS, "slime: the oldest dissolved away")
	st.deactivate()
	check.call(st.blobs.is_empty() and st.drops.is_empty(), "slime: leaving the mode clears the goo")

	# Points for the centre.
	var sc0: int = st.slime_state().score
	var bull := st.stick(Vector3(0.1, SlimeStage.TARGET_Y - 0.1, SlimeStage.WALL_Z), Vector3.BACK, Vector3(0, 0, -14), "wall")
	var rim := st.stick(Vector3(2.2, SlimeStage.TARGET_Y, SlimeStage.WALL_Z), Vector3.BACK, Vector3(0, 0, -14), "wall")
	var off := st.stick(Vector3(4.0, 0.8, SlimeStage.WALL_Z), Vector3.BACK, Vector3(0, 0, -14), "wall")
	check.call(int(bull.pts) == 10 and int(rim.pts) == 1 and int(off.pts) == 0 and st.slime_state().score == sc0 + 11 and int(ctx.counts.get("slime", 0)) == st.slime_state().score,
		"slime: 10 for the bullseye, 1 for the outer ring, nothing off the target")
	check.call(extra.any(func(x): return x[0] == "confetti"), "slime: a bullseye celebrates")

	# A tower of 5.
	var base := st.stick(Vector3(-2, 0, -7), Vector3.UP, Vector3(0, -6, 0), "floor")
	var tb := base
	for i in 4:
		_wait(st, b, 0.3)
		tb = st.stick((tb.anchor as Vector3) + Vector3.UP * float(tb.H), Vector3.UP, Vector3(0, -6, 0), "blob", tb)
	check.call(int(tb.level) == 5 and st.slime_state().best_tower == 5 and int(ch.get("slime5", 0)) == 5 and int(tb.pts) == 8,
		"slime: a tower of 5 (the challenge; +8 for the top one)")
	check.call(extra.any(func(x): return x[0] == "toast" and String(x[1]).contains("٥")), "slime: the tower is announced")
	check.call(GameRuntime.challenge("slime5").size() == 4 and "slime" in GameRuntime.MODES, "slime: the mode and its challenge are in the runtime")
	_wait(st, b, 4.0)
	check.call((tb.anchor as Vector3).y > 4.0 * SlimeStage.R and st.slime_state().tower == 5, "slime: the tower keeps standing as it melts (top at %.2f)" % (tb.anchor as Vector3).y)

	# An earlier throw of a volley sticks and leaves the volley.
	st.deactivate()
	b.respawn()
	b.pos = Vector3(-1, 3.3, -6)
	b.throw_with(Vector3(0, 2.5, -13.0))
	b.another()
	b.pos = Vector3(1, 3.3, -6)
	b.throw_with(Vector3(0, 2.5, -13.0))
	for i in 72 * 2:
		b.step(1.0 / 72.0)
	check.call(st.blobs.size() == 2 and b.volley.is_empty() and not b.shot, "slime: both throws of a volley stick (%d blobs, %d in the volley)" % [st.blobs.size(), b.volley.size()])
	st.free()
