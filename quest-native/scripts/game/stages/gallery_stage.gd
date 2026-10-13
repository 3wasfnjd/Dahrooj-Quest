class_name GalleryStage
extends Node3D
## Dahrooj Gallery («ميدان الرماية», mode "gallery"): a lively fairground shooting gallery.
## Dahroojs pop up and the player knocks them over with blaster shots or thrown Dahroojs:
##
## - cardboard targets (a flat painted Dahrooj on a target disc and a stick) flip up off the
##   ground with a clack, stand a moment and flip down; hit, they fall back with a clack and
##   a spray of cardboard chips.
## - carousel rows at three depths (VR): a near row of cardboard targets, a middle row and a
##   far, faster row of little Dahroojs sliding on rails behind painted boards, each row the
##   other way round.
## - swingers: Dahroojs lowered on ropes from the gantry, swinging side to side.
## - peekers: Dahroojs that lean out from behind cover (crates, a bush, a tree, barrels) and
##   duck back; the cover is solid, so shots and throws stop on it.
## - trick shots: a Dahrooj tossed up from behind cover for a split second (big bonus).
## - crowned Dahroojs are friendly: hitting one only makes it go "ouch!" (dizzy stars) and
##   resets the streak; no points are lost.
## - bonuses: the eyes are the bullseye (+15), far targets give a distance bonus, a streak of
##   quick hits raises the multiplier (×2 .. ×6) with big banners, fireworks from ×3 on.
## - every minute or so a rapid round: a drumroll, then for ten seconds everything comes faster
##   and every hit counts double.
## - open play: no lives, no timer, no board, no losing; a lull only lets the streak run out.
##   Endless and slowly escalating (more targets, faster). Points go to ctx.counts["gallery"]
##   (the jelly score popup).
##
## Mixed reality: `planes_provider` returns the room's planes in game units, as
## SlimeStage.planes_provider does ({pos, normal, ax, ay, half, label}; furniture boxes as their
## top and side faces). Then the court's booth and cover hide and the room is the gallery:
## rails run along the walls, cardboard targets flip up on the floor and furniture tops and spin
## round on the walls, Dahroojs peek over the far edges of furniture and out of wall edges, hang
## from the ceiling on ropes (from the tops of the walls without a ceiling) and are tossed up
## from the floor. No usable planes: the court's booth.
## Game units, like the other stages. The blaster finds targets through hidden (layers = 0)
## sphere MeshInstance3Ds; the cover is real MeshInstance3Ds (they stop shots); the booth and
## every effect are MultiMeshes or JuiceTexts (shots pass through them).

const R := 0.6  # a Dahrooj target's radius (game units, × size)
const CARD_R := 0.72  # a cardboard target's disc radius (× size)
const CARD_H := 1.85  # its centre above the hinge (× disc radius): the stick
const SLOTS := 36
const FX_MAX := 1500
const ROCKETS_MAX := 8
const RINGS_MAX := 16
const STARS_MAX := 36
const IN_T := 0.2
const OUT_T := 0.2
const HIT_T := 0.42
const OUCH_T := 1.1
const SWING_IN := 0.55
const FLIP_D := 0.9  # a rail's targets flip up / down over this distance at its ends (× size)
const COMBO_T := 3.2  # seconds without a hit before the streak runs out
const STEPS := [3, 6, 10, 15, 21]  # streak lengths where the multiplier steps up (×2 .. ×6)
const RAPID_FIRST := 42.0
const RAPID_EVERY := 55.0
const RAPID_T := 10.0
const ROLL_T := 1.8
const RAPID_K := 1.5
const LEVEL_T := 35.0  # play seconds per level of intensity
const BANNER_T := 2.2
const PTS := {"card": 10, "rail": 10, "swing": 15, "peek": 15, "toss": 30}
const GOLD_K := 3
const BULLSEYE_PTS := 15
const FRIENDLY_P := 0.16
const GOLD_P := 0.07
const EYES := [Vector2(-0.3, 0.08), Vector2(0.3, 0.08)]  # in the Dahrooj's unit frame (crowd.gd)
const EYE_R := 0.27
const COLORS := ["ff69b4", "b36bff", "ff9b3d", "6fa8d6", "7bbf8a", "e2603f", "46aaa9", "58b9ff", "ff505c", "9b7bff"]
const FRIEND_COLORS := ["ffd6e8", "d8f3ff", "e6ffd9", "fff1c9"]
const STYLES := ["jelly", "fur", "clay", "fabric", "bubble", "clay", "jelly"]
const ACCS := ["", "", "", "party", "glasses", "cap", "flower", "headphones", "scarf"]
const RING := {"plain": "e8453c", "gold": "ffc21a", "friendly": "3fc46a"}
const FIREWORKS := [["ff4fa3", "ffd23f", "ffffff"], ["58b9ff", "b36bff", "e8f4ff"], ["7bff8a", "fff27a", "ffffff"],
	["ff7a3d", "ffd23f", "ff4f4f"], ["ff69b4", "7fd8ff", "fff3b0"]]
const BULB_COLORS := ["ffd23f", "ff5a4a", "fff3b0", "58b9ff", "7bff8a"]
const STREAK_WORDS := [["رائع!", "Great!"], ["مذهل!", "Amazing!"], ["خرافي!", "Legendary!"], ["لا يُصدّق!", "Unbelievable!"], ["أسطوري!", "Mythic!"]]

## The court's booth (VR): rows (rails) and where things happen.
## Rows: z, y (rail / hinge height), board top, from x0 to x1, speed (× size / s), flat (cards),
## k (target size), spacing.
const ROWS_VR := [
	{"z": -7.6, "y": 0.0, "board": 0.55, "x0": -9.6, "x1": 9.6, "speed": 2.0, "flat": true, "k": 0.95, "space": 2.2},
	{"z": -12.8, "y": 2.0, "board": 2.0, "x0": 9.8, "x1": -9.8, "speed": 2.5, "flat": false, "k": 1.0, "space": 2.0},
	{"z": -18.6, "y": 3.6, "board": 3.6, "x0": -10.4, "x1": 10.4, "speed": 3.2, "flat": false, "k": 0.9, "space": 1.9},
]
const COVERS_VR := [
	{"kind": "crates", "pos": Vector3(-5.4, 0, -10.2), "half": Vector3(0.95, 1.35, 0.9)},
	{"kind": "bush", "pos": Vector3(5.6, 0, -10.4), "half": Vector3(1.55, 1.1, 1.0)},
	{"kind": "barrels", "pos": Vector3(1.2, 0, -15.8), "half": Vector3(1.35, 0.8, 0.7)},
	{"kind": "tree", "pos": Vector3(-5.0, 0, -22.0), "half": Vector3(0.72, 2.2, 0.72)},
]
const CARD_SPOTS_VR := [Vector3(-1.9, 0, -9.8), Vector3(2.1, 0, -9.6), Vector3(-8.0, 0, -11.4), Vector3(0.2, 0, -11.3),
	Vector3(8.6, 0, -11.4), Vector3(-3.0, 0, -15.2), Vector3(4.4, 0, -15.6), Vector3(-1.2, 0, -16.8), Vector3(7.4, 0, -16.6),
	Vector3(-9.0, 0, -15.6), Vector3(-2.2, 0, -22.4), Vector3(1.8, 0, -22.6), Vector3(5.8, 0, -21.6), Vector3(-8.2, 0, -21.0),
	Vector3(9.4, 0, -21.2)]
const GANTRY_Z := -14.8
const GANTRY_Y := 10.8
const GANTRY_X := 10.2
const ANCHORS_VR := [-7.2, -4.3, -1.4, 1.4, 4.3, 7.2]
const VIEW_VR := Vector3(0, 3.2, 1.0)

## Particles: a billboard quad whose motion is in the shader (written once, never updated).
## Instance: origin = start, basis x = (size, 0, 0), y = (0, gravity, 0), z = velocity;
## custom = (t0, life, kind, drag); colour = linear rgba. Kinds: 0 flash, 1 spark, 2 glitter, 3 chip.
const FX_CODE := """
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, fog_disabled;
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
	if (kind < 0.5) { s *= 0.6 + 0.6 * k; }
	else if (kind < 1.5) { s *= 1.0 - 0.7 * k; }
	else if (kind < 2.5) { s *= 1.0 - 0.5 * k; }
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
	float glow = 0.7;
	if (kind > 2.5) {
		a = 1.0 - smoothstep(0.7, 0.9, max(abs(q.x), abs(q.y) * 1.4));
		a *= 1.0 - smoothstep(0.75, 1.0, k);
		glow = 1.0;
	} else {
		a = exp(-d * d * 4.5) * (1.0 - smoothstep(0.85, 1.0, d));
		col = col * (1.0 + 1.4 * exp(-d * d * 30.0));
		if (kind < 0.5) { a *= (1.0 - k) * (1.0 - k); }
		else if (kind < 1.5) { a *= 1.0 - k * k; }
		else { a *= (1.0 - k * k) * (0.6 + 0.4 * sin(TIME * 40.0 + v_k.z * 60.0)); }
	}
	a = clamp(a * v_col.a, 0.0, 1.0);
	ALBEDO = col * a;
	ALPHA = a * glow;
}
"""

static var _meshes := {}

var aim_z := -10.0
var far_z = -24.0
var reach_z = null
var friction = null
var shot_time = 4.0
var ctx: GameCtx

## Room planes (mixed reality), as SlimeStage.planes_provider; [] or invalid: the court's booth.
var planes_provider: Callable
## Spots all around the player (mixed reality, RoomSpots; as MoleStage.spots_provider, called
## with the kinds wanted): cardboard targets, tosses, peekers and swingers then pick a side the
## player has not been looking at. Without a scan (ring spots) the cardboard targets flip up and
## the tosses jump all around the player, the rest stays at the booth.
var spots_provider: Callable
## Size of the targets and their effects (mixed reality wants 2).
var size := 1.0
## The player's eye (game units): targets face it. Main keeps it current.
var viewer := VIEW_VR
## buzz(hand: String, amp: float, ms: float): haptics (main's buzz).
var buzz: Callable
## Targets come on their own (tests turn it off and call spawn()).
var auto_spawn := true
## Main holds the game while the menu is open or the court is being placed.
var paused := false
var time := 0.0

var F := {"state": "idle", "t": 0.0, "score": 0, "streak": 0, "best": 0, "mult": 1, "combo_t": 0.0, "spd": 1.0,
	"spawn_t": 0.8, "rapid": "", "next_rapid": RAPID_FIRST, "roll_t": 0.0, "roll_tick": 0.0, "rapid_left": 0.0,
	"rapid_pts": 0, "rapids": 0, "beat_t": 0.0, "hits": 0, "bullseyes": 0, "tricks": 0, "ouches": 0, "fireworks": 0,
	"touched": false, "banner_t": 0.0, "banner_life": BANNER_T, "combo_show_t": 0.0, "combo_at": Vector3.ZERO}
