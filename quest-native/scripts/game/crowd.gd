class_name Crowd
extends Node3D
## Crowds: lots of little Dahroojs in a handful of draws (src/reference/character.js crowd()).
## Used by the opening and Dahrooj Rain (and could carry shots). Each style's bodies are
## one MultiMesh (jelly and bubble keep their own shaders and learn the instance colour),
## the eyes are one MultiMesh per look (open / wide / shut; whites, pupils and glints of
## both eyes merged into one mesh), the fur ball's ribbon one, the jelly's bandage one,
## and each accessory one. Positions and sizes are in this node's units (metres when it
## sits in the rig).
##
## begin(); add(style, pos, radius, toward, squash, eyes, accessory, color) per ball; end().

const DAHROOJ_COLORS := {"jelly": "ff69b4", "fabric": "b36bff", "clay": "ff9b3d", "fur": "f1ebe1", "bubble": "cfe8ff"}
const STYLES := ["jelly", "fabric", "clay", "fur", "bubble"]
const HEADWEAR := ["party", "cap", "crown", "headphones", "aviator", "woodhat", "beanie"]
## The accessories built for crowds (the rain's own seven).
const ACCESSORIES := ["party", "glasses", "cap", "flower", "crown", "headphones", "scarf"]
const EYE_LOOKS := {"open": [1.0, 1.0], "wide": [1.0, 0.42 / 0.55], "shut": [0.12, 1.0]}
const ER := 0.19
const BOW_AT := Vector3(-0.1, 0.86, 0.5)

static var _cache := {}

var max_n := 120
var with_accessories := false
## The drawn face (mouth and blush) on a cap: not in the original crowd, so off by default.
var with_faces := false
## Default colour per style (sRGB) when add() gets no colour: DAHROOJ_COLORS.
var tints := {}
var parts := {}  # name -> {mm: MultiMesh, mi: MultiMeshInstance3D, n: int, cap: int}


func _init(max_count := 120, accessories := false, faces := false) -> void:
	max_n = max_count
	with_accessories = accessories
	with_faces = faces
	for s in DAHROOJ_COLORS:
		tints[s] = Color(DAHROOJ_COLORS[s])
	for s in STYLES:
		_part("body_" + s, _body_mesh(), _body_mat(s), max_n, true, 3 if s == "bubble" else 0)
	for look in EYE_LOOKS:
		_part("eyes_" + look, _eyes_mesh(look), _eye_mat(), max_n)
	_part("bow", _bow_mesh(), _deco_mat(), max_n)
	_part("bandage", _bandage_mesh(), _deco_mat(), max_n)
	if with_accessories:
		for id in ACCESSORIES:
			_part("acc_" + id, _accessory_mesh(id), _deco_mat(), max_n)
	if with_faces:
		for f in ["open", "wide"]:
			_part("face_" + f, DahroojView._cap_mesh(1.006), DahroojView._face_mat(f), max_n)


func _part(id: String, mesh: Mesh, mat: Material, cap: int, colors := false, priority := 0) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	mm.instance_count = cap
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.name = id
	mi.multimesh = mm
	mi.material_override = mat
	mi.sorting_offset = float(priority)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-40, -20, -40), Vector3(80, 60, 80))
	add_child(mi)
	parts[id] = {"mm": mm, "mi": mi, "n": 0, "cap": cap}


func begin() -> void:
	for id in parts:
		parts[id].n = 0


func _put(id: String, m: Transform3D, color = null) -> void:
	var p: Dictionary = parts[id]
	var n: int = p.n
	if n >= int(p.cap):
		return
	var mm: MultiMesh = p.mm
	mm.set_instance_transform(n, m)
	if color != null:
		mm.set_instance_color(n, color)
	p.n = n + 1


static func _color(c) -> Color:
	if c is Color:
		return c
	if c is int:
		return Color.hex(((c as int) << 8) | 0xff)
	return Color(str(c))


