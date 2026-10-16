class_name CastleStage
extends Node3D
## Dahrooj Fort («حصن الدحاريج», mode "castle"): a small cute fort stands in front of you and
## mischievous Dahroojs climb it from every side you can see (they set out in front of you,
## never behind you or close by). Knock them off with blaster shots and thrown Dahroojs:
##
## - ladder carriers walk in with a ladder over their heads, raise it against the wall and
##   climb; followers climb a ladder that is already up. Knock a ladder over and everyone on
##   it tumbles off (a chain).
## - stack gangs walk in together and hop onto each other into a living tower (three high);
##   the rest climb up the tower and hop over the wall. Hit one and everything above him
##   topples (hit the bottom one: the whole tower, a big combo).
## - a little catapult rolls in with its crew in tow and flings them up one by one (hit them
##   in the air for more; three hits smash the catapult and its crew).
## - parachuters float down onto the walls (shoot the canopy or the rider).
## - every 4th wave a siege tower rolls up to the wall, a rider on each floor: blast it apart
##   piece by piece (each floor you break drops the ones above; break the base and it all
##   comes down).
## Who reaches the top plants a silly flag (the Dahrooj's own colour, with eyes) and dances:
## the combo resets and it takes FLAG_PENALTY points; knock the dancer off and the flag comes
## down too. The siege tower docking against the wall takes SIEGE_PENALTY.
## Tumbling Dahroojs bounce off like rag dolls, see stars on the ground and pop; a fast one
## that lands on another knocks him too (domino).
##
## Open play: no lives, no clock, no board. Waves escalate without end (more of them, faster,
## more kinds); the points (× combo ×1 .. ×5) go to ctx.counts["castle"], the jelly score.
##
## Everything lives in the "Fort" child, in fort units: the fort's centre on the ground at
## `fort_at` (game units), `size` game units per fort unit. In mixed reality main pins the
## court (and so the fort) on the floor or a table; `planes_provider` (the room's planes, as
## SlimeStage's: {pos, normal, ax, ay, half, label} in game units) lets them march out of the
## real walls and parachute from the real ceiling. The blaster finds Dahroojs, canopies,
## ladders, catapults and the siege tower's pieces through hidden (layers = 0) MeshInstance3Ds;
## the fort itself is solid (shots stop on it). Effects are MultiMeshes and JuiceTexts.

const W := 3.2  # the fort's half width (fort units)
const H := 2.9  # the wall walk's height
const TOWER_R := 0.85
const TOWER_H := 4.3
const KEEP_C := Vector3(0, H + 1.05, -0.8)  # the keep on the roof (centre, half extents)
const KEEP_E := Vector3(1.15, 1.05, 1.15)
const R := 0.4  # a Dahrooj's radius
const GRAV := 13.0
const LANES := [-1.65, -0.55, 0.55, 1.65]
const MERLONS := [-2.3, -1.1, 0.0, 1.1, 2.3]
## Spots on each wall: the four gaps between the merlons, then the tops of the three middle
## merlons (cheeky dancers stand on the battlements).
const SPOTS := [[-1.65, 0], [-0.55, 0], [0.55, 0], [1.65, 0], [-1.1, 1], [0.0, 1], [1.1, 1]]
const SPOT_N := 7
const NORMALS := [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)]
const LAD_OUT := 1.05  # a ladder's foot, out from the wall
const LAD_W := 0.72
const STACK_STEP := 0.74  # centre to centre in a living tower
const TOWER_N := 3  # members in a tower; the rest climb it
const SLOTS := 60
const LADDERS := 8
const CATS := 2
const CANOPIES := 10
const SPARKS_MAX := 320
const PLANKS_MAX := 96
const RINGS_MAX := 14
const STARS_MAX := 72
const COMBO_T := 2.4
const COMBO_STEPS := [3, 6, 10, 15]  # combo counts where the multiplier steps up (×2 .. ×5)
const BANNER_T := 2.4
const BREAK_T := 2.6
const FIRST_BREAK_T := 1.8
const SIEGE_EVERY := 4
const PTS := {"climber": 10, "air": 15, "flag": 20, "ladder": 5, "cat": 30, "piece": 20, "siege": 150, "tick": 2}
## Points off the score when one gets onto the fort and plants his flag (however he got up:
## ladder, tower, catapult, parachute or siege ramp; ctx.nibble, the light touch), and when the
## siege tower docks against the wall (ctx.penalty, the full hit). Never below 0.
const FLAG_PENALTY := 10
const SIEGE_PENALTY := 25
const WALK := 1.7
const CLIMB := 1.3
const PARA_V := 1.3
const SIEGE_V := 1.05
const CAT_V := 1.9
const ARM_COCK := 1.2
const ARM_FIRE := -0.5
const ARM_L := 1.45
const ARM_PIVOT := Vector3(0, 0.62, 0.2)
const SIEGE_H := [0.7, 1.0, 1.0, 0.95]  # base, two floors, the deck (its floor at the wall walk)
const SIEGE_HP := [5, 3, 3, 3]
const DECK := 3
const SIEGE_HALF := 0.95
const COLORS := ["ff69b4", "b36bff", "ff9b3d", "6fa8d6", "7bbf8a", "e2603f", "ffd166", "46aaa9", "58b9ff", "ff505c", "f1ebe1"]
const ACCS := ["", "", "cap", "party", "glasses", "headphones", "scarf", "flower", "cap", "party"]
const WOOD := ["b07a45", "c48d52", "9b6a42", "d29a5c", "8a5a36"]
const STONE := ["f4e3c3", "e9d3ac", "f9ecd4", "dcc39a"]

static var _meshes := {}

var aim_z := -10.0
## The court runs out past the fort (the walkers come from there); in VR the player stands
## 2.5 m further back than the fort's spot (reach_z 5 units past aim_z), so the front corner is
## some 5.5 m away and the walkers coming round from behind it stay in view.
var far_z = -24.0
var reach_z = -15.0
var friction = null
var shot_time = 4.0
var ctx: GameCtx

## Where the fort stands (game units), how big a fort unit is (game units) and its turn about
## the vertical: a corner points at you, so two walls (the gate's and the next) face you.
var fort_at := Vector3(0, 0, -10)
var size := 1.0
var fort_yaw := -PI / 4.0
## The room's planes (mixed reality), see the header. Unset or empty: the court.
var planes_provider: Callable
## The player's eye (game units). Main keeps it current.
var viewer := Vector3(0, 3.2, 1.0)
## Game units per metre (main: the court's scale). Walkers, catapults and the siege tower
## start out in front of the player (RoomSpots.ARC either side of the court's forward, game
## -Z) and RoomSpots.MIN_DIST away or more (see _front()).
var unit := 2.0
## buzz(hand: String, amp: float, ms: float): haptics (main's buzz).
var buzz: Callable
## Waves start on their own (tests turn it off and spawn by hand).
var auto_spawn := true
## Main holds the game while the menu is open or the court is being placed.
var paused := false
var time := 0.0

var F := {"state": "idle", "wave": 0, "score": 0, "knocked": 0, "planted": 0, "queue": [], "spawn_t": 0.0,
	"break_t": 0.0, "combo": 0, "combo_t": 0.0, "mult": 1, "banner_t": 0.0, "banner_life": BANNER_T,
	"combo_show_t": 0.0, "combo_at": Vector3.ZERO, "touched": false, "throw_live": false, "throw_hits": 0,
	"best_chain": 0, "sieges": 0, "cleared": 0}
var root: Node3D
var fort: MeshInstance3D
var dudes: Array = []
var ladders: Array = []
var cats: Array = []
var siege := {}
var canopies: Array = []  # canopy proxies: {proxy, owner}
var spots: Array = []  # top spots on the walls: owner dude index or -1
var groups := {}
var crowd: Crowd
var banner: JuiceText
var banner_sub: JuiceText
var combo_label: JuiceText
var _sparks: Array = []
var _planks: Array = []
var _rings: Array = []
var _mm := {}
var _room: Array = []
var _room_t := 0.0
var _sim_acc := 0.0
var _next_group := 1
var _flag_said := -9.0
var _domino_said := -9.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 1717
	name = "Castle"
	root = Node3D.new()
	root.name = "Fort"
	add_child(root)
	fort = MeshInstance3D.new()
	fort.name = "FortWalls"
	fort.mesh = fort_mesh()
	fort.material_override = _mat("lit")
	root.add_child(fort)
	crowd = Crowd.new(SLOTS, true, true)
	crowd.name = "Climbers"
	root.add_child(crowd)
	for i in SLOTS:
		dudes.append({"on": false, "kind": "", "phase": "", "t": 0.0, "c": Vector3.ZERO, "v": Vector3.ZERO,
			"from": Vector3.ZERO, "to": Vector3.ZERO, "dur": 1.0, "arc": 0.0, "next": "", "path": [],
			"dir": Vector3.FORWARD, "hop": 0.0, "spd": 1.0, "style": "jelly", "color": "ff69b4", "acc": "",
			"sq": Vector2.ONE, "ax": Vector3.RIGHT, "ang": 0.0, "w": 0.0, "bounces": 0, "delay": 0.0,
			"spot": -1, "ladder": -1, "s": 0.0, "group": -1, "cat": -1, "piece": -1, "off": Vector3.ZERO,
			"flag_k": 0.0, "planted_at": 0.0, "blink": 0.0, "blink_t": 1.0, "knocks": 0, "canopy": -1,
			"face": 0, "u": 0.0, "seed": 0.0, "land_t": 0.0, "proxy": _proxy("ClimberHit%d" % i, "sphere")})
	for i in LADDERS:
		ladders.append({"on": false, "state": "", "base": Vector3.ZERO, "dir": Vector3.UP, "across": Vector3.RIGHT,
			"face": 0, "u": 0.0, "t": 0.0, "ang": 0.0, "w": 0.0, "owner": -1, "fade": 1.0, "ball_t": 0.0,
			"proxy": _proxy("LadderHit%d" % i, "box")})
	for i in CATS:
		cats.append({"on": false, "phase": "", "p": Vector3.ZERO, "from": Vector3.ZERO, "to": Vector3.ZERO,
			"b": Basis.IDENTITY, "face": 0, "ammo": [], "cup": -1, "t": 0.0, "arm": ARM_COCK, "hp": 3,
			"flash": 0.0, "cd": 0.0, "ball_t": 0.0, "roll": 0.0, "proxy": _proxy("CatapultHit%d" % i, "box")})
	for i in CANOPIES:
		canopies.append({"proxy": _proxy("CanopyHit%d" % i, "sphere"), "owner": -1})
	var sp: Array = []
	for i in SIEGE_H.size():
		sp.append(_proxy("SiegeHit%d" % i, "box"))
	siege = {"on": false, "phase": "", "p": Vector3.ZERO, "b": Basis.IDENTITY, "face": 0, "from": Vector3.ZERO,
		"to": Vector3.ZERO, "t": 0.0, "ramp": 0.0, "cd": 0.0, "idle": 0.0, "pieces": [], "proxies": sp, "ball_t": 0.0, "roll": 0.0}
	for k in 4 * SPOT_N:
		spots.append(-1)
	_mm.sparks = _multi("Sparks", Crowd.merge([[Crowd.sphere(1.0, 6, 4), Transform3D.IDENTITY, Color.WHITE]]), _mat("glow"), SPARKS_MAX)
	_mm.planks = _multi("Planks", Crowd.merge([[Crowd.box(1.0, 1.0, 1.0), Transform3D.IDENTITY, Color.WHITE]]), _mat("lit"), PLANKS_MAX)
	_mm.rings = _multi("Rings", Crowd.merge([[Crowd.torus(1.0, 0.07, 6, 40), Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO), Color.WHITE]]), _mat("glow"), RINGS_MAX)
	_mm.shadows = _multi("Shadows", Crowd.merge([[Crowd.circle(1.0, 20), Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3.ZERO), Color.WHITE]]), _mat("shadow"), SLOTS + CATS + 1)
	_mm.shadows.mesh = null  # no blob shadows in any mode (owner's call)
	_mm.stars = _multi("Stars", MoleStage.star_mesh(), _mat("flat2"), STARS_MAX)
	_mm.ladders = _multi("Ladders", ladder_mesh(), _mat("lit"), LADDERS)
	_mm.cat_body = _multi("CatapultBody", catapult_mesh(), _mat("lit"), CATS)
	_mm.cat_arm = _multi("CatapultArm", arm_mesh(), _mat("lit"), CATS)
	_mm.canopy = _multi("Canopies", canopy_mesh(), _mat("lit2"), CANOPIES)
	_mm.poles = _multi("FlagPoles", pole_mesh(), _mat("lit"), 16)
	_mm.cloth = _multi("FlagCloth", cloth_mesh(), _mat("lit2"), 16)
	_mm.siege_base = _multi("SiegeBase", siege_mesh("base"), _mat("lit"), 1)
	_mm.siege_tier = _multi("SiegeFloors", siege_mesh("tier"), _mat("lit"), 3)
	_mm.siege_deck = _multi("SiegeDeck", siege_mesh("deck"), _mat("lit"), 1)
	_mm.siege_ramp = _multi("SiegeRamp", siege_mesh("ramp"), _mat("lit"), 1)
	banner = _big_label("banner", 210 * 0.0062, Color("ffd166"))
	banner_sub = _big_label("sub", 96 * 0.0058, Color("fff3e0"))
	combo_label = _big_label("combo", 150 * 0.0058, Color("ff7ad9"))
	_sync_root()
	draw()


func _big_label(kind: String, em: float, col: Color) -> JuiceText:
	var l := JuiceText.make(kind, em)
	if kind != "combo":
		l.modulate = col
	root.add_child(l)
	return l


# ---- art ----

func _proxy(id: String, shape: String) -> MeshInstance3D:
	var p := MeshInstance3D.new()
	p.name = id
	p.mesh = _proxy_mesh(shape)
	p.layers = 0  # never drawn: only the blaster's ray sees it
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visible = false
	root.add_child(p)
	return p


static func _proxy_mesh(shape: String) -> Mesh:
	if not _meshes.has("proxy_" + shape):
		if shape == "box":
			var b := BoxMesh.new()
			b.size = Vector3.ONE
			_meshes["proxy_box"] = b
		else:
			var s := SphereMesh.new()
			s.radius = 1.0
			s.height = 2.0
			s.radial_segments = 12
			s.rings = 6
			_meshes["proxy_sphere"] = s
	return _meshes["proxy_" + shape]