var targets: Array = []
var rows: Array = []
var covers: Array = []
var crowd: Crowd
var banner: JuiceText
var banner_sub: JuiceText
var combo_label: JuiceText
var sign_label: Label3D
var booth: Node3D
var fx_spawned := 0
var _rings: Array = []
var _rockets: Array = []
var _fx_i := 0
var _fx_mat: ShaderMaterial
var _mm := {}
var _bulbs: Array = []  # [pos, phase]
var _planes: Array = []
var _room_sig := ""
var _room_t := 0.0
var _draw_acc := 0.0
var _lang := ""
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 5150
	name = "Gallery"
	crowd = Crowd.new(SLOTS, true, true)
	crowd.name = "Targets"
	add_child(crowd)
	for i in SLOTS:
		targets.append(_blank(_proxy("TargetHit%d" % i)))
	_fx_mat = _shader_mat(FX_CODE)
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	_mm.fx = _multi("Sparks", quad, _fx_mat, FX_MAX, true)
	(_mm.fx as MultiMesh).visible_instance_count = FX_MAX
	_mm.cards = _multi("Cards", card_mesh(), _mat("lit"), SLOTS)
	_mm.discs = _multi("Discs", card_mesh(false), _mat("lit"), SLOTS)
	_mm.ring = _multi("CardRings", Crowd.merge([[Crowd.torus(0.9, 0.075, 8, 40), Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.07)), Color.WHITE],
		[Crowd.torus(0.9, 0.075, 8, 40), Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.07)), Color.WHITE]]), _mat("lit"), SLOTS)
	_mm.ropes = _multi("Ropes", Crowd.merge([[Crowd.cylinder(1.0, 1.0, 1.0, 6), Transform3D(Basis.IDENTITY, Vector3(0, -0.5, 0)), Color("b08850")]]), _mat("lit"), SLOTS)
	_mm.shadows = _multi("Shadows", Crowd.merge([[Crowd.circle(1.0, 20), Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3.ZERO), Color.WHITE]]), _mat("shadow"), SLOTS)
	_mm.rings = _multi("Rings", Crowd.merge([[Crowd.torus(1.0, 0.06, 6, 40), Transform3D.IDENTITY, Color.WHITE]]), _mat("glow"), RINGS_MAX)
	_mm.stars = _multi("Stars", star_mesh(), _mat("flat2"), STARS_MAX)
	_build_booth()
	banner = _label("banner", 210 * 0.0062, Color("ffd166"))
	banner_sub = _label("sub", 96 * 0.0058, Color("fff3e0"))
	combo_label = _label("combo", 150 * 0.0058, Color("ff7ad9"))
	_refresh_room()
	draw()


func _blank(proxy: MeshInstance3D) -> Dictionary:
	return {"on": false, "mover": "card", "kind": "plain", "phase": "", "t": 0.0, "life": 2.0, "style": "jelly",
		"color": "ff69b4", "acc": "", "r": R, "flat": false, "flip": "hinge", "grow": false, "e": 0.0,
		"c": Vector3.ZERO, "rr": R, "xf": Transform3D(), "dx": Transform3D(), "show": false, "sq": Vector2.ONE,
		"base": Vector3.ZERO, "bx": Basis(), "hide": Vector3.ZERO, "out_p": Vector3.ZERO, "row": -1, "s": 0.0,
		"len": 1.0, "speed": 1.0, "a": Vector3.ZERO, "b": Vector3.ZERO, "up": Vector3.UP, "sink": true, "anchor": Vector3.ZERO,
		"rope": 4.0, "rope_end": Vector3.ZERO, "amp": 0.5, "w": 1.6, "ph": 0.0, "st": 0.0, "side": Vector3.RIGHT,
		"p": Vector3.ZERO, "v": Vector3.ZERO, "land_y": 0.0, "g": Ball.GRAV, "spin": 0.0, "src": -1,
		"look": 0.0, "look_to": 0.0, "look_t": 0.4, "blink": 0.0, "blink_t": 1.0, "hit_dir": Vector3.FORWARD,
		"ball_t": 0.0, "hid": -PI / 2.0, "proxy": proxy}


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
	proxy.mesh = _sphere_mesh()
	proxy.layers = 0  # never drawn: only the blaster's ray sees it
	proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	proxy.visible = false
	add_child(proxy)
	return proxy


static func _sphere_mesh() -> SphereMesh:
	if not _meshes.has("proxy"):
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 12
		s.rings = 6
		_meshes["proxy"] = s
	return _meshes["proxy"]


static func _shader_mat(code: String) -> ShaderMaterial:
	if not _meshes.has("sh_" + str(code.hash())):
		var sh := Shader.new()
		sh.code = code
		_meshes["sh_" + str(code.hash())] = sh
	var m := ShaderMaterial.new()
	m.shader = _meshes["sh_" + str(code.hash())]
	return m


static func _mat(key: String) -> Material:
	if _meshes.has("mat_" + key):
		return _meshes["mat_" + key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	match key:
		"lit":
			m.roughness = 0.8
		"wood":
			m.roughness = 0.9
		"glow", "flat", "flat2", "bulb":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			if key == "glow":
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
			if key == "flat2":
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"shadow":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.render_priority = -1
	_meshes["mat_" + key] = m
	return m


func _multi(id: String, mesh: Mesh, mat: Material, cap: int, custom := false, parent: Node = null) -> MultiMesh:
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
	(parent if parent else self).add_child(mi)
	return mm


## A cardboard target (unit disc radius, facing +Z, centre at the origin): the disc with a cream
## face on both sides and a stick down to the hinge at y = -CARD_H. The ring is CardRings.
static func card_mesh(stick := true) -> ArrayMesh:
	var key := "card" if stick else "disc"
	if _meshes.has(key):
		return _meshes[key]
	var x90 := Basis(Vector3.RIGHT, PI / 2.0)
	var list := [
		[Crowd.cylinder(1.0, 1.0, 0.1, 32), Transform3D(x90, Vector3.ZERO), Color("c98f55")],
		[Crowd.circle(0.97, 32), Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.052)), Color("fff1d6")],
		[Crowd.circle(0.97, 32), Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -0.052)), Color("e9c99a")],
	]
	if stick:
		list.append([Crowd.box(0.16, CARD_H - 0.9, 0.07), Transform3D(Basis.IDENTITY, Vector3(0, -(CARD_H + 0.9) / 2.0, -0.02)), Color("a8743f")])
		list.append([Crowd.box(0.5, 0.07, 0.2), Transform3D(Basis.IDENTITY, Vector3(0, -CARD_H + 0.035, -0.02)), Color("6e4a2e")])
	var mesh := Crowd.merge(list)
	_meshes[key] = mesh
	return mesh


