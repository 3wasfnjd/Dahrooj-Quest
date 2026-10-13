class_name MenuPanel
extends Node3D
## The headset menu (src/reference/flat-mode-panel.ts with menu-art.ts, mode-catalog.ts,
## quest-controls.ts): one flat panel, 0.765 m wide, laid out on a 1200 x 1000
## canvas — a column of page tabs and Close on the reading side, a page of cards,
## and a footer naming the card under the pointer. Pages: modes, appearance
## (Dahrooj / accessories), play, world, challenges (a scrolling list), system, about.
## Same layout, buttons and right-to-left mirroring as the original, drawn in the
## frosted-glass style of Glass: a translucent tinted sheet with a rim light,
## cards of lighter glass with an icon over a label, the selected one tinted in the
## accent with a halo, hover brighter, disabled dimmed, one type scale, every label
## measured and fitted to its card (measure() lists them for the tests).
##
## The page is drawn by 2D canvas items into a transparent SubViewport that renders
## once per change (draw() compares a key of what is visible, like the original),
## shown on a quad that cuts the rounded corners in its shader, blends the
## premultiplied page and averages four taps per pixel (the panel is minified in
## the headset). The quad draws after the world without a depth test, like the
## original's late menu layer.
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
const TEXT := Glass.TEXT
const SUB := Glass.SUB
const ACCENT := Glass.ACCENT
const INK := Glass.INK
const SLATE := Glass.ICON_REST
## The header rule and the footer bar.
const RULE_Y := 150.0
const FOOTER_Y := 916.0

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
## Every label of the last paint: {s, size, w, max_w, x} (see measure()).
var texts: Array = []


func _init() -> void:
	name = "MenuPanel"
	viewport = Glass.viewport(Vector2i(W, H))
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
	material = Glass.material(viewport.get_texture(), Vector2(W, H), CORNER, 20, false)
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


## The mode cards: five across, three rows; a short last row is centred.
static func mode_cell(index: int, english: bool) -> Dictionary:
	var cols := 5
	var gap := 16.0
	var w := (888.0 - gap * (cols - 1)) / cols
	var h := 210.0
	var n := MenuCatalog.MODES.size()
	var row := index / cols
	var col := index % cols
	var in_row := mini(cols, n - row * cols)
	var shift := (cols - in_row) / 2.0
	var at := col + shift
	var x := content_x(english) + (at if english else cols - 1 - at) * (w + gap)
	return {"x": x, "y": 190.0 + row * (h + gap), "w": w, "h": h}


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
			add.call("throw", c[0], c[1], c[2], grid(i, 3, 206, 100, english), {"selected": c[0] == m.get("throw_style", "")})
		for i in MenuCatalog.SHOTS.size():
			var c: Array = MenuCatalog.SHOTS[i]
			add.call("shot", c[0], c[1], c[2], grid(i, 4, 360, 100, english), {"selected": c[0] == m.get("shot_style", "")})
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
		add.call("reset", "reset", "تأكيد التصفير؟" if armed else "تصفير التحديات", "Confirm reset?" if armed else "Reset challenges", {"x": base + 274, "y": 826.0, "w": 340.0, "h": 70.0}, {"color": "c8442f" if armed else ""})
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

## Every label the current page draws, without drawing ({s, size, w, max_w, x}).
func measure() -> Array:
	texts = []
	_paint(null)
	var page_texts := texts
	texts = []
	_paint_list(null)
	page_texts.append_array(texts)
	texts = page_texts
	return texts


func _dir() -> int:
	return TextServer.DIRECTION_LTR if _english() else TextServer.DIRECTION_RTL


## A label: baseline y, aligned around x, fitted to max_w; recorded in texts.
func _text(ci: CanvasItem, s: String, x: float, y: float, size: int, color: Color, max_w: float, align := "center", weight := Glass.W_BODY, dir := -1) -> void:
	var r := Glass.text(ci, s, x, y, size, color, max_w, align, weight, dir)
	if not r.is_empty():
		texts.append(r)


