class_name SlimeStage
extends Node3D
## Slime («سلايم», mode "slime"): throw Dahrooj and he SPLATS and STICKS where he lands, on
## the goo wall, the ground or another stuck Dahrooj, then slowly melts into a glossy jelly
## puddle (the body sags, the footprint spreads; on a wall he slides down a little and drips;
## on a ceiling he hangs, sagging downward into a drop, and drips fall from him to the floor).
## Every Dahrooj is a jelly in a random colour. The impact shows on his face: soft = eyes pop
## wide, medium = cross-eyed, hard = squeezed shut with stars, very hard = swirly dizzy eyes;
## the jelly wobbles and settles, smeared along the way he came in, then blinks slowly and
## melts into a sleepy smile. Later throws pile up on the blobs (sticky towers that wobble):
## the "tower of 5" challenge. No score panel: the points go to ctx.counts["slime"], which the
## jelly score popup shows (the target's rings stay on the wall). Blaster shots pop blobs (and whatever is
## stacked on them) in a burst of goo. At most CAP blobs: the oldest free one dissolves.
## Game units, like the other stages.
##
## Points: the target's rings on the goo wall (10 / 5 / 3 / 1 from the bullseye out) and a
## stacking bonus (+2 for each level a blob sits on: a blob on a 2-high pile scores 4).
##
## Surfaces: in VR the goo wall (with its target) and the ground; in mixed reality, when
## `planes_provider` returns any, the room's planes instead of the wall (the target goes on
## the wall that faces you best): an Array of {pos: Vector3 (centre, game units), normal:
## Vector3 (game space, out of the surface), ax: Vector3, ay: Vector3 (unit, in the plane),
## half: Vector2 (half extents along ax / ay, game units), label: String}; a ceiling ("ceiling",
## normal pointing down) works too. The ground (y = 0) always holds.
##
## Drawing: one body MultiMesh whose vertex shader melts a sphere (squash, sag and spread along
## the stuck normal; per instance: face direction, melt, wobble in INSTANCE_CUSTOM), the eyes
## and the drawn face in their own MultiMeshes with the same deformation (so they ride the
## melting body), stains, drips and droplets, stars. Blaster: every live blob has a hidden
## (layers = 0) collision sphere MeshInstance3D, so the runtime's ray_stage() finds it.

const R := Ball.BR
const CAP := 24  # live blobs at most; the oldest free one dissolves
const SLOTS := 32  # instances (live blobs plus a few dissolving)
const MELT_T := 2.4  # melt time constant (game seconds)
const HY_MIN := 0.36  # height of a fully melted blob / a fresh one
const SKIRT := 0.55
const SAG := 0.9
const STACK_MELT := 0.42  # blobs in a pile melt this far (and the pile keeps standing)
## Hanging (a ceiling, gravity pulling out of the surface): a melted blob stretches to
## 1 + HANG_K of its height, and its tip runs out TIP_K (× R) further, narrower.
const HANG_K := 0.55
const TIP_K := 0.35
const CEIL_DRIPS := 4  # drops that fall from a blob on a ceiling
const WALL_Z := -12.0
const WALL := Vector2(9.0, 7.2)  # the goo wall: width, height
const WALL_D := 0.3
const TARGET_Y := 3.3
const RINGS := [0.45, 1.1, 1.75, 2.4]
const RING_PTS := [10, 5, 3, 1]
const RING_COLS := ["ffd23f", "ff69b4", "fff4e0", "58b9ff"]
const STACK_PTS := 2
const TOWER := 5
const COLORS := ["pink", "red", "orange", "yellow", "green", "blue", "purple"]
## Impact speed (game units / s) where the face reaction changes: wide | cross | shut | dizzy.
const SPEEDS := [7.0, 12.0, 16.0]
const REACT_T := {"wide": 1.3, "cross": 1.7, "shut": 1.2, "dizzy": 2.2}
const EYES := ["open", "wide", "cross", "dizzy_a", "dizzy_b", "sleepy", "blink"]
const FACES := ["open", "wide", "joy", "closed"]
const DROPS_MAX := 160
const GOO_MAX := 320
const STARS_MAX := 48
const ER := 0.2

static var _cache := {}

var aim_z := WALL_Z
var far_z = null
var reach_z = null
var friction = null
var shot_time = 4.0
var ctx: GameCtx

## Room planes (mixed reality); see the header. Unset or empty: the goo wall.
var planes_provider: Callable
## Where the player's head is (game units): new blobs turn their faces to it.
var viewer := Vector3(0, 3.2, 9.0)
## The colour (DahroojLooks colour id) of the next Dahrooj in the hand: main shows him in it.
var next_color := "pink"

var F := {"score": 0, "stuck": 0, "popped": 0, "tower": 0, "best_tower": 0, "dripped": 0}
var blobs: Array = []  # see _new_blob()
var drops: Array = []
var planes: Array = []
var target := {"pos": Vector3(0, TARGET_Y, WALL_Z), "normal": Vector3.BACK, "ax": Vector3.RIGHT, "ay": Vector3.UP, "on": true}
var board: Node3D
var room_target: MeshInstance3D
var time := 0.0
var _parts := {}  # id -> MultiMesh
var _proxies: Array = []
var _by_id := {}
var _next_id := 1
var _vin := {}  # shot id -> velocity before this sub-step (the floor bounce flips it)
var _shot_colors := {}  # shot id -> colour id it was thrown in
var _gone_shots: Array = []  # volley shots that stuck (taken out of the volley in update)
var _planes_t := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 404
	name = "Slime"
	next_color = COLORS[_rng.randi() % COLORS.size()]
	_build_parts()
	for i in SLOTS:
		var proxy := MeshInstance3D.new()
		proxy.name = "BlobHit%d" % i
		proxy.mesh = _proxy_mesh()
		proxy.layers = 0  # never drawn: only the blaster's ray sees it
		proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		proxy.visible = false
		add_child(proxy)
		_proxies.append(proxy)
	_build_board()
	room_target = MeshInstance3D.new()
	room_target.name = "RoomTarget"
	room_target.mesh = target_mesh()
	room_target.material_override = _mat("target")
	room_target.visible = false
	add_child(room_target)
	draw()


# ---- shaders and materials ----

