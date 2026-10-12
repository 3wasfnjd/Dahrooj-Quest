class_name ParkProps
extends Node3D
## PoleLights.js, Lanterns.js, Benches.js, ExplosiveCrates.js and Fireballs.js as
## nature.js runs them around the stone: Dahrooj bounces off poles, benches and
## lanterns (box colliders standing on the ground) and shoves the light ones, which
## slide, spin and tip back upright (or settle half under in the pond); a crate he
## touches burns its fuse for 0.4 s and blows up in a fireball, setting off the crates
## within 1.8, and pops back in 25 s later; a crate left in the air drops onto the one
## below. At night the pole glass lights up, fireflies drift round the poles and a warm
## pool of light lies under each. Game units; each prop kind is one MultiMesh per model
## part, re-synced when an item moves.

const CRATE := 0.7
const LANTERN := 0.6
const BENCH := 0.75
const FUSE := 0.4
const BACK := 25.0
const CHAIN := 1.8
const BLAST := 3.5
const FIRE_LIFE := 2.25

var park: Park
var poles: Array
var benches: Array
var lanterns: Array
var crates: Array
## Colliders: {it, hx, hz, h, mass, vx, vz, spin, tip, kind}.
var obstacles: Array = []
var items := {}
var pole_glow: ShaderMaterial
var lantern_glow: ShaderMaterial
var _flies_mat: ShaderMaterial
var _flies_node: MeshInstance3D
var _pool_node: MultiMeshInstance3D
var _pool_mat: ShaderMaterial
var _flies_scale := 0.0
var _pool_opacity := -1.0
var _glass_on := -1.0
var _fire_mesh: SphereMesh
var _fire_shader: Shader
## Live fireballs: {node, mat, t, radius}; spent nodes wait in _fire_pool.
var fires: Array = []
var _fire_pool: Array = []


func _init() -> void:
	name = "Props"


## Pole lights line the stone, benches with a lantern at each end sit beyond them,
## crates wait at the sides.
func setup(p: Park, court: Vector2) -> void:
	park = p
	poles = park.props.poles
	benches = park.props.benches
	lanterns = park.props.lanterns
	crates = park.props.crates
	var cx := court.x
	var cz := court.y
	for s in [-1.0, 1.0]:
		for z in [4.0, -7.0, -18.0]:
			poles.append({"x": cx + s * 10.3, "z": z, "rot": 0.0})
		for z in [-1.5, -12.5]:
			benches.append({"x": cx + s * 11.9, "z": z, "rot": -s * PI / 2})
			lanterns.append({"x": cx + s * 11.9, "z": z + 1.75, "rot": 0.4 * s})
			lanterns.append({"x": cx + s * 11.9, "z": z - 1.75, "rot": -0.3 * s})
	for xz in [[-7.4, -4.0], [7.4, -14.0]]:
		var x: float = xz[0]
		var z: float = xz[1]
		var sd := signf(x)
		crates.append({"x": cx + x, "z": cz + z + 10 - 0.45, "y": 0.0, "rot": 0.2})
		crates.append({"x": cx + x + sd * 0.15, "z": cz + z + 10 + 0.45, "y": 0.0, "rot": -0.15})
		crates.append({"x": cx + x + sd * 0.05, "z": cz + z + 10, "y": 1.0, "rot": 0.5})
	for c: Dictionary in crates:
		c.home = {"x": c.x, "z": c.z, "y": c.y, "rot": c.rot}
		c.exploded = false
		c.fuse = 0.0
		c.k = 1.0
		c.vy = 0.0
		c.back = 0.0
		c.by_player = true
	lantern_glow = ShaderMaterial.new()
	lantern_glow.shader = load("res://shaders/glow.gdshader")
	pole_glow = ShaderMaterial.new()
	pole_glow.shader = lantern_glow.shader
	pole_glow.set_shader_parameter("on", 0.0)  # pole glass lights up at night
	items.poles = _build("poleLight.glb", poles, 1.0, 1.78, pole_glow)
	items.lanterns = _build("lantern.glb", lanterns, LANTERN, 0.51, lantern_glow)
	items.benches = _build("bench.glb", benches, BENCH, 0.71, null)
	items.crates = _build("explosiveCrate.glb", crates, CRATE, 0.53, null)
	# Colliders: boxes standing on the ground (half sizes).
	for o in poles:
		obstacles.append({"it": o, "hx": 0.2, "hz": 0.2, "h": 3.5, "mass": 0.0, "kind": "poles"})
	for b in benches:
		obstacles.append({"it": b, "hx": 1.09 * BENCH, "hz": 0.63 * BENCH, "h": 1.4 * BENCH, "mass": 0.25, "vx": 0.0, "vz": 0.0, "spin": 0.0, "tip": 0.0, "kind": "benches"})
	for l in lanterns:
		obstacles.append({"it": l, "hx": 0.35 * LANTERN, "hz": 0.35 * LANTERN, "h": 1.1 * LANTERN, "mass": 0.6, "vx": 0.0, "vz": 0.0, "spin": 0.0, "tip": 0.0, "kind": "lanterns"})
	# The poles never move: their shadows are still; the rest are drawn where they are now.
	for o in poles:
		park.shadows.add_stick(o.x, o.z, 0.0, 3.3, 0.28, 0.85)
		park.shadows.add_blob(o.x, o.z, 3.45, 0.34, 0.85)
	park.shadows.dynamic_draw = _cast_shadows
	_fireflies()
	_pools()
	_fire_mesh = SphereMesh.new()
	_fire_mesh.radius = 0.5
	_fire_mesh.height = 1.0
	_fire_mesh.radial_segments = 12
	_fire_mesh.rings = 6
	_fire_shader = load("res://shaders/fireball.gdshader")


