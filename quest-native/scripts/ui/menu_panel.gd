class_name MenuPanel
extends Node3D
## The headset menu (src/reference/flat-mode-panel.ts with menu-art.ts, mode-catalog.ts,
## quest-controls.ts): one flat panel, 0.765 m wide, laid out on a 1200 x 1000
## canvas — a column of page tabs and Close on the reading side, a page of cards,
## and a footer naming the card under the pointer. Pages: modes, appearance
## (Dahrooj / accessories), play, world, challenges (a scrolling list), system, about.
## Same layout, buttons, texts and right-to-left mirroring as the original, in the
## dark style of Panel3D (cards a little lighter than the panel, the selected one
## outlined in orange with a glow, hover brighter, disabled dimmed) with two-tone
## MenuIcons.
##
## The page is drawn by 2D canvas items into a SubViewport that renders once per
## change (draw() compares a key of what is visible, like the original), shown on
## a quad that cuts the rounded corners in its shader and averages four taps per
## pixel (the panel is minified in the headset). The quad draws after the world
## without a depth test, like the original's late opaque menu layer.
##
## uv here is texture space: (0, 0) top-left, (1, 1) bottom-right
## (design y = uv.y * 1000; the original's three.js v is 1 - uv.y).
## The owner calls draw(model, hover) every frame while the menu is open; it only
## re-renders when something visible changed.

const W := 1200
const H := 1000
const WIDTH := 0.765
const HEIGHT := WIDTH * H / W
const CORNER := 76.0
const LIST_TOP := 244.0
const LIST_HEIGHT := 552.0
const ROW_HEIGHT := 96.0
const TRACK_TOP := 300.0
const TRACK_HEIGHT := 440.0