## A chubby five-pointed star, flat (unit radius, facing +Z).
static func star_mesh() -> ArrayMesh:
	if _meshes.has("star"):
		return _meshes["star"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 10:
		var a0 := PI / 2 + TAU * i / 10.0
		var a1 := PI / 2 + TAU * (i + 1) / 10.0
		var r0 := 1.0 if i % 2 == 0 else 0.48
		var r1 := 0.48 if i % 2 == 0 else 1.0
		for p in [Vector3.ZERO, Vector3(cos(a1), sin(a1), 0) * r1, Vector3(cos(a0), sin(a0), 0) * r0]:
			st.set_color(Color.WHITE)
			st.set_normal(Vector3.BACK)
			st.add_vertex(p)
	var mesh := st.commit()
	_meshes["star"] = mesh
	return mesh


## The court's booth: painted row boards and rails, the striped gantry with its sign, bunting
## and bulbs (one MultiMesh: shots pass), and the cover (solid MeshInstance3Ds).
func _build_booth() -> void:
	booth = Node3D.new()
	booth.name = "Booth"
	add_child(booth)
	var list := []
	var x90z := Basis(Vector3.BACK, PI / 2.0)
	for ri in ROWS_VR.size():
		var row: Dictionary = ROWS_VR[ri]
		var z: float = row.z + 0.62
		var top: float = row.board
		var bot := maxf(0.0, top - (0.55 if ri == 0 else 0.85))
		var w := absf(float(row.x1) - float(row.x0)) + 0.6
		var segs := 14
		for s in segs:
			var x := -w / 2.0 + w * (s + 0.5) / segs
			list.append([Crowd.box(w / segs, top - bot, 0.16), Transform3D(Basis.IDENTITY, Vector3(x, (top + bot) / 2.0, z)), Color("d94a3a") if s % 2 == 0 else Color("fff1d6")])
		list.append([Crowd.box(w + 0.2, 0.12, 0.24), Transform3D(Basis.IDENTITY, Vector3(0, top + 0.03, z)), Color("f2c14e")])
		list.append([Crowd.box(w + 0.2, 0.08, 0.2), Transform3D(Basis.IDENTITY, Vector3(0, bot, z)), Color("8a3a2a")])
		if bot > 0.0:
			for x in [-w / 2.0, -w / 6.0, w / 6.0, w / 2.0]:
				list.append([Crowd.box(0.22, bot, 0.22), Transform3D(Basis.IDENTITY, Vector3(x, bot / 2.0, z)), Color("6e4a2e")])
		# The rail the row runs on.
		list.append([Crowd.cylinder(0.05, 0.05, w + 1.0, 8), Transform3D(x90z, Vector3(0, top - 0.12, row.z)), Color("9aa0b8")])
	# The gantry: red-and-white posts, a beam, the sign.
	for sx in [-1.0, 1.0]:
		var n := 8
		for k in n:
			var h := GANTRY_Y / n
			list.append([Crowd.cylinder(0.24, 0.24, h, 14), Transform3D(Basis.IDENTITY, Vector3(sx * GANTRY_X, h * (k + 0.5), GANTRY_Z)), Color("e8453c") if k % 2 == 0 else Color("fff4e6")])
		list.append([Crowd.sphere(0.36, 14, 10), Transform3D(Basis.IDENTITY, Vector3(sx * GANTRY_X, GANTRY_Y + 0.35, GANTRY_Z)), Color("f2c14e")])
	list.append([Crowd.box(GANTRY_X * 2.0, 0.36, 0.36), Transform3D(Basis.IDENTITY, Vector3(0, GANTRY_Y, GANTRY_Z)), Color("7a4a8a")])
	list.append([Crowd.box(8.2, 2.3, 0.2), Transform3D(Basis.IDENTITY, Vector3(0, GANTRY_Y + 1.45, GANTRY_Z - 0.06)), Color("f2c14e")])
	list.append([Crowd.box(7.8, 1.9, 0.26), Transform3D(Basis.IDENTITY, Vector3(0, GANTRY_Y + 1.45, GANTRY_Z)), Color("b8322a")])
	# Bunting under the beam.
	var cols := ["ff5a4a", "ffd23f", "58b9ff", "7bbf8a", "ff69b4", "b36bff"]
	var nb := 22
	for k in nb:
		var x := -GANTRY_X + 0.4 + (GANTRY_X * 2.0 - 0.8) * (k + 0.5) / nb
		var sag := 0.35 * sin(PI * (k + 0.5) / nb * 2.0) * sin(PI * (k + 0.5) / nb * 2.0)
		list.append([Crowd.cylinder(0.3, 0.0, 0.62, 3), Transform3D(Basis(Vector3.RIGHT, PI) * Basis(Vector3.UP, PI / 6.0), Vector3(x, GANTRY_Y - 0.45 - sag, GANTRY_Z + 0.05)), Color(cols[k % cols.size()])])
	var mm := _multi("BoothArt", Crowd.merge(list), _mat("lit"), 1, false, booth)
	mm.set_instance_transform(0, Transform3D.IDENTITY)
	mm.set_instance_color(0, Color.WHITE)
	mm.visible_instance_count = 1
	# Bulbs round the sign and along the beam.
	for k in 11:
		var x := -3.6 + 7.2 * k / 10.0
		_bulbs.append([Vector3(x, GANTRY_Y + 2.62, GANTRY_Z + 0.1), k])
		_bulbs.append([Vector3(x, GANTRY_Y + 0.28, GANTRY_Z + 0.2), k + 1])
	for k in 3:
		for sx in [-1.0, 1.0]:
			_bulbs.append([Vector3(sx * 4.08, GANTRY_Y + 0.85 + 0.6 * k, GANTRY_Z + 0.1), k])
	for k in 6:
		for sx in [-1.0, 1.0]:
			_bulbs.append([Vector3(sx * (4.8 + k * 0.48), GANTRY_Y + 0.22, GANTRY_Z + 0.2), k])
	_mm.bulbs = _multi("Bulbs", Crowd.merge([[Crowd.sphere(0.14, 10, 8), Transform3D.IDENTITY, Color.WHITE]]), _mat("bulb"), _bulbs.size(), false, booth)
	sign_label = Panel3D.label("", 190, Color("fff3d6"))
	sign_label.pixel_size = 0.0068
	sign_label.outline_size = 22
	sign_label.outline_modulate = Color("5a1410")
	sign_label.position = Vector3(0, GANTRY_Y + 1.42, GANTRY_Z + 0.16)
	booth.add_child(sign_label)
	# The cover: solid to shots and throws.
	for i in COVERS_VR.size():
		var cv: Dictionary = COVERS_VR[i]
		var mi := MeshInstance3D.new()
		mi.name = "Cover_" + String(cv.kind) + str(i)
		mi.mesh = cover_mesh(cv.kind)
		mi.material_override = _mat("wood")
		mi.position = cv.pos
		booth.add_child(mi)
		covers.append({"kind": cv.kind, "pos": cv.pos, "half": cv.half, "node": mi, "busy": false})


## The cover's look (origin on the ground at its middle).
static func cover_mesh(kind: String) -> ArrayMesh:
	if _meshes.has("cover_" + kind):
		return _meshes["cover_" + kind]
	var list := []
	match kind:
		"crates":
			for k in 2:
				var y := 0.675 + 1.35 * k
				var b := Basis(Vector3.UP, 0.08 if k == 0 else -0.1)
				list.append([Crowd.box(1.85 - k * 0.15, 1.35, 1.75 - k * 0.15), Transform3D(b, Vector3(0, y, 0)), Color("c4874a")])
				for sx in [-1.0, 1.0]:
					list.append([Crowd.box(0.16, 1.37, 1.79 - k * 0.15), Transform3D(b, b * Vector3(sx * (0.86 - k * 0.075), y, 0)), Color("8a5a30")])
				for sy in [-1.0, 1.0]:
					list.append([Crowd.box(1.89 - k * 0.15, 0.14, 1.79 - k * 0.15), Transform3D(b, b * Vector3(0, y + sy * 0.6, 0) + Vector3(0, 0, 0)), Color("8a5a30")])
				list.append([Crowd.box(0.16, 1.5, 0.05), Transform3D(b * Basis(Vector3.BACK, 0.62), b * Vector3(0, y, 0.89 - k * 0.075)), Color("8a5a30")])
		"bush":
			var greens := ["5aa63c", "6cbc45", "4a9233", "7cc84f", "d8cf3a"]
			var balls := [[0, 0.95, 0, 1.15], [-0.85, 0.75, 0.1, 0.85], [0.9, 0.7, 0.05, 0.9], [-0.35, 1.45, -0.1, 0.75],
				[0.45, 1.4, 0.05, 0.7], [0.0, 0.6, 0.55, 0.8], [-1.25, 0.5, 0.0, 0.55], [1.3, 0.48, -0.05, 0.55]]
			for k in balls.size():
				var q: Array = balls[k]
				list.append([Crowd.sphere(float(q[3]), 14, 10), Transform3D(Basis.IDENTITY, Vector3(q[0], q[1], q[2])), Color(greens[k % greens.size()])])
			var flowers := ["ff69b4", "fff3b0", "ff5a4a", "ffffff"]
			for k in 12:
				var a := TAU * k / 12.0 + 0.3
				var p := Vector3(cos(a) * 1.05, 0.95 + 0.45 * sin(a * 2.0), 0.55 + 0.25 * sin(a))
				list.append([Crowd.sphere(0.1, 8, 6), Transform3D(Basis.IDENTITY, p), Color(flowers[k % flowers.size()])])
		"barrels":
			for sx in [-1.0, 1.0]:
				var c := Vector3(sx * 0.66, 0.8, 0)
				list.append([Crowd.cylinder(0.6, 0.6, 1.6, 20), Transform3D(Basis.IDENTITY, c), Color("a5622f")])
				list.append([Crowd.cylinder(0.66, 0.66, 0.5, 20), Transform3D(Basis.IDENTITY, c), Color("b8733a")])
				for y in [-0.62, 0.62]:
					list.append([Crowd.cylinder(0.64, 0.64, 0.1, 20), Transform3D(Basis.IDENTITY, c + Vector3(0, y, 0)), Color("5a5d70")])
				list.append([Crowd.cylinder(0.5, 0.5, 0.04, 20), Transform3D(Basis.IDENTITY, c + Vector3(0, 0.81, 0)), Color("7a4520")])
		"tree":
			list.append([Crowd.cylinder(0.6, 0.78, 4.4, 16), Transform3D(Basis.IDENTITY, Vector3(0, 2.2, 0)), Color("8a5a36")])
			list.append([Crowd.cylinder(0.25, 0.4, 1.4, 10), Transform3D(Basis(Vector3.BACK, -0.8), Vector3(0.75, 3.6, 0)), Color("8a5a36")])
			var leaves := ["f0802c", "f29a38", "e0602a", "f6b347", "d9532b"]
			var blobs := [[0, 5.4, 0, 1.9], [-1.4, 4.8, 0.3, 1.3], [1.5, 4.9, -0.2, 1.4], [0.3, 6.6, 0.1, 1.3], [-0.8, 6.0, -0.6, 1.1], [1.0, 6.1, 0.6, 1.0]]
			for k in blobs.size():
				var q: Array = blobs[k]
				list.append([Crowd.sphere(float(q[3]), 14, 10), Transform3D(Basis.IDENTITY, Vector3(q[0], q[1], q[2])), Color(leaves[k % leaves.size()])])
	var mesh := Crowd.merge(list)
	_meshes["cover_" + kind] = mesh
	return mesh


# ---- ctx ----

func _num(v: int) -> String:
	return str(v) if _en() else GameCtx.ar_digits(v)


func _en() -> bool:
	return ctx != null and ctx.lang == "en"


func _tr(ar: String, en: String) -> String:
	return en if _en() else ar


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


# ---- effects ----

func _fx(p: Vector3, v: Vector3, life: float, col: Color, s: float, kind: int, g := 0.0, drag := 0.0) -> void:
	var mm: MultiMesh = _mm.fx
	var i := _fx_i
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


## A Dahrooj pops: sparks in its colour, white and gold, and a flash.
func _burst(at: Vector3, hex: String, k := 1.0) -> void:
	for i in int(26 * k):
		var c := _lin(hex) if i % 3 != 0 else _lin("fffaf2")
		if i % 5 == 4:
			c = _lin("ffd23f")
		_fx(at, _rand_dir() * _rng.randf_range(2.5, 6.0) * size * k + Vector3.UP * 1.5 * size, _rng.randf_range(0.4, 0.75), c, _rng.randf_range(0.12, 0.2) * size, 1, 6.0 * size, 1.2)
	_fx(at, Vector3.ZERO, 0.22, _lin("fff6e0"), 0.9 * size * k, 0)
	_ring(at, (viewer - at).normalized(), 0.3 * size, 1.4 * size * k, 0.28, Color(hex))


## Cardboard chips flying off a hit card.
func _chips(at: Vector3, dir: Vector3, k := 1.0) -> void:
	for i in int(14 * k):
		var v := (_rand_dir() * 2.6 + dir * 2.0 + Vector3.UP * 2.5) * size
		_fx(at, v, _rng.randf_range(0.55, 0.9), _lin("d9a066" if i % 3 else "fff1d6"), _rng.randf_range(0.06, 0.11) * size, 3, Ball.GRAV * size, 0.6)
	_fx(at, Vector3.ZERO, 0.18, _lin("fff6e0"), 0.7 * size * k, 0)


func _glitter(at: Vector3, n: int, hex: String) -> void:
	for i in n:
		_fx(at + _rand_dir() * 0.3 * size, _rand_dir() * _rng.randf_range(1.0, 3.0) * size, _rng.randf_range(0.5, 0.9), _lin(hex if i % 2 else "fff3b0"), 0.1 * size, 2, 1.5 * size, 1.5)


func _ring(at: Vector3, n: Vector3, r0: float, r1: float, life: float, col: Color) -> void:
	if _rings.size() >= RINGS_MAX:
		_rings.pop_front()
	_rings.append({"p": at, "n": n, "r0": r0, "r1": r1, "t": 0.0, "life": life, "c": col})


## kind: a JuiceText kind (a callout like BULLSEYE! is a small banner).
func _pop_label(at: Vector3, text: String, col: Color, k := 1.0, kind := "points") -> void:
	var sk := k * size * maxf(1.0, at.distance_to(viewer) / (12.0 * size))
	JuiceText.spawn(self, text, at, kind, sk * (0.55 if kind == "banner" else 1.0), col)

func _banner(text: String, sub: String, color: Color, secs := BANNER_T) -> void:
	banner.text = text
	banner.modulate = color
	banner_sub.text = sub
	F.banner_t = secs
	F.banner_life = secs


func banner_at() -> Vector3:
	if room():
		return Vector3(viewer.x, viewer.y + 1.3 * size, viewer.z - 11.0 * size)
	return Vector3(0, maxf(6.0, viewer.y + 2.7), -8.5)


## A firework rocket goes up from behind the gallery and bursts.
func launch_rocket(golden := false) -> void:
	if _rockets.size() >= ROCKETS_MAX:
		return
	var p: Vector3
	var v: Vector3
	if room():
		var fy := floor_y()
		p = Vector3(viewer.x + _rng.randf_range(-6.0, 6.0) * size, fy, viewer.z - _rng.randf_range(12.0, 16.0) * size)
		v = Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(7.0, 8.0), 0.5) * size
	else:
		p = Vector3(_rng.randf_range(-10.0, 10.0), 0.5, _rng.randf_range(-23.0, -20.0))
		v = Vector3(_rng.randf_range(-1.5, 1.5), _rng.randf_range(17.0, 19.5), 1.5)
	_rockets.append({"p": p, "v": v, "t": 0.0, "fuse": _rng.randf_range(0.85, 1.05), "gold": golden,
		"pal": FIREWORKS[_rng.randi() % FIREWORKS.size()]})
	_sfx("firework_launch", 0.8, p)


func _firework(at: Vector3, pal: Array, golden: bool) -> void:
	var n := 110 if not golden else 140
	var big := 1.0 if room() else 1.8
	for i in n:
		var c := _lin(String(pal[i % pal.size()]) if not golden else ["ffd23f", "fff3b0", "ffb347"][i % 3])
		_fx(at, _rand_dir() * _rng.randf_range(8.0, 11.0) * size * big * 0.8, _rng.randf_range(1.2, 1.8), c, _rng.randf_range(0.2, 0.32) * size * big, 2 if i % 2 else 1, 2.2 * size, 1.6)
	_fx(at, Vector3.ZERO, 0.35, _lin("fff6e0"), 3.0 * size * big, 0)
	_ring(at, (viewer - at).normalized(), 0.5 * size, 5.0 * size * big, 0.4, Color(String(pal[0])))
	F.fireworks += 1
	_sfx("firework_burst", 1.0, at)


