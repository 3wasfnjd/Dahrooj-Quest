extends RefCounted
## Fair (stages/fair.js): a throw starts the 60 s round; the bell scores 5 (ding, bell3); a
## blaster shot at a duck scores 1 and the duck flies off and comes back; a balloon scores 2;
## a wide throw misses; the round ends with a toast; the counter is solid.


static func run(check: Callable) -> void:
	FairStage.persist_best = false
	var sfx: Array = []
	var counts: Array = []
	var events: Array = []
	var extra: Array = []
	var st := FairStage.new()
	var b := Ball.new()
	var ctx := GameCtx.new()
	ctx.ball = b
	ctx.sfx = func(n, k, _p): sfx.append([n, k])
	ctx.add_count = func(m, r): counts.append([m, r])
	ctx.toast = func(t): extra.append(["toast", t])
	ctx.ch_progress = func(id, v): extra.append(["ch", id, v])
	ctx.confetti = func(p, r, e, s): extra.append(["confetti", p])
	st.ctx = ctx
	b.set_stage(st, "fair")
	b.event.connect(func(k, _d): events.append(k))
	for i in 10:
		b.step(1.0 / 72.0)
	check.call(not st.fair_state().on and st.sign_labels.secs.text == "ارمِ وابدأ", "fair: the board waits for a throw")
	# At the bell.
	var bell_at: Vector3 = st.bell.transform * st.bell_m.position
	b.pos = bell_at + Vector3(0, 0, 1.6)
	b.throw_with(Vector3(0, 1.6, -7))
	check.call(st.fair_state().on and st.fair_state().time == 60.0, "fair: a throw starts the round")
	for i in 72:
		b.step(1.0 / 72.0)
	check.call(st.fair_state().score == 5, "fair: the bell scores 5 (%d)" % st.fair_state().score)
	check.call(sfx.any(func(s): return s[0] == "fair_ding") and extra.any(func(e): return e[0] == "ch" and e[1] == "bell3"), "fair: the bell dings and counts toward bell3")
	check.call(counts.size() == 5 and counts.all(func(c): return c[0] == "fair"), "fair: each point is counted (%d)" % counts.size())
	check.call(st.F.swing > 0.0 and absf(st.bell.rotation.z) >= 0.0, "fair: the bell swings")
	for i in 72 * 5:
		b.step(1.0 / 72.0)
		if not b.shot:
			break
	# A blaster shot at a duck's body.
	var d: Dictionary = st.ducks[0]
	var part: Node = d.g.get_child(0)
	check.call(st.shoot(part, d.g.position, Vector3(0, 0, -1)) and st.fair_state().score == 6, "fair: a shot duck scores 1")
	check.call(d.fly != null and sfx.any(func(s): return s[0] == "squeak"), "fair: the duck squeaks and flies off")
	for i in 72 * 6:
		b.step(1.0 / 72.0)
		if d.fly == null:
			break
	check.call(d.fly == null and absf(d.g.position.y - (FairStage.CY + 0.27)) < 1e-3, "fair: the duck comes back to the rail")
	# A balloon.
	var bl: Dictionary = st.balloons[0]
	check.call(st.shoot(bl.m, bl.m.position, Vector3(0, 0, -1)) and st.fair_state().score == 8, "fair: a shot balloon scores 2")
	check.call(sfx.any(func(s): return s[0] == "start_pop") and extra.any(func(e): return e[0] == "confetti"), "fair: the balloon pops with confetti")
	check.call(not st.shoot(st.sign_mesh, Vector3.ZERO, Vector3.FORWARD), "fair: a shot at the board scores nothing")
	# A wide throw.
	events.clear()
	var before: int = st.fair_state().score
	b.respawn()
	b.pos = Vector3(0, 1.4, 0)
	b.throw_with(Vector3(9, 3, -1))
	for i in 72 * 6:
		b.step(1.0 / 72.0)
		if events.has("miss"):
			break
	check.call(events.has("miss") and st.fair_state().score == before, "fair: a wide throw misses")
	# The counter is solid: a ball falling into it is pushed out on top.
	var res := st.collide_body(Vector3(0, FairStage.CY + 0.1, FairStage.FZ + 0.2), Vector3(0, -3, 0), Ball.BR, Vector3(0, FairStage.CY + 0.5, FairStage.FZ + 0.2))
	check.call(res.hit and res.p.y > FairStage.CY + 0.08 + Ball.BR - 1e-3 and res.v.y > 0.0, "fair: the counter stops a ball (y %.2f)" % res.p.y)
	# The round runs out.
	extra.clear()
	b.respawn()
	for i in 72 * 60:
		b.step(1.0 / 72.0)
		if not st.fair_state().on:
			break
	check.call(not st.fair_state().on and st.fair_state().best == 8 and extra.any(func(e): return e[0] == "toast"), "fair: time runs out with a toast and a best of 8")
	check.call(sfx.any(func(s): return s[0] == "chime"), "fair: the round ends with a chime")
	st.free()
