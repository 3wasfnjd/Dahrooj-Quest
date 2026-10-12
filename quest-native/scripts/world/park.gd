class_name Park
extends Node3D
## The headset park around the court (src/reference/nature.js, built from Bruno
## Simon's folio-2025 pieces): grass ground with the stone court and the pond,
## grass blades, oak/birch/cherry trees with foliage clumps, bushes, flowers,
## fallen leaves, pebbles, pole lights, benches, lanterns and crates. Same random
## generator (Lehmer, seed 7) in the same order, so things stand where they do in
## the web game. Game units; the court centre is (0, -10).
##
## And everything that moves (nature.js api): the props (collide, collide_crates,
## explode, reset, the exploded signal / on_explode), the pond's water lines, ripples
## and splashes, tracks where balls roll (mark), the baked drop shadows, the day cycle
## and the weather (set_settings, sky_state), rain and snow, and the night lights
## (pole glass, fireflies, pools of light, moonlight and a lantern by the player).
## Call update(dt, eye) every frame while the park shows (eye = the head in game units).

## A crate went up: where, the blast radius, and whether the player set it off.
signal exploded(at: Vector3, radius: float, by_player: bool)

const COURT := Vector2(0, -10)
const POND := {"x": -22.0, "z": -5.0, "rx": 7.0, "rz": 10.0}
const TREES := [["oakTreesVisual.glb", "b4b536", "d8cf3b"], ["birchTreesVisual.glb", "ff4f2b", "ff903f"],
	["cherryTreesVisual.glb", "ff6d6d", "ff9990"]]
const CLUMP_TOWARD := Vector3(0, 6, 8)
## Motri's light direction (Ligthing.js phi .63, theta .72).
const LIGHT_PHI := 0.63
const LIGHT_THETA := 0.72
## The game's own lights are calibrated on the day preset (main.gd: sun 0.75 for
## three's 2.16, ambient 0.6 for the hemisphere's 1.89).
const SUN_K := 0.75 / 2.16
const AMBIENT_K := 0.6 / 1.89
const RAIN_COUNT := 2048

var _seed := 7
var perlin_image: Image
var perlin: ImageTexture
var spots: Array = []
var _clump_mesh: ArrayMesh
var _mesh_mats := {}
var props := {"poles": [], "benches": [], "lanterns": [], "crates": []}
var lantern_glow: ShaderMaterial
var pole_glow: ShaderMaterial
## Also called when a crate goes up: func(at: Vector3, radius: float, by_player: bool).
var on_explode := Callable()
var prop_set: ParkProps
var shadows: ParkShadows
var tracks: ParkTracks
var water: ParkWater
var cycle := ParkCycle.new()
var light_dir := Vector3(sin(LIGHT_PHI) * sin(LIGHT_THETA), cos(LIGHT_PHI), sin(LIGHT_PHI) * cos(LIGHT_THETA)).normalized()
var eye := Vector3(0, 3.2, 9.7)
var _materials_with_slab: Array = []
var _slab := Vector4(0, -2.5, 9, 9)
var _rain: MeshInstance3D
var _rain_mat: ShaderMaterial
var _rain_time := 0.0
var _snow: MeshInstance3D
var _snow_mat: ShaderMaterial
var _snow_elevation := -1.0
var _moon: DirectionalLight3D
var _lantern: OmniLight3D


func rng() -> float:
	_seed = (_seed * 16807) % 2147483647
	return float(_seed) / 2147483647.0


func _init() -> void:
	name = "Park"