func _step_rockets(dt: float) -> void:
	for i in range(_rockets.size() - 1, -1, -1):
		var k: Dictionary = _rockets[i]
		k.t += dt
		k.v.y -= 3.0 * size * dt
		k.p += (k.v as Vector3) * dt
		if _rng.randf() < 0.7:
			_fx(k.p, -(k.v as Vector3) * 0.15 + _rand_dir() * 0.4 * size, 0.5, _lin("ffc070"), (0.18 if room() else 0.3) * size, 1, 1.0 * size, 1.0)
		if k.t >= k.fuse:
			_firework(k.p, k.pal, k.gold)
			_rockets.remove_at(i)


# ---- the play ----

func level() -> float:
	return F.t / LEVEL_T


## Everything's pace: escalates with the minutes, much faster in a rapid round.
func pace() -> float:
	return (1.0 + minf(0.6, level() * 0.1)) * (RAPID_K if F.rapid == "on" else 1.0)


static func spawn_interval(lv: float) -> float:
	return lerpf(1.45, 0.62, clampf(lv / 6.0, 0.0, 1.0))


static func cap_at(lv: float) -> int:
	return 3 + mini(5, int(lv))


static func multiplier(streak: int) -> int:
	var m := 1
	for s in STEPS:
		if streak >= int(s):
			m += 1
	return m


func start() -> void:
	F.state = "play"
	F.t = 0.0
	F.next_rapid = RAPID_FIRST
	F.spawn_t = 0.8
	for row in rows:
		row.timer = _rng.randf_range(0.1, 0.8)
	_banner(_tr("ميدان الرماية", "DAHROOJ GALLERY"), _tr("أصب الدحاريج… ولا تصب المتوّج!", "Hit the Dahroojs, spare the crowned ones!"), Color("ffd166"), 3.0)
	_sfx("chime", 0.8, banner_at())
	_sfx("firework_launch", 0.5, banner_at())


func hit_count() -> int:
	return F.hits


func _alive(only_free := true) -> int:
	var n := 0
	for T in targets:
		if T.on and (not only_free or int(T.row) < 0):
			n += 1
	return n


func _step_director(dt: float) -> void:
	if not auto_spawn or F.state != "play":
		return
	var lv := level()
	F.spawn_t -= dt
	if F.spawn_t <= 0.0:
		var rapid: bool = F.rapid == "on"
		var cap := cap_at(lv) + (3 if rapid else 0)
		if _alive() < cap:
			var kinds := ["card", "card", "card", "peek", "peek", "peek", "swing", "swing"]
			if _rng.randf() < 0.22 + 0.04 * minf(lv, 5.0):
				kinds = ["toss"]
			for _k in 4:
				if spawn(kinds[_rng.randi() % kinds.size()]) >= 0:
					break
		F.spawn_t = spawn_interval(lv) * _rng.randf_range(0.7, 1.3) * (0.45 if rapid else 1.0)
	# The carousel rows keep rolling.
	for ri in rows.size():
		var row: Dictionary = rows[ri]
		row.timer -= dt * float(F.spd)
		if row.timer <= 0.0:
			var gap: float = float(row.space) / float(row.speed)
			if _rng.randf() < (0.62 if F.rapid != "on" else 0.85):
				spawn("rail", "", {"row": ri})
				row.timer = gap * _rng.randf_range(1.0, 1.6)
			else:
				row.timer = gap * _rng.randf_range(0.6, 1.0)


func _step_rapid(dt: float) -> void:
	if F.state != "play":
		return
	match String(F.rapid):
		"":
			F.next_rapid -= dt
			if F.next_rapid <= 0.0:
				F.rapid = "roll"
				F.roll_t = ROLL_T
				F.roll_tick = 0.0
				_banner(_tr("استعد…", "GET READY..."), _tr("جولة سريعة!", "Rapid round!"), Color("ffb347"), ROLL_T)
		"roll":
			# The drumroll: quick drum hits, louder and louder.
			F.roll_t -= dt
			F.roll_tick -= dt
			if F.roll_tick <= 0.0:
				F.roll_tick = 0.055
				var k := 1.0 - maxf(0.0, F.roll_t) / ROLL_T
				_sfx("thump", lerpf(0.25, 0.75, k), banner_at())
			if F.roll_t <= 0.0:
				F.rapid = "on"
				F.rapid_left = RAPID_T
				F.rapid_pts = 0
				F.rapids += 1
				F.beat_t = 0.0
				_banner(_tr("جولة سريعة!", "RAPID ROUND!"), _tr("النقاط مضاعفة ×٢", "Every hit counts ×2"), Color("ff5a4a"), 2.0)
				_sfx("boom", 0.6, banner_at())
				_sfx("chime", 1.0, banner_at())
				_buzz2(0.7, 140)
				launch_rocket()
				launch_rocket()
				F.spawn_t = 0.0
		"on":
			F.rapid_left -= dt
			F.beat_t -= dt
			if F.beat_t <= 0.0:
				F.beat_t = 0.5 if F.rapid_left > 3.0 else 0.25
				_sfx("thump", 0.3 if F.rapid_left > 3.0 else 0.5, banner_at())
			if F.rapid_left <= 0.0:
				F.rapid = ""
				F.next_rapid = RAPID_EVERY
				_banner(_tr("انتهت الجولة!", "PHEW!"), "+" + _num(F.rapid_pts), Color("7bff8a"), 2.0)
				_sfx("chime", 1.0, banner_at())
				_confetti(banner_at(), 1.5)
				launch_rocket(true)


## Points for hitting target T: base (× 3 for a golden one), the bullseye, distance.
func points_for(T: Dictionary, bull: bool) -> Dictionary:
	var base: int = int(PTS[T.mover]) * (GOLD_K if T.kind == "gold" else 1)
	var dd := viewer.distance_to(T.c) / size
	var far := int(maxf(0.0, dd - 10.0) / 4.0) * 5
	var mult: int = F.mult * (2 if F.rapid == "on" else 1)
	return {"base": base, "bull": BULLSEYE_PTS if bull else 0, "far": far, "total": (base + (BULLSEYE_PTS if bull else 0) + far) * mult}


## Whether a hit point (game units) is on the target's eyes.
static func bullseye(T: Dictionary, point: Vector3) -> bool:
	var lp: Vector3 = (T.dx as Transform3D).affine_inverse() * point
	if lp.z < 0.0:
		return false
	for e in EYES:
		if Vector2(lp.x, lp.y).distance_to(e) < EYE_R:
			return true
	return false


## The target can be hit now.
static func hittable(T: Dictionary) -> bool:
	if not T.on:
		return false
	match String(T.phase):
		"up":
			return T.mover != "rail" or float(T.e) > 0.45
		"in":
			return float(T.e) > 0.55
		"out":
			return float(T.e) > 0.45
	return false


## A hit (shot or throw) on target T at point, from direction dir.
func hit(T: Dictionary, point: Vector3, dir: Vector3, by_ball := false) -> bool:
	if not hittable(T):
		return false
	T.hit_dir = dir
	if T.kind == "friendly":
		_ouch(T)
		return true
	var bull := bullseye(T, point)
	F.streak += 1
	F.combo_t = COMBO_T
	var before: int = F.mult
	F.mult = multiplier(F.streak)
	F.best = maxi(F.best, F.streak)
	var P := points_for(T, bull)
	var pts: int = P.total
	F.score += pts
	F.hits += 1
	if F.rapid == "on":
		F.rapid_pts += pts
	if ctx:
		ctx.counts["gallery"] = int(ctx.counts.get("gallery", 0)) + pts
		ctx.ch_progress.call("gallery10", F.streak)
	var c: Vector3 = T.c
	var top := c + Vector3.UP * float(T.rr) * 1.2
	var mult_all: int = F.mult * (2 if F.rapid == "on" else 1)
	_pop_label(top, "+" + _num(pts), Color("ffe08a") if mult_all <= 1 else Color("ff8ad8"), 1.0 + 0.1 * (mult_all - 1))
	if bull:
		F.bullseyes += 1
		_pop_label(top + Vector3.UP * 0.75 * size, _tr("في العين!", "BULLSEYE!"), Color("ffd23f"), 1.1, "banner")
		_sfx("fair_ding", 1.0, c)
		_buzz2(0.6, 50)
		_glitter(c, 14, "ffd23f")
	elif T.mover == "toss":
		F.tricks += 1
		_pop_label(top + Vector3.UP * 0.75 * size, _tr("ضربة خرافية!", "TRICK SHOT!"), Color("7fd8ff"), 1.15, "banner")
		_sfx("chime", 0.8, c)
		_confetti(c, 0.8)
	elif int(P.far) >= 10:
		_pop_label(top + Vector3.UP * 0.75 * size, _tr("رمية بعيدة!", "LONG SHOT!"), Color("b0ffb0"), 0.9, "banner")
	if T.kind == "gold":
		_glitter(c, 20, "ffd23f")
		_confetti(c, 0.7)
	_buzz2(0.35, 30)
	# Down it goes: a card falls back with a clack, a Dahrooj pops.
	if T.flat:
		T.phase = "hit"
		T.t = 0.0
		_sfx("bowling_clack", 0.9, c)
		_sfx("squeak", 1.2, c)
		_chips(c, dir, 1.0)
	else:
		_sfx("start_pop", 1.0, c)
		_sfx("squeak", 1.15 if T.kind != "gold" else 0.85, c)
		_burst(c, T.color, 1.0 + (0.4 if T.kind == "gold" else 0.0))
		_off(T)
	if by_ball:
		_sfx("thump", 0.5, c)
	if F.mult > before:
		_streak_up(c)
	elif F.mult == STEPS.size() + 1 and F.streak % 10 == 0:
		launch_rocket()
		launch_rocket()
		_banner(_tr("سلسلة ", "STREAK ") + _num(F.streak) + "!", _tr("لا يوقفك شي!", "Unstoppable!"), Color("ffd23f"), 1.6)
	return true


func _streak_up(at: Vector3) -> void:
	var m: int = F.mult
	var w: Array = STREAK_WORDS[clampi(m - 2, 0, STREAK_WORDS.size() - 1)]
	_banner(_tr("سلسلة ×", "STREAK ×") + _num(m), _tr(w[0], w[1]), [Color("ffd166"), Color("ff9b3d"), Color("ff6ad5"), Color("7fd8ff"), Color("7bff8a")][clampi(m - 2, 0, 4)], 1.6)
	combo_label.text = "×" + _num(m)
	F.combo_show_t = 1.1
	F.combo_at = at
	_sfx("chime", 0.9, at)
	_buzz2(0.5, 70)
	if m >= 3:
		for _i in m - 2:
			launch_rocket(m >= 6)
		_confetti(banner_at(), 1.0 + 0.2 * m)


