extends RefCounted
## Headless checks of the window (stages/window.js port): a throw through the frame
## scores, the window then shrinks and moves; a wide throw misses; the frame is solid.


static func _setup() -> Array:
	var st := WindowStage.new()
	var b := Ball.new()
	var ctx := GameCtx.new()
	ctx.ball = b
	st.ctx = ctx
	var progress: Array = []
	ctx.ch_progress = func(id, v): progress.append([id, v])
	b.set_stage(st, "window")
	var got: Array = []
	b.event.connect(func(k, d): got.append([k, d]))
	return [st, b, ctx, progress, got]


static func _kinds(got: Array) -> Array:
	return got.map(func(e): return e[0])


## Velocity from p that reaches the window centre c after t seconds (gravity and drag 0.9^t).
static func _aim(p: Vector3, c: Vector3, t: float) -> Vector3:
	var lk := log(0.9)
	var f := (1.0 - pow(0.9, t)) / -lk  # integral of 0.9^s ds
	var v := (c - p) / f
	v.y = (c.y - p.y + Ball.GRAV * t * t / 2.0) / f
	return v


static func run(check: Callable) -> void:
	var s := _setup()
	var st: WindowStage = s[0]
	var b: Ball = s[1]
	var progress: Array = s[3]
	var got: Array = s[4]
	# Pop-in: the new frame grows from small.
	b.step(1.0 / 72.0)
	check.call(st.W.frame.scale.x > 0.01 and st.W.frame.scale.x < 0.1, "window: the frame pops in from small")
	for i in 72:
		b.step(1.0 / 72.0)
	check.call(is_equal_approx(st.W.frame.scale.x, 1.0), "window: the frame settles at full size")
	# 1. Through the middle of the window.
	var c := Vector3(st.W.x, st.W.y, WindowStage.WZ)
	var size0: float = st.W.size
	b.pos = Vector3(0, 1.5, -3)
	b.throw_with(_aim(b.pos, c, 0.8))
	for i in 72 * 2:
		b.step(1.0 / 72.0)
	var k := _kinds(got)
	check.call(k.has("success") and not k.has("miss"), "window: a throw through the window scores")
	check.call(is_equal_approx(st.W.size, size0 * WindowStage.SHRINK), "window: it shrinks after the hit")
	check.call(Vector2(st.W.x - c.x, st.W.y - c.y).length() >= 1.6, "window: it moves away after the hit")
	check.call(st.get_child_count() == 2, "window: the old frame is gone")
	# 2. Wide of the window.
	for i in 72 * 3:
		b.step(1.0 / 72.0)
	got.clear()
	var wide := Vector3(st.W.x + (2.5 if st.W.x < 0.0 else -2.5), st.W.y, WindowStage.WZ)
	b.pos = Vector3(0, 1.5, -3)
	b.throw_with(_aim(b.pos, wide, 0.8))
	for i in 72 * 2:
		b.step(1.0 / 72.0)
	k = _kinds(got)
	check.call(k.has("miss") and not k.has("success"), "window: a throw wide of the window misses")
	# 3. The frame is solid: a throw at the bottom bar bounces back.
	for i in 72 * 3:
		b.step(1.0 / 72.0)
	got.clear()
	var o: Vector3 = st.W.frame.position
	var bar := Vector3(o.x, o.y - st.W.size / 2 - WindowStage.FR, WindowStage.WZ + 0.3)
	b.pos = Vector3(0, 1.5, -3)
	b.throw_with(_aim(b.pos, bar, 0.7))
	var back := false
	for i in 72:
		b.step(1.0 / 72.0)
		if b.vel.z > 0.0:
			back = true
			break
	check.call(back and _kinds(got).has("thump"), "window: the frame bounces Dahrooj back")
	# 4. The smallest window reports the challenge.
	st.W.size = WindowStage.MIN
	st.relocate()
	check.call(progress.has(["windowMin", 1]), "window: the smallest window counts for its challenge")
	check.call(is_equal_approx(WindowStage.MIN, 0.576), "window: smallest is 1.2 ball widths")
	st.free()
