class_name GiantStage
extends Node3D
## Giant Dahrooj («الدحروج العملاق», mode "giant"): a house-sized Dahrooj (a DahroojView
## scaled up: the same body styles, big glossy 3D eyes, the drawn face, squash and stretch)
## fights you in phases, on and on, a little harder each time. Open play: no lives, no clock,
## no board; the points go to ctx.counts["giant"], which the jelly score popup shows.
##
## - Weak spots glow on him and glide over his body (eyes, bow, belly button, a sewn patch):
##   a shot or a thrown Dahrooj on one makes him flinch and wobble and knocks a chunk out of
##   the big hit-points ring around him (shots on the body only chip it).
## - Phases by what is left of the ring: (1) he bounces and stomps: dust rings, nearby props
##   jump, and each stomp's shockwave takes STOMP_PENALTY points (a little one left unpopped
##   until it gives up takes ESCAPE_PENALTY); (2) he spits waves of little Dahroojs at you: pop them (if one reaches you it
##   bounces off, the combo breaks and it takes MINION_PENALTY points off the score); (3) he melts into slime and splits into three medium
##   ones that merge back later; (4) rage: red glow, faster, more spots. The three stay
##   hidden while he collapses, then pop up out of the top of the puddle (small, growing on
##   the way out); merging back, each one splashes into him as it reaches the puddle, and
##   none is left by the time he stands up again (never inside or under him, at any size).
## - Ring empty: a huge knock-out (spin, dizzy stars, he topples over, a confetti storm,
##   fireworks), then he comes back bigger, in a new colour and accessory ("Giant Lv.2").
## - Mixed reality: he stands where the court was pinned (the anchor: game (0, floor, aim_z)),
##   straight ahead of the player along the court's forward (game -Z), pushed back along it
##   until his near side is MIN_DIST metres away; a new pin moves him (on_placed()). With a
##   scan (planes_provider returns the room's planes, game units, as main gives the slime
##   stage: {pos, normal, ax, ay, half, label}) and a wall right behind that spot, he knocks
##   and bulges it, cracks it open and squeezes in through the hole; otherwise he drops from
##   the sky there. He fits under the scanned ceiling (hops too). VR: the court layout.
## Every effect is a MultiMesh or a JuiceText, so shots pass through them; the blaster finds the
## weak spots and the little ones through hidden (layers = 0) spheres, and the big bodies
## through their own meshes. Game units, like the other stages.

const R_BASE := 5.2  # the giant's radius at Lv.1 (× size)
const R_LV := 0.5  # bigger each level
const R_MAX := 8.2
const HOME_Z := -18.0  # where he stands on the court (VR)
const HP_BASE := 100.0
const HP_LV := 25.0
const SPOT_DMG := 6.0
const MED_DMG := 5.0
const BODY_DMG := 0.35
const BALL_DMG := 3.0
const BALL_SPOT_DMG := 10.0
const POP_DMG := 1.0
const PHASE_AT := [0.75, 0.5, 0.25]
const G_GRAV := 26.0
const SPLIT_T := 11.0
const OUT_K := 0.35  # how small a medium one is as it pops out of the puddle
const WHOLE_T := 7.0
const KO_T := 4.9
const ENTER_DROP := 30.0
const SEGS := 56
const ARC := 4.887  # the ring's sweep (280°)
const MINIONS := 28
const MIN_R := 0.42
const NEAR_MIN := 1.2  # metres to his near side at the very least (mixed reality, a small room)
const REACH := 1.6
## Points a little one that reaches you takes off the score (ctx.penalty: never below 0).
const MINION_PENALTY := 25
## Points his stomp (a big hop landing: the shockwave rolls out to you) takes off the score, and
## a little one that hops about unpopped until it gives up (ctx.nibble, the light touch).
const STOMP_PENALTY := 15
const ESCAPE_PENALTY := 5
const COMBO_T := 1.8
const COMBO_STEPS := [3, 6, 10, 15]
const BANNER_T := 2.4
const SPARKS_MAX := 520
const RINGS_MAX := 16
const PUFFS_MAX := 72
const DEBRIS_MAX := 96
const CHUNKS_MAX := 48
const STARS_MAX := 20
const PROPS := 12
const SPOT_KEYS := ["eye_l", "eye_r", "bow", "belly", "patch"]
const SPOT_SIZE := {"eye_l": 1.25, "eye_r": 1.25, "bow": 1.1, "belly": 0.95, "patch": 1.05}
const SPOT_PTS := {"eye_l": 15, "eye_r": 15, "bow": 10, "belly": 10, "patch": 10}
## Each level's look: [style, colour id, accessory].
const LOOKS := [["fur", "pink", ""], ["jelly", "blue", "crown"], ["fur", "green", "starGlasses"],
	["jelly", "orange", "party"], ["fur", "purple", "aviator"], ["jelly", "red", "headphones"],
	["fur", "yellow", "scarf"], ["jelly", "green", "beanie"], ["fur", "blue", "woodhat"], ["jelly", "purple", "flower"]]
const MIN_COLORS := ["ff69b4", "b36bff", "ff9b3d", "6fa8d6", "7bbf8a", "e2603f", "ffd166", "46aaa9", "58b9ff", "ff505c"]
const MIN_ACCS := ["", "", "party", "glasses", "cap", "flower", "headphones", "scarf", "crown"]
const MIN_STYLES := ["jelly", "fur", "clay", "fabric", "bubble", "jelly", "fur"]
const FW_COLORS := ["ff4d6d", "ffd23f", "5dff8a", "58b9ff", "c77dff", "ff9b3d", "ffffff"]
const DUST := Color("efe0c2")
const PLASTER := Color("e9e3d8")

static var _meshes := {}

var aim_z := -10.0
## The court runs out past him; the player stands near (as Dahrooj Attack: reach_z = aim_z).
var far_z = -30.0
var reach_z = -10.0
var friction = null
var shot_time = 4.0
var ctx: GameCtx

## The room's planes (mixed reality), game units: Array of {pos, normal, ax, ay, half, label}
## (main's slime provider). Unset or empty: the court.
var planes_provider: Callable
## Mixed reality (as MoleStage.spots_provider): main's room spots. He does not take his place
## from them (he stands at the pinned court, see the header); a provider that gives spots
## only says the game is played in the room (no scan: the sky drop at the court). Unset or
## empty, and no planes: the court (VR).
var spots_provider: Callable
## Mixed reality: (p, r, prev, goal, mem) -> p kept out of the real furniture (main.furniture_push), game
## units; unset in VR.
var furniture: Callable
## His clock against the game's (main: the same calm real-time pace in VR and mixed reality,
## where the game's time runs fast for the small falling balls).
var pace := 1.0
## Game units per metre (main: the court's scale), for the distance kept from the player.
var unit := 2.0
## Size of the little ones, props and effects (mixed reality wants them bigger; main: 2).
var size := 1.0
## The player's eye (game units). Main keeps it current.
var viewer := Vector3(0, 3.2, 1.0)
## buzz(hand: String, amp: float, ms: float): haptics.
var buzz: Callable
## Main holds the game while the menu is open or the court is being placed.
var paused := false
## He picks his own moves (tests turn it off and drive him).
var auto_play := true
var time := 0.0

var F := {"state": "idle", "t": 0.0, "lv": 1, "hp": HP_BASE, "max_hp": HP_BASE, "phase": 1,
	"split": "", "split_t": 0.0, "whole_t": 0.0, "combo": 0, "combo_t": 0.0, "mult": 1, "score": 0,
	"hits": 0, "kos": 0, "pops": 0, "bounced": 0, "touched": false, "throw_live": false, "throw_hits": 0,
	"ball_t": 0.0, "banner_t": 0.0, "banner_life": BANNER_T, "combo_show_t": 0.0, "combo_at": Vector3.ZERO,
	"enter": "", "fw_t": 0.0, "fw_n": 0, "conf_t": 0.0, "steam_t": 0.0, "ko_land": false, "ko_pop": false, "spin_from": 0.0}
var giant: Dictionary
var meds: Array = []
var minions: Array = []
var props: Array = []
var crowd: Crowd
## Where he stands and what the room allows (see _layout()).
var room := {"floor": 0.0, "ceil": INF, "wall": {}, "home": Vector3(0, 0, HOME_Z), "side": Vector3.RIGHT,
	"lane": 3.0, "max_h": INF, "planes": false, "r": R_BASE}
## The hole in the wall he comes in through (mixed reality).
var breach := {"on": false, "p": Vector3.ZERO, "n": Vector3.BACK, "bulge": 0.0, "crack": 0.0, "hole": 0.0, "r": 1.0, "spin": 0.0, "jolt": 0.0}
var banner: JuiceText
var banner_sub: JuiceText
var combo_label: JuiceText
var lv_label: JuiceText
var _sparks: Array = []
var _rings: Array = []
var _puffs: Array = []
var _debris: Array = []
var _chunks: Array = []
var _rockets: Array = []
var _mm := {}
var _ring_c := Vector3.ZERO
var _ring_r := 5.0
var _ring_fb := Basis.IDENTITY
var _shown_hp := 1.0
var _ghost := 1.0
var _draw_acc := 0.0
var _room_t := 0.0
var _glitter := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 5150
	name = "Giant"
	giant = _make_body("Giant", 3, true)
	for i in 3:
		meds.append(_make_body("Medium%d" % i, 1, false))
	crowd = Crowd.new(MINIONS, true, true)
	crowd.name = "LittleOnes"
	add_child(crowd)
	for i in MINIONS:
		minions.append({"on": false, "p": Vector3.ZERO, "v": Vector3.ZERO, "r": MIN_R, "ph": "", "t": 0.0, "life": 0.0,
			"bounces": 0, "style": "jelly", "color": "ff69b4", "acc": "", "proxy": _proxy("LittleHit%d" % i),
			"hop_p": 0.5, "flash": 0.0, "zig": 0.0})
	_mm.shells = _multi("Glow", Crowd.merge([[Crowd.sphere(1.0, 24, 16), Transform3D.IDENTITY, Color.WHITE]]), _shell_mat(), 12)
	_mm.targets = _multi("Spots", target_mesh(), _mat("glow"), 6)
	_mm.ripples = _multi("SpotRipples", ripple_mesh(), _mat("glow"), 6)
	_mm.patches = _multi("Patches", patch_mesh(), _mat("lit"), 4)
	_mm.mouths = _multi("Mouths", mouth_mesh(), _mat("lit"), 4)
	_mm.segs = _multi("HpRing", Crowd.merge([[Crowd.box(1.0, 1.0, 1.0), Transform3D.IDENTITY, Color.WHITE]]), _mat("glow"), SEGS * 2 + 2)
	_mm.chunks = _multi("HpChunks", Crowd.merge([[Crowd.box(1.0, 1.0, 1.0), Transform3D.IDENTITY, Color.WHITE]]), _mat("glow"), CHUNKS_MAX)
	_mm.sparks = _multi("Sparks", Crowd.merge([[Crowd.sphere(1.0, 6, 4), Transform3D.IDENTITY, Color.WHITE]]), _mat("glow"), SPARKS_MAX)
	_mm.rings = _multi("Rings", Crowd.merge([[Crowd.torus(1.0, 0.05, 6, 56), Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO), Color.WHITE]]), _mat("glow"), RINGS_MAX)
	_mm.puffs = _multi("Dust", Crowd.merge([[Crowd.sphere(1.0, 10, 6), Transform3D.IDENTITY, Color.WHITE]]), _mat("puff"), PUFFS_MAX)
	_mm.debris = _multi("Debris", Crowd.merge([[Crowd.box(1.0, 0.7, 0.9), Transform3D.IDENTITY, Color.WHITE]]), _mat("lit"), DEBRIS_MAX)
	_mm.stars = _multi("Stars", MoleStage.star_mesh(), _mat("star"), STARS_MAX)
	_mm.shadows = _multi("Shadows", Crowd.merge([[Crowd.circle(1.0, 32), Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3.ZERO), Color.WHITE]]), _mat("shadow"), 4 + MINIONS)
	_mm.shadows.mesh = null  # no blob shadows in any mode (owner's call)
	_mm.crate = _multi("Crates", prop_mesh("crate"), _mat("lit"), PROPS)
	_mm.barrel = _multi("Barrels", prop_mesh("barrel"), _mat("lit"), PROPS)
	_mm.cone = _multi("Cones", prop_mesh("cone"), _mat("lit"), PROPS)
	_mm.bulge = _multi("WallBulge", Crowd.merge([[Crowd.sphere(1.0, 24, 12, 0.0, TAU, 0.0, PI / 2.0), Transform3D.IDENTITY, PLASTER]]), _mat("lit"), 1)
	_mm.cracks = _multi("WallCracks", crack_mesh(), _mat("flat"), 1)
	_mm.hole = _multi("WallHole", breach_mesh(), _mat("lit"), 1)
	banner = _label("banner", 210, Color("ffd166"))
	banner_sub = _label("sub", 96, Color("fff3e0"))
	combo_label = _label("combo", 150, Color("ff7ad9"))
	lv_label = _label("sub", 110, Color("fff3e0"))
	draw()


# ---- art ----

func _label(kind: String, font_size: int, col: Color) -> JuiceText:
	var l := JuiceText.make(kind, font_size * 0.006)
	if kind != "combo":
		l.modulate = col
	add_child(l)
	return l


func _proxy(id: String) -> MeshInstance3D:
	var proxy := MeshInstance3D.new()
	proxy.name = id
	if not _meshes.has("proxy"):
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 12
		s.rings = 6
		_meshes["proxy"] = s
	proxy.mesh = _meshes["proxy"]
	proxy.layers = 0  # never drawn: only the blaster's ray sees it
	proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	proxy.visible = false
	add_child(proxy)
	return proxy


func _make_body(id: String, n_spots: int, big: bool) -> Dictionary:
	var v := DahroojView.new(1.0)
	v.name = id
	v.visible = false
	add_child(v)
	var spots := []
	for i in n_spots:
		spots.append({"on": false, "key": "", "from": Vector3.BACK, "to": Vector3.BACK, "mt": 1.0, "dwell": 2.0, "cd": 0.0,
			"proxy": _proxy("%sSpot%d" % [id, i]), "at": Vector3.ZERO, "n": Vector3.BACK, "rad": 0.0, "hit_t": 9.0})
	return {"id": id, "on": false, "big": big, "view": v, "c": Vector3.ZERO, "g": Vector3.ZERO, "r": 1.0, "k": 1.0,
		"y": 0.0, "vy": 0.0, "hv": Vector3.ZERO, "air": false, "free": false, "axis": Vector3.UP,
		"s": 1.0, "sv": 0.0, "s_to": 1.0, "sx_k": 1.0, "melt": 0.0, "wob": Vector3.ZERO, "wobv": Vector3.ZERO,
		"spin": 0.0, "tilt": 0.0, "fwd": Vector3.BACK, "act": "", "act_t": 0.0, "act_cd": 1.2, "hop_h": 0.0,
		"spit_n": 0, "spit_i": 0, "face": "open", "face_t": 0.0, "blink": 0.0, "blink_t": 1.5, "look": Vector2.ZERO,
		"look_to": Vector2.ZERO, "look_t": 0.4, "eye_pop": 0.0, "flash": 0.0, "glow": 0.0, "dizzy": 0.0,
		"spots": spots, "solid": false, "base": Vector3.ZERO, "base_to": Vector3.ZERO, "land": "", "mouth": 0.0, "mouth_to": 0.0}


