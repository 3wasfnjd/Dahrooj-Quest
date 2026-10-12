class_name SummitWorld
extends Node3D
## The Summit's model mountain (src/reference/mountain-complete.js, the same art as
## summit-world.js): a rough clay slab coloured by section with a snowy peak, trees,
## boulders, crystals and snowy pines on its face; the ledges (rock, sand when they
## crumble, planks when they move, ice, spikes, grass tufts and snow lumps, flags on
## the checkpoint ledges and the summit cairn); the beetle crawlers, bats and potted
## spitters with their eyes; the icicles. One unit is Dahrooj's radius; x is centred
## (game x - width / 2), y = 0 is the starting ground, the face looks toward +z.
##
## Every material here is clipped to a window (the web game's two clipping planes):
## set_clip() each frame with the window's plane in world space. draw() moves the
## pieces from the core state each frame.

const THEMES := [Color("7f9a5b"), Color("a38b74"), Color("77728a"), Color("e8f1f5")]
const DEPTH := 3.0
const VIEW := 24.0
const BELOW := 2.0

const SHADER := """
shader_type spatial;
render_mode %s;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness = 0.85;
uniform float metallic = 0.0;
uniform vec3 emission : source_color = vec3(0.0);
uniform bool vcol = false;
uniform bool wave = false;
uniform float wave_t = 0.0;
uniform vec3 clip_up = vec3(0.0, 1.0, 0.0);
uniform float clip_lo = -100000.0;
uniform float clip_hi = 100000.0;
void vertex() {
	if (wave) {
		VERTEX.z = sin(wave_t * 5.0 + VERTEX.x * 4.0) * 0.08 * (VERTEX.x + 0.7);
	}
}
void fragment() {
	vec3 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = dot(clip_up, w);
	if (d < clip_lo || d > clip_hi) {
		discard;
	}
	vec3 c = albedo.rgb;
	if (vcol) {
		c *= COLOR.rgb;
	}
	ALBEDO = c;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = emission;
	%s
}
"""

static var _shaders := {}
static var _meshes := {}

var width := 16.25
var mats: Array[ShaderMaterial] = []
var pieces: Array = []  # {kind: plat|monster|icicle, ...}
var _seed := 11
var _clip := [Vector3.UP, -100000.0, 100000.0]
# Materials shared by the pieces.
var leaf: ShaderMaterial
var trunk: ShaderMaterial
var boulder: ShaderMaterial
var crystal: ShaderMaterial
var snow: ShaderMaterial
var white: ShaderMaterial
var pupil: ShaderMaterial
var ledge_rock: ShaderMaterial
var plank: ShaderMaterial
var metal: ShaderMaterial
var tops: Array[ShaderMaterial] = []
var ice: ShaderMaterial
var sand: ShaderMaterial
var crack: ShaderMaterial
var shell: ShaderMaterial
var shell_dark: ShaderMaterial
var ink: ShaderMaterial
var gold: ShaderMaterial
var seed_mat: ShaderMaterial
var ice_mat: ShaderMaterial
var mountain: MeshInstance3D


func _init(w := 16.25) -> void:
	width = w
	name = "SummitWorld"
	leaf = mat(Color("5f8f45"))
	trunk = mat(Color("7a5236"))
	boulder = mat(Color("8a7f74"))
	crystal = mat(Color("b28ad8"), {"roughness": 0.2, "metalness": 0.1, "emissive": Color("2a1840")})
	snow = mat(Color("d3dce2"))
	white = mat(Color("fffaf2"), {"roughness": 0.4})
	pupil = mat(Color("23242f"), {"roughness": 0.3})
	ledge_rock = mat(Color("5e3f29"))
	plank = mat(Color("9c6b3f"))
	metal = mat(Color("6a6c74"), {"metalness": 0.5, "roughness": 0.4})
	tops = [mat(Color("7fa35a")), mat(Color("a58a6c")), mat(Color("8a84a0")), mat(Color("d0d9df"))]
	ice = mat(Color("a9cfdd"), {"roughness": 0.35, "metalness": 0.1})
	sand = mat(Color("b48d62"))
	crack = mat(Color("3b2f26"))
	shell = mat(Color("7a4f78"), {"roughness": 0.35})
	shell_dark = mat(Color("4a2c48"), {"roughness": 0.5})
	ink = mat(Color("2c2d3d"), {"roughness": 0.9})
	gold = mat(Color("e2b04a"))
	seed_mat = mat(Color("3d5a2c"))
	ice_mat = mat(Color("bfe3f0"), {"roughness": 0.15, "transparent": true, "opacity": 0.9})
	_build_mountain()
	_build_scenery()


