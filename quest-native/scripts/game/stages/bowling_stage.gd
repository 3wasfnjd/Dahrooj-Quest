class_name BowlingStage
extends Node3D
## The bowling lane (src/reference/stages/bowling.js): a slick lane with aiming arrows, ten
## pins on a rigid-body solver (impulses with friction, sample points on each pin), two rolls
## a frame, strike/spare toasts and the strike1 challenge. Game units.

const S_PIN := 0.34
const PH := 2.967 * S_PIN
const CR := 0.15
const CH := PH
const HEAD := -16.0
const LANE_W := 1.9
const BACK := -19.4
const PIN_MASS := 0.6
## The pin's bounding radius about its centre: no sample point inside a pin lies farther.
const PIN_RAD2 := (CH / 2.0) * (CH / 2.0) + CR * CR

var aim_z := -9.0
var far_z = BACK + 0.5
var reach_z = null
var friction = 0.97
var shot_time = 10.0
var ctx: GameCtx

var pins: Array = []
var spots: Array = []
var samples: Array = []
var attempt := ThrowAttempt.new()
var roll := 0
var knocked := 0
var _touched := false
var clack_t := -1.0
var struck := false
var thrown := false
var auto_t := 0.0
var time := 0.0
var _ball: Ball
var _nrm := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


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


func _init() -> void:
	_rng.seed = 17
	name = "Bowling"
	# Lane boards with the aiming arrows, and dark gutters at the sides.
	var lane_len := 1.0 - BACK
	var lane_mat := StandardMaterial3D.new()
	lane_mat.albedo_texture = _lane_tex()
	lane_mat.roughness = 0.45
	lane_mat.metallic = 0.0
	lane_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var lane := _flat_quad(LANE_W, lane_len, lane_mat)
	lane.position = Vector3(0, 0.006, (1.0 + BACK) / 2.0)
	add_child(lane)
	for s in [-1.0, 1.0]:
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color("3a3340")
		gm.roughness = 0.6
		var gut := _flat_quad(0.22, lane_len, gm)
		gut.position = Vector3(s * (LANE_W / 2.0 + 0.11), 0.005, (1.0 + BACK) / 2.0)
		add_child(gut)
	# The pit at the back: a dark board that stops the pins and the ball.
	var back := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(LANE_W + 0.44, 0.7, 0.12)
	back.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color("2c2d3d")
	bmat.roughness = 0.8
	back.material_override = bmat
	back.position = Vector3(0, 0.35, BACK - 0.06)
	add_child(back)
	# Pins: Motri's model once it loads, a turned shape until then.
	var prof := [[0, 0], [.33, 0], [.42, .08], [.5, .3], [.42, .5], [.24, .66], [.22, .74], [.3, .86], [.27, .96], [0, 1]]
	var pts: Array = []
	for rp in prof:
		pts.append(Vector2(float(rp[0]) * 0.511 * S_PIN, float(rp[1]) * PH))
	var pin_mesh: Mesh = _lathe(pts, 20)
	var pin_mat := StandardMaterial3D.new()
	pin_mat.albedo_color = Color("f4efe6")
	pin_mat.roughness = 0.35
	var pin_scale := 1.0
	var model := _load_pin_model()
	if model:
		pin_mesh = model
		pin_scale = S_PIN
	# refPinPositions from Motri, head pin first: depth back along the lane and offset across it.
	var REF := [[-10.79, 67.77], [-11.94, 68.49], [-11.94, 67.05], [-13.08, 69.21], [-13.08, 67.77], [-13.08, 66.32],
		[-14.25, 69.94], [-14.25, 68.49], [-14.25, 67.05], [-14.25, 65.6]]
	for xz in REF:
		spots.append([(float(xz[1]) - 67.77) * S_PIN, HEAD + (float(xz[0]) + 10.79) * S_PIN])
	var inv_i := 1.0 / (PIN_MASS * (3.0 * CR * CR + CH * CH) / 12.0)
	for i in 10:
		var g := Node3D.new()
		var mesh := MeshInstance3D.new()
		mesh.mesh = pin_mesh
		if model == null:
			mesh.material_override = pin_mat
		mesh.scale = Vector3.ONE * pin_scale
		mesh.position.y = -CH / 2.0
		g.add_child(mesh)
		add_child(g)
		pins.append({"mesh": g, "body": mesh, "x": Vector3.ZERO, "v": Vector3.ZERO, "q": Quaternion.IDENTITY,
			"w": Vector3.ZERO, "inv_m": 1.0 / PIN_MASS, "inv_i": inv_i, "sleep": true, "down": false, "gone": false, "calm": 0.0})
	for y in [-CH / 2.0, -CH / 6.0, CH / 6.0, CH / 2.0]:
		for k in 8:
			var a := float(k) / 8.0 * PI * 2.0
			var r := CR * 0.8 if absf(y) > CH / 3.0 else CR
			samples.append(Vector3(cos(a) * r, y, sin(a) * r))
	set_pins(true)