static func _mat(key: String) -> Material:
	if _meshes.has("mat_" + key):
		return _meshes["mat_" + key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	match key:
		"lit":
			m.roughness = 0.85
		"lit2":
			m.roughness = 0.7
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"glow":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		"flat2":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"shadow":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.render_priority = -1
	_meshes["mat_" + key] = m
	return m


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
	mi.custom_aabb = AABB(Vector3(-50, -10, -50), Vector3(100, 60, 100))
	root.add_child(mi)
	return mm


static func _box(list: Array, c: Vector3, e: Vector3, col: String, rot := Basis.IDENTITY) -> void:
	list.append([Crowd.box(e.x, e.y, e.z), Transform3D(rot, c), Color(col)])


## An arched opening on a face (bottom centre at c): a box with a half disc on top (facing n).
static func _arch(list: Array, c: Vector3, n: Vector3, w: float, h: float, col: String, depth := 0.06) -> void:
	var t := Vector3.UP.cross(n).normalized()
	var b := Basis(t, Vector3.UP, n)
	var hb := h - w * 0.5
	_box(list, c + Vector3.UP * hb * 0.5, Vector3(w, hb, depth), col, b)
	# Half disc: a cylinder (axis along n) cut to its upper half.
	list.append([Crowd.cylinder(w * 0.5, w * 0.5, depth, 14, false, -PI / 2.0, PI), Transform3D(b * Basis(Vector3.RIGHT, -PI / 2.0), c + Vector3.UP * hb), Color(col)])


## The fort (fort units, centre of its footprint at the origin): a cream stone keep block with
## crenellations, four round corner towers with pink and teal cone roofs and pennants, a
## wooden gate, arched windows with flower boxes, a little keep on the roof with the big flag.
static func fort_mesh() -> ArrayMesh:
	if _meshes.has("fort"):
		return _meshes["fort"]
	var list := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	_box(list, Vector3(0, 0.14, 0), Vector3(W * 2 + 0.5, 0.28, W * 2 + 0.5), "cdb48c")
	_box(list, Vector3(0, H * 0.5, 0), Vector3(W * 2, H, W * 2), "f4e3c3")
	_box(list, Vector3(0, H + 0.02, 0), Vector3(W * 2 - 0.2, 0.06, W * 2 - 0.2), "e2cba2")
	for f in 4:
		var n: Vector3 = NORMALS[f]
		var t := Vector3.UP.cross(n)
		var fb := Basis(t, Vector3.UP, n)
		# Stone blocks standing out a little, in rows.
		for row in 4:
			var y := 0.55 + row * 0.55
			var u := -W + 0.9 + rng.randf_range(0.0, 0.6)
			while u < W - 0.9:
				var bw := rng.randf_range(0.45, 0.85)
				if rng.randf() < 0.55 and not (f == 0 and absf(u) < 1.0 and y < 2.4):
					_box(list, n * (W + 0.025) + t * (u + bw * 0.5) + Vector3.UP * y, Vector3(bw - 0.06, 0.46, 0.05), STONE[rng.randi() % STONE.size()], fb)
				u += bw + rng.randf_range(0.1, 0.5)
		# A band under the battlements.
		_box(list, n * (W + 0.04) + Vector3.UP * (H - 0.12), Vector3(W * 2 + 0.02, 0.2, 0.1), "e6cfa5", fb)
		# Merlons between the lanes (the climbers come over the gaps).
		for u in MERLONS:
			_box(list, n * (W - 0.22) + t * float(u) + Vector3.UP * (H + 0.29), Vector3(0.6, 0.58, 0.44), "f1dcb6", fb)
			_box(list, n * (W - 0.22) + t * float(u) + Vector3.UP * (H + 0.6), Vector3(0.66, 0.06, 0.5), "e2cba2", fb)
		if f == 0:
			# The gate: a stone frame, the wooden door with planks, studs and a ring.
			_arch(list, n * (W + 0.03) + Vector3.UP * 0.28, n, 1.7, 2.35, "d6bd93", 0.06)
			_arch(list, n * (W + 0.07) + Vector3.UP * 0.28, n, 1.36, 2.1, "7a4a2c", 0.06)
			for k in 4:
				var x := -0.51 + k * 0.34
				_box(list, n * (W + 0.11) + t * x + Vector3.UP * 1.1, Vector3(0.04, 1.6, 0.02), "5e3720", fb)
			for y in [0.7, 1.5]:
				_box(list, n * (W + 0.12) + Vector3.UP * float(y), Vector3(1.3, 0.1, 0.03), "4a4350", fb)
			list.append([Crowd.torus(0.1, 0.025, 6, 14), Transform3D(fb, n * (W + 0.14) + t * 0.32 + Vector3.UP * 1.15), Color("ffd166")])
			for s in [-1.0, 1.0]:
				var x := 1.5 * float(s)
				_arch(list, n * (W + 0.05) + t * x + Vector3.UP * 1.7, n, 0.5, 0.8, "4a3550")
				_box(list, n * (W + 0.15) + t * x + Vector3.UP * 1.62, Vector3(0.7, 0.16, 0.22), "a5673f", fb)
				for k in 4:
					list.append([Crowd.sphere(0.09, 6, 4), Transform3D(Basis.IDENTITY, n * (W + 0.2) + t * (x - 0.24 + k * 0.16) + Vector3.UP * 1.75), Color(["ff6fae", "ffd166", "ff8a5c", "ffffff"][k])])
		else:
			for x in [-1.1, 1.1]:
				_arch(list, n * (W + 0.05) + t * float(x) + Vector3.UP * 1.7, n, 0.42, 0.7, "4a3550")
	# Corner towers.
	var roofs := ["ff6f9f", "6fc6d6", "6fc6d6", "ff6f9f"]
	var k := 0
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var c := Vector3(W * sx, 0, W * sz)
			list.append([Crowd.cylinder(TOWER_R, TOWER_R * 1.06, TOWER_H, 22), Transform3D(Basis.IDENTITY, c + Vector3.UP * TOWER_H * 0.5), Color("f7e1c8")])
			list.append([Crowd.cylinder(TOWER_R * 1.1, TOWER_R * 1.1, 0.22, 22), Transform3D(Basis.IDENTITY, c + Vector3.UP * (TOWER_H - 0.05)), Color("e6cfa5")])
			for m in 8:
				var a := TAU * m / 8.0
				var mp := c + Vector3(cos(a), 0, sin(a)) * TOWER_R * 0.92 + Vector3.UP * (TOWER_H + 0.25)
				_box(list, mp, Vector3(0.3, 0.38, 0.3), "f1dcb6", Basis(Vector3.UP, -a))
			list.append([Crowd.cylinder(0.0, TOWER_R * 1.22, 1.7, 22), Transform3D(Basis.IDENTITY, c + Vector3.UP * (TOWER_H + 0.42 + 0.85)), Color(roofs[k])])
			list.append([Crowd.sphere(0.12, 8, 6), Transform3D(Basis.IDENTITY, c + Vector3.UP * (TOWER_H + 2.2)), Color("ffd166")])
			list.append([Crowd.cylinder(0.03, 0.03, 0.8, 6), Transform3D(Basis.IDENTITY, c + Vector3.UP * (TOWER_H + 2.6)), Color("8a5a36")])
			_box(list, c + Vector3(0.24, TOWER_H + 2.82, 0), Vector3(0.44, 0.26, 0.03), roofs[3 - k])
			# A window on the tower, facing out.
			var out := Vector3(sx, 0, sz).normalized()
			_arch(list, c + out * (TOWER_R * 1.02) + Vector3.UP * (H - 0.75), out, 0.32, 0.55, "4a3550")
			k += 1
	# The keep on the roof, its pyramid roof and the big flag.
	_box(list, KEEP_C, KEEP_E * 2.0, "f9e6cc")
	_box(list, KEEP_C + Vector3.UP * (KEEP_E.y - 0.05), KEEP_E * 2.0 + Vector3(0.14, -KEEP_E.y * 2.0 + 0.12, 0.14), "e6cfa5")
	list.append([Crowd.cylinder(0.0, KEEP_E.x * 1.62, 1.5, 4), Transform3D(Basis(Vector3.UP, PI / 4.0), KEEP_C + Vector3.UP * (KEEP_E.y + 0.75)), Color("ff6f9f")])
	_arch(list, KEEP_C + Vector3(0, -0.45, KEEP_E.z + 0.02), Vector3.BACK, 0.55, 0.9, "4a3550")
	list.append([Crowd.sphere(0.14, 8, 6), Transform3D(Basis.IDENTITY, KEEP_C + Vector3.UP * (KEEP_E.y + 1.55)), Color("ffd166")])
	list.append([Crowd.cylinder(0.035, 0.035, 1.3, 6), Transform3D(Basis.IDENTITY, KEEP_C + Vector3.UP * (KEEP_E.y + 2.2)), Color("8a5a36")])
	_box(list, KEEP_C + Vector3(0.42, KEEP_E.y + 2.55, 0), Vector3(0.8, 0.5, 0.04), "ffd166")
	list.append([Crowd.sphere(0.13, 10, 6), Transform3D(Basis.IDENTITY, KEEP_C + Vector3(0.42, KEEP_E.y + 2.55, 0.025)), Color("ff6f9f")])
	# Bushes round the foot.
	for i in 14:
		var a := TAU * i / 14.0 + 0.2
		var d := W + 0.55 + rng.randf_range(0.0, 0.35)
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		p.x = clampf(p.x, -W - 0.7, W + 0.7)
		p.z = clampf(p.z, -W - 0.7, W + 0.7)
		if p.z > W and absf(p.x) < 1.2:
			continue
		var r := rng.randf_range(0.22, 0.38)
		list.append([Crowd.sphere(r, 8, 6), Transform3D(Basis.from_scale(Vector3(1.2, 0.85, 1.2)), p + Vector3.UP * r * 0.6), Color(["6cbf6a", "5aa95c", "7fcf74"][i % 3])])
		if i % 3 == 0:
			list.append([Crowd.sphere(0.07, 6, 4), Transform3D(Basis.IDENTITY, p + Vector3.UP * r * 1.25), Color("ff8ac2")])
	var mesh := Crowd.merge(list)
	_meshes["fort"] = mesh
	return mesh


static func ladder_len() -> float:
	return Vector2(LAD_OUT, H + 0.3).length()


## A wooden ladder along +Y from 0 to its length, across along X.
static func ladder_mesh() -> ArrayMesh:
	if _meshes.has("ladder"):
		return _meshes["ladder"]
	var L := ladder_len()
	var list := []
	for s in [-1.0, 1.0]:
		_box(list, Vector3(float(s) * LAD_W * 0.45, L * 0.5, 0), Vector3(0.1, L, 0.1), "b07a45")
	var y := 0.35
	while y < L - 0.1:
		_box(list, Vector3(0, y, 0), Vector3(LAD_W * 0.9, 0.07, 0.07), "e0a764")
		y += 0.42
	var mesh := Crowd.merge(list)
	_meshes["ladder"] = mesh
	return mesh


## The catapult's frame, facing -Z: beams, four wheels, the uprights and the stop bar.
static func catapult_mesh() -> ArrayMesh:
	if _meshes.has("cat"):
		return _meshes["cat"]
	var list := []
	for s in [-1.0, 1.0]:
		var x := float(s)
		_box(list, Vector3(x * 0.42, 0.42, 0), Vector3(0.16, 0.18, 1.9), "9b6a42")
		_box(list, Vector3(x * 0.33, 1.0, -0.25), Vector3(0.13, 1.25, 0.13), "b07a45", Basis(Vector3.RIGHT, 0.18))
		for z in [-0.62, 0.62]:
			var wc := Vector3(x * 0.56, 0.32, float(z))
			list.append([Crowd.cylinder(0.32, 0.32, 0.12, 16), Transform3D(Basis(Vector3.BACK, PI / 2.0), wc), Color("6b4429")])
			list.append([Crowd.cylinder(0.11, 0.11, 0.15, 10), Transform3D(Basis(Vector3.BACK, PI / 2.0), wc), Color("ffd166")])
	for z in [-0.8, 0.0, 0.8]:
		_box(list, Vector3(0, 0.42, float(z)), Vector3(0.9, 0.14, 0.14), "8a5a36")
	_box(list, Vector3(0, 1.55, -0.38), Vector3(0.86, 0.16, 0.16), "c48d52")
	_box(list, Vector3(0, 1.55, -0.38), Vector3(0.9, 0.06, 0.2), "ff6f9f")
	list.append([Crowd.cylinder(0.08, 0.08, 0.95, 8), Transform3D(Basis(Vector3.BACK, PI / 2.0), ARM_PIVOT), Color("5e3720")])
	var mesh := Crowd.merge(list)
	_meshes["cat"] = mesh
	return mesh


## The throwing arm along +Y from the pivot, the cup at the tip.
static func arm_mesh() -> ArrayMesh:
	if _meshes.has("arm"):
		return _meshes["arm"]
	var list := []
	_box(list, Vector3(0, ARM_L * 0.5, 0), Vector3(0.14, ARM_L, 0.14), "c48d52")
	list.append([Crowd.sphere(0.36, 12, 8, 0.0, TAU, PI * 0.5, PI * 0.5), Transform3D(Basis.IDENTITY, Vector3(0, ARM_L + 0.12, 0)), Color("8a5a36")])
	list.append([Crowd.torus(0.34, 0.05, 6, 16), Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, ARM_L + 0.12, 0)), Color("ffd166")])
	var mesh := Crowd.merge(list)
	_meshes["arm"] = mesh
	return mesh


## A striped parachute (white and grey: the instance colour tints it), strings to the rider at
## (0, -1.6, 0).
static func canopy_mesh() -> ArrayMesh:
	if _meshes.has("canopy"):
		return _meshes["canopy"]
	var list := []
	var seg := 8
	var th := 1.25
	for i in seg:
		var col := Color("ffffff") if i % 2 == 0 else Color("b9b9b9")
		list.append([Crowd.sphere(1.0, 4, 6, TAU * i / seg, TAU / seg, 0.0, th), Transform3D(Basis.from_scale(Vector3(1, 0.62, 1)), Vector3.ZERO), col])
	var rim_y := cos(th) * 0.62
	var rim_r := sin(th)
	var tip := Vector3(0, -1.25, 0)
	for i in 6:
		var a := TAU * i / 6.0
		var top := Vector3(cos(a) * rim_r, rim_y, sin(a) * rim_r)
		var mid := (top + tip) * 0.5
		var d := tip - top
		var b := Basis(Quaternion(Vector3.UP, d.normalized()))
		list.append([Crowd.cylinder(0.012, 0.012, d.length(), 4), Transform3D(b, mid), Color("f4f0e8")])
	var mesh := Crowd.merge(list)
	_meshes["canopy"] = mesh
	return mesh


static func pole_mesh() -> ArrayMesh:
	if _meshes.has("pole"):
		return _meshes["pole"]
	var list := []
	list.append([Crowd.cylinder(0.035, 0.04, 1.3, 6), Transform3D(Basis.IDENTITY, Vector3(0, 0.65, 0)), Color("8a5a36")])
	list.append([Crowd.sphere(0.07, 8, 6), Transform3D(Basis.IDENTITY, Vector3(0, 1.32, 0)), Color("ffd166")])
	var mesh := Crowd.merge(list)
	_meshes["pole"] = mesh
	return mesh


## The cheeky flag: a swallow-tailed cloth from the pole (at x = 0) with two googly eyes and a
## grin (the cloth is white: the instance colour tints it; the face stays dark).
static func cloth_mesh() -> ArrayMesh:
	if _meshes.has("cloth"):
		return _meshes["cloth"]
	var list := []
	_box(list, Vector3(0.3, 0, 0), Vector3(0.6, 0.46, 0.025), "ffffff")
	_box(list, Vector3(0.66, 0.13, 0), Vector3(0.14, 0.2, 0.025), "ffffff")
	_box(list, Vector3(0.66, -0.13, 0), Vector3(0.14, 0.2, 0.025), "ffffff")
	for s in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			list.append([Crowd.sphere(0.07, 8, 6), Transform3D(Basis.from_scale(Vector3(1, 1, 0.4)), Vector3(0.3 + float(s) * 0.11, 0.07, float(z) * 0.015)), Color("fbfbfb")])
			list.append([Crowd.sphere(0.036, 6, 4), Transform3D(Basis.from_scale(Vector3(1, 1, 0.4)), Vector3(0.3 + float(s) * 0.11 + 0.015, 0.06, float(z) * 0.03)), Color("1a1424")])
		list.append([Crowd.torus(0.09, 0.018, 4, 10, PI), Transform3D(Basis(Vector3.BACK, PI), Vector3(0.3, -0.05, float(s) * 0.016)), Color("1a1424")])
	var mesh := Crowd.merge(list)
	_meshes["cloth"] = mesh
	return mesh


