class_name ToastCard
extends Node3D
## The notifications (xr-runtime.js "notifications", fed by complete-game.js toast()), in
## Dahrooj's own jelly style rather than a phone banner: a chunky glossy jelly pill (green for
## a challenge done, gold for a reward, pink for a note; 0.4 m wide, 1024 x 220 layout) with a
## white jelly badge (a check, a star or "!") and white outlined words. It bounces up from
## below the gaze (about 19° down, 0.8 m ahead), wobbles like jelly, follows your gaze, then
## squashes and drops away. Challenge 3.4 s, notes 2.4 s. Challenge and reward cards always
## wait their turn (several finished at once each get theirs); at most QUEUE_INFO plain notes
## wait, the oldest note giving way. Low in view, clear of the HUD's score and the banners.
## Call place(head) every frame with the head's global transform; step(dt) runs
## from _process unless auto_step is false.

signal buzz(kind: String)  ## a challenge or reward card appeared: pulse both hands (0.35, 60 ms)

const CW := 1024
const CH := 220
const WIDTH := 0.4
const PX := WIDTH / CW  # metres per layout pixel
const TOAST_HOLD := 2.3
## Plain notes ("!") that may wait; challenge and reward cards are never dropped (up to
## QUEUE_MAX in all, far more than ever finish at once).
const QUEUE_INFO := 4
const QUEUE_MAX := 32  # complete-game.js toast(): the text stays up 2.3 s
const CHALLENGE := Color("3f8f5a")
const REWARD := Color("e5ad2e")
const PAPER := Color(1, 1, 1)

const CARD_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_test_disabled, depth_draw_never, fog_disabled;
uniform vec4 bg;
uniform vec4 bg2;
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
// A five-point star (the reward badge), inner/outer radius ratio ~0.45.
float star5(vec2 p, float r) {
	const vec2 k1 = vec2(0.809016994375, -0.587785252292);
	const vec2 k2 = vec2(-0.809016994375, -0.587785252292);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = 0.45 * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}