## The lane's canvas (128 x 1024): boards, their seams, the arrows and the dots.
static func _lane_tex() -> ImageTexture:
	var img := Image.create(128, 1024, false, Image.FORMAT_RGBA8)
	var seam := Color(120 / 255.0, 70 / 255.0, 30 / 255.0)
	for i in 16:
		var c := Color("d9a066") if i % 2 else Color("cf955a")
		img.fill_rect(Rect2i(i * 8, 0, 8, 1024), c)
		img.fill_rect(Rect2i(i * 8, 0, 1, 1024), c.lerp(seam, 0.35))
	var ink := Color("8a4b2a")
	for i in range(-2, 3):
		var ax := 64.0 + i * 20
		var ay := 330.0 + absi(i) * 26
		# triangle (ax, ay-18) (ax+6, ay) (ax-6, ay)
		for py in range(int(ay - 18), int(ay) + 1):
			for px in range(int(ax - 6), int(ax + 6) + 1):
				var cy := py + 0.5
				var cx := px + 0.5
				var t := (cy - (ay - 18.0)) / 18.0
				if t >= 0.0 and t <= 1.0 and absf(cx - ax) <= 6.0 * t:
					img.set_pixel(px, py, ink)
	for i in range(-3, 4):
		var cx0 := 64.0 + i * 16
		for py in range(617, 624):
			for px in range(int(cx0) - 3, int(cx0) + 4):
				if Vector2(px + 0.5 - cx0, py + 0.5 - 620.0).length() <= 3.0:
					img.set_pixel(px, py, ink)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## A flat plane (three.js PlaneGeometry rotated -90° about x): canvas top at the far end (-z).
static func _flat_quad(w: float, l: float, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var v := [Vector3(-w / 2, 0, -l / 2), Vector3(w / 2, 0, -l / 2), Vector3(w / 2, 0, l / 2), Vector3(-w / 2, 0, l / 2)]
	var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.UP)
		st.set_uv(uv[k])
		st.add_vertex(v[k])
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = mat
	return m


