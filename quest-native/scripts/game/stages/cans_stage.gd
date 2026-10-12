class_name CansStage
extends Node3D
## The tin cans (src/reference/stages/cans.js): a pyramid of six cans on a table, each a
## rigid cylinder with the reference's own impulse solver (sample points on the rims
## against the ground, the table top and the other cans). Game units.

const TY := 0.9
const TW := 2.2
const TD := 0.9
const TZ := -20.0
const CR := 0.22
const CH := 0.5
const M := 1.0
const INV_I := 1.0 / (M * (3 * CR * CR + CH * CH) / 12)
const UP := Vector3.UP


## One rack, one launched ball. A blaster or second throw invalidates that rack
## (challenge-rules.js createThrowAttempt).
class ThrowAttempt:
	var owner := 0
	var valid := true
	var touched := false

	func reset() -> void:
		owner = 0
		valid = true
		touched = false

	func launch(id: int) -> void:
		if not id:
			valid = false
			return
		if owner and owner != id:
			valid = false
		else:
			owner = id

	func contact(id: int, intact: bool) -> void:
		if not id:
			valid = false
			return
		if not owner:
			valid = false
		if owner != id or (not touched and not intact):
			valid = false
		touched = true

	func invalidate() -> void:
		valid = false

	func complete() -> bool:
		return valid and owner > 0 and touched


var aim_z := TZ
var far_z = null
var reach_z = null
var ctx: GameCtx
var friction = null
var shot_time = null
var cans: Array = []
var samples: Array = []
var attempt := ThrowAttempt.new()
var cleared := false
var clang_t := 0.0
var _touched := false
var auto_t := 0.0
var time := 0.0
var _last_ball: Ball
var _rng := RandomNumberGenerator.new()
var nrm := Vector3.ZERO


func _init() -> void:
	_rng.seed = 31
	name = "Cans"
	# table
	var top := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(TW, 0.06, TD)
	top.mesh = tb
	top.material_override = _mat(Color("cfae86"), 0.85)
	top.position = Vector3(0, TY - 0.03, TZ)
	add_child(top)
	var tf := HoopStage.box_edges(tb.size, HoopStage.line_mat(StageArt.INK, 0.6))
	tf.position = top.position
	add_child(tf)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			StageArt.bar(self, Vector3(sx * (TW / 2 - 0.1), 0, TZ + sz * (TD / 2 - 0.1)),
				Vector3(sx * (TW / 2 - 0.1), TY - 0.06, TZ + sz * (TD / 2 - 0.1)), 0.035)
	# cans
	var can_geo := CylinderMesh.new()
	can_geo.top_radius = CR
	can_geo.bottom_radius = CR
	can_geo.height = CH
	can_geo.radial_segments = 28
	can_geo.rings = 1
	var label_geo := CylinderMesh.new()
	label_geo.top_radius = CR * 1.01
	label_geo.bottom_radius = CR * 1.01
	label_geo.height = CH * 0.56
	label_geo.radial_segments = 28
	label_geo.rings = 1
	label_geo.cap_top = false
	label_geo.cap_bottom = false
	# three.js TorusGeometry turned flat (rotation.x = PI/2): Godot's torus already lies flat.
	var rim_geo := TorusMesh.new()
	rim_geo.inner_radius = CR * 0.97 - 0.012
	rim_geo.outer_radius = CR * 0.97 + 0.012
	rim_geo.rings = 28
	rim_geo.ring_segments = 6
	var tin_mat := _mat(Color("a4a9ad"), 0.6)
	tin_mat.metallic = 0.18
	var label_mats := [_glow(Color("ff805c")), _glow(Color("57b8f0"))]
	var rim_mat := HoopStage.line_mat(StageArt.INK)
	for i in 6:
		var g := Node3D.new()
		var body := MeshInstance3D.new()
		body.mesh = can_geo
		body.material_override = tin_mat
		g.add_child(body)
		var lab := MeshInstance3D.new()
		lab.mesh = label_geo
		lab.material_override = label_mats[i % 2]
		lab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(lab)
		for s in [-1.0, 1.0]:
			var r := MeshInstance3D.new()
			r.mesh = rim_geo
			r.material_override = rim_mat
			r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			r.position.y = s * CH / 2
			g.add_child(r)
		add_child(g)
		cans.append({"mesh": g, "x": Vector3.ZERO, "v": Vector3.ZERO, "q": Quaternion.IDENTITY, "w": Vector3.ZERO,
			"invM": 1.0 / M, "invI": INV_I, "sleep": true, "down": false})
	for s in [-1.0, 1.0]:
		for k in 8:
			var a := k / 8.0 * PI * 2
			samples.append(Vector3(cos(a) * CR, s * CH / 2, sin(a) * CR))
	reset_cans()


static func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