## The siege tower's parts (local: -Z toward the fort, +Z open toward you): the wheeled base,
## a floor (posts, low side walls, a front shield, a back rail), the deck (shield with
## battlements, a pennant) and the ramp (along +Y from its hinge).
static func siege_mesh(part: String) -> ArrayMesh:
	if _meshes.has("siege_" + part):
		return _meshes["siege_" + part]
	var list := []
	var e := SIEGE_HALF
	match part:
		"base":
			_box(list, Vector3(0, 0.56, 0), Vector3(e * 2 + 0.1, 0.26, e * 2 + 0.1), "8a5a36")
			for x in [-0.62, 0.62]:
				for z in [-1.0, 1.0]:
					var wc := Vector3(float(x), 0.38, float(z) * (e + 0.12))
					list.append([Crowd.cylinder(0.38, 0.38, 0.14, 18), Transform3D(Basis(Vector3.RIGHT, PI / 2.0), wc), Color("6b4429")])
					list.append([Crowd.cylinder(0.12, 0.12, 0.17, 10), Transform3D(Basis(Vector3.RIGHT, PI / 2.0), wc), Color("ffd166")])
					for k in 3:
						_box(list, wc, Vector3(0.66, 0.05, 0.16), "9b6a42", Basis(Vector3.BACK, k * PI / 3.0))
		"tier":
			_box(list, Vector3(0, 0.06, 0), Vector3(e * 2, 0.12, e * 2), "9b6a42")
			for x in [-1.0, 1.0]:
				for z in [-1.0, 1.0]:
					_box(list, Vector3(float(x) * (e - 0.07), 0.5, float(z) * (e - 0.07)), Vector3(0.14, 1.0, 0.14), "8a5a36")
				_box(list, Vector3(float(x) * (e - 0.04), 0.24, 0), Vector3(0.08, 0.26, e * 2 - 0.1), "c48d52")
				_box(list, Vector3(float(x) * (e - 0.02), 0.62, 0), Vector3(0.1, 0.08, e * 2), "b07a45")
				_box(list, Vector3(float(x) * (e - 0.02), 0.62, 0), Vector3(0.06, 0.06, e * 2), "b07a45", Basis(Vector3.RIGHT, 0.5))
			_box(list, Vector3(0, 0.5, -(e - 0.04)), Vector3(e * 2, 0.88, 0.08), "c48d52")
			for k in 4:
				_box(list, Vector3(-0.72 + k * 0.48, 0.5, -(e + 0.01)), Vector3(0.04, 0.86, 0.02), "9b6a42")
			_box(list, Vector3(0, 0.62, e - 0.04), Vector3(e * 2, 0.08, 0.08), "b07a45")
			_box(list, Vector3(0, 0.3, e - 0.04), Vector3(0.08, 0.6, 0.08), "8a5a36")
		"deck":
			_box(list, Vector3(0, 0.06, 0), Vector3(e * 2 + 0.1, 0.12, e * 2 + 0.1), "9b6a42")
			_box(list, Vector3(0, 0.45, -(e - 0.02)), Vector3(e * 2, 0.75, 0.1), "c48d52")
			for k in 4:
				_box(list, Vector3(-0.75 + k * 0.5, 0.92, -(e - 0.02)), Vector3(0.28, 0.24, 0.12), "b07a45")
			for x in [-1.0, 1.0]:
				_box(list, Vector3(float(x) * (e - 0.03), 0.3, 0.1), Vector3(0.08, 0.45, e * 2 - 0.2), "c48d52")
			list.append([Crowd.cylinder(0.03, 0.03, 1.4, 6), Transform3D(Basis.IDENTITY, Vector3(e - 0.1, 0.7, e - 0.1)), Color("5e3720")])
			_box(list, Vector3(e + 0.14, 1.22, e - 0.1), Vector3(0.48, 0.28, 0.03), "ff505c")
		"ramp":
			_box(list, Vector3(0, 0.62, 0), Vector3(1.3, 1.24, 0.08), "b07a45")
			for k in 4:
				_box(list, Vector3(0, 0.2 + k * 0.3, 0.05), Vector3(1.3, 0.05, 0.04), "8a5a36")
	var mesh := Crowd.merge(list)
	_meshes["siege_" + part] = mesh
	return mesh


# ---- frames, ctx ----

func _sync_root() -> void:
	root.transform = Transform3D(Basis(Vector3.UP, fort_yaw) * Basis.from_scale(Vector3.ONE * size), fort_at)


## Game units -> fort units and back (points; directions with _ldir / _gdir).
func to_fort(p: Vector3) -> Vector3:
	return Basis(Vector3.UP, -fort_yaw) * (p - fort_at) / size


func to_game(p: Vector3) -> Vector3:
	return fort_at + Basis(Vector3.UP, fort_yaw) * p * size


func _ldir(v: Vector3) -> Vector3:
	return Basis(Vector3.UP, -fort_yaw) * v


func _gdir(v: Vector3) -> Vector3:
	return Basis(Vector3.UP, fort_yaw) * v


func _view() -> Vector3:
	return to_fort(viewer)


func _en() -> bool:
	return ctx != null and ctx.lang == "en"


func _num(v: int) -> String:
	return str(v) if _en() else GameCtx.ar_digits(v)


func _tx(ar: String, en: String) -> String:
	return en if _en() else ar


func _sfx(n: String, k: float, p: Vector3) -> void:
	if ctx:
		ctx.sfx.call(n, k, to_game(p))


func _confetti(at: Vector3, k := 1.0) -> void:
	if ctx:
		var g := to_game(at)
		ctx.confetti.call(g, 1.2 * k * size, 1.4, maxf(1.0, g.distance_to(viewer) / 7.0))


func _buzz2(amp: float, ms: float) -> void:
	if buzz.is_valid():
		buzz.call("left", amp, ms)
		buzz.call("right", amp, ms)


# ---- geometry helpers ----

static func face_n(f: int) -> Vector3:
	return NORMALS[f]


static func face_t(f: int) -> Vector3:
	return Vector3.UP.cross(NORMALS[f])


static func spot_face(k: int) -> int:
	return floori(k / float(SPOT_N))


## A top spot (index face * SPOT_N + j): where a Dahrooj stands to dance (his centre).
static func spot_pos(k: int) -> Vector3:
	var f := spot_face(k)
	var sp: Array = SPOTS[k % SPOT_N]
	var u: float = sp[0]
	if int(sp[1]) == 1:
		return face_n(f) * (W - 0.22) + face_t(f) * u + Vector3.UP * (H + 0.64 + R)
	return face_n(f) * (W - 0.32) + face_t(f) * u + Vector3.UP * (H + R)


## The faces you can see (VR: the front and both sides).
func faces() -> Array:
	var v := _view()
	var vd := Vector3(v.x, 0, v.z)
	vd = vd.normalized() if vd.length_squared() > 1e-4 else Vector3.BACK
	var out: Array = []
	for f in 4:
		if face_n(f).dot(vd) > 0.25:
			out.append(f)
	if out.is_empty():
		out.append(front_face())
	return out


## The face that looks at you most.
func front_face() -> int:
	var v := _view()
	var best := 0
	var bd := -INF
	for f in 4:
		var d := face_n(f).dot(Vector3(v.x, 0, v.z))
		if d > bd:
			bd = d
			best = f
	return best


func _pick_face() -> int:
	var fs := faces()
	var ff := front_face()
	if _rng.randf() < 0.45 and ff in fs:
		return ff
	return fs[_rng.randi() % fs.size()]


## A lane on face f that no ladder or tower holds, if there is one.
func _pick_lane(f: int) -> float:
	var free: Array = []
	for u in LANES:
		var used := false
		for l in ladders:
			if l.on and l.face == f and absf(float(l.u) - float(u)) < 0.1:
				used = true
		for gid in groups:
			var g: Dictionary = groups[gid]
			if g.face == f and absf(float(g.u) - float(u)) < 0.1:
				used = true
		if not used:
			free.append(u)
	var list: Array = free if not free.is_empty() else LANES
	return list[_rng.randi() % list.size()]


## The floor under p: the roof inside the walls, the ground outside.
static func floor_y(p: Vector3) -> float:
	return H if absf(p.x) < W and absf(p.z) < W else 0.0


static func _inside(p: Vector3, m: float) -> bool:
	if absf(p.x) < W + m and absf(p.z) < W + m:
		return true
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			if Vector2(p.x - W * float(sx), p.z - W * float(sz)).length() < TOWER_R + m:
				return true
	return false


static func _seg_hits(a: Vector3, b: Vector3) -> bool:
	for k in range(1, 12):
		var p := a.lerp(b, k / 12.0)
		if _inside(p, 0.25):
			return true
	return false


## A walk from a to b around the fort: [waypoints..., b].
static func path_to(a: Vector3, b: Vector3, f: int) -> Array:
	var out := face_n(f) * (W + 2.0) + face_t(f) * face_t(f).dot(b)
	out.y = 0.0
	if not _seg_hits(a, out):
		return [out, b]
	var best: Array = [out, b]
	var bl := INF
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var c := Vector3(float(sx) * (W + 2.0), 0, float(sz) * (W + 2.0))
			if _seg_hits(a, c) or _seg_hits(c, out):
				continue
			var l := a.distance_to(c) + c.distance_to(out)
			if l < bl:
				bl = l
				best = [c, out, b]
	return best


## Whether a point (fort units) is in front of the player and far enough (RoomSpots.ahead).
func is_front(p: Vector3) -> bool:
	return RoomSpots.ahead(viewer, to_game(p), RoomSpots.MIN_DIST * unit)


## A start point (fort units, its height kept) moved, if need be, into the arc in front of the
## player and RoomSpots.MIN_DIST away from them.
func _front(p: Vector3) -> Vector3:
	if is_front(p):
		return p
	var q := to_fort(RoomSpots.into_arc(viewer, to_game(p), RoomSpots.MIN_DIST * unit))
	q.y = p.y
	return q


## Where walkers come from: the real walls in a room, the far court otherwise; always out in
## front of the player (never behind them or close).
func _spawn_point(f: int) -> Vector3:
	var n := face_n(f)
	var t := face_t(f)
	var walls: Array = []
	for s in _room:
		if s.kind == "wall" and (s.pos as Vector3).dot(n) > W and is_front(s.pos):
			walls.append(s)
	if not walls.is_empty():
		var s: Dictionary = walls[_rng.randi() % walls.size()]
		_ring(s.pos + Vector3.UP * 0.05, 0.2, 1.4, 0.45, Color("ffcf6b"))
		return s.pos
	var p := Vector3.ZERO
	for _try in 10:
		p = n * _rng.randf_range(12.0, 14.0) + t * _rng.randf_range(-6.0, 6.0) * _away(f)
		if is_front(p):
			return p
	return _front(p)


## +1 / -1: along face f's tangent, the way away from the other wall you see (0: both ways).
func _away(f: int) -> float:
	for o in faces():
		if o != f:
			var d := face_t(f).dot(face_n(o))
			if absf(d) > 0.5:
				return -signf(d)
	return -1.0 if _rng.randf() < 0.5 else 1.0


# ---- the room (mixed reality) ----

func _planes() -> Array:
	if planes_provider.is_valid():
		var p = planes_provider.call()
		if p is Array:
			return p
	return []


## The room's walls (as spawn spots on the fort's ground) and ceiling (the parachuters' sky).
func _scan_room() -> void:
	_room = []
	for pl in _planes():
		var n := _ldir(pl.normal as Vector3).normalized()
		var c := to_fort(pl.pos)
		var lab := String(pl.get("label", ""))
		if lab == "ceiling" or n.y < -0.8:
			_room.append({"kind": "ceiling", "y": c.y})
			continue
		if absf(n.y) > 0.3:
			continue
		var ax := _ldir(pl.get("ax", Vector3.RIGHT))
		var ay := _ldir(pl.get("ay", Vector3.UP))
		var half: Vector2 = pl.get("half", Vector2.ONE)
		var bottom := c.y - (absf(ax.y) * half.x + absf(ay.y) * half.y) / size
		if absf(bottom) > 1.2:
			continue  # the wall doesn't come down to the fort's ground (a table)
		var hz: Vector3 = ax if absf(ax.y) < 0.5 else ay
		var hl: float = half.x if absf(ax.y) < 0.5 else half.y
		hz = Vector3(hz.x, 0, hz.z).normalized()
		for k in 3:
			var p := c + hz * (k - 1) * hl * 0.6 / size + Vector3(n.x, 0, n.z).normalized() * R * 1.5
			p.y = 0.0
			var d := Vector2(p.x, p.z).length()
			if d > W + 3.0 and d < 40.0:
				_room.append({"kind": "wall", "pos": p})


func _para_top() -> float:
	var top := 10.5
	for s in _room:
		if s.kind == "ceiling" and float(s.y) > H + 3.0:
			top = minf(top, float(s.y) - 1.0)
	return top


# ---- effects ----

func _spark(p: Vector3, v: Vector3, life: float, c: Color, s: float, g := 1.0) -> void:
	if _sparks.size() >= SPARKS_MAX:
		_sparks.pop_front()
	_sparks.append({"p": p, "v": v, "t": 0.0, "life": life, "c": c, "s": s, "g": g})


func _burst(at: Vector3, col: Color, count: int, k: float) -> void:
	for i in count:
		var a := _rng.randf() * TAU
		var e := _rng.randf_range(-0.4, 1.2)
		var sp := _rng.randf_range(2.0, 5.0) * k
		var v := Vector3(cos(a) * cos(e), sin(e), sin(a) * cos(e)) * sp + Vector3.UP * 1.4
		var c := col if i % 3 != 0 else Color("fffaf2")
		if i % 5 == 4:
			c = Color("ffd23f")
		_spark(at, v, _rng.randf_range(0.4, 0.8), c, _rng.randf_range(0.05, 0.11) * k, 0.6)


func _dust(at: Vector3, count: int) -> void:
	for i in count:
		var a := _rng.randf() * TAU
		_spark(at, Vector3(cos(a), 0.6, sin(a)) * _rng.randf_range(1.0, 2.4), _rng.randf_range(0.3, 0.55), Color("e8d8b8"), _rng.randf_range(0.05, 0.1), 0.5)


func _plank(p: Vector3, v: Vector3, e: Vector3, col: Color) -> void:
	if _planks.size() >= PLANKS_MAX:
		_planks.pop_front()
	_planks.append({"p": p, "v": v, "e": e, "c": col, "ax": Vector3(_rng.randf() - 0.5, _rng.randf() - 0.5, _rng.randf() - 0.5).normalized(),
		"ang": 0.0, "w": _rng.randf_range(4.0, 11.0), "t": 0.0, "life": _rng.randf_range(1.6, 2.4)})


## Splinters and planks flying out of a broken wooden thing (a box of half extents e at c).
func _splinter(c: Vector3, e: Vector3, count: int, k := 1.0) -> void:
	for i in count:
		var p := c + Vector3(_rng.randf_range(-e.x, e.x), _rng.randf_range(-e.y, e.y), _rng.randf_range(-e.z, e.z))
		var out := (p - c + Vector3.UP * 0.3).normalized()
		var v := out * _rng.randf_range(2.0, 5.0) * k + Vector3.UP * _rng.randf_range(2.0, 4.5)
		var sz := Vector3(_rng.randf_range(0.08, 0.14), _rng.randf_range(0.08, 0.14), _rng.randf_range(0.35, 0.8))
		_plank(p, v, sz, Color(WOOD[_rng.randi() % WOOD.size()]))
	_burst(c, Color("d29a5c"), count + 6, 0.9 * k)


func _ring(at: Vector3, r0: float, r1: float, life: float, col: Color) -> void:
	if _rings.size() >= RINGS_MAX:
		_rings.pop_front()
	_rings.append({"p": at, "r0": r0, "r1": r1, "t": 0.0, "life": life, "c": col})


func _label(at: Vector3, text: String, col: Color, k := 1.0) -> void:
	JuiceText.spawn(root, text, at, "points", k * 0.0085 * 120.0 / 0.66, col)

## Where banners show: between the fort's top and you, a little above your eye line.
func banner_at() -> Vector3:
	var v := _view()
	var top := Vector3(0, H + 2.4, 0)
	return top.lerp(v, 0.35) + Vector3.DOWN * 0.6  # under the HUD's score


func _banner(text: String, sub: String, color: Color, secs := BANNER_T) -> void:
	banner.text = text
	banner.modulate = color
	banner_sub.text = sub
	F.banner_t = secs
	F.banner_life = secs


# ---- scoring ----

static func multiplier(combo: int) -> int:
	var m := 1
	for s in COMBO_STEPS:
		if combo >= int(s):
			m += 1
	return m


## Points (× the combo multiplier) with a floating label; count = a knock that feeds the combo.
func award(base: int, at: Vector3, count: bool, extra := "", quiet := false) -> int:
	if count:
		F.combo = F.combo + 1 if F.combo_t > 0.0 else 1
		F.combo_t = COMBO_T
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
		ctx.counts["castle"] = int(ctx.counts.get("castle", 0)) + pts
	if quiet:
		return pts
	var txt := "+" + _num(pts)
	if extra != "":
		txt = extra + " " + txt
	_label(at + Vector3.UP * R * 1.2, txt, Color("ffe08a") if F.mult <= 1 else Color("ff8ad8"), 1.0 + 0.1 * (F.mult - 1))
	return pts


func _break_combo() -> void:
	F.combo = 0
	F.combo_t = 0.0
	F.mult = 1


# ---- the Dahroojs ----

func _free_slot() -> int:
	for i in dudes.size():
		if not dudes[i].on:
			return i
	return -1


