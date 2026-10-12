class_name Slingshot
extends Node3D
## The slingshot held in the fork hand: a light procedural model (no imported asset).
## A Y-shaped wooden fork grown as one branching piece (a tapered handle, a smooth crotch and two arms
## that curve out and up to the tips), a leather wrap spiralling round the grip, rubber ties at the
## tips, two rubber bands that stretch from the tips to a leather pouch, and the pouch itself.
## Grip space (this node sits on the controller's grip pose), metres; the anchors are main.gd's.
## About 1.6k triangles in five draws (wood, wrap, rubber, pouch + the two bands share rubber).
##
## set_pouch(world_pos, ball_radius) pulls the pouch (and the bands) to a point, e.g. Dahrooj's centre:
## the pouch then cradles the back of the ball. rest() puts it back between the tips.

const TIP_L := Vector3(-0.04, 0.15, -0.045)
const TIP_R := Vector3(0.04, 0.15, -0.045)
const POUCH := Vector3(0, 0.14, 0.02)
const FORK_CENTER := Vector3(0, 0.15, -0.045)
const CROTCH := Vector3(0, 0.07, -0.03)
const BUTT := Vector3(0, -0.065, -0.008)
const POUCH_HALF := 0.017  # half the pouch's width: where the bands tie on
const BAND_R := 0.0032

var wood_mat: StandardMaterial3D
var wrap_mat: StandardMaterial3D
var rubber_mat: StandardMaterial3D
var leather_mat: StandardMaterial3D
var bands: Array[MeshInstance3D] = []
var pouch: MeshInstance3D
## The pouch's centre in grip space (POUCH at rest).
var pouch_local := POUCH


func _init() -> void:
	name = "Slingshot"
	wood_mat = _mat(Color("9a6438"), 0.7)
	wrap_mat = _mat(Color("4a2c1d"), 0.85)
	rubber_mat = _mat(Color("c8442f"), 0.45)
	leather_mat = _mat(Color("6b3f26"), 0.8)
	_add_mesh("Fork", _fork_mesh(), wood_mat)
	_add_mesh("Wrap", _wrap_mesh(), wrap_mat)
	_add_mesh("Ties", _ties_mesh(), rubber_mat)
	var band_mesh := CylinderMesh.new()
	band_mesh.top_radius = BAND_R
	band_mesh.bottom_radius = BAND_R
	band_mesh.height = 1.0
	band_mesh.radial_segments = 6
	band_mesh.rings = 1
	band_mesh.cap_top = false
	band_mesh.cap_bottom = false
	for i in 2:
		bands.append(_add_mesh("Band" + str(i), band_mesh, rubber_mat))
	pouch = _add_mesh("Pouch", _pouch_mesh(), leather_mat)
	rest()