func build() -> void:
	_make_perlin()
	RenderingServer.global_shader_parameter_set("dah_perlin", perlin)
	shadows = ParkShadows.new()
	add_child(shadows)
	shadows.setup(COURT, light_dir)
	tracks = ParkTracks.new(COURT)
	water = ParkWater.new()
	add_child(water)
	water.setup()
	var G := RenderingServer
	G.global_shader_parameter_set("dah_tracks", tracks.texture)
	G.global_shader_parameter_set("dah_track_area", Vector3(COURT.x, COURT.y, ParkTracks.SIZE))
	G.global_shader_parameter_set("dah_shadow", shadows.texture)
	G.global_shader_parameter_set("dah_shadow_area", Vector3(COURT.x, COURT.y, ParkShadows.SIZE))
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
	_weather()
	_night_lights()
	update(0.0)


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
	_materials_with_slab.append(mat)
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
	_materials_with_slab.append(mat)
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
		shadows.add_blob(x, z, y * 0.6, size, 0.8)
	_multimesh(_clump_mesh, mats, _foliage_material("b4b536", "d8cf3b"), "Bushes")


func _tinted_material(mode: int, shadow_k := 0.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/tinted.gdshader")
	mat.set_shader_parameter("mode", mode)
	mat.set_shader_parameter("shadow_k", shadow_k)
	if mode == 1:
		_materials_with_slab.append(mat)
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
	_multimesh(mesh, mats, _tinted_material(1, 0.8), "Flowers", tints)


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
	_multimesh(mesh, mats, _tinted_material(0, 0.85), "Leaves", cols)


## Pale faceted stones beside the stone and around the pond.
func _pebbles() -> void:
	var mats := []
	var put := func(x: float, z: float, s: float) -> void:
		var rot := Vector3(rng() * 0.6, rng() * PI * 2.0, rng() * 0.6)
		var sc := Vector3(s * (0.8 + rng() * 0.5), s * (0.45 + rng() * 0.3), s * (0.8 + rng() * 0.5))
		mats.append(Transform3D(Basis.from_euler(rot, EULER_ORDER_XYZ).scaled(sc), Vector3(x, s * 0.25, z)))
		shadows.add_blob(x, z, sc.y * 0.8, (sc.x + sc.z) * 0.45, 0.6)
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
	_multimesh(ico, mats, _tinted_material(0, 0.7), "Pebbles", cols)


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
		var crown := []
		for leaf in leaves:
			var w: Transform3D = ref * leaf.xf
			clumps.append(_clump(w.origin, w.basis.get_scale().x))
			crown.append([w.origin, w.basis.get_scale().x])
		# Its shadow: the trunk up to the lowest leaves, then a soft blob for each clump of leaves.
		var low := 9.0
		for c: Array in crown:
			low = minf(low, (c[0] as Vector3).y)
		shadows.add_stick(s.x, s.z, 0.0, low, 0.32 * float(s.scale), 0.8)
		for c: Array in crown:
			var o: Vector3 = c[0]
			shadows.add_blob(o.x, o.z, o.y, float(c[1]) * 1.2, 0.85)
	_multimesh(body.mesh, bodies, _palette_material(body.mesh), "Trees" + str(kind))
	_multimesh(_clump_mesh, clumps, _foliage_material(TREES[kind][1], TREES[kind][2]), "Foliage" + str(kind))


## The props and their behaviour (park_props.gd).
func _props() -> void:
	prop_set = ParkProps.new()
	add_child(prop_set)
	prop_set.setup(self, COURT)
	lantern_glow = prop_set.lantern_glow
	pole_glow = prop_set.pole_glow


# --- weather and night lights -------------------------------------------------------

## RainLines.js (2048 quads falling from 20, wrapped around the view; short and slow
## for snow) and Snow.js (drifts on the ground that rise while it snows).
func _weather() -> void:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var idx := PackedInt32Array()
	verts.resize(RAIN_COUNT * 4)
	uvs.resize(RAIN_COUNT * 4)
	uv2s.resize(RAIN_COUNT * 4)
	idx.resize(RAIN_COUNT * 6)
	for l in RAIN_COUNT:
		var x := randf()
		var z := randf()
		var r := randf()
		for v in 4:
			verts[l * 4 + v] = Vector3(x, 0, z)
			uvs[l * 4 + v] = Vector2(1.0 if v == 0 or v == 1 else 0.0, 1.0 if v == 0 or v == 3 else 0.0)
			uv2s[l * 4 + v] = Vector2(r, 0)
		var k := l * 4
		var q := l * 6
		idx[q] = k
		idx[q + 1] = k + 3
		idx[q + 2] = k + 2
		idx[q + 3] = k + 2
		idx[q + 4] = k + 1
		idx[q + 5] = k
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_TEX_UV2] = uv2s
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.custom_aabb = AABB(Vector3(-200, -5, -200), Vector3(400, 130, 400))
	_rain_mat = ShaderMaterial.new()
	_rain_mat.shader = load("res://shaders/rain.gdshader")
	_rain_mat.render_priority = 1
	_rain = MeshInstance3D.new()
	_rain.name = "WeatherParticles"
	_rain.mesh = mesh
	_rain.material_override = _rain_mat
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain.visible = false
	add_child(_rain)
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	plane.subdivide_width = 159
	plane.subdivide_depth = 159
	plane.custom_aabb = AABB(Vector3(-200, -2, -200), Vector3(400, 4, 400))
	_snow_mat = ShaderMaterial.new()
	_snow_mat.shader = load("res://shaders/snow.gdshader")
	_snow = MeshInstance3D.new()
	_snow.name = "SnowGround"
	_snow.mesh = plane
	_snow.material_override = _snow_mat
	_snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_snow.visible = false
	add_child(_snow)


