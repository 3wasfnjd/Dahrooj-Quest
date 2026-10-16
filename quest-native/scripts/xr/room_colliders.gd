class_name RoomColliders
extends Node3D
## Mixed reality: the real room's walls and furniture as colliders (xr-runtime.js
## updateRoom / roomCollide). Works in WORLD space (metres) on what SceneSurfaces
## reports. A ball is tested along the path it moved this frame (prev -> p), so a fast
## throw can't slip through a wall between two frames. The real floor stays the game's
## own floor (floor planes are skipped), and the whole-room mesh is not used.
## show_planes(true) outlines what the headset found (the web's showPlanes), faintly.

const RESTITUTION := 1.55  # v += n * (-1.55 * vn): a bounce keeping 55% of the normal speed
const DAMP := 0.92  # then the whole velocity loses a little (as roomCollide)
const SKIP := ["floor", "global_mesh"]

var surfaces: SceneSurfaces = null
var _planes: Array = []  # {xf, inv, hx, hy, label}
var _boxes: Array = []  # {xf, inv, h: Vector3, label}
var _frame := -1
var _dirty := true
var _shown := false
var _lines: MeshInstance3D = null
var _occluder: MeshInstance3D = null
var _occluding := false

## How far the hiding surfaces sit back from the real ones (metres): what lies on a table or
## sticks to a wall (a stain, a target, a resting Dahrooj) stays in front and is not cut.
const OCCLUDE_INSET := 0.02
## The hiding surfaces: drawn first among the see-through things, colour (0, 0, 0) and alpha 0
## multiplied into what is already drawn where they are nearer (the real room shows through
## passthrough there), and their depth kept, so whatever lies behind is hidden, opaque or not.
const OCCLUDE_SHADER := """
shader_type spatial;
render_mode blend_mul, depth_draw_always, cull_disabled, unshaded, shadows_disabled, fog_disabled;
void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
}
"""


func _init(s: SceneSurfaces = null) -> void:
	if s != null:
		use(s)


func use(s: SceneSurfaces) -> void:
	surfaces = s
	_dirty = true
	s.surfaces_changed.connect(func(): _dirty = true)


func has_any() -> bool:
	_refresh()
	return not _planes.is_empty() or not _boxes.is_empty()


## Anchors drift a little as tracking settles: re-read them once per frame.
func _refresh() -> void:
	var f := Engine.get_process_frames()
	if not _dirty and f == _frame:
		return
	_dirty = false
	_frame = f
	_planes.clear()
	_boxes.clear()
	if surfaces == null:
		return
	for pl in surfaces.planes():
		if SKIP.has(pl.label):
			continue
		var xf: Transform3D = pl.xform
		var sz: Vector2 = pl.size
		_planes.append({"xf": xf, "inv": xf.affine_inverse(), "hx": sz.x / 2.0, "hy": sz.y / 2.0, "label": pl.label})
	for bx in surfaces.boxes():
		if SKIP.has(bx.label):
			continue
		var xf: Transform3D = bx.xform
		_boxes.append({"xf": xf, "inv": xf.affine_inverse(), "h": (bx.size as Vector3) / 2.0, "label": bx.label})