static func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _add_mesh(n: String, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


# --- API ----------------------------------------------------------------------------------------

## The tips (where the bands tie on), in global space: [left, right].
func tips() -> Array:
	return [global_transform * TIP_L, global_transform * TIP_R]


func tip_position(left: bool) -> Vector3:
	return global_transform * (TIP_L if left else TIP_R)


## Between the tips (the aim point main.gd pulls against), global.
func fork_center() -> Vector3:
	return global_transform * FORK_CENTER


## The pouch at rest, global (where Dahrooj sits when parked).
func pouch_rest() -> Vector3:
	return global_transform * POUCH


## Pull the pouch to world_pos; with a ball radius, the pouch sits on the far side of the ball from
## the fork so it cradles it.
func set_pouch(world_pos: Vector3, ball_radius := 0.0) -> void:
	var p := global_transform.affine_inverse() * world_pos
	if ball_radius > 0.0:
		var away := p - FORK_CENTER
		if away.length_squared() > 1e-8:
			p += away.normalized() * ball_radius * 0.92
	_place_pouch(p)


func rest() -> void:
	_place_pouch(POUCH)


func _place_pouch(p: Vector3) -> void:
	pouch_local = p
	# The pouch faces the fork (its -Z toward the fork centre), its width across the tips.
	var back := (p - FORK_CENTER)
	back = back.normalized() if back.length_squared() > 1e-8 else Vector3.BACK
	var across := (TIP_R - TIP_L).normalized()
	across = (across - back * across.dot(back))
	across = across.normalized() if across.length_squared() > 1e-8 else Vector3.RIGHT
	var up := back.cross(across).normalized()
	var b := Basis(across, up, back)
	# Stretched a little along the pull the further it is drawn back (leather gives).
	var pull := clampf((p - POUCH).length() / 0.4, 0.0, 1.0)
	pouch.transform = Transform3D(b * Basis.from_scale(Vector3(1.0 - 0.12 * pull, 1.0, 1.0)), p)
	var ends := [p - across * POUCH_HALF + back * 0.004, p + across * POUCH_HALF + back * 0.004]
	var tl := [TIP_L + Vector3(0, -0.004, 0), TIP_R + Vector3(0, -0.004, 0)]
	for i in 2:
		_stretch(bands[i], tl[i], ends[i])


## A unit cylinder from a to b; it thins as it stretches (rubber keeps its volume).
static func _stretch(m: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var l := d.length()
	var q := Quaternion.IDENTITY
	if l > 1e-6:
		var u := d / l
		q = Quaternion(Vector3.UP, u) if u.dot(Vector3.UP) > -0.9999 else Quaternion(Vector3.RIGHT, PI)
	var rest_len := 0.07
	var thin := clampf(sqrt(rest_len / maxf(l, 1e-4)), 0.45, 1.0)
	m.transform = Transform3D(Basis(q) * Basis.from_scale(Vector3(thin, maxf(l, 1e-4), thin)), (a + b) * 0.5)


# --- geometry -----------------------------------------------------------------------------------

static func _bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t


## A tube along points with radii (a ring per point), closed with a dome at the end if asked.
static func _tube(st: SurfaceTool, pts: Array, radii: Array, sides: int, cap_start: bool, cap_end: bool) -> void:
	var n := pts.size()
	var rings: Array = []
	var prev_side := Vector3.RIGHT
	for i in n:
		var p: Vector3 = pts[i]
		var tan: Vector3 = ((pts[mini(i + 1, n - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		var side := (prev_side - tan * prev_side.dot(tan))
		if side.length_squared() < 1e-6:
			side = tan.cross(Vector3.FORWARD)
		side = side.normalized()
		prev_side = side
		var up := tan.cross(side).normalized()
		var ring: Array = []
		for k in sides:
			var a := float(k) / sides * TAU
			var nrm := side * cos(a) + up * sin(a)
			ring.append([p + nrm * float(radii[i]), nrm])
		rings.append(ring)
	for i in n - 1:
		for k in sides:
			var k2 := (k + 1) % sides
			var a: Array = rings[i][k]
			var b: Array = rings[i][k2]
			var c: Array = rings[i + 1][k2]
			var d: Array = rings[i + 1][k]
			_tri(st, a, c, b)
			_tri(st, a, d, c)
	for e in 2:
		if (e == 0 and not cap_start) or (e == 1 and not cap_end):
			continue
		var i := 0 if e == 0 else n - 1
		var p: Vector3 = pts[i]
		var dir: Vector3 = ((pts[1] as Vector3) - (pts[0] as Vector3)).normalized() * -1.0 if e == 0 else ((pts[n - 1] as Vector3) - (pts[n - 2] as Vector3)).normalized()
		var tip_v := [p + dir * float(radii[i]) * 0.8, dir]
		for k in sides:
			var a: Array = rings[i][k]
			var b: Array = rings[i][(k + 1) % sides]
			if e == 0:
				_tri(st, a, b, tip_v)
			else:
				_tri(st, a, tip_v, b)


## One triangle of [position, normal] corners, wound for Godot (clockwise seen from outside).
static func _tri(st: SurfaceTool, a: Array, b: Array, c: Array) -> void:
	var pa: Vector3 = a[0]
	var pb: Vector3 = b[0]
	var pc: Vector3 = c[0]
	var avg: Vector3 = (a[1] as Vector3) + (b[1] as Vector3) + (c[1] as Vector3)
	var order := [a, b, c]
	if (pb - pa).cross(pc - pa).dot(avg) > 0.0:
		order = [a, c, b]
	for v: Array in order:
		st.set_normal(v[1])
		st.add_vertex(v[0])


static func _fork_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The handle: butt to crotch, slightly bellied, flaring into the crotch.
	var hp: Array = []
	var hr: Array = []
	for i in 9:
		var t := float(i) / 8.0
		hp.append(BUTT.lerp(CROTCH, t) + Vector3(0, 0, sin(t * PI) * 0.003))
		hr.append(0.0125 + sin(t * PI) * 0.0012 + pow(t, 4.0) * 0.004)
	_tube(st, hp, hr, 12, true, false)
	# The arms: out and up from the crotch, then straight up into the tips.
	for side in [-1.0, 1.0]:
		var tip := TIP_L if side < 0 else TIP_R
		var p0 := CROTCH + Vector3(side * 0.004, 0.004, 0)
		var p1 := CROTCH + Vector3(side * 0.03, 0.03, -0.004)
		var p2 := tip + Vector3(side * 0.006, -0.045, 0.004)
		var p3 := tip + Vector3(0, 0.006, 0)
		var ap: Array = []
		var ar: Array = []
		for i in 11:
			var t := float(i) / 10.0
			ap.append(_bezier(p0, p1, p2, p3, t))
			ar.append(lerpf(0.0115, 0.0075, t))
		_tube(st, ap, ar, 10, false, true)
	# The crotch: a smooth knot where the branches part.
	var knot: Array = []
	var kr: Array = []
	for i in 7:
		var t := float(i) / 6.0
		knot.append(CROTCH + Vector3(0, -0.012 + t * 0.022, -0.001))
		kr.append(0.0128 * sin(lerpf(0.5, PI - 0.5, t)) + 0.0015)
	_tube(st, knot, kr, 12, false, true)
	return st.commit()


## A leather strap wound round the grip (a flat helix).
static func _wrap_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = []
	var radii: Array = []
	var turns := 6.5
	var steps := 120
	var y0 := BUTT.y + 0.018
	var y1 := CROTCH.y - 0.03
	for i in steps + 1:
		var t := float(i) / steps
		var a := t * turns * TAU
		var axis := BUTT.lerp(CROTCH, (lerpf(y0, y1, t) - BUTT.y) / (CROTCH.y - BUTT.y))
		pts.append(axis + Vector3(cos(a), 0, sin(a)) * 0.0149)
		radii.append(0.0026)
	_tube(st, pts, radii, 5, true, true)
	return st.commit()


## Rubber ties round the tips, where the bands are knotted on.
static func _ties_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tip in [TIP_L, TIP_R]:
		for j in 2:
			var c: Vector3 = tip + Vector3(0, -0.006 - j * 0.006, 0)
			var pts: Array = []
			var radii: Array = []
			for i in 17:
				var a := float(i) / 16.0 * TAU
				pts.append(c + Vector3(cos(a), 0, sin(a)) * 0.0088)
				radii.append(0.0022)
			_tube(st, pts, radii, 5, false, false)
	return st.commit()


## The pouch: a little saddle of leather, cupped toward -Z (the fork side faces away from the ball).
static func _pouch_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nu := 8
	var nv := 4
	var grid: Array = []
	for j in nv + 1:
		var row: Array = []
		for i in nu + 1:
			var u := float(i) / nu * 2.0 - 1.0
			var v := float(j) / nv * 2.0 - 1.0
			var x := u * (POUCH_HALF + 0.003)
			var y := v * 0.011 * (1.0 - 0.25 * u * u)
			var z := -(1.0 - u * u) * 0.009 - (1.0 - v * v) * 0.003  # cupped round the ball
			row.append(Vector3(x, y, z))
		grid.append(row)
	for j in nv:
		for i in nu:
			var a: Vector3 = grid[j][i]
			var b: Vector3 = grid[j][i + 1]
			var c: Vector3 = grid[j + 1][i + 1]
			var d: Vector3 = grid[j + 1][i]
			var n := (b - a).cross(d - a).normalized()
			for side: float in [1.0, -1.0]:  # both faces, a hair apart
				var o := n * 0.0006 * side
				var nn := n * side
				_tri(st, [a + o, nn], [b + o, nn], [c + o, nn])
				_tri(st, [a + o, nn], [c + o, nn], [d + o, nn])
	return st.commit()
