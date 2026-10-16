class_name FrenzyStage
extends Node3D
## Pop Frenzy («حمّى الفرقعة», mode "frenzy"): the air around the player fills with soap
## bubbles and little Dahroojs of every colour and size, drifting on gentle currents (mixed
## reality: they fill the room and bounce softly off the scanned walls, ceiling, floor and
## furniture). Pop them with blaster shots and thrown Dahroojs.
##
## - popping the SAME colour again and again builds a colour chain (×2 at 3, ×3 at 6, ×4 at 10,
##   ×5 at 15); the chain's colour glows in a ring of ten beads around each hand (how far to
##   FRENZY) and the chain-coloured bubbles pulse. Another colour starts a new chain.
## - a pop spreads to the same-coloured bubbles touching it (chain reaction; same colours
##   drift together into little clusters); big bubbles hold little Dahroojs that spill out; a
##   rare rainbow bubble pops everything of the chain's colour.
## - 10 in a chain: FRENZY. Everything turns gold, time slows (time_scale 0.5 for 6 s; main
##   multiplies it into the game dt and lowers the audio pitch with audio_pitch()), every pop
##   counts for the chain and is worth double, the blaster fires a fan of three (shot_fan()),
##   fireworks burst all around.
## - open play: no clock, no lives, nothing to lose; they refill without end and the air grows
##   busier (more of them, more colours, faster currents) the longer you play. The points go to
##   ctx.counts["frenzy"], which the jelly score popup shows.
## Game units, like the other stages. The blaster finds them through hidden (layers = 0) sphere
## MeshInstance3Ds; everything drawn is a MultiMesh or a JuiceText (a handful of draws).
##
## Mixed reality: `planes_provider` returns the room's planes in game units, as for the slime
## stage: Array of {pos, normal (into the room), ax, ay (unit axes), half: Vector2, label};
## `spots_provider` (RoomSpots) brings new ones out of the room in front of the player, and
## without a scan (`around`) the air they float in surrounds the player (new ones still appear
## only in front, never behind or close: _pick_spot()).

const SLOTS := 64
const KINDS := {
	# r: radius range (game units, × size), pts: base points.
	"bubble": {"r": [0.34, 0.56], "pts": 1},
	"dahrooj": {"r": [0.26, 0.34], "pts": 2},
	"big": {"r": [0.95, 1.2], "pts": 3},
	"rainbow": {"r": [0.62, 0.62], "pts": 5},
}
## The chain colours: [hex, Arabic, English].
const COLORS := [
	["ff4fa3", "وردي", "PINK"],
	["4fb3ff", "أزرق", "BLUE"],
	["ffd93d", "أصفر", "YELLOW"],
	["5ee07a", "أخضر", "GREEN"],
	["ff8a2f", "برتقالي", "ORANGE"],
	["b06bff", "بنفسجي", "PURPLE"],
]
const GOLD := Color("ffc93a")
const GOLD_BODY := Color("ffe27a")  # the Dahroojs' gold (their shaders deepen the colour)
const CHAIN_STEPS := [3, 6, 10, 15]  # chain lengths where the multiplier steps up (×2 .. ×5)
const FRENZY_AT := 10
const FRENZY_T := 6.0
const FRENZY_SCALE := 0.5
const CHAIN_T := 7.0  # a chain fades if nothing is popped for this long (real seconds)
const TOUCH_K := 1.22  # same colours closer than (ra + rb) × this pop together
const CHAIN_DELAY := 0.075
const STYLES := ["jelly", "fur", "clay", "fabric", "jelly", "clay"]
const ACCS := ["", "", "", "party", "glasses", "cap", "flower", "headphones", "scarf", "crown"]
const SPARKS_MAX := 420
const RINGS_MAX := 24
const BEADS := 10
const HEAT_T := 150.0  # seconds of play to the busiest air
const FIELD_HALF := Vector3(7.5, 2.9, 6.5)  # VR field (× size), around the player, mostly ahead
const FIELD_AHEAD := 4.2
const FIELD_Y := Vector3(0.7, 6.5, 0.0)  # x: lowest centre, y: highest (× size)

static var _cache := {}

var aim_z := -10.0
var far_z = null
var reach_z = null
var friction = null
var shot_time = 4.0
var ctx: GameCtx

## Mixed reality: the room's planes (see the header). Unset or empty: the air over the court.
var planes_provider: Callable
## Spots in front of the player (mixed reality, RoomSpots; as MoleStage.spots_provider): new
## ones blow out of the walls, furniture and floor there, or appear in the air ahead.
var spots_provider: Callable
## Mixed reality: new ones often come from spots_provider, and without a scan the air they
## float in surrounds the player (not mostly ahead); they still appear only in front.
var around := false
## Size of everything (1 = VR). Mixed reality: main's scale / VR scale, so they keep their real size.
var size := 1.0
## The player's eye (game units); main keeps it current.
var viewer := Vector3(0, 3.2, 1.0)
## The hands (game units): hand -> Transform3D (grip) or Vector3. The chain ring glows around them.
var hands := {}
## buzz(hand: String, amp: float, ms: float): haptics (main's buzz).
var buzz: Callable
## FRENZY's slow motion: main multiplies this into the game dt.
var time_scale := 1.0
## Main holds the game while the menu is open or the court is being placed.
var paused := false
## New ones float in on their own (tests turn it off and call spawn()).
var auto_spawn := true
var time := 0.0

var F := {"score": 0, "chain": 0, "chain_col": -1, "chain_t": 0.0, "mult": 1, "frenzy_t": 0.0, "frenzies": 0,
	"popped": 0, "play_t": 0.0, "spawn_t": 0.0, "rainbow_t": 18.0, "filled": false, "touched": false,
	"banner_t": 0.0, "banner_life": 2.0, "combo_t": 0.0, "combo_at": Vector3.ZERO, "gold": 0.0,
	"firework_t": 0.0, "snd_t": 0.0, "buzz_t": 0.0, "best_chain": 0}
