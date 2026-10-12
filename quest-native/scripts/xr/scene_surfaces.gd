class_name SceneSurfaces
extends Node
## The real room through the Meta Scene API (OpenXR Vendors OpenXRFbSceneManager):
## walls, floor, ceiling, tables, couch, bed and other furniture the user captured in
## Space Setup. Only reports what the headset actually provides; with no room setup or
## a denied permission the lists stay empty and the game falls back to the floor.
##
## planes(): [{label, xform: Transform3D, size: Vector2, normal: Vector3}] in world space.
##   The plane is xform's local XY plane, centred on xform.origin, size along local X/Y;
##   its normal is xform.basis.z (Meta's convention: into the room for walls, up for
##   floor and table tops, down for the ceiling). `normal` is that axis, normalized.
## boxes(): [{label, xform: Transform3D, size: Vector3}] world space; the volume is the
##   box of `size` centred on xform.origin, axis aligned to xform.basis.
## Labels: wall (wall_face / invisible_wall_face), floor, ceiling, table, couch, bed,
##   storage, screen, lamp, plant, wall_art, door_frame, window_frame, other.
## Test planes and boxes (add_test_plane / add_test_box) are listed like real ones.

signal surfaces_changed

const Probe := preload("res://scripts/xr/scene_anchor_probe.gd")
const USE_SCENE := "com.oculus.permission.USE_SCENE"

var manager: Node = null
var status := "unavailable"  # unavailable | waiting | ready | no_data | denied
var _tests: Array = []  # {label, xform, size: Vector2} or {label, xform, size: Vector3, box}


func attach(origin: XROrigin3D) -> void:
	if not ClassDB.class_exists("OpenXRFbSceneManager"):
		return
	manager = ClassDB.instantiate("OpenXRFbSceneManager")
	var probe := Node3D.new()
	probe.set_script(Probe)
	var packed := PackedScene.new()
	packed.pack(probe)
	probe.free()
	manager.set("default_scene", packed)
	manager.set("auto_create", true)
	origin.add_child(manager)
	status = "waiting"
	if manager.has_signal("openxr_fb_scene_anchor_created"):
		manager.connect("openxr_fb_scene_anchor_created", func(_a, _b): _changed())
	if manager.has_signal("openxr_fb_scene_data_missing"):
		manager.connect("openxr_fb_scene_data_missing", _on_missing)
	if manager.has_signal("openxr_fb_scene_capture_completed"):
		manager.connect("openxr_fb_scene_capture_completed", func(_ok): reload())
	# The room is behind a runtime permission (USE_SCENE). The vendors plugin asks for
	# it at launch; if it arrives after the session began, the first query found
	# nothing, so query again once it is granted.
	if OS.get_name() == "Android":
		get_tree().on_request_permissions_result.connect(_on_permission)
		if not OS.get_granted_permissions().has(USE_SCENE):
			OS.request_permission(USE_SCENE)


func _on_missing() -> void:
	if OS.get_name() == "Android" and not OS.get_granted_permissions().has(USE_SCENE):
		status = "denied"
	else:
		status = "no_data"
	surfaces_changed.emit()


func _on_permission(permission: String, granted: bool) -> void:
	if permission != USE_SCENE:
		return
	if granted:
		reload()
	else:
		status = "denied"
		surfaces_changed.emit()


## Query the room again (after the permission arrives or Space Setup finishes).
func reload() -> void:
	if manager == null:
		return
	status = "waiting"
	if bool(manager.call("are_scene_anchors_created")):
		manager.call("remove_scene_anchors")
	manager.call("create_scene_anchors")
	surfaces_changed.emit()


## Opens Meta's Space Setup so the user can scan the room (when status is no_data).
func request_capture() -> bool:
	if manager == null or not bool(manager.call("is_scene_capture_supported")):
		return false
	return bool(manager.call("request_scene_capture", ""))


func _changed() -> void:
	status = "ready"
	surfaces_changed.emit()


func _probes() -> Array:
	var out: Array = []
	for p in Probe.registry:
		if is_instance_valid(p) and p.is_inside_tree():
			out.append(p)
	return out