# --- models ------------------------------------------------------------------------

## One MultiMesh per model part; parts keep their offset inside the model.
func _build(file: String, list: Array, scale_k: float, lift: float, glow: Material) -> Dictionary:
	# shown: each item's transform as last synced (what the MultiMeshes hold).
	var item := {"parts": [], "list": list, "scale": scale_k, "lift": lift, "shown": []}
	item.shown.resize(list.size())
	for p in park._model_parts(file):
		var src := (p.mesh as Mesh).surface_get_material(0)
		var emissive: bool = src != null and "emissive" in src.resource_name.to_lower()
		var mat: Material = glow if emissive and glow else park._palette_material(p.mesh)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = p.mesh
		mm.instance_count = list.size()
		var mi := MultiMeshInstance3D.new()
		mi.name = file.get_basename()
		mi.multimesh = mm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.custom_aabb = AABB(Vector3(-60, -5, -60), Vector3(120, 20, 120))
		add_child(mi)
		item.parts.append([mm, p.xf])
	for i in list.size():
		sync(item, i)
	return item


## Put item i where it is now: turned, tipped, sunk, popped in at its scale.
func sync(item: Dictionary, i: int) -> void:
	if i < 0:
		return
	var it: Dictionary = item.list[i]
	var k: float = it.get("k", 1.0)
	var sc: float = item.scale
	var b := Basis(Vector3.UP, it.rot)
	var tilt: float = it.get("tilt", 0.0)
	if tilt != 0.0:
		b = b * Basis(Vector3.RIGHT, tilt)
	var s := maxf(sc * k, 1e-4)
	var t := Transform3D(b.scaled_local(Vector3(s, s, s)), Vector3(it.x, float(it.get("y", 0.0)) + float(item.lift) * sc * k, it.z))
	item.shown[i] = t
	for part: Array in item.parts:
		(part[0] as MultiMesh).set_instance_transform(i, t * (part[1] as Transform3D))
	if park.shadows:
		park.shadows.dirty = true


func _sync_obstacle(o: Dictionary) -> void:
	var item: Dictionary = items[o.kind]
	sync(item, (item.list as Array).find(o.it))


func _cast_shadows(s: ParkShadows, ci: CanvasItem) -> void:
	for b in benches:
		s.box(ci, b.x, b.z, 0.45, b.rot, 1.05 * BENCH, 0.42 * BENCH, 0.75)
	for l in lanterns:
		s.stick(ci, l.x, l.z, 0.0, 1.0 * LANTERN, 0.32 * LANTERN, 0.7)
		s.blob(ci, l.x, l.z, 1.05 * LANTERN, 0.2 * LANTERN, 0.7)
	for c in crates:
		var sc: float = c.k
		if (c.exploded and not c.fuse > 0.0) or sc < 0.05:
			continue
		var half := 0.53 * CRATE * sc
		s.box(ci, c.x, c.z, c.y + half, c.rot, half, half, 0.8)
		s.box(ci, c.x, c.z, c.y + 0.05, c.rot, half, half, 0.8)