func _new_dude(kind: String, at: Vector3) -> int:
	var i := _free_slot()
	if i < 0:
		return -1
	var d: Dictionary = dudes[i]
	d.on = true
	d.kind = kind
	d.phase = "walk"
	d.t = 0.0
	d.c = at + Vector3.UP * R
	d.v = Vector3.ZERO
	d.path = []
	d.hop = _rng.randf() * TAU
	d.spd = wave_speed(maxi(1, F.wave)) * _rng.randf_range(0.9, 1.1)
	d.style = Crowd.STYLES[_rng.randi() % Crowd.STYLES.size()]
	d.color = COLORS[_rng.randi() % COLORS.size()] if _rng.randf() < 0.75 else Crowd.DAHROOJ_COLORS[d.style]
	d.acc = ACCS[_rng.randi() % ACCS.size()]
	if _rng.randf() < 0.04:
		d.acc = "crown"
	d.sq = Vector2.ONE
	d.ang = 0.0
	d.w = 0.0
	d.bounces = 0
	d.delay = 0.0
	d.spot = -1
	d.ladder = -1
	d.s = 0.0
	d.group = -1
	d.cat = -1
	d.piece = -1
	d.flag_k = 0.0
	d.knocks = 2
	d.canopy = -1
	d.seed = _rng.randf() * TAU
	d.blink_t = _rng.randf_range(0.5, 2.0)
	d.land_t = 0.0
	return i


static func hittable(d: Dictionary) -> bool:
	return d.on and not (d.phase in ["tumble", "dizzy", ""])


static func airborne(d: Dictionary) -> bool:
	return d.phase in ["fling", "top_hop", "para", "cup"] or (d.phase == "hop" and d.next == "perch")


static func climbing(d: Dictionary) -> bool:
	return d.phase in ["climb", "brace", "perch", "hop", "wait"] or (d.phase == "walk" and d.ladder >= 0)


func _arc(d: Dictionary, to: Vector3, dur: float, arc_h: float, next: String) -> void:
	d.from = d.c
	d.to = to
	d.dur = dur
	d.arc = arc_h
	d.next = next
	d.phase = "hop" if next != "top" else "top_hop"
	d.t = 0.0


## A spot on the wall near p for one who is about to get up there (the oldest dancer hops
## down inside if all are taken).
func reserve_spot(i: int, near: Vector3) -> int:
	var best := -1
	var bd := INF
	var fs := faces()
	for k in spots.size():
		if spots[k] >= 0 or not (spot_face(k) in fs):
			continue
		var dd := spot_pos(k).distance_to(near)
		if dd < bd:
			bd = dd
			best = k
	if best < 0:
		var old := -1
		var ot := INF
		for k in spots.size():
			var o: int = spots[k]
			if o >= 0 and spot_face(k) in fs and dudes[o].phase == "dance" and float(dudes[o].planted_at) < ot:
				ot = dudes[o].planted_at
				old = k
		if old < 0:
			# All taken by ones on their way up: share one (they squeeze in).
			var vis: Array = []
			for k in spots.size():
				if spot_face(k) in fs:
					vis.append(k)
			best = vis[_rng.randi() % vis.size()]
			spots[best] = i
			dudes[i].spot = best
			return best
		var od: Dictionary = dudes[spots[old]]
		_burst(od.c, Color(od.color), 8, 0.5)
		_sfx("swish", 0.4, od.c)
		od.on = false
		spots[old] = -1
		best = old
	spots[best] = i
	dudes[i].spot = best
	return best


func _release_spot(i: int) -> void:
	var k: int = dudes[i].spot
	if k >= 0 and k < spots.size() and spots[k] == i:
		spots[k] = -1
	dudes[i].spot = -1


## Up and over: a hop from where he is onto his spot on the wall.
func go_top(i: int, fling := false) -> void:
	var d: Dictionary = dudes[i]
	var k := reserve_spot(i, d.c)
	var to: Vector3 = spot_pos(k) if k >= 0 else Vector3(d.c.x, H + R, d.c.z)
	if fling:
		_fling(d, to, 0.95)
	else:
		_arc(d, to, 0.45, 0.8, "top")
	_sfx("swish", 0.35, d.c)


func _fling(d: Dictionary, to: Vector3, dur: float) -> void:
	d.from = d.c
	d.to = to
	d.dur = dur
	d.v = (to - d.c - 0.5 * Vector3.DOWN * GRAV * dur * dur) / dur
	d.phase = "fling"
	d.t = 0.0
	d.ax = Vector3.UP.cross(Vector3(d.v.x, 0, d.v.z)).normalized() if Vector2(d.v.x, d.v.z).length() > 0.01 else Vector3.RIGHT
	d.ang = 0.0


func _land_top(i: int) -> void:
	var d: Dictionary = dudes[i]
	if d.spot < 0:
		reserve_spot(i, d.c)
	if d.spot >= 0:
		d.c = spot_pos(d.spot)
	d.phase = "plant"
	d.t = 0.0
	d.flag_k = 0.0
	d.ang = 0.0
	d.planted_at = time
	d.group = -1
	d.ladder = -1
	F.planted += 1
	_break_combo()
	if ctx:
		ctx.nibble.call("castle", FLAG_PENALTY, to_game((d.c as Vector3) + Vector3.UP * R * 2.0))
	_sfx("thump", 0.4, d.c)
	_sfx("squeak", 1.45, d.c)
	_dust(d.c - Vector3.UP * R, 6)
	if time - _flag_said > 0.8:
		_flag_said = time
		_label(d.c + Vector3.UP * R * 1.4, _tx("رفع علمه!", "FLAG UP!"), Color("ffae5c"), 0.9)


## Knock Dahrooj i off (a shot, a ball, a domino) toward dir. Returns whether he went.
func knock(i: int, dir: Vector3, why := "") -> bool:
	var d: Dictionary = dudes[i]
	if not hittable(d):
		return false
	var c: Vector3 = d.c
	var air := airborne(d)
	var dancer: bool = d.phase in ["plant", "dance"]
	var dh := Vector3(dir.x, 0, dir.z)
	dh = dh.normalized() if dh.length_squared() > 1e-4 else Vector3.FORWARD
	var out := Vector3(c.x, 0, c.z)
	out = out.normalized() if out.length_squared() > 1e-4 else Vector3.BACK
	if dancer and d.spot >= 0:
		out = face_n(spot_face(d.spot))
	var v := out * _rng.randf_range(1.4, 2.2) + dh * 1.3 + Vector3.UP * _rng.randf_range(3.2, 4.6)
	if d.phase == "para":
		v = dh * 1.5 + Vector3.UP * 1.5
		_pop_canopy(i)
	elif d.phase == "fling":
		v = d.v * 0.3 + dh * 2.5 + Vector3.UP * 2.0
	# What he leaves behind.
	var chain: Array = []
	if d.group >= 0 and groups.has(d.group):
		var g: Dictionary = groups[d.group]
		var st: Array = g.stack
		var k := st.find(i)
		if k >= 0:
			for j in range(k + 1, st.size()):
				chain.append(st[j])
			st.resize(k)
		if d.phase == "walk":
			g.incoming = maxi(0, int(g.incoming) - 1)
	if d.ladder >= 0 and d.phase in ["walk", "raise"]:
		var l: Dictionary = ladders[d.ladder]
		if l.on and l.owner == i and l.state in ["carried", "raising"]:
			_drop_ladder(d.ladder, dh)
	if dancer:
		_flag_down(d)
	_detach(i)
	_tumble(d, v, 0.0)
	F.knocked += 1
	F.throw_hits += 1
	var base: int = PTS.air if air else PTS.climber
	var extra := ""
	if air:
		extra = _tx("طاير!", "AIR!")
	if dancer:
		base = PTS.flag
		extra = _tx("طاح العلم!", "FLAG DOWN!")
	var quiet := false
	if why == "domino":
		extra = _tx("دومينو!", "DOMINO!")
		quiet = time - _domino_said < 0.5
		if not quiet:
			_domino_said = time
	award(base, c, true, extra, quiet)
	_burst(c, Color(d.color), 14, 1.0)
	_sfx("start_pop", 1.0, c)
	_sfx("squeak", 1.2 if not dancer else 0.9, c)
	_buzz2(0.35, 35)
	if ctx:
		ctx.ch_progress.call("castle25", int(ctx.ch_state.get("castle25", 0)) + 1)
	if not chain.is_empty():
		_topple(chain, dh, out, c)
	return true


## The ones above a knocked tower member topple with him, one after the other, the higher
## the farther: a chain with a bonus.
func _topple(chain: Array, dh: Vector3, out: Vector3, at: Vector3) -> void:
	var lean := (dh + out).normalized()
	var top := at
	for j in chain.size():
		var m: Dictionary = dudes[chain[j]]
		if not m.on:
			continue
		top = m.c
		_detach(chain[j])
		var v := lean * (1.2 + j * 0.7) + Vector3.UP * (1.4 + j * 0.4) + Vector3(_rng.randf_range(-0.5, 0.5), 0, _rng.randf_range(-0.5, 0.5))
		_tumble(m, v, 0.07 * (j + 1))
		F.knocked += 1
		award(PTS.climber, m.c, true, "", true)
	_chain_bonus(chain.size() + 1, top, _tx("انهيار", "TOPPLE"))


func _chain_bonus(n: int, at: Vector3, word: String) -> void:
	if n < 2:
		return
	F.best_chain = maxi(F.best_chain, n)
	var bonus := 5 * n * n
	var pts := award(bonus, at + Vector3.UP * 0.6, false, "", true)
	_sfx("boom", 0.35 + 0.05 * n, at)
	_sfx("firework_burst", 0.6, at)
	_buzz2(0.6 + 0.05 * n, 90)
	_confetti(at, 0.8 + 0.1 * n)
	_banner("%s ×%s!" % [word, _num(n)], "+" + _num(pts), Color("ffd23f"), 1.5)
	if ctx:
		ctx.ch_progress.call("castleTopple", maxi(int(ctx.ch_state.get("castleTopple", 0)), n))


## Loose him from whatever holds him: a spot, a ladder, a tower, a catapult, the siege tower.
func _detach(i: int) -> void:
	var d: Dictionary = dudes[i]
	_release_spot(i)
	if d.group >= 0 and groups.has(d.group):
		var st: Array = groups[d.group].stack
		var k := st.find(i)
		if k >= 0:
			st.remove_at(k)
	d.group = -1
	d.ladder = -1
	if d.cat >= 0:
		var c: Dictionary = cats[d.cat]
		(c.ammo as Array).erase(i)
		if c.cup == i:
			c.cup = -1
		d.cat = -1
	if d.piece >= 0:
		d.piece = -1
	if d.canopy >= 0:
		_pop_canopy(i)


func _tumble(d: Dictionary, v: Vector3, delay: float) -> void:
	d.phase = "tumble"
	d.t = 0.0
	d.v = v
	d.delay = delay
	d.bounces = 0
	var h := Vector3(v.x, 0, v.z)
	d.ax = Vector3.UP.cross(h).normalized() if h.length_squared() > 1e-4 else Vector3.RIGHT
	d.w = _rng.randf_range(7.0, 13.0)
	d.knocks = 2


func _flag_down(d: Dictionary) -> void:
	if d.spot < 0 and d.flag_k <= 0.0:
		return
	var fp := _flag_pos(d)
	_plank(fp + Vector3.UP * 0.65, face_n(spot_face(maxi(0, int(d.spot)))) * 2.5 + Vector3.UP * 3.0, Vector3(0.07, 1.3, 0.07), Color("8a5a36"))
	_burst(fp + Vector3.UP * 1.1, Color(d.color), 12, 0.7)
	_sfx("swish", 0.6, fp)
	d.flag_k = 0.0


func _flag_pos(d: Dictionary) -> Vector3:
	var k: int = d.spot
	if k < 0:
		return (d.c as Vector3) - Vector3.UP * R
	var f := spot_face(k)
	if int(SPOTS[k % SPOT_N][1]) == 1:
		return spot_pos(k) - Vector3.UP * R + face_t(f) * 0.2 - face_n(f) * 0.16
	return spot_pos(k) - Vector3.UP * R + face_t(f) * 0.42 - face_n(f) * 0.12


func _pop_canopy(i: int) -> void:
	var d: Dictionary = dudes[i]
	var k: int = d.canopy
	if k < 0:
		return
	var at: Vector3 = (d.c as Vector3) + Vector3.UP * 1.6
	_burst(at, Color(d.color), 18, 0.9)
	_sfx("start_pop", 0.8, at)
	canopies[k].owner = -1
	(canopies[k].proxy as MeshInstance3D).visible = false
	d.canopy = -1


# ---- spawning ----

## A ladder carrier for face f, lane u (random when not given). Returns the Dahrooj's slot.
func spawn_ladder(f := -1, u := INF) -> int:
	if f < 0:
		f = _pick_face()
	if u == INF:
		u = _pick_lane(f)
	var li := -1
	for k in ladders.size():
		if not ladders[k].on:
			li = k
			break
	if li < 0:
		# Reuse the oldest one standing: it falls.
		for k in ladders.size():
			if ladders[k].state == "up":
				_drop_ladder(k, Vector3.ZERO)
				ladders[k].on = false
				li = k
				break
	if li < 0:
		return -1
	var from := _spawn_point(f)
	var i := _new_dude("ladder", from)
	if i < 0:
		return -1
	var d: Dictionary = dudes[i]
	var n := face_n(f)
	var t := face_t(f)
	var base := n * (W + LAD_OUT) + t * u
	d.face = f
	d.u = u
	d.ladder = li
	d.path = path_to(from, base + n * 0.55, f)
	var l: Dictionary = ladders[li]
	l.on = true
	l.state = "carried"
	l.face = f
	l.u = u
	l.base = base
	l.owner = i
	l.t = 0.0
	l.fade = 1.0
	_step_ladder(l, 0.0)
	return i


## A follower: climbs a ladder that is up (or brings his own when there's none).
func spawn_follower() -> int:
	var li := _pick_ladder()
	if li < 0:
		return spawn_ladder()
	var l: Dictionary = ladders[li]
	var from := _spawn_point(l.face)
	var i := _new_dude("follow", from)
	if i < 0:
		return -1
	var d: Dictionary = dudes[i]
	d.face = l.face
	d.u = l.u
	d.ladder = li
	d.path = path_to(from, (l.base as Vector3) + face_n(l.face) * 0.6, l.face)
	return i


func _pick_ladder() -> int:
	var best := -1
	var fs := faces()
	var n := 0
	for k in ladders.size():
		var l: Dictionary = ladders[k]
		if l.on and l.state in ["up", "raising", "carried"] and l.face in fs:
			n += 1
			if _rng.randi() % n == 0:
				best = k
	return best


## A gang of n that build a living tower on face f, lane u. Returns the group id.
func spawn_stack(n: int, f := -1, u := INF) -> int:
	if f < 0:
		f = _pick_face()
	if u == INF:
		u = _pick_lane(f)
	var gid := _next_group
	_next_group += 1
	var nn := face_n(f)
	var base := nn * (W + R + 0.06) + face_t(f) * u
	groups[gid] = {"face": f, "u": u, "base": base, "stack": [], "incoming": 0, "boing_t": 0.0}
	var from := _spawn_point(f)
	var path := path_to(from, base, f)
	var first: Vector3 = path[0]
	var back := (from - first)
	back.y = 0.0
	back = back.normalized() if back.length_squared() > 1e-4 else Vector3.ZERO
	for k in n:
		var i := _new_dude("stack", from + back * k * 0.95)
		if i < 0:
			break
		var d: Dictionary = dudes[i]
		d.group = gid
		d.face = f
		d.u = u
		d.path = path.duplicate()
		d.spd = wave_speed(maxi(1, F.wave))
		groups[gid].incoming += 1
	return gid


## A parachuter drifting down onto a spot on the walls.
func spawn_para() -> int:
	var i := _new_dude("para", Vector3.ZERO)
	if i < 0:
		return -1
	var k := -1
	for q in canopies.size():
		if canopies[q].owner < 0:
			k = q
			break
	var d: Dictionary = dudes[i]
	var pf := _pick_face()
	var sp := reserve_spot(i, face_n(pf) * (W + 4.0) + face_t(pf) * _rng.randf_range(-3.0, 3.0) + Vector3.UP * H)
	if sp < 0 or k < 0:
		_release_spot(i)
		d.on = false
		return -1
	var to := spot_pos(sp)
	var from := to + Vector3(_rng.randf_range(-3.0, 3.0), 0, _rng.randf_range(-1.0, 3.0))
	from.y = _para_top()
	d.c = from
	d.from = from
	d.to = to
	d.phase = "para"
	d.t = 0.0
	d.dur = (from.y - to.y) / (PARA_V * float(d.spd))
	d.canopy = k
	canopies[k].owner = i
	_sfx("whoosh", 0.4, from)
	return i


