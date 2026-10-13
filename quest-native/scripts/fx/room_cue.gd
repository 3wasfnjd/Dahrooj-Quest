class_name RoomCue
extends Node3D
## A subtle bright chevron at the edge of the view that points at something new behind or
## beside the player (mixed reality, when targets come from all around the room), so they
## know to turn. World space: main calls notify() with a new target (a Node3D to follow or a
## point) and step() every frame with the head. A cue fades once the target is in view, gone
## or old; at most MAX at once, and one per direction (a newer target nearby takes it over).

const MAX := 3
const LIFE := 3.0  # seconds a cue lasts at most
const IN_VIEW := deg_to_rad(30.0)  # within this angle of the gaze it counts as seen
const MERGE := deg_to_rad(40.0)
const DIST := 0.9  # metres in front of the eye
const EDGE := Vector2(0.42, 0.26)  # the ellipse the chevrons sit on (metres, at DIST)
const COLOR := Color("ffd23f")
const OUTLINE := Color("6b3300")

var cues: Array = []  # {node, p: Vector3, t: float, mi: MeshInstance3D, dir: Vector2}
var _pool: Array = []
var _mat: StandardMaterial3D


func _init() -> void:
	name = "RoomCue"
	top_level = true  # world space, wherever it hangs
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.no_depth_test = true
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.vertex_color_use_as_albedo = true
	_mat.albedo_color = Color.WHITE
	_mat.render_priority = 10
	var mesh := chevron_mesh()
	for i in MAX:
		var mi := MeshInstance3D.new()
		mi.name = "Cue%d" % i
		mi.mesh = mesh
		mi.material_override = _mat.duplicate()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_pool.append(mi)


## A chevron pointing along +X (metres): a bright warm core over a darker rim, so it reads
## on bright walls and dark rooms alike.
static func chevron_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in 2:
		var w := 0.017 if layer == 0 else 0.009  # half thickness of the stroke
		var col := Color(OUTLINE, 0.75) if layer == 0 else Color(COLOR, 1.0)
		var z := 0.0 if layer == 0 else 0.0005
		var tip := Vector3(0.03, 0, z)
		for sgn in [-1.0, 1.0]:
			var tail := Vector3(-0.016, 0.042 * sgn, z)
			var d := (tip - tail).normalized()
			var nrm := Vector3(-d.y, d.x, 0) * w
			var ext := d * (w if layer == 0 else 0.0)
			var q := [tail - nrm - ext, tail + nrm - ext, tip + nrm + ext, tip - nrm + ext]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_color(col)
				st.add_vertex(q[idx])
	return st.commit()


## Whether a world point lies within the view cone of the head.
static func in_view(head: Transform3D, p: Vector3, cone := IN_VIEW) -> bool:
	var to := p - head.origin
	if to.length_squared() < 1e-6:
		return true
	return (-head.basis.z).normalized().angle_to(to.normalized()) <= cone


## Where on the view's edge a cue for p sits (unit direction in the view plane; +x right,
## +y up). Behind the player it points to the nearer side.
static func edge_dir(head: Transform3D, p: Vector3) -> Vector2:
	var l := head.affine_inverse() * p
	var d := Vector2(l.x, l.y)
	if l.z > 0.0:
		d = Vector2(1.0 if l.x >= 0.0 else -1.0, clampf(l.y / maxf(absf(l.z), 0.01), -0.5, 0.5))
	return d.normalized() if d.length_squared() > 1e-8 else Vector2.RIGHT


static func _yaw(head: Transform3D, p: Vector3) -> float:
	var to := p - head.origin
	return atan2(to.x, -to.z)


## Something new appeared: a cue unless it is already in view. target: a Node3D (followed
## while it lives) or a Vector3 (world).
func notify(head: Transform3D, target: Variant) -> bool:
	var p: Vector3
	var node: Node3D = null
	if target is Node3D:
		node = target
		p = node.global_position if node.is_inside_tree() else node.position
	elif target is Vector3:
		p = target
	else:
		return false
	if in_view(head, p):
		return false
	var yaw := _yaw(head, p)
	for c: Dictionary in cues:
		if absf(angle_difference(_yaw(head, c.p), yaw)) < MERGE:
			c.node = node
			c.p = p
			c.t = minf(float(c.t), 0.3)
			return true
	if cues.size() >= MAX:
		cues.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) > float(b.t))
		var old: Dictionary = cues.pop_front()
		(old.mi as MeshInstance3D).visible = false
	var mi: MeshInstance3D = null
	for m: MeshInstance3D in _pool:
		var busy := false
		for c: Dictionary in cues:
			if c.mi == m:
				busy = true
				break
		if not busy:
			mi = m
			break
	if mi == null:
		return false
	cues.append({"node": node, "p": p, "t": 0.0, "mi": mi, "dir": edge_dir(head, p)})
	return true


func clear() -> void:
	for c: Dictionary in cues:
		(c.mi as MeshInstance3D).visible = false
	cues.clear()


## Every frame: follow the targets, fade out the seen or old ones, place the chevrons.
func step(head: Transform3D, dt: float) -> void:
	for i in range(cues.size() - 1, -1, -1):
		var c: Dictionary = cues[i]
		c.t = float(c.t) + dt
		var node: Node3D = c.node
		if node != null:
			if not is_instance_valid(node) or not node.is_visible_in_tree():
				c.node = null
				c.t = maxf(float(c.t), LIFE - 0.3)
			elif node.is_inside_tree():
				c.p = node.global_position
		if in_view(head, c.p, IN_VIEW * 0.8) and float(c.t) < LIFE - 0.25:
			c.t = LIFE - 0.25
		if float(c.t) >= LIFE:
			(c.mi as MeshInstance3D).visible = false
			cues.remove_at(i)
			continue
		var d: Vector2 = (c.dir as Vector2).lerp(edge_dir(head, c.p), 1.0 - exp(-dt * 8.0)).normalized()
		c.dir = d
		var t: float = c.t
		var a := minf(1.0, t / 0.15) * minf(1.0, (LIFE - t) / 0.25) * (0.7 + 0.3 * sin(t * 9.0))
		var behind := (head.affine_inverse() * (c.p as Vector3)).z > 0.0
		var nudge := 0.012 * sin(t * 9.0)
		var local := Vector3(d.x * (EDGE.x + nudge), d.y * (EDGE.y + nudge), -DIST)
		var b := Basis(Vector3.BACK, atan2(d.y, d.x)).scaled(Vector3.ONE * (1.25 if behind else 1.0))
		var mi: MeshInstance3D = c.mi
		mi.transform = head * Transform3D(b, local)  # the cue node stays at the world origin
		(mi.material_override as StandardMaterial3D).albedo_color = Color(1, 1, 1, clampf(a, 0.0, 1.0))
		mi.visible = true
