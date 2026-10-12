class_name Panel3D
extends Node3D
## The start screen: a floating frosted-glass panel (Glass) with a title, a subtitle
## and large icon cards, picked with the controller ray (plane intersection; no
## physics). Drawn into a transparent SubViewport once per change (build, hover)
## and shown on a quad. Metres.
##
## build(title, subtitle, buttons): buttons are [id, text] or [id, text, icon].
## The icon defaults to the id ("mr", "vr", "lang" have their own art). A text
## "Name — caption" shows the caption on a second line. Language buttons ("lang")
## are a slim pill under the cards; every other button is a card in the row.

signal pressed(id: String)

const BG := Color(0.07, 0.08, 0.11, 0.86)
const ROW_BG := Color(1, 1, 1, 0.06)
const ROW_HOT := Color(1.0, 0.62, 0.36, 0.28)
const TEXT := Glass.TEXT
const SUB := Glass.SUB
const ACCENT := Glass.ACCENT
const PW := 1000  # canvas width in pixels
const WIDTH := 0.6
const CORNER := 56.0
const PAD := 48.0
const CARD_TOP := 214.0
const CARD_H := 340.0
const GAP := 28.0
const PILL_H := 86.0

static var _font: FontFile
static var _round_tex: Texture2D

var rows: Array = []  # {id, rect: Rect2 (panel-local x, y; metres), box: Rect2 (canvas px), text, caption, icon, pill}
var height := 0.0
var title := ""
var subtitle := ""
var hot := ""
var renders := 0
## Every label of the last paint: {s, size, w, max_w, x} (see measure()).
var texts: Array = []
var _px_h := 600
var _viewport: SubViewport
var _sheet: MenuPanel.Sheet
var _mesh: MeshInstance3D


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


func _ensure() -> void:
	if _viewport != null:
		return
	_viewport = Glass.viewport(Vector2i(PW, _px_h))
	add_child(_viewport)
	_sheet = MenuPanel.Sheet.new()
	_sheet.paint = _paint
	_viewport.add_child(_sheet)
	_mesh = MeshInstance3D.new()
	_mesh.name = "Glass"
	_mesh.mesh = QuadMesh.new()
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)


## title, subtitle (optional), buttons: [[id, text], ...] or [[id, text, icon], ...]
func build(title_text: String, subtitle_text: String, buttons: Array) -> void:
	_ensure()
	title = title_text
	subtitle = subtitle_text
	hot = ""
	rows.clear()
	var cards: Array = []
	var pills: Array = []
	for b: Array in buttons:
		var icon := str(b[2]) if b.size() > 2 else str(b[0])
		var parts := str(b[1]).split(" — ", false, 1)
		var row := {"id": str(b[0]), "text": parts[0] if parts.size() > 0 else "", "caption": parts[1] if parts.size() > 1 else "",
			"icon": icon, "pill": icon == "lang"}
		if row.pill:
			pills.append(row)
		else:
			cards.append(row)
	var top := CARD_TOP if subtitle != "" else CARD_TOP - 44.0
	var y := top
	if not cards.is_empty():
		var n := cards.size()
		var w := (PW - PAD * 2.0 - GAP * (n - 1)) / n
		for i in n:
			cards[i].box = Rect2(PAD + i * (w + GAP), y, w, CARD_H)
		y += CARD_H + GAP
	if not pills.is_empty():
		var n := pills.size()
		var w := minf(340.0, (PW - PAD * 2.0 - GAP * (n - 1)) / n)
		var x0 := PW / 2.0 - (w * n + GAP * (n - 1)) / 2.0
		for i in n:
			pills[i].box = Rect2(x0 + i * (w + GAP), y, w, PILL_H)
		y += PILL_H + GAP
	_px_h = int(y - GAP + PAD - 4.0)
	var k := WIDTH / PW
	height = _px_h * k
	for r: Dictionary in cards + pills:
		var bx: Rect2 = r.box
		r.rect = Rect2((bx.position.x - PW / 2.0) * k, (_px_h / 2.0 - bx.end.y) * k, bx.size.x * k, bx.size.y * k)
		rows.append(r)
	_viewport.size = Vector2i(PW, _px_h)
	(_mesh.mesh as QuadMesh).size = Vector2(WIDTH, height)
	_mesh.material_override = Glass.material(_viewport.get_texture(), Vector2(PW, _px_h), CORNER, 2, true)
	_render()


func _render() -> void:
	if _viewport == null:
		return
	_sheet.queue_redraw()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	renders += 1


## Every label the panel draws, without drawing.
func measure() -> Array:
	_paint(null)
	return texts


