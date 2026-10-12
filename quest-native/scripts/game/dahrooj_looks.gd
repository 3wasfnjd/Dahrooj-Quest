class_name DahroojLooks
extends RefCounted
## Dahrooj's looks, shared by the full character (dahrooj_view.gd) and the crowds
## (crowd.gd): src/reference/character.js MATERIALS, accessory(), bow(), bandaid() and
## setJellyColor(), src/core/appearance.ts (PLAYABLE_STYLES, DAHROOJ_COLOR_CHOICES,
## jellyColor, playableStyle) and src/progression/challenges.ts (UNLOCKS, accessoryAvailable,
## via MenuCatalog).
##
## Meshes are built with three.js's own generators (unit radius, face toward +Z) and merged
## into one mesh per part with vertex colours, so a decoration or an accessory is one draw.
## Accessory parts also carry their roughness, metalness, environment reflection and canvas
## pattern (party stripes, cap seams, knit, wood grain) in UV2 for ACC_SHADER.

## palette.js DAHROOJ_COLORS: each style's own colour (sRGB).
const DAHROOJ_COLORS := {"jelly": "ff69b4", "fabric": "b36bff", "clay": "ff9b3d", "fur": "f1ebe1", "bubble": "cfe8ff"}
## Every style character.js can draw; legacy fabric and clay keep their own colour.
const STYLES := ["jelly", "fabric", "clay", "fur", "bubble"]
const PLAYABLE_STYLES := ["jelly", "fur", "bubble"]
## The styles the saved colour tints (character.js styleTints).
const TINTED := ["jelly", "fur", "bubble"]
## appearance.ts DAHROOJ_COLOR_CHOICES: id -> hex ("" = the style's own colour).
const COLOR_CHOICES := {"original": "", "pink": "ff69b4", "red": "ff505c", "orange": "ff9b3d", "yellow": "ffdf45",
	"green": "58db83", "blue": "58b9ff", "purple": "b878ff"}
const COLOR_IDS := ["original", "pink", "red", "orange", "yellow", "green", "blue", "purple"]
## config.ts ACCESSORIES ('' = none).
const ACCESSORIES := ["", "party", "glasses", "cap", "flower", "crown", "headphones", "scarf", "aviator", "woodhat", "starGlasses", "beanie"]
## A hat takes the place of the fur ball's ribbon.
const HEADWEAR := ["party", "cap", "crown", "headphones", "aviator", "woodhat", "beanie"]
const BOW_AT := Vector3(-0.1, 0.86, 0.5)
## Canvas patterns drawn by ACC_SHADER (the accessories' CanvasTextures).
enum Pattern { NONE, PARTY, CAP, BEANIE, WOOD, SCARF, UNLIT }

static var _cache := {}


# --- appearance.ts / store.ts --------------------------------------------------------------

## appearance.ts jellyColor(): unknown ids fall back to pink.
static func color_id(value: Variant) -> String:
	var id := str(value) if value != null else ""
	return id if COLOR_CHOICES.has(id) else "pink"


## appearance.ts playableStyle(): fabric was folded into fur; anything else is jelly.
static func playable_style(value: Variant) -> String:
	var s := str(value) if value != null else ""
	return "fur" if s == "fur" or s == "fabric" else ("bubble" if s == "bubble" else "jelly")


## config.ts normalizeAccessory(): the retired laurel became the aviator cap.
static func normalize_accessory(value: Variant) -> String:
	var id := str(value) if value != null else ""
	if id == "laurel":
		id = "aviator"
	return id if id in ACCESSORIES else ""


## The colour a style is drawn in (sRGB): the saved colour, or the style's own for
## "original" (and always for fabric and clay, which the saved colour never tinted).
static func tint(style: String, color: String) -> Color:
	var hex: String = COLOR_CHOICES.get(color_id(color), "")
	if hex == "" or not style in TINTED:
		return Color(DAHROOJ_COLORS.get(style, DAHROOJ_COLORS.jelly))
	return Color(hex)


## Finished challenges (store.completed).
static func done_count(progress: Dictionary) -> int:
	var n := 0
	for c: Array in MenuCatalog.CHALLENGES:
		if int(progress.get(c[0], 0)) >= int(c[1]):
			n += 1
	return n


## challenges.ts accessoryAvailable (MenuCatalog's port).
static func accessory_available(id: String, completed: int, progress: Dictionary) -> bool:
	return MenuCatalog.accessory_available(id, completed, progress)


## store.ts migrate(): the saved look, validated. raw: the saved dictionary.
static func load_look(raw: Dictionary, progress: Dictionary) -> Dictionary:
	var style := "fur"
	if str(raw.get("style", "")) in STYLES:
		style = playable_style(raw.style)
	var acc := normalize_accessory(raw.get("accessory", ""))
	if not accessory_available(acc, done_count(progress), progress):
		acc = ""
	return {"style": style, "jelly_color": color_id(raw.get("jelly_color", "pink")), "accessory": acc}


# --- shaders --------------------------------------------------------------------------------