static func _glow(c: Color) -> StandardMaterial3D:
	var m := _mat(c, 0.6)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.035
	return m


func reset_cans() -> void:
	var g := 0.006
	var sp := 2 * CR + g
	var layout := [[-sp, 0], [0.0, 0], [sp, 0], [-sp / 2, 1], [sp / 2, 1], [0.0, 2]]
	for i in layout.size():
		var c: Dictionary = cans[i]
		var x: float = layout[i][0]
		var row: int = layout[i][1]
		c.x = Vector3(x, TY + CH / 2 + row * (CH + 0.003) + 0.001, TZ)
		c.v = Vector3.ZERO
		c.w = Vector3.ZERO
		c.q = Quaternion.IDENTITY
		c.sleep = true
		c.down = false
		c.mesh.position = c.x
		c.mesh.quaternion = c.q
	cleared = false
	attempt.reset()


static func _vel_at(b: Dictionary, r: Vector3) -> Vector3:
	return (b.w as Vector3).cross(r) + b.v


static func _apply_imp(b: Dictionary, r: Vector3, dir: Vector3, j: float) -> void:
	b.v += dir * (j * b.invM)
	if b.invI:
		b.w += r.cross(dir) * (j * b.invI)


## Impulse contact between body A and body B (or the static world when B is null) at p
## along n (pointing towards A); returns the normal impulse.
static func contact(A: Dictionary, B, p: Vector3, n: Vector3, depth: float, e: float, mu: float) -> float:
	var ia: float = A.invM
	var ib: float = B.invM if B else 0.0
	var tot := ia + ib
	if tot <= 0.0:
		return 0.0
	var corr := maxf(0.0, depth - 0.002) * 0.8
	A.x += n * (corr * ia / tot)
	if B:
		B.x += n * (-corr * ib / tot)
	var ra: Vector3 = p - A.x
	var rb: Vector3 = p - B.x if B else Vector3.ZERO
	var tv := _vel_at(A, ra)
	if B:
		tv -= _vel_at(B, rb)
	var vn := tv.dot(n)
	if vn >= 0.0:
		return 0.0
	var ka: float = ra.cross(n).length_squared() * A.invI
	var kb: float = rb.cross(n).length_squared() * B.invI if B else 0.0
	var ee := 0.0 if vn > -0.6 else e
	var j := -(1 + ee) * vn / (ia + ib + ka + kb)
	_apply_imp(A, ra, n, j)
	if B:
		_apply_imp(B, rb, n, -j)
	# friction
	tv += n * -vn
	var vt := tv.length()
	if vt > 1e-5:
		var t := tv / vt
		var kta: float = ra.cross(t).length_squared() * A.invI
		var ktb: float = rb.cross(t).length_squared() * B.invI if B else 0.0
		var jt := -vt / (ia + ib + kta + ktb)
		jt = maxf(-mu * j, minf(mu * j, jt))
		_apply_imp(A, ra, t, jt)
		if B:
			_apply_imp(B, rb, t, -jt)
	return j


## point against a can's cylinder; returns depth and sets nrm (world, pointing out of the can)
func point_in_can(p: Vector3, B: Dictionary) -> float:
	var q: Quaternion = B.q
	var lp: Vector3 = q.inverse() * (p - B.x)
	var rad := Vector2(lp.x, lp.z).length()
	var pr := CR - rad
	var pa := CH / 2 - absf(lp.y)
	if pr <= 0.0 or pa <= 0.0:
		return 0.0
	if pa < pr:
		nrm = Vector3(0, signf(lp.y) if lp.y != 0.0 else 1.0, 0)
	else:
		var rr := rad if rad != 0.0 else 1.0
		nrm = Vector3(lp.x / rr, 0, lp.z / rr)
	nrm = q * nrm
	return minf(pa, pr)


func wake_all() -> void:
	for c in cans:
		c.sleep = false


## clang(s): the stage's own tin "clang" (three triangle partials); s 0..1 is how hard.
func clang(s: float, pos: Vector3) -> void:
	if time - clang_t < 0.05:
		return
	clang_t = time
	if ctx:
		ctx.sfx.call("cans_clang", s, pos)


static func on_table(c: Dictionary) -> bool:
	var x: Vector3 = c.x
	return x.y > TY - 0.05 and absf(x.x) < TW / 2 and absf(x.z - TZ) < TD / 2


func _ball() -> Ball:
	if ctx and ctx.ball:
		return ctx.ball
	return _last_ball


## A blaster shot hit node (a mesh of this stage) at point going along dir.
func shoot(obj: Node, point: Vector3, dir: Vector3) -> bool:
	var c = StageArt.body_of(cans, obj)
	if not c:
		return false
	attempt.invalidate()
	wake_all()
	StageArt.shove(c, dir, point, 4.5)
	clang(0.7, point)
	return true


