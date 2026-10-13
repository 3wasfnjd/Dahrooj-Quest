class_name InvasionStage
extends Node3D
## Dahrooj Attack («هجوم الدحاريج», mode "invasion"): waves of mischievous Dahroojs hop toward
## the player from the far end of the court (VR: they drop out of the sky; mixed reality: they
## also burst out of the room's scanned walls and floor, like the mole holes). Stop them with
## blaster shots and thrown Dahroojs before they cross the line around you.
##
## - plain ones wobble and zig-zag; fast little ones dart; tanks take several hits and split
##   into two small ones; every 5th wave a boss (giant, crown, hit-points bar) that jumps and
##   slams: hit it 3 times in the air to knock it down (stunned, double damage), or it lands
##   with a shockwave, leaps closer and shakes out two little ones.
## - quick successive pops build a combo (×2 .. ×5).
## - popped ones may drop a power-up (a floating bubble): shoot or hit it to collect:
##   triple shot (shot_fan() = 3), slow motion (time_scale 0.4 for 4 s; main multiplies it into
##   the game dt and may lower the audio pitch with audio_pitch()), bomb (pops everything near).
## - open-ended: no hearts, no game over, no score board. One that reaches the line around you
##   just pops there (a red flash around the head, a buzz, the combo broken; the boss leaps
##   back instead); the waves keep coming. The points go to ctx.counts["invasion"], which the
##   jelly score popup shows; it starts on its own when the mode is shown.
## Game units, like the other stages. The blaster finds the invaders and power-ups through
## hidden (layers = 0) sphere MeshInstance3Ds; every effect is a MultiMesh or a JuiceText, so
## shots pass through them.

const KINDS := {
	# r: radius (game units, before `size`), hp, speed (× BASE_SPEED), hop period (s), hop height
	# (× r), zig-zag (lateral units/s), points, drop: chance of a power-up.
	"plain": {"r": 0.45, "hp": 1, "speed": 1.0, "hop": 0.62, "hop_h": 1.5, "zig": 1.1, "pts": 10, "drop": 0.1},
	"fast": {"r": 0.3, "hp": 1, "speed": 1.75, "hop": 0.36, "hop_h": 1.1, "zig": 2.2, "pts": 15, "drop": 0.12},
	"tank": {"r": 0.82, "hp": 3, "speed": 0.62, "hop": 0.95, "hop_h": 0.7, "zig": 0.35, "pts": 40, "drop": 0.35},
	"mini": {"r": 0.28, "hp": 1, "speed": 1.5, "hop": 0.34, "hop_h": 1.1, "zig": 1.6, "pts": 5, "drop": 0.04},
	"boss": {"r": 1.7, "hp": 18, "speed": 0.42, "hop": 1.25, "hop_h": 0.35, "zig": 0.0, "pts": 300, "drop": 1.0},
}
const BASE_SPEED := 2.1
const SLOTS := 40
const PU_SLOTS := 4
const SPAWN_Z := -24.0
const SPAWN_X := 7.0
const DROP_H := 11.0
const REACH := 2.4  # the line: this far from the player (× size)
const GROUND_FR := 0.22  # part of a hop spent on the ground
const BREAK_T := 2.8
const FIRST_BREAK_T := 2.4
const BANNER_T := 2.4
const COMBO_T := 1.5
const COMBO_STEPS := [3, 6, 10, 15]  # combo counts where the multiplier steps up (×2 .. ×5)
const TRIPLE_T := 8.0
const SLOW_T := 4.0
const SLOW_SCALE := 0.4
const BOMB_R := 5.5
const PU_LIFE := 7.5
const PU_R := 0.62
const BOSS_EVERY := 5
const AIR_HITS := 3
const BALL_DAMAGE := 2
const BANNER_AT := Vector3(0, 4.6, -8.0)  # (VR; it rises with a taller viewer, as in a room)
const SPARKS_MAX := 260
const RINGS_MAX := 12
const MARKS := 2  # the boss's landing marks, after the rings
const HOLES_MAX := 8
const DASHES := 56
const BARS_MAX := 36
const STARS_MAX := 24
const COLORS := ["ff69b4", "b36bff", "ff9b3d", "6fa8d6", "7bbf8a", "e2603f", "ffd166", "46aaa9", "58b9ff", "ff505c"]
const ACCS := ["", "", "party", "glasses", "cap", "flower", "headphones", "scarf"]
const PLAIN_STYLES := ["jelly", "fur", "clay", "fabric", "bubble", "jelly", "clay"]
const PU := {
	"triple": {"color": "ffb347", "ar": "طلقة ثلاثية", "en": "TRIPLE SHOT"},
	"slow": {"color": "7fd8ff", "ar": "تبطيء", "en": "SLOW-MO"},
	"bomb": {"color": "ff5a4a", "ar": "قنبلة", "en": "BOMB"},
}
const DIRT := ["7d5434", "9b6a42", "6b4429", "b08355"]

static var _meshes := {}

var aim_z := -10.0
## The pitch runs out to where they come from; the player stands near (reach_z = aim_z).
var far_z = SPAWN_Z - 1.0
var reach_z = -10.0
var friction = null
var shot_time = 4.0
var ctx: GameCtx

## Room spots (mixed reality), as MoleStage.spots_provider: Array of {pos, normal, kind?} in game
## units (RoomSpots: in front of the player, far). Every wave then comes out of the room there
## (and hops toward the player).
var spots_provider: Callable
## Size of the Dahroojs, the line and the power-ups (mixed reality wants them bigger).
var size := 1.0
## The player's eye (game units): they head for it and look at it. Main keeps it current.
var viewer := Vector3(0, 3.2, 1.0)
## Waves spawn on their own (tests turn it off and call spawn()).
var auto_spawn := true
## buzz(hand: String, amp: float, ms: float): haptics (main's buzz).
var buzz: Callable
## Slow motion: main multiplies this into the game dt.
var time_scale := 1.0
## Main holds the game while the menu is open or the court is being placed.
var paused := false
var time := 0.0

var F := {"state": "idle", "wave": 0, "score": 0, "breaches": 0,
	"combo": 0, "combo_t": 0.0, "mult": 1, "queue": [], "spawn_t": 0.0, "break_t": 0.0,
	"popped": 0, "touched": false, "triple_t": 0.0, "slow_t": 0.0, "flash_t": 0.0, "banner_t": 0.0, "banner_life": BANNER_T,
	"combo_show_t": 0.0, "combo_at": Vector3.ZERO, "cleared": 0, "danger": 0.0}
