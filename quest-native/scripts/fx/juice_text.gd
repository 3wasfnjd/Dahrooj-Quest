class_name JuiceText
extends Node3D
## The shared in-world feedback text in the Dahrooj style (the jelly score popup's
## look: Baloo at weight 800, every glyph its own jelly hue with a vertical gradient,
## a dark extruded copy under it and a light rim on top), for points (+1, +10, -2),
## combos (COMBO ×3 / كومبو ×3: bigger, rainbow, shaking, star bursts), banners (wave
## and mode titles), their subtitles ("sub") and soft grey-blue "ouch" / "miss" texts.
##
## Two ways to use it:
## - JuiceText.spawn(parent, text, pos, kind, scale, color): a fire-and-forget text
##   at pos (parent-local) that pops in, squashes, wobbles, rises and fades by itself.
##   Pooled per parent (a "JuiceLayer" child), pictures cached per distinct string.
## - JuiceText.make(kind, em): a persistent text the owner places, scales and fades
##   (position / scale / modulate.a / visible / text), like a Label3D. Its picture
##   adds its own juice on top: a jelly pop when the text changes, a gentle bounce,
##   the rainbow cycle and the stars of a combo.
##
## Each picture is drawn once into a small transparent SubViewport (shaped by the
## TextServer, so Arabic joins correctly) and shown on a quad that always faces the
## viewer (Y-up billboard in the shader), ignores depth (no z-fighting, drawn late)
## and is unshaded and fog-free. Digits are Western for points and combos in both
## languages (like the score popup); banners keep their words as given.

const KINDS := {
	"points": {"px": 140, "em": 0.66, "life": 1.0, "cycle": 0.0, "stars": 0, "sat": 1.0},
	"combo": {"px": 160, "em": 0.85, "life": 1.35, "cycle": 0.45, "stars": 8, "sat": 1.0},
	"banner": {"px": 170, "em": 1.3, "life": 1.8, "cycle": 0.08, "stars": 10, "sat": 1.0},
	"sub": {"px": 110, "em": 0.56, "life": 1.8, "cycle": 0.0, "stars": 0, "sat": 0.75},
	"ouch": {"px": 140, "em": 0.7, "life": 1.1, "cycle": 0.0, "stars": 0, "sat": 0.32},
	"miss": {"px": 120, "em": 0.6, "life": 1.0, "cycle": 0.0, "stars": 0, "sat": 0.25},
}
## How big each kind is drawn against its em (the owner found the texts too big in play):
## round titles about half their first size, and the little ones (+1, combos, ouch, miss)
## about a third of a round title's height.
const SIZE_K := {"banner": 0.55, "sub": 0.7, "points": 0.36, "combo": 0.33, "ouch": 0.34, "miss": 0.38}
## The festive palette (degrees) that walks across the glyphs of a word.
const FESTIVE: Array[float] = [330.0, 42.0, 190.0, 112.0, 275.0, 18.0, 205.0, 55.0]
const POOL := 14
const CACHE := 28
const PRIORITY := 3

const CANVAS_SHADER := """
shader_type canvas_item;
uniform sampler2D hue_tex : filter_nearest;
uniform float mode;
uniform float y0;
uniform float y1;
uniform float w;
varying vec2 lp;
vec3 hsl(float h, float s, float l) {
	vec3 rgb = clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	return l + s * (rgb - 0.5) * (1.0 - abs(2.0 * l - 1.0));
}
void vertex() { lp = VERTEX; }
void fragment() {
	vec4 hs = texture(hue_tex, vec2(clamp(lp.x / w, 0.0, 1.0), 0.5));
	float h = hs.r;
	float s = hs.g;
	vec3 col;
	if (mode < 0.5) {
		col = hsl(h, 0.55 * s, 0.17);
	} else if (mode < 1.5) {
		col = hsl(h, 0.72 * s, 0.32);
	} else if (mode < 2.5) {
		col = hsl(h, 0.95 * s, 0.9);
	} else {
		float k = clamp((lp.y - y0) / max(1.0, y1 - y0), 0.0, 1.0);
		col = mix(hsl(h, 0.95 * s, 0.97), hsl(h, 0.95 * s, 0.80), clamp(k / 0.22, 0.0, 1.0));
		col = mix(col, hsl(h, 0.92 * s, 0.64), clamp((k - 0.22) / 0.28, 0.0, 1.0));
		col = mix(col, hsl(h, 0.88 * s, 0.55), clamp((k - 0.5) / 0.06, 0.0, 1.0));
		col = mix(col, hsl(h, 0.8 * s, 0.43), clamp((k - 0.56) / 0.44, 0.0, 1.0));
	}
	COLOR = vec4(col, texture(TEXTURE, UV).a * COLOR.a);
}
"""