var items: Array = []
var crowd: Crowd
var banner: JuiceText
var banner_sub: JuiceText
var combo_label: JuiceText
var _sparks: Array = []
var _rings: Array = []
var _rockets: Array = []
var _mm := {}
var _bubble_mat: ShaderMaterial
var _room: Array = []
var _room_t := 0.0
var _bounds := {}  # {lo, hi} of the room (game units), or empty
var _follow := Vector3(0, 0, 1.0)
var _acc := 0.0
var _racc := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 9090
	name = "Frenzy"
	crowd = Crowd.new(56, true, true)
	crowd.name = "Floaters"
	for id in crowd.parts:
		(crowd.parts[id].mi as MultiMeshInstance3D).custom_aabb = AABB(Vector3(-200, -100, -200), Vector3(400, 300, 400))
	add_child(crowd)
	for i in SLOTS:
		var proxy := MeshInstance3D.new()
		proxy.name = "FloatHit%d" % i
		proxy.mesh = _sphere_mesh()
		proxy.layers = 0  # never drawn: only the blaster's ray sees it
		proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		proxy.visible = false
		add_child(proxy)
		items.append({"on": false, "kind": "bubble", "col": 0, "p": Vector3.ZERO, "v": Vector3.ZERO, "r": 0.4,
			"grow": 0.0, "delay": 0.0, "t": 0.0, "ph": 0.0, "wob": 0.0, "style": "jelly", "acc": "", "kids": [],
			"pop_t": -1.0, "pop_dir": Vector3.FORWARD, "safe": 0.0, "blink": 0.0, "blink_t": 1.0, "spin": 0.0, "proxy": proxy})
	_bubble_mat = ShaderMaterial.new()
	_bubble_mat.shader = load("res://shaders/frenzy_bubble.gdshader")
	_bubble_mat.render_priority = 4
	_mm.bubbles = _multi("Bubbles", Crowd.merge([[Crowd.sphere(1.0, 24, 16), Transform3D.IDENTITY, Color.WHITE]]), _bubble_mat, SLOTS)
	_mm.sparks = _multi("Droplets", Crowd.merge([[Crowd.sphere(1.0, 6, 4), Transform3D.IDENTITY, Color.WHITE]]), _mat("glow"), SPARKS_MAX)
	_mm.rings = _multi("PopRings", _ring_mesh(), _mat("ring"), RINGS_MAX)
	_mm.beads = _multi("ChainBeads", Crowd.merge([[Crowd.sphere(1.0, 8, 6), Transform3D.IDENTITY, Color.WHITE]]), _mat("glow"), BEADS * 2 + 2)
	_mm.halo = _multi("ChainHalo", Crowd.merge([[Crowd.torus(1.0, 0.07, 6, 40), Transform3D.IDENTITY, Color.WHITE]]), _mat("ring"), 2)
	_mm.flash = _multi("GoldDome", Crowd.merge([[Crowd.sphere(1.0, 16, 10), Transform3D.IDENTITY, Color.WHITE]]), _mat("flash"), 1)
	banner = JuiceText.make("banner", 230 * 0.0062)
	banner.modulate = GOLD
	add_child(banner)
	banner_sub = JuiceText.make("sub", 96 * 0.0058)
	banner_sub.modulate = Color("fff3e0")
	add_child(banner_sub)
	combo_label = JuiceText.make("combo", 140 * 0.0058)
	add_child(combo_label)
	draw()


# ---- art ----

static func _sphere_mesh() -> SphereMesh:
	if not _cache.has("proxy"):
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 10
		s.rings = 5
		_cache["proxy"] = s
	return _cache["proxy"]