var invaders: Array = []
var powerups: Array = []
var crowd: Crowd
var banner: JuiceText
var banner_sub: JuiceText
var combo_label: JuiceText
var _sparks: Array = []
var _rings: Array = []
var _holes: Array = []
var _goal_s := Vector3(0, 0, 1.0)
## The room's spots, refreshed now and then (mixed reality).
var _room: Array = []
var _room_t := 0.0
var _draw_acc := 0.0
var _mm := {}
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 4242
	name = "Invasion"
	crowd = Crowd.new(SLOTS, true, true)
	crowd.name = "Invaders"
	add_child(crowd)
	for i in SLOTS:
		var proxy := _proxy("InvaderHit%d" % i)
		invaders.append({"on": false, "kind": "plain", "phase": "", "t": 0.0, "p": Vector3.ZERO, "c": Vector3.ZERO,
			"v": Vector3.ZERO, "r": 0.45, "hp": 1, "max_hp": 1, "speed": 1.0, "hop": 0.6, "hop_h": 1.0, "hop_u": 0.0,
			"y": 0.0, "zig": 0.0, "zig_f": 2.0, "zig_ph": 0.0, "style": "jelly", "color": "ff69b4", "acc": "",
			"sq": Vector2.ONE, "flash_t": 0.0, "hit_t": 0.0, "land_t": 0.0, "blink": 0.0, "blink_t": 1.0,
			"wob": 0.0, "act": "", "act_t": 0.0, "slam_cd": 3.0, "from": Vector3.ZERO, "to": Vector3.ZERO,
			"air_hits": 0, "ball_t": 0.0, "proxy": proxy, "n": Vector3.UP, "dir": Vector3.FORWARD})
	for i in PU_SLOTS:
		var lab := Panel3D.label("", 76, Color.WHITE)
		lab.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		lab.pixel_size = 0.006
		lab.outline_size = 14
		lab.outline_modulate = Color("1d2230")
		lab.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
		lab.visible = false
		add_child(lab)
		powerups.append({"on": false, "kind": "triple", "p": Vector3.ZERO, "v": Vector3.ZERO, "t": 0.0, "home_y": 2.6,
			"proxy": _proxy("PowerUpHit%d" % i), "label": lab, "spin": 0.0})
	_mm.sparks = _multi("Sparks", Crowd.merge([[Crowd.sphere(1.0, 6, 4), Transform3D.IDENTITY, Color.WHITE]]), _mat("glow"), SPARKS_MAX)
	_mm.rings = _multi("Rings", Crowd.merge([[Crowd.torus(1.0, 0.06, 6, 48), Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO), Color.WHITE]]), _mat("glow"), RINGS_MAX + MARKS)
	_mm.dashes = _multi("Line", Crowd.merge([[Crowd.box(1.0, 0.04, 1.0), Transform3D.IDENTITY, Color.WHITE]]), _mat("glow"), DASHES)
	_mm.shadows = _multi("Shadows", Crowd.merge([[Crowd.circle(1.0, 24), Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3.ZERO), Color.WHITE]]), _mat("shadow"), SLOTS + PU_SLOTS)
	_mm.bars = _multi("Bars", Crowd.merge([[Crowd.box(1.0, 1.0, 1.0), Transform3D.IDENTITY, Color.WHITE]]), _mat("flat"), BARS_MAX)
	_mm.holes = _multi("Holes", MoleStage.hole_mesh(), _mat("hole"), HOLES_MAX)
	_mm.stars = _multi("Stars", MoleStage.star_mesh(), _mat("flat2"), STARS_MAX)
	_mm.shells = _multi("Shells", Crowd.merge([[Crowd.sphere(1.0, 16, 12), Transform3D.IDENTITY, Color.WHITE]]), _mat("shell"), PU_SLOTS)
	_mm.halos = _multi("Halos", Crowd.merge([[Crowd.torus(1.0, 0.05, 6, 40), Transform3D.IDENTITY, Color.WHITE]]), _mat("glow"), PU_SLOTS)
	for k in PU:
		_mm["icon_" + k] = _multi("Icon_" + k, icon_mesh(k), _mat("flat"), PU_SLOTS)
	_mm.flash = _multi("Flash", Crowd.merge([[Crowd.sphere(1.0, 16, 10), Transform3D.IDENTITY, Color.WHITE]]), _mat("flash"), 1)
	banner = JuiceText.make("banner", 210 * 0.0062)
	banner.modulate = Color("ffd166")
	add_child(banner)
	banner_sub = JuiceText.make("sub", 96 * 0.0058)
	banner_sub.modulate = Color("fff3e0")
	add_child(banner_sub)
	combo_label = JuiceText.make("combo", 150 * 0.0058)
	add_child(combo_label)
	draw()


# ---- art ----

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


static func _mat(key: String) -> Material:
	if _meshes.has("mat_" + key):
		return _meshes["mat_" + key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	match key:
		"glow", "flat", "flat2":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			if key == "glow":
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			if key == "flat2":
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"shadow":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.render_priority = -1
		"shell":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.15
			m.metallic_specular = 0.9
			m.rim_enabled = true
			m.rim = 0.9
			m.rim_tint = 0.2
			m.emission_enabled = true
			m.emission = Color("332a3a")
			m.cull_mode = BaseMaterial3D.CULL_BACK
		"hole":
			m.roughness = 1.0
		"flash":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_FRONT  # seen from inside
			m.no_depth_test = true
			m.render_priority = 10
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
	mi.custom_aabb = AABB(Vector3(-60, -20, -60), Vector3(120, 60, 120))
	add_child(mi)
	return mm


## The power-ups' icons inside their bubbles (unit size, facing +Z): three shots in a fan,
## an hourglass, a bomb with its fuse.
static func icon_mesh(kind: String) -> ArrayMesh:
	if _meshes.has("icon_" + kind):
		return _meshes["icon_" + kind]
	var list := []
	match kind:
		"triple":
			for i in 3:
				var a := (i - 1) * 0.42
				var d := Vector3(sin(a), cos(a), 0)
				list.append([Crowd.sphere(0.13, 10, 8), Transform3D(Basis.IDENTITY, d * 0.32), Color("fff1c9")])
				list.append([Crowd.cylinder(0.05, 0.05, 0.3, 8), Transform3D(Basis(Vector3.BACK, -a), d * 0.08), Color("ffb347")])
			list.append([Crowd.sphere(0.1, 10, 8), Transform3D(Basis.IDENTITY, Vector3(0, -0.12, 0)), Color("ff8a3d")])
		"slow":
			list.append([Crowd.cylinder(0.3, 0.03, 0.34, 16), Transform3D(Basis.IDENTITY, Vector3(0, 0.19, 0)), Color("d9f4ff")])
			list.append([Crowd.cylinder(0.03, 0.3, 0.34, 16), Transform3D(Basis.IDENTITY, Vector3(0, -0.19, 0)), Color("d9f4ff")])
			list.append([Crowd.cylinder(0.18, 0.03, 0.18, 16), Transform3D(Basis.IDENTITY, Vector3(0, -0.27, 0)), Color("ffd166")])
			for y in [0.4, -0.4]:
				list.append([Crowd.cylinder(0.36, 0.36, 0.07, 18), Transform3D(Basis.IDENTITY, Vector3(0, y, 0)), Color("5a8bd6")])
			for x in [-0.3, 0.3]:
				list.append([Crowd.cylinder(0.03, 0.03, 0.8, 6), Transform3D(Basis.IDENTITY, Vector3(x, 0, 0.12)), Color("5a8bd6")])
		"bomb":
			list.append([Crowd.sphere(0.34, 16, 12), Transform3D(Basis.IDENTITY, Vector3(0, -0.06, 0)), Color("2c2d3d")])
			list.append([Crowd.sphere(0.08, 8, 6), Transform3D(Basis.IDENTITY, Vector3(-0.12, 0.06, 0.28)), Color("8a8fa8")])
			list.append([Crowd.cylinder(0.11, 0.11, 0.1, 12), Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 0)), Color("5a5d70")])
			list.append([Crowd.cylinder(0.025, 0.025, 0.22, 6), Transform3D(Basis(Vector3.BACK, -0.5), Vector3(0.06, 0.43, 0)), Color("e8d2a8")])
			list.append([Crowd.sphere(0.07, 8, 6), Transform3D(Basis.IDENTITY, Vector3(0.12, 0.53, 0)), Color("ffd23f")])
	var mesh := Crowd.merge(list)
	_meshes["icon_" + kind] = mesh
	return mesh


func _num(v: int) -> String:
	return str(v) if _en() else GameCtx.ar_digits(v)


func _en() -> bool:
	return ctx != null and ctx.lang == "en"


# ---- ctx ----

func _sfx(n: String, k: float, p: Vector3) -> void:
	if ctx:
		ctx.sfx.call(n, k, p)


func _confetti(at: Vector3, k := 1.0) -> void:
	if ctx:
		ctx.confetti.call(at, 1.2 * k, 1.4, maxf(1.0, at.distance_to(viewer) / 7.0))


func _buzz(hand: String, amp: float, ms: float) -> void:
	if buzz.is_valid():
		buzz.call(hand, amp, ms)


func _buzz2(amp: float, ms: float) -> void:
	_buzz("left", amp, ms)
	_buzz("right", amp, ms)


# ---- the game ----

## Where they head for: the player's spot on the ground (smoothed, so the line doesn't shake).
func goal() -> Vector3:
	return _goal_s


func reach_r() -> float:
	return REACH * size


## Where the wave banner shows: ahead, a little above the eye.
func banner_at() -> Vector3:
	return Vector3(BANNER_AT.x, maxf(BANNER_AT.y, viewer.y + 1.4), BANNER_AT.z)


func start() -> void:
	for m in invaders:
		if m.on:
			_burst(m.c, Color(m.color), 10, 0.8)
			m.on = false
	F.state = "break"
	F.wave = 0
	F.score = 0
	F.breaches = 0
	F.combo = 0
	F.combo_t = 0.0
	F.mult = 1
	F.popped = 0
	F.cleared = 0
	F.triple_t = 0.0
	F.slow_t = 0.0
	F.queue = []
	_sfx("whoosh", 0.8, banner_at())
	_next_wave()


