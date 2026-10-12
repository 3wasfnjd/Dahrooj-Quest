extends RefCounted
## The opening and Dahrooj Rain (intro_rain.gd) and the crowd that draws them (crowd.gd).

const DT := 1.0 / 72.0


static func _head(at := Vector3(0, 1.6, 0)) -> Transform3D:
	return Transform3D(Basis.IDENTITY, at)  # looking along -Z


static func _make() -> IntroRain:
	var ir := IntroRain.new()
	ir.rng.seed = 7
	ir.use_wall_clock = false
	return ir


static func run(check: Callable) -> void:
	_crowd(check)
	_opening(check)
	_start(check)
	_rain(check)


static func _crowd(check: Callable) -> void:
	var c := Crowd.new(10, true)
	c.begin()
	c.add("jelly", Vector3(0, 0.1, -1), 0.1, Vector3(0, 1.6, 0), Vector2.ONE, "open", "party")
	c.add("fur", Vector3(0.3, 0.1, -1), 0.1, Vector3(0, 1.6, 0), Vector2(1.2, 0.8), "wide", "", "58db83")
	c.add("fur", Vector3(0.6, 0.1, -1), 0.1, null, Vector2.ONE, "shut", "crown")
	c.add("bubble", Vector3(0.9, 0.1, -1), 0.1, Vector3(0, 1.6, 0), Vector2.ONE, "")
	c.end()
	check.call(c.count() == 4 and c.part_count("body_jelly") == 1 and c.part_count("body_fur") == 2 and c.part_count("body_bubble") == 1,
		"crowd: one instance per ball in its style's draw (%d)" % c.count())
	check.call(c.part_count("eyes_open") == 1 and c.part_count("eyes_wide") == 1 and c.part_count("eyes_shut") == 1,
		"crowd: eyes per look; none when asked")
	check.call(c.part_count("bandage") == 1 and c.part_count("bow") == 1 and c.part_count("acc_party") == 1 and c.part_count("acc_crown") == 1,
		"crowd: the jelly's bandage, the fur's ribbon (not under a crown), accessories")
	var mm: MultiMesh = c.parts["body_jelly"].mm
	var m := Crowd.place(Vector3(0, 0.1, -1), 0.1, Vector3(0, 1.6, 0))
	check.call(absf(m.basis.get_scale().x - 0.1) < 1e-4 and m.basis.z.normalized().dot(Vector3(0, 1.5, 1).normalized()) > 0.99,
		"crowd: a ball is its radius and faces the point asked")
	var sq := Crowd.place(Vector3.ZERO, 1.0, null, Vector2(1.2, 0.8))
	check.call(sq.basis.y.length() < 0.81 and sq.basis.x.length() > 1.19, "crowd: squashed in height, wider round")
	check.call(Crowd._color("58db83") == Color("58db83") and Crowd._color(0x58db83) == Color("58db83"), "crowd: colours as hex or Color")
	for i in 20:
		c.add("jelly", Vector3.ZERO, 0.1, null)
	c.end()
	check.call(c.part_count("body_jelly") == 10, "crowd: never more than its size")
	c.begin()
	c.end()
	check.call(c.count() == 0 and mm.visible_instance_count == 0, "crowd: begin/end with nothing draws nothing")
	c.free()


static func _opening(check: Callable) -> void:
	var ir := _make()
	var sounds: Array = []
	var chs: Array = []
	ir.sfx = func(n: String, _k: float, _p: Vector3) -> void: sounds.append(n)
	ir.ch_add = func(id: String) -> void: chs.append(id)
	ir.begin(false)
	ir.step(DT, _head())
	ir.step(DT, _head())
	check.call(ir.balls.is_empty(), "intro: nothing in the first two frames")
	ir.step(DT, _head())
	var late := 0.0
	for b in ir.balls:
		late = maxf(late, b.born)
	check.call(ir.balls.size() == 100 and late < 2.6 and late > 1.5, "intro: 100 balls come down over 2.6 s from the third frame (last %.2f)" % late)
	var outside := 0
	var low := 0
	for i in int(6.0 / DT):
		ir.step(DT, _head())
		for b in ir.balls:
			if b.born > ir.t:
				continue
			if Vector2(b.p.x, b.p.z).length() > 4.4 + 0.45:
				outside += 1
			if b.p.y < b.R - 0.03:
				low += 1
	var resting := 0
	for b in ir.balls:
		if absf(b.p.y - b.R) < 0.002:
			resting += 1
	check.call(resting >= 50, "intro: they fall and rest on the floor at their radius (%d / 100)" % resting)
	check.call(low == 0, "intro: never through the floor")
	check.call(outside == 0, "intro: they stay within the ring")
	check.call(ir.crowd.count() == ir.live_count() and ir.crowd.count() == 100, "intro: the crowd draws every ball that came down (%d)" % ir.crowd.count())
	var b0: IntroRain.Drop = ir.balls[0]
	ir.pop_ball(b0)
	check.call(ir.popped == 1 and ir.balls.size() == 99 and ir.sparks.size() == 10 and sounds.has("start_pop") and chs.has("pop20"),
		"intro: popping counts, sparks, sounds and counts toward the challenge")
	ir.pop_ball(b0)
	check.call(ir.popped == 1, "intro: a ball pops once")
	# A shot through a ball pops it; one beside it doesn't.
	var b1: IntroRain.Drop = ir.balls[0]
	var p := b1.p
	check.call(not ir.pop_along(p + Vector3(1, 0.5, 1), p + Vector3(1, 0.5, -1), 0.02), "intro: a shot that misses pops nothing")
	check.call(ir.pop_along(p + Vector3(0, 0, 1), p + Vector3(0, 0, -1), 0.02) and b1.popped, "intro: a shot through a ball pops it")
	var before := ir.balls.size()
	var n := ir.pop_near(Vector3(0, 0, 0), 20.0)
	check.call(n == before and ir.balls.is_empty(), "intro: a burst pops all it reaches")
	for i in int(1.2 / DT):
		ir.step(DT, _head())
	check.call(ir.balls.size() == 100, "intro: all popped, a new wave a moment later")
	ir.free()