## A friendly (crowned) one was hit: "ouch!", dizzy stars, the streak resets; no points lost.
func _ouch(T: Dictionary) -> void:
	T.phase = "ouch"
	T.t = 0.0
	F.ouches += 1
	var had: int = F.streak
	F.streak = 0
	F.mult = 1
	F.combo_t = 0.0
	var c: Vector3 = T.c
	var top := c + Vector3.UP * float(T.rr) * 1.25
	_pop_label(top, _tr("آخ!", "OUCH!"), Color("ff7ab0"), 1.3, "ouch")
	if had >= 2:
		_pop_label(top + Vector3.UP * 0.7 * size, _tr("ضاعت السلسلة", "streak lost"), Color("ffd6e8"), 0.75, "miss")
	_sfx("squeak", 1.35, c)
	_sfx("thump", 0.3, c)
	if T.flat:
		_sfx("bowling_clack", 0.4, c)
	_buzz2(0.5, 90)
	_fx(c, Vector3.ZERO, 0.25, _lin("ffb3d1"), 1.0 * size, 0)


func _off(T: Dictionary) -> void:
	T.on = false
	T.show = false
	(T.proxy as MeshInstance3D).visible = false
	if int(T.src) >= 0 and int(T.src) < covers.size() and T.mover == "peek" and not room():
		covers[int(T.src)].busy = false


# ---- the room (mixed reality) ----

func _refresh_room() -> void:
	var list: Array = []
	if planes_provider.is_valid():
		var got = planes_provider.call()
		if got is Array:
			list = got
	_planes = []
	for pl in list:
		if pl is Dictionary and pl.has("pos") and pl.has("normal"):
			_planes.append(pl)
	var sig := str(_planes.size())
	for pl in _planes:
		var p: Vector3 = pl.pos
		sig += "|%d,%d,%d" % [roundi(p.x), roundi(p.y), roundi(p.z)]
	booth.visible = not room()
	if sig != _room_sig:
		_room_sig = sig
		_build_rows()


func room() -> bool:
	return not _planes.is_empty()


static func is_ceiling(pl: Dictionary) -> bool:
	return pl.get("label", "") == "ceiling" or (pl.normal as Vector3).y < -0.8


static func is_wall(pl: Dictionary) -> bool:
	return absf((pl.normal as Vector3).y) < 0.35 and pl.get("label", "") not in ["floor", "ceiling"]


func is_floor(pl: Dictionary) -> bool:
	return pl.get("label", "") == "floor" or ((pl.normal as Vector3).y > 0.8 and (pl.pos as Vector3).y < viewer.y - 7.0 * size)


## A furniture top: facing up, above the floor.
func is_top(pl: Dictionary) -> bool:
	return (pl.normal as Vector3).y > 0.8 and not is_floor(pl)


## Extent of a plane along a direction in it (its half size projected).
static func extent(pl: Dictionary, d: Vector3) -> float:
	var ax: Vector3 = pl.get("ax", Vector3.RIGHT)
	var ay: Vector3 = pl.get("ay", Vector3.UP)
	var h: Vector2 = pl.get("half", Vector2.ONE)
	return absf(ax.dot(d)) * h.x + absf(ay.dot(d)) * h.y


static func on_plane(pl: Dictionary, u: float, v: float) -> Vector3:
	var h: Vector2 = pl.get("half", Vector2.ONE)
	return (pl.pos as Vector3) + (pl.get("ax", Vector3.RIGHT) as Vector3) * u * h.x + (pl.get("ay", Vector3.UP) as Vector3) * v * h.y


func floor_y() -> float:
	var y := INF
	for pl in _planes:
		if is_floor(pl):
			y = minf(y, (pl.pos as Vector3).y)
	return y if y < INF else 0.0


## The planes of a sort that face the viewer and are not on top of them.
func _room(sort: String) -> Array:
	var out := []
	for pl in _planes:
		var p: Vector3 = pl.pos
		var n: Vector3 = pl.normal
		if n.dot(viewer - p) <= 0.0:
			continue
		var ok := false
		match sort:
			"wall":
				ok = is_wall(pl)
			"floor":
				ok = is_floor(pl)
			"top":
				ok = is_top(pl)
			"ceiling":
				ok = is_ceiling(pl)
		if ok:
			out.append(pl)
	return out


## A spot all around the player (RoomSpots) of a sort, with the plane it lies on (the room's,
## or a small stand-in for a ring spot): {pos, plane} or {}.
func _spot_point(sort: String) -> Dictionary:
	var sps := RoomSpots.ask(spots_provider, [sort])
	for sp: Dictionary in sps:
		if str(sp.get("kind", "")) != sort:
			continue
		var p: Vector3 = sp.pos
		if not _free_at(p, 2.2 * R * size):
			continue
		var pl := RoomSpots.plane_of(sp, _planes, 0.3 * size)
		if pl.is_empty():
			if room():
				continue
			var n: Vector3 = sp.get("normal", Vector3.UP)
			var b := MoleStage.basis_up(n)
			pl = {"pos": p, "normal": n, "ax": b.x, "ay": b.z, "half": Vector2.ONE * 1.5 * size, "label": "ring"}
		return {"pos": p, "plane": pl}
	return {}


## A random point on a plane of a sort, far enough from the viewer: {} when there is none.
func _room_point(sort: String, margin := 0.75) -> Dictionary:
	if sort != "ceiling":
		var at := _spot_point(sort)
		if not at.is_empty():
			return at
	var list := _room(sort)
	if list.is_empty():
		return {}
	for _k in 12:
		var pl: Dictionary = list[_rng.randi() % list.size()]
		var p := on_plane(pl, _rng.randf_range(-margin, margin), _rng.randf_range(-margin, margin))
		var hd := Vector2(p.x - viewer.x, p.z - viewer.z).length()
		if hd < 5.0 * size or hd > 60.0 * size:
			continue
		if not _free_at(p, 2.2 * R * size):
			continue
		return {"pos": p, "plane": pl}
	return {}


func _free_at(p: Vector3, d: float) -> bool:
	for T in targets:
		if T.on and int(T.row) < 0:
			var q: Vector3 = T.base if T.mover == "card" else T.c
			if q.distance_to(p) < d:
				return false
	return true


## The carousel rows: the court's three, or along the room's two widest walls.
func _build_rows() -> void:
	for T in targets:
		if T.on and int(T.row) >= 0:
			_off(T)
	rows = []
	if not room():
		for rd in ROWS_VR:
			var y: float = rd.y if rd.flat else float(rd.board)
			var face := Vector3.BACK
			rows.append({"a": Vector3(rd.x0, y, rd.z), "b": Vector3(rd.x1, y, rd.z), "up": Vector3.UP, "face": face,
				"flat": rd.flat, "flip": "hinge", "grow": false, "speed": rd.speed, "k": rd.k, "space": rd.space, "timer": 0.5})
		return
	var walls := _room("wall")
	walls.sort_custom(func(p, q): return extent(p, (p.normal as Vector3).cross(Vector3.UP).normalized()) > extent(q, (q.normal as Vector3).cross(Vector3.UP).normalized()))
	for wi in mini(2, walls.size()):
		var pl: Dictionary = walls[wi]
		var n: Vector3 = (pl.normal as Vector3)
		n.y = 0.0
		n = n.normalized()
		var hd := n.cross(Vector3.UP).normalized()
		var eh := extent(pl, hd)
		var ev := extent(pl, Vector3.UP)
		if eh < 3.0 * size or ev < 1.5 * size or n.dot(viewer - (pl.pos as Vector3)) < 6.0 * size:
			continue
		var p: Vector3 = pl.pos
		var lo := p.y - ev + 1.6 * R * size
		var hi := p.y + ev - 1.6 * R * size
		var y := clampf(viewer.y - (0.6 + 1.6 * wi) * size, lo, maxf(lo, hi))
		var flat := wi == 1
		var off := n * ((CARD_R * 0.8 if flat else R + 0.06) * size)
		var a := p + hd * eh * 0.92 + Vector3.UP * (y - p.y) + off
		var b := p - hd * eh * 0.92 + Vector3.UP * (y - p.y) + off
		if wi == 1:
			var t := a
			a = b
			b = t
		rows.append({"a": a, "b": b, "up": Vector3.UP, "face": n, "flat": flat, "flip": "spin", "grow": true,
			"speed": 2.4 * size, "k": 1.0, "space": 2.6 * size, "timer": 0.5})


# ---- spawning ----

func _free_slot() -> int:
	for i in targets.size():
		if not targets[i].on:
			return i
	return -1


## A basis standing up with +Z (its face) along face (horizontal).
static func standing(face: Vector3) -> Basis:
	var z := Vector3(face.x, 0, face.z)
	z = z.normalized() if z.length_squared() > 1e-6 else Vector3.BACK
	return Basis(Vector3.UP.cross(z), Vector3.UP, z)


func _pick_kind(mover: String) -> String:
	var r := _rng.randf()
	if r < GOLD_P:
		return "gold"
	if r < GOLD_P + FRIENDLY_P * (0.6 if mover == "toss" else 1.0):
		return "friendly"
	return "plain"


func _dress(T: Dictionary) -> void:
	match String(T.kind):
		"gold":
			T.style = "clay"
			T.color = "f2c14e"
			T.acc = "party"
		"friendly":
			T.style = ["fur", "clay", "jelly", "fabric"][_rng.randi() % 4] if not T.flat else ["clay", "jelly", "fabric"][_rng.randi() % 3]
			T.color = FRIEND_COLORS[_rng.randi() % FRIEND_COLORS.size()]
			T.acc = "crown"
		_:
			T.style = STYLES[_rng.randi() % STYLES.size()] if not T.flat else ["clay", "jelly", "fabric", "clay"][_rng.randi() % 4]
			T.color = COLORS[_rng.randi() % COLORS.size()] if _rng.randf() < 0.75 else Crowd.DAHROOJ_COLORS[T.style]
			T.acc = ACCS[_rng.randi() % ACCS.size()]


## Starts a target: mover "card" | "rail" | "peek" | "swing" | "toss", kind "" (random),
## "plain", "gold" or "friendly"; at overrides where (tests): card {pos, face?, wall?},
## rail {row}, peek {hide, out, grow?} or {cover, edge}, swing {anchor, rope?}, toss {from, v}.
## Returns the slot, or -1.
func spawn(mover: String, kind := "", at := {}) -> int:
	var i := _free_slot()
	if i < 0:
		return -1
	var T: Dictionary = targets[i]
	var proxy: MeshInstance3D = T.proxy
	T.merge(_blank(proxy), true)
	T.mover = mover
	T.kind = kind if kind != "" else _pick_kind(mover)
	T.look_t = _rng.randf_range(0.2, 0.6)
	T.blink_t = _rng.randf_range(0.6, 1.8)
	T.spin = _rng.randf() * TAU
	var lv := level()
	T.life = lerpf(2.4, 1.3, clampf(lv / 6.0, 0.0, 1.0)) * _rng.randf_range(0.85, 1.2)
	var ok := false
	match mover:
		"card":
			ok = _setup_card(T, at)
		"rail":
			ok = _setup_rail(T, at)
		"peek":
			ok = _setup_peek(T, at)
		"swing":
			ok = _setup_swing(T, at)
		"toss":
			ok = _setup_toss(T, at)
	if not ok:
		return -1
	# All around the room: a little longer to turn and find it.
	if room() and mover != "rail":
		T.life *= 1.4
	_dress(T)
	T.on = true
	if T.phase == "":
		T.phase = "in"
	_step_target(T, 0.0)
	return i