## Night lights for the game's own models: moonlight from above and a soft warm
## lantern that follows the player (off by day).
func _night_lights() -> void:
	_moon = DirectionalLight3D.new()
	_moon.name = "Moon"
	_moon.light_color = Color("c9d4ff")
	_moon.light_energy = 0.0
	_moon.shadow_enabled = false
	_moon.transform = Transform3D(Basis.looking_at(Vector3(6, -14, -6).normalized(), Vector3.UP), Vector3(-6, 14, 6))
	_moon.visible = false
	add_child(_moon)
	_lantern = OmniLight3D.new()
	_lantern.name = "Lantern"
	_lantern.light_color = Color("ffd9a0")
	_lantern.light_energy = 0.0
	_lantern.omni_attenuation = 1.6
	_lantern.shadow_enabled = false
	_lantern.top_level = true
	_lantern.visible = false
	add_child(_lantern)


# --- the frame -----------------------------------------------------------------------

## Every frame while the park shows: eye = the head in game units (main.gd's
## w2g * head.origin). Sets the park's shader globals (light, sky, fog, stars, wind).
func update(dt: float, eye_at := Vector3(INF, 0, 0)) -> void:
	if eye_at.x != INF:
		eye = eye_at
	cycle.update(dt)
	_set_globals()
	var nt := cycle.night
	prop_set.update(dt, nt)
	water.update(dt)
	tracks.update(dt)
	# RainLines.js
	var w := cycle.w
	var snow_ratio := 1.0 - pow(1.0 - maxf(w.snow, 0.0), 4.0)
	var visible_ratio := pow(float(w.rain), 2.0)
	var speed := lerpf(ParkCycle.remap_clamp(w.rain, 0.0, 1.0, 0.2, 0.4), 0.05, snow_ratio)
	_rain_time += dt * speed
	_rain.visible = visible_ratio > 0.00001
	if _rain.visible:
		_rain_mat.set_shader_parameter("visible_ratio", visible_ratio)
		_rain_mat.set_shader_parameter("len", lerpf(ParkCycle.remap_clamp(w.rain, 0.0, 1.0, 1.0, 3.0), 0.03, snow_ratio))
		_rain_mat.set_shader_parameter("incline", ParkCycle.remap_clamp(w.wind, 0.0, 1.0, 0.1, 0.4))
		_rain_mat.set_shader_parameter("center", Vector2(eye.x, eye.z))
		_rain_mat.set_shader_parameter("local_time", _rain_time)
	# Snow.js: the ground layer rises while it snows and melts away otherwise.
	var forced := dt * 0.045 if cycle.weather == "snow" else (-dt * 0.05 if cycle.weather == "clear" or cycle.weather == "rain" else 0.0)
	_snow_elevation = clampf(_snow_elevation + float(w.snow) * cycle.progress_delta * 10.0 + forced, -1.0, 0.5)
	_snow.visible = _snow_elevation > -0.9
	if _snow.visible:
		_snow_mat.set_shader_parameter("snow_elevation", _snow_elevation)
		_snow_mat.set_shader_parameter("center", Vector2(roundf(eye.x / 0.375) * 0.375, roundf(eye.z / 0.375) * 0.375))
	# Night lights.
	var scale_k := global_transform.basis.get_scale().x if is_inside_tree() else 1.0
	_moon.light_energy = nt * 0.45 * SUN_K
	_moon.visible = nt > 0.001
	_lantern.light_energy = nt * 1.1 * SUN_K
	_lantern.visible = nt > 0.001
	if _lantern.visible and is_inside_tree():
		_lantern.global_position = global_transform * Vector3(eye.x, eye.y + 0.5, eye.z - 1.5)
		_lantern.omni_range = 16.0 * scale_k


