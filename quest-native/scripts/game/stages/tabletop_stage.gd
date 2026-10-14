class_name TabletopStage
extends Node3D
## The original wooden tabletop games (src/reference/stages/tabletop.js): balance, ricochet
## and maze. All lettering is on the solid board itself. Unlike the throwing stages a
## tabletop lives in ROOM space at its own unit scale (place_table) and is driven by the
## controllers (xr_press / xr_release / xr_frame), not the thrown ball. Rules and physics:
## TabletopGame (tabletop-games.ts); progression: TabletopProgress.
##
## This node is the web `grp`; `board` tilts under it and carries everything else.
## Board units: the tray is 3.35 x 3.77, the play surface 3 x 3.4, the far end is -z.
##
## Controls (owner's scheme): the GRIP holds and tilts the board (balance, maze). In
## ricochet one paddle is selected (it glows, a gold arrow bobs over it): A picks the next
## one (next_paddle) and the LEFT STICK turns it in 5-degree steps (stick_turn: one step on
## a push, then repeating, faster the further it is pushed); the TRIGGER aims and launches
## Dahrooj. In balance and maze the stage leaves the trigger to the runtime (blaster):
## xr_press returns whether the stage took the press.
##
## Ricochet hearts (TabletopGame.RICOCHET_HEARTS): a row of six glossy hearts stands on top
## of the sign. A launch that misses costs one: it pops, spins and empties with a squeak and
## an "ouch" text where Dahrooj fell; the last one beats faster; out of hearts the round
## starts over with all six (they pop back in one by one, as after a cleared round).

## A round is won: points, result {mode, level, attempts, failures, stars}, and where
## (world position of the ball) for confetti.
signal won(points: int, result: Dictionary, at_world: Vector3)

const R := TabletopGame.TABLE_RADIUS
const TRAY_W := 3.35
const TRAY_D := 3.77
const HEART_SIZE := 1.25  # the ricochet hearts over the sign (about 8 cm each in VR)
const HEART_GAP := 0.36
## Ricochet stick turning: a push past STICK_ON turns one step, held it repeats after
## TURN_FIRST every TURN_SLOW (just past STICK_ON) .. TURN_FAST (all the way); back under
## STICK_OFF it stops.
const STICK_ON := 0.5
const STICK_OFF := 0.3
const TURN_FIRST := 0.34
const TURN_SLOW := 0.16
const TURN_FAST := 0.065

static var _meshes := {}
static var _grain: ImageTexture

## sfx(name, k, pos_world): GameAudio names (whoosh, chime, ...).
var sfx: Callable = func(_n, _k, _p): pass
## The web ctx.tabletopWin(result) (TabletopProgress.record_win by the runtime).
var tabletop_win: Callable = func(_r): pass

var mode := "balance"
var game: TabletopGame
var tilting := true
var wooden := false
var unit := 0.32
var board: Node3D
var pieces: Node3D
var mats := {}
var handles: Array = []
var goal: MeshInstance3D
var stars: Array = []
var mirrors: Array = []
var obstacles: Array = []
var gate_mesh: MeshInstance3D
var dots: Array = []
var floor_mesh: MeshInstance3D
var floor_mat: ShaderMaterial
var sign_box: MeshInstance3D
var sign_lines: Array = []  # 3 Label3D
var maze_walls: MultiMeshInstance3D
var maze_caps: MultiMeshInstance3D
var character: DahroojView
var level_shown := -1
var status_key := ""
var time := 0.0
var grips := {}  # input id -> {q, pos, buttons, tilt} or {q, pos, index, angle}
var aim := Vector2(0, -1)
var trigger = null  # input id holding the trigger (ricochet)
var english := false
## Ricochet: the hearts on the sign (empty elsewhere), each heart's time since it was lost
## (-1: not animating) and since the row refilled.
var hearts: Array = []
var heart_row: Node3D
var heart_lost_t: Array = []
var hearts_refill_t := 99.0
var hearts_shown := -1
## Ricochet: the paddle the stick turns (A: the next one), the stick's held direction
## (-1, 0, 1), the time to its next repeat, the time since the selection changed, and the
## arrow over the selected paddle.
var selected := 0
var turn_dir := 0
var turn_t := 0.0
var select_t := 99.0
var marker: MeshInstance3D


func _init(mode_ := "balance") -> void:
	mode = mode_ if mode_ in ["balance", "ricochet", "maze"] else "balance"
	name = "Tabletop" + mode.capitalize()
	wooden = mode == "ricochet"
	tilting = mode == "balance" or mode == "maze"
	game = TabletopGame.new(mode)
	game.won.connect(_on_won)
	game.heart_lost.connect(_on_heart_lost)
	game.restarted.connect(_on_restarted)
	board = Node3D.new()
	board.name = "Board"
	board.rotation_order = EULER_ORDER_XYZ
	add_child(board)
	pieces = Node3D.new()
	board.add_child(pieces)
	scale = Vector3.ONE * unit
	_build()
	english = not Save.arabic()
	_level_art()
	_status(english)
	character.show_at(Vector3(game.ball.x, R, game.ball.y), null, "focus", false)


# ---------- materials and meshes ----------

## Shared procedural grain: opaque painted wood, no downloaded textures or blended layers.
static func grain() -> ImageTexture:
	if _grain:
		return _grain
	# The canvas (256 x 512, polylines through every 16 px) drawn 4x over and smoothed down.
	const SS := 4
	var img := Image.create(256 * SS, 512 * SS, false, Image.FORMAT_RGB8)
	img.fill(Color("f7e6ca"))
	for k in 28:
		var col := Color("e1c6a3") if k % 3 else Color("c6a27b")
		var lw := (1.5 if k % 3 else 2.8) * SS
		for row in 512 * SS:
			var y := (row + 0.5) / SS
			var y0 := floorf(y / 16.0) * 16.0
			var xa := k * 10 + sin(y0 * 0.018 + k) * 3.0 + sin(y0 * 0.041 + k * 0.7)
			var xb := k * 10 + sin((y0 + 16.0) * 0.018 + k) * 3.0 + sin((y0 + 16.0) * 0.041 + k * 0.7)
			var x := lerpf(xa, xb, (y - y0) / 16.0) * SS
			img.fill_rect(Rect2i(int(roundf(x - lw / 2.0)), row, maxi(1, int(roundf(lw))), 1), col)
	img.resize(256, 512, Image.INTERPOLATE_CUBIC)
	img.generate_mipmaps()
	_grain = ImageTexture.create_from_image(img)
	return _grain


