class_name MeteorStage
extends Node3D
## Dahrooj Meteors («نيازك الدحاريج», mode "meteor"): flaming Dahrooj meteors fall out of the sky
## toward you and the court (mixed reality: they crack holes in the scanned ceiling and fall
## through them to the floor). Shoot them in the air: a big one splits into two middle ones, a
## middle one into two small ones (Asteroids, in 3D around you), and a small one bursts into a
## firework. Every explosion sets off the meteors close to it (chain explosions, a bonus per link).
##
## - each meteor: a Dahrooj inside a flickering teardrop of fire, a heat glow and shimmer around
##   it, a trail of embers (and smoke from the big ones, glitter from the golden ones); a warning
##   target on the ground where it will land, tightening as it comes down.
## - golden meteors (a crowned golden Dahrooj) are worth ×5 and split into golden pieces.
## - every half minute or so a meteor shower: a banner, then a burst of meteors along parallel
##   streaks from one side of the sky.
## - open play: no hearts, no game over, no timer, no board. One that lands leaves a glowing
##   crater with a shockwave and a dust cloud; it breaks the combo and takes GROUND_PENALTY
##   points (by size), and one that lands right at the player's feet (within HIT_R) takes
##   LAND_PENALTY more off the score. Quick blasts build a
##   combo (×2 .. ×6). The points go to ctx.counts["meteor"] (the jelly score popup).
## - endless and escalating: they come more often, faster and bigger as the minutes go by.
## Game units, like the other stages (VR: 2 per metre; mixed reality: 8 per metre, size 2).
## The blaster finds the meteors through hidden (layers = 0) sphere MeshInstance3Ds; every effect
## is a MultiMesh (particles move in their shader: written once, never updated) or a JuiceText.
##
## Mixed reality: `planes_provider` returns the room's planes as SlimeStage's do ({pos, normal,
## ax, ay, half, label}, game units): the ceiling ("ceiling", or facing down) is where they come
## through, the floor ("floor", or facing up below the eye) where they land. No scan: the sky.

const KINDS := {
	# r: radius (game units, × size), pts: points for a blast, split: what it breaks into,
	# rate: embers a second in its trail.
	"big": {"r": 1.25, "pts": 10, "split": "mid", "rate": 34.0},
	"mid": {"r": 0.85, "pts": 15, "split": "small", "rate": 26.0},
	"small": {"r": 0.56, "pts": 25, "split": "", "rate": 18.0},
}
const GOLD_K := 5
const SLOTS := 44
const FX_MAX := 1400
const DUST_MAX := 360
const HALO_MAX := SLOTS * 2 + 8
const RINGS_MAX := 24
const WARN_MAX := SLOTS * 2
const CRATERS_MAX := 14
const SKY_H := 21.0  # VR: how high they appear (× size)
const GRAV := 3.0  # their gravity (× size)
const T_START := 4.4  # flight time at the start (s)
const T_MIN := 2.3
const LAND_MIN := 4.0
const LAND_MAX := 17.0
const SHOWER_SPREAD := 0.6  # radians a shower's streaks spread off its way
const BLAST_R := 2.0  # an explosion sets off meteors this close (× size, beyond their radii)
const CHAIN_DELAY := 0.13
const CHAIN_PTS := 10
const COMBO_T := 2.2
const COMBO_STEPS := [3, 6, 10, 15, 22]
const SHOWER_FIRST := 26.0
const SHOWER_EVERY := 32.0
const SHOWER_T := 4.5
const CRACK_T := 0.9  # a ceiling cracks this long before the meteor comes through
const CRATER_T := 7.0
## A meteor landing this close to the player (across the floor, × size) hits them: it takes
## LAND_PENALTY points (ctx.penalty: never below 0; records and totals keep theirs).
const HIT_R := 6.0
const LAND_PENALTY := 25
## Every meteor that reaches the ground unpopped takes these points too (ctx.nibble: a small grey
## «-N» at the crater), by kind; a shower's take them one by one.
const GROUND_PENALTY := {"big": 20, "mid": 15, "small": 10}
const LAND_T := 0.9  # the dazed Dahrooj sinks into its crater
const BANNER_T := 2.4
const LEVEL_T := 30.0  # play seconds per level of intensity
const COLORS := ["ff7a3d", "ff5a4a", "ffb347", "e2603f", "ff69b4", "b36bff", "ff9b3d", "58b9ff", "7bbf8a"]
const STYLES := ["jelly", "fur", "clay", "fabric", "clay", "jelly"]
const ACCS := ["", "", "", "party", "glasses", "cap", "headphones", "scarf"]
const FIRE := ["ff7a2a", "ff5a1f", "ff9a3a"]
const GOLD := "ffd23f"
const DUST := ["c4ae92", "d6c2a6", "b09a80", "e0d0b8", "bfb2a2"]
const FIREWORKS := [["ff4fa3", "ffd23f", "ffffff"], ["58b9ff", "b36bff", "e8f4ff"], ["7bff8a", "fff27a", "ffffff"],
	["ff7a3d", "ffd23f", "ff4f4f"], ["ff69b4", "7fd8ff", "fff3b0"]]
const GOLD_FW := ["ffd23f", "fff3b0", "ffb347", "ffffff"]
## Particle kinds (their look and motion live in the shader).
const K_FLASH := 0
const K_EMBER := 1
const K_GLITTER := 2
const K_SMOKE := 3
const K_SHIMMER := 4
const K_GLOW := 5

## Particles: a billboard quad whose motion is in the shader. Instance: origin = start,
## basis columns x = (size, 0, 0), y = (0, gravity, 0), z = velocity (all game units, so the
## node's transform carries them to the world); custom = (t0, life, kind, drag); colour = linear rgba.
const FX_CODE := """
shader_type spatial;
render_mode unshaded, %s, depth_draw_never, cull_disabled, fog_disabled;
uniform float now = 0.0;
varying vec4 v_col;
varying vec3 v_k;
void vertex() {
	float t0 = INSTANCE_CUSTOM.x;
	float life = max(INSTANCE_CUSTOM.y, 0.001);
	float kind = INSTANCE_CUSTOM.z;
	float drag = INSTANCE_CUSTOM.w;
	float age = max(now - t0, 0.0);
	float k = age / life;
	float sz = length(MODEL_MATRIX[0].xyz);
	float mv = drag > 0.001 ? (1.0 - exp(-drag * age)) / drag : age;
	vec3 p = MODEL_MATRIX[3].xyz + MODEL_MATRIX[2].xyz * mv - MODEL_MATRIX[1].xyz * 0.5 * age * age;
	float s = sz;
	if (kind < 0.5) { s *= 1.0 - 0.5 * k; }
	else if (kind < 1.5) { s *= (0.7 + 0.9 * k) * (1.0 - k * k); }
	else if (kind < 2.5) { s *= 1.0 - 0.6 * k; }
	else if (kind < 3.5) { s *= 0.55 + 1.9 * sqrt(k); }
	if (k > 1.0 || now < t0) { s = 0.0; }
	vec3 pv = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
	POSITION = PROJECTION_MATRIX * vec4(pv + vec3(VERTEX.xy * s, 0.0), 1.0);
	v_col = COLOR;
	v_k = vec3(k, kind, fract(t0 * 13.7 + MODEL_MATRIX[3].x * 3.1));
}
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float d = length(q);
	float k = v_k.x;
	float kind = v_k.y;
	vec3 col = v_col.rgb;
	float a;
	float glow = 0.75;  // < 1: part of it adds light (premultiplied alpha)
	if (kind > 3.5 && kind < 4.5) {
		// heat shimmer: a faint wavering ring
		float w = 0.7 + 0.06 * sin(atan(q.y, q.x) * 6.0 + TIME * 7.0 + v_k.z * 20.0) + 0.03 * sin(TIME * 13.0);
		float e = (d - w) / 0.08;
		a = exp(-e * e) * 0.3;
	} else if (kind > 2.5 && kind < 3.5) {
		a = (1.0 - smoothstep(0.15, 1.0, d)) * (1.0 - k) * min(1.0, k * 6.0);
		glow = 1.0;
	} else {
		a = exp(-d * d * 4.5) * (1.0 - smoothstep(0.85, 1.0, d));
		col = col * (1.0 + 1.6 * exp(-d * d * 30.0));
		if (kind < 0.5) { a *= 1.0 - k; }
		else if (kind < 1.5) {
			col = mix(mix(vec3(1.0, 0.92, 0.6), vec3(1.0, 0.42, 0.08), smoothstep(0.0, 0.4, k)), vec3(0.55, 0.07, 0.02), smoothstep(0.4, 1.0, k)) * col;
			a *= pow(1.0 - k, 1.2);
		}
		else if (kind < 2.5) { a *= (1.0 - k * k) * (0.65 + 0.35 * sin(TIME * 40.0 + v_k.z * 60.0)); }
	}
	a = clamp(a * v_col.a, 0.0, 1.0);
	ALBEDO = col * a;
	ALPHA = a * glow;
}
"""