## The melt (model space of a unit ball whose centre is the origin; +Y out of the surface it
## stuck to, the instance origin on that surface): squash to hy, spread to keep the volume,
## the lower half flares into a thin skirt (the puddle), on a wall the down side sags.
const DEFORM_LIB := """
uniform float face_part = 0.0;
uniform float hy_min = 0.36;
uniform float skirt = 0.55;
uniform float sag = 0.9;
uniform float hang_k = 0.55;
uniform float tip_k = 0.35;
vec3 slime_shape(vec3 v, float m, vec3 g, float rip, float tm) {
	v *= 1.0 + rip * 0.07 * sin(v.x * 4.0 + v.y * 3.0 + v.z * 5.0 + tm * 15.0);
	// On a ceiling gravity pulls out of the surface (g.y > 0): he hangs and stretches downward
	// into a drop instead of flattening (hang = 0 on floors and walls).
	float hang = clamp((g.y - 0.3) / 0.6, 0.0, 1.0);
	float hy = mix(mix(1.0, hy_min, m), 1.0 + hang_k * m, hang);
	float l = max(length(v), 1e-4);
	float u = clamp(-v.y / l, 0.0, 1.0);
	float y = (1.0 + v.y) * hy;
	vec2 q = v.xz * inversesqrt(hy);
	q *= 1.0 + m * skirt * (1.0 - 0.5 * hang) * sin(min(u * 2.0, 1.0) * 1.5708);
	y *= 1.0 - m * 0.94 * (1.0 - 0.5 * hang) * smoothstep(0.0, 0.5, u);
	float tip = hang * m * smoothstep(0.2, 1.0, v.y);
	q *= 1.0 - 0.35 * tip;
	y += tip_k * tip;
	float gl = length(g.xz);
	if (gl > 0.02) {
		vec2 gd = g.xz / gl;
		float side = dot(v.xz, gd);
		float w = smoothstep(-0.7, 1.0, side) * (1.0 - 0.45 * clamp(v.y, 0.0, 1.0));
		q += gd * (m * sag * gl * w);
	}
	return vec3(q.x, y, q.y);
}
"""

## Vertex code: the face parts (eyes, drawn face) first turn from their own frame (face +Z) to
## the instance's face direction (INSTANCE_CUSTOM.xy = its x and z; y >= 0), then everything
## melts; normals from the deformed tangents. Leaves `mid`, the melted centre.
const DEFORM_VERTEX := """
	vec3 slime_up = normalize(transpose(mat3(MODEL_MATRIX)) * vec3(0.0, 1.0, 0.0));
	vec4 slime_c = INSTANCE_CUSTOM;
	vec3 sv = VERTEX;
	vec3 sn = NORMAL;
	if (face_part > 0.5) {
		vec3 f = vec3(slime_c.x, sqrt(max(0.0, 1.0 - slime_c.x * slime_c.x - slime_c.y * slime_c.y)), slime_c.y);
		vec3 h = slime_up - f * dot(slime_up, f);
		if (dot(h, h) < 1e-4) {
			h = vec3(0.0, 0.0, 1.0) - f * f.z;
		}
		vec3 yb = normalize(h);
		vec3 xb = cross(yb, f);
		mat3 fb = mat3(xb, yb, f);
		sv = fb * sv;
		sn = fb * sn;
	}
	vec3 ta = abs(sn.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 t1 = normalize(cross(ta, sn));
	vec3 t2 = cross(sn, t1);
	vec3 p0 = slime_shape(sv, slime_c.z, -slime_up, slime_c.w, TIME);
	vec3 p1 = slime_shape(sv + t1 * 0.03, slime_c.z, -slime_up, slime_c.w, TIME);
	vec3 p2 = slime_shape(sv + t2 * 0.03, slime_c.z, -slime_up, slime_c.w, TIME);
	VERTEX = p0;
	NORMAL = normalize(cross(p1 - p0, p2 - p0));
	vec3 mid = slime_shape(vec3(0.0), slime_c.z, -slime_up, 0.0, TIME);
"""