static func timber(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = grain()
	m.roughness = 0.62
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.resource_name = "tabletop-wood"
	return m


static func plain(color: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


## A triangle builder that keeps Godot's (clockwise) front faces whatever order it is given.
class MB:
	var st := SurfaceTool.new()

	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	func tri(a: Vector3, b: Vector3, c: Vector3, n: Vector3, ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO, na := Vector3.ZERO, nb := Vector3.ZERO, nc := Vector3.ZERO) -> void:
		if na == Vector3.ZERO:
			na = n
			nb = n
			nc = n
		if (b - a).cross(c - a).dot(n) > 0.0:
			_v(a, na, ua)
			_v(c, nc, uc)
			_v(b, nb, ub)
		else:
			_v(a, na, ua)
			_v(b, nb, ub)
			_v(c, nc, uc)

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO, ud := Vector2.ZERO) -> void:
		tri(a, b, c, n, ua, ub, uc)
		tri(a, c, d, n, ua, uc, ud)

	func _v(p: Vector3, n: Vector3, uv: Vector2) -> void:
		st.set_normal(n)
		st.set_uv(uv)
		st.add_vertex(p)

	func commit(into: ArrayMesh = null) -> ArrayMesh:
		var m := st.commit(into)
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		return m


## three.js BoxGeometry: each face mapped 0..1 (texture top = face top / far side).
## split_front: +z on its own (second) surface, as the sign's material array does.
static func box_mesh(w: float, h: float, d: float, split_front := false) -> ArrayMesh:
	var key := "box_%f_%f_%f_%s" % [w, h, d, split_front]
	if _meshes.has(key):
		return _meshes[key]
	var hs := Vector3(w, h, d) / 2.0
	# normal, u axis, "down the texture" axis
	var faces := [
		[Vector3.RIGHT, Vector3.FORWARD, Vector3.DOWN], [Vector3.LEFT, Vector3.BACK, Vector3.DOWN],
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK], [Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.BACK, Vector3.RIGHT, Vector3.DOWN], [Vector3.FORWARD, Vector3.LEFT, Vector3.DOWN],
	]
	var mb := MB.new()
	var mesh: ArrayMesh = null
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		if split_front and n == Vector3.BACK:
			continue
		_box_face(mb, hs, n, u, v)
	mesh = mb.commit()
	if split_front:
		_box_face(mb, hs, Vector3.BACK, Vector3.RIGHT, Vector3.DOWN)
		mesh = mb.commit(mesh)
	_meshes[key] = mesh
	return mesh


static func _box_face(mb: MB, hs: Vector3, n: Vector3, u: Vector3, v: Vector3) -> void:
	var c := n * hs
	var hu := (u.abs() * hs).length()
	var hv := (v.abs() * hs).length()
	var p := func(a: float, b: float) -> Vector3: return c + u * a * hu + v * b * hv
	mb.quad(p.call(-1, -1), p.call(1, -1), p.call(1, 1), p.call(-1, 1), n, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))


## One continuous frame per layer: a rounded outline (x, z), 8 segments a corner.
static func outline(w: float, d: float, r: float) -> PackedVector2Array:
	var x := w / 2.0
	var z := d / 2.0
	var pts := PackedVector2Array()
	var corners := [[Vector2(x - r, -z + r), -PI / 2], [Vector2(x - r, z - r), 0.0], [Vector2(-x + r, z - r), PI / 2], [Vector2(-x + r, -z + r), PI]]
	for c in corners:
		for i in 9:
			var a: float = c[1] + PI / 2 * i / 8.0
			pts.append(c[0] + Vector2(cos(a), sin(a)) * r)
	return pts


## A tray layer extruded from y = 0 to height (three ExtrudeGeometry, flat side normals,
## its UVs remapped as tabletop.js does: top by x/z, sides by z or x and height).
static func tray_mesh(height: float, hollow: bool) -> ArrayMesh:
	var key := "tray_%f_%s" % [height, hollow]
	if _meshes.has(key):
		return _meshes[key]
	var o := outline(TRAY_W, TRAY_D, 0.12)
	var inner := outline(3.04, 3.48, 0.03)
	var mb := MB.new()
	var top_uv := func(p: Vector2) -> Vector2: return Vector2(p.x / TRAY_W + 0.5, 1.0 - (p.y / TRAY_D + 0.5))
	var n := o.size()
	for y in [0.0, height]:
		var up := Vector3.UP if y > 0.0 else Vector3.DOWN
		for i in n:
			var a := o[i]
			var b := o[(i + 1) % n]
			if hollow:
				var ia := inner[i]
				var ib := inner[(i + 1) % n]
				mb.quad(Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(ib.x, y, ib.y), Vector3(ia.x, y, ia.y), up,
					top_uv.call(a), top_uv.call(b), top_uv.call(ib), top_uv.call(ia))
			else:
				mb.tri(Vector3(0, y, 0), Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), up, top_uv.call(Vector2.ZERO), top_uv.call(a), top_uv.call(b))
	var rings := [[o, 1.0]]
	if hollow:
		rings.append([inner, -1.0])
	for ring in rings:
		var pts: PackedVector2Array = ring[0]
		for i in n:
			var a := pts[i]
			var b := pts[(i + 1) % n]
			if a.distance_to(b) < 1e-6:
				continue
			var e := b - a
			var nn := Vector3(e.y, 0, -e.x).normalized()
			var mid := (a + b) / 2.0
			if Vector2(nn.x, nn.z).dot(mid) * ring[1] < 0.0:
				nn = -nn
			var side := absf(nn.x) > 0.5
			var uvf := func(p: Vector2, yy: float) -> Vector2:
				return Vector2((p.y / TRAY_D + 0.5) if side else (p.x / TRAY_W + 0.5), 1.0 - yy / height)
			mb.quad(Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y), Vector3(b.x, height, b.y), Vector3(a.x, height, a.y), nn,
				uvf.call(a, 0.0), uvf.call(b, 0.0), uvf.call(b, height), uvf.call(a, height))
	var mesh := mb.commit()
	_meshes[key] = mesh
	return mesh


