class_name StageArt
extends RefCounted
## Drawing helpers shared by the stages (src/reference/stage-art.js): chalk lines on
## the ground, posts and bars, and a springy net. Game units.

const INK := Color("2c2d3d")
static var _line_mat: StandardMaterial3D
static var _post_mat: StandardMaterial3D
static var _net_mat: StandardMaterial3D


static func line_mat() -> StandardMaterial3D:
	if _line_mat == null:
		_line_mat = StandardMaterial3D.new()
		_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_line_mat.albedo_color = Color(INK, 0.18)
		_line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_line_mat.render_priority = -1
	return _line_mat


static func post_mat() -> StandardMaterial3D:
	if _post_mat == null:
		_post_mat = StandardMaterial3D.new()
		_post_mat.albedo_color = Color("f6eee2")
		_post_mat.roughness = 0.7
		_post_mat.emission_enabled = true
		_post_mat.emission = Color("f6eee2")
		_post_mat.emission_energy_multiplier = 0.025
	return _post_mat


static func net_mat() -> StandardMaterial3D:
	if _net_mat == null:
		_net_mat = StandardMaterial3D.new()
		_net_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_net_mat.albedo_color = Color(Color("f3eddf"), 0.65)
		_net_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_net_mat.no_depth_test = false
	return _net_mat


static func ground_line(grp: Node3D, x1: float, z1: float, x2: float, z2: float, w := 0.07) -> void:
	var m := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(Vector2(x2 - x1, z2 - z1).length(), w)
	m.mesh = q
	m.material_override = line_mat()
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = Vector3((x1 + x2) / 2.0, 0.003, (z1 + z2) / 2.0)
	m.rotation.y = -atan2(z2 - z1, x2 - x1)
	grp.add_child(m)


static func bar(grp: Node3D, a: Vector3, b: Vector3, r: float, mat: Material = null) -> MeshInstance3D:
	var dir := b - a
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = dir.length()
	c.radial_segments = 14
	c.rings = 1
	m.mesh = c
	m.material_override = mat if mat else post_mat()
	m.position = a + dir * 0.5
	var up := dir.normalized()
	if absf(up.dot(Vector3.UP)) < 0.9999:
		m.basis = Basis(Quaternion(Vector3.UP, up))
	elif up.y < 0.0:
		m.basis = Basis(Vector3.RIGHT, PI)
	grp.add_child(m)
	return m


## A grid of springy net lines; pt(u, v) -> Vector3. Returns a dictionary the stage
## animates with net_poke / net_update.
static func net_grid(grp: Node3D, nu: int, nv: int, pt: Callable) -> Dictionary:
	var base := PackedVector3Array()
	for j in nv:
		for i in nu:
			base.append(pt.call(float(i) / (nu - 1), float(j) / (nv - 1)))
	var mesh := ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = net_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grp.add_child(mi)
	var net := {"nu": nu, "nv": nv, "base": base, "off": PackedFloat32Array(), "vel": PackedFloat32Array(), "mesh": mesh}
	net.off.resize(nu * nv)
	net.vel.resize(nu * nv)
	_draw_net(net)
	return net


static func _draw_net(net: Dictionary) -> void:
	var mesh: ImmediateMesh = net.mesh
	var nu: int = net.nu
	var nv: int = net.nv
	var base: PackedVector3Array = net.base
	var off: PackedFloat32Array = net.off
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var p := func(k: int) -> Vector3: return base[k] - Vector3(0, 0, off[k])
	for j in nv:
		for i in nu:
			var k := j * nu + i
			if i < nu - 1:
				mesh.surface_add_vertex(p.call(k))
				mesh.surface_add_vertex(p.call(k + 1))
			if j < nv - 1:
				mesh.surface_add_vertex(p.call(k))
				mesh.surface_add_vertex(p.call(k + nu))
	mesh.surface_end()


static func net_poke(net: Dictionary, x: float, y: float, amt: float) -> void:
	var base: PackedVector3Array = net.base
	var vel: PackedFloat32Array = net.vel
	for k in base.size():
		var b := base[k]
		vel[k] += amt * exp(-((b.x - x) * (b.x - x) + (b.y - y) * (b.y - y)) / 0.5)
	net.vel = vel


## The net's springs (back face pushed along -z), as in goal.js update().
static func net_update(net: Dictionary, dt: float) -> void:
	var nu: int = net.nu
	var nv: int = net.nv
	var off: PackedFloat32Array = net.off
	var vel: PackedFloat32Array = net.vel
	var moving := false
	for j in nv:
		for i in nu:
			var k := j * nu + i
			if i == 0 or i == nu - 1 or j == 0 or j == nv - 1:
				off[k] = 0.0
				vel[k] = 0.0
				continue
			var nb := (off[k - 1] + off[k + 1] + off[k - nu] + off[k + nu]) * 0.25
			vel[k] += ((nb - off[k]) * 120.0 - off[k] * 60.0 - vel[k] * 6.0) * dt
	for k in off.size():
		off[k] += vel[k] * dt
		if absf(off[k]) > 1e-4 or absf(vel[k]) > 1e-4:
			moving = true
	net.off = off
	net.vel = vel
	if moving or net.get("dirty", false):
		_draw_net(net)
		net.dirty = moving
