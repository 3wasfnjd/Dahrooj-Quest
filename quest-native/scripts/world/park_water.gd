class_name ParkWater
extends Node3D
## The pond's surface effects, as Motri's water (nature.js water): a white line where
## anything meets the water (MeshDefaultMaterial's hasWater band), queued each frame
## and drawn once, and rings that spread from a splash or from something bobbing,
## fading from white into the shallow water's colour. Two MultiMeshes, two draw calls.

const MAX := 48
const SHALLOW := Color("5bc2b9")

var _lines: MultiMesh
var _rip: MultiMesh
## Queued water lines, four floats each: x, y, z, r.
var _queue := PackedFloat32Array()
## Live ripples, six floats each: x, z, r0, r1, life, t.
var _ripples := PackedFloat32Array()


func _init() -> void:
	name = "Water"


func setup() -> void:
	_lines = _rings("WaterLines", 0.86, 40, 1.0)
	_rip = _rings("Ripples", 0.92, 48, 0.85)


static func ring_mesh(inner: float, segs: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var idx := PackedInt32Array()
	for i in segs + 1:
		var a := TAU * i / segs
		var d := Vector3(cos(a), 0, -sin(a))
		verts.append(d * inner)
		verts.append(d)
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
	for i in segs:
		var k := i * 2
		idx.append_array([k, k + 1, k + 2, k + 1, k + 3, k + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


func _rings(label: String, inner: float, segs: int, alpha: float) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = ring_mesh(inner, segs)
	mm.instance_count = MAX
	mm.visible_instance_count = 0
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water_ring.gdshader")
	mat.set_shader_parameter("alpha", alpha)
	mat.render_priority = 2
	var mi := MultiMeshInstance3D.new()
	mi.name = label
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-200, -5, -200), Vector3(400, 10, 400))
	add_child(mi)
	return mm


## A white line where a ball of radius r centred y above the surface meets the water.
func line(x: float, y: float, z: float, r: float) -> void:
	if _queue.size() < MAX * 4:
		_queue.append_array([x, y, z, r])


func ripple(x: float, z: float, r0: float, r1: float, life: float) -> void:
	if _ripples.size() >= MAX * 6:
		_ripples = _ripples.slice(6)
	_ripples.append_array([x, z, r0, r1, life, 0.0])


func ripple_count() -> int:
	return _ripples.size() / 6


func line_count() -> int:
	return _lines.visible_instance_count


func update(dt: float) -> void:
	var n := 0
	for i in range(0, _queue.size(), 4):
		var h := absf(_queue[i + 1])
		var r := _queue[i + 3]
		if h >= r:
			continue
		var rr := sqrt(r * r - h * h) * 1.06 + 0.02
		_lines.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3(rr, 1, rr)), Vector3(_queue[i], 0.004, _queue[i + 2])))
		_lines.set_instance_custom_data(n, Color(1, 1, 1, 1))
		n += 1
	_lines.visible_instance_count = n
	_queue.clear()
	var k := 0
	var i := _ripples.size() - 6
	while i >= 0:
		_ripples[i + 5] += dt
		var t := _ripples[i + 5]
		var life := _ripples[i + 4]
		if t >= life:
			_ripples = _ripples.slice(0, i) + _ripples.slice(i + 6)
			i -= 6
			continue
		var e := t / life
		var rr := _ripples[i + 2] + (_ripples[i + 3] - _ripples[i + 2]) * (1.0 - pow(1.0 - e, 2.0))
		_rip.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3(rr, 1, rr)), Vector3(_ripples[i], 0.003, _ripples[i + 1])))
		# Fading: blend from white into the shallow water's colour.
		_rip.set_instance_custom_data(k, SHALLOW.lerp(Color.WHITE, 1.0 - e).srgb_to_linear())
		k += 1
		i -= 6
	_rip.visible_instance_count = k