func ft(sp: float) -> float:
	return maxf(0.8, minf(1.6, 1.75 - sp / 2400.0))


func behind(p: Vector3) -> bool:
	return p.z < TZ - 0.7


func on_respawn() -> void:
	if cleared:
		reset_cans()
	_touched = false


func on_throw() -> void:
	var b := _ball()
	attempt.launch(b.shot_id if b else 0)


func touched() -> bool:
	return _touched


func collide(b: Ball) -> void:
	_last_ball = b
	if b.shot and not _touched and b.pos.z < TZ - 1:
		b.miss()
	# ball vs the table block
	var P := b.pos
	var cx := clampf(P.x, -TW / 2, TW / 2)
	var cy := clampf(P.y, 0.0, TY)
	var cz := clampf(P.z, TZ - TD / 2, TZ + TD / 2)
	b.point_collide(Vector3(cx, cy, cz), 0, 0.4)


## ball vs cans (wakes the pile); also used for extra balls in a headset volley
func ball_contact(b: Ball) -> void:
	for c in cans:
		var q: Quaternion = c.q
		var lp: Vector3 = q.inverse() * (b.pos - c.x)
		var rad := Vector2(lp.x, lp.z).length()
		var qx := lp.x / rad * CR if rad > CR else lp.x
		var qz := lp.z / rad * CR if rad > CR else lp.z
		var qy := clampf(lp.y, -CH / 2, CH / 2)
		var wp: Vector3 = q * Vector3(qx, qy, qz) + c.x
		var n := b.pos - wp
		var d := n.length()
		if d > 1e-5 and d < Ball.BR:
			n /= d
			wake_all()
			var before := b.vel.dot(n)
			var ball_body := {"x": b.pos, "v": b.vel, "w": Vector3.ZERO, "invM": 1.0 / 2.5, "invI": 0.0}
			var j := contact(ball_body, c, wp, n, Ball.BR - d, 0.35, 0.3)
			b.pos = ball_body.x
			b.vel = ball_body.v
			if j > 0.0:
				attempt.contact(b.shot_id if b.shot else 0, cans.all(func(k): return not k.down))
				b.hit(n, maxf(0.0, -before) * 0.7, wp)
				clang(minf(1.0, j / 4.0), wp)
				if not _touched and b.shot:
					_touched = true
					b.react("joy", 1.3)


func update(b: Ball, dt: float) -> void:
	_last_ball = b
	time = b.time
	ball_contact(b)
	# Knocked off by the headset's blaster while Dahrooj is still in hand: a moment later, a fresh stack.
	if cleared and not b.shot:
		auto_t += dt
		if auto_t > 1.6:
			auto_t = 0.0
			reset_cans()
	else:
		auto_t = 0.0
	if cans.all(func(k): return k.sleep):
		return
	for c in cans:
		if c.sleep:
			continue
		var v: Vector3 = c.v
		v.y -= Ball.GRAV * dt
		c.v = v
		c.x += v * dt
		var w: Vector3 = c.w
		var q: Quaternion = c.q
		var wq := Quaternion(w.x * dt * 0.5, w.y * dt * 0.5, w.z * dt * 0.5, 0) * q
		c.q = Quaternion(q.x + wq.x, q.y + wq.y, q.z + wq.z, q.w + wq.w).normalized()
		c.v *= pow(0.85, dt)
		c.w *= pow(0.5, dt)
	for it in 3:
		for ai in cans.size():
			var A: Dictionary = cans[ai]
			if A.sleep:
				continue
			for s in samples:
				var wp: Vector3 = (A.q as Quaternion) * (s as Vector3) + A.x
				if wp.y < 0.0:
					contact(A, null, wp, UP, -wp.y, 0.25, 0.6)
				elif wp.y < TY and wp.y > TY - 0.12 and absf(wp.x) < TW / 2 and absf(wp.z - TZ) < TD / 2 and A.x.y > TY:
					contact(A, null, wp, UP, TY - wp.y, 0.25, 0.6)
				for bi in cans.size():
					if bi == ai:
						continue
					var B: Dictionary = cans[bi]
					var dep := point_in_can(wp, B)
					if dep > 0.0:
						var j := contact(A, B, wp, nrm, dep, 0.25, 0.4)
						if j > 1.2:
							clang(minf(1.0, j / 6.0), wp)
	for c in cans:
		c.mesh.position = c.x
		c.mesh.quaternion = c.q
		if not c.down and not on_table(c):
			c.down = true
			if ctx:
				ctx.add_count.call("cans", false)
	if not cleared and cans.all(func(k): return not on_table(k)):
		cleared = true
		if attempt.complete() and ctx:
			ctx.ch_progress.call("cansOne", 1)
		if b.shot:
			b.scored_t = 0.0
			b.miss_t = 0.0
			b.success()
