class_name MoleStage
extends Node3D
## Whack-a-Dahrooj («اضرب الدحروج», mode "mole"): little Dahroojs in every style and colour
## pop out of holes that crack open in the ground, look around, blink and duck back. Hit them
## with a thrown Dahrooj or a blaster shot. A 60-second round (a throw or a shot starts it),
## best score kept, the pace rises through the round. A golden one (crown) is worth 3; a
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

const ROUND := 60.0
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
const BOARD_Z := -15.6
const BOARD_Y := 3.3
const BOARD := Vector2(5.0, 1.45)
const POST_X := 2.1
const BEST_PATH := "user://dahrooj-mole-best"
const COLORS := ["ff69b4", "b36bff", "ff9b3d", "6fa8d6", "7bbf8a", "e2603f", "f1ebe1", "cfe8ff", "ffd166", "46aaa9"]
const ACCS := ["", "", "", "party", "glasses", "cap", "flower", "headphones", "scarf"]
const GRID_X := [-4.0, -2.0, 0.0, 2.0, 4.0]
const GRID_Z := [-5.5, -8.2, -10.9, -13.6]
const DEBRIS_MAX := 96
const STARS_MAX := 40
const DIRT := ["7d5434", "9b6a42", "6b4429", "b08355", "5a3a24"]

## Tests turn this off so they don't write the best score.
static var persist_best := true
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

var F := {"time": ROUND, "on": false, "score": 0, "best": 0, "streak": 0, "over": 0.0, "touched": false,
	"spawn_t": 0.6, "whacked": 0, "shown_key": "", "throw_live": false, "throw_hits": 0}
var moles: Array = []
var grid: Array = []
var crowd: Crowd
var board: Node3D
var labels := {}
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
		var pop := Panel3D.label("+1", 128, Color("ffe08a"))
		pop.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		pop.pixel_size = 0.004
		pop.outline_size = 7
		pop.outline_modulate = Color("2c2d3d")
		pop.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS  # a depth prepass keeps the fill solid over other see-through things
		pop.visible = false
		add_child(pop)
		moles.append({"on": false, "phase": "", "t": 0.0, "spot": Vector3.ZERO, "n": Vector3.UP, "sink": true,
			"kind": "plain", "style": "fur", "color": "ff69b4", "acc": "", "up_t": 1.5, "e": 0.0,
			"sq": Vector2.ONE, "hs": 0.0, "look": 0.0, "look_to": 0.0, "look_t": 0.3, "blink": 0.0,
			"blink_t": 1.0, "woke": false, "hit_dir": Vector3.ZERO, "c": Vector3.ZERO, "rr": 0.0,
			"spin": 0.0, "hole": hole, "proxy": proxy, "zzz": zzz, "pop": pop, "pop_t": 0.0, "pop_at": Vector3.ZERO})
	_debris_mm = _multi("Debris", Crowd.merge([[Crowd.sphere(1.0, 5, 3), Transform3D.IDENTITY, Color.WHITE]]), _mat("debris"), DEBRIS_MAX)
	_stars_mm = _multi("Stars", star_mesh(), _mat("star"), STARS_MAX)
	_build_board()
	F.best = _load_best()
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
		"board":
			m.vertex_color_use_as_albedo = false
			m.albedo_color = Color("243133")
			m.roughness = 0.85
		"post":
			m.vertex_color_use_as_albedo = false
			m.albedo_color = Color("c98f5c")
			m.roughness = 0.65
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


func _build_board() -> void:
	board = Node3D.new()
	board.name = "Board"
	board.position = Vector3(0, 0, BOARD_Z)
	add_child(board)
	var panel := StageArt.rbox(BOARD.x, BOARD.y, 0.18, 0.08, _mat("board"))
	panel.position = Vector3(0, BOARD_Y, 0)
	board.add_child(panel)
	for x in [-POST_X, POST_X]:
		var post := StageArt.rbox(0.16, BOARD_Y - 0.2, 0.16, 0.06, _mat("post"))
		post.position = Vector3(x, (BOARD_Y - 0.2) / 2.0, -0.05)
		board.add_child(post)
	# time | score | best, a line of words under them
	for k in [["time", -1.6, 0.12, 100, "ffcb62"], ["score", 0.0, 0.14, 150, "79f5b3"], ["best", 1.6, 0.12, 80, "c9d8b2"],
			["hint", 0.0, -0.46, 44, "b7dec3"], ["time_l", -1.6, -0.46, 40, "b7dec3"], ["best_l", 1.6, -0.46, 40, "b7dec3"]]:
		var l := Panel3D.label("", k[3], Color(k[4]))
		l.pixel_size = 0.0048
		k[2] = BOARD_Y + float(k[2])
		l.render_priority = 1
		l.position = Vector3(k[1], k[2], 0.095)
		board.add_child(l)
		labels[k[0]] = l
	draw_board()