func _next_wave() -> void:
	F.wave += 1
	F.state = "break"
	F.break_t = FIRST_BREAK_T if F.wave == 1 else BREAK_T
	F.queue = wave_plan(F.wave)
	F.spawn_t = 0.0
	var boss: bool = F.wave % BOSS_EVERY == 0
	var en := _en()
	_banner(("WAVE %d" % F.wave) if en else ("الموجة " + GameCtx.ar_digits(F.wave)),
		("THE BOSS IS COMING!" if en else "الزعيم قادم!") if boss else ("GET READY!" if en else "استعد!"),
		Color("ff6b5a") if boss else Color("ffd166"))
	_sfx("swish", 0.6, banner_at())
	if boss:
		_sfx("boom", 0.6, banner_at())
		_buzz2(0.5, 120)


func _banner(text: String, sub: String, color: Color) -> void:
	banner.text = text
	banner.modulate = color
	banner_sub.text = sub
	_banner_for(BANNER_T)


func _banner_for(secs: float) -> void:
	F.banner_t = secs
	F.banner_life = secs


## The kinds of wave n, in spawn order (the boss first on a boss wave).
func wave_plan(n: int) -> Array:
	var out: Array = []
	var boss := n % BOSS_EVERY == 0
	var count := mini(4 + n * 2, 30)
	if boss:
		count = int(count * 0.5)
	for _i in count:
		var r := _rng.randf()
		var k := "plain"
		if n >= 3 and r < minf(0.08 + n * 0.015, 0.24):
			k = "tank"
		elif n >= 2 and r < minf(0.3 + n * 0.03, 0.55):
			k = "fast"
		out.append(k)
	if boss:
		out.insert(0, "boss")
	return out


## Speed of wave n (× BASE_SPEED).
static func wave_speed(n: int) -> float:
	return minf(1.0 + 0.065 * maxf(0.0, n - 1.0), 1.9)


func _alive() -> int:
	var n := 0
	for m in invaders:
		if m.on:
			n += 1
	return n


func _boss() -> Dictionary:
	for m in invaders:
		if m.on and m.kind == "boss":
			return m
	return {}


func _wave_cap() -> int:
	return mini(6 + F.wave, SLOTS - 6)


func _step_waves(dt: float, rdt: float) -> void:
	match F.state:
		"idle":
			# Open play: the waves start on their own as soon as the mode is shown.
			if auto_spawn:
				start()
		"break":
			F.break_t -= rdt
			if F.break_t <= 0.0:
				F.state = "wave"
				F.spawn_t = 0.2
		"wave":
			if auto_spawn and not (F.queue as Array).is_empty():
				F.spawn_t -= dt
				if F.spawn_t <= 0.0 and _alive() < _wave_cap():
					var pack := 1
					if F.wave >= 4 and _rng.randf() < 0.22:
						pack = _rng.randi_range(2, 3)
					for _k in pack:
						if (F.queue as Array).is_empty():
							break
						var kind: String = (F.queue as Array).pop_front()
						spawn(kind)
					F.spawn_t = maxf(0.32, 1.25 - 0.07 * F.wave) * _rng.randf_range(0.65, 1.3)
			if (F.queue as Array).is_empty() and _alive() == 0:
				_wave_cleared()


func _wave_cleared() -> void:
	F.cleared = F.wave
	if ctx:
		ctx.ch_progress.call("invasion10", F.wave)
	_sfx("chime", 1.0, banner_at())
	_sfx("firework_burst", 0.8, banner_at())
	_confetti(banner_at() + Vector3(0, 0.5, 0), 1.6)
	_buzz2(0.35, 60)
	_next_wave()


## One got through to the line: it pops there with a red flash around the head and a buzz,
## and the combo breaks. Nothing else is lost; the game goes on.
func _breach(at: Vector3) -> void:
	F.breaches += 1
	F.flash_t = 0.5
	F.combo = 0
	F.mult = 1
	F.combo_t = 0.0
	_sfx("boom", 0.8, at)
	_sfx("squeak", 0.7, at)
	_buzz2(1.0, 160)
	_burst(at + Vector3.UP * 0.5 * size, Color("ff3d63"), 22, 1.4)
	_ring(Vector3(at.x, 0.05, at.z), 0.3 * size, 3.0 * size, 0.5, Color("ff3d63"))


# ---- spawning ----

func _spots() -> Array:
	return RoomSpots.ask(spots_provider)


## Starts an invader; returns its slot or -1. spot: {} (the far end, or a room spot), or
## {pos, normal} — on the ground with normal UP it marches straight away (tests), "drop": true
## drops it from the sky there, "idle": true makes it dance in place.
func spawn(kind: String, spot := {}) -> int:
	var slot := -1
	for i in invaders.size():
		if not invaders[i].on:
			slot = i
			break
	if slot < 0:
		return -1
	var m: Dictionary = invaders[slot]
	var K: Dictionary = KINDS[kind]
	m.on = true
	m.kind = kind
	m.r = float(K.r) * size
	m.hp = int(K.hp)
	if kind == "tank":
		m.hp += int(F.wave / 4.0)
	if kind == "boss":
		m.hp += 8 * maxi(0, int(F.wave / float(BOSS_EVERY)) - 1)
	m.max_hp = m.hp
	m.speed = float(K.speed) * BASE_SPEED * wave_speed(maxi(1, F.wave)) * _rng.randf_range(0.9, 1.1)
	m.hop = float(K.hop) * _rng.randf_range(0.9, 1.1)
	m.hop_h = float(K.hop_h)
	m.hop_u = _rng.randf()
	m.zig = float(K.zig) * _rng.randf_range(0.6, 1.3) * (1.0 if _rng.randf() < 0.75 else 0.2)
	m.zig_f = _rng.randf_range(1.4, 2.8)
	m.zig_ph = _rng.randf() * TAU
	m.wob = _rng.randf() * TAU
	m.flash_t = 0.0
	m.hit_t = 0.0
	m.land_t = 0.0
	m.blink = 0.0
	m.blink_t = _rng.randf_range(0.5, 2.0)
	m.act = ""
	m.act_t = 0.0
	m.slam_cd = 3.5
	m.air_hits = 0
	m.ball_t = 0.0
	m.y = 0.0
	m.sq = Vector2.ONE
	m.v = Vector3.ZERO
	match kind:
		"fast":
			m.style = "jelly"
			m.color = ["ffdf45", "58db83", "ff69b4", "58b9ff"][_rng.randi() % 4]
			m.acc = "party"
		"tank":
			m.style = "clay"
			m.color = "6a55d8"
			m.acc = "cap" if _rng.randf() < 0.5 else "headphones"
		"mini":
			m.style = "fur" if _rng.randf() < 0.5 else "jelly"
			m.color = "b9a8ff"
			m.acc = ""
		"boss":
			m.style = "fur"
			m.color = "e2503f"
			m.acc = "crown"
		_:
			m.style = PLAIN_STYLES[_rng.randi() % PLAIN_STYLES.size()]
			m.color = COLORS[_rng.randi() % COLORS.size()] if _rng.randf() < 0.75 else Crowd.DAHROOJ_COLORS[m.style]
			m.acc = ACCS[_rng.randi() % ACCS.size()]
	# Mixed reality: out of the room in front of the player (RoomSpots): through a hole in a
	# wall, the floor or a piece of furniture; a spot in the air (no scan) or the boss drops
	# from above there instead.
	var room := _spots() if spot.is_empty() else []
	if not room.is_empty():
		var s: Dictionary = room[_rng.randi() % room.size()]
		var sp: Vector3 = s.pos
		if kind == "boss" or str(s.get("kind", "")) == "air":
			spot = {"pos": Vector3(sp.x, 0, sp.z), "normal": Vector3.UP, "drop": true}
		else:
			spot = {"pos": sp, "normal": s.normal, "emerge": true}
	if spot.is_empty():
		var x := _rng.randf_range(-SPAWN_X, SPAWN_X) * (0.3 if kind == "boss" else 1.0)
		spot = {"pos": Vector3(x, 0, SPAWN_Z + _rng.randf_range(-1.5, 1.5)), "normal": Vector3.UP, "drop": true}
	var n0: Vector3 = spot.get("normal", Vector3.UP)
	var n := n0.normalized() if n0.length_squared() > 1e-6 else Vector3.UP
	var at: Vector3 = spot.pos
	m.n = n
	m.t = 0.0
	if spot.get("emerge", false):
		m.phase = "emerge"
		m.p = at
		m.c = at
		_hole(at, n)
		_dirt(at, n, 10, 1.0)
		_sfx("thump", 0.5, at)
	elif spot.get("drop", false):
		m.phase = "drop"
		m.p = Vector3(at.x, 0, at.z)
		m.c = Vector3(at.x, DROP_H * (1.6 if kind == "boss" else 1.0), at.z)
		m.v = Vector3(0, -2.0, 0)
		_ring(Vector3(at.x, 0.04, at.z), m.r * 2.4, m.r * 1.0, 0.6, Color("ffcf6b") if kind != "boss" else Color("ff5a3a"))
	elif spot.get("idle", false):
		m.phase = "idle"
		m.p = Vector3(at.x, 0, at.z)
		m.c = m.p + Vector3.UP * float(m.r)
	else:
		m.phase = "march"
		m.p = Vector3(at.x, 0, at.z)
		m.c = m.p + Vector3.UP * float(m.r)
	if kind == "boss":
		_sfx("boom", 0.5, at)
	_place(m)
	return slot


