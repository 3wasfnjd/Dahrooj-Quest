extends RefCounted
## Giant Dahrooj (giant): he comes in on his own (from the sky on the court) with a level
## banner; glowing weak spots take a chunk out of his ring when shot (the body only chips it),
## he flinches and wobbles; hits build a combo; points feed ctx.counts["giant"]; the phases
## follow the ring (stomp shakes the props, spit sends little ones that pop and bounce off you
## harmlessly, slime split into three that merge back, rage glow); an empty ring is a knock-out
## with fireworks and confetti, then he is back bigger with a new look (Lv.2); open play (no
## lives, no game over); mixed reality: he breaks in through the scanned wall and fits under
## the ceiling.

const DT := 1.0 / 72.0


static func _steps(st: GiantStage, b: Ball, secs: float) -> void:
	var t := 0.0
	while t < secs:
		st.update(b, DT)
		t += DT


static func _until(st: GiantStage, b: Ball, cond: Callable, limit: float) -> bool:
	var t := 0.0
	while t < limit:
		if cond.call():
			return true
		st.update(b, DT)
		t += DT
	return cond.call()


static func _live_spot(_st: GiantStage, body: Dictionary) -> Dictionary:
	for sp in body.spots:
		if GiantStage.spot_live(sp):
			return sp
	return {}


static func _fight(st: GiantStage, b: Ball) -> bool:
	return _until(st, b, func(): return st.F.state == "fight" and not st.giant.air and not _live_spot(st, st.giant).is_empty(), 8.0)


