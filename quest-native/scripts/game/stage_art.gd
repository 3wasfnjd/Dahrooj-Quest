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


## A chalk arc on the ground (stage-art.js groundArc; three.js RingGeometry angles
## measured from +x toward -z once laid flat).
static func ground_arc(grp: Node3D, cx: float, cz: float, r: float, a0: float, a1: float, w := 0.07) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 64
	for i in n:
		var t0 := a0 + (a1 - a0) * i / n
		var t1 := a0 + (a1 - a0) * (i + 1) / n
		var q := [r - w / 2, r + w / 2]
		var p := func(rr: float, t: float) -> Vector3: return Vector3(rr * cos(t), 0.0, -rr * sin(t))
		var v00: Vector3 = p.call(q[0], t0)
		var v01: Vector3 = p.call(q[1], t0)
		var v10: Vector3 = p.call(q[0], t1)
		var v11: Vector3 = p.call(q[1], t1)
		for v in [v00, v01, v11, v00, v11, v10]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = line_mat()
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = Vector3(cx, 0.003, cz)
	grp.add_child(m)


static var _rbox_cache := {}


## A rounded box w×h×d with edge radius r (stage-art.js rbox), centred on the origin.
static func rbox(w: float, h: float, d: float, r: float, mat: Material) -> MeshInstance3D:
	var key := "%f_%f_%f_%f" % [w, h, d, r]
	if not _rbox_cache.has(key):
		_rbox_cache[key] = _rbox_mesh(w, h, d, r)
	var m := MeshInstance3D.new()
	m.mesh = _rbox_cache[key]
	m.material_override = mat
	return m


## Rounded box: each vertex of a subdivided cube is pushed onto the inner box plus
## radius r along its direction from the inner box (smooth rounded edges/corners).
static func _rbox_mesh(w: float, h: float, d: float, r: float) -> ArrayMesh:
	var half := Vector3(w, h, d) / 2.0
	var inner := (half - Vector3.ONE * r).max(Vector3.ZERO)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 6
	var faces := [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
		[Vector3.BACK, Vector3.UP, Vector3.LEFT], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]
	var pt := func(c: Vector3) -> Array:
		var cp := c * half
		var q := cp.clamp(-inner, inner)
		var dir := cp - q
		var nrm := dir.normalized() if dir.length_squared() > 1e-12 else c.normalized()
		return [q + nrm * r, nrm]
	for f in faces:
		var nz: Vector3 = f[0]
		var u: Vector3 = f[2]
		var v: Vector3 = f[1]
		for j in n:
			for i in n:
				var c := []
				for k in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
					var a: float = -1.0 + 2.0 * k[0] / n
					var b: float = -1.0 + 2.0 * k[1] / n
					c.append(pt.call(nz + u * a + v * b))
				for idx in [0, 2, 1, 0, 3, 2]:
					st.set_normal(c[idx][1])
					st.add_vertex(c[idx][0])
	return st.commit()


## The body (a Dictionary with "mesh") that owns a hit node, walking up the parents
## (stage-art.js bodyOf).
static func body_of(list: Array, obj: Node):
	var o := obj
	while o:
		for b in list:
			if b.mesh == o:
				return b
		o = o.get_parent()
	return null


## A blaster push on a body {x, v, w: Vector3, sleep} (stage-art.js shove).
static func shove(b: Dictionary, dir: Vector3, point: Vector3, k: float) -> void:
	b.v += dir * k
	b.w += (point - b.x).cross(dir) * (k * 3.0)
	b.sleep = false
