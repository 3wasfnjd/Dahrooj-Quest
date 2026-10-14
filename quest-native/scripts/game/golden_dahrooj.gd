class_name GoldenDahrooj
extends Node3D
## The Golden Dahrooj («الدحروج الذهبي»): a rare shimmering gold Dahrooj with a crown that turns
## up now and then in the modes you play by shooting and throwing (MODES), floats about far out
## in front of you for a few seconds and escapes with a puff if nobody hits him. A shot or a
## thrown Dahrooj that reaches him catches him: main adds GameRuntime.GOLDEN_POINTS to the mode's
## score with a gold banner, confetti and haptics, and little bonus Dahroojs pop out of him.
##
## - Timing: one every EVERY seconds of active play (randomised; the clock only runs while the
##   owner says the player is playing a mode that has him), never more than one at a time; he
##   stays STAY seconds.
## - Where: the owner's spot callable gives his home (game units); spots are kept in FRONT of
##   the player like every spawn in the game (RoomSpots: within ARC_USE of the play direction,
##   at least MIN_M metres away), and his zig-zag and bobbing never take him out of that arc.
## - Hits: hit_by(p, r) tells whether a ball of radius r at p reaches him; catch(how) takes him
##   (on_caught), escape() lets him go (on_escape). WorldBalls asks for the blaster's shots
##   (target kind "g"), main for thrown Dahroojs.
## Lives under GameRoot: positions in game units; `unit` is game units per metre (main's
## scale_now), so his size and moves are the same in metres in VR and in mixed reality.

## The modes that have him: the throwing courses and the arcade modes. Not the tabletops, the
## Summit or the rain; not Whack-a-Dahrooj, whose own golden moles are its rare golden prize.
const MODES := ["goal", "hoop", "window", "cans", "bowling", "bricks", "fair",
	"invasion", "slime", "meteor", "giant", "frenzy", "castle", "gallery"]
## The throwing courses: he floats over their target (the goal, the hoop, the cans...).
const COURSES := ["goal", "hoop", "window", "cans", "bowling", "bricks", "fair"]
const EVERY := Vector2(60.0, 120.0)  # seconds of active play between two
const STAY := Vector2(6.0, 8.0)
const R_VR := 0.4  # his radius in metres (VR: far away in the park)
const R_MR := 0.15  # in your room
const MIN_M := 2.5  # metres from the player at the least (RoomSpots.MIN_DIST and a margin)
const ARC_USE := 0.96  # radians either side of the play direction (55°: his sway stays in 70°)
const SWAY := 0.35  # metres either side (zig-zag)
const BOB := 0.12  # metres up and down
const POP_T := 0.35
const PALS := 5  # the little bonus Dahroojs that pop out when he is caught
const SPARKS := 96
const SPARK_EVERY := 0.035
const GOLD := Color("ffc928")

const BODY_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;
uniform float flash = 0.0;
void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float ndv = clamp(dot(n, v), 0.0, 1.0);
	vec3 deep = vec3(0.55, 0.32, 0.04);
	vec3 gold = vec3(1.0, 0.78, 0.2);
	vec3 base = mix(deep, gold, pow(ndv, 0.55));
	vec3 wn = (INV_VIEW_MATRIX * vec4(n, 0.0)).xyz;
	float band = smoothstep(0.82, 1.0, sin(wn.y * 3.2 + wn.x * 2.1 - TIME * 3.4));
	vec3 l = normalize(vec3(0.35, 0.8, 0.5));
	float spec = pow(clamp(dot(reflect(-v, n), l), 0.0, 1.0), 28.0);
	float rim = pow(1.0 - ndv, 2.5);
	vec3 c = base + vec3(1.0, 0.96, 0.75) * (band * 0.55 + spec * 0.9) + vec3(1.0, 0.86, 0.45) * rim * 0.55;
	ALBEDO = mix(c, vec3(1.0), flash);
}
"""

const HALO_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform float strength = 1.0;
void vertex() {
	float sc = length(MODEL_MATRIX[0].xyz);
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
	vec3 up = normalize(cross(INV_VIEW_MATRIX[2].xyz, right));
	VERTEX = VERTEX * sc;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(up, 0.0), vec4(INV_VIEW_MATRIX[2].xyz, 0.0), MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);
	float a = exp(-d * d * 4.0) * (1.0 - smoothstep(0.75, 1.0, d));
	float ray = pow(abs(cos(atan(p.y, p.x) * 4.0 + TIME * 0.8)), 12.0) * (1.0 - smoothstep(0.2, 1.0, d)) * 0.5;
	// Plain alpha, not added light: it reads on a bright day and over passthrough (MR).
	ALBEDO = mix(vec3(1.0, 0.72, 0.18), vec3(1.0, 0.95, 0.7), clamp(a + ray, 0.0, 1.0));
	ALPHA = clamp((a * 0.75 + ray) * strength * (0.85 + 0.15 * sin(TIME * 7.0)), 0.0, 1.0);
}
"""