func _setup_card(T: Dictionary, at: Dictionary) -> bool:
	T.flat = true
	T.r = CARD_R * size
	var pos: Vector3
	var wall := false
	var face := Vector3.ZERO
	var placed := at.has("pos") or room()
	if at.has("pos"):
		pos = at.pos
		wall = at.get("wall", false)
		face = at.get("face", Vector3.ZERO)
	elif room():
		var pick := {}
		var sorts := ["floor", "floor", "top", "wall"]
		for _k in 6:
			pick = _room_point(sorts[_rng.randi() % sorts.size()])
			if not pick.is_empty():
				break
		if pick.is_empty():
			return false
		pos = pick.pos
		wall = is_wall(pick.plane)
		if wall:
			face = pick.plane.normal
			pos += (face as Vector3) * 0.1 * size
	else:
		# Mixed reality without a scan: mostly on the floor all around the player.
		var ring := _spot_point("floor")
		if not ring.is_empty() and _rng.randf() < 0.7:
			pos = ring.pos
			placed = true
	if not placed:
		var free := []
		for s in CARD_SPOTS_VR:
			if _free_at(s, 1.6):
				free.append(s)
		if free.is_empty():
			return false
		pos = free[_rng.randi() % free.size()]
		pos += Vector3(_rng.randf_range(-0.4, 0.4), 0, _rng.randf_range(-0.3, 0.3))
	if face == Vector3.ZERO:
		face = viewer - pos
	T.base = pos
	T.bx = standing(face)
	if wall:
		# On a wall: a turning target, edge-on until it spins round to face the room.
		T.flip = "spin"
		T.hid = PI / 2.0
	else:
		T.flip = "hinge"
		T.hid = -PI / 2.0
	_sfx("bowling_clack", 0.6, pos)
	return true


func _setup_rail(T: Dictionary, at: Dictionary) -> bool:
	var ri: int = at.get("row", 0)
	if ri < 0 or ri >= rows.size():
		return false
	var row: Dictionary = rows[ri]
	T.row = ri
	T.a = row.a
	T.b = row.b
	T.len = maxf(0.1, (row.a as Vector3).distance_to(row.b))
	T.s = 0.0
	T.speed = row.speed
	T.up = row.up
	T.flat = row.flat
	T.flip = row.flip
	T.grow = row.grow
	T.bx = standing(row.face)
	T.hid = -PI / 2.0 if T.flip == "hinge" else PI / 2.0
	T.r = (CARD_R if T.flat else R) * float(row.k) * size
	T.phase = "up"
	if T.flat:
		_sfx("bowling_clack", 0.45, row.a)
	return true


## Peeking out from behind cover: the court's crates, bush, barrels and tree, or the far edges
## of the room's furniture and the side edges of its walls.
func _setup_peek(T: Dictionary, at: Dictionary) -> bool:
	var r := R * size
	T.r = r
	if at.has("hide"):
		T.hide = at.hide
		T.out_p = at.out
		T.grow = at.get("grow", room())
	elif room():
		var tops := _room("top")
		var walls := _room("wall")
		if tops.is_empty() and walls.is_empty():
			return false
		var use_top := not tops.is_empty() and (walls.is_empty() or _rng.randf() < 0.6)
		# All around the room: the piece of furniture or wall of a side not looked at lately.
		var pref := _spot_point("top" if use_top else "wall")
		if use_top:
			var pl: Dictionary = tops[_rng.randi() % tops.size()]
			if not pref.is_empty() and (pref.plane as Dictionary) in tops:
				pl = pref.plane
			var p: Vector3 = pl.pos
			var d := Vector3(p.x - viewer.x, 0, p.z - viewer.z)
			if d.length() < 3.0 * size:
				return false
			d = d.normalized()
			var side := Vector3(-d.z, 0, d.x)
			var e := p + d * extent(pl, d) * 0.85 + side * extent(pl, side) * _rng.randf_range(-0.6, 0.6)
			T.hide = e + Vector3.UP * r * 0.2
			T.out_p = e + Vector3.UP * r * 0.95
		else:
			var pl: Dictionary = walls[_rng.randi() % walls.size()]
			if not pref.is_empty() and (pref.plane as Dictionary) in walls:
				pl = pref.plane
			var n: Vector3 = pl.normal
			n.y = 0.0
			n = n.normalized()
			var hd := n.cross(Vector3.UP).normalized()
			var sgn := -1.0 if _rng.randf() < 0.5 else 1.0
			var p: Vector3 = pl.pos
			var ev := extent(pl, Vector3.UP)
			var y := clampf(viewer.y - _rng.randf_range(0.0, 2.0) * size, p.y - ev + r * 1.5, maxf(p.y - ev + r * 1.5, p.y + ev - r * 1.5))
			var e := p + hd * sgn * extent(pl, hd) + Vector3.UP * (y - p.y) + n * (r + 0.05 * size)
			if Vector2(e.x - viewer.x, e.z - viewer.z).length() < 3.5 * size:
				return false
			T.hide = e + hd * sgn * r * 0.5
			T.out_p = e - hd * sgn * r * 1.1
		T.grow = true
	else:
		var free := []
		for ci in covers.size():
			if not covers[ci].busy:
				free.append(ci)
		if free.is_empty():
			return false
		var ci: int = at.get("cover", free[_rng.randi() % free.size()])
		var cv: Dictionary = covers[ci]
		var edges := cover_edges(cv)
		var ed: Dictionary = edges[clampi(int(at.get("edge", _rng.randi() % edges.size())), 0, edges.size() - 1)]
		T.hide = ed.hide
		T.out_p = ed.out
		T.src = ci
		cv.busy = true
		T.grow = false
	T.life *= 1.1
	_sfx("swish", 0.35, T.out_p)
	return true


## Where a Dahrooj hides behind a piece of the court's cover and where it peeks out:
## [{hide, out}] (left and right; over the top too unless it's the tree).
func cover_edges(cv: Dictionary) -> Array:
	var C: Vector3 = cv.pos
	var h: Vector3 = cv.half
	var r := R * size
	var d := Vector3(C.x - VIEW_VR.x, 0, C.z - VIEW_VR.z).normalized()
	var side := Vector3(-d.z, 0, d.x)
	var top := h.y * 2.0
	var y := clampf(top * 0.5, r + 0.15, top - r - 0.1)
	if cv.kind == "tree":
		y = 1.5
	var behind := C + d * (h.z + r + 0.2)
	var out := [
		{"hide": behind + Vector3.UP * y, "out": C - side * (h.x + r * 0.45) + d * 0.1 + Vector3.UP * y},
		{"hide": behind + Vector3.UP * y, "out": C + side * (h.x + r * 0.45) + d * 0.1 + Vector3.UP * y},
	]
	if cv.kind != "tree":
		var back := C + d * minf(h.z * 0.4, 0.3)
		out.append({"hide": back + Vector3.UP * (top - r - 0.2), "out": back + Vector3.UP * (top + r * 0.8)})
	return out


func _setup_swing(T: Dictionary, at: Dictionary) -> bool:
	var r := R * size
	T.r = r
	var anchor: Vector3
	var rope := 0.0
	if at.has("anchor"):
		anchor = at.anchor
		rope = at.get("rope", 4.5 * size)
	elif room():
		var pick := _ceiling_over(_spot_point("floor"))
		if pick.is_empty():
			pick = _room_point("ceiling", 0.7)
		if pick.is_empty():
			# No ceiling: hang from the top of a wall.
			var walls := _room("wall")
			if walls.is_empty():
				return false
			var pl: Dictionary = walls[_rng.randi() % walls.size()]
			var n: Vector3 = pl.normal
			n.y = 0.0
			n = n.normalized()
			var hd := n.cross(Vector3.UP).normalized()
			anchor = (pl.pos as Vector3) + Vector3.UP * extent(pl, Vector3.UP) + hd * extent(pl, hd) * _rng.randf_range(-0.7, 0.7) + n * 1.8 * size
		else:
			anchor = pick.pos
		var want := viewer.y - _rng.randf_range(-0.5, 2.0) * size
		rope = anchor.y - want - r
		if rope < 1.5 * size:
			return false
	else:
		var free := []
		for x in ANCHORS_VR:
			var p := Vector3(x, GANTRY_Y - 0.2, GANTRY_Z)
			if _free_at_swing(p):
				free.append(p)
		if free.is_empty():
			return false
		anchor = free[_rng.randi() % free.size()]
		rope = _rng.randf_range(4.0, 6.0)
	if not at.has("anchor") and not _free_at_swing(anchor):
		return false
	T.anchor = anchor
	T.rope = rope
	var d := Vector3(anchor.x - viewer.x, 0, anchor.z - viewer.z)
	d = d.normalized() if d.length_squared() > 1e-6 else Vector3.FORWARD
	T.side = Vector3(-d.z, 0, d.x)
	T.amp = _rng.randf_range(0.35, 0.6)
	T.w = _rng.randf_range(1.7, 2.4) / sqrt(maxf(0.5, rope / (4.5 * size)))
	T.ph = _rng.randf() * TAU
	T.life *= 1.7
	_sfx("whoosh", 0.3, anchor)
	return true


## The ceiling right over a spot ({pos, plane} or {}), for a swinger on that side.
func _ceiling_over(at: Dictionary) -> Dictionary:
	if at.is_empty():
		return {}
	var p: Vector3 = at.pos
	for pl in _room("ceiling"):
		var n: Vector3 = pl.normal
		if absf(n.y) < 0.5:
			continue
		var c: Vector3 = pl.pos
		var q := Vector3(p.x, c.y - ((p.x - c.x) * n.x + (p.z - c.z) * n.z) / n.y, p.z)
		var d := q - c
		var h: Vector2 = pl.get("half", Vector2.ONE)
		if absf(d.dot(pl.get("ax", Vector3.RIGHT))) <= h.x * 0.9 and absf(d.dot(pl.get("ay", Vector3.UP))) <= h.y * 0.9:
			return {"pos": q, "plane": pl}
	return {}


func _free_at_swing(p: Vector3) -> bool:
	for T in targets:
		if T.on and T.mover == "swing" and (T.anchor as Vector3).distance_to(p) < 1.0 * size:
			return false
	return true


func _setup_toss(T: Dictionary, at: Dictionary) -> bool:
	var r := R * size
	T.r = r
	T.g = Ball.GRAV * size
	var from: Vector3
	var v: Vector3
	if at.has("from"):
		from = at.from
		v = at.v
	else:
		var land := 0.0
		if room():
			var pick := _room_point("top" if _rng.randf() < 0.4 else "floor", 0.6)
			if pick.is_empty():
				pick = _room_point("floor", 0.6)
			if pick.is_empty():
				return false
			from = (pick.pos as Vector3) + Vector3.UP * r
			land = from.y
		else:
			# Mixed reality without a scan: up from the floor all around the player.
			var ring := _spot_point("floor")
			if not ring.is_empty():
				from = (ring.pos as Vector3) + Vector3.UP * r
			else:
				var cv: Dictionary = covers[_rng.randi() % covers.size()]
				var C: Vector3 = cv.pos
				var d := Vector3(C.x - VIEW_VR.x, 0, C.z - VIEW_VR.z).normalized()
				from = C + d * (float(cv.half.z) + r + 0.3) + Vector3.UP * 0.6
			land = from.y
		var hgt := _rng.randf_range(3.2, 4.6) * size
		var vy := sqrt(2.0 * float(T.g) * hgt)
		var to_v := Vector3(viewer.x - from.x, 0, viewer.z - from.z).normalized()
		var side := Vector3(-to_v.z, 0, to_v.x)
		v = Vector3.UP * vy + side * _rng.randf_range(-2.2, 2.2) * size + to_v * _rng.randf_range(0.3, 1.2) * size
		T.land_y = land
	T.p = from
	T.v = v
	if at.has("from"):
		T.land_y = from.y
	T.phase = "up"
	T.e = 1.0
	_sfx("whoosh", 0.7, from)
	_fx(from, Vector3.UP * 3.0 * size, 0.3, _lin("fff3e0"), 0.5 * size, 0)
	return true