const FACE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D face_tex : source_color, filter_linear_mipmap;
%s
void vertex() {
%s
}
void fragment() {
	vec4 c = texture(face_tex, UV);
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
"""

## A soft wet stain (a flat unit disc in XZ), the instance colour, fading out to the rim.
const STAIN_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
varying float vr;
void vertex() {
	vr = length(VERTEX.xz);
}
void fragment() {
	float a = 1.0 - smoothstep(0.45, 1.0, vr);
	ALBEDO = COLOR.rgb;
	ALPHA = a * COLOR.a;
}
"""


static func _shader_mat(key: String, code: String, params := {}) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	for k in params:
		m.set_shader_parameter(k, params[k])
	_cache[key] = m
	return m


## The jelly (DahroojLooks.JELLY_SHADER, the instanced white-based one) with the melt in its
## vertex function; the refraction is centred on the melted middle.
static func body_shader_code() -> String:
	var code: String = DahroojLooks.JELLY_SHADER
	var a := code.find("void vertex() {")
	var b := code.find("\n}\n", a)
	var vtx := "void vertex() {\n" + DEFORM_VERTEX + """
	vW = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vN = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	vC = (MODEL_MATRIX * vec4(mid, 1.0)).xyz;
	vTint = COLOR.rgb * tint;
}
"""
	return code.substr(0, a) + DEFORM_LIB + vtx + code.substr(b + 3)


static func eye_shader_code() -> String:
	var code: String = Crowd.EYE_SHADER
	var at := code.find("void fragment()")
	return code.substr(0, at) + DEFORM_LIB + "void vertex() {\n" + DEFORM_VERTEX + "}\n" + code.substr(at)


static func _mat(key: String) -> Material:
	var ck := "mat_" + key
	if _cache.has(ck):
		return _cache[ck]
	var m: Material
	match key:
		"body":
			m = _shader_mat("sh_body", body_shader_code(), {"tint": Vector3.ONE, "hy_min": HY_MIN, "skirt": SKIRT, "sag": SAG, "hang_k": HANG_K, "tip_k": TIP_K})
		"eyes":
			m = _shader_mat("sh_eyes", eye_shader_code(), {"face_part": 1.0, "hy_min": HY_MIN, "skirt": SKIRT, "sag": SAG, "hang_k": HANG_K, "tip_k": TIP_K})
		"stain":
			m = _shader_mat("sh_stain", STAIN_SHADER)
		"goo":
			m = DahroojLooks.body_material("jelly", "", true)
		"star":
			var s := StandardMaterial3D.new()
			s.vertex_color_use_as_albedo = true
			s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			s.cull_mode = BaseMaterial3D.CULL_DISABLED
			m = s
		"wall":
			var s := StandardMaterial3D.new()
			s.albedo_color = Color("3b2a55")
			s.roughness = 0.55
			m = s
		"frost":
			var s := StandardMaterial3D.new()
			s.albedo_color = Color("7ee04f")
			s.roughness = 0.08
			s.rim_enabled = true
			s.rim = 0.6
			s.rim_tint = 0.3
			s.emission_enabled = true
			s.emission = Color("2f7a12")
			s.emission_energy_multiplier = 0.35
			m = s
		"target":
			var s := StandardMaterial3D.new()
			s.vertex_color_use_as_albedo = true
			s.roughness = 0.5
			s.cull_mode = BaseMaterial3D.CULL_DISABLED
			m = s
		_:
			if key.begins_with("face_"):
				var f := key.trim_prefix("face_")
				var sm := _shader_mat("sh_" + key, FACE_SHADER % [DEFORM_LIB, DEFORM_VERTEX],
					{"face_part": 1.0, "hy_min": HY_MIN, "skirt": SKIRT, "sag": SAG, "hang_k": HANG_K, "tip_k": TIP_K, "face_tex": load("res://assets/character/face_%s.png" % f)})
				sm.render_priority = 1
				m = sm
	_cache[ck] = m
	return m


# ---- meshes ----

static func _proxy_mesh() -> SphereMesh:
	if not _cache.has("proxy"):
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 12
		s.rings = 6
		_cache["proxy"] = s
	return _cache["proxy"]


## Both eyes for a look, in the ball's own frame (unit radius, face +Z), as Crowd's eyes:
## [white, pupil, glint] per side, whites and pupils with their roughness in the alpha.
static func eye_mesh(look: String) -> ArrayMesh:
	var key := "eyes_" + look
	if _cache.has(key):
		return _cache[key]
	var eye := DahroojLooks.sphere(1.0, 12, 8)
	var dot := DahroojLooks.sphere(1.0, 6, 4)
	var white := Color(Color("fffaf2"), 0.2)
	var ink := Color(Color("2c2d3d"), 0.06)
	var list := []
	for s in [-1.0, 1.0]:
		var open := 1.0
		var ws := 1.0
		var pr := 1.0
		var px := 0.0
		var py := 0.0
		match look:
			"wide":
				ws = 1.3
				pr = 0.62
			"cross":
				px = -s * 0.5
				pr = 0.9
			"sleepy":
				open = 0.42
				py = -0.25
			"blink":
				open = 0.12
		var pivot := Transform3D(Basis.from_euler(Vector3(-0.1, s * 0.33, 0), EULER_ORDER_YXZ), Vector3.ZERO)
		var ball := pivot * DahroojLooks.xf(Vector3(0, 0, 1.0 - ER * 0.2))
		list.append([eye, ball * DahroojLooks.xf(Vector3.ZERO, Vector3.ZERO, Vector3(ER * ws, ER * 1.12 * ws * open, ER * 0.55)), white])
		if look == "blink":
			continue
		var pupil := ball * DahroojLooks.xf(Vector3(px * ER, py * ER, ER * 0.42 * ws))
		if look.begins_with("dizzy"):
			# A swirl of dots instead of the pupil (two meshes, half a turn apart, alternate).
			var a0 := 0.0 if look == "dizzy_a" else PI
			for k in 13:
				var t := float(k) / 12.0
				var a: float = a0 + s * t * TAU * 1.6
				var rr := ER * (0.08 + 0.62 * t)
				list.append([dot, pupil * DahroojLooks.xf(Vector3(cos(a) * rr, sin(a) * rr, 0.02 * ER), Vector3.ZERO, Vector3.ONE * ER * (0.1 + 0.03 * t)), ink])
			continue
		list.append([eye, pupil * DahroojLooks.xf(Vector3.ZERO, Vector3.ZERO, Vector3(ER * 0.55 * pr, ER * 0.55 * pr * (0.7 if look == "sleepy" else 1.0), ER * 0.22)), ink])
		list.append([dot, pupil * DahroojLooks.xf(Vector3(-ER * 0.2 * pr, ER * 0.22 * pr, ER * 0.2), Vector3.ZERO, Vector3.ONE * ER * 0.15), Color(1, 1, 1, 1)])
	var mesh := DahroojLooks.merge(list)
	_cache[key] = mesh
	return mesh


## The flat unit disc for stains (XZ plane, +Y up).
static func disc_mesh() -> ArrayMesh:
	if not _cache.has("disc"):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var seg := 28
		for i in seg:
			var a0 := TAU * i / seg
			var a1 := TAU * (i + 1) / seg
			for p in [Vector3.ZERO, Vector3(cos(a1), 0, sin(a1)), Vector3(cos(a0), 0, sin(a0))]:
				st.set_normal(Vector3.UP)
				st.set_color(Color.WHITE)
				st.add_vertex(p)
		_cache["disc"] = st.commit()
	return _cache["disc"]


## The target: rings round a bullseye (radius RINGS[-1]), facing +Z, thin ink lines between.
static func target_mesh() -> ArrayMesh:
	if _cache.has("target"):
		return _cache["target"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 64
	var ink := Color("2c2d3d")
	var bands := []  # [r0, r1, colour]
	var r0 := 0.0
	for i in RINGS.size():
		var r1: float = RINGS[i]
		bands.append([r0, r1 - 0.045, Color(RING_COLS[i])])
		bands.append([r1 - 0.045, r1, ink])
		r0 = r1
	bands.append([r0, r0 + 0.1, Color("fff4e0")])
	for bd: Array in bands:
		var a: float = bd[0]
		var b: float = bd[1]
		var c: Color = bd[2]
		for i in seg:
			var t0 := TAU * i / seg
			var t1 := TAU * (i + 1) / seg
			var p := [Vector3(cos(t0) * a, sin(t0) * a, 0), Vector3(cos(t1) * a, sin(t1) * a, 0),
				Vector3(cos(t1) * b, sin(t1) * b, 0), Vector3(cos(t0) * b, sin(t0) * b, 0)]
			for k in [0, 2, 1, 0, 3, 2]:
				st.set_normal(Vector3.BACK)
				st.set_color(c)
				st.add_vertex(p[k])
	var mesh := st.commit()
	_cache["target"] = mesh
	return mesh


## The goo frosting along the top of the wall: a lumpy rope with drips hanging off it.
static func frosting_mesh() -> ArrayMesh:
	if _cache.has("frost"):
		return _cache["frost"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var ball := DahroojLooks.sphere(1.0, 12, 8)
	var white := Color.WHITE
	var list := []
	var n := 26
	for i in n + 1:
		var x := -WALL.x / 2.0 + WALL.x * i / n
		var r := rng.randf_range(0.2, 0.3)
		list.append([ball, DahroojLooks.xf(Vector3(x, rng.randf_range(-0.04, 0.05), 0.0), Vector3.ZERO, Vector3(r * 1.5, r, r * 0.9)), white])
		if i % 2 == 1 or rng.randf() < 0.3:
			var ln := rng.randf_range(0.25, 1.1)
			var w := rng.randf_range(0.07, 0.11)
			list.append([ball, DahroojLooks.xf(Vector3(x, -ln / 2.0, 0.05), Vector3.ZERO, Vector3(w, ln / 2.0 + 0.1, w * 0.8)), white])
			list.append([ball, DahroojLooks.xf(Vector3(x, -ln - 0.02, 0.06), Vector3.ZERO, Vector3.ONE * w * 1.55), white])
	var mesh := DahroojLooks.merge(list)
	_cache["frost"] = mesh
	return mesh


func _multi(id: String, mesh: Mesh, mat: Material, cap: int, colors: bool, custom: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.use_custom_data = custom
	mm.mesh = mesh
	mm.instance_count = cap
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.name = id
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-60, -20, -60), Vector3(120, 60, 120))
	add_child(mi)
	_parts[id] = mm


func _build_parts() -> void:
	_multi("stain", disc_mesh(), _mat("stain"), SLOTS, true, false)
	_multi("body", DahroojLooks.body_mesh(1.0, 32, 22), _mat("body"), SLOTS, true, true)
	for e in EYES:
		_multi("eyes_" + e, eye_mesh(e), _mat("eyes"), SLOTS, false, true)
	for f in FACES:
		_multi("face_" + f, DahroojView._cap_mesh(1.006), _mat("face_" + f), SLOTS, false, true)
	_multi("goo", DahroojLooks.body_mesh(1.0, 12, 8), _mat("goo"), GOO_MAX, true, false)
	_multi("stars", MoleStage.star_mesh(), _mat("star"), STARS_MAX, true, false)


func _build_board() -> void:
	board = Node3D.new()
	board.name = "GooWall"
	board.position = Vector3(0, 0, WALL_Z)
	add_child(board)
	var panel := StageArt.rbox(WALL.x, WALL.y, WALL_D, 0.12, _mat("wall"))
	panel.name = "Panel"
	panel.position = Vector3(0, WALL.y / 2.0, -WALL_D / 2.0)
	board.add_child(panel)
	var ring := MeshInstance3D.new()
	ring.name = "Target"
	ring.mesh = target_mesh()
	ring.material_override = _mat("target")
	ring.position = Vector3(0, TARGET_Y, 0.006)
	board.add_child(ring)
	var frost := MeshInstance3D.new()
	frost.name = "Frosting"
	frost.mesh = frosting_mesh()
	frost.material_override = _mat("frost")
	frost.position = Vector3(0, WALL.y - 0.05, 0.02)
	board.add_child(frost)
	# The points on the rings, small, at the top of each band.
	for i in RINGS.size():
		var r_in: float = 0.0 if i == 0 else RINGS[i - 1]
		var l := Panel3D.label(str(RING_PTS[i]), 64, Color("2c2d3d") if i != 3 else Color("fff4e0"))
		l.pixel_size = 0.0045
		l.position = Vector3(0, TARGET_Y + (r_in + float(RINGS[i])) / 2.0 - (0.0 if i > 0 else 0.0), 0.02)
		l.render_priority = 1
		board.add_child(l)
		if i == 0:
			l.position.y = TARGET_Y


# ---- ctx ----

func _sfx(n: String, k: float, p: Vector3) -> void:
	if ctx:
		ctx.sfx.call(n, k, p)


func _toast(ar: String, en: String) -> void:
	if ctx:
		ctx.toast.call(ctx.t(ar, en))


func _celebrate(at: Vector3, k := 1.0) -> void:
	if ctx:
		ctx.confetti.call(at, 1.2 * k, 1.4, maxf(1.0, at.distance_to(viewer) / 7.0))


# ---- surfaces ----

## The room's planes (refreshed every half second); [] in VR or an unscanned room.
func _refresh_planes() -> void:
	planes = []
	if planes_provider.is_valid():
		var p = planes_provider.call()
		if p is Array:
			planes = p
	var room := not planes.is_empty()
	board.visible = not room
	if not room:
		target = {"pos": Vector3(0, TARGET_Y, WALL_Z), "normal": Vector3.BACK, "ax": Vector3.RIGHT, "ay": Vector3.UP, "on": true}
		room_target.visible = false
		return
	# The target goes on the wall that faces you best (big enough for it).
	var best := -INF
	var pick := {}
	var rt: float = RINGS[RINGS.size() - 1] + 0.1
	for pl: Dictionary in planes:
		var n: Vector3 = pl.normal
		var half: Vector2 = pl.half
		if absf(n.y) > 0.3 or half.x < rt or half.y < rt:
			continue
		var to: Vector3 = viewer - (pl.pos as Vector3)
		var sc := n.dot(to.normalized()) - to.length() * 0.01
		if sc > best:
			best = sc
			pick = pl
	if pick.is_empty():
		target.on = false
		room_target.visible = false
		return
	var ay: Vector3 = pick.ay
	var c: Vector3 = pick.pos
	var hh: float = (pick.half as Vector2).y
	# Its centre at about chest height when the wall allows.
	var v := clampf((viewer.y * 0.8 - c.y) / ay.y, -hh + rt, hh - rt) if absf(ay.y) > 0.3 else 0.0
	var pos: Vector3 = c + ay * v + (pick.normal as Vector3) * 0.01
	var n2: Vector3 = pick.normal
	var up := (Vector3.UP - n2 * n2.y).normalized()
	target = {"pos": pos, "normal": n2, "ax": up.cross(n2), "ay": up, "on": true}
	room_target.transform = Transform3D(Basis(up.cross(n2), up, n2), pos)
	room_target.visible = true


## Which ring a point on the target's plane lands in: 0 = bullseye .. 3, -1 = outside.
func ring_of(p: Vector3) -> int:
	if not target.on:
		return -1
	var d := p - (target.pos as Vector3)
	if absf(d.dot(target.normal)) > R:
		return -1
	var r := (d - (target.normal as Vector3) * d.dot(target.normal)).length()
	for i in RINGS.size():
		if r <= float(RINGS[i]):
			return i
	return -1


# ---- the blobs ----

## The height of a blob (× its fresh height) at melt m; hang: 0 (floor, wall) .. 1 (hanging
## from a ceiling), as the shader's slime_shape.
static func hy_of(m: float, hang := 0.0) -> float:
	return lerpf(lerpf(1.0, HY_MIN, m), 1.0 + HANG_K * m, hang)


## How much a blob stuck along n hangs (gravity pulling out of the surface): the shader's rule.
static func hang_of(n: Vector3) -> float:
	return clampf((-n.y - 0.3) / 0.6, 0.0, 1.0)


## A stuck frame: +Y along n, +Z up the wall (or toward `toward` on the ground).
static func stick_basis(n: Vector3, toward: Vector3) -> Basis:
	var z: Vector3
	if absf(n.y) < 0.95:
		z = (Vector3.UP - n * n.y).normalized()
	else:
		z = toward - n * toward.dot(n)
		z = z.normalized() if z.length_squared() > 1e-6 else Vector3.BACK
	return Basis(n.cross(z), n, z)


func _reaction(speed: float) -> String:
	if speed < SPEEDS[0]:
		return "wide"
	if speed < SPEEDS[1]:
		return "cross"
	if speed < SPEEDS[2]:
		return "shut"
	return "dizzy"


func _live_count() -> int:
	var n := 0
	for b: Dictionary in blobs:
		if b.dying < 0.0:
			n += 1
	return n


func _has_live_child(b: Dictionary) -> bool:
	for c: Dictionary in blobs:
		if c.parent == b.id and c.dying < 0.0:
			return true
	return false


## Keeps room for one more: the oldest blob nothing sticks to dissolves.
func _make_room() -> void:
	while _live_count() >= CAP:
		var done := false
		for b: Dictionary in blobs:
			if b.dying < 0.0 and not _has_live_child(b):
				_dissolve(b)
				done = true
				break
		if not done:
			return


## A Dahrooj sticks: at p (on the surface), n out of it, coming in with vin; parent: the
## blob he landed on (or {}). kind: "floor" | "wall" | "room" | "blob". Returns the blob.
func stick(p: Vector3, n: Vector3, vin: Vector3, kind: String, parent := {}, color := "") -> Dictionary:
	_make_room()
	var speed := vin.length()
	var k := clampf(speed / 18.0, 0.0, 1.0)
	n = n.normalized()
	var rb := stick_basis(n, viewer - p)
	var vt := vin - n * vin.dot(n)
	var vtl := rb.transposed() * vt
	var look := viewer - p
	look = look.normalized() if look.length_squared() > 1e-6 else n
	var dn := look.dot(n)
	if dn < 0.35:
		look = (look + n * (0.35 - dn)).normalized()
	var cid: String = color if color != "" else COLORS[_rng.randi() % COLORS.size()]
	var b := {"id": _next_id, "dying": -1.0, "dkind": "", "pop_delay": -1.0, "t": 0.0, "kind": kind,
		"color": cid, "tint": DahroojLooks.tint("jelly", cid), "p0": p, "n": n, "basis": rb,
		"parent": 0, "level": 1, "rel_h": 0.0, "rel_t": Vector3.ZERO,
		"m0": 0.12 + 0.28 * k, "m_max": 1.0, "m": 0.12 + 0.28 * k, "j": 0.35 + 0.5 * k, "jv": 0.0,
		"sway": Vector3.ZERO, "swayv": Vector3.ZERO, "smear_a": atan2(vtl.z, vtl.x), "smear": 1.0 + 0.5 * clampf(vt.length() / 12.0, 0.0, 1.0),
		"look": look, "speed": speed, "react": _reaction(speed), "react_t": 0.0, "next_react": "",
		"blink": 0.0, "blink_t": _rng.randf_range(1.5, 3.0), "slide": 0.0, "drips": [],
		"anchor": p, "H": 2.0 * R, "S": R, "c": p + n * R, "rc": R, "ring": -1, "pts": 0,
		"hang": hang_of(n), "ceil": false}
	_next_id += 1
	b.react_t = REACT_T[b.react]
	if b.react == "dizzy":
		# Very hard: squeezed shut first, then the swirl.
		b.react = "shut"
		b.react_t = 0.45
		b.next_react = "dizzy"
	if not parent.is_empty():
		b.parent = parent.id
		b.level = int(parent.level) + 1
		b.m_max = STACK_MELT
		b.m0 = minf(b.m0, 0.2)
		b.m = b.m0
		var d: Vector3 = p - (parent.anchor as Vector3)
		var pn: Vector3 = parent.n
		b.rel_h = d.dot(pn) / maxf(float(parent.H), 1e-3)
		b.rel_t = (d - pn * d.dot(pn)) / maxf(float(parent.S), 1e-3)
		# The pile feels it: a squash and a sway down the chain.
		var push := vt * 0.05
		var q: Dictionary = parent
		var f := 1.0
		while not q.is_empty():
			q.j = float(q.j) + 0.22 * f
			q.swayv = (q.swayv as Vector3) + push * f
			f *= 0.6
			q = _by_id.get(int(q.parent), {})
	elif absf(n.y) < 0.6:
		# On a wall: a few drips run down from the lower rim.
		for i in _rng.randi_range(1, 3):
			b.drips.append({"u": _rng.randf_range(-0.55, 0.55), "len": 0.0, "max": _rng.randf_range(0.5, 1.7) * R,
				"v": _rng.randf_range(0.12, 0.3) * R, "w": _rng.randf_range(0.11, 0.17) * R, "delay": _rng.randf_range(0.4, 1.8)})
	elif n.y < -0.6:
		# On a ceiling: goo strands grow from the hanging tip and drop off, falling to the floor.
		b.ceil = true
		for i in _rng.randi_range(1, 2):
			b.drips.append({"u": _rng.randf_range(-0.5, 0.5), "len": 0.0, "max": _rng.randf_range(0.35, 0.8) * R,
				"v": _rng.randf_range(0.35, 0.6) * R, "w": _rng.randf_range(0.1, 0.15) * R, "delay": _rng.randf_range(0.6, 1.6),
				"left": CEIL_DRIPS})
	blobs.append(b)
	_by_id[b.id] = b
	_pose(b)
	F.stuck += 1
	_splash(b, vin, k)
	_score(b)
	return b


func _splash(b: Dictionary, vin: Vector3, k: float) -> void:
	var p: Vector3 = b.anchor
	var n: Vector3 = b.n
	_sfx("splash", clampf(0.35 + 0.65 * k, 0.25, 1.0), p)
	_sfx("thump", clampf(0.25 + 0.6 * k, 0.25, 1.0), p)
	var pitch := {"wide": 1.35, "cross": 1.15, "shut": 0.85, "dizzy": 0.7}
	_sfx("squeak", float(pitch.get(b.react, 1.0)), p)
	var rb: Basis = b.basis
	var vt := vin - n * vin.dot(n)
	for i in int(6 + 10 * k):
		var a := _rng.randf() * TAU
		var out := rb.x * cos(a) + rb.z * sin(a)
		var v := out * _rng.randf_range(1.2, 3.6) * (0.6 + k) + n * _rng.randf_range(1.5, 4.5) * (0.5 + k) + vt * _rng.randf_range(0.05, 0.3)
		_drop(p + n * R * 0.4 + out * R * 0.5, v, b.tint, _rng.randf_range(0.05, 0.11) * (0.8 + 0.4 * k))


func _drop(p: Vector3, v: Vector3, c: Color, s: float) -> void:
	if drops.size() >= DROPS_MAX:
		drops.pop_front()
	drops.append({"p": p, "prev": p, "v": v, "c": c, "s": s, "t": 0.0, "life": _rng.randf_range(1.4, 2.4), "stuck": false, "n": Vector3.UP})


func _score(b: Dictionary) -> void:
	var pts := 0
	if b.parent == 0:
		b.ring = ring_of(b.anchor)
		if int(b.ring) >= 0:
			pts += int(RING_PTS[b.ring])
	else:
		pts += STACK_PTS * (int(b.level) - 1)
		F.tower = maxi(F.tower, int(b.level))
		if ctx:
			ctx.ch_progress.call("slime5", int(b.level))
		if int(b.level) > F.best_tower:
			F.best_tower = int(b.level)
			if b.level >= 3:
				_toast("برج سلايم ×%s!" % GameCtx.ar_digits(b.level), "Slime tower ×%d!" % b.level)
		if int(b.level) >= TOWER and int(b.level) == F.best_tower:
			_sfx("chime", 1.0, b.anchor)
			_celebrate((b.anchor as Vector3) + Vector3.UP * R * 2.0)
	b.pts = pts
	if pts <= 0:
		return
	F.score += pts
	if ctx:
		ctx.counts["slime"] = int(ctx.counts.get("slime", 0)) + pts
	if int(b.ring) == 0:
		_sfx("chime", 0.8, b.anchor)
		_toast("في المنتصف! +١٠", "Bullseye! +10")
		_celebrate(b.anchor, 0.7)


func _dissolve(b: Dictionary) -> void:
	if b.dying >= 0.0:
		return
	b.dying = 0.0
	b.dkind = "fade"


## A blob pops (a shot): a burst of goo; whatever is stacked on it pops a moment later.
func pop(b: Dictionary) -> void:
	if b.dying >= 0.0 and b.dkind == "pop":
		return
	b.dying = 0.0
	b.dkind = "pop"
	b.pop_delay = -1.0
	var c: Vector3 = b.c
	_sfx("start_pop", 1.0, c)
	_sfx("splash", 0.6, c)
	for i in 18:
		var d := Vector3(_rng.randf() - 0.5, _rng.randf() - 0.5, _rng.randf() - 0.5).normalized()
		d = (d + (b.n as Vector3) * 0.8).normalized()
		_drop(c + d * float(b.rc) * 0.6, d * _rng.randf_range(2.0, 5.0), b.tint if i % 4 else Color("fffaf2"), _rng.randf_range(0.05, 0.12))
	F.popped += 1
	if ctx:
		ctx.ch_progress.call("pop20", int(ctx.ch_state.get("pop20", 0)) + 1)
	for ch: Dictionary in blobs:
		if ch.parent == b.id and ch.dying < 0.0 and ch.pop_delay < 0.0:
			ch.pop_delay = 0.09


## Where a blob is now (its parent first): anchor, height H, spread S, the collision sphere.
func _pose(b: Dictionary) -> void:
	var m: float = b.m
	var hang: float = b.hang
	var hy := hy_of(m, hang)
	var n: Vector3 = b.n
	var anchor: Vector3
	var par: Dictionary = _by_id.get(int(b.parent), {}) if b.parent != 0 else {}
	if not par.is_empty():
		var pn: Vector3 = par.n
		anchor = (par.anchor as Vector3) + pn * float(b.rel_h) * float(par.H) + (b.rel_t as Vector3) * float(par.S)
	else:
		var g := Vector3.DOWN - n * (-n.y)
		anchor = (b.p0 as Vector3) + (g.normalized() * float(b.slide) if g.length_squared() > 1e-4 else Vector3.ZERO)
	anchor += b.sway
	var sy := clampf(1.0 - 0.35 * float(b.j), 0.55, 1.4)
	var H := R * (2.0 * hy + TIP_K * m * hang) * sy
	var S := R / sqrt(hy) * (1.0 + SKIRT * m * 0.5 * (1.0 - 0.5 * hang))
	var rc := maxf(H * 0.5, S * 0.9)
	b.anchor = anchor
	b.H = H
	b.S = S
	b.rc = rc
	b.c = anchor + n * (H - rc)


## The instance transform: the stuck frame, squashed by the wobble (along n), smeared the way
## he came in, at the anchor.
func blob_xform(b: Dictionary) -> Transform3D:
	var rb: Basis = b.basis
	var sy := clampf(1.0 - 0.35 * float(b.j), 0.55, 1.4)
	var sx := 1.0 / sqrt(sy)
	var a: float = b.smear_a
	var sm: float = b.smear
	var e1 := Vector3(cos(a), 0, sin(a))
	var e2 := Vector3(-sin(a), 0, cos(a))
	var A := func(v: Vector3) -> Vector3: return e1 * (sx * sm * e1.dot(v)) + Vector3.UP * (sy * v.y) + e2 * (sx / sqrt(sm) * e2.dot(v))
	var la := Basis(A.call(Vector3.RIGHT), A.call(Vector3.UP), A.call(Vector3.BACK))
	var k := 1.0
	if b.dying >= 0.0:
		var u: float = b.dying
		k = (1.0 + 0.5 * sin(minf(u / 0.16, 1.0) * PI)) * (0.0 if u >= 0.16 else 1.0) if b.dkind == "pop" else maxf(0.0, 1.0 - u / 0.7)
	return Transform3D(rb * la * Basis.from_scale(Vector3.ONE * R * maxf(0.001, k)), b.anchor)


## The face direction in the stuck frame (x, z; y >= 0 is implied): toward the viewer, turning
## up out of the surface as he melts.
func face_dir(b: Dictionary) -> Vector2:
	var n: Vector3 = b.n
	var f := ((b.look as Vector3) + n * float(b.m) * 0.9).normalized()
	var fl := (b.basis as Basis).transposed() * f
	if fl.y < 0.05:
		fl.y = 0.05
		fl = fl.normalized()
	return Vector2(fl.x, fl.z)


## [eyes ("" for none), face] for the moment.
func looks(b: Dictionary) -> Array:
	if b.dying >= 0.0:
		return ["wide", "wide"]
	if float(b.react_t) > 0.0:
		match b.react:
			"wide":
				return ["wide", "wide"]
			"cross":
				return ["cross", "open"]
			"shut":
				return ["", "closed"]
			"dizzy":
				return ["dizzy_a" if fmod(time, 0.16) < 0.08 else "dizzy_b", "wide"]
	var blink: bool = float(b.blink) > 0.0
	if float(b.m) > 0.62:
		return ["blink" if blink else "sleepy", "joy"]
	return ["blink" if blink else "open", "joy"]


func _step_blob(b: Dictionary, dt: float) -> bool:
	b.t = float(b.t) + dt
	if b.pop_delay >= 0.0:
		b.pop_delay = float(b.pop_delay) - dt
		if b.pop_delay < 0.0:
			pop(b)
	if b.dying >= 0.0:
		b.dying = float(b.dying) + dt
		if (b.dkind == "pop" and b.dying >= 0.16) or b.dying >= 0.7:
			return false
		if b.dkind == "fade":
			b.m = minf(1.0, float(b.m) + dt * 1.2)
	else:
		var mm: float = b.m_max
		b.m = mm - (mm - float(b.m0)) * exp(-float(b.t) / MELT_T)
	# The jelly wobbles and settles; the pile sways back.
	b.jv = float(b.jv) + (-float(b.j) * 140.0 - float(b.jv) * 5.5) * dt
	b.j = clampf(float(b.j) + float(b.jv) * dt, -0.8, 1.2)
	var n: Vector3 = b.n
	var sw: Vector3 = b.sway
	var swv: Vector3 = b.swayv
	swv += (-sw * 55.0 - swv * 3.2) * dt
	sw += swv * dt
	sw -= n * sw.dot(n)
	b.sway = sw
	b.swayv = swv
	# On a wall he slides down a little as he melts.
	if b.parent == 0:
		var steep := 1.0 - absf(n.y)
		b.slide = 0.55 * R * steep * float(b.m) * float(b.m)
	for d: Dictionary in b.drips:
		if float(d.delay) > 0.0:
			d.delay = float(d.delay) - dt
		elif b.ceil:
			if int(d.left) <= 0 or b.dying >= 0.0:
				continue
			# A strand grows from the hanging tip; when it's long enough its drop falls off.
			d.len = float(d.len) + float(d.v) * dt
			if float(d.len) >= float(d.max):
				var tip := ceil_drip_root(b, d) + n * float(d.len)
				_drop(tip, n * 0.4 + Vector3(_rng.randf_range(-0.1, 0.1), 0, _rng.randf_range(-0.1, 0.1)), b.tint, float(d.w) * 1.5)
				F.dripped += 1
				d.left = int(d.left) - 1
				d.len = 0.0
				d.max = _rng.randf_range(0.35, 0.8) * R
				d.delay = _rng.randf_range(0.8, 2.2)
		else:
			d.len = minf(float(d.max), float(d.len) + float(d.v) * dt * (1.0 - float(d.len) / float(d.max) * 0.7))
	# Faces: the reaction, then slow blinks.
	if float(b.react_t) > 0.0:
		b.react_t = float(b.react_t) - dt
		if b.react_t <= 0.0 and b.next_react != "":
			b.react = b.next_react
			b.react_t = REACT_T[b.react]
			b.next_react = ""
	b.blink_t = float(b.blink_t) - dt
	if b.blink_t <= 0.0:
		var sleepy: bool = float(b.m) > 0.62
		b.blink = 0.5 if sleepy else 0.2
		b.blink_t = _rng.randf_range(3.0, 5.5) if sleepy else _rng.randf_range(1.8, 3.8)
	b.blink = maxf(0.0, float(b.blink) - dt)
	return true


func _step_drops(dt: float) -> void:
	for i in range(drops.size() - 1, -1, -1):
		var d: Dictionary = drops[i]
		d.t = float(d.t) + dt
		if d.t > d.life:
			drops.remove_at(i)
			continue
		if d.stuck:
			# Stuck on a wall it creeps down.
			var n: Vector3 = d.n
			var g := Vector3.DOWN - n * (-n.y)
			d.p = (d.p as Vector3) + g * 0.04 * dt
			continue
		d.prev = d.p
		d.v = (d.v as Vector3) + Vector3.DOWN * Ball.GRAV * dt
		d.p = (d.p as Vector3) + (d.v as Vector3) * dt
		var p: Vector3 = d.p
		var s: float = d.s
		if p.y < s * 0.3:
			_land(d, Vector3(p.x, 0.0, p.z), Vector3.UP)
			continue
		if board.visible and p.z < WALL_Z + s * 0.3 and (d.prev as Vector3).z >= WALL_Z and absf(p.x) <= WALL.x / 2.0 and p.y <= WALL.y:
			_land(d, Vector3(p.x, p.y, WALL_Z), Vector3.BACK)
			continue
		for pl: Dictionary in planes:
			var hit := _plane_cross(pl, d.prev, p, s * 0.3)
			if not hit.is_empty():
				_land(d, hit.p, pl.normal)
				break


func _land(d: Dictionary, p: Vector3, n: Vector3) -> void:
	d.stuck = true
	d.p = p + n * 0.01
	d.n = n
	d.t = maxf(0.0, float(d.life) - _rng.randf_range(1.0, 2.0))


## Where a ceiling drip hangs from: the blob's tip, a little to the side.
func ceil_drip_root(b: Dictionary, d: Dictionary) -> Vector3:
	var rb: Basis = b.basis
	return (b.anchor as Vector3) + (b.n as Vector3) * float(b.H) * 0.94 + rb.x * float(d.u) * float(b.S) * 0.3


## A point moving from a to b crossing the plane (from its front, within r): {p} or {}.
static func _plane_cross(pl: Dictionary, a: Vector3, b: Vector3, r: float) -> Dictionary:
	var n: Vector3 = pl.normal
	var c: Vector3 = pl.pos
	var db := (b - c).dot(n)
	var da := (a - c).dot(n)
	if db >= r or da < db or da < -r:
		return {}
	var q := b - n * db
	var half: Vector2 = pl.half
	var u := (q - c).dot(pl.ax)
	var v := (q - c).dot(pl.ay)
	if absf(u) > half.x + r or absf(v) > half.y + r:
		return {}
	return {"p": c + (pl.ax as Vector3) * clampf(u, -half.x, half.x) + (pl.ay as Vector3) * clampf(v, -half.y, half.y)}


# ---- drawing ----

func _process(_delta: float) -> void:
	if is_visible_in_tree():
		draw()


## Draws the blobs, their faces, stains, drips, droplets and stars; moves the hit spheres.
func draw() -> void:
	var counts := {}
	for id in _parts:
		counts[id] = 0
	var put := func(id: String, xf: Transform3D, col, custom) -> void:
		var mm: MultiMesh = _parts[id]
		var i: int = counts[id]
		if i >= mm.instance_count:
			return
		mm.set_instance_transform(i, xf)
		if col != null:
			mm.set_instance_color(i, col)
		if custom != null:
			mm.set_instance_custom_data(i, custom)
		counts[id] = i + 1
	var np := 0
	for b: Dictionary in blobs:
		var xf := blob_xform(b)
		var fd := face_dir(b)
		var custom := Color(fd.x, fd.y, float(b.m), clampf(float(b.j), -1.0, 1.0) * 0.8)
		var tint: Color = b.tint
		put.call("body", xf, tint.srgb_to_linear(), custom)
		var lk := looks(b)
		if lk[0] != "":
			put.call("eyes_" + lk[0], xf, null, custom)
		put.call("face_" + lk[1], xf, null, custom)
		var n: Vector3 = b.n
		var rb: Basis = b.basis
		var alive: bool = b.dying < 0.0
		var fade := 1.0 if alive else maxf(0.0, 1.0 - float(b.dying) / 0.5)
		# The wet stain round the foot (stretched down a wall as it sags).
		if b.parent == 0:
			var sr := float(b.S) * (1.05 + 0.5 * float(b.m))
			var g := rb.transposed() * Vector3.DOWN
			var sag := Vector2(g.x, g.z).length() * float(b.m) * SAG * R
			var st := Transform3D(rb * Basis.from_scale(Vector3(sr, 1.0, sr + sag * 0.6)), (b.anchor as Vector3) + n * 0.012 - rb.z * sag * 0.3)
			var sc := tint.darkened(0.25).srgb_to_linear()
			sc.a = 0.5 * fade
			put.call("stain", st, sc, null)
		# Drips: a thin trail and a bulb at its end.
		if alive and b.ceil:
			for d: Dictionary in b.drips:
				var ln: float = d.len
				if ln <= 0.01:
					continue
				var root := ceil_drip_root(b, d)
				var w: float = d.w
				var lc := tint.srgb_to_linear()
				put.call("goo", Transform3D(Basis(rb.x * w, n * (ln * 0.5 + w), rb.z * w * 0.7), root + n * ln * 0.5), lc, null)
				put.call("goo", Transform3D(rb * Basis.from_scale(Vector3(w * 1.5, w * 1.9, w * 1.5)), root + n * ln), lc, null)
		elif alive and not (b.drips as Array).is_empty():
			var down := -rb.z
			var side := rb.x
			for d: Dictionary in b.drips:
				var ln: float = d.len
				if ln <= 0.01:
					continue
				var rim: Vector3 = (b.anchor as Vector3) + down * (float(b.S) * 0.7 + float(b.m) * SAG * R * 0.5) + side * float(d.u) * float(b.S) + n * R * 0.1
				var w: float = d.w
				var lc := tint.srgb_to_linear()
				put.call("goo", Transform3D(Basis(side * w, down * (ln * 0.5 + w), n * w * 0.7), rim + down * ln * 0.5), lc, null)
				put.call("goo", Transform3D(rb * Basis.from_scale(Vector3(w * 1.6, w * 1.9, w * 1.3)), rim + down * ln + n * w * 0.3), lc, null)
		# Stars over a hard hit.
		if alive and float(b.react_t) > 0.0 and (b.react == "shut" or b.react == "dizzy"):
			var top: Vector3 = (b.anchor as Vector3) + n * (float(b.H) + R * 0.35)
			for s in 3:
				var a: float = time * 7.0 + TAU * s / 3.0
				var p := top + (rb.x * cos(a) + rb.z * sin(a)) * R * 0.85
				var to := viewer - p
				var bb := Basis.looking_at(to.normalized(), Vector3.UP, true) if to.length_squared() > 1e-6 and absf(to.normalized().y) < 0.99 else Basis.IDENTITY
				put.call("stars", Transform3D(bb * Basis(Vector3.BACK, time * 5.0 + s) * Basis.from_scale(Vector3.ONE * R * 0.32), p), Color("ffd23f").srgb_to_linear(), null)
		if alive and np < _proxies.size():
			var proxy: MeshInstance3D = _proxies[np]
			proxy.visible = true
			proxy.transform = Transform3D(Basis.from_scale(Vector3.ONE * float(b.rc)), b.c)
			proxy.set_meta("blob", b.id)
			np += 1
	for i in range(np, _proxies.size()):
		(_proxies[i] as MeshInstance3D).visible = false
	for d: Dictionary in drops:
		var k: float = 1.0 - maxf(0.0, (float(d.t) - float(d.life) + 0.4) / 0.4)
		var s: float = d.s * maxf(0.01, k)
		var lc := (d.c as Color).srgb_to_linear()
		if d.stuck:
			var dn: Vector3 = d.n
			var bb := stick_basis(dn, Vector3.BACK)
			put.call("goo", Transform3D(bb * Basis.from_scale(Vector3(s * 1.5, s * 0.35, s * 1.5)), d.p), lc, null)
		else:
			var v: Vector3 = d.v
			var st := clampf(v.length() * 0.04, 0.0, 0.8)
			var bb := Basis.looking_at(v.normalized(), Vector3.UP if absf(v.normalized().y) < 0.99 else Vector3.BACK) if v.length_squared() > 1e-4 else Basis.IDENTITY
			put.call("goo", Transform3D(bb * Basis.from_scale(Vector3(s, s, s * (1.0 + st))), d.p), lc, null)
	for id in _parts:
		(_parts[id] as MultiMesh).visible_instance_count = counts[id]


# ---- stage interface ----

## The goo wall is solid (a resting ball too). Returns {hit, p, v, n}.
func collide_body(p: Vector3, v: Vector3, r: float, previous: Vector3) -> Dictionary:
	if not board.visible:
		return {"hit": false, "p": p, "v": v, "n": Vector3.ZERO}
	return FairStage.collide_solid_box(p, v, r, previous, Vector3(0, WALL.y / 2.0, WALL_Z - WALL_D / 2.0), Vector3(WALL.x / 2.0, WALL.y / 2.0, WALL_D / 2.0))


func collide(S: Ball) -> void:
	if not S.shot or S.held or S.wet:
		return
	var id := S.shot_id
	if id in _gone_shots:
		return
	var vin: Vector3 = _vin.get(id, S.vel)
	_vin[id] = S.vel
	var hit := {}
	# Another Dahrooj (a pile).
	var best := INF
	for b: Dictionary in blobs:
		if b.dying >= 0.0:
			continue
		var c: Vector3 = b.c
		var d := S.pos.distance_to(c)
		if d < Ball.BR + float(b.rc) and d < best:
			best = d
			var nn := (S.pos - c).normalized() if d > 1e-5 else (b.n as Vector3)
			hit = {"p": c + nn * float(b.rc), "n": nn, "kind": "blob", "parent": b}
	# The goo wall.
	if hit.is_empty() and board.visible and S.pos.z - Ball.BR < WALL_Z and S.pos.z > WALL_Z - WALL_D - Ball.BR \
			and S.prev.z - Ball.BR >= WALL_Z - 0.05 and absf(S.pos.x) <= WALL.x / 2.0 and S.pos.y <= WALL.y + Ball.BR * 0.5:
		hit = {"p": Vector3(S.pos.x, minf(S.pos.y, WALL.y), WALL_Z), "n": Vector3.BACK, "kind": "wall", "parent": {}}
	# The room's walls and furniture.
	if hit.is_empty():
		for pl: Dictionary in planes:
			var h := _plane_cross(pl, S.prev, S.pos, Ball.BR)
			if not h.is_empty():
				hit = {"p": h.p, "n": pl.normal, "kind": "room", "parent": {}}
				break
	# The ground.
	if hit.is_empty() and S.pos.y <= Ball.BR + 1e-3:
		hit = {"p": Vector3(S.pos.x, 0.0, S.pos.z), "n": Vector3.UP, "kind": "floor", "parent": {}}
	if hit.is_empty():
		return
	var v_in := vin if vin.length_squared() > S.vel.length_squared() else S.vel
	var b := stick(hit.p, hit.n, v_in, hit.kind, hit.parent, String(_shot_colors.get(id, next_color)))
	_vin.erase(id)
	_shot_colors.erase(id)
	var volley := false
	for v: Dictionary in S.volley:
		if int(v.shot_id) == id:
			volley = true
	if volley:
		# An earlier throw of the volley: out of the volley at the next step.
		_gone_shots.append(id)
		S.vel = Vector3.ZERO
		S.pos = b.c
		if int(b.ring) == 0:
			_celebrate(b.anchor, 0.8)
		return
	if int(b.ring) == 0:
		S.success()
	S.respawn()


func shoot(obj: Node, _point: Vector3, _dir: Vector3) -> bool:
	if not obj is MeshInstance3D or not obj.has_meta("blob"):
		return false
	var b: Dictionary = _by_id.get(int(obj.get_meta("blob")), {})
	if b.is_empty() or b.dying >= 0.0:
		return false
	pop(b)
	return true


func touched() -> bool:
	return false


func on_throw() -> void:
	if ctx and ctx.ball:
		_shot_colors[ctx.ball.shot_id] = next_color


func on_respawn() -> void:
	next_color = COLORS[_rng.randi() % COLORS.size()]


## The colour id a throw is shown in (main: the volley's balls).
func color_for(shot_id: int) -> String:
	return String(_shot_colors.get(shot_id, next_color))


func deactivate() -> void:
	blobs.clear()
	_by_id.clear()
	drops.clear()
	_vin.clear()
	_gone_shots.clear()
	F.tower = 0
	draw()


func update(b: Ball, dt: float) -> void:
	time += dt
	_planes_t -= dt
	if _planes_t <= 0.0:
		_planes_t = 0.5
		_refresh_planes()
	if not _gone_shots.is_empty():
		for i in range(b.volley.size() - 1, -1, -1):
			if int(b.volley[i].shot_id) in _gone_shots:
				b.volley.remove_at(i)
		_gone_shots.clear()
	var tower := 0
	for i in range(blobs.size() - 1, -1, -1):
		var bl: Dictionary = blobs[i]
		if not _step_blob(bl, dt):
			blobs.remove_at(i)
			_by_id.erase(bl.id)
	for bl: Dictionary in blobs:
		_pose(bl)
		if bl.dying < 0.0:
			tower = maxi(tower, int(bl.level))
	F.tower = tower
	_step_drops(dt)


# ---- for tests and main ----

func slime_state() -> Dictionary:
	return {"score": F.score, "stuck": F.stuck, "popped": F.popped, "tower": F.tower, "best_tower": F.best_tower, "live": _live_count(),
		"dripped": F.dripped}


func blob_state(b: Dictionary) -> Dictionary:
	var lk := looks(b)
	return {"id": b.id, "kind": b.kind, "m": b.m, "n": b.n, "anchor": b.anchor, "level": b.level, "react": b.react,
		"eyes": lk[0], "face": lk[1], "ring": b.ring, "pts": b.pts, "dying": b.dying >= 0.0, "H": b.H, "S": b.S, "color": b.color}
