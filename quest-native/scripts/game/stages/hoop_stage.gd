class_name HoopStage
extends Node3D
## The hoop (src/reference/stages/hoop.js): a backboard on a pole, an orange rim and a
## springy net of three rings joined in a diamond pattern. Game units.

const BBZ := -9.0
const BBW := 1.8
const BBB := 2.9
const BBT := 3.95
const RY := 3.05
const RR := 0.48
const TUBE := 0.035
const RZ := BBZ + 0.15 + RR
const RIM_C := Vector3(0, RY, RZ)
const N := 16
# net: three rings of points joined in a diamond pattern [radius, dy, phase]
const RINGS := [[RR, 0.0, 0.0], [RR * 0.78, -0.26, 0.5], [RR * 0.56, -0.52, 0.0]]

var aim_z := RZ
var far_z = null
var reach_z = null
var ctx: GameCtx
var friction = null
var shot_time = null
var board: MeshInstance3D
var rim: MeshInstance3D
var net := {"off": Vector3.ZERO, "vel": Vector3.ZERO, "stretch": 0.0, "sv": 0.0}
var npos := PackedVector3Array()
var nidx := PackedInt32Array()
var _net_mesh := ImmediateMesh.new()


func _init() -> void:
	name = "Hoop"
	var V := func(x, y, z): return Vector3(x, y, z)
	# court lines
	var base := BBZ - 1.2
	StageArt.ground_line(self, -9, base, 9, base)
	StageArt.ground_line(self, -1.8, base, -1.8, base + 5.8)
	StageArt.ground_line(self, 1.8, base, 1.8, base + 5.8)
	StageArt.ground_line(self, -1.8, base + 5.8, 1.8, base + 5.8)
	StageArt.ground_arc(self, 0, base + 5.8, 1.8, 0, PI * 2)
	StageArt.ground_arc(self, 0, RZ, 6.75, PI * 1.08, PI * 1.92)
	# pole and arm
	StageArt.bar(self, V.call(0, 0, BBZ - 0.9), V.call(0, BBT - 0.25, BBZ - 0.9), 0.09)
	StageArt.bar(self, V.call(0, BBT - 0.25, BBZ - 0.9), V.call(0, BBT - 0.25, BBZ - 0.03), 0.06)
	# backboard
	board = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(BBW, BBT - BBB, 0.05)
	board.mesh = bm
	board.material_override = _mat(Color("f8f3ea"), 0.6)
	board.position = Vector3(0, (BBB + BBT) / 2, BBZ - 0.025)
	add_child(board)
	var frame := box_edges(bm.size, line_mat(StageArt.INK))
	frame.position = board.position
	add_child(frame)
	var sq := rect_edges(0.6, 0.45, line_mat(StageArt.INK))
	sq.position = Vector3(0, RY + 0.25, BBZ + 0.003)
	add_child(sq)
	# rim (Godot's torus already lies in the XZ plane: three.js rotation.x = PI/2)
	rim = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = RR - TUBE
	tm.outer_radius = RR + TUBE
	tm.rings = 48
	tm.ring_segments = 10
	rim.mesh = tm
	var rm := _mat(Color("ff703c"), 0.65)
	rm.emission_enabled = true
	rm.emission = Color("ff703c")
	rm.emission_energy_multiplier = 0.035
	rim.material_override = rm
	rim.position = RIM_C
	add_child(rim)
	StageArt.bar(self, V.call(0, RY, BBZ), V.call(0, RY, RZ - RR), 0.03)
	# net
	npos.resize(N * 3)
	for i in N:
		nidx.append_array([i, N + i, (i + 1) % N, N + i, N + i, 2 * N + i, N + i, 2 * N + (i + 1) % N])
	var nm := MeshInstance3D.new()
	nm.mesh = _net_mesh
	nm.material_override = StageArt.net_mat()
	nm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(nm)
	net_draw()


static func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


## three.js LineBasicMaterial: unlit, optionally see-through.
static func line_mat(c: Color, opacity := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c, opacity)
	if opacity < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func _lines(pts: PackedVector3Array, mat: Material) -> MeshInstance3D:
	var am := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pts
	am.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	var m := MeshInstance3D.new()
	m.mesh = am
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


