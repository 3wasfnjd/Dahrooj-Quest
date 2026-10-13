class_name MoleStage
extends Node3D
## Whack-a-Dahrooj («اضرب الدحروج», mode "mole"): little Dahroojs in every style and colour
## pop out of holes that crack open in the ground, look around, blink and duck back. Hit them
## with a thrown Dahrooj or a blaster shot. Open play: no round, no clock, no score board;
## they keep popping up at a steady, comfortable pace (PACE) and the points go to
## ctx.counts["mole"], which the jelly score popup shows. A golden one (crown) is worth 3; a
## sleepy one (eyes shut, Zzz) costs 2 and breaks the streak. Every 5 in a row: confetti.
## Game units, like the other stages.
##
## Spawn spots: on the court's ground in a loose 5 x 4 field in front of the player, or, when
## `spots_provider` returns any, on those spots (mixed reality: the room's floor, walls and
## tables): an Array of {pos: Vector3 (game units, on the surface), normal: Vector3 (game
## space)}. A hole on a wall faces along the wall's normal and the Dahrooj pokes out sideways.
##
## Blaster: every mole that can be hit has a hidden (layers = 0, never drawn) collision sphere
## MeshInstance3D that follows it, so the runtime's ray_stage() finds it and calls shoot().

## The pace of play, 0 (calm) .. 1 (frantic): fixed at what was the middle of the old round.
const PACE := 0.5
const R := 0.34  # a mole's radius (game units, before `size`)
const HOLE_K := 1.32  # hole radius / mole radius
const SLOTS := 8
const OPEN_T := 0.22
const RISE_T := 0.2
const DUCK_T := 0.16
const CLOSE_T := 0.24
const HIT_T := 0.8
const POINTS := {"plain": 1, "gold": 3, "sleepy": -2}
const STREAK := 5
const COLORS := ["ff69b4", "b36bff", "ff9b3d", "6fa8d6", "7bbf8a", "e2603f", "f1ebe1", "cfe8ff", "ffd166", "46aaa9"]
const ACCS := ["", "", "", "party", "glasses", "cap", "flower", "headphones", "scarf"]
const GRID_X := [-4.0, -2.0, 0.0, 2.0, 4.0]
const GRID_Z := [-5.5, -8.2, -10.9, -13.6]
const DEBRIS_MAX := 96
const STARS_MAX := 40
const DIRT := ["7d5434", "9b6a42", "6b4429", "b08355", "5a3a24"]

static var _meshes := {}

var aim_z := -10.0
var far_z = null
var reach_z = null
var friction = null
var shot_time = 4.0
var ctx: GameCtx

## Room spots (mixed reality); see the header. Unset or empty: the ground field.
var spots_provider: Callable
## Moles sink into the ground (the court's ground hides them). Main sets false in mixed reality,
## where nothing real hides what is under the floor: moles then swell out of the hole instead.
var sink := true
## Size of the moles and holes (1 = R game units). Mixed reality may want them bigger.
var size := 1.0
## Where the player's head is (game units): the moles look at it.
var viewer := Vector3(0, 2.6, 0.5)
## New moles come up on their own (tests turn it off and call spawn()).
var auto_spawn := true