func draw_board() -> void:
	var en := ctx != null and ctx.lang == "en"
	var key := "%d|%d|%d|%s|%s|%d" % [ceili(F.time), F.score, F.best, F.on, en, F.streak]
	if key == F.shown_key:
		return
	F.shown_key = key
	var num := func(v: int) -> String: return str(v) if en else GameCtx.ar_digits(v)
	labels.time.text = num.call(maxi(0, ceili(F.time)))
	labels.score.text = num.call(F.score)
	labels.best.text = num.call(F.best)
	# While waiting the hint takes the whole line.
	labels.time_l.text = ("TIME" if en else "الوقت") if F.on else ""
	labels.best_l.text = ("BEST" if en else "الأفضل") if F.on else ""
	if F.on:
		labels.hint.text = (("STREAK ×%d" % F.streak) if en else ("سلسلة ×" + GameCtx.ar_digits(F.streak))) if F.streak >= 2 else ("POINTS" if en else "النقاط")
	else:
		labels.hint.text = "THROW OR SHOOT TO START" if en else "ارمِ أو اطلق وابدأ"


# ---- persistence, ctx ----

static func _load_best() -> int:
	if not persist_best or not FileAccess.file_exists(BEST_PATH):
		return 0
	var f := FileAccess.open(BEST_PATH, FileAccess.READ)
	return int(f.get_as_text().to_int()) if f else 0


static func _save_best(v: int) -> void:
	if not persist_best:
		return
	var f := FileAccess.open(BEST_PATH, FileAccess.WRITE)
	if f:
		f.store_string(str(v))


func _sfx(n: String, k: float, p: Vector3) -> void:
	if ctx:
		ctx.sfx.call(n, k, p)


func _toast(ar: String, en: String) -> void:
	if ctx:
		ctx.toast.call(ctx.t(ar, en))


func _celebrate(at: Vector3, k := 1.0) -> void:
	if ctx:
		ctx.confetti.call(at, 1.2 * k, 1.4, maxf(1.0, at.distance_to(viewer) / 7.0))


# ---- the round ----

func _start_round() -> void:
	F.on = true
	F.time = ROUND
	F.score = 0
	F.streak = 0
	F.whacked = 0
	F.spawn_t = minf(F.spawn_t, 0.3)
	if ctx:
		ctx.counts["mole"] = 0
	_sfx("whoosh", 0.4, board.position + Vector3(0, BOARD_Y, 0))


func _end_round() -> void:
	F.on = false
	F.time = 0.0
	F.over = 2.5
	var best: bool = F.score > F.best
	if best:
		F.best = F.score
		_save_best(F.best)
	_toast("انتهى الوقت! %s نقطة%s" % [GameCtx.ar_digits(F.score), " · أفضل نتيجة" if best else ""],
		"Time! %d points%s" % [F.score, " — best yet" if best else ""])
	_sfx("chime", 1.0, board.position + Vector3(0, BOARD_Y, 0))
	if best and F.score > 0:
		_celebrate(board.position + Vector3(0, BOARD_Y + 0.6, 0.4), 1.5)
	# Everyone ducks.
	for m in moles:
		if m.on and m.phase in ["open", "rise", "up"]:
			_phase(m, "duck" if m.phase != "open" else "close")


## 0 at the start of a round, 1 at its end: the pace.
func pace() -> float:
	return clampf(1.0 - F.time / ROUND, 0.0, 1.0) if F.on else 0.0


func _score(m: Dictionary) -> void:
	var pts: int = POINTS[m.kind]
	var at: Vector3 = m.c + (m.n as Vector3) * float(m.rr) * 1.3
	m.pop_t = 0.85
	m.pop_at = at
	(m.pop as Label3D).text = ("+%d" % pts) if pts > 0 else ("%d" % pts)
	(m.pop as Label3D).modulate = Color("ffc21a") if m.kind == "gold" else (Color("ff4d3d") if pts < 0 else Color("5dff8a"))
	if not F.on:
		return
	F.score = maxi(0, F.score + pts)
	if pts < 0:
		F.streak = 0
		_toast("شش! كان نايم", "Shh! He was asleep")
		return
	F.whacked += 1
	F.streak += 1
	F.throw_hits += 1
	if ctx:
		ctx.add_count.call("mole", false)
		ctx.ch_progress.call("mole20", int(ctx.ch_state.get("mole20", 0)) + 1)
	if m.kind == "gold":
		_toast("دحروج ذهبي! +٣", "Golden Dahrooj! +3")
		_celebrate(at, 0.8)
	if F.streak % STREAK == 0:
		_sfx("chime", 0.8, at)
		_celebrate(at)
		_toast("سلسلة ×%s!" % GameCtx.ar_digits(F.streak), "Streak ×%d!" % F.streak)


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
	if not F.on:
		return "plain"
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
	if not F.on:
		m.up_t = 2.4
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
		var pop: Label3D = m.pop
		pop.visible = m.pop_t > 0.0
		if pop.visible:
			var k: float = 1.0 - m.pop_t / 0.85
			pop.position = (m.pop_at as Vector3) + Vector3.UP * (0.25 + k * 0.7) * size
			pop.modulate.a = 1.0 - k * k
			pop.outline_modulate.a = pop.modulate.a  # the outline fades with the fill
			pop.scale = Vector3.ONE * size * (0.7 + 0.5 * minf(1.0, k * 6.0))
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
	draw_board()


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