# --- night: fireflies and pools of light ------------------------------------------

## Fireflies around each pole light (5 per light): points, UV.x = their seed.
func _fireflies() -> void:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	for p in poles:
		for j in 5:
			var a := randf() * TAU
			verts.append(Vector3(p.x + cos(a), 2.8, p.z + sin(a)))
			uvs.append(Vector2(randf() * 999.0, 0))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arr)
	mesh.custom_aabb = AABB(Vector3(-40, -2, -40), Vector3(80, 10, 80))
	_flies_mat = ShaderMaterial.new()
	_flies_mat.shader = load("res://shaders/fireflies.gdshader")
	var mi := MeshInstance3D.new()
	mi.name = "Fireflies"
	mi.mesh = mesh
	mi.material_override = _flies_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	_flies_node = mi


## A warm 6 x 6 pool of light on the ground under each pole.
func _pools() -> void:
	var q := PlaneMesh.new()
	q.size = Vector2(6, 6)
	_pool_mat = ShaderMaterial.new()
	_pool_mat.shader = load("res://shaders/light_pool.gdshader")
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = q
	mm.instance_count = poles.size()
	for i in poles.size():
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(poles[i].x, 0.03, poles[i].z)))
	var mi := MultiMeshInstance3D.new()
	mi.name = "LightPools"
	mi.multimesh = mm
	mi.material_override = _pool_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	_pool_node = mi


func glass_on() -> bool:
	return _glass_on > 0.5


# --- the ball against the props ---------------------------------------------------

## Ball against prop: push it out, bounce it, shove light props and light the fuse on
## crates. Returns {"hit", "p", "v"}.
func collide(p: Vector3, v: Vector3, r: float, by_player := true) -> Dictionary:
	var hit := false
	for o: Dictionary in obstacles:
		var it: Dictionary = o.it
		if p.y - r > float(o.h):
			continue
		var hx: float = o.hx
		var hz: float = o.hz
		var rot: float = it.rot
		var dx: float = p.x - float(it.x)
		var dz: float = p.z - float(it.z)
		var c := cos(rot)
		var s := sin(rot)
		var lx := dx * c - dz * s
		var lz := dx * s + dz * c
		var ex := lx - clampf(lx, -hx, hx)
		var ez := lz - clampf(lz, -hz, hz)
		var d := sqrt(ex * ex + ez * ez)
		if d >= r:
			continue
		if d < 1e-4:
			if hx - absf(lx) < hz - absf(lz):
				ex = _sgn(lx)
				ez = 0.0
			else:
				ex = 0.0
				ez = _sgn(lz)
			d = 0.0
		else:
			ex /= d
			ez /= d
		var nx := ex * c + ez * s
		var nz := -ex * s + ez * c
		var push := r - d
		p.x += nx * push
		p.z += nz * push
		var vn := v.x * nx + v.z * nz
		if vn < 0.0:
			var mass: float = o.mass
			if mass > 0.0:
				var k := -vn * mass
				o.vx -= nx * k
				o.vz -= nz * k
				o.spin += (randf() - 0.5) * k * 0.6
				o.tip = minf(1.0, float(o.tip) + k * 0.08)
			v.x -= nx * vn * 1.5
			v.z -= nz * vn * 1.5
			hit = true
	var cr := collide_crates(p, v, r, by_player)
	return {"hit": bool(cr.hit) or hit, "p": cr.p, "v": cr.v}


static func _sgn(x: float) -> float:
	return -1.0 if x < 0.0 else 1.0