func _block(ci: CanvasItem, s: String, x: float, cy: float, size: int, color: Color, max_w: float, lines := 2, weight := Glass.W_BODY) -> void:
	texts.append_array(Glass.block(ci, s, x, cy, size, color, max_w, lines, "center", weight))


func _icon(ci: CanvasItem, id: String, c: Vector2, size: float, line: Color, tint: Color) -> void:
	if ci != null:
		MenuIcons.draw(ci, id, c, size, line, tint)


func _circle(ci: CanvasItem, c: Vector2, r: float, col: Color, filled := true, w := -1.0) -> void:
	if ci != null:
		ci.draw_circle(c, r, col, filled, w, true)


func _rect(ci: CanvasItem, r: Rect2, radius: float, col: Color) -> void:
	if ci != null:
		ci.draw_polygon(Glass.rounded(r, radius, 6), PackedColorArray([col]))


## A section label on the reading side with a hairline running to the far side.
func _section(ci: CanvasItem, s: String, y: float) -> void:
	var english := _english()
	var base := content_x(english)
	var x := base if english else base + 888.0
	var size := Glass.fit_size(s, Glass.T_HEAD, 600.0, Glass.W_LABEL)
	_text(ci, s, x, y, size, SUB, 600.0, "left" if english else "right", Glass.W_LABEL)
	var w := Glass.width(s, size, Glass.W_LABEL)
	if ci != null:
		var y0 := y - size * 0.32
		if english:
			ci.draw_line(Vector2(base + w + 16, y0), Vector2(base + 888, y0), Color(1, 1, 1, 0.09), 1.5, true)
		else:
			ci.draw_line(Vector2(base, y0), Vector2(base + 888 - w - 16, y0), Color(1, 1, 1, 0.09), 1.5, true)


func _page_name() -> String:
	if page == "appearance":
		return _say("المظهر", "Appearance")
	for p: Array in MenuCatalog.PAGES:
		if p[0] == page:
			return _say(p[1], p[2])
	return ""


func _paint(ci: CanvasItem) -> void:
	texts = []
	var english := _english()
	var base := content_x(english)
	var cx := base + 444.0
	var side := 58.0 if english else 1030.0
	Glass.panel(ci, Rect2(0, 0, W, H), CORNER)
	# The navigation rail: the brand over a recessed column of tabs.
	if ci != null:
		var rail := Rect2(side - 13.0, 158, 138, 768)
		ci.draw_polygon(Glass.rounded(rail, 34, 8), PackedColorArray([Color(0, 0, 0, 0.16)]))
		Glass.rim(ci, rail, 34, 0.05, 0.12, 1.5)
	_text(ci, _say("دحروج", "Dahrooj"), side + 56.0, 112, 32, ACCENT, 140, "center", Glass.W_TITLE)
	# The header: the page's name over a hairline with an accent mark.
	_text(ci, _page_name(), cx, 108, Glass.T_TITLE, TEXT, 700, "center", Glass.W_TITLE)
	if ci != null:
		ci.draw_line(Vector2(base, RULE_Y), Vector2(base + 888, RULE_Y), Color(1, 1, 1, 0.10), 1.5, true)
		ci.draw_line(Vector2(cx - 30, RULE_Y), Vector2(cx + 30, RULE_Y), ACCENT, 3.0, true)
	_details(ci)
	for i in buttons.size():
		_button(ci, buttons[i], i)
	# Footer: the name of the card under the pointer (and what unlocks it).
	var fr := Rect2(cx - 420, FOOTER_Y, 840, 60)
	if ci != null:
		ci.draw_polygon(Glass.rounded(fr, 30, 8), PackedColorArray([Color(0, 0, 0, 0.18)]))
		Glass.rim(ci, fr, 30, 0.04, 0.12, 1.5)
	var t: Dictionary = buttons[hover] if hover >= 0 and hover < buttons.size() else {}
	if not t.is_empty() and t.kind != "scroll":
		var label := _say(t.ar, t.en)
		if str(t.sub) != "":
			label += " · " + str(t.sub)
		_text(ci, label, cx, FOOTER_Y + 39, Glass.T_BODY, TEXT, 790, "center", Glass.W_BODY)
	elif page == "challenges" and bool(model.get("reset_armed", false)):
		_text(ci, _say("اضغط مرة أخرى لتصفير كل التحديات", "Press again to reset every challenge"), cx, FOOTER_Y + 39, Glass.T_BODY, Color("ff8a70"), 790)
	else:
		_text(ci, _say("وجّه إلى بطاقة واضغط الزناد للاختيار", "Point at a card and pull the trigger to choose"), cx, FOOTER_Y + 39, Glass.T_SMALL, Glass.MUTED, 790)