## three.js TorusGeometry(radius, tube, radial, tubular, arc) in the XY plane.
static func torus_mesh(radius: float, tube: float, radial: int, tubular: int, arc: float) -> ArrayMesh:
	var key := "torus_%f_%f_%d_%d_%f" % [radius, tube, radial, tubular, arc]
	if _meshes.has(key):
		return _meshes[key]
	var mb := MB.new()
	var pt := func(i: int, j: int) -> Array:
		var u := float(i) / tubular * arc
		var v := float(j) / radial * TAU
		var centre := Vector3(radius * cos(u), radius * sin(u), 0)
		var p := Vector3((radius + tube * cos(v)) * cos(u), (radius + tube * cos(v)) * sin(u), tube * sin(v))
		return [p, (p - centre).normalized(), Vector2(float(i) / tubular, float(j) / radial)]
	for j in radial:
		for i in tubular:
			var a: Array = pt.call(i, j)
			var b: Array = pt.call(i + 1, j)
			var c: Array = pt.call(i + 1, j + 1)
			var d: Array = pt.call(i, j + 1)
			var n: Vector3 = (a[1] + b[1] + c[1] + d[1])
			mb.tri(a[0], b[0], c[0], n, a[2], b[2], c[2], a[1], b[1], c[1])
			mb.tri(a[0], c[0], d[0], n, a[2], c[2], d[2], a[1], c[1], d[1])
	var mesh := mb.commit()
	_meshes[key] = mesh
	return mesh


## The extruded five-point star (depth .035, bevel .014 / .012), lying flat, thickness up.
static func star_mesh() -> ArrayMesh:
	if _meshes.has("star"):
		return _meshes.star
	var base := PackedVector2Array()
	for k in 10:
		var a := k * PI / 5.0 + PI / 2.0
		var r := 0.065 if k % 2 else 0.14
		base.append(Vector2(cos(a) * r, -sin(a) * r))  # shape y -> board -z
	var grown := PackedVector2Array()
	for i in 10:
		var prev := base[(i + 9) % 10]
		var cur := base[i]
		var nxt := base[(i + 1) % 10]
		var n1 := (cur - prev).orthogonal().normalized()
		var n2 := (nxt - cur).orthogonal().normalized()
		if n1.dot(cur) < 0.0:
			n1 = -n1
			n2 = -n2
		var bis := (n1 + n2).normalized()
		grown.append(cur + bis * 0.012 / maxf(bis.dot(n1), 0.2))
	var layers := [[base, -0.014], [grown, 0.0], [grown, 0.035], [base, 0.049]]
	var mb := MB.new()
	for cap in [[base, -0.014, Vector3.DOWN], [base, 0.049, Vector3.UP]]:
		var pts: PackedVector2Array = cap[0]
		for i in 10:
			var a := pts[i]
			var b := pts[(i + 1) % 10]
			mb.tri(Vector3(0, cap[1], 0), Vector3(a.x, cap[1], a.y), Vector3(b.x, cap[1], b.y), cap[2])
	for l in 3:
		var p0: PackedVector2Array = layers[l][0]
		var p1: PackedVector2Array = layers[l + 1][0]
		var y0: float = layers[l][1]
		var y1: float = layers[l + 1][1]
		for i in 10:
			var a0 := Vector3(p0[i].x, y0, p0[i].y)
			var b0 := Vector3(p0[(i + 1) % 10].x, y0, p0[(i + 1) % 10].y)
			var a1 := Vector3(p1[i].x, y1, p1[i].y)
			var b1 := Vector3(p1[(i + 1) % 10].x, y1, p1[(i + 1) % 10].y)
			var mid := (a0 + b0 + a1 + b1) / 4.0
			var n := (b0 - a0).cross(a1 - a0).normalized()
			if n.dot(Vector3(mid.x, 0, mid.z)) < 0.0:
				n = -n
			mb.quad(a0, b0, b1, a1, n)
	var mesh := mb.commit()
	_meshes.star = mesh
	return mesh


## An extruded, bevelled heart standing up (x across, y up, thickness along z), about
## .22 wide and .2 tall with its tip at y -.1.
static func heart_mesh() -> ArrayMesh:
	if _meshes.has("heart"):
		return _meshes.heart
	var n := 48
	var base := PackedVector2Array()
	for k in n:
		var t := TAU * k / n
		var x := 16.0 * pow(sin(t), 3)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		base.append(Vector2(x, y + 2.5) * 0.0068)
	var inner := PackedVector2Array()
	for q in base:
		inner.append(q * 0.9)
	var tris := Geometry2D.triangulate_polygon(inner)
	var mb := MB.new()
	var d := 0.04
	var b := 0.016
	for side: float in [1.0, -1.0]:
		var nn := Vector3(0, 0, side)
		for i in range(0, tris.size(), 3):
			var a := inner[tris[i]]
			var c := inner[tris[i + 1]]
			var e := inner[tris[i + 2]]
			var va := Vector3(a.x, a.y, side * d)
			var vc := Vector3(c.x, c.y, side * d)
			var ve := Vector3(e.x, e.y, side * d)
			if (vc - va).cross(ve - va).dot(nn) < 0.0:
				mb.tri(va, ve, vc, nn)
			else:
				mb.tri(va, vc, ve, nn)
	# The bevelled rim: inner face edge -> outline at the middle -> the other face.
	var rings := [[inner, d], [base, d - b], [base, -(d - b)], [inner, -d]]
	for l in 3:
		var p0: PackedVector2Array = rings[l][0]
		var p1: PackedVector2Array = rings[l + 1][0]
		var z0: float = rings[l][1]
		var z1: float = rings[l + 1][1]
		for i in n:
			var j := (i + 1) % n
			var a0 := Vector3(p0[i].x, p0[i].y, z0)
			var b0 := Vector3(p0[j].x, p0[j].y, z0)
			var a1 := Vector3(p1[i].x, p1[i].y, z1)
			var b1 := Vector3(p1[j].x, p1[j].y, z1)
			var out := Vector3((p1[i] + p1[j]).x, (p1[i] + p1[j]).y, 0.0) * 0.5
			var nm := (b0 - a0).cross(a1 - a0).normalized()
			if nm.dot(out + Vector3(0, 0, (z0 + z1) * 0.5)) < 0.0:
				nm = -nm
				mb.quad(a0, a1, b1, b0, nm)
			else:
				mb.quad(a0, b0, b1, a1, nm)
	var mesh := mb.commit()
	_meshes.heart = mesh
	return mesh


static func cylinder_mesh(r: float, h: float, segs: int) -> CylinderMesh:
	var key := "cyl_%f_%f_%d" % [r, h, segs]
	if not _meshes.has(key):
		var c := CylinderMesh.new()
		c.top_radius = r
		c.bottom_radius = r
		c.height = h
		c.radial_segments = segs
		c.rings = 1
		_meshes[key] = c
	return _meshes[key]