## Jelly: light refracted through the ball (character.js jellyMaterial). A soft sky is looked up
## along the path light takes through a sphere of index 1.35, a little apart per colour;
## Beer-Lambert absorption from the tint, a Fresnel reflection and the sun's highlight (the
## park's light, as updateProbe gives it). The tint is the vertex/instance colour times `tint`.
const JELLY_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;
global uniform vec3 dah_light_dir;
global uniform vec3 dah_light_color;
global uniform float dah_light_intensity;
uniform vec3 tint = vec3(1.0);
uniform float ior = 1.35;
uniform vec3 sky : source_color = vec3(0.8118, 0.8902, 1.0);
uniform vec3 ground : source_color = vec3(0.5412, 0.4902, 0.4235);
varying vec3 vW;
varying vec3 vN;
varying vec3 vC;
varying vec3 vTint;
void vertex() {
	vW = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vN = normalize(mat3(MODEL_MATRIX) * NORMAL);
	vC = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vTint = COLOR.rgb * tint;
}
vec3 world_col(vec3 d) { return mix(ground, sky, smoothstep(-0.25, 0.35, d.y)); }
vec3 through(vec3 p, vec3 v, vec3 nrm, float n, out float len) {
	vec3 t = refract(v, nrm, 1.0 / n);
	vec3 oc = p - vC;
	float b = dot(oc, t);
	len = max(0.0, -2.0 * b);
	vec3 q = p + t * len;
	vec3 nx = normalize(q - vC);
	vec3 o = refract(t, -nx, n);
	if (dot(o, o) < 0.01) o = reflect(t, -nx);
	return o;
}
void fragment() {
	vec3 N = normalize(vN);
	vec3 V = normalize(CAMERA_POSITION_WORLD - vW);
	vec3 I = -V;
	float R = max(length(vW - vC), 1e-4);
	float len;
	vec3 oR = through(vW, I, N, ior - 0.012, len);
	vec3 oG = through(vW, I, N, ior, len);
	vec3 oB = through(vW, I, N, ior + 0.014, len);
	vec3 seen = vec3(world_col(oR).r, world_col(oG).g, world_col(oB).b);
	vec3 absorption = vec3(0.08) + (vec3(1.0) - vTint) * 1.2;
	vec3 trans = seen * exp(-absorption * (len / (2.0 * R))) * mix(vec3(1.0), vTint * 2.4, 0.5) * 1.05;
	float f = 0.022 + (1.0 - 0.022) * pow(1.0 - max(dot(N, V), 0.0), 5.0);
	vec3 refl = world_col(reflect(I, N));
	vec3 L = normalize(dah_light_dir);
	vec3 H = normalize(L + V);
	float nh = max(dot(N, H), 0.0);
	vec3 lc = dah_light_color * min(1.4, 0.6 + dah_light_intensity);
	vec3 spec = lc * (pow(nh, 260.0) * 2.2 + pow(nh, 40.0) * 0.12);
	float rim = pow(1.0 - max(dot(N, V), 0.0), 2.0) * max(dot(N, L) * 0.5 + 0.5, 0.0);
	ALBEDO = mix(trans, refl, f) + spec + vTint * rim * 0.35;
}
"""

## Bubble: a swirling soap film with white spots fixed to the body (character.js MATERIALS.bubble).
const BUBBLE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
uniform vec3 tint = vec3(1.0);
varying vec3 vN;
varying vec3 vV;
varying vec3 vP;
varying vec3 vTint;
void vertex() {
	vec4 mv = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vN = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vV = normalize(-mv.xyz);
	vP = VERTEX;
	vTint = COLOR.rgb * tint;
}
float white_spot(vec3 p, vec3 at, float radius) { return 1.0 - smoothstep(radius - 0.018, radius + 0.018, distance(p, normalize(at))); }
void fragment() {
	vec3 n = normalize(vN);
	vec3 v = normalize(vV);
	float c = abs(dot(n, v));
	float f = 1.0 - c;
	vec3 p = normalize(vP);
	float th = 0.55 + 0.25 * sin(p.x * 5.0 + TIME * 0.7 + sin(p.y * 4.0 - TIME * 0.5) * 1.6) + 0.2 * sin(p.z * 7.0 - TIME * 0.4) - 0.25 * p.y;
	vec3 film = 0.5 + 0.5 * cos(6.2831 * (th * 2.2 / (0.4 + c) + vec3(0.0, 0.33, 0.67)));
	vec3 r = reflect(-v, n);
	float win = smoothstep(0.93, 0.97, dot(r, normalize(vec3(-0.45, 0.6, 0.65)))) + 0.6 * smoothstep(0.96, 0.985, dot(r, normalize(vec3(0.6, 0.3, 0.75))));
	float rim = pow(f, 1.8);
	vec3 col = mix(vTint, film, 0.32);
	float spots = max(white_spot(p, vec3(-0.38, 0.58, 0.72), 0.14), max(white_spot(p, vec3(-0.08, 0.77, 0.62), 0.08), white_spot(p, vec3(0.62, -0.38, 0.67), 0.065)));
	col = mix(col * (0.7 + rim * 0.3) + win * 0.7, vec3(1.0), spots);
	ALBEDO = col;
	ALPHA = min(1.0, 0.22 + rim * 0.65 + win * 0.65 + spots * 0.78);
}
"""