## A flat ring (unit outer radius, facing +Z, both sides): the pop's shock ring.
static func _ring_mesh() -> ArrayMesh:
	if _cache.has("ring_mesh"):
		return _cache["ring_mesh"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 40
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var o0 := Vector3(cos(a0), sin(a0), 0)
		var o1 := Vector3(cos(a1), sin(a1), 0)
		var c_in := Color(1, 1, 1, 0.0)
		var c_mid := Color(1, 1, 1, 1.0)
		# inner fade (0.72 .. 0.9) then outer edge (0.9 .. 1.0)
		for band in [[0.72, 0.9, c_in, c_mid], [0.9, 1.0, c_mid, Color(1, 1, 1, 0.35)]]:
			var ra: float = band[0]
			var rb: float = band[1]
			var ca: Color = band[2]
			var cb: Color = band[3]
			for v in [[o0 * ra, ca], [o1 * ra, ca], [o1 * rb, cb], [o0 * ra, ca], [o1 * rb, cb], [o0 * rb, cb]]:
				st.set_color(v[1])
				st.set_normal(Vector3.BACK)
				st.add_vertex(v[0])
	var mesh := st.commit()
	_cache["ring_mesh"] = mesh
	return mesh


static func _mat(key: String) -> Material:
	if _cache.has("mat_" + key):
		return _cache["mat_" + key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	match key:
		"ring":
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.render_priority = 5
		"glow":
			m.render_priority = 5
		"flash":
			m.cull_mode = BaseMaterial3D.CULL_FRONT  # seen from inside
			m.no_depth_test = true
			m.render_priority = 10
	_cache["mat_" + key] = m
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
	mi.custom_aabb = AABB(Vector3(-200, -100, -200), Vector3(400, 300, 400))
	add_child(mi)
	return mm


# ---- ctx ----

func _en() -> bool:
	return ctx != null and ctx.lang == "en"


func _num(v: int) -> String:
	return str(v) if _en() else GameCtx.ar_digits(v)


func _sfx(n: String, k: float, p: Vector3) -> void:
	if ctx:
		ctx.sfx.call(n, k, p)


func _buzz2(amp: float, ms: float) -> void:
	if buzz.is_valid():
		buzz.call("left", amp, ms)
		buzz.call("right", amp, ms)


func _confetti(at: Vector3, k := 1.0) -> void:
	if ctx:
		ctx.confetti.call(at, 1.2 * k * size, 1.4, maxf(1.0, at.distance_to(viewer) / 7.0))


## A colour index's display colour (gold in FRENZY; -1: the rainbow's white).
func color_of(col: int) -> Color:
	if col < 0:
		return Color("fffaf2")
	return Color(COLORS[col][0])


## The chain's colour (for the hand ring, and for main to tint the blaster's bolts).
func chain_color() -> Color:
	if F.frenzy_t > 0.0:
		return GOLD
	var c: int = F.chain_col
	return color_of(c) if c >= 0 else Color("fffaf2")


# ---- the air ----

## How busy the air is, 0 (calm start) .. 1 (after HEAT_T seconds of play).
func heat() -> float:
	return clampf(float(F.play_t) / HEAT_T, 0.0, 1.0)


## How many colours are in play: 4, then 5, then 6 as it heats up.
func colors_in_play() -> int:
	var h := heat()
	return 4 + (1 if h > 0.3 else 0) + (1 if h > 0.65 else 0)


## The space they float in: {lo, hi} (game units). The room's bounds in mixed reality,
## otherwise a box of air around the player, mostly ahead.
func field() -> Dictionary:
	if not _bounds.is_empty():
		return _bounds
	var c := Vector3(_follow.x, 0.0, _follow.z - (0.0 if around else FIELD_AHEAD * size))
	var h := FIELD_HALF * size
	return {"lo": Vector3(c.x - h.x, FIELD_Y.x * size, c.z - h.z), "hi": Vector3(c.x + h.x, FIELD_Y.y * size, c.z + h.z)}


## How many float at once: more as it heats up; fewer in a small room.
func target_count() -> int:
	var f := field()
	var d: Vector3 = (f.hi as Vector3) - (f.lo as Vector3)
	var m3 := absf(d.x * d.y * d.z) / pow(2.0 * size, 3.0)  # cubic metres (2 game units a metre × size)
	var cap := clampi(int(m3 * 2.0), 16, 56)
	return mini(cap, int(lerpf(34.0, 56.0, heat())))


func _planes() -> Array:
	if planes_provider.is_valid():
		var p = planes_provider.call()
		if p is Array:
			return p
	return []


## Main, as soon as the mode is set up in mixed reality: read the room now, so the first
## frame already has the room layout (no VR wall, booth or field shown for a moment).
func refresh_room() -> void:
	_refresh_room()


## The room's planes and bounds, refreshed every second (mixed reality).
func _refresh_room() -> void:
	_room = _planes()
	_bounds = {}
	if _room.is_empty():
		return
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var n := 0
	for pl in _room:
		var lab := String(pl.get("label", ""))
		if not lab in ["wall", "floor", "ceiling"]:
			continue
		var c: Vector3 = pl.pos
		var ax: Vector3 = pl.ax
		var ay: Vector3 = pl.ay
		var hf: Vector2 = pl.half
		for s in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var q: Vector3 = c + ax * hf.x * s.x + ay * hf.y * s.y
			lo = lo.min(q)
			hi = hi.max(q)
		n += 1
	if n == 0:
		return
	var m := 0.35 * size
	lo += Vector3.ONE * m
	hi -= Vector3.ONE * m
	# A room without a ceiling scan: up to about 2.4 m over the floor.
	hi.y = minf(hi.y, lo.y + 4.8 * size) if hi.y - lo.y > 6.0 * size else hi.y
	if hi.x - lo.x < 1.5 * size or hi.z - lo.z < 1.5 * size or hi.y - lo.y < 1.0 * size:
		return
	_bounds = {"lo": lo, "hi": hi}


# ---- spawning ----

func _free_slot() -> int:
	for i in items.size():
		if not items[i].on:
			return i
	return -1


func alive() -> int:
	var n := 0
	for it in items:
		if it.on:
			n += 1
	return n


func _pick_kind() -> String:
	var bigs := 0
	var rainbow := false
	for it in items:
		if it.on and it.kind == "big":
			bigs += 1
		if it.on and it.kind == "rainbow":
			rainbow = true
	if not rainbow and F.rainbow_t <= 0.0:
		F.rainbow_t = _rng.randf_range(20.0, 30.0)
		return "rainbow"
	var r := _rng.randf()
	if r < 0.07 + 0.06 * heat() and bigs < 3:
		return "big"
	if r < 0.4:
		return "dahrooj"
	return "bubble"


## A colour for a new one: mostly random, sometimes the chain's (so a chain can go on).
func _pick_col() -> int:
	var n := colors_in_play()
	var cc: int = F.chain_col
	if cc >= 0 and cc < n and _rng.randf() < 0.22:
		return cc
	return _rng.randi() % n


## How near the player a new one may appear (game units): RoomSpots.MIN_DIST (a metre is
## 2 game units × size).
func near_d() -> float:
	return RoomSpots.MIN_DIST * 2.0 * size


## Where a new one appears: {p, v}. In the air, rising from the ground, or (mixed reality)
## blown out of a wall, the ceiling or a table; always in front of the player (RoomSpots.ARC
## either side of the court's forward, game -Z) and near_d() away or more. They float about
## (and may drift round you) afterwards.
func _pick_spot(r: float) -> Dictionary:
	var f := field()
	var lo: Vector3 = f.lo
	var hi: Vector3 = f.hi
	var near := near_d()
	# Mixed reality: out of a wall, a table or the floor in front of the player, or in the air.
	if around and _rng.randf() < 0.55:
		var sps := RoomSpots.ask(spots_provider)
		if not sps.is_empty():
			var sp: Dictionary = sps[0]
			var n: Vector3 = sp.get("normal", Vector3.UP)
			var at: Vector3 = sp.pos
			if str(sp.get("kind", "")) == "air":
				return {"p": RoomSpots.into_arc(viewer, at, near), "v": Vector3.ZERO, "wall": false}
			return {"p": RoomSpots.into_arc(viewer, at + n * r * 1.15, near), "v": n * 1.3 * size, "wall": true}
	if not _room.is_empty() and _rng.randf() < 0.45:
		for k in 6:
			var pl: Dictionary = _room[_rng.randi() % _room.size()]
			var hf: Vector2 = pl.half
			if hf.x < r * 1.5 or hf.y < r * 1.5:
				continue
			var n: Vector3 = pl.normal
			var p: Vector3 = (pl.pos as Vector3) + (pl.ax as Vector3) * _rng.randf_range(-1, 1) * (hf.x - r) + (pl.ay as Vector3) * _rng.randf_range(-1, 1) * (hf.y - r) + n * r * 1.15
			if not RoomSpots.ahead(viewer, p, near):
				continue
			return {"p": p, "v": n * 1.3 * size, "wall": true}
	for k in 16:
		var p := Vector3(_rng.randf_range(lo.x, hi.x), _rng.randf_range(lo.y, hi.y), _rng.randf_range(lo.z, minf(hi.z, viewer.z - near * 0.5)))
		var rise := _bounds.is_empty() and _rng.randf() < 0.3
		if rise:
			p.y = lo.y
		if not RoomSpots.ahead(viewer, p, near):
			continue
		return {"p": p, "v": Vector3(0, 0.9 * size, 0) if rise else Vector3.ZERO, "wall": false}
	# Nothing out there (a small room): in the air ahead of the player.
	var q := viewer + RoomSpots.dir_at(Vector3.FORWARD, _rng.randf_range(-RoomSpots.ARC, RoomSpots.ARC)) * near * _rng.randf_range(1.05, 1.5)
	q.y = clampf(viewer.y + _rng.randf_range(-0.6, 0.6) * size, lo.y, maxf(lo.y, hi.y))
	return {"p": q, "v": Vector3.ZERO, "wall": false}


## A new one; kind "" = a random one, col -1 = a random colour, at = null: a free spot.
## Returns its slot, or -1. Tests call it directly.
func spawn(kind := "", col := -1, at = null, vel := Vector3.ZERO, delay := 0.0) -> int:
	var slot := _free_slot()
	if slot < 0:
		return -1
	if kind == "":
		kind = _pick_kind()
	var it: Dictionary = items[slot]
	var K: Dictionary = KINDS[kind]
	var rr: Array = K.r
	var r := _rng.randf_range(float(rr[0]), float(rr[1])) * size
	it.on = true
	it.kind = kind
	it.col = -1 if kind == "rainbow" else (col if col >= 0 else _pick_col())
	it.r = r
	if at == null:
		var s := _pick_spot(r)
		it.p = s.p
		it.v = s.v
	else:
		it.p = at
		it.v = vel
	it.grow = 0.0
	it.delay = delay
	it.t = 0.0
	it.ph = _rng.randf() * TAU
	it.wob = 0.0
	it.pop_t = -1.0
	it.safe = 0.0
	it.spin = _rng.randf() * TAU
	it.blink = 0.0
	it.blink_t = _rng.randf_range(0.8, 3.0)
	it.style = STYLES[_rng.randi() % STYLES.size()]
	it.acc = ACCS[_rng.randi() % ACCS.size()]
	it.kids = []
	if kind == "big":
		for k in _rng.randi_range(3, 5):
			it.kids.append({"style": STYLES[_rng.randi() % STYLES.size()], "acc": ACCS[_rng.randi() % ACCS.size()], "ph": TAU * k / 5.0 + _rng.randf() * 0.5})
	return slot


## Fills the air at the start, each one inflating a moment after the last.
func fill() -> void:
	F.filled = true
	var n := int(target_count() * 0.75)
	for i in n:
		spawn("", -1, null, Vector3.ZERO, i * 0.03)


# ---- popping ----

static func multiplier(chain: int) -> int:
	var m := 1
	for s in CHAIN_STEPS:
		if chain >= int(s):
			m += 1
	return m


func frenzy() -> bool:
	return F.frenzy_t > 0.0


## Can be popped now (grown in, not already gone).
static func hittable(it: Dictionary) -> bool:
	return it.on and float(it.grow) > 0.25 and float(it.delay) <= 0.0 and float(it.safe) <= 0.0


## The chain after a pop of colour col (-1: the rainbow, which keeps the chain's colour).
func _chain_pop(col: int, at: Vector3) -> void:
	var before: int = F.mult
	if frenzy() or col < 0 or col == int(F.chain_col):
		F.chain += 1
	else:
		if int(F.chain) >= 3:
			_sfx("squeak", 0.7, at)
		F.chain_col = col
		F.chain = 1
	F.chain_t = CHAIN_T
	F.best_chain = maxi(int(F.best_chain), int(F.chain))
	F.mult = multiplier(F.chain)
	if F.mult > before and F.mult > 1:
		var en := _en()
		var cname: String = ("GOLD" if en else "ذهبي") if frenzy() else (String(COLORS[int(F.chain_col)][2 if en else 1]) if int(F.chain_col) >= 0 else "")
		combo_label.text = ("%s ×%d!" % [cname, F.mult]) if en else ("%s ×%s!" % [cname, GameCtx.ar_digits(F.mult)])
		combo_label.modulate = chain_color()
		F.combo_t = 1.2
		F.combo_at = at
		_sfx("chime", 0.7, at)
		_buzz2(0.45, 50)
	if not frenzy() and int(F.chain) >= FRENZY_AT:
		start_frenzy(at)


## FRENZY: gold, slow motion, double points, fireworks.
func start_frenzy(at := Vector3.ZERO) -> void:
	F.frenzy_t = FRENZY_T
	F.frenzies += 1
	F.firework_t = 0.0
	var en := _en()
	banner.text = "FRENZY!" if en else "حمّى!"
	banner.modulate = GOLD
	banner_sub.text = "EVERY POP ×2" if en else "كل فرقعة ×٢"
	F.banner_t = 2.2
	F.banner_life = 2.2
	_sfx("whoosh", 1.0, banner_at())
	_sfx("boom", 0.6, banner_at())
	_sfx("firework_burst", 1.0, banner_at())
	_buzz2(1.0, 220)
	_ring(at, 0.3 * size, 3.5 * size, 0.7, GOLD)
	_firework(banner_at() + Vector3(-2.5, -0.5, 0) * size)
	_firework(banner_at() + Vector3(2.5, -0.3, 0) * size)
	_confetti(banner_at(), 1.4)
	if ctx:
		ctx.ch_progress.call("frenzy3", int(ctx.ch_state.get("frenzy3", 0)) + 1)


func _end_frenzy() -> void:
	F.chain = 0
	F.chain_col = -1
	F.mult = 1
	F.chain_t = 0.0
	_sfx("swish", 0.6, viewer)
	_buzz2(0.3, 60)


## Pops item i (a shot, a ball, a chain reaction or the rainbow) from direction dir.
func pop(i: int, dir := Vector3.FORWARD, cause := "shot") -> void:
	var it: Dictionary = items[i]
	if not it.on:
		return
	var kind: String = it.kind
	var col: int = it.col
	var p: Vector3 = it.p
	var r: float = float(it.r) * maxf(0.3, float(it.grow))
	var c := GOLD if frenzy() else color_of(col)
	it.on = false
	it.pop_t = -1.0
	(it.proxy as MeshInstance3D).visible = false
	F.popped += 1
	if ctx:
		ctx.tally.call("frenzy500", 1)
	# Effects: a shock ring, a spray of droplets in its colour and white.
	_ring(p, r * 0.9, r * (2.6 if kind != "big" else 2.0), 0.38, c)
	_spray(p, c, r, 10 if kind == "bubble" else (16 if kind == "dahrooj" else 30), dir)
	var snd: bool = float(F.snd_t) <= 0.0 or cause != "chain"
	if snd:
		F.snd_t = 0.035
		_sfx("start_pop", 1.0, p)
		if kind == "dahrooj":
			_sfx("squeak", 1.35 if _rng.randf() < 0.5 else 1.15, p)
		elif kind == "big":
			_sfx("splash", 0.6, p)
	if float(F.buzz_t) <= 0.0:
		F.buzz_t = 0.05
		_buzz2(0.2 if kind != "big" else 0.5, 22 if kind != "big" else 60)
	# The chain and the points.
	_chain_pop(col, p)
	var pts: int = int(KINDS[kind].pts) * int(F.mult) * (2 if frenzy() else 1)
	F.score += pts
	if ctx:
		ctx.counts["frenzy"] = int(ctx.counts.get("frenzy", 0)) + pts
	_pop_label(p + Vector3.UP * r * 0.6, "+" + _num(pts), c.lightened(0.25), 1.0 + 0.1 * (int(F.mult) - 1) + (0.25 if frenzy() else 0.0))
	# Same colours touching it go too (in FRENZY everything is gold).
	if col >= 0 or frenzy():
		for j in items.size():
			var o: Dictionary = items[j]
			if j == i or not hittable(o) or float(o.pop_t) >= 0.0 or o.kind == "rainbow":
				continue
			if not frenzy() and int(o.col) != col:
				continue
			if (o.p as Vector3).distance_to(p) < (float(o.r) + float(it.r)) * TOUCH_K:
				o.pop_t = CHAIN_DELAY
				o.pop_dir = ((o.p as Vector3) - p).normalized()
	match kind:
		"big":
			# The little ones inside spill out, and a few small bubbles with them.
			var kids: Array = it.kids
			for k in kids.size():
				var a: float = float(kids[k].ph)
				var out := Vector3(cos(a), 0.5 + 0.4 * sin(a * 2.0), sin(a)).normalized()
				var s := spawn("dahrooj", col, p + out * float(it.r) * 0.4, out * 2.2 * size)
				if s >= 0:
					items[s].grow = 0.6
					items[s].safe = 0.3
					items[s].style = kids[k].style
					items[s].acc = kids[k].acc
			for k in 2:
				var out := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.2, 1), _rng.randf_range(-1, 1)).normalized()
				var s := spawn("bubble", col, p + out * float(it.r) * 0.5, out * 1.8 * size)
				if s >= 0:
					items[s].grow = 0.5
					items[s].safe = 0.3
			_confetti(p, 0.6)
		"rainbow":
			rainbow_pop(p)
		"dahrooj":
			_stars(p, r)