static func floor_shader(cutout: bool) -> Shader:
	var key := "floor_%s" % cutout
	if _meshes.has(key):
		return _meshes[key]
	var code := """
shader_type spatial;
render_mode cull_disabled;
uniform int kind = 0;
uniform vec4 path[8];
uniform int path_n = 0;
uniform float width = 0.3;
uniform vec4 holes[2];
uniform int holes_n = 0;
uniform vec2 start_p;
uniform vec3 start_col : source_color;
varying vec2 bp;
vec3 lin(vec3 c) { c /= 255.0; return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
float cover(float d) { return clamp(0.5 - d / max(fwidth(d), 1e-5), 0.0, 1.0); }
void vertex() { bp = VERTEX.xz; }
void fragment() {
	vec3 col;
	float alpha = 1.0;
	if (kind == 0) {
		float dmin = 1e9; float s_at = 0.0; float acc = 0.0;
		for (int i = 1; i < 8; i++) {
			if (i >= path_n) break;
			vec2 a = path[i - 1].xy; vec2 ab = path[i].xy - a; float l = length(ab);
			float t = clamp(dot(bp - a, ab) / max(l * l, 1e-6), 0.0, 1.0);
			float d = length(bp - a - ab * t);
			if (d < dmin) { dmin = d; s_at = acc + t * l; }
			acc += l;
		}
		alpha = cover(dmin - width);
		col = lin(vec3(250.0, 237.0, 201.0));
		float ph = mod(s_at, 0.12);
		float off = ph > 0.06 ? min(ph - 0.06, 0.12 - ph) : 0.0;
		col = mix(col, lin(vec3(213.0, 178.0, 133.0)), cover(length(vec2(off, dmin)) - 0.014));
		for (int h = 0; h < 2; h++) {
			if (h >= holes_n) break;
			alpha *= 1.0 - cover(length(bp - holes[h].xy) - holes[h].z);
		}
	} else {
		col = lin(vec3(212.0, 161.0, 107.0));
		float px = bp.x + 1.5;
		int i = int(floor(px / 0.5));
		float lx = px - float(i) * 0.5;
		if (i >= 0 && i < 6 && lx < 0.496) {
			col = (i % 2 == 1) ? lin(vec3(198.0, 152.0, 101.0)) : lin(vec3(215.0, 175.0, 123.0));
			for (int k = 0; k < 7; k++) {
				float xx = -1.5 + float(i) * 0.5 + 0.035 + float(k) * 0.066 + sin(bp.y * 6.0 + float(i + k)) * 0.008;
				vec3 g = (k % 2 == 1) ? lin(vec3(185.0, 140.0, 91.0)) : lin(vec3(225.0, 188.0, 142.0));
				col = mix(col, g, cover(abs(bp.x - xx) - 0.0045));
			}
		}
		float e = max(abs(bp.x) - 1.43, abs(bp.y) - 1.63);
		col = mix(col, lin(vec3(245.0, 219.0, 169.0)), cover(abs(e) - 0.0175));
	}
	float sc = cover(length(bp - start_p) - 0.23);
	col = mix(col, start_col, sc);
	alpha = max(alpha, sc);
	ALBEDO = col;
	ROUGHNESS = 0.9;
	METALLIC = 0.0;
"""
	if cutout:
		code += "\tALPHA = alpha;\n\tALPHA_SCISSOR_THRESHOLD = 0.5;\n"
	code += "}\n"
	var sh := Shader.new()
	sh.code = code
	_meshes[key] = sh
	return sh


# ---------- the board ----------

func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	return m


func _box(parent: Node3D, w: float, h: float, d: float, x: float, y: float, z: float, mat: Material) -> MeshInstance3D:
	return _mesh(parent, box_mesh(w, h, d), mat, Vector3(x, y, z))


func _tray(nm: String, bottom: float, height: float, mat: Material, hollow := false) -> void:
	var m := _mesh(board, tray_mesh(height, hollow), mat, Vector3(0, bottom, 0))
	m.name = "tabletop-tray-" + nm