func _set_globals() -> void:
	var G := RenderingServer
	var d := cycle.d
	G.global_shader_parameter_set("dah_light_color", _lin(d.light))
	G.global_shader_parameter_set("dah_light_intensity", cycle.light_intensity)
	G.global_shader_parameter_set("dah_shadow_color", _lin(d.shadow))
	G.global_shader_parameter_set("dah_horizon", _lin(cycle.horizon))
	G.global_shader_parameter_set("dah_zenith", _lin(cycle.zenith))
	G.global_shader_parameter_set("dah_fog_a", _lin(d.fog_a))
	G.global_shader_parameter_set("dah_light_dir", light_dir)
	G.global_shader_parameter_set("dah_sun_dir", cycle.sun_dir)
	G.global_shader_parameter_set("dah_fog_near", cycle.fog_near)
	G.global_shader_parameter_set("dah_fog_far", cycle.fog_far)
	G.global_shader_parameter_set("dah_stars", cycle.stars)
	G.global_shader_parameter_set("dah_night", cycle.night)
	G.global_shader_parameter_set("dah_wind_strength", cycle.wind_strength)
	G.global_shader_parameter_set("dah_wind_time", cycle.wind_time)


## Shader globals take linear colours (the park shades in linear light, as three.js does).
static func _lin(c: Color) -> Vector3:
	var l := c.srgb_to_linear()
	return Vector3(l.r, l.g, l.b)


## The current light, sky and fog: linear Vector3 colours for shaders, sRGB Colors
## and energies for Godot's own lights (calibrated so the day preset gives main.gd's
## sun 0.75 and ambient 0.6). The park sets its shader globals itself in update().
func sky_state() -> Dictionary:
	var d := cycle.d
	var nt := cycle.night
	var li: float = d.intensity
	var k := 1.0 / 3.0 if li > 2.0 else 1.0
	var light: Color = d.light
	var shadow: Color = d.shadow
	var hemi := light.lerp(Color.WHITE, 0.35 + nt * 0.25)
	var hemi_ground := shadow.lerp(Color("c1c8d6"), 0.6)
	var hemi_i := maxf(1.65, 1.4 * li * k)
	var sun_c := light.lerp(Color("c9d4ff"), nt * 0.6)
	var sun_i := maxf(1.15, 1.6 * li * k)
	return {
		"light_color": _lin(light), "light_intensity": cycle.light_intensity, "shadow_color": _lin(shadow),
		"horizon": _lin(cycle.horizon), "zenith": _lin(cycle.zenith), "fog_a": _lin(d.fog_a), "fog_b": _lin(d.fog_b),
		"light_dir": light_dir, "sun_dir": cycle.sun_dir, "fog_near": cycle.fog_near, "fog_far": cycle.fog_far,
		"stars": cycle.stars, "night": nt, "wind_strength": cycle.wind_strength, "wind_time": cycle.wind_time,
		"fog_color": cycle.horizon, "fog_depth_begin": maxf(1.0, cycle.fog_near), "fog_depth_end": cycle.fog_far + 10.0,
		"sun_color": sun_c, "sun_energy": sun_i * SUN_K, "sun_intensity_three": sun_i,
		"hemi_color": hemi, "hemi_ground": hemi_ground, "hemi_intensity_three": hemi_i,
		"ambient_color": hemi.lerp(hemi_ground, 0.35), "ambient_energy": hemi_i * AMBIENT_K,
		"moon_energy": nt * 0.45 * SUN_K, "lantern_energy": nt * 1.1 * SUN_K,
		"day_p": cycle.day_p, "time": cycle.time, "weather": cycle.weather,
	}


