class_name Park
extends Node3D
## The headset park around the court (src/reference/nature.js, built from Bruno
## Simon's folio-2025 pieces): grass ground with the stone court and the pond,
## grass blades, oak/birch/cherry trees with foliage clumps, bushes, flowers,
## fallen leaves, pebbles, pole lights, benches, lanterns and crates. Same random
## generator (Lehmer, seed 7) in the same order, so things stand where they do in
## the web game. Game units; the court centre is (0, -10).

const COURT := Vector2(0, -10)
const POND := {"x": -22.0, "z": -5.0, "rx": 7.0, "rz": 10.0}
const TREES := [["oakTreesVisual.glb", "b4b536", "d8cf3b"], ["birchTreesVisual.glb", "ff4f2b", "ff903f"],
	["cherryTreesVisual.glb", "ff6d6d", "ff9990"]]
const CLUMP_TOWARD := Vector3(0, 6, 8)

var _seed := 7
var perlin_image: Image
var perlin: ImageTexture
var spots: Array = []
var _clump_mesh: ArrayMesh
var _mesh_mats := {}
var props := {"poles": [], "benches": [], "lanterns": [], "crates": []}
var lantern_glow: ShaderMaterial
var pole_glow: ShaderMaterial


func rng() -> float:
	_seed = (_seed * 16807) % 2147483647
	return float(_seed) / 2147483647.0


func _init() -> void:
	name = "Park"


func build() -> void:
	_make_perlin()
	RenderingServer.global_shader_parameter_set("dah_perlin", perlin)
	_ground()
	_grass()
	_clump_mesh = _foliage_geometry()
	_tree_spots()
	_bushes()
	_flowers()
	_leaves()
	_pebbles()
	_props()
	for kind in TREES.size():
		_trees(kind)


# --- noise ---------------------------------------------------------------------

## Noises.js perlin: 6 cells, period 6, remapped 0.1–0.9 to 0–1, 128 x 128.
func _make_perlin(size := 128) -> void:
	var rand := func(x: float, y: float) -> Vector2:
		var a := sin(x * 127.1 + y * 311.7) * 43758.5453123
		var b := sin(x * 269.5 + y * 183.3) * 43758.5453123
		return Vector2(-1.0 + 2.0 * (a - floorf(a)), -1.0 + 2.0 * (b - floorf(b)))
	var sm := func(t: float) -> float: return t * t * (3.0 - 2.0 * t)
	perlin_image = Image.create(size, size, false, Image.FORMAT_L8)
	for j in size:
		for i in size:
			var u := float(i) / size * 6.0
			var v := float(j) / size * 6.0
			var x0 := floorf(u)
			var y0 := floorf(v)
			var fx := u - x0
			var fy := v - y0
			var lx := posmod(int(x0), 6)
			var ly := posmod(int(y0), 6)
			var hx := posmod(int(x0) + 1, 6)
			var hy := posmod(int(y0) + 1, 6)
			var d := func(c: Vector2, ox: float, oy: float) -> float: return c.x * (fx - ox) + c.y * (fy - oy)
			var sx: float = sm.call(fx)
			var n := lerpf(lerpf(d.call(rand.call(lx, ly), 0.0, 0.0), d.call(rand.call(hx, ly), 1.0, 0.0), sx),
				lerpf(d.call(rand.call(lx, hy), 0.0, 1.0), d.call(rand.call(hx, hy), 1.0, 1.0), sx), sm.call(fy)) * 0.8 + 0.5
			var val := clampf((n - 0.1) / 0.8, 0.0, 1.0)
			perlin_image.set_pixel(i, j, Color(val, val, val))
	perlin = ImageTexture.create_from_image(perlin_image)


## The same noise on the CPU (bilinear, wrapping), for the pond's real shore.
func perlin_at(u: float, v: float) -> float:
	var n := perlin_image.get_width()
	var x := fposmod(u, 1.0) * n - 0.5
	var y := fposmod(v, 1.0) * n - 0.5
	var x0 := floori(x)
	var y0 := floori(y)
	var fx := x - x0
	var fy := y - y0
	var at := func(i: int, j: int) -> float: return perlin_image.get_pixel(posmod(i, n), posmod(j, n)).r
	return lerpf(lerpf(at.call(x0, y0), at.call(x0 + 1, y0), fx), lerpf(at.call(x0, y0 + 1), at.call(x0 + 1, y0 + 1), fx), fy)