const QUAD_SHADER := """
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D tex : source_color, filter_linear;
uniform float opacity = 1.0;
uniform vec2 squash = vec2(1.0);
uniform float tilt = 0.0;
uniform float spread = 0.0;
uniform float hue_shift = 0.0;
vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}
vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}
void vertex() {
	vec2 v = VERTEX.xy * vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz)) * squash;
	float cs = cos(tilt);
	float sn = sin(tilt);
	VERTEX = vec3(v.x * cs - v.y * sn, v.x * sn + v.y * cs, 0.0);
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
	vec3 fwd = normalize(cross(right, vec3(0.0, 1.0, 0.0)));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(-fwd, 0.0), MODEL_MATRIX[3]);
}
void fragment() {
	vec4 t = texture(tex, UV);
	vec3 rgb = t.rgb / max(t.a, 0.0001);
	float shift = hue_shift + spread * UV.x;
	if (abs(shift) > 0.0001) {
		vec3 hsv = rgb2hsv(rgb);
		hsv.x = fract(hsv.x + shift);
		rgb = hsv2rgb(hsv);
	}
	ALBEDO = rgb * t.a * opacity;
	ALPHA = t.a * opacity;
}
"""

const STAR_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
varying vec4 col;
float star5(vec2 p, float r, float rf) {
	const vec2 k1 = vec2(0.809016994375, -0.587785252292);
	const vec2 k2 = vec2(-0.809016994375, -0.587785252292);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}
