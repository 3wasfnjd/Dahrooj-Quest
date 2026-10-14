extends RefCounted
## Dahrooj Meteors (meteor): it starts on its own (a banner, no board, no hearts); meteors fall
## from the sky with a warning target where they will land; a shot splits a big one into two
## middle ones, a middle one into two small ones, and a small one bursts into a firework; the
## points go to ctx.counts["meteor"]; golden ones are worth ×5; an explosion sets off its
## neighbours (a chain); one that lands leaves a crater and only breaks the combo (open play);
## a thrown Dahrooj blasts them too; the intensity escalates and showers come; mixed reality:
## they crack through the scanned ceiling and land on the scanned floor.

const DT := 1.0 / 72.0


static func _steps(st: MeteorStage, b: Ball, secs: float) -> void:
	var t := 0.0
	while t < secs:
		st.update(b, DT)
		t += DT


static func _until(st: MeteorStage, b: Ball, cond: Callable, limit: float) -> bool:
	var t := 0.0
	while t < limit:
		if cond.call():
			return true
		st.update(b, DT)
		t += DT
	return cond.call()


## A quiet game (no automatic meteors).
static func _fresh(st: MeteorStage, b: Ball) -> void:
	st.deactivate()
	st.auto_spawn = false
	st.start()
	st.F.banner_t = 0.0
	st.update(b, DT)


static func _fly(st: MeteorStage, kind: String, golden: bool, from: Vector3, to: Vector3, T := 4.0) -> Dictionary:
	var i := st.spawn(kind, golden, {"start": from, "land": to, "T": T})
	return st.meteors[i] if i >= 0 else {}


static func _on(st: MeteorStage, kind: String) -> Array:
	return st.meteors.filter(func(q): return q.on and q.phase == "fall" and q.kind == kind)