static func pond_at(x: float, z: float) -> float:
	return 1.0 - Vector2((x - POND.x) / POND.rx, (z - POND.z) / POND.rz).length()


## Water depth for the ball (0 on land), with the noisy shore the ground draws.
func depth(x: float, z: float) -> float:
	var pd := pond_at(x, z) + (perlin_at(x * 0.045, z * 0.045) - 0.5) * 0.35
	return pd if pd > 0.005 else 0.0


# --- ground and grass ------------------------------------------------------------

func _ground() -> void:
	var m := MeshInstance3D.new()
	m.name = "Ground"
	var q := PlaneMesh.new()
	q.size = Vector2(600, 600)
	m.mesh = q
	m.position.y = -0.02
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ground.gdshader")
	mat.set_shader_parameter("slabs", load("res://assets/textures/slabs.png"))
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)


## Grass.js: 250 x 250 blades over 60 x 60 around the court, three vertices each.
func _grass() -> void:
	var sub := 250
	var size := 60.0
	var frag := size / sub
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	verts.resize(sub * sub * 3)
	uvs.resize(sub * sub * 3)
	var k := 0
	for ix in sub:
		for iz in sub:
			var fx := (float(ix) / sub - 0.5) * size + frag * 0.5 + COURT.x
			var fz := (float(iz) / sub - 0.5) * size + frag * 0.5 + COURT.y
			var x := fx + (rng() - 0.5) * frag
			var z := fz + (rng() - 0.5) * frag
			var r := rng()
			for v in 3:
				verts[k] = Vector3(x, 0, z)
				uvs[k] = Vector2(v, r)
				k += 1
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.custom_aabb = AABB(Vector3(-40, -2, -50), Vector3(80, 4, 80))
	var mi := MeshInstance3D.new()
	mi.name = "Grass"
	mi.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grass.gdshader")
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# --- foliage ---------------------------------------------------------------------

## Foliage.js: 80 leaf planes per clump, 0.8 wide, scattered in a unit ball, with
## normals bent outward (own generator, seed 11).
func _foliage_geometry() -> ArrayMesh:
	var s := [11]  # in an array: lambdas copy captured locals
	var r := func() -> float:
		s[0] = (s[0] * 16807) % 2147483647
		return float(s[0]) / 2147483647.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [Vector2(-0.4, 0.4), Vector2(0.4, 0.4), Vector2(-0.4, -0.4), Vector2(0.4, -0.4)]
	var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]  # three.js uv (0,1)… flipped to Godot's v
	for i in 80:
		var radius: float = 1.0 - pow(r.call(), 3)
		var phi: float = PI * 2.0 * r.call()
		var theta: float = PI * r.call()
		var pos := Vector3(radius * sin(phi) * sin(theta), radius * cos(phi), radius * sin(phi) * cos(theta))
		var rot: float = r.call() * 9999.0
		var nrm := pos.normalized()
		var pts := []
		for c in corners:
			var v := Vector3(c.x * cos(rot) - c.y * sin(rot), c.x * sin(rot) + c.y * cos(rot), 0.0) + pos
			pts.append(v)
		var n := Vector3(0, 0, 1).lerp(nrm, 0.85)
		for idx in [0, 2, 1, 2, 3, 1]:
			st.set_normal(n)
			st.set_uv(uv[idx])
			st.add_vertex(pts[idx])
	return st.commit()


