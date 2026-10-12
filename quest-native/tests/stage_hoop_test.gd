extends RefCounted
## Headless checks of the hoop (stages/hoop.js port): a lob drops through the rim and
## swishes the net, a short lob misses, a flat throw bounces off the backboard.


static func _setup() -> Array:
	var st := HoopStage.new()
	var b := Ball.new()
	var ctx := GameCtx.new()
	ctx.ball = b
	st.ctx = ctx
	var sounds: Array = []
	ctx.sfx = func(n, k, p): sounds.append([n, k, p])
	b.set_stage(st, "hoop")
	var got: Array = []  # [kind, data] of every ball event
	b.event.connect(func(k, d): got.append([k, d]))
	return [st, b, ctx, sounds, got]


static func _kinds(got: Array) -> Array:
	return got.map(func(e): return e[0])


static func run(check: Callable) -> void:
	# 1. A lob from 3 m out drops through the rim from above.
	var s := _setup()
	var st: HoopStage = s[0]
	var b: Ball = s[1]
	var sounds: Array = s[3]
	var got: Array = s[4]
	var rim_aabb: AABB = st.rim.get_aabb()
	check.call(rim_aabb.size.y < 0.1 and absf(rim_aabb.size.x - 2 * (HoopStage.RR + HoopStage.TUBE)) < 0.01,
		"hoop: the rim lies flat, 0.48 radius")
	var net0: Vector3 = st.npos[2 * HoopStage.N]
	b.pos = Vector3(0, 1.5, -3)
	b.throw_with(Vector3(0, 9.0, -5.0))
	var net_moved := false
	for i in 72 * 4:
		b.step(1.0 / 72.0)
		if st.npos[2 * HoopStage.N].distance_to(net0) > 0.02:
			net_moved = true
	var k := _kinds(got)
	check.call(k.has("success") and not k.has("miss"), "hoop: a lob through the rim scores")
	check.call(sounds.any(func(e): return e[0] == "swish"), "hoop: the score swishes")
	check.call(net_moved, "hoop: the net stretches as the ball drops through")
	check.call(not b.shot, "hoop: Dahrooj comes back after the score")
	st.free()

	# 2. A lob too short: it falls below the rim and misses.
	s = _setup()
	st = s[0]
	b = s[1]
	got = s[4]
	b.pos = Vector3(0, 1.5, -3)
	b.throw_with(Vector3(0, 7.0, -4.0))
	for i in 72 * 4:
		b.step(1.0 / 72.0)
	k = _kinds(got)
	check.call(k.has("miss") and not k.has("success"), "hoop: a short lob misses")
	st.free()

	# 3. A flat throw at the backboard bounces back with a thump.
	s = _setup()
	st = s[0]
	b = s[1]
	got = s[4]
	b.pos = Vector3(0.3, 3.5, -4)
	b.throw_with(Vector3(0, 1.0, -12.0))
	var back := false
	for i in 72:
		b.step(1.0 / 72.0)
		if b.vel.z > 0.0 and b.pos.z > HoopStage.BBZ:
			back = true
			break
	check.call(back and _kinds(got).has("thump"), "hoop: the backboard bounces Dahrooj back")
	check.call(st.behind(Vector3(0, 1, -9.2)) and not st.behind(Vector3(0, 1, -8.9)), "hoop: behind the board")
	check.call(is_equal_approx(st.ft(0.0), 1.5) and is_equal_approx(st.ft(5000.0), 0.75), "hoop: ft as in the reference")
	st.free()