## Sphere of radius r that moved prev -> p with velocity v (all world space) against
## every room plane and volume. Returns {hit_speed, p, v}: the corrected position and
## velocity, and the fastest normal speed it hit with (0 when nothing was touched).
func collide(p: Vector3, v: Vector3, r: float, prev: Vector3) -> Dictionary:
	_refresh()
	var hit := 0.0
	for e in _planes:
		var inv: Transform3D = e.inv
		var xf: Transform3D = e.xf
		var lp := inv * p
		var lq := inv * prev
		var crossed := (lp.z > 0.0) != (lq.z > 0.0)
		if not crossed and absf(lp.z) >= r:
			continue
		# Where the path met the plane (or the nearest point), inside the surface?
		var t := lq.z / (lq.z - lp.z) if crossed else 1.0
		var cx := lq.x + (lp.x - lq.x) * t
		var cy := lq.y + (lp.y - lq.y) * t
		if absf(cx) > e.hx or absf(cy) > e.hy:
			continue
		# Back onto the side it came from, touching the surface; a bounce that loses a little.
		var side := 1.0 if (lq.z if crossed else lp.z) >= 0.0 else -1.0
		var rn := (xf.basis.z * side).normalized()
		if crossed:
			p = xf * Vector3(cx, cy, side * r * 1.001)
		else:
			p += rn * (r - absf(lp.z))
		var vn := v.dot(rn)
		if vn < 0.0:
			v += rn * (-RESTITUTION * vn)
			v *= DAMP
			hit = maxf(hit, -vn)
	for e in _boxes:
		var inv: Transform3D = e.inv
		var xf: Transform3D = e.xf
		var h: Vector3 = e.h
		var lp := inv * p
		var lq := inv * prev
		var ln := Vector3.ZERO
		var lnew := lp
		var hr := h + Vector3(r, r, r)
		var outside_q := absf(lq.x) > hr.x or absf(lq.y) > hr.y or absf(lq.z) > hr.z
		var sweep := ray_box(lq, lp - lq, hr) if outside_q and lq.distance_squared_to(lp) > 1e-12 else {}
		if not sweep.is_empty() and float(sweep.t) <= 1.0:
			# Entered the grown box during this step: stop at the entry, on that face.
			ln = sweep.n
			lnew = lq + (lp - lq) * float(sweep.t) + ln * r * 0.001
		else:
			var c := lp.clamp(-h, h)
			var off := lp - c
			var dist := off.length()
			if dist >= r:
				continue
			if dist > 1e-6:
				ln = off / dist
				lnew = c + ln * r * 1.001
			else:
				# The centre is inside: out through the nearest face.
				var pen := h - lp.abs()
				var ax := 0
				if pen.y < pen[ax]:
					ax = 1
				if pen.z < pen[ax]:
					ax = 2
				ln[ax] = 1.0 if lp[ax] >= 0.0 else -1.0
				lnew = lp
				lnew[ax] = ln[ax] * (h[ax] + r * 1.001)
		p = xf * lnew
		var rn := (xf.basis * ln).normalized()
		var vn := v.dot(rn)
		if vn < 0.0:
			v += rn * (-RESTITUTION * vn)
			v *= DAMP
			hit = maxf(hit, -vn)
	return {"hit_speed": hit, "p": p, "v": v}


## Whether a real wall, surface or piece of furniture stands between the eye and a sphere at p
## of radius r (world space): it is then out of sight (behind the sofa, under the table).
func blocked(eye: Vector3, p: Vector3, r: float) -> bool:
	_refresh()
	var d := p - eye
	var dist := d.length()
	if dist < 1e-4:
		return false
	var reach := dist - r  # what is in front of the sphere's near side
	if reach <= 0.0:
		return false
	for e in _planes:
		var inv: Transform3D = e.inv
		var lo := inv * eye
		var ld := inv.basis * d
		if absf(ld.z) < 1e-9:
			continue
		var t := -lo.z / ld.z
		if t <= 0.0 or t * dist >= reach:
			continue
		var hit := lo + ld * t
		if absf(hit.x) <= e.hx and absf(hit.y) <= e.hy:
			return true
	for e in _boxes:
		var inv: Transform3D = e.inv
		var res := ray_box(inv * eye, inv.basis * d, e.h)
		if not res.is_empty() and float(res.t) * dist < reach:
			return true
	return false


## Ray o + d*t against the box [-h, h] (slab test) from outside: {t, n} of the entry
## face (t in units of d), or {} on a miss or when o is inside.
static func ray_box(o: Vector3, d: Vector3, h: Vector3) -> Dictionary:
	var t0 := -INF
	var t1 := INF
	var n := Vector3.ZERO
	for a in 3:
		if absf(d[a]) < 1e-9:
			if absf(o[a]) > h[a]:
				return {}
			continue
		var ta := (-h[a] - o[a]) / d[a]
		var tb := (h[a] - o[a]) / d[a]
		var sgn := -1.0
		if ta > tb:
			var tmp := ta
			ta = tb
			tb = tmp
			sgn = 1.0
		if ta > t0:
			t0 = ta
			n = Vector3.ZERO
			n[a] = sgn
		t1 = minf(t1, tb)
		if t0 > t1:
			return {}
	if t0 < 0.0 or t1 < 0.0:
		return {}
	return {"t": t0, "n": n}


## Faint outlines of the detected planes and volumes (while placing the court).
func show_planes(on: bool) -> void:
	_shown = on
	if on and _lines == null:
		_lines = MeshInstance3D.new()
		_lines.top_level = true
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(Color("fffaf2"), 0.6)
		m.render_priority = 3
		_lines.material_override = m
		_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_lines)
	if _lines != null:
		_lines.visible = on
	if on:
		_draw_lines()


