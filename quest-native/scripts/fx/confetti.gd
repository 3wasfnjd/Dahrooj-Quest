class_name Confetti
extends Node3D
## The confetti burst (src/reference/celebration.js createReferenceConfetti): a pool
## of four bursts, each 180 paper slips (0.05 x 0.1, double-sided, Lambert, casting
## shadows) in seven rainbow colours. Each slip leaves at its own moment, flies out on
## a fixed heading and arcs up and down (a parabola in its own progress), growing in
## and shrinking out; a burst lasts 3.5 s. Positions are in this node's local space
## (game units). step(dt) runs from _process unless auto_step is turned off.

const COUNT := 180
const POOL := 4
const AMP := 0.7
const REST := 1.0 - AMP
const DUR := 3.5
const COLORS: Array[Color] = [Color("ff4040"), Color("ff9638"), Color("ffe14a"), Color("46d56c"), Color("38baff"), Color("5754e8"), Color("b65bff")]

## When false the owner calls step(dt) itself (the web game ticks it from its game step).
var auto_step := true
## One entry per burst: {mi: MultiMeshInstance3D, rp: PackedFloat32Array, ang: PackedFloat32Array,
## qs: Array[Basis], pos: PackedVector3Array (each slip's offset), t, active, radius, elev}
var pool: Array[Dictionary] = []

static var _mesh: QuadMesh
static var _mat: StandardMaterial3D


static func _shared_mesh() -> QuadMesh:
	if _mesh == null:
		_mesh = QuadMesh.new()
		_mesh.size = Vector2(0.05, 0.1)
		_mat = StandardMaterial3D.new()
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat.vertex_color_use_as_albedo = true
		_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
		_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_mat.roughness = 1.0
		_mesh.material = _mat
	return _mesh


func _init() -> void:
	for k in POOL:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _shared_mesh()
		mm.instance_count = COUNT
		var rp := PackedFloat32Array()
		var ang := PackedFloat32Array()
		var qs: Array[Basis] = []
		rp.resize(COUNT)
		ang.resize(COUNT)
		for i in COUNT:
			rp[i] = randf()
			ang[i] = randf() * TAU
			qs.append(Basis.from_euler(Vector3(randf() * 6.283, randf() * 6.283, randf() * 6.283), EULER_ORDER_XYZ))
			mm.set_instance_color(i, COLORS[i % COLORS.size()])
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), Vector3.ZERO))
		var pos := PackedVector3Array()
		pos.resize(COUNT)
		var mi := MultiMeshInstance3D.new()
		mi.name = "Confetti%d" % k
		mi.multimesh = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.visible = false
		add_child(mi)
		pool.append({"mi": mi, "rp": rp, "ang": ang, "qs": qs, "pos": pos, "t": 0.0, "active": false, "radius": 4.0, "elev": 6.0})


## A burst at pos (local space). Returns the pool slot used, or -1 when all four are busy.
func pop(pos: Vector3, radius := 4.0, elev := 6.0, scale_k := 1.0) -> int:
	for k in pool.size():
		var c: Dictionary = pool[k]
		if c.active:
			continue
		c.active = true
		c.t = 0.0
		c.radius = radius
		c.elev = elev
		var mi: MultiMeshInstance3D = c.mi
		mi.position = pos
		mi.scale = Vector3.ONE * scale_k
		# never culled while it flies (frustumCulled=false in the original)
		mi.custom_aabb = AABB(Vector3(-radius - 0.2, -0.2, -radius - 0.2), Vector3(radius * 2 + 0.4, elev + 0.4, radius * 2 + 0.4))
		mi.visible = true
		return k
	return -1


## One burst where the ball landed, scaled with distance so it reads the same size
## on screen (celebration.js celebrate). cam_pos: the eye in this node's local space.
func celebrate(at: Vector3, cam_pos: Vector3) -> int:
	var p := Vector3(at.x, maxf(0.0, at.y - Ball.BR), at.z)
	var k := maxf(1.0, p.distance_to(cam_pos) / 7.0)
	return pop(p, 1.6, 1.5, k)


## Where slip i of a burst is, relative to the burst's centre (before its scale).
func slip_position(slot: int, i: int) -> Vector3:
	var pos: PackedVector3Array = pool[slot].pos
	return pos[i]


func active_count() -> int:
	var n := 0
	for c in pool:
		if c.active:
			n += 1
	return n


func _process(delta: float) -> void:
	if auto_step:
		step(delta)


func step(dt: float) -> void:
	for c in pool:
		if not c.active:
			continue
		c.t = float(c.t) + dt
		var lin := minf(1.0, float(c.t) / DUR)
		var p := 1.0 - (1.0 - lin) * (1.0 - lin)  # gsap default ease (power1.out)
		var mm: MultiMesh = (c.mi as MultiMeshInstance3D).multimesh
		var rp: PackedFloat32Array = c.rp
		var ang: PackedFloat32Array = c.ang
		var qs: Array[Basis] = c.qs
		var pos: PackedVector3Array = c.pos
		var radius: float = c.radius
		var elev: float = c.elev
		for i in COUNT:
			var start := REST * rp[i]
			var pr := clampf((p - start) / AMP, 0.0, 1.0)
			pr = 1.0 - pow(1.0 - pr, 3.0)
			var sc := minf(1.0, (1.0 - absf(pr - 0.5) * 2.0) * 20.0)
			var strength := fposmod(rp[i] * 99.0, 1.0)
			var u := 1.0 - pr * 2.0
			var pv := Vector3(sin(ang[i]) * pr * strength * radius, (1.0 - u * u) * strength * elev, cos(ang[i]) * pr * strength * radius)
			pos[i] = pv
			mm.set_instance_transform(i, Transform3D(qs[i] * Basis.from_scale(Vector3.ONE * maxf(0.0001, sc)), pv))
		c.pos = pos
		if lin >= 1.0:
			c.active = false
			(c.mi as MultiMeshInstance3D).visible = false
