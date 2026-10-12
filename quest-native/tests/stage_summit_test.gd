extends RefCounted
## Summit (الجبل): the level as summit-core.js builds it; Dahrooj jumps from ledge to
## ledge under the core's rules; stomping or hitting a monster defeats it (and counts
## toward monsters15); hazards cost hearts, losing them all pops him back at the last
## checkpoint (a fall itself never costs a heart: the checkpoint ledges span the face);
## checkpoints and the summit fire their events, sounds, toasts and counts; the HUD;
## the 3D world builds and follows the state; the window clips at the surface.

const DT := 1.0 / 72.0


static func _step(st: Dictionary, seconds: float, events: Array) -> void:
	var t := 0.0
	while t < seconds:
		SummitCore.step(st, DT)
		events.append_array(st.events)
		st.events.clear()
		t += DT


static func _has(events: Array, type: String) -> bool:
	return events.any(func(e: Dictionary) -> bool: return e.type == type)


## Jump from where he stands toward a platform, steering in the air; true if he lands on it.
static func _hop(st: Dictionary, target: Dictionary, events: Array) -> bool:
	var b: Dictionary = st.ball
	SummitCore.jump(st)
	var t := 0.0
	while t < 2.0:
		var tx: float = (target.x0 + target.x1) / 2.0
		SummitCore.set_dir(st, clampf((tx - b.x) * 1.5, -1.0, 1.0))
		SummitCore.step(st, DT)
		events.append_array(st.events)
		st.events.clear()
		t += DT
		if b.grounded and t > 0.1:
			break
	SummitCore.set_dir(st, 0.0)
	return b.grounded and b.on == target


static func _place(st: Dictionary, x: float, y: float, vy := 0.0) -> void:
	var b: Dictionary = st.ball
	b.x = x
	b.y = y
	b.vx = 0.0
	b.vy = vy
	b.grounded = false
	b.on = null
	b.inv = 0.0
	b.stun = 0.0


