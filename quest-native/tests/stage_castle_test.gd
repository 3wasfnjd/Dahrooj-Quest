extends RefCounted
## Dahrooj Fort (castle): ladder carriers raise a ladder and climb, shots and thrown balls
## knock them off for points in counts[castle]; knocking a ladder or the bottom of a living
## tower topples everyone above (a chain bonus); who gets up plants a flag and dances (no
## penalty, the combo resets; knocking him off takes the flag down); parachuters, catapults
## and the siege tower; endless escalating waves with no way to lose; the room's walls and
## ceiling in mixed reality.

const DT := 1.0 / 72.0


static func _until(st: CastleStage, b: Ball, cond: Callable, limit: float) -> bool:
	var t := 0.0
	while t < limit:
		if cond.call():
			return true
		st.update(b, DT)
		t += DT
	return cond.call()


static func _run(st: CastleStage, b: Ball, secs: float) -> void:
	for i in int(secs / DT):
		st.update(b, DT)


static func _count(ctx: GameCtx) -> int:
	return int(ctx.counts.get("castle", 0))


static func run(check: Callable) -> void:
	var sfx: Array = []
	var extra: Array = []
	var st := CastleStage.new()
	st.auto_spawn = false
	var b := Ball.new()
	var ctx := GameCtx.new()
	ctx.ball = b
	ctx.lang = "en"
	ctx.sfx = func(n, k, _p): sfx.append([n, k])
	ctx.toast = func(t): extra.append(["toast", t])
	ctx.ch_progress = func(id, v): extra.append(["ch", id, v])
	ctx.confetti = func(p, _r, _e, _s): extra.append(["confetti", p])
	var buzzes: Array = []
	st.buzz = func(h, a, ms): buzzes.append([h, a, ms])
	st.ctx = ctx
	b.set_stage(st, "castle")
	st.F.wave = 1
	st.F.state = "wave"
	var cs := st.castle_state()
	check.call(st.get_node_or_null("Board") == null and not cs.has("lives") and not cs.has("time"), "castle: no board, no lives, no clock")
	check.call(st.fort is MeshInstance3D and st.fort.layers != 0 and st.fort.visible, "castle: the fort is a solid, drawn mesh")
	check.call(not st.shoot(st.fort, st.to_game(Vector3(0, 1, CastleStage.W)), Vector3.FORWARD), "castle: a shot at the fort's wall scores nothing")
	var pt := Vector3(1.3, 2.0, -4.0)
	check.call(st.to_game(st.to_fort(pt)).distance_to(pt) < 1e-4, "castle: game <-> fort units round trip (turned 45°)")
	check.call(st.faces().size() == 2 and st.front_face() in st.faces(), "castle: two walls face the player (%s)" % [st.faces()])

	# A ladder carrier: walks in, raises the ladder, climbs.
	var i := st.spawn_ladder(0, 0.55)
	var d: Dictionary = st.dudes[i]
	var lad: Dictionary = st.ladders[d.ladder]
	check.call(i >= 0 and d.phase == "walk" and lad.state == "carried", "castle: a Dahrooj walks in with a ladder over his head")
	check.call(_until(st, b, func(): return d.phase == "climb", 20.0) and lad.state == "up", "castle: he raises the ladder against the wall and climbs")
	check.call(_until(st, b, func(): return d.c.y > 1.2, 3.0), "castle: up the ladder (%.2f)" % d.c.y)
	st.draw()
	var px: MeshInstance3D = d.proxy
	check.call(px.visible and px.layers == 0, "castle: an undrawn hit sphere follows him for the blaster")
	check.call(st.shoot(px, st.to_game(d.c), Vector3.FORWARD) and d.phase == "tumble", "castle: a blaster shot knocks him off")
	check.call(_count(ctx) == 10 and st.castle_state().knocked == 1, "castle: +10 into counts[castle] (%d)" % _count(ctx))
	check.call(sfx.any(func(s): return s[0] == "start_pop") and sfx.any(func(s): return s[0] == "squeak") and not buzzes.is_empty(), "castle: pop, squeak and a buzz")
	check.call(extra.any(func(e): return e[0] == "ch" and e[1] == "castle25"), "castle: knocks count toward castle25")
	check.call(not st.shoot(px, st.to_game(d.c), Vector3.FORWARD), "castle: a tumbling one can't be hit again")
	check.call(_until(st, b, func(): return d.phase == "dizzy", 4.0), "castle: he bounces down and sees stars")
	st.draw()
	check.call(st._mm.stars.visible_instance_count >= 3, "castle: dizzy stars over him")
	check.call(_until(st, b, func(): return not d.on, 2.0), "castle: then he pops")
	check.call(lad.on and lad.state == "up", "castle: the ladder stays up")

	# Followers climb the ladder that is up; knocking the ladder drops them all (a chain).
	var f1 := st.spawn_follower()
	var f2 := st.spawn_follower()
	check.call(st.dudes[f1].ladder == d.ladder or st.dudes[f1].ladder >= 0, "castle: followers head for a standing ladder")
	check.call(_until(st, b, func(): return st.dudes[f1].phase == "climb" and st.dudes[f2].phase == "climb", 25.0), "castle: two climb it, one after the other")
	var before := _count(ctx)
	st.draw()
	var li := int(st.dudes[f1].ladder)
	check.call(st.shoot(st.ladders[li].proxy, Vector3.ZERO, Vector3.FORWARD), "castle: a shot at the ladder knocks it over")
	check.call(st.dudes[f1].phase == "tumble" and st.dudes[f2].phase == "tumble" and st.ladders[li].state == "falling", "castle: both riders tumble off, the ladder falls")
	check.call(_count(ctx) - before >= 2 * 10 + 20, "castle: chain bonus for the ladder (%d)" % (_count(ctx) - before))
	check.call(_until(st, b, func(): return not st.ladders[li].on, 4.0), "castle: the fallen ladder fades away")

	# A living tower: the gang hops onto each other; the bottom one topples them all.
	st.F.combo_t = 0.0
	var gid := st.spawn_stack(5, 1, -0.55)
	var g: Dictionary = st.groups[gid]
	check.call(_until(st, b, func(): return (g.stack as Array).size() >= 3 and st.dudes[g.stack[2]].phase == "brace", 30.0), "castle: they stack up three high")
	var tower: Array = (g.stack as Array).duplicate()
	var top_y: float = st.dudes[tower[tower.size() - 1]].c.y
	check.call(top_y > 1.6, "castle: the tower stands tall (%.2f)" % top_y)
	before = _count(ctx)
	var chain0: int = st.castle_state().best_chain
	st.knock(tower[0], Vector3.FORWARD)
	check.call(tower.all(func(k): return st.dudes[k].phase == "tumble"), "castle: knock the bottom one and the whole tower topples")
	check.call(st.castle_state().best_chain >= 3 and st.castle_state().best_chain > chain0 - 1 and st.banner.text.begins_with("TOPPLE"), "castle: TOPPLE banner (%s)" % st.banner.text)
	check.call(_count(ctx) - before >= tower.size() * 10 + 5 * 9, "castle: a big chain bonus (%d)" % (_count(ctx) - before))
	check.call(st.castle_state().mult >= 2, "castle: the combo multiplier climbs (×%d)" % st.castle_state().mult)
	check.call(extra.any(func(e): return e[0] == "confetti"), "castle: confetti for the topple")
	_run(st, b, 6.0)

	# Getting to the top: flag up, a dance, the combo resets (no other penalty).
	var j := st.spawn_ladder(0, -1.65)
	var dj: Dictionary = st.dudes[j]
	st.F.combo = 4
	st.F.combo_t = 99.0
	st.F.mult = 2
	var score_before := _count(ctx)
	check.call(_until(st, b, func(): return dj.phase == "dance", 30.0), "castle: a climber gets over the wall and dances")
	check.call(st.castle_state().planted >= 1 and st.castle_state().combo == 0 and st.castle_state().mult == 1, "castle: flag up resets the combo")
	check.call(_count(ctx) == score_before and st.castle_state().state == "wave", "castle: no points lost, no game over")
	check.call(dj.spot >= 0 and dj.c.y > CastleStage.H, "castle: he stands on the wall (%.2f)" % dj.c.y)
	st.draw()
	check.call(st._mm.poles.visible_instance_count >= 1 and st._mm.cloth.visible_instance_count >= 1, "castle: his silly flag is up")
	before = _count(ctx)
	check.call(st.shoot(dj.proxy, Vector3.ZERO, Vector3.FORWARD) and _count(ctx) - before == 20, "castle: knocking the flag-planter off is worth 20")
	st.draw()
	check.call(st._mm.poles.visible_instance_count == 0 and dj.spot < 0, "castle: the flag comes down with him")
	_run(st, b, 4.0)

	# A parachuter: shoot his canopy.
	var q := st.spawn_para()
	var dq: Dictionary = st.dudes[q]
	_run(st, b, 0.5)
	st.draw()
	var cp: MeshInstance3D = st.canopies[dq.canopy].proxy
	check.call(q >= 0 and dq.phase == "para" and dq.c.y > CastleStage.H + 2.0 and cp.visible and cp.layers == 0, "castle: a parachuter floats down (canopy hit shape)")
	before = _count(ctx)
	check.call(st.shoot(cp, Vector3.ZERO, Vector3.FORWARD) and dq.phase == "tumble" and dq.canopy < 0, "castle: a shot pops the canopy and he drops")
	check.call(_count(ctx) - before == 15 * int(st.F.mult), "castle: in the air: 15")
	_run(st, b, 4.0)

	# A catapult: rolls in, flings its crew up; shoot one in flight; three hits smash it.
	var ci := st.spawn_catapult(3, 0)
	var cat: Dictionary = st.cats[ci]
	check.call(ci >= 0 and cat.ammo.size() == 3, "castle: a catapult rolls in with a crew of three")
	var flier := {"i": -1}
	var seen := func() -> bool:
		for k in st.dudes.size():
			if st.dudes[k].on and st.dudes[k].kind == "cat" and st.dudes[k].phase == "fling":
				flier.i = k
				return true
		return false
	check.call(_until(st, b, seen, 20.0), "castle: it flings a Dahrooj at the wall")
	_run(st, b, 0.3)
	st.F.combo_t = 0.0
	before = _count(ctx)
	check.call(st.knock(flier.i, Vector3.FORWARD) and _count(ctx) - before == 15, "castle: hit in flight: 15")
	st.draw()
	check.call((cat.proxy as MeshInstance3D).visible, "castle: the catapult has a hit shape")
	st.shoot(cat.proxy, Vector3.ZERO, Vector3.FORWARD)
	st.shoot(cat.proxy, Vector3.ZERO, Vector3.FORWARD)
	before = _count(ctx)
	check.call(st.shoot(cat.proxy, Vector3.ZERO, Vector3.FORWARD) and not cat.on, "castle: three shots smash the catapult")
	check.call(_count(ctx) - before >= 30 and st._planks.size() > 5, "castle: planks fly, +30 and more for its crew (%d)" % (_count(ctx) - before))
	_run(st, b, 4.0)

	# The siege tower: blast it apart piece by piece.
	st.F.wave = 4
	check.call(st.spawn_siege() and not st.spawn_siege(), "castle: one siege tower rolls in")
	_run(st, b, 1.0)
	st.draw()
	var sp: Array = st.siege.proxies
	check.call(sp.all(func(x): return x.visible and x.layers == 0), "castle: each piece has a hit shape")
	var deck_y: float = st.siege.pieces[CastleStage.DECK].y
	var riders1: Array = []
	for k in st.dudes.size():
		if st.dudes[k].on and st.dudes[k].kind == "siege" and st.dudes[k].piece == 1:
			riders1.append(k)
	for k in CastleStage.SIEGE_HP[1]:
		st.shoot(sp[1], Vector3.ZERO, Vector3.FORWARD)
	check.call(not st.siege.pieces[1].alive and riders1.all(func(k): return st.dudes[k].phase == "tumble"), "castle: a floor breaks and its riders tumble")
	_run(st, b, 1.0)
	check.call(st.siege.pieces[CastleStage.DECK].y < deck_y - 0.5, "castle: the floors above drop down (%.2f -> %.2f)" % [deck_y, st.siege.pieces[CastleStage.DECK].y])
	before = _count(ctx)
	for k in CastleStage.SIEGE_HP[0]:
		st.shoot(sp[0], Vector3.ZERO, Vector3.FORWARD)
	check.call(not st.siege.on and _count(ctx) - before >= 150, "castle: break the base and it all comes down (+%d)" % (_count(ctx) - before))
	check.call(st.banner.text.begins_with("SIEGE"), "castle: SIEGE TOWER DOWN banner")
	_run(st, b, 4.0)

	# The thrown Dahrooj: knocks a climber, bounces off the fort.
	var k2 := st.spawn_ladder(0, 1.65)
	var d2: Dictionary = st.dudes[k2]
	_until(st, b, func(): return d2.phase == "climb" and d2.c.y > 1.0, 25.0)
	b.respawn()
	var at := st.to_game(d2.c)
	b.pos = at + Vector3(0, 0.3, 2.5)
	b.throw_with(Vector3(0, 0.6, -10))
	var hit := false
	for k in 72:
		b.step(DT)
		if d2.phase == "tumble":
			hit = true
			break
	check.call(hit and st.touched(), "castle: a thrown Dahrooj knocks a climber off")
	b.respawn()
	var wall := st.to_game(Vector3(0, 1.0, CastleStage.W + 2.0))
	b.pos = wall
	var into := st._gdir(Vector3(0, 0, -12))
	b.throw_with(into)
	for k in 30:
		b.step(DT)
	check.call(st.to_fort(b.pos).z > CastleStage.W - 0.01 and st._ldir(b.vel).z > 0.0, "castle: the ball bounces off the wall")
	b.respawn()
	_run(st, b, 4.0)

	# Waves: bigger, faster, more kinds; endless and never lost.
	var p1 := st.wave_plan(1)
	var p8 := st.wave_plan(8)
	var kinds := {}
	for e in p8:
		kinds[e.k] = true
	check.call(p1.size() <= 5 and p8.size() > p1.size() and kinds.has("stack"), "castle: waves grow (%d -> %d)" % [p1.size(), p8.size()])
	check.call(st.wave_plan(4).any(func(e): return e.k == "siege") and st.wave_plan(8)[0].k == "siege", "castle: every 4th wave brings the siege tower")
	check.call(CastleStage.wave_speed(10) > CastleStage.wave_speed(1) and CastleStage.wave_speed(60) <= 2.0, "castle: they get faster, up to a cap")
	st.deactivate()
	check.call(st.dudes.all(func(x): return not x.on) and _count(ctx) > 0, "castle: deactivate clears the fort (counts stay)")
	st.auto_spawn = true
	var c0 := _count(ctx)
	var most := 0
	for k in int(150.0 / DT):
		st.update(b, DT)
		if k % 72 == 0:
			most = maxi(most, st.castle_state().dancing)
	cs = st.castle_state()
	check.call(cs.wave >= 4 and cs.state in ["wave", "break"], "castle: left alone the waves still go on (wave %d)" % cs.wave)
	check.call(most >= 4 and _count(ctx) == c0, "castle: idle: they party on the walls (%d), no points lost" % most)
	check.call(cs.dancing <= 4 * CastleStage.SPOT_N, "castle: never more dancers than spots")
	# Shooting along: points pour in.
	var hits := 0
	for k in int(40.0 / DT):
		st.update(b, DT)
		if k % 30 == 0:
			for n in st.dudes.size():
				if CastleStage.hittable(st.dudes[n]):
					if st.shoot(st.dudes[n].proxy, Vector3.ZERO, Vector3.FORWARD):
						hits += 1
					break
	check.call(hits > 20 and _count(ctx) > c0 + 200, "castle: shooting them pays (%d hits, +%d)" % [hits, _count(ctx) - c0])
	st.deactivate()

	# Mixed reality: they march out of the real walls and parachute from the real ceiling.
	st.auto_spawn = false
	st.F.wave = 2
	st.F.state = "wave"
	var wpos := st.to_game(Vector3(-2.0, 1.2, 14.0))
	var wn := st._gdir(Vector3(0, 0, -1))
	st.planes_provider = func() -> Array: return [
		{"pos": wpos, "normal": wn, "ax": st._gdir(Vector3.RIGHT), "ay": Vector3.UP, "half": Vector2(3.0, 1.2), "label": "wall"},
		{"pos": st.to_game(Vector3(0, 8.0, 0)), "normal": Vector3.DOWN, "ax": Vector3.RIGHT, "ay": Vector3.BACK, "half": Vector2(4, 4), "label": "ceiling"}]
	st._room_t = 0.0
	st.update(b, DT)
	var walls := st._room.filter(func(s): return s.kind == "wall")
	check.call(walls.size() == 3 and st._para_top() < 8.0, "castle: the room's wall gives spawn spots, the ceiling caps the sky (%.1f)" % st._para_top())
	var m := st.spawn_ladder(0, 0.55)
	var start: Vector3 = st.dudes[m].c
	check.call(walls.any(func(s): return Vector2(s.pos.x - start.x, s.pos.z - start.z).length() < 0.01), "castle: he marches out of the real wall")
	var pq := st.spawn_para()
	check.call(st.dudes[pq].c.y < 8.0, "castle: the parachuter starts under the real ceiling")
	st.planes_provider = func() -> Array: return []
	st._room_t = 0.0
	st.update(b, DT)
	check.call(st._room.is_empty(), "castle: no scan, the court")
	st.deactivate()
	b.set_stage(null, "")
	st.free()