func _build() -> void:
	mats.wood = timber(Color("b98656"))
	mats.cream = timber(Color("f5dbab"))
	mats.walnut = timber(Color("835134"))
	mats.honey = timber(Color("dca557"))
	mats.gold = plain(Color("f6ca56"), 0.4)
	mats.mint = plain(Color("77b7a4"), 0.7)
	mats.violet = plain(Color("b29bd8"), 0.7)
	mats.dark = plain(Color("694b40"), 0.85)
	_tray("base", -0.43, 0.16, mats.walnut)
	_tray("liner", -0.27, 0.045, mats.honey)
	_tray("frame", -0.225, 0.25, mats.wood, true)
	_tray("trim", 0.025, 0.026, mats.cream, true)
	for s in [-1, 1]:
		var h := _mesh(board, torus_mesh(0.22, 0.055, 8, 24, PI), mats.cream, Vector3(s * 1.64, -0.14, 0.9))
		h.basis = Basis(Vector3.RIGHT, -PI / 2) * Basis(Vector3.BACK, PI / 2 if s < 0 else -PI / 2)
		h.name = "balance-handle-%d" % s
		handles.append(h)
	# A single cutout surface for the bridges, with a recessed tray below it.
	var plane := PlaneMesh.new()
	plane.size = Vector2(3, 3.4)
	floor_mat = ShaderMaterial.new()
	floor_mat.shader = floor_shader(mode == "balance")
	floor_mat.set_shader_parameter("kind", 0 if mode == "balance" else 1)
	floor_mat.set_shader_parameter("start_col", Color("f2d195") if wooden else Color("c5dbad"))
	floor_mesh = _mesh(board, plane, floor_mat)
	floor_mesh.name = "tabletop-floor"
	# The instructions on the far side: wood all round, the painted sign at the front.
	var sign_mat := StandardMaterial3D.new()
	sign_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sign_mat.albedo_color = Color("815635")
	sign_box = MeshInstance3D.new()
	sign_box.mesh = box_mesh(3.04, 0.75, 0.12, true)
	sign_box.set_surface_override_material(0, mats.wood)
	sign_box.set_surface_override_material(1, sign_mat)
	sign_box.position = Vector3(0, 0.426, -1.81)
	sign_box.name = "tabletop-instructions"
	board.add_child(sign_box)
	var px := 3.04 / 1536.0  # the sign's canvas: 1536 x 352 px over 3.04 x .75
	var panel_mat := StandardMaterial3D.new()
	panel_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	panel_mat.albedo_color = Color("d7ae7b") if wooden else Color("fff6df")
	var panel := QuadMesh.new()
	panel.size = Vector2(1504, 320) * px
	_mesh(sign_box, panel, panel_mat, Vector3(0, 0, 0.0605))
	var font := Glass.font(500)
	for i in 3:
		var l := Label3D.new()
		l.font = font
		l.pixel_size = px
		l.font_size = [64, 44, 43][i]
		l.outline_size = 0
		l.modulate = Color("62825c") if i == 2 else Color("59402f")
		l.double_sided = false
		l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		# Canvas baselines at 101, 187 and 274 px of 352 (top at +.375).
		l.position = Vector3(0, 0.375 - [101, 187, 274][i] * 0.75 / 352.0 - l.font_size * 0.22 * px, 0.062)
		l.render_priority = 1
		sign_box.add_child(l)
		sign_lines.append(l)
	var goal_mesh: Mesh
	if mode == "maze":
		goal_mesh = cylinder_mesh(0.21, 0.026, 36)
	else:
		var t := TorusMesh.new()
		t.inner_radius = 0.24 - 0.038
		t.outer_radius = 0.24 + 0.038
		t.rings = 36
		t.ring_segments = 10
		goal_mesh = t
	goal = _mesh(pieces, goal_mesh, mats.honey if wooden else mats.mint, Vector3(0, 0.065, 0))
	# Shared boxes keep every maze divider and its cap in just two draw calls.
	if mode == "maze":
		var count := 0
		for l in TabletopGame.maze_levels():
			count = maxi(count, l.walls.size())
		maze_walls = _multi(mats.wood, count)
		maze_walls.name = "maze-walls"
		maze_caps = _multi(mats.cream, count)
		maze_caps.name = "maze-wall-caps"
	for i in 3:
		stars.append(_mesh(pieces, star_mesh(), mats.gold))
	for i in 4:
		var m := _box(pieces, 0.91, 0.32, 0.09, 0, 0.16, 0, mats.walnut if i % 2 else mats.wood)
		m.name = "ricochet-paddle-%d" % i
		# Inlaid maple strips, end grain caps and a wooden pivot make each rotating paddle legible.
		_box(m, 0.91, 0.026, 0.108, 0, 0.148, 0, mats.honey)
		_box(m, 0.87, 0.024, 0.104, 0, -0.136, 0, mats.cream)
		for side in [-1, 1]:
			_box(m, 0.035, 0.29, 0.113, side * 0.432, 0, 0, mats.cream)
		_mesh(m, cylinder_mesh(0.07, 0.038, 16), mats.honey, Vector3(0, 0.179, 0))
		_box(m, 0.08, 0.012, 0.016, 0, 0.204, 0, mats.walnut)
		mirrors.append(m)
	for i in 2:
		var b := _box(pieces, 1, 0.35, 1, 0, 0.175, 0, mats.walnut)
		b.name = "ricochet-obstacle-%d" % i
		_box(b, 0.94, 0.045, 0.94, 0, 0.183, 0, mats.wood)
		obstacles.append(b)
	gate_mesh = _box(pieces, 0.16, 0.27, 0.42, 0, 0.135, 0, mats.violet)
	var dot := SphereMesh.new()
	dot.radius = 0.025
	dot.height = 0.05
	dot.radial_segments = 8
	dot.rings = 6
	for i in 12:
		dots.append(_mesh(pieces, dot, mats.honey if wooden else mats.gold))
	character = DahroojView.new(R)
	character.name = "Dahrooj"
	board.add_child(character)
	if mode == "ricochet":
		_build_marker()
	if game.max_hearts > 0:
		_build_hearts()


## Ricochet: the selected paddle glows warm gold and a gold arrow bobs over it.
func _build_marker() -> void:
	var sel := timber(Color("ffd27a"))
	sel.emission_enabled = true
	sel.emission = Color("ffb52e")
	sel.emission_energy_multiplier = 0.55
	sel.rim_enabled = true
	sel.rim = 0.7
	mats.selected = sel
	var gold := plain(Color("ffcf3f"), 0.3)
	gold.emission_enabled = true
	gold.emission = Color("ffb000")
	gold.emission_energy_multiplier = 0.9
	mats.marker = gold
	var cone := CylinderMesh.new()
	cone.top_radius = 0.13
	cone.bottom_radius = 0.0
	cone.height = 0.26
	cone.radial_segments = 4
	cone.rings = 1
	marker = _mesh(pieces, cone, gold)
	marker.name = "ricochet-selected-arrow"
	marker.visible = false


## Ricochet: the hearts stand in a row on top of the sign (coral and glossy while you have
## them, a dark walnut inlay once lost).
func _build_hearts() -> void:
	mats.heart = plain(Color("ff5a6e"), 0.22)
	(mats.heart as StandardMaterial3D).rim_enabled = true
	(mats.heart as StandardMaterial3D).rim = 0.6
	(mats.heart as StandardMaterial3D).emission_enabled = true
	(mats.heart as StandardMaterial3D).emission = Color("ff2d55")
	(mats.heart as StandardMaterial3D).emission_energy_multiplier = 0.18
	mats.heart_empty = plain(Color("5b4034"), 0.8)
	heart_row = Node3D.new()
	heart_row.name = "ricochet-hearts"
	heart_row.position = Vector3(0, 0.426 + 0.375 + 0.17, -1.81)
	board.add_child(heart_row)
	var n := game.max_hearts
	for i in n:
		var h := _mesh(heart_row, heart_mesh(), mats.heart, Vector3((i - (n - 1) / 2.0) * HEART_GAP, 0, 0))
		h.name = "heart-%d" % i
		hearts.append(h)
		heart_lost_t.append(-1.0)
	hearts_shown = game.hearts


