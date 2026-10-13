extends RefCounted
## Dahrooj Attack (invasion): a throw starts wave 1 (banner), the wave drops in from the far
## end and hops toward the player; a shot pops a small one; a tank takes several hits and
## splits in two; the boss has hit points, is knocked down by hits in the air and then takes
## double damage; open play: one that reaches the line just pops (flash, buzz, no hearts, no
## game over, no board) and the waves go on; the points feed ctx.counts["invasion"] (the jelly
## score popup); power-ups (triple shot, slow motion, bomb) work; quick pops build the combo
## multiplier; a cleared wave counts toward invasion10; mixed-reality wall spots.

const DT := 1.0 / 72.0


static func _steps(st: InvasionStage, b: Ball, secs: float) -> void:
	var t := 0.0
	while t < secs:
		st.update(b, DT)
		t += DT


static func _until(st: InvasionStage, b: Ball, cond: Callable, limit: float) -> bool:
	var t := 0.0
	while t < limit:
		if cond.call():
			return true
		st.update(b, DT)
		t += DT
	return cond.call()


static func _ground(x: float, z: float) -> Dictionary:
	return {"pos": Vector3(x, 0, z), "normal": Vector3.UP}


## A fresh game in wave n with no automatic spawns (the queue empty, one keeper far away so
## the wave doesn't count as cleared).
static func _fresh(st: InvasionStage, b: Ball, wave := 1) -> int:
	st.deactivate()
	st.auto_spawn = false
	st.start()
	st.F.wave = wave
	st.F.queue = []
	st.F.state = "wave"
	st.F.banner_t = 0.0
	var keep := st.spawn("plain", _ground(6.0, -40.0))
	st.invaders[keep].speed = 0.0
	st.update(b, DT)
	return keep