# --- settings ----------------------------------------------------------------------------

## time: auto | day | dusk | night | dawn; weather: auto | clear | rain | snow.
func set_settings(d: Dictionary) -> void:
	cycle.set_settings(d)


func settings() -> Dictionary:
	return {"time": cycle.time, "weather": cycle.weather}


## Weather.js state: temperature, humidity, clouds, wind, rain, snow.
func weather() -> Dictionary:
	return cycle.w


## How dark it is (0 day, 1 night), for the nature sounds.
func night() -> float:
	return cycle.night


## The stone reaches from behind the player to just past the target at far_z.
func set_pitch(far_z: float, near_z := 5.0) -> void:
	var z0 := far_z - 1.5
	var z1 := maxf(5.0, near_z)
	var s := Vector4(COURT.x, (z0 + z1) / 2.0, 9.0, (z1 - z0) / 2.0)
	if s.is_equal_approx(_slab):
		return
	_slab = s
	for m: ShaderMaterial in _materials_with_slab:
		m.set_shader_parameter("slab_area", s)


# --- tracks, the pond, the props ------------------------------------------------------

## Press a track at (x, z): radius in game units, strength 0–1.
func mark(x: float, z: float, radius: float, strength: float) -> void:
	tracks.mark(x, z, radius, strength)


## How pressed the ground is at (x, z), 0–1.
func track_at(x: float, z: float) -> float:
	return tracks.at(x, z)


func water_at(x: float, z: float) -> float:
	return depth(x, z)


## A white line where a ball of radius r centred y above the surface meets the water.
func water_line(x: float, y: float, z: float, r: float) -> void:
	if depth(x, z) > 0.0:
		water.line(x, y, z, r)


## Rings from a splash, strength 0–1.
func splash(x: float, z: float, k: float) -> void:
	var s := clampf(k, 0.15, 1.0)
	water.ripple(x, z, 0.2, 1.0 + 2.2 * s, 1.1 + s)
	water.ripple(x, z, 0.1, 0.6 + 1.4 * s, 0.8 + s * 0.6)
	if s > 0.5:
		water.ripple(x, z, 0.05, 0.4 + s, 0.7)


## A ring as something bobs in the water.
func bob(x: float, z: float, r: float) -> void:
	water.ripple(x, z, r * 0.9, r * 2.6, 1.8)


func ripple(x: float, z: float, r0: float, r1: float, life: float) -> void:
	water.ripple(x, z, r0, r1, life)


## Ball (position p, velocity v, radius r) against poles, benches, lanterns and crates.
## Returns {"hit": bool, "p": Vector3, "v": Vector3} (p and v pushed out / bounced).
func collide(p: Vector3, v: Vector3, r: float, by_player := true) -> Dictionary:
	return prop_set.collide(p, v, r, by_player)


func collide_crates(p: Vector3, v: Vector3, r: float, by_player := true) -> Dictionary:
	return prop_set.collide_crates(p, v, r, by_player)


## Light crate i's fuse.
func explode(i: int, by_player := true) -> void:
	prop_set.explode(i, by_player)


## Every crate back in place.
func reset() -> void:
	prop_set.reset()


func _crate_exploded(at: Vector3, radius: float, by_player: bool) -> void:
	exploded.emit(at, radius, by_player)
	if on_explode.is_valid():
		on_explode.call(at, radius, by_player)