static func run(check: Callable) -> void:
	var sfx: Array = []
	var extra: Array = []
	var buzzes: Array = []
	var st := GiantStage.new()
	var b := Ball.new()
	var ctx := GameCtx.new()
	ctx.ball = b
	ctx.counts = {}
	ctx.sfx = func(n, k, _p): sfx.append([n, k])
	ctx.add_count = func(md, r): extra.append(["count", md, r])
	ctx.toast = func(t): extra.append(["toast", t])
	ctx.ch_progress = func(id, v): extra.append(["ch", id, v])
	ctx.confetti = func(p, _r, _e, _s): extra.append(["confetti", p])
	st.ctx = ctx
	st.buzz = func(h, a, ms): buzzes.append([h, a, ms])
	b.set_stage(st, "giant")
	check.call(st.get_node_or_null("Board") == null and not st.F.has("lives") and not st.F.has("best"), "giant: no board, no lives")
	# He comes in on his own: from the sky onto the court, with the level banner.
	st.update(b, DT)
	st.draw()
	var s0 := st.giant_state()
	check.call(s0.state == "enter" and s0.enter == "sky" and st.giant.y > 10.0 and st.banner.visible and st.banner.text == "العملاق مستوى ١",
		"giant: comes in from the sky with a banner (%s, y %.1f)" % [st.banner.text, st.giant.y])
	check.call(absf(float(s0.r) - GiantStage.R_BASE) < 1e-4 and (s0.home as Vector3).z < -12.0, "giant: house-sized on the court (r %.1f)" % s0.r)
	var booms := sfx.filter(func(e): return e[0] == "boom").size()
	check.call(_fight(st, b), "giant: lands, roars and the fight starts")
	check.call(sfx.filter(func(e): return e[0] == "boom").size() > booms and not buzzes.is_empty(), "giant: the landing booms and buzzes")
	check.call(st.giant.view.visible and st.giant.c.y > GiantStage.R_BASE * 0.6, "giant: drawn, standing on the ground")
	# A weak spot: a shot on it takes a chunk of the ring, scores, he flinches.
	var sp := _live_spot(st, st.giant)
	st.draw()
	check.call((sp.proxy as MeshInstance3D).visible and (sp.proxy as MeshInstance3D).layers == 0 and st._mm.targets.visible_instance_count >= 1, "giant: a glowing weak spot with a hidden hit sphere")
	var hp0: float = st.F.hp
	var took := st.shoot(sp.proxy, sp.at, Vector3.FORWARD)
	check.call(took and absf(hp0 - st.F.hp - GiantStage.SPOT_DMG) < 1e-3, "giant: a shot on a weak spot takes %.0f (hp %.1f)" % [GiantStage.SPOT_DMG, st.F.hp])
	check.call(int(ctx.counts.get("giant", 0)) >= 10 and st.F.score == int(ctx.counts.giant), "giant: points go to ctx.counts[giant] (%d)" % int(ctx.counts.get("giant", 0)))
	check.call(st.giant.flash > 0.0 and (st.giant.wobv as Vector3).length() > 0.5 and st._chunks.size() > 0, "giant: he flinches, wobbles, the ring loses a chunk")
	check.call(not st.shoot(sp.proxy, sp.at, Vector3.FORWARD), "giant: a spot just hit is gone for a moment")
	# The body only chips.
	hp0 = st.F.hp
	check.call(st.shoot((st.giant.view as DahroojView).body, st.giant.c, Vector3.FORWARD) and absf(hp0 - st.F.hp - GiantStage.BODY_DMG) < 1e-3, "giant: a shot on the body chips the ring")
	# The spots move.
	var key0: String = st.giant.spots[0].key
	var moved := _until(st, b, func(): return st.giant.spots[0].key != key0, 6.0)
	check.call(moved, "giant: the weak spots move over him")
	# Combo: quick hits step up the multiplier.
	st.auto_play = false
	for i in 40:
		var q := _live_spot(st, st.giant)
		if not q.is_empty():
			st.shoot(q.proxy, q.at, Vector3.FORWARD)
			if st.F.combo >= 3:
				break
		_steps(st, b, 0.25)
	check.call(st.F.mult >= 2 and st.combo_label.text != "", "giant: quick hits build a combo (×%d)" % st.F.mult)
	# Phase 2: spit; little ones fly at you, pop with a shot.
	st.F.hp = st.F.max_hp * 0.76
	st._damage(2.0)
	check.call(st.F.phase == 2 and st.banner.text == "هجوم البصق!", "giant: phase 2, spit attack (%s)" % st.banner.text)
	_until(st, b, func(): return st.giant.act == "" and not st.giant.air, 3.0)
	st._start_spit(st.giant)
	check.call(_until(st, b, func(): return st.giant_state().minions >= 3, 3.0), "giant: he spits little ones (%d)" % st.giant_state().minions)
	var mi: Dictionary = {}
	for q in st.minions:
		if q.on:
			mi = q
			break
	var c0 := int(ctx.counts.giant)
	var pops0: int = st.F.pops
	check.call(st.shoot(mi.proxy, mi.p, Vector3.FORWARD) and not mi.on and st.F.pops == pops0 + 1 and int(ctx.counts.giant) > c0, "giant: a shot pops a little one")
	# One that reaches you just bounces off: no lives lost, the combo breaks, the fight goes on.
	var near: Dictionary = {}
	for q in st.minions:
		if q.on:
			near = q
			break
	near.ph = "hop"
	near.p = Vector3(st.viewer.x, near.r, st.viewer.z - 0.5)
	st.F.combo = 4
	st.update(b, DT)
	check.call(near.bounces == 1 and near.ph == "fly" and near.v.y > 0.0 and st.F.combo == 0 and st.F.bounced >= 1 and st.F.state == "fight",
		"giant: a little one bounces off you harmlessly (combo broken, no fail)")
	check.call(_until(st, b, func(): return st.giant_state().minions == 0, 25.0), "giant: the little ones don't pile up forever")
	# A thrown Dahrooj hits him.
	_until(st, b, func(): return not st.giant.air, 3.0)
	hp0 = st.F.hp
	b.shot = true
	b.pos = (st.giant.c as Vector3) + Vector3(0, 0, st.giant.r + 0.1)
	b.vel = Vector3(0, 0, -12)
	st.F.ball_t = 0.0
	st.collide(b)
	check.call(st.F.hp < hp0 - 2.0 and b.vel.z > 0.0, "giant: a thrown Dahrooj bounces off him and hurts (%.1f)" % (hp0 - st.F.hp))
	b.shot = false
	# Phase 1 stomps: props jump.
	var props_up := false
	st.F.phase = 1
	st._start_hop(st.giant, true)
	var t := 0.0
	while t < 3.0 and not props_up:
		st.update(b, DT)
		t += DT
		for p in st.props:
			if p.y > 0.05:
				props_up = true
	check.call(st.props.size() >= 6 and props_up and st._rings.size() > 0, "giant: a stomp shakes the ground (dust rings, props jump)")
	st.F.phase = 2
	# Phase 3: he melts and splits into three; they take hits; they merge back; rage.
	st.F.hp = st.F.max_hp * 0.51
	st._damage(2.0)
	check.call(st.F.phase == 3 and st.F.split == "melt", "giant: phase 3, he melts")
	check.call(_until(st, b, func(): return st.F.split == "fight", 4.0) and st.giant_state().meds == 3, "giant: three medium ones")
	check.call(_until(st, b, func(): return not _live_spot(st, st.meds[0]).is_empty(), 2.0), "giant: the medium ones have weak spots")
	var ms := _live_spot(st, st.meds[0])
	hp0 = st.F.hp
	check.call(st.shoot(ms.proxy, ms.at, Vector3.FORWARD) and absf(hp0 - st.F.hp - GiantStage.MED_DMG) < 1e-3, "giant: a medium one's spot hurts the ring")
	check.call(_until(st, b, func(): return st.F.split == "", GiantStage.SPLIT_T + 4.0) and st.giant_state().meds == 0 and st.giant.melt == 0.0, "giant: they merge back into him")
	st.F.hp = st.F.max_hp * 0.27
	st._damage(3.0)
	_steps(st, b, 1.0)
	check.call(st.F.phase == 4 and st.giant.glow > 0.4 and st.speed_k() > 1.2 and st.banner.text == "وضع الغضب!", "giant: rage (red glow %.2f, speed ×%.2f)" % [st.giant.glow, st.speed_k()])
	# Knock-out: spin, stars, fireworks, confetti, then Lv.2: bigger, a new look.
	var look1: Array = st.giant_state().look
	var r1: float = st.giant.r
	c0 = int(ctx.counts.giant)
	var conf0 := extra.filter(func(e): return e[0] == "confetti").size()
	st._damage(st.F.hp + 1.0)
	check.call(st.F.state == "ko" and st.F.kos == 1 and int(ctx.counts.giant) >= c0 + 100 and st.banner.text == "ضربة قاضية!", "giant: knock-out (+%d)" % (int(ctx.counts.giant) - c0))
	check.call(extra.any(func(e): return e[0] == "ch" and e[1] == "giant3" and e[2] == 1), "giant: a knock-out counts toward giant3")
	_steps(st, b, 2.0)
	check.call(st.giant.tilt > 0.5 and st._mm.stars.visible_instance_count > 0, "giant: he spins and topples over, dizzy stars")
	_steps(st, b, 1.2)
	check.call(sfx.any(func(e): return e[0] == "firework_launch") and sfx.any(func(e): return e[0] == "firework_burst") and extra.filter(func(e): return e[0] == "confetti").size() >= conf0 + 4,
		"giant: fireworks and a confetti storm")
	check.call(_until(st, b, func(): return st.F.lv == 2, 4.0), "giant: he comes back (Lv.2)")
	var s2 := st.giant_state()
	check.call(s2.r > r1 and s2.look != look1 and s2.max_hp > GiantStage.HP_BASE and st.F.hp == st.F.max_hp and s2.phase == 1, "giant: Lv.2 is bigger with a new look %s" % str(s2.look))
	check.call(st.banner.text == "العملاق مستوى ٢" and _fight(st, b), "giant: Lv.2 banner, the fight goes on (endless)")
	st.deactivate()
	check.call(st.F.state == "idle" and st.giant_state().minions == 0 and not st.giant.view.visible, "giant: deactivate clears him")
	st.free()

	# Mixed reality: through the wall that faces you, under the ceiling.
	var mr := GiantStage.new()
	var b2 := Ball.new()
	var ctx2 := GameCtx.new()
	ctx2.ball = b2
	ctx2.counts = {}
	mr.ctx = ctx2
	mr.size = 2.0
	mr.viewer = Vector3(0, 12.8, 0)
	var calls := [0]
	mr.planes_provider = func() -> Array:
		calls[0] += 1
		return [
			{"pos": Vector3(0, 0, -10), "normal": Vector3.UP, "ax": Vector3.RIGHT, "ay": Vector3.FORWARD, "half": Vector2(20, 20), "label": "floor"},
			{"pos": Vector3(0, 20, -10), "normal": Vector3.DOWN, "ax": Vector3.RIGHT, "ay": Vector3.FORWARD, "half": Vector2(20, 20), "label": "ceiling"},
			{"pos": Vector3(0, 10, -30), "normal": Vector3.BACK, "ax": Vector3.RIGHT, "ay": Vector3.UP, "half": Vector2(20, 10), "label": "wall"},
			{"pos": Vector3(20, 10, -10), "normal": Vector3.LEFT, "ax": Vector3.FORWARD, "ay": Vector3.UP, "half": Vector2(20, 10), "label": "wall"},
		]
	b2.set_stage(mr, "giant")
	mr.update(b2, DT)
	var m0 := mr.giant_state()
	check.call(calls[0] > 0 and m0.enter == "wall" and mr.breach.on and absf((mr.breach.p as Vector3).z + 30.0) < 0.1, "giant (MR): he comes through the wall facing you")
	check.call(float(m0.r) <= 20.0 * 0.36 + 1e-3 and float(m0.r) > 4.0 and (m0.home as Vector3).z > -30.0 + float(m0.r), "giant (MR): sized to fit under the ceiling (r %.1f)" % m0.r)
	_steps(mr, b2, 1.0)
	mr.draw()
	check.call(mr.breach.bulge > 0.3 and mr._mm.bulge.visible_instance_count == 1 and mr._mm.cracks.visible_instance_count == 1 and not mr.giant.view.visible, "giant (MR): the wall bulges and cracks")
	_steps(mr, b2, 0.6)
	mr.draw()
	check.call(mr.breach.hole > 0.0 and mr._mm.hole.visible_instance_count == 1 and mr.giant.view.visible and mr._debris.size() > 10, "giant (MR): it bursts open and he squeezes in")
	var top := 0.0
	var t2 := 0.0
	mr._start_hop(mr.giant, true)
	while t2 < 12.0:
		mr.update(b2, DT)
		t2 += DT
		if mr.giant.on and not mr.giant.free:
			top = maxf(top, (mr.giant.c as Vector3).y + float(mr.giant.r) * float(mr.giant.s))
	check.call(mr.F.state == "fight" and (mr.giant.g as Vector3).distance_to(mr.giant_state().home) < float(m0.r) * 1.2, "giant (MR): he stands in the room")
	check.call(top <= 20.0 + 0.3 and top > 10.0, "giant (MR): never through the ceiling (top %.1f)" % top)
	mr.free()