func planes() -> Array:
	var out: Array = []
	for p in _probes():
		if p.has_plane():
			var xf: Transform3D = p.plane_xform()
			out.append({"label": p.label, "xform": xf, "size": p.rect.size, "normal": xf.basis.z.normalized()})
	for t in _tests:
		if not t.has("box"):
			var xf: Transform3D = t.xform
			out.append({"label": t.label, "xform": xf, "size": t.size, "normal": xf.basis.z.normalized()})
	return out


func boxes() -> Array:
	var out: Array = []
	for p in _probes():
		if p.has_box():
			out.append({"label": p.label, "xform": p.box_xform(), "size": p.box.size})
	for t in _tests:
		if t.has("box"):
			out.append({"label": t.label, "xform": t.xform, "size": t.size})
	return out


## A stand-in plane (tests / desktop): xform as in planes() (centre, normal = basis.z).
func add_test_plane(xform: Transform3D, size: Vector2, label := "wall") -> void:
	_tests.append({"label": label, "xform": xform.orthonormalized(), "size": size})
	if status == "unavailable":
		status = "ready"
	surfaces_changed.emit()


## A stand-in volume (tests / desktop): xform at the box centre.
func add_test_box(xform: Transform3D, size: Vector3, label := "couch") -> void:
	_tests.append({"label": label, "xform": xform.orthonormalized(), "size": size, "box": true})
	if status == "unavailable":
		status = "ready"
	surfaces_changed.emit()


func clear_tests() -> void:
	_tests.clear()
	surfaces_changed.emit()


## Legacy: the upward-facing surfaces (floor, tables and other furniture tops) as
## {label, center, size, basis} with basis = (x along the plane, UP, z along the plane).
func surfaces() -> Array:
	var out: Array = []
	for pl in planes():
		var n: Vector3 = pl.normal
		if n.y < 0.9:
			continue
		var xf: Transform3D = pl.xform
		var ax := Vector3(xf.basis.x.x, 0.0, xf.basis.x.z).normalized()
		var az := Vector3(xf.basis.y.x, 0.0, xf.basis.y.z).normalized()
		if ax.length_squared() < 0.5 or az.length_squared() < 0.5:
			ax = Vector3.RIGHT
			az = Vector3.BACK
		out.append({"label": pl.label, "center": xf.origin, "size": pl.size, "basis": Basis(ax, Vector3.UP, az)})
	return out


func has_table() -> bool:
	for s in surfaces():
		if s.label == "table":
			return true
	return false


## The nearest real surface along a ray: {p, n, label} (n faces the ray's origin), or {}.
## Planes are hit from their front side only; ceilings are skipped (nothing to stand on).
## Volumes count by the face the ray enters. With floor_fallback, a ray going down that
## meets nothing ends on the floor y = 0 ({label: "floor"}).
func ray_surface(origin: Vector3, dir: Vector3, max_dist := 8.0, floor_fallback := false) -> Dictionary:
	var d := dir.normalized()
	var best := {}
	var best_t := max_dist
	for pl in planes():
		var n: Vector3 = pl.normal
		if n.y < -0.5:
			continue
		var dn := d.dot(n)
		if dn > -1e-4:
			continue
		var xf: Transform3D = pl.xform
		var t := (xf.origin - origin).dot(n) / dn
		if t <= 0.0 or t >= best_t:
			continue
		var p := origin + d * t
		var l := xf.affine_inverse() * p
		var sz: Vector2 = pl.size
		if absf(l.x) <= sz.x / 2.0 and absf(l.y) <= sz.y / 2.0:
			best_t = t
			best = {"p": p, "n": n, "label": pl.label}
	for bx in boxes():
		var xf: Transform3D = bx.xform
		var inv := xf.affine_inverse()
		var hit := RoomColliders.ray_box(inv * origin, inv.basis * d, (bx.size as Vector3) / 2.0)
		if hit.is_empty() or float(hit.t) <= 0.0 or float(hit.t) >= best_t:
			continue
		var n := (xf.basis * (hit.n as Vector3)).normalized()
		if n.y < -0.5:
			continue
		best_t = hit.t
		best = {"p": origin + d * best_t, "n": n, "label": bx.label}
	if best.is_empty() and floor_fallback and d.y < -0.05:
		var t := -origin.y / d.y
		if t < max_dist:
			best = {"p": origin + d * t, "n": Vector3.UP, "label": "floor"}
	return best