## A catapult with its crew of n, aiming at face f. Returns its index or -1.
func spawn_catapult(n: int, f := -1) -> int:
	var ci := -1
	for k in cats.size():
		if not cats[k].on:
			ci = k
			break
	if ci < 0:
		return -1
	if f < 0:
		f = _pick_face()
	var c: Dictionary = cats[ci]
	var nn := face_n(f)
	var t := face_t(f)
	var to := nn * (W + 3.4) + t * _rng.randf_range(-1.2, 1.2)
	var from := _front(to + nn * 7.0 + t * _away(f) * 6.0)
	c.on = true
	c.phase = "roll"
	c.p = from
	c.from = from
	c.to = to
	c.face = f
	var aim := Vector3(-to.x, 0, -to.z).normalized()
	c.b = Basis.looking_at(aim, Vector3.UP)
	c.ammo = []
	c.cup = -1
	c.t = 0.0
	c.arm = ARM_COCK
	c.hp = 3
	c.flash = 0.0
	c.cd = 0.6
	for k in n:
		var i := _new_dude("cat", from)
		if i < 0:
			break
		dudes[i].phase = "ride"
		dudes[i].cat = ci
		(c.ammo as Array).append(i)
	_sfx("thump", 0.3, from)
	_step_cat_crew(c, 0.0)
	return ci


## The siege tower: rolls in along the wall you see best, a rider on every floor and two on
## the deck.
func spawn_siege() -> bool:
	if siege.on:
		return false
	var f := front_face()
	var n := face_n(f)
	var t := face_t(f)
	var sgn := _away(f)
	var lane := sgn * 1.1
	siege.on = true
	siege.phase = "enter"
	siege.face = f
	siege.b = Basis.looking_at(-n, Vector3.UP)
	siege.to = n * (W + SIEGE_HALF + 0.12) + t * lane
	siege.from = _front((siege.to as Vector3) + t * sgn * 15.0)
	siege.p = siege.from
	siege.t = 0.0
	siege.ramp = 0.0
	siege.cd = 0.0
	siege.idle = 0.0
	siege.pieces = []
	for k in SIEGE_H.size():
		siege.pieces.append({"alive": true, "hp": SIEGE_HP[k], "y": 0.0, "vy": 0.0, "flash": 0.0})
	_settle_pieces(true)
	var offs := [[1, Vector3(-0.35, 0, 0.3)], [1, Vector3(0.35, 0, 0.3)], [2, Vector3(0.1, 0, 0.3)], [DECK, Vector3(-0.4, 0, 0.2)], [DECK, Vector3(0.4, 0, 0.2)]]
	for o in offs:
		var i := _new_dude("siege", siege.p)
		if i < 0:
			break
		var d: Dictionary = dudes[i]
		d.phase = "ride"
		d.piece = o[0]
		d.off = o[1]
		_ride_pos(d)
	F.sieges += 1
	_sfx("boom", 0.4, siege.p)
	_buzz2(0.4, 100)
	return true


# ---- ladders ----

func _ladder_top(l: Dictionary) -> Vector3:
	var f: int = l.face
	return face_n(f) * W + face_t(f) * float(l.u) + Vector3.UP * (H + 0.3)


func _step_ladder(l: Dictionary, dt: float) -> void:
	var f: int = l.face
	var n := face_n(f)
	var t := face_t(f)
	var L := ladder_len()
	l.t += dt
	l.ball_t = maxf(0.0, l.ball_t - dt)
	match l.state:
		"carried":
			var o: Dictionary = dudes[l.owner] if l.owner >= 0 else {}
			if o.is_empty() or not o.on:
				return
			var wd: Vector3 = o.dir
			wd = Vector3(wd.x, 0, wd.z).normalized() if Vector2(wd.x, wd.z).length() > 0.01 else -n
			l.dir = wd
			l.across = Vector3.UP.cross(wd).normalized()
			l.base = (o.c as Vector3) + Vector3.UP * (R + 0.1) - wd * L * 0.5
		"raising":
			var k := clampf(l.t / 0.7, 0.0, 1.0)
			var e := k * k * (3.0 - 2.0 * k)
			var foot := n * (W + LAD_OUT) + t * float(l.u)
			var top := _ladder_top(l)
			var d0 := (-n + Vector3.UP * 0.25).normalized()
			l.base = foot
			l.dir = d0.slerp((top - foot).normalized(), e).normalized()
			l.across = t
			if k >= 1.0:
				l.state = "up"
				l.t = 0.0
				_sfx("thump", 0.5, top)
				_dust(top, 5)
		"up":
			var foot := n * (W + LAD_OUT) + t * float(l.u)
			l.base = foot
			l.dir = (_ladder_top(l) - foot).normalized()
			l.across = t
		"falling":
			# It swings away from the wall about its foot and slaps the ground.
			l.w = float(l.w) + 6.5 * dt
			l.ang = float(l.ang) + float(l.w) * dt
			var a := atan2(LAD_OUT, H + 0.3) - float(l.ang)
			if a <= -PI / 2.0 + 0.05:
				a = -PI / 2.0 + 0.05
				l.state = "down"
				l.t = 0.0
				_sfx("thump", 0.7, l.base)
				_dust((l.base as Vector3) + n * L * 0.5, 10)
			l.dir = (Vector3.UP * cos(a) - n * sin(a)).normalized()
		"dropped":
			# Dropped while carried: falls flat from the carrier's head.
			l.base = (l.base as Vector3) + Vector3.DOWN * minf(dt * 6.0, maxf(0.0, (l.base as Vector3).y - 0.05))
			if l.t > 0.3:
				l.state = "down"
				l.t = 0.0
		"down":
			l.fade = clampf(1.0 - (l.t - 1.2) / 0.5, 0.0, 1.0)
			if l.t > 1.7:
				l.on = false


## The point s (0 .. 1) up ladder l where a climber's centre is.
func ladder_point(l: Dictionary, s: float) -> Vector3:
	var n := face_n(l.face)
	return (l.base as Vector3) + (l.dir as Vector3) * ladder_len() * s + n * R * 0.85 + Vector3.UP * R * 0.25


## Knock ladder k over (everyone on it tumbles off: a chain).
func knock_ladder(k: int, dir: Vector3) -> bool:
	var l: Dictionary = ladders[k]
	if not l.on or not l.state in ["up", "raising"]:
		return false
	var riders: Array = []
	for i in dudes.size():
		var d: Dictionary = dudes[i]
		if d.on and d.ladder == k and d.phase == "climb":
			riders.append(i)
	l.state = "falling"
	l.t = 0.0
	l.ang = 0.0
	l.w = 0.8
	var top := _ladder_top(l)
	_sfx("swish", 0.8, top)
	_sfx("squeak", 0.8, top)
	award(PTS.ladder, top - Vector3.UP * 1.0, false)
	var n := face_n(l.face)
	var dh := Vector3(dir.x, 0, dir.z).normalized() if Vector2(dir.x, dir.z).length() > 0.01 else Vector3.ZERO
	for j in riders.size():
		var d: Dictionary = dudes[riders[j]]
		_detach(riders[j])
		var hgt: float = d.c.y
		_tumble(d, n * (1.5 + hgt * 0.9) + dh + Vector3.UP * (2.0 + _rng.randf() * 1.5), 0.05 * j)
		F.knocked += 1
		award(PTS.climber, d.c, true, "", j > 0)
	if riders.size() >= 2:
		_chain_bonus(riders.size(), top, _tx("سلّم", "LADDER"))
	_buzz2(0.45, 60)
	# Followers waiting at its foot look for another one.
	for i in dudes.size():
		var d: Dictionary = dudes[i]
		if d.on and d.ladder == k and d.phase in ["walk", "queue"]:
			d.ladder = -1
	return true


func _drop_ladder(k: int, _dir: Vector3) -> void:
	var l: Dictionary = ladders[k]
	if l.state in ["up", "raising"]:
		l.state = "falling"
		l.ang = 0.0
		l.w = 0.8
	else:
		l.state = "dropped"
	l.t = 0.0
	l.owner = -1
	_sfx("thump", 0.5, l.base)


# ---- the Dahroojs, step by step ----

func _stack_pos(g: Dictionary, level: int) -> Vector3:
	var lean := sin(time * 1.7 + float(g.u)) * 0.025 * level
	return (g.base as Vector3) + Vector3.UP * (R + level * STACK_STEP) + face_t(g.face) * lean


func _arrive(i: int) -> void:
	var d: Dictionary = dudes[i]
	match d.kind:
		"ladder":
			var l: Dictionary = ladders[d.ladder] if d.ladder >= 0 else {}
			if l.is_empty() or not l.on or l.owner != i:
				_stranded(i)
				return
			l.state = "raising"
			l.t = 0.0
			d.phase = "raise"
			d.t = 0.0
			_sfx("swish", 0.4, d.c)
		"follow":
			d.phase = "queue"
			d.t = 0.0
		"stack":
			d.phase = "wait"
			d.t = 0.0
			if groups.has(d.group):
				groups[d.group].incoming = maxi(0, int(groups[d.group].incoming) - 1)
		_:
			_stranded(i)


## Nobody to help him up: a big springy "boing" straight onto the wall.
func _stranded(i: int) -> void:
	var d: Dictionary = dudes[i]
	d.phase = "boing"
	d.t = 0.0
	d.ladder = -1


func _step_dude(i: int, d: Dictionary, dt: float) -> void:
	d.t += dt
	d.land_t = maxf(0.0, d.land_t - dt)
	d.blink_t -= dt
	if d.blink_t <= 0.0:
		d.blink = 0.12
		d.blink_t = _rng.randf_range(1.2, 3.0)
	d.blink = maxf(0.0, d.blink - dt)
	var spd: float = d.spd
	match d.phase:
		"walk":
			if (d.path as Array).is_empty():
				_arrive(i)
				return
			var target: Vector3 = d.path[0]
			var c: Vector3 = d.c
			var flat := Vector3(target.x - c.x, 0, target.z - c.z)
			var step := WALK * spd * dt * (0.85 if d.ladder >= 0 and d.kind == "ladder" else 1.0)
			if flat.length() <= step:
				c.x = target.x
				c.z = target.z
				(d.path as Array).pop_front()
			else:
				d.dir = flat.normalized()
				c += flat.normalized() * step
			d.hop = float(d.hop) + dt * 9.0 * spd
			var b := absf(sin(float(d.hop)))
			c.y = R + b * R * 0.45
			d.c = c
			d.sq = Vector2(1.0 + 0.1 * (1.0 - b), 1.0 - 0.12 * (1.0 - b))
			if (d.path as Array).is_empty():
				_arrive(i)
		"raise":
			d.sq = Vector2(1.0 + 0.08 * sin(d.t * 20.0), 1.0 - 0.08 * sin(d.t * 20.0))
			var l: Dictionary = ladders[d.ladder] if d.ladder >= 0 else {}
			if l.is_empty() or not l.on:
				_stranded(i)
			elif l.state == "up":
				d.phase = "climb"
				d.s = 0.0
				d.t = 0.0
		"queue":
			var l: Dictionary = ladders[d.ladder] if d.ladder >= 0 else {}
			if l.is_empty() or not l.on or not l.state in ["up", "raising", "carried"]:
				var other := _pick_ladder()
				if other >= 0 and ladders[other].state == "up" and other != d.ladder:
					d.ladder = other
					d.face = ladders[other].face
					d.path = path_to(d.c, (ladders[other].base as Vector3) + face_n(ladders[other].face) * 0.6, ladders[other].face)
					d.phase = "walk"
				else:
					_stranded(i)
				return
			d.c = Vector3(d.c.x, R + absf(sin(d.t * 6.0)) * 0.08, d.c.z)
			if l.state == "up":
				var busy := false
				for o in dudes:
					if o.on and o.ladder == d.ladder and o.phase == "climb" and float(o.s) < 0.35:
						busy = true
				if not busy:
					d.phase = "climb"
					d.s = 0.0
					d.t = 0.0
		"climb":
			var l: Dictionary = ladders[d.ladder] if d.ladder >= 0 else {}
			if l.is_empty() or not l.on or l.state != "up":
				_tumble(d, face_n(d.face) * 2.0 + Vector3.UP * 2.0, 0.0)
				return
			d.s = float(d.s) + CLIMB * spd * dt / ladder_len()
			var rung := sin(float(d.s) * ladder_len() / 0.42 * PI)
			d.c = ladder_point(l, minf(1.0, d.s)) + face_t(d.face) * rung * 0.05
			d.sq = Vector2(1.0 - 0.06 * rung, 1.0 + 0.08 * rung)
			if d.s >= 1.0:
				go_top(i)
		"hop", "top_hop":
			var k := clampf(d.t / d.dur, 0.0, 1.0)
			d.c = (d.from as Vector3).lerp(d.to, k) + Vector3.UP * float(d.arc) * 4.0 * k * (1.0 - k)
			d.sq = Vector2(1.0 - 0.12 * sin(PI * k), 1.0 + 0.2 * sin(PI * k))
			if k >= 1.0:
				d.land_t = 0.2
				if d.phase == "top_hop":
					_land_top(i)
				else:
					d.phase = d.next
					d.t = 0.0
					_sfx("thump", 0.25, d.c)
		"wait":
			_step_wait(i, d)
		"brace":
			pass
		"perch":
			if d.t >= 0.3:
				var g: Dictionary = groups.get(d.group, {})
				if not g.is_empty():
					(g.stack as Array).erase(i)
				d.group = -1
				go_top(i)
		"boing":
			d.sq = Vector2(1.0 + 0.3 * minf(1.0, d.t / 0.35), 1.0 - 0.35 * minf(1.0, d.t / 0.35))
			if d.t >= 0.35:
				d.sq = Vector2(0.8, 1.3)
				_sfx("squeak", 1.6, d.c)
				var k := reserve_spot(i, d.c)
				_fling(d, spot_pos(k) if k >= 0 else Vector3(d.c.x * 0.7, H + R, d.c.z * 0.7), 0.9)
		"fling":
			var t: float = minf(d.t, d.dur)
			d.c = (d.from as Vector3) + (d.v as Vector3) * t + 0.5 * Vector3.DOWN * GRAV * t * t
			d.ang = float(d.ang) + dt * 9.0
			if d.t >= d.dur:
				d.c = d.to
				_land_top(i)
		"para":
			var k := clampf(d.t / d.dur, 0.0, 1.0)
			var ek := 1.0 - pow(1.0 - k, 1.4)
			var sway := sin(d.t * 2.2 + float(d.seed)) * 0.6 * (1.0 - k)
			d.c = (d.from as Vector3).lerp(d.to, ek) + face_t(spot_face(maxi(0, int(d.spot)))) * sway
			d.c.y = lerpf(float(d.from.y), float(d.to.y), k)
			d.ang = sin(d.t * 2.2 + float(d.seed)) * 0.25 * (1.0 - k)
			if k >= 1.0:
				_pop_canopy_soft(i)
				_land_top(i)
		"ride", "cup":
			pass
		"plant":
			d.flag_k = minf(1.0, d.t / 0.55)
			d.sq = Vector2(1.0 + 0.15 * sin(d.t * 18.0) * (1.0 - d.flag_k), 1.0 - 0.18 * sin(d.t * 18.0) * (1.0 - d.flag_k))
			if d.t >= 0.55:
				d.phase = "dance"
				d.t = 0.0
		"dance":
			var b := absf(sin(d.t * 7.0 + float(d.seed)))
			d.c = spot_pos(d.spot) + Vector3.UP * b * 0.3 if d.spot >= 0 else d.c
			d.sq = Vector2(1.0 + 0.12 * (1.0 - b), 1.0 - 0.15 * (1.0 - b))
		"tumble":
			_step_tumble(i, d, dt)
		"dizzy":
			var fy := floor_y(d.c)
			d.c = Vector3(d.c.x, fy + R * 0.72, d.c.z)
			d.sq = Vector2(1.22, 0.72)
			if d.t >= 1.0:
				_burst(d.c, Color(d.color), 10, 0.6)
				_sfx("start_pop", 0.6, d.c)
				d.on = false
				d.phase = ""