## The rainbow: everything of the chain's colour (or the commonest one) pops, in a wave out
## from where the rainbow was.
func rainbow_pop(at: Vector3) -> int:
	var col: int = F.chain_col
	if col < 0:
		var tally := {}
		for it in items:
			if it.on and int(it.col) >= 0:
				tally[it.col] = int(tally.get(it.col, 0)) + 1
		var best := 0
		for k in tally:
			if int(tally[k]) > best:
				best = int(tally[k])
				col = int(k)
		F.chain_col = col
	var n := 0
	for it in items:
		if hittable(it) and it.kind != "rainbow" and (frenzy() or int(it.col) == col):
			it.pop_t = 0.06 + (it.p as Vector3).distance_to(at) * 0.035 / size
			it.pop_dir = ((it.p as Vector3) - at).normalized()
			n += 1
	_sfx("boom", 0.5, at)
	_sfx("chime", 1.0, at)
	_buzz2(0.8, 140)
	_ring(at, 0.4 * size, 6.0 * size, 0.9, color_of(col) if not frenzy() else GOLD)
	_confetti(at, 1.0)
	var en := _en()
	banner.text = "RAINBOW!" if en else "قوس قزح!"
	banner_sub.text = ("ALL %s" % String(COLORS[col][2])) if col >= 0 and en else (("كل الـ%s" % String(COLORS[col][1])) if col >= 0 else "")
	banner.modulate = color_of(col).lightened(0.2) if col >= 0 else GOLD
	F.banner_t = 1.5
	F.banner_life = 1.5
	return n