## three.js LatheGeometry: the profile (x = radius, y = height) turned round the y axis.
static func _lathe(pts: Array, segs: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	var nrm2: Array = []
	for i in n:
		var a: Vector2 = pts[maxi(0, i - 1)]
		var b: Vector2 = pts[mini(n - 1, i + 1)]
		var t := (b - a).normalized()
		nrm2.append(Vector2(t.y, -t.x))
	for j in segs:
		var p0 := float(j) / segs * TAU
		var p1 := float(j + 1) / segs * TAU
		for i in n - 1:
			var quad := []
			for c in [[i, p0], [i, p1], [i + 1, p1], [i + 1, p0]]:
				var pp: Vector2 = pts[c[0]]
				var nn: Vector2 = nrm2[c[0]]
				var ph: float = c[1]
				quad.append([Vector3(pp.x * sin(ph), pp.y, pp.x * cos(ph)), Vector3(nn.x * sin(ph), nn.y, nn.x * cos(ph)).normalized()])
			for tri in [[0, 1, 2], [0, 2, 3]]:
				var A: Vector3 = quad[tri[0]][0]
				var B: Vector3 = quad[tri[1]][0]
				var C: Vector3 = quad[tri[2]][0]
				var out: Vector3 = quad[tri[0]][1] + quad[tri[1]][1] + quad[tri[2]][1]
				var order: Array = tri
				if (B - A).cross(C - A).dot(out) > 0.0:  # Godot's front faces wind clockwise
					order = [tri[0], tri[2], tri[1]]
				for k in order:
					st.set_normal(quad[k][1])
					st.add_vertex(quad[k][0])
	return st.commit()


## Motri's pin (assets/models/bowlingPin.glb): its first mesh, used unscaled (the stage scales it by S_PIN).
static func _load_pin_model() -> Mesh:
	var path := "res://assets/models/bowlingPin.glb"
	if not ResourceLoader.exists(path):
		return null
	var ps = load(path)
	if not (ps is PackedScene):
		return null
	var inst: Node = (ps as PackedScene).instantiate()
	var found: Mesh = null
	var stack: Array = [inst]
	while not stack.is_empty() and found == null:
		var o: Node = stack.pop_front()
		if o is MeshInstance3D and (o as MeshInstance3D).mesh:
			found = (o as MeshInstance3D).mesh
		for ch in o.get_children():
			stack.append(ch)
	inst.free()
	return found


func _S() -> Ball:
	if ctx and ctx.ball:
		return ctx.ball
	return _ball


func _sfx(n: String, k: float, p: Vector3) -> void:
	if ctx:
		ctx.sfx.call(n, k, p)


func is_down(p: Dictionary) -> bool:
	return p.gone or (p.q * Vector3.UP).y < 0.5 or p.x.y < CH / 2.0 - 0.25


func set_pins(all: bool) -> void:
	for i in pins.size():
		var p: Dictionary = pins[i]
		if not all and not p.down:
			continue
		if not all and p.down:
			p.gone = true
			p.mesh.visible = false
			p.sleep = true
			continue
		p.x = Vector3(spots[i][0], CH / 2.0 + 0.001, spots[i][1])
		p.v = Vector3.ZERO
		p.w = Vector3.ZERO
		p.q = Quaternion.IDENTITY
		p.sleep = true
		p.down = false
		p.gone = false
		p.mesh.visible = true
		p.mesh.position = p.x
		p.mesh.quaternion = p.q
	if all:
		roll = 0
		knocked = 0
		attempt.reset()


static func _vel_at(b: Dictionary, r: Vector3) -> Vector3:
	return (b.w as Vector3).cross(r) + b.v


static func _apply_imp(b: Dictionary, r: Vector3, dir: Vector3, j: float) -> void:
	b.v += dir * (j * b.inv_m)
	if b.inv_i:
		b.w += r.cross(dir) * (j * b.inv_i)


## An impulse contact between body A and body B (or the ground when B is empty) at p along n.
static func contact(A: Dictionary, B: Dictionary, p: Vector3, n: Vector3, depth: float, e: float, mu: float) -> float:
	var hb := not B.is_empty()
	var ia: float = A.inv_m
	var ib: float = B.inv_m if hb else 0.0
	var tot := ia + ib
	if tot <= 0.0:
		return 0.0
	var corr := maxf(0.0, depth - 0.002) * 0.8
	A.x += n * (corr * ia / tot)
	if hb:
		B.x -= n * (corr * ib / tot)
	var ra: Vector3 = p - A.x
	var rb: Vector3 = (p - B.x) if hb else Vector3.ZERO
	var tv := _vel_at(A, ra)
	if hb:
		tv -= _vel_at(B, rb)
	var vn := tv.dot(n)
	if vn >= 0.0:
		return 0.0
	var ka: float = ra.cross(n).length_squared() * A.inv_i
	var kb: float = rb.cross(n).length_squared() * B.inv_i if hb else 0.0
	var j := -(1.0 + (0.0 if vn > -0.6 else e)) * vn / (ia + ib + ka + kb)
	_apply_imp(A, ra, n, j)
	if hb:
		_apply_imp(B, rb, n, -j)
	tv += n * -vn
	var vt := tv.length()
	if vt > 1e-5:
		var t := tv / vt
		var kta: float = ra.cross(t).length_squared() * A.inv_i
		var ktb: float = rb.cross(t).length_squared() * B.inv_i if hb else 0.0
		var jt := -vt / (ia + ib + kta + ktb)
		jt = maxf(-mu * j, minf(mu * j, jt))
		_apply_imp(A, ra, t, jt)
		if hb:
			_apply_imp(B, rb, t, -jt)
	return j


## Depth of point p inside pin B (0 when outside); the push-out normal goes to _nrm.
func point_in_pin(p: Vector3, B: Dictionary) -> float:
	var q: Quaternion = B.q
	var lp: Vector3 = q.inverse() * (p - B.x)
	var rad := Vector2(lp.x, lp.z).length()
	var pr := CR - rad
	var pa := CH / 2.0 - absf(lp.y)
	if pr <= 0.0 or pa <= 0.0:
		return 0.0
	if pa < pr:
		var sy := signf(lp.y)
		_nrm = Vector3(0, sy if sy != 0.0 else 1.0, 0)
	else:
		var rr := rad if rad != 0.0 else 1.0
		_nrm = Vector3(lp.x / rr, 0, lp.z / rr)
	_nrm = q * _nrm
	return minf(pa, pr)


## A wooden clack, louder for harder hits (made here, no recorded sounds).
func clack(s: float, at: Vector3) -> void:
	if time - clack_t < 0.04 and clack_t >= 0.0:
		return
	clack_t = time
	_sfx("bowling_clack", s, at)


func live() -> Array:
	return pins.filter(func(p): return not p.gone)


func shoot(obj: Node, point: Vector3, dir: Vector3) -> bool:
	var p = StageArt.body_of(pins, obj)
	if p == null:
		return false
	attempt.invalidate()
	for q in pins:
		q.sleep = false
	StageArt.shove(p, dir, point, 4)
	return true


## Test view: each pin's state.
func pins_state() -> Array:
	return pins.map(func(p): return {"down": p.down, "gone": p.gone, "x": p.x.x, "y": p.x.y, "z": p.x.z})


func frame() -> Dictionary:
	return {"roll": roll, "knocked": knocked}


func ft(sp: float) -> float:
	return maxf(0.55, minf(1.1, 1.2 - sp / 3000.0))


func behind(p: Vector3) -> bool:
	return p.z < HEAD - 0.4


func on_throw() -> void:
	var b := _S()
	attempt.launch(b.shot_id if b else 0)


func on_respawn() -> void:
	# After the first roll the fallen pins are swept away; after a strike or the second roll, a fresh rack.
	if not thrown:
		return
	thrown = false
	roll += 1
	if roll >= 2 or pins.all(func(p): return p.down):
		set_pins(true)
	else:
		set_pins(false)
	_touched = false
	struck = false


func touched() -> bool:
	return _touched


func collide(b: Ball) -> void:
	_ball = b
	var P := b.pos
	# The back board.
	if P.z < BACK + Ball.BR and absf(P.x) < LANE_W / 2.0 + 0.3 and P.y < 0.7 + Ball.BR:
		b.pos.z = BACK + Ball.BR
		if b.vel.z < 0.0:
			b.hit(Vector3(0, 0, 1), -b.vel.z, Vector3(b.pos.x, b.pos.y, BACK))
			b.vel.z *= -0.25
	if b.shot:
		thrown = true
	if b.shot and not _touched and b.pos.z < HEAD - 1.6:
		b.miss()


func ball_contact(b: Ball) -> void:
	_ball = b
	var L := live()
	for c in L:
		var q: Quaternion = c.q
		var lp: Vector3 = q.inverse() * (b.pos - c.x)
		var rad := Vector2(lp.x, lp.z).length()
		var qx := lp.x / rad * CR if rad > CR else lp.x
		var qz := lp.z / rad * CR if rad > CR else lp.z
		var qy := clampf(lp.y, -CH / 2.0, CH / 2.0)
		var wp: Vector3 = q * Vector3(qx, qy, qz) + c.x
		var n := b.pos - wp
		var d := n.length()
		if d > 1e-5 and d < Ball.BR:
			n /= d
			for p in L:
				p.sleep = false
			var before := b.vel.dot(n)
			var ball_body := {"x": b.pos, "v": b.vel, "w": Vector3.ZERO, "inv_m": 1.0 / 2.5, "inv_i": 0.0}
			var j := contact(ball_body, c, wp, n, Ball.BR - d, 0.3, 0.3)
			b.pos = ball_body.x
			b.vel = ball_body.v
			if j > 0.0:
				attempt.contact(b.shot_id if b.shot else 0, pins.all(func(p): return not p.down and not p.gone))
				b.hit(n, maxf(0.0, -before) * 0.5, wp)
				clack(minf(1.0, j / 3.0), wp)
				if not _touched and b.shot:
					_touched = true
					b.react("joy", 1.3)


func update(b: Ball, dt: float) -> void:
	_ball = b
	time += dt
	ball_contact(b)
	# Every pin shot down while Dahrooj is still in hand: a moment later, a fresh rack.
	if not b.shot and not thrown and pins.all(func(p): return p.down or p.gone):
		auto_t += dt
		if auto_t > 1.6:
			auto_t = 0.0
			roll = 0
			set_pins(true)
			_touched = false
			struck = false
	else:
		auto_t = 0.0
	var L := live()
	if L.all(func(c): return c.sleep):
		return
	for c in L:
		if c.sleep:
			continue
		c.v.y -= Ball.GRAV * dt
		c.x += c.v * dt
		var q: Quaternion = c.q
		var wq := Quaternion(c.w.x * dt * 0.5, c.w.y * dt * 0.5, c.w.z * dt * 0.5, 0) * q
		c.q = Quaternion(q.x + wq.x, q.y + wq.y, q.z + wq.z, q.w + wq.w).normalized()
		c.v *= pow(0.8, dt)
		c.w *= pow(0.45, dt)
		if c.x.z < BACK + CR:
			c.x.z = BACK + CR
			if c.v.z < 0.0:
				c.v.z *= -0.2
	var none := {}
	for it in 3:
		for ai in L.size():
			var A: Dictionary = L[ai]
			if A.sleep:
				continue
			for s in samples:
				var wp: Vector3 = (A.q as Quaternion) * (s as Vector3) + A.x
				if wp.y < 0.0:
					contact(A, none, wp, Vector3.UP, -wp.y, 0.2, 0.5)
				for bi in L.size():
					if bi == ai:
						continue
					var B: Dictionary = L[bi]
					if wp.distance_squared_to(B.x) >= PIN_RAD2:
						continue  # outside B's bounding sphere: point_in_pin would return 0
					var dep := point_in_pin(wp, B)
					if dep > 0.0:
						B.sleep = false
						var j := contact(A, B, wp, _nrm, dep, 0.3, 0.3)
						if j > 0.6:
							clack(minf(1.0, j / 4.0), wp)
	for c in L:
		c.mesh.position = c.x
		c.mesh.quaternion = c.q
		# Settled pins go back to sleep.
		if c.v.length_squared() < 0.004 and c.w.length_squared() < 0.01:
			c.calm += dt
		else:
			c.calm = 0.0
		if c.calm > 0.6:
			c.sleep = true
		if not c.down and is_down(c):
			c.down = true
			knocked += 1
			if ctx:
				ctx.add_count.call("bowling", false)
	if not struck and b.shot and pins.all(func(p): return p.down):
		struck = true
		b.scored_t = 0.0
		b.miss_t = 0.0
		b.success()
		if ctx:
			ctx.toast.call(ctx.t("سترايك!" if roll == 0 else "سبير!", "Strike!" if roll == 0 else "Spare!"))
			if roll == 0 and attempt.complete():
				ctx.ch_progress.call("strike1", 1)