## Crates are solid boxes: Dahrooj bounces off their sides and can land on top. Until
## the fuse burns down they stay where they are; then they're gone.
func collide_crates(p: Vector3, v: Vector3, r: float, by_player := true) -> Dictionary:
	var hit := false
	for c: Dictionary in crates:
		if c.exploded and not float(c.fuse) > 0.0:
			continue
		var half: float = 0.53 * CRATE * float(c.k)
		var bound := half * sqrt(2.0) + r
		var cy: float = c.y
		if absf(p.x - float(c.x)) > bound or absf(p.z - float(c.z)) > bound or p.y + r < cy or p.y - r > cy + half * 2.0:
			continue
		var rot: float = c.rot
		var cs := cos(rot)
		var sn := sin(rot)
		var dx: float = p.x - float(c.x)
		var dy: float = p.y - (cy + half)
		var dz: float = p.z - float(c.z)
		var lx := dx * cs - dz * sn
		var lz := dx * sn + dz * cs
		var ex := lx - clampf(lx, -half, half)
		var ey := dy - clampf(dy, -half, half)
		var ez := lz - clampf(lz, -half, half)
		var d := sqrt(ex * ex + ey * ey + ez * ez)
		if d >= r:
			continue
		if d < 1e-4:
			# Centre inside the box: out through the nearest face.
			var fx := half - absf(lx)
			var fy := half - absf(dy)
			var fz := half - absf(lz)
			var m := minf(fx, minf(fy, fz))
			ex = _sgn(lx) if m == fx else 0.0
			ey = _sgn(dy) if m == fy else 0.0
			ez = _sgn(lz) if (m == fz and m != fx and m != fy) else 0.0
			d = -m
		else:
			ex /= d
			ey /= d
			ez /= d
		var nx := ex * cs + ez * sn
		var nz := -ex * sn + ez * cs
		var ny := ey
		var push := r - d
		p.x += nx * push
		p.y += ny * push
		p.z += nz * push
		var vn := v.x * nx + v.y * ny + v.z * nz
		if vn < 0.0:
			var k := 1.0 if (ny > 0.7 and vn > -1.4) else 1.4
			v.x -= nx * vn * k
			v.y -= ny * vn * k
			v.z -= nz * vn * k
			hit = true
		_light(c, by_player)
	return {"hit": hit, "p": p, "v": v}


func _light(c: Dictionary, by_player := true) -> void:
	if c.exploded:
		return
	c.exploded = true
	c.by_player = by_player
	c.fuse = FUSE


func explode(i: int, by_player := true) -> void:
	if i >= 0 and i < crates.size():
		_light(crates[i], by_player)


## Every crate back in place (for tests and a fresh round).
func reset() -> void:
	for i in crates.size():
		var c: Dictionary = crates[i]
		c.merge(c.home, true)
		c.exploded = false
		c.fuse = 0.0
		c.k = 1.0
		c.vy = 0.0
		sync(items.crates, i)


func _fireball(at: Vector3, radius: float) -> void:
	var f: Dictionary
	if _fire_pool.is_empty():
		var mat := ShaderMaterial.new()
		mat.shader = _fire_shader
		var mi := MeshInstance3D.new()
		mi.name = "Fireball"
		mi.mesh = _fire_mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		f = {"node": mi, "mat": mat}
	else:
		f = _fire_pool.pop_back()
	f.t = 0.0
	f.radius = radius
	f.rx = randf() * TAU
	f.ry = randf() * TAU
	f.at = at
	(f.mat as ShaderMaterial).set_shader_parameter("progress", 0.15)
	(f.node as Node3D).visible = true
	_place_fire(f)
	fires.append(f)


func _place_fire(f: Dictionary) -> void:
	var t: float = f.t
	var radius: float = f.radius
	var e := minf(1.0, t / 0.6)
	var s := 0.5 + (radius - 0.5) * (1.0 - pow(1.0 - e, 3.0))
	var rz := -minf(1.0, t / FIRE_LIFE)
	var b := Basis.from_euler(Vector3(f.rx, f.ry, rz), EULER_ORDER_XYZ).scaled_local(Vector3(s, s, s))
	(f.node as Node3D).transform = Transform3D(b, f.at)


# --- the frame ------------------------------------------------------------------------

