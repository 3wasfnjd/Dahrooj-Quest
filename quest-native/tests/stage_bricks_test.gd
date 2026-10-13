extends RefCounted
## Bricks (stages/bricks.js): bricks grow in; a throw at the wall breaks bricks (tink, count,
## bricks20) and comes back; a wide throw misses; blaster shots and a cleared wall bring the
## next level and its towers.


static func _setup(sfx: Array, counts: Array, events: Array, extra: Array) -> Array:
	var st := BricksStage.new()
	var b := Ball.new()
	var ctx := GameCtx.new()
	ctx.ball = b
	ctx.sfx = func(n, k, _p): sfx.append([n, k])
	ctx.add_count = func(m, r): counts.append([m, r])
	ctx.toast = func(t): extra.append(["toast", t])
	ctx.ch_progress = func(id, v): extra.append(["ch", id, v])
	ctx.confetti = func(p, r, e, s): extra.append(["confetti", p])
	st.ctx = ctx
	b.set_stage(st, "bricks")
	b.event.connect(func(k, _d): events.append(k))
	return [st, b]


static func run(check: Callable) -> void:
	var sfx: Array = []
	var counts: Array = []
	var events: Array = []
	var extra: Array = []
	var sb := _setup(sfx, counts, events, extra)
	var st: BricksStage = sb[0]
	var b: Ball = sb[1]
	check.call(st.bricks_left() == 48 and st.towers.size() == 2, "bricks: level 1 is a full wall of 48 with two towers")
	for i in 72:
		b.step(1.0 / 72.0)
	check.call(st.B.bricks.all(func(x): return x.grow >= 1.0), "bricks: the wall has grown in after a second")
	check.call(st.towers_state().all(func(t): return t.rise >= 1.0 and t.top > 4.0), "bricks: the towers have risen")
	# A throw straight at the wall.
	b.respawn()
	b.pos = Vector3(0, 1.4, 0)
	b.throw_with(Vector3(0, 3.5, -13))
	var came_back := false
	for i in 72 * 3:
		b.step(1.0 / 72.0)
		if b.shot and b.vel.z > 2.0:
			came_back = true
		if not b.shot:
			break
	var broken := 48 - st.bricks_left()
	check.call(broken >= 1, "bricks: a throw at the wall breaks a brick (%d)" % broken)
	check.call(came_back, "bricks: Dahrooj bounces back off the wall")
	check.call(sfx.any(func(s): return s[0] == "bricks_tink") and sfx.any(func(s): return s[0] == "thump"), "bricks: a break tinks and thumps")
	check.call(counts.size() == broken and extra.any(func(e): return e[0] == "ch" and e[1] == "bricks20"), "bricks: breaks are counted toward bricks20")
	check.call(not events.has("miss"), "bricks: a throw that broke bricks is no laughing miss")
	# A wide throw misses the wall.
	var left := st.bricks_left()
	events.clear()
	b.respawn()
	b.pos = Vector3(0, 1.4, 0)
	b.throw_with(Vector3(9, 3, -2))
	for i in 72 * 8:
		b.step(1.0 / 72.0)
		if events.has("miss"):
			break
	check.call(events.has("miss") and st.bricks_left() == left, "bricks: a wide throw misses and breaks nothing")
	# The blaster breaks one brick on its own.
	var target: Dictionary = st.B.bricks.filter(func(x): return x.alive)[0]
	check.call(st.shoot(target.mesh, target.mesh.position, Vector3.FORWARD) and not target.alive, "bricks: a blaster shot breaks the brick it hits")
	check.call(not st.shoot(st, Vector3.ZERO, Vector3.FORWARD), "bricks: a shot at no brick is not taken")
	# Clearing the wall with Dahrooj in hand: confetti, wall1, and a moment later the next level.
	b.respawn()
	extra.clear()
	st.smash_all()
	check.call(st.bricks_left() == 0 and extra.any(func(e): return e[0] == "ch" and e[1] == "wall1" and e[2] == 1), "bricks: smashing the whole wall completes wall1")
	check.call(extra.any(func(e): return e[0] == "confetti") and JuiceText.showing(st).any(func(j: JuiceText) -> bool: return j.kind == "banner" and j.text == "حطّمت الحائط!"), "bricks: the wall celebrates on its own (confetti, a festive banner)")
	for i in 72 * 2:
		b.step(1.0 / 72.0)
	check.call(st.level == 1 and st.bricks_left() == 24, "bricks: the next level is laid (level %d, %d bricks)" % [st.level, st.bricks_left()])
	for i in 72:
		b.step(1.0 / 72.0)
	check.call(st.towers_state().all(func(t): return t.rise >= 1.0 and t.top > 5.0), "bricks: level 2's round towers with roofs rise")
	for lv in 3:
		st.next_level()
	check.call(st.level == 4 and st.towers.size() == 2, "bricks: every tower design builds")
	st.free()