## One ball: style, centre, radius, the point it faces (or null), squash (sx, sy),
## eyes "open" | "wide" | "shut" | "" (none), accessory id ("" for none), colour
## (Color, 0xRRGGBB or "rrggbb"; null for the style's own).
func add(style: String, pos: Vector3, radius: float, toward, squash := Vector2.ONE, eyes := "open", accessory := "", color = null) -> void:
	var body := "body_" + style
	if not parts.has(body):
		body = "body_jelly"
	if int(parts[body].n) >= max_n:
		return
	var m := place(pos, radius, toward, squash)
	var tint: Color = _color(color) if color != null else (tints.get(style, Color.WHITE) as Color)
	_put(body, m, tint.srgb_to_linear())
	if style == "jelly":
		_put("bandage", m)
	if parts.has("acc_" + accessory):
		_put("acc_" + accessory, m * Transform3D(Basis.from_scale(Vector3.ONE * 1.08), Vector3.ZERO) if style == "fur" else m)
	if style == "fur" and accessory not in HEADWEAR:
		_put("bow", m)
	if eyes != "":
		_put("eyes_" + (eyes if EYE_LOOKS.has(eyes) else "open"), m)
		if with_faces:
			_put("face_" + ("wide" if eyes == "wide" else "open"), m)


## A ball's instance transform: at pos, radius big, squashed (in world axes), its +Z (face)
## toward the point asked.
static func place(pos: Vector3, radius: float, toward, squash := Vector2.ONE) -> Transform3D:
	var r := Basis.IDENTITY
	if toward != null:
		var d: Vector3 = (toward as Vector3) - pos
		if d.length_squared() > 1e-12:
			var dn := d.normalized()
			r = Basis.looking_at(dn, Vector3.UP if absf(dn.y) < 0.9999 else Vector3.BACK, true)
	return Transform3D(Basis.from_scale(Vector3(radius * squash.x, radius * squash.y, radius * squash.x)) * r, pos)


func end() -> void:
	for id in parts:
		(parts[id].mm as MultiMesh).visible_instance_count = int(parts[id].n)


## Balls drawn (bodies of every style).
func count() -> int:
	var n := 0
	for s in STYLES:
		n += int(parts["body_" + s].n)
	return n


func part_count(id: String) -> int:
	return int(parts[id].n) if parts.has(id) else 0


# --- materials -----------------------------------------------------------------------------

const _SRGB := "vec3 lin(vec3 c){return mix(pow((c+vec3(.055))/1.055,vec3(2.4)),c/12.92,lessThan(c,vec3(.04045)));}\n"