# ---- each target ----

static func _back(k: float) -> float:
	var c := 2.2
	return 1.0 + (c + 1.0) * pow(k - 1.0, 3.0) + c * pow(k - 1.0, 2.0)


func _step_target(T: Dictionary, dt0: float) -> void:
	var dt := dt0 * float(F.spd)
	T.t += dt
	T.ball_t = maxf(0.0, float(T.ball_t) - dt0)
	var t: float = T.t
	match String(T.phase):
		"in":
			var it := SWING_IN if T.mover == "swing" else IN_T
			T.e = clampf(t / it, 0.0, 1.0)
			if t >= it:
				T.phase = "up"
				T.t = 0.0
		"up":
			if T.mover == "rail":
				pass
			elif T.mover == "toss":
				pass
			else:
				T.e = 1.0
				if t >= T.life:
					T.phase = "out"
					T.t = 0.0
					if T.flat:
						_sfx("bowling_clack", 0.35, T.base)
		"out":
			var ot := SWING_IN if T.mover == "swing" else OUT_T
			T.e = 1.0 - clampf(t / ot, 0.0, 1.0)
			if t >= ot:
				_off(T)
				return
		"hit":
			if t >= HIT_T:
				_off(T)
				return
		"ouch":
			if t >= OUCH_T:
				T.t = 0.0
				T.phase = "up" if T.mover in ["rail", "toss"] else "out"
	# Movers.
	match String(T.mover):
		"rail":
			T.s += float(T.speed) * dt
			var s: float = T.s
			var fd := FLIP_D * size
			T.e = clampf(minf(s, float(T.len) - s) / fd, 0.0, 1.0)
			if s >= float(T.len):
				if T.flat:
					_sfx("bowling_clack", 0.25, T.b)
				_off(T)
				return
		"swing":
			T.st += dt
		"toss":
			T.v.y -= float(T.g) * dt
			T.p += (T.v as Vector3) * dt
			if (T.v as Vector3).y < 0.0 and (T.p as Vector3).y < float(T.land_y):
				_fx(T.p, Vector3.UP * size, 0.25, _lin("fff3e0"), 0.5 * size, 0)
				_off(T)
				return
	# Looking round and blinking.
	T.look_t -= dt0
	if T.look_t <= 0.0:
		T.look_t = _rng.randf_range(0.3, 0.8)
		T.look_to = [-0.6, -0.3, 0.0, 0.0, 0.3, 0.6][_rng.randi() % 6]
	T.look = move_toward(T.look, T.look_to, dt0 * 6.0)
	T.blink_t -= dt0
	if T.blink_t <= 0.0:
		T.blink = 0.12
		T.blink_t = _rng.randf_range(1.0, 2.6)
	T.blink = maxf(0.0, float(T.blink) - dt0)
	_pose(T)


## Where target T is this frame: centre c, radius rr, the drawn transform xf (card or body),
## the Dahrooj's own transform dx (bullseye) and whether it shows.
func _pose(T: Dictionary) -> void:
	var r: float = T.r
	var e: float = T.e
	var t: float = T.t
	var ph: String = T.phase
	var c := Vector3.ZERO
	var pivot := Vector3.ZERO
	var tilt := 0.0
	var sq := Vector2.ONE
	match String(T.mover):
		"card":
			pivot = T.base
		"rail":
			pivot = (T.a as Vector3).lerp(T.b, clampf(float(T.s) / float(T.len), 0.0, 1.0))
		"peek":
			var k := e * e * (3.0 - 2.0 * e)
			c = (T.hide as Vector3).lerp(T.out_p, k)
		"swing":
			var th := float(T.amp) * sin(float(T.w) * float(T.st) + float(T.ph))
			var l := float(T.rope) * maxf(0.02, 1.0 - pow(1.0 - e, 3.0))
			var d := (T.side as Vector3) * sin(th) + Vector3.DOWN * cos(th)
			T.rope_end = (T.anchor as Vector3) + d * l
			c = (T.anchor as Vector3) + d * (l + r * 0.95)
			tilt = th
		"toss":
			c = T.p
	if T.flat:
		var hid: float = T.hid
		var ang := 0.0
		match ph:
			"in":
				ang = hid * (1.0 - _back(e))
			"up":
				ang = hid * (1.0 - e) if T.mover == "rail" else hid * -0.08 * exp(-t * 7.0) * sin(t * 30.0)
			"out":
				ang = hid * (1.0 - e * e)
			"hit":
				var k := clampf(t / 0.2, 0.0, 1.0)
				if T.flip == "spin":
					ang = hid * (1.0 - k) + t * 30.0
				else:
					ang = hid * k * k - (0.0 if k < 1.0 else hid * 0.1 * exp(-(t - 0.2) * 12.0) * sin((t - 0.2) * 40.0))
			"ouch":
				ang = hid * 0.3 * exp(-t * 3.5) * sin(t * 26.0)
		var B: Basis = T.bx
		if T.flip == "spin" and T.mover == "rail":
			# Along a wall: half turned toward the player.
			var tv := viewer - pivot
			tv.y = 0.0
			B = standing(B.z + tv.normalized() * 0.8)
		var rot: Basis
		var cc: Vector3
		if T.flip == "spin":
			rot = Basis(B.y, ang) * B
			cc = pivot
		else:
			rot = Basis(B.x, ang) * B
			cc = pivot + rot.y * CARD_H * r
		T.xf = Transform3D(rot * Basis.from_scale(Vector3.ONE * r), cc)
		T.dx = T.xf * Transform3D(Basis.from_scale(Vector3(0.72, 0.72, 0.26)), Vector3(0, -0.02, 0.1))
		T.c = cc
		T.rr = r
		T.show = ph == "hit" or e > 0.02 or ph == "ouch"
		var proxy: MeshInstance3D = T.proxy
		proxy.visible = hittable(T) and T.show
		proxy.transform = T.xf * Transform3D(Basis.from_scale(Vector3(1.04, 1.04, 0.32)), Vector3.ZERO)
		return
	var rr := r
	match String(T.mover):
		"rail":
			var up: Vector3 = T.up
			if T.grow:
				c = pivot
				rr = r * maxf(0.05, e)
			else:
				c = pivot + up * (r * 0.88 - (1.0 - e) * 2.3 * r)
				rr = r * (0.45 + 0.55 * e)
		"peek":
			if T.grow:
				rr = r * maxf(0.08, 0.15 + 0.85 * e)
	match ph:
		"in":
			sq = Vector2(1.0 - 0.12 * sin(PI * e), 1.0 + 0.25 * sin(PI * e))
		"up":
			var wob := exp(-t * 7.0) * sin(t * 26.0)
			sq = Vector2(1.0 + 0.1 * wob, 1.0 - 0.15 * wob)
		"ouch":
			var sp := exp(-t * 4.0) * cos(t * 22.0)
			sq = Vector2(1.0 + 0.3 * sp, 1.0 - 0.38 * sp)
	if T.mover == "toss":
		var vy: float = (T.v as Vector3).y
		var st := clampf(absf(vy) / (8.0 * size), 0.0, 1.0) * 0.18
		sq = Vector2(1.0 - st * 0.5, 1.0 + st)
	var to := viewer - c
	to.y *= 0.6
	if to.length_squared() < 1e-6:
		to = Vector3.BACK
	var look: float = T.look
	if ph == "ouch":
		look += 0.6 * sin(t * 24.0) * exp(-t * 2.5)
	var dir := to.normalized().rotated(Vector3.UP, look)
	var rot2 := Basis.looking_at(dir, Vector3.UP, true)
	var roll := tilt
	if T.mover == "toss":
		roll = sin(float(T.t) * 9.0 + float(T.spin)) * 0.6
	if T.mover == "peek" and ph == "up":
		roll = 0.18 * sin(t * 5.0 + float(T.spin))
	var fwd := to.normalized()
	T.xf = Transform3D(Basis(fwd, roll) * Basis.from_scale(Vector3(rr * sq.x, rr * sq.y, rr * sq.x)) * rot2, c)
	T.dx = T.xf
	T.c = c
	T.rr = rr * maxf(sq.x, sq.y)
	T.sq = sq
	T.show = rr > r * 0.06 and (T.mover != "rail" or e > 0.01)
	var proxy2: MeshInstance3D = T.proxy
	proxy2.visible = hittable(T) and T.show
	proxy2.transform = Transform3D(Basis.from_scale(Vector3.ONE * float(T.rr) * 1.08), c)


func _eyes(T: Dictionary) -> String:
	if T.phase == "ouch":
		return "shut" if T.t < 0.6 else "wide"
	if T.phase in ["in", "hit"] or T.mover == "toss":
		return "wide"
	if T.kind == "gold":
		return "wide"
	if T.blink > 0.0:
		return "shut"
	return "open"


# ---- drawing ----

func _crowd_add(style: String, xf: Transform3D, eyes: String, accessory: String, color: Color) -> void:
	crowd._put("body_" + style, xf, color.srgb_to_linear())
	if style == "jelly":
		crowd._put("bandage", xf)
	if crowd.parts.has("acc_" + accessory):
		crowd._put("acc_" + accessory, xf * Transform3D(Basis.from_scale(Vector3.ONE * 1.08), Vector3.ZERO) if style == "fur" else xf)
	if style == "fur" and accessory not in Crowd.HEADWEAR:
		crowd._put("bow", xf)
	crowd._put("eyes_" + eyes, xf)
	if crowd.with_faces:
		crowd._put("face_" + ("wide" if eyes == "wide" else "open"), xf)


func _face(p: Vector3) -> Basis:
	var to := viewer - p
	to.y = 0.0
	if to.length_squared() < 1e-6:
		return Basis.IDENTITY
	return Basis.looking_at(to.normalized(), Vector3.UP, true)


func _put_star(i: int, p: Vector3, s: float, spin: float, c: Color) -> int:
	if i >= STARS_MAX:
		return i
	var mm: MultiMesh = _mm.stars
	mm.set_instance_transform(i, Transform3D(_face(p) * Basis(Vector3.BACK, spin) * Basis.from_scale(Vector3.ONE * s), p))
	mm.set_instance_color(i, c.srgb_to_linear())
	return i + 1