## The fire around a meteor: a teardrop (tail along +Z, length TAIL) that flickers, its edge
## brightest (so the Dahrooj shows through its middle). Colour = tint and strength; custom.x = seed.
const FIRE_CODE := """
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_back, fog_disabled;
varying vec3 lp;
varying float seed;
void vertex() {
	lp = VERTEX;
	seed = INSTANCE_CUSTOM.x;
}
void fragment() {
	float tail = clamp(lp.z / 3.2, 0.0, 1.0);
	float fres = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float ang = atan(lp.y, lp.x);
	float fl = 0.62 + 0.38 * sin(lp.z * 5.0 - TIME * 22.0 + ang * 3.0 + seed) * sin(lp.z * 2.3 - TIME * 13.0 - ang * 2.0 + seed * 2.0);
	float a = (0.2 + 1.2 * pow(fres, 1.4)) * mix(1.0, fl, 0.3 + 0.7 * tail) * pow(1.0 - tail, 1.1);
	a = clamp(a * COLOR.a, 0.0, 1.0);
	vec3 hot = mix(vec3(1.0, 0.86, 0.32), COLOR.rgb, smoothstep(0.0, 0.4, tail + fres * 0.3));
	hot = mix(hot, vec3(0.62, 0.06, 0.02), smoothstep(0.4, 1.0, tail));
	ALBEDO = hot * a * 1.25;
	ALPHA = a * 0.85;
}
"""