void vertex() {
	col = COLOR;
	float sc = length(MODEL_MATRIX[0].xyz);
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
	vec3 fwd = normalize(cross(right, vec3(0.0, 1.0, 0.0)));
	VERTEX = VERTEX * sc;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(-fwd, 0.0), MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = (UV - 0.5) * vec2(2.0, -2.0);
	float d = star5(p, 0.82, 0.48);
	float aa = fwidth(d) + 0.01;
	float body = 1.0 - smoothstep(-aa, aa, d);
	float edge = 1.0 - smoothstep(-aa, aa, d - 0.12);
	float glow = exp(-max(d, 0.0) * 6.0) * 0.35;
	float k = clamp(0.5 - p.y * 0.6, 0.0, 1.0);
	vec3 fill = mix(vec3(1.0), col.rgb, k * 0.85);
	vec3 rgb = mix(col.rgb * 0.25, fill, body);
	float a = max(edge, glow);
	ALBEDO = mix(col.rgb, rgb, max(body, edge));
	ALPHA = a * col.a;
}
"""

## Which picture this item shows, how it moves.
var kind := "points"
var text := "":
	set = set_text
## rgb picks the theme hue (as a Label3D's modulate); a is the opacity.
var modulate := Color.WHITE:
	set = set_modulate
## The font size in metres (scale 1).
var em := 0.66
## Spawned (self-moving) or placed by its owner.
var spawned := false
var age := 99.0
var life := 1.0
var start := Vector3.ZERO
var tint = null
var quad: MeshInstance3D
var material: ShaderMaterial
## The picture's size in pixels (tests and tools).
var picture := Vector2i.ZERO

var _stars: MultiMeshInstance3D
var _star_dirs: Array = []
var _viewport: SubViewport  # persistent texts own theirs
var _key := ""
var _base := 1.0
var _shake := 0.0

static var _font: FontVariation
static var _canvas_shader: Shader
static var _quad_shader: Shader
static var _star_shader: Shader
static var _star_mat: ShaderMaterial
static var _quad_mesh: QuadMesh


## Baloo at weight 800 with Arabic first and the Latin face as fallback.
static func font() -> Font:
	if _font == null:
		_font = FontVariation.new()
		_font.base_font = load("res://assets/fonts/baloo-arabic.woff2")
		_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
		_font.fallbacks = [ScorePopup.bold_font()]
	return _font


## Eastern Arabic digits to Western ones (points and combos use Latin digits).
static func western(s: String) -> String:
	var out := ""
	for ch in s:
		var c := ch.unicode_at(0)
		if c >= 0x0660 and c <= 0x0669:
			out += char(0x30 + c - 0x0660)
		elif c >= 0x06F0 and c <= 0x06F9:
			out += char(0x30 + c - 0x06F0)
		else:
			out += ch
	return out


static func _is_arabic(c: int) -> bool:
	return (c >= 0x0600 and c <= 0x06FF) or (c >= 0x0750 and c <= 0x077F) or (c >= 0xFB50 and c <= 0xFEFF)


## A fire-and-forget text at pos (parent-local). color: a Color (theme hue) or null
## (festive per-glyph hues). Returns the item (pooled: do not keep it).
static func spawn(parent: Node3D, txt: String, pos: Vector3, k := "points", scale_k := 1.0, color = null) -> JuiceText:
	var layer := _layer(parent)
	return layer.fire(txt, pos, k, scale_k, color)


## Hides every spawned text under parent (a stage reset).
static func clear(parent: Node3D) -> void:
	var layer := parent.get_node_or_null("JuiceLayer") as Layer
	if layer:
		for it: JuiceText in layer.items:
			it.age = 99.0
			it.visible = false


## The spawned texts under parent that are showing (tests).
static func showing(parent: Node3D) -> Array:
	var layer := parent.get_node_or_null("JuiceLayer") as Layer
	if layer == null:
		return []
	return layer.items.filter(func(it: JuiceText) -> bool: return it.visible)


## A persistent text its owner moves (banner, combo...). em: font size in metres.
static func make(k := "banner", em_m := -1.0) -> JuiceText:
	var j := JuiceText.new()
	j.kind = k
	j.em = em_m if em_m > 0.0 else float(KINDS.get(k, KINDS.points).em)
	j.visible = false
	j._viewport = SubViewport.new()
	j._viewport.transparent_bg = true
	j._viewport.disable_3d = true
	j._viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	j._viewport.size = Vector2i(4, 4)
	j.add_child(j._viewport)
	j.material.set_shader_parameter("tex", j._viewport.get_texture())
	return j


static func _layer(parent: Node3D) -> Layer:
	var layer := parent.get_node_or_null("JuiceLayer") as Layer
	if layer == null:
		layer = Layer.new()
		layer.name = "JuiceLayer"
		parent.add_child(layer)
	return layer


func _init() -> void:
	name = "JuiceText"
	if _quad_shader == null:
		_quad_shader = Shader.new()
		_quad_shader.code = QUAD_SHADER
		_quad_mesh = QuadMesh.new()
	quad = MeshInstance3D.new()
	quad.name = "Quad"
	quad.mesh = _quad_mesh
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.extra_cull_margin = 4.0
	material = ShaderMaterial.new()
	material.shader = _quad_shader
	material.render_priority = PRIORITY
	quad.material_override = material
	add_child(quad)


func set_text(v: String) -> void:
	if v == text:
		return
	text = v
	if _viewport != null:
		_repaint()
		age = 0.0
		_burst()


func set_modulate(c: Color) -> void:
	var rgb_changed := not (is_equal_approx(c.r, modulate.r) and is_equal_approx(c.g, modulate.g) and is_equal_approx(c.b, modulate.b))
	modulate = c
	if rgb_changed and _viewport != null:
		tint = Color(c.r, c.g, c.b)
		_repaint()


func _repaint() -> void:
	if text == "":
		return
	picture = JuiceText.paint(_viewport, text, kind, tint)
	_fit()


## Sizes the quad to the picture: its em (px) maps to em metres.
func _fit() -> void:
	var px := float(KINDS.get(kind, KINDS.points).px)
	var k := float(SIZE_K.get(kind, 0.55))
	quad.scale = Vector3(picture.x / px * em * k, picture.y / px * em * k, 1.0)


## Draws txt into vp (resized to fit) and returns the picture size in pixels.
static func paint(vp: SubViewport, txt: String, k: String, color = null) -> Vector2i:
	for c in vp.get_children():
		vp.remove_child(c)
		c.queue_free()
	var K: Dictionary = KINDS.get(k, KINDS.points)
	var shown := western(txt) if k in ["points", "combo", "ouch", "miss"] else txt
	var px := int(K.px)
	var f := font()
	var line := TextLine.new()
	var rtl := false
	for ch in shown:
		rtl = rtl or _is_arabic(ch.unicode_at(0))
	line.direction = TextServer.DIRECTION_AUTO if rtl else TextServer.DIRECTION_LTR  # "-2" reads -2 in both languages
	if rtl:  # inside Arabic, "+2" and "×3" still read as they do in the score popup
		var re := RegEx.create_from_string("[+\\-×]?[0-9]+")
		shown = re.sub(shown, "\u2066$0\u2069", true)
	line.add_string(shown, f, px)
	var width := line.get_size().x
	var asc := line.get_line_ascent()
	var deep := px * 0.075  # the extruded copy's drop
	var pad := px * 0.2
	var w := clampi(int(ceil(width + pad * 2.0)), 8, 2048)
	# The ink's extent (Baloo's line box has lots of room above and below).
	var ts := TextServerManager.get_primary_interface()
	var top := -asc * 0.75
	var bottom := 0.0
	var found := false
	for g: Dictionary in ts.shaped_text_get_glyphs(line.get_rid()):
		var rid: RID = g.get("font_rid", RID())
		var index: int = g.get("index", 0)
		if not rid.is_valid():
			continue
		var gsize := Vector2i(px, 0)
		ts.font_render_glyph(rid, gsize, index)
		var off: Vector2 = ts.font_get_glyph_offset(rid, gsize, index)
		var sz: Vector2 = ts.font_get_glyph_size(rid, gsize, index)
		if sz.y <= 0.0:
			continue
		var gy: float = (g.get("y_off", 0.0) as float)
		top = minf(top, off.y + gy) if found else off.y + gy
		bottom = maxf(bottom, off.y + gy + sz.y)
		found = true
	var h := clampi(int(ceil(bottom - top + pad * 2.0 + deep)), 8, 1024)
	vp.size = Vector2i(w, h)
	var at := Vector2((w - width) / 2.0, pad - asc - top)
	var base_y := at.y + asc
	# Per-glyph hues: Latin glyphs step through the palette, Arabic ones blend.
	var centers: Array = []
	var x := at.x
	for g: Dictionary in ts.shaped_text_get_glyphs(line.get_rid()):
		var adv: float = g.get("advance", 0.0)
		var st: int = g.get("start", 0)
		var ch := shown.unicode_at(clampi(st, 0, shown.length() - 1)) if shown.length() > 0 else 32
		if adv > 0.0 and ch != 32:
			centers.append([x + adv / 2.0, _is_arabic(ch), ch])
		x += adv
	var hues: Array[float] = []
	var sat := float(K.sat)
	var base_h := -1.0
	if color is Color:
		base_h = (color as Color).h * 360.0
		if (color as Color).s < 0.15:  # near white: a warm cream-gold
			base_h = 42.0
			sat *= 0.6
	for i in centers.size():
		var ch: int = centers[i][2]
		var hue: float
		if k == "ouch" or k == "miss":
			hue = 212.0 + (i % 2) * 14.0
		elif base_h >= 0.0:
			hue = base_h + [0.0, 16.0, -10.0, 22.0][i % 4]
		elif ch >= 0x30 and ch <= 0x39 and k == "points":
			hue = ScorePopup.HUES[ch - 0x30]
		else:
			hue = FESTIVE[i % FESTIVE.size()]
		hues.append(fposmod(hue, 360.0))
	var img := Image.create(w, 1, false, Image.FORMAT_RGB8)
	for px_x in w:
		var hue := 45.0
		if not centers.is_empty():
			var j := 0
			var best := 1e9
			for i in centers.size():
				var d := absf(float(centers[i][0]) - px_x)
				if d < best:
					best = d
					j = i
			hue = hues[j]
			if centers[j][1]:  # Arabic: blend toward the neighbour
				var c0: float = centers[j][0]
				var n := j + (1 if px_x > c0 else -1)
				if n >= 0 and n < centers.size() and centers[n][1]:
					var c1: float = centers[n][0]
					var tt := clampf((px_x - c0) / (c1 - c0), 0.0, 0.5)
					var dh := fposmod(hues[n] - hue + 180.0, 360.0) - 180.0
					hue = fposmod(hue + dh * tt, 360.0)
		img.set_pixel(px_x, 0, Color(hue / 360.0, sat, 0.0))
	var hue_tex := ImageTexture.create_from_image(img)
	if _canvas_shader == null:
		_canvas_shader = Shader.new()
		_canvas_shader.code = CANVAS_SHADER
	var canvas := Node2D.new()
	vp.add_child(canvas)
	var y0 := base_y - px * 0.62
	var y1 := base_y + px * 0.08
	var o_deep := int(px * 0.30)
	var o_rim := int(px * 0.09)
	var layers := [[Vector2(0, deep), o_deep, 0.0], [Vector2(0, deep), 0, 1.0], [Vector2.ZERO, o_rim, 2.0], [Vector2.ZERO, 0, 3.0]]
	for L: Array in layers:
		var n := Ink.new()
		n.line = line
		n.at = at + (L[0] as Vector2)
		n.outline = L[1]
		var sm := ShaderMaterial.new()
		sm.shader = _canvas_shader
		sm.set_shader_parameter("hue_tex", hue_tex)
		sm.set_shader_parameter("mode", L[2])
		sm.set_shader_parameter("y0", y0)
		sm.set_shader_parameter("y1", y1)
		sm.set_shader_parameter("w", float(w))
		n.material = sm
		canvas.add_child(n)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	return Vector2i(w, h)


## One layer of ink (outline or fill) of a shaped line.
class Ink extends Node2D:
	var line: TextLine
	var at := Vector2.ZERO
	var outline := 0

	func _draw() -> void:
		if outline > 0:
			line.draw_outline(get_canvas_item(), at, outline, Color.WHITE)
		else:
			line.draw(get_canvas_item(), at, Color.WHITE)


func _ensure_stars(n: int) -> void:
	if _stars != null or n <= 0:
		return
	if _star_shader == null:
		_star_shader = Shader.new()
		_star_shader.code = STAR_SHADER
		_star_mat = ShaderMaterial.new()
		_star_mat.shader = _star_shader
		_star_mat.render_priority = PRIORITY + 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _quad_mesh
	mm.instance_count = n
	mm.visible_instance_count = 0
	_stars = MultiMeshInstance3D.new()
	_stars.name = "Stars"
	_stars.multimesh = mm
	_stars.material_override = _star_mat
	_stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stars.extra_cull_margin = 4.0
	add_child(_stars)
	for i in n:
		var a := TAU * (i + 0.5) / n + randf_range(-0.25, 0.25)
		_star_dirs.append([Vector2(cos(a), sin(a) * 0.75), randf_range(0.8, 1.25), FESTIVE[(i * 3) % FESTIVE.size()]])


func _burst() -> void:
	var n := int(KINDS.get(kind, KINDS.points).stars)
	if n <= 0:
		return
	_ensure_stars(n)
	for d: Array in _star_dirs:
		var a := randf() * TAU
		d[0] = Vector2(cos(a), sin(a) * 0.7)
		d[1] = randf_range(0.75, 1.3)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not spawned and visible:
		age = 0.0  # every showing pops in again
		_burst()


func _process(dt: float) -> void:
	if not spawned and visible:
		step(dt)


## Advances the juice (spawned: the whole flight; placed: the picture's own bounce).
func step(dt: float) -> void:
	age += dt
	var K: Dictionary = KINDS.get(kind, KINDS.points)
	var t := age
	var big := kind == "combo" or kind == "banner"
	# Pop-in with an overshoot (easeOutBack), then jelly squash and stretch.
	var enter := minf(1.0, t / (0.2 if big else 0.16))
	var c1 := 2.4 if big else 1.9
	var pop := 1.0 + (c1 + 1.0) * pow(enter - 1.0, 3.0) + c1 * pow(enter - 1.0, 2.0)
	var j := sin(t * 19.0) * exp(-t * 6.5) * (0.2 if big else 0.16)
	var breathe := 0.0 if spawned else sin(t * 4.0) * 0.025
	var tilt := sin(t * 13.0) * exp(-t * 5.0) * 0.09
	var opacity := 1.0
	var off := Vector3.ZERO
	if kind == "ouch" or kind == "miss":
		j *= 0.6
		tilt = sin(t * 5.0) * 0.07 * minf(1.0, t * 3.0)
	if kind == "combo":
		tilt += sin(t * 31.0) * 0.05 * exp(-t * 1.5)
		off = Vector3(sin(t * 63.0), cos(t * 57.0), 0.0) * 0.035 * em * exp(-t * 3.0)
	if spawned:
		var k := clampf(t / life, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 2.2)
		var rise := (1.5 if big else 1.25) * em * _base
		if kind == "ouch" or kind == "miss":
			off.y += -0.25 * em * _base * e + 0.35 * em * _base * minf(1.0, t * 6.0)
		else:
			off.y += rise * (0.2 + e)
		position = start + off
		var fade := clampf((k - 0.62) / 0.38, 0.0, 1.0)
		opacity = minf(1.0, t / 0.06) * (1.0 - fade * fade * (3.0 - 2.0 * fade))
		scale = Vector3.ONE * _base * maxf(0.05, pop) * (1.0 + 0.12 * fade)
		visible = t < life
	else:
		quad.position = off
		quad.scale.z = 1.0
		opacity = modulate.a
		var p := maxf(0.05, pop) * (1.0 + breathe)
		material.set_shader_parameter("squash", Vector2((1.0 + j) * p, (1.0 - j) * p))
	if spawned:
		material.set_shader_parameter("squash", Vector2(1.0 + j, 1.0 - j))
	material.set_shader_parameter("tilt", tilt)
	material.set_shader_parameter("opacity", opacity)
	# Untinted big moments walk the rainbow (a tint keeps its meaning: gold, rage red...).
	var cyc := float(K.cycle) if tint == null else 0.0
	material.set_shader_parameter("hue_shift", fposmod(cyc * t, 1.0))
	material.set_shader_parameter("spread", 0.6 if kind == "combo" and tint == null else 0.0)
	_step_stars(t, opacity)


func _step_stars(t: float, opacity: float) -> void:
	if _stars == null:
		return
	var mm := _stars.multimesh
	var n := _star_dirs.size()
	var dur := 0.9
	if t > dur or opacity <= 0.01:
		mm.visible_instance_count = 0
		return
	mm.visible_instance_count = n
	var k := t / dur
	var e := 1.0 - pow(1.0 - k, 3.0)
	var half_w := quad.scale.x * 0.5
	var half_h := quad.scale.y * 0.5
	for i in n:
		var d: Array = _star_dirs[i]
		var dir: Vector2 = d[0]
		var r := e * (0.45 + 0.55 * float(d[1]))
		var p := Vector3(dir.x * half_w * (0.35 + 0.95 * r), dir.y * half_h * (0.35 + 1.4 * r), 0.0)
		var s := em * 0.32 * float(d[1]) * sin(minf(1.0, k * 1.3) * PI) + 0.001
		var b := Basis().scaled(Vector3.ONE * s)
		mm.set_instance_transform(i, Transform3D(b, p))
		var c := ScorePopup.hsl(float(d[2]), 1.0, 0.62)
		c.a = opacity * (1.0 - k * k)
		mm.set_instance_color(i, c)


## The pool and the picture cache of the spawned texts under one parent.
class Layer extends Node3D:
	var items: Array = []
	var cache := {}  # key -> {vp: SubViewport, size: Vector2i, used: int}
	var _tick := 0
	var _next := 0

	func fire(txt: String, pos: Vector3, k: String, scale_k: float, color) -> JuiceText:
		var it: JuiceText = null
		for c: JuiceText in items:
			if not c.visible:
				it = c
				break
		if it == null:
			if items.size() < JuiceText.POOL:
				it = JuiceText.new()
				it.spawned = true
				add_child(it)
				items.append(it)
			else:
				it = items[_next % items.size()]
				_next += 1
		var K: Dictionary = JuiceText.KINDS.get(k, JuiceText.KINDS.points)
		it.kind = k
		it.text = txt
		it.tint = color
		it.em = float(K.em)
		it._base = scale_k
		it.life = float(K.life) * (1.15 if scale_k > 1.15 else 1.0)
		it.start = pos
		it.age = 0.0
		it.position = pos
		var key := "%s|%s|%s" % [k, txt, (color as Color).to_html() if color is Color else "-"]
		var e: Dictionary = _entry(key, txt, k, color)
		it._key = key
		it.picture = e.px_size
		it.material.set_shader_parameter("tex", (e.vp as SubViewport).get_texture())
		it._fit()
		it._burst()
		it.visible = true
		it.step(0.0)
		return it

	func _entry(key: String, txt: String, k: String, color) -> Dictionary:
		_tick += 1
		if cache.has(key):
			cache[key].used = _tick
			return cache[key]
		var vp: SubViewport = null
		if cache.size() >= JuiceText.CACHE:
			var old := ""
			var oldest := 1 << 62
			var busy := {}
			for it: JuiceText in items:
				if it.visible:
					busy[it._key] = true
			for kk: String in cache:
				if not busy.has(kk) and int(cache[kk].used) < oldest:
					oldest = int(cache[kk].used)
					old = kk
			if old != "":
				vp = cache[old].vp
				cache.erase(old)
		if vp == null:
			vp = SubViewport.new()
			vp.transparent_bg = true
			vp.disable_3d = true
			vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			add_child(vp)
		var size := JuiceText.paint(vp, txt, k, color)
		var e := {"vp": vp, "px_size": size, "used": _tick}
		cache[key] = e
		return e

	func _process(dt: float) -> void:
		for it: JuiceText in items:
			if it.visible:
				it.step(dt)