func _paint(ci: CanvasItem) -> void:
	texts = []
	Glass.panel(ci, Rect2(0, 0, PW, _px_h), CORNER)
	var cx := PW / 2.0
	_say(Glass.text(ci, title, cx, 112, Glass.T_DISPLAY, TEXT, PW - PAD * 2.0, "center", Glass.W_TITLE))
	if subtitle != "":
		_say(Glass.text(ci, subtitle, cx, 164, 28, SUB, PW - PAD * 2.0, "center", Glass.W_BODY))
	for r: Dictionary in rows:
		var box: Rect2 = r.box
		var on := str(r.id) == hot
		Glass.card(ci, box, 30.0 if not r.pill else PILL_H / 2.0, "selected-hot" if on else "rest")
		var line := TEXT
		var tint := Color(ACCENT, 1.0) if on else Color(ACCENT, 0.55)
		if r.pill:
			var name := str(r.text)
			var isz := 44.0
			var fs := Glass.fit_size(name, 30, box.size.x - 80.0 - isz, Glass.W_LABEL)
			var tw := Glass.width(name, fs, Glass.W_LABEL)
			var gw := isz + 14.0 + tw
			var x0 := box.get_center().x - gw / 2.0
			MenuIcons.draw_hi(ci, "world" if r.icon == "lang" else str(r.icon), Vector2(x0 + isz / 2.0, box.get_center().y), isz + 6.0, line, Color(0.66, 0.83, 0.87, 0.9))
			_say(Glass.text(ci, name, x0 + isz + 14.0, box.get_center().y + fs * 0.36, fs, TEXT, box.size.x - 80.0 - isz, "left", Glass.W_LABEL))
		else:
			var c := box.get_center()
			# The icon sits on a soft disc, like an app tile.
			if ci != null:
				ci.draw_texture_rect(Glass.glow(), Rect2(Vector2(c.x - 120, box.position.y + 18), Vector2(240, 240)), false, Color(ACCENT if on else Color(0.6, 0.75, 1.0), 0.14 if on else 0.08))
			MenuIcons.draw_hi(ci, str(r.icon), Vector2(c.x, box.position.y + 140), 176, line, tint)
			var cap := str(r.caption)
			var label_y := box.end.y - (66.0 if cap != "" else 40.0)
			_say(Glass.text(ci, str(r.text), c.x, label_y, 36, TEXT, box.size.x - 40.0, "center", Glass.W_TITLE))
			if cap != "":
				_say(Glass.text(ci, cap, c.x, label_y + 40.0, Glass.T_BODY, SUB, box.size.x - 40.0, "center", Glass.W_BODY))


func _say(rec: Dictionary) -> void:
	if not rec.is_empty():
		texts.append(rec)


## The panel-local point (metres) of a canvas pixel.
func px_to_local(px: Vector2) -> Vector3:
	var k := WIDTH / PW
	return Vector3((px.x - PW / 2.0) * k, (_px_h / 2.0 - px.y) * k, 0.0)


## Ray in world space -> button id under it ("" for none); highlights it.
func hit(origin: Vector3, dir: Vector3) -> String:
	if not visible:
		return ""
	var gt := global_transform if is_inside_tree() else transform
	var inv := gt.affine_inverse()
	var o := inv * origin
	var d := inv.basis * dir
	var id := ""
	if absf(d.z) > 1e-5:
		var t := -o.z / d.z
		if t > 0.0:
			var p := o + d * t
			for r: Dictionary in rows:
				if (r.rect as Rect2).has_point(Vector2(p.x, p.y)):
					id = r.id
	if id != hot:
		hot = id
		_render()
	return id


## Distance along the ray to the panel plane (for the pointer dot), or -1.
func ray_distance(origin: Vector3, dir: Vector3) -> float:
	var gt := global_transform if is_inside_tree() else transform
	var inv := gt.affine_inverse()
	var o := inv * origin
	var d := inv.basis * dir
	if absf(d.z) < 1e-5:
		return -1.0
	var t := -o.z / d.z
	var p := o + d * t
	if t <= 0.0 or absf(p.x) > WIDTH / 2 or absf(p.y) > height / 2:
		return -1.0
	return (gt * p - origin).length()


## Stand in front of the head, facing it.
func place(head: Transform3D, distance := 0.7, drop := 0.08) -> void:
	var fwd := -head.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 0.01 else Vector3.FORWARD
	var pos := head.origin + fwd * distance + Vector3(0, -drop, 0)
	if is_inside_tree():
		global_position = pos
		look_at(head.origin, Vector3.UP, true)
	else:
		position = pos
		transform = transform.looking_at(head.origin, Vector3.UP, true)