static func run(check: Callable) -> void:
	var sfx: Array = []
	var extra: Array = []
	var buzzes: Array = []
	var st := MeteorStage.new()
	var b := Ball.new()
	var ctx := GameCtx.new()
	ctx.ball = b
	ctx.sfx = func(n, k, _p): sfx.append([n, k])
	ctx.add_count = func(md, r): extra.append(["count", md, r])
	ctx.ch_progress = func(id, v): extra.append(["ch", id, v])
	ctx.confetti = func(p, _r, _e, _s): extra.append(["confetti", p])
	var taken: Array = []
	ctx.penalty = func(md: String, pts: int, _at: Vector3) -> int:
		taken.append([md, pts])
		return pts
	var nibbled: Array = []
	ctx.nibble = func(md: String, pts: int, _at: Vector3) -> int:
		nibbled.append([md, pts])
		return pts
	st.ctx = ctx
	st.buzz = func(h, a, ms): buzzes.append([h, a, ms])
	b.set_stage(st, "meteor")
	check.call(st.meteor_state().state == "idle" and not ("hearts" in st) and not ("lives" in st.F) and st.get_node_or_null("Board") == null, "meteor: no board, no hearts")

	# Open play: shown, it starts on its own with a banner; meteors come out of the sky.
	st.update(b, DT)
	st.draw()
	check.call(st.meteor_state().state == "play" and st.banner.visible and st.banner.text == "نيازك الدحاريج!", "meteor: starts on its own with a banner (%s)" % st.banner.text)
	check.call(_until(st, b, func(): return st.meteor_state().falling >= 1, 3.0), "meteor: the first meteor comes")
	var first: Dictionary = {}
	for q in st.meteors:
		if q.on:
			first = q
	check.call(first.phase == "fall" and first.c.y > 15.0 and (first.proxy as MeshInstance3D).visible and (first.proxy as MeshInstance3D).layers == 0, "meteor: high in the sky (y %.1f) with an undrawn hit sphere" % first.c.y)
	var land0: Vector3 = first.land
	st.draw()
	check.call((st._mm.rings as MultiMesh).visible_instance_count >= 2 and (st._mm.discs as MultiMesh).visible_instance_count >= 1 and (st._mm.fire as MultiMesh).visible_instance_count >= 1 and (st._mm.halo as MultiMesh).visible_instance_count >= 2, "meteor: fire, heat glow and a warning target on the ground")
	check.call(absf(land0.y) < 0.01 and Vector2(land0.x, land0.z).distance_to(Vector2(st.viewer.x, st.viewer.z)) > 3.0, "meteor: it will land on the ground around you (%s)" % land0)
	var f0 := st.fx_spawned
	var fy0: float = first.c.y
	_steps(st, b, 0.5)
	check.call(st.fx_spawned > f0 + 6 and first.c.y < fy0 - 1.0, "meteor: a trail of embers as it falls (%d)" % (st.fx_spawned - f0))
	check.call(Vector2(first.land.x, first.land.z).distance_to(Vector2(land0.x, land0.z)) < 0.3, "meteor: the target is where it really lands")

	# A meteor that lands: a crater, a shockwave, dust; the combo breaks; it nibbles points.
	_fresh(st, b)
	nibbled.clear()
	var m := _fly(st, "big", false, Vector3(2, 18, -16), Vector3(1, 0, -9), 2.0)
	st.F.combo = 5
	st.F.combo_t = 1.5
	st.F.mult = 2
	var c0 := int(ctx.counts.get("meteor", 0))
	sfx.clear()
	check.call(_until(st, b, func(): return m.phase == "land", 3.0), "meteor: it lands")
	check.call(st.craters.size() == 1 and st._rings.size() >= 2 and sfx.any(func(s): return s[0] == "thump") and sfx.any(func(s): return s[0] == "boom"), "meteor: crater, shockwave and a thud")
	check.call(st.meteor_state().combo == 0 and st.meteor_state().mult == 1 and st.meteor_state().landed == 1 and st.meteor_state().state == "play" and int(ctx.counts.get("meteor", 0)) == c0, "meteor: only the combo breaks (no lives, no game over)")
	check.call(Vector2(m.c.x, m.c.z).distance_to(Vector2(1, -9)) < 0.5, "meteor: it landed on its target")
	_steps(st, b, MeteorStage.LAND_T + 0.1)
	check.call(not m.on, "meteor: the dazed Dahrooj sinks away")
	check.call(taken.is_empty(), "meteor: one landing far from you does not hit you")
	check.call(nibbled == [["meteor", MeteorStage.GROUND_PENALTY.big]] and int(MeteorStage.GROUND_PENALTY.big) == 20,
		"meteor: a big one reaching the ground takes 20 (light) (%s)" % [nibbled])
	# One landing right at your feet hits you: LAND_PENALTY points.
	var vf := Vector3(st.viewer.x, 0, st.viewer.z - st.near_d() * 1.05)
	var m2 := _fly(st, "small", false, vf + Vector3(1, 18, -6), vf, 1.5)
	check.call(_until(st, b, func(): return m2.phase == "land", 3.0) and taken.size() == 1 and taken[0][0] == "meteor" and int(taken[0][1]) == MeteorStage.LAND_PENALTY,
		"meteor: one landing at your feet takes 25 points (%s)" % [taken])
	check.call(nibbled.size() == 2 and nibbled[1] == ["meteor", MeteorStage.GROUND_PENALTY.small] and int(MeteorStage.GROUND_PENALTY.small) == 10,
		"meteor: and the ground takes its 10 for a small one too (%s)" % [nibbled])
	_steps(st, b, MeteorStage.CRATER_T)
	check.call(st.craters.is_empty(), "meteor: the crater fades")

	# Shots: big -> two middle -> two small each -> fireworks.
	_fresh(st, b)
	m = _fly(st, "big", false, Vector3(0, 16, -14), Vector3(0, 0, -8))
	_steps(st, b, 0.3)
	var s0: int = st.meteor_state().score
	c0 = int(ctx.counts.get("meteor", 0))
	sfx.clear()
	check.call(st.shoot(m.proxy, m.c, Vector3.FORWARD) and not (m.proxy as MeshInstance3D).visible, "meteor: a shot hits a big one")
	var mids := _on(st, "mid")
	check.call(mids.size() == 2 and mids[0].c.distance_to(mids[1].c) > 0.3 and st.meteor_state().score == s0 + 10, "meteor: it splits into two middle ones (+10)")
	check.call(int(ctx.counts.get("meteor", 0)) == c0 + 10, "meteor: the points go to counts[meteor] for the jelly score")
	check.call(sfx.any(func(s): return s[0] == "boom") and extra.any(func(e): return e[0] == "ch" and e[1] == "meteor50"), "meteor: a boom, and it counts toward meteor50")
	_steps(st, b, 0.2)
	check.call(mids.all(func(q): return q.on and q.phase == "fall" and q.land.y == 0.0) and mids[0].land.distance_to(mids[1].land) > 1.0, "meteor: the pieces fly apart, each with its own landing spot")
	check.call(not st.shoot(m.proxy, m.c, Vector3.FORWARD), "meteor: a blasted one can't be hit again")
	# (far enough apart that they don't chain)
	mids[1].c += Vector3(8, 0, 0)
	st.shoot(mids[0].proxy, mids[0].c, Vector3.FORWARD)
	var smalls := _on(st, "small")
	check.call(smalls.size() == 2 and st.meteor_state().combo == 2, "meteor: a middle one splits into two small ones (combo %d)" % st.meteor_state().combo)
	smalls[1].c += Vector3(0, 0, -8)
	var fw0: int = st.meteor_state().fireworks
	f0 = st.fx_spawned
	sfx.clear()
	st.shoot(smalls[0].proxy, smalls[0].c, Vector3.FORWARD)
	check.call(not smalls[0].on and st.meteor_state().fireworks == fw0 + 1 and st.fx_spawned > f0 + 50 and sfx.any(func(s): return s[0] == "firework_burst"), "meteor: a small one bursts into a firework (%d sparks)" % (st.fx_spawned - f0))
	check.call(_on(st, "small").size() == 1 and _on(st, "mid").size() == 1, "meteor: and nothing new from a small one")

	# Combo: quick blasts step the multiplier up.
	_fresh(st, b)
	for k in 6:
		var q := _fly(st, "small", false, Vector3(-6 + k * 2.5, 15, -14), Vector3(-6 + k * 2.5, 0, -9))
		st.shoot(q.proxy, q.c, Vector3.FORWARD)
	check.call(st.meteor_state().combo == 6 and st.meteor_state().mult == 3 and st.combo_label.text != "", "meteor: six quick blasts: combo ×3")

	# Golden: ×5.
	_fresh(st, b)
	m = _fly(st, "small", true, Vector3(0, 15, -14), Vector3(0, 0, -9))
	check.call(m.golden and m.acc == "crown", "meteor: a golden one wears a crown")
	s0 = st.meteor_state().score
	extra.clear()
	st.shoot(m.proxy, m.c, Vector3.FORWARD)
	check.call(st.meteor_state().score == s0 + 125 and extra.any(func(e): return e[0] == "confetti"), "meteor: golden is worth ×5 (+%d) with confetti" % (st.meteor_state().score - s0))
	m = _fly(st, "big", true, Vector3(0, 15, -14), Vector3(0, 0, -9))
	st.shoot(m.proxy, m.c, Vector3.FORWARD)
	check.call(_on(st, "mid").size() == 2 and _on(st, "mid").all(func(q): return q.golden), "meteor: a golden big one splits into golden pieces")

	# Chain: an explosion sets off the meteors next to it, a moment later, with a bonus.
	_fresh(st, b)
	var a := _fly(st, "small", false, Vector3(0, 15, -14), Vector3(0, 0, -9))
	var n1 := _fly(st, "small", false, Vector3(1.2, 15, -14), Vector3(1.2, 0, -9))
	var n2 := _fly(st, "mid", false, Vector3(2.6, 15.3, -14), Vector3(2.6, 0, -9))
	var far := _fly(st, "small", false, Vector3(-9, 15, -14), Vector3(-9, 0, -9))
	s0 = st.meteor_state().score
	st.shoot(a.proxy, a.c, Vector3.FORWARD)
	check.call(n1.on and n1.chain_t > 0.0, "meteor: the neighbour is lit")
	_steps(st, b, 0.5)
	check.call(not n1.on and not n2.on and far.on and st.meteor_state().chains >= 2, "meteor: chain explosions (%d), the far one untouched" % st.meteor_state().chains)
	check.call(_on(st, "small").size() == 1 and st.meteor_state().score >= s0 + 25 + 35 + 45, "meteor: chained ones burst whole, with a bonus per link (+%d)" % (st.meteor_state().score - s0))

	# A thrown Dahrooj blasts one too.
	_fresh(st, b)
	m = _fly(st, "big", false, Vector3(0, 3.0, -8), Vector3(0, 0, -8.5), 3.0)
	m.v = Vector3.ZERO
	m.g = 0.0
	b.respawn()
	b.pos = m.c + Vector3(0, 0.2, 3.0)
	b.throw_with(Vector3(0, 0.5, -12))
	var thrown := func() -> bool:
		b.step(DT)
		return not m.on or m.kind != "big"
	check.call(_until(st, b, thrown, 1.5) and st.touched() and _on(st, "mid").size() == 2, "meteor: a thrown Dahrooj splits a big one")
	b.respawn()

	# Escalation: more often, faster, more at once; showers.
	check.call(MeteorStage.spawn_interval(10.0) < MeteorStage.spawn_interval(0.0) * 0.4 and MeteorStage.flight_time(10.0) < MeteorStage.flight_time(0.0) and MeteorStage.cap_at(8.0) > MeteorStage.cap_at(0.0), "meteor: it escalates with time")
	st.deactivate()
	st.auto_spawn = true
	st.update(b, DT)
	var spawned := {"n": 0}
	var t := 0.0
	while t < 30.0:
		st.update(b, DT)
		t += DT
	check.call(st.meteor_state().showers >= 1 and st.meteor_state().popped == 0 and st.meteor_state().landed >= 5 and st.meteor_state().state == "play", "meteor: a shower came, %d landed, still playing" % st.meteor_state().landed)
	spawned.n = st.meteor_state().landed
	st.F.t = 600.0
	st.F.shower_t = 999.0
	var landed0: int = st.meteor_state().landed
	_steps(st, b, 20.0)
	check.call(st.meteor_state().landed - landed0 > (spawned.n as int) and st.meteor_state().level >= 20.0, "meteor: ten minutes in they come thick and fast (%d in 20 s)" % (st.meteor_state().landed - landed0))
	check.call(st.meteor_state().alive <= MeteorStage.SLOTS and st.meteor_state().state == "play", "meteor: endless, never over")

	# Mixed reality: through the ceiling to the floor.
	st.deactivate()
	st.size = 2.0
	st.viewer = Vector3(0, 12.8, 0)
	st.planes_provider = func() -> Array:
		return [
			{"pos": Vector3(0, 20, -8), "normal": Vector3.DOWN, "ax": Vector3.RIGHT, "ay": Vector3.BACK, "half": Vector2(14, 14), "label": "ceiling"},
			{"pos": Vector3(0, 0.0, -8), "normal": Vector3.UP, "ax": Vector3.RIGHT, "ay": Vector3.BACK, "half": Vector2(14, 14), "label": "floor"},
			{"pos": Vector3(0, 10, -22), "normal": Vector3.BACK, "ax": Vector3.RIGHT, "ay": Vector3.UP, "half": Vector2(14, 10), "label": "wall"}]
	st._room_t = 0.0
	st.auto_spawn = false
	st.start()
	st.update(b, DT)
	check.call(st.room() and st.floor_y() == 0.0, "meteor: the room's planes are read")
	var i := st.spawn("mid", false, {"ceiling": true})
	m = st.meteors[i]
	check.call(m.phase == "crack" and absf(m.c.y - 20.0) < 1.0 and not (m.proxy as MeshInstance3D).visible and st.craters.size() == 1 and st.craters[0].crack, "meteor: the ceiling cracks first (y %.1f)" % m.c.y)
	check.call(absf(m.land.z + 8.0) <= 14.0 and absf(m.land.x) <= 14.0 and Vector2(m.land.x, m.land.z).length() > 1.6 * 2.0, "meteor: aimed at the floor, not on your head (%s)" % m.land)
	check.call(_until(st, b, func(): return m.phase == "fall", 1.5) and m.v.y < 0.0 and st.craters[0].heat == 1.0, "meteor: it breaks through and falls")
	check.call(_until(st, b, func(): return m.phase == "land", 5.0) and absf(m.c.y - m.r * 0.5) < 0.5, "meteor: it lands on the floor")
	st.deactivate()
	st.planes_provider = Callable()
	st.size = 1.0
	st.viewer = Vector3(0, 3.2, 1.0)
	st._room_t = 0.0
	st.auto_spawn = false
	st.start()
	st.update(b, DT)
	i = st.spawn("small")
	check.call(not st.room() and st.meteors[i].phase == "fall" and st.meteors[i].c.y > 15.0, "meteor: no scan: from the sky")

	# Paused / hidden: nothing moves; deactivate clears everything.
	m = st.meteors[i]
	var y0: float = m.c.y
	st.paused = true
	_steps(st, b, 0.5)
	st.paused = false
	check.call(m.c.y == y0, "meteor: held while paused")
	st.deactivate()
	check.call(st.meteor_state().alive == 0 and st.craters.is_empty() and st.meteor_state().state == "idle", "meteor: deactivate clears the sky")
	# Quick blasts in a row feed the combo, and its length goes toward combo10.
	extra.clear()
	for k in 3:
		st._score(1, Vector3.ZERO, true)
	check.call(extra.any(func(e): return e[0] == "ch" and e[1] == "combo10" and int(e[2]) == 3), "meteor: a combo of three counts toward combo10")
	st.free()