func _pop_canopy_soft(i: int) -> void:
	var d: Dictionary = dudes[i]
	var k: int = d.canopy
	if k < 0:
		return
	canopies[k].owner = -1
	(canopies[k].proxy as MeshInstance3D).visible = false
	d.canopy = -1
	_burst((d.c as Vector3) + Vector3.UP * 1.4, Color(d.color), 6, 0.4)


## A tower member waiting at the foot: hop on when it's his turn.
func _step_wait(i: int, d: Dictionary) -> void:
	var g: Dictionary = groups.get(d.group, {})
	if g.is_empty():
		_stranded(i)
		return
	var st: Array = g.stack
	# One at a time: the next in line goes when the top is settled.
	for m in st:
		if dudes[m].phase == "hop":
			return
	if st.size() > TOWER_N:
		return
	var level := st.size()
	st.append(i)
	var to := _stack_pos(g, level)
	if level == 0:
		d.c = to
		d.phase = "brace"
		d.t = 0.0
		return
	_arc(d, to, 0.4 + 0.04 * level, 0.7, "perch" if level >= TOWER_N else "brace")
	_sfx("swish", 0.3, d.c)
	_sfx("squeak", 1.3, d.c)


func _step_group(gid: int, g: Dictionary, dt: float) -> void:
	var st: Array = g.stack
	var level := 0
	for m in st:
		var d: Dictionary = dudes[m]
		if d.phase == "brace":
			d.c = _stack_pos(g, level)
			var ld := st.size() - 1 - level
			var wob := sin(time * 9.0 + level) * 0.03
			d.sq = Vector2(1.0 + 0.05 * ld + wob, 1.0 - 0.07 * ld - wob)
		elif d.phase == "perch":
			d.c = _stack_pos(g, level)
		level += 1
	# Nobody else coming: the tower springs up onto the wall, top first ("boing").
	var waiting := 0
	for i in dudes.size():
		if dudes[i].on and dudes[i].group == gid and dudes[i].phase in ["walk", "wait", "hop"]:
			waiting += 1
	if waiting == 0 and int(g.incoming) == 0 and not st.is_empty():
		g.boing_t = float(g.boing_t) + dt
		if g.boing_t > 0.9:
			g.boing_t = 0.0
			var top: int = st.pop_back()
			dudes[top].group = -1
			_stranded(top)
	if st.is_empty() and waiting == 0 and int(g.incoming) == 0:
		groups.erase(gid)


func _step_tumble(i: int, d: Dictionary, dt: float) -> void:
	if d.delay > 0.0:
		d.delay = float(d.delay) - dt
		d.sq = Vector2(1.0 + 0.1 * sin(time * 30.0), 1.0 - 0.1 * sin(time * 30.0))
		return
	var v: Vector3 = d.v
	v.y -= GRAV * dt
	var c: Vector3 = (d.c as Vector3) + v * dt
	d.ang = float(d.ang) + float(d.w) * dt
	# The walls: inside the footprint below the roof he is pushed back out.
	if absf(c.x) < W + R * 0.6 and absf(c.z) < W + R * 0.6 and c.y < H - 0.1:
		if absf(c.x) - W > absf(c.z) - W:
			c.x = signf(c.x) * (W + R * 0.6)
			v.x = absf(v.x) * 0.4 * signf(c.x)
		else:
			c.z = signf(c.z) * (W + R * 0.6)
			v.z = absf(v.z) * 0.4 * signf(c.z)
	var fy := floor_y(c)
	if c.y < fy + R:
		c.y = fy + R
		if v.y < -1.6:
			v.y = -v.y * 0.42
			v.x *= 0.55
			v.z *= 0.55
			d.bounces += 1
			d.w = float(d.w) * 0.7
			d.land_t = 0.18
			if d.bounces <= 2:
				_sfx("thump", 0.3 / d.bounces, c)
				_dust(c - Vector3.UP * R, 4)
		else:
			v.y = 0.0
			v.x *= 0.7
			v.z *= 0.7
		if Vector2(v.x, v.z).length() < 1.0 and absf(v.y) < 2.2 or d.bounces >= 3:
			d.phase = "dizzy"
			d.t = 0.0
			d.ang = 0.0
			c.y = fy + R * 0.72
	d.v = v
	d.c = c
	d.sq = Vector2(1.25, 0.7) if d.land_t > 0.0 else Vector2.ONE
	if d.t > 5.0 or c.length() > 60.0:
		d.on = false
		d.phase = ""
		return
	# A fast one knocks the next one over (domino).
	if d.knocks > 0 and v.length() > 2.2:
		for j in dudes.size():
			if j == i:
				continue
			var o: Dictionary = dudes[j]
			if not hittable(o) or o.phase in ["plant", "dance"] and c.y < H:
				continue
			if (o.c as Vector3).distance_to(c) < R * 1.9:
				d.knocks -= 1
				knock(j, v, "domino")
				break


# ---- catapults ----

func _cup_pos(c: Dictionary) -> Vector3:
	var b: Basis = c.b
	var arm := Basis(Vector3.RIGHT, float(c.arm))
	var tip := ARM_PIVOT + arm * Vector3(0, ARM_L + 0.12, 0)
	return (c.p as Vector3) + b * (tip + arm * Vector3(0, R * 0.75, 0))


## The crew walks behind (pushing), one after the other.
func _step_cat_crew(c: Dictionary, _dt: float) -> void:
	var b: Basis = c.b
	var j := 0
	for i in c.ammo:
		var d: Dictionary = dudes[i]
		if d.phase != "ride":
			continue
		var bob := absf(sin(time * 8.0 + j * 1.3))
		d.c = (c.p as Vector3) + b * Vector3((j % 2) * 0.3 - 0.15, R + bob * 0.12, 1.45 + j * 0.85)
		d.dir = -(b.z)
		d.sq = Vector2(1.0 + 0.08 * (1.0 - bob), 1.0 - 0.1 * (1.0 - bob))
		j += 1
	if c.cup >= 0:
		var d: Dictionary = dudes[c.cup]
		if d.phase == "cup":
			d.c = _cup_pos(c)


func _step_cat(ci: int, c: Dictionary, dt: float) -> void:
	c.t += dt
	c.flash = maxf(0.0, c.flash - dt)
	c.ball_t = maxf(0.0, c.ball_t - dt)
	var spd := wave_speed(maxi(1, F.wave))
	match c.phase:
		"roll", "leave":
			var to: Vector3 = c.to if c.phase == "roll" else c.from
			var dd := to - (c.p as Vector3)
			var step := CAT_V * dt * (1.4 if c.phase == "leave" else 1.0)
			c.roll = float(c.roll) + step
			if dd.length() <= step:
				c.p = to
				if c.phase == "roll":
					c.phase = "ready"
					c.cd = 0.5
					_sfx("thump", 0.4, c.p)
				else:
					for i in c.ammo:
						dudes[i].on = false
					c.ammo = []
					c.on = false
					return
			else:
				c.p = (c.p as Vector3) + dd.normalized() * step
		"ready":
			c.cd = float(c.cd) - dt
			if (c.ammo as Array).is_empty() and c.cup < 0:
				c.phase = "leave"
				c.t = 0.0
			elif c.cd <= 0.0 and c.cup < 0:
				var i: int = c.ammo.pop_front()
				c.cup = i
				var d: Dictionary = dudes[i]
				_arc(d, _cup_pos(c), 0.4, 0.8, "cup")
				d.cat = ci
				c.phase = "load"
		"load":
			if c.cup < 0:
				c.phase = "ready"
				c.cd = 0.6
			elif dudes[c.cup].phase == "cup":
				c.phase = "fire"
				c.t = 0.0
				_sfx("squeak", 0.6, c.p)
		"fire":
			var k := clampf(c.t / 0.2, 0.0, 1.0)
			c.arm = lerpf(ARM_COCK, ARM_FIRE, k * k)
			if k >= 1.0:
				if c.cup >= 0:
					var i: int = c.cup
					c.cup = -1
					var d: Dictionary = dudes[i]
					d.cat = -1
					var sp := reserve_spot(i, (c.p as Vector3) * 0.5)
					_fling(d, spot_pos(sp) if sp >= 0 else Vector3(0, H + R, 0), 1.15)
					_sfx("whoosh", 0.8, d.c)
					_sfx("squeak", 1.5, d.c)
				_sfx("thump", 0.6, c.p)
				c.phase = "reset"
				c.t = 0.0
		"reset":
			var k := clampf(c.t / 0.9, 0.0, 1.0)
			c.arm = lerpf(ARM_FIRE, ARM_COCK, k * k * (3.0 - 2.0 * k))
			if k >= 1.0:
				c.phase = "ready"
				c.cd = 1.1 / spd
	_step_cat_crew(c, dt)


## A hit on catapult ci (n points of damage). Three and it breaks with its crew.
func damage_cat(ci: int, n: int, at: Vector3) -> bool:
	var c: Dictionary = cats[ci]
	if not c.on or c.phase == "broken":
		return false
	c.hp = int(c.hp) - n
	c.flash = 0.12
	_sfx("thump", 0.6, at)
	_splinter((c.p as Vector3) + Vector3.UP * 0.6, Vector3(0.4, 0.3, 0.6), 2, 0.6)
	if c.hp > 0:
		award(PTS.tick, (c.p as Vector3) + Vector3.UP * 1.4, false)
		return true
	var p: Vector3 = c.p
	_splinter(p + Vector3.UP * 0.7, Vector3(0.5, 0.5, 0.9), 12, 1.2)
	_sfx("boom", 0.7, p)
	_buzz2(0.8, 120)
	award(PTS.cat, p + Vector3.UP * 1.6, false, _tx("المنجنيق!", "CATAPULT!"))
	var crew: Array = (c.ammo as Array).duplicate()
	if c.cup >= 0:
		crew.append(c.cup)
	c.ammo = []
	c.cup = -1
	c.on = false
	var j := 0
	for i in crew:
		var d: Dictionary = dudes[i]
		if not hittable(d):
			continue
		d.cat = -1
		var out := ((d.c as Vector3) - p)
		out.y = 0.0
		out = out.normalized() if out.length_squared() > 1e-4 else Vector3.BACK
		_tumble(d, out * _rng.randf_range(2.0, 3.5) + Vector3.UP * _rng.randf_range(3.5, 5.5), 0.05 * j)
		F.knocked += 1
		award(PTS.climber, d.c, true, "", j > 0)
		j += 1
	_banner(_tx("تحطم المنجنيق!", "CATAPULT SMASHED!"), "", Color("ff9b3d"), 1.4)
	if crew.size() >= 2:
		_chain_bonus(crew.size(), p + Vector3.UP, _tx("طاقم", "CREW"))
	return true


# ---- the siege tower ----

func _piece_h(k: int) -> float:
	return SIEGE_H[k]


## Each living piece rests on the living ones under it (initial: snap them there).
func _settle_pieces(snap: bool) -> void:
	var y := 0.0
	var ps: Array = siege.pieces
	for k in ps.size():
		var pc: Dictionary = ps[k]
		if not pc.alive:
			continue
		if snap:
			pc.y = y
			pc.vy = 0.0
		pc.rest = y
		y += _piece_h(k)


func piece_floor(k: int) -> float:
	var pc: Dictionary = siege.pieces[k]
	return float(pc.y) + (0.68 if k == 0 else 0.12)


func _ride_pos(d: Dictionary) -> void:
	if d.piece < 0 or not siege.on:
		return
	var b: Basis = siege.b
	var bob := absf(sin(time * 5.0 + float(d.seed))) * 0.06
	d.c = (siege.p as Vector3) + b * ((d.off as Vector3) + Vector3.UP * (piece_floor(d.piece) + R + bob))
	d.dir = -(b.z)


func _top_piece() -> int:
	var ps: Array = siege.pieces
	for k in range(ps.size() - 1, -1, -1):
		if ps[k].alive:
			return k
	return -1


func _step_siege(dt: float) -> void:
	siege.t = float(siege.t) + dt
	siege.ball_t = maxf(0.0, float(siege.ball_t) - dt)
	var spd := wave_speed(maxi(1, F.wave))
	var ps: Array = siege.pieces
	for k in ps.size():
		var pc: Dictionary = ps[k]
		pc.flash = maxf(0.0, float(pc.flash) - dt)
		if not pc.alive:
			continue
		if float(pc.y) > float(pc.rest) + 1e-4:
			pc.vy = float(pc.vy) - GRAV * dt
			pc.y = float(pc.y) + float(pc.vy) * dt
			if pc.y <= pc.rest:
				pc.y = pc.rest
				if pc.vy < -2.0:
					_sfx("thump", 0.6, siege.p)
					_dust((siege.p as Vector3) + Vector3.UP * float(pc.y), 6)
				pc.vy = 0.0
	match siege.phase:
		"enter", "leave":
			var to: Vector3 = siege.to if siege.phase == "enter" else siege.from
			var dd := to - (siege.p as Vector3)
			var step := SIEGE_V * spd * dt * (1.6 if siege.phase == "leave" else 1.0)
			siege.roll = float(siege.roll) + step
			if dd.length() <= step:
				siege.p = to
				if siege.phase == "enter":
					siege.phase = "dock"
					siege.t = 0.0
					_sfx("thump", 0.8, siege.p)
					_buzz2(0.3, 80)
					if ctx:
						ctx.penalty.call("castle", SIEGE_PENALTY, to_game(siege.p))
				else:
					_siege_off()
					return
			else:
				siege.p = (siege.p as Vector3) + dd.normalized() * step
		"dock":
			siege.ramp = clampf(siege.t / 0.6, 0.0, 1.0)
			if siege.t >= 0.6:
				siege.phase = "unload"
				siege.t = 0.0
				siege.cd = 0.2
				if ps[DECK].alive:
					_sfx("thump", 0.7, siege.p)
					_dust(face_n(siege.face) * W + Vector3.UP * H, 8)
		"unload":
			siege.cd = float(siege.cd) - dt
			if siege.cd <= 0.0:
				siege.cd = 0.55 / spd
				if not _unload_one():
					siege.phase = "parked"
					siege.idle = 0.0
		"parked":
			siege.idle = float(siege.idle) + dt
			if siege.idle > 0.5 and _unload_one():
				siege.phase = "unload"
			elif siege.idle > 16.0:
				siege.phase = "leave"
				siege.ramp = 0.0
	if siege.phase in ["enter", "leave", "dock", "unload", "parked"]:
		for d in dudes:
			if d.on and d.kind == "siege" and d.phase == "ride":
				_ride_pos(d)


## The rider who can get highest goes up a floor, or over the ramp onto the wall.
func _unload_one() -> bool:
	var best := -1
	var bf := -INF
	for i in dudes.size():
		var d: Dictionary = dudes[i]
		if d.on and d.kind == "siege" and d.phase == "ride" and d.piece >= 0:
			var f := piece_floor(d.piece)
			if f > bf:
				bf = f
				best = i
	if best < 0:
		return false
	var r: Dictionary = dudes[best]
	if bf + 1.5 >= H:
		r.piece = -1
		go_top(best)
		return true
	# Up a floor, if there is a living one above.
	var ps: Array = siege.pieces
	for k in range(int(r.piece) + 1, ps.size()):
		if ps[k].alive:
			var from: Vector3 = r.c
			r.piece = k
			_ride_pos(r)
			var to: Vector3 = r.c
			r.c = from
			r.phase = "hop"
			r.from = from
			r.to = to
			r.dur = 0.4
			r.arc = 0.5
			r.next = "ride"
			r.t = 0.0
			return true
	return false


## A hit on piece k of the siege tower (n points). Returns whether it took.
func damage_piece(k: int, n: int, at: Vector3) -> bool:
	if not siege.on:
		return false
	var pc: Dictionary = siege.pieces[k]
	if not pc.alive:
		return false
	pc.hp = int(pc.hp) - n
	pc.flash = 0.12
	_sfx("thump", 0.55, at)
	_splinter(at, Vector3(0.2, 0.2, 0.2), 2, 0.6)
	if pc.hp > 0:
		award(PTS.tick, at, false)
		return true
	_break_piece(k)
	return true


func _piece_centre(k: int) -> Vector3:
	var b: Basis = siege.b
	return (siege.p as Vector3) + b * Vector3(0, float(siege.pieces[k].y) + _piece_h(k) * 0.5, 0)