func _multi(mat: Material, count: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box_mesh(1, 1, 1)
	mm.instance_count = count
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	pieces.add_child(mi)
	return mi


func _level_art() -> void:
	if level_shown == game.level:
		return
	level_shown = game.level
	var l := game.definition()
	# The painted floor.
	var start := game.start_point()
	floor_mat.set_shader_parameter("start_p", start)
	if mode == "balance":
		var path := PackedVector4Array()
		for q: Vector2 in l.path:
			path.append(Vector4(q.x, q.y, 0, 0))
		while path.size() < 8:
			path.append(Vector4.ZERO)
		floor_mat.set_shader_parameter("path", path)
		floor_mat.set_shader_parameter("path_n", l.path.size())
		floor_mat.set_shader_parameter("width", l.width)
		var hs := PackedVector4Array()
		for h in l.holes:
			hs.append(Vector4(h.p.x, h.p.y, h.r, 0))
		while hs.size() < 2:
			hs.append(Vector4(99, 99, 0, 0))
		floor_mat.set_shader_parameter("holes", hs)
		floor_mat.set_shader_parameter("holes_n", l.holes.size())
	var end := game.end_point()
	goal.position = Vector3(end.x, 0.065, end.y)
	if maze_walls:
		var walls: Array = l.walls
		maze_walls.multimesh.visible_instance_count = walls.size()
		maze_caps.multimesh.visible_instance_count = walls.size()
		for i in walls.size():
			var w: Dictionary = walls[i]
			maze_walls.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(w.hx * 2, TabletopGame.MAZE_WALL_HEIGHT, w.hz * 2)), Vector3(w.x, TabletopGame.MAZE_WALL_HEIGHT / 2, w.z)))
			maze_caps.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(w.hx * 2, 0.024, w.hz * 2)), Vector3(w.x, TabletopGame.MAZE_WALL_HEIGHT + 0.012, w.z)))
	for i in stars.size():
		stars[i].visible = tilting
		if tilting:
			stars[i].position = Vector3(l.stars[i].x, 0.13, l.stars[i].y)
	for i in mirrors.size():
		var m: MeshInstance3D = mirrors[i]
		m.visible = mode == "ricochet" and i < l.mirrors.size()
		if m.visible:
			var d: Dictionary = l.mirrors[i]
			m.position = Vector3(d.x, 0.16, d.z)
			m.scale.x = d.length / 0.91
	for i in obstacles.size():
		var m: MeshInstance3D = obstacles[i]
		m.visible = mode == "ricochet" and i < l.obstacles.size()
		if m.visible:
			var b: Dictionary = l.obstacles[i]
			m.scale = Vector3(b.hx * 2, 1, b.hz * 2)
			m.position = Vector3(b.x, 0.175, b.z)
	gate_mesh.visible = tilting and l.has("gate")


func _tr(ar: String, en: String) -> String:
	return en if english else ar


func _status(en: bool) -> void:
	english = en
	var key := "%s|%d|%s|%d|%d|%d|%d|%s|%d" % [en, game.level, game.phase, game.stars.size(), game.bounces.size(), game.attempts, game.score, grips.size() > 0, game.hearts]
	if key == status_key:
		return
	status_key = key
	var pair := func(a, b) -> String: return "\u2066%s / %s\u2069" % [a, b]
	var title := _tr("التوازن" if mode == "balance" else ("الارتداد" if mode == "ricochet" else "المتاهة"), mode.capitalize()) \
		+ " · " + _tr("المرحلة %s" % pair.call(game.level + 1, game.level_count), "Round %d / %d" % [game.level + 1, game.level_count])
	var hint: String
	if game.phase == "won":
		hint = _tr("أحسنت! المرحلة التالية…", "Nice! Next round…")
	elif game.phase == "falling" and game.max_hearts > 0:
		if game.hearts > 0:
			hint = _tr("راح قلب! باقي %s" % GameCtx.ar_digits(game.hearts), "Lost a heart! %d left" % game.hearts)
		else:
			hint = _tr("نفدت القلوب! نعيد المرحلة بست قلوب", "Out of hearts! The round starts over with six")
	elif game.phase == "falling":
		hint = _tr("جرّب مرة ثانية", "Try again")
	elif mode == "balance":
		hint = _tr("امسك بالقبضة وأمل اللوح · اجمع النجوم", "Hold grip and tilt the board · collect the stars")
	elif mode == "ricochet":
		hint = _tr("القير الأيسر: تدوير اللوح · A: اللوح التالي · الزناد: وجّه وأطلق", "Left stick: turn the paddle · A: next paddle · Trigger: aim, release")
	else:
		hint = _tr("امسك بالقبضة وأمل اللوح · اجمع النجوم ثم اتجه للهدف", "Hold grip and tilt · collect the stars, then reach the goal")
	var info: String
	if tilting:
		info = _tr("النجوم %s · النقاط %d" % [pair.call(game.stars.size(), 3), game.score], "Stars %d / 3 · Score %d" % [game.stars.size(), game.score])
	else:
		var req: int = game.definition().required
		info = _tr("ألواح %s · محاولات %d · النقاط %d" % [pair.call(game.bounces.size(), req), game.attempts, game.score],
			"Paddles %d / %d · Throws %d · Score %d" % [game.bounces.size(), req, game.attempts, game.score])
	var dir := TextServer.DIRECTION_LTR if en else TextServer.DIRECTION_RTL
	var texts := [title, hint, info]
	for i in 3:
		var l: Label3D = sign_lines[i]
		l.text = texts[i]
		l.text_direction = dir
		# fillText's maxWidth (1430 px) squeezes a long line.
		var w := l.font.get_string_size(texts[i], HORIZONTAL_ALIGNMENT_LEFT, -1, l.font_size, TextServer.JUSTIFICATION_NONE, dir).x
		l.scale.x = 1430.0 / w if w > 1430.0 else 1.0


# ---------- room placement and inputs ----------

## spot_world: the table spot (origin on the board's surface plane, -Z away from the
## player, +Y up) in world space; unit: metres per board unit (VR .32; MR
## clamp(3.2 / arScale, .1, .44)).
func place_table(spot_world: Transform3D, unit_: float) -> void:
	unit = unit_
	var xf := Transform3D(spot_world.basis.orthonormalized().scaled(Vector3.ONE * unit), spot_world.origin)
	if is_inside_tree():
		global_transform = xf
	else:
		transform = xf


func _grp_xf() -> Transform3D:
	return global_transform if is_inside_tree() else transform


func _board_xf() -> Transform3D:
	return _grp_xf() * board.transform


func _local_input(input: Dictionary) -> Dictionary:
	var g := _grp_xf()
	var rot: Quaternion = input.get("rotation", Quaternion.IDENTITY)
	return {"q": g.basis.get_rotation_quaternion().inverse() * rot, "pos": g.affine_inverse() * (input.get("position", Vector3.ZERO) as Vector3)}


func _ray_of(input: Dictionary, xf: Transform3D) -> Array:
	var ray: Dictionary = input.get("ray", {})
	var inv := xf.affine_inverse()
	return [inv * (ray.get("origin", Vector3.ZERO) as Vector3), inv.basis * (ray.get("dir", Vector3.FORWARD) as Vector3)]


func _aim_at(input: Dictionary) -> void:
	var r := _ray_of(input, _board_xf())
	var o: Vector3 = r[0]
	var d: Vector3 = (r[1] as Vector3).normalized()
	if d.y >= -0.01:
		return
	var t := (R - o.y) / d.y
	if t <= 0.0:
		return
	var x := o.x + d.x * t - game.ball.x
	var z := o.z + d.z * t - game.ball.y
	var dd := Vector2(x, z).length()
	if dd > 0.08:
		aim = Vector2(x / dd, z / dd)