# ---- effects ----

func _spark(p: Vector3, v: Vector3, life: float, c: Color, s: float, g := 1.0, drag := 0.0) -> void:
	if _sparks.size() >= SPARKS_MAX:
		_sparks.pop_front()
	_sparks.append({"p": p, "v": v, "t": 0.0, "life": life, "c": c, "s": s, "g": g, "d": drag})


## Droplets flying out of a pop, a little more along the shot.
func _spray(at: Vector3, col: Color, r: float, count: int, dir: Vector3) -> void:
	for i in count:
		var d := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
		if d.length_squared() < 1e-4:
			d = Vector3.UP
		d = d.normalized()
		var p := at + d * r * 0.9
		var v := (d * _rng.randf_range(1.6, 4.2) + dir * 1.2) * size * (0.6 + r / size)
		var c := col if i % 3 != 0 else Color("fffaf2")
		_spark(p, v, _rng.randf_range(0.35, 0.7), c, _rng.randf_range(0.03, 0.065) * size, 0.55, 2.2)


## Little gold stars out of a popped Dahrooj.
func _stars(at: Vector3, r: float) -> void:
	for i in 6:
		var a := TAU * i / 6.0
		var v := Vector3(cos(a), 0.8, sin(a)) * 2.4 * size
		_spark(at + Vector3.UP * r * 0.5, v, 0.6, Color("ffe066"), 0.05 * size, 0.4, 1.5)


func _ring(at: Vector3, r0: float, r1: float, life: float, col: Color) -> void:
	if _rings.size() >= RINGS_MAX:
		_rings.pop_front()
	_rings.append({"p": at, "r0": r0, "r1": r1, "t": 0.0, "life": life, "c": col})


func _pop_label(at: Vector3, text: String, col: Color, k := 1.0) -> void:
	JuiceText.spawn(self, text, at, "points", k * size * _near_k(at + Vector3.UP * 0.5 * size), col)

## A firework: a rocket climbing to `at`, then a burst of gold and colours.
func _firework(at: Vector3) -> void:
	var from := Vector3(at.x + _rng.randf_range(-1, 1) * size, at.y - 3.0 * size, at.z)
	_rockets.append({"p": from, "to": at, "t": 0.0, "life": 0.45})
	_sfx("firework_launch", 0.6, from)


func _burst_firework(at: Vector3) -> void:
	var c1 := color_of(_rng.randi() % COLORS.size())
	for i in 46:
		var d := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
		if d.length_squared() < 1e-4:
			continue
		d = d.normalized()
		var c := GOLD if i % 2 == 0 else c1
		if i % 7 == 0:
			c = Color("fffaf2")
		_spark(at, d * _rng.randf_range(3.5, 5.0) * size, _rng.randf_range(0.8, 1.2), c, _rng.randf_range(0.045, 0.075) * size, 0.25, 1.6)
	_ring(at, 0.2 * size, 2.6 * size, 0.6, c1)
	_sfx("firework_burst", 0.8, at)


## Where the big words show: ahead, a little above the eye.
func banner_at() -> Vector3:
	var ahead := 4.6 * size
	if not _bounds.is_empty():
		ahead = clampf(viewer.z - float((_bounds.lo as Vector3).z) - 0.5 * size, 2.0 * size, ahead)
	return Vector3(viewer.x, viewer.y + 0.6 * size, viewer.z - ahead)  # under the HUD's score


# ---- moving ----

## The gentle currents: a slowly turning flow through the field (game units / s).
func current(p: Vector3) -> Vector3:
	var f := field()
	var lo: Vector3 = f.lo
	var hi: Vector3 = f.hi
	var c := (lo + hi) * 0.5
	var h := ((hi - lo) * 0.5).max(Vector3.ONE * 0.1)
	var u := (p - c) / h
	var T := time
	var flow := Vector3(
		sin(u.y * 1.9 + T * 0.21) + 0.6 * sin(u.z * 2.3 - T * 0.13),
		0.45 * sin(u.x * 2.1 + T * 0.17) + 0.3 * cos(u.z * 1.7 + T * 0.11),
		cos(u.x * 1.6 - T * 0.19) + 0.5 * sin(u.y * 2.6 + T * 0.23))
	var sp := lerpf(0.32, 0.75, heat()) * size
	return flow * sp