## Sparkles: stars (custom.x 0) or soft round puffs (custom.x 1), facing the viewer.
const SPARK_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
varying vec4 col;
varying float kind;
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
	kind = INSTANCE_CUSTOM.x;
	float sc = length(MODEL_MATRIX[0].xyz);
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
	vec3 fwd = normalize(cross(right, vec3(0.0, 1.0, 0.0)));
	VERTEX = VERTEX * sc;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(-fwd, 0.0), MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = (UV - 0.5) * vec2(2.0, -2.0);
	float a;
	vec3 rgb;
	if (kind < 0.5) {
		float d = star5(p, 0.82, 0.48);
		float aa = fwidth(d) + 0.01;
		float body = 1.0 - smoothstep(-aa, aa, d);
		float glow = exp(-max(d, 0.0) * 6.0) * 0.4;
		rgb = mix(col.rgb, vec3(1.0), body * clamp(0.6 - p.y * 0.5, 0.0, 1.0));
		a = max(body, glow);
	} else {
		float d = length(p);
		a = (1.0 - smoothstep(0.25, 1.0, d)) * 0.75;
		rgb = col.rgb;
	}
	ALBEDO = rgb;
	ALPHA = a * col.a;
}
"""

## True while he is out.
var active := false
## His home (game units) and where he is now.
var home := Vector3.ZERO
var pos := Vector3.ZERO
var t := 0.0
var life := 7.0
## Active-play seconds to the next one.
var wait := 90.0
## Game units per metre (main: scale_now) and whether the game is in your room.
var unit := 2.0
var mr := false
## The player's eye (game units): he faces it and sways across its line of sight.
var eye := Vector3(0, 3.2, 1.0)
var side := Vector3.RIGHT
var caught := 0
var escaped := 0
var appeared := 0
var rng := RandomNumberGenerator.new()
## on_caught(pos: Vector3, how: String), on_escape(pos: Vector3), on_appear(pos: Vector3).
var on_caught: Callable = func(_p, _h): pass
var on_escape: Callable = func(_p): pass
var on_appear: Callable = func(_p): pass
## sfx(name: String, k: float, pos: Vector3) — main's sounds.
var sfx: Callable = func(_n, _k, _p): pass

var holder: Node3D
var view: DahroojView
var halo: MeshInstance3D
var _body_mat: ShaderMaterial
var _halo_mat: ShaderMaterial
var _sparks: Array = []  # {p, v, t, max, c: Color, s, kind (0 star, 1 puff)}
var _spark_mm: MultiMesh
var _spark_t := 0.0
var _pals: Array = []  # {view: DahroojView, p, v, t, spin}
var _flash := 0.0

static var _shaders := {}


static func _shader(key: String, code: String) -> Shader:
	if not _shaders.has(key):
		var sh := Shader.new()
		sh.code = code
		_shaders[key] = sh
	return _shaders[key]


func _init() -> void:
	name = "GoldenDahrooj"
	rng.randomize()
	wait = next_wait()
	holder = Node3D.new()
	holder.name = "Body"
	holder.visible = false
	add_child(holder)
	view = DahroojView.new(1.0)
	view.set_look("fur", "gold", "crown")
	_body_mat = ShaderMaterial.new()
	_body_mat.shader = _shader("body", BODY_SHADER)
	view.body.material_override = _body_mat
	view.body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(view)
	halo = MeshInstance3D.new()
	halo.name = "Halo"
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	halo.mesh = q
	_halo_mat = ShaderMaterial.new()
	_halo_mat.shader = _shader("halo", HALO_SHADER)
	_halo_mat.render_priority = 1
	halo.material_override = _halo_mat
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.scale = Vector3.ONE * 3.4
	holder.add_child(halo)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Sparkles"
	_spark_mm = MultiMesh.new()
	_spark_mm.transform_format = MultiMesh.TRANSFORM_3D
	_spark_mm.use_colors = true
	_spark_mm.use_custom_data = true
	var sq := QuadMesh.new()
	sq.size = Vector2(1, 1)
	_spark_mm.mesh = sq
	_spark_mm.instance_count = SPARKS
	_spark_mm.visible_instance_count = 0
	mmi.multimesh = _spark_mm
	var sm := ShaderMaterial.new()
	sm.shader = _shader("spark", SPARK_SHADER)
	sm.render_priority = 2
	mmi.material_override = sm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-500, -500, -500), Vector3(1000, 1000, 1000))
	add_child(mmi)


func next_wait() -> float:
	return rng.randf_range(EVERY.x, EVERY.y)


## His radius in game units now.
func radius() -> float:
	return (R_MR if mr else R_VR) * unit


# ---- where he turns up ----

## A point (game units) moved into the part of the forward arc he uses (ARC_USE either side of
## fwd) and at least MIN_M metres from the eye, its height kept.
static func settle(eye_p: Vector3, p: Vector3, fwd: Vector3, unit_k: float) -> Vector3:
	return RoomSpots.into_arc(eye_p, p, MIN_M * unit_k, fwd, ARC_USE)


## Up in the air ahead of the player (the arcade modes): dist metres out, h metres over the
## floor, within the arc.
static func air_spot(eye_p: Vector3, fwd: Vector3, unit_k: float, floor_y: float, r: RandomNumberGenerator,
		dist := Vector2(4.0, 8.0), h := Vector2(1.3, 2.5)) -> Vector3:
	var d := RoomSpots.dir_at(fwd, r.randf_range(-ARC_USE, ARC_USE) * 0.9) * r.randf_range(dist.x, dist.y) * unit_k
	return settle(eye_p, Vector3(eye_p.x + d.x, floor_y + r.randf_range(h.x, h.y) * unit_k, eye_p.z + d.z), fwd, unit_k)


## Over a throwing course's target (aim_z, the course's own units): a golden target to hit with
## a throw or a shot.
static func course_spot(eye_p: Vector3, fwd: Vector3, unit_k: float, aim_z: float, r: RandomNumberGenerator) -> Vector3:
	var p := Vector3(r.randf_range(-2.2, 2.2), r.randf_range(2.6, 3.8), aim_z + r.randf_range(-1.2, 0.6))
	return settle(eye_p, p, fwd, unit_k)


# ---- the frame ----

## dt: real seconds. playing: the player is playing a mode that has him (the clock runs, he
## moves); otherwise everything waits. spot: Callable -> Variant (a home Vector3, or null to try
## again a little later).
func step(dt: float, playing: bool, spot: Callable) -> void:
	_step_fx(dt)
	if not playing:
		return
	if active:
		t += dt
		pos = motion(t)
		_trail(dt)
		_draw()
		if t >= life:
			escape()
		return
	wait -= dt
	if wait <= 0.0:
		var p: Variant = spot.call() if spot.is_valid() else null
		if p is Vector3:
			appear(p as Vector3)
		else:
			wait = 3.0


## Where he is t seconds after appearing: a lazy zig-zag across the line of sight and a gentle
## bob over his home.
func motion(tt: float) -> Vector3:
	var nerves := clampf((tt - (life - 1.2)) / 1.2, 0.0, 1.0)  # he gets restless before he leaves
	var sway := sin(tt * 1.7) * SWAY + sin(tt * 9.0) * 0.03 * nerves
	return home + side * sway * unit + Vector3.UP * sin(tt * 2.6) * BOB * unit


func appear(p: Vector3) -> void:
	active = true
	appeared += 1
	t = 0.0
	life = rng.randf_range(STAY.x, STAY.y)
	home = p
	var to := Vector3(p.x - eye.x, 0.0, p.z - eye.z)
	side = Vector3(-to.z, 0.0, to.x).normalized() if to.length_squared() > 1e-8 else Vector3.RIGHT
	pos = motion(0.0)
	holder.visible = true
	_draw()
	for i in 18:
		_spark(pos + _rand_dir() * radius() * 0.4, _rand_dir() * radius() * 2.2, rng.randf_range(0.5, 0.9), GOLD.lightened(rng.randf() * 0.5), radius() * 0.32, 0)
	sfx.call("chime", 1.0, p)
	sfx.call("bricks_tink", 1.0, p)
	on_appear.call(p)


## Whether a ball of radius r (game units) at p reaches him.
func hit_by(p: Vector3, r: float) -> bool:
	return active and p.distance_to(pos) < radius() * 1.15 + r


## A shot or a throw got him: a golden burst, the little bonus Dahroojs and on_caught. False
## when he was not out.
func catch(how := "shot") -> bool:
	if not active:
		return false
	active = false
	caught += 1
	wait = next_wait()
	holder.visible = false
	var rr := radius()
	for i in 46:
		var c := GOLD.lightened(rng.randf() * 0.6) if i % 3 else Color("fff6d8")
		_spark(pos, _rand_dir() * rr * rng.randf_range(3.0, 7.0), rng.randf_range(0.6, 1.1), c, rr * rng.randf_range(0.25, 0.45), 0)
	for i in PALS:
		var a := TAU * i / PALS + rng.randf() * 0.4
		var v := Vector3(cos(a) * 1.6, rng.randf_range(2.2, 3.4), sin(a) * 1.6) * unit
		var pv := DahroojView.new(1.0)
		pv.set_look(str(["jelly", "fur", "bubble"][i % 3]), str(["gold", "yellow", "orange", "pink", "gold"][i % 5]), "")
		add_child(pv)
		_pals.append({"view": pv, "p": pos, "v": v, "t": 0.0, "spin": rng.randf_range(-6.0, 6.0)})
	on_caught.call(pos, how)
	return true


## Nobody got him in time: off he goes in a puff.
func escape() -> void:
	if not active:
		return
	active = false
	escaped += 1
	wait = next_wait()
	holder.visible = false
	_puff(pos)
	sfx.call("whoosh", 0.6, pos)
	sfx.call("start_pop", 1.0, pos)
	on_escape.call(pos)


## A new mode or a stop: he goes quietly (no puff), the clock keeps its time.
func clear() -> void:
	active = false
	holder.visible = false


func _puff(at: Vector3) -> void:
	var rr := radius()
	for i in 16:
		_spark(at + _rand_dir() * rr * 0.5, _rand_dir() * rr * 1.6 + Vector3.UP * rr, rng.randf_range(0.5, 0.8), Color(0.96, 0.94, 0.9, 0.85), rr * rng.randf_range(0.6, 1.0), 1)
	for i in 8:
		_spark(at, _rand_dir() * rr * 3.0, rng.randf_range(0.4, 0.7), GOLD, rr * 0.25, 0)


func _rand_dir() -> Vector3:
	var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
	return d.normalized() if d.length_squared() > 1e-6 else Vector3.UP


func _trail(dt: float) -> void:
	_spark_t -= dt
	var rr := radius()
	while _spark_t <= 0.0:
		_spark_t += SPARK_EVERY
		var off := _rand_dir() * rr * rng.randf_range(0.5, 1.1)
		_spark(pos + off, Vector3(0, -0.25, 0) * unit + off * 0.6, rng.randf_range(0.6, 1.0), GOLD.lightened(rng.randf() * 0.7), rr * rng.randf_range(0.14, 0.3), 0)


func _spark(p: Vector3, v: Vector3, life_s: float, c: Color, s: float, kind: int) -> void:
	if _sparks.size() >= SPARKS:
		_sparks.pop_front()
	_sparks.append({"p": p, "v": v, "t": 0.0, "max": life_s, "c": c, "s": s, "kind": kind})


func _draw() -> void:
	var k := minf(1.0, t / POP_T)
	var pop := 1.0 + 2.2 * pow(k - 1.0, 3) + 1.2 * pow(k - 1.0, 2)
	var out := clampf((t - (life - 0.25)) / 0.25, 0.0, 1.0)
	var rr := radius() * maxf(0.05, pop) * (1.0 - 0.6 * out)
	holder.position = pos
	holder.scale = Vector3.ONE * rr
	var wob := sin(t * 7.0) * 0.06
	view.show_at(Vector3.ZERO, (eye - pos) / maxf(rr, 1e-4), "joy" if fmod(t, 3.0) < 2.4 else "laugh", fmod(t, 2.7) < 0.12, Vector2(1.0 + wob, 1.0 - wob))
	_halo_mat.set_shader_parameter("strength", 0.75 + 0.25 * sin(t * 5.0))


func _step_fx(dt: float) -> void:
	_flash = maxf(0.0, _flash - dt)
	var n := 0
	var i := _sparks.size() - 1
	while i >= 0:
		var s: Dictionary = _sparks[i]
		s.t = float(s.t) + dt
		if float(s.t) >= float(s.max):
			_sparks.remove_at(i)
		else:
			s.v = (s.v as Vector3) * pow(0.25, dt) + (Vector3.DOWN * 1.2 * unit * dt if int(s.kind) == 0 else Vector3.UP * 0.2 * unit * dt)
			s.p = (s.p as Vector3) + (s.v as Vector3) * dt
		i -= 1
	for s: Dictionary in _sparks:
		var k := float(s.t) / float(s.max)
		var sz := float(s.s) * (sin(minf(1.0, k * 2.5) * PI * 0.5) * (1.0 - k * 0.5) if int(s.kind) == 0 else (0.6 + 0.8 * k))
		_spark_mm.set_instance_transform(n, Transform3D(Basis().scaled(Vector3.ONE * maxf(sz, 1e-4)), s.p))
		var c: Color = s.c
		_spark_mm.set_instance_color(n, Color(c.r, c.g, c.b, c.a * (1.0 - k * k)))
		_spark_mm.set_instance_custom_data(n, Color(float(s.kind), 0, 0, 0))
		n += 1
	_spark_mm.visible_instance_count = n
	# The bonus Dahroojs: out of him in an arc, then pop.
	var j := _pals.size() - 1
	while j >= 0:
		var pl: Dictionary = _pals[j]
		pl.t = float(pl.t) + dt
		pl.v = (pl.v as Vector3) + Vector3.DOWN * 7.0 * unit * dt
		pl.p = (pl.p as Vector3) + (pl.v as Vector3) * dt
		var pv: DahroojView = pl.view
		if float(pl.t) > 1.0:
			for q in 8:
				_spark(pl.p, _rand_dir() * radius() * 2.0, rng.randf_range(0.3, 0.6), GOLD.lightened(0.3), radius() * 0.18, 0)
			sfx.call("start_pop", 0.8, pl.p)
			pv.queue_free()
			_pals.remove_at(j)
		else:
			var g := minf(1.0, float(pl.t) / 0.2)
			pv.show_at(pl.p, eye, "joy", false, Vector2.ONE * radius() * 0.38 * g)
			pv.rotation.z = float(pl.spin) * float(pl.t) * 0.3
		j -= 1


## The little bonus Dahroojs in flight (tests).
func pals_out() -> int:
	return _pals.size()