func _foliage_material(a: String, b: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/foliage.gdshader")
	mat.set_shader_parameter("foliage_sdf", load("res://assets/textures/foliageSDF.png"))
	mat.set_shader_parameter("color_a", Color(a))
	mat.set_shader_parameter("color_b", Color(b))
	return mat


## A clump faces the player's usual view at a random roll (Foliage.js).
func _clump(pos: Vector3, size: float) -> Transform3D:
	var angle := PI * 2.0 * rng()
	var up := Vector3(sin(angle), cos(angle), 0)
	var z := (CLUMP_TOWARD - pos).normalized()
	var x := up.cross(z).normalized()
	var y := z.cross(x)
	return Transform3D(Basis(x, y, z).scaled(Vector3.ONE * size), pos)


func _multimesh(mesh: Mesh, xforms: Array, mat: Material, label: String, colors := []) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if mm.use_custom_data:
			mm.set_instance_custom_data(i, colors[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = label
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


# --- trees, bushes, flowers, leaves, pebbles ------------------------------------

func _tree_spots() -> void:
	var i := 0
	while i < 90 and spots.size() < 42:
		i += 1
		var a := rng() * PI * 2.0
		var r := 20.0 + rng() * 30.0
		var x := COURT.x + cos(a) * r
		var z := COURT.y + sin(a) * r
		if absf(x - COURT.x) < 14.0 and z > -30.0 and z < 26.0:
			continue
		if pond_at(x, z) > -0.45:
			continue
		spots.append({"x": x, "z": z, "rot": rng() * PI * 2.0, "scale": 0.85 + rng() * 0.4})
	# A wood behind the target, beyond the stone.
	for k in 24:
		var x := COURT.x + (rng() - 0.5) * 40.0
		var z := -28.0 - rng() * 18.0
		spots.append({"x": x, "z": z, "rot": rng() * PI * 2.0, "scale": 0.8 + rng() * 0.5})


func _bushes() -> void:
	var mats := []
	var i := 0
	while i < 60 and mats.size() < 46:
		i += 1
		var a := rng() * PI * 2.0
		var r := 15.0 + rng() * 24.0
		var x := COURT.x + cos(a) * r
		var z := COURT.y + sin(a) * r
		if absf(x - COURT.x) < 12.0 and z > -29.0 and z < 25.0:
			continue
		if pond_at(x, z) > -0.3:
			continue
		var y := 0.6 + rng() * 0.7
		var size := 0.9 + rng() * 0.3
		mats.append(_clump(Vector3(x, y, z), size))
	_multimesh(_clump_mesh, mats, _foliage_material("b4b536", "d8cf3b"), "Bushes")


func _tinted_material(mode: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/tinted.gdshader")
	mat.set_shader_parameter("mode", mode)
	return mat


## Flowers.js: little white flowers, eight planes to a patch.
func _flowers() -> void:
	var s := [5]  # in an array: lambdas copy captured locals
	var r := func() -> float:
		s[0] = (s[0] * 16807) % 2147483647
		return float(s[0]) / 2147483647.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 8:
		var phi: float = PI * 0.2 * r.call()
		var theta: float = PI * 2.0 * r.call()
		var dir := Vector3(sin(phi) * sin(theta), cos(phi), sin(phi) * cos(theta))
		var pos: Vector3 = dir * (1.0 + (r.call() - 0.5) * 0.5)
		pos.y -= 0.75
		var sc: float = 1.0 + (r.call() - 0.5)
		# three.js Matrix4.lookAt(eye=dir, target=0): z axis = dir.
		var z := dir.normalized()
		var x := Vector3.UP.cross(z).normalized()
		if x.length_squared() < 1e-6:
			x = Vector3.RIGHT
		var y := z.cross(x)
		var b := Basis(x, y, z).scaled(Vector3.ONE * sc)
		var pts := [Vector3(-0.06, 0.06, 0), Vector3(0.06, 0.06, 0), Vector3(-0.06, -0.06, 0), Vector3(0.06, -0.06, 0)]
		for idx in [0, 2, 1, 2, 3, 1]:
			st.set_normal(z)
			st.add_vertex(b * pts[idx] + pos)
	var mesh := st.commit()
	var mats := []
	var tints := []
	var c := 0
	while c < 200 and mats.size() < 420:
		c += 1
		var cx := COURT.x + (rng() - 0.5) * 56.0
		var cz := COURT.y + (rng() - 0.5) * 56.0
		if absf(cx - COURT.x) < 9.5 or pond_at(cx, cz) > -0.3:
			continue
		var k := 3 + int(floor(rng() * 8.0))
		var tint := Color("ffffff") if rng() < 0.8 else (Color("c9d4ff") if rng() < 0.5 else Color("ffd6e8"))
		for j in k:
			var rot := PI * 2.0 * rng()
			var px := cx + (rng() - 0.5) * 3.0
			var pz := cz + (rng() - 0.5) * 3.0
			var scl := 0.6 + rng() * 0.4
			mats.append(Transform3D(Basis(Vector3.UP, rot).scaled(Vector3.ONE * scl), Vector3(px, 0, pz)))
			tints.append(tint.srgb_to_linear())
	_multimesh(mesh, mats, _tinted_material(1), "Flowers", tints)


## Leaves.js: fallen leaves in two reds, most of them under the trees.
func _leaves() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# three.js PlaneGeometry(1,1) with the top edge pushed right and the bottom left, laid flat.
	var pts := [Vector3(-0.5 + 0.15, 0, -0.5), Vector3(0.5 + 0.15, 0, -0.5), Vector3(-0.5 - 0.15, 0, 0.5), Vector3(0.5 - 0.15, 0, 0.5)]
	for idx in [0, 2, 1, 2, 3, 1]:
		st.set_normal(Vector3.UP)
		st.add_vertex(pts[idx])
	var mesh := st.commit()
	var mats := []
	var cols := []
	var a := Color("95513a")
	var b := Color("f56a3a")
	var kx := -0.384 / 0.808 * 2.0
	var kz := -0.441 / 0.808 * 2.0
	var i := 0
	while i < 700 and mats.size() < 520:
		var x: float
		var z: float
		if i % 5 < 3 and not spots.is_empty():
			var t: Dictionary = spots[int(floor(rng() * spots.size()))]
			var ang := rng() * PI * 2.0
			var dd := sqrt(rng()) * 3.5
			x = t.x + cos(ang) * dd + kx
			z = t.z + sin(ang) * dd + kz
		else:
			x = COURT.x + (rng() - 0.5) * 60.0
			z = COURT.y + (rng() - 0.5) * 60.0
		i += 1
		if pond_at(x, z) > -0.12:
			continue
		var y := 0.025 + rng() * 0.01
		var rot := rng() * PI * 2.0
		var sc := 0.25 * (0.5 + rng() * 0.5)
		mats.append(Transform3D(Basis(Vector3.UP, rot).scaled(Vector3.ONE * sc), Vector3(x, y, z)))
		cols.append(a.lerp(b, rng()).srgb_to_linear())
		rng()
		rng()  # the tilt of the normal (not used for these flat leaves' shading here)
	_multimesh(mesh, mats, _tinted_material(0), "Leaves", cols)


## Pale faceted stones beside the stone and around the pond.
func _pebbles() -> void:
	var mats := []
	var put := func(x: float, z: float, s: float) -> void:
		var rot := Vector3(rng() * 0.6, rng() * PI * 2.0, rng() * 0.6)
		var sc := Vector3(s * (0.8 + rng() * 0.5), s * (0.45 + rng() * 0.3), s * (0.8 + rng() * 0.5))
		mats.append(Transform3D(Basis.from_euler(rot, EULER_ORDER_XYZ).scaled(sc), Vector3(x, s * 0.25, z)))
	for i in 18:
		var a := rng() * PI * 2.0
		var k := 1.06 + rng() * 0.12
		put.call(POND.x + cos(a) * POND.rx * k, POND.z + sin(a) * POND.rz * k, 0.12 + rng() * 0.22)
	for i in 16:
		var sd := -1.0 if rng() < 0.5 else 1.0
		var x := COURT.x + sd * (10.2 + rng() * 6.0)
		var z := COURT.y + (rng() - 0.5) * 44.0
		var n := 1 + int(floor(rng() * 3.0))
		for j in n:
			put.call(x + (rng() - 0.5) * 0.8, z + (rng() - 0.5) * 0.8, 0.08 + rng() * 0.16)
	var ico := SphereMesh.new()
	ico.radius = 1.0
	ico.height = 2.0
	ico.radial_segments = 6
	ico.rings = 3
	var white := Color("f3eeff").srgb_to_linear()
	var cols := []
	for m in mats:
		cols.append(white)
	_multimesh(ico, mats, _tinted_material(0), "Pebbles", cols)


# --- models ----------------------------------------------------------------------

## Mesh parts of a GLB (deduplicated: the source files hold several copies of a
## part at the same place), each with its transform inside the model.
func _model_parts(file: String) -> Array:
	var scene: PackedScene = load("res://assets/models/" + file)
	var root := scene.instantiate()
	var parts := []
	var seen := {}
	var stack := [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var node: Node = item[0]
		var xf: Transform3D = item[1]
		if node is Node3D:
			xf = xf * (node as Node3D).transform
		if node is MeshInstance3D and (node as MeshInstance3D).mesh:
			var mi := node as MeshInstance3D
			var key := "%d|%s" % [mi.mesh.get_rid().get_id(), str(xf)]
			if not seen.has(key):
				seen[key] = true
				parts.append({"name": String(mi.name) + " " + String(mi.get_parent().name), "mesh": mi.mesh, "xf": xf})
		for c in node.get_children():
			stack.append([c, xf])
	root.free()
	return parts


func _palette_material(mesh: Mesh) -> Material:
	var src := mesh.surface_get_material(0)
	var tex: Texture2D = null
	if src is BaseMaterial3D:
		tex = (src as BaseMaterial3D).albedo_texture
	var key := str(tex.get_rid().get_id()) if tex else "none"
	if not _mesh_mats.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/motri_mesh.gdshader")
		mat.set_shader_parameter("map", tex)
		_mesh_mats[key] = mat
	return _mesh_mats[key]


func _trees(kind: int) -> void:
	var file: String = TREES[kind][0]
	var parts := _model_parts(file)
	var body = null
	var leaves := []
	for p in parts:
		if "treeBody" in p.name:
			body = p
		elif "treeLeaves" in p.name:
			leaves.append(p)
	if body == null:
		return
	var mine := []
	for i in spots.size():
		if i % 3 == kind:
			mine.append(spots[i])
	var bodies := []
	var clumps := []
	for s in mine:
		var ref := Transform3D(Basis(Vector3.UP, s.rot).scaled(Vector3.ONE * s.scale), Vector3(s.x, 0, s.z))
		bodies.append(ref * body.xf)
		for leaf in leaves:
			var w: Transform3D = ref * leaf.xf
			clumps.append(_clump(w.origin, w.basis.get_scale().x))
	_multimesh(body.mesh, bodies, _palette_material(body.mesh), "Trees" + str(kind))
	_multimesh(_clump_mesh, clumps, _foliage_material(TREES[kind][1], TREES[kind][2]), "Foliage" + str(kind))


## Pole lights line the stone, benches with a lantern at each end sit beyond them,
## crates wait at the sides (PoleLights.js, Benches.js, Lanterns.js, ExplosiveCrates.js).
func _props() -> void:
	var cx := COURT.x
	var cz := COURT.y
	for s in [-1.0, 1.0]:
		for z in [4.0, -7.0, -18.0]:
			props.poles.append({"x": cx + s * 10.3, "z": z, "rot": 0.0})
		for z in [-1.5, -12.5]:
			props.benches.append({"x": cx + s * 11.9, "z": z, "rot": -s * PI / 2})
			props.lanterns.append({"x": cx + s * 11.9, "z": z + 1.75, "rot": 0.4 * s})
			props.lanterns.append({"x": cx + s * 11.9, "z": z - 1.75, "rot": -0.3 * s})
	for xz in [[-7.4, -4.0], [7.4, -14.0]]:
		var x: float = xz[0]
		var z: float = xz[1]
		var sd := signf(x)
		props.crates.append({"x": cx + x, "z": cz + z + 10 - 0.45, "y": 0.0, "rot": 0.2})
		props.crates.append({"x": cx + x + sd * 0.15, "z": cz + z + 10 + 0.45, "y": 0.0, "rot": -0.15})
		props.crates.append({"x": cx + x + sd * 0.05, "z": cz + z + 10, "y": 1.0, "rot": 0.5})
	lantern_glow = ShaderMaterial.new()
	lantern_glow.shader = load("res://shaders/glow.gdshader")
	pole_glow = ShaderMaterial.new()
	pole_glow.shader = lantern_glow.shader
	pole_glow.set_shader_parameter("on", 0.0)  # pole glass lights up at night
	_build_prop("poleLight.glb", props.poles, 1.0, 1.78, pole_glow)
	_build_prop("lantern.glb", props.lanterns, 0.6, 0.51, lantern_glow)
	_build_prop("bench.glb", props.benches, 0.75, 0.71, null)
	_build_prop("explosiveCrate.glb", props.crates, 0.7, 0.53, null)


func _build_prop(file: String, list: Array, scale: float, lift: float, glow: Material) -> void:
	for p in _model_parts(file):
		var src := (p.mesh as Mesh).surface_get_material(0)
		var emissive: bool = src != null and "emissive" in src.resource_name.to_lower()
		var xforms := []
		for it in list:
			var b := Basis(Vector3.UP, it.rot).scaled(Vector3.ONE * scale)
			xforms.append(Transform3D(b, Vector3(it.x, it.get("y", 0.0) + lift * scale, it.z)) * p.xf)
		var mat: Material = glow if emissive and glow else _palette_material(p.mesh)
		_multimesh(p.mesh, xforms, mat, file.get_basename())