func _step_items(dt: float) -> void:
	var f := field()
	var lo: Vector3 = f.lo
	var hi: Vector3 = f.hi
	var n := items.size()
	# Pairs, on flat arrays: same colours drift together (they touch: chain reactions),
	# nobody overlaps.
	var P := PackedVector3Array()
	var R := PackedFloat32Array()
	var C := PackedInt32Array()
	P.resize(n)
	R.resize(n)
	C.resize(n)
	var live := PackedInt32Array()
	for i in n:
		var it: Dictionary = items[i]
		if it.on and float(it.delay) <= 0.0:
			P[i] = it.p
			R[i] = float(it.r) * maxf(0.2, float(it.grow))
			C[i] = int(it.col) if it.kind != "big" else -10 - int(it.col)
			live.append(i)
	var push := PackedVector3Array()
	push.resize(n)
	var reach := 2.6 * size
	for a in live.size():
		var i := live[a]
		for b in range(a + 1, live.size()):
			var j := live[b]
			var d := P[j] - P[i]
			var l2 := d.length_squared()
			var want := (R[i] + R[j]) * 1.02
			if l2 > reach * reach and l2 > want * want:
				continue
			var l := sqrt(l2)
			if l < 1e-4:
				continue
			var dn := d / l
			if l < want:
				var k := (want - l) * 4.0
				push[i] -= dn * k
				push[j] += dn * k
			elif C[i] == C[j] and C[i] >= 0:
				var k := 0.35 * size * (1.0 - l / reach)
				push[i] += dn * k
				push[j] -= dn * k
	for i in live:
		var it: Dictionary = items[i]
		var p: Vector3 = it.p
		var v: Vector3 = it.v
		var r: float = R[i]
		var acc := (current(p) - v) * 0.7 + push[i]
		# Keep to the field: a soft push back in near its sides.
		for ax in 3:
			var m := r + 0.2 * size
			if p[ax] < lo[ax] + m:
				acc[ax] += (lo[ax] + m - p[ax]) * 3.0
			elif p[ax] > hi[ax] - m:
				acc[ax] -= (p[ax] - hi[ax] + m) * 3.0
		# A little room around the player's head.
		var to := p - viewer
		var dl := to.length()
		var clear := 1.9 * size + r
		if dl < clear and dl > 1e-4:
			acc += to / dl * (clear - dl) * 6.0
		v += acc * dt
		p += v * dt
		# The ground (VR), soft.
		if _bounds.is_empty() and p.y < r:
			p.y = r
			if v.y < 0.0:
				v.y = -v.y * 0.6
		# Mixed reality: bounce softly off the real walls, ceiling, floor and furniture.
		for pl in _room:
			var pn: Vector3 = pl.normal
			var q: Vector3 = p - (pl.pos as Vector3)
			var dd := q.dot(pn)
			if dd >= r or dd < -r * 2.0:
				continue
			var hf: Vector2 = pl.half
			if absf(q.dot(pl.ax)) > hf.x + r * 0.5 or absf(q.dot(pl.ay)) > hf.y + r * 0.5:
				continue
			p += pn * (r - dd)
			var vn := v.dot(pn)
			if vn < 0.0:
				v -= pn * vn * 1.65
				it.wob = minf(1.0, float(it.wob) + minf(0.6, -vn / size * 0.5))
		it.p = p
		it.v = v
		# The rainbow twinkles.
		if it.kind == "rainbow" and _rng.randf() < 0.5:
			var d := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()
			_spark(p + d * r * 1.05, d * 0.4 * size + Vector3.UP * 0.3 * size, 0.6, color_of(_rng.randi() % COLORS.size()).lightened(0.3), 0.03 * size, 0.0, 1.0)


func _step_item(it: Dictionary, dt: float) -> void:
	if float(it.delay) > 0.0:
		it.delay = float(it.delay) - dt
		return
	it.t = float(it.t) + dt
	it.safe = maxf(0.0, float(it.safe) - dt)
	it.grow = minf(1.0, float(it.grow) + dt / 0.35)
	it.wob = maxf(0.0, float(it.wob) - dt * 1.6)
	it.spin = float(it.spin) + dt * 0.6
	it.blink_t = float(it.blink_t) - dt
	if float(it.blink_t) <= 0.0:
		it.blink = 0.13
		it.blink_t = _rng.randf_range(1.2, 3.2)
	it.blink = maxf(0.0, float(it.blink) - dt)


# ---- drawing ----

static func _back(k: float) -> float:
	var c := 2.0
	return 1.0 + (c + 1.0) * pow(k - 1.0, 3.0) + c * pow(k - 1.0, 2.0)


## Where an item is drawn: {p, s: radius, sq: wobble squash}.
func _pose(it: Dictionary) -> Dictionary:
	var g: float = clampf(float(it.grow), 0.0, 1.0)
	var e := _back(g) if g < 1.0 else 1.0
	var t: float = it.t
	var bob := sin(t * 1.3 + float(it.ph)) * 0.06 * float(it.r)
	var w: float = it.wob
	var wob := sin(t * 14.0 + float(it.ph)) * 0.18 * w + sin(t * 2.1 + float(it.ph)) * 0.025
	return {"p": (it.p as Vector3) + Vector3.UP * bob, "s": float(it.r) * maxf(0.001, e), "sq": Vector2(1.0 - wob * 0.5, 1.0 + wob)}


func _face(p: Vector3) -> Basis:
	var to := viewer - p
	if to.length_squared() < 1e-8:
		return Basis.IDENTITY
	var dn := to.normalized()
	return Basis.looking_at(dn, Vector3.UP if absf(dn.y) < 0.999 else Vector3.BACK, true)


## The colour an item shows (gold in FRENZY, fading in and out with F.gold).
func _show_col(it: Dictionary) -> Color:
	var c := color_of(int(it.col))
	return c.lerp(GOLD if it.kind != "dahrooj" else GOLD_BODY, float(F.gold)) if int(it.col) >= 0 else c


