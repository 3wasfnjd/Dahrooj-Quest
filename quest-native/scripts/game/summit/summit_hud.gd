class_name SummitHud
extends Node3D
## The Summit's board (xr-runtime.js drawHud, the climb branch): on the 1 m x 0.3 m HUD
## pane (1024 x 300 layout), a white paper card (202, 14, 620 x 236, corner 60, soft
## shadow, faint ink rim) with big hearts (♥ at 112 px: coral #c8584b while you have
## them, faint ink when lost) and under them the height «N م» / "N m", or «A للتسلق من
## جديد» / "A to climb again" after the summit. Add it under main's hud node and call
## show_hud(summit.hud(), lang) every frame (it redraws only on a change).

const CW := 1024
const CH := 300
const WIDTH := 1.0
const PX := WIDTH / CW

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_test_disabled, depth_draw_never, fog_disabled;
uniform float hearts = 3.0;
uniform float max_hearts = 3.0;
uniform vec4 full : source_color = vec4(0.784, 0.345, 0.294, 1.0);
uniform vec4 empty : source_color = vec4(0.173, 0.176, 0.239, 0.2);

float rrect(vec2 p, vec2 c, vec2 h, float r) {
	vec2 q = abs(p - c) - h + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
float dot2(vec2 v) { return dot(v, v); }
// A heart, its tip at the origin, about 1.2 tall (Inigo Quilez's exact SDF).
float heart(vec2 p) {
	p.x = abs(p.x);
	if (p.y + p.x > 1.0) return sqrt(dot2(p - vec2(0.25, 0.75))) - sqrt(2.0) / 4.0;
	return sqrt(min(dot2(p - vec2(0.0, 1.0)), dot2(p - 0.5 * max(p.x + p.y, 0.0)))) * sign(p.x - p.y);
}
vec4 over(vec4 dst, vec3 c, float a) {
	return vec4(mix(dst.rgb, c, a), a + dst.a * (1.0 - a));
}
void fragment() {
	vec2 p = UV * vec2(1024.0, 300.0);
	float aa = max(fwidth(p.x), 0.5);
	vec4 o = vec4(0.0);
	// Shadow (blur 24, 7 px down), the card, its rim.
	float ds = rrect(p, vec2(512.0, 132.0 + 7.0), vec2(310.0, 118.0), 60.0);
	o = over(o, vec3(20.0, 20.0, 30.0) / 255.0, 0.32 * (1.0 - smoothstep(-12.0, 24.0, ds)));
	float d = rrect(p, vec2(512.0, 132.0), vec2(310.0, 118.0), 60.0);
	float inside = clamp(0.5 - d / aa, 0.0, 1.0);
	o = over(o, vec3(1.0), 0.96 * inside);
	o = over(o, vec3(44.0, 45.0, 61.0) / 255.0, 0.12 * clamp(1.5 - abs(d) / aa, 0.0, 1.0));
	for (int i = 0; i < 8; i++) {
		if (float(i) >= max_hearts) break;
		float cx = 512.0 + (float(i) - (max_hearts - 1.0) / 2.0) * 128.0;
		vec2 q = vec2(p.x - cx, 132.0 - p.y) / 60.0;
		float h = heart(q) * 60.0;
		vec4 c = float(i) < hearts ? full : empty;
		o = over(o, c.rgb, c.a * clamp(0.5 - h / aa, 0.0, 1.0));
	}
	ALBEDO = o.rgb;
	ALPHA = o.a;
}
"""

static var _shader: Shader

var mat: ShaderMaterial
var quad: MeshInstance3D
var label: Label3D
var key := ""


func _init() -> void:
	name = "SummitHud"
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	mat = ShaderMaterial.new()
	mat.shader = _shader
	mat.render_priority = 4
	quad = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(WIDTH, WIDTH * CH / CW)
	quad.mesh = q
	quad.material_override = mat
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(quad)
	label = Label3D.new()
	label.font = Glass.font(800)
	label.font_size = 46 * 2
	label.pixel_size = PX / 2.0
	label.modulate = Color(Color("2c2d3d"), 0.8)
	label.outline_size = 0
	label.no_depth_test = true
	label.render_priority = 5
	label.shaded = false
	label.double_sided = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.position = Vector3(0, (CH / 2.0 - 214.0 - label.font.get_descent(46)) * PX, 0.001)
	add_child(label)


## The board's text (drawHud): again → «A للتسلق من جديد», else the title if any, else the height.
static func text_for(h: Dictionary, lang := "ar", title := "") -> String:
	if h.get("again", false):
		return "A to climb again" if lang == "en" else "A للتسلق من جديد"
	if title != "":
		return title
	return ("%d m" if lang == "en" else "%d م") % int(h.get("height", 0))


## h: SummitMode.hud(); hidden when empty.
func show_hud(h: Dictionary, lang := "ar", title := "") -> void:
	visible = not h.is_empty()
	if h.is_empty():
		key = ""
		return
	var t := text_for(h, lang, title)
	var k := "%d|%d|%s" % [int(h.hearts), int(h.max), t]
	if k == key:
		return
	key = k
	mat.set_shader_parameter("hearts", float(h.hearts))
	mat.set_shader_parameter("max_hearts", float(h.max))
	label.text = t
	label.text_direction = TextServer.DIRECTION_LTR if lang == "en" else TextServer.DIRECTION_RTL