var F := {"score": 0, "streak": 0, "touched": false, "spawn_t": 0.6, "whacked": 0, "throw_live": false, "throw_hits": 0}
var moles: Array = []
var grid: Array = []
var crowd: Crowd
var time := 0.0
var _debris: Array = []
var _debris_mm: MultiMesh
var _stars_mm: MultiMesh
var _recent: Array = []
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 77
	name = "Mole"
	crowd = Crowd.new(SLOTS, true, true)
	crowd.name = "Moles"
	add_child(crowd)
	for zi in GRID_Z.size():
		for xi in GRID_X.size():
			# A loose field: every other row shifted, a little jitter.
			var x: float = GRID_X[xi] + (0.5 if zi % 2 == 1 else -0.2) + _rng.randf_range(-0.35, 0.35)
			var z: float = GRID_Z[zi] + _rng.randf_range(-0.4, 0.4)
			grid.append({"pos": Vector3(x * (1.0 + zi * 0.08), 0.0, z), "normal": Vector3.UP})
	for i in SLOTS:
		var hole := MeshInstance3D.new()
		hole.name = "Hole%d" % i
		hole.mesh = hole_mesh()
		hole.material_override = _mat("hole")
		hole.visible = false
		add_child(hole)
		var proxy := MeshInstance3D.new()
		proxy.name = "MoleHit%d" % i
		proxy.mesh = _proxy_mesh()
		proxy.layers = 0  # never drawn: only the blaster's ray sees it
		proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		proxy.visible = false
		add_child(proxy)
		var zzz := Panel3D.label("z", 72, Color("cfd8ff"))
		zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		zzz.pixel_size = 0.004
		zzz.outline_size = 10
		zzz.outline_modulate = Color("2c2d3d")
		zzz.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS  # a depth prepass keeps the fill solid over other see-through things
		zzz.visible = false
		add_child(zzz)
		moles.append({"on": false, "phase": "", "t": 0.0, "spot": Vector3.ZERO, "n": Vector3.UP, "sink": true,
			"kind": "plain", "style": "fur", "color": "ff69b4", "acc": "", "up_t": 1.5, "e": 0.0,
			"sq": Vector2.ONE, "hs": 0.0, "look": 0.0, "look_to": 0.0, "look_t": 0.3, "blink": 0.0,
			"blink_t": 1.0, "woke": false, "hit_dir": Vector3.ZERO, "c": Vector3.ZERO, "rr": 0.0,
			"spin": 0.0, "hole": hole, "proxy": proxy, "zzz": zzz, "pop_t": 0.0, "pop_at": Vector3.ZERO})
	_debris_mm = _multi("Debris", Crowd.merge([[Crowd.sphere(1.0, 5, 3), Transform3D.IDENTITY, Color.WHITE]]), _mat("debris"), DEBRIS_MAX)
	_stars_mm = _multi("Stars", star_mesh(), _mat("star"), STARS_MAX)
	draw()


# ---- art ----