void fragment() {
	vec2 p = UV * vec2(1024.0, 220.0);
	float aa = max(fwidth(p.x), 0.5);
	vec4 o = vec4(0.0);
	// The jelly's deeper base just below it (its depth, like the score digits' extrusion).
	float db = rrect(p, vec2(512.0, 116.0), vec2(490.0, 86.0), 86.0);
	o = over(o, bg2.rgb * 0.5, clamp(0.5 - db / aa, 0.0, 1.0));
	// The jelly pill: light on top, deeper below.
	float d = rrect(p, vec2(512.0, 104.0), vec2(490.0, 86.0), 86.0);
	float inside = clamp(0.5 - d / aa, 0.0, 1.0);
	float k = clamp((p.y - 18.0) / 172.0, 0.0, 1.0);
	o = over(o, mix(bg.rgb, bg2.rgb, k * k), inside);
	// Gloss: a soft white band across the top, and a light rim.
	float g = rrect(p, vec2(512.0, 50.0), vec2(420.0, 20.0), 20.0);
	o = over(o, vec3(1.0), 0.36 * clamp(0.5 - g / 8.0, 0.0, 1.0) * inside);
	o = over(o, vec3(1.0), 0.4 * clamp((2.5 - abs(d + 3.0)) / aa + 0.5, 0.0, 1.0));
	// The badge: a white jelly bubble on the reading side, its mark in the card's colour.
	vec2 b = vec2(rtl > 0.5 ? 1024.0 - 110.0 : 110.0, 104.0);
	o = over(o, bg2.rgb * 0.5, clamp((60.0 - length(p - b - vec2(0.0, 7.0))) / aa + 0.5, 0.0, 1.0));
	float bd = length(p - b);
	o = over(o, paper.rgb, clamp((58.0 - bd) / aa + 0.5, 0.0, 1.0));
	o = over(o, vec3(1.0), 0.0);
	if (kind > 1.5) {
		float sd = star5((p - b) * vec2(1.0, -1.0), 38.0);
		o = over(o, accent.rgb, clamp(0.5 - sd / aa, 0.0, 1.0));
	} else if (kind > 0.5) {
		float cd = min(seg(p, b + vec2(-25.0, 2.0), b + vec2(-6.0, 20.0)), seg(p, b + vec2(-6.0, 20.0), b + vec2(28.0, -19.0)));
		o = over(o, accent.rgb, clamp((8.5 - cd) / aa + 0.5, 0.0, 1.0));
	}
	// A sparkle of gloss on the badge.
	o = over(o, vec3(1.0), 0.55 * clamp((9.0 - length(p - b - vec2(-22.0, -26.0))) / aa + 0.5, 0.0, 1.0));
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
var _ink := Color(0.1, 0.2, 0.15)  # the labels' outline: the jelly's colour, deep

static var _shader: Shader


static func weight_font(w: int) -> Font:
	return Glass.font(w)


func _init() -> void:
	name = "ToastCard"
	visible = false
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CARD_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	_mat.render_priority = 6
	_mat.set_shader_parameter("bg", Glass.TINT_TOP)
	_mat.set_shader_parameter("bg2", Glass.TINT_BOTTOM)
	_mat.set_shader_parameter("edge", Color(1, 1, 1, 0.34))
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
	# A finished challenge always gets its card: each completion happens once (GameRuntime),
	# so the same title again is a new completion (after a reset), never a repeat to fold.
	if text.begins_with("✓ "):
		_last = text
		_last_left = TOAST_HOLD
		notify("challenge", text.substr(2))
		return
	if text == _last and _last_left > 0.0:
		_last_left = TOAST_HOLD
		return
	_last = text
	_last_left = TOAST_HOLD
	var queued := false
	for n in cards:
		if n.title == text:
			queued = true
	if not queued and String(now.get("title", "")) != text:
		notify("info", text)


## kind: "challenge" | "reward" | "info". Challenge and reward cards always wait their turn;
## past QUEUE_INFO waiting notes (or QUEUE_MAX cards) the oldest plain note gives way.
func notify(kind: String, title: String, sub := "") -> void:
	cards.append({"kind": kind, "title": title, "sub": sub})
	var infos := cards.filter(func(n: Dictionary) -> bool: return n.kind == "info").size()
	while infos > QUEUE_INFO or cards.size() > QUEUE_MAX:
		var drop := -1
		for i in cards.size():
			if cards[i].kind == "info":
				drop = i
				break
		if drop < 0:
			drop = 0
		if cards[drop].kind == "info":
			infos -= 1
		cards.remove_at(drop)


func _arabic() -> bool:
	if lang != "":
		return lang != "en"
	var tree := Engine.get_main_loop() as SceneTree
	var save: Node = tree.root.get_node_or_null("Save") if tree else null
	return bool(save.call("arabic")) if save else true


func _accent(kind: String) -> Color:
	return CHALLENGE if kind == "challenge" else REWARD if kind == "reward" else Panel3D.ACCENT


## The jelly's two colours (light top, deep bottom) for each kind of card.
static func jelly(kind: String) -> Array:
	match kind:
		"challenge":
			return [Color("8cf2ad"), Color("2aa25c")]
		"reward":
			return [Color("ffe27a"), Color("e09a1a")]
	return [Color("ff9ccb"), Color("e0457f")]


## A label whose baseline sits at layout pixel (x, y).
func _text(t: String, w: int, size: int, color: Color, x: float, y: float, rtl: bool, center := false, outlined := true) -> Label3D:
	var f := weight_font(w)
	var l := Label3D.new()
	l.text = t
	l.font = f
	l.font_size = size * 2
	l.pixel_size = PX / 2.0
	l.modulate = color
	# White words with a deep outline in the jelly's colour, like the game's jelly texts.
	l.outline_size = 14 if outlined else 0
	l.outline_modulate = _ink
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
	var j := jelly(kind)
	_mat.set_shader_parameter("bg", j[0])
	_mat.set_shader_parameter("bg2", j[1])
	_mat.set_shader_parameter("accent", (j[1] as Color).darkened(0.1))
	_ink = (j[1] as Color).darkened(0.55)
	_mat.set_shader_parameter("rtl", 1.0 if rtl else 0.0)
	_mat.set_shader_parameter("kind", 1.0 if kind == "challenge" else 2.0 if kind == "reward" else 0.0)
	var bx := CW - 118.0 if rtl else 118.0
	var by := CH / 2.0 - 4.0
	if kind == "info":
		_text("!", 800, 64, (j[1] as Color).darkened(0.1), bx, by + 23.0, rtl, true, false)
	var tx := CW - 206.0 if rtl else 206.0
	var sub := String(n.sub)
	var head := ""
	if kind == "challenge":
		head = "تحدّي مكتمل" if rtl else "Challenge complete"
	elif kind == "reward":
		head = "مكافأة جديدة" if rtl else "New reward"
	else:
		head = "دحروج" if rtl else "Dahrooj"
	var max_w := text_width()
	_text(head, 800, Glass.fit_size(head, 28, max_w, 800), Color(1, 1, 1, 0.92), tx, 66.0 if sub != "" else 78.0, rtl)
	var title := String(n.title)
	_text(title, 800, Glass.fit_size(title, 46, max_w, 800, -1, 22), PAPER, tx, 118.0 if sub != "" else 136.0, rtl)
	if sub != "":
		_text(sub, 700, Glass.fit_size(sub, 26, max_w, 700, -1, 16), Color(1, 1, 1, 0.9), tx, 160.0, rtl)


## The room for text: from past the badge to the card's far inner edge.
static func text_width() -> float:
	return CW - 206.0 - 52.0


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
	# Low in view (about 19° below the gaze), clear of the HUD's score and the stages' banners
	# above; it bounces up from below and drops back down when done.
	var spot := eye + fwd * 0.8 * s + up * (-0.27 - 0.08 * slide) * s
	var at := _get_pos()
	_set_pos(spot if _first else at.lerp(spot, 1.0 - exp(-dt * 9.0)))
	_first = false
	if _get_pos().distance_squared_to(eye) > 1e-8:
		_look(eye, jelly_squash(t, life))
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


## The card's jelly wobble (x, y scale): it pops in a little too big, wobbles and settles,
## and squashes down as it leaves.
static func jelly_squash(t: float, life: float) -> Vector2:
	var pop := 0.6 + 0.4 * minf(1.0, t / 0.18)
	var w := sin(t * 20.0) * exp(-t * 6.0) * 0.12
	var out := clampf((life - t) / 0.3, 0.0, 1.0)
	var leave := 0.7 + 0.3 * out
	return Vector2(pop * (1.0 + w) * leave, pop * (1.0 - w) * (0.4 + 0.6 * out))


## Face the eye (+Z toward it, as three.js lookAt does for a mesh), with a jelly squash.
func _look(eye: Vector3, squash := Vector2.ONE) -> void:
	var z := (eye - _get_pos()).normalized()
	var x := Vector3.UP.cross(z)
	if x.length_squared() < 1e-6:
		x = Vector3.RIGHT
	x = x.normalized()
	var b := Basis(x, z.cross(x), z) * Basis.from_scale(Vector3(squash.x, squash.y, 1.0) * world_scale)
	if is_inside_tree():
		global_basis = b
	else:
		basis = b
