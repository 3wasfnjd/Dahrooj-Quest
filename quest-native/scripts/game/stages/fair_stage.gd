class_name FairStage
extends Node3D
## The fairground stall (src/reference/stages/fair.js): a 60-second round of ducks on a rail
## (1 point), balloons (2) and a bell (5), points doubled for a curved throw, an LED board
## with the time and score, and ducks that fly off tumbling when hit. Game units.

const FZ := -9.5
const CY := 1.05
const ROUND := 60.0
const DUCK_R := 0.22
const SR := 6.8 / 24.0
const BAL := ["6fa8d6", "e2603f", "7bbf8a", "c9a2e6", "f2c14e"]
## stand-in for confetti.celebrate's camera distance (the player's head near the throw spot)
const CAMERA := Vector3(0, 1.6, 0)
const BEST_PATH := "user://dahrooj-fair-best"  # localStorage 'dahrooj-fair-best'
## The canvas is 1024 x 256 drawn on a 2.5 x 0.625 board.
const SIGN_W := 2.5
const SIGN_H := 0.625
const SEGMENTS := [0x3f, 0x06, 0x5b, 0x4f, 0x66, 0x6d, 0x7d, 0x07, 0x7f, 0x6f]
const BARS := [[7, 0, 44, 9], [52, 8, 9, 43], [52, 59, 9, 43], [7, 101, 44, 9], [0, 59, 9, 43], [0, 8, 9, 43], [7, 51, 44, 9]]

## Tests turn this off so they don't write the best score.
static var persist_best := true

var aim_z := FZ
var far_z = FZ - 1.5
var reach_z = -18.5
var friction = null
var shot_time = 4.0
var ctx: GameCtx

var F := {"time": ROUND, "on": false, "score": 0, "best": 0, "swing": 0.0, "bell_hits": 0, "shown_key": "", "over": 0.0, "touched": false}
var ducks: Array = []
var balloons: Array = []
var bell: Node3D
var bell_m: MeshInstance3D
var stall: Array = []
var sign_mesh: MeshInstance3D
var sign_img: Image
var sign_bg: Image
var sign_tex: ImageTexture
var sign_labels := {}
var time := 0.0
var _ball: Ball
var _rng := RandomNumberGenerator.new()


static func mat(c: String, rough := 0.55, metal := 0.0, double := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c)
	m.roughness = rough
	m.metallic = metal
	if double:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _add(m: MeshInstance3D, x: float, y: float, z: float) -> MeshInstance3D:
	m.position = Vector3(x, y, z)
	add_child(m)
	return m