## LineSegments(EdgesGeometry(BoxGeometry)): the 12 edges of a box centred on the origin.
static func box_edges(size: Vector3, mat: Material) -> MeshInstance3D:
	var h := size / 2.0
	var pts := PackedVector3Array()
	for a in 3:
		var b := (a + 1) % 3
		var c := (a + 2) % 3
		for sb in [-1.0, 1.0]:
			for sc in [-1.0, 1.0]:
				var p := Vector3.ZERO
				p[b] = sb * h[b]
				p[c] = sc * h[c]
				p[a] = -h[a]
				pts.append(p)
				p[a] = h[a]
				pts.append(p)
	return _lines(pts, mat)


## LineSegments(EdgesGeometry(PlaneGeometry(w, h))): a rectangle in the XY plane.
static func rect_edges(w: float, h: float, mat: Material) -> MeshInstance3D:
	var c := [Vector3(-w / 2, -h / 2, 0), Vector3(w / 2, -h / 2, 0), Vector3(w / 2, h / 2, 0), Vector3(-w / 2, h / 2, 0)]
	var pts := PackedVector3Array()
	for i in 4:
		pts.append(c[i])
		pts.append(c[(i + 1) % 4])
	return _lines(pts, mat)


func net_draw() -> void:
	var off: Vector3 = net.off
	var stretch: float = net.stretch
	for r in 3:
		var rad: float = RINGS[r][0]
		var dy: float = RINGS[r][1]
		var ph: float = RINGS[r][2]
		var k := r / 2.0
		for i in N:
			var a := (i + ph) / N * PI * 2
			npos[r * N + i] = Vector3(RIM_C.x + cos(a) * rad + off.x * k,
				RIM_C.y + dy * (1 + stretch * k) + off.y * k,
				RIM_C.z + sin(a) * rad + off.z * k)
	_net_mesh.clear_surfaces()
	_net_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for idx in nidx:
		_net_mesh.surface_add_vertex(npos[idx])
	_net_mesh.surface_end()


func ft(sp: float) -> float:
	return maxf(0.75, minf(1.5, 1.7 - sp / 2400.0))


func behind(p: Vector3) -> bool:
	return p.z < BBZ - 0.05


func collide(b: Ball) -> void:
	var P := b.pos
	# backboard front face
	if absf(P.x) < BBW / 2 + Ball.BR * 0.4 and P.y > BBB - Ball.BR * 0.4 and P.y < BBT + Ball.BR * 0.4 \
			and P.z - Ball.BR < BBZ and P.z > BBZ - 0.3:
		b.pos.z = BBZ + Ball.BR
		if b.vel.z < 0.0:
			b.hit(Vector3(0, 0, 1), -b.vel.z, Vector3(b.pos.x, b.pos.y, BBZ))
			b.vel.z = -b.vel.z * 0.6
			b.vel.x *= 0.9
			b.side = Vector3.ZERO
	# rim: closest point on the ring
	P = b.pos
	var hx := P.x - RIM_C.x
	var hz := P.z - RIM_C.z
	var hl := Vector2(hx, hz).length()
	if hl == 0.0:
		hl = 1e-6
	if b.point_collide(Vector3(RIM_C.x + hx / hl * RR, RIM_C.y, RIM_C.z + hz / hl * RR), TUBE, 0.55):
		b.ooh()
	# pole
	b.seg_collide(Vector3(0, 0, BBZ - 0.9), Vector3(0, BBT - 0.25, BBZ - 0.9), 0.09, 0.5)
	P = b.pos
	if b.shot and b.scored_t <= 0.0 and b.vel.y < 0.0 and P.y < RY - 0.7 and b.shot_t > 0.4:
		b.miss()
	# through the hoop from above
	if b.shot and b.scored_t <= 0.0 and b.prev.y >= RY and P.y < RY \
			and Vector2(P.x - RIM_C.x, P.z - RIM_C.z).length() < RR:
		b.success()
		if ctx:
			ctx.sfx.call("swish", 1.0, b.pos)
		net.vel = Vector3(b.vel.x * 0.15, -0.4, b.vel.z * 0.15)
		net.sv += 6.0


func update(_b: Ball, dt: float) -> void:
	net.vel = (net.vel + net.off * (-70.0 * dt)) * pow(0.02, dt)
	net.off += net.vel * dt
	net.sv += (-net.stretch * 80.0 - net.sv * 6.0) * dt
	net.stretch += net.sv * dt
	net_draw()
