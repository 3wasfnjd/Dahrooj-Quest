class_name ScorePopup
extends Node3D
## The transient jelly score digits (src/reference/score-popup.ts): one reused
## 768 x 384 picture on a 1 x 0.5 quad that ignores depth (drawn last, priority 4).
## Each new higher score repaints the number in the game font (Baloo Bhaijaan 2,
## weight 800, up to 256 px, fitted to 640 px): every numeral keeps its own hue,
## a dark extruded copy 8 px below (14 px stroke) and on top a light 5 px rim with
## a vertical jelly gradient. Then it pops in, wobbles like jelly, drifts up and
## fades over 1.65 s. Latin digits in both languages, as in the original.
##
## Place this node like the web game's HUD pane (hud.mesh in xr-runtime.js): its
## own transform is the pane's; the animated quad is the child `root`.
## Call observe(scope, value) every frame and step(dt) every frame (step runs
## from _process unless auto_step is false).

const DURATION := 1.65
const W := 768
const H := 384
const HUES: Array[float] = [0.0, 30.0, 55.0, 95.0, 140.0, 180.0, 215.0, 245.0, 280.0, 325.0]

const JELLY_SHADER := """
shader_type canvas_item;
uniform vec4 c0; uniform vec4 c1; uniform vec4 c2; uniform vec4 c3; uniform vec4 c4;
uniform float y0;
uniform float y1;
varying float ly;
void vertex() { ly = VERTEX.y; }
void fragment() {
	float k = clamp((ly - y0) / max(1.0, y1 - y0), 0.0, 1.0);
	vec4 col = mix(c0, c1, clamp(k / 0.22, 0.0, 1.0));
	col = mix(col, c2, clamp((k - 0.22) / 0.28, 0.0, 1.0));
	col = mix(col, c3, clamp((k - 0.5) / 0.06, 0.0, 1.0));
	col = mix(col, c4, clamp((k - 0.56) / 0.44, 0.0, 1.0));
	COLOR = vec4(col.rgb, texture(TEXTURE, UV).a * COLOR.a);
}
"""

## When false the owner calls step(dt) itself.
var auto_step := true
var root: Node3D
var mesh: MeshInstance3D
var material: StandardMaterial3D
var viewport: SubViewport
var value := -1  # the number painted (root.userData.value)
var opacity := 0.0
## The number shown fell (drop()): it sinks as it fades.
var dropping := false

var _scope := ""
var _previous := 0
var _age := DURATION
var _canvas: Node2D

static var _font: FontVariation
static var _shader: Shader


## Baloo at weight 800 (the web canvas asks for "800 256px Dahrooj").
static func bold_font() -> Font:
	if _font == null:
		_font = FontVariation.new()
		_font.base_font = load("res://assets/fonts/baloo-latin.woff2")  # the digits' face (a fallback would stay at 400)
		_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
	return _font


static func hsl(h: float, s: float, l: float) -> Color:
	var c := (1.0 - absf(2.0 * l - 1.0)) * s
	var hp := fposmod(h, 360.0) / 60.0
	var x := c * (1.0 - absf(fposmod(hp, 2.0) - 1.0))
	var rgb := Vector3.ZERO
	if hp < 1.0: rgb = Vector3(c, x, 0)
	elif hp < 2.0: rgb = Vector3(x, c, 0)
	elif hp < 3.0: rgb = Vector3(0, c, x)
	elif hp < 4.0: rgb = Vector3(0, x, c)
	elif hp < 5.0: rgb = Vector3(x, 0, c)
	else: rgb = Vector3(c, 0, x)
	var m := l - c / 2.0
	return Color(rgb.x + m, rgb.y + m, rgb.z + m)


## One text layer of the picture (a stroke or a fill), drawn in viewport pixels.
## A Godot outline of size n reaches n / 4 px past the glyph (measured), a canvas
## stroke of lineWidth w reaches w / 2: outline = 2 * lineWidth (14 -> 28, 5 -> 10).
class Layer extends Node2D:
	var text := ""
	var at := Vector2.ZERO
	var size := 16
	var outline := 0
	var color := Color.WHITE

	func _draw() -> void:
		var f := ScorePopup.bold_font()
		if outline > 0:
			draw_string_outline(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, color)
		else:
			draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _init() -> void:
	name = "ScorePopup"
	viewport = SubViewport.new()
	viewport.size = Vector2i(W, H)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	_canvas = Node2D.new()
	viewport.add_child(_canvas)
	root = Node3D.new()
	root.name = "Root"
	root.visible = false
	add_child(root)
	mesh = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 0.5)
	mesh.mesh = q
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_PREMULT_ALPHA  # the picture is drawn premultiplied
	material.no_depth_test = true
	material.disable_fog = true
	material.render_priority = 4
	material.albedo_texture = viewport.get_texture()
	material.albedo_color = Color(0, 0, 0, 0)
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mesh)