## The board is solid (a resting thrown ball too). Returns {hit, p, v, n}.
func collide_body(p: Vector3, v: Vector3, r: float, previous: Vector3) -> Dictionary:
	return FairStage.collide_solid_box(p, v, r, previous, board.position + Vector3(0, BOARD_Y, 0), Vector3(BOARD.x / 2.0, BOARD.y / 2.0, 0.09))


func collide(S: Ball) -> void:
	if not S.shot:
		return
	var incoming := S.vel.length()
	var res := collide_body(S.pos, S.vel, Ball.BR, S.prev)
	if res.hit:
		S.pos = res.p
		S.vel = res.v
		S.hit(res.n, incoming, S.pos)
		S.side = Vector3.ZERO
	for x in [-POST_X, POST_X]:
		S.seg_collide(board.position + Vector3(x, 0, -0.05), board.position + Vector3(x, BOARD_Y, -0.05), 0.08, 0.5)
	for m in moles:
		if not solid(m):
			continue
		var pose := mole_pose(m)
		if not pose.show:
			continue
		if _ball_vs(S, pose.c, pose.rr):
			F.touched = true
			if hittable(m):
				if not F.on and F.over <= 0.0:
					_start_round()
				whack(m, S.vel.normalized() if S.vel.length_squared() > 0.0 else Vector3.FORWARD)
				_sfx("thump", 0.4, pose.c)


func shoot(obj: Node, _point: Vector3, dir: Vector3) -> bool:
	if not F.on and F.over <= 0.0:
		_start_round()
	for m in moles:
		if obj == m.proxy and hittable(m):
			whack(m, dir if dir != Vector3.ZERO else Vector3.FORWARD)
			return true
	return false


func touched() -> bool:
	return F.touched


func on_throw() -> void:
	if not F.on and F.over <= 0.0:
		_start_round()
	F.throw_live = true
	F.throw_hits = 0


func on_respawn() -> void:
	F.touched = false
	# A throw that hit nothing breaks the streak.
	if F.throw_live and F.throw_hits == 0 and F.on:
		F.streak = 0
	F.throw_live = false


func deactivate() -> void:
	for m in moles:
		m.on = false
		m.pop_t = 0.0
	_debris.clear()
	F.on = false
	F.over = 0.0
	F.time = ROUND
	F.streak = 0
	F.touched = false
	F.throw_live = false
	F.spawn_t = 0.6
	draw()


func update(_b: Ball, dt: float) -> void:
	time += dt
	if F.on:
		F.time -= dt
		if F.time <= 0.0:
			_end_round()
	elif F.over > 0.0:
		F.over -= dt
		if F.over <= 0.0:
			F.time = ROUND
	# New moles: faster and more of them as the round goes on; a slow few while waiting.
	if F.over <= 0.0 and auto_spawn:
		F.spawn_t -= dt
		var up := 0
		for m in moles:
			if m.on:
				up += 1
		var p := pace()
		var cap := (2 + int(p * 3.5)) if F.on else 2
		if F.spawn_t <= 0.0:
			if up < cap:
				spawn()
			F.spawn_t = (lerpf(1.05, 0.42, p) if F.on else 1.8) * _rng.randf_range(0.7, 1.3)
	for m in moles:
		if m.on:
			_step_mole(m, dt)
		elif m.pop_t > 0.0:
			m.pop_t = maxf(0.0, m.pop_t - dt)
	_step_debris(dt)
	draw()


func mole_state() -> Dictionary:
	return {"on": F.on, "time": F.time, "score": F.score, "best": F.best, "streak": F.streak, "whacked": F.whacked}


func moles_state() -> Array:
	return moles.map(func(m): return {"on": m.on, "phase": m.phase, "kind": m.kind, "hittable": hittable(m),
		"spot": m.spot, "normal": m.n, "c": m.c, "hole_up": (m.hole as MeshInstance3D).transform.basis.y.normalized()})
