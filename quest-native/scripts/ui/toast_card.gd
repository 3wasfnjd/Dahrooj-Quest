class_name ToastCard
extends Node3D
## The notifications (xr-runtime.js "notifications", fed by complete-game.js toast()):
## a slim card (0.46 m wide, 1024 x 220 layout) that drops in near the top of your
## view, about 0.8 m ahead and tilted with your head, follows your gaze, then slides
## back up and fades. A challenge done ("✓ " prefix) shows a check badge for 3.4 s,
## anything else a "!" badge for 2.4 s; up to four wait in line. Dark style of
## Panel3D (rounded BG, coloured band on the reading side, Baloo 800 text).
## Call place(head) every frame with the head's global transform; step(dt) runs
## from _process unless auto_step is false.

signal buzz(kind: String)  ## a challenge or reward card appeared: pulse both hands (0.35, 60 ms)

const CW := 1024
const CH := 220
const WIDTH := 0.46
const PX := WIDTH / CW  # metres per layout pixel
const TOAST_HOLD := 2.3  # complete-game.js toast(): the text stays up 2.3 s
const CHALLENGE := Color("3f8f5a")
const REWARD := Color("e5ad2e")
const PAPER := Color(1, 1, 1)

const CARD_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_test_disabled, depth_draw_never, fog_disabled;
uniform vec4 bg;
uniform vec4 accent;
uniform vec4 edge;
uniform vec4 badge_in;
uniform vec4 paper;
uniform float rtl;
uniform float kind;
uniform float opacity;

float rrect(vec2 p, vec2 c, vec2 h, float r) {
	vec2 q = abs(p - c) - h + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a, ba = b - a;
	return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}