func draw() -> void:
	crowd.begin()
	var bm: MultiMesh = _mm.bubbles
	var nb := 0
	var cc: int = F.chain_col
	var fz := frenzy()
	for it in items:
		var proxy: MeshInstance3D = it.proxy
		if not it.on or float(it.delay) > 0.0:
			proxy.visible = false
			continue
		var pose := _pose(it)
		var p: Vector3 = pose.p
		var s: float = pose.s
		var sq: Vector2 = pose.sq
		proxy.visible = hittable(it)
		# The blaster's sphere: a little bigger than the bubble, so near misses still pop.
		proxy.transform = Transform3D(Basis.from_scale(Vector3.ONE * maxf(0.001, float(it.r) * 1.15 + 0.06 * size)), it.p)
		var kind: String = it.kind
		var col := _show_col(it)
		if kind == "dahrooj":
			var b := Basis(Vector3.UP, sin(float(it.t) * 0.9 + float(it.ph)) * 0.35) * _face(p)
			var xf := Transform3D(Basis.from_scale(Vector3(s * sq.x, s * sq.y, s * sq.x)) * b, p)
			_crowd_add(it.style, xf, "shut" if float(it.blink) > 0.0 else ("wide" if float(it.wob) > 0.3 else "open"), it.acc, col)
			continue
		var a := 1.0
		if kind == "rainbow":
			a = 0.5
		elif not fz and int(it.col) == cc and int(F.chain) > 0:
			a = 0.85
		bm.set_instance_transform(nb, Transform3D(Basis.from_scale(Vector3(s * sq.x, s * sq.y, s * sq.x)), p))
		bm.set_instance_color(nb, Color(col.srgb_to_linear(), a))
		nb += 1
		if kind == "big":
			# The little ones inside, bobbing round.
			var kids: Array = it.kids
			for k in kids.size():
				var ka: float = float(kids[k].ph) + float(it.t) * 0.5
				var kp := p + Vector3(cos(ka) * 0.42, sin(ka * 1.7) * 0.25 - 0.1, sin(ka) * 0.42) * s
				var kr := s * 0.27
				var kxf := Transform3D(Basis.from_scale(Vector3.ONE * kr) * _face(kp), kp)
				_crowd_add(kids[k].style, kxf, "open", kids[k].acc, col)
	bm.visible_instance_count = nb
	crowd.end()
	_bubble_mat.set_shader_parameter("gold", float(F.gold))
	_draw_fx()
	_draw_hands()
	_draw_labels()


## Crowd.add with our own transform.
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


func _draw_fx() -> void:
	var sp: MultiMesh = _mm.sparks
	var n := mini(_sparks.size(), SPARKS_MAX)
	for i in n:
		var s: Dictionary = _sparks[i]
		var k: float = 1.0 - float(s.t) / float(s.life)
		sp.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * float(s.s) * (0.35 + 0.65 * k)), s.p))
		sp.set_instance_color(i, Color((s.c as Color).srgb_to_linear(), clampf(k * 1.8, 0.0, 1.0)))
	sp.visible_instance_count = n
	var rings: MultiMesh = _mm.rings
	for i in _rings.size():
		var g: Dictionary = _rings[i]
		var k: float = clampf(float(g.t) / float(g.life), 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 3.0)
		var rad: float = lerpf(g.r0, g.r1, e)
		rings.set_instance_transform(i, Transform3D(_face(g.p) * Basis.from_scale(Vector3.ONE * rad), g.p))
		rings.set_instance_color(i, Color((g.c as Color).srgb_to_linear(), (1.0 - k) * 0.9))
	rings.visible_instance_count = _rings.size()
	# FRENZY: a faint warm gold around the head (comfortable: no flashes, slow pulse).
	var fl: MultiMesh = _mm.flash
	var gk: float = F.gold
	if gk > 0.01:
		fl.set_instance_transform(0, Transform3D(Basis.from_scale(Vector3.ONE * 0.9 * size), viewer))
		fl.set_instance_color(0, Color(Color("ffb820").srgb_to_linear(), gk * (0.09 + 0.03 * sin(time * 5.0))))
		fl.visible_instance_count = 1
	else:
		fl.visible_instance_count = 0


## The chain ring around each hand: a glowing halo in the chain's colour and ten beads, one lit
## per pop in the chain (how far to FRENZY); in FRENZY all of them gold, spinning.
func _draw_hands() -> void:
	var beads: MultiMesh = _mm.beads
	var halo: MultiMesh = _mm.halo
	var nb := 0
	var nh := 0
	var cc := chain_color()
	var chain: int = F.chain
	var fz := frenzy()
	var fade := clampf(float(F.chain_t) / 1.5, 0.0, 1.0) if not fz else 1.0
	for h in hands:
		var hv = hands[h]
		var xf: Transform3D
		if hv is Transform3D:
			xf = hv
		elif hv is Vector3:
			xf = Transform3D(_face(hv), hv)
		else:
			continue
		var b := xf.basis.orthonormalized()
		var o := xf.origin
		var rr := 0.17 * size
		var lit := mini(chain, BEADS) if not fz else BEADS
		var spin := time * (3.0 if fz else 0.6)
		var pulse := 1.0 + 0.12 * sin(time * 8.0) * (1.0 if chain > 0 else 0.0)
		if nh < 2:
			halo.set_instance_transform(nh, Transform3D(b * Basis.from_scale(Vector3(rr, rr, rr) * pulse), o))
			halo.set_instance_color(nh, Color(cc.srgb_to_linear(), (0.25 + 0.55 * fade) if chain > 0 or fz else 0.15))
			nh += 1
		for k in BEADS:
			if nb >= BEADS * 2:
				break
			var a := spin + TAU * k / BEADS
			var p := o + (b.x * cos(a) + b.y * sin(a)) * rr * pulse
			var on := k < lit
			var c := cc if on else Color("ffffff")
			var bs := (0.026 if on else 0.015) * size
			beads.set_instance_transform(nb, Transform3D(Basis.from_scale(Vector3.ONE * bs), p))
			beads.set_instance_color(nb, Color(c.srgb_to_linear(), (0.95 * maxf(0.35, fade)) if on else 0.3))
			nb += 1
	beads.visible_instance_count = nb
	halo.visible_instance_count = nh


## Words near the eye shrink (they keep about the same size in view as farther ones).
func _near_k(p: Vector3) -> float:
	return clampf(p.distance_to(viewer) / (6.0 * size), 0.3, 1.0)


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
		var s := (0.3 + 0.7 * inn) * over * (1.0 + out * 0.4) * size
		banner.position = banner_at() + Vector3.UP * out * 0.35 * size
		banner.scale = Vector3.ONE * s
		banner.modulate.a = 1.0 - out
		banner_sub.position = banner_at() + Vector3(0, -1.0, 0) * size + Vector3.UP * out * 0.35 * size
		banner_sub.scale = Vector3.ONE * minf(1.0, age / 0.5) * size
		banner_sub.modulate.a = 1.0 - out
	var ct: float = F.combo_t
	combo_label.visible = ct > 0.0
	if combo_label.visible:
		var a := 1.2 - ct
		combo_label.position = (F.combo_at as Vector3) + Vector3.UP * (0.9 + a * 0.5) * size
		combo_label.scale = Vector3.ONE * size * _near_k(combo_label.position) * (0.6 + 0.5 * minf(1.0, a * 6.0)) * (1.0 + 0.08 * sin(a * 30.0) * (1.0 - a))
		combo_label.modulate.a = clampf(ct / 0.3, 0.0, 1.0)


# ---- stage interface ----