# ---- effects ----

func _spark(p: Vector3, v: Vector3, life: float, c: Color, s: float, g := 1.0, floor_y := -INF) -> void:
	if _sparks.size() >= SPARKS_MAX:
		_sparks.pop_front()
	_sparks.append({"p": p, "v": v, "t": 0.0, "life": life, "c": c, "s": s, "g": g, "floor": floor_y})


## A pop: a puff of sparks in its colour and white, flying every way.
func _burst(at: Vector3, col: Color, count: int, k: float) -> void:
	for i in count:
		var a := _rng.randf() * TAU
		var e := _rng.randf_range(-0.5, 1.2)
		var sp := _rng.randf_range(2.0, 5.5) * k * size
		var v := Vector3(cos(a) * cos(e), sin(e), sin(a) * cos(e)) * sp + Vector3.UP * 1.5 * size
		var c := col if i % 3 != 0 else Color("fffaf2")
		if i % 5 == 4:
			c = Color("ffd23f")
		_spark(at, v, _rng.randf_range(0.4, 0.8), c, _rng.randf_range(0.05, 0.11) * k * size, 0.6, 0.02)


func _dirt(at: Vector3, n: Vector3, count: int, k: float) -> void:
	var b := MoleStage.basis_up(n)
	for i in count:
		var a := _rng.randf() * TAU
		var out := b.x * cos(a) + b.z * sin(a)
		var v := (out * _rng.randf_range(1.2, 3.0) + n * _rng.randf_range(2.5, 5.0)) * k * size
		_spark(at + out * 0.3 * size + n * 0.1, v, _rng.randf_range(0.5, 0.85), Color(DIRT[_rng.randi() % DIRT.size()]), _rng.randf_range(0.05, 0.1) * size, 1.0, 0.03)


func _ring(at: Vector3, r0: float, r1: float, life: float, col: Color) -> void:
	if _rings.size() >= RINGS_MAX:
		_rings.pop_front()
	_rings.append({"p": at, "r0": r0, "r1": r1, "t": 0.0, "life": life, "c": col})


func _hole(at: Vector3, n: Vector3) -> void:
	if _holes.size() >= HOLES_MAX:
		_holes.pop_front()
	_holes.append({"p": at, "n": n, "t": 0.0, "spin": _rng.randf() * TAU})


func _pop_label(at: Vector3, text: String, col: Color, k := 1.0) -> void:
	JuiceText.spawn(self, text, at, "points", k * size, col)


# ---- hits ----

static func hittable(m: Dictionary) -> bool:
	return m.on and m.phase != "" and not (m.phase == "emerge" and m.t < 0.18)


## A hit on invader m (n points of damage) from direction dir. Returns whether it counted.
func damage(m: Dictionary, n: int, dir: Vector3, by_ball := false) -> bool:
	if not hittable(m):
		return false
	if m.phase == "idle":
		pop(m, dir, false)
		if F.state == "idle":
			start()
		return true
	var c: Vector3 = m.c
	m.flash_t = 0.1
	m.hit_t = 0.28
	m.dir = dir
	if m.kind == "boss":
		if m.act == "air":
			m.air_hits += 1
			_pop_label(c + Vector3.UP * float(m.r) * 1.3, "%s/%s" % [_num(m.air_hits), _num(AIR_HITS)], Color("ffd23f"), 1.2)
			if m.air_hits >= AIR_HITS:
				_knock_down(m)
		elif m.act == "stun":
			n *= 2
	m.hp -= n
	_burst(c + (-dir * float(m.r) * 0.8), Color(m.color), 6, 0.6)
	_sfx("thump", 0.6 if by_ball else 0.35, c)
	if m.hp <= 0:
		pop(m, dir, true)
		return true
	_sfx("squeak", 0.7 if m.kind in ["tank", "boss"] else 1.15, c)
	_score(5, c + Vector3.UP * float(m.r), false)
	_buzz("left", 0.25, 25)
	_buzz("right", 0.25, 25)
	return true


func _knock_down(m: Dictionary) -> void:
	m.act = "fall"
	m.act_t = 0.0
	m.v = Vector3(0, -2.0, 0)
	var c: Vector3 = m.c
	_sfx("boom", 0.5, c)
	_sfx("squeak", 0.7, c)
	_burst(c, Color("ffd23f"), 24, 1.4)
	_buzz2(0.7, 90)
	_banner("KNOCKED DOWN!" if _en() else "أسقطته!", "DOUBLE DAMAGE" if _en() else "الضرر مضاعف", Color("ffd23f"))
	_banner_for(1.4)


## Points (× the combo multiplier) with a floating label; count = a pop that feeds the combo.
func _score(base: int, at: Vector3, count: bool) -> void:
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
		ctx.counts["invasion"] = int(ctx.counts.get("invasion", 0)) + pts
	var txt := "+" + _num(pts)
	_pop_label(at, txt, Color("ffe08a") if F.mult <= 1 else Color("ff8ad8"), 1.0 + 0.12 * (F.mult - 1))


static func multiplier(combo: int) -> int:
	var m := 1
	for s in COMBO_STEPS:
		if combo >= int(s):
			m += 1
	return m


## Pops invader m: points, sparks, a split for a tank, maybe a power-up.
func pop(m: Dictionary, dir: Vector3, scored := true) -> void:
	var c: Vector3 = m.c
	var kind: String = m.kind
	var K: Dictionary = KINDS[kind]
	m.on = false
	(m.proxy as MeshInstance3D).visible = false
	_burst(c, Color(m.color), 26 if kind in ["tank", "boss"] else 16, 1.0 + float(m.r) / size * 0.4)
	_sfx("start_pop", 1.0, c)
	_sfx("squeak", 1.35 if kind in ["fast", "mini"] else (0.7 if kind in ["tank", "boss"] else 1.0), c)
	_buzz("left", 0.35, 35)
	_buzz("right", 0.35, 35)
	if not scored:
		return
	F.popped += 1
	_score(int(K.pts), c + Vector3.UP * float(m.r), true)
	if ctx:
		ctx.ch_progress.call("pop20", int(ctx.ch_state.get("pop20", 0)) + 1)
	match kind:
		"tank":
			_sfx("boom", 0.4, c)
			_ring(Vector3(c.x, 0.05, c.z), 0.3 * size, 2.2 * size, 0.4, Color(m.color))
			var side := Vector3(-dir.z, 0, dir.x).normalized() if Vector2(dir.x, dir.z).length() > 0.01 else Vector3.RIGHT
			for s in [-1.0, 1.0]:
				var i := spawn("mini", {"pos": Vector3(c.x, 0, c.z) + side * s * 0.6 * size, "normal": Vector3.UP})
				if i >= 0:
					var q: Dictionary = invaders[i]
					q.phase = "leap"
					q.c = Vector3(c.x, c.y, c.z) + side * s * 0.3 * size
					q.v = (side * s * 2.5 + Vector3.UP * 5.0) * size
		"boss":
			_sfx("boom", 1.0, c)
			_sfx("firework_burst", 1.0, c)
			_ring(Vector3(c.x, 0.05, c.z), 0.5 * size, 7.0 * size, 0.8, Color("ffd23f"))
			_burst(c, Color("ffd23f"), 40, 2.0)
			_confetti(c + Vector3.UP, 2.0)
			_buzz2(1.0, 200)
			_banner("BOSS DOWN!" if _en() else "هزمت الزعيم!", "+%s" % _num(int(K.pts) * int(F.mult)), Color("ffd23f"))
			_banner_for(1.8)
			drop_powerup("bomb" if _rng.randf() < 0.5 else "triple", c + Vector3(-1.0, 0.5, 0) * size)
			drop_powerup("slow", c + Vector3(1.0, 0.5, 0) * size)
			return
	if _rng.randf() < float(K.drop):
		var keys := PU.keys()
		drop_powerup(keys[_rng.randi() % keys.size()], c)