func _break_piece(k: int) -> void:
	var pc: Dictionary = siege.pieces[k]
	pc.alive = false
	var c := _piece_centre(k)
	_splinter(c, Vector3(SIEGE_HALF, _piece_h(k) * 0.5, SIEGE_HALF), 10, 1.1)
	_sfx("boom", 0.55, c)
	_buzz2(0.6, 90)
	var fallen: Array = []
	for i in dudes.size():
		var d: Dictionary = dudes[i]
		if d.on and d.kind == "siege" and d.piece == k and hittable(d):
			fallen.append(i)
	award(PTS.piece, c + Vector3.UP * 0.6, false)
	if k == 0:
		# The base: everything comes down.
		var ps: Array = siege.pieces
		for q in ps.size():
			if ps[q].alive:
				ps[q].alive = false
				_splinter(_piece_centre(q), Vector3(SIEGE_HALF, _piece_h(q) * 0.5, SIEGE_HALF), 7, 1.3)
		for i in dudes.size():
			var d: Dictionary = dudes[i]
			if d.on and d.kind == "siege" and d.phase in ["ride", "hop"] and d.piece >= 0 and not i in fallen:
				fallen.append(i)
	var j := 0
	for i in fallen:
		var d: Dictionary = dudes[i]
		d.piece = -1
		var out := ((d.c as Vector3) - (siege.p as Vector3))
		out.y = 0.0
		out = out.normalized() if out.length_squared() > 1e-4 else Vector3.BACK
		_tumble(d, out * _rng.randf_range(2.0, 3.5) + Vector3.UP * _rng.randf_range(3.0, 5.0), 0.05 * j)
		F.knocked += 1
		award(PTS.climber, d.c, true, "", j > 0)
		j += 1
	if fallen.size() >= 2:
		_chain_bonus(fallen.size(), c, _tx("برج", "TOWER"))
	_settle_pieces(false)
	if _top_piece() < 0:
		var p: Vector3 = siege.p
		award(PTS.siege, p + Vector3.UP * 2.5, false)
		_banner(_tx("دمّرت برج الحصار!", "SIEGE TOWER DOWN!"), "+" + _num(PTS.siege * int(F.mult)), Color("ffd23f"), 2.0)
		_sfx("firework_burst", 1.0, p)
		_sfx("boom", 1.0, p)
		_confetti(p + Vector3.UP * 2.0, 1.6)
		_buzz2(1.0, 200)
		_siege_off()
		if ctx:
			ctx.ch_progress.call("castleSiege", int(ctx.ch_state.get("castleSiege", 0)) + 1)


func _siege_off() -> void:
	siege.on = false
	for d in dudes:
		if d.on and d.kind == "siege" and d.phase in ["ride", "hop"] and d.piece >= 0:
			d.on = false
			d.phase = ""
	for p in siege.proxies:
		(p as MeshInstance3D).visible = false


# ---- waves ----

static func wave_speed(n: int) -> float:
	return minf(1.0 + 0.07 * maxf(0.0, n - 1.0), 2.0)


## What wave n brings, in order: {k: ladder | follow | stack (n) | para | cat (n) | siege}.
func wave_plan(n: int) -> Array:
	if n == 1:
		return [{"k": "ladder"}, {"k": "stack", "n": 4}, {"k": "follow"}, {"k": "ladder"}]
	var out: Array = []
	var budget := mini(5 + n * 2, 36)
	if n % SIEGE_EVERY == 0:
		out.append({"k": "siege"})
		budget -= 4
	var cats_n := 0
	while budget > 0:
		var r := _rng.randf()
		if n >= 3 and r < 0.15 and cats_n < 2:
			var crew := 2 + mini(int(n / 3.0), 3)
			out.append({"k": "cat", "n": crew})
			budget -= crew
			cats_n += 1
		elif n >= 2 and r < 0.37:
			out.append({"k": "para"})
			budget -= 1
		elif r < 0.6:
			var g := mini(4 + int(n / 4.0) + _rng.randi_range(0, 1), 7)
			out.append({"k": "stack", "n": g})
			budget -= g
		elif r < 0.8:
			out.append({"k": "ladder"})
			budget -= 1
		else:
			out.append({"k": "follow"})
			budget -= 1
	return out


func start() -> void:
	F.state = "break"
	F.wave = 0
	F.queue = []
	_next_wave()


func _next_wave() -> void:
	F.wave += 1
	F.state = "break"
	F.break_t = FIRST_BREAK_T if F.wave == 1 else BREAK_T
	F.queue = wave_plan(F.wave)
	F.spawn_t = 0.0
	var siege_wave: bool = F.wave % SIEGE_EVERY == 0
	_banner(("WAVE %d" % F.wave) if _en() else ("الموجة " + GameCtx.ar_digits(F.wave)),
		_tx("برج الحصار قادم!", "SIEGE TOWER INCOMING!") if siege_wave else _tx("طيّحهم من الحصن!", "KNOCK THEM OFF THE FORT!"),
		Color("ff6b5a") if siege_wave else Color("ffd166"))
	_sfx("swish", 0.6, banner_at())
	if siege_wave:
		_sfx("boom", 0.5, banner_at())
		_buzz2(0.5, 120)
	if ctx and F.wave > 1:
		ctx.ch_progress.call("castleWaves", F.wave - 1)


## Climbers still on their way (dancers, the fallen, the stranded siege riders don't count).
func active() -> int:
	var n := 0
	for d in dudes:
		if d.on and not d.phase in ["plant", "dance", "tumble", "dizzy", ""]:
			if d.kind == "siege" and d.phase == "ride" and siege.phase in ["parked", "leave"]:
				continue
			n += 1
	for c in cats:
		if c.on and c.phase != "leave":
			n += 1
	if siege.on and siege.phase == "enter":
		n += 1
	return n


func _cap() -> int:
	return mini(9 + F.wave * 2, SLOTS - 10)


func _spawn_event(e: Dictionary) -> void:
	match String(e.k):
		"ladder":
			spawn_ladder()
		"follow":
			spawn_follower()
		"stack":
			spawn_stack(int(e.n))
		"para":
			spawn_para()
		"cat":
			if spawn_catapult(int(e.n)) < 0:
				spawn_stack(int(e.n))
		"siege":
			if not spawn_siege():
				spawn_ladder()


func _step_waves(dt: float) -> void:
	match F.state:
		"idle":
			if auto_spawn:
				start()
		"break":
			F.break_t = float(F.break_t) - dt
			if F.break_t <= 0.0:
				F.state = "wave"
				F.spawn_t = 0.3
		"wave":
			if not auto_spawn:
				return
			var q: Array = F.queue
			F.spawn_t = float(F.spawn_t) - dt
			if not q.is_empty() and F.spawn_t <= 0.0:
				var e: Dictionary = q[0]
				var need := int(e.get("n", 1))
				var free := 0
				for d in dudes:
					if not d.on:
						free += 1
				if active() + need <= _cap() + 3 and free >= need + 2:
					q.pop_front()
					_spawn_event(e)
					var k := clampf((F.wave - 1) / 12.0, 0.0, 1.0)
					F.spawn_t = lerpf(2.1, 0.75, k) * _rng.randf_range(0.8, 1.2) * (1.6 if String(e.k) in ["stack", "cat", "siege"] else 1.0)
				else:
					F.spawn_t = 0.4
			if q.is_empty() and active() == 0:
				F.cleared += 1
				_sfx("chime", 1.0, banner_at())
				_confetti(banner_at(), 1.0)
				_buzz2(0.3, 60)
				_next_wave()


# ---- drawing ----

func _eyes(d: Dictionary) -> String:
	match d.phase:
		"tumble":
			return "wide" if d.bounces == 0 else "shut"
		"dizzy":
			return "shut"
		"fling", "boing", "para", "top_hop", "cup":
			return "wide"
		"dance":
			return "shut" if fmod(d.t * 1.3 + float(d.seed), 2.0) < 0.35 else "open"
	return "shut" if d.blink > 0.0 else "open"


func _dude_xf(d: Dictionary) -> Transform3D:
	var c: Vector3 = d.c
	var to := _view() - c
	to.y *= 0.35
	if d.phase == "walk" or (d.phase == "ride" and d.kind == "cat"):
		var wd: Vector3 = d.dir
		to = to.normalized() * 0.6 + Vector3(wd.x, 0, wd.z).normalized()
	var dn := to.normalized() if to.length_squared() > 1e-6 else Vector3.BACK
	var rot := Basis.looking_at(dn, Vector3.UP, true) if absf(dn.y) < 0.99 else Basis.IDENTITY
	match d.phase:
		"tumble", "fling":
			rot = Basis(d.ax, float(d.ang)) * rot
		"dizzy":
			rot = Basis(Vector3.UP, sin(time * 3.0 + float(d.seed)) * 0.4) * Basis(Vector3.RIGHT, -0.5) * rot
		"dance":
			var tw := sin(d.t * 5.0 + float(d.seed)) * 0.55
			if fmod(d.t + float(d.seed), 4.0) < 0.5:
				tw = fmod(d.t + float(d.seed), 4.0) / 0.5 * TAU
			rot = Basis(Vector3.UP, tw) * Basis(Vector3.BACK, sin(d.t * 7.0 + float(d.seed)) * 0.18) * rot
		"para":
			rot = Basis(Vector3.BACK, float(d.ang)) * rot
		"brace":
			rot = Basis(Vector3.BACK, sin(time * 3.0 + float(d.seed)) * 0.08) * rot
	var sq: Vector2 = d.sq
	return Transform3D(Basis.from_scale(Vector3(sq.x, sq.y, sq.x)) * rot * Basis.from_scale(Vector3.ONE * R), c)


func _crowd_add(style: String, m: Transform3D, eyes: String, accessory: String, color: Color) -> void:
	crowd._put("body_" + style, m, color.srgb_to_linear())
	if style == "jelly":
		crowd._put("bandage", m)
	if crowd.parts.has("acc_" + accessory):
		crowd._put("acc_" + accessory, m * Transform3D(Basis.from_scale(Vector3.ONE * 1.08), Vector3.ZERO) if style == "fur" else m)
	if style == "fur" and accessory not in Crowd.HEADWEAR:
		crowd._put("bow", m)
	crowd._put("eyes_" + eyes, m)
	if crowd.with_faces:
		crowd._put("face_" + ("wide" if eyes == "wide" else "open"), m)


func _face_basis(p: Vector3) -> Basis:
	var to := _view() - p
	to.y = 0.0
	if to.length_squared() < 1e-6:
		return Basis.IDENTITY
	return Basis.looking_at(to.normalized(), Vector3.UP, true)


func _put_star(i: int, p: Vector3, s: float, spin: float, c: Color) -> int:
	var stars: MultiMesh = _mm.stars
	if i >= STARS_MAX:
		return i
	stars.set_instance_transform(i, Transform3D(_face_basis(p) * Basis(Vector3.BACK, spin) * Basis.from_scale(Vector3.ONE * s), p))
	stars.set_instance_color(i, c.srgb_to_linear())
	return i + 1


func draw() -> void:
	crowd.begin()
	var nsh := 0
	var nstar := 0
	var ncan := 0
	var nflag := 0
	var shadows: MultiMesh = _mm.shadows
	var can: MultiMesh = _mm.canopy
	var poles: MultiMesh = _mm.poles
	var cloth: MultiMesh = _mm.cloth
	for i in dudes.size():
		var d: Dictionary = dudes[i]
		var proxy: MeshInstance3D = d.proxy
		if not d.on:
			proxy.visible = false
			continue
		var xf := _dude_xf(d)
		_crowd_add(d.style, xf, _eyes(d), d.acc, Color(d.color))
		var c: Vector3 = d.c
		proxy.visible = hittable(d)
		if proxy.visible:
			proxy.transform = Transform3D(Basis.from_scale(Vector3.ONE * R * 1.3), c)
		# A soft shadow under him (on the roof or the ground).
		var fy := floor_y(c)
		if nsh < shadows.instance_count and not d.phase in ["brace", "perch", "climb"] and not (d.phase == "ride" and d.kind == "siege"):
			var h := maxf(0.0, c.y - R - fy)
			var k := clampf(1.0 - h / 7.0, 0.15, 1.0)
			shadows.set_instance_transform(nsh, Transform3D(Basis.from_scale(Vector3.ONE * R * (0.6 + 0.4 * k)), Vector3(c.x, fy + 0.03, c.z)))
			shadows.set_instance_color(nsh, Color(0.05, 0.02, 0.08, 0.35 * k))
			nsh += 1
		if d.phase == "dizzy" or (d.phase == "tumble" and d.bounces > 0):
			var top := c + Vector3.UP * R * 1.1
			for s in 3:
				var a: float = time * 7.0 + TAU * s / 3.0 + float(d.seed)
				nstar = _put_star(nstar, top + Vector3(cos(a), 0, sin(a)) * R * 0.8, 0.09, time * 5.0 + s, Color("ffd23f"))
		if d.canopy >= 0 and ncan < can.instance_count:
			var cp := c + Vector3.UP * 1.6
			var cnb := Basis(Vector3.BACK, float(d.ang) * 0.6) * Basis(Vector3.UP, time * 0.5 + float(d.seed))
			can.set_instance_transform(ncan, Transform3D(cnb * Basis.from_scale(Vector3.ONE * 1.0), cp))
			can.set_instance_color(ncan, Color(d.color).srgb_to_linear())
			var cpx: MeshInstance3D = canopies[d.canopy].proxy
			cpx.visible = true
			cpx.transform = Transform3D(Basis.from_scale(Vector3(1.0, 0.65, 1.0)), cp + Vector3.UP * 0.25)
			ncan += 1
		if d.phase in ["plant", "dance"] and d.flag_k > 0.0 and nflag < poles.instance_count:
			var fp := _flag_pos(d)
			var k: float = d.flag_k
			var e := 1.0 - pow(1.0 - k, 3.0)
			var f := spot_face(d.spot) if d.spot >= 0 else 0
			var fb := Basis(face_t(f), Vector3.UP, face_n(f))
			var wave := sin(time * 6.0 + float(d.seed)) * 0.35
			poles.set_instance_transform(nflag, Transform3D(fb * Basis.from_scale(Vector3(1, e, 1)), fp))
			poles.set_instance_color(nflag, Color.WHITE)
			cloth.set_instance_transform(nflag, Transform3D(fb * Basis(Vector3.UP, wave) * Basis.from_scale(Vector3(1.0 + 0.08 * sin(time * 9.0), 1, 1) * e), fp + Vector3.UP * 1.05 * e))
			cloth.set_instance_color(nflag, Color(d.color).srgb_to_linear())
			nflag += 1
	for q in canopies:
		if q.owner < 0:
			(q.proxy as MeshInstance3D).visible = false
	crowd.end()
	can.visible_instance_count = ncan
	poles.visible_instance_count = nflag
	cloth.visible_instance_count = nflag
	# Ladders.
	var lm: MultiMesh = _mm.ladders
	var nl := 0
	var L := ladder_len()
	for k in ladders.size():
		var l: Dictionary = ladders[k]
		var px: MeshInstance3D = l.proxy
		if not l.on:
			px.visible = false
			continue
		var y: Vector3 = l.dir
		var x: Vector3 = l.across
		var z := x.cross(y).normalized()
		var lb := Basis(x, y, z)
		var s: float = l.fade
		lm.set_instance_transform(nl, Transform3D(lb * Basis.from_scale(Vector3.ONE * maxf(0.01, s)), l.base))
		lm.set_instance_color(nl, Color.WHITE)
		nl += 1
		px.visible = l.state in ["up", "raising"]
		if px.visible:
			px.transform = Transform3D(lb * Basis.from_scale(Vector3(LAD_W, L, 0.3)), (l.base as Vector3) + y * L * 0.5)
	lm.visible_instance_count = nl
	# Catapults.
	var cb: MultiMesh = _mm.cat_body
	var ca: MultiMesh = _mm.cat_arm
	var nc := 0
	for c in cats:
		var px: MeshInstance3D = c.proxy
		if not c.on:
			px.visible = false
			continue
		var b: Basis = c.b
		var jig := Vector3(sin(time * 60.0), 0, cos(time * 50.0)) * 0.05 * (1.0 if c.flash > 0.0 else 0.0)
		var bob := Vector3.UP * absf(sin(float(c.roll) * 4.0)) * 0.04
		var bx := Transform3D(b, (c.p as Vector3) + jig + bob)
		var col := Color.WHITE.lerp(Color(3, 3, 3), 0.5) if c.flash > 0.0 else Color.WHITE
		cb.set_instance_transform(nc, bx)
		cb.set_instance_color(nc, col)
		ca.set_instance_transform(nc, bx * Transform3D(Basis(Vector3.RIGHT, float(c.arm)), ARM_PIVOT))
		ca.set_instance_color(nc, col)
		nc += 1
		px.visible = true
		px.transform = Transform3D(b * Basis.from_scale(Vector3(1.3, 1.6, 2.0)), (c.p as Vector3) + Vector3.UP * 0.8)
		if nsh < shadows.instance_count:
			shadows.set_instance_transform(nsh, Transform3D(b * Basis.from_scale(Vector3(0.9, 1, 1.3)), (c.p as Vector3) + Vector3.UP * 0.03))
			shadows.set_instance_color(nsh, Color(0.05, 0.02, 0.08, 0.35))
			nsh += 1
	cb.visible_instance_count = nc
	ca.visible_instance_count = nc
	_draw_siege(shadows, nsh)
	_mm.stars.visible_instance_count = nstar
	_draw_fx()
	_draw_labels()


