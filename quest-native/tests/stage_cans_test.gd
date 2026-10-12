extends RefCounted
## Headless checks of the tin cans (stages/cans.js port): a low throw clears the whole
## pyramid in one go (score + "cansOne"), a high throw sails over and misses, a glancing
## throw knocks some, and the blaster knocks cans off (no one-throw credit) with a fresh
## stack a moment later.


static func _setup() -> Array:
	var st := CansStage.new()
	var b := Ball.new()
	var ctx := GameCtx.new()
	ctx.ball = b
	st.ctx = ctx
	var rec := {"counts": [], "progress": [], "sounds": []}
	ctx.add_count = func(m, r): rec.counts.append([m, r])
	ctx.ch_progress = func(id, v): rec.progress.append([id, v])
	ctx.sfx = func(n, k, p): rec.sounds.append([n, k, p])
	b.set_stage(st, "cans")
	var got: Array = []
	b.event.connect(func(k, _d): got.append(k))
	return [st, b, ctx, rec, got]


## Velocity from p that reaches c after t seconds (gravity and drag 0.9^t).
static func _aim(p: Vector3, c: Vector3, t: float) -> Vector3:
	var f := (1.0 - pow(0.9, t)) / -log(0.9)
	var v := (c - p) / f
	v.y = (c.y - p.y + Ball.GRAV * t * t / 2.0) / f
	return v


static func _on_table(st: CansStage) -> int:
	return st.cans.filter(func(c): return CansStage.on_table(c)).size()


static func run(check: Callable) -> void:
	# 1. A low, fast throw clears the whole pyramid.
	var s := _setup()
	var st: CansStage = s[0]
	var b: Ball = s[1]
	var rec: Dictionary = s[3]
	var got: Array = s[4]
	check.call(_on_table(st) == 6 and st.cans.all(func(c): return c.sleep), "cans: six cans stacked asleep on the table")
	check.call(is_equal_approx(st.cans[5].x.y, CansStage.TY + CansStage.CH / 2 + 2 * (CansStage.CH + 0.003) + 0.001), "cans: the top can sits two rows up")
	b.pos = Vector3(0, 1.5, -3)
	b.throw_with(_aim(b.pos, Vector3(0, 1.0, CansStage.TZ), 0.6))
	var joy := false
	var cleared_seen := false
	for i in 72 * 5:
		b.step(1.0 / 72.0)
		if b.mood == "joy" and not got.has("success"):
			joy = true
		if st.cleared:
			cleared_seen = true
	check.call(st.touched() or cleared_seen, "cans: the ball touched the pile")
	check.call(joy, "cans: Dahrooj cheers when he hits the cans")
	check.call(rec.counts.size() == 6 and rec.counts.all(func(e): return e == ["cans", false]), "cans: every can knocked down counts once (%d)" % rec.counts.size())
	check.call(got.has("success") and not got.has("miss"), "cans: clearing the table scores")
	check.call(rec.progress.has(["cansOne", 1]), "cans: one throw for the whole pyramid counts for its challenge")
	check.call(rec.sounds.any(func(e): return e[0] == "cans_clang" and e[1] > 0.0 and e[1] <= 1.0), "cans: the cans clang")
	check.call(not b.shot and _on_table(st) == 6 and not st.cleared, "cans: a fresh stack when Dahrooj comes back")
	st.free()

	# 2. A high throw sails over the pyramid: a miss.
	s = _setup()
	st = s[0]
	b = s[1]
	rec = s[3]
	got = s[4]
	b.pos = Vector3(0, 1.5, -3)
	b.throw_with(_aim(b.pos, Vector3(0, 3.6, CansStage.TZ), 0.8))
	for i in 72 * 4:
		b.step(1.0 / 72.0)
	check.call(got.has("miss") and not got.has("success") and rec.counts.is_empty(), "cans: a throw over the pile misses")
	st.free()

	# 3. A throw that knocks only some cans: no score, no challenge credit, the rest stay up.
	s = _setup()
	st = s[0]
	b = s[1]
	rec = s[3]
	got = s[4]
	b.pos = Vector3(0, 1.5, -3)
	b.throw_with(_aim(b.pos, Vector3(0, 1.6, CansStage.TZ), 0.6))
	var touched := false
	for i in 72 * 5:
		b.step(1.0 / 72.0)
		touched = touched or st.touched()
	check.call(touched and rec.counts.size() > 0 and rec.counts.size() < 6, "cans: a glancing throw knocks some cans (%d)" % rec.counts.size())
	check.call(not got.has("success") and not got.has("miss") and rec.progress.is_empty(), "cans: a touched pile is no laughing miss and no score")
	check.call(_on_table(st) == 6 - rec.counts.size(), "cans: the rest stay up for the next throw")
	st.free()

	# 4. The blaster knocks the cans off while Dahrooj is in hand; a fresh stack comes back.
	s = _setup()
	st = s[0]
	b = s[1]
	rec = s[3]
	got = s[4]
	check.call(not st.shoot(st.get_child(0), Vector3.ZERO, Vector3.FORWARD), "cans: a blast at the table is not a can")
	var body: MeshInstance3D = st.cans[5].mesh.get_child(0)
	var took := st.shoot(body, st.cans[5].x, Vector3(0, 0.2, -1).normalized())
	check.call(took and not st.cans[5].sleep, "cans: a blast at a can shoves it")
	var reset_seen := false
	for n in 20:
		for c in st.cans:
			if CansStage.on_table(c):
				st.shoot(c.mesh.get_child(1), c.x, Vector3(0, 0.2, -1).normalized())
		for i in 36:
			b.step(1.0 / 72.0)
			if st.cleared:
				reset_seen = true
		if reset_seen:
			break
	check.call(reset_seen and rec.counts.size() == 6, "cans: the blaster can clear the table")
	check.call(not rec.progress.has(["cansOne", 1]) and not got.has("success"), "cans: blasting gives no score or challenge")
	for i in 72 * 2:
		b.step(1.0 / 72.0)
	check.call(not st.cleared and _on_table(st) == 6, "cans: a fresh stack 1.6 s later")
	check.call(st.behind(Vector3(0, 1, -20.8)) and not st.behind(Vector3(0, 1, -20.5)), "cans: behind the table")
	st.free()