static func _id(input):
	return input.get("id") if input is Dictionary else input


## A controller button went down: how = "trigger" | "grip". True when the stage took it.
func xr_press(input: Dictionary, how: String) -> bool:
	var id = input.get("id")
	if tilting:
		if how != "grip":
			return false
		if not grips.has(id):
			var local := _local_input(input)
			grips[id] = {"q": local.q, "pos": local.pos, "buttons": {how: true}, "tilt": game.tilt}
		else:
			grips[id].buttons[how] = true
		return true
	if how == "grip":
		return false  # ricochet: the paddles turn with the left stick (A picks one)
	if trigger == null and game.phase == "ready" and grips.is_empty():
		trigger = id
		_aim_at(input)
		return true
	return false


## A button came up (or the input was lost): input is the input Dictionary or its id.
func xr_release(input, lost := false, how := "") -> void:
	var id = _id(input)
	if tilting:
		var grip = grips.get(id)
		if grip != null and how != "" and not lost:
			grip.buttons.erase(how)
			if grip.buttons.is_empty():
				grips.erase(id)
		else:
			grips.erase(id)
		if grips.is_empty():
			game.set_tilt(0, 0)
	else:
		if lost or how == "" or how == "grip":
			grips.erase(id)
		if trigger != null and trigger == id and (lost or how == "" or how == "trigger"):
			trigger = null
			if not lost and game.launch(aim):
				sfx.call("whoosh", 0.5, ball_world())


func xr_cancel() -> void:
	grips.clear()
	trigger = null
	turn_dir = 0
	game.set_tilt(0, 0)


## Ricochet, A: the next paddle of this round is the one the stick turns. True when it moved.
func next_paddle() -> bool:
	var n := paddle_count()
	if n <= 1:
		return false
	selected = (selected + 1) % n
	select_t = 0.0
	sfx.call("bricks_tink", 0.75, _paddle_world(selected))
	return true


## The round's paddles (0 outside ricochet).
func paddle_count() -> int:
	if mode != "ricochet":
		return 0
	return (game.definition().mirrors as Array).size()


func _paddle_world(i: int) -> Vector3:
	var l: Dictionary = game.definition()
	if i < 0 or i >= l.mirrors.size():
		return ball_world()
	return _board_xf() * Vector3(l.mirrors[i].x, 0.3, l.mirrors[i].z)


## Turns the selected paddle by `steps` 5-degree steps (a soft click each). True if it turned.
func turn_paddle(steps: int) -> bool:
	if selected >= paddle_count() or steps == 0:
		return false
	if not game.turn_mirror(selected, game.angles[selected] + steps * TabletopGame.MIRROR_ANGLE_STEP):
		return false
	sfx.call("bricks_tink", 0.25, _paddle_world(selected))
	return true


## The left stick's x this frame (ricochet): a push turns the selected paddle one 5° step
## (right: clockwise seen from above), holding it repeats, faster the further it is pushed.
func stick_turn(x: float, dt: float) -> void:
	var dir := 0
	if absf(x) >= STICK_ON:
		dir = 1 if x > 0.0 else -1
	elif turn_dir != 0 and absf(x) > STICK_OFF and signf(x) == float(turn_dir):
		dir = turn_dir
	if dir == 0 or paddle_count() == 0 or game.phase != "ready":
		turn_dir = 0
		return
	if dir != turn_dir:
		turn_dir = dir
		turn_t = TURN_FIRST
		turn_paddle(dir)
		return
	turn_t -= dt
	var k := clampf((absf(x) - STICK_ON) / (1.0 - STICK_ON), 0.0, 1.0)
	var guard := 0
	while turn_t <= 0.0 and guard < 4:
		turn_paddle(dir)
		turn_t += lerpf(TURN_SLOW, TURN_FAST, k)
		guard += 1
	turn_t = maxf(turn_t, 0.0)


func deactivate() -> void:
	xr_cancel()


## A / X (recall): start the round again (counts as a retry).
func retry() -> void:
	xr_cancel()
	game.retry()


func on_respawn() -> void:
	xr_cancel()
	if game.phase != "ready" and game.phase != "won":
		game.retry()


func ball_world() -> Vector3:
	return _board_xf() * Vector3(game.ball.x, R - game.fall, game.ball.y)


## A missed launch: the heart pops, spins and empties; a squeak and an "ouch" where he fell.
func _on_heart_lost(left: int) -> void:
	if left >= 0 and left < heart_lost_t.size():
		heart_lost_t[left] = 0.0
	hearts_shown = left
	var at := Vector3(clampf(game.ball.x, -1.1, 1.1), 0.75, clampf(game.ball.y, -1.3, 1.1))
	sfx.call("squeak", 0.7, _grp_xf() * at)
	JuiceText.spawn(self, _tr("آخ!", "OUCH!"), at, "ouch", 0.32)
	if left == 0 and heart_row:
		JuiceText.spawn(self, _tr("نفدت القلوب!", "Out of hearts!"), heart_row.position + Vector3(0, 0.45, 0.1), "ouch", 0.3)


## Out of hearts: the round from the top, all six hearts back.
func _on_restarted() -> void:
	xr_cancel()
	selected = 0
	_refill_hearts()
	sfx.call("swish", 0.6, _board_xf() * heart_row.position if heart_row else ball_world())


func _refill_hearts() -> void:
	hearts_refill_t = 0.0
	hearts_shown = game.hearts
	for i in heart_lost_t.size():
		heart_lost_t[i] = -1.0