func _state(b: Dictionary, hot: bool) -> String:
	if b.disabled:
		return "off"
	if b.selected:
		return "selected-hot" if hot else "selected"
	return "hot" if hot else "rest"


func _button(ci: CanvasItem, b: Dictionary, index: int) -> void:
	var kind: String = b.kind
	if kind == "scroll":
		return
	var on: bool = b.selected
	var dis: bool = b.disabled
	var hot := index == hover and not dis
	var r := Rect2(b.x, b.y, b.w, b.h)
	var c := r.get_center()
	var radius := minf(22.0, minf(r.size.x, r.size.y) * 0.24)
	var tone := ACCENT
	var toned := str(b.color) != "" and kind != "jellyColor"
	if toned:
		# lang, exit and an armed reset keep the original's colour, as a tint.
		tone = Color(str(b.color)).lightened(0.12)
		Glass.card(ci, r, radius, "selected-hot" if hot else "selected", tone)
	else:
		Glass.card(ci, r, radius, _state(b, hot))
	var line := TEXT
	var tint := Color(ACCENT, 1.0) if on else Color(ACCENT, 0.9) if hot else SLATE
	var label_col := TEXT if on or hot else Color(TEXT, 0.88)
	if toned:
		tint = Color(str(b.fill)) if str(b.fill) != "" else tone
		label_col = TEXT
	if dis:
		line = Color(TEXT, 0.32)
		tint = Color(SLATE, 0.35)
		label_col = Color(TEXT, 0.38)
	var name := _say(b.ar, b.en)
	var pad := 14.0
	var lw := r.size.x - pad * 2.0
	match kind:
		"tab", "close":
			_icon(ci, str(b.icon), Vector2(c.x, r.position.y + 31), 40, line, tint)
			_text(ci, name, c.x, r.position.y + 70, Glass.T_TAB, label_col, r.size.x - 12, "center", Glass.W_LABEL)
		"jellyColor":
			var sc := Vector2(c.x, r.position.y + 38)
			if b.id == "original":
				_icon(ci, "original", sc, 50, line, tint)
			else:
				var col := Color(str(b.color))
				_circle(ci, sc, 24, Color(0, 0, 0, 0.25))
				_circle(ci, sc, 22, col)
				_circle(ci, sc + Vector2(-7, -8), 6, Color(1, 1, 1, 0.3))
				_circle(ci, sc, 22, Color(1, 1, 1, 0.55 if on or hot else 0.2), false, 2.0)
				if on:
					_icon(ci, "check", sc, 24, INK, Color(0, 0, 0, 0))
			_text(ci, name, c.x, r.end.y - 16, Glass.T_SMALL, label_col, lw, "center", Glass.W_LABEL)
		"appearance", "reset":
			# Icon and label side by side, centred as a group (icon on the reading side).
			var isz := 44.0 if kind == "appearance" else 34.0
			var fs := Glass.T_LABEL if kind == "appearance" else Glass.T_SMALL + 1
			var max_text := r.size.x - pad * 2.0 - isz - 12.0
			fs = Glass.fit_size(name, fs, max_text, Glass.W_LABEL)
			var tw := Glass.width(name, fs, Glass.W_LABEL)
			var gw := isz + 12.0 + tw
			var x0 := c.x - gw / 2.0
			var ic := Vector2(x0 + isz / 2.0, c.y) if _english() else Vector2(x0 + gw - isz / 2.0, c.y)
			var tx := x0 + isz + 12.0 if _english() else x0 + gw - isz - 12.0
			_icon(ci, str(b.icon), ic, isz + 6.0, line, tint)
			_text(ci, name, tx, c.y + fs * 0.36, fs, label_col, max_text, "left" if _english() else "right", Glass.W_LABEL)
		"scrollStep":
			_icon(ci, str(b.icon), c, 28, line, tint)
		"lang", "exit":
			if kind == "lang":
				_lang_icon(ci, Vector2(c.x, r.position.y + 100), 100)
			else:
				_icon(ci, "exit", Vector2(c.x, r.position.y + 100), 100, line, tint)
			_text(ci, name, c.x, r.end.y - 30, 28, TEXT, lw, "center", Glass.W_LABEL)
		_:
			# Icon over label. Sizes follow the card's height.
			var tall := r.size.y >= 150.0
			var fs := Glass.T_LABEL if tall else Glass.T_SMALL
			var label_y := r.end.y - (22.0 if tall else 14.0)
			var top := r.position.y + 10.0
			var bottom := label_y - fs - 8.0
			# A tall card's label that would shrink a lot breaks onto two lines instead.
			var lines := PackedStringArray([name])
			if tall and Glass.fit_size(name, fs, lw, Glass.W_LABEL) < fs - 3:
				lines = Glass.split_two(name, fs - 2)
				if lines.size() == 2:
					fs -= 2
					bottom -= fs + 2.0
			var isz := minf(r.size.x - 40.0, (bottom - top) * 0.98)
			var ic := Vector2(c.x, (top + bottom) / 2.0 + 2.0)
			_icon(ci, str(b.icon), ic, isz, line, tint)
			for li in lines.size():
				_text(ci, lines[li], c.x, label_y - (lines.size() - 1 - li) * (fs + 4.0), fs, label_col, lw, "center", Glass.W_LABEL)
			if dis and kind == "acc":
				var lc := ic + Vector2(isz * 0.42, isz * 0.36)
				_circle(ci, lc, 17, Color(0.12, 0.13, 0.17, 0.95))
				_circle(ci, lc, 17, Color(1, 1, 1, 0.2), false, 1.5)
				_icon(ci, "lock", lc, 22, Color(TEXT, 0.85), Color(ACCENT, 0.3))