## Decorations and accessories: vertex colour (linear) as albedo; UV2.x = roughness + 2 *
## pattern, UV2.y = metalness + 2 * round(10 * envMapIntensity). The patterns redraw
## character.js's canvases from the UVs; the env term stands in for the reflected room.
const ACC_SHADER := """
shader_type spatial;
render_mode cull_disabled;
vec3 lin(vec3 c) { return mix(pow((c + vec3(0.055)) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045))); }
float seg(vec2 p, vec2 a, vec2 b) { vec2 pa = p - a, ba = b - a; float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0); return length(pa - ba * h); }
vec3 room(float y) {
	float v = acos(clamp(y, -1.0, 1.0)) / PI;
	vec3 c = mix(vec3(1.0, 0.98, 0.941), vec3(0.914, 0.875, 0.812), smoothstep(0.0, 0.45, v));
	c = mix(c, vec3(0.616, 0.561, 0.486), smoothstep(0.45, 0.55, v));
	c = mix(c, vec3(0.298, 0.263, 0.220), smoothstep(0.55, 1.0, v));
	return lin(c);
}
vec3 pattern(int k, vec2 uv) {
	if (k == 1) {
		// Party hat: seven stripes and cream dots (256 x 256).
		vec2 px = uv * 256.0;
		int band = clamp(int(floor(uv.y * 7.0)), 0, 6);
		vec3 cols[7] = vec3[7](vec3(1.0, 0.412, 0.494), vec3(1.0, 0.627, 0.306), vec3(1.0, 0.902, 0.361), vec3(0.4, 0.847, 0.553), vec3(0.396, 0.773, 1.0), vec3(0.502, 0.525, 0.929), vec3(0.753, 0.502, 0.875));
		vec3 c = cols[band];
		for (int i = 0; i < 18; i++) {
			vec2 d = vec2(mod(float(i * 73 + 25), 256.0), mod(float(i * 51 + 22), 256.0));
			if (distance(px, d) < 3.0) c = vec3(1.0, 0.953, 0.855);
		}
		return c;
	} else if (k == 2) {
		// Cap: red with dashed seams (256 x 128).
		vec2 px = uv * vec2(256.0, 128.0);
		float x = mod(px.x + 1.0, 256.0 / 6.0) - 1.0;
		bool on = abs(x) <= 1.0 && mod(px.y, 8.0) < 4.0;
		return on ? vec3(0.929, 0.573, 0.486) : vec3(0.784, 0.267, 0.184);
	} else if (k == 3) {
		// Beanie: knit chevrons (256 x 128).
		vec2 px = uv * vec2(256.0, 128.0);
		vec2 q = vec2(mod(px.x, 16.0), mod(px.y + 8.0, 12.0));
		float d = min(seg(q, vec2(3.0, 0.0), vec2(8.0, 7.0)), seg(q, vec2(8.0, 7.0), vec2(13.0, 0.0)));
		return d < 1.0 ? vec3(0.510, 0.725, 0.784) : vec3(0.341, 0.612, 0.698);
	} else if (k == 4) {
		// Wooden hat: wavy grain (128 x 256).
		vec2 px = uv * vec2(128.0, 256.0);
		float d = 99.0;
		for (int i = 0; i < 10; i++) {
			float x = 4.0 + 13.0 * float(i);
			d = min(d, abs(px.x - (x + sin(px.y * 0.035 + x) * 2.0)));
		}
		return d < 1.0 ? vec3(0.643, 0.451, 0.282) : vec3(0.784, 0.612, 0.396);
	} else {
		// Scarf: knit zigzag rows (128 x 128).
		vec2 px = uv * 128.0;
		float lx = mod(px.x, 16.0);
		float off = (lx < 8.0 ? lx : 16.0 - lx) / 8.0 * 3.0;
		float d = abs(mod(px.y - off + 4.0, 8.0) - 4.0);
		return d < 1.0 ? vec3(0.620, 0.859, 0.816) : vec3(0.275, 0.667, 0.663);
	}
}
void fragment() {
	float pk = floor(UV2.x * 0.5 + 0.001);
	float rough = clamp(UV2.x - 2.0 * pk, 0.0, 1.0);
	float eq = floor(UV2.y * 0.5 + 0.001);
	float metal = clamp(UV2.y - 2.0 * eq, 0.0, 1.0);
	float env = eq * 0.1;
	int k = int(pk + 0.5);
	vec3 col = COLOR.rgb;
	if (k >= 1 && k <= 5) col *= lin(pattern(k, UV));
	if (k == 6) {
		ALBEDO = vec3(0.0);
		EMISSION = col;
		SPECULAR = 0.0;
		ROUGHNESS = 1.0;
	} else {
		ALBEDO = col;
		ROUGHNESS = rough;
		METALLIC = metal;
		if (env > 0.0) {
			vec3 r = (INV_VIEW_MATRIX * vec4(reflect(-VIEW, NORMAL), 0.0)).xyz;
			float fv = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
			vec3 f0 = mix(vec3(0.04), col, metal);
			EMISSION = room(r.y) * (f0 + (vec3(1.0) - f0) * fv) * env * (1.0 - rough * 0.6) * 0.6;
		}
	}
}
"""


static func _shader(key: String, code: String) -> Shader:
	if not _cache.has("shader_" + key):
		var sh := Shader.new()
		sh.code = code
		_cache["shader_" + key] = sh
	return _cache["shader_" + key]


## The body's material for a style in a colour (character.js MATERIALS + setJellyColor).
## instanced: for crowds, where the colour comes from each instance (white base).
static func body_material(style: String, color := "original", instanced := false) -> Material:
	if not style in STYLES:
		style = "jelly"
	var c := Color.WHITE if instanced else tint(style, color)
	var key := "body_%s_%s_%s" % [style, c.to_html(false), "i" if instanced else "s"]
	if _cache.has(key):
		return _cache[key]
	var m: Material
	match style:
		"jelly", "bubble":
			var sm := ShaderMaterial.new()
			sm.shader = _shader(style, JELLY_SHADER if style == "jelly" else BUBBLE_SHADER)
			# Linear, as the crowd's instance colours (the shaders work in linear light).
			sm.set_shader_parameter("tint", c.srgb_to_linear())
			m = sm
		_:
			var s := StandardMaterial3D.new()
			s.albedo_color = c
			s.vertex_color_use_as_albedo = instanced
			match style:
				"fur":
					# The skin is the colour of the hair roots: the neutral coat keeps the hue.
					s.albedo_texture = load("res://assets/character/fur.png")
					s.roughness = 0.95
				"fabric":
					s.roughness = 0.82
				_:
					s.roughness = 0.72
			m = s
	_cache[key] = m
	return m