## A thing reached the line around the player.
func _reach(m: Dictionary) -> void:
	var c: Vector3 = m.c
	if m.kind == "boss":
		_breach(c)
		# He laughs and leaps back to the far end.
		m.act = "retreat"
		m.act_t = 0.0
		m.from = m.p
		m.to = Vector3(m.p.x * 0.5, 0, SPAWN_Z + 2.0)
		return
	m.on = false
	(m.proxy as MeshInstance3D).visible = false
	_burst(c, Color(m.color), 14, 0.9)
	_sfx("start_pop", 0.8, c)
	_breach(c)


# ---- power-ups ----

func drop_powerup(kind: String, at: Vector3) -> int:
	for i in powerups.size():
		var u: Dictionary = powerups[i]
		if u.on:
			continue
		u.on = true
		u.kind = kind
		u.p = at
		u.v = Vector3(_rng.randf_range(-1.0, 1.0), 6.0, _rng.randf_range(-0.5, 1.0)) * size
		u.t = 0.0
		u.spin = _rng.randf() * TAU
		u.home_y = clampf(viewer.y + _rng.randf_range(-1.0, 0.2) * size, 1.6 * size, maxf(4.0 * size, viewer.y))
		var info: Dictionary = PU[kind]
		(u.label as Label3D).text = str(info.en) if _en() else str(info.ar)
		(u.label as Label3D).modulate = Color(info.color)
		_sfx("whoosh", 0.4, at)
		return i
	return -1


func collect(i: int) -> void:
	var u: Dictionary = powerups[i]
	if not u.on:
		return
	u.on = false
	(u.proxy as MeshInstance3D).visible = false
	(u.label as Label3D).visible = false
	var at: Vector3 = u.p
	var info: Dictionary = PU[u.kind]
	_burst(at, Color(info.color), 20, 1.0)
	_sfx("chime", 0.8, at)
	_buzz2(0.5, 70)
	_score(20, at + Vector3.UP * 0.4 * size, false)
	_banner(str(info.en) + "!" if _en() else str(info.ar) + "!", "", Color(info.color))
	_banner_for(1.3)
	match u.kind:
		"triple":
			F.triple_t = TRIPLE_T
			_sfx("pew", 0.6, at)
		"slow":
			F.slow_t = SLOW_T
			_sfx("whoosh", 1.0, at)
		"bomb":
			bomb(at)


## Everything within BOMB_R (× size, across the ground) of `at` pops; the boss takes 6.
func bomb(at: Vector3) -> int:
	var n := 0
	var rr := BOMB_R * size
	_sfx("boom", 1.0, at)
	_sfx("firework_burst", 1.0, at)
	_buzz2(1.0, 180)
	_ring(Vector3(at.x, 0.06, at.z), 0.4 * size, rr, 0.55, Color("ff7a3d"))
	_ring(at, 0.2 * size, rr * 0.7, 0.35, Color("ffd23f"))
	_burst(at, Color("ff7a3d"), 40, 2.2)
	_confetti(at, 1.4)
	for m in invaders:
		if not m.on or not hittable(m):
			continue
		var c: Vector3 = m.c
		if Vector2(c.x - at.x, c.z - at.z).length() > rr + float(m.r):
			continue
		var d := Vector3(c.x - at.x, 0, c.z - at.z).normalized()
		if m.kind == "boss":
			damage(m, 6, d)
		elif m.kind == "tank":
			m.hp = 0
			damage(m, 1, d)
		else:
			pop(m, d, true)
		n += 1
	return n


## Triple shot: the blaster fires this many shots in a fan.
func shot_fan() -> int:
	return 3 if F.triple_t > 0.0 else 1


## Music and sounds slow down with the game (main may set AudioServer.playback_speed_scale).
func audio_pitch() -> float:
	return 1.0 - (1.0 - time_scale) * 0.5


# ---- moving ----

func _step_invader(m: Dictionary, dt: float) -> void:
	m.t += dt
	m.flash_t = maxf(0.0, m.flash_t - dt)
	m.hit_t = maxf(0.0, m.hit_t - dt)
	m.land_t = maxf(0.0, m.land_t - dt)
	m.ball_t = maxf(0.0, m.ball_t - dt)
	m.blink_t -= dt
	if m.blink_t <= 0.0:
		m.blink = 0.12
		m.blink_t = _rng.randf_range(1.0, 2.6)
	m.blink = maxf(0.0, m.blink - dt)
	var r: float = m.r
	var G := Ball.GRAV * 0.9
	match m.phase:
		"emerge":
			# Out of the wall (or floor) along its normal, then a leap into the room.
			var n: Vector3 = m.n
			var k := clampf(m.t / 0.32, 0.0, 1.0)
			m.c = (m.p as Vector3) + n * r * (k * 1.1 - 0.2)
			m.sq = Vector2(1.0 - 0.2 * sin(PI * k), 1.0 + 0.3 * sin(PI * k))
			if k >= 1.0:
				m.phase = "leap"
				var to := goal() - (m.c as Vector3)
				to.y = 0.0
				m.v = n * 1.8 * size + Vector3.UP * 2.6 * size + to.normalized() * 0.9 * size
				_dirt(m.p, n, 8, 1.2)
				_sfx("swish", 0.4, m.c)
		"drop", "leap":
			m.v.y -= G * dt
			m.c += (m.v as Vector3) * dt
			m.sq = Vector2(0.88, 1.18) if m.v.y < -3.0 else Vector2.ONE
			if m.c.y <= r and m.v.y < 0.0:
				_land(m)
		"idle":
			_hop(m, dt, false)
		"march":
			if m.kind == "boss" and _boss_act(m, dt):
				pass
			else:
				_hop(m, dt, true)
	_place(m)


func _land(m: Dictionary) -> void:
	var r: float = m.r
	m.p = Vector3(m.c.x, 0, m.c.z)
	m.c = Vector3(m.c.x, r, m.c.z)
	m.v = Vector3.ZERO
	m.phase = "march"
	m.land_t = 0.25
	m.hop_u = 0.0
	m.y = 0.0
	var heavy: bool = m.kind in ["tank", "boss"]
	_dirt(m.p, Vector3.UP, 12 if heavy else 5, 0.9 if heavy else 0.6)
	_ring(Vector3(m.c.x, 0.04, m.c.z), r * 0.8, r * (4.0 if m.kind == "boss" else 2.2), 0.4, Color("e8d2a8"))
	_sfx("thump", 1.0 if heavy else 0.4, m.p)
	if m.kind == "boss":
		_sfx("boom", 0.6, m.p)
		_buzz2(0.6, 120)


## A hop cycle: a squash on the ground, then a bouncy arc forward (march) or in place.
func _hop(m: Dictionary, dt: float, march: bool) -> void:
	var r: float = m.r
	m.hop_u += dt / float(m.hop)
	if m.hop_u >= 1.0:
		m.hop_u -= 1.0
		if m.kind in ["tank", "boss"] and march:
			_sfx("thump", 0.5 if m.kind == "tank" else 0.9, m.p)
	var u: float = m.hop_u
	if u < GROUND_FR:
		var k := u / GROUND_FR
		m.y = 0.0
		m.sq = Vector2(1.0 + 0.22 * sin(PI * k), 1.0 - 0.3 * sin(PI * k))
	else:
		var k := (u - GROUND_FR) / (1.0 - GROUND_FR)
		m.y = float(m.hop_h) * r * 4.0 * k * (1.0 - k)
		var st := maxf(0.0, 1.0 - k * 3.0)
		m.sq = Vector2(1.0 - 0.1 * st, 1.0 + 0.18 * st)
		if march:
			var g := goal()
			var to := Vector3(g.x - m.p.x, 0, g.z - m.p.z)
			var dist := to.length()
			var d := to / dist if dist > 1e-4 else Vector3.BACK
			var s := Vector3(-d.z, 0, d.x)
			var lat: float = m.zig * sin(time * float(m.zig_f) + float(m.zig_ph))
			# Keep to the court in VR.
			if _room.is_empty() and absf(m.p.x) > SPAWN_X + 1.0:
				lat = -signf(m.p.x * s.x) * absf(lat)
			m.p += (d * float(m.speed) + s * lat) * dt / (1.0 - GROUND_FR)
			m.dir = d
	if march:
		var g2 := goal()
		if Vector2(m.p.x - g2.x, m.p.z - g2.z).length() < reach_r() + r * 0.5:
			_reach(m)