# --- materials and shapes -----------------------------------------------------------

static func shader(double_sided: bool, transparent: bool) -> Shader:
	var key := "%s%s" % [double_sided, transparent]
	if not _shaders.has(key):
		var s := Shader.new()
		var modes := "cull_disabled" if double_sided else "cull_back"
		if transparent:
			modes += ", blend_mix, depth_draw_opaque"
		s.code = SHADER % [modes, "ALPHA = albedo.a;" if transparent else ""]
		_shaders[key] = s
	return _shaders[key]


## The web's std(color, o): MeshStandardMaterial (roughness .85) with the clipping planes.
## o: roughness, metalness, emissive, double (DoubleSide), transparent, opacity, vcol.
func mat(color: Color, o := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader(bool(o.get("double", false)), bool(o.get("transparent", false)))
	m.set_shader_parameter("albedo", Color(color, float(o.get("opacity", 1.0))))
	m.set_shader_parameter("roughness", float(o.get("roughness", 0.85)))
	m.set_shader_parameter("metallic", float(o.get("metalness", 0.0)))
	m.set_shader_parameter("emission", o.get("emissive", Color(0, 0, 0)))
	m.set_shader_parameter("vcol", bool(o.get("vcol", false)))
	m.set_shader_parameter("clip_up", _clip[0])
	m.set_shader_parameter("clip_lo", _clip[1])
	m.set_shader_parameter("clip_hi", _clip[2])
	mats.append(m)
	return m


## The clip window: keep what lies between lo and hi along up (world space).
func set_clip(up: Vector3, lo: float, hi: float) -> void:
	_clip = [up, lo, hi]
	for m in mats:
		m.set_shader_parameter("clip_up", up)
		m.set_shader_parameter("clip_lo", lo)
		m.set_shader_parameter("clip_hi", hi)


static func ball_mesh() -> Mesh:
	if not _meshes.has("ball"):
		var s := SphereMesh.new()  # SphereGeometry(1, 20, 14)
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 20
		s.rings = 13
		_meshes.ball = s
	return _meshes.ball


static func cone_mesh() -> Mesh:
	if not _meshes.has("cone"):
		var c := CylinderMesh.new()  # ConeGeometry(1, 1, 10)
		c.top_radius = 0.0
		c.bottom_radius = 1.0
		c.height = 1.0
		c.radial_segments = 10
		c.rings = 0
		_meshes.cone = c
	return _meshes.cone


static func cyl_mesh() -> Mesh:
	if not _meshes.has("cyl"):
		var c := CylinderMesh.new()  # CylinderGeometry(1, 1, 1, 14)
		c.top_radius = 1.0
		c.bottom_radius = 1.0
		c.height = 1.0
		c.radial_segments = 14
		c.rings = 0
		_meshes.cyl = c
	return _meshes.cyl


static func box_mesh() -> Mesh:
	if not _meshes.has("box"):
		_meshes.box = BoxMesh.new()
	return _meshes.box


## A triangle with the given outward side as its front (Godot's front faces wind clockwise).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.dot(out) > 0.0:
		var t := b
		b = c
		c = t
		n = -n
	n = -n.normalized()
	for v in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(v)


## three.js PolyhedronGeometry(radius 1, detail 0): flat faces.
static func _poly(key: String, verts: Array, idx: Array) -> Mesh:
	if not _meshes.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var v: Array[Vector3] = []
		for i in range(0, verts.size(), 3):
			v.append(Vector3(verts[i], verts[i + 1], verts[i + 2]).normalized())
		for i in range(0, idx.size(), 3):
			var a := v[idx[i]]
			var b := v[idx[i + 1]]
			var c := v[idx[i + 2]]
			_tri(st, a, b, c, (a + b + c) / 3.0)
		_meshes[key] = st.commit()
	return _meshes[key]


static func dodeca_mesh() -> Mesh:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var r := 1.0 / t
	return _poly("dodeca", [
		-1, -1, -1, -1, -1, 1, -1, 1, -1, -1, 1, 1, 1, -1, -1, 1, -1, 1, 1, 1, -1, 1, 1, 1,
		0, -r, -t, 0, -r, t, 0, r, -t, 0, r, t, -r, -t, 0, -r, t, 0, r, -t, 0, r, t, 0,
		-t, 0, -r, t, 0, -r, -t, 0, r, t, 0, r], [
		3, 11, 7, 3, 7, 15, 3, 15, 13, 7, 19, 17, 7, 17, 6, 7, 6, 15, 17, 4, 8, 17, 8, 10, 17, 10, 6,
		8, 0, 16, 8, 16, 2, 8, 2, 10, 0, 12, 1, 0, 1, 18, 0, 18, 16, 6, 10, 2, 6, 2, 13, 6, 13, 15,
		2, 16, 18, 2, 18, 3, 2, 3, 13, 18, 1, 9, 18, 9, 11, 18, 11, 3, 4, 14, 12, 4, 12, 0, 4, 0, 8,
		11, 9, 5, 11, 5, 19, 11, 19, 7, 19, 5, 14, 19, 14, 4, 19, 4, 17, 1, 12, 14, 1, 14, 5, 1, 5, 9])


static func octa_mesh() -> Mesh:
	return _poly("octa", [1, 0, 0, -1, 0, 0, 0, 1, 0, 0, -1, 0, 0, 0, 1, 0, 0, -1],
		[0, 2, 4, 0, 4, 3, 0, 3, 5, 0, 5, 2, 1, 2, 5, 1, 5, 3, 1, 3, 4, 1, 4, 2])


## A flat disc facing +y (CircleGeometry rotated -90° about x).
static func disc_mesh(radius: float, segs: int) -> Mesh:
	var key := "disc%f_%d" % [radius, segs]
	if not _meshes.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in segs:
			var a0 := TAU * i / segs
			var a1 := TAU * (i + 1) / segs
			_tri(st, Vector3.ZERO, Vector3(cos(a0), 0, -sin(a0)) * radius, Vector3(cos(a1), 0, -sin(a1)) * radius, Vector3.UP)
		_meshes[key] = st.commit()
	return _meshes[key]


## The bat's wing: a membrane with a scalloped trailing edge (ShapeGeometry, 8 steps a curve).
static func wing_mesh() -> Mesh:
	if not _meshes.has("wing"):
		var pts := PackedVector2Array([Vector2(0, 0.1)])
		var curves := [[Vector2(0.6, 0.6), Vector2(1.3, 0.35)], [Vector2(1.1, 0), Vector2(1.05, -0.15)],
			[Vector2(0.85, -0.02), Vector2(0.7, -0.2)], [Vector2(0.5, -0.02), Vector2(0.35, -0.18)],
			[Vector2(0.2, -0.02), Vector2(0, -0.1)]]
		for c: Array in curves:
			var p0: Vector2 = pts[pts.size() - 1]
			for k in range(1, 9):
				var t := k / 8.0
				pts.append(p0 * (1 - t) * (1 - t) + (c[0] as Vector2) * 2.0 * (1 - t) * t + (c[1] as Vector2) * t * t)
		if pts[pts.size() - 1].distance_to(pts[0]) < 1e-4:
			pts.remove_at(pts.size() - 1)
		var tris := Geometry2D.triangulate_polygon(pts)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(0, tris.size(), 3):
			var a := Vector3(pts[tris[i]].x, pts[tris[i]].y, 0)
			var b := Vector3(pts[tris[i + 1]].x, pts[tris[i + 1]].y, 0)
			var c := Vector3(pts[tris[i + 2]].x, pts[tris[i + 2]].y, 0)
			_tri(st, a, b, c, Vector3.BACK)
		_meshes.wing = st.commit()
	return _meshes.wing


func _mesh(m: Mesh, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation_order = EULER_ORDER_XYZ
	(parent if parent != null else self).add_child(mi)
	return mi


func _group(parent: Node3D = null) -> Node3D:
	var g := Node3D.new()
	g.rotation_order = EULER_ORDER_XYZ
	(parent if parent != null else self).add_child(g)
	return g


func rnd() -> float:
	_seed = (_seed * 16807) % 2147483647
	return _seed / 2147483647.0


static func noise(x: float, y: float) -> float:
	return sin(x * 1.7 + y * 0.37) * 0.5 + sin(x * 0.53 - y * 1.13) * 0.35 + sin(x * 3.1 + y * 2.3) * 0.15


func X(x: float) -> float:
	return x - width / 2.0


# --- the mountain itself: a rough rock slab, coloured by section ---------------------------

## One vertex of the slab, displaced and coloured as the web game does (box-local in, slab-local out).
func _slab_vertex(p: Vector3, H: float) -> Array:
	var x := p.x
	var y := p.y + H / 2.0 - 3.0
	var z := p.z
	var TOP := SummitCore.TOP
	# Jagged sides, a bumpy face and a peak that narrows above the summit.
	var side := absf(x) / ((width + 5.0) / 2.0)
	var taper := maxf(0.25, 1.0 - (y - TOP + 6.0) / 22.0) if y > TOP - 6.0 else 1.0
	x = x * taper + (noise(y * 0.4, z) * 1.6 if side > 0.95 else 0.0)
	z += noise(x * 0.5, y * 0.5) * 0.9 + (noise(x * 1.3, y * 1.1) * 0.2 if z > 0.0 else 0.0)
	# A muddy clay mountain: warm brown earth, darker in the hollows.
	var theme: Color = THEMES[clampi(floori(y / 36.0), 0, 3)]
	var c := Color("7b5536").lerp(theme, 0.15).lerp(Color("4a2f1f"), maxf(0.0, noise(x * 2.0, y * 2.0)) * 0.45)
	# Snow toward the peak, a soft blue-grey so it isn't glaring under the sun.
	if y > TOP - 10.0:
		c = c.lerp(Color("cfd8de"), minf(1.0, (y - TOP + 10.0) / 6.0) * 0.9)
	return [Vector3(x, y, z), c.srgb_to_linear()]


func _build_mountain() -> void:
	var H := SummitCore.TOP + 16.0
	var size := Vector3(width + 5.0, H, 5.0)
	var segs := Vector3i(14, roundi(H * 0.55), 3)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# BoxGeometry(W + 5, H, 5, 14, H * .55, 3): each face a grid, every vertex displaced alike.
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for sgn in [-1.0, 1.0]:
			var out := Vector3.ZERO
			out[axis] = sgn
			var nu: int = segs[u]
			var nv: int = segs[v]
			var grid := []
			for j in nv + 1:
				var row := []
				for i in nu + 1:
					var p := Vector3.ZERO
					p[axis] = sgn * size[axis] / 2.0
					p[u] = (float(i) / nu - 0.5) * size[u]
					p[v] = (float(j) / nv - 0.5) * size[v]
					row.append([p, _slab_vertex(p, H)])
				grid.append(row)
			for j in nv:
				for i in nu:
					var q := [grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]]
					for t in [[0, 1, 2], [0, 2, 3]]:
						var A: Array = q[t[0]]
						var B: Array = q[t[1]]
						var C: Array = q[t[2]]
						# Orientation from the undisplaced box, the flat normal from the displaced face.
						var flip: bool = ((B[0] as Vector3) - A[0]).cross((C[0] as Vector3) - A[0]).dot(out) > 0.0
						var a: Array = A[1]
						var b: Array = C[1] if flip else B[1]
						var c: Array = B[1] if flip else C[1]
						var n: Vector3 = -((b[0] as Vector3) - a[0]).cross((c[0] as Vector3) - a[0]).normalized()
						for vv: Array in [a, b, c]:
							st.set_normal(n)
							st.set_color(vv[1])
							st.add_vertex(vv[0])
	mountain = _mesh(st.commit(), mat(Color(1, 1, 1), {"vcol": true}))
	mountain.name = "Mountain"
	mountain.position.z = -DEPTH / 2.0 - 2.6


# Scenery on the face: trees in the meadow, boulders on the cliffs, crystals in the caves, snowy pines.
func _tree(x: float, y: float, z: float, s: float, snowy: bool) -> void:
	var g := _group()
	g.position = Vector3(x, y, z)
	g.scale = Vector3.ONE * s
	var t := _mesh(cyl_mesh(), trunk, g)
	t.scale = Vector3(0.18, 1, 0.18)
	t.position.y = 0.5
	for k in 3:
		var f := _mesh(cone_mesh(), snow if snowy and k == 2 else leaf, g)
		f.scale = Vector3(1.1 - k * 0.3, 1.2, 1.1 - k * 0.3)
		f.position.y = 1.3 + k * 0.65


func _build_scenery() -> void:
	var W := width
	for i in 9:
		var x := X(rnd() * W)
		var y := rnd() * 32.0
		var z := -DEPTH / 2.0 - 0.8 - rnd() * 0.6
		_tree(x, y, z, 0.9 + rnd() * 0.5, false)
	for i in 10:
		var b := _mesh(dodeca_mesh(), boulder)
		var sx := 0.6 + rnd()
		var sy := 0.5 + rnd() * 0.6
		var sz := 0.6 + rnd() * 0.5
		b.scale = Vector3(sx, sy, sz)
		var px := X(rnd() * W)
		var py := 36.0 + rnd() * 34.0
		b.position = Vector3(px, py, -DEPTH / 2.0 - 0.9)
		var rx := rnd() * 3.0
		var ry := rnd() * 3.0
		b.rotation = Vector3(rx, ry, 0)
	for i in 14:
		var k := _mesh(octa_mesh(), crystal)
		k.scale = Vector3(0.3, 0.8 + rnd() * 0.7, 0.3)
		var px := X(rnd() * W)
		var py := 74.0 + rnd() * 32.0
		k.position = Vector3(px, py, -DEPTH / 2.0 - 0.9)
		k.rotation.z = (rnd() - 0.5) * 0.8
	for i in 8:
		var x := X(rnd() * W)
		var y := 110.0 + rnd() * 30.0
		var z := -DEPTH / 2.0 - 0.8 - rnd() * 0.6
		_tree(x, y, z, 0.8 + rnd() * 0.4, true)


# --- eyes shared by the monsters -------------------------------------------------------------

func _eyes(parent: Node3D, r: float, spread: float, y: float, z: float) -> Array:
	var out := []
	for s in [-1.0, 1.0]:
		var e := _group(parent)
		e.position = Vector3(s * spread, y, z)
		var w := _mesh(ball_mesh(), white, e)
		w.scale = Vector3.ONE * r
		var p := _mesh(ball_mesh(), pupil, e)
		p.scale = Vector3.ONE * r * 0.55
		p.position.z = r * 0.6
		var shine := _mesh(ball_mesh(), white, e)
		shine.scale = Vector3.ONE * r * 0.18
		shine.position = Vector3(-r * 0.2, r * 0.25, r * 1.02)
		out.append({"p": p, "r": r})
	return out


static func look_at_eyes(list: Array, dx: float, dy: float) -> void:
	var l := Vector2(dx, dy).length()
	if l == 0.0:
		l = 1.0
	for e: Dictionary in list:
		var r: float = e.r
		(e.p as Node3D).position = Vector3(dx / l * r * 0.35, dy / l * r * 0.35, r * 0.55)


# --- ledges ----------------------------------------------------------------------------------

func _ledge(p: Dictionary) -> Dictionary:
	var g := _group()
	var w: float = p.x1 - p.x0
	var h := (1.6 if p.ground else 1.0) if p.full else 0.8
	# The starting ground isn't drawn: Dahrooj starts on the real floor (VR's stone, your room's floor or table).
	if p.ground:
		return {"kind": "plat", "p": p, "obj": g, "h": h}
	var body := _mesh(box_mesh(), plank if p.move != null else (sand if p.crumble != null else ledge_rock), g)
	body.scale = Vector3(1, h, DEPTH)
	body.position.y = -h / 2.0 - 0.08
	var top := _mesh(box_mesh(), ice if p.ice else (plank if p.move != null else tops[p.theme]), g)
	top.scale = Vector3(1.02, 0.2, DEPTH + 0.1)
	top.position.y = -0.1
	if p.crumble != null:
		for k in range(1, 4):
			var c := _mesh(box_mesh(), crack, g)
			c.scale = Vector3(0.012, 0.5, DEPTH + 0.12)
			c.position = Vector3(k / 4.0 - 0.5, -0.3, 0)
			c.rotation.z = 0.4 if k % 2 else -0.4
	# Tufts of grass on meadow ledges, snow lumps on the high ones.
	if not p.ice and p.move == null and (p.theme == 0 or p.theme == 3) and not p.full:
		for k in 3:
			var t := _mesh(cone_mesh() if p.theme == 0 else ball_mesh(), leaf if p.theme == 0 else snow, g)
			if p.theme == 0:
				t.scale = Vector3(0.08 / w, 0.35, 0.08)
			else:
				t.scale = Vector3(0.25 / w, 0.12, 0.3)
			t.position = Vector3((k + 0.5) / 3.0 - 0.5, 0.05, DEPTH * 0.35)
	if p.spikes != null:
		var s0: float = p.spikes[0]
		var s1: float = p.spikes[1]
		var n := maxi(2, roundi((s1 - s0) * w / 0.4))
		for k in n:
			for z in [-0.9, 0.0, 0.9]:
				var s := _mesh(cone_mesh(), metal, g)
				s.scale = Vector3(0.17 / w, 0.55, 0.17)
				s.position = Vector3(s0 + (s1 - s0) * (k + 0.5) / n - 0.5, 0.28, z)
	var out := {"kind": "plat", "p": p, "obj": g, "h": h}
	if (p.checkpoint >= 0 and not p.ground) or p.summit:
		var f := _group(g)
		var hgt := 3.4 if p.summit else 2.2
		var pole := _mesh(cyl_mesh(), mat(Color("3a2f28")), f)
		pole.scale = Vector3(0.07, hgt, 0.07)
		pole.position.y = hgt / 2.0
		var knob := _mesh(ball_mesh(), mat(Color("e2b04a"), {"metalness": 0.4, "roughness": 0.3}), f)
		knob.scale = Vector3.ONE * 0.14
		knob.position.y = hgt
		var q := QuadMesh.new()  # PlaneGeometry(1.4, .8, 8, 1)
		q.size = Vector2(1.4, 0.8)
		q.subdivide_width = 7
		var cloth_mat := mat(Color("fffaf2"), {"double": true, "roughness": 0.9})
		cloth_mat.set_shader_parameter("wave", true)
		var cloth := _mesh(q, cloth_mat, f)
		cloth.position = Vector3(0.72, hgt - 0.45, 0)
		if p.summit:
			for k in 5:
				var st := _mesh(dodeca_mesh(), boulder, f)
				st.scale = Vector3.ONE * (0.45 - k * 0.06)
				st.position = Vector3((k % 2 - 0.5) * 0.3, 0.3 + k * 0.35, -0.2)
		out.flag = f
		out.cloth = cloth_mat
		out.on = false
	return out


# --- monsters --------------------------------------------------------------------------------

func _crawler(g: Node3D) -> Dictionary:
	# A little beetle: three shell segments, back spikes, six legs and feelers.
	var xs := [-0.55, 0.0, 0.55]
	for k in 3:
		var s := _mesh(ball_mesh(), shell if k == 1 else shell_dark, g)
		s.scale = Vector3(0.48, 0.5 - (0.0 if k == 1 else 0.06), 0.62)
		s.position = Vector3(xs[k], 0.22, 0)
	for k in range(-2, 3):
		var s := _mesh(cone_mesh(), ink, g)
		s.scale = Vector3(0.1, 0.3, 0.1)
		s.position = Vector3(k * 0.27, 0.72 - absi(k) * 0.06, 0)
		s.rotation.z = -k * 0.25
	var legs := []
	for k in 6:
		var l := _mesh(cyl_mesh(), ink, g)
		l.scale = Vector3(0.05, 0.36, 0.05)
		l.position = Vector3((k % 3 - 1) * 0.5, -0.12, 0.42 if k < 3 else -0.42)
		l.rotation.x = 0.5 if k < 3 else -0.5
		legs.append(l)
	var head := _group(g)
	head.position = Vector3(0.95, 0.2, 0)
	var face := _mesh(ball_mesh(), shell, head)
	face.scale = Vector3(0.42, 0.4, 0.45)
	for s in [-1.0, 1.0]:
		var a := _mesh(cyl_mesh(), ink, head)
		a.scale = Vector3(0.03, 0.45, 0.03)
		a.position = Vector3(0.1, 0.5, s * 0.15)
		a.rotation.z = -0.4
		var t := _mesh(ball_mesh(), gold, head)
		t.scale = Vector3.ONE * 0.07
		t.position = Vector3(0.2, 0.72, s * 0.15)
	return {"legs": legs, "head": head, "eyes": _eyes(head, 0.15, 0.15, 0.12, 0.38)}


func _bat(g: Node3D) -> Dictionary:
	var body := _mesh(ball_mesh(), mat(Color("47405e"), {"roughness": 0.6}), g)
	body.scale = Vector3(0.42, 0.46, 0.4)
	var belly := _mesh(ball_mesh(), mat(Color("6c6386")), g)
	belly.scale = Vector3(0.26, 0.3, 0.1)
	belly.position = Vector3(0, -0.08, 0.33)
	# Membrane wings with a scalloped trailing edge.
	var wing_mat := mat(Color("3a3450"), {"double": true, "roughness": 0.7})
	var wings := []
	for s in [-1.0, 1.0]:
		var w := _group(g)
		w.position.x = s * 0.3
		var m := _mesh(wing_mesh(), wing_mat, w)
		m.scale.x = s
		wings.append(w)
	var ear := mat(Color("2c2838"))
	for s in [-1.0, 1.0]:
		var e := _mesh(cone_mesh(), ear, g)
		e.scale = Vector3(0.12, 0.34, 0.1)
		e.position = Vector3(s * 0.22, 0.5, 0)
		e.rotation.z = -s * 0.25
		var f := _mesh(cone_mesh(), white, g)
		f.scale = Vector3(0.04, 0.12, 0.04)
		f.rotation.z = PI
		f.position = Vector3(s * 0.08, -0.16, 0.36)
	return {"wings": wings, "eyes": _eyes(g, 0.12, 0.16, 0.1, 0.33)}


func _spitter(g: Node3D) -> Dictionary:
	var pot_mesh := CylinderMesh.new()  # CylinderGeometry(.62, .46, .72, 18)
	pot_mesh.top_radius = 0.62
	pot_mesh.bottom_radius = 0.46
	pot_mesh.height = 0.72
	pot_mesh.radial_segments = 18
	pot_mesh.rings = 0
	var pot := _mesh(pot_mesh, mat(Color("b8693f")), g)
	pot.position.y = -0.24
	var torus := TorusMesh.new()  # TorusGeometry(.62, .1, 8, 20), laid flat
	torus.inner_radius = 0.52
	torus.outer_radius = 0.72
	torus.rings = 20
	torus.ring_segments = 8
	var rim := _mesh(torus, mat(Color("9a4f31")), g)
	rim.position.y = 0.12
	var soil := _mesh(disc_mesh(0.58, 18), mat(Color("4a3326")), g)
	soil.position.y = 0.1
	var stem := _mesh(cyl_mesh(), mat(Color("4f7a3a")), g)
	stem.scale = Vector3(0.08, 0.8, 0.08)
	stem.position.y = 0.5
	for s in [-1.0, 1.0]:
		var l := _mesh(ball_mesh(), leaf, g)
		l.scale = Vector3(0.36, 0.07, 0.16)
		l.position = Vector3(s * 0.3, 0.42, 0)
		l.rotation.z = s * 0.4
	var head := _group(g)
	head.position.y = 1.0
	var bulb := _mesh(ball_mesh(), mat(Color("6e9f50"), {"roughness": 0.45}), head)
	bulb.scale = Vector3.ONE * 0.5
	var spot := mat(Color("c9dca0"))
	for k in 4:
		var sp := _mesh(ball_mesh(), spot, head)
		sp.scale = Vector3.ONE * 0.07
		var a := k * 1.6
		sp.position = Vector3(cos(a) * 0.3, 0.25 + sin(a) * 0.1, -0.35)
	var mouth := _group(head)
	mouth.position.x = 0.38
	var lip := _mesh(cone_mesh(), mat(Color("5a1f2a")), mouth)
	lip.scale = Vector3(0.22, 0.34, 0.22)
	lip.rotation.z = -PI / 2.0
	for s in [-1.0, 1.0]:
		var t := _mesh(cone_mesh(), white, mouth)
		t.scale = Vector3(0.04, 0.1, 0.04)
		t.position = Vector3(0.1, s * 0.1, 0)
		t.rotation.z = PI if s > 0.0 else 0.0
	return {"head": head, "mouth": mouth, "eyes": _eyes(head, 0.14, 0.15, 0.2, 0.38)}


## The ledges, monsters and icicles for a core state.
func build(state: Dictionary) -> void:
	for pc: Dictionary in pieces:
		(pc.obj as Node).queue_free()
	pieces = []
	for p: Dictionary in state.platforms:
		pieces.append(_ledge(p))
	for m: Dictionary in state.monsters:
		var g := _group()
		var parts: Dictionary
		if m.type == "crawler":
			parts = _crawler(g)
		elif m.type == "bat":
			parts = _bat(g)
		else:
			parts = _spitter(g)
		pieces.append({"kind": "monster", "m": m, "obj": g, "parts": parts})
	for i: Dictionary in state.icicles:
		var g := _group()
		var c := _mesh(cone_mesh(), ice_mat, g)
		c.scale = Vector3(0.32, 1.3, 0.32)
		c.rotation.z = PI
		var cap := _mesh(ball_mesh(), snow, g)
		cap.scale = Vector3(0.5, 0.18, 0.5)
		cap.position.y = 0.62
		pieces.append({"kind": "icicle", "i": i, "obj": g})


## Moves every piece from the state; cam: the scroll (units), only what is near the window shows.
func draw(state: Dictionary, cam: float) -> void:
	var lo := cam - BELOW
	var hi := cam + VIEW + 2.0
	var t: float = state.time
	var b: Dictionary = state.ball
	for pc: Dictionary in pieces:
		var o: Node3D = pc.obj
		if pc.kind == "plat":
			var p: Dictionary = pc.p
			var drop := 0.0
			var shake := 0.0
			var vis: bool = p.y > lo and p.y < hi
			if p.crumble != null:
				if p.crumble.state == "shaking":
					shake = sin(t * 70.0) * 0.06
				if p.crumble.state == "fallen":
					drop = p.crumble.t * p.crumble.t * 14.0
					vis = vis and p.crumble.t < 0.45
			o.visible = vis
			if not vis:
				continue
			var w: float = p.x1 - p.x0
			o.position = Vector3(X(p.x0) + w / 2.0 + shake, p.y - drop, 0)
			o.scale.x = w
			if pc.has("flag"):
				var f: Node3D = pc.flag
				f.scale.x = 1.0 / w
				f.position.x = (0.0 if p.summit else width * 0.36) / w
				var on: bool = state.won if p.summit else state.checkpoint >= p.checkpoint
				var cm: ShaderMaterial = pc.cloth
				if on != pc.on:
					pc.on = on
					cm.set_shader_parameter("albedo", Color("c8584b") if on else Color("fffaf2"))
				cm.set_shader_parameter("wave_t", t)
		elif pc.kind == "monster":
			var m: Dictionary = pc.m
			var y: float = m.plat.y + 0.45 if m.type == "crawler" else (m.plat.y + 0.6 if m.type == "spitter" else float(m.y))
			var fade := 1.0 if m.alive else maxf(0.0, 1.0 - m.t / 0.6)
			o.visible = fade > 0.0 and y > lo and y < hi
			if not o.visible:
				continue
			o.position = Vector3(X(m.x), y, 0.2)
			o.scale = Vector3.ONE * (1.0 if m.alive else fade * (1.0 + (1.0 - fade) * 0.5))
			var dx: float = b.x - m.x
			var dy: float = b.y - y
			var parts: Dictionary = pc.parts
			if m.type == "crawler":
				o.rotation.y = -0.35 if m.dir > 0 else PI + 0.35
				var legs: Array = parts.legs
				for k in legs.size():
					(legs[k] as Node3D).rotation.z = sin(m.t * 16.0 + k * 1.6) * 0.5
				look_at_eyes(parts.eyes, absf(dx), dy)
			elif m.type == "bat":
				var wings: Array = parts.wings
				for k in wings.size():
					(wings[k] as Node3D).rotation.y = (-1.0 if k else 1.0) * sin(m.t * 16.0) * 0.9
				look_at_eyes(parts.eyes, dx, dy)
			else:
				var head: Node3D = parts.head
				head.rotation.y = 0.0 if dx >= 0.0 else PI
				head.scale = Vector3.ONE * (1.0 + m.swell * 0.16)
				(parts.mouth as Node3D).scale = Vector3(1, 1.0 + m.swell * 0.8, 1.0 + m.swell * 0.8)
				look_at_eyes(parts.eyes, absf(dx), dy)
		else:
			var i: Dictionary = pc.i
			o.visible = i.state != "gone" and i.y > lo and i.y < hi
			o.position = Vector3(X(i.x) + (sin(t * 60.0) * 0.06 if i.state == "shake" else 0.0), i.y - 0.65, 0)