vec4 over(vec4 dst, vec3 c, float a) {
	return vec4(mix(dst.rgb, c, a), a + dst.a * (1.0 - a));
}
void fragment() {
	vec2 p = UV * vec2(1024.0, 220.0);
	float aa = max(fwidth(p.x), 0.5);
	vec4 o = vec4(0.0);
	float d = rrect(p, vec2(512.0, 106.0), vec2(492.0, 90.0), 56.0);
	float inside = clamp(0.5 - d / aa, 0.0, 1.0);
	o = over(o, bg.rgb, bg.a * inside);
	float band = rtl > 0.5 ? step(1004.0 - 14.0, p.x) : step(p.x, 20.0 + 14.0);
	o = over(o, accent.rgb, inside * band);
	o = over(o, edge.rgb, edge.a * clamp((1.5 - abs(d)) / aa + 0.5, 0.0, 1.0) * clamp(1.0 - band * inside, 0.0, 1.0));
	vec2 b = vec2(rtl > 0.5 ? 1024.0 - 118.0 : 118.0, 106.0);
	float bd = length(p - b);
	o = over(o, accent.rgb, clamp((56.0 - bd) / aa + 0.5, 0.0, 1.0));
	if (kind > 1.5) {
		o = over(o, badge_in.rgb, badge_in.a * clamp((47.0 - bd) / aa + 0.5, 0.0, 1.0));
	} else if (kind > 0.5) {
		float cd = min(seg(p, b + vec2(-25.0, 2.0), b + vec2(-6.0, 20.0)), seg(p, b + vec2(-6.0, 20.0), b + vec2(28.0, -19.0)));
		o = over(o, paper.rgb, clamp((6.5 - cd) / aa + 0.5, 0.0, 1.0));
	}
	ALBEDO = o.rgb;
	ALPHA = o.a * opacity;
}
"""

## When false the owner calls step(dt) itself.
var auto_step := true
## True while a menu is open: the card hides and waits (uiBusy()).
var busy := false
## "ar" / "en"; empty follows Save.arabic().
var lang := ""
## The rig's scale (the original sizes the offsets by rig.scale.x); 1 in metres.
var world_scale := 1.0
var cards: Array[Dictionary] = []  # waiting: {kind, title, sub}
var now: Dictionary = {}  # showing: {kind, title, sub, t}
var opacity := 0.0

var _head := Transform3D.IDENTITY
var _last := ""
var _last_left := 0.0
var _first := true
var _quad: MeshInstance3D
var _mat: ShaderMaterial
var _labels: Array[Label3D] = []

static var _shader: Shader
static var _fonts := {}


static func weight_font(w: int) -> Font:
	if not _fonts.has(w):
		# Panel3D.font() at weight w: the Arabic face, then the Latin one. Each face gets its
		# own variation (a variation of the shared font leaves its fallback at 400).
		var tag := TextServerManager.get_primary_interface().name_to_tag("wght")
		var latin := FontVariation.new()
		latin.base_font = load("res://assets/fonts/baloo-latin.woff2")
		latin.variation_opentype = {tag: w}
		var arabic_face := (load("res://assets/fonts/baloo-arabic.woff2") as FontFile).duplicate() as FontFile
		arabic_face.fallbacks = []
		var f := FontVariation.new()
		f.base_font = arabic_face
		f.variation_opentype = {tag: w}
		f.fallbacks = [latin]
		_fonts[w] = f
	return _fonts[w]


func _init() -> void:
	name = "ToastCard"
	visible = false
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CARD_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	_mat.render_priority = 6
	_mat.set_shader_parameter("bg", Panel3D.BG)
	_mat.set_shader_parameter("edge", Color(1, 1, 1, 0.1))
	_mat.set_shader_parameter("badge_in", Color(184 / 255.0, 184 / 255.0, 184 / 255.0, 0.95))
	_mat.set_shader_parameter("paper", PAPER)
	_quad = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(WIDTH, WIDTH * CH / CW)
	_quad.mesh = q
	_quad.material_override = _mat
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_quad)


## The head's global transform (XRCamera3D.global_transform), every frame.
func place(head: Transform3D) -> void:
	_head = head


## The game's toast text (complete-game.js toast()). "✓ title" is a finished challenge.
## The same text again while it is still up only keeps it up (the web game compares
## its live toast text with the last one it saw).
func show_text(text: String) -> void:
	if text == "":
		return
	if text == _last and _last_left > 0.0:
		_last_left = TOAST_HOLD
		return
	_last = text
	_last_left = TOAST_HOLD
	if text.begins_with("✓ "):
		notify("challenge", text.substr(2))
	else:
		var queued := false
		for n in cards:
			if n.title == text:
				queued = true
		if not queued and String(now.get("title", "")) != text:
			notify("info", text)


## kind: "challenge" | "reward" | "info"; at most four wait.
func notify(kind: String, title: String, sub := "") -> void:
	cards.append({"kind": kind, "title": title, "sub": sub})
	if cards.size() > 4:
		cards.pop_front()


func _arabic() -> bool:
	if lang != "":
		return lang != "en"
	var tree := Engine.get_main_loop() as SceneTree
	var save: Node = tree.root.get_node_or_null("Save") if tree else null
	return bool(save.call("arabic")) if save else true


func _accent(kind: String) -> Color:
	return CHALLENGE if kind == "challenge" else REWARD if kind == "reward" else Panel3D.ACCENT


## A label whose baseline sits at layout pixel (x, y).
func _text(t: String, w: int, size: int, color: Color, x: float, y: float, rtl: bool, center := false) -> Label3D:
	var f := weight_font(w)
	var l := Label3D.new()
	l.text = t
	l.font = f
	l.font_size = size * 2
	l.pixel_size = PX / 2.0
	l.modulate = color
	l.outline_size = 0
	l.no_depth_test = true
	l.render_priority = 7
	l.fixed_size = false
	l.shaded = false
	l.double_sided = false
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if center else (HORIZONTAL_ALIGNMENT_RIGHT if rtl else HORIZONTAL_ALIGNMENT_LEFT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	l.text_direction = TextServer.DIRECTION_RTL if rtl else TextServer.DIRECTION_LTR
	var descent := f.get_descent(size)
	l.position = Vector3((x - CW / 2.0) * PX, (CH / 2.0 - y - descent) * PX, 0.001)
	add_child(l)
	_labels.append(l)
	return l


func _draw_card(n: Dictionary) -> void:
	for l in _labels:
		l.queue_free()
	_labels.clear()
	var rtl := _arabic()
	var kind := String(n.kind)
	var accent := _accent(kind)
	_mat.set_shader_parameter("accent", accent)
	_mat.set_shader_parameter("rtl", 1.0 if rtl else 0.0)
	_mat.set_shader_parameter("kind", 1.0 if kind == "challenge" else 2.0 if kind == "reward" else 0.0)
	var bx := CW - 118.0 if rtl else 118.0
	var by := CH / 2.0 - 4.0
	if kind == "info":
		_text("!", 800, 64, PAPER, bx, by + 23.0, rtl, true)
	var tx := CW - 206.0 if rtl else 206.0
	var sub := String(n.sub)
	var head := ""
	if kind == "challenge":
		head = "تحدّي مكتمل" if rtl else "Challenge complete"
	elif kind == "reward":
		head = "مكافأة جديدة" if rtl else "New reward"
	else:
		head = "دحروج" if rtl else "Dahrooj"
	_text(head, 800, 28, accent, tx, 66.0 if sub != "" else 78.0, rtl)
	var title := String(n.title)
	var size := 46
	var f := weight_font(800)
	while size > 24 and f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > CW - 260:
		size -= 2
	_text(title, 800, size, Panel3D.TEXT, tx, 118.0 if sub != "" else 136.0, rtl)
	if sub != "":
		_text(sub, 700, 26, Panel3D.SUB, tx, 160.0, rtl)


func _process(delta: float) -> void:
	if auto_step:
		step(delta)


static func _ease(k: float) -> float:
	return 1.0 - pow(1.0 - k, 3.0)


func step(dt: float) -> void:
	if _last_left > 0.0:
		_last_left -= dt
		if _last_left <= 0.0:
			_last = ""
	if busy:
		visible = false
		return
	if now.is_empty() and not cards.is_empty():
		now = cards.pop_front()
		now.t = 0.0
		_first = true
		_draw_card(now)
		if now.kind != "info":
			buzz.emit(String(now.kind))
	if now.is_empty():
		visible = false
		opacity = 0.0
		return
	var life := 2.4 if now.kind == "info" else 3.4
	now.t = float(now.t) + dt
	var t: float = now.t
	var eye := _head.origin
	var fwd := (-_head.basis.z).normalized()
	var up := _head.basis.y.normalized()
	var s := world_scale
	var in_k := minf(1.0, t / 0.3)
	var out_k := clampf((life - t) / 0.3, 0.0, 1.0)
	var slide := (1.0 - _ease(in_k)) + (1.0 - _ease(out_k))
	var spot := eye + fwd * 0.8 * s + up * (0.23 + 0.07 * slide) * s
	var at := _get_pos()
	_set_pos(spot if _first else at.lerp(spot, 1.0 - exp(-dt * 9.0)))
	_first = false
	if _get_pos().distance_squared_to(eye) > 1e-8:
		_look(eye)
	opacity = minf(_ease(in_k), _ease(out_k))
	_mat.set_shader_parameter("opacity", opacity)
	for l in _labels:
		l.modulate.a = opacity
	visible = opacity > 0.01
	if t >= life:
		now = {}


func _get_pos() -> Vector3:
	return global_position if is_inside_tree() else position


func _set_pos(p: Vector3) -> void:
	if is_inside_tree():
		global_position = p
	else:
		position = p


## Face the eye (+Z toward it, as three.js lookAt does for a mesh).
func _look(eye: Vector3) -> void:
	var z := (eye - _get_pos()).normalized()
	var x := Vector3.UP.cross(z)
	if x.length_squared() < 1e-6:
		x = Vector3.RIGHT
	x = x.normalized()
	var b := Basis(x, z.cross(x), z) * Basis.from_scale(Vector3.ONE * world_scale)
	if is_inside_tree():
		global_basis = b
	else:
		basis = b