func draw() -> void:
	_fx_mat.set_shader_parameter("now", time)
	crowd.begin()
	var cards: MultiMesh = _mm.cards
	var discs: MultiMesh = _mm.discs
	var nd := 0
	var ring: MultiMesh = _mm.ring
	var ropes: MultiMesh = _mm.ropes
	var shadows: MultiMesh = _mm.shadows
	var nc := 0
	var nrope := 0
	var nsh := 0
	var ns := 0
	var vr := not room()
	for T in targets:
		if not T.on or not T.show:
			continue
		var col := Color(T.color)
		_crowd_add(T.style, T.dx, _eyes(T), T.acc, col)
		var c: Vector3 = T.c
		var rr: float = T.rr
		if T.flat:
			if T.flip == "spin":
				discs.set_instance_transform(nd, T.xf)
				discs.set_instance_color(nd, Color.WHITE)
				nd += 1
			else:
				cards.set_instance_transform(nc - nd, T.xf)
				cards.set_instance_color(nc - nd, Color.WHITE)
			ring.set_instance_transform(nc, T.xf)
			ring.set_instance_color(nc, Color(RING[T.kind]).srgb_to_linear())
			nc += 1
		if T.mover == "swing":
			var a: Vector3 = T.anchor
			var b: Vector3 = T.rope_end
			var d := b - a
			var l := d.length()
			if l > 0.01:
				var y := -d / l
				var x := y.cross(Vector3.BACK if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
				var z := x.cross(y)
				ropes.set_instance_transform(nrope, Transform3D(Basis(x * 0.07 * size, y * l, z * 0.07 * size), a))
				ropes.set_instance_color(nrope, Color.WHITE)
				nrope += 1
		if vr and T.mover in ["swing", "toss", "peek"] and nsh < SLOTS:
			var h := maxf(0.0, c.y - rr)
			var k := clampf(1.0 - h / 8.0, 0.15, 1.0)
			shadows.set_instance_transform(nsh, Transform3D(Basis.from_scale(Vector3.ONE * rr * (0.6 + 0.4 * k)), Vector3(c.x, 0.03, c.z)))
			shadows.set_instance_color(nsh, Color(0.05, 0.02, 0.08, 0.35 * k))
			nsh += 1
		# Dizzy stars over an "ouch"; sparkles round a golden one.
		var top := c + Vector3.UP * rr * 1.15
		if T.phase == "ouch":
			for s in 3:
				var a2: float = time * 7.0 + TAU * s / 3.0
				ns = _put_star(ns, top + Vector3(cos(a2), 0.0, sin(a2)) * rr * 0.8, 0.18 * size, time * 5.0 + s, Color("ffd23f"))
		elif T.kind == "gold":
			for s in 3:
				var a3: float = time * 2.0 + TAU * s / 3.0
				var tw := 0.5 + 0.5 * sin(time * 9.0 + s * 2.1)
				ns = _put_star(ns, c + Vector3(cos(a3), 0.4 + 0.5 * sin(a3 * 1.7), sin(a3)) * rr * 1.3, 0.07 * size * tw + 0.015, time * 2.0, Color("fff3b0"))
		elif T.kind == "friendly" and T.phase == "up":
			# A little heart-ish twinkle over the friendly ones.
			var tw2 := 0.5 + 0.5 * sin(time * 4.0 + float(T.spin))
			ns = _put_star(ns, top + Vector3.UP * (0.25 + 0.1 * tw2) * size, 0.07 * size * (0.6 + 0.4 * tw2), 0.0, Color("ffb3d1"))
	crowd.end()
	cards.visible_instance_count = nc - nd
	discs.visible_instance_count = nd
	ring.visible_instance_count = nc
	ropes.visible_instance_count = nrope
	shadows.visible_instance_count = nsh
	(_mm.stars as MultiMesh).visible_instance_count = ns
	var rings: MultiMesh = _mm.rings
	for i in _rings.size():
		var g: Dictionary = _rings[i]
		var k: float = clampf(float(g.t) / float(g.life), 0.0, 1.0)
		var ee := 1.0 - pow(1.0 - k, 3.0)
		var rad: float = lerpf(g.r0, g.r1, ee)
		var n: Vector3 = g.n
		var b := Basis.looking_at(n, Vector3.UP if absf(n.y) < 0.99 else Vector3.BACK, true) if n.length_squared() > 1e-6 else Basis.IDENTITY
		rings.set_instance_transform(i, Transform3D(b * Basis.from_scale(Vector3.ONE * rad), g.p))
		rings.set_instance_color(i, Color((g.c as Color).srgb_to_linear(), 1.0 - k))
	rings.visible_instance_count = _rings.size()
	if booth.visible:
		_draw_bulbs()
	_draw_labels()


## The booth's bulbs chase round; in a rapid round they race and flash red and gold.
func _draw_bulbs() -> void:
	var mm: MultiMesh = _mm.bulbs
	var rapid: bool = F.rapid != ""
	var step := int(time * (14.0 if rapid else 5.0))
	for i in _bulbs.size():
		var b: Array = _bulbs[i]
		var on := (int(b[1]) + step) % 3 == 0
		var hex: String = (["ff3d3d", "ffd23f"][(i + step) % 2]) if rapid else BULB_COLORS[(i >> 1) % BULB_COLORS.size()]
		var c := Color(hex)
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * (1.25 if on else 0.9)), b[0]))
		mm.set_instance_color(i, (c if on else c.darkened(0.65)).srgb_to_linear())
	mm.visible_instance_count = _bulbs.size()


func _draw_labels() -> void:
	if ctx and ctx.lang != _lang:
		_lang = ctx.lang
	sign_label.text = _tr("ميدان الرماية", "DAHROOJ GALLERY")
	sign_label.font_size = 150 if _en() else 190
	var bt: float = F.banner_t
	banner.visible = bt > 0.0 and banner.text != ""
	banner_sub.visible = banner.visible and banner_sub.text != ""
	if banner.visible:
		var life: float = F.banner_life
		var age := maxf(0.0, life - bt)
		var inn := minf(1.0, age / 0.35)
		var over := 1.0 + 0.35 * sin(inn * PI) * (1.0 - inn * 0.5)
		var out := clampf((0.45 - bt) / 0.45, 0.0, 1.0)
		var s := (0.3 + 0.7 * inn) * over * (1.0 + out * 0.4)
		var at := banner_at()
		banner.position = at + Vector3.UP * out * 0.35 * size
		banner.scale = Vector3.ONE * s * size
		banner.modulate.a = 1.0 - out
		banner_sub.position = at + Vector3(0, -1.05, 0) * size + Vector3.UP * out * 0.35 * size
		banner_sub.scale = Vector3.ONE * minf(1.0, age / 0.5) * size
		banner_sub.modulate.a = 1.0 - out
	var ct: float = F.combo_show_t
	combo_label.visible = ct > 0.0
	if combo_label.visible:
		var a := 1.1 - ct
		combo_label.position = (F.combo_at as Vector3) + Vector3.UP * (1.4 + a * 0.6) * size
		combo_label.scale = Vector3.ONE * size * (0.6 + 0.6 * minf(1.0, a * 6.0)) * (1.0 + 0.08 * sin(a * 30.0) * (1.0 - a))
		combo_label.modulate.a = clampf(ct / 0.3, 0.0, 1.0)


# ---- stage interface ----

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
		S.vel += dq * (-1.5 * vn)
	S.side = Vector3.ZERO
	return true


## The thrown Dahrooj bounces off the court's cover (boxes round each piece).
func _ball_cover(S: Ball) -> void:
	for cv in covers:
		var C: Vector3 = cv.pos
		var h: Vector3 = cv.half
		var lo := C + Vector3(-h.x, 0, -h.z)
		var hi := C + Vector3(h.x, h.y * 2.0, h.z)
		var q := S.pos.clamp(lo, hi)
		var d := S.pos - q
		var l := d.length()
		if l >= Ball.BR or l <= 1e-6:
			continue
		var n := d / l
		S.pos = q + n * Ball.BR
		var vn := S.vel.dot(n)
		if vn < 0.0:
			S.hit(n, -vn, q)
			S.vel -= n * vn * 1.5
			_sfx("thump", minf(1.0, -vn / 10.0), q)
		F.touched = true


func collide(S: Ball) -> void:
	if not S.shot:
		return
	if booth.visible:
		_ball_cover(S)
	for T in targets:
		if not hittable(T) or not T.show or float(T.ball_t) > 0.0:
			continue
		var c: Vector3 = T.c
		var rr: float = T.rr
		var dir := S.vel.normalized() if S.vel.length_squared() > 0.0 else Vector3.FORWARD
		if _ball_vs(S, c, rr):
			F.touched = true
			T.ball_t = 0.3
			hit(T, c + (S.pos - c).normalized() * rr, dir, true)


func shoot(obj: Node, point: Vector3, dir: Vector3) -> bool:
	if F.state == "idle":
		start()
	var d := dir if dir != Vector3.ZERO else Vector3.FORWARD
	for T in targets:
		if obj == T.proxy and T.on:
			return hit(T, point, d)
	# Cover stops a shot: a wooden tock.
	for cv in covers:
		if obj == cv.node:
			_sfx("bricks_tink", 0.3, point)
	return false


func touched() -> bool:
	return F.touched


func on_throw() -> void:
	if F.state == "idle":
		start()


func on_respawn() -> void:
	F.touched = false


func deactivate() -> void:
	for T in targets:
		_off(T)
	for cv in covers:
		cv.busy = false
	JuiceText.clear(self)
	_rings.clear()
	_rockets.clear()
	var keep := {"banner_life": BANNER_T, "next_rapid": RAPID_FIRST, "spawn_t": 0.8, "spd": 1.0}
	for k in F:
		if F[k] is int:
			F[k] = 0
		elif F[k] is float:
			F[k] = 0.0
		elif F[k] is bool:
			F[k] = false
	for k in keep:
		F[k] = keep[k]
	F.state = "idle"
	F.rapid = ""
	F.mult = 1
	F.combo_at = Vector3.ZERO
	draw()


func update(_b: Ball, dt: float) -> void:
	# Nothing moves while hidden (the rain, a tabletop, the Summit) or held by main.
	if not visible or paused:
		return
	time += dt
	_room_t -= dt
	if _room_t <= 0.0 or rows.is_empty():
		_room_t = 1.0
		_refresh_room()
	if F.state == "idle":
		start()
	F.t += dt
	F.spd = move_toward(F.spd, pace(), dt * 1.5)
	if F.combo_t > 0.0:
		F.combo_t -= dt
		if F.combo_t <= 0.0:
			F.streak = 0
			F.mult = 1
	F.banner_t = maxf(0.0, F.banner_t - dt)
	F.combo_show_t = maxf(0.0, F.combo_show_t - dt)
	_step_rapid(dt)
	_step_director(dt)
	for T in targets:
		if T.on:
			_step_target(T, dt)
	_step_rockets(dt)
	for i in range(_rings.size() - 1, -1, -1):
		_rings[i].t += dt
		if _rings[i].t >= _rings[i].life:
			_rings.remove_at(i)
	# Drawn about once a frame (update runs three times a frame).
	_draw_acc += dt
	if _draw_acc >= 0.0125:
		_draw_acc = 0.0
		draw()


func _movers() -> Dictionary:
	var out := {}
	for T in targets:
		if T.on:
			out[T.mover] = int(out.get(T.mover, 0)) + 1
	return out


## For tests and the HUD.
func gallery_state() -> Dictionary:
	return {"state": F.state, "score": F.score, "streak": F.streak, "best": F.best, "mult": F.mult, "rapid": F.rapid,
		"hits": F.hits, "bullseyes": F.bullseyes, "tricks": F.tricks, "ouches": F.ouches, "fireworks": F.fireworks,
		"alive": _alive(false), "movers": _movers(), "rows": rows.size(), "room": room(), "pace": pace(), "rapids": F.rapids, "rockets": _rockets.size()}
