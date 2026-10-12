class_name Panel3D
extends Node3D
## A dark floating panel with a title and a column of buttons, picked with the
## controller ray (plane intersection; no physics). Metres.

signal pressed(id: String)

const BG := Color(0.07, 0.075, 0.1, 0.94)
const ROW_BG := Color(1, 1, 1, 0.06)
const ROW_HOT := Color(1.0, 0.62, 0.36, 0.28)
const TEXT := Color(0.96, 0.95, 0.93)
const SUB := Color(0.72, 0.72, 0.78)
const ACCENT := Color(1.0, 0.62, 0.36)
const WIDTH := 0.46
const ROW_H := 0.07
const GAP := 0.012
const PAD := 0.03

static var _font: FontFile
static var _round_tex: Texture2D

var rows: Array = []  # {id, rect: Rect2 (panel-local x, y), bg: MeshInstance3D}
var _hot := ""
var height := 0.0


static func font() -> FontFile:
	if _font == null:
		_font = load("res://assets/fonts/baloo-arabic.woff2")
		var latin: FontFile = load("res://assets/fonts/baloo-latin.woff2")
		if _font and latin:
			_font.fallbacks = [latin]
	return _font


## A rounded-rectangle mask, shared by every panel and button.
static func round_tex() -> Texture2D:
	if _round_tex == null:
		var n := 128
		var img := Image.create(n, n, false, Image.FORMAT_LA8)
		var r := 28.0
		for y in n:
			for x in n:
				var dx := maxf(0.0, maxf(r - x, x - (n - 1 - r)))
				var dy := maxf(0.0, maxf(r - y, y - (n - 1 - r)))
				var a := clampf(r + 0.5 - sqrt(dx * dx + dy * dy), 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_round_tex = ImageTexture.create_from_image(img)
	return _round_tex


static func label(text: String, size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font()
	l.font_size = size
	l.pixel_size = 0.0009
	l.modulate = color
	l.outline_size = 0
	l.double_sided = false
	l.no_depth_test = false
	l.render_priority = 3
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.text_direction = TextServer.DIRECTION_AUTO
	return l


func _quad(size: Vector2, color: Color, pos: Vector3, priority: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.albedo_texture = round_tex()
	m.render_priority = priority
	m.no_depth_test = false
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## title, subtitle (optional), buttons: [[id, text], ...]
func build(title: String, subtitle: String, buttons: Array) -> void:
	for c in get_children():
		c.queue_free()
	rows.clear()
	var head := 0.09 + (0.04 if subtitle != "" else 0.0)
	height = PAD * 2 + head + buttons.size() * (ROW_H + GAP)
	_quad(Vector2(WIDTH, height), BG, Vector3.ZERO, 1)
	var y := height / 2 - PAD - 0.045
	var t := label(title, 64, TEXT)
	t.position = Vector3(0, y, 0.002)
	add_child(t)
	if subtitle != "":
		y -= 0.05
		var s := label(subtitle, 30, SUB)
		s.position = Vector3(0, y, 0.002)
		add_child(s)
	y -= 0.065
	for b in buttons:
		var cy := y - ROW_H / 2
		var bg := _quad(Vector2(WIDTH - PAD * 2, ROW_H), ROW_BG, Vector3(0, cy, 0.001), 2)
		var l := label(b[1], 40, TEXT)
		l.position = Vector3(0, cy, 0.003)
		add_child(l)
		rows.append({"id": b[0], "rect": Rect2(-WIDTH / 2 + PAD, cy - ROW_H / 2, WIDTH - PAD * 2, ROW_H), "bg": bg})
		y -= ROW_H + GAP


## Ray in world space -> button id under it ("" for none); highlights it.
func hit(origin: Vector3, dir: Vector3) -> String:
	if not visible:
		return ""
	var inv := global_transform.affine_inverse()
	var o := inv * origin
	var d := inv.basis * dir
	var id := ""
	if absf(d.z) > 1e-5:
		var t := -o.z / d.z
		if t > 0.0:
			var p := o + d * t
			for r in rows:
				if (r.rect as Rect2).has_point(Vector2(p.x, p.y)):
					id = r.id
	if id != _hot:
		_hot = id
		for r in rows:
			(r.bg.material_override as StandardMaterial3D).albedo_color = ROW_HOT if r.id == id else ROW_BG
	return id


## Distance along the ray to the panel plane (for the pointer dot), or -1.
func ray_distance(origin: Vector3, dir: Vector3) -> float:
	var inv := global_transform.affine_inverse()
	var o := inv * origin
	var d := inv.basis * dir
	if absf(d.z) < 1e-5:
		return -1.0
	var t := -o.z / d.z
	var p := o + d * t
	if t <= 0.0 or absf(p.x) > WIDTH / 2 or absf(p.y) > height / 2:
		return -1.0
	return (global_transform * p - origin).length()


## Stand in front of the head, facing it.
func place(head: Transform3D, distance := 0.7, drop := 0.08) -> void:
	var fwd := -head.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 0.01 else Vector3.FORWARD
	global_position = head.origin + fwd * distance + Vector3(0, -drop, 0)
	look_at(head.origin, Vector3.UP, true)