## Glyph ink above and below the baseline (canvas actualBoundingBoxAscent/Descent).
static func _ink(text: String, size: int) -> Vector2:
	var ts := TextServerManager.get_primary_interface()
	var f := bold_font()
	var sh := ts.create_shaped_text()
	ts.shaped_text_add_string(sh, text, f.get_rids(), size)
	var top := 0.0
	var bottom := 0.0
	var found := false
	for g: Dictionary in ts.shaped_text_get_glyphs(sh):
		var rid: RID = g.get("font_rid", RID())
		var index: int = g.get("index", 0)
		if not rid.is_valid():
			continue
		var gsize := Vector2i(size, 0)
		ts.font_render_glyph(rid, gsize, index)
		var off: Vector2 = ts.font_get_glyph_offset(rid, gsize, index)
		var sz: Vector2 = ts.font_get_glyph_size(rid, gsize, index)
		if sz.y <= 0.0:
			continue
		top = minf(top, off.y)
		bottom = maxf(bottom, off.y + sz.y)
		found = true
	ts.free_rid(sh)
	if not found:
		return Vector2(f.get_ascent(size) * 0.72, 0.0)
	return Vector2(-top, bottom)


func paint(v: int) -> void:
	for c in _canvas.get_children():
		_canvas.remove_child(c)
		c.queue_free()
	var text := str(v)
	var f := bold_font()
	var size := 256.0
	size *= minf(1.0, 640.0 / maxf(1.0, f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x))
	var px := maxi(1, int(round(size)))
	var ink := _ink(text, px)
	var y := (H + ink.x - ink.y) / 2.0 - 9.0
	var widths: Array[float] = []
	var total := 0.0
	for d in text:
		var w := f.get_string_size(d, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		widths.append(w)
		total += w
	var x := W / 2.0 - total / 2.0
	if _shader == null:
		_shader = Shader.new()
		_shader.code = JELLY_SHADER
	for i in text.length():
		var hue: float = HUES[int(text[i])]
		_layer(text[i], Vector2(x, y + 8.0), px, 28, hsl(hue, 0.55, 0.22))
		_layer(text[i], Vector2(x, y + 8.0), px, 0, hsl(hue, 0.70, 0.35))
		_layer(text[i], Vector2(x, y), px, 10, hsl(hue, 0.90, 0.88))
		var fill := _layer(text[i], Vector2(x, y), px, 0, Color.WHITE)
		var sm := ShaderMaterial.new()
		sm.shader = _shader
		sm.set_shader_parameter("c0", hsl(hue, 0.95, 0.96))
		sm.set_shader_parameter("c1", hsl(hue, 0.95, 0.80))
		sm.set_shader_parameter("c2", hsl(hue, 0.90, 0.64))
		sm.set_shader_parameter("c3", hsl(hue, 0.85, 0.54))
		sm.set_shader_parameter("c4", hsl(hue, 0.75, 0.42))
		sm.set_shader_parameter("y0", y - ink.x)
		sm.set_shader_parameter("y1", y + ink.y)
		fill.material = sm
		x += widths[i]
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	value = v


func _layer(t: String, at: Vector2, px: int, outline: int, color: Color) -> Layer:
	var l := Layer.new()
	l.text = t
	l.at = at
	l.size = px
	l.outline = outline
	l.color = color
	_canvas.add_child(l)
	return l


## The game's mode (or "placing", "climb", "rain") and its count, every frame.
## A new scope only remembers the count; a higher count pops the digits; a lower one hides them.
func observe(next_scope: String, v: float) -> void:
	var n := maxi(0, int(floor(v))) if is_finite(v) else 0
	if next_scope != _scope:
		_scope = next_scope
		_previous = n
		_age = DURATION
		root.visible = false
		return
	if n > _previous:
		paint(n)
		_age = 0.0
		dropping = false
		root.visible = true
	elif n < _previous:
		_age = DURATION
		root.visible = false
	_previous = n


## An attack took points: the lower score pops in and sinks instead of drifting up (observe()
## then takes it as the count seen, so it stays shown).
func drop(v: int) -> void:
	var n := maxi(0, v)
	paint(n)
	_previous = n
	_age = 0.0
	dropping = true
	root.visible = true


func showing() -> bool:
	return root.visible


func _process(delta: float) -> void:
	if auto_step:
		step(delta)


func step(dt: float) -> void:
	if _age >= DURATION:
		root.visible = false
		return
	_age = minf(DURATION, _age + dt)
	var enter := minf(1.0, _age / 0.22)
	var pop := 1.0 - pow(1.0 - enter, 3.0)
	var t := maxf(0.0, _age - 0.14)
	var wobble := sin(t * 18.0) * exp(-t * 6.0) * 0.11
	var sc := 0.42 + 0.58 * pop
	var fade := clampf((_age - 1.05) / 0.6, 0.0, 1.0)
	root.scale = Vector3(sc * (1.0 + wobble), sc * (1.0 - wobble), 1.0)
	root.position.y = _age * (-0.06 if dropping else 0.045)
	root.rotation.z = sin(t * 12.0) * exp(-t * 6.0) * 0.025
	opacity = minf(1.0, _age / 0.07) * (1.0 - fade * fade * (3.0 - 2.0 * fade))
	material.albedo_color = Color(opacity, opacity, opacity, opacity)  # premultiplied
	root.visible = _age < DURATION