## A crater (or a crack in the ceiling): scorched, jagged, its rim and cracks glowing with heat.
## Colour: r = heat, g = opacity, b = seed.
const CRATER_CODE := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	if (r > 1.0) discard;
	float a = atan(q.y, q.x);
	float seed = COLOR.b * 40.0;
	float heat = COLOR.r;
	float edge = 0.8 + 0.08 * sin(a * 7.0 + seed) + 0.05 * sin(a * 13.0 + seed * 1.7);
	float scorch = 1.0 - smoothstep(edge * 0.6, edge, r);
	float pit = 1.0 - smoothstep(0.0, edge * 0.45, r);
	float e1 = (r - edge * 0.47) / 0.06;
	float e2 = (r - edge * 0.62) / 0.08;
	float rim = exp(-e1 * e1);
	float lip = exp(-e2 * e2);
	float cracks = pow(abs(sin(a * 4.5 + seed + r * 3.0)), 28.0) * (1.0 - smoothstep(edge * 0.4, edge * 1.05, r)) * step(edge * 0.3, r);
	float glow = clamp((rim * 0.9 + cracks + pit * 0.7) * heat, 0.0, 1.0);
	vec3 soot = mix(vec3(0.2, 0.15, 0.12), vec3(0.03, 0.02, 0.02), pit);
	soot = mix(soot, vec3(0.42, 0.34, 0.27), lip * 0.6);
	vec3 ember = mix(vec3(1.0, 0.32, 0.04), vec3(1.0, 0.85, 0.45), pit);
	ALBEDO = mix(soot, ember * 2.0, glow);
	ALPHA = clamp(max(scorch * 0.9, glow), 0.0, 1.0) * COLOR.g;
}
"""

static var _meshes := {}

var aim_z := -10.0
var far_z = -26.0
var reach_z = -10.0
var friction = null
var shot_time = 4.0
var ctx: GameCtx

## Room planes (mixed reality), as SlimeStage.planes_provider; [] or invalid: the sky.
var planes_provider: Callable
## Landing spots (mixed reality): RoomSpots on the open floor in front of the player (as
## MoleStage.spots_provider). Unset or empty: the court ahead (VR).
var spots_provider: Callable
## Game units per metre (main: the court's scale): every meteor lands in front of the player
## (RoomSpots.ARC either side of the court's forward, game -Z) and RoomSpots.MIN_DIST away.
var unit := 2.0
## Size of the meteors and their effects (mixed reality wants 2).
var size := 1.0
## The player's eye (game units). Main keeps it current.
var viewer := Vector3(0, 3.2, 1.0)
## Meteors come on their own (tests turn it off and call spawn()).
var auto_spawn := true
## buzz(hand: String, amp: float, ms: float): haptics (main's buzz).
var buzz: Callable
## Main holds the game while the menu is open or the court is being placed.
var paused := false
var time := 0.0

var F := {"state": "idle", "t": 0.0, "score": 0, "combo": 0, "combo_t": 0.0, "mult": 1,
	"spawn_t": 0.0, "shower_t": SHOWER_FIRST, "shower_on": 0.0, "shower_spawn": 0.0, "shower_dir": Vector3.FORWARD,
	"showers": 0, "popped": 0, "landed": 0, "fireworks": 0, "chains": 0, "best_chain": 0, "golden": 0, "touched": false,
	"banner_t": 0.0, "banner_life": BANNER_T, "combo_show_t": 0.0, "combo_at": Vector3.ZERO}
var meteors: Array = []
var craters: Array = []
var crowd: Crowd
var banner: JuiceText
var banner_sub: JuiceText
var combo_label: JuiceText
var fx_spawned := 0  # particles started (tests)
var _rings: Array = []
var _fx_i := 0
var _dust_i := 0
var _goal_s := Vector3(0, 0, 1.0)
var _planes: Array = []
var _room_t := 0.0
var _draw_acc := 0.0
var _mm := {}
var _fx_mat: ShaderMaterial
var _dust_mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 7171
	name = "Meteor"
	crowd = Crowd.new(SLOTS, true, true)
	crowd.name = "Meteors"
	add_child(crowd)
	for i in SLOTS:
		meteors.append({"on": false, "kind": "big", "golden": false, "phase": "", "t": 0.0, "c": Vector3.ZERO,
			"v": Vector3.ZERO, "g": GRAV, "r": 0.9, "land": Vector3.ZERO, "eta": 1.0, "warn": 3.0, "floor": 0.0,
			"style": "clay", "color": "ff7a3d", "fire": "ff7a2a", "acc": "", "wob": 0.0, "emit": 0.0, "smoke": 0.0,
			"chain_t": -1.0, "chain_n": 0, "flash_t": 0.0, "crack": {}, "n": Vector3.DOWN, "seed": 0.0,
			"proxy": _proxy("MeteorHit%d" % i)})
	_fx_mat = _shader_mat(FX_CODE % "blend_premul_alpha")
	_dust_mat = _shader_mat(FX_CODE % "blend_premul_alpha")
	_dust_mat.render_priority = -1
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	_mm.fx = _multi("Sparks", quad, _fx_mat, FX_MAX, true)
	_mm.dust = _multi("Dust", quad, _dust_mat, DUST_MAX, true)
	_mm.halo = _multi("Heat", quad, _fx_mat, HALO_MAX, true)
	(_mm.fx as MultiMesh).visible_instance_count = FX_MAX
	(_mm.dust as MultiMesh).visible_instance_count = DUST_MAX
	var fire := _shader_mat(FIRE_CODE)
	_mm.fire = _multi("Fire", fire_mesh(), fire, SLOTS, true)
	_mm.rings = _multi("Rings", Crowd.merge([[Crowd.torus(1.0, 0.07, 6, 48), Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO), Color.WHITE]]), _glow_mat(), RINGS_MAX + WARN_MAX)
	_mm.discs = _multi("Targets", Crowd.merge([[Crowd.circle(1.0, 32), Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3.ZERO), Color.WHITE]]), _glow_mat(), SLOTS)
	var plane := PlaneMesh.new()
	plane.size = Vector2(2, 2)
	var cm := _shader_mat(CRATER_CODE)
	cm.render_priority = -2
	_mm.craters = _multi("Craters", plane, cm, CRATERS_MAX)
	banner = _label("banner", 210 * 0.0062, Color("ffb347"))
	banner_sub = _label("sub", 96 * 0.0058, Color("fff3e0"))
	combo_label = _label("combo", 150 * 0.0058, Color("ff7ad9"))
	draw()


# ---- art ----

func _label(kind: String, em: float, col: Color) -> JuiceText:
	var l := JuiceText.make(kind, em)
	if kind != "combo":
		l.modulate = col
	add_child(l)
	return l

func _proxy(id: String) -> MeshInstance3D:
	var proxy := MeshInstance3D.new()
	proxy.name = id
	proxy.mesh = InvasionStage._sphere_mesh()
	proxy.layers = 0  # never drawn: only the blaster's ray sees it
	proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	proxy.visible = false
	add_child(proxy)
	return proxy


static func _shader_mat(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


static func _glow_mat() -> Material:
	if not _meshes.has("glow"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.no_depth_test = false
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_meshes["glow"] = m
	return _meshes["glow"]


func _multi(id: String, mesh: Mesh, mat: Material, cap: int, custom := false) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = custom
	mm.mesh = mesh
	mm.instance_count = cap
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.name = id
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-90, -30, -90), Vector3(180, 100, 180))
	add_child(mi)
	return mm


## The fire's teardrop: a unit sphere whose back half (+Z) is drawn out into a tapering tail.
static func fire_mesh() -> ArrayMesh:
	if _meshes.has("fire"):
		return _meshes["fire"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ws := 18
	var hs := 14
	var pts := []
	for j in hs + 1:
		var th := PI * j / hs
		for i in ws + 1:
			var ph := TAU * i / ws
			var p := Vector3(sin(th) * cos(ph), sin(th) * sin(ph), -cos(th))
			if p.z > 0.0:
				var k := p.z
				p = Vector3(p.x * (1.0 - 0.45 * k), p.y * (1.0 - 0.45 * k), k * 3.2)
			pts.append(p)
	for j in hs:
		for i in ws:
			var a: int = j * (ws + 1) + i
			var b: int = a + ws + 1
			for idx in [a, b, a + 1, a + 1, b, b + 1]:
				st.add_vertex(pts[idx])
	st.generate_normals()
	var mesh := st.commit()
	_meshes["fire"] = mesh
	return mesh


func _num(v: int) -> String:
	return str(v) if _en() else GameCtx.ar_digits(v)


func _en() -> bool:
	return ctx != null and ctx.lang == "en"


func _sfx(n: String, k: float, p: Vector3) -> void:
	if ctx:
		ctx.sfx.call(n, k, p)


func _confetti(at: Vector3, k := 1.0) -> void:
	if ctx:
		ctx.confetti.call(at, 1.2 * k * size, 1.4, maxf(1.0, at.distance_to(viewer) / 7.0))


func _buzz2(amp: float, ms: float) -> void:
	if buzz.is_valid():
		buzz.call("left", amp, ms)
		buzz.call("right", amp, ms)


# ---- particles ----

func _fx(p: Vector3, v: Vector3, life: float, col: Color, s: float, kind: int, g := 0.0, drag := 0.0) -> void:
	var mm: MultiMesh
	var i: int
	if kind == K_SMOKE:
		mm = _mm.dust
		i = _dust_i
		_dust_i = (_dust_i + 1) % DUST_MAX
	else:
		mm = _mm.fx
		i = _fx_i
		_fx_i = (_fx_i + 1) % FX_MAX
	mm.set_instance_transform(i, Transform3D(Basis(Vector3(s, 0, 0), Vector3(0, g, 0), v), p))
	mm.set_instance_color(i, col)
	mm.set_instance_custom_data(i, Color(time, life, float(kind), drag))
	fx_spawned += 1


static func _lin(hex: String, a := 1.0) -> Color:
	return Color(Color(hex).srgb_to_linear(), a)


func _rand_dir() -> Vector3:
	var z := _rng.randf_range(-1.0, 1.0)
	var a := _rng.randf() * TAU
	var s := sqrt(1.0 - z * z)
	return Vector3(s * cos(a), z, s * sin(a))


## A firework: a shell of twinkling sparks in a palette, a white flash at its heart.
func firework(at: Vector3, golden: bool, k := 1.0) -> void:
	var pal: Array = GOLD_FW if golden else FIREWORKS[_rng.randi() % FIREWORKS.size()]
	var n := int(80 * k) + (30 if golden else 0)
	for i in n:
		var d := _rand_dir()
		var sp := _rng.randf_range(9.0, 12.0) * size * k
		var c := _lin(pal[i % pal.size()], 1.0)
		_fx(at, d * sp, _rng.randf_range(1.0, 1.6), c, _rng.randf_range(0.15, 0.24) * size, K_GLITTER, 2.2 * size, 1.7)
	for _i in int(18 * k):
		var d := _rand_dir()
		_fx(at, d * _rng.randf_range(2.0, 3.5) * size, _rng.randf_range(0.5, 0.8), _lin(pal[0]), 0.3 * size, K_FLASH, 1.0 * size, 2.0)
	_fx(at, Vector3.ZERO, 0.28, _lin("fff6e0"), 1.6 * size * k, K_FLASH)
	_ring(at, (viewer - at).normalized(), 0.3 * size, 2.0 * size * k, 0.3, Color(pal[0]))
	F.fireworks += 1
	_sfx("firework_burst", 0.7 + 0.3 * k, at)
	if golden:
		_confetti(at, 1.3)


## A fiery blast (a split or a chain link): embers out every way and a flash.
func _blast(at: Vector3, r: float, golden: bool) -> void:
	for _i in 26:
		var d := _rand_dir()
		_fx(at, d * _rng.randf_range(3.0, 7.0) * size, _rng.randf_range(0.4, 0.8), _lin("ffd9a0") if not golden else _lin(GOLD), _rng.randf_range(0.12, 0.2) * size, K_EMBER, 2.5 * size, 1.2)
	_fx(at, Vector3.ZERO, 0.3, _lin("ffe7b0"), r * 3.2, K_FLASH)
	for _i in 6:
		_fx(at + _rand_dir() * r * 0.5, _rand_dir() * 1.2 * size + Vector3.UP * 0.5 * size, _rng.randf_range(1.0, 1.5), _lin("9a8f88", 0.32), r * 0.8, K_SMOKE, -0.3 * size, 1.5)
	_ring(at, (viewer - at).normalized(), r * 0.6, r * 2.2, 0.25, Color("ffb347"))


func _dust(at: Vector3, n: Vector3, count: int, k: float) -> void:
	var b := MoleStage.basis_up(n)
	for _i in count:
		var a := _rng.randf() * TAU
		var out := b.x * cos(a) + b.z * sin(a)
		var v := (out * _rng.randf_range(3.0, 6.5) + n * _rng.randf_range(0.3, 1.6)) * size * k
		_fx(at + out * 0.3 * size * k + n * 0.2 * size, v, _rng.randf_range(0.9, 1.7), _lin(DUST[_rng.randi() % DUST.size()], 0.6),
			_rng.randf_range(0.4, 0.7) * size * k, K_SMOKE, -0.25 * size, 2.4)


func _ring(at: Vector3, n: Vector3, r0: float, r1: float, life: float, col: Color) -> void:
	if _rings.size() >= RINGS_MAX:
		_rings.pop_front()
	_rings.append({"p": at, "n": n if n.length_squared() > 1e-6 else Vector3.UP, "r0": r0, "r1": r1, "t": 0.0, "life": life, "c": col})


func _crater(at: Vector3, n: Vector3, r: float, heat: float, crack := false) -> Dictionary:
	if craters.size() >= CRATERS_MAX:
		craters.pop_front()
	var q := {"p": at, "n": n, "r": r, "t": 0.0, "heat": heat, "crack": crack, "seed": _rng.randf()}
	craters.append(q)
	return q


func _pop_label(at: Vector3, text: String, col: Color, k := 1.0) -> void:
	JuiceText.spawn(self, text, at, "points", k * size * maxf(1.0, at.distance_to(viewer) / (9.0 * size)), col)

# ---- the game ----

func goal() -> Vector3:
	return _goal_s


## Intensity: one level per LEVEL_T seconds of play.
func level() -> float:
	return float(F.t) / LEVEL_T


## Seconds between meteors at level lv.
static func spawn_interval(lv: float) -> float:
	return maxf(0.42, 2.2 - 0.2 * lv)


## Flight time from the sky at level lv.
static func flight_time(lv: float) -> float:
	return maxf(T_MIN, T_START - 0.14 * lv)


## How many may be falling at once (pieces of a split don't count against it).
static func cap_at(lv: float) -> int:
	return mini(4 + int(lv * 1.5), 26)


static func multiplier(combo: int) -> int:
	var m := 1
	for s in COMBO_STEPS:
		if combo >= int(s):
			m += 1
	return m


func banner_at() -> Vector3:
	var to := Vector3(0, 0, aim_z) - Vector3(viewer.x, 0, viewer.z)
	var d := to.normalized() if to.length_squared() > 0.01 else Vector3.FORWARD
	var k := banner_k()
	return Vector3(viewer.x, viewer.y + 1.3 * size * k, viewer.z) + d * 8.0 * size * k


## The banner's distance (and so its size) over the VR one: the room's small meteors would
## put it half a metre from your face, so it keeps at least 2.6 m away (and grows with it).
func banner_k() -> float:
	return maxf(1.0, 2.6 * unit / (8.0 * size))


func start() -> void:
	F.state = "play"
	F.t = 0.0
	F.score = 0
	F.combo = 0
	F.combo_t = 0.0
	F.mult = 1
	F.spawn_t = 1.2
	F.shower_t = SHOWER_FIRST
	F.shower_on = 0.0
	F.showers = 0
	F.popped = 0
	F.landed = 0
	F.fireworks = 0
	F.chains = 0
	_banner("نيازك الدحاريج!" if not _en() else "DAHROOJ METEORS!", "فجّرها قبل ما تطيح!" if not _en() else "Blast them before they land!", Color("ffb347"))
	_sfx("whoosh", 0.8, banner_at())
	_sfx("firework_launch", 0.6, banner_at())


func _banner(text: String, sub: String, color: Color, secs := BANNER_T) -> void:
	banner.text = text
	banner.modulate = color
	banner_sub.text = sub
	F.banner_t = secs
	F.banner_life = secs


func falling() -> int:
	var n := 0
	for m in meteors:
		if m.on and m.phase in ["fall", "crack"]:
			n += 1
	return n


func _pick_kind(lv: float, shower: bool) -> String:
	var r := _rng.randf()
	if shower:
		return "big" if r < 0.1 else ("mid" if r < 0.45 else "small")
	var big := minf(0.55, 0.28 + 0.03 * lv)
	return "big" if r < big else ("mid" if r < big + 0.4 else "small")


func _gold_chance(shower: bool) -> float:
	return 0.22 if shower else minf(0.12, 0.06 + 0.006 * level())


func _step_spawns(dt: float) -> void:
	if F.state == "idle":
		# Open play: it starts as soon as the mode is shown.
		if auto_spawn:
			start()
		return
	F.t += dt
	if not auto_spawn:
		return
	var lv := level()
	# Meteor showers.
	F.shower_t -= dt
	if F.shower_t <= 0.0 and F.shower_on <= 0.0:
		start_shower()
	if F.shower_on > 0.0:
		F.shower_on -= dt
		F.shower_spawn -= dt
		if F.shower_spawn <= 0.0 and falling() < SLOTS - 8:
			F.shower_spawn = _rng.randf_range(0.14, 0.26)
			spawn(_pick_kind(lv, true), _rng.randf() < _gold_chance(true), {"shower": true})
		return
	F.spawn_t -= dt
	if F.spawn_t <= 0.0:
		F.spawn_t = spawn_interval(lv) * _rng.randf_range(0.7, 1.3)
		if falling() < cap_at(lv):
			var pack := 1
			if lv >= 3.0 and _rng.randf() < minf(0.4, 0.1 + 0.03 * lv):
				pack = 2
			for _k in pack:
				spawn(_pick_kind(lv, false), _rng.randf() < _gold_chance(false))


func start_shower() -> void:
	F.shower_on = SHOWER_T
	F.shower_spawn = 0.6
	F.showers += 1
	F.shower_t = SHOWER_EVERY * _rng.randf_range(0.9, 1.15) + SHOWER_T
	# From ahead: the streaks spread SHOWER_SPREAD more either way, all inside the forward arc.
	var az := _rng.randf_range(-(RoomSpots.ARC - SHOWER_SPREAD), RoomSpots.ARC - SHOWER_SPREAD)
	F.shower_dir = RoomSpots.dir_at(Vector3.FORWARD, az)
	_banner("زخّة نيازك!" if not _en() else "METEOR SHOWER!", "اللمّاعة بخمسة أضعاف!" if not _en() else "Shiny ones are worth ×5!", Color("ff6b3d"), 2.0)
	_sfx("firework_launch", 1.0, banner_at())
	_sfx("whoosh", 1.0, banner_at())
	_buzz2(0.4, 90)


## Main, as soon as the mode is set up in mixed reality: read the room now, so the first
## frame already has the room layout (no VR wall, booth or field shown for a moment).
func refresh_room() -> void:
	_refresh_room()


# ---- the room ----

func _refresh_room() -> void:
	_planes = []
	if planes_provider.is_valid():
		var p = planes_provider.call()
		if p is Array:
			_planes = p


func room() -> bool:
	return not _planes.is_empty()


static func is_ceiling(pl: Dictionary) -> bool:
	return str(pl.get("label", "")) == "ceiling" or (pl.normal as Vector3).y < -0.7


func _is_floor(pl: Dictionary) -> bool:
	var l := str(pl.get("label", ""))
	return l == "floor" or ((pl.normal as Vector3).y > 0.7 and (pl.pos as Vector3).y < viewer.y - 2.0 * size and l != "table")


## The floor's height (the lowest scanned floor; the court's ground otherwise).
func floor_y() -> float:
	var y := INF
	for pl: Dictionary in _planes:
		if _is_floor(pl):
			y = minf(y, (pl.pos as Vector3).y)
	return 0.0 if y == INF else y


static func _on_plane(pl: Dictionary, u: float, v: float) -> Vector3:
	var half: Vector2 = pl.get("half", Vector2.ONE)
	return (pl.pos as Vector3) + (pl.get("ax", Vector3.RIGHT) as Vector3) * u * half.x + (pl.get("ay", Vector3.BACK) as Vector3) * v * half.y


## A landing spot in front of the player (RoomSpots), or null.
func _spot_land(fy: float) -> Variant:
	var sps := RoomSpots.ask(spots_provider, ["floor"])
	if sps.is_empty():
		return null
	var p: Vector3 = (sps[0] as Dictionary).pos
	p.y = fy
	return p


## The point of a ceiling right above p (within its extents), or null.
func _ceiling_above(ceilings: Array, p: Vector3) -> Variant:
	for pl: Dictionary in ceilings:
		var n: Vector3 = pl.normal
		if absf(n.y) < 0.5:
			continue
		var c: Vector3 = pl.pos
		var q := Vector3(p.x, c.y - ((p.x - c.x) * n.x + (p.z - c.z) * n.z) / n.y, p.z)
		var d := q - c
		var half: Vector2 = pl.get("half", Vector2.ONE)
		if absf(d.dot(pl.get("ax", Vector3.RIGHT))) <= half.x + 1e-3 and absf(d.dot(pl.get("ay", Vector3.BACK))) <= half.y + 1e-3:
			return q
	return null


## A landing this close to the player hits them (game units): HIT_R, or the nearest band of
## landings in the room (they never land nearer than near_d()).
func hit_r() -> float:
	return maxf(HIT_R * size, near_d() * 1.4)


## How near the player a meteor may land (game units): RoomSpots.MIN_DIST, and LAND_MIN.
func near_d() -> float:
	return maxf(LAND_MIN * size, RoomSpots.MIN_DIST * unit)


## Where one lands in the room: on a scanned floor in front of you (the forward arc, not near
## you), else on the floor ahead of you.
func _room_land(fy: float) -> Vector3:
	var sp: Variant = _spot_land(fy)
	if sp != null:
		return sp as Vector3
	var floors := _planes.filter(func(pl): return _is_floor(pl))
	var g := goal()
	var near := near_d()
	for _try in 12:
		if floors.is_empty():
			break
		var pl: Dictionary = floors[_rng.randi() % floors.size()]
		var p := _on_plane(pl, _rng.randf_range(-0.85, 0.85), _rng.randf_range(-0.85, 0.85))
		p.y = fy
		if RoomSpots.ahead(g, p, near):
			return p
	var a2 := _rng.randf_range(-RoomSpots.ARC, RoomSpots.ARC)
	var q := g + RoomSpots.dir_at(Vector3.FORWARD, a2) * near * _rng.randf_range(1.0, 1.4)
	q.y = fy
	return q


# ---- spawning ----

func _free_slot() -> int:
	for i in meteors.size():
		if not meteors[i].on:
			return i
	return -1


## Starts a meteor; returns its slot or -1. spot: {} (picked: the sky or, in the room, the ceiling),
## or {start, land, T} to fly it from start to land in T seconds (tests), "shower": true for a
## shower streak, "ceiling": true to come through the ceiling when there is one.
func spawn(kind: String, golden := false, spot := {}) -> int:
	var slot := _free_slot()
	if slot < 0:
		return -1
	var m: Dictionary = meteors[slot]
	var K: Dictionary = KINDS[kind]
	_setup(m, kind, golden)
	var lv := level()
	var fy := floor_y()
	var T := flight_time(lv) * _rng.randf_range(0.85, 1.15)
	var start_p: Vector3
	var land: Vector3
	var g: float = GRAV * size
	var crack := false
	var ceilings := _planes.filter(func(pl): return is_ceiling(pl))
	if spot.has("start"):
		start_p = spot.start
		land = spot.land
		T = float(spot.get("T", T))
	elif not ceilings.is_empty() and (spot.get("ceiling", false) or _rng.randf() < 0.9):
		# Through the ceiling: it cracks first, then the meteor comes through and falls to the floor.
		var pl: Dictionary = ceilings[_rng.randi() % ceilings.size()]
		start_p = _on_plane(pl, _rng.randf_range(-0.8, 0.8), _rng.randf_range(-0.8, 0.8))
		land = _room_land(fy)
		# All around the room: through the ceiling close above where it lands.
		if spots_provider.is_valid():
			var off := Vector3(_rng.randf_range(-1.0, 1.0), 0, _rng.randf_range(-1.0, 1.0)) * 1.5 * size
			var above: Variant = _ceiling_above(ceilings, land + off)
			if above == null:
				above = _ceiling_above(ceilings, land)
			if above != null:
				start_p = above as Vector3
				for q: Dictionary in ceilings:
					if absf(((above as Vector3) - (q.pos as Vector3)).dot(q.normal)) < 0.05 * size:
						pl = q
						break
		T = maxf(1.7, 3.0 - 0.08 * lv) * _rng.randf_range(0.9, 1.1)
		g = 0.6 * size
		crack = true
		m.n = (pl.normal as Vector3).normalized()
		start_p += m.n * float(m.r) * 0.2
	else:
		var gl := goal()
		var room_on := room()
		var dir: Vector3
		if spot.get("shower", false):
			var d0: Vector3 = F.shower_dir
			dir = d0.rotated(Vector3.UP, _rng.randf_range(-SHOWER_SPREAD, SHOWER_SPREAD))
		else:
			dir = RoomSpots.dir_at(Vector3.FORWARD, _rng.randf_range(-RoomSpots.ARC, RoomSpots.ARC))
		# Mixed reality: it lands on a spot of the room in front of the player and comes in
		# from beyond it, so it is seen coming from that side.
		var at: Variant = _spot_land(fy) if not spot.get("shower", false) else null
		if at != null:
			land = at as Vector3
			var out := Vector3(land.x - gl.x, 0, land.z - gl.z)
			dir = out.normalized() if out.length_squared() > 1e-4 else dir
			var lift := (viewer.y - fy + 8.0 * size) if room_on else (SKY_H * 0.5 + _rng.randf_range(0.0, 3.0)) * size
			start_p = land + Vector3.UP * lift + dir * 4.0 * size
		elif room_on:
			land = _room_land(fy)
			start_p = land + Vector3.UP * (viewer.y - fy + 8.0 * size) + dir * 4.0 * size
		else:
			land = gl + dir * maxf(_rng.randf_range(LAND_MIN, LAND_MAX) * size, near_d())
			land.y = fy
			var side := Vector3(-dir.z, 0, dir.x)
			var away: Vector3 = (F.shower_dir as Vector3) * 12.0 * size if spot.get("shower", false) else dir * _rng.randf_range(6.0, 14.0) * size + side * _rng.randf_range(-6.0, 6.0) * size
			start_p = land + away + Vector3.UP * (SKY_H + _rng.randf_range(0.0, 5.0)) * size
		if spot.get("shower", false):
			T *= 0.8
	land.y = fy
	# Ballistic: start + v T - g T² / 2 (down) = land.
	var v := (land - start_p) / T + Vector3(0, 0.5 * g * T, 0)
	if v.y > -0.3 * size:
		g = 0.0
		v = (land - start_p) / T
	m.c = start_p
	m.v = v
	m.g = g
	m.floor = fy
	m.land = land
	m.warn = T
	m.eta = T
	m.t = 0.0
	m.crack = {}
	if crack:
		m.phase = "crack"
		m.crack = _crater(start_p - m.n * float(m.r) * 0.15, m.n, float(m.r) * 1.7, 0.0, true)
		_sfx("thump", 0.6, start_p)
	else:
		m.phase = "fall"
		_sfx("whoosh", 0.35 + 0.25 * float(K.r), start_p)
	_place(m)
	return slot


func _setup(m: Dictionary, kind: String, golden: bool) -> void:
	var K: Dictionary = KINDS[kind]
	m.on = true
	m.kind = kind
	m.golden = golden
	m.r = float(K.r) * size
	m.emit = 0.0
	m.smoke = 0.0
	m.chain_t = -1.0
	m.chain_n = 0
	m.flash_t = 0.0
	m.wob = _rng.randf() * TAU
	m.seed = _rng.randf() * 20.0
	m.n = Vector3.DOWN
	if golden:
		m.style = "clay"
		m.color = GOLD
		m.fire = "ffc93a"
		m.acc = "crown"
	else:
		m.style = STYLES[_rng.randi() % STYLES.size()]
		m.color = COLORS[_rng.randi() % COLORS.size()]
		m.fire = FIRE[_rng.randi() % FIRE.size()]
		m.acc = ACCS[_rng.randi() % ACCS.size()]


# ---- hits ----

static func hittable(m: Dictionary) -> bool:
	return m.on and m.phase == "fall"


## Points (× the combo multiplier) with a floating label; count = a blast that feeds the combo.
func _score(base: int, at: Vector3, count: bool, col := Color("ffe08a")) -> int:
	if count:
		F.combo = F.combo + 1 if F.combo_t > 0.0 else 1
		F.combo_t = COMBO_T
		if ctx and int(F.combo) >= 2:
			ctx.ch_progress.call("combo10", int(F.combo))
		var before: int = F.mult
		F.mult = multiplier(F.combo)
		if F.mult > before and F.mult > 1:
			combo_label.text = ("COMBO ×%d!" % F.mult) if _en() else ("كومبو ×%s!" % GameCtx.ar_digits(F.mult))
			F.combo_show_t = 1.1
			F.combo_at = at
			_sfx("chime", 0.7, at)
			_buzz2(0.4, 50)
			if F.mult >= 3:
				_confetti(at, 0.7)
	var pts: int = base * int(F.mult)
	F.score += pts
	if ctx:
		ctx.counts["meteor"] = int(ctx.counts.get("meteor", 0)) + pts
	_pop_label(at, "+" + _num(pts), col if F.mult <= 1 else Color("ff8ad8"), 1.0 + 0.12 * (F.mult - 1))
	return pts


## A shot (or a thrown Dahrooj) hits meteor m: it splits, or bursts if it's a small one.
func hit(m: Dictionary, dir: Vector3) -> bool:
	if not hittable(m):
		return false
	explode(m, dir, 0)
	return true


## Meteor m blows up: points, a split into two smaller ones (only from a direct hit), or a
## firework; and it sets off the meteors near it (depth = links in the chain so far).
func explode(m: Dictionary, dir: Vector3, depth: int) -> void:
	var c: Vector3 = m.c
	var r: float = m.r
	var kind: String = m.kind
	var golden: bool = m.golden
	var K: Dictionary = KINDS[kind]
	# (the slot stays taken until the pieces have theirs)
	m.phase = ""
	(m.proxy as MeshInstance3D).visible = false
	F.popped += 1
	if golden:
		F.golden += 1
	var base: int = int(K.pts) * (GOLD_K if golden else 1) + CHAIN_PTS * depth
	var pts := _score(base, c + Vector3.UP * r, true, Color(GOLD) if golden else Color("ffe08a"))
	if ctx:
		ctx.ch_progress.call("meteor50", int(ctx.ch_state.get("meteor50", 0)) + 1)  # a running total across visits
	if depth > 0:
		F.chains += 1
		F.best_chain = maxi(F.best_chain, depth)
		combo_label.text = ("CHAIN ×%d!" % (depth + 1)) if _en() else ("سلسلة ×%s!" % GameCtx.ar_digits(depth + 1))
		F.combo_show_t = 1.1
		F.combo_at = c
	if golden:
		_pop_label(c + Vector3.UP * r * 2.2, ("SHINY! +%d" % pts) if _en() else ("لمّاع! +%s" % GameCtx.ar_digits(pts)), Color(GOLD), 1.4)
		_sfx("chime", 1.0, c)
		_buzz2(0.6, 80)
	else:
		_buzz2(0.3 + 0.1 * minf(depth, 3), 30)
	# The chain: everything close by goes off a moment later.
	for q in meteors:
		if not hittable(q) or float(q.chain_t) >= 0.0:
			continue
		if (q.c as Vector3).distance_to(c) < BLAST_R * size + float(q.r) + r * 0.5:
			q.chain_t = CHAIN_DELAY
			q.chain_n = depth + 1
			# A crackle of sparks along the way.
			var to: Vector3 = (q.c as Vector3) - c
			for i in 6:
				_fx(c + to * (i + 0.5) / 6.0, _rand_dir() * 0.6 * size, 0.35, _lin("fff0b0"), 0.14 * size, K_FLASH)
	var split: String = K.split
	if split != "" and depth == 0:
		_sfx("boom", 0.4 + 0.2 * float(K.r), c)
		_sfx("start_pop", 1.0, c)
		_blast(c, r, golden)
		var d := dir.normalized() if dir.length_squared() > 1e-6 else Vector3.FORWARD
		var side := d.cross(Vector3.UP)
		side = side.normalized() if side.length_squared() > 1e-4 else Vector3.RIGHT
		var up := side.cross(d).normalized()
		var tilt := _rng.randf() * TAU
		for s in [-1.0, 1.0]:
			var i := _free_slot()
			if i < 0:
				break
			var q: Dictionary = meteors[i]
			_setup(q, split, golden)
			var out: Vector3 = (side * cos(tilt) + up * sin(tilt)) * s
			q.c = c + out * r * 0.6
			q.v = (m.v as Vector3) * 0.7 + out * 3.6 * size + Vector3.UP * 2.2 * size + d * 1.0 * size
			q.g = maxf(float(m.g), GRAV * size * 0.8)
			q.floor = m.floor
			q.phase = "fall"
			q.t = 0.0
			q.crack = {}
			q.eta = predict_eta(q)
			q.warn = q.eta
			q.land = predict_land(q)
			q.flash_t = 0.15
			_place(q)
		m.on = false
	else:
		m.on = false
		_sfx("start_pop", 1.0, c)
		if depth > 0:
			_sfx("boom", minf(1.0, 0.45 + 0.15 * depth), c)
			_blast(c, r, golden)
		firework(c, golden, 1.0 if kind == "small" else 1.25)


## Seconds until m reaches the floor.
static func predict_eta(m: Dictionary) -> float:
	var h: float = float(m.c.y) - float(m.floor) - float(m.r) * 0.6
	var vy: float = m.v.y
	var g: float = m.g
	if h <= 0.0:
		return 0.0
	if g < 1e-4:
		return h / -vy if vy < -1e-4 else 99.0
	return (vy + sqrt(vy * vy + 2.0 * g * h)) / g


static func predict_land(m: Dictionary) -> Vector3:
	var t := predict_eta(m)
	var c: Vector3 = m.c
	var v: Vector3 = m.v
	return Vector3(c.x + v.x * t, float(m.floor), c.z + v.z * t)


## One reached the floor: a glowing crater, a shockwave, a dust cloud; the combo breaks, it
## takes GROUND_PENALTY points, and right at the player's feet LAND_PENALTY more.
func _impact(m: Dictionary) -> void:
	var r: float = m.r
	var p := Vector3(m.c.x, float(m.floor), m.c.z)
	m.phase = "land"
	m.t = 0.0
	m.c = p + Vector3.UP * r * 0.5
	(m.proxy as MeshInstance3D).visible = false
	F.landed += 1
	F.combo = 0
	F.mult = 1
	F.combo_t = 0.0
	_crater(p + Vector3.UP * 0.03 * size, Vector3.UP, r * 2.4, 1.0)
	_ring(p + Vector3.UP * 0.08 * size, Vector3.UP, r * 0.8, r * 6.0, 0.6, Color("ffcf8a"))
	_ring(p + Vector3.UP * 0.12 * size, Vector3.UP, r * 0.5, r * 3.6, 0.4, Color("ff7a3d") if not m.golden else Color(GOLD))
	_dust(p, Vector3.UP, 16 + int(10 * r / size), r / size)
	for _i in 18:
		var d := _rand_dir()
		d.y = absf(d.y) + 0.4
		_fx(p + Vector3.UP * r * 0.3, d * _rng.randf_range(3.0, 7.0) * size, _rng.randf_range(0.5, 0.9), _lin("ffd9a0"), 0.13 * size, K_EMBER, 9.0 * size, 0.6)
	_fx(p + Vector3.UP * r * 0.5, Vector3.ZERO, 0.3, _lin("ffd9a0"), r * 3.5, K_FLASH)
	_sfx("thump", 1.0, p)
	_sfx("boom", 0.35 + 0.35 * r / size, p)
	if ctx:
		ctx.nibble.call("meteor", int(GROUND_PENALTY.get(m.kind, 10)), p + Vector3.UP * r)
	if Vector2(p.x - viewer.x, p.z - viewer.z).length() < hit_r():
		_buzz2(0.2, 45)
		if ctx:
			ctx.penalty.call("meteor", LAND_PENALTY, p)


# ---- moving ----

func _step_meteor(m: Dictionary, dt: float) -> void:
	m.t += dt
	m.flash_t = maxf(0.0, m.flash_t - dt)
	match m.phase:
		"crack":
			var k := clampf(m.t / CRACK_T, 0.0, 1.0)
			var cq: Dictionary = m.crack
			if not cq.is_empty():
				cq.heat = k
			var n: Vector3 = m.n
			if _rng.randf() < 0.35:
				var b := MoleStage.basis_up(n)
				var a := _rng.randf() * TAU
				_fx((m.c as Vector3) + (b.x * cos(a) + b.z * sin(a)) * float(m.r) * _rng.randf_range(0.3, 1.4), Vector3.ZERO, _rng.randf_range(0.8, 1.3), _lin(DUST[_rng.randi() % DUST.size()], 0.7), 0.16 * size, K_SMOKE, 8.0 * size, 0.0)
			if k >= 1.0:
				m.phase = "fall"
				m.t = 0.0
				cq.heat = 1.0
				m.crack = {}
				_dust(m.c, n, 14, 0.8)
				for _i in 10:
					_fx(m.c, (n * 3.0 + _rand_dir() * 2.0) * size, 0.6, _lin("ffd9a0"), 0.14 * size, K_EMBER, 6.0 * size, 0.5)
				_sfx("boom", 0.5, m.c)
				_sfx("whoosh", 0.6, m.c)
		"fall":
			m.v.y -= float(m.g) * dt
			m.c += (m.v as Vector3) * dt
			m.eta = predict_eta(m)
			m.land = predict_land(m)
			_trail(m, dt)
			if m.chain_t >= 0.0:
				m.chain_t -= dt
				if m.chain_t < 0.0:
					explode(m, (m.v as Vector3).normalized(), int(m.chain_n))
					return
			if float(m.c.y) - float(m.r) * 0.6 <= float(m.floor) and m.v.y <= 0.0:
				_impact(m)
		"land":
			if m.t >= LAND_T:
				m.on = false
				m.phase = ""
	_place(m)


## Embers off its back, smoke from the big ones, glitter from the golden ones.
func _trail(m: Dictionary, dt: float) -> void:
	var K: Dictionary = KINDS[m.kind]
	var v: Vector3 = m.v
	var sp := v.length()
	var back := -v / sp if sp > 1e-4 else Vector3.UP
	var r: float = m.r
	var c: Vector3 = m.c
	m.emit += float(K.rate) * dt
	while m.emit >= 1.0:
		m.emit -= 1.0
		var j := _rand_dir() * r * 0.45
		var pv := back * sp * 0.12 + _rand_dir() * 0.7 * size
		if m.golden and _rng.randf() < 0.5:
			_fx(c + back * r * 0.7 + j, pv, _rng.randf_range(0.5, 0.9), _lin(["ffd23f", "fff3b0", "ffffff"][_rng.randi() % 3]), _rng.randf_range(0.08, 0.14) * size, K_GLITTER, 0.8 * size, 0.8)
		else:
			_fx(c + back * r * 0.8 + j, pv, _rng.randf_range(0.5, 0.9) * (0.7 + r / size * 0.4), Color(1, 1, 1), r * _rng.randf_range(0.45, 0.75), K_EMBER, -0.6 * size, 0.6)
	if m.kind == "big":
		m.smoke += 7.0 * dt
		while m.smoke >= 1.0:
			m.smoke -= 1.0
			_fx(c + back * r * 1.6 + _rand_dir() * r * 0.3, back * sp * 0.05 + Vector3.UP * 0.4 * size, _rng.randf_range(1.0, 1.6), _lin("7a6e66", 0.3), r * 0.7, K_SMOKE, -0.2 * size, 1.0)


func _place(m: Dictionary) -> void:
	var proxy: MeshInstance3D = m.proxy
	proxy.visible = hittable(m)
	if proxy.visible:
		var rr := maxf(float(m.r) * 1.4, 0.55 * size)
		proxy.transform = Transform3D(Basis.from_scale(Vector3.ONE * rr), m.c)


# ---- drawing ----

func draw() -> void:
	_fx_mat.set_shader_parameter("now", time)
	_dust_mat.set_shader_parameter("now", time)
	crowd.begin()
	var fire: MultiMesh = _mm.fire
	var halo: MultiMesh = _mm.halo
	var rings: MultiMesh = _mm.rings
	var discs: MultiMesh = _mm.discs
	var nf := 0
	var nh := 0
	var nr := 0
	var nd := 0
	for m in meteors:
		if not m.on:
			continue
		var c: Vector3 = m.c
		var r: float = m.r
		var golden: bool = m.golden
		if m.phase == "fall":
			var col := Color(m.color)
			if m.flash_t > 0.0:
				col = col.lerp(Color.WHITE, 0.7)
			var wob := sin(time * 7.0 + float(m.wob)) * 0.12
			crowd.add(m.style, c, r * 0.85, viewer + Vector3(wob * 4.0, 0, 0), Vector2(0.94, 1.08), "wide", m.acc, col)
			# The fire: its tail streams back along the way it came.
			var v: Vector3 = m.v
			var back := -v.normalized() if v.length_squared() > 1e-6 else Vector3.UP
			var up := Vector3.UP if absf(back.y) < 0.95 else Vector3.RIGHT
			var bx := up.cross(back).normalized()
			var by := back.cross(bx)
			var stretch := clampf(v.length() / (8.0 * size), 0.55, 1.3)
			var fs := r * 1.25
			fire.set_instance_transform(nf, Transform3D(Basis(bx * fs, by * fs, back * fs * stretch), c))
			fire.set_instance_color(nf, _lin(m.fire, 1.0 if not golden else 1.15))
			fire.set_instance_custom_data(nf, Color(float(m.seed), 0, 0, 0))
			nf += 1
			# Heat: a soft glow and a wavering shimmer around it.
			if nh + 2 <= HALO_MAX:
				var flick := 0.85 + 0.15 * sin(time * 23.0 + float(m.seed))
				_halo(halo, nh, c, r * 3.0 * flick, _lin("ffd27a" if golden else "ff8a3a", 0.5), K_GLOW)
				_halo(halo, nh + 1, c, r * 2.4, _lin("fff0d0", 0.5), K_SHIMMER)
				nh += 2
			# Where it will land: a target that tightens as it comes.
			if nr + 2 <= WARN_MAX:
				var land: Vector3 = m.land
				var k := 1.0 - clampf(float(m.eta) / minf(float(m.warn), 3.0), 0.0, 1.0)
				var wc := Color(GOLD) if golden else Color("ffb347").lerp(Color("ff2d3d"), k)
				var pulse := 0.55 + 0.45 * sin(time * (8.0 + 14.0 * k))
				var rw := r * 2.3
				var at := Vector3(land.x, float(m.floor) + 0.05 * size, land.z)
				rings.set_instance_transform(nr, Transform3D(Basis.from_scale(Vector3(rw, 1.4 * size, rw)), at))
				rings.set_instance_color(nr, Color(wc.srgb_to_linear(), 0.35 + 0.5 * k))
				var ri := lerpf(rw, r * 0.45, k)
				rings.set_instance_transform(nr + 1, Transform3D(Basis.from_scale(Vector3(ri, 1.4 * size, ri)), at + Vector3.UP * 0.01))
				rings.set_instance_color(nr + 1, Color(wc.srgb_to_linear(), (0.5 + 0.5 * k) * pulse))
				nr += 2
				discs.set_instance_transform(nd, Transform3D(Basis.from_scale(Vector3.ONE * rw), at - Vector3.UP * 0.01))
				discs.set_instance_color(nd, Color(wc.srgb_to_linear(), 0.08 + 0.22 * k))
				nd += 1
		elif m.phase == "land":
			# Dazed in its crater, sinking away.
			var k: float = clampf(float(m.t) / LAND_T, 0.0, 1.0)
			var sq := Vector2(1.0 + 0.25 * (1.0 - k), 0.75 - 0.15 * k)
			var rr: float = r * 0.8 * (1.0 - k * k)
			var fy: float = m.floor
			if rr > 0.01:
				crowd.add(m.style, Vector3(c.x, fy + rr * sq.y - r * 0.4 * k, c.z), rr, viewer, sq, "shut", m.acc, Color(m.color).darkened(0.25))
	crowd.end()
	fire.visible_instance_count = nf
	halo.visible_instance_count = nh
	discs.visible_instance_count = nd
	# Shockwaves.
	for g in _rings:
		if nr >= rings.instance_count:
			break
		var k: float = clampf(float(g.t) / float(g.life), 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 3.0)
		var rad: float = lerpf(g.r0, g.r1, e)
		var b := MoleStage.basis_up(g.n)
		rings.set_instance_transform(nr, Transform3D(b * Basis.from_scale(Vector3(rad, rad * 0.8, rad)), g.p))
		rings.set_instance_color(nr, Color((g.c as Color).srgb_to_linear(), 1.0 - k))
		nr += 1
	rings.visible_instance_count = nr
	# Craters (and cracks in the ceiling).
	var cm: MultiMesh = _mm.craters
	for i in craters.size():
		var q: Dictionary = craters[i]
		var t: float = q.t
		var grow := 1.0
		var heat: float = q.heat
		var fade := 1.0
		if q.crack and heat < 1.0 and t < CRACK_T + 0.1:
			grow = 0.25 + 0.75 * heat
		else:
			grow = MoleStage._back(clampf(t / 0.25, 0.0, 1.0)) if not q.crack else 1.0
			heat = float(q.heat) * exp(-t * 0.6)
			fade = clampf((CRATER_T - t) / 1.2, 0.0, 1.0)
		var b := MoleStage.basis_up(q.n).rotated(q.n, float(q.seed) * TAU)
		cm.set_instance_transform(i, Transform3D(b.scaled_local(Vector3.ONE * maxf(0.001, float(q.r) * grow)), q.p))
		cm.set_instance_color(i, Color(heat, fade, float(q.seed), 1.0))
	cm.visible_instance_count = craters.size()
	_draw_labels()


func _halo(mm: MultiMesh, i: int, p: Vector3, s: float, col: Color, kind: int) -> void:
	mm.set_instance_transform(i, Transform3D(Basis(Vector3(s, 0, 0), Vector3.ZERO, Vector3.ZERO), p))
	mm.set_instance_color(i, col)
	mm.set_instance_custom_data(i, Color(time - 0.001, 1e6, float(kind), 0.0))


func _draw_labels() -> void:
	var bt: float = F.banner_t
	banner.visible = bt > 0.0 and banner.text != ""
	banner_sub.visible = banner.visible and banner_sub.text != ""
	if banner.visible:
		var life: float = F.banner_life
		var age := maxf(0.0, life - bt)
		var inn := minf(1.0, age / 0.35)
		var over := 1.0 + 0.35 * sin(inn * PI) * (1.0 - inn * 0.5)
		var out := clampf((0.45 - bt) / 0.45, 0.0, 1.0)
		var bk := size * banner_k()
		var s := (0.3 + 0.7 * inn) * over * (1.0 + out * 0.4) * bk
		var at := banner_at()
		banner.position = at + Vector3.UP * out * 0.35 * bk
		banner.scale = Vector3.ONE * s
		banner.modulate.a = 1.0 - out
		banner_sub.position = at + Vector3(0, -1.05 * bk, 0) + Vector3.UP * out * 0.35 * bk
		banner_sub.scale = Vector3.ONE * minf(1.0, age / 0.5) * bk
		banner_sub.modulate.a = 1.0 - out
	var ct: float = F.combo_show_t
	combo_label.visible = ct > 0.0
	if combo_label.visible:
		var a := 1.1 - ct
		combo_label.position = (F.combo_at as Vector3) + Vector3.UP * (1.3 + a * 0.6) * size
		combo_label.scale = Vector3.ONE * size * (0.6 + 0.6 * minf(1.0, a * 6.0)) * (1.0 + 0.08 * sin(a * 30.0) * (1.0 - a)) * maxf(1.0, (F.combo_at as Vector3).distance_to(viewer) / (9.0 * size))
		combo_label.modulate.a = clampf(ct / 0.3, 0.0, 1.0)


# ---- stage interface ----

func collide(S: Ball) -> void:
	if not S.shot:
		return
	for m in meteors:
		if not hittable(m):
			continue
		var c: Vector3 = m.c
		var r: float = float(m.r) + Ball.BR
		if S.pos.distance_to(c) < r:
			F.touched = true
			var dir := S.vel.normalized() if S.vel.length_squared() > 0.0 else Vector3.FORWARD
			hit(m, dir)
			S.hit((S.pos - c).normalized(), S.vel.length() * 0.5, c)


func shoot(obj: Node, _point: Vector3, dir: Vector3) -> bool:
	var d := dir if dir != Vector3.ZERO else Vector3.FORWARD
	for m in meteors:
		if obj == m.proxy and m.on:
			return hit(m, d)
	if F.state == "idle":
		start()
	return false


func touched() -> bool:
	return F.touched


func on_throw() -> void:
	if F.state == "idle":
		start()


func on_respawn() -> void:
	F.touched = false


func deactivate() -> void:
	for m in meteors:
		m.on = false
		m.phase = ""
		(m.proxy as MeshInstance3D).visible = false
	JuiceText.clear(self)
	_rings.clear()
	craters.clear()
	F.state = "idle"
	F.t = 0.0
	F.score = 0
	F.combo = 0
	F.mult = 1
	F.combo_t = 0.0
	F.shower_on = 0.0
	F.banner_t = 0.0
	F.combo_show_t = 0.0
	F.touched = false
	# Old particles die out: move the clock past every life.
	time += 100.0
	draw()


func update(_b: Ball, dt: float) -> void:
	# Nothing moves while hidden or held by main.
	if not visible or paused:
		return
	time += dt
	_goal_s = _goal_s.lerp(Vector3(viewer.x, 0, viewer.z), 1.0 - exp(-dt * 3.0))
	F.banner_t = maxf(0.0, F.banner_t - dt)
	F.combo_show_t = maxf(0.0, F.combo_show_t - dt)
	if F.combo_t > 0.0:
		F.combo_t -= dt
		if F.combo_t <= 0.0:
			F.combo = 0
			F.mult = 1
	_room_t -= dt
	if _room_t <= 0.0:
		_room_t = 1.0
		_refresh_room()
	_step_spawns(dt)
	for m in meteors:
		if m.on:
			_step_meteor(m, dt)
	for i in range(_rings.size() - 1, -1, -1):
		_rings[i].t += dt
		if _rings[i].t >= _rings[i].life:
			_rings.remove_at(i)
	for i in range(craters.size() - 1, -1, -1):
		var q: Dictionary = craters[i]
		if q.crack and q.heat < 1.0:
			continue  # still cracking open
		q.t += dt
		if q.t >= CRATER_T:
			craters.remove_at(i)
	# Drawn about once a frame (update runs three times a frame).
	_draw_acc += dt
	if _draw_acc >= 0.0125:
		_draw_acc = 0.0
		draw()


## For tests and the HUD.
func meteor_state() -> Dictionary:
	var alive := 0
	for m in meteors:
		if m.on:
			alive += 1
	return {"state": F.state, "t": F.t, "level": level(), "score": F.score, "combo": F.combo, "mult": F.mult,
		"alive": alive, "falling": falling(), "popped": F.popped, "landed": F.landed, "fireworks": F.fireworks,
		"chains": F.chains, "showers": F.showers, "shower": F.shower_on > 0.0, "golden": F.golden}
