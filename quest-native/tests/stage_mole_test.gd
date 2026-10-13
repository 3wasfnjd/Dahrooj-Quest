extends RefCounted
## Whack-a-Dahrooj (mole): moles open a hole, rise, stay and hide on a timer; a thrown ball
## scores on a raised mole but not on a hidden one; a blaster shot scores; the golden one is
## worth more and the sleepy one costs; open play: no round, clock or board, the points go to
## counts[mole] and they keep coming at a steady pace; wall spots orient the hole and the mole
## along the wall's normal.


static func _until(st: MoleStage, b: Ball, i: int, phase: String, limit: float) -> bool:
	var t := 0.0
	while t < limit:
		if st.moles[i].phase == phase:
			return true
		st.update(b, 1.0 / 72.0)
		t += 1.0 / 72.0
	return st.moles[i].phase == phase


static func run(check: Callable) -> void:
	var sfx: Array = []
	var counts: Array = []
	var extra: Array = []
	var st := MoleStage.new()
	st.auto_spawn = false
	var b := Ball.new()
	var ctx := GameCtx.new()
	ctx.ball = b
	ctx.sfx = func(n, k, _p): sfx.append([n, k])
	ctx.add_count = func(m, r): counts.append([m, r])
	ctx.toast = func(t): extra.append(["toast", t])
	ctx.ch_progress = func(id, v): extra.append(["ch", id, v])
	ctx.confetti = func(p, _r, _e, _s): extra.append(["confetti", p])
	st.ctx = ctx
	b.set_stage(st, "mole")
	check.call(st.get_node_or_null("Board") == null and not ("labels" in st) and not st.mole_state().has("time"), "mole: no score board and no round clock")
	check.call(st.grid.size() == 20 and st.grid.all(func(s): return s.pos.z < -4.5 and s.pos.z > -14.5 and absf(s.pos.x) < 6.0), "mole: 20 ground spots in the field in front")

	# Up and down on a timer.
	var spot := {"pos": Vector3(0, 0, -8), "normal": Vector3.UP}
	var i := st.spawn("plain", spot)
	var m: Dictionary = st.moles[i]
	check.call(i >= 0 and m.phase == "open" and not MoleStage.hittable(m) and sfx.any(func(s): return s[0] == "thump"), "mole: the ground cracks open first (thump), nothing to hit yet")
	check.call(st._debris.size() > 0, "mole: earth flies out of the hole")
	# A ball where he will be does nothing while he is still underground.
	b.shot = true
	b.pos = Vector3(0, MoleStage.R * 0.9, -8 + 0.1)
	b.prev = b.pos
	b.vel = Vector3(0, 0, -8)
	st.collide(b)
	check.call(st.mole_state().score == 0 and m.phase == "open" and b.vel.z < 0.0, "mole: a hidden one can't be hit")
	b.respawn()
	check.call(_until(st, b, i, "up", 0.6) and MoleStage.hittable(m), "mole: he rises out of the hole")
	check.call(m.c.y > 0.2 and st.moles_state()[i].hittable and m.proxy.visible and m.proxy.layers == 0 and m.proxy is MeshInstance3D, "mole: he's up, with an undrawn hit sphere for the blaster")
	check.call(_until(st, b, i, "close", m.up_t + 0.5) and not MoleStage.hittable(m) and not m.proxy.visible, "mole: he ducks back on a timer")
	check.call(_until(st, b, i, "", 0.5) or not m.on, "mole: the hole closes and he's gone")
	check.call(not m.on and not m.hole.visible, "mole: the slot is free again")

	# A thrown Dahrooj at a raised one.
	i = st.spawn("plain", spot)
	m = st.moles[i]
	_until(st, b, i, "up", 0.6)
	b.respawn()
	b.pos = m.c + Vector3(0, 0.6, 3.0)
	b.throw_with(Vector3(0, 1.0, -10))
	for k in 72:
		b.step(1.0 / 72.0)
		if m.phase == "hit":
			break
	check.call(m.phase == "hit" and st.mole_state().score == 1, "mole: a thrown ball whacks a raised one (score %d)" % st.mole_state().score)
	check.call(st.touched() and sfx.any(func(s): return s[0] == "start_pop") and sfx.any(func(s): return s[0] == "squeak"), "mole: pop and squeak, and the throw counts as touched")
	check.call(int(ctx.counts.get("mole", 0)) == 1 and counts.is_empty() and extra.any(func(e): return e[0] == "ch" and e[1] == "mole20"), "mole: the whack goes to counts[mole] (the jelly score) and toward mole20")
	st.draw()
	check.call(st._stars_mm.visible_instance_count >= 3, "mole: dizzy stars over his head")
	check.call(not MoleStage.hittable(m), "mole: a whacked one can't be hit again")
	b.respawn()

	# The blaster.
	var j := st.spawn("plain", {"pos": Vector3(2, 0, -11), "normal": Vector3.UP})
	var mj: Dictionary = st.moles[j]
	check.call(not st.shoot(mj.proxy, mj.spot, Vector3.FORWARD), "mole: a shot can't hit him underground")
	_until(st, b, j, "up", 0.6)
	var before: int = st.mole_state().score
	check.call(st.shoot(mj.proxy, mj.c, Vector3.FORWARD) and st.mole_state().score == before + 1 and mj.phase == "hit", "mole: a blaster shot whacks him")
	check.call(not st.shoot(mj.hole, mj.spot, Vector3.FORWARD), "mole: a shot at the hole scores nothing")

	# Golden and sleepy.
	var g := st.spawn("gold", {"pos": Vector3(-2, 0, -6), "normal": Vector3.UP})
	_until(st, b, g, "up", 0.6)
	before = st.mole_state().score
	st.shoot(st.moles[g].proxy, st.moles[g].c, Vector3.FORWARD)
	check.call(st.mole_state().score == before + 3, "mole: the golden one is worth 3")
	check.call(extra.any(func(e): return e[0] == "confetti"), "mole: the golden one throws confetti")
	check.call(JuiceText.showing(st).any(func(j: JuiceText) -> bool: return j.kind == "banner" and j.text == "دحروج ذهبي!"), "mole: and a festive «دحروج ذهبي!» banner")
	var z := st.spawn("sleepy", {"pos": Vector3(-4, 0, -12), "normal": Vector3.UP})
	_until(st, b, z, "up", 0.6)
	st.draw()
	check.call(st._eyes(st.moles[z]) == "shut" and st.moles[z].zzz.visible, "mole: the sleepy one dozes (eyes shut, Zzz)")
	before = st.mole_state().score
	st.shoot(st.moles[z].proxy, st.moles[z].c, Vector3.FORWARD)
	check.call(st.mole_state().score == before - 2 and st.mole_state().streak == 0 and int(ctx.counts.get("mole", 0)) == st.mole_state().score, "mole: waking the sleepy one costs 2 and the streak")

	# A streak of five throws confetti.
	extra.clear()
	for k in 5:
		var q := st.spawn("plain", {"pos": Vector3(-4 + k * 2.0, 0, -13.6), "normal": Vector3.UP})
		_until(st, b, q, "up", 0.6)
		st.shoot(st.moles[q].proxy, st.moles[q].c, Vector3.FORWARD)
	check.call(st.mole_state().streak == 5 and extra.any(func(e): return e[0] == "confetti"), "mole: five in a row, confetti")

	# Open play: they keep coming up on their own at a steady pace, with no time-out.
	st.auto_spawn = true
	var score0: int = st.mole_state().score
	var spawned := 0
	var t := 0.0
	var gaps := {"early": 0, "late": 0}
	var most := 0
	sfx.clear()
	extra.clear()
	while t < 90.0:
		st.update(b, 1.0 / 72.0)
		t += 1.0 / 72.0
		var up := 0
		for k in st.moles.size():
			if st.moles[k].on:
				up += 1
			if st.moles[k].on and st.moles[k].phase == "open" and st.moles[k].t == 1.0 / 72.0:
				spawned += 1
				if t < 30.0:
					gaps.early += 1
				elif t > 60.0:
					gaps.late += 1
		most = maxi(most, up)
	check.call(spawned > 60 and gaps.early > 15 and gaps.late > 15 and absi(gaps.late - gaps.early) <= maxi(6, gaps.early / 3), "mole: they keep coming at a steady pace (%d early, %d late)" % [gaps.early, gaps.late])
	check.call(most <= 3 and st.moles.any(func(x): return x.on), "mole: a comfortable few at a time (%d), still coming after 90 s" % most)
	check.call(not extra.any(func(e): return e[0] == "toast") and not sfx.any(func(s): return s[0] == "chime") and st.mole_state().score == score0, "mole: no time-out, the score stays (%d)" % st.mole_state().score)
	var up_t := 0.0
	for k in st.moles.size():
		if st.moles[k].on and st.moles[k].kind == "plain":
			up_t = maxf(up_t, st.moles[k].up_t)
	check.call(up_t == 0.0 or up_t > 1.6, "mole: they stay up a comfortable while (%.2f s)" % up_t)

	# Room spots: a wall facing -x.
	st.deactivate()
	st.auto_spawn = false
	var wall := Vector3(3, 1.5, -6)
	st.spots_provider = func() -> Array: return [{"pos": wall, "normal": Vector3(-1, 0, 0)}]
	var w := st.spawn()
	check.call(w >= 0 and st.moles[w].spot == wall and not st.moles[w].sink, "mole: a room spot from the provider (no sinking)")
	_until(st, b, w, "up", 0.6)
	var ws: Dictionary = st.moles_state()[w]
	var off: Vector3 = ws.c - wall
	check.call(ws.normal.distance_to(Vector3(-1, 0, 0)) < 1e-4 and ws.hole_up.distance_to(Vector3(-1, 0, 0)) < 1e-3, "mole: the hole faces along the wall's normal")
	check.call(off.length() > 0.2 and off.normalized().distance_to(Vector3(-1, 0, 0)) < 1e-3, "mole: he pokes out of the wall along its normal (%.2f)" % off.length())
	var face: Vector3 = (st.moles[w].proxy.transform.basis.z as Vector3).normalized()
	check.call(face.dot(Vector3(-1, 0, 0)) > 0.25, "mole: he looks out of the wall, not into it")
	check.call(st.shoot(st.moles[w].proxy, ws.c, Vector3(1, 0, 0)), "mole: a wall mole can be shot")
	st.spots_provider = func() -> Array: return []
	var gnd := st.spawn()
	check.call(gnd >= 0 and st.moles[gnd].n == Vector3.UP and st.moles[gnd].sink, "mole: no room spots, the ground field")
	st.deactivate()
	check.call(st.moles.all(func(x): return not x.on) and st.mole_state().score == 0 and int(ctx.counts.get("mole", 0)) > 0, "mole: deactivate clears the field (counts[mole] stays)")
	b.set_stage(null, "")
	st.free()