static func _mi(mesh: Mesh, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	return mi


static func _cyl(rt: float, rb: float, h: float, segs: int) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return c


static func _sphere(r: float, w: int, h: int) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = w
	s.rings = h
	return s


## Adds the triangle wound so that its front faces `out` (Godot's front faces wind clockwise).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	var out := na + nb + nc
	if (b - a).cross(c - a).dot(out) > 0.0:
		st.set_normal(na)
		st.add_vertex(a)
		st.set_normal(nc)
		st.add_vertex(c)
		st.set_normal(nb)
		st.add_vertex(b)
	else:
		st.set_normal(na)
		st.add_vertex(a)
		st.set_normal(nb)
		st.add_vertex(b)
		st.set_normal(nc)
		st.add_vertex(c)


## three.js CylinderGeometry(r, r, h, segs, 1, openEnded, t0, tl): the open side wall only.
static func _open_cyl(r: float, h: float, segs: int, t0: float, tl: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in segs:
		var a0 := t0 + tl * k / segs
		var a1 := t0 + tl * (k + 1) / segs
		var n0 := Vector3(sin(a0), 0, cos(a0))
		var n1 := Vector3(sin(a1), 0, cos(a1))
		var p00 := n0 * r + Vector3(0, h / 2, 0)
		var p01 := n0 * r - Vector3(0, h / 2, 0)
		var p10 := n1 * r + Vector3(0, h / 2, 0)
		var p11 := n1 * r - Vector3(0, h / 2, 0)
		_tri(st, p00, p01, p11, n0, n0, n1)
		_tri(st, p00, p11, p10, n0, n1, n1)
	return st.commit()


## three.js CircleGeometry(r, segs, t0, tl): a fan in the xy plane facing +z.
static func _circle(r: float, segs: int, t0: float, tl: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in segs:
		var a0 := t0 + tl * k / segs
		var a1 := t0 + tl * (k + 1) / segs
		_tri(st, Vector3.ZERO, Vector3(cos(a0), sin(a0), 0) * r, Vector3(cos(a1), sin(a1), 0) * r, Vector3.BACK, Vector3.BACK, Vector3.BACK)
	return st.commit()


## three.js SphereGeometry(r, w, h, 0, 2π, 0, tl): a cap from the top down to polar angle tl.
static func _sphere_cap(r: float, w: int, h: int, tl: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pt := func(u: float, v: float) -> Vector3:
		var phi := u * TAU
		var th := v * tl
		return Vector3(-cos(phi) * sin(th), cos(th), sin(phi) * sin(th))
	for j in h:
		for i in w:
			var a: Vector3 = pt.call(float(i) / w, float(j) / h)
			var b: Vector3 = pt.call(float(i + 1) / w, float(j) / h)
			var c: Vector3 = pt.call(float(i + 1) / w, float(j + 1) / h)
			var d: Vector3 = pt.call(float(i) / w, float(j + 1) / h)
			if j > 0:
				_tri(st, a * r, b * r, c * r, a, b, c)
			_tri(st, a * r, c * r, d * r, a, c, d)
	return st.commit()


func _init() -> void:
	_rng.seed = 31
	name = "Fair"
	StageArt.ground_line(self, -14, FZ, 14, FZ)
	var wood := mat("c98f5c", 0.65)
	var wood_dark := mat("9a6a43", 0.7)
	var cream := mat("fffaf2", 0.5)
	var coral := mat("e2603f", 0.55)
	# The stall: back panel, counter, two posts and a striped awning.
	_add(StageArt.rbox(6.4, 2.6, 0.25, 0.08, wood), 0, 1.3 + CY * 0.0, FZ - 1.1)
	_add(StageArt.rbox(6.6, 0.16, 1.0, 0.06, cream), 0, CY, FZ + 0.2)
	_add(StageArt.rbox(6.4, CY - 0.08, 0.9, 0.08, wood_dark), 0, (CY - 0.08) / 2, FZ + 0.2)
	for x in [-3.15, 3.15]:
		_add(_mi(_cyl(0.09, 0.1, 3.2, 16), cream), x, 1.6, FZ + 0.55)
	# The awning: rounded stripes running front to back, sloping down toward you, with a scalloped fringe.
	var awn := Node3D.new()
	awn.position = Vector3(0, 3.3, FZ + 0.05)
	awn.rotation.x = 0.28
	add_child(awn)
	var stripe := _open_cyl(SR, 1.9, 16, PI / 2, PI)
	var coral_d := mat("e2603f", 0.6, 0.0, true)
	var cream_d := mat("fffaf2", 0.6, 0.0, true)
	for i in 12:
		var st := _mi(stripe, cream_d if i % 2 else coral_d)
		st.rotation.x = PI / 2
		st.position = Vector3(-3.4 + SR + i * 2 * SR, 0, 0)
		st.scale = Vector3(1, 1, 0.55)
		awn.add_child(st)
	# The fringe arches the same way as the stripes, a little taller than their rounded ends, in the other colour.
	var scallop := _circle(SR, 16, 0, PI)
	for i in 12:
		var sc := _mi(scallop, coral_d if i % 2 else cream_d)
		sc.position = Vector3(-3.4 + SR + i * 2 * SR, -0.01, 0.955)
		sc.scale = Vector3(1, 0.8, 1)
		awn.add_child(sc)
	# The sign: time left and points, drawn on a board under the awning.
	# It stands on top of the awning, like a fairground crest.
	_add(StageArt.rbox(2.7, 0.76, 0.14, 0.05, mat("243133", 0.85)), 0, 4.05, FZ - 0.35)
	_build_sign()
	# Targets. Ducks run along a rail on the counter, balloons float above them, the bell hangs at the side.
	var duck_mat := mat("f2c14e", 0.4)
	var eye_mat := mat("1b1c26", 0.2)
	var rail := BoxMesh.new()
	rail.size = Vector3(6.2, 0.05, 0.1)
	_add(_mi(rail, mat("b9ad9c", 0.4, 0.4)), 0, CY + 0.1, FZ - 0.05)
	for i in 6:
		var g := _duck(duck_mat, coral, eye_mat)
		g.position = Vector3(0, CY + 0.27, FZ - 0.05)
		add_child(g)
		ducks.append({"g": g, "u": i / 6.0, "down": 0, "down_t": 0.0, "r": 0.26, "fly": null})
	for i in 5:
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color(BAL[i])
		bm.roughness = 0.15
		bm.clearcoat_enabled = true
		bm.clearcoat = 1.0
		var m := _mi(_sphere(0.24, 24, 18), bm)
		m.scale.y = 1.15
		var string := _mi(_cyl(0.006, 0.006, 0.6, 4), cream)
		string.position.y = -0.55
		m.add_child(string)
		add_child(m)
		balloons.append({"m": m, "x": -2.2 + i * 1.1, "y": 2.15 + (i % 2) * 0.25, "pop_t": 0.0, "r": 0.27})
	bell = Node3D.new()
	bell.position = Vector3(2.6, 2.55, FZ - 0.3)
	add_child(bell)
	bell_m = _mi(_sphere_cap(0.26, 24, 16, PI * 0.62), mat("e5ad2e", 0.25, 0.75, true))
	bell_m.position.y = -0.2
	bell.add_child(bell_m)
	var clap := _mi(_sphere(0.06, 12, 10), wood_dark)
	clap.position.y = -0.38
	bell.add_child(clap)
	_add(_mi(_cyl(0.03, 0.03, 0.5, 8), wood_dark), 2.6, 2.8, FZ - 0.3)
	F.best = _load_best()
	# A hit duck flies off its rail, tumbling: it bounces off the stall (back board, counter, posts, awning), the
	# balloons and the ground and rolls to a stop; then it vanishes and a new duck pops up on the rail.
	stall = [
		{"c": Vector3(0, 1.3, FZ - 1.1), "h": Vector3(3.2, 1.3, 0.13)}, {"c": Vector3(0, CY / 2, FZ + 0.2), "h": Vector3(3.3, CY / 2 + 0.08, 0.5)},
		{"c": Vector3(-3.15, 1.6, FZ + 0.55), "h": Vector3(0.1, 1.6, 0.1)}, {"c": Vector3(3.15, 1.6, FZ + 0.55), "h": Vector3(0.1, 1.6, 0.1)},
		{"c": Vector3(0, 3.3, FZ + 0.05), "h": Vector3(3.4, 0.2, 1)}]


static func _duck(duck_mat: Material, beak_mat: Material, eye_mat: Material) -> Node3D:
	var g := Node3D.new()
	g.rotation_order = EULER_ORDER_XYZ  # three.js Euler order: the tumble adds to x, y, z
	var b := _mi(_sphere(0.2, 22, 16), duck_mat)
	b.scale = Vector3(1.25, 0.9, 1)
	g.add_child(b)
	var h := _mi(_sphere(0.13, 18, 14), duck_mat)
	h.position = Vector3(0.15, 0.2, 0)
	g.add_child(h)
	var bk := _mi(_cyl(0.0, 0.05, 0.12, 10), beak_mat)
	bk.rotation.z = -PI / 2
	bk.position = Vector3(0.3, 0.19, 0)
	g.add_child(bk)
	for z in [-0.07, 0.07]:
		var e := _mi(_sphere(0.025, 8, 6), eye_mat)
		e.position = Vector3(0.22, 0.25, z)
		g.add_child(e)
	return g


static func _load_best() -> int:
	if not persist_best or not FileAccess.file_exists(BEST_PATH):
		return 0
	var f := FileAccess.open(BEST_PATH, FileAccess.READ)
	if f == null:
		return 0
	return int(f.get_as_text().to_int())


static func _save_best(v: int) -> void:
	if not persist_best:
		return
	var f := FileAccess.open(BEST_PATH, FileAccess.WRITE)
	if f:
		f.store_string(str(v))


# ---- the LED board ----

func _sign_xy(cx: float, cy: float) -> Vector3:
	return Vector3((cx / 1024.0 - 0.5) * SIGN_W, (0.5 - cy / 256.0) * SIGN_H, 0.002)


func _build_sign() -> void:
	sign_img = Image.create(1024, 256, false, Image.FORMAT_RGBA8)
	# Cached retro LED display: steady light, no flashing scanlines or new textures.
	sign_bg = Image.create(1024, 256, false, Image.FORMAT_RGBA8)
	sign_bg.fill(Color("081816"))
	var dot := Color("112520")
	for y in range(8, 256, 12):
		for x in range(8, 1024, 12):
			sign_bg.fill_rect(Rect2i(x - 1, y - 1, 2, 2), dot)  # arc r 1.1 round (x, y)
	sign_bg.fill_rect(Rect2i(507, 24, 3, 208), Color("486052"))
	sign_tex = ImageTexture.create_from_image(sign_bg)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = sign_tex
	m.disable_fog = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var q := QuadMesh.new()
	q.size = Vector2(SIGN_W, SIGN_H)
	sign_mesh = _mi(q, m)
	sign_mesh.name = "xr-fair-screen"
	sign_mesh.position = Vector3(0, 4.05, FZ - 0.268)
	add_child(sign_mesh)
	# canvas text: '700 31px' headings at y 42, '600 29px' lines at y 229 (alphabetic baselines)
	for k in [["time", 252, 42, 31, "b7dec3"], ["score", 766, 42, 31, "b7dec3"], ["secs", 252, 229, 29, "c9d8b2"], ["best", 766, 229, 29, "c9d8b2"]]:
		var l := Panel3D.label("", k[3], Color(k[4]))
		l.pixel_size = SIGN_W / 1024.0
		l.render_priority = 1
		l.position = _sign_xy(k[1], float(k[2]) - float(k[3]) * 0.35)
		sign_mesh.add_child(l)
		sign_labels[k[0]] = l
	draw_sign()


func _led(value: int, cx: float, color: Color) -> void:
	var text := str(value).lpad(2, "0")
	var scale := minf(1.0, 410.0 / (text.length() * 76))
	var ox := cx - text.length() * 76 * scale / 2
	var off := Color("18312a")
	for i in text.length():
		for j in 7:
			var b: Array = BARS[j]
			var lit: bool = (SEGMENTS[int(text[i])] & (1 << j)) != 0
			var x0: float = ox + (i * 76 + b[0]) * scale
			var y0: float = 67.0 + b[1] * scale
			var x1: float = ox + (i * 76 + b[0] + b[2]) * scale
			var y1: float = 67.0 + (b[1] + b[3]) * scale
			sign_img.fill_rect(Rect2i(roundi(x0), roundi(y0), roundi(x1) - roundi(x0), roundi(y1) - roundi(y0)), color if lit else off)


func draw_sign() -> void:
	var en := ctx != null and ctx.lang == "en"
	var key := "%d|%d|%d|%s|%s" % [ceili(F.time), F.score, F.best, F.on, en]
	if key == F.shown_key:
		return
	F.shown_key = key
	sign_img.copy_from(sign_bg)
	_led(maxi(0, ceili(F.time)), 252, Color("ffcb62"))
	_led(F.score, 766, Color("79f5b3"))
	sign_tex.update(sign_img)
	sign_labels.time.text = "TIME" if en else "الوقت"
	sign_labels.score.text = "SCORE" if en else "النقاط"
	sign_labels.secs.text = ("SECONDS" if en else "ثانية") if F.on else ("THROW TO START" if en else "ارمِ وابدأ")
	sign_labels.best.text = ("BEST %d" % F.best) if en else ("أفضل " + GameCtx.ar_digits(F.best))


# ---- rules ----

func _S() -> Ball:
	if ctx and ctx.ball:
		return ctx.ball
	return _ball


func _sfx(n: String, k: float, p: Vector3) -> void:
	if ctx:
		ctx.sfx.call(n, k, p)


func _toast(ar: String, en: String) -> void:
	if ctx:
		ctx.toast.call(ctx.t(ar, en))


func _ch(id: String, v: int) -> void:
	if ctx:
		ctx.ch_progress.call(id, v)


## confetti.celebrate (celebration.js): one burst at the spot, scaled with distance.
func _celebrate(at: Vector3) -> void:
	if not ctx:
		return
	var p := Vector3(at.x, maxf(0.0, at.y - Ball.BR), at.z)
	ctx.confetti.call(p, 1.6, 1.5, maxf(1.0, p.distance_to(CAMERA) / 7.0))


## The bell's ring: three sine partials fading over 1.2 s.
func ding() -> void:
	_sfx("fair_ding", 1.0, bell.position)


func score(pts: int, curved := false) -> void:
	if not F.on or F.time <= 0.0:
		return
	if curved:
		pts *= 2
	F.score += pts
	if ctx:
		for i in pts:
			ctx.add_count.call("fair", false)
	_ch("fair25", F.score)
	if curved:
		_toast("ملتفة ×٢: +" + GameCtx.ar_digits(pts), "Curved ×2: +%d" % pts)


func _start_round() -> void:
	F.on = true
	F.time = ROUND
	F.score = 0
	if ctx:
		ctx.counts["fair"] = 0
	_ch("fair25", 0)


func launch_duck(d: Dictionary, dir: Vector3, speed: float) -> void:
	d.down = 1
	d.g.visible = true
	var v := dir
	v.y = maxf(0.35, v.y)
	v = v.normalized() * speed
	v.y += 2.5
	v.x += (_rng.randf() - 0.5) * 2
	d.fly = {"v": v, "spin": Vector3((_rng.randf() - 0.5) * 14, (_rng.randf() - 0.5) * 10, (_rng.randf() - 0.5) * 14),
		"t": 0.0, "calm": 0.0, "home": null, "gone": null, "fresh": false, "tap": 0.0}


func step_duck(d: Dictionary, dt: float, rail_x: float) -> void:
	var f: Dictionary = d.fly
	var g: Node3D = d.g
	if f.gone != null:
		# Done: it shrinks away where it lies, then a fresh duck pops up in its place on the rail.
		f.gone += dt
		if f.gone < 0.25:
			g.scale = Vector3.ONE * maxf(0.001, 1.0 - f.gone / 0.25)
			return
		if not f.fresh:
			f.fresh = true
			g.position = Vector3(rail_x, CY + 0.27, FZ - 0.05)
			g.rotation = Vector3.ZERO
		else:
			g.position.x = rail_x
		var k := minf(1.0, (f.gone - 0.25) / 0.35)
		g.scale = Vector3.ONE * maxf(0.001, k * (1.0 + sin(k * PI) * 0.25))
		g.visible = absf(rail_x) < 2.95
		if k >= 1.0:
			d.fly = null
			d.down = 0
			g.scale = Vector3.ONE
		return
	f.t += dt
	f.v.y -= Ball.GRAV * dt
	var fv: Vector3 = f.v
	var p: Vector3 = g.position + fv * dt
	g.rotation.x += f.spin.x * dt
	g.rotation.y += f.spin.y * dt
	g.rotation.z += f.spin.z * dt
	var touched := false
	for b in stall:
		var c: Vector3 = b.c
		var h: Vector3 = b.h
		var lx := p.x - c.x
		var ly := p.y - c.y
		var lz := p.z - c.z
		var ox := h.x + DUCK_R - absf(lx)
		var oy := h.y + DUCK_R - absf(ly)
		var oz := h.z + DUCK_R - absf(lz)
		if ox <= 0.0 or oy <= 0.0 or oz <= 0.0:
			continue
		touched = true
		if ox < oy and ox < oz:
			p.x += signf(lx) * ox
			if f.v.x * signf(lx) < 0.0:
				f.v.x *= -0.5
		elif oy < oz:
			p.y += signf(ly) * oy
			if f.v.y * signf(ly) < 0.0:
				f.v.y *= -0.45
			f.v.x *= 0.85
			f.v.z *= 0.85
		else:
			p.z += signf(lz) * oz
			if f.v.z * signf(lz) < 0.0:
				f.v.z *= -0.5
	for b in balloons:
		if b.pop_t > 0.0:
			continue
		var bp: Vector3 = b.m.position
		var dq := p - bp
		var l := dq.length()
		if l > 0.0 and l < DUCK_R + b.r:
			dq /= l
			p = bp + dq * (DUCK_R + b.r)
			var vn: float = f.v.dot(dq)
			if vn < 0.0:
				f.v += dq * (-1.6 * vn)
			touched = true
	if p.y < DUCK_R:
		p.y = DUCK_R
		if f.v.y < -1.2:
			f.v.y *= -0.4
		else:
			f.v.y = 0.0
		f.v.x *= pow(0.15, dt)
		f.v.z *= pow(0.15, dt)
		f.spin *= pow(0.1, dt)
		touched = true
	g.position = p
	var sp: float = f.v.length()
	if touched and sp > 2.0 and f.t - f.tap > 0.12:
		f.tap = f.t
		_sfx("thump", minf(0.5, sp / 20.0), p)
	f.calm = f.calm + dt if sp < 0.6 else 0.0
	# It flies and rolls until it settles (or a few seconds pass), then it's gone.
	if f.t > 4.0 or f.calm > 0.5 or p.y < -2.0 or absf(p.x) > 14.0:
		f.gone = 0.0


## Ball against a sphere at c (radius r); bounce pushes him out and back (e = 0.5).
func sphere_hit(S: Ball, c: Vector3, r: float, bounce: bool) -> bool:
	var tmp := S.pos - c
	var d := tmp.length()
	if d <= 0.0 or d >= Ball.BR + r:
		return false
	if bounce:
		tmp /= d
		S.pos = c + tmp * (Ball.BR + r)
		var vn := S.vel.dot(tmp)
		if vn < 0.0:
			S.hit(tmp, -vn, c + tmp * r)
			S.vel += tmp * (-1.5 * vn)
	return true


## solid-box.ts collideSolidBox: swept sphere against a simple solid box.
## Returns {hit, p, v, n} (Vectors are values in GDScript).
static func collide_solid_box(p: Vector3, v: Vector3, r: float, previous: Vector3, c: Vector3, h: Vector3) -> Dictionary:
	var lo3 := c - h - Vector3.ONE * r
	var hi3 := c + h + Vector3.ONE * r
	var dd := p - previous
	var enter := 0.0
	var leave := 1.0
	var axis := -1
	var sgn := 0.0
	var none := {"hit": false, "p": p, "v": v, "n": Vector3.ZERO}
	# Scalar slab sweep.
	for a in 3:
		var start: float = previous[a]
		var delta: float = dd[a]
		var lo: float = lo3[a]
		var hi: float = hi3[a]
		if absf(delta) < 1e-9:
			if start < lo or start > hi:
				return none
			continue
		var near := (lo - start) / delta
		var far := (hi - start) / delta
		if near > far:
			var sw := near
			near = far
			far = sw
		if near > enter:
			enter = near
			axis = a
			sgn = -1.0 if delta > 0.0 else 1.0
		leave = minf(leave, far)
		if enter > leave:
			return none
	if axis >= 0:
		p = previous + dd * enter
	else:
		if p.x <= lo3.x or p.x >= hi3.x or p.y <= lo3.y or p.y >= hi3.y or p.z <= lo3.z or p.z >= hi3.z:
			return none
		var l := p - c
		var ox := h.x + r - absf(l.x)
		var oy := h.y + r - absf(l.y)
		var oz := h.z + r - absf(l.z)
		axis = 0 if ox < oy and ox < oz else (1 if oy < oz else 2)
		var la: float = l[axis]
		sgn = 1.0 if la >= 0.0 else -1.0
		var ca: float = c[axis]
		var ha: float = h[axis]
		p[axis] = ca + sgn * (ha + r)
	var n := Vector3.ZERO
	n[axis] = sgn
	p += n * 0.001
	var speed := v.dot(n)
	if speed < 0.0:
		v -= n * speed * 1.5
	return {"hit": true, "p": p, "v": v, "n": n}


## Counter and lower cabinet are solid on every face, with a sweep for hard throws.
## The runtime uses it for a resting thrown ball too. Returns {hit, p, v, n}.
func collide_body(p: Vector3, v: Vector3, r: float, previous: Vector3) -> Dictionary:
	return collide_solid_box(p, v, r, previous, stall[1].c, stall[1].h)


static func _owns(obj: Node, root: Node) -> bool:
	var x := obj
	while x:
		if x == root:
			return true
		x = x.get_parent()
	return false


func shoot(obj: Node, _point: Vector3, dir: Vector3) -> bool:
	if not F.on and F.over <= 0.0:
		_start_round()
	if not F.on:
		return false
	for d in ducks:
		if d.down <= 0 and _owns(obj, d.g):
			launch_duck(d, dir if dir != Vector3.ZERO else Vector3(0, 0, -1), 6.5)
			_sfx("squeak", 1.35, d.g.position)
			score(1)
			return true
	for b in balloons:
		if b.pop_t <= 0.0 and _owns(obj, b.m):
			b.pop_t = 2.2
			_sfx("start_pop", 1.0, b.m.position)
			_celebrate(b.m.position)
			score(2)
			return true
	if _owns(obj, bell) and F.swing < 0.3:
		F.swing = 1.0
		ding()
		F.bell_hits += 1
		_ch("bell3", int(ctx.ch_state.get("bell3", 0)) + 1 if ctx else 1)
		score(5)
		return true
	return false


func ft(sp: float) -> float:
	return maxf(0.5, minf(1.25, 1.35 - sp / 2600.0))


func behind(p: Vector3) -> bool:
	return p.z < FZ - 1.2


func touched() -> bool:
	return F.touched


func on_respawn() -> void:
	F.touched = false


func on_throw() -> void:
	if not F.on and F.over <= 0.0:
		_start_round()


func collide(S: Ball) -> void:
	_ball = S
	if not S.shot:
		return
	var incoming := S.vel.length()
	var res := collide_body(S.pos, S.vel, Ball.BR, S.prev)
	if res.hit:
		S.pos = res.p
		S.vel = res.v
		S.hit(res.n, incoming, S.pos)
		S.side = Vector3.ZERO
	if F.over > 0.0:
		return
	if not F.on and F.over <= 0.0:
		_start_round()
	for d in ducks:
		if d.down > 0:
			continue
		var wp: Vector3 = d.g.position
		wp.y += 0.08
		if sphere_hit(S, wp, d.r, true):
			launch_duck(d, S.vel.normalized(), minf(9.0, S.vel.length() * .55) + 3)
			F.touched = true
			_sfx("squeak", 1.35, wp)
			_sfx("thump", 0.4, wp)
			score(1, S.throw_curve)
	for b in balloons:
		if b.pop_t > 0.0:
			continue
		if sphere_hit(S, b.m.position, b.r, false):
			b.pop_t = 2.2
			F.touched = true
			_sfx("start_pop", 1.0, b.m.position)
			_celebrate(b.m.position)
			score(2, S.throw_curve)
	var bw: Vector3 = bell.transform * bell_m.position
	if F.swing < 0.3 and sphere_hit(S, bw, 0.3, true):
		F.swing = 1.0
		F.touched = true
		ding()
		F.bell_hits += 1
		_ch("bell3", int(ctx.ch_state.get("bell3", 0)) + 1 if ctx else 1)
		score(5, S.throw_curve)
	# The stall: the back panel and the counter bounce him back.
	var P := S.pos
	if P.z - Ball.BR < FZ - 0.97 and P.z > FZ - 1.6 and absf(P.x) < 3.2 and P.y < 2.6:
		S.pos.z = FZ - 0.97 + Ball.BR
		if S.vel.z < 0.0:
			S.hit(Vector3(0, 0, 1), -S.vel.z, Vector3(S.pos.x, S.pos.y, FZ - 0.97))
			S.vel.z = -S.vel.z * 0.5
			S.side = Vector3.ZERO


func update(b: Ball, dt: float) -> void:
	_ball = b
	time += dt
	# The round clock.
	if F.on:
		F.time -= dt
		if F.time <= 0.0:
			F.on = false
			F.time = 0.0
			F.over = 2.5
			var best: bool = F.score > F.best
			if best:
				F.best = F.score
				_save_best(F.best)
			_toast("انتهى الوقت! %s نقطة%s" % [GameCtx.ar_digits(F.score), " · أفضل نتيجة" if best else ""],
				"Time! %d points%s" % [F.score, " — best yet" if best else ""])
			_sfx("chime", 1.0, sign_mesh.position)
	elif F.over > 0.0:
		F.over -= dt
		if F.over <= 0.0:
			F.time = ROUND
	# Ducks glide along the rail and wrap round; a hit one tips back, then pops up again.
	for d in ducks:
		d.u = fmod(d.u + dt * 0.06, 1.0)
		var x: float = -3.0 + d.u * 6.0
		if d.fly != null:
			step_duck(d, dt, x)
			continue
		d.g.position = Vector3(x, CY + 0.27, FZ - 0.05)
		d.g.visible = absf(x) < 2.95
	for i in balloons.size():
		var bl: Dictionary = balloons[i]
		var m: MeshInstance3D = bl.m
		m.position = Vector3(bl.x, bl.y + sin(time * 1.4 + i) * 0.07, FZ - 0.55)
		if bl.pop_t > 0.0:
			bl.pop_t -= dt
			var pt: float = bl.pop_t
			m.scale = Vector3.ONE * (maxf(0.001, (pt - 2.0) * 5.0) if pt > 2.0 else (maxf(0.001, 1.0 - pt / 0.4) if pt < 0.4 else 0.001))
			if pt <= 0.0:
				m.scale = Vector3(1, 1.15, 1)
	F.swing = maxf(0.0, F.swing - dt * 0.6)
	bell.rotation.z = sin(time * 14.0) * 0.35 * F.swing
	draw_sign()


func fair_state() -> Dictionary:
	return {"on": F.on, "time": F.time, "score": F.score, "best": F.best}


func ducks_state() -> Array:
	return ducks.map(func(d): return {"flying": d.fly != null, "gone": d.fly != null and d.fly.gone != null, "p": d.g.position})


func knock_duck(i: int) -> bool:
	if i < 0 or i >= ducks.size():
		return false
	var d: Dictionary = ducks[i]
	if d.fly == null:
		launch_duck(d, Vector3(0.3, 0.2, -1), 7)
		return true
	return false