## Jelly: light refracted through the ball (character.js jellyMaterial, instanced). A soft sky is
## looked up along the path light takes through a sphere of index 1.35, a little apart per colour;
## Beer-Lambert absorption from the instance tint, a Fresnel reflection and the sun's highlight.
const JELLY_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;
uniform float ior = 1.35;
uniform vec3 light_dir = vec3(0.4, 0.8, 0.45);
uniform vec3 light_color = vec3(1.0);
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
	vTint = COLOR.rgb;
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
	vec3 L = normalize(light_dir);
	vec3 H = normalize(L + V);
	float nh = max(dot(N, H), 0.0);
	vec3 spec = light_color * (pow(nh, 260.0) * 2.2 + pow(nh, 40.0) * 0.12);
	float rim = pow(1.0 - max(dot(N, V), 0.0), 2.0) * max(dot(N, L) * 0.5 + 0.5, 0.0);
	ALBEDO = mix(trans, refl, f) + spec + vTint * rim * 0.35;
}
"""

## Bubble: a swirling soap film with white spots fixed to the body (character.js MATERIALS.bubble).
const BUBBLE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
varying vec3 vN;
varying vec3 vV;
varying vec3 vP;
varying vec3 vTint;
void vertex() {
	vec4 mv = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vN = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vV = normalize(-mv.xyz);
	vP = VERTEX;
	vTint = COLOR.rgb;
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

## Eyes: glossy whites and pupils (roughness in the vertex alpha) and glowing glints (alpha 1).
const EYE_SHADER := """
shader_type spatial;
render_mode cull_back;
void fragment() {
	if (COLOR.a > 0.99) {
		ALBEDO = vec3(0.0);
		EMISSION = COLOR.rgb;
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
	} else {
		ALBEDO = COLOR.rgb;
		ROUGHNESS = COLOR.a;
		SPECULAR = 0.6;
	}
}
"""


static func _shader_mat(key: String, code: String) -> ShaderMaterial:
	if not _cache.has(key):
		var sh := Shader.new()
		sh.code = code
		var m := ShaderMaterial.new()
		m.shader = sh
		_cache[key] = m
	return _cache[key]


static func _body_mat(style: String) -> Material:
	match style:
		"jelly":
			return _shader_mat("jelly", JELLY_SHADER)
		"bubble":
			var b := _shader_mat("bubble", BUBBLE_SHADER)
			b.render_priority = 3
			return b
	var key := "mat_" + style
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true  # the instance colour; a cream base would tint it twice
		m.albedo_color = Color.WHITE
		match style:
			"fur":
				m.albedo_texture = load("res://assets/character/fur.png")
				m.roughness = 0.95
			"fabric":
				m.roughness = 0.82
			_:
				m.roughness = 0.72
		_cache[key] = m
	return _cache[key]


static func _eye_mat() -> Material:
	return _shader_mat("eyes", EYE_SHADER)


static func _deco_mat() -> Material:
	if not _cache.has("deco"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.5
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_cache["deco"] = m
	return _cache["deco"]


# --- geometry (three.js generators, so the shapes match) -----------------------------------

## Generators return {v, n, uv, i} (vertices, normals, uvs, indices).


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
				puv.append(Vector2(0.5, 0.5))
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
			puv.append(Vector2(float(i) / ts, float(j) / rs))
	for j in range(1, rs + 1):
		for i in range(1, ts + 1):
			var a := (ts + 1) * j + i - 1
			var b := (ts + 1) * (j - 1) + i - 1
			var c := (ts + 1) * (j - 1) + i
			var d := (ts + 1) * j + i
			pi.append_array([a, b, d, b, c, d])
	return {"v": pv, "n": pn, "uv": puv, "i": pi}


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
			puv.append(Vector2.ZERO)
		pi.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	return {"v": pv, "n": pn, "uv": puv, "i": pi}


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


## three.js object matrix: position, Euler rotation (XYZ unless told), scale.
static func xf(pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, order := EULER_ORDER_XYZ) -> Transform3D:
	return Transform3D(Basis.from_euler(rot, order) * Basis.from_scale(scl), pos)


## Merge [geometry, transform, colour (sRGB; alpha kept)] parts into one mesh with vertex
## colours (linear). Triangles face the way their normals point (Godot: clockwise front).
static func merge(list: Array, with_uv := false) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	for part in list:
		var g: Dictionary = part[0]
		var t: Transform3D = part[1]
		var col: Color = part[2]
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
	if with_uv:
		arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


static func _cached(key: String, build: Callable) -> ArrayMesh:
	if not _cache.has(key):
		_cache[key] = build.call()
	return _cache[key]


## Small balls need fewer facets: SphereGeometry(r, 16, 12), unit radius.
static func _body_mesh() -> ArrayMesh:
	return _cached("body", func() -> ArrayMesh: return merge([[sphere(1.0, 16, 12), Transform3D.IDENTITY, Color.WHITE]], true))


## Both eyes for one look, in the ball's own frame (unit radius): [white, pupil, glint] per side.
static func _eyes_mesh(look: String) -> ArrayMesh:
	return _cached("eyes_" + look, func() -> ArrayMesh:
		var open: float = EYE_LOOKS[look][0]
		var pr: float = EYE_LOOKS[look][1]
		var eye := sphere(1.0, 10, 6)
		var glint := sphere(1.0, 6, 4)
		var list := []
		for s in [-1.0, 1.0]:
			var pivot := Transform3D(Basis.from_euler(Vector3(-0.08, s * 0.31, 0), EULER_ORDER_YXZ), Vector3.ZERO)
			var ball := pivot * xf(Vector3(0, 0, 1.0 - ER * 0.22), Vector3.ZERO, Vector3(1, open, 1))
			var pupil := ball * xf(Vector3(0, 0, ER * 0.42), Vector3.ZERO, Vector3(pr, pr, 1))
			list.append([eye, ball * xf(Vector3.ZERO, Vector3.ZERO, Vector3(ER, ER * 1.12, ER * 0.55)), Color(Color("fffaf2"), 0.2)])
			list.append([eye, pupil * xf(Vector3.ZERO, Vector3.ZERO, Vector3(ER * 0.55, ER * 0.55, ER * 0.22)), Color(Color("2c2d3d"), 0.06)])
			list.append([glint, pupil * xf(Vector3(-ER * 0.2, ER * 0.22, ER * 0.2), Vector3.ZERO, Vector3.ONE * ER * 0.15), Color(1, 1, 1, 1)])
		return merge(list))


## The fur ball's ribbon: two loops and a knot where bow() puts them.
static func _bow_mesh() -> ArrayMesh:
	return _cached("bow", func() -> ArrayMesh:
		var g := xf(BOW_AT.normalized() * 1.06, Vector3(-0.15, -0.1, 0.15))
		var list := []
		for s in [-1.0, 1.0]:
			list.append([sphere(0.17, 10, 8), g * xf(Vector3(s * 0.2, 0, 0), Vector3(0, 0, s * 0.35), Vector3(1.2, 0.9, 0.6)), Color("d8452f")])
		list.append([sphere(0.07, 8, 6), g, Color("b8432a")])
		return merge(list))


## The jelly's bandage on its surface, tilted.
static func _bandage_mesh() -> ArrayMesh:
	return _cached("bandage", func() -> ArrayMesh:
		var n := Vector3(0.4, 0.62, 0.6).normalized()
		var g := Transform3D(Basis.looking_at(n, Vector3.UP, true) * Basis(Vector3.BACK, -0.55), n * 1.005)
		var list := [[box(0.66, 0.24, 0.03), g, Color("e8c29d")], [box(0.22, 0.17, 0.04), g, Color("f4ddc3")]]
		for i in 6:
			var p := Vector3((i % 3 - 1) * 0.07 + (-0.23 if i < 3 else 0.23), (1 if i < 3 else -1) * 0.03, 0.016)
			list.append([circle(0.012, 8), g * xf(p), Color("c9a07c")])
		return merge(list))


## The lite (crowd) accessories of character.js accessory(id, true), unit radius, face +Z.
## Textured parts take their main colour (the party hat keeps its seven stripes).
static func _accessory_mesh(id: String) -> ArrayMesh:
	return _cached("acc_" + id, func() -> ArrayMesh:
		var list := []
		match id:
			"party":
				var hat := xf(Vector3(0.06, 0.90, 0.015), Vector3(-0.09, 0, -0.14))
				var cols := ["ff697e", "ffa04e", "ffe65c", "66d88d", "65c5ff", "8086ed", "c080df"]
				for i in 7:
					var h := 1.02 / 7.0
					list.append([cylinder(0.44 * i / 7.0, 0.44 * (i + 1) / 7.0, h, 18, true), hat * xf(Vector3(0, 1.02 - (i + 0.5) * h, 0)), Color(cols[i])])
				list.append([sphere(0.13, 10, 8), hat * xf(Vector3(0, 1.035, 0)), Color("ffedb1")])
				list.append([torus(0.44, 0.044, 8, 24), hat * xf(Vector3.ZERO, Vector3(PI / 2, 0, 0)), Color("ffdf73")])
			"glasses":
				var frame := Color("2c2d3d")
				for sd in [-1.0, 1.0]:
					var a: float = sd * 0.32
					var out := Vector3(sin(a), 0, cos(a))
					var p := out * 1.17
					p.y = 0.1
					list.append([torus(0.21, 0.035, 6, 12), xf(p, Vector3(0, a, 0), Vector3(1, 0.8, 1)), frame])
					list.append([circle(0.2, 12), xf(p - out * 0.005, Vector3(0, a, 0), Vector3(1, 0.8, 1)), Color("1b2233")])
					list.append([box(0.035, 0.035, 1.05), xf(Vector3(sd * 0.74, 0.13, 0.66), Vector3(0, -sd * 0.56, 0)), frame])
				list.append([torus(0.08, 0.026, 6, 8, PI), xf(Vector3(0, 0.15, 1.2)), frame])
			"cap":
				var red := Color("c8442f")
				var white := Color("fffaf2")
				list.append([sphere(1.05, 16, 8, 0, TAU, 0, PI * 0.36), xf(Vector3(0, 0.02, 0)), red])
				list.append([cylinder(0.68, 0.68, 0.04, 16, false, -PI / 2, PI), xf(Vector3(0, 0.5, 0.55), Vector3(0.42, 0, 0), Vector3(1, 1, 0.9)), red])
				list.append([sphere(0.07, 8, 6), xf(Vector3(0, 1.06, 0)), white])
				list.append([sphere(0.13, 16, 12), xf(Vector3(0, 0.72, 0.77), Vector3(-0.2, 0, 0), Vector3(1, 1, 0.2)), white])
				list.append([sphere(0.055, 12, 8), xf(Vector3(0, 0.73, 0.81), Vector3.ZERO, Vector3(1, 1, 0.2)), Color("f2c14e")])
			"flower":
				var at := Vector3(0.55, 0.72, 0.42)
				var f := Transform3D(Basis.looking_at(at, Vector3.UP, true), at)
				for i in 5:
					var a := i / 5.0 * TAU
					list.append([sphere(0.14, 8, 6), f * xf(Vector3(cos(a) * 0.17, sin(a) * 0.17, 0), Vector3.ZERO, Vector3(1, 1, 0.45)), Color("ff7f9a")])
				list.append([sphere(0.08, 8, 6), f * xf(Vector3(0, 0, 0.03)), Color("f2c14e")])
				for side in [-1.0, 1.0]:
					list.append([sphere(0.12, 8, 10), f * xf(Vector3(side * 0.2, -0.18, -0.025), Vector3(0, 0, -side * 0.65), Vector3(0.6, 1.4, 0.2)), Color("60a86c")])
			"crown":
				var gold := Color("f2c14e")
				var c := xf(Vector3(0, 0.86, 0), Vector3(-0.12, 0, 0))
				list.append([cylinder(0.4, 0.44, 0.2, 16, true), c, gold])
				for i in 7:
					var a := i / 7.0 * TAU
					list.append([cylinder(0.0, 0.07, 0.2, 6), c * xf(Vector3(sin(a) * 0.41, 0.19, cos(a) * 0.41)), gold])
					list.append([sphere(0.035, 6, 4), c * xf(Vector3(sin(a) * 0.41, 0.3, cos(a) * 0.41)), gold])
				list.append([sphere(0.06, 8, 6), c * xf(Vector3(0, 0, 0.43), Vector3.ZERO, Vector3(1, 1, 0.5)), Color("c8442f")])
				for y in [-0.1, 0.1]:
					list.append([torus(0.44 if y < 0 else 0.4, 0.018, 8, 20), c * xf(Vector3(0, y, 0), Vector3(PI / 2, 0, 0)), gold])
			"headphones":
				var shell := Color("7862cc")
				list.append([torus(1.06, 0.055, 6, 18, PI), xf(Vector3(0, 0.04, 0)), shell])
				for sd in [-1.0, 1.0]:
					list.append([sphere(0.27, 10, 8), xf(Vector3(sd * 0.98, 0.06, 0), Vector3.ZERO, Vector3(0.44, 1, 1)), Color("292638")])
					list.append([sphere(0.25, 10, 8), xf(Vector3(sd * 1.09, 0.06, 0), Vector3.ZERO, Vector3(0.4, 1, 1)), shell])
					list.append([torus(0.16, 0.016, 8, 16), xf(Vector3(sd * 1.18, 0.06, 0), Vector3(0, PI / 2, 0)), Color("f2c14e")])
			"scarf":
				var wool := Color("46aaa9")
				list.append([torus(0.81, 0.095, 8, 20), xf(Vector3(0, -0.56, 0), Vector3(PI / 2, 0, 0)), wool])
				list.append([sphere(0.13, 12, 10), xf(Vector3(0.3, -0.6, 0.69)), wool])
				for sd in [-1.0, 1.0]:
					list.append([box(0.15, 0.47, 0.045), xf(Vector3(0.3 + sd * 0.08, -0.86, 0.65), Vector3(0, 0, sd * 0.17)), wool])
		return merge(list))