static func run(check: Callable) -> void:
	var W := SummitMode.WIDTH
	var st := SummitCore.create_state(W)
	var plats: Array = st.platforms
	var mons: Array = st.monsters
	var kinds := {}
	for m: Dictionary in mons:
		kinds[m.type] = int(kinds.get(m.type, 0)) + 1
	check.call(plats.size() == 38 and plats[0].ground and plats[plats.size() - 1].summit and plats[plats.size() - 1].y == SummitCore.TOP,
		"summit: 38 platforms from the ground to the summit at 148 (%d)" % plats.size())
	check.call(kinds == {"crawler": 5, "spitter": 4, "bat": 7} and st.icicles.size() == 3,
		"summit: 5 crawlers, 4 spitters, 7 bats, 3 icicles (%s)" % [kinds])
	var cps := plats.filter(func(p: Dictionary) -> bool: return p.checkpoint > 0).map(func(p: Dictionary) -> float: return p.y)
	check.call(cps == [36.0, 72.0, 108.0], "summit: checkpoint ledges at 36, 72, 108")
	var gaps_ok := true
	for i in range(1, plats.size()):
		if not plats[i].full:
			gaps_ok = gaps_ok and plats[i].x0 >= 0.2 - 1e-6 and plats[i].x1 <= W - 0.2 + 1e-6
	var reach := SummitCore.JUMP * SummitCore.JUMP / (2.0 * SummitCore.G)
	check.call(gaps_ok and reach > 4.0, "summit: every ledge on the face, 4 apart, under the jump's %.2f" % reach)
	var b: Dictionary = st.ball
	check.call(b.grounded and b.on == plats[0] and b.y == 1.0 and b.x == W / 2.0 and b.hearts == 3, "summit: he starts on the ground, 3 hearts")

	# Rolling and jumping.
	var ev: Array = []
	SummitCore.set_dir(st, 1.0)
	_step(st, 0.5, ev)
	check.call(b.vx > 9.0 and b.x > W / 2.0 + 3.0 and b.facing == 1.0, "summit: the stick rolls him (vx %.1f)" % b.vx)
	SummitCore.set_dir(st, 0.0)
	_step(st, 0.6, ev)
	b.x = W / 2.0
	SummitCore.jump(st)
	ev.clear()
	var top := 0.0
	var t := 0.0
	while t < 1.5:
		SummitCore.step(st, DT)
		ev.append_array(st.events)
		st.events.clear()
		top = maxf(top, b.y)
		t += DT
	check.call(_has(ev, "launch") and _has(ev, "land") and absf(top - 1.0 - reach) < 0.15 and b.grounded,
		"summit: a jump rises %.2f (core: %.2f) and lands" % [top - 1.0, reach])
	SummitCore.jump(st)
	_step(st, 0.05, ev)
	check.call(not b.grounded, "summit: a press just before landing is buffered")
	_step(st, 1.5, ev)

	# Ledge to ledge.
	b.x = W / 2.0
	ev.clear()
	var hop1 := _hop(st, plats[1], ev)
	check.call(hop1 and b.y == plats[1].y + 1.0, "summit: he jumps from the ground onto the first ledge (y %.1f)" % b.y)
	mons[0].alive = false  # the crawler on the next one
	var hop2 := _hop(st, plats[2], ev)
	check.call(hop2 and b.y == 9.0, "summit: and on to the next (y %.1f)" % b.y)
	check.call(_has(ev, "land") and st.checkpoint == 0, "summit: plain ledges are no checkpoint")
	# Walking off a ledge drops him to the one below; a fall never costs a heart.
	SummitCore.set_dir(st, 1.0 if b.x > W / 2.0 else -1.0)
	ev.clear()
	_step(st, 2.5, ev)
	SummitCore.set_dir(st, 0.0)
	check.call(b.grounded and b.y < 9.0 and b.hearts == 3 and not _has(ev, "hurt"), "summit: off the edge he falls to a lower ledge, no heart lost")

	# Stomping a crawler.
	st = SummitCore.create_state(W)
	b = st.ball
	var crawler: Dictionary = st.monsters[0]
	crawler.speed = 0.0
	_place(st, crawler.x, crawler.plat.y + 0.6 + 1.6, -8.0)
	ev.clear()
	_step(st, 0.2, ev)
	check.call(_has(ev, "stomp") and not crawler.alive and b.hearts == 3, "summit: falling on a crawler stomps it")
	check.call(not b.grounded and b.vy > 5.0 or _has(ev, "land"), "summit: and he bounces off it")
	# Walking into one hurts.
	var c2: Dictionary = st.monsters[1]
	c2.speed = 0.0
	_place(st, c2.x - 1.2, c2.plat.y + 1.0)
	b.grounded = true
	b.on = c2.plat
	ev.clear()
	_step(st, 0.05, ev)
	check.call(_has(ev, "hurt") and b.hearts == 2 and b.inv > 1.0 and b.vx < 0.0, "summit: touching a crawler costs a heart and knocks him back")
	ev.clear()
	_step(st, 0.3, ev)
	check.call(not _has(ev, "hurt") and b.hearts == 2, "summit: a moment of grace after a hit")

	# A thrown ball at a crawler on the ledge above.
	st = SummitCore.create_state(W)
	b = st.ball
	crawler = st.monsters[0]
	crawler.speed = 0.0
	b.x = crawler.x - 5.4
	b.facing = 1.0
	ev.clear()
	var threw := SummitCore.throw_ball(st)
	check.call(threw and st.shots.size() == 1 and st.shots[0].vy > 3.0, "summit: a throw aims at the monster ahead")
	check.call(not SummitCore.throw_ball(st), "summit: a short cool-down between throws")
	_step(st, 1.0, ev)
	check.call(_has(ev, "kill") and not crawler.alive and st.shots.is_empty(), "summit: the thrown ball defeats it")
	b.facing = -1.0
	for i in 3:
		b.cool = 0.0
		SummitCore.throw_ball(st)
	b.cool = 0.0
	check.call(st.shots.size() == SummitCore.SHOT_MAX and not SummitCore.throw_ball(st), "summit: at most 3 balls in the air")

	# Hearts, the pop, back at the checkpoint.
	st = SummitCore.create_state(W)
	b = st.ball
	_place(st, W / 2.0, 36.0 + 1.5)
	ev.clear()
	_step(st, 0.3, ev)
	check.call(_has(ev, "checkpoint") and st.checkpoint == 1, "summit: landing on the 36 ledge saves a checkpoint")
	_place(st, W - 1.0, 55.0)
	_step(st, 1.5, ev)
	check.call(b.grounded and b.y >= 37.0 and b.hearts == 3, "summit: a fall stops on the checkpoint ledge at worst (y %.1f)" % b.y)
	ev.clear()
	for i in 3:
		b.inv = 0.0
		SummitCore.hurt(st, b.x)
	check.call(_has(ev, "pop") or st.events.any(func(e: Dictionary) -> bool: return e.type == "pop"), "summit: the third heart lost pops him")
	check.call(b.dead > 0.0 and b.hearts == 0, "summit: he's gone a moment")
	st.events.clear()
	_step(st, 1.2, ev)
	check.call(b.dead == 0.0 and b.hearts == 3 and b.y == 37.0 and b.x == W / 2.0 and b.inv > 0.0, "summit: back on the checkpoint with 3 hearts")
	# Spikes and crumbling ledges.
	var spiky: Dictionary = plats.filter(func(p: Dictionary) -> bool: return p.spikes != null)[0]
	st = SummitCore.create_state(W)
	b = st.ball
	spiky = st.platforms.filter(func(p: Dictionary) -> bool: return p.spikes != null)[0]
	_place(st, spiky.x0 + 0.3, spiky.y + 1.5)
	ev.clear()
	_step(st, 0.2, ev)
	check.call(_has(ev, "hurt") and b.hearts == 2, "summit: landing on spikes hurts")
	var crumbly: Dictionary = st.platforms.filter(func(p: Dictionary) -> bool: return p.crumble != null)[0]
	_place(st, (crumbly.x0 + crumbly.x1) / 2.0, crumbly.y + 1.3)
	_step(st, 0.15, ev)
	check.call(crumbly.crumble.state == "shaking" and b.on == crumbly, "summit: a sandy ledge shakes when he lands")
	_step(st, 0.7, ev)
	check.call(crumbly.crumble.state == "fallen" and b.y < crumbly.y + 1.0, "summit: then gives way under him")

	# The summit, through the mode (sounds, toasts, counts) and its HUD.
	var sounds: Array = []
	var extra: Array = []
	var ctx := GameCtx.new()
	ctx.ch_state = {"monsters15": 4}
	ctx.toast = func(s: String): extra.append(["toast", s])
	ctx.add_count = func(m: String, r: bool): extra.append(["count", m, r])
	ctx.ch_progress = func(id: String, v: int): extra.append(["ch", id, v])
	var sm := SummitMode.new()
	sm.sfx = func(n: String, k: float, p: Vector3): sounds.append([n, k, p])
	sm.game = ctx
	check.call(sm.hud().is_empty() and not sm.visible, "summit: nothing until it's switched on")
	sm.set_unit(SummitMode.CLIMB_VR)
	sm.position = Vector3(0, 0.04, -10.5)
	sm.set_base(0.04)
	sm.set_active(true)
	var n_pieces := sm.world.pieces.size()
	check.call(sm.visible and n_pieces == 38 + 16 + 3 and sm.world.mountain.mesh.get_surface_count() == 1,
		"summit: the world builds (mountain, %d ledges/monsters/icicles)" % n_pieces)
	check.call(SummitWorld.wing_mesh().get_surface_count() == 1 and SummitWorld.dodeca_mesh().get_surface_count() == 1,
		"summit: the bat's wings and the boulders have geometry")
	check.call(not sm.pedestal.visible and sm.shadow.visible, "summit: VR at 4 cm: no pedestal, a soft shadow")
	sm.set_base(0.9)
	check.call(sm.pedestal.visible and not sm.shadow.visible, "summit: higher up it stands on a pedestal")
	sm.set_base(0.04)
	var got: Array = []
	var on_event := func(e: Dictionary): got.append(e.type)
	var h := sm.hud()
	check.call(h == {"hearts": 3, "max": 3, "height": 0, "checkpoint": 0, "won": false, "again": false}, "summit: HUD at the start %s" % [h])
	var spot := SummitMode.vr_spot(Transform3D(Basis().scaled(Vector3.ONE / 2.0), -Vector3(0, 0, 9.7) / 2.0))
	check.call(spot.is_equal_approx(Vector3(0, 0.04, -10.5)), "summit: VR spot where the goal stands (%s)" % spot)
	sm.update(DT, {"style": "fur", "color": "pink", "eye": Vector3(0, 1.6, 0), "on_event": on_event})
	check.call(sm.hero.visible and sm.hero.style == "fur" and sm.hero.position.distance_to(Vector3(0, 1, 0.4)) < 0.05,
		"summit: Dahrooj drawn at his spot in his style")
	var s := sm.state
	# Stomp through the mode: sound, challenge.
	var cr: Dictionary = s.monsters[0]
	cr.speed = 0.0
	_place(s, cr.x, cr.plat.y + 0.6 + 1.6, -8.0)
	for i in 15:
		sm.update(DT, {"eye": Vector3(0, 1.6, 0), "on_event": on_event})
	check.call("stomp" in got and sounds.any(func(x: Array) -> bool: return x[0] == "start_pop") and extra.has(["ch", "monsters15", 5]),
		"summit: a stomp pops (start_pop) and counts toward monsters15")
	check.call(sm.parts.size() > 0, "summit: sparks fly from the stomp")
	_place(s, W / 2.0, 72.0 + 1.5)
	for i in 30:
		sm.update(DT, {"on_event": on_event})
	check.call("checkpoint" in got and extra.has(["toast", "نقطة حفظ ✓"]) and sounds.any(func(x: Array) -> bool: return x[0] == "chime"),
		"summit: a checkpoint chimes with «نقطة حفظ ✓»")
	h = sm.hud()
	check.call(h.checkpoint == 2 and h.height == 72, "summit: HUD height %d, checkpoint %d" % [h.height, h.checkpoint])
	s.started_at = s.time - 75.0
	_place(s, W / 2.0, SummitCore.TOP + 1.5)
	for i in 30:
		sm.update(DT, {"on_event": on_event})
	check.call("summit" in got and s.won and extra.has(["count", "climb", false]) and extra.has(["ch", "summit1", 1]),
		"summit: the top fires summit, counts the climb and summit1")
	var toast_text := ""
	for x: Array in extra:
		if x[0] == "toast" and String(x[1]).begins_with("وصلت"):
			toast_text = x[1]
	check.call(toast_text == "وصلت القمة في ١ د ١٥ ث", "summit: toast with the time (%s)" % toast_text)
	check.call(SummitMode.summit_toast(42.0) == "وصلت القمة في ٤٢ ث", "summit: under a minute, seconds only")
	check.call(sm.hero.visible and sm.hud().won and not sm.hud().again, "summit: won, the board waits a moment")
	for i in 90:
		sm.update(DT, {})
	check.call(sm.hud().again, "summit: then «A للتسلق من جديد»")
	check.call(SummitHud.text_for(sm.hud()) == "A للتسلق من جديد" and SummitHud.text_for({"height": 12}) == "12 م"
		and SummitHud.text_for({"height": 12}, "en") == "12 m", "summit: board text")
	sm.jump()
	check.call(not s.won and s.checkpoint == 0 and s.ball.y == 1.0, "summit: A climbs again from the bottom")
	# The window: the camera follows him up; the clip planes sit at the surface and VIEW above.
	_place(s, W / 2.0, 60.0)
	for i in 144:
		sm.update(DT, {})
	var m0: ShaderMaterial = sm.world.mats[0]
	var lo: float = m0.get_shader_parameter("clip_lo")
	var hi: float = m0.get_shader_parameter("clip_hi")
	check.call(sm.cam > 25.0 and absf(lo - (0.04 - 0.06 * SummitMode.CLIMB_VR)) < 1e-3 and absf(hi - (0.04 + 24.0 * SummitMode.CLIMB_VR)) < 1e-3,
		"summit: the mountain slides down; the window stays %.2f..%.2f m" % [lo, hi])
	var low: Node3D = sm.world.pieces[1].obj
	check.call(not low.visible, "summit: ledges far below the window are hidden")
	sm.set_active(false)
	check.call(not sm.visible and sm.hud().has("hearts"), "summit: switched off it keeps the climb")
	var u := SummitMode.zoom_unit(0.14, 1.0, 0.5)
	check.call(u > 0.14 and SummitMode.zoom_unit(0.19, 1.0, 2.0) == SummitMode.UNIT_MAX and SummitMode.zoom_unit(0.013, -1.0, 2.0) == SummitMode.UNIT_MIN, "summit: the right stick resizes within limits")
	check.call(absf(SummitMode.ar_unit(8.0, 1.0) - SummitMode.CLIMB_AR) < 1e-6, "summit: MR size from the surface scale")
	var hud := SummitHud.new()
	hud.show_hud({"hearts": 2, "max": 3, "height": 40, "checkpoint": 1, "won": false, "again": false})
	check.call(hud.visible and hud.label.text == "40 م" and float(hud.mat.get_shader_parameter("hearts")) == 2.0, "summit: the board shows hearts and height")
	hud.show_hud({})
	check.call(not hud.visible, "summit: the board hides without a climb")
	hud.free()
	sm.free()
