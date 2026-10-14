class_name QuickPick
extends Node3D
## The right controller's A and B in play (main.gd _on_button): A steps to the next shot
## style the challenges have opened (ShotCatalog.open_now), B to the next accessory
## (DahroojLooks.accessory_available, "none" included); both wrap round. The Summit keeps A
## for its jump and ricochet for the next paddle.
##
## Feedback near the hand: the pick's menu icon pops in over the controller and its name
## rises from it as a small JuiceText; main adds a click and a tick in the hand.
## Lives in world space (metres, unscaled), a child of main.

const LIFE := 1.3
const ICON_M := 0.075  # the icon's size over the hand (metres)

var icon_line: Sprite3D
var icon_tint: Sprite3D
var t := 99.0
var last_icon := ""
var last_text := ""


## The shot styles that can be fired now, in menu order.
static func open_shots(progress: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id: String in ShotCatalog.ids():
		if ShotCatalog.open_now(id, progress):
			out.append(id)
	return out


## The accessories that can be worn now ("" = none first), in the menu's order, then any the
## menu does not list.
static func open_accessories(progress: Dictionary) -> Array[String]:
	var done := DahroojLooks.done_count(progress)
	var order: Array[String] = []
	for a: Array in MenuCatalog.ACCESSORIES:
		order.append(str(a[0]))
	for id: String in DahroojLooks.ACCESSORIES:
		if not order.has(id):
			order.append(id)
	var out: Array[String] = []
	for id in order:
		if DahroojLooks.accessory_available(id, done, progress):
			out.append(id)
	return out


## The one after `current` in `list`, wrapping round (the first when current is not in it).
static func next_in(list: Array[String], current: String) -> String:
	if list.is_empty():
		return current
	var i := list.find(current)
	return list[(i + 1) % list.size()] if i >= 0 else list[0]


static func next_shot(current: String, progress: Dictionary) -> String:
	return next_in(open_shots(progress), current)


static func next_accessory(current: String, progress: Dictionary) -> String:
	return next_in(open_accessories(progress), current)


## [ar, en] name of a shot style.
static func shot_name(id: String) -> Array:
	var info := ShotCatalog.info(id)
	return [str(info.get("ar", id)), str(info.get("en", id))]


## [ar, en] name of an accessory ("" = none).
static func accessory_name(id: String) -> Array:
	var a := MenuCatalog.accessory(id)
	if a.is_empty():
		return [id, id]
	return [str(a[1]), str(a[2])]


func _init() -> void:
	name = "QuickPick"
	icon_tint = _sprite(5)
	icon_line = _sprite(6)
	_show_icon(false)


func _show_icon(on: bool) -> void:
	icon_line.visible = on
	icon_tint.visible = on


func _sprite(priority: int) -> Sprite3D:
	var s := Sprite3D.new()
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.no_depth_test = true
	s.shaded = false
	s.double_sided = true
	s.render_priority = priority
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(s)
	return s


## Shows a pick: its menu icon over the hand at `at` (world) and its name rising from it.
func show_pick(icon: String, text: String, at: Vector3) -> void:
	last_icon = icon
	last_text = text
	t = 0.0
	position = at
	_show_icon(true)
	var pair := MenuIcons.textures(icon)
	if pair.size() >= 2:
		icon_line.texture = pair[0]
		icon_tint.texture = pair[1]
		var px := ICON_M / float((pair[0] as Texture2D).get_width())
		icon_line.pixel_size = px
		icon_tint.pixel_size = px
	icon_line.modulate = Glass.TEXT
	icon_tint.modulate = Color(Glass.ACCENT, 0.85)
	JuiceText.spawn(self, text, Vector3(0, 0.07, 0), "sub", 0.12)


func step(dt: float) -> void:
	if not icon_line.visible:
		return
	t += dt
	if t >= LIFE:
		_show_icon(false)
		return
	# Pops in with a little overshoot, floats up a touch, fades at the end.
	var k := clampf(t / 0.18, 0.0, 1.0)
	var pop := k * (1.0 + 0.35 * sin(PI * k))
	var fade := clampf((LIFE - t) / 0.35, 0.0, 1.0)
	for s: Sprite3D in [icon_line, icon_tint]:
		s.scale = Vector3.ONE * maxf(0.001, pop)
		s.position = Vector3(0, 0.02 * t, 0)
		s.modulate.a = fade * (1.0 if s == icon_line else 0.85)


func _process(delta: float) -> void:
	step(delta)