static func _mat(key: String) -> Material:
	if _meshes.has("mat_" + key):
		return _meshes["mat_" + key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	match key:
		"hole":
			m.roughness = 1.0
		"debris":
			m.roughness = 0.95
		"star":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
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
	mi.custom_aabb = AABB(Vector3(-40, -20, -40), Vector3(80, 60, 80))
	add_child(mi)
	return mm


static func _proxy_mesh() -> SphereMesh:
	if not _meshes.has("proxy"):
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 12
		s.rings = 6
		_meshes["proxy"] = s
	return _meshes["proxy"]


## Adds a triangle wound so its front faces the normals (Godot's front faces wind clockwise).
static func _tri(st: SurfaceTool, p: Array, n: Array, c: Array) -> void:
	var order := [0, 1, 2]
	if ((p[1] as Vector3) - p[0]).cross((p[2] as Vector3) - p[0]).dot((n[0] as Vector3) + n[1] + n[2]) > 0.0:
		order = [0, 2, 1]
	for k in order:
		st.set_color(c[k])
		st.set_normal(n[k])
		st.add_vertex(p[k])


## The opened ground (unit radius, +Y out of the surface): a dark well with a raised lip of dirt,
## a splash of loose earth around it and cracks running out. Vertex colours (linear).
static func hole_mesh() -> ArrayMesh:
	if _meshes.has("hole"):
		return _meshes["hole"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 32
	# Radial profile: [radius, height, colour]; the radius wobbles round the rim.
	var prof := [[0.0, -0.03, "070403"], [0.55, -0.02, "0d0806"], [0.86, 0.0, "1c110b"], [1.0, 0.05, "3d2618"],
		[1.1, 0.17, "8a5a36"], [1.3, 0.13, "a2713f"], [1.55, 0.04, "8c5f3a"], [1.78, 0.0, "6e4a2e"]]
	var wob := func(a: float, k: int) -> float:
		if k < 2:
			return 1.0
		var w := 1.0 + 0.06 * sin(3.0 * a + 0.4) + 0.045 * sin(7.0 * a + 1.3)
		if k == prof.size() - 1:
			w += 0.12 * sin(5.0 * a + 2.0) + 0.07 * sin(11.0 * a)
		return w
	var pts := []  # [ring][seg] -> [pos, normal, colour]
	for k in prof.size():
		var row := []
		var r0: float = prof[maxi(0, k - 1)][0]
		var y0: float = prof[maxi(0, k - 1)][1]
		var r1: float = prof[mini(prof.size() - 1, k + 1)][0]
		var y1: float = prof[mini(prof.size() - 1, k + 1)][1]
		var nr := -(y1 - y0)
		var ny := r1 - r0
		var c := Color(prof[k][2]).srgb_to_linear()
		for s in seg:
			var a := TAU * s / seg
			var rad: float = prof[k][0] * wob.call(a, k)
			var dir := Vector3(cos(a), 0, sin(a))
			var nrm := (dir * nr + Vector3.UP * maxf(0.05, ny)).normalized() if k > 0 else Vector3.UP
			row.append([dir * rad + Vector3.UP * float(prof[k][1]), nrm, c])
		pts.append(row)
	for k in prof.size() - 1:
		for s in seg:
			var a: Array = pts[k][s]
			var b: Array = pts[k][(s + 1) % seg]
			var c: Array = pts[k + 1][(s + 1) % seg]
			var d: Array = pts[k + 1][s]
			if k > 0:
				_tri(st, [a[0], b[0], c[0]], [a[1], b[1], c[1]], [a[2], b[2], c[2]])
			_tri(st, [a[0], c[0], d[0]], [a[1], c[1], d[1]], [a[2], c[2], d[2]])
	# Cracks: thin dark wedges running out over the ground, one with a branch.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var crack := Color("3a2618").srgb_to_linear()
	for i in 6:
		var a := TAU * (i + rng.randf_range(-0.25, 0.25)) / 6.0
		var ln := rng.randf_range(2.3, 2.9)
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x)
		var bend := side * rng.randf_range(-0.2, 0.2)
		var p0 := dir * 1.6
		var mid := dir * ((1.6 + ln) * 0.5) + bend
		var tip := dir * ln + bend * 0.4
		var y := Vector3.UP * 0.006
		var w := 0.08
		var ups := [Vector3.UP, Vector3.UP, Vector3.UP]
		var cs := [crack, crack, crack]
		_tri(st, [p0 - side * w + y, p0 + side * w + y, mid + y], ups, cs)
		_tri(st, [mid - side * w * 0.55 + y, mid + side * w * 0.55 + y, tip + y], ups, cs)
		if i % 3 == 0:
			var bdir := (dir + side * 0.9).normalized()
			_tri(st, [mid - dir * 0.05 + y, mid + dir * 0.05 + y, mid + bdir * 0.55 + y], ups, cs)
	var mesh := st.commit()
	_meshes["hole"] = mesh
	return mesh


## A chubby five-pointed star, flat (unit radius, facing +Z, both sides).
static func star_mesh() -> ArrayMesh:
	if _meshes.has("star"):
		return _meshes["star"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := Color.WHITE
	for i in 10:
		var a0 := PI / 2 + TAU * i / 10.0
		var a1 := PI / 2 + TAU * (i + 1) / 10.0
		var r0 := 1.0 if i % 2 == 0 else 0.48
		var r1 := 0.48 if i % 2 == 0 else 1.0
		_tri(st, [Vector3.ZERO, Vector3(cos(a0), sin(a0), 0) * r0, Vector3(cos(a1), sin(a1), 0) * r1],
			[Vector3.BACK, Vector3.BACK, Vector3.BACK], [w, w, w])
	var mesh := st.commit()
	_meshes["star"] = mesh
	return mesh


# ---- ctx ----

func _sfx(n: String, k: float, p: Vector3) -> void:
	if ctx:
		ctx.sfx.call(n, k, p)


## A festive floating text (JuiceText) at a point, in the game's language.
func _say(ar: String, en: String, at: Vector3, kind: String, k := 1.0, col = null) -> void:
	JuiceText.spawn(self, en if ctx != null and ctx.lang == "en" else ar, at, kind, k * size, col)


func _celebrate(at: Vector3, k := 1.0) -> void:
	if ctx:
		ctx.confetti.call(at, 1.2 * k, 1.4, maxf(1.0, at.distance_to(viewer) / 7.0))


# ---- the play ----

## The pace, 0 .. 1 (steady: open play has no round to speed up through).
func pace() -> float:
	return PACE


func _score(m: Dictionary) -> void:
	var pts: int = POINTS[m.kind]
	var at: Vector3 = m.c + (m.n as Vector3) * float(m.rr) * 1.3
	m.pop_t = 0.85
	m.pop_at = at
	JuiceText.spawn(self, ("+%d" % pts) if pts > 0 else ("%d" % pts), at + Vector3.UP * 0.15 * size, "points" if pts > 0 else "ouch",
		size * 128.0 * 0.004 / 0.66 * (1.25 if m.kind == "gold" else 1.0), Color("ffc21a") if m.kind == "gold" else (Color("ff4d3d") if pts < 0 else Color("5dff8a")))
	F.score = maxi(0, F.score + pts)
	if ctx:
		ctx.counts["mole"] = maxi(0, int(ctx.counts.get("mole", 0)) + pts)
	if pts < 0:
		F.streak = 0
		_say("شش! كان نايم", "Shh! He was asleep", at + Vector3.UP * 0.6 * size, "miss", 0.9)
		return
	F.whacked += 1
	F.streak += 1
	F.throw_hits += 1
	if ctx:
		ctx.ch_progress.call("mole20", int(ctx.ch_state.get("mole20", 0)) + 1)
	if m.kind == "gold":
		_say("دحروج ذهبي!", "Golden Dahrooj!", at + Vector3.UP * 0.75 * size, "banner", 0.6, Color("ffc21a"))
		_celebrate(at, 0.8)
	if F.streak % STREAK == 0:
		_sfx("chime", 0.8, at)
		_celebrate(at)
		_say("سلسلة ×%s!" % GameCtx.ar_digits(F.streak), "Streak ×%d!" % F.streak, at + Vector3.UP * 1.1 * size, "combo", 0.9)


## A mole is hit (by a ball or a shot) from direction dir.
func whack(m: Dictionary, dir: Vector3) -> void:
	var pose := mole_pose(m)
	m.c = pose.c
	m.rr = pose.rr
	_phase(m, "hit")
	m.hit_dir = dir
	m.woke = true
	var c: Vector3 = m.c
	_sfx("start_pop", 1.0, c)
	_sfx("squeak", 0.7 if m.kind == "sleepy" else 1.25, c)
	if m.kind == "sleepy":
		_sfx("boom", 0.3, c)
	elif m.kind == "gold":
		_sfx("chime", 0.6, c)
	_burst(m.spot, m.n, 4, 0.6)
	_score(m)


## The mole can be hit: up out of its hole and not already hit.
static func hittable(m: Dictionary) -> bool:
	return m.on and (m.phase == "up" or (m.phase in ["rise", "duck"] and m.e > 0.4))


## Solid for a ball: anything of him out of the hole.
static func solid(m: Dictionary) -> bool:
	return hittable(m) or (m.on and m.phase == "hit")


# ---- spawning ----

func _spots() -> Array:
	if spots_provider.is_valid():
		var s = spots_provider.call()
		if s is Array and not (s as Array).is_empty():
			return s
	return []


func _free_spot(p: Vector3) -> bool:
	for m in moles:
		if m.on and (m.spot as Vector3).distance_to(p) < R * size * 3.2:
			return false
	for q in _recent:
		if (q as Vector3).distance_to(p) < 0.01:
			return false
	return true


func _pick_spot() -> Dictionary:
	var room := _spots()
	var list: Array = room if not room.is_empty() else grid
	for k in 10:
		var s: Dictionary = list[_rng.randi() % list.size()]
		if _free_spot(s.pos):
			return {"pos": s.pos, "normal": s.normal, "room": not room.is_empty()}
	return {}


func _pick_kind() -> String:
	var r := _rng.randf()
	if r < 0.1 and pace() > 0.08:
		return "gold"
	if r < 0.23:
		return "sleepy"
	return "plain"


## Starts a mole at a spot (or a free one); returns its slot or -1. Tests call it directly.
func spawn(kind := "", spot := {}) -> int:
	var slot := -1
	for i in moles.size():
		if not moles[i].on:
			slot = i
			break
	if slot < 0:
		return -1
	if spot.is_empty():
		spot = _pick_spot()
		if spot.is_empty():
			return -1
	var m: Dictionary = moles[slot]
	var n: Vector3 = (spot.normal as Vector3).normalized() if (spot.normal as Vector3).length_squared() > 1e-6 else Vector3.UP
	m.on = true
	m.spot = spot.pos
	m.n = n
	m.sink = sink and not spot.get("room", false) and n.y > 0.9
	m.kind = kind if kind != "" else _pick_kind()
	match m.kind:
		"gold":
			m.style = "clay"
			m.color = "f2c14e"
			m.acc = "crown"
		"sleepy":
			m.style = "fur"
			m.color = "b9b3e6"
			m.acc = "scarf"
		_:
			m.style = Crowd.STYLES[_rng.randi() % Crowd.STYLES.size()]
			m.color = COLORS[_rng.randi() % COLORS.size()] if _rng.randf() < 0.7 else Crowd.DAHROOJ_COLORS[m.style]
			m.acc = ACCS[_rng.randi() % ACCS.size()]
	var p := pace()
	m.up_t = lerpf(2.6, 1.4, p) * (0.75 if m.kind == "gold" else (1.25 if m.kind == "sleepy" else 1.0)) * _rng.randf_range(0.85, 1.15)
	m.look = 0.0
	m.look_to = 0.0
	m.look_t = 0.3
	m.blink = 0.0
	m.blink_t = _rng.randf_range(0.6, 1.6)
	m.woke = false
	m.hit_dir = Vector3.ZERO
	var spin := _rng.randf() * TAU
	var b := basis_up(n).rotated(n, spin)
	(m.hole as MeshInstance3D).transform = Transform3D(b.scaled_local(Vector3.ONE * 0.001), m.spot + n * 0.004)
	m.spin = spin
	_phase(m, "open")
	_recent.append(m.spot)
	if _recent.size() > 2:
		_recent.pop_front()
	_burst(m.spot, n, 9, 1.0)
	_sfx("thump", 0.3, m.spot)
	_step_mole(m, 0.0)
	return slot


func _phase(m: Dictionary, ph: String) -> void:
	m.phase = ph
	m.t = 0.0


## A basis with +Y along n.
static func basis_up(n: Vector3) -> Basis:
	var a := Vector3.UP if absf(n.y) < 0.99 else Vector3.BACK
	var z := (a - n * a.dot(n)).normalized()
	return Basis(n.cross(z), n, z)


# ---- effects ----

func _burst(at: Vector3, n: Vector3, count: int, k: float) -> void:
	var b := basis_up(n)
	var hr := R * size * HOLE_K
	for i in count:
		if _debris.size() >= DEBRIS_MAX:
			_debris.pop_front()
		var a := _rng.randf() * TAU
		var out := b.x * cos(a) + b.z * sin(a)
		_debris.append({"p": at + out * hr * 0.8 + n * 0.08, "v": (out * _rng.randf_range(1.2, 2.8) + n * _rng.randf_range(2.5, 4.8)) * k * size,
			"s": _rng.randf_range(0.045, 0.1) * size, "t": 0.0, "life": _rng.randf_range(0.55, 0.85),
			"c": Color(DIRT[_rng.randi() % DIRT.size()]).srgb_to_linear(), "ax": Vector3(_rng.randf() - 0.5, _rng.randf() - 0.5, _rng.randf() - 0.5).normalized(),
			"w": _rng.randf_range(6, 14), "floor": m_floor(at, n)})


## Where loose earth stops falling: the court's ground in VR, nowhere in a room.
func m_floor(at: Vector3, n: Vector3) -> float:
	return 0.0 if sink and n.y > 0.9 and absf(at.y) < 0.05 else -INF


func _step_debris(dt: float) -> void:
	for i in range(_debris.size() - 1, -1, -1):
		var d: Dictionary = _debris[i]
		d.t += dt
		if d.t > d.life:
			_debris.remove_at(i)
			continue
		d.v.y -= Ball.GRAV * dt
		d.p += d.v * dt
		if d.p.y < d.floor + d.s:
			d.p.y = d.floor + d.s
			d.v *= Vector3(0.6, -0.3, 0.6)


# ---- the moles ----

func _step_mole(m: Dictionary, dt: float) -> void:
	m.t += dt
	var t: float = m.t
	match m.phase:
		"open":
			if t >= OPEN_T:
				_phase(m, "rise")
				_sfx("swish", 0.3, m.spot)
		"rise":
			if t >= RISE_T:
				_phase(m, "up")
		"up":
			if t >= m.up_t:
				_phase(m, "duck")
		"hit":
			if t >= HIT_T:
				_phase(m, "duck")
		"duck":
			if t >= DUCK_T:
				_phase(m, "close")
		"close":
			if t >= CLOSE_T:
				m.on = false
	t = m.t
	# Look around and blink while up.
	m.look_t -= dt
	if m.look_t <= 0.0:
		m.look_t = _rng.randf_range(0.35, 0.8)
		m.look_to = [-0.65, -0.3, 0.0, 0.0, 0.3, 0.65][_rng.randi() % 6]
	m.look = move_toward(m.look, m.look_to, dt * 6.0)
	m.blink_t -= dt
	if m.blink_t <= 0.0:
		m.blink = 0.12
		m.blink_t = _rng.randf_range(1.0, 2.4)
	m.blink = maxf(0.0, m.blink - dt)
	# The hole, how far he is out (e) and his squash (sx, sy along the hole's normal).
	var hs := 1.0
	var e := 0.0
	var sq := Vector2.ONE
	match m.phase:
		"open":
			var k := clampf(t / OPEN_T, 0.0, 1.0)
			hs = _back(k)
			sq = Vector2(1.1, 0.8)
		"rise":
			var k := clampf(t / RISE_T, 0.0, 1.0)
			e = 1.0 - pow(1.0 - k, 3.0)
			sq = Vector2(1.0 - 0.14 * sin(PI * k), 1.0 + 0.3 * sin(PI * k))
		"up":
			var wob := exp(-t * 7.0) * sin(t * 26.0)
			e = 1.0
			sq = Vector2(1.0 + 0.1 * wob, 1.0 - 0.16 * wob)
			if m.kind == "sleepy":
				var br := sin(time * 2.6) * 0.04
				sq = Vector2(1.0 + br * 0.5, 1.0 - br)
		"hit":
			var sp := exp(-t * 6.0) * cos(t * 19.0)
			e = 1.0 if t < HIT_T - 0.25 else clampf((HIT_T - t) / 0.25, 0.35, 1.0)
			sq = Vector2(1.0 + 0.32 * sp, 1.0 - 0.45 * sp)
		"duck":
			var k := clampf(t / DUCK_T, 0.0, 1.0)
			e = (0.35 if m.woke else 1.0) * (1.0 - k * k)
			sq = Vector2(1.0 - 0.1 * sin(PI * k), 1.0 + 0.18 * sin(PI * k))
		"close":
			var k := clampf(t / CLOSE_T, 0.0, 1.0)
			hs = 1.0 - k * k
	m.hs = hs
	m.e = e
	m.sq = sq
	if m.pop_t > 0.0:
		m.pop_t = maxf(0.0, m.pop_t - dt)


static func _back(k: float) -> float:
	var c := 2.2
	return 1.0 + (c + 1.0) * pow(k - 1.0, 3.0) + c * pow(k - 1.0, 2.0)


## Where the mole is this frame: {xf: Transform3D, c: centre, rr: radius, show: bool}.
func mole_pose(m: Dictionary) -> Dictionary:
	var n: Vector3 = m.n
	var e: float = m.e
	var sq: Vector2 = m.sq
	var r := R * size
	var rr := r if m.sink else r * maxf(0.001, e)
	var off := r * sq.y * 0.9 - (1.0 - e) * 2.15 * r if m.sink else rr * sq.y * 0.9
	var c: Vector3 = m.spot + n * off
	var show: bool = e > 0.01 and (off + rr * sq.y > 0.0)
	# He faces you (turning to look around), never into his wall.
	var dir := viewer - c
	dir.y *= 0.6
	dir = dir.normalized().rotated(Vector3.UP, m.look)
	var dn := dir.dot(n)
	if dn < 0.3:
		dir = (dir + n * (0.3 - dn)).normalized()
	var rot := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.BACK, true)
	if m.phase == "hit" and (m.hit_dir as Vector3).length_squared() > 0.0:
		var ax := n.cross(m.hit_dir as Vector3)
		if ax.length_squared() > 1e-6:
			rot = Basis(ax.normalized(), 0.45 * exp(-float(m.t) * 5.0) * cos(float(m.t) * 15.0)) * rot
	# Squash along the normal: M = sx I + (sy - sx) n nᵀ.
	var d := sq.y - sq.x
	var M := Basis(Vector3(sq.x, 0, 0) + n * (d * n.x), Vector3(0, sq.x, 0) + n * (d * n.y), Vector3(0, 0, sq.x) + n * (d * n.z))
	return {"xf": Transform3D(M * rot * Basis.from_scale(Vector3.ONE * rr), c), "c": c, "rr": rr * maxf(sq.x, sq.y), "show": show}


func _eyes(m: Dictionary) -> String:
	if m.phase == "hit":
		return "wide" if m.t < 0.12 else "shut"
	if m.kind == "sleepy" and not m.woke:
		return "shut"
	if m.phase == "rise" or m.kind == "gold":
		return "wide"
	if m.blink > 0.0:
		return "shut"
	return "open"


## Crowd.add with our own transform (the squash runs along a wall's normal, not world Y).
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


func _put_star(i: int, p: Vector3, s: float, spin: float, c: Color) -> int:
	if i >= STARS_MAX:
		return i
	var to := viewer - p
	var b := Basis.looking_at(to.normalized(), Vector3.UP, true) if to.length_squared() > 1e-6 and absf(to.normalized().y) < 0.99 else Basis.IDENTITY
	_stars_mm.set_instance_transform(i, Transform3D(b * Basis(Vector3.BACK, spin) * Basis.from_scale(Vector3.ONE * s), p))
	_stars_mm.set_instance_color(i, c.srgb_to_linear())
	return i + 1


## Draws the moles, holes, stars, earth and labels; moves the blaster's hit spheres.
func draw() -> void:
	crowd.begin()
	var ns := 0
	var gold := Color("ffd23f")
	for m in moles:
		var hole: MeshInstance3D = m.hole
		var proxy: MeshInstance3D = m.proxy
		var zzz: Label3D = m.zzz
		if not m.on:
			hole.visible = false
			proxy.visible = false
			zzz.visible = false
			continue
		var n: Vector3 = m.n
		var hb := basis_up(n).rotated(n, float(m.spin))
		hole.visible = m.hs > 0.01
		hole.transform = Transform3D(hb.scaled_local(Vector3.ONE * maxf(0.001, float(m.hs)) * R * size * HOLE_K), m.spot + n * 0.004)
		var pose := mole_pose(m)
		m.c = pose.c
		m.rr = pose.rr
		proxy.visible = hittable(m) and pose.show
		proxy.transform = pose.xf
		if pose.show:
			_crowd_add(m.style, pose.xf, _eyes(m), m.acc, Color(m.color))
		var top: Vector3 = pose.c + n * float(pose.rr) * 1.15
		zzz.visible = m.kind == "sleepy" and not m.woke and m.phase == "up"
		if zzz.visible:
			var u := fmod(time * 0.7, 1.0)
			zzz.text = "z" if u < 0.5 else "Z"
			zzz.position = top + (Vector3.UP * 0.5 + Vector3.RIGHT * 0.25) * u * size
			zzz.modulate.a = sin(u * PI)
			zzz.outline_modulate.a = zzz.modulate.a
			zzz.scale = Vector3.ONE * size * (0.7 + u * 0.6)
		if m.phase == "hit":
			# Dizzy stars circling over his head.
			var hb2 := basis_up(n)
			for s in 3:
				var a: float = time * 7.0 + TAU * s / 3.0
				var p := top + (hb2.x * cos(a) + hb2.z * sin(a)) * float(pose.rr) * 0.75
				ns = _put_star(ns, p, 0.085 * size, time * 5.0 + s, gold)
		elif m.kind == "gold" and pose.show:
			for s in 3:
				var a: float = time * 2.0 + TAU * s / 3.0
				var tw := 0.5 + 0.5 * sin(time * 9.0 + s * 2.1)
				var p: Vector3 = pose.c + (Vector3(cos(a), 0.4 + 0.5 * sin(a * 1.7), sin(a))) * float(pose.rr) * 1.25
				ns = _put_star(ns, p, 0.05 * size * tw + 0.01, time * 2.0, Color("fff3b0"))
	crowd.end()
	_stars_mm.visible_instance_count = ns
	var nd := mini(_debris.size(), DEBRIS_MAX)
	for i in nd:
		var d: Dictionary = _debris[i]
		var k: float = 1.0 - maxf(0.0, (d.t - d.life * 0.6) / (d.life * 0.4))
		_debris_mm.set_instance_transform(i, Transform3D(Basis(d.ax, d.t * d.w) * Basis.from_scale(Vector3(1.0, 0.75, 1.1) * d.s * maxf(0.01, k)), d.p))
		_debris_mm.set_instance_color(i, d.c)
	_debris_mm.visible_instance_count = nd


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


func collide(S: Ball) -> void:
	if not S.shot:
		return
	for m in moles:
		if not solid(m):
			continue
		var pose := mole_pose(m)
		if not pose.show:
			continue
		if _ball_vs(S, pose.c, pose.rr):
			F.touched = true
			if hittable(m):
				whack(m, S.vel.normalized() if S.vel.length_squared() > 0.0 else Vector3.FORWARD)
				_sfx("thump", 0.4, pose.c)


func shoot(obj: Node, _point: Vector3, dir: Vector3) -> bool:
	for m in moles:
		if obj == m.proxy and hittable(m):
			whack(m, dir if dir != Vector3.ZERO else Vector3.FORWARD)
			return true
	return false


func touched() -> bool:
	return F.touched


func on_throw() -> void:
	F.throw_live = true
	F.throw_hits = 0


func on_respawn() -> void:
	F.touched = false
	# A throw that hit nothing breaks the streak.
	if F.throw_live and F.throw_hits == 0:
		F.streak = 0
	F.throw_live = false


func deactivate() -> void:
	for m in moles:
		m.on = false
		m.pop_t = 0.0
	JuiceText.clear(self)
	_debris.clear()
	F.score = 0
	F.streak = 0
	F.touched = false
	F.throw_live = false
	F.spawn_t = 0.6
	draw()


func update(_b: Ball, dt: float) -> void:
	time += dt
	# New moles, on and on at a steady pace.
	if auto_spawn:
		F.spawn_t -= dt
		var up := 0
		for m in moles:
			if m.on:
				up += 1
		var p := pace()
		var cap := 2 + int(p * 3.5)
		if F.spawn_t <= 0.0:
			if up < cap:
				spawn()
			F.spawn_t = lerpf(1.05, 0.42, p) * _rng.randf_range(0.7, 1.3)
	for m in moles:
		if m.on:
			_step_mole(m, dt)
		elif m.pop_t > 0.0:
			m.pop_t = maxf(0.0, m.pop_t - dt)
	_step_debris(dt)
	draw()


func mole_state() -> Dictionary:
	return {"score": F.score, "streak": F.streak, "whacked": F.whacked}


func moles_state() -> Array:
	return moles.map(func(m): return {"on": m.on, "phase": m.phase, "kind": m.kind, "hittable": hittable(m),
		"spot": m.spot, "normal": m.n, "c": m.c, "hole_up": (m.hole as MeshInstance3D).transform.basis.y.normalized()})