## Decorations and accessories (ACC_SHADER), one material for all.
static func acc_material() -> ShaderMaterial:
	if not _cache.has("acc_mat"):
		var m := ShaderMaterial.new()
		m.shader = _shader("acc", ACC_SHADER)
		_cache["acc_mat"] = m
	return _cache["acc_mat"]


## The single character's eye materials: sclera (felt for fabric), pupil, glint.
static func eye_material(key: String) -> Material:
	if _cache.has("eye_" + key):
		return _cache["eye_" + key]
	var m := StandardMaterial3D.new()
	match key:
		"sclera":
			m.albedo_color = Color("fffaf2")
			m.roughness = 0.2
			m.clearcoat_enabled = true
			m.clearcoat = 1.0
		"sclera_felt":
			m.albedo_color = Color("f2ebdd")
			m.roughness = 0.85
		"pupil":
			m.albedo_color = Color("2c2d3d")
			m.roughness = 0.06
			m.clearcoat_enabled = true
			m.clearcoat = 1.0
		_:
			m.albedo_color = Color.WHITE
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cache["eye_" + key] = m
	return m


## The drawn face (mouth, blush) for an expression, on the cap over the front.
static func face_material(face: String) -> Material:
	var key := "face_" + face
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = load("res://assets/character/face_%s.png" % face)
		m.render_priority = 1
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_cache[key] = m
	return _cache[key]


# --- geometry (three.js generators, so the shapes match) -----------------------------------
## Generators return {v, n, uv, i}. UV y runs down the canvas (three's flipped v), so a
## canvas pixel is uv * size.


## three.js SphereGeometry.
static func sphere(r: float, ws: int, hs: int, phi0 := 0.0, phi_len := TAU, th0 := 0.0, th_len := PI) -> Dictionary:
	var pv := PackedVector3Array()
	var pn := PackedVector3Array()
	var puv := PackedVector2Array()
	var pi := PackedInt32Array()
	var th_end := minf(th0 + th_len, PI)
	for iy in hs + 1:
		var v := float(iy) / hs
		for ix in ws + 1:
			var u := float(ix) / ws
			var p := Vector3(-r * cos(phi0 + u * phi_len) * sin(th0 + v * th_len), r * cos(th0 + v * th_len), r * sin(phi0 + u * phi_len) * sin(th0 + v * th_len))
			pv.append(p)
			pn.append(p.normalized() if p.length_squared() > 0.0 else Vector3.UP)
			puv.append(Vector2(u, v))
	for iy in hs:
		for ix in ws:
			var a := iy * (ws + 1) + ix + 1
			var b := iy * (ws + 1) + ix
			var c := (iy + 1) * (ws + 1) + ix
			var d := (iy + 1) * (ws + 1) + ix + 1
			if iy != 0 or th0 > 0.0:
				pi.append_array([a, b, d])
			if iy != hs - 1 or th_end < PI:
				pi.append_array([b, c, d])
	return {"v": pv, "n": pn, "uv": puv, "i": pi}


## three.js CylinderGeometry (ConeGeometry is rt = 0).
static func cylinder(rt: float, rb: float, h: float, rs: int, open := false, th0 := 0.0, th_len := TAU) -> Dictionary:
	var pv := PackedVector3Array()
	var pn := PackedVector3Array()
	var puv := PackedVector2Array()
	var pi := PackedInt32Array()
	var half := h / 2.0
	var slope := (rb - rt) / h
	for y in 2:
		var v := float(y)
		var radius := v * (rb - rt) + rt
		for x in rs + 1:
			var u := float(x) / rs
			var th := u * th_len + th0
			pv.append(Vector3(radius * sin(th), -v * h + half, radius * cos(th)))
			pn.append(Vector3(sin(th), slope, cos(th)).normalized())
			puv.append(Vector2(u, v))
	for x in rs:
		var a := x
		var b := rs + 1 + x
		var c := rs + 1 + x + 1
		var d := x + 1
		pi.append_array([a, b, d, b, c, d])
	if not open:
		for top in [true, false]:
			var radius := rt if top else rb
			if radius <= 0.0:
				continue
			var s := 1.0 if top else -1.0
			var base := pv.size()
			for x in rs:
				pv.append(Vector3(0, half * s, 0))
				pn.append(Vector3(0, s, 0))
				puv.append(Vector2(0.5, 0.5))
			for x in rs + 1:
				var th := float(x) / rs * th_len + th0
				pv.append(Vector3(radius * sin(th), half * s, radius * cos(th)))
				pn.append(Vector3(0, s, 0))
				puv.append(Vector2(cos(th) * 0.5 + 0.5, 0.5 - sin(th) * 0.5 * s))
			for x in rs:
				pi.append_array([base + x, base + rs + x, base + rs + x + 1])
	return {"v": pv, "n": pn, "uv": puv, "i": pi}


## three.js TorusGeometry (in the XY plane, around Z).
static func torus(R: float, tube: float, rs: int, ts: int, arc := TAU) -> Dictionary:
	var pv := PackedVector3Array()
	var pn := PackedVector3Array()
	var puv := PackedVector2Array()
	var pi := PackedInt32Array()
	for j in rs + 1:
		for i in ts + 1:
			var u := float(i) / ts * arc
			var v := float(j) / rs * TAU
			var p := Vector3((R + tube * cos(v)) * cos(u), (R + tube * cos(v)) * sin(u), tube * sin(v))
			pv.append(p)
			pn.append((p - Vector3(R * cos(u), R * sin(u), 0)).normalized())
			puv.append(Vector2(float(i) / ts, 1.0 - float(j) / rs))
	for j in range(1, rs + 1):
		for i in range(1, ts + 1):
			var a := (ts + 1) * j + i - 1
			var b := (ts + 1) * (j - 1) + i - 1
			var c := (ts + 1) * (j - 1) + i
			var d := (ts + 1) * j + i
			pi.append_array([a, b, d, b, c, d])
	return {"v": pv, "n": pn, "uv": puv, "i": pi}