func _draw_siege(shadows: MultiMesh, nsh_in: int) -> void:
	var nsh := nsh_in
	var mb: MultiMesh = _mm.siege_base
	var mt: MultiMesh = _mm.siege_tier
	var md: MultiMesh = _mm.siege_deck
	var mr: MultiMesh = _mm.siege_ramp
	var nt := 0
	var nb := 0
	var nd := 0
	var nr := 0
	var sp: Array = siege.proxies
	if siege.on:
		var b: Basis = siege.b
		var p: Vector3 = siege.p
		var ps: Array = siege.pieces
		var rock := sin(float(siege.roll) * 3.0) * 0.02 if siege.phase in ["enter", "leave"] else 0.0
		var rb := b * Basis(Vector3.BACK, rock)
		for k in ps.size():
			var pc: Dictionary = ps[k]
			var px: MeshInstance3D = sp[k]
			if not pc.alive:
				px.visible = false
				continue
			var jig := Vector3(sin(time * 70.0 + k), 0, 0) * 0.06 if pc.flash > 0.0 else Vector3.ZERO
			var xf := Transform3D(rb, p + rb * (Vector3.UP * float(pc.y) + jig))
			var col := Color(2.2, 2.2, 2.2) if pc.flash > 0.0 else Color.WHITE
			if k == 0:
				mb.set_instance_transform(nb, xf)
				mb.set_instance_color(nb, col)
				nb += 1
			elif k == DECK:
				md.set_instance_transform(nd, xf)
				md.set_instance_color(nd, col)
				nd += 1
				if siege.ramp > 0.0 or siege.phase == "unload" or siege.phase == "parked":
					var hinge := Vector3(0, 0.12, -SIEGE_HALF)
					var ra: float = -float(siege.ramp) * PI / 2.0 * 0.92
					mr.set_instance_transform(nr, xf * Transform3D(Basis(Vector3.RIGHT, ra), hinge))
					mr.set_instance_color(nr, col)
					nr += 1
				else:
					mr.set_instance_transform(nr, xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.15, -SIEGE_HALF - 0.06)))
					mr.set_instance_color(nr, col)
					nr += 1
			else:
				mt.set_instance_transform(nt, xf)
				mt.set_instance_color(nt, col)
				nt += 1
			var h := _piece_h(k)
			px.visible = true
			px.transform = Transform3D(rb * Basis.from_scale(Vector3(SIEGE_HALF * 2.0, h, SIEGE_HALF * 2.0)), p + rb * Vector3(0, float(pc.y) + h * 0.5, 0))
		if nsh < shadows.instance_count:
			shadows.set_instance_transform(nsh, Transform3D(b * Basis.from_scale(Vector3(1.4, 1, 1.4)), p + Vector3.UP * 0.03))
			shadows.set_instance_color(nsh, Color(0.05, 0.02, 0.08, 0.4))
			nsh += 1
	else:
		for px in sp:
			(px as MeshInstance3D).visible = false
	mb.visible_instance_count = nb
	mt.visible_instance_count = nt
	md.visible_instance_count = nd
	mr.visible_instance_count = nr
	shadows.visible_instance_count = nsh


func _draw_fx() -> void:
	var sp: MultiMesh = _mm.sparks
	var n := mini(_sparks.size(), SPARKS_MAX)
	for i in n:
		var s: Dictionary = _sparks[i]
		var k: float = 1.0 - float(s.t) / float(s.life)
		sp.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * float(s.s) * (0.4 + 0.6 * k)), s.p))
		sp.set_instance_color(i, Color((s.c as Color).srgb_to_linear(), clampf(k * 1.6, 0.0, 1.0)))
	sp.visible_instance_count = n
	var pm: MultiMesh = _mm.planks
	var np := mini(_planks.size(), PLANKS_MAX)
	for i in np:
		var q: Dictionary = _planks[i]
		var k: float = clampf((float(q.life) - float(q.t)) / 0.4, 0.0, 1.0)
		pm.set_instance_transform(i, Transform3D(Basis(q.ax, float(q.ang)) * Basis.from_scale((q.e as Vector3) * maxf(0.01, k)), q.p))
		pm.set_instance_color(i, (q.c as Color).srgb_to_linear())
	pm.visible_instance_count = np
	var rings: MultiMesh = _mm.rings
	for i in _rings.size():
		var g: Dictionary = _rings[i]
		var k: float = clampf(float(g.t) / float(g.life), 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 3.0)
		var rad: float = lerpf(g.r0, g.r1, e)
		rings.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(rad, rad * 1.6, rad)), g.p))
		rings.set_instance_color(i, Color((g.c as Color).srgb_to_linear(), 1.0 - k))
	rings.visible_instance_count = _rings.size()


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
		var s := (0.3 + 0.7 * inn) * over * (1.0 + out * 0.4)
		banner.position = banner_at() + Vector3.UP * out * 0.35
		banner.scale = Vector3.ONE * s
		banner.modulate.a = 1.0 - out
		banner_sub.position = banner_at() + Vector3(0, -1.05, 0) + Vector3.UP * out * 0.35
		banner_sub.scale = Vector3.ONE * minf(1.0, age / 0.5)
		banner_sub.modulate.a = 1.0 - out
	var ct: float = F.combo_show_t
	combo_label.visible = ct > 0.0
	if combo_label.visible:
		var a := 1.1 - ct
		combo_label.position = (F.combo_at as Vector3) + Vector3.UP * (1.3 + a * 0.6)
		combo_label.scale = Vector3.ONE * (0.6 + 0.6 * minf(1.0, a * 6.0)) * (1.0 + 0.08 * sin(a * 30.0) * (1.0 - a))
		combo_label.modulate.a = clampf(ct / 0.3, 0.0, 1.0)


# ---- the thrown Dahrooj ----

## Pushes a ball (fort units: centre p, radius r) out of the fort. {hit, p, n}.
static func fort_push(p: Vector3, r: float) -> Dictionary:
	var best := {"hit": false, "p": p, "n": Vector3.UP}
	var boxes := [[Vector3(-W, 0, -W), Vector3(W, H, W)], [KEEP_C - KEEP_E, KEEP_C + KEEP_E]]
	for bx in boxes:
		var mn: Vector3 = bx[0]
		var mx: Vector3 = bx[1]
		var q := p.clamp(mn, mx)
		var d := p - q
		var l := d.length()
		if l < r:
			var n := Vector3.UP
			if l > 1e-5:
				n = d / l
			else:
				# The centre inside: out the nearest side.
				var e := [p.x - mn.x, mx.x - p.x, p.y - mn.y, mx.y - p.y, p.z - mn.z, mx.z - p.z]
				var nn := [Vector3.LEFT, Vector3.RIGHT, Vector3.DOWN, Vector3.UP, Vector3.FORWARD, Vector3.BACK]
				var bi := 0
				for k in 6:
					if float(e[k]) < float(e[bi]):
						bi = k
				n = nn[bi]
				q = p + n * float(e[bi])
			p = q + n * r
			best = {"hit": true, "p": p, "n": n}
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var a := Vector2(W * float(sx), W * float(sz))
			var h := Vector2(p.x, p.z) - a
			if p.y < TOWER_H + 0.4 and h.length() < TOWER_R + r:
				var n2 := h.normalized() if h.length() > 1e-5 else Vector2(float(sx), float(sz)).normalized()
				var to := a + n2 * (TOWER_R + r)
				p = Vector3(to.x, p.y, to.y)
				best = {"hit": true, "p": p, "n": Vector3(n2.x, 0, n2.y)}
	return best


func collide(S: Ball) -> void:
	_sync_root()
	var r := Ball.BR / size
	var lp := to_fort(S.pos)
	var fp := fort_push(lp, r)
	if fp.hit:
		var n := _gdir(fp.n)
		S.pos = to_game(fp.p)
		var vn := S.vel.dot(n)
		if vn < 0.0:
			S.hit(n, -vn, S.pos - n * Ball.BR)
			S.vel -= n * vn * 1.5
		S.side = Vector3.ZERO
		lp = fp.p
	if not S.shot:
		return
	var dir := _ldir(S.vel.normalized()) if S.vel.length_squared() > 1e-6 else _ldir(Vector3.FORWARD)
	for i in dudes.size():
		var d: Dictionary = dudes[i]
		if not hittable(d):
			continue
		if (d.c as Vector3).distance_to(lp) < r + R * 1.1:
			F.touched = true
			if knock(i, dir):
				_sfx("thump", 0.5, d.c)
				var nn := _gdir((lp - (d.c as Vector3)).normalized())
				var vn := S.vel.dot(nn)
				if vn < 0.0:
					S.vel -= nn * vn * 1.2
				S.vel *= 0.85
	for k in ladders.size():
		var l: Dictionary = ladders[k]
		if not l.on or not l.state in ["up", "raising"] or l.ball_t > 0.0:
			continue
		var a: Vector3 = l.base
		var b: Vector3 = a + (l.dir as Vector3) * ladder_len()
		var ab := b - a
		var t := clampf((lp - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		if (a + ab * t).distance_to(lp) < r + LAD_W * 0.45:
			F.touched = true
			l.ball_t = 0.4
			knock_ladder(k, dir)
	for k in cats.size():
		var c: Dictionary = cats[k]
		if c.on and c.ball_t <= 0.0 and ((c.p as Vector3) + Vector3.UP * 0.7).distance_to(lp) < r + 0.95:
			c.ball_t = 0.35
			F.touched = true
			F.throw_hits += 1
			damage_cat(k, 2, lp)
	if siege.on and siege.ball_t <= 0.0:
		var b: Basis = siege.b
		var loc := b.inverse() * (lp - (siege.p as Vector3))
		var ps: Array = siege.pieces
		for k in ps.size():
			var pc: Dictionary = ps[k]
			if not pc.alive:
				continue
			var mn := Vector3(-SIEGE_HALF, float(pc.y), -SIEGE_HALF)
			var mx := Vector3(SIEGE_HALF, float(pc.y) + _piece_h(k), SIEGE_HALF)
			if loc.clamp(mn, mx).distance_to(loc) < r:
				siege.ball_t = 0.35
				F.touched = true
				F.throw_hits += 1
				damage_piece(k, 2, lp)
				var nn := (loc - loc.clamp(mn, mx)).normalized() if loc.clamp(mn, mx).distance_to(loc) > 1e-5 else Vector3.BACK
				var wn := _gdir(b * nn)
				var vn := S.vel.dot(wn)
				if vn < 0.0:
					S.vel -= wn * vn * 1.4
				break


## A blaster shot hit node (one of our hidden hit shapes) going along dir.
func shoot(obj: Node, point: Vector3, dir: Vector3) -> bool:
	var d := _ldir(dir) if dir != Vector3.ZERO else _ldir(Vector3.FORWARD)
	var at := to_fort(point)
	for i in dudes.size():
		if obj == dudes[i].proxy and dudes[i].on:
			return knock(i, d)
	for k in canopies.size():
		if obj == canopies[k].proxy and canopies[k].owner >= 0:
			return knock(int(canopies[k].owner), d)
	for k in ladders.size():
		if obj == ladders[k].proxy:
			return knock_ladder(k, d)
	for k in cats.size():
		if obj == cats[k].proxy:
			return damage_cat(k, 1, at)
	var sp: Array = siege.proxies
	for k in sp.size():
		if obj == sp[k]:
			return damage_piece(k, 1, at)
	if F.state == "idle" and auto_spawn:
		start()
	return false


func touched() -> bool:
	return F.touched


func on_throw() -> void:
	F.throw_live = true
	F.throw_hits = 0
	if F.state == "idle" and auto_spawn:
		start()


func on_respawn() -> void:
	F.touched = false
	F.throw_live = false


func deactivate() -> void:
	for d in dudes:
		d.on = false
		d.phase = ""
		(d.proxy as MeshInstance3D).visible = false
	for l in ladders:
		l.on = false
	for c in cats:
		c.on = false
	siege.on = false
	for q in canopies:
		q.owner = -1
	for k in spots.size():
		spots[k] = -1
	groups.clear()
	JuiceText.clear(root)
	_sparks.clear()
	_planks.clear()
	_rings.clear()
	F.state = "idle"
	F.wave = 0
	F.score = 0
	F.queue = []
	F.planted = 0
	_break_combo()
	F.banner_t = 0.0
	F.combo_show_t = 0.0
	F.touched = false
	draw()


func update(_b: Ball, sub_dt: float) -> void:
	if not visible or paused:
		return
	# The runtime calls this three times a frame; the fort's crowd moves once a frame (the
	# sub-steps add up), which keeps the cost down on the headset.
	_sim_acc += sub_dt
	if _sim_acc < 0.012:
		return
	var dt := minf(_sim_acc, 0.05)
	_sim_acc = 0.0
	time += dt
	_sync_root()
	F.banner_t = maxf(0.0, float(F.banner_t) - dt)
	F.combo_show_t = maxf(0.0, float(F.combo_show_t) - dt)
	if F.combo_t > 0.0:
		F.combo_t = float(F.combo_t) - dt
		if F.combo_t <= 0.0:
			_break_combo()
	_room_t -= dt
	if _room_t <= 0.0:
		_room_t = 1.0
		_scan_room()
	_step_waves(dt)
	for l in ladders:
		if l.on:
			_step_ladder(l, dt)
	for i in dudes.size():
		var d: Dictionary = dudes[i]
		if d.on:
			_step_dude(i, d, dt)
	for gid in groups.keys():
		if groups.has(gid):
			_step_group(gid, groups[gid], dt)
	for k in cats.size():
		if cats[k].on:
			_step_cat(k, cats[k], dt)
	if siege.on:
		_step_siege(dt)
	for i in range(_sparks.size() - 1, -1, -1):
		var s: Dictionary = _sparks[i]
		s.t += dt
		if s.t >= s.life:
			_sparks.remove_at(i)
			continue
		s.v.y -= GRAV * float(s.g) * dt
		s.p += (s.v as Vector3) * dt
		var fy := floor_y(s.p)
		if s.p.y < fy:
			s.p.y = fy
			s.v *= Vector3(0.6, -0.3, 0.6)
	for i in range(_planks.size() - 1, -1, -1):
		var q: Dictionary = _planks[i]
		q.t += dt
		if q.t >= q.life:
			_planks.remove_at(i)
			continue
		q.v.y -= GRAV * dt
		q.p += (q.v as Vector3) * dt
		q.ang = float(q.ang) + float(q.w) * dt
		var fy := floor_y(q.p) + 0.05
		if q.p.y < fy:
			q.p.y = fy
			q.v *= Vector3(0.5, -0.3, 0.5)
			q.w = float(q.w) * 0.5
	for i in range(_rings.size() - 1, -1, -1):
		_rings[i].t += dt
		if _rings[i].t >= _rings[i].life:
			_rings.remove_at(i)
	draw()


## For tests and the HUD.
func castle_state() -> Dictionary:
	var dancing := 0
	for d in dudes:
		if d.on and d.phase in ["plant", "dance"]:
			dancing += 1
	return {"state": F.state, "wave": F.wave, "score": F.score, "knocked": F.knocked, "planted": F.planted,
		"dancing": dancing, "combo": F.combo, "mult": F.mult, "active": active(), "queue": (F.queue as Array).size(),
		"best_chain": F.best_chain, "siege": siege.on}
