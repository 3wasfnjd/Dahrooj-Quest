extends RefCounted
## Pop Frenzy (frenzy): the air fills on its own; a shot on a bubble's hidden sphere pops it
## and the points go to ctx.counts["frenzy"]; the same colour in a row builds the chain and its
## multiplier, another colour starts over; a pop spreads to touching same-coloured ones; a big
## bubble spills little ones; the rainbow pops every one of the chain's colour; 10 in a chain is
## FRENZY (gold, time_scale 0.5, lower pitch, a fan of shots, double points, fireworks) for 6 s;
## open play (no board, no lives, it refills forever and only gets busier); a thrown Dahrooj
## pops them too; mixed reality: the room's planes bound the air and they bounce off them.

const DT := 1.0 / 72.0


static func _steps(st: FrenzyStage, b: Ball, secs: float) -> void:
	var t := 0.0
	while t < secs:
		st.update(b, DT)
		t += DT


## A fresh, empty air with no automatic spawns.
static func _fresh(st: FrenzyStage, b: Ball) -> void:
	st.deactivate()
	st.auto_spawn = false
	st.F.filled = true
	st.update(b, DT)


## A grown-in one of a kind and colour at p, not moving.
static func _put(st: FrenzyStage, kind: String, col: int, p: Vector3) -> int:
	var i := st.spawn(kind, col, p, Vector3.ZERO)
	st.items[i].grow = 1.0
	return i