## three.js BoxGeometry (one 0..1 UV square per face).
static func box(w: float, h: float, d: float) -> Dictionary:
	var pv := PackedVector3Array()
	var pn := PackedVector3Array()
	var puv := PackedVector2Array()
	var pi := PackedInt32Array()
	var e := Vector3(w, h, d) / 2.0
	for f in [[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
			[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
			[Vector3.BACK, Vector3.UP, Vector3.LEFT], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT]]:
		var n: Vector3 = f[0]
		var a: Vector3 = f[1]
		var b: Vector3 = f[2]
		var base := pv.size()
		for c in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
			pv.append((n + a * float(c[0]) + b * float(c[1])) * e)
			pn.append(n)
			puv.append(Vector2((float(c[1]) + 1.0) * 0.5, (1.0 - float(c[0])) * 0.5))
		pi.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	return {"v": pv, "n": pn, "uv": puv, "i": pi}


## three.js CircleGeometry (facing +Z).
static func circle(r: float, segs: int) -> Dictionary:
	var pv := PackedVector3Array()
	var pn := PackedVector3Array()
	var puv := PackedVector2Array()
	var pi := PackedInt32Array()
	pv.append(Vector3.ZERO)
	pn.append(Vector3.BACK)
	puv.append(Vector2(0.5, 0.5))
	for s in segs + 1:
		var a := float(s) / segs * TAU
		pv.append(Vector3(cos(a) * r, sin(a) * r, 0))
		pn.append(Vector3.BACK)
		puv.append(Vector2(0.5, 0.5))
	for s in range(1, segs + 1):
		pi.append_array([0, s, s + 1])
	return {"v": pv, "n": pn, "uv": puv, "i": pi}


## Flat-shaded triangles (each [a, b, c]) as a geometry.
static func _flat(tris: Array) -> Dictionary:
	var pv := PackedVector3Array()
	var pn := PackedVector3Array()
	var puv := PackedVector2Array()
	var pi := PackedInt32Array()
	for t: Array in tris:
		var p0: Vector3 = t[0]
		var n := ((t[1] as Vector3) - p0).cross((t[2] as Vector3) - p0).normalized()
		for p: Vector3 in t:
			pi.append(pv.size())
			pv.append(p)
			pn.append(n)
			puv.append(Vector2(0.5, 0.5))
	return {"v": pv, "n": pn, "uv": puv, "i": pi}


## three.js OctahedronGeometry(r), flat faces.
static func octahedron(r: float) -> Dictionary:
	var tris := []
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				tris.append([Vector3(sx * r, 0, 0), Vector3(0, sy * r, 0), Vector3(0, 0, sz * r)])
	return _flat(tris)


## The star of the star glasses (character.js starShape): ten points, radii 0.26 / 0.12.
static func _star_points(r: float) -> Array:
	var pts := []
	for i in 10:
		var a := i * PI / 5.0 + PI / 2.0
		var k := r * (0.12 if i % 2 == 1 else 0.26)
		pts.append(Vector2(cos(a) * k, sin(a) * k))
	return pts


## ShapeGeometry(star) when depth is 0, else ExtrudeGeometry(star, {depth}) from z 0 to depth.
static func star(r: float, depth := 0.0) -> Dictionary:
	var pts := _star_points(r)
	var tris := []
	for z in ([0.0] if depth <= 0.0 else [0.0, depth]):
		for i in 10:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % 10]
			tris.append([Vector3(0, 0, z), Vector3(a.x, a.y, z), Vector3(b.x, b.y, z)])
	if depth > 0.0:
		for i in 10:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % 10]
			tris.append([Vector3(a.x, a.y, 0), Vector3(b.x, b.y, 0), Vector3(b.x, b.y, depth)])
			tris.append([Vector3(a.x, a.y, 0), Vector3(b.x, b.y, depth), Vector3(a.x, a.y, depth)])
	var g := _flat(tris)
	# Fan faces point along z; side faces outward from the centre.
	var pn: PackedVector3Array = g.n
	var pv: PackedVector3Array = g.v
	for k in range(0, pv.size(), 3):
		var nrm := pn[k]
		var mid := (pv[k] + pv[k + 1] + pv[k + 2]) / 3.0
		var want := Vector3(0, 0, 1.0 if mid.z > depth * 0.5 or depth <= 0.0 else -1.0) if absf(nrm.z) > 0.5 else Vector3(mid.x, mid.y, 0)
		if nrm.dot(want) < 0.0:
			for j in 3:
				pn[k + j] = -nrm
	g.n = pn
	return g


## three.js object matrix: position, Euler rotation (XYZ unless told), scale.
static func xf(pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, order := EULER_ORDER_XYZ) -> Transform3D:
	return Transform3D(Basis.from_euler(rot, order) * Basis.from_scale(scl), pos)