func collide(S: Ball) -> void:
	if not S.shot:
		return
	var dir := S.vel.normalized() if S.vel.length_squared() > 0.0 else Vector3.FORWARD
	for i in items.size():
		var it: Dictionary = items[i]
		if not hittable(it):
			continue
		var r: float = float(it.r) * float(it.grow)
		if S.pos.distance_to(it.p) < Ball.BR + r:
			F.touched = true
			if it.kind == "dahrooj":
				# He bumps: a little nudge for the ball, a squeak and a pop.
				S.vel *= 0.94
			pop(i, dir, "ball")


func shoot(obj: Node, _point: Vector3, dir: Vector3) -> bool:
	for i in items.size():
		var it: Dictionary = items[i]
		if obj == it.proxy and hittable(it):
			pop(i, dir if dir != Vector3.ZERO else Vector3.FORWARD, "shot")
			return true
	return false


## FRENZY: the blaster fires a fan of three.
func shot_fan() -> int:
	return 3 if frenzy() else 1


## Music and sounds slow down with the game (main sets AudioServer.playback_speed_scale).
func audio_pitch() -> float:
	return 1.0 - (1.0 - time_scale) * 0.5


func touched() -> bool:
	return F.touched


func on_throw() -> void:
	pass


func on_respawn() -> void:
	F.touched = false


func deactivate() -> void:
	for it in items:
		it.on = false
		(it.proxy as MeshInstance3D).visible = false
	JuiceText.clear(self)
	_sparks.clear()
	_rings.clear()
	_rockets.clear()
	F.score = 0
	F.chain = 0
	F.chain_col = -1
	F.chain_t = 0.0
	F.mult = 1
	F.frenzy_t = 0.0
	F.gold = 0.0
	F.play_t = 0.0
	F.spawn_t = 0.0
	F.rainbow_t = 18.0
	F.filled = false
	F.touched = false
	F.banner_t = 0.0
	F.combo_t = 0.0
	time_scale = 1.0
	_room_t = 0.0
	draw()


func update(_b: Ball, dt: float) -> void:
	# Nothing moves while hidden or held by main.
	if not visible or paused:
		return
	# dt is game time (slowed by time_scale when main applies it); rdt ~ unslowed.
	var rdt := dt / maxf(time_scale, 0.05)
	time += dt
	F.play_t += rdt
	_follow = _follow.lerp(Vector3(viewer.x, 0, viewer.z), 1.0 - exp(-rdt * 0.5))
	_room_t -= rdt
	if _room_t <= 0.0:
		_room_t = 1.0
		_refresh_room()
	if auto_spawn and not F.filled:
		fill()
	# FRENZY: real seconds; time eases down to half speed and back.
	if F.frenzy_t > 0.0:
		F.frenzy_t = maxf(0.0, F.frenzy_t - rdt)
		if F.frenzy_t <= 0.0:
			_end_frenzy()
	var fz := frenzy()
	time_scale = move_toward(time_scale, FRENZY_SCALE if fz else 1.0, rdt * 2.5)
	F.gold = move_toward(F.gold, 1.0 if fz else 0.0, rdt * 2.5)
	if fz:
		F.firework_t -= rdt
		if F.firework_t <= 0.0:
			F.firework_t = _rng.randf_range(0.3, 0.55)
			var f := field()
			var lo: Vector3 = f.lo
			var hi: Vector3 = f.hi
			var at := Vector3(_rng.randf_range(lo.x, hi.x), _rng.randf_range(lerpf(lo.y, hi.y, 0.55), hi.y), _rng.randf_range(lo.z, minf(hi.z, viewer.z - 3.0 * size)))
			_firework(at)
	elif F.chain_t > 0.0:
		F.chain_t = maxf(0.0, F.chain_t - rdt)
		if F.chain_t <= 0.0:
			F.chain = 0
			F.mult = 1
	F.banner_t = maxf(0.0, F.banner_t - rdt)
	F.combo_t = maxf(0.0, F.combo_t - rdt)
	F.snd_t = maxf(0.0, F.snd_t - rdt)
	F.buzz_t = maxf(0.0, F.buzz_t - rdt)
	F.rainbow_t = maxf(0.0, F.rainbow_t - rdt)
	# Refill, without end.
	if auto_spawn:
		F.spawn_t -= rdt
		if F.spawn_t <= 0.0:
			F.spawn_t = lerpf(0.32, 0.14, heat())
			if alive() < target_count():
				spawn()
	# Chain reactions due.
	for i in items.size():
		var it: Dictionary = items[i]
		if it.on and float(it.pop_t) >= 0.0:
			it.pop_t = float(it.pop_t) - dt
			if float(it.pop_t) < 0.0:
				pop(i, it.pop_dir, "chain")
	for it in items:
		if it.on:
			_step_item(it, dt)
	# The floating, the effects and the drawing: about once a frame (update runs three times a frame).
	_acc += dt
	_racc += rdt
	if _racc >= 0.0125:
		var step := minf(_acc, 0.05)
		_acc = 0.0
		_racc = 0.0
		_step_items(step)
		_step_fx(step)
		draw()


func _step_fx(dt: float) -> void:
	for i in range(_sparks.size() - 1, -1, -1):
		var s: Dictionary = _sparks[i]
		s.t = float(s.t) + dt
		if float(s.t) >= float(s.life):
			_sparks.remove_at(i)
			continue
		var v: Vector3 = s.v
		v.y -= Ball.GRAV * float(s.g) * dt * size
		v *= exp(-float(s.d) * dt)
		s.v = v
		s.p = (s.p as Vector3) + v * dt
	for i in range(_rings.size() - 1, -1, -1):
		_rings[i].t = float(_rings[i].t) + dt
		if float(_rings[i].t) >= float(_rings[i].life):
			_rings.remove_at(i)
	for i in range(_rockets.size() - 1, -1, -1):
		var r: Dictionary = _rockets[i]
		r.t = float(r.t) + dt
		var k := clampf(float(r.t) / float(r.life), 0.0, 1.0)
		var e := 1.0 - (1.0 - k) * (1.0 - k)
		var to: Vector3 = r.to
		var p := Vector3(to.x, lerpf(to.y - 3.0 * size, to.y, e), to.z)
		r.p = p
		_spark(p, Vector3(_rng.randf_range(-0.3, 0.3), -1.0, _rng.randf_range(-0.3, 0.3)) * size, 0.3, Color("ffd27a"), 0.035 * size, 0.2, 1.0)
		if k >= 1.0:
			_burst_firework(to)
			_rockets.remove_at(i)


## For tests.
func frenzy_state() -> Dictionary:
	return {"score": F.score, "chain": F.chain, "chain_col": F.chain_col, "mult": F.mult, "frenzy": frenzy(),
		"frenzies": F.frenzies, "popped": F.popped, "alive": alive(), "colors": colors_in_play(), "heat": heat(),
		"target": target_count(), "time_scale": time_scale, "gold": F.gold, "room": not _bounds.is_empty()}