static func _mat(key: String) -> Material:
	if _meshes.has("mat_" + key):
		return _meshes["mat_" + key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	match key:
		"glow", "flat", "star", "puff":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			if key != "flat":
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			if key == "star" or key == "glow":
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"shadow":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.render_priority = -1
		"lit":
			m.roughness = 0.85
	_meshes["mat_" + key] = m
	return m


## The glow around him (rage red, the white hit flash, the slime sheen): an additive rim.
static func _shell_mat() -> ShaderMaterial:
	if not _meshes.has("mat_shell"):
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
void fragment() {
	float f = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = COLOR.rgb * (0.12 + pow(f, 1.4) * 1.8) * COLOR.a;
}
"""
		var m := ShaderMaterial.new()
		m.shader = sh
		_meshes["mat_shell"] = m
	return _meshes["mat_shell"]


func _multi(id: String, mesh: Mesh, mat: Material, cap: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = cap
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.name = id
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-80, -20, -80), Vector3(160, 100, 160))
	add_child(mi)
	return mm


## Adds a triangle wound so its front faces the normals (Godot's front faces wind clockwise).
static func _tri(st: SurfaceTool, p: Array, n: Array, c: Array) -> void:
	var order := [0, 1, 2]
	if ((p[1] as Vector3) - p[0]).cross((p[2] as Vector3) - p[0]).dot((n[0] as Vector3) + n[1] + n[2]) > 0.0:
		order = [0, 2, 1]
	for k in order:
		st.set_color(c[k])
		st.set_normal(n[k])
		st.add_vertex(p[k])


## A point on a sphere of radius rad around +Z: th from +Z, ph around it.
static func _cap(th: float, ph: float, rad: float) -> Vector3:
	return Vector3(sin(th) * cos(ph), sin(th) * sin(ph), cos(th)) * rad


static func _cap_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	_tri(st, [a, b, c], [a.normalized(), b.normalized(), c.normalized()], [col, col, col])
	_tri(st, [a, c, d], [a.normalized(), c.normalized(), d.normalized()], [col, col, col])


## A band on the unit sphere around +Z from angle t0 to t1.
static func _band(st: SurfaceTool, t0: float, t1: float, rad: float, col: Color, seg := 40) -> void:
	for i in seg:
		var p0 := TAU * i / seg
		var p1 := TAU * (i + 1) / seg
		_cap_quad(st, _cap(t0, p0, rad), _cap(t0, p1, rad), _cap(t1, p1, rad), _cap(t1, p0, rad), col)


## A weak spot: a target that hugs the body (rings, four ticks and a dot), unit sphere, +Z.
static func target_mesh() -> ArrayMesh:
	if _meshes.has("target"):
		return _meshes["target"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rad := 1.03
	var w := Color.WHITE
	_band(st, 0.0, 0.055, rad, w, 16)
	_band(st, 0.055, 0.1, rad * 0.999, Color(1, 1, 1, 0.3))
	_band(st, 0.1, 0.14, rad, w)
	_band(st, 0.14, 0.19, rad * 0.999, Color(1, 1, 1, 0.3))
	_band(st, 0.19, 0.27, rad, w)
	for k in 4:
		var ph := TAU * k / 4.0 + PI / 4.0
		var dp := 0.16
		_cap_quad(st, _cap(0.27, ph - dp * 0.5, rad), _cap(0.27, ph + dp * 0.5, rad), _cap(0.34, ph + dp * 0.25, rad), _cap(0.34, ph - dp * 0.25, rad), w)
	var mesh := st.commit()
	_meshes["target"] = mesh
	return mesh


## The ripple a weak spot sends out (one ring, unit sphere, +Z).
static func ripple_mesh() -> ArrayMesh:
	if _meshes.has("ripple"):
		return _meshes["ripple"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_band(st, 0.24, 0.27, 1.035, Color.WHITE)
	var mesh := st.commit()
	_meshes["ripple"] = mesh
	return mesh


## His open mouth (unit sphere, +Z, about 0.2 across): dark inside, a tongue, a rim.
## Stretched per frame for how wide it opens.
static func mouth_mesh() -> ArrayMesh:
	if _meshes.has("mouth"):
		return _meshes["mouth"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rad := 1.009
	var inside := Color("3a1424").srgb_to_linear()
	var tongue := Color("ff6f8e").srgb_to_linear()
	var rim := Color("2c2d3d").srgb_to_linear()
	var at := func(x: float, y: float, lift: float) -> Vector3:
		return Vector3(x, y, sqrt(maxf(0.0, 1.0 - x * x - y * y))).normalized() * (rad + lift)
	var seg := 28
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var e0 := Vector2(cos(a0), sin(a0)) * 0.1
		var e1 := Vector2(cos(a1), sin(a1)) * 0.1
		_cap_quad(st, at.call(0.0, 0.0, 0.0), at.call(0.0, 0.0, 0.0), at.call(e1.x, e1.y, 0.0), at.call(e0.x, e0.y, 0.0), inside)
		_cap_quad(st, at.call(e0.x, e0.y, 0.001), at.call(e1.x, e1.y, 0.001), at.call(e1.x * 1.14, e1.y * 1.14, 0.001), at.call(e0.x * 1.14, e0.y * 1.14, 0.001), rim)
	# The tongue: a soft lump in the lower part.
	for i in seg:
		var a0 := PI + PI * i / seg
		var a1 := PI + PI * (i + 1) / seg
		var e0 := Vector2(cos(a0) * 0.065, -0.045 + sin(a0) * 0.045)
		var e1 := Vector2(cos(a1) * 0.065, -0.045 + sin(a1) * 0.045)
		_cap_quad(st, at.call(0.0, -0.045, 0.0005), at.call(0.0, -0.045, 0.0005), at.call(e1.x, e1.y, 0.0005), at.call(e0.x, e0.y, 0.0005), tongue)
	var mesh := st.commit()
	_meshes["mouth"] = mesh
	return mesh


## A sewn denim patch with white stitches and a cross (unit sphere, +Z). Vertex colours.
static func patch_mesh() -> ArrayMesh:
	if _meshes.has("patch"):
		return _meshes["patch"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rad := 1.012
	var denim := Color("4c76b8").srgb_to_linear()
	var thread := Color("f6ecd6").srgb_to_linear()
	var h := 0.17
	var at := func(x: float, y: float, lift: float) -> Vector3:
		return Vector3(x, y, sqrt(maxf(0.0, 1.0 - x * x - y * y))).normalized() * (rad + lift)
	# The cloth: a grid so it follows the curve.
	var n := 6
	for i in n:
		for j in n:
			var x0 := -h + 2.0 * h * i / n
			var x1 := -h + 2.0 * h * (i + 1) / n
			var y0 := -h + 2.0 * h * j / n
			var y1 := -h + 2.0 * h * (j + 1) / n
			_cap_quad(st, at.call(x0, y0, 0.0), at.call(x1, y0, 0.0), at.call(x1, y1, 0.0), at.call(x0, y1, 0.0), denim)
	# Stitches round the edge.
	var e := h * 0.82
	for side in 4:
		for k in 5:
			var u := -e + 2.0 * e * (k + 0.25) / 5.0
			var v := u + 2.0 * e * 0.5 / 5.0
			var a: Vector3
			var b: Vector3
			match side:
				0:
					a = Vector3(u, -e, 0); b = Vector3(v, -e, 0)
				1:
					a = Vector3(e, u, 0); b = Vector3(e, v, 0)
				2:
					a = Vector3(-u, e, 0); b = Vector3(-v, e, 0)
				_:
					a = Vector3(-e, -u, 0); b = Vector3(-e, -v, 0)
			var d := (b - a).normalized()
			var nn := Vector3(-d.y, d.x, 0) * 0.012
			_cap_quad(st, at.call(a.x - nn.x, a.y - nn.y, 0.004), at.call(b.x - nn.x, b.y - nn.y, 0.004),
				at.call(b.x + nn.x, b.y + nn.y, 0.004), at.call(a.x + nn.x, a.y + nn.y, 0.004), thread)
	# The cross in the middle.
	for s in [-1.0, 1.0]:
		var a := Vector3(-0.07, -0.07 * s, 0)
		var b := Vector3(0.07, 0.07 * s, 0)
		var d := (b - a).normalized()
		var nn := Vector3(-d.y, d.x, 0) * 0.016
		_cap_quad(st, at.call(a.x - nn.x, a.y - nn.y, 0.006), at.call(b.x - nn.x, b.y - nn.y, 0.006),
			at.call(b.x + nn.x, b.y + nn.y, 0.006), at.call(a.x + nn.x, a.y + nn.y, 0.006), thread)
	var mesh := st.commit()
	_meshes["patch"] = mesh
	return mesh


## The court's props (bottom at the origin, about a unit tall): crate, barrel, traffic cone.
static func prop_mesh(kind: String) -> ArrayMesh:
	if _meshes.has("prop_" + kind):
		return _meshes["prop_" + kind]
	var list := []
	match kind:
		"crate":
			list.append([Crowd.box(1.0, 1.0, 1.0), Crowd.xf(Vector3(0, 0.5, 0)), Color("c08a52")])
			for y in [0.06, 0.94]:
				list.append([Crowd.box(1.04, 0.12, 1.04), Crowd.xf(Vector3(0, y, 0)), Color("7d5230")])
			for x in [-0.46, 0.46]:
				for z in [-0.46, 0.46]:
					list.append([Crowd.box(0.12, 1.0, 0.12), Crowd.xf(Vector3(x, 0.5, z)), Color("7d5230")])
			list.append([Crowd.box(1.02, 0.1, 1.02), Crowd.xf(Vector3(0, 0.5, 0)), Color("9a693d")])
		"barrel":
			list.append([Crowd.cylinder(0.4, 0.4, 1.0, 16), Crowd.xf(Vector3(0, 0.5, 0)), Color("d8543c")])
			for y in [0.18, 0.82]:
				list.append([Crowd.cylinder(0.42, 0.42, 0.08, 16), Crowd.xf(Vector3(0, y, 0)), Color("3a3d4a")])
			list.append([Crowd.cylinder(0.36, 0.36, 0.02, 16), Crowd.xf(Vector3(0, 1.0, 0)), Color("b4432f")])
		"cone":
			list.append([Crowd.box(0.8, 0.08, 0.8), Crowd.xf(Vector3(0, 0.04, 0)), Color("2e2f3a")])
			list.append([Crowd.cylinder(0.05, 0.3, 0.92, 16), Crowd.xf(Vector3(0, 0.54, 0)), Color("ff7a1a")])
			list.append([Crowd.cylinder(0.17, 0.215, 0.16, 16), Crowd.xf(Vector3(0, 0.5, 0)), Color("fbfbf4")])
	var mesh := Crowd.merge(list)
	_meshes["prop_" + kind] = mesh
	return mesh


## Cracks running out from the bulge (flat, +Y out of the wall, unit radius ~ 1.9).
static func crack_mesh() -> ArrayMesh:
	if _meshes.has("cracks"):
		return _meshes["cracks"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var c := Color("3b332c")
	var up := [Vector3.UP, Vector3.UP, Vector3.UP]
	var cs := [c, c, c]
	var y := Vector3.UP * 0.01
	for i in 9:
		var a := TAU * (i + rng.randf_range(-0.3, 0.3)) / 9.0
		var p := Vector3(cos(a), 0, sin(a)) * 0.35
		var dir := Vector3(cos(a), 0, sin(a))
		var w := 0.07
		for k in 4:
			dir = dir.rotated(Vector3.UP, rng.randf_range(-0.5, 0.5))
			var q := p + dir * rng.randf_range(0.3, 0.45)
			var side := Vector3(-dir.z, 0, dir.x)
			_tri(st, [p - side * w + y, p + side * w + y, q - side * w * 0.6 + y], up, cs)
			_tri(st, [p + side * w + y, q + side * w * 0.6 + y, q - side * w * 0.6 + y], up, cs)
			if k == 1 and i % 2 == 0:
				var bd := dir.rotated(Vector3.UP, 0.9)
				_tri(st, [q - side * 0.03 + y, q + side * 0.03 + y, q + bd * 0.4 + y], up, cs)
			p = q
			w *= 0.65
	var mesh := st.commit()
	_meshes["cracks"] = mesh
	return mesh


## The broken wall: a dark jagged hole, a lip of broken plaster and cracks (+Y out, unit radius).
static func breach_mesh() -> ArrayMesh:
	if _meshes.has("breach"):
		return _meshes["breach"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var seg := 28
	var jag := []
	for i in seg:
		jag.append(rng.randf_range(0.82, 1.08))
	var dark := Color("0b0807")
	var deep := Color("1d1612")
	var lip := Color("d3c9b8")
	var lip2 := Color("978b7a")
	var up := Vector3.UP
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var r0: float = jag[i]
		var r1: float = jag[(i + 1) % seg]
		# The dark inside.
		_tri(st, [Vector3(0, 0.005, 0), d0 * r0 * 0.6 + up * 0.005, d1 * r1 * 0.6 + up * 0.005], [up, up, up], [dark, dark, dark])
		_tri(st, [d0 * r0 * 0.6 + up * 0.005, d0 * r0 + up * 0.005, d1 * r1 + up * 0.005], [up, up, up], [deep, deep, deep])
		_tri(st, [d0 * r0 * 0.6 + up * 0.005, d1 * r1 + up * 0.005, d1 * r1 * 0.6 + up * 0.005], [up, up, up], [deep, deep, deep])
		# A broken lip of plaster, raised a little.
		var o0 := d0 * (r0 + 0.16 + 0.08 * sin(a0 * 5.0)) + up * 0.012
		var o1 := d1 * (r1 + 0.16 + 0.08 * sin(a1 * 5.0)) + up * 0.012
		var i0 := d0 * r0 + up * 0.06
		var i1 := d1 * r1 + up * 0.06
		var nl := (up + d0 * 0.4).normalized()
		_tri(st, [i0, o0, o1], [nl, nl, nl], [lip2, lip, lip])
		_tri(st, [i0, o1, i1], [nl, nl, nl], [lip2, lip, lip2])
	var mesh := crack_mesh()
	var arrays := mesh.surface_get_arrays(0)
	var pv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var pc: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for i in pv.size():
		st.set_color(pc[i])
		st.set_normal(Vector3.UP)
		st.add_vertex(pv[i] * 1.25 + Vector3.UP * 0.004)
	var out := st.commit()
	_meshes["breach"] = out
	return out


# ---- ctx ----

func _en() -> bool:
	return ctx != null and ctx.lang == "en"


func _tx(ar: String, en: String) -> String:
	return en if _en() else ar


func _num(v: int) -> String:
	return str(v) if _en() else GameCtx.ar_digits(v)


func _sfx(n: String, k: float, p: Vector3) -> void:
	if ctx:
		ctx.sfx.call(n, k, p)


func _confetti(at: Vector3, k := 1.0) -> void:
	if ctx:
		ctx.confetti.call(at, 1.4 * k * size, 1.6, maxf(1.0, at.distance_to(viewer) / 7.0))


func _buzz2(amp: float, ms: float) -> void:
	if buzz.is_valid():
		buzz.call("left", amp, ms)
		buzz.call("right", amp, ms)


# ---- the room ----

func _planes() -> Array:
	if planes_provider.is_valid():
		var p = planes_provider.call()
		if p is Array:
			return p
	return []


## The giant's radius this level (before the room's limits).
func want_r(lv: int) -> float:
	return minf(R_BASE + R_LV * (lv - 1), R_MAX) * size


## Where he stands and how big he may be. VR: on the court (HOME_Z). Mixed reality: at the
## pinned court (the anchor, game (0, floor, aim_z)), along the court's forward (game -Z)
## from there until his near side is RoomSpots.MIN_DIST from the player and he is in the
## forward arc; in front of a scanned wall right behind that spot (he breaks in through it),
## else he drops from the sky there. Never outside the room: when the wall along that line is
## nearer, he stands inside it with clearance, smaller, and if need be nearer than 2 m (never
## under NEAR_MIN to his near side). Under the ceiling.
func _layout() -> void:
	var pl := _planes()
	var fl := INF
	var ce := INF
	for p: Dictionary in pl:
		var n: Vector3 = p.get("normal", Vector3.UP)
		var y: float = (p.get("pos", Vector3.ZERO) as Vector3).y
		var label := str(p.get("label", ""))
		if label == "floor" or (label == "" and n.y > 0.9):
			fl = minf(fl, y)
		elif label == "ceiling" or n.y < -0.9:
			ce = minf(ce, y)
	room.floor = fl if fl < INF else 0.0
	room.ceil = ce if ce < INF and ce > room.floor + 2.0 * size else INF
	room.planes = not pl.is_empty()
	room.wall = {}
	var r := want_r(F.lv)
	if room.ceil < INF:
		r = minf(r, (room.ceil - room.floor) * 0.36)
	var mr: bool = room.planes or not RoomSpots.ask(spots_provider, ["wall"]).is_empty()
	if not mr:
		room.home = Vector3(0, room.floor, HOME_Z)
		room.side = Vector3.RIGHT
		room.lane = r * 0.9
		room.r = r
		room.max_h = INF if room.ceil == INF else maxf(0.08 * r, room.ceil - room.floor - 2.45 * r)
		return
	var fwd := Vector3.FORWARD
	var near := RoomSpots.MIN_DIST * unit
	var anchor := Vector3(0, room.floor, aim_z)
	var eye := Vector3(viewer.x, room.floor, viewer.z)
	# The wall straight ahead behind the anchor (facing the player), if the scan has one.
	var wall := {}
	var wall_s := INF  # along fwd from the anchor to the wall
	for p: Dictionary in pl:
		var n: Vector3 = p.get("normal", Vector3.UP)
		if absf(n.y) > 0.3 or not p.has("half") or str(p.get("label", "")) in ["door_frame", "window_frame"]:
			continue
		var nh := Vector3(n.x, 0, n.z).normalized()
		if nh.dot(-fwd) < 0.5:
			continue
		var den := fwd.dot(nh)
		var s0 := ((p.pos as Vector3) - anchor).dot(nh) / den
		var q := anchor + fwd * s0
		var tang := Vector3.UP.cross(nh).normalized()
		var half: Vector2 = p.half
		var hx: float = half.x if absf((p.get("ax", Vector3.RIGHT) as Vector3).y) < 0.5 else half.y
		if absf((q - (p.pos as Vector3)).dot(tang)) > hx + 0.3 * unit or (eye - q).dot(nh) <= 0.0:
			continue
		if s0 < wall_s and s0 > -(anchor - eye).dot(fwd):
			wall_s = s0
			wall = p
	# Back along fwd from the anchor until his near side is far enough and he is in the arc.
	var s := 0.0
	while s < 60.0 * unit and not RoomSpots.ahead(eye, anchor + fwd * s, near + r):
		s += 0.1 * unit
	var home := anchor + fwd * s
	if not RoomSpots.ahead(eye, home, near + r):
		home = eye + fwd * (near + r)
	if not wall.is_empty():
		var nh := Vector3((wall.normal as Vector3).x, 0, (wall.normal as Vector3).z).normalized()
		var q := anchor + fwd * wall_s
		# How far his spot stands in front of the wall: past it or too near it (he would stick
		# out of the room), or the wall right behind it: he stands inside the wall, with
		# clearance, and comes in through it.
		var clear := (home - q).dot(nh)
		if clear < r * 3.62:
			# As big as fits with his near side 2 m away; in a small room smaller, and if even
			# that does not fit, nearer, but never under NEAR_MIN metres.
			# Back from the wall along the court's line (on the line through the pin), so that
			# he clears the wall by fit × 1.12 across it.
			var back := 1.12 / maxf(0.3, -fwd.dot(nh))
			var fit := -1.0
			for lim: float in [near, NEAR_MIN * unit]:
				var f := r
				while f > 0.05 * size:
					if RoomSpots.ahead(eye, q - fwd * f * back, lim + f):
						fit = f
						break
					f *= 0.93
				if fit > 0.0:
					break
			if fit < 0.0:
				fit = 0.05 * size  # the wall is right in front of the player: as small as can be
			r = fit
			home = q - fwd * fit * back
			room.wall = wall
			room.side = Vector3.UP.cross(nh).normalized()
			var half: Vector2 = wall.half
			room.lane = clampf(half.x - r * 1.1, 0.0, r * 0.8)
			breach.p = Vector3(q.x, room.floor + r * 1.25, q.z) + nh * 0.02
			breach.n = nh
	if room.wall.is_empty():
		room.side = Vector3(-fwd.z, 0, fwd.x)
		room.lane = r * 0.6
	room.home = Vector3(home.x, room.floor, home.z)
	room.r = r
	room.max_h = INF if room.ceil == INF else maxf(0.08 * r, room.ceil - room.floor - 2.45 * r)


## A new pin (or a mode / world change) moved the court: he goes with it, in again at the new
## spot (through its wall or from the sky). Mid-fight he keeps his hit points and phase.
## Knocked out: the next level lays out anyway.
func on_placed() -> void:
	if F.state != "enter" and F.state != "fight":
		return
	var fighting: bool = F.state == "fight"
	var hp: float = F.hp
	var phase: int = F.phase
	_begin_level()
	if fighting:
		F.hp = hp
		F.phase = phase
		_shown_hp = hp_frac()
		_ghost = _shown_hp


func fwd_of(p: Vector3) -> Vector3:
	var d := viewer - p
	d.y = 0.0
	return d.normalized() if d.length_squared() > 1e-6 else Vector3.BACK


# ---- the game ----

func start() -> void:
	F.lv = 1
	F.score = 0
	F.kos = 0
	F.combo = 0
	F.mult = 1
	_begin_level()


## A new level: his look, size, ring; in he comes (from the sky, or through the wall).
func _begin_level() -> void:
	_layout()
	var lv: int = F.lv
	var look: Array = LOOKS[(lv - 1) % LOOKS.size()]
	F.max_hp = HP_BASE + HP_LV * (lv - 1)
	F.hp = F.max_hp
	F.phase = 1
	F.split = ""
	F.whole_t = 0.0
	F.state = "enter"
	F.t = 0.0
	F.ko_land = false
	F.ko_pop = false
	_shown_hp = 0.0
	_ghost = 0.0
	for m in meds:
		_body_off(m)
		(m.view as DahroojView).set_look(look[0], look[1], look[2])
	var g := giant
	_body_reset(g, room.r)
	(g.view as DahroojView).set_look(look[0], look[1], look[2])
	g.g = room.home
	g.fwd = fwd_of(room.home)
	_ring_c = room.home + Vector3.UP * room.r
	_ring_fb = _face(_ring_c)
	_ring_r = room.r * 1.25
	_place_props()
	if not room.wall.is_empty():
		F.enter = "wall"
		g.on = false
		breach.on = true
		breach.r = room.r * 0.78
		breach.bulge = 0.0
		breach.crack = 0.0
		breach.hole = 0.0
		breach.spin = _rng.randf() * TAU
	else:
		F.enter = "sky"
		breach.on = false
		g.on = true
		g.y = ENTER_DROP * (room.r / R_BASE)
		g.vy = -4.0
		g.air = true
		g.s = 1.3
		g.s_to = 1.3
		g.face = "wide"
		g.land = "enter"
		_sfx("whoosh", 1.0, viewer + (room.home - viewer) * 0.5)
	_banner(_tx("العملاق مستوى %s" % GameCtx.ar_digits(lv), "GIANT Lv.%d" % lv),
		_tx("هو قادم!", "Here he comes!") if lv == 1 else _tx("أكبر وأقوى!", "Bigger! Badder! Fancier!"), Color("ffd166"))


func _body_reset(b: Dictionary, r: float) -> void:
	b.on = true
	b.r = r
	b.k = 1.0
	b.y = 0.0
	b.vy = 0.0
	b.hv = Vector3.ZERO
	b.air = false
	b.free = false
	b.axis = Vector3.UP
	b.s = 1.0
	b.sv = 0.0
	b.s_to = 1.0
	b.sx_k = 1.0
	b.melt = 0.0
	b.wob = Vector3.ZERO
	b.wobv = Vector3.ZERO
	b.spin = 0.0
	b.tilt = 0.0
	b.act = ""
	b.act_t = 0.0
	b.act_cd = 1.0
	b.face = "open"
	b.face_t = 0.0
	b.blink_t = _rng.randf_range(0.5, 2.5)
	b.mouth = 0.0
	b.mouth_to = 0.0
	b.flash = 0.0
	b.glow = 0.0
	b.dizzy = 0.0
	b.solid = false
	b.land = ""
	for sp in b.spots:
		sp.on = false


func _body_off(b: Dictionary) -> void:
	b.on = false
	b.solid = false
	b.air = false
	for sp in b.spots:
		sp.on = false
	(b.view as DahroojView).visible = false


func _place_props() -> void:
	props.clear()
	var home: Vector3 = room.home
	var r: float = room.r
	var fwd := fwd_of(home)
	var kinds := ["crate", "barrel", "cone"]
	var scale_k := {"crate": 1.1, "barrel": 1.0, "cone": 0.85}
	for i in PROPS:
		var a := lerpf(-PI * 0.8, PI * 0.8, (i + 0.5) / PROPS) + _rng.randf_range(-0.12, 0.12)
		var d := r * _rng.randf_range(1.35, 2.3)
		var p := home + fwd.rotated(Vector3.UP, a) * d
		if not room.wall.is_empty():
			var wp: Vector3 = (room.wall as Dictionary).pos
			var behind := (p - wp).dot(breach.n as Vector3)
			if behind < 1.2 * size:
				p += (breach.n as Vector3) * (1.2 * size - behind)
		var to_v := Vector2(viewer.x - p.x, viewer.z - p.z)
		if to_v.length() < 4.0 * size:
			continue
		var kind: String = kinds[i % 3]
		props.append({"kind": kind, "p": Vector3(p.x, room.floor, p.z), "y": 0.0, "vy": 0.0, "tilt": Vector3.ZERO,
			"tiltv": Vector3.ZERO, "yaw": _rng.randf() * TAU, "s": size * float(scale_k[kind]) * _rng.randf_range(0.85, 1.15)})


func _banner(text: String, sub: String, color: Color) -> void:
	banner.text = text
	banner.modulate = color
	banner_sub.text = sub
	F.banner_t = BANNER_T
	F.banner_life = BANNER_T


## The phase by what is left of the ring: 1 stomp, 2 spit, 3 split, 4 rage.
static func phase_of(f: float) -> int:
	if f > PHASE_AT[0]:
		return 1
	if f > PHASE_AT[1]:
		return 2
	if f > PHASE_AT[2]:
		return 3
	return 4


## How hard he goes: faster each level and in a rage.
func speed_k() -> float:
	return minf(2.2, (1.0 + 0.1 * (F.lv - 1)) * (1.35 if F.phase == 4 else 1.0))


func hp_frac() -> float:
	return clampf(float(F.hp) / float(F.max_hp), 0.0, 1.0)


func _enter_phase(p: int) -> void:
	F.phase = p
	var at := banner_at()
	match p:
		2:
			_banner(_tx("هجوم البصق!", "SPIT ATTACK!"), _tx("فجّر الصغار!", "Pop the little ones!"), Color("7fd8ff"))
		3:
			_banner(_tx("انقسام السلايم!", "SLIME SPLIT!"), _tx("صار ثلاثة!", "There are three of him!"), Color("8dff7a"))
		4:
			_banner(_tx("وضع الغضب!", "RAGE MODE!"), _tx("صار أسرع — كمّل!", "He's faster — keep going!"), Color("ff4d4d"))
	_sfx("boom", 0.7, at)
	_sfx("swish", 0.7, at)
	_buzz2(0.6, 160)
	if p == 3:
		_start_split()
	else:
		_roar(giant)


func _roar(b: Dictionary) -> void:
	if b.air:
		return
	b.act = "roar"
	b.act_t = 0.0
	b.s_to = 1.18
	b.face = "laugh"
	b.face_t = 1.0
	_sfx("boom", 0.5, b.c)


## Takes hit points off the ring; the lost part of the ring flies off in chunks.
func _damage(d: float) -> void:
	if F.state != "fight":
		return
	var before: float = F.hp
	var lo := 0.0
	if F.split != "":
		lo = F.max_hp * PHASE_AT[2]
	F.hp = maxf(lo, before - d)
	var n0 := ceili(before / F.max_hp * SEGS)
	var n1 := ceili(float(F.hp) / F.max_hp * SEGS)
	for i in range(n1, n0):
		_chunk(i)
	if F.hp <= 0.0:
		_ko()
		return
	var p := phase_of(hp_frac())
	if p > F.phase:
		if F.split != "" and p == 4:
			_merge()
		elif F.split == "":
			_enter_phase(p)


func _score(base: int, at: Vector3, count := true) -> int:
	if count:
		F.combo += 1
		F.combo_t = COMBO_T
		var m := multiplier(F.combo)
		if m > F.mult:
			F.combo_show_t = 1.1
			F.combo_at = at
			combo_label.text = _tx("كومبو ×%s!" % GameCtx.ar_digits(m), "COMBO ×%d!" % m)
			_sfx("chime", 0.5 + 0.1 * m, at)
		F.mult = m
	var pts: int = base * int(F.mult)
	F.score += pts
	if ctx:
		ctx.counts["giant"] = int(ctx.counts.get("giant", 0)) + pts
	_pop_label(at, "+" + _num(pts), Color("ffd23f") if base >= 10 else Color("5dff8a"), 1.0 + 0.1 * minf(4.0, F.mult - 1))
	return pts


static func multiplier(combo: int) -> int:
	var m := 1
	for s in COMBO_STEPS:
		if combo >= s:
			m += 1
	return m


func _break_combo() -> void:
	F.combo = 0
	F.combo_t = 0.0
	F.mult = 1


func _pop_label(at: Vector3, text: String, col: Color, k := 1.0) -> void:
	JuiceText.spawn(self, text, at, "points", k * clampf(at.distance_to(viewer) / 9.0, 0.45, 2.5), col)

## A weak spot is hit.
func spot_hit(b: Dictionary, sp: Dictionary, dir: Vector3, by_ball := false) -> void:
	if not spot_live(sp) or not b.solid:
		return
	var at: Vector3 = sp.at
	var key: String = sp.key
	var dmg: float = (BALL_SPOT_DMG if by_ball else SPOT_DMG) if b.big else MED_DMG
	sp.cd = 0.5
	sp.hit_t = 0.0
	F.hits += 1
	F.throw_hits += 1
	_burst(at, Color("ffd23f"), 22, 1.2 * b.r / R_BASE)
	_burst(at, Color("ffffff"), 8, 0.8 * b.r / R_BASE)
	_ring_at(at, sp.n, b.r * 0.1, b.r * 0.6, 0.45, Color("ffe36b"))
	_flinch(b, dir, 1.0, key)
	_sfx("start_pop", 1.0, at)
	_sfx("squeak", 0.55 if b.big else 0.9, at)
	_sfx("boom", 0.25, at)
	_buzz2(0.45, 55)
	_score(int(SPOT_PTS[key]), at)
	_damage(dmg)


## A shot or a throw on the body (not a weak spot): a little chip.
func body_hit(b: Dictionary, at: Vector3, dir: Vector3, by_ball := false) -> void:
	if not b.solid:
		return
	_flinch(b, dir, 0.6 if by_ball else 0.18, "")
	_burst(at, Color("fff1c9"), 5, 0.5 * b.r / R_BASE)
	if by_ball:
		F.throw_hits += 1
		_sfx("thump", 0.8, at)
		_sfx("squeak", 0.5, at)
		_damage(BALL_DMG)
	else:
		_damage(BODY_DMG)


func _body_color(b: Dictionary) -> Color:
	var v: DahroojView = b.view
	return DahroojLooks.tint(v.style, v.color_id)


func _flinch(b: Dictionary, dir: Vector3, k: float, key: String) -> void:
	var d := dir if dir.length_squared() > 1e-6 else -fwd_of(b.g)
	var ax := Vector3.UP.cross(d)
	if ax.length_squared() < 1e-6:
		ax = Vector3.RIGHT
	b.wobv += ax.normalized() * 2.6 * k
	b.wobv += Vector3.UP * _rng.randf_range(-1.0, 1.0) * k
	b.sv -= 3.0 * k
	b.flash = maxf(float(b.flash), 0.55 * minf(1.0, k + 0.3))
	if k >= 0.5:
		b.face = "squint" if key.begins_with("eye") else ("wide" if _rng.randf() < 0.5 else "closed")
		b.face_t = 0.55
		b.eye_pop = 0.6 if b.face == "wide" else 0.0
		if key.begins_with("eye"):
			b.dizzy = maxf(float(b.dizzy), 1.0)


func _ko() -> void:
	F.state = "ko"
	F.t = 0.0
	F.kos += 1
	F.fw_t = 0.5
	F.fw_n = 0
	F.conf_t = 0.1
	F.ko_land = false
	F.ko_pop = false
	F.split = ""
	for m in meds:
		if m.on:
			_burst(m.c, Color("8dff7a"), 14, 1.0)
			_body_off(m)
	var g := giant
	g.melt = 0.0
	g.sx_k = 1.0
	g.on = true
	g.solid = false
	for sp in g.spots:
		sp.on = false
	g.act = "ko"
	g.act_t = 0.0
	g.s_to = 1.0
	g.air = true
	g.vy = 11.0
	g.hv = Vector3.ZERO
	g.face = "wide"
	g.face_t = 0.4
	g.eye_pop = 1.0
	g.dizzy = 5.0
	g.flash = 1.0
	g.land = "ko"
	for mi in minions:
		if mi.on:
			_pop_minion(mi, Vector3.UP, false)
	_banner(_tx("ضربة قاضية!", "KNOCKOUT!"), _tx("العملاق طاح!", "The Giant is down!"), Color("ff7ad9"))
	_sfx("boom", 1.0, g.c)
	_sfx("whoosh", 1.0, g.c)
	_sfx("chime", 1.0, banner_at())
	_buzz2(1.0, 320)
	_score(100 * int(F.lv), g.c + Vector3.UP * g.r * 1.3)
	if ctx:
		ctx.ch_progress.call("giant3", int(ctx.ch_state.get("giant3", 0)) + 1)  # a running total, like mole20


func _level_up() -> void:
	F.lv += 1
	_burst(giant.c, Color.WHITE, 20, 1.5)
	_begin_level()


# ---- moves ----

func _start_hop(b: Dictionary, big: bool) -> void:
	var r: float = b.r
	var h := r * (1.0 if big else 0.42) * (1.1 if F.phase == 4 else 1.0)
	if b.big:
		h = minf(h, room.max_h)
	b.hop_h = maxf(h, r * 0.06)
	b["stomp"] = big
	var to: Vector3 = b.g
	if not big:
		if b.big:
			to = (room.home as Vector3) + (room.side as Vector3) * _rng.randf_range(-room.lane, room.lane)
		else:
			to = (b.base as Vector3) + Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)) * r * 0.5
	b.base_to = to
	b.act = "crouch"
	b.act_t = 0.0
	b.s_to = 0.78


## Merging back: each medium one splashes into him as soon as it reaches the puddle (or
## lands); run again once the bodies have moved, so none is drawn over him.
func _absorb() -> void:
	_place(giant)
	for m in meds:
		if m.on:
			_place(m)
			if not m.air or absorbed(m):
				_burst(m.c, Color("8dff7a"), 10, 1.0)
				_body_off(m)


## The giant's footprint: how far his squashed body reaches across the floor from his centre.
func footprint(b: Dictionary) -> float:
	var s: float = b.s
	return float(b.r) * float(b.k) * (1.0 / sqrt(maxf(s, 0.2))) * (1.0 + 0.8 * float(b.melt)) * float(b.sx_k)


## How high his body's top is over where he stands.
func _top_of(b: Dictionary) -> float:
	var s: float = b.s
	return 2.0 * float(b.r) * float(b.k) * s * (1.0 - 0.86 * float(b.melt)) + float(b.y)


## Whether a point is inside his body (the squashed, wobbling ellipsoid).
func inside(b: Dictionary, p: Vector3) -> bool:
	var bs := body_basis(b)
	if absf(bs.determinant()) < 1e-9:
		return false
	return (bs.inverse() * (p - (b.c as Vector3))).length() < 1.0


## A medium one merging back has reached him: its centre over his footprint or in his body.
func absorbed(m: Dictionary) -> bool:
	var g := giant
	var d: Vector3 = (m.c as Vector3) - (g.g as Vector3)
	d.y = 0.0
	return d.length() < footprint(g) or inside(g, m.c)


## As _launch, from the height b.y it is at now down to the floor at `to`, peaking h above
## where it starts.
func _launch_from(b: Dictionary, to: Vector3, h: float) -> void:
	h = maxf(h, 0.05)
	var y0 := maxf(0.0, float(b.y))
	var vy := sqrt(2.0 * G_GRAV * h)
	var t_air := (vy + sqrt(vy * vy + 2.0 * G_GRAV * y0)) / G_GRAV
	b.vy = vy
	b.hv = (to - (b.g as Vector3)) / t_air
	b.hv.y = 0.0
	b.air = true
	b.s_to = 1.16


func _launch(b: Dictionary, to: Vector3, h: float) -> void:
	h = maxf(h, 0.05)
	var vy := sqrt(2.0 * G_GRAV * h)
	var t_air := 2.0 * vy / G_GRAV
	b.vy = vy
	b.hv = (to - (b.g as Vector3)) / t_air
	b.hv.y = 0.0
	b.air = true
	b.s_to = 1.16


func _start_spit(b: Dictionary) -> void:
	b.act = "spit"
	b.act_t = 0.0
	b.spit_n = mini(3 + F.lv + (2 if F.phase == 4 else 0), 10) if b.big else 2
	b.spit_i = 0
	b.s_to = 1.15
	b.face = "focus"
	b.face_t = 0.6
	_sfx("swish", 0.5, b.c)


## His next move when he's free (the phase decides).
func _think(b: Dictionary, dt: float) -> void:
	if b.act != "" or b.air:
		return
	b.act_cd -= dt * speed_k()
	if b.act_cd > 0.0:
		return
	var r := _rng.randf()
	match int(F.phase):
		1:
			_start_hop(b, r < 0.32)
		2:
			if r < 0.62:
				_start_spit(b)
			else:
				_start_hop(b, r > 0.85)
		3:
			if r < 0.5:
				_start_spit(b)
			else:
				_start_hop(b, r > 0.8)
		_:
			if r < 0.45:
				_start_spit(b)
			else:
				_start_hop(b, r > 0.7)


func _act_done(b: Dictionary) -> void:
	b.act = ""
	b.s_to = 1.0
	var base := [1.25, 1.05, 0.95, 0.5][clampi(F.phase - 1, 0, 3)] as float
	b.act_cd = base * _rng.randf_range(0.7, 1.3)
	if not b.big:
		b.act_cd = _rng.randf_range(0.5, 1.4)


func _step_act(b: Dictionary, dt: float) -> void:
	b.act_t += dt
	var t: float = b.act_t
	var k := speed_k()
	match b.act:
		"crouch":
			if t >= 0.32 / k:
				b.act = "air"
				_launch(b, b.base_to, b.hop_h)
				_sfx("whoosh", 0.35 if b.big else 0.2, b.c)
		"spit":
			var wind := 0.55 / k
			if t >= wind:
				var due := int((t - wind) / (0.16 / k)) + 1
				while b.spit_i < mini(due, b.spit_n):
					b.spit_i += 1
					_spit_one(b)
				if b.spit_i >= b.spit_n and t >= wind + b.spit_n * 0.16 / k + 0.35:
					_act_done(b)
		"roar":
			b.wobv += Vector3(sin(t * 40.0), 0, cos(t * 33.0)) * 0.6 * dt * 60.0 * 0.05
			if t >= 1.0:
				_act_done(b)
				if F.state == "enter":
					F.state = "fight"
					F.t = 0.0


func _spit_one(b: Dictionary) -> void:
	var mi: Dictionary = {}
	for q in minions:
		if not q.on:
			mi = q
			break
	if mi.is_empty():
		return
	var xf := body_xf(b)
	var mouth: Vector3 = xf * (Vector3(0, -0.28, 0.96).normalized() * 1.02)
	var goal := Vector3(viewer.x, room.floor, viewer.z)
	var home: Vector3 = b.g
	var land := home.lerp(goal, _rng.randf_range(0.35, 0.62))
	land += (room.side as Vector3) * _rng.randf_range(-1.0, 1.0) * (b.r as float) * 0.9
	var r := MIN_R * size * _rng.randf_range(0.85, 1.2)
	land.y = room.floor + r
	var t_fly := _rng.randf_range(0.85, 1.15)
	var v := (land - mouth) / t_fly + Vector3.UP * 0.5 * Ball.GRAV * t_fly
	if room.ceil < INF:
		var top_h: float = room.ceil - mouth.y - r
		v.y = minf(v.y, sqrt(maxf(0.0, 2.0 * Ball.GRAV * top_h)))
	mi.on = true
	mi.p = mouth
	mi.v = v
	mi.r = r
	mi.ph = "fly"
	mi.t = 0.0
	mi.life = 0.0
	mi.bounces = 0
	mi.best = INF
	mi.stuck_t = 0.0
	mi.nav = {}
	mi.flash = 0.0
	mi.zig = _rng.randf() * TAU
	mi.hop_p = _rng.randf_range(0.42, 0.56)
	mi.style = MIN_STYLES[_rng.randi() % MIN_STYLES.size()]
	mi.color = MIN_COLORS[_rng.randi() % MIN_COLORS.size()]
	mi.acc = MIN_ACCS[_rng.randi() % MIN_ACCS.size()]
	b.face = "laugh"
	b.face_t = 0.2
	b.sv += 2.5
	b.wobv += (b.fwd as Vector3).cross(Vector3.UP) * -0.5
	_burst(mouth, Color(mi.color), 5, 0.5)
	_sfx("pew", 0.6, mouth)
	_sfx("squeak", 1.3, mouth)


# ---- slime split ----

func _start_split() -> void:
	F.split = "melt"
	F.split_t = 0.0
	for m in meds:
		if m.on:
			_body_off(m)
	var g := giant
	g.act = ""
	g.air = false
	g.y = 0.0
	g.vy = 0.0
	g.hv = Vector3.ZERO
	g.solid = false
	for sp in g.spots:
		sp.on = false
	g.face = "wide"
	g.face_t = 1.2
	_sfx("splash", 1.0, g.c)


func _merge() -> void:
	if F.split != "fight" and F.split != "out":
		return
	F.split = "merge"
	F.split_t = 0.0
	for m in meds:
		if m.on:
			m.solid = false
			for sp in m.spots:
				sp.on = false
			m.air = false
			m.act = "merge"
			m.act_t = 0.0
			_launch(m, room.home, m.r * 1.2)
	_sfx("whoosh", 0.8, giant.c)


func _step_split(dt: float) -> void:
	F.split_t += dt
	var t: float = F.split_t
	var g := giant
	match F.split:
		"melt":
			var e := clampf(t / 1.0, 0.0, 1.0)
			g.melt = e * e * (3.0 - 2.0 * e)
			if _rng.randf() < 0.5:
				var a := _rng.randf() * TAU
				_spark((g.c as Vector3) + Vector3(cos(a), 0.3, sin(a)) * g.r * 0.9, Vector3(cos(a), 1.5, sin(a)) * 2.0 * size,
					0.7, _body_color(g), 0.18 * size * g.r / R_BASE, 1.0, room.floor)
			if t >= 1.0:
				F.split = "out"
				F.split_t = 0.0
				var home: Vector3 = room.home
				var fwd := fwd_of(home)
				var side: Vector3 = room.side
				var mr: float = g.r * 0.52
				var lane: float = maxf(float(room.lane), mr * 1.2)
				var spots := [home + side * minf(g.r * 1.55, lane + mr) + fwd * mr * 0.4, home - side * minf(g.r * 1.55, lane + mr) + fwd * mr * 0.4, home + fwd * g.r * 1.15]
				# Out of the top of the puddle (not from inside or under it): each starts
				# small, sitting on the slime toward its spot, and grows as it leaps out.
				var top := _top_of(g)
				var reach := footprint(g) * 0.45
				for i in 3:
					var m: Dictionary = meds[i]
					_body_reset(m, mr)
					var away: Vector3 = spots[i] - home
					away.y = 0.0
					m.g = home + away.normalized() * minf(reach, away.length())
					m.y = top
					m.k = OUT_K
					m.base = spots[i]
					m.fwd = fwd
					m.face = "joy"
					m.face_t = 1.0
					(m.view as DahroojView).visible = true
					m.act = "air"
					_launch_from(m, spots[i], mr * 1.6)
					_place(m)
					_burst(m.c, Color("8dff7a"), 10, mr / R_BASE)
				_sfx("splash", 1.0, home)
				_sfx("boom", 0.5, home)
				_buzz2(0.5, 120)
		"out":
			g.sx_k = lerpf(1.0, 0.45, clampf(t / 0.6, 0.0, 1.0))
			var e := clampf(t / 0.45, 0.0, 1.0)
			for m in meds:
				if m.on:
					m.k = lerpf(OUT_K, 1.0, e * e * (3.0 - 2.0 * e))
			if t >= 0.8:
				F.split = "fight"
				F.split_t = 0.0
				for m in meds:
					m.solid = true
		"fight":
			g.sx_k = 0.45
			if t >= SPLIT_T / minf(1.5, speed_k()):
				_merge()
		"merge":
			g.sx_k = lerpf(0.45, 1.0, clampf(t / 0.9, 0.0, 1.0))
			for m in meds:
				if m.on:
					m.k = maxf(0.3, 1.0 - t * 0.7)
			_absorb()
			if t >= 1.0:
				# None left over to stand inside him as he rises (a big one is still in the
				# air here: in mixed reality, and from Lv.2 on).
				for m in meds:
					if m.on:
						_burst(m.c, Color("8dff7a"), 10, 1.0)
						_body_off(m)
				F.split = "reform"
				F.split_t = 0.0
				_sfx("splash", 1.0, g.c)
				_sfx("boom", 0.8, g.c)
				_buzz2(0.6, 140)
		"reform":
			var e := clampf(t / 0.55, 0.0, 1.0)
			g.melt = 1.0 - e
			if t >= 0.55:
				g.melt = 0.0
				g.sv += 6.0
				F.split = ""
				F.whole_t = 0.0
				g.solid = true
				g.act = ""
				g.act_cd = 0.6
				var p := phase_of(hp_frac())
				if p > F.phase:
					_enter_phase(p)
				else:
					_roar(g)


# ---- the little ones ----

func _step_minion(mi: Dictionary, dt: float) -> void:
	mi.t += dt
	mi.life += dt
	mi.flash = maxf(0.0, mi.flash - dt * 4.0)
	var r: float = mi.r
	var fl: float = room.floor
	var goal := Vector3(viewer.x, fl, viewer.z)
	match mi.ph:
		"fly":
			mi.v.y -= Ball.GRAV * dt
			mi.p += (mi.v as Vector3) * dt
			if room.ceil < INF and mi.p.y > room.ceil - r:
				mi.p.y = room.ceil - r
				mi.v.y = minf(0.0, mi.v.y)
			if mi.p.y <= fl + r and mi.v.y < 0.0:
				mi.p.y = fl + r
				if mi.bounces >= 3:
					_pop_minion(mi, Vector3.UP, false)
					return
				mi.ph = "hop"
				mi.t = 0.0
				_sfx("thump", 0.25, mi.p)
		"hop":
			var k := speed_k()
			var to := goal - (mi.p as Vector3)
			to.y = 0.0
			var d := to.length()
			var dir := to / d if d > 1e-4 else Vector3.FORWARD
			var side := Vector3(-dir.z, 0, dir.x)
			var sp := 2.3 * size * k
			var was: Vector3 = mi.p
			mi.p += (dir * sp + side * sin(float(mi.t) * 4.0 + mi.zig) * 1.0 * size) * dt
			# Round the real furniture; one that gets no nearer for a while goes on through it.
			if not mi.has("nav"):
				mi.nav = {}
			if d < float(mi.get("best", INF)) - 0.1 * r:
				mi.best = d
				mi.stuck_t = 0.0
			else:
				mi.stuck_t = float(mi.get("stuck_t", 0.0)) + dt
				if float(mi.stuck_t) >= 4.0:
					mi.nav["ghost"] = true
					mi.stuck_t = 0.0
					mi.best = INF
			if furniture.is_valid():
				var q: Vector3 = furniture.call(Vector3(mi.p.x, fl + r, mi.p.z), r, Vector3(was.x, fl + r, was.z), Vector3(goal.x, fl + r, goal.z), mi.nav)
				mi.p = Vector3(q.x, mi.p.y, q.z)
			var u: float = mi.t / (mi.hop_p / sqrt(k))
			mi.p.y = fl + r + absf(sin(u * PI)) * r * 2.6
			if d < REACH * size + r:
				# He bounces off you: the combo breaks and he takes a few points.
				mi.ph = "fly"
				mi.t = 0.0
				mi.bounces += 1
				mi.v = -dir * 4.5 * size + Vector3.UP * 8.0 * sqrt(size) + side * _rng.randf_range(-2.0, 2.0) * size
				mi.flash = 1.0
				mi.best = INF
				mi.stuck_t = 0.0
				F.bounced += 1
				_break_combo()
				_burst(mi.p, Color("7fe8ff"), 10, 0.6)
				_ring_at(mi.p, -dir, r * 0.5, r * 3.0, 0.4, Color("7fe8ff"))
				_sfx("squeak", 1.5, mi.p)
				_sfx("thump", 0.5, mi.p)
				_buzz2(0.35, 70)
				giant.face = "laugh"
				giant.face_t = 0.8
				if ctx:
					ctx.penalty.call("giant", MINION_PENALTY, mi.p)
	if mi.life > 18.0:
		# Left unpopped all that time (and never bounced off you: that took its points).
		if int(mi.bounces) == 0 and ctx:
			ctx.nibble.call("giant", ESCAPE_PENALTY, mi.p)
		_pop_minion(mi, Vector3.UP, false)


func _pop_minion(mi: Dictionary, _dir: Vector3, scored: bool) -> void:
	mi.on = false
	(mi.proxy as MeshInstance3D).visible = false
	var c: Vector3 = mi.p
	_burst(c, Color(mi.color), 16, 0.8 * size)
	_burst(c, Color.WHITE, 5, 0.5 * size)
	_sfx("start_pop", 1.0, c)
	if scored:
		F.pops += 1
		F.throw_hits += 1
		_sfx("squeak", 1.6, c)
		_buzz2(0.3, 35)
		_score(5, c)
		_damage(POP_DMG)


# ---- effects ----

func _spark(p: Vector3, v: Vector3, life: float, c: Color, s: float, g := 1.0, floor_y := -INF) -> void:
	if _sparks.size() >= SPARKS_MAX:
		_sparks.pop_front()
	_sparks.append({"p": p, "v": v, "t": 0.0, "life": life, "c": c, "s": s, "g": g, "floor": floor_y})


func _burst(at: Vector3, col: Color, count: int, k: float) -> void:
	for i in count:
		var d := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.3, 1.2), _rng.randf_range(-1, 1)).normalized()
		_spark(at, d * _rng.randf_range(3.0, 7.0) * k, _rng.randf_range(0.35, 0.7), col.lerp(Color.WHITE, _rng.randf() * 0.3),
			_rng.randf_range(0.07, 0.14) * k, 0.6)


func _ring_at(at: Vector3, n: Vector3, r0: float, r1: float, life: float, col: Color) -> void:
	if _rings.size() >= RINGS_MAX:
		_rings.pop_front()
	_rings.append({"p": at, "n": n.normalized() if n.length_squared() > 1e-6 else Vector3.UP, "t": 0.0, "life": life, "r0": r0, "r1": r1, "c": col})


func _puff(at: Vector3, v: Vector3, s0: float, s1: float, life: float, col := DUST) -> void:
	if _puffs.size() >= PUFFS_MAX:
		_puffs.pop_front()
	_puffs.append({"p": at, "v": v, "t": 0.0, "life": life, "s0": s0, "s1": s1, "c": col})


func _chip(at: Vector3, v: Vector3, s: float, col: Color, floor_y: float) -> void:
	if _debris.size() >= DEBRIS_MAX:
		_debris.pop_front()
	_debris.append({"p": at, "v": v, "t": 0.0, "life": _rng.randf_range(0.9, 1.5), "s": s, "c": col.srgb_to_linear(),
		"ax": Vector3(_rng.randf() - 0.5, _rng.randf() - 0.5, _rng.randf() - 0.5).normalized(), "w": _rng.randf_range(5, 12), "floor": floor_y})


## One segment of the ring breaks off.
func _chunk(i: int) -> void:
	if _chunks.size() >= CHUNKS_MAX:
		_chunks.pop_front()
	var xf := seg_xf(i, 1.0)
	var out := (xf.origin - _ring_c).normalized()
	_chunks.append({"p": xf.origin, "b": xf.basis, "v": out * _rng.randf_range(3.0, 6.0) * _ring_r / 6.0 + Vector3.UP * 2.0,
		"t": 0.0, "life": 0.8, "c": seg_color(float(i) / SEGS), "w": _rng.randf_range(-8, 8)})


## He lands (or stomps): dust rings and puffs, the props jump, the little ones hop.
func _shake(at: Vector3, r: float, k: float) -> void:
	var g := Vector3(at.x, room.floor + 0.05, at.z)
	_ring_at(g, Vector3.UP, r * 0.7, r * (2.4 + k), 0.9, DUST)
	_ring_at(g, Vector3.UP, r * 0.5, r * (1.5 + k * 0.6), 0.6, Color.WHITE)
	var n := int(10 + 8 * k)
	for i in n:
		var a := TAU * i / n + _rng.randf() * 0.3
		var d := Vector3(cos(a), 0, sin(a))
		_puff(g + d * r * 0.85, d * _rng.randf_range(2.5, 5.0) * r / R_BASE + Vector3.UP * _rng.randf_range(0.3, 1.2), r * 0.12, r * _rng.randf_range(0.32, 0.5), _rng.randf_range(0.7, 1.1))
	for i in int(6 * k):
		var a := _rng.randf() * TAU
		var d := Vector3(cos(a), 0, sin(a))
		_chip(g + d * r * 0.9, (d * _rng.randf_range(2, 5) + Vector3.UP * _rng.randf_range(4, 8)) * sqrt(r / R_BASE), r * 0.04, Color("8b6a45"), room.floor)
	var reach := r * 3.4
	for p in props:
		var dd := Vector2((p.p as Vector3).x - at.x, (p.p as Vector3).z - at.z).length()
		if dd < reach:
			var f := 1.0 - dd / reach
			p.vy = maxf(float(p.vy), (4.0 + 8.0 * f) * minf(k, 1.5) * sqrt(size))
			p.tiltv += Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)) * 5.0 * f
	for mi in minions:
		if mi.on and mi.ph == "hop":
			var dd := Vector2(mi.p.x - at.x, mi.p.z - at.z).length()
			if dd < reach * 1.5:
				mi.ph = "fly"
				mi.v = Vector3(0, 6.0 * sqrt(size) * (1.0 - dd / (reach * 1.5)) + 2.0, 0)
	_sfx("boom", clampf(0.35 + 0.4 * k, 0.0, 1.0), g)
	_sfx("thump", 1.0, g)
	_buzz2(clampf(0.25 + 0.4 * k, 0.0, 1.0), 90 + 80 * k)


func _landed(b: Dictionary, speed: float) -> void:
	var k := clampf(speed / 16.0, 0.25, 1.8)
	if b.land == "enter":
		k = 1.8
	b.sv -= clampf(speed * 0.3, 1.5, 5.0)
	if b.big:
		_shake(b.g, b.r, k)
		# A stomp (a big hop, not his entrance or the knock-out): the shockwave reaches you.
		if b.get("stomp", false) and b.land == "" and ctx:
			ctx.nibble.call("giant", STOMP_PENALTY, (b.g as Vector3) + Vector3.UP * float(b.r) * 0.4)
	else:
		_shake(b.g, b.r * 0.6, k * 0.5)
	b["stomp"] = false
	var cb: String = b.land
	b.land = ""
	if b.act == "air":
		_act_done(b)
	match cb:
		"enter":
			b.face = "joy"
			b.face_t = 0.3
			_roar(b)
		"ko":
			pass


func _step_body(b: Dictionary, dt: float) -> void:
	b.sv += ((float(b.s_to) - float(b.s)) * 150.0 - float(b.sv) * 10.0) * dt
	b.s = clampf(b.s + b.sv * dt, 0.45, 1.65)
	b.wobv += (-(b.wob as Vector3) * 70.0 - (b.wobv as Vector3) * 5.5) * dt
	b.wob += (b.wobv as Vector3) * dt
	var wl: float = (b.wob as Vector3).length()
	if wl > 0.5:
		b.wob = (b.wob as Vector3) * (0.5 / wl)
	b.flash = maxf(0.0, b.flash - dt * 3.0)
	b.mouth = move_toward(b.mouth, b.mouth_to, dt * 7.0)
	var mt := 0.0
	match b.act:
		"spit":
			mt = 0.25 if b.act_t < 0.55 / speed_k() else 0.6 + 0.4 * absf(sin(float(b.act_t) * 20.0))
		"roar":
			mt = 1.0
		"ko":
			mt = 0.55
		"crouch":
			mt = 0.2
	if b.face_t > 0.0 and b.face in ["wide", "squint", "closed"]:
		mt = maxf(mt, 0.45)
	if b.glow > 0.5:
		mt = maxf(mt, 0.3)
	b.mouth_to = mt
	b.eye_pop = maxf(0.0, b.eye_pop - dt * 2.0)
	b.dizzy = maxf(0.0, b.dizzy - dt)
	b.face_t -= dt
	b.blink_t -= dt
	if b.blink_t <= 0.0:
		b.blink = 0.13
		b.blink_t = _rng.randf_range(1.2, 3.2)
	b.blink = maxf(0.0, b.blink - dt)
	b.look_t -= dt
	if b.look_t <= 0.0:
		b.look_t = _rng.randf_range(0.3, 0.9)
		b.look_to = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.6, 0.6))
	b.look = (b.look as Vector2).move_toward(b.look_to, dt * 6.0)
	var want := fwd_of(b.g)
	if b.act != "ko":
		b.fwd = (b.fwd as Vector3).slerp(want, minf(1.0, dt * 3.0)).normalized() if (b.fwd as Vector3).dot(want) > -0.95 else want
	if b.air:
		b.vy -= G_GRAV * dt
		b.y += b.vy * dt
		b.g += (b.hv as Vector3) * dt
		if b.act != "ko" and b.act != "merge":
			b.s_to = 1.16 if b.vy > 0.0 else 1.04
		if b.big and room.ceil < INF:
			var top: float = room.floor + b.y + 2.0 * b.r * b.s
			if top > room.ceil:
				b.y -= top - room.ceil
				b.vy = minf(0.0, b.vy)
		if b.y <= 0.0 and b.vy < 0.0:
			var sp: float = -b.vy
			b.y = 0.0
			b.vy = 0.0
			b.hv = Vector3.ZERO
			b.air = false
			if b.act != "ko":
				b.s_to = 1.0
			_landed(b, sp)
	if b.act in ["crouch", "spit", "roar"]:
		_step_act(b, dt)


## Where the body is: centre and the full basis (squash, wobble, facing, the knock-out tilt).
func body_basis(b: Dictionary) -> Basis:
	var s: float = b.s
	var melt: float = b.melt
	var sy := s * (1.0 - 0.86 * melt)
	var sx := (1.0 / sqrt(maxf(s, 0.2))) * (1.0 + 0.8 * melt) * float(b.sx_k)
	var a: Vector3 = b.axis
	var d := sy - sx
	var S := Basis(Vector3(sx, 0, 0) + a * (d * a.x), Vector3(0, sx, 0) + a * (d * a.y), Vector3(0, 0, sx) + a * (d * a.z))
	var fwd: Vector3 = b.fwd
	var yaw := Basis.looking_at(fwd, Vector3.UP, true).rotated(Vector3.UP, float(b.spin))
	var tilt := Basis.IDENTITY
	if absf(float(b.tilt)) > 1e-4:
		tilt = Basis(fwd.cross(Vector3.UP).normalized(), float(b.tilt))
	var wob := Basis.IDENTITY
	var w: Vector3 = b.wob
	if w.length_squared() > 1e-8:
		wob = Basis(w.normalized(), w.length())
	return wob * S * tilt * yaw * Basis.from_scale(Vector3.ONE * float(b.r) * float(b.k))


func _place(b: Dictionary) -> void:
	if b.free:
		return
	var s: float = b.s
	var sy := s * (1.0 - 0.86 * float(b.melt))
	b.c = (b.g as Vector3) + Vector3.UP * (float(b.r) * float(b.k) * sy + float(b.y))


func body_xf(b: Dictionary) -> Transform3D:
	return Transform3D(body_basis(b), b.c)


# ---- weak spots ----

static func spot_dir(key: String) -> Vector3:
	match key:
		"eye_l":
			return Basis.from_euler(Vector3(-0.08, -0.31, 0), EULER_ORDER_YXZ) * Vector3.BACK
		"eye_r":
			return Basis.from_euler(Vector3(-0.08, 0.31, 0), EULER_ORDER_YXZ) * Vector3.BACK
		"bow":
			# Just under the bow (the knot itself would hide the target).
			return Vector3(-0.08, 0.6, 0.8).normalized()
		"belly":
			return Vector3(0, -0.42, 0.91).normalized()
		"patch":
			return Vector3(0.64, 0.14, 0.76).normalized()
	return Vector3.BACK


static func spot_live(sp: Dictionary) -> bool:
	return sp.on and sp.cd <= 0.0


func _spot_count(b: Dictionary) -> int:
	if not b.big:
		return 1
	match int(F.phase):
		1:
			return 2 if F.lv >= 3 else 1
		2:
			return 2 if F.lv >= 2 else 1
		3:
			return 2
	return 3 if F.lv >= 4 else 2


func _free_key(b: Dictionary, not_key := "") -> String:
	var used := []
	for sp in b.spots:
		if sp.on:
			used.append(sp.key)
	var keys := SPOT_KEYS.filter(func(k): return not (k in used) and k != not_key)
	if keys.is_empty():
		return SPOT_KEYS[_rng.randi() % SPOT_KEYS.size()]
	return keys[_rng.randi() % keys.size()]


func _dwell() -> float:
	var x := minf(1.0, (F.lv - 1) * 0.12 + (F.phase - 1) * 0.15)
	return lerpf(3.2, 1.5, x) * _rng.randf_range(0.8, 1.2)


func _step_spots(b: Dictionary, dt: float) -> void:
	var n := _spot_count(b) if b.solid else 0
	var move_t := 0.6 / speed_k()
	var spots: Array = b.spots
	for i in spots.size():
		var sp: Dictionary = spots[i]
		sp.hit_t += dt
		if i >= n:
			sp.on = false
			continue
		if not sp.on:
			sp.on = true
			sp.key = _free_key(b)
			sp.from = spot_dir(sp.key)
			sp.to = sp.from
			sp.mt = 1.0
			sp.dwell = _dwell()
			sp.cd = 0.3
			continue
		if sp.cd > 0.0:
			sp.cd -= dt
			if sp.cd <= 0.0 and sp.hit_t < 2.0:
				# After a hit it shows up somewhere else (gliding there from where it was hit).
				var from: Vector3 = sp.to
				sp.key = _free_key(b, sp.key)
				sp.from = from
				sp.to = spot_dir(sp.key)
				sp.mt = 0.0
				sp.dwell = _dwell()
			continue
		sp.mt = minf(1.0, sp.mt + dt / move_t)
		sp.dwell -= dt
		if sp.dwell <= 0.0 and sp.mt >= 1.0:
			var from: Vector3 = sp.to
			sp.key = _free_key(b, sp.key)
			sp.from = from
			sp.to = spot_dir(sp.key)
			sp.mt = 0.0
			sp.dwell = _dwell()


func spot_local(sp: Dictionary) -> Vector3:
	var e: float = sp.mt
	e = e * e * (3.0 - 2.0 * e)
	return (sp.from as Vector3).slerp(sp.to, e).normalized()


# ---- the stage interface ----

func _ball_vs(S: Ball, c: Vector3, r: float) -> bool:
	var dq := S.pos - c
	var l := dq.length()
	if l <= 0.0 or l >= Ball.BR + r:
		return false
	dq /= l
	S.pos = c + dq * (Ball.BR + r)
	var vn := S.vel.dot(dq)
	if vn < 0.0:
		S.hit(dq, -vn, c + dq * r)
		S.vel += dq * (-1.6 * vn)
	S.side = Vector3.ZERO
	return true


func _body_ball(S: Ball, b: Dictionary) -> void:
	if not b.on or not b.solid:
		return
	var bb := body_basis(b)
	var r := (bb.x.length() + bb.y.length() + bb.z.length()) / 3.0
	var dir := S.vel.normalized() if S.vel.length_squared() > 0.0 else Vector3.FORWARD
	if _ball_vs(S, b.c, r):
		F.touched = true
		if F.ball_t > 0.0:
			return
		F.ball_t = 0.35
		var n := (S.pos - (b.c as Vector3)).normalized()
		for sp in b.spots:
			if spot_live(sp) and n.dot(sp.n) > cos(0.42):
				spot_hit(b, sp, dir, true)
				return
		body_hit(b, S.pos - n * Ball.BR, dir, true)


func collide(S: Ball) -> void:
	if not S.shot:
		return
	_body_ball(S, giant)
	for m in meds:
		_body_ball(S, m)
	for mi in minions:
		if mi.on and S.pos.distance_to(mi.p) < Ball.BR + float(mi.r):
			F.touched = true
			_ball_vs(S, mi.p, mi.r)
			_pop_minion(mi, S.vel.normalized(), true)


func shoot(obj: Node, point: Vector3, dir: Vector3) -> bool:
	var d := dir if dir != Vector3.ZERO else Vector3.FORWARD
	for b in [giant] + meds:
		for sp in b.spots:
			if obj == sp.proxy:
				if spot_live(sp) and b.solid:
					spot_hit(b, sp, d)
					return true
				return false
	for mi in minions:
		if obj == mi.proxy and mi.on:
			_pop_minion(mi, d, true)
			return true
	for b in [giant] + meds:
		var v: DahroojView = b.view
		if b.on and (obj == v or v.is_ancestor_of(obj)):
			if b.solid:
				body_hit(b, point, d)
				return true
			return false
	return false


func touched() -> bool:
	return F.touched


func on_throw() -> void:
	F.throw_live = true
	F.throw_hits = 0


func on_respawn() -> void:
	F.touched = false
	# A throw that hit nothing breaks the combo.
	if F.throw_live and F.throw_hits == 0:
		_break_combo()
	F.throw_live = false


func deactivate() -> void:
	_body_off(giant)
	for m in meds:
		_body_off(m)
	for mi in minions:
		mi.on = false
		(mi.proxy as MeshInstance3D).visible = false
	JuiceText.clear(self)
	_sparks.clear()
	_rings.clear()
	_puffs.clear()
	_debris.clear()
	_chunks.clear()
	_rockets.clear()
	props.clear()
	breach.on = false
	F.state = "idle"
	F.lv = 1
	F.split = ""
	F.combo = 0
	F.mult = 1
	F.score = 0
	F.banner_t = 0.0
	F.combo_show_t = 0.0
	F.touched = false
	F.throw_live = false
	draw()


func update(_b: Ball, dt: float) -> void:
	if not visible or paused:
		return
	dt *= pace
	time += dt
	if F.state == "idle":
		start()
	F.t += dt
	F.ball_t = maxf(0.0, F.ball_t - dt)
	F.banner_t = maxf(0.0, F.banner_t - dt)
	F.combo_show_t = maxf(0.0, F.combo_show_t - dt)
	if F.combo_t > 0.0:
		F.combo_t -= dt
		if F.combo_t <= 0.0:
			_break_combo()
	# A room scanned after he came in on the court: he comes in again through its wall.
	_room_t -= dt
	if _room_t <= 0.0:
		_room_t = 2.0
		if not room.planes and F.state == "fight" and F.split == "" and not _planes().is_empty():
			_begin_level()
	var g := giant
	match F.state:
		"enter":
			if F.enter == "wall":
				_step_wall(dt)
			_shown_hp = minf(1.0, _shown_hp + dt * 0.8)
			_ghost = _shown_hp
		"fight":
			_shown_hp = hp_frac()
			if F.split != "":
				_step_split(dt)
			else:
				g.solid = true
				F.whole_t += dt
				if auto_play:
					_think(g, dt)
				if F.phase == 3 and F.whole_t > WHOLE_T and g.act == "" and not g.air:
					_start_split()
			for m in meds:
				if m.on and m.solid and auto_play:
					_think(m, dt)
		"ko":
			_step_ko(dt)
	_ghost = maxf(_shown_hp, _ghost - dt * 0.6)
	# Rage: a red glow and steam.
	var rage: float = 1.0 if F.phase == 4 and F.state == "fight" else 0.0
	g.glow = move_toward(g.glow, rage, dt * 2.0)
	if g.glow > 0.5 and g.on:
		F.steam_t -= dt
		if F.steam_t <= 0.0:
			F.steam_t = 0.12
			var top: Vector3 = (g.c as Vector3) + Vector3.UP * g.r * 0.95
			var sd: Vector3 = Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)) * g.r * 0.35
			_puff(top + sd, Vector3.UP * g.r * 0.6 + sd * 0.8, g.r * 0.08, g.r * 0.28, 0.9, Color("fff4f0"))
		if g.face_t <= 0.0 and g.act == "":
			g.face = "focus"
	for b in [g] + meds:
		if b.on:
			_step_body(b, dt)
			_place(b)
			_step_spots(b, dt)
	if F.split == "merge":
		_absorb()
	for mi in minions:
		if mi.on:
			_step_minion(mi, dt)
	_step_props(dt)
	_step_fx(dt)
	_draw_acc += dt
	if _draw_acc >= 0.0125:
		_draw_acc = 0.0
		draw()


## Mixed reality: knock, knock, the wall bulges and cracks, bursts, and he squeezes through.
func _step_wall(dt: float) -> void:
	var t: float = F.t
	var g := giant
	var n: Vector3 = breach.n
	var H: Vector3 = breach.p
	var r: float = room.r
	breach.jolt = maxf(0.0, breach.jolt - dt * 5.0)
	if t < 1.3:
		var e := clampf(t / 1.3, 0.0, 1.0)
		breach.bulge = e * e
		breach.crack = clampf((t - 0.2) / 1.0, 0.0, 1.0)
		for kt in [0.25, 0.65, 1.0]:
			if t - dt < kt and t >= kt:
				breach.jolt = 1.0
				_sfx("thump", 1.0, H)
				_sfx("boom", 0.3, H)
				_buzz2(0.45, 70)
				for i in 4:
					_chip(H + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * r * 0.4 + n * r * 0.2,
						n * _rng.randf_range(2, 5) + Vector3.UP * 2.0, r * 0.03, PLASTER, room.floor)
				_puff(H + n * r * 0.25, n * 1.5, r * 0.08, r * 0.3, 0.7)
		return
	if breach.hole <= 0.0:
		# Crash!
		breach.hole = 1.0
		breach.bulge = 0.0
		_sfx("boom", 1.0, H)
		_sfx("thump", 1.0, H)
		_buzz2(1.0, 220)
		_ring_at(H + n * 0.05, n, r * 0.4, r * 2.2, 0.7, DUST)
		for i in 36:
			var d := (n * _rng.randf_range(0.6, 1.4) + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.6, 1.0), _rng.randf_range(-1, 1)) * 0.7)
			_chip(H + (d - n * d.dot(n)) * r * 0.4, d * _rng.randf_range(4, 9) * sqrt(r / R_BASE), r * _rng.randf_range(0.03, 0.07), PLASTER.darkened(_rng.randf() * 0.2), room.floor)
		for i in 12:
			var a := TAU * i / 12.0
			var sd := (n.cross(Vector3.UP).normalized() * cos(a) + Vector3.UP * sin(a))
			_puff(H + sd * r * 0.6 + n * r * 0.2, (n * 2.0 + sd * 1.5) * r / R_BASE, r * 0.12, r * 0.45, 1.1)
		g.on = true
		g.free = true
		g.axis = n
		g.face = "wide"
		g.face_t = 1.0
		g.eye_pop = 1.0
		_sfx("squeak", 0.4, H)
	if t < 2.1:
		# Squeezing through: thin and stretched along the wall's normal, then out.
		var e := clampf((t - 1.3) / 0.8, 0.0, 1.0)
		var es := 1.0 - pow(1.0 - e, 2.0)
		g.free = true
		g.axis = n
		g.s = lerpf(1.6, 1.05, es)
		g.s_to = g.s
		g.sv = 0.0
		g.sx_k = lerpf(0.42, 1.0, e * e)
		g.c = H + n * r * lerpf(0.2, 1.1, es) * g.s
		g.g = Vector3(g.c.x, room.floor, g.c.z)
		return
	if g.free:
		# Out! He drops to the floor and hops to his spot.
		var c: Vector3 = g.c
		g.free = false
		g.axis = Vector3.UP
		g.sx_k = 1.0
		g.s = 1.0
		g.s_to = 1.0
		g.g = Vector3(c.x, room.floor, c.z)
		g.y = maxf(0.0, c.y - room.floor - r)
		g.vy = 4.0
		var t_air: float = (g.vy + sqrt(g.vy * g.vy + 2.0 * G_GRAV * g.y)) / G_GRAV
		g.hv = ((room.home as Vector3) - (g.g as Vector3)) / maxf(0.2, t_air)
		g.hv.y = 0.0
		g.air = true
		g.act = "air"
		g.land = "enter"
		_sfx("start_pop", 1.0, c)
		_sfx("whoosh", 0.8, c)


func _step_ko(dt: float) -> void:
	var t: float = F.t
	var g := giant
	# Spin up, then topple over onto his back.
	if t < 1.4:
		g.spin += (3.0 + 15.0 * t / 1.4) * dt
		F.spin_from = g.spin
	else:
		# The spin winds down to face you again (a whole number of turns).
		var to: float = ceilf(float(F.spin_from) / TAU) * TAU + TAU
		var e := clampf((t - 1.4) / 0.6, 0.0, 1.0)
		g.spin = lerpf(F.spin_from, to, 1.0 - pow(1.0 - e, 2.0))
	if t > 0.4:
		g.face = "closed"
		g.face_t = 0.2
	if t >= 1.35:
		var e := clampf((t - 1.35) / 0.45, 0.0, 1.0)
		g.tilt = 0.6 * e * e
		if e >= 1.0 and not F.ko_land:
			F.ko_land = true
			g.sv -= 3.0
			g.wobv += (g.fwd as Vector3).cross(Vector3.UP).normalized() * -1.5
			_shake(g.g, g.r, 1.6)
	# Confetti storm and fireworks.
	F.conf_t -= dt
	if t < 3.6 and F.conf_t <= 0.0:
		F.conf_t = 0.3
		var c: Vector3 = g.c
		var at: Vector3 = c.lerp(viewer, _rng.randf_range(0.0, 0.8)) + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.5, 1.5), _rng.randf_range(-1, 1)) * g.r * 0.6
		if room.ceil < INF:
			at.y = minf(at.y, room.ceil - size)
		_confetti(at, 1.4)
	if t < 3.8:
		_glitter += dt * 70.0
		while _glitter >= 1.0:
			_glitter -= 1.0
			var span: float = g.r * 2.4
			var top: float = viewer.y + 6.0 * size if room.ceil == INF else room.ceil - 0.3 * size
			var mid := viewer.lerp(g.c, 0.5)
			_spark(Vector3(mid.x + _rng.randf_range(-span, span), top, mid.z + _rng.randf_range(-span, span)),
				Vector3(_rng.randf_range(-0.5, 0.5), -_rng.randf_range(2.0, 3.5), _rng.randf_range(-0.5, 0.5)) * sqrt(size),
				_rng.randf_range(1.6, 2.4), Color(FW_COLORS[_rng.randi() % FW_COLORS.size()]), 0.07 * size, 0.0)
	F.fw_t -= dt
	if t < 4.0 and F.fw_t <= 0.0 and F.fw_n < 10:
		F.fw_t = _rng.randf_range(0.25, 0.42)
		F.fw_n += 1
		_launch_rocket()
	if t >= 4.2:
		if not F.ko_pop:
			F.ko_pop = true
			_burst(g.c, Color(DahroojLooks.tint((g.view as DahroojView).style, (g.view as DahroojView).color_id)), 40, 2.0 * g.r / R_BASE)
			_burst(g.c, Color.WHITE, 20, 1.5 * g.r / R_BASE)
			_sfx("start_pop", 1.0, g.c)
			_sfx("chime", 1.0, g.c)
			_sfx("whoosh", 0.7, g.c)
			for i in 10:
				var a := TAU * i / 10.0
				_puff((g.c as Vector3) + Vector3(cos(a), 0, sin(a)) * g.r * 0.5, Vector3(cos(a), 0.6, sin(a)) * g.r * 0.6, g.r * 0.15, g.r * 0.45, 0.8, Color.WHITE)
		g.k = maxf(0.001, 1.0 - (t - 4.2) / 0.35)
	if t >= KO_T:
		_level_up()


func _launch_rocket() -> void:
	var g := giant
	var home: Vector3 = room.home
	var a := _rng.randf() * TAU
	var from: Vector3 = home + Vector3(cos(a), 0, sin(a)) * g.r * _rng.randf_range(1.2, 2.2)
	from.y = room.floor + 0.2
	var h: float = g.r * _rng.randf_range(2.0, 3.0) + 3.0 * size
	if room.ceil < INF:
		h = minf(h, room.ceil - room.floor - g.r * 0.4)
	var sp := 22.0 * sqrt(maxf(h, 1.0) / 12.0)
	_rockets.append({"p": from, "v": Vector3(_rng.randf_range(-0.12, 0.12), 1.0, _rng.randf_range(-0.12, 0.12)) * sp,
		"t": 0.0, "fuse": h / sp, "c": Color(FW_COLORS[_rng.randi() % FW_COLORS.size()]), "k": maxf(h, 4.0) / 14.0})
	_sfx("firework_launch", 0.8, from)


func _step_props(dt: float) -> void:
	for p in props:
		p.tiltv += (-(p.tilt as Vector3) * 40.0 - (p.tiltv as Vector3) * 4.0) * dt
		p.tilt += (p.tiltv as Vector3) * dt
		if p.y > 0.0 or p.vy > 0.0:
			p.vy -= Ball.GRAV * dt
			p.y += p.vy * dt
			if p.y <= 0.0:
				p.y = 0.0
				if p.vy < -2.5:
					p.vy = -p.vy * 0.35
					_sfx("thump", 0.3, p.p)
				else:
					p.vy = 0.0


func _step_fx(dt: float) -> void:
	for i in range(_sparks.size() - 1, -1, -1):
		var s: Dictionary = _sparks[i]
		s.t += dt
		if s.t >= s.life:
			_sparks.remove_at(i)
			continue
		s.v.y -= Ball.GRAV * float(s.g) * dt
		s.p += (s.v as Vector3) * dt
		if s.p.y < s.floor:
			s.p.y = s.floor
			s.v *= Vector3(0.5, -0.3, 0.5)
	for i in range(_rings.size() - 1, -1, -1):
		_rings[i].t += dt
		if _rings[i].t >= _rings[i].life:
			_rings.remove_at(i)
	for i in range(_puffs.size() - 1, -1, -1):
		var p: Dictionary = _puffs[i]
		p.t += dt
		if p.t >= p.life:
			_puffs.remove_at(i)
			continue
		p.v *= pow(0.25, dt)
		p.p += (p.v as Vector3) * dt
	for i in range(_debris.size() - 1, -1, -1):
		var d: Dictionary = _debris[i]
		d.t += dt
		if d.t > d.life:
			_debris.remove_at(i)
			continue
		d.v.y -= Ball.GRAV * dt
		d.p += (d.v as Vector3) * dt
		if d.p.y < d.floor + d.s:
			d.p.y = d.floor + d.s
			d.v *= Vector3(0.6, -0.3, 0.6)
	for i in range(_chunks.size() - 1, -1, -1):
		var c: Dictionary = _chunks[i]
		c.t += dt
		if c.t >= c.life:
			_chunks.remove_at(i)
			continue
		c.v.y -= Ball.GRAV * 0.4 * dt
		c.p += (c.v as Vector3) * dt
		c.b = Basis(Vector3.BACK, float(c.w) * dt) * (c.b as Basis)
	for i in range(_rockets.size() - 1, -1, -1):
		var r: Dictionary = _rockets[i]
		r.t += dt
		r.p += (r.v as Vector3) * dt
		if _rng.randf() < 0.7:
			_spark(r.p, Vector3(_rng.randf_range(-0.5, 0.5), -2.0, _rng.randf_range(-0.5, 0.5)) * size, 0.35, Color("ffc070"), 0.06 * size * float(r.k) + 0.03, 0.2)
		if r.t >= r.fuse:
			_rockets.remove_at(i)
			var col: Color = r.c
			var k: float = r.k
			for j in 46:
				var d := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()
				_spark(r.p, d * _rng.randf_range(7.0, 10.0) * k, _rng.randf_range(0.9, 1.4), col.lerp(Color.WHITE, _rng.randf() * 0.35), 0.22 * k + 0.04, 0.18, room.floor)
			_sfx("firework_burst", 0.9, r.p)


# ---- drawing ----

## Where the big banner shows: between you and him, a little above your eye.
func banner_at() -> Vector3:
	var to: Vector3 = (giant.c as Vector3) - viewer if giant.on else (room.home as Vector3) - viewer
	to.y = 0.0
	var d := minf(9.0 * size, to.length() * 0.5)
	var dir := to.normalized() if to.length_squared() > 1e-6 else Vector3.FORWARD
	var at := viewer + dir * d + Vector3.UP * d * 0.2  # low, under the HUD's score digits
	if room.ceil < INF:
		at.y = minf(at.y, room.ceil - 1.2 * size)
	return at


func _face(p: Vector3) -> Basis:
	var to := viewer - p
	to.y = 0.0
	if to.length_squared() < 1e-6:
		return Basis.IDENTITY
	return Basis.looking_at(to.normalized(), Vector3.UP, true)


static func seg_color(f: float) -> Color:
	if f > 0.5:
		return Color("ffd23f").lerp(Color("5dff8a"), (f - 0.5) * 2.0)
	return Color("ff3d5a").lerp(Color("ffd23f"), f * 2.0)


## Segment i of the hit-points ring (0 = the left end), scale k.
func seg_xf(i: int, k: float) -> Transform3D:
	var a := -ARC / 2.0 + ARC * (i + 0.5) / SEGS
	var fb := _ring_fb
	var p := _ring_c + fb * (Vector3(sin(a), cos(a), 0) * _ring_r)
	var w := _ring_r * ARC / SEGS * 0.72
	return Transform3D(fb * Basis(Vector3.BACK, -a) * Basis.from_scale(Vector3(w * k, _ring_r * 0.075 * k, _ring_r * 0.03)), p)


func draw() -> void:
	var g := giant
	var shells: MultiMesh = _mm.shells
	var targets: MultiMesh = _mm.targets
	var ripples: MultiMesh = _mm.ripples
	var patches: MultiMesh = _mm.patches
	var shadows: MultiMesh = _mm.shadows
	var stars: MultiMesh = _mm.stars
	var nsh := 0
	var nt := 0
	var np := 0
	var nshadow := 0
	var nmouth := 0
	var nstar := 0
	for b in [g] + meds:
		var v: DahroojView = b.view
		v.visible = b.on
		for sp in b.spots:
			(sp.proxy as MeshInstance3D).visible = false
		if not b.on:
			continue
		var xf := body_xf(b)
		v.transform = xf
		var blink: bool = b.blink > 0.0
		var face: String = b.face if b.face_t > 0.0 or b.face == "focus" else "joy"
		if b.mouth > 0.12 and face in ["joy", "wide", "laugh"]:
			face = "open" if face != "laugh" else "squint"
		v.set_face(face, blink and face in DahroojView.EYE_FACES, b.look)
		if b.eye_pop > 0.0:
			for e in v.eyes:
				(e.ball as Node3D).scale *= 1.0 + 0.35 * float(b.eye_pop)
		# Glow: rage red, the hit flash, the slime sheen.
		var col := Color(0, 0, 0, 0)
		var glow: float = b.glow * (0.75 + 0.25 * sin(time * 9.0))
		if glow > 0.01:
			col = Color(1.0, 0.1, 0.06) * glow * 2.6
		if b.flash > 0.0:
			col += Color(1, 0.95, 0.8) * float(b.flash) * 0.45
		if b.melt > 0.05 or not b.big:
			col += Color(0.3, 1.0, 0.4) * (0.35 * float(b.melt) if b.big else 0.18)
		if col.r + col.g + col.b > 0.02 and nsh < shells.instance_count:
			shells.set_instance_transform(nsh, Transform3D(xf.basis * Basis.from_scale(Vector3.ONE * 1.05), xf.origin))
			shells.set_instance_color(nsh, Color(col.r, col.g, col.b, 1.0))
			nsh += 1
		if glow > 0.01 and nsh < shells.instance_count:
			# The rage aura, a wider haze.
			shells.set_instance_transform(nsh, Transform3D(xf.basis * Basis.from_scale(Vector3.ONE * (1.16 + 0.04 * sin(time * 7.0))), xf.origin))
			shells.set_instance_color(nsh, Color(1.0, 0.18, 0.05) * glow * 0.9)
			nsh += 1
		# The mouth, open as wide as he shouts.
		if b.mouth > 0.04 and b.melt < 0.3:
			var mo: float = b.mouth
			var md := Vector3(0, -0.29, 0.957).normalized()
			var mm: MultiMesh = _mm.mouths
			mm.set_instance_transform(nmouth, xf * Transform3D(Basis.looking_at(md, Vector3.UP, true) * Basis.from_scale(Vector3(0.9 + 0.5 * mo, 0.25 + 1.1 * mo, 1.0)), Vector3.ZERO))
			mm.set_instance_color(nmouth, Color.WHITE)
			nmouth += 1
		# The patch.
		if b.melt < 0.3 and np < patches.instance_count:
			var pd := spot_dir("patch")
			patches.set_instance_transform(np, xf * Transform3D(Basis.looking_at(pd, Vector3.UP, true), Vector3.ZERO))
			patches.set_instance_color(np, Color.WHITE)
			np += 1
		# The weak spots: a target hugging the body, pulsing, with a ripple going out.
		var inv_t := xf.basis.inverse().transposed()
		for sp in b.spots:
			if not sp.on:
				continue
			var d := spot_local(sp)
			var up := Vector3.UP if absf(d.y) < 0.98 else Vector3.BACK
			var rb := Basis.looking_at(d, up, true)
			var key_k: float = SPOT_SIZE.get(sp.key, 1.0)
			var pulse := 1.0 + 0.08 * sin(time * 10.0)
			var appear := 1.0 if sp.cd <= 0.0 else 0.0
			sp.at = xf * (d * 1.03)
			sp.n = (inv_t * d).normalized()
			sp.rad = float(b.r) * 0.3 * key_k
			if appear <= 0.0:
				continue
			var gold := Color("ffd23f") if b.glow < 0.5 else Color("fff27a")
			targets.set_instance_transform(nt, xf * Transform3D(rb * Basis.from_scale(Vector3(key_k * pulse, key_k * pulse, 1.0)), Vector3.ZERO))
			targets.set_instance_color(nt, Color(gold.lerp(Color.WHITE, 0.5 + 0.5 * sin(time * 14.0)), 0.95))
			var u := fmod(time * 1.6 + nt * 0.37, 1.0)
			ripples.set_instance_transform(nt, xf * Transform3D(rb * Basis.from_scale(Vector3.ONE * key_k * (1.0 + u * 1.2)) * Basis.from_scale(Vector3(1, 1, 1.0 / (key_k * (1.0 + u * 1.2)))), Vector3.ZERO))
			ripples.set_instance_color(nt, Color(gold, (1.0 - u) * 0.8))
			nt += 1
			var px := sp.proxy as MeshInstance3D
			px.visible = b.solid
			px.transform = Transform3D(Basis.from_scale(Vector3.ONE * float(sp.rad)), sp.at)
		# A soft shadow on the floor.
		if nshadow < shadows.instance_count:
			var h := maxf(0.0, float(b.y))
			var kk := clampf(1.0 - h / (float(b.r) * 4.0), 0.2, 1.0)
			var wide := (1.0 + 0.8 * float(b.melt)) * float(b.k) * float(b.sx_k)
			shadows.set_instance_transform(nshadow, Transform3D(Basis.from_scale(Vector3.ONE * float(b.r) * wide * (0.7 + 0.3 * kk)), Vector3((b.g as Vector3).x, room.floor + 0.04, (b.g as Vector3).z)))
			shadows.set_instance_color(nshadow, Color(0.05, 0.02, 0.08, 0.4 * kk))
			nshadow += 1
		# Dizzy stars.
		if b.dizzy > 0.0:
			var ns := 5 if b.big else 3
			var top: Vector3 = xf * Vector3(0, 1.15, 0.0) if b.tilt < 0.6 else xf * Vector3(0, 0.0, 1.2)
			for s in ns:
				var a: float = time * 6.0 + TAU * s / ns
				var p := top + Vector3(cos(a), 0.15 * sin(a * 2.0), sin(a)) * float(b.r) * 0.55
				if nstar < STARS_MAX:
					stars.set_instance_transform(nstar, Transform3D(_face(p) * Basis(Vector3.BACK, time * 4.0 + s) * Basis.from_scale(Vector3.ONE * float(b.r) * 0.1), p))
					stars.set_instance_color(nstar, Color("fff27a").srgb_to_linear())
					nstar += 1
	shells.visible_instance_count = nsh
	targets.visible_instance_count = nt
	ripples.visible_instance_count = nt
	patches.visible_instance_count = np
	(_mm.mouths as MultiMesh).visible_instance_count = nmouth
	stars.visible_instance_count = nstar
	# The little ones.
	crowd.begin()
	for mi in minions:
		var px := mi.proxy as MeshInstance3D
		px.visible = mi.on
		if not mi.on:
			continue
		var c: Vector3 = mi.p
		var r: float = mi.r
		var near_ground: float = clampf(1.0 - (c.y - room.floor - r) / (r * 0.6), 0.0, 1.0) if mi.ph == "hop" else 0.0
		var sq := Vector2(1.0 + 0.18 * near_ground, 1.0 - 0.25 * near_ground)
		if mi.ph == "fly":
			sq = Vector2(0.9, 1.15)
		var col := Color(mi.color)
		if mi.flash > 0.0:
			col = col.lerp(Color.WHITE, 0.7 * float(mi.flash))
		crowd.add(mi.style, c, r, viewer, sq, "wide" if mi.ph == "fly" else ("shut" if fmod(float(mi.life), 2.3) < 0.12 else "open"), mi.acc, col)
		px.transform = Transform3D(Basis.from_scale(Vector3.ONE * r * 1.3), c)
		if nshadow < shadows.instance_count:
			shadows.set_instance_transform(nshadow, Transform3D(Basis.from_scale(Vector3.ONE * r * 0.9), Vector3(c.x, room.floor + 0.03, c.z)))
			shadows.set_instance_color(nshadow, Color(0.05, 0.02, 0.08, 0.3))
			nshadow += 1
	crowd.end()
	shadows.visible_instance_count = nshadow
	_draw_props()
	_draw_ring()
	_draw_breach()
	_draw_fx()
	_draw_labels()


func _draw_props() -> void:
	var counts := {"crate": 0, "barrel": 0, "cone": 0}
	for p in props:
		var mm: MultiMesh = _mm[p.kind]
		var i: int = counts[p.kind]
		var t: Vector3 = p.tilt
		var tb := Basis(t.normalized(), t.length()) if t.length_squared() > 1e-8 else Basis.IDENTITY
		mm.set_instance_transform(i, Transform3D(tb * Basis(Vector3.UP, float(p.yaw)) * Basis.from_scale(Vector3.ONE * float(p.s)), (p.p as Vector3) + Vector3.UP * float(p.y)))
		mm.set_instance_color(i, Color.WHITE)
		counts[p.kind] = i + 1
	for k in counts:
		(_mm[k] as MultiMesh).visible_instance_count = counts[k]


func _draw_ring() -> void:
	var segs: MultiMesh = _mm.segs
	var g := giant
	var shown: bool = F.state == "fight" or (F.state == "enter" and (F.enter == "sky" or F.t > 1.3))
	if not shown:
		segs.visible_instance_count = 0
		lv_label.visible = false
		return
	var base: Vector3 = room.home if F.split != "" or not g.on else g.g
	var want: Vector3 = base + Vector3.UP * float(room.r) - fwd_of(base) * float(room.r) * 0.35
	_ring_c = _ring_c.lerp(want, 0.15)
	_ring_r = float(room.r) * 1.25
	_ring_fb = _face(_ring_c)
	var n := 0
	var f := _shown_hp
	var hot: float = g.flash
	for i in SEGS:
		var u := (i + 0.5) / SEGS
		segs.set_instance_transform(n, seg_xf(i, 1.3))
		segs.set_instance_color(n, Color(Color("221a33").srgb_to_linear(), 0.85))
		n += 1
		var col: Color
		var k := 1.0
		if u <= f:
			col = seg_color(f).lerp(Color.WHITE, hot * 0.6)
			if F.phase == 4:
				col = col.lerp(Color("ff2040"), 0.4 + 0.3 * sin(time * 10.0))
			col = Color(col.srgb_to_linear(), 1.0)
		elif u <= _ghost:
			col = Color(1, 1, 1, 0.9)
		else:
			col = Color(Color("3a3150").srgb_to_linear(), 0.7)
			k = 0.7
		segs.set_instance_transform(n, seg_xf(i, k).translated_local(Vector3(0, 0, 0.6)))
		segs.set_instance_color(n, col)
		n += 1
	segs.visible_instance_count = n
	lv_label.visible = not banner.visible
	lv_label.text = _tx("العملاق مستوى %s" % GameCtx.ar_digits(F.lv), "GIANT Lv.%d" % F.lv)
	lv_label.position = _ring_c + fwd_of(_ring_c) * float(room.r) * 1.1 + Vector3.UP * (_ring_r + float(room.r) * 0.12)
	lv_label.scale = Vector3.ONE * clampf(lv_label.position.distance_to(viewer) / 12.0, 0.5, 3.0)
	lv_label.modulate = Color("ff6b6b") if F.phase == 4 else Color("fff3e0")


func _draw_breach() -> void:
	var bulge: MultiMesh = _mm.bulge
	var cracks: MultiMesh = _mm.cracks
	var hole: MultiMesh = _mm.hole
	if not breach.on:
		bulge.visible_instance_count = 0
		cracks.visible_instance_count = 0
		hole.visible_instance_count = 0
		return
	var n: Vector3 = breach.n
	var hb := MoleStage.basis_up(n).rotated(n, float(breach.spin))
	var r: float = breach.r
	var p: Vector3 = breach.p
	var jolt: float = breach.jolt
	if breach.bulge > 0.0 and breach.hole <= 0.0:
		var s: float = breach.bulge
		var shake := Vector3(sin(time * 60.0), cos(time * 53.0), 0) * jolt * r * 0.03
		bulge.set_instance_transform(0, Transform3D(hb * Basis.from_scale(Vector3(r * (0.4 + 0.6 * s) * (1.0 + 0.08 * jolt), r * 0.38 * s * (1.0 + 0.3 * jolt), r * (0.4 + 0.6 * s) * (1.0 + 0.08 * jolt))), p + hb * shake))
		bulge.set_instance_color(0, Color.WHITE)
		bulge.visible_instance_count = 1
	else:
		bulge.visible_instance_count = 0
	if breach.crack > 0.0 and breach.hole <= 0.0:
		var c: float = breach.crack
		cracks.set_instance_transform(0, Transform3D(hb * Basis.from_scale(Vector3(r * 1.3 * c, 1.0, r * 1.3 * c)), p + n * (r * 0.02 + 0.01)))
		cracks.set_instance_color(0, Color.WHITE)
		cracks.visible_instance_count = 1
	else:
		cracks.visible_instance_count = 0
	if breach.hole > 0.0:
		hole.set_instance_transform(0, Transform3D(hb * Basis.from_scale(Vector3(r, r, r)), p + n * 0.01))
		hole.set_instance_color(0, Color.WHITE)
		hole.visible_instance_count = 1
	else:
		hole.visible_instance_count = 0


func _draw_fx() -> void:
	var sp: MultiMesh = _mm.sparks
	var n := mini(_sparks.size(), SPARKS_MAX)
	for i in n:
		var s: Dictionary = _sparks[i]
		var k: float = 1.0 - float(s.t) / float(s.life)
		sp.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * float(s.s) * (0.4 + 0.6 * k)), s.p))
		sp.set_instance_color(i, Color((s.c as Color).srgb_to_linear(), clampf(k * 1.6, 0.0, 1.0)))
	sp.visible_instance_count = n
	var rings: MultiMesh = _mm.rings
	for i in _rings.size():
		var g: Dictionary = _rings[i]
		var k: float = clampf(float(g.t) / float(g.life), 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 3.0)
		var rad: float = lerpf(g.r0, g.r1, e)
		var rn: Vector3 = g.n
		rings.set_instance_transform(i, Transform3D(MoleStage.basis_up(rn) * Basis.from_scale(Vector3(rad, rad * 1.6, rad)), g.p))
		rings.set_instance_color(i, Color((g.c as Color).srgb_to_linear(), 1.0 - k))
	rings.visible_instance_count = _rings.size()
	var puffs: MultiMesh = _mm.puffs
	for i in _puffs.size():
		var p: Dictionary = _puffs[i]
		var k: float = clampf(float(p.t) / float(p.life), 0.0, 1.0)
		var s := lerpf(p.s0, p.s1, 1.0 - pow(1.0 - k, 2.0))
		puffs.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s, s * 0.8, s)), p.p))
		puffs.set_instance_color(i, Color((p.c as Color).srgb_to_linear(), 0.55 * (1.0 - k)))
	puffs.visible_instance_count = _puffs.size()
	var deb: MultiMesh = _mm.debris
	for i in _debris.size():
		var d: Dictionary = _debris[i]
		var k: float = 1.0 - maxf(0.0, (d.t - d.life * 0.7) / (d.life * 0.3))
		deb.set_instance_transform(i, Transform3D(Basis(d.ax, d.t * d.w) * Basis.from_scale(Vector3.ONE * d.s * maxf(0.01, k) * 2.0), d.p))
		deb.set_instance_color(i, d.c)
	deb.visible_instance_count = _debris.size()
	var ch: MultiMesh = _mm.chunks
	for i in _chunks.size():
		var c: Dictionary = _chunks[i]
		var k: float = 1.0 - float(c.t) / float(c.life)
		ch.set_instance_transform(i, Transform3D(c.b, c.p))
		ch.set_instance_color(i, Color((c.c as Color).lerp(Color.WHITE, 0.4).srgb_to_linear(), k))
	ch.visible_instance_count = _chunks.size()


func _draw_labels() -> void:
	var bt: float = F.banner_t
	banner.visible = bt > 0.0 and banner.text != ""
	banner_sub.visible = banner.visible and banner_sub.text != ""
	if banner.visible:
		var at := banner_at()
		var dk := clampf(at.distance_to(viewer) / 9.0, 0.3, 3.0)
		var life: float = F.banner_life
		var age := maxf(0.0, life - bt)
		var inn := minf(1.0, age / 0.35)
		var over := 1.0 + 0.35 * sin(inn * PI) * (1.0 - inn * 0.5)
		var out := clampf((0.45 - bt) / 0.45, 0.0, 1.0)
		var s := (0.3 + 0.7 * inn) * over * (1.0 + out * 0.4) * dk
		banner.position = at + Vector3.UP * out * 0.35 * dk
		banner.scale = Vector3.ONE * s
		banner.modulate.a = 1.0 - out
		banner_sub.position = at + Vector3(0, -1.05, 0) * dk + Vector3.UP * out * 0.35 * dk
		banner_sub.scale = Vector3.ONE * minf(1.0, age / 0.5) * dk
		banner_sub.modulate.a = 1.0 - out
		BannerFit.fit([banner, banner_sub])  # the same distance in every mode
	var ct: float = F.combo_show_t
	combo_label.visible = ct > 0.0
	if combo_label.visible:
		var a := 1.1 - ct
		var ck := clampf((F.combo_at as Vector3).distance_to(viewer) / 9.0, 0.45, 2.5)
		combo_label.position = (F.combo_at as Vector3) + Vector3.UP * (1.4 + a * 0.6) * ck
		combo_label.scale = Vector3.ONE * ck * (0.6 + 0.6 * minf(1.0, a * 6.0)) * (1.0 + 0.08 * sin(a * 30.0) * (1.0 - a))
		combo_label.modulate.a = clampf(ct / 0.3, 0.0, 1.0)


## For tests and the HUD.
func giant_state() -> Dictionary:
	var alive := 0
	for mi in minions:
		if mi.on:
			alive += 1
	var med_on := 0
	for m in meds:
		if m.on:
			med_on += 1
	return {"state": F.state, "lv": F.lv, "hp": F.hp, "max_hp": F.max_hp, "phase": F.phase, "split": F.split,
		"score": F.score, "combo": F.combo, "mult": F.mult, "kos": F.kos, "minions": alive, "meds": med_on,
		"r": giant.r, "home": room.home, "enter": F.enter, "look": [(giant.view as DahroojView).style, (giant.view as DahroojView).color_id, (giant.view as DahroojView).accessory]}