## Merge [geometry, transform, colour (sRGB; alpha kept), (surface)] parts into one mesh with
## vertex colours (linear). surface: [roughness, metalness, pattern, envMapIntensity]; when any
## part has one the mesh carries UV2 for ACC_SHADER (others get roughness 0.5). Triangles face
## the way their normals point (Godot: clockwise front).
static func merge(list: Array, with_uv := false) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	var surfaced := false
	for part: Array in list:
		if part.size() > 3:
			surfaced = true
	for part: Array in list:
		var g: Dictionary = part[0]
		var t: Transform3D = part[1]
		var col: Color = part[2]
		var s: Array = part[3] if part.size() > 3 else [0.5, 0.0, 0, 0.0]
		var s2 := Vector2(float(s[0]) + 2.0 * int(s[2]), float(s[1]) + 2.0 * roundf(float(s[3]) * 10.0))
		var lc := Color(col.srgb_to_linear(), col.a)
		var nb := t.basis.inverse().transposed()
		var base := v.size()
		var gv: PackedVector3Array = g.v
		var gn: PackedVector3Array = g.n
		var guv: PackedVector2Array = g.uv
		for k in gv.size():
			v.append(t * gv[k])
			n.append((nb * gn[k]).normalized())
			c.append(lc)
			uv.append(guv[k])
			uv2.append(s2)
		var gi: PackedInt32Array = g.i
		for k in range(0, gi.size(), 3):
			var a := base + gi[k]
			var b := base + gi[k + 1]
			var d := base + gi[k + 2]
			var face := (v[b] - v[a]).cross(v[d] - v[a])
			if face.dot(n[a] + n[b] + n[d]) > 0.0:
				idx.append_array([a, d, b])
			else:
				idx.append_array([a, b, d])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = c
	if with_uv or surfaced:
		arr[Mesh.ARRAY_TEX_UV] = uv
	if surfaced:
		arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


static func _cached(key: String, build: Callable) -> ArrayMesh:
	if not _cache.has(key):
		_cache[key] = build.call()
	return _cache[key]


## A body sphere (three SphereGeometry(r, segs, rings)) with UVs and white vertex colours.
static func body_mesh(r: float, segs := 32, rings := 20) -> ArrayMesh:
	return _cached("body_%f_%d_%d" % [r, segs, rings], func() -> ArrayMesh:
		return merge([[sphere(r, segs, rings), Transform3D.IDENTITY, Color.WHITE]], true))


## A surface for merge(): roughness, metalness, pattern, envMapIntensity.
static func _s(rough := 0.5, metal := 0.0, pat := Pattern.NONE, env := 0.0) -> Array:
	return [rough, metal, pat, env]


## The fur ball's ribbon (character.js bow()), unit radius. lite: the crowd's (loops and knot).
static func bow_mesh(lite := false) -> ArrayMesh:
	return _cached("bow_%s" % lite, func() -> ArrayMesh:
		var g := xf(BOW_AT.normalized() * 1.06, Vector3(-0.15, -0.1, 0.15))
		var red := _s(0.45, 0.0, Pattern.NONE, 0.5)
		var dark := _s(0.6)
		var list := []
		for s in [-1.0, 1.0]:
			list.append([sphere(0.17, 10 if lite else 20, 8 if lite else 14), g * xf(Vector3(s * 0.2, 0, 0), Vector3(0, 0, s * 0.35), Vector3(1.2, 0.9, 0.6)), Color("d8452f"), red])
			if not lite:
				list.append([cylinder(0.0, 0.06, 0.3, 10), g * xf(Vector3(s * 0.09, -0.19, 0.12), Vector3(0.35, 0, s * 0.35)), Color("b8432a"), dark])
		list.append([sphere(0.07, 8 if lite else 12, 6 if lite else 10), g, Color("b8432a"), dark])
		return merge(list))


## The jelly's bandage on its surface, tilted (character.js bandaid()), unit radius.
static func bandage_mesh() -> ArrayMesh:
	return _cached("bandage", func() -> ArrayMesh:
		var n := Vector3(0.4, 0.62, 0.6).normalized()
		var g := Transform3D(Basis.looking_at(n, Vector3.UP, true) * Basis(Vector3.BACK, -0.55), n * 1.005)
		var list := [[box(0.66, 0.24, 0.03), g, Color("e8c29d"), _s(0.6, 0.0, Pattern.NONE, 0.4)], [box(0.22, 0.17, 0.04), g, Color("f4ddc3"), _s(0.95)]]
		for i in 6:
			var p := Vector3((i % 3 - 1) * 0.07 + (-0.23 if i < 3 else 0.23), (1 if i < 3 else -1) * 0.03, 0.016)
			list.append([circle(0.012, 8), g * xf(p), Color("c9a07c"), _s(1.0, 0.0, Pattern.UNLIT)])
		return merge(list))


## character.js accessory(id, lite), unit radius, face toward +Z: one merged mesh. lite: the
## crowd's fewer facets (and no small extras). Empty for an unknown id.
static func accessory_mesh(id: String, lite := false) -> ArrayMesh:
	return _cached("acc_%s_%s" % [id, lite], func() -> ArrayMesh: return merge(_accessory_parts(id, lite)))