## The language card: "A" and "ع" (menu-art.ts draws them as text too).
func _lang_icon(ci: CanvasItem, c: Vector2, size: float) -> void:
	if ci == null:
		return
	var k := size / 100.0
	var f := Glass.font(Glass.W_TITLE)
	var fs := int(round(66 * k))
	var a := f.get_string_size("A", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, TextServer.DIRECTION_LTR).x
	ci.draw_string(f, c + Vector2(-22 * k - a / 2.0, 18 * k), "A", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TEXT, 3, TextServer.DIRECTION_LTR)
	var e := f.get_string_size("ع", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, TextServer.DIRECTION_RTL).x
	ci.draw_string(f, c + Vector2(24 * k - e / 2.0, 18 * k), "ع", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("a8d4df"), 3, TextServer.DIRECTION_RTL)
	ci.draw_line(c + Vector2(-38, 32) * k, c + Vector2(-6, 32) * k, Color("a8d4df"), maxf(2.0, 5.5 * k), true)


func _details(ci: CanvasItem) -> void:
	var english := _english()
	var base := content_x(english)
	var cx := base + 444.0
	var kind := str(model.get("kind", ""))
	if page == "appearance" and appearance == "character":
		_section(ci, _say("لون دحروج", "Dahrooj’s colour"), 556)
	if page == "appearance" and appearance == "accessories":
		var done := int(model.get("done", 0))
		_text(ci, _say("مكافآت التحديات · مكتمل %d" % done, "Challenge rewards · %d complete" % done), cx, 878, Glass.T_SMALL, SUB, 860)
	if page == "play":
		_section(ci, _say("طريقة الرمي", "Throw style"), 192)
		_section(ci, _say("نوع الطلقة", "Projectile"), 346)
		_section(ci, _say("أزرار Meta Quest", "Meta Quest controls"), 500)
		var help := MenuCatalog.quest_controls(str(model.get("mode", "")), str(model.get("throw_style", "")))
		var hands := [
			{"title": _say("اليد اليسرى", "Left hand"), "rows": [["≡", _say("الأنماط", "Modes")], ["X", _say("التحديات", "Challenges")], ["Y", _say("المظهر", "Appearance")], ["trigger", _pair(help.left_trigger)], ["grip", _pair(help.left_grip)]]},
			{"title": _say("اليد اليمنى", "Right hand"), "rows": [["trigger", _pair(help.right_trigger)], ["grip", _pair(help.right_grip)]]},
		]
		for i in 2:
			var hand: Dictionary = hands[i]
			# The left hand on the left in both languages (it is the controller).
			var x := base + i * 456.0
			var box := Rect2(x, 516, 432, 232)
			if ci != null:
				ci.draw_polygon(Glass.rounded(box, 20, 8), PackedColorArray([Color(1, 1, 1, 0.045)]))
				Glass.rim(ci, box, 20, 0.14, 0.05, 1.5)
			_text(ci, hand.title, x + 216, 552, Glass.T_LABEL, TEXT, 400, "center", Glass.W_LABEL)
			var rows: Array = hand.rows
			for j in rows.size():
				var row: Array = rows[j]
				var y := 592.0 + j * 36.0
				var bx := x + 50.0 if english else x + 382.0
				if row[0] == "trigger" or row[0] == "grip":
					# A key cap for the trigger and the grip.
					var cap := Rect2(bx - 32, y - 23, 64, 30)
					_rect(ci, cap, 15, Color(ACCENT, 0.16))
					if ci != null:
						var pts := Glass.rounded(cap, 15, 6)
						pts.append(pts[0])
						ci.draw_polyline(pts, Color(ACCENT, 0.9), 2.0, true)
					_text(ci, _say("الزناد", "Trigger") if row[0] == "trigger" else _say("القبضة", "Grip"), bx, y - 2, 15, TEXT, 56, "center", Glass.W_LABEL)
				else:
					_circle(ci, Vector2(bx, y - 8), 15, Color(ACCENT, 0.16))
					_circle(ci, Vector2(bx, y - 8), 15, Color(ACCENT, 0.9), false, 2.0)
					if row[0] == "≡":
						# The controller's menu button: three bars (the font has no ≡).
						if ci != null:
							for k in 3:
								var yy := y - 14.0 + k * 6.0
								ci.draw_line(Vector2(bx - 7, yy), Vector2(bx + 7, yy), TEXT, 2.4, true)
					else:
						_text(ci, row[0], bx, y, 20, TEXT, 26, "center", Glass.W_TITLE, TextServer.DIRECTION_LTR)
				_text(ci, row[1], x + 98.0 if english else x + 334.0, y, Glass.T_SMALL + 1, TEXT, 316, "left" if english else "right", Glass.W_BODY)
		_text(ci, _pair(help.grip), cx, 790, Glass.T_SMALL, SUB, 880)
		_text(ci, _say("في القائمة: الزناد للاختيار · قير اليمين لتمرير التحديات", "In menus: the trigger selects · the right stick scrolls challenges"), cx, 826, Glass.T_SMALL, Glass.MUTED, 880)
		if is_ar(kind):
			_text(ci, _say("الواقع المختلط: وجّه إلى سطح واضغط الزناد لتثبيته", "Mixed reality: aim at a surface and pull a trigger to pin it"), cx, 862, Glass.T_SMALL, Glass.MUTED, 880)
	if page == "world":
		if is_vr(kind):
			_section(ci, _say("وقت اليوم", "Time of day"), 222)
			_section(ci, _say("الطقس", "Weather"), 444)
		else:
			_icon(ci, "world", Vector2(cx, 300), 110, TEXT, Color(ACCENT, 0.5))
			_text(ci, _say("العالم في غرفتك", "Your room is the world"), cx, 430, 36, TEXT, 850, "center", Glass.W_TITLE)
			_text(ci, _say("أعد التثبيت لاختيار سطح جديد", "Re-pin to choose a new surface"), cx, 478, Glass.T_BODY, SUB, 850)
	if page == "challenges":
		var list := _challenges()
		var done := 0
		for c: Dictionary in list:
			if int(c.get("value", 0)) >= int(c.get("goal", 1)):
				done += 1
		_text(ci, _say("إنجازاتك · %d من %d" % [done, list.size()], "Your progress · %d of %d" % [done, list.size()]), cx, 212, Glass.T_LABEL, SUB, 860, "center", Glass.W_LABEL)
		_rect(ci, Rect2(base + 858, TRACK_TOP, 10, TRACK_HEIGHT), 5, Color(1, 1, 1, 0.08))
		var tr_info := _track()
		var mx := scroll_max()
		var top := TRACK_TOP + (challenge_offset / mx * float(tr_info.travel) if mx > 0.0 else 0.0)
		var hot_track: bool = hover >= 0 and hover < buttons.size() and buttons[hover].id == "track"
		_rect(ci, Rect2(base + 851, top, 24, tr_info.height), 12, Color(ACCENT, 0.95) if hot_track else Color(0.86, 0.87, 0.92, 0.55))
	if page == "about":
		_text(ci, _say("امسك دحروج والعب في %d نمطًا مرحًا." % MenuCatalog.MODES.size(), "Play with Dahrooj across %d playful modes." % MenuCatalog.MODES.size()), cx, 214, 28, TEXT, 860, "center", Glass.W_LABEL)
		_text(ci, _say("واقع افتراضي وواقع مختلط · Meta Quest", "Virtual and mixed reality · Meta Quest"), cx, 256, Glass.T_SMALL + 2, SUB, 860)
		if ci != null:
			ci.draw_line(Vector2(cx - 200, 300), Vector2(cx + 200, 300), Color(1, 1, 1, 0.1), 1.5, true)
		for i in MenuCatalog.CREDITS.size():
			var cr: Array = MenuCatalog.CREDITS[i]
			var y := 368.0 + i * 128.0
			var box := Rect2(base + 64, y - 46, 760, 104)
			if ci != null:
				ci.draw_polygon(Glass.rounded(box, 20, 8), PackedColorArray([Color(1, 1, 1, 0.04)]))
				Glass.rim(ci, box, 20, 0.12, 0.04, 1.5)
			_text(ci, cr[0], cx, y, 30, ACCENT if i == 0 else TEXT, 720, "center", Glass.W_TITLE, TextServer.DIRECTION_LTR)
			_text(ci, _say(cr[1], cr[2]), cx, y + 38, Glass.T_SMALL + 1, SUB, 720)


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
		if ci != null and (y + 88.0 < 0.0 or y > LIST_HEIGHT):
			continue
		var value := int(c.get("value", 0))
		var goal := int(c.get("goal", 1))
		var done := value >= goal
		var r := Rect2(0, y, 824, 86)
		if ci != null:
			if done:
				Glass.card(ci, r, 16, "done")
			else:
				Glass.card(ci, r, 16, "rest")
		var ix := 36.0 if english else 788.0
		if done:
			_circle(ci, Vector2(ix, y + 36), 19, ACCENT)
			_icon(ci, "check", Vector2(ix, y + 36), 26, INK, Color(0, 0, 0, 0))
		else:
			_icon(ci, "challenges", Vector2(ix, y + 36), 36, Color(TEXT, 0.8), Color(ACCENT, 0.3))
		_text(ci, _say(str(c.get("title", "")), str(c.get("en", ""))), 70.0 if english else 754.0, y + 44, 25, TEXT, 600, "left" if english else "right", Glass.W_LABEL)
		_text(ci, "%d / %d" % [value, goal], 804.0 if english else 20.0, y + 44, 22, ACCENT if done else SUB, 110, "right" if english else "left", Glass.W_LABEL, TextServer.DIRECTION_LTR)
		_rect(ci, Rect2(24, y + 64, 776, 7), 3.5, Color(1, 1, 1, 0.09))
		var w := clampf(value / maxf(1.0, goal), 0.0, 1.0) * 776.0
		if w > 0.5:
			_rect(ci, Rect2(24.0 if english else 800.0 - w, y + 64, w, 7), 3.5, ACCENT if done else Color(ACCENT, 0.75))