## The boss's big moves: a crouch, a jump, a slam (or a fall when knocked down), a stun,
## a leap back. Returns true while one runs (no plain hopping then).
func _boss_act(m: Dictionary, dt: float) -> bool:
	var g := goal()
	var flat := Vector3(g.x - m.p.x, 0, g.z - m.p.z)
	var dist := flat.length()
	match m.act:
		"":
			m.slam_cd -= dt
			if m.slam_cd <= 0.0 and dist > reach_r() + 5.0 * size and F.state == "wave":
				m.act = "crouch"
				m.act_t = 0.0
				m.from = m.p
				var jump := minf(dist - reach_r() - 3.5 * size, 7.0 * size)
				m.to = (m.p as Vector3) + flat.normalized() * maxf(0.0, jump)
				m.air_hits = 0
				_sfx("whoosh", 0.6, m.c)
				_ring(Vector3(m.to.x, 0.05, m.to.z), m.r * 2.0, m.r * 1.6, 0.7, Color("ff3d3d"))
				return true
			return false
		"crouch":
			m.act_t += dt
			var k := clampf(m.act_t / 0.7, 0.0, 1.0)
			m.y = 0.0
			var shake := sin(m.act_t * 60.0) * 0.04 * k
			m.sq = Vector2(1.0 + 0.2 * k + shake, 1.0 - 0.3 * k)
			if k >= 1.0:
				m.act = "air"
				m.act_t = 0.0
				_sfx("swish", 0.8, m.c)
			return true
		"air":
			m.act_t += dt
			var T := 1.4
			var k := clampf(m.act_t / T, 0.0, 1.0)
			m.p = (m.from as Vector3).lerp(m.to, k)
			m.y = 7.0 * size * 4.0 * k * (1.0 - k)
			m.sq = Vector2(0.9, 1.15) if k < 0.5 else Vector2(1.05, 0.95)
			if k >= 1.0:
				_slam(m)
			return true
		"fall":
			m.act_t += dt
			m.v.y -= Ball.GRAV * 1.4 * dt
			m.y = maxf(0.0, m.y + m.v.y * dt)
			m.sq = Vector2(1.1, 0.9)
			if m.y <= 0.0:
				m.act = "stun"
				m.act_t = 0.0
				m.y = 0.0
				_sfx("thump", 1.0, m.p)
				_dirt(m.p, Vector3.UP, 14, 1.0)
				_ring(Vector3(m.p.x, 0.05, m.p.z), m.r, m.r * 2.5, 0.4, Color("e8d2a8"))
			return true
		"stun":
			m.act_t += dt
			var w := exp(-m.act_t * 4.0) * sin(m.act_t * 22.0)
			m.sq = Vector2(1.15 + 0.15 * w, 0.82 - 0.2 * w)
			if m.act_t >= 2.4:
				m.act = ""
				m.slam_cd = 3.0
			return true
		"retreat":
			m.act_t += dt
			var k := clampf(m.act_t / 1.6, 0.0, 1.0)
			m.p = (m.from as Vector3).lerp(m.to, k)
			m.y = 9.0 * size * 4.0 * k * (1.0 - k)
			m.sq = Vector2.ONE
			if k >= 1.0:
				m.act = ""
				m.slam_cd = 4.0
				_land(m)
			return true
	return false


func _slam(m: Dictionary) -> void:
	m.act = ""
	m.slam_cd = _rng.randf_range(3.5, 5.0)
	m.y = 0.0
	m.land_t = 0.35
	var p: Vector3 = m.p
	_sfx("boom", 1.0, p)
	_sfx("thump", 1.0, p)
	_buzz2(0.9, 220)
	_ring(Vector3(p.x, 0.05, p.z), m.r, 10.0 * size, 0.9, Color("ff5a3a"))
	_ring(Vector3(p.x, 0.08, p.z), m.r * 0.5, 6.0 * size, 0.6, Color("ffd23f"))
	_dirt(p, Vector3.UP, 24, 1.6)
	# He shakes out two little ones.
	var d: Vector3 = m.dir
	var side := Vector3(-d.z, 0, d.x)
	for s in [-1.0, 1.0]:
		var i := spawn("mini", {"pos": p + side * s * m.r, "normal": Vector3.UP})
		if i >= 0:
			var q: Dictionary = invaders[i]
			q.phase = "leap"
			q.c = p + side * s * float(m.r) + Vector3.UP * float(m.r)
			q.v = (side * s * 3.0 + d * 1.5 + Vector3.UP * 6.0) * size


## Where m is drawn this frame (centre and transform) and its hit sphere.
func _place(m: Dictionary) -> void:
	var r: float = m.r
	var sq: Vector2 = m.sq
	if m.hit_t > 0.0:
		var k: float = m.hit_t / 0.28
		var w := sin(k * PI * 3.0) * k
		sq = Vector2(sq.x * (1.0 + 0.25 * w), sq.y * (1.0 - 0.3 * w))
	if m.land_t > 0.0:
		var k2: float = m.land_t / 0.25
		sq = Vector2(sq.x * (1.0 + 0.3 * k2), sq.y * (1.0 - 0.35 * k2))
	if m.phase in ["march", "idle"]:
		m.c = (m.p as Vector3) + Vector3.UP * (r * sq.y + float(m.y))
	var proxy: MeshInstance3D = m.proxy
	proxy.visible = hittable(m)
	proxy.transform = Transform3D(Basis.from_scale(Vector3.ONE * r * maxf(sq.x, sq.y) * 1.18), m.c)


func _xf(m: Dictionary) -> Transform3D:
	var r: float = m.r
	var sq: Vector2 = m.sq
	if m.hit_t > 0.0:
		var k: float = m.hit_t / 0.28
		var w := sin(k * PI * 3.0) * k
		sq = Vector2(sq.x * (1.0 + 0.25 * w), sq.y * (1.0 - 0.3 * w))
	if m.land_t > 0.0:
		var k2: float = m.land_t / 0.25
		sq = Vector2(sq.x * (1.0 + 0.3 * k2), sq.y * (1.0 - 0.35 * k2))
	var c: Vector3 = m.c
	var to := viewer - c
	to.y *= 0.5
	if to.length_squared() < 1e-6:
		to = Vector3.BACK
	var look := Basis.looking_at(to.normalized(), Vector3.UP, true)
	# A mischievous wobble: tilting side to side as it goes.
	var tilt := sin(time * 5.0 + float(m.wob)) * (0.16 if m.phase == "march" else 0.1)
	if m.kind == "boss" and m.act == "air":
		tilt = sin(time * 3.0) * 0.12
	var fwd := to.normalized()
	return Transform3D(Basis(fwd, tilt) * Basis.from_scale(Vector3(r * sq.x, r * sq.y, r * sq.x)) * look, c)


func _eyes(m: Dictionary) -> String:
	if m.kind == "boss" and m.act == "stun":
		return "shut"
	if m.flash_t > 0.0 or m.hit_t > 0.15 or m.phase in ["drop", "emerge", "leap"]:
		return "wide"
	if m.kind == "boss" and m.act in ["crouch", "air"]:
		return "wide"
	if m.blink > 0.0:
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