static func run(check: Callable) -> void:
	var sfx: Array = []
	var extra: Array = []
	var buzzes: Array = []
	var st := FrenzyStage.new()
	var b := Ball.new()
	var ctx := GameCtx.new()
	ctx.ball = b
	ctx.lang = "en"
	ctx.sfx = func(n, k, _p): sfx.append([n, k])
	ctx.add_count = func(md, r): extra.append(["count", md, r])
	ctx.toast = func(t): extra.append(["toast", t])
	ctx.ch_progress = func(id, v): extra.append(["ch", id, v])
	ctx.tally = func(id, n): extra.append(["tally", id, n])
	ctx.confetti = func(p, _r, _e, _s): extra.append(["confetti", p])
	st.ctx = ctx
	st.buzz = func(h, a, ms): buzzes.append([h, a, ms])
	b.set_stage(st, "frenzy")
	check.call(st.get_node_or_null("Board") == null and not ("hearts" in st) and not ("lives" in st), "frenzy: no score board and no hearts")

	# The air fills on its own as soon as it is shown.
	st.update(b, DT)
	var s0 := st.frenzy_state()
	check.call(s0.alive >= 20 and s0.alive <= s0.target, "frenzy: the air fills on its own (%d of %d)" % [s0.alive, s0.target])
	_steps(st, b, 1.5)
	var kinds := {}
	var cols := {}
	for it in st.items:
		if it.on:
			kinds[it.kind] = true
			cols[it.col] = true
	check.call(kinds.has("bubble") and kinds.has("dahrooj") and cols.size() >= 3, "frenzy: bubbles and little Dahroojs in several colours (%s, %d colours)" % [kinds.keys(), cols.size()])
	check.call(st.crowd.count() > 0 and (st._mm.bubbles as MultiMesh).visible_instance_count > 0, "frenzy: drawn as MultiMeshes (%d Dahroojs, %d bubbles)" % [st.crowd.count(), (st._mm.bubbles as MultiMesh).visible_instance_count])
	var hidden := true
	var proxies := 0
	for it in st.items:
		var px: MeshInstance3D = it.proxy
		if px.visible:
			proxies += 1
			hidden = hidden and px.layers == 0
	check.call(proxies > 10 and hidden, "frenzy: hidden (layers 0) blaster spheres for the ones that can be popped (%d)" % proxies)

	# A shot pops one: points into ctx.counts["frenzy"], sounds, droplets, a ring.
	_fresh(st, b)
	ctx.counts["frenzy"] = 0
	var a := _put(st, "bubble", 0, Vector3(-3, 3, -6))
	st.update(b, DT)
	sfx.clear()
	var took := st.shoot(st.items[a].proxy, st.items[a].p, Vector3.FORWARD)
	check.call(took and not st.items[a].on and int(ctx.counts["frenzy"]) == 1 and st.frenzy_state().popped == 1, "frenzy: a shot pops a bubble and scores (%d)" % int(ctx.counts["frenzy"]))
	check.call(sfx.any(func(e): return e[0] == "start_pop") and st._sparks.size() >= 8 and st._rings.size() >= 1, "frenzy: a pop sounds, sprays droplets and rings")
	check.call(extra.has(["tally", "frenzy500", 1]), "frenzy: each pop counts toward frenzy500")
	check.call(not st.shoot(st.items[a].proxy, Vector3.ZERO, Vector3.FORWARD), "frenzy: a popped one can't be shot again")
	check.call(not buzzes.is_empty(), "frenzy: pops buzz the hands")

	# The colour chain: same colour builds it, another colour starts over.
	_fresh(st, b)
	var xs := [-6.0, -4.0, -2.0, 0.0, 2.0, 4.0]
	var ids := []
	for k in 6:
		ids.append(_put(st, "bubble", 1, Vector3(xs[k], 4.0, -8.0)))
	var other := _put(st, "bubble", 2, Vector3(0, 1.5, -10.0))
	st.update(b, DT)
	for k in 3:
		st.shoot(st.items[ids[k]].proxy, Vector3.ZERO, Vector3.FORWARD)
	var s1 := st.frenzy_state()
	check.call(s1.chain == 3 and s1.chain_col == 1 and s1.mult == 2, "frenzy: three blues in a row: chain 3, ×2 (%d, ×%d)" % [s1.chain, s1.mult])
	check.call(st.combo_label.text.contains("BLUE") and st.chain_color() == Color(FrenzyStage.COLORS[1][0]), "frenzy: the chain's colour is shown (%s)" % st.combo_label.text)
	var before := int(ctx.counts["frenzy"])
	st.shoot(st.items[ids[3]].proxy, Vector3.ZERO, Vector3.FORWARD)
	check.call(int(ctx.counts["frenzy"]) - before == 2, "frenzy: the multiplier counts (+%d)" % (int(ctx.counts["frenzy"]) - before))
	st.draw()
	var lit := 0
	st.hands = {"right": Transform3D(Basis.IDENTITY, Vector3(0.4, 2.4, 0.2))}
	st.draw()
	lit = (st._mm.beads as MultiMesh).visible_instance_count
	check.call(lit == FrenzyStage.BEADS and (st._mm.halo as MultiMesh).visible_instance_count == 1, "frenzy: a ring of beads glows around the hand")
	st.shoot(st.items[other].proxy, Vector3.ZERO, Vector3.FORWARD)
	var s2 := st.frenzy_state()
	check.call(s2.chain == 1 and s2.chain_col == 2 and s2.mult == 1, "frenzy: another colour starts a new chain (no penalty: %d points)" % int(ctx.counts["frenzy"]))
	# A chain left alone fades.
	_steps(st, b, FrenzyStage.CHAIN_T + 0.3)
	check.call(st.frenzy_state().chain == 0, "frenzy: a chain fades when nothing is popped for a while")

	# Chain reaction: same colours touching pop together; another colour touching does not.
	_fresh(st, b)
	var c1 := _put(st, "bubble", 3, Vector3(0, 3, -7))
	var r1: float = st.items[c1].r
	var c2 := _put(st, "bubble", 3, Vector3(r1 * 1.9, 3, -7))
	var c3 := _put(st, "bubble", 3, Vector3(r1 * 3.8, 3, -7))
	var c4 := _put(st, "bubble", 0, Vector3(-r1 * 1.9, 3, -7))
	st.items[c2].r = r1
	st.items[c3].r = r1
	st.items[c4].r = r1
	st.update(b, DT)
	st.shoot(st.items[c1].proxy, Vector3.ZERO, Vector3.FORWARD)
	_steps(st, b, 0.4)
	check.call(not st.items[c2].on and not st.items[c3].on and st.items[c4].on, "frenzy: a pop spreads along touching same-coloured bubbles (and not to others)")
	check.call(st.frenzy_state().chain == 3, "frenzy: the chain reaction counts in the chain (%d)" % st.frenzy_state().chain)

	# A big bubble spills the little ones inside.
	_fresh(st, b)
	var big := _put(st, "big", 4, Vector3(2, 3.5, -8))
	var kids: int = (st.items[big].kids as Array).size()
	st.update(b, DT)
	var n0 := st.alive()
	st.shoot(st.items[big].proxy, Vector3.ZERO, Vector3.FORWARD)
	var spilled := 0
	for it in st.items:
		if it.on and it.kind == "dahrooj" and it.col == 4:
			spilled += 1
	check.call(kids >= 3 and spilled == kids and st.alive() >= n0 - 1 + kids, "frenzy: a big bubble spills its %d little Dahroojs (%d)" % [kids, spilled])
	_steps(st, b, 0.5)
	var moved := true
	for it in st.items:
		if it.on and it.kind == "dahrooj":
			moved = moved and (it.p as Vector3).distance_to(Vector3(2, 3.5, -8)) > 0.3
	check.call(moved, "frenzy: the little ones fly out")

	# The rainbow pops every one of the chain's colour.
	_fresh(st, b)
	var pinks := []
	for k in 5:
		pinks.append(_put(st, "bubble", 0, Vector3(-6 + k * 3.0, 2.5 + k * 0.3, -9)))
	var blue := _put(st, "bubble", 1, Vector3(0, 5, -5))
	var first := _put(st, "bubble", 0, Vector3(6, 2, -6))
	var rb := _put(st, "rainbow", -1, Vector3(0, 3, -6))
	st.update(b, DT)
	st.shoot(st.items[first].proxy, Vector3.ZERO, Vector3.FORWARD)
	st.shoot(st.items[rb].proxy, Vector3.ZERO, Vector3.FORWARD)
	_steps(st, b, 1.0)
	var left := 0
	for i in pinks:
		if st.items[i].on:
			left += 1
	check.call(left == 0 and st.items[blue].on and st.frenzy_state().chain >= 7, "frenzy: the rainbow pops every pink (left %d, chain %d)" % [left, st.frenzy_state().chain])

	# FRENZY at 10 in a chain.
	_fresh(st, b)
	ctx.counts["frenzy"] = 0
	extra.clear()
	sfx.clear()
	var run := []
	for k in 12:
		run.append(_put(st, "bubble", 5, Vector3(-7 + k * 1.3, 2.0 + (k % 3) * 1.6, -9 - (k % 2) * 2.0)))
	var gold_target := _put(st, "bubble", 2, Vector3(0, 6, -12))
	st.update(b, DT)
	for k in 9:
		st.shoot(st.items[run[k]].proxy, Vector3.ZERO, Vector3.FORWARD)
	check.call(not st.frenzy_state().frenzy and st.shot_fan() == 1, "frenzy: not yet at 9")
	st.shoot(st.items[run[9]].proxy, Vector3.ZERO, Vector3.FORWARD)
	var s3 := st.frenzy_state()
	check.call(s3.frenzy and s3.frenzies == 1 and st.banner.text == "FRENZY!", "frenzy: 10 in a chain: FRENZY! (%s)" % st.banner.text)
	check.call(extra.any(func(e): return e[0] == "ch" and e[1] == "frenzy3") and sfx.any(func(e): return e[0] == "firework_burst"), "frenzy: fireworks and challenge progress")
	_steps(st, b, 1.0)
	var s4 := st.frenzy_state()
	check.call(absf(st.time_scale - FrenzyStage.FRENZY_SCALE) < 0.01 and st.audio_pitch() < 0.9 and s4.gold > 0.99 and st.shot_fan() == 3, "frenzy: time slows to %.2f, pitch %.2f, gold, a fan of shots" % [st.time_scale, st.audio_pitch()])
	var mult: int = s4.mult
	var pre := int(ctx.counts["frenzy"])
	st.shoot(st.items[gold_target].proxy, Vector3.ZERO, Vector3.FORWARD)
	var s5 := st.frenzy_state()
	check.call(int(ctx.counts["frenzy"]) - pre == 2 * FrenzyStage.multiplier(s5.chain) and s5.chain_col == 5 and s5.mult >= mult, "frenzy: any colour counts in FRENZY, worth double (+%d)" % (int(ctx.counts["frenzy"]) - pre))
	var fw := 0
	sfx.clear()
	_steps(st, b, 1.5)
	fw = sfx.filter(func(e): return e[0] == "firework_launch").size()
	check.call(fw >= 1, "frenzy: fireworks keep going in FRENZY (%d)" % fw)
	# (tests step unslowed time: real seconds run at dt / time_scale)
	_steps(st, b, 4.0)
	var s6 := st.frenzy_state()
	check.call(not s6.frenzy and s6.chain == 0 and s6.chain_col == -1, "frenzy: FRENZY ends after its time and the chain starts over")
	_steps(st, b, 1.0)
	check.call(absf(st.time_scale - 1.0) < 1e-3 and st.frenzy_state().gold < 0.01 and st.audio_pitch() == 1.0, "frenzy: time and colours come back")

	# A thrown Dahrooj pops what it flies through.
	_fresh(st, b)
	var t1 := _put(st, "dahrooj", 2, Vector3(0, 2.0, -4.0))
	st.update(b, DT)
	b.pos = Vector3(0, 2.0, -3.6)
	b.vel = Vector3(0, 0, -10)
	b.shot = true
	st.collide(b)
	check.call(not st.items[t1].on and st.touched(), "frenzy: a thrown Dahrooj pops them")
	b.shot = false

	# Open play: it refills forever, gets busier, and nothing ever ends it.
	st.deactivate()
	st.auto_spawn = true
	ctx.counts["frenzy"] = 0
	_steps(st, b, 2.0)
	var early := st.frenzy_state()
	var last := 0
	var never_down := true
	for sec in 30:
		# Pop a few now and then, like a player.
		for k in 3:
			for i in st.items.size():
				if FrenzyStage.hittable(st.items[i]):
					st.shoot(st.items[i].proxy, Vector3.ZERO, Vector3.FORWARD)
					break
		_steps(st, b, 1.0)
		never_down = never_down and int(ctx.counts["frenzy"]) >= last
		last = int(ctx.counts["frenzy"])
	var later := st.frenzy_state()
	check.call(never_down and later.alive >= early.alive - 4 and later.popped >= 80, "frenzy: endless refill, the score only goes up (%d alive, %d popped)" % [later.alive, later.popped])
	st.F.play_t = FrenzyStage.HEAT_T
	var hot := st.frenzy_state()
	check.call(early.colors == 4 and hot.colors == 6 and hot.target > early.target and st.current(Vector3(0, 3, -5)).length() >= 0.0, "frenzy: it heats up: %d -> %d colours, %d -> %d at once" % [early.colors, hot.colors, early.target, hot.target])
	_steps(st, b, 6.0)
	check.call(st.alive() > early.alive, "frenzy: more of them when it's hot (%d)" % st.alive())
	var inside := true
	for it in st.items:
		if it.on:
			inside = inside and (it.p as Vector3).y > 0.0 and (it.p as Vector3).distance_to(st.viewer) > 1.0
	check.call(inside, "frenzy: they stay over the ground and out of the player's face")

	# Mixed reality: the room's planes bound the air; they bounce softly off the walls.
	st.deactivate()
	var W := 10.0
	var D := 10.0
	var H := 6.0
	var planes := [
		{"pos": Vector3(0, 0, -3), "normal": Vector3.UP, "ax": Vector3.RIGHT, "ay": Vector3.FORWARD, "half": Vector2(W / 2, D / 2), "label": "floor"},
		{"pos": Vector3(0, H, -3), "normal": Vector3.DOWN, "ax": Vector3.RIGHT, "ay": Vector3.FORWARD, "half": Vector2(W / 2, D / 2), "label": "ceiling"},
		{"pos": Vector3(0, H / 2, -8), "normal": Vector3.BACK, "ax": Vector3.RIGHT, "ay": Vector3.UP, "half": Vector2(W / 2, H / 2), "label": "wall"},
		{"pos": Vector3(0, H / 2, 2), "normal": Vector3.FORWARD, "ax": Vector3.RIGHT, "ay": Vector3.UP, "half": Vector2(W / 2, H / 2), "label": "wall"},
		{"pos": Vector3(-W / 2, H / 2, -3), "normal": Vector3.RIGHT, "ax": Vector3.FORWARD, "ay": Vector3.UP, "half": Vector2(D / 2, H / 2), "label": "wall"},
		{"pos": Vector3(W / 2, H / 2, -3), "normal": Vector3.LEFT, "ax": Vector3.FORWARD, "ay": Vector3.UP, "half": Vector2(D / 2, H / 2), "label": "wall"},
	]
	var asked := [0]
	st.planes_provider = func() -> Array:
		asked[0] += 1
		return planes
	st.viewer = Vector3(0, 3.2, 0)
	st.auto_spawn = true
	_steps(st, b, 3.0)
	var all_in := true
	var near_wall := 0
	for it in st.items:
		if it.on:
			var p: Vector3 = it.p
			all_in = all_in and p.x > -W / 2 and p.x < W / 2 and p.z > -8.0 and p.z < 2.0 and p.y > 0.0 and p.y < H
	st.auto_spawn = false
	check.call(asked[0] >= 1 and st.frenzy_state().room and all_in, "frenzy (MR): the room's planes bound the air (asked %d)" % asked[0])
	var w := _put(st, "bubble", 0, Vector3(0, 3, -7.2))
	st.items[w].v = Vector3(0, 0, -3)
	_steps(st, b, 0.6)
	var wp: Vector3 = st.items[w].p
	check.call(wp.z > -8.0 + float(st.items[w].r) * 0.9 and float(st.items[w].v.z) > -1.0, "frenzy (MR): a bubble bounces softly off the wall (z %.2f)" % wp.z)
	var from_wall := 0
	for k in 40:
		var i := st.spawn("bubble")
		if i >= 0:
			var p: Vector3 = st.items[i].p
			if (st.items[i].v as Vector3).length() > 0.5:
				from_wall += 1
			st.items[i].on = false
			all_in = all_in and p.x > -W / 2 and p.x < W / 2 and p.z > -8.0 and p.z < 2.0
	check.call(from_wall > 5 and all_in, "frenzy (MR): some are blown out of the walls (%d of 40)" % from_wall)
	st.planes_provider = Callable()

	# Leaving resets the slow motion.
	st.F.frenzy_t = 3.0
	st.time_scale = 0.5
	st.deactivate()
	check.call(st.time_scale == 1.0 and st.alive() == 0 and not st.frenzy_state().frenzy, "frenzy: leaving resets everything")
	st.free()