func update(dt: float, night: float) -> void:
	var on := 1.0 if night > 0.5 else 0.0
	if on != _glass_on:
		_glass_on = on
		pole_glow.set_shader_parameter("on", on)
	var fs := _flies_scale + (on - _flies_scale) * minf(1.0, dt / 1.5)
	if absf(fs - _flies_scale) > 1e-5 or (fs == 0.0) != (_flies_scale == 0.0):
		_flies_scale = fs
		_flies_mat.set_shader_parameter("scale_k", fs)
	_flies_node.visible = _flies_scale > 0.001
	var po := night * 0.35
	if po != _pool_opacity:
		_pool_opacity = po
		_pool_mat.set_shader_parameter("opacity", po)
		_pool_node.visible = po > 0.0005
	# Shoved props slide to a stop on the stone and settle back upright.
	for o: Dictionary in obstacles:
		if float(o.mass) <= 0.0:
			continue
		var it: Dictionary = o.it
		var vx: float = o.vx
		var vz: float = o.vz
		var spin: float = o.spin
		var tip: float = o.tip
		if absf(vx) + absf(vz) + absf(spin) + tip < 0.002:
			continue
		it.x += vx * dt
		it.z += vz * dt
		it.rot += spin * dt
		var f := pow(0.04, dt)
		o.vx = vx * f
		o.vz = vz * f
		o.spin = spin * f
		o.tip = maxf(0.0, tip - dt * 1.5)
		it.tilt = sin(float(o.tip) * PI) * 0.35
		_sync_obstacle(o)
	# Shoved into the pond: it settles half under the water, with Motri's white line round it.
	for o: Dictionary in obstacles:
		if float(o.mass) <= 0.0:
			continue
		var it: Dictionary = o.it
		# The water's depth under it, looked up again only when it has moved.
		var wd: float
		if o.get("wx", INF) == it.x and o.get("wz", INF) == it.z:
			wd = o.wd
		else:
			wd = park.water_at(it.x, it.z)
			o.wx = it.x
			o.wz = it.z
			o.wd = wd
		var want := -minf(0.45, 0.1 + wd) * float(o.h) if wd > 0.0 else 0.0
		var y: float = it.get("y", 0.0)
		if absf(y - want) > 0.002:
			it.y = y + (want - y) * minf(1.0, dt * 2.5)
			_sync_obstacle(o)
			if wd > 0.0 and randf() < dt * 1.5:
				park.ripple(it.x, it.z, o.hx, float(o.hx) * 2.4, 1.6)
		if wd > 0.0:
			park.water.line(it.x, 0.0, it.z, maxf(o.hx, o.hz) * 1.05)
	for i in crates.size():
		var c: Dictionary = crates[i]
		# A crate left in the air drops onto the one below or the ground.
		if not c.exploded:
			var below := 0.0
			for o: Dictionary in crates:
				if o != c and not o.exploded and absf(float(o.x) - float(c.x)) < 0.6 and absf(float(o.z) - float(c.z)) < 0.6 and float(o.y) < float(c.y):
					below = maxf(below, float(o.y) + 1.06 * CRATE)
			if float(c.y) > below + 0.001:
				c.vy = float(c.vy) - 9.8 * dt
				c.y = maxf(below, float(c.y) + float(c.vy) * dt)
				if float(c.y) == below:
					c.vy = 0.0
				sync(items.crates, i)
		if float(c.fuse) > 0.0:
			c.fuse = float(c.fuse) - dt
			if float(c.fuse) <= 0.0:
				var at := Vector3(c.x, float(c.y) + 0.53 * CRATE, c.z)
				_fireball(at, BLAST)
				c.k = 0.0
				sync(items.crates, i)
				c.back = BACK
				park.mark(c.x, c.z, 1.6, 0.9)
				park._crate_exploded(at, BLAST, c.by_player != false)
				# Crates next to it go up too, one after the other.
				for o: Dictionary in crates:
					if not o.exploded and Vector3(float(o.x) - float(c.x), float(o.y) - float(c.y), float(o.z) - float(c.z)).length() < CHAIN:
						_light(o, c.by_player != false)
		# Back after a while, popping in.
		if c.exploded and float(c.fuse) <= 0.0:
			c.back = float(c.back) - dt
			if float(c.back) <= 0.0:
				c.merge(c.home, true)
				c.exploded = false
				c.k = 0.01
				c.vy = 0.0
		if not c.exploded and float(c.k) < 1.0:
			c.k = minf(1.0, float(c.k) + dt * 3.0)
			sync(items.crates, i)
	var j := fires.size() - 1
	while j >= 0:
		var f: Dictionary = fires[j]
		f.t = float(f.t) + dt
		_place_fire(f)
		(f.mat as ShaderMaterial).set_shader_parameter("progress", 0.15 + 0.85 * clampf((float(f.t) - 0.25) / 2.0, 0.0, 1.0))
		if float(f.t) > FIRE_LIFE:
			(f.node as Node3D).visible = false
			fires.remove_at(j)
			_fire_pool.append(f)
		j -= 1