func draw() -> void:
	crowd.begin()
	var nsh := 0
	var nbar := 0
	var nstar := 0
	var shadows: MultiMesh = _mm.shadows
	var bars: MultiMesh = _mm.bars
	var stars: MultiMesh = _mm.stars
	for m in invaders:
		if not m.on:
			continue
		var xf := _xf(m)
		var col := Color(m.color)
		if m.flash_t > 0.0:
			col = col.lerp(Color.WHITE, 0.75)
		if not (m.phase == "emerge" and m.t < 0.1):
			_crowd_add(m.style, xf, _eyes(m), m.acc, col)
		var c: Vector3 = m.c
		var r: float = m.r
		# A soft shadow on the ground (smaller and fainter the higher it is).
		if nsh < shadows.instance_count and m.phase != "emerge":
			var h := maxf(0.0, c.y - r)
			var k := clampf(1.0 - h / (8.0 * size), 0.15, 1.0)
			shadows.set_instance_transform(nsh, Transform3D(Basis.from_scale(Vector3.ONE * r * (0.6 + 0.4 * k)), Vector3(c.x, 0.03, c.z)))
			shadows.set_instance_color(nsh, Color(0.05, 0.02, 0.08, 0.38 * k))
			nsh += 1
		# Hit points over tanks and the boss.
		if m.kind in ["tank", "boss"] and nbar + 3 <= BARS_MAX:
			var w := r * (1.6 if m.kind == "boss" else 1.5)
			var bh := (0.2 if m.kind == "boss" else 0.13) * size
			var top := c + Vector3.UP * (r * 1.25 + (0.35 if m.kind == "boss" else 0.2) * size)
			var fb := _face(top)
			var f := clampf(float(m.hp) / float(m.max_hp), 0.0, 1.0)
			bars.set_instance_transform(nbar, Transform3D(fb * Basis.from_scale(Vector3(w + 0.1 * size, bh + 0.1 * size, 0.04 * size)), top))
			bars.set_instance_color(nbar, Color("fff3e0"))
			nbar += 1
			bars.set_instance_transform(nbar, Transform3D(fb * Basis.from_scale(Vector3(w, bh, 0.05 * size)), top + fb * Vector3(0, 0, 0.012 * size)))
			bars.set_instance_color(nbar, Color("2a2440"))
			nbar += 1
			var fc := Color("5dff8a").lerp(Color("ff3d3d"), 1.0 - f) if m.kind == "tank" else Color("ff4d6d")
			var off := fb * Vector3(-(w * (1.0 - f)) / 2.0, 0, 0.03 * size)
			bars.set_instance_transform(nbar, Transform3D(fb * Basis.from_scale(Vector3(maxf(0.001, w * f), bh, 0.05 * size)), top + off))
			bars.set_instance_color(nbar, fc)
			nbar += 1
		# Dizzy stars over a stunned boss.
		if m.kind == "boss" and m.act == "stun":
			for s in 4:
				var a: float = time * 6.0 + TAU * s / 4.0
				var p := c + Vector3(cos(a), 0, sin(a)) * r * 0.8 + Vector3.UP * r * 1.2
				nstar = _put_star(stars, nstar, p, 0.38 * size, time * 4.0 + s, Color("fff27a"))
	crowd.end()
	# Power-ups: a glossy bubble, a turning halo and the icon, the name under it.
	var shells: MultiMesh = _mm.shells
	var halos: MultiMesh = _mm.halos
	var nshell := 0
	var nicon := {}
	for k in PU:
		nicon[k] = 0
	for u in powerups:
		var lab: Label3D = u.label
		var proxy: MeshInstance3D = u.proxy
		if not u.on:
			lab.visible = false
			proxy.visible = false
			continue
		var p: Vector3 = u.p
		var info: Dictionary = PU[u.kind]
		var col := Color(info.color)
		var blink: bool = u.t > PU_LIFE - 1.6 and fmod(u.t * 8.0, 1.0) < 0.35
		var s := PU_R * size * (1.0 + 0.06 * sin(time * 6.0)) * minf(1.0, float(u.t) * 5.0 + 0.2)
		var fb := _face(p)
		shells.set_instance_transform(nshell, Transform3D(Basis.from_scale(Vector3.ONE * s), p))
		shells.set_instance_color(nshell, Color(col, 0.0 if blink else 0.32))
		halos.set_instance_transform(nshell, Transform3D(fb * Basis(Vector3.BACK, float(u.spin)) * Basis(Vector3.RIGHT, 0.5) * Basis.from_scale(Vector3.ONE * s * 1.12), p))
		halos.set_instance_color(nshell, Color(col, 0.2 if blink else 0.95))
		nshell += 1
		var im: MultiMesh = _mm["icon_" + u.kind]
		im.set_instance_transform(nicon[u.kind], Transform3D(fb * Basis(Vector3.UP, sin(time * 2.0) * 0.5) * Basis.from_scale(Vector3.ONE * s * 1.05), p))
		im.set_instance_color(nicon[u.kind], Color.WHITE)
		nicon[u.kind] += 1
		if nsh < shadows.instance_count:
			shadows.set_instance_transform(nsh, Transform3D(Basis.from_scale(Vector3.ONE * s * 0.7), Vector3(p.x, 0.03, p.z)))
			shadows.set_instance_color(nsh, Color(col.darkened(0.6), 0.25))
			nsh += 1
		lab.visible = not blink
		lab.position = p + Vector3.DOWN * s * 1.45
		lab.scale = Vector3.ONE * size
		proxy.visible = true
		proxy.transform = Transform3D(Basis.from_scale(Vector3.ONE * s * 1.25), p)
	shells.visible_instance_count = nshell
	halos.visible_instance_count = nshell
	for k in PU:
		(_mm["icon_" + k] as MultiMesh).visible_instance_count = nicon[k]
	shadows.visible_instance_count = nsh
	bars.visible_instance_count = nbar
	stars.visible_instance_count = nstar
	_draw_fx()
	_draw_labels()


func _put_star(stars: MultiMesh, i: int, p: Vector3, s: float, spin: float, c: Color) -> int:
	if i >= STARS_MAX:
		return i
	stars.set_instance_transform(i, Transform3D(_face(p) * Basis(Vector3.BACK, spin) * Basis.from_scale(Vector3.ONE * s), p))
	stars.set_instance_color(i, c.srgb_to_linear())
	return i + 1


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
		rings.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(rad, rad * 1.6, rad)), g.p))
		rings.set_instance_color(i, Color((g.c as Color).srgb_to_linear(), 1.0 - k))
	var nr := _rings.size()
	# Where the boss will land: a red target that tightens as he comes down.
	var bo := _boss()
	if not bo.is_empty() and bo.act in ["crouch", "air"]:
		var to: Vector3 = bo.to
		var r: float = bo.r
		var k: float = clampf(float(bo.act_t) / 1.4, 0.0, 1.0) if bo.act == "air" else 0.0
		var pulse := 0.6 + 0.4 * sin(time * 18.0)
		for j in MARKS:
			var rad := r * (2.6 - 1.2 * k) * (1.0 if j == 0 else 0.55)
			rings.set_instance_transform(nr, Transform3D(Basis.from_scale(Vector3(rad, 1.5, rad)), Vector3(to.x, 0.05, to.z)))
			rings.set_instance_color(nr, Color(Color("ff2d3d").srgb_to_linear(), pulse))
			nr += 1
	rings.visible_instance_count = nr
	var holes: MultiMesh = _mm.holes
	for i in _holes.size():
		var h: Dictionary = _holes[i]
		var t: float = h.t
		var hs := MoleStage._back(clampf(t / 0.22, 0.0, 1.0)) if t < 0.22 else (1.0 if t < 1.4 else maxf(0.001, 1.0 - (t - 1.4) / 0.4))
		var hn: Vector3 = h.n
		var hb := MoleStage.basis_up(hn).rotated(hn, float(h.spin))
		holes.set_instance_transform(i, Transform3D(hb.scaled_local(Vector3.ONE * maxf(0.001, hs) * 0.6 * size), (h.p as Vector3) + hn * 0.01))
		holes.set_instance_color(i, Color.WHITE)
	holes.visible_instance_count = _holes.size()
	# The line around you: a ring of dashes that turns and glows red when they're close.
	var dashes: MultiMesh = _mm.dashes
	var nd := 0
	if F.state in ["wave", "break"]:
		var g := goal()
		var rr := reach_r()
		var hot: float = F.danger
		var col := Color("ffb347").lerp(Color("ff2d55"), hot)
		var pulse := 0.55 + 0.45 * hot * (0.5 + 0.5 * sin(time * 14.0))
		for i in DASHES:
			var a := TAU * i / DASHES + time * 0.25
			var p := g + Vector3(cos(a), 0, sin(a)) * rr + Vector3.UP * 0.03
			var b := Basis(Vector3.UP, -a)
			dashes.set_instance_transform(i, Transform3D(b * Basis.from_scale(Vector3(0.09 * size, 1.0, rr * TAU / DASHES * 0.55)), p))
			dashes.set_instance_color(i, Color(col.srgb_to_linear(), pulse))
		nd = DASHES
	dashes.visible_instance_count = nd
	# One got through: a red flash around your head.
	var fl: MultiMesh = _mm.flash
	if F.flash_t > 0.0:
		var k: float = F.flash_t / 0.5
		fl.set_instance_transform(0, Transform3D(Basis.from_scale(Vector3.ONE * 0.9 * size), viewer))
		fl.set_instance_color(0, Color(Color("ff1f3d").srgb_to_linear(), 0.42 * k * k))
		fl.visible_instance_count = 1
	elif time_scale < 0.999:
		# Slow motion: the world takes a cool blue tint.
		var k := (1.0 - time_scale) / (1.0 - SLOW_SCALE)
		fl.set_instance_transform(0, Transform3D(Basis.from_scale(Vector3.ONE * 0.9 * size), viewer))
		fl.set_instance_color(0, Color(Color("4fb8ff").srgb_to_linear(), 0.16 * k))
		fl.visible_instance_count = 1
	else:
		fl.visible_instance_count = 0