## The heart row each frame: full ones bob (the last one beats fast), a lost one pops and
## spins for .6 s then sits empty, a refill pops them back in one after another.
func _frame_hearts(dt: float) -> void:
	if hearts.is_empty():
		return
	if game.hearts > hearts_shown:
		_refill_hearts()
	hearts_refill_t += dt
	for i in hearts.size():
		var h: MeshInstance3D = hearts[i]
		var x := (i - (hearts.size() - 1) / 2.0) * HEART_GAP
		var full := i < game.hearts
		var lt: float = heart_lost_t[i]
		var k := 1.0
		var y := 0.0
		var spin := 0.0
		if lt >= 0.0:
			lt += dt
			heart_lost_t[i] = lt
			var u := clampf(lt / 0.6, 0.0, 1.0)
			if lt < 0.3:
				k = 1.0 + 0.6 * sin(PI * lt / 0.3)  # the pop
			else:
				k = lerpf(1.0, 0.8, clampf((u - 0.5) * 2.0, 0.0, 1.0))  # settles, empty
			y = 0.22 * sin(PI * u)
			spin = TAU * (1.0 - pow(1.0 - u, 3.0))
			full = lt < 0.3
			if lt > 0.6:
				heart_lost_t[i] = -1.0
		elif full:
			var beat := 7.0 if game.hearts == 1 else 3.0
			k = 1.0 + (0.12 if game.hearts == 1 else 0.05) * maxf(0.0, sin(time * beat + i * 0.7))
			y = 0.02 * sin(time * 2.2 + i * 0.9)
		else:
			k = 0.8
		# The refill: each pops in with a little overshoot, left to right.
		var rt := hearts_refill_t - i * 0.08
		if rt < 0.35 and full:
			k *= clampf(rt / 0.35, 0.0, 1.0) * (1.0 + 0.35 * sin(PI * clampf(rt / 0.35, 0.0, 1.0)))
		h.position = Vector3(x, y, 0)
		h.basis = Basis(Vector3.UP, spin) * Basis.from_scale(Vector3.ONE * HEART_SIZE * maxf(k, 0.001))
		h.material_override = mats.heart if full else mats.heart_empty


func _on_won(points: int, result: Dictionary) -> void:
	tabletop_win.call(result)
	var at := _board_xf() * Vector3(game.ball.x, R, game.ball.y)
	sfx.call("chime", 0.5, at)
	won.emit(points, result, at)


static func _has_input(inputs: Array, id) -> bool:
	for h in inputs:
		if h.get("id") == id:
			return true
	return false


## Every frame while the tabletop is on. ctx: {inputs: Array of inputs, active: bool, style,
## color, accessory, eye: Vector3 world, english: bool}.
func xr_frame(dt: float, ctx: Dictionary) -> void:
	var inputs: Array = ctx.get("inputs", [])
	var active: bool = ctx.get("active", true)
	time += dt if active else 0.0
	for id in grips.keys():
		if not _has_input(inputs, id):
			xr_release(id, true)
	if trigger != null and not _has_input(inputs, trigger):
		xr_release(trigger, true)
	var held := []
	if active:
		for input: Dictionary in inputs:
			var grip = grips.get(input.get("id"))
			if grip != null:
				var local := _local_input(input)
				if tilting:
					var delta: Quaternion = local.q * (grip.q as Quaternion).inverse()
					var normal := delta * Vector3.UP
					held.append({"x": grip.tilt.x + atan2(normal.x, normal.y), "z": grip.tilt.y + atan2(normal.z, normal.y), "pos": local.pos, "base": grip.pos})
			if not tilting and (trigger == null or trigger == input.get("id")) and grip == null and game.phase == "ready":
				_aim_at(input)
	if mode == "ricochet":
		var stick: Vector2 = ctx.get("stick", Vector2.ZERO)
		if active:
			stick_turn(stick.x, dt)
		else:
			turn_dir = 0
	if not held.is_empty():
		var x := 0.0
		var z := 0.0
		for h in held:
			x += h.x / held.size()
			z += h.z / held.size()
		if held.size() == 2:
			var d: Vector3 = held[1].pos - held[0].pos
			var b: Vector3 = held[1].base - held[0].base
			var k := d.x * d.x + d.z * d.z
			if k > 0.04:
				x -= (d.y - b.y) * d.x / k
				z -= (d.y - b.y) * d.z / k
		game.set_tilt(x, z)
	game.step(dt, active and (not tilting or not grips.is_empty() or game.phase == "won" or game.phase == "falling"))
	if level_shown != game.level:
		xr_cancel()
		selected = 0
		select_t = 99.0
	board.rotation = Vector3(game.tilt.y, 0, -game.tilt.x)
	_level_art()
	_status(bool(ctx.get("english", english)))
	_frame_pieces()
	_frame_hearts(dt if active else 0.0)
	_frame_marker(dt if active else 0.0)
	var style := str(ctx.get("style", Save.style))
	character.set_look(style, str(ctx.get("color", Save.jelly_color)), str(ctx.get("accessory", "")))
	var pos := Vector3(game.ball.x, R - game.fall, game.ball.y)
	var eye = ctx.get("eye")
	var toward = null
	if eye is Vector3:
		toward = _board_xf().affine_inverse() * (eye as Vector3)
	var face := "joy" if game.phase == "won" else ("wide" if game.phase == "falling" else "focus")
	character.show_at(pos, toward, face, fmod(time, 3.7) < 0.12)
	character.visible = game.fall < 0.45


func _frame_pieces() -> void:
	for i in stars.size():
		if tilting:
			stars[i].visible = not game.stars.has(i)
			stars[i].basis = Basis(Vector3.UP, time * 0.6)
	for i in mirrors.size():
		var m: MeshInstance3D = mirrors[i]
		if m.visible:
			m.rotation.y = -game.angles[i]
			if i == selected and mats.has("selected"):
				m.material_override = mats.selected
			else:
				m.material_override = mats.honey if game.bounces.has(i) else (mats.walnut if i % 2 else mats.wood)
	var g := game.gate()
	if gate_mesh.visible and not g.is_empty():
		gate_mesh.position = Vector3(g.x, 0.135, g.z)
	for h: MeshInstance3D in handles:
		h.material_override = mats.gold if not grips.is_empty() else mats.cream
		h.visible = tilting
	for i in dots.size():
		var d: MeshInstance3D = dots[i]
		d.visible = not tilting and game.phase == "ready" and grips.is_empty()
		if d.visible:
			var t := 0.24 + i * 0.10
			d.position = Vector3(game.ball.x + aim.x * t, 0.07, game.ball.y + aim.y * t)
			d.visible = absf(d.position.x) < 1.45 and absf(d.position.z) < 1.65


## The gold arrow over the selected paddle: it bobs and spins slowly, and pops when A picks
## a new paddle.
func _frame_marker(dt: float) -> void:
	if marker == null:
		return
	select_t += dt
	var n := paddle_count()
	if selected >= n:
		selected = 0
	marker.visible = n > 0 and selected < mirrors.size() and (mirrors[selected] as MeshInstance3D).visible
	if not marker.visible:
		return
	var m: MeshInstance3D = mirrors[selected]
	var pop := 1.0
	if select_t < 0.3:
		pop = 1.0 + 0.5 * sin(PI * select_t / 0.3)
	marker.position = Vector3(m.position.x, 0.62 + 0.05 * sin(time * 4.0), m.position.z)
	marker.basis = Basis(Vector3.UP, time * 1.6) * Basis.from_scale(Vector3.ONE * pop)