static func _accessory_parts(id: String, lite: bool) -> Array:
	var list := []
	match id:
		"party":
			var hat := xf(Vector3(0.06, 0.90, 0.015), Vector3(-0.09, 0, -0.14))
			list.append([cylinder(0.0, 0.44, 1.02, _q(lite, 18, 40), true), hat * xf(Vector3(0, 0.51, 0)), Color.WHITE, _s(0.65, 0.0, Pattern.PARTY)])
			list.append([sphere(0.13, _q(lite, 10, 20), _q(lite, 8, 14)), hat * xf(Vector3(0, 1.035, 0)), Color("ffedb1"), _s(0.85)])
			list.append([torus(0.44, 0.044, _q(lite, 8, 12), _q(lite, 24, 48)), hat * xf(Vector3.ZERO, Vector3(PI / 2, 0, 0)), Color("ffdf73"), _s(0.6)])
		"glasses":
			# Out in front of the 3D eyes, which stand a little proud of the face.
			var frame := Color("2c2d3d")
			var fs := _s(0.35)
			for sd in [-1.0, 1.0]:
				var a: float = sd * 0.32
				var out := Vector3(sin(a), 0, cos(a))
				var p := out * 1.17
				p.y = 0.1
				list.append([torus(0.21, 0.035, _q(lite, 6, 10), _q(lite, 12, 28)), xf(p, Vector3(0, a, 0), Vector3(1, 0.8, 1)), frame, fs])
				list.append([circle(0.2, _q(lite, 12, 28)), xf(p - out * 0.005, Vector3(0, a, 0), Vector3(1, 0.8, 1)), Color("1b2233"), _s(0.08, 0.2, Pattern.NONE, 0.8)])
				# The arms run back from the lenses along the side of the head.
				list.append([box(0.035, 0.035, 1.05), xf(Vector3(sd * 0.74, 0.13, 0.66), Vector3(0, -sd * 0.56, 0)), frame, fs])
				if not lite:
					list.append([sphere(0.025, 10, 8), xf(Vector3(sd * 0.6, 0.13, 0.99)), Color("f2c14e"), _s(0.25, 0.7)])
			list.append([torus(0.08, 0.026, _q(lite, 6, 8), _q(lite, 8, 16), PI), xf(Vector3(0, 0.15, 1.2)), frame, fs])
		"cap":
			var red := _s(0.7, 0.0, Pattern.CAP)
			var white := Color("fffaf2")
			list.append([sphere(1.05, _q(lite, 16, 36), _q(lite, 8, 16), 0, TAU, 0, PI * 0.36), xf(Vector3(0, 0.02, 0)), Color.WHITE, red])
			# The peak sticks out over the eyes, tipped down so it shows from the front.
			list.append([cylinder(0.68, 0.68, 0.04, _q(lite, 16, 32), false, -PI / 2, PI), xf(Vector3(0, 0.5, 0.55), Vector3(0.42, 0, 0), Vector3(1, 1, 0.9)), Color.WHITE, red])
			list.append([sphere(0.07, _q(lite, 8, 12), _q(lite, 6, 10)), xf(Vector3(0, 1.06, 0)), white, _s(0.7)])
			list.append([sphere(0.13, 16, 12), xf(Vector3(0, 0.72, 0.77), Vector3(-0.2, 0, 0), Vector3(1, 1, 0.2)), white, _s(0.7)])
			list.append([sphere(0.055, 12, 8), xf(Vector3(0, 0.73, 0.81), Vector3.ZERO, Vector3(1, 1, 0.2)), Color("f2c14e"), _s()])
		"flower":
			var at := Vector3(0.55, 0.72, 0.42)
			var f := Transform3D(Basis.looking_at(at, Vector3.UP, true), at)
			for i in 5:
				var a := i / 5.0 * TAU
				list.append([sphere(0.14, _q(lite, 8, 14), _q(lite, 6, 10)), f * xf(Vector3(cos(a) * 0.17, sin(a) * 0.17, 0), Vector3.ZERO, Vector3(1, 1, 0.45)), Color("ff7f9a"), _s(0.6)])
			list.append([sphere(0.08, _q(lite, 8, 14), _q(lite, 6, 10)), f * xf(Vector3(0, 0, 0.03)), Color("f2c14e"), _s(0.6)])
			for side in [-1.0, 1.0]:
				list.append([sphere(0.12, _q(lite, 8, 16), 10), f * xf(Vector3(side * 0.2, -0.18, -0.025), Vector3(0, 0, -side * 0.65), Vector3(0.6, 1.4, 0.2)), Color("60a86c"), _s(0.65)])
		"crown":
			var gold := Color("f2c14e")
			var gs := _s(0.25, 0.85, Pattern.NONE, 1.2)
			var c := xf(Vector3(0, 0.86, 0), Vector3(-0.12, 0, 0))
			list.append([cylinder(0.4, 0.44, 0.2, _q(lite, 16, 28), true), c, gold, gs])
			for i in 7:
				var a := i / 7.0 * TAU
				list.append([cylinder(0.0, 0.07, 0.2, _q(lite, 6, 10)), c * xf(Vector3(sin(a) * 0.41, 0.19, cos(a) * 0.41)), gold, gs])
				list.append([sphere(0.035, _q(lite, 6, 10), _q(lite, 4, 8)), c * xf(Vector3(sin(a) * 0.41, 0.3, cos(a) * 0.41)), gold, gs])
			list.append([sphere(0.06, _q(lite, 8, 14), _q(lite, 6, 10)), c * xf(Vector3(0, 0, 0.43), Vector3.ZERO, Vector3(1, 1, 0.5)), Color("c8442f"), _s(0.15)])
			for y in [-0.1, 0.1]:
				list.append([torus(0.44 if y < 0 else 0.4, 0.018, 8, _q(lite, 20, 48)), c * xf(Vector3(0, y, 0), Vector3(PI / 2, 0, 0)), gold, gs])
			if not lite:
				for sd in [-1.0, 1.0]:
					list.append([octahedron(0.045), c * xf(Vector3(sd * 0.26, 0, 0.34)), Color("65d8ff" if sd < 0 else "b68aff"), _s(0.15, 0.25)])
		"headphones":
			var shell := Color("7862cc")
			var ss := _s(0.3, 0.25)
			list.append([torus(1.06, 0.055, _q(lite, 6, 12), _q(lite, 18, 48), PI), xf(Vector3(0, 0.04, 0)), shell, ss])
			for sd in [-1.0, 1.0]:
				list.append([sphere(0.27, _q(lite, 10, 24), _q(lite, 8, 16)), xf(Vector3(sd * 0.98, 0.06, 0), Vector3.ZERO, Vector3(0.44, 1, 1)), Color("292638"), _s(0.85)])
				list.append([sphere(0.25, _q(lite, 10, 24), _q(lite, 8, 16)), xf(Vector3(sd * 1.09, 0.06, 0), Vector3.ZERO, Vector3(0.4, 1, 1)), shell, ss])
				list.append([torus(0.16, 0.016, 8, _q(lite, 16, 32)), xf(Vector3(sd * 1.18, 0.06, 0), Vector3(0, PI / 2, 0)), Color("f2c14e"), _s(0.25, 0.65)])
		"beanie":
			var cream := Color("f3e7cf")
			list.append([sphere(1.07, _q(lite, 20, 36), _q(lite, 10, 18), 0, TAU, 0, PI * 0.375), xf(Vector3(0, 0.06, 0)), Color.WHITE, _s(0.95, 0.0, Pattern.BEANIE)])
			list.append([torus(0.989, 0.085, _q(lite, 8, 12), _q(lite, 28, 48)), xf(Vector3(0, 0.47, 0), Vector3(PI / 2, 0, 0)), cream, _s(0.95)])
			list.append([sphere(0.17, _q(lite, 10, 20), _q(lite, 8, 14)), xf(Vector3(0.06, 1.28, -0.04)), cream, _s(0.95)])
			list.append([box(0.18, 0.13, 0.035), xf(Vector3(0.22, 0.49, 1.035), Vector3(-0.4, 0, 0.05)), Color("d37863"), _s(0.8)])
		"aviator":
			var leather := Color("885839")
			var ls := _s(0.85)
			var trim := Color("e8c999")
			list.append([sphere(1.065, _q(lite, 18, 32), _q(lite, 8, 14), 0, TAU, 0, PI * 0.35), xf(Vector3(0, 0.035, 0)), leather, ls])
			list.append([torus(0.949, 0.038, _q(lite, 6, 10), _q(lite, 24, 40)), xf(Vector3(0, 0.518, 0), Vector3(PI / 2, 0, 0)), trim, _s(0.75)])
			for sd in [-1.0, 1.0]:
				list.append([sphere(0.31, _q(lite, 10, 18), _q(lite, 8, 12)), xf(Vector3(sd * 0.97, 0.25, -0.015), Vector3.ZERO, Vector3(0.22, 1, 0.6)), leather, ls])
				# The goggles sit on the forehead, clear of Dahrooj's eyes.
				var p := Vector3(sd * 0.28, 0.68, 0.85)
				list.append([torus(0.205, 0.039, _q(lite, 6, 10), _q(lite, 16, 28)), xf(p, Vector3(-0.62, 0, 0), Vector3(1.08, 0.85, 1)), trim, _s(0.75)])
				list.append([sphere(0.17, _q(lite, 12, 20), _q(lite, 8, 12)), xf(p + Vector3(0, 0.014, 0.02), Vector3(-0.62, 0, 0), Vector3(1.08, 0.85, 0.16)), Color("66bad4"), _s(0.22, 0.15)])
			list.append([box(0.17, 0.055, 0.06), xf(Vector3(0, 0.68, 0.875), Vector3(-0.62, 0, 0)), leather, ls])
		"woodhat":
			var hat := xf(Vector3(0, 0.9, 0), Vector3(-0.12, 0, -0.12))
			var maple := _s(0.7, 0.0, Pattern.WOOD)
			list.append([cylinder(0.62, 0.62, 0.07, _q(lite, 20, 40)), hat, Color.WHITE, maple])
			list.append([cylinder(0.34, 0.41, 0.5, _q(lite, 20, 40)), hat * xf(Vector3(0, 0.27, 0)), Color.WHITE, maple])
			list.append([cylinder(0.405, 0.42, 0.095, _q(lite, 20, 40)), hat * xf(Vector3(0, 0.1, 0)), Color("765036"), _s(0.8)])
			list.append([octahedron(0.07), hat * xf(Vector3(0, 0.11, 0.425)), Color("f3d497"), _s()])
		"starGlasses":
			var gold := Color("f0c45e")
			var gs := _s(0.35, 0.3)
			for sd in [-1.0, 1.0]:
				var q := Vector3(sd * 0.34, 0.13, 1.15)
				list.append([star(1.0, 0.045), xf(q, Vector3(0, sd * 0.2, 0)), gold, gs])
				list.append([star(1.0), xf(q + Vector3(0, 0, 0.053), Vector3(0, sd * 0.2, 0), Vector3(0.7, 0.7, 0.7)), Color("7760a5"), _s(0.3)])
				list.append([box(0.035, 0.04, 0.9), xf(Vector3(sd * 0.71, 0.13, 0.65), Vector3(0, -sd * 0.56, 0)), gold, gs])
			list.append([box(0.18, 0.04, 0.045), xf(Vector3(0, 0.14, 1.18)), gold, gs])
		"scarf":
			var wool := _s(0.9, 0.0, Pattern.SCARF)
			list.append([torus(0.81, 0.095, _q(lite, 8, 12), _q(lite, 20, 48)), xf(Vector3(0, -0.56, 0), Vector3(PI / 2, 0, 0)), Color.WHITE, wool])
			list.append([sphere(0.13, 12, 10), xf(Vector3(0.3, -0.6, 0.69)), Color.WHITE, wool])
			for sd in [-1.0, 1.0]:
				list.append([box(0.15, 0.47, 0.045), xf(Vector3(0.3 + sd * 0.08, -0.86, 0.65), Vector3(0, 0, sd * 0.17)), Color.WHITE, wool])
				if not lite:
					for j in 4:
						list.append([cylinder(0.009, 0.009, 0.09, 6), xf(Vector3(0.3 + sd * 0.08 + (j - 1.5) * 0.035, -1.13, 0.65)), Color.WHITE, wool])
	return list


## The lite (crowd) or full facet count.
static func _q(lite: bool, a: int, b: int) -> int:
	return a if lite else b