func _draw_labels() -> void:
	# The wave banner: pops in with an overshoot, holds, then flies up and fades.
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
		combo_label.position = (F.combo_at as Vector3) + Vector3.UP * (1.3 + a * 0.6) * size
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
		S.vel += dq * (-1.6 * vn)
	S.side = Vector3.ZERO
	return true


func collide(S: Ball) -> void:
	if not S.shot:
		return
	for m in invaders:
		if not hittable(m):
			continue
		var r: float = float(m.r) * maxf(m.sq.x, m.sq.y)
		var dir := S.vel.normalized() if S.vel.length_squared() > 0.0 else Vector3.FORWARD
		if _ball_vs(S, m.c, r):
			F.touched = true
			if m.ball_t <= 0.0:
				m.ball_t = 0.3
				damage(m, BALL_DAMAGE, dir, true)
	for i in powerups.size():
		var u: Dictionary = powerups[i]
		if u.on and S.pos.distance_to(u.p) < Ball.BR + PU_R * size:
			F.touched = true
			collect(i)


func shoot(obj: Node, _point: Vector3, dir: Vector3) -> bool:
	var d := dir if dir != Vector3.ZERO else Vector3.FORWARD
	for m in invaders:
		if obj == m.proxy and m.on:
			return damage(m, 1, d)
	for i in powerups.size():
		if obj == powerups[i].proxy and powerups[i].on:
			collect(i)
			return true
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
	for m in invaders:
		m.on = false
		(m.proxy as MeshInstance3D).visible = false
	for u in powerups:
		u.on = false
	JuiceText.clear(self)
	_sparks.clear()
	_rings.clear()
	_holes.clear()
	F.state = "idle"
	F.wave = 0
	F.score = 0
	F.breaches = 0
	F.combo = 0
	F.mult = 1
	F.queue = []
	F.triple_t = 0.0
	F.slow_t = 0.0
	F.flash_t = 0.0
	F.banner_t = 0.0
	F.combo_show_t = 0.0
	F.touched = false
	time_scale = 1.0
	draw()


func update(_b: Ball, dt: float) -> void:
	# Nothing moves while hidden (the rain, a tabletop, the Summit) or held by main.
	if not visible or paused:
		return
	# dt is game time (already slowed by time_scale when main applies it); rdt ~ unslowed.
	var rdt := dt / maxf(time_scale, 0.05)
	time += dt
	_goal_s = _goal_s.lerp(Vector3(viewer.x, 0, viewer.z), 1.0 - exp(-rdt * 3.0))
	F.triple_t = maxf(0.0, F.triple_t - rdt)
	F.slow_t = maxf(0.0, F.slow_t - rdt)
	var target := SLOW_SCALE if F.slow_t > 0.0 else 1.0
	time_scale = move_toward(time_scale, target, rdt * 3.0)
	F.flash_t = maxf(0.0, F.flash_t - rdt)
	F.banner_t = maxf(0.0, F.banner_t - rdt)
	F.combo_show_t = maxf(0.0, F.combo_show_t - rdt)
	if F.combo_t > 0.0:
		F.combo_t -= dt
		if F.combo_t <= 0.0:
			F.combo = 0
			F.mult = 1
	_room_t -= rdt
	if _room_t <= 0.0:
		_room_t = 1.0
		_room = _spots()
	_step_waves(dt, rdt)
	var danger := 0.0
	var g := goal()
	for m in invaders:
		if m.on:
			_step_invader(m, dt)
			if m.on and m.phase == "march":
				var dd := Vector2(m.p.x - g.x, m.p.z - g.z).length() - reach_r()
				danger = maxf(danger, clampf(1.0 - dd / (5.0 * size), 0.0, 1.0))
	F.danger = danger
	_separate()
	for u in powerups:
		if u.on:
			_step_powerup(u, dt)
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
			s.v *= Vector3(0.6, -0.3, 0.6)
	for i in range(_rings.size() - 1, -1, -1):
		_rings[i].t += dt
		if _rings[i].t >= _rings[i].life:
			_rings.remove_at(i)
	for i in range(_holes.size() - 1, -1, -1):
		_holes[i].t += dt
		if _holes[i].t >= 1.8:
			_holes.remove_at(i)
	# Drawn about once a frame (update runs three times a frame).
	_draw_acc += rdt
	if _draw_acc >= 0.0125:
		_draw_acc = 0.0
		draw()


## Marchers don't pile into each other.
func _separate() -> void:
	for i in invaders.size():
		var a: Dictionary = invaders[i]
		if not a.on or a.phase != "march":
			continue
		for j in range(i + 1, invaders.size()):
			var b: Dictionary = invaders[j]
			if not b.on or b.phase != "march":
				continue
			var d := Vector2(b.p.x - a.p.x, b.p.z - a.p.z)
			var want: float = (float(a.r) + float(b.r)) * 0.95
			var l := d.length()
			if l >= want or l < 1e-5:
				continue
			var push := d / l * (want - l) * 0.5
			var wa := 0.0 if a.kind == "boss" else (0.2 if b.kind == "boss" else 1.0)
			var wb := 0.0 if b.kind == "boss" else (0.2 if a.kind == "boss" else 1.0)
			a.p -= Vector3(push.x, 0, push.y) * wa
			b.p += Vector3(push.x, 0, push.y) * wb


func _step_powerup(u: Dictionary, dt: float) -> void:
	u.t += dt
	u.spin += dt * 2.5
	if u.t > PU_LIFE:
		u.on = false
		_burst(u.p, Color(PU[u.kind].color), 8, 0.5)
		return
	# Up out of the pop, then floating at eye height, bobbing, drifting toward you.
	var p: Vector3 = u.p
	var v: Vector3 = u.v
	var target := Vector3(p.x, float(u.home_y) + sin(float(u.t) * 2.2) * 0.25 * size, p.z)
	v.y += ((target.y - p.y) * 9.0 - v.y * 3.5) * dt
	var to := goal() - p
	to.y = 0.0
	var drift := to.normalized() * 0.7 * size if to.length() > reach_r() + 2.0 * size else Vector3.ZERO
	v.x += (drift.x - v.x) * minf(1.0, dt * 1.5)
	v.z += (drift.z - v.z) * minf(1.0, dt * 1.5)
	u.v = v
	u.p = p + v * dt
	if u.kind == "bomb" and _rng.randf() < 0.5:
		var s := PU_R * size
		var fuse := p + _face(p) * Vector3(0.12, 0.55, 0) * s
		_spark(fuse, Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.5, 2.0), _rng.randf_range(-1, 1)) * 0.6 * size, 0.3, Color("ffc070"), 0.04 * size, 0.2)


## For tests and the HUD.
func invasion_state() -> Dictionary:
	return {"state": F.state, "wave": F.wave, "score": F.score, "breaches": F.breaches, "combo": F.combo, "mult": F.mult, "triple": F.triple_t > 0.0, "slow": F.slow_t > 0.0,
		"queue": (F.queue as Array).size(), "alive": _alive(), "popped": F.popped}