static func run(check: Callable) -> void:
	var sfx: Array = []
	var extra: Array = []
	var buzzes: Array = []
	var st := InvasionStage.new()
	var b := Ball.new()
	var ctx := GameCtx.new()
	ctx.ball = b
	ctx.sfx = func(n, k, _p): sfx.append([n, k])
	ctx.add_count = func(md, r): extra.append(["count", md, r])
	ctx.toast = func(t): extra.append(["toast", t])
	ctx.ch_progress = func(id, v): extra.append(["ch", id, v])
	ctx.confetti = func(p, _r, _e, _s): extra.append(["confetti", p])
	st.ctx = ctx
	st.buzz = func(h, a, ms): buzzes.append([h, a, ms])
	b.set_stage(st, "invasion")
	check.call(st.invasion_state().state == "idle" and st.get_node_or_null("Board") == null and not ("hearts" in st) and not ("labels" in st), "invasion: no score board and no hearts")
	check.call("invasion" in GameRuntime.MODES and not GameRuntime.challenge("invasion10").is_empty() and GameRuntime.challenge("invasion10")[3] == 10, "invasion: a mode of the runtime, with the invasion10 challenge")
	# Open play: shown, wave 1 starts on its own (no throw to start): a banner, then they drop
	# in from the far end and hop at you.
	st.update(b, DT)
	st.draw()
	check.call(st.invasion_state().state == "break" and st.invasion_state().wave == 1 and st.banner.visible and st.banner.text == "الموجة ١", "invasion: wave 1 starts on its own with a big banner (%s)" % st.banner.text)
	check.call(st.invasion_state().queue == 6 and not st.invasion_state().has("lives"), "invasion: six of them queued, no hearts")
	check.call(_until(st, b, func(): return st.invasion_state().state == "wave", 3.0), "invasion: the break ends and the wave comes")
	check.call(_until(st, b, func(): return st.invasion_state().alive >= 2, 4.0), "invasion: they spawn (%d alive)" % st.invasion_state().alive)
	var first: Dictionary = {}
	for q in st.invaders:
		if q.on and (first.is_empty() or q.c.y > first.c.y):
			first = q
	check.call(first.phase == "drop" and first.c.y > 5.0 and first.p.z < -20.0, "invasion: dropping in from the sky at the far end (z %.1f)" % first.p.z)
	_until(st, b, func(): return first.phase == "march", 3.0)
	var z0: float = first.p.z
	_steps(st, b, 1.5)
	check.call(first.on and first.phase == "march" and first.p.z > z0 + 1.5, "invasion: hopping toward the player (z %.1f -> %.1f)" % [z0, first.p.z])
	var max_y := 0.0
	for i in 60:
		st.update(b, DT)
		max_y = maxf(max_y, first.y)
	check.call(max_y > 0.2, "invasion: and they really hop (%.2f)" % max_y)
	_steps(st, b, 6.0)
	check.call(st.invasion_state().queue < 6 and st.invasion_state().wave == 1, "invasion: the queue runs down")

	# A shot pops a small one.
	_fresh(st, b)
	var i := st.spawn("fast", _ground(1.0, -12.0))
	var m: Dictionary = st.invaders[i]
	var proxy: MeshInstance3D = m.proxy
	check.call(m.phase == "march" and proxy.visible and proxy.layers == 0 and InvasionStage.hittable(m), "invasion: an undrawn hit sphere for the blaster")
	var s0: int = st.invasion_state().score
	var c0 := int(ctx.counts.get("invasion", 0))
	sfx.clear()
	check.call(st.shoot(proxy, m.c, Vector3.FORWARD) and not m.on and st.invasion_state().score == s0 + 15, "invasion: one shot pops a fast little one (+15)")
	check.call(int(ctx.counts.get("invasion", 0)) == c0 + 15, "invasion: the points go to counts[invasion] for the jelly score (%d)" % int(ctx.counts.get("invasion", 0)))
	check.call(sfx.any(func(s): return s[0] == "start_pop") and st._sparks.size() > 8 and extra.any(func(e): return e[0] == "ch" and e[1] == "pop20"), "invasion: pop, sparks, and it counts toward pop20")
	check.call(not st.shoot(proxy, m.c, Vector3.FORWARD), "invasion: a popped one can't be hit again")

	# A tank takes several hits and splits in two.
	_fresh(st, b)
	i = st.spawn("tank", _ground(-2.0, -14.0))
	m = st.invaders[i]
	check.call(m.hp == 3 and m.r > 0.7, "invasion: a tank is big with 3 hit points")
	st.shoot(m.proxy, m.c, Vector3.FORWARD)
	st.shoot(m.proxy, m.c, Vector3.FORWARD)
	check.call(m.on and m.hp == 1, "invasion: two shots don't stop a tank (hp %d)" % m.hp)
	st.draw()
	check.call((st._mm.bars as MultiMesh).visible_instance_count >= 2, "invasion: its hit points over its head")
	st.shoot(m.proxy, m.c, Vector3.FORWARD)
	var minis := st.invaders.filter(func(q): return q.on and q.kind == "mini")
	check.call(not st.invaders.any(func(q): return q.on and q.kind == "tank") and minis.size() == 2 and minis.all(func(q): return q.phase == "leap"), "invasion: the third pops it and it splits into two small ones")
	check.call(_until(st, b, func(): return minis.all(func(q): return q.phase == "march"), 3.0) and minis[0].p.distance_to(minis[1].p) > 0.4, "invasion: they land apart and keep coming")

	# A thrown Dahrooj hits hard (2) and bounces off.
	i = st.spawn("tank", _ground(0.0, -6.0))
	m = st.invaders[i]
	b.respawn()
	b.pos = m.c + Vector3(0, 0.3, 3.0)
	b.throw_with(Vector3(0, 1.0, -12))
	var thrown := func() -> bool:
		b.step(DT)
		return m.hp < 3
	check.call(_until(st, b, thrown, 1.5) and m.hp == 1 and st.touched(), "invasion: a thrown Dahrooj does 2 damage (hp %d)" % m.hp)
	b.respawn()

	# The boss: hit points, a jump to knock him out of, double damage while stunned.
	_fresh(st, b, 5)
	i = st.spawn("boss", _ground(0.0, -18.0))
	m = st.invaders[i]
	check.call(m.hp == 18 and m.acc == "crown" and m.r > 1.5, "invasion: the boss is giant, crowned, 18 hit points")
	for k in 10:
		st.shoot(m.proxy, m.c, Vector3.FORWARD)
	check.call(m.on and m.hp == 8, "invasion: ten shots take ten hit points (hp %d)" % m.hp)
	m.slam_cd = 0.0
	check.call(_until(st, b, func(): return m.act == "air", 2.0), "invasion: he crouches and jumps")
	_steps(st, b, 0.3)
	check.call(m.y > 2.0 and InvasionStage.hittable(m), "invasion: high in the air, still hittable (%.1f)" % m.y)
	for k in 3:
		st.shoot(m.proxy, m.c, Vector3.FORWARD)
	check.call(m.act == "fall" and m.hp == 5, "invasion: three hits in the air knock him down")
	check.call(_until(st, b, func(): return m.act == "stun", 2.0), "invasion: he lands stunned")
	st.draw()
	check.call((st._mm.stars as MultiMesh).visible_instance_count >= 3, "invasion: dizzy stars over his head")
	st.shoot(m.proxy, m.c, Vector3.FORWARD)
	check.call(m.hp == 3, "invasion: double damage while stunned (hp %d)" % m.hp)
	extra.clear()
	st.shoot(m.proxy, m.c, Vector3.FORWARD)
	st.shoot(m.proxy, m.c, Vector3.FORWARD)
	check.call(not m.on and st.banner.text == "هزمت الزعيم!" and extra.any(func(e): return e[0] == "confetti"), "invasion: the boss goes down (banner, confetti)")
	check.call(st.powerups.filter(func(q): return q.on).size() >= 2, "invasion: and drops power-ups")
	# A slam that lands: a shockwave and two little ones.
	_fresh(st, b, 5)
	i = st.spawn("boss", _ground(0.0, -18.0))
	m = st.invaders[i]
	m.slam_cd = 0.0
	_until(st, b, func(): return m.act == "air", 2.0)
	var n0 := st.invaders.filter(func(q): return q.on and q.kind == "mini").size()
	check.call(_until(st, b, func(): return m.act == "", 2.0) and m.p.z > -15.0, "invasion: unstopped, he slams down nearer (z %.1f)" % m.p.z)
	check.call(st.invaders.filter(func(q): return q.on and q.kind == "mini").size() == n0 + 2 and st._rings.size() >= 2, "invasion: with a shockwave and two little ones")

	# One that reaches the line just pops: a flash and a buzz, nothing lost, the game goes on.
	_fresh(st, b)
	buzzes.clear()
	var g := st.goal()
	i = st.spawn("plain", _ground(g.x, g.z - st.reach_r() - 0.6))
	m = st.invaders[i]
	check.call(_until(st, b, func(): return not m.on, 2.0) and st.invasion_state().breaches == 1, "invasion: reaching the line pops it (%d through)" % st.invasion_state().breaches)
	st.draw()
	check.call(st.F.flash_t > 0.0 and (st._mm.flash as MultiMesh).visible_instance_count == 1 and buzzes.size() >= 2, "invasion: a red flash around the head and a buzz in both hands")
	# Open-ended: however many get through, no game over; the score is never taken away.
	var counted := int(ctx.counts.get("invasion", 0))
	for k in 6:
		var q := st.spawn("plain", _ground(g.x + (k % 3) * 1.2 - 1.2, g.z - st.reach_r() - 0.4))
		st.invaders[q].hop_u = 0.5
	_steps(st, b, 1.5)
	check.call(st.invasion_state().breaches == 7 and st.invasion_state().state == "wave" and st.banner.text != "انتهت اللعبة", "invasion: seven through and still playing (%s)" % st.invasion_state().state)
	check.call(int(ctx.counts.get("invasion", 0)) == counted, "invasion: nothing comes off the score")
	_steps(st, b, 5.0)
	check.call(st.invasion_state().state == "wave" and st.invasion_state().wave == 1, "invasion: no game over later either")

	# Combo: quick pops raise the multiplier.
	check.call(InvasionStage.multiplier(1) == 1 and InvasionStage.multiplier(3) == 2 and InvasionStage.multiplier(6) == 3 and InvasionStage.multiplier(10) == 4 and InvasionStage.multiplier(15) == 5 and InvasionStage.multiplier(99) == 5, "invasion: the multiplier steps at 3, 6, 10, 15 pops")
	_fresh(st, b)
	var scores: Array = []
	for k in 4:
		var q := st.spawn("plain", _ground(-3.0 + k * 2.0, -12.0))
		var s1: int = st.invasion_state().score
		st.shoot(st.invaders[q].proxy, st.invaders[q].c, Vector3.FORWARD)
		scores.append(st.invasion_state().score - s1)
		st.update(b, DT)
	st.draw()
	check.call(scores == [10, 10, 20, 20] and st.invasion_state().mult == 2 and st.combo_label.visible, "invasion: quick pops build a combo ×2 (%s)" % [scores])
	_steps(st, b, InvasionStage.COMBO_T + 0.1)
	check.call(st.invasion_state().mult == 1 and st.invasion_state().combo == 0, "invasion: the combo runs out after a pause")

	# Power-ups: shot to collect.
	var u := st.drop_powerup("triple", Vector3(0, 1, -10))
	_steps(st, b, 0.6)
	var pu: Dictionary = st.powerups[u]
	check.call(pu.on and pu.p.y > 1.5 and (pu.proxy as MeshInstance3D).visible and (pu.label as Label3D).text == "طلقة ثلاثية", "invasion: a power-up floats up in its bubble, named")
	check.call(st.shot_fan() == 1 and st.shoot(pu.proxy, pu.p, Vector3.FORWARD) and not pu.on, "invasion: a shot collects it")
	check.call(st.invasion_state().triple and st.shot_fan() == 3, "invasion: triple shot on (the blaster fires three)")
	_steps(st, b, InvasionStage.TRIPLE_T + 0.2)
	check.call(st.shot_fan() == 1, "invasion: triple shot wears off")
	u = st.drop_powerup("slow", Vector3(0, 1, -10))
	st.collect(u)
	_steps(st, b, 0.5)
	check.call(st.invasion_state().slow and absf(st.time_scale - InvasionStage.SLOW_SCALE) < 1e-3 and st.audio_pitch() < 0.8, "invasion: slow motion (time_scale %.2f, pitch %.2f)" % [st.time_scale, st.audio_pitch()])
	_steps(st, b, InvasionStage.SLOW_T)
	check.call(not st.invasion_state().slow and st.time_scale == 1.0 and st.audio_pitch() == 1.0, "invasion: and back to full speed")
	# Bomb: everything near pops, the far ones don't.
	_fresh(st, b)
	var near := st.spawn("plain", _ground(1.5, -10.0))
	var near_t := st.spawn("tank", _ground(-2.5, -11.0))
	var far := st.spawn("plain", _ground(0.0, -10.0 - InvasionStage.BOMB_R - 3.0))
	u = st.drop_powerup("bomb", Vector3(0, 2.5, -10))
	st.powerups[u].p = Vector3(0, 2.5, -10)
	st.collect(u)
	var left := st.invaders.filter(func(q): return q.on and q.kind != "mini" and Vector2(q.p.x, q.p.z + 10.0).length() < InvasionStage.BOMB_R)
	check.call(near != near_t and left.is_empty() and st.invaders[far].on and st.invaders[far].kind == "plain", "invasion: the bomb pops everything within its radius, not beyond")
	check.call(sfx.any(func(s): return s[0] == "boom") and st._rings.size() > 0, "invasion: with a boom and a blast ring")
	# A thrown Dahrooj collects one too.
	u = st.drop_powerup("triple", Vector3(0, 2, -6))
	st.powerups[u].p = Vector3(0, 2, -6)
	st.powerups[u].v = Vector3.ZERO
	st.powerups[u].home_y = 2.0
	b.respawn()
	b.pos = Vector3(0, 2, -4)
	b.throw_with(Vector3(0, 0, -12))
	var pu_t: Dictionary = st.powerups[u]
	var caught := func() -> bool:
		b.step(DT)
		return not pu_t.on
	check.call(_until(st, b, caught, 0.5), "invasion: a thrown Dahrooj collects a power-up")
	b.respawn()

	# A cleared wave: next wave, counted, challenge progress.
	_fresh(st, b, 2)
	extra.clear()
	for q in st.invaders:
		if q.on:
			q.on = false
	st.update(b, DT)
	check.call(st.invasion_state().wave == 3 and st.invasion_state().state == "break" and extra.any(func(e): return e[0] == "ch" and e[1] == "invasion10" and e[2] == 2),
		"invasion: a cleared wave counts toward invasion10 and the next one begins")
	# Waves keep coming forever: run a few through on their own.
	st.auto_spawn = true
	var reached := func() -> bool:
		for q in st.invaders:
			if q.on and InvasionStage.hittable(q) and q.phase == "march":
				st.shoot(q.proxy, q.c, Vector3.FORWARD)
		return st.invasion_state().wave >= 6
	check.call(_until(st, b, reached, 120.0) and st.invasion_state().state != "idle", "invasion: wave after wave, on and on (wave %d)" % st.invasion_state().wave)
	st.auto_spawn = false
	var plan := st.wave_plan(10)
	check.call(plan[0] == "boss" and st.wave_plan(1).size() == 6 and st.wave_plan(1).all(func(k): return k == "plain") and st.wave_plan(8).size() > st.wave_plan(3).size(), "invasion: every 5th wave a boss; waves grow")
	check.call(InvasionStage.wave_speed(8) > InvasionStage.wave_speed(1), "invasion: and speed up")

	# Mixed reality: they burst out of a scanned wall and fall into the room.
	_fresh(st, b)
	st.size = 2.0
	st.spots_provider = func() -> Array: return [{"pos": Vector3(6.0, 3.0, -6.0), "normal": Vector3(-1, 0, 0)}]
	var w := -1
	for k in 10:
		w = st.spawn("plain")
		if st.invaders[w].phase == "emerge":
			break
		st.invaders[w].on = false
	m = st.invaders[w]
	check.call(m.phase == "emerge" and st._holes.size() > 0 and m.r > 0.85, "invasion: out of a wall, bigger in the room")
	check.call(_until(st, b, func(): return m.phase == "march", 3.0) and m.p.x < 6.0 and m.c.y < 2.0, "invasion: it leaps out and lands on the floor (x %.1f)" % m.p.x)
	st.size = 1.0
	st.spots_provider = Callable()

	st.deactivate()
	check.call(st.invasion_state().state == "idle" and st.invasion_state().alive == 0 and st.time_scale == 1.0, "invasion: deactivate clears the field")
	st.free()