static func _start(check: Callable) -> void:
	var ir := _make()
	ir.begin(false)
	for i in 3:
		ir.step(DT, _head())
	while ir.t < 3.15:
		ir.step(DT, _head())
	check.call(not ir.start_panel.visible, "start: no button before 3.2 s")
	for i in 8:
		ir.step(DT, _head())
	var sp := ir.start_panel
	check.call(sp.visible and absf(sp.position.y - (1.6 - 0.55)) < 1e-4 and absf(-sp.position.z - 0.8) < 1e-4 and absf(absf(sp.position.x) - 0.3) < 1e-4,
		"start: shows after 3.2 s, low, ahead and to the side (%s)" % sp.position)
	check.call(absf(sp.basis.get_scale().x - 0.85) < 1e-3 and sp.basis.z.normalized().dot((Vector3(0, 1.6, 0) - sp.position).normalized()) > 0.999,
		"start: scale .85, tilted to face you")
	var at := sp.position
	check.call(ir.start_hit(Vector3(at.x, 1.6, 0), (at - Vector3(at.x, 1.6, 0)).normalized()) and ir._start_hot, "start: the ray on the panel lights the button")
	check.call(not ir.start_hit(Vector3(at.x, 1.6, 0), Vector3(0, 1, 0)), "start: a ray away misses")
	ir.step(DT, _head())
	ir.step(DT, _head())
	check.call(not ir._start_hot, "start: and dims when the ray leaves")
	ir.pop_ball(ir.balls[0])
	ir.step(DT, _head())
	check.call(ir.start_line.ends_with("1"), "start: counts the pops (%s)" % ir.start_line)
	var spill: Array = []
	for r: Dictionary in ir.measure_start():
		if float(r.w) > float(r.max_w) + 0.5:
			spill.append(r.s)
	check.call(spill.is_empty() and ir.start_texts.size() == 3, "start: the glass panel's labels fit (%s)" % [spill])
	var got := {"c": false}
	ir.cleared.connect(func() -> void: got.c = true)
	check.call(ir.end_intro() and not sp.visible and ir.sparks.is_empty(), "start: pressing it begins leaving")
	check.call(not ir.end_intro(), "start: only once")
	for i in int(0.3 / DT):
		ir.step(DT, _head())
	check.call(ir.active and ir.crowd.count() > 0, "start: the balls shrink away")
	for i in int(0.1 / DT):
		ir.step(DT, _head())
	check.call(not ir.active and got.c and ir.crowd.count() == 0, "start: gone within .35 s")
	ir.free()


static func _rain(check: Callable) -> void:
	var ir := _make()
	ir.begin(true)
	check.call(not ir.end_intro(), "rain: no start button to end it")
	for i in int(4.0 / DT):
		ir.step(DT, _head())
	check.call(ir.balls.size() == 100 and not ir.start_panel.visible, "rain: 100 balls, no button")
	var ahead := 0
	var accs := 0
	var big := 0
	var shown := 0
	for b in ir.balls:
		if b.pending:
			continue
		shown += 1
		if -b.p.z > 0.3:
			ahead += 1
		if b.accessory != "":
			accs += 1
		if b.R > 0.11 * 1.125 + 1e-6:
			big += 1
	check.call(ahead >= ir.live_count() * 0.9, "rain: falls in front of you (%d / %d)" % [ahead, ir.live_count()])
	check.call(accs == shown and shown > 0, "rain: every ball wears something")
	check.call(big == 0, "rain: the big ones are kept smaller")
	ir.pop_ball(ir.balls[0])
	check.call(ir.balls.size() == 100 and ir.popped == 1, "rain: a popped ball is replaced")
	# Two that meet hard pop each other.
	var a: IntroRain.Drop = ir.balls[0]
	var b: IntroRain.Drop = ir.balls[1]
	for d in [a, b]:
		d.born = 0.0
		d.pending = false
		d.hop = 10.0
	a.p = Vector3(0, a.R, -2)
	b.p = Vector3(a.R + b.R + 0.02, b.R, -2)
	a.v = Vector3(2, 0, 0)
	b.v = Vector3(-2, 0, 0)
	a.gx = 2.0
	b.gx = -2.0
	var popped_before := ir.popped
	for i in 3:
		ir.step(DT, _head())
	check.call(a.popped and b.popped and ir.popped == popped_before, "rain: a hard meeting pops both (not the player's)")
	ir.step(DT, _head())
	check.call(ir.balls.size() == 100, "rain: and refills")
	ir.set_rain(false)
	check.call(not ir.active and ir.crowd.count() == 0, "rain: off clears it")
	ir.free()