const BG := Color(0.07, 0.075, 0.1)
const BG_TOP := Color(0.095, 0.1, 0.13)
const TEXT := Panel3D.TEXT
const SUB := Panel3D.SUB
const ACCENT := Panel3D.ACCENT
const CARD := Color(1, 1, 1, 0.055)
const CARD_EDGE := Color(1, 1, 1, 0.075)
const CARD_HOT := Color(1, 1, 1, 0.12)
const CARD_HOT_EDGE := Color(1, 1, 1, 0.34)
const INK := Color(0.08, 0.085, 0.11)
const SLATE := Color(0.33, 0.35, 0.44)

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_test_disabled, depth_draw_never, fog_disabled, shadows_disabled;
uniform sampler2D page : source_color, filter_linear, repeat_disable;
uniform vec2 size_px = vec2(1200.0, 1000.0);
uniform float corner = 76.0;
void fragment() {
	// Four rotated-grid taps over the screen pixel's footprint: the 1200-wide page
	// is minified (about 950 headset pixels at arm's length) and seen at an angle.
	vec2 dx = dFdx(UV);
	vec2 dy = dFdy(UV);
	vec3 c = texture(page, UV + dx * 0.125 + dy * 0.375).rgb;
	c += texture(page, UV - dx * 0.375 + dy * 0.125).rgb;
	c += texture(page, UV - dx * 0.125 - dy * 0.375).rgb;
	c += texture(page, UV + dx * 0.375 - dy * 0.125).rgb;
	vec2 p = UV * size_px;
	vec2 q = abs(p - size_px * 0.5) - size_px * 0.5 + corner;
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner;
	float aa = max(fwidth(p.x), 0.75);
	ALBEDO = c * 0.25;
	ALPHA = clamp(0.5 - d / aa, 0.0, 1.0);
}
"""

## A 2D layer that paints through a callable.
class Sheet:
	extends Node2D
	var paint: Callable

	func _draw() -> void:
		if paint.is_valid():
			paint.call(self)


var page := "modes"
var appearance := "character"  # the appearance page's sub page: character | accessories
var challenge_offset := 0.0
var buttons: Array[Dictionary] = []
var model: Dictionary = {}
var hover := -1
var renders := 0  # texture re-renders so far
var viewport: SubViewport
var mesh: MeshInstance3D
var material: ShaderMaterial
var _key := ""
var _sheet: Sheet
var _clip: Control
var _list: Sheet
var _styles := {}
static var _bold: FontVariation


func _init() -> void:
	name = "MenuPanel"
	viewport = SubViewport.new()
	viewport.size = Vector2i(W, H)
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.gui_disable_input = true
	add_child(viewport)
	_sheet = Sheet.new()
	_sheet.paint = _paint
	viewport.add_child(_sheet)
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.size = Vector2(824, LIST_HEIGHT)
	_clip.visible = false
	viewport.add_child(_clip)
	_list = Sheet.new()
	_list.paint = _paint_list
	_clip.add_child(_list)
	mesh = MeshInstance3D.new()
	mesh.name = "Page"
	var q := QuadMesh.new()
	q.size = Vector2(WIDTH, HEIGHT)
	mesh.mesh = q
	material = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	material.shader = sh
	material.render_priority = 20
	material.set_shader_parameter("page", viewport.get_texture())
	material.set_shader_parameter("corner", CORNER)
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)


# ---------------------------------------------------------------- layout

static func content_x(english: bool) -> float:
	return 220.0 if english else 92.0


## The original's grid(): cols across the 888-wide content column, mirrored in Arabic.
static func grid(index: int, cols: int, y: float, h: float, english: bool, gap := 16.0) -> Dictionary:
	var w := (888.0 - gap * (cols - 1)) / cols
	var col := index % cols
	return {"x": content_x(english) + (col if english else cols - 1 - col) * (w + gap), "y": y + floorf(index / float(cols)) * (h + gap), "w": w, "h": h}


static func mode_cell(index: int, english: bool) -> Dictionary:
	return grid(index, 4, 204, 200, english, 20)


## The centre of mode card `index` on the panel (local metres).
static func mode_point(index: int, english: bool) -> Vector3:
	var b := mode_cell(index, english)
	return Vector3(((float(b.x) + float(b.w) / 2.0) / W - 0.5) * WIDTH, (0.5 - (float(b.y) + float(b.h) / 2.0) / H) * HEIGHT, 0.0)


static func is_vr(kind: String) -> bool:
	return kind == "vr" or kind == "immersive-vr"


static func is_ar(kind: String) -> bool:
	return kind == "mr" or kind == "ar" or kind == "immersive-ar"


func _english() -> bool:
	return bool(model.get("english", false))


func _say(ar: String, en: String) -> String:
	return en if _english() else ar


func _challenges() -> Array:
	var c: Variant = model.get("challenges", [])
	return c if c is Array else []


func scroll_max() -> float:
	return maxf(0.0, _challenges().size() * ROW_HEIGHT - LIST_HEIGHT)


func challenge_scroll() -> Dictionary:
	return {"offset": challenge_offset, "max": scroll_max()}


func _track() -> Dictionary:
	var rows := _challenges().size() * ROW_HEIGHT
	var h := minf(TRACK_HEIGHT, maxf(54.0, TRACK_HEIGHT * LIST_HEIGHT / maxf(LIST_HEIGHT, rows)))
	return {"height": h, "travel": TRACK_HEIGHT - h}


func layout(m: Dictionary) -> Array[Dictionary]:
	var english: bool = m.get("english", false)
	var base := content_x(english)
	var kind := str(m.get("kind", ""))
	var out: Array[Dictionary] = []
	var add := func(k: String, id: String, ar: String, en: String, box: Dictionary, rest: Dictionary) -> void:
		var icon := "weather-rain" if k == "weather" and id == "rain" else "palette" if k == "jellyColor" else id if id != "" else "none"
		var b := {"kind": k, "id": id, "ar": ar, "en": en, "x": float(box.x), "y": float(box.y), "w": float(box.w), "h": float(box.h),
			"selected": false, "disabled": false, "icon": icon, "color": "", "fill": "", "sub": ""}
		b.merge(rest, true)
		out.append(b)
	var side := 58.0 if english else 1030.0
	for i in MenuCatalog.PAGES.size():
		var p: Array = MenuCatalog.PAGES[i]
		add.call("tab", p[0], p[1], p[2], {"x": side, "y": 174.0 + i * 94.0, "w": 112.0, "h": 82.0}, {"selected": p[0] == page, "icon": "character" if p[0] == "appearance" else p[0]})
	add.call("close", "close", "إغلاق", "Close", {"x": side, "y": 832.0, "w": 112.0, "h": 82.0}, {})
	if page == "modes":
		for i in MenuCatalog.MODES.size():
			var c: Array = MenuCatalog.MODES[i]
			add.call("mode", c[0], c[1], c[2], mode_cell(i, english), {"selected": c[0] == m.get("mode", ""), "icon": c[0]})
	elif page == "appearance":
		for i in MenuCatalog.APPEARANCE.size():
			var c: Array = MenuCatalog.APPEARANCE[i]
			add.call("appearance", c[0], c[1], c[2], grid(i, 2, 184, 88, english), {"selected": appearance == c[0]})
		if appearance == "character":
			for i in MenuCatalog.STYLES.size():
				var c: Array = MenuCatalog.STYLES[i]
				add.call("style", c[0], c[1], c[2], grid(i, 3, 300, 200, english), {"selected": c[0] == m.get("style", ""), "icon": c[0]})
			for i in MenuCatalog.COLORS.size():
				var c: Array = MenuCatalog.COLORS[i]
				add.call("jellyColor", c[0], c[1], c[2], grid(i, 4, 575, 102, english), {"selected": c[0] == m.get("jelly_color", ""), "color": c[3], "icon": "original" if c[0] == "original" else "palette"})
		else:
			var progress: Dictionary = {}
			if m.get("rewards") is Dictionary:
				progress = m.rewards
			else:
				for c: Dictionary in m.get("challenges", []):
					progress[str(c.get("id", ""))] = int(c.get("value", 0))
			var done := int(m.get("done", 0))
			for i in MenuCatalog.ACCESSORIES.size():
				var a: Array = MenuCatalog.ACCESSORIES[i]
				var open := MenuCatalog.accessory_available(a[0], done, progress)
				var sub := ""
				if not open:
					var ch := MenuCatalog.challenge(str(a[3])) if a[3] is String else []
					sub = _say(ch[2], ch[3]) if not ch.is_empty() else _say("يحتاج %d تحديات" % int(a[3]), "Needs %d challenges" % int(a[3]))
				add.call("acc", a[0], a[1], a[2], grid(i, 4, 304, 168, english), {"selected": a[0] == m.get("accessory", ""), "disabled": not open, "sub": sub})
	elif page == "play":
		for i in MenuCatalog.THROWS.size():
			var c: Array = MenuCatalog.THROWS[i]
			add.call("throw", c[0], c[1], c[2], grid(i, 3, 218, 100, english), {"selected": c[0] == m.get("throw_style", "")})
		for i in MenuCatalog.SHOTS.size():
			var c: Array = MenuCatalog.SHOTS[i]
			add.call("shot", c[0], c[1], c[2], grid(i, 4, 385, 100, english), {"selected": c[0] == m.get("shot_style", "")})
	elif page == "world":
		if is_vr(kind):
			for i in MenuCatalog.TIMES.size():
				var c: Array = MenuCatalog.TIMES[i]
				add.call("time", c[0], c[1], c[2], grid(i, 5, 244, 112, english), {"selected": c[0] == m.get("time", "")})
			for i in MenuCatalog.WEATHERS.size():
				var c: Array = MenuCatalog.WEATHERS[i]
				add.call("weather", c[0], c[1], c[2], grid(i, 4, 466, 112, english), {"selected": c[0] == m.get("weather", "")})
		var ar := is_ar(kind)
		add.call("place", "place", "إعادة تثبيت العالم" if ar else "توسيط العالم", "Re-pin world" if ar else "Recentre world", {"x": base + 314, "y": 660.0, "w": 260.0, "h": 156.0}, {})
	elif page == "challenges":
		challenge_offset = minf(scroll_max(), challenge_offset)
		add.call("scroll", "content", "", "", {"x": base, "y": LIST_TOP, "w": 824.0, "h": LIST_HEIGHT}, {})
		add.call("scroll", "track", "", "", {"x": base + 838, "y": TRACK_TOP, "w": 50.0, "h": TRACK_HEIGHT}, {})
		add.call("scrollStep", "up", "أعلى", "Up", {"x": base + 838, "y": LIST_TOP, "w": 50.0, "h": 48.0}, {"disabled": challenge_offset == 0.0})
		add.call("scrollStep", "down", "أسفل", "Down", {"x": base + 838, "y": 748.0, "w": 50.0, "h": 48.0}, {"disabled": challenge_offset == scroll_max()})
		var armed: bool = m.get("reset_armed", false)
		add.call("reset", "reset", "تأكيد التصفير؟" if armed else "تصفير التحديات", "Confirm reset?" if armed else "Reset challenges", {"x": base + 344, "y": 828.0, "w": 200.0, "h": 72.0}, {"color": "c8442f" if armed else ""})
	elif page == "system":
		add.call("lang", "lang", "English", "العربية", {"x": base + 100, "y": 308.0, "w": 300.0, "h": 244.0}, {"color": "5797b1", "fill": "a8d4df"})
		add.call("exit", "exit", "الخروج من اللعب", "Exit session", {"x": base + 488, "y": 308.0, "w": 300.0, "h": 244.0}, {"color": "b8734b", "fill": "e4b081"})
	return out


# ---------------------------------------------------------------- API

## Shows a page (one of MenuCatalog.PAGES); the next draw() renders it.
func set_page(p: String) -> void:
	for x: Array in MenuCatalog.PAGES:
		if x[0] == p:
			page = p
			_key = ""
			return


## Lays out and, when something visible changed, re-renders the page.
## model: english, kind ("vr"/"mr"), mode, style, jelly_color, throw_style,
## shot_style, time, weather, accessory, done, reset_armed, rewards,
## challenges [{id, title, en, value, goal}]. hover: the button under the pointer.
func draw(m: Dictionary, hot := -1) -> void:
	var seen: Array = []
	match page:
		"modes": seen = [m.get("mode")]
		"appearance": seen = [m.get("style"), m.get("jelly_color"), m.get("accessory"), m.get("done"), m.get("challenges"), m.get("rewards")]
		"play": seen = [m.get("throw_style"), m.get("shot_style"), m.get("mode"), m.get("kind")]
		"world": seen = [m.get("kind"), m.get("time"), m.get("weather")]
		"challenges": seen = [m.get("reset_armed"), m.get("challenges")]
	var next := str([page, appearance, challenge_offset, hot, m.get("english", false), seen])
	model = m
	if next == _key:
		return
	_key = next
	hover = hot
	buttons = layout(m)
	_clip.position = Vector2(content_x(_english()), LIST_TOP)
	_clip.visible = page == "challenges"
	_sheet.queue_redraw()
	_list.queue_redraw()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	renders += 1


## The button under a point of the page (uv: top-left origin), or -1. A button
## keeps the pointer within 6 design pixels outside it (controller tremor).
func button_at(uv: Vector2, previous := -1) -> int:
	if not uv.is_finite():
		return -1
	var x := uv.x * W
	var y := uv.y * H
	if previous >= 0 and previous < buttons.size():
		var b := buttons[previous]
		if x >= b.x - 6 and x < b.x + b.w + 6 and y >= b.y - 6 and y < b.y + b.h + 6:
			return previous
	for i in buttons.size():
		var b := buttons[i]
		if x >= b.x and x < b.x + b.w and y >= b.y and y < b.y + b.h:
			return i
	return -1


## The button to act on ({} when there is none or it is disabled).
func action(i: int) -> Dictionary:
	if i < 0 or i >= buttons.size() or buttons[i].disabled:
		return {}
	return buttons[i]


## The panel's own buttons: tabs, the appearance sub pages and the scroll steps.
## True when it handled `b` (the owner then only redraws).
func navigate(b: Dictionary) -> bool:
	match str(b.get("kind", "")):
		"tab":
			set_page(str(b.id))
			return true
		"appearance":
			appearance = str(b.id)
			_key = ""
			return true
		"scrollStep":
			scroll_by(ROW_HEIGHT * 2.0 if b.id == "down" else -ROW_HEIGHT * 2.0)
			return true
	return false


## A world-space ray against the panel: {index, uv, distance} (index -1 off the
## buttons; uv (-1, -1) and distance -1 when the ray misses the panel).
func hit(origin: Vector3, dir: Vector3, previous := -1) -> Dictionary:
	var miss := {"index": -1, "uv": Vector2(-1, -1), "distance": -1.0}
	if not visible or (is_inside_tree() and not is_visible_in_tree()):
		return miss
	var gt := global_transform if is_inside_tree() else transform
	var inv := gt.affine_inverse()
	var o := inv * origin
	var d := inv.basis * dir
	if absf(d.z) < 1e-6:
		return miss
	var t := -o.z / d.z
	if t <= 0.0:
		return miss
	var p := o + d * t
	var uv := Vector2(p.x / WIDTH + 0.5, 0.5 - p.y / HEIGHT)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return miss
	return {"index": button_at(uv, previous), "uv": uv, "distance": (gt * p).distance_to(origin)}


## Scrolls the challenge list by `delta` design pixels; false if nothing moved.
func scroll_by(delta: float) -> bool:
	if page != "challenges" or not is_finite(delta):
		return false
	var next := clampf(challenge_offset + delta, 0.0, scroll_max())
	if next == challenge_offset:
		return false
	challenge_offset = next
	_key = ""
	return true


## Right thumbstick y (Godot sign: pushed up is positive, scrolls back toward the
## first challenge); 0.22 dead zone, up to 700 design px/s. (The original read
## WebXR axes[3], where up is negative.)
func scroll_axis(v: float, dt: float) -> bool:
	if not is_finite(v) or not is_finite(dt) or absf(v) < 0.22 or dt <= 0.0:
		return false
	return scroll_by(-signf(v) * (minf(1.0, absf(v)) - 0.22) / 0.78 * minf(dt, 0.05) * 700.0)


## Dragging with the trigger held (from the "scroll" buttons): the list follows the
## pointer from uv.y from_v to to_v; on the track the thumb follows it instead.
func scroll_drag(from_v: float, to_v: float, track := false) -> bool:
	if not is_finite(from_v) or not is_finite(to_v):
		return false
	if track:
		return scroll_by((to_v - from_v) * H * scroll_max() / maxf(1e-6, float(_track().travel)))
	return scroll_by((from_v - to_v) * H)


## In front of the head like xr-runtime.js placePlaza: 1.1 m ahead along the level
## gaze, 0.2 m lower, facing the head.
func place(head: Transform3D, distance := 1.1, drop := 0.2) -> void:
	var fwd := -head.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 1e-6 else Vector3.FORWARD
	var pos := head.origin + fwd * distance + Vector3(0, -drop, 0)
	if is_inside_tree():
		global_position = pos
		look_at(head.origin, Vector3.UP, true)
	else:
		position = pos
		transform = transform.looking_at(head.origin, Vector3.UP, true)


func size_px() -> Vector2i:
	return Vector2i(W, H)


func size_m() -> Vector2:
	return Vector2(WIDTH, HEIGHT)


# ---------------------------------------------------------------- painting

static func bold() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = Panel3D.font()
		_bold.variation_embolden = 0.55
	return _bold


func _dir(force := -1) -> int:
	if force >= 0:
		return force
	return TextServer.DIRECTION_LTR if _english() else TextServer.DIRECTION_RTL


## Canvas fillText: baseline at y, align center/left/right at x, shrunk to max_w.
func _text(ci: CanvasItem, s: String, x: float, y: float, size := 32, color := TEXT, max_w := 850.0, align := "center", dir := -1, font: Font = null) -> void:
	if s == "":
		return
	var f: Font = font if font != null else Panel3D.font()
	var d := _dir(dir)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, d).x
	if w > max_w:
		size = maxi(8, int(floor(size * max_w / w)))
		w = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, d).x
	var px := x - w / 2.0 if align == "center" else x if align == "left" else x - w
	ci.draw_string(f, Vector2(px, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color, 3, d)


func _box(ci: CanvasItem, r: Rect2, radius: float, bg: Color, edge := Color(0, 0, 0, 0), edge_w := 0, glow := Color(0, 0, 0, 0), glow_size := 0) -> void:
	var key := "%s|%s|%s|%s|%s|%s" % [radius, bg, edge, edge_w, glow, glow_size]
	var sb: StyleBoxFlat = _styles.get(key)
	if sb == null:
		sb = StyleBoxFlat.new()
		sb.bg_color = bg
		sb.set_corner_radius_all(int(round(radius)))
		sb.corner_detail = 12
		sb.anti_aliasing = true
		sb.anti_aliasing_size = 1.0
		if edge_w > 0:
			sb.set_border_width_all(edge_w)
			sb.border_color = edge
		if glow_size > 0:
			sb.shadow_color = glow
			sb.shadow_size = glow_size
		_styles[key] = sb
	ci.draw_style_box(sb, r)


func _paint(ci: CanvasItem) -> void:
	var english := _english()
	var base := content_x(english)
	var cx := base + 444.0
	# The panel: a soft top-to-bottom shade, a faint rim, the tab column and the rule.
	ci.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, H), Vector2(0, H)]), PackedColorArray([BG_TOP, BG_TOP, BG, BG]))
	_box(ci, Rect2(2, 2, W - 4, H - 4), CORNER - 2.0, Color(0, 0, 0, 0), Color(1, 1, 1, 0.08), 3)
	_box(ci, Rect2(45.0 if english else 1017.0, 155, 138, 770), 64, Color(1, 1, 1, 0.035), Color(1, 1, 1, 0.05), 2)
	ci.draw_line(Vector2(base, 153), Vector2(base + 888, 153), Color(1, 1, 1, 0.09), 2.0, true)
	ci.draw_line(Vector2(cx - 34, 153), Vector2(cx + 34, 153), ACCENT, 3.0, true)
	_text(ci, _say("دحروج", "Dahrooj"), cx, 112, 40, TEXT, 850, "center", -1, bold())
	_details(ci)
	for i in buttons.size():
		_button(ci, buttons[i], i)
	# Footer: the name of the card under the pointer.
	_box(ci, Rect2(cx - 410, 916, 820, 64), 32, Color(1, 1, 1, 0.045), Color(1, 1, 1, 0.06), 2)
	var t: Dictionary = buttons[hover] if hover >= 0 and hover < buttons.size() else {}
	if not t.is_empty() and t.kind != "scroll":
		var label := _say(t.ar, t.en)
		if str(t.sub) != "":
			label += " · " + str(t.sub)
		_text(ci, label, cx, 958, 29, TEXT, 780)
	elif page == "challenges" and bool(model.get("reset_armed", false)):
		_text(ci, _say("تأكيد التصفير؟", "Confirm reset?"), cx, 958, 29, Color("ff8a70"), 780)


func _button(ci: CanvasItem, b: Dictionary, index: int) -> void:
	var kind: String = b.kind
	if kind == "scroll":
		return
	var on: bool = b.selected
	var dis: bool = b.disabled
	var hot := index == hover and not dis
	var r := Rect2(b.x, b.y, b.w, b.h)
	var c := r.get_center()
	var radius := minf(26.0, minf(r.size.x, r.size.y) * 0.24)
	var tint := ACCENT
	var line := TEXT
	if str(b.color) != "":
		# lang, exit and an armed reset keep the original's colour, as a tint.
		tint = Color(str(b.fill)) if str(b.fill) != "" else Color(str(b.color))
		var col := Color(str(b.color))
		if hot:
			_box(ci, r, radius, BG, Color(0, 0, 0, 0), 0, Color(col, 0.3), 12)
		_box(ci, r, radius, Color(col, 0.26 if hot else 0.17), Color(col.lightened(0.15), 0.95 if hot else 0.7), 3)
	elif on:
		# The glow first, under a card of panel colour, so it only shows outside.
		_box(ci, r, radius, BG, Color(0, 0, 0, 0), 0, Color(ACCENT, 0.3), 16)
		_box(ci, r, radius, Color(ACCENT, 0.22 if hot else 0.14), ACCENT, 3)
	elif hot:
		_box(ci, r, radius, CARD_HOT, CARD_HOT_EDGE, 2)
	elif dis:
		_box(ci, r, radius, Color(1, 1, 1, 0.025), Color(1, 1, 1, 0.04), 2)
	else:
		_box(ci, r, radius, CARD, CARD_EDGE, 2)
	# Icons: slate tint at rest, orange when hovered or chosen.
	var tint_col := Color(tint, 1.0) if on or str(b.color) != "" else Color(tint, 0.85) if hot else SLATE
	if dis:
		line = Color(TEXT, 0.3)
		tint_col = Color(SLATE, 0.35)
	if kind == "jellyColor" and b.id != "original":
		var col := Color(str(b.color))
		ci.draw_circle(c, 31, Color(0, 0, 0, 0.25), true, -1.0, true)
		ci.draw_circle(c, 29, col, true, -1.0, true)
		ci.draw_circle(c + Vector2(-9, -10), 8, Color(1, 1, 1, 0.28), true, -1.0, true)
		ci.draw_circle(c, 29, Color(1, 1, 1, 0.5 if on or hot else 0.18), false, 2.0, true)
		if on:
			MenuIcons.draw(ci, "check", c, 29, INK, Color(0, 0, 0, 0))
		return
	# The original sizes (24 / 45 / min(82, h-34, w-38)), a little larger: the icons carry their own margins.
	var size := 28.0 if kind == "scrollStep" else 52.0 if kind == "tab" or kind == "close" else minf(94.0, minf(r.size.y - 30.0, r.size.x - 34.0))
	if kind == "lang":
		_lang_icon(ci, c, size)
	else:
		MenuIcons.draw(ci, str(b.icon), c, size, line, tint_col)
	if dis and kind == "acc":
		var lc := c + Vector2(43, 40)
		ci.draw_circle(lc, 19, Color(0.13, 0.135, 0.17), true, -1.0, true)
		ci.draw_circle(lc, 19, Color(1, 1, 1, 0.16), false, 2.0, true)
		MenuIcons.draw(ci, "lock", lc, 24, Color(TEXT, 0.85), Color(ACCENT, 0.3))


## The language card: "A" and "ع" (menu-art.ts draws them as text too).
func _lang_icon(ci: CanvasItem, c: Vector2, size: float) -> void:
	var k := size / 100.0
	var f := bold()
	var fs := int(round(66 * k))
	var a := f.get_string_size("A", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, TextServer.DIRECTION_LTR).x
	ci.draw_string(f, c + Vector2(-22 * k - a / 2.0, 14 * k), "A", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TEXT, 3, TextServer.DIRECTION_LTR)
	var e := f.get_string_size("ع", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, TextServer.DIRECTION_RTL).x
	ci.draw_string(f, c + Vector2(24 * k - e / 2.0, 14 * k), "ع", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("a8d4df"), 3, TextServer.DIRECTION_RTL)
	ci.draw_line(c + Vector2(-38, 30) * k, c + Vector2(-6, 30) * k, Color("a8d4df"), maxf(2.0, 5.5 * k), true)


func _details(ci: CanvasItem) -> void:
	var english := _english()
	var base := content_x(english)
	var cx := base + 444.0
	var kind := str(model.get("kind", ""))
	if page == "appearance" and appearance == "character":
		_text(ci, _say("لون دحروج", "Dahrooj’s colour"), cx, 540, 30, SUB)
	if page == "appearance" and appearance == "accessories":
		var done := int(model.get("done", 0))
		_text(ci, _say("مكافآت التحديات · مكتمل %d" % done, "Challenge rewards · %d complete" % done), cx, 866, 28, SUB)
	if page == "play":
		_text(ci, _say("طريقة الرمي", "Throw style"), cx, 195, 29, SUB)
		_text(ci, _say("نوع الطلقة", "Projectile"), cx, 360, 29, SUB)
		_text(ci, _say("أزرار Meta Quest", "Meta Quest controls"), cx, 539, 30, SUB)
		var help := MenuCatalog.quest_controls(str(model.get("mode", "")), str(model.get("throw_style", "")))
		var hands := [
			{"title": _say("اليد اليسرى", "Left hand"), "rows": [["Y", _say("الأنماط", "Modes")], ["X", _say("التحديات", "Challenges")], ["trigger", _pair(help.left_trigger)]]},
			{"title": _say("اليد اليمنى", "Right hand"), "rows": [["B", _say("صفحة اللعب", "Play settings")], ["A", _pair(help.a)], ["trigger", _pair(help.right_trigger)]]},
		]
		for i in 2:
			var hand: Dictionary = hands[i]
			var x := base + i * 456.0
			_box(ci, Rect2(x, 561, 432, 202), 24, Color(1, 1, 1, 0.045), Color(1, 1, 1, 0.07), 2)
			_text(ci, hand.title, x + 216, 592, 26, TEXT, 400, "center", -1, bold())
			var rows: Array = hand.rows
			for j in rows.size():
				var row: Array = rows[j]
				var y := 632.0 + j * 46.0
				var bx := x + 34.0 if english else x + 398.0
				if row[0] == "trigger":
					MenuIcons.draw(ci, "trigger", Vector2(bx, y - 9), 30, TEXT, Color(ACCENT, 0.55))
				else:
					ci.draw_circle(Vector2(bx, y - 9), 16, Color(ACCENT, 0.16), true, -1.0, true)
					ci.draw_circle(Vector2(bx, y - 9), 16, Color(ACCENT, 0.9), false, 2.0, true)
					_text(ci, row[0], bx, y, 22, TEXT, 40, "center", TextServer.DIRECTION_LTR, bold())
				_text(ci, row[1], x + 65.0 if english else x + 367.0, y, 25, TEXT, 334, "left" if english else "right")
		_text(ci, _pair(help.grip), cx, 804, 26, SUB, 870)
		_text(ci, _say("في القائمة: زناد اليمين للاختيار · قير اليمين لتمرير التحديات", "In menus: right trigger selects · right stick scrolls challenges"), cx, 846, 25, SUB, 870)
		if is_ar(kind):
			_text(ci, _say("AR: وجّه إلى سطح واضغط الزناد لتثبيته", "AR: aim at a surface and press a trigger to pin it"), cx, 886, 25, SUB, 870)
	if page == "world":
		if is_vr(kind):
			_text(ci, _say("وقت اليوم", "Time of day"), cx, 213, 31, SUB)
			_text(ci, _say("الطقس", "Weather"), cx, 428, 31, SUB)
		else:
			_text(ci, _say("العالم في غرفتك", "Your room is the world"), cx, 315, 42, TEXT, 850, "center", -1, bold())
			_text(ci, _say("أعد التثبيت لاختيار سطح جديد", "Re-pin to choose a new surface"), cx, 400, 31, SUB)
	if page == "challenges":
		var list := _challenges()
		var done := 0
		for c: Dictionary in list:
			if int(c.get("value", 0)) >= int(c.get("goal", 1)):
				done += 1
		_text(ci, _say("إنجازاتك · %d من %d" % [done, list.size()], "Your progress · %d of %d" % [done, list.size()]), cx, 212, 30, SUB)
		_box(ci, Rect2(base + 856, TRACK_TOP, 14, TRACK_HEIGHT), 7, Color(1, 1, 1, 0.08))
		var tr_info := _track()
		var mx := scroll_max()
		var top := TRACK_TOP + (challenge_offset / mx * float(tr_info.travel) if mx > 0.0 else 0.0)
		var hot_track: bool = hover >= 0 and hover < buttons.size() and buttons[hover].id == "track"
		_box(ci, Rect2(base + 846, top, 34, tr_info.height), 12, Color(ACCENT, 0.95) if hot_track else Color(0.86, 0.86, 0.9, 0.6))
	if page == "about":
		_text(ci, _say("دحروج", "Dahrooj"), cx, 209, 42, TEXT, 850, "center", -1, bold())
		_text(ci, _say("امسك دحروج والعب في ١٢ نمطًا مرحًا.", "Play with Dahrooj across 12 playful modes."), cx, 265, 29)
		_text(ci, _say("واقع افتراضي وواقع مختلط.", "Virtual and mixed reality."), cx, 304, 28, SUB)
		for i in MenuCatalog.CREDITS.size():
			var cr: Array = MenuCatalog.CREDITS[i]
			var y := 397.0 + i * 100.0
			_text(ci, cr[0], cx, y, 34 if i == 0 else 28, ACCENT if i == 0 else TEXT, 850, "center", TextServer.DIRECTION_LTR, bold() if i == 0 else null)
			_text(ci, _say(cr[1], cr[2]), cx, y + 34, 24, SUB)


func _pair(p: Array) -> String:
	return _say(p[0], p[1])


## The challenge rows (drawn in the clipped list layer, origin at the list's top-left).
func _paint_list(ci: CanvasItem) -> void:
	if page != "challenges":
		return
	var english := _english()
	var list := _challenges()
	for i in list.size():
		var c: Dictionary = list[i]
		var y := i * ROW_HEIGHT - challenge_offset
		if y + 88.0 < 0.0 or y > LIST_HEIGHT:
			continue
		var value := int(c.get("value", 0))
		var goal := int(c.get("goal", 1))
		var done := value >= goal
		if done:
			_box(ci, Rect2(0, y, 824, 88), 14, Color(ACCENT, 0.1), Color(ACCENT, 0.35), 2)
		else:
			_box(ci, Rect2(0, y, 824, 88), 14, CARD, CARD_EDGE, 2)
		var ix := 34.0 if english else 790.0
		if done:
			ci.draw_circle(Vector2(ix, y + 37), 20, ACCENT, true, -1.0, true)
			MenuIcons.draw(ci, "check", Vector2(ix, y + 37), 27, INK, Color(0, 0, 0, 0))
		else:
			MenuIcons.draw(ci, "challenges", Vector2(ix, y + 37), 37, Color(TEXT, 0.8), Color(ACCENT, 0.3))
		_text(ci, _say(str(c.get("title", "")), str(c.get("en", ""))), 66.0 if english else 758.0, y + 41, 28, TEXT, 610, "left" if english else "right")
		_text(ci, "%d / %d" % [value, goal], 808.0 if english else 16.0, y + 41, 25, ACCENT if done else SUB, 124, "right" if english else "left", TextServer.DIRECTION_LTR)
		_box(ci, Rect2(24, y + 62, 776, 8), 4, Color(1, 1, 1, 0.09))
		var w := clampf(value / maxf(1.0, goal), 0.0, 1.0) * 776.0
		if w > 0.5:
			_box(ci, Rect2(24.0 if english else 800.0 - w, y + 62, w, 8), 4, ACCENT if done else Color(ACCENT, 0.75))