func _process(_dt: float) -> void:
	if _shown:
		_draw_lines()
	if _occluding:
		_draw_occluder()


## Mixed reality: the real walls and furniture hide what is behind them (an invisible mask
## where they are: passthrough shows the real thing in front of any game object behind it).
func occlude(on: bool) -> void:
	_occluding = on
	if on and _occluder == null:
		_occluder = MeshInstance3D.new()
		_occluder.top_level = true
		_occluder.name = "RoomOccluder"
		var sh := Shader.new()
		sh.code = OCCLUDE_SHADER
		var m := ShaderMaterial.new()
		m.shader = sh
		m.render_priority = Material.RENDER_PRIORITY_MIN
		_occluder.material_override = m
		_occluder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_occluder.custom_aabb = AABB(Vector3(-100, -100, -100), Vector3(200, 200, 200))
		add_child(_occluder)
	if _occluder != null:
		_occluder.visible = on
		_occluder.global_transform = Transform3D.IDENTITY
	if on:
		_draw_occluder()


## The mask's triangles (world space): every plane but the floor, set back OCCLUDE_INSET behind
## its face, and every volume shrunk by it.
func _draw_occluder() -> void:
	_refresh()
	var verts := PackedVector3Array()
	for e in _planes:
		var xf: Transform3D = e.xf
		var hx: float = e.hx
		var hy: float = e.hy
		var z := -OCCLUDE_INSET
		var c := [xf * Vector3(-hx, -hy, z), xf * Vector3(hx, -hy, z), xf * Vector3(hx, hy, z), xf * Vector3(-hx, hy, z)]
		verts.append_array([c[0], c[1], c[2], c[0], c[2], c[3]])
	for e in _boxes:
		var xf: Transform3D = e.xf
		var h: Vector3 = (e.h as Vector3) - Vector3.ONE * OCCLUDE_INSET
		h = h.max(Vector3.ONE * 0.005)
		for a in 3:
			var b := (a + 1) % 3
			var cc := (a + 2) % 3
			for sgn: float in [-1.0, 1.0]:
				var q: Array[Vector3] = []
				for uv: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
					var p := Vector3.ZERO
					p[a] = sgn * h[a]
					p[b] = uv.x * h[b]
					p[cc] = uv.y * h[cc]
					q.append(xf * p)
				verts.append_array([q[0], q[1], q[2], q[0], q[2], q[3]])
	var mesh := ArrayMesh.new()
	if not verts.is_empty():
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_occluder.mesh = mesh


## Triangles in the hiding mask (tests).
func occluder_triangles() -> int:
	if _occluder == null or not _occluder.visible or _occluder.mesh == null or _occluder.mesh.get_surface_count() == 0:
		return 0
	return (_occluder.mesh as ArrayMesh).surface_get_array_len(0) / 3


## Rebuilt each frame while shown (a handful of quads; anchors may move).
func _draw_lines() -> void:
	if surfaces == null or _lines == null:
		return
	var verts := PackedVector3Array()
	for pl in surfaces.planes():
		var xf: Transform3D = pl.xform
		var sz: Vector2 = pl.size
		var c: Array[Vector3] = [xf * Vector3(-sz.x / 2, -sz.y / 2, 0), xf * Vector3(sz.x / 2, -sz.y / 2, 0),
			xf * Vector3(sz.x / 2, sz.y / 2, 0), xf * Vector3(-sz.x / 2, sz.y / 2, 0)]
		for i in 4:
			verts.append(c[i])
			verts.append(c[(i + 1) % 4])
	for bx in surfaces.boxes():
		var xf: Transform3D = bx.xform
		var h: Vector3 = (bx.size as Vector3) / 2.0
		for a in 3:
			var b := (a + 1) % 3
			var cc := (a + 2) % 3
			for sb: float in [-1.0, 1.0]:
				for sc: float in [-1.0, 1.0]:
					var p0 := Vector3.ZERO
					p0[a] = -h[a]
					p0[b] = sb * h[b]
					p0[cc] = sc * h[cc]
					var p1 := p0
					p1[a] = h[a]
					verts.append(xf * p0)
					verts.append(xf * p1)
	var mesh := ArrayMesh.new()
	if not verts.is_empty():
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	_lines.mesh = mesh


func line_count() -> int:
	if _lines == null or _lines.mesh == null or _lines.mesh.get_surface_count() == 0:
		return 0
	return (_lines.mesh as ArrayMesh).surface_get_array_len(0) >> 1
