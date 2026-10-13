class_name TabletopGame
extends RefCounted
## The isolated tabletop solvers (src/reference/tabletop-games.ts): balance, ricochet and
## maze rules, their five levels each and the fixed-step physics. Board units, x across and
## z toward the player (the far end is -z). Points are Vector2(x, z); boxes are
## {x, z, hx, hz}. No changes to the throw/world physics.
##
## won(points, result) fires on a win with result = {mode, level, attempts, failures, stars}.
##
## Ricochet hearts: the player has RICOCHET_HEARTS; every launch that misses (falls off the
## board or runs out of time) costs one (heart_lost). At none the round starts again with
## full hearts and the paddles as they first were (restarted): no game over, the score and
## progress stay. A cleared round refills them (reset).

signal won(points: int, result: Dictionary)
signal heart_lost(left: int)
signal restarted

const RICOCHET_HEARTS := 6
## How long the last miss lingers before the round restarts (the "out of hearts" beat).
const OUT_DELAY := 1.5

const TABLE_RADIUS := 0.14
const MIRROR_ANGLE_STEP := PI / 36.0
const STEP := 1.0 / 120.0
const LIMIT_X := 1.5
const LIMIT_Z := 1.7
const MAZE_WALL_HEIGHT := 0.24
const MAZE_WALL := 0.09
## No contact (sweep_box): t is INF.
const NO_HIT := Vector3(INF, 0, 0)

static var _levels := {}

var mode := "balance"
var level := 0
var phase := "ready"  # ready | playing | falling | won
var elapsed := 0.0
var delay := 0.0
var accumulator := 0.0
var attempts := 0
var failures := 0
var score := 0
var rounds := 0
var fall := 0.0
var ball := Vector2.ZERO
var velocity := Vector2.ZERO
var tilt := Vector2.ZERO
var stars := {}  # star index -> true (a Set)
var bounces := {}  # paddle index -> true (a Set)
var angles: Array = []
var level_count := 5
## Ricochet only (0 elsewhere): hearts left this round, and how many a round starts with.
var hearts := 0
var max_hearts := 0


static func p(x: float, z: float) -> Vector2:
	return Vector2(x, z)


## JS Math.round (halves toward +infinity).
static func js_round(v: float) -> float:
	return floorf(v + 0.5)


static func snap_mirror_angle(angle: float) -> float:
	return js_round(atan2(sin(angle), cos(angle)) / MIRROR_ANGLE_STEP) * MIRROR_ANGLE_STEP


static func segment_distance(q: Vector2, a: Vector2, b: Vector2) -> float:
	var x := b.x - a.x
	var z := b.y - a.y
	var l := x * x + z * z
	var t := clampf(((q.x - a.x) * x + (q.y - a.y) * z) / (l if l != 0.0 else 1.0), 0.0, 1.0)
	return Vector2(q.x - a.x - x * t, q.y - a.y - z * t).length()


static func _sgn(v: float) -> float:
	return 1.0 if v > 0.0 else (-1.0 if v < 0.0 else 0.0)


## Continuous expanded-box sweep; handles a ball already inside as well. Returns
## Vector3(t, nx, nz) or NO_HIT.
static func sweep_box(start: Vector2, delta: Vector2, bx: float, bz: float, bhx: float, bhz: float, angle := 0.0, radius := TABLE_RADIUS) -> Vector3:
	var c := cos(angle)
	var s := sin(angle)
	var x := (start.x - bx) * c + (start.y - bz) * s
	var z := -(start.x - bx) * s + (start.y - bz) * c
	var dx := delta.x * c + delta.y * s
	var dz := -delta.x * s + delta.y * c
	var hx := bhx + radius
	var hz := bhz + radius
	var enter := 0.0
	var leave := 1.0
	var nx := 0.0
	var nz := 0.0
	# x axis
	if absf(dx) < 1e-10:
		if absf(x) > hx:
			return NO_HIT
	else:
		var near := (-hx - x) / dx
		var far := (hx - x) / dx
		if near > far:
			var tmp := near
			near = far
			far = tmp
		if near > enter:
			enter = near
			nx = -_sgn(dx)
			nz = 0.0
		leave = minf(leave, far)
		if enter > leave:
			return NO_HIT
	# z axis
	if absf(dz) < 1e-10:
		if absf(z) > hz:
			return NO_HIT
	else:
		var near := (-hz - z) / dz
		var far := (hz - z) / dz
		if near > far:
			var tmp := near
			near = far
			far = tmp
		if near > enter:
			enter = near
			nx = 0.0
			nz = -_sgn(dz)
		leave = minf(leave, far)
		if enter > leave:
			return NO_HIT
	if leave < 0.0 or enter > 1.0:
		return NO_HIT
	if nx == 0.0 and nz == 0.0:
		if absf(x) >= hx or absf(z) >= hz:
			return NO_HIT
		if hx - absf(x) < hz - absf(z):
			nx = _sgn(x)
			if nx == 0.0:
				nx = -_sgn(dx)
			if nx == 0.0:
				nx = 1.0
		else:
			nz = _sgn(z)
			if nz == 0.0:
				nz = -_sgn(dz)
			if nz == 0.0:
				nz = 1.0
		if dx * nx + dz * nz >= 0.0:
			return NO_HIT
	return Vector3(enter, nx * c - nz * s, nx * s + nz * c)


static func sweep(start: Vector2, delta: Vector2, box: Dictionary, angle := 0.0) -> Vector3:
	return sweep_box(start, delta, box.x, box.z, box.hx, box.hz, angle)


# ---------- levels ----------

static func balance_levels() -> Array:
	if not _levels.has("balance"):
		_levels.balance = [
			{"path": [p(-1, 1.25), p(-1, 0), p(1, 0), p(1, -1.25)], "width": 0.49, "holes": [{"p": p(-0.72, 0.5), "r": 0.14}, {"p": p(0.35, -0.25), "r": 0.14}], "stars": [p(-1, 0.6), p(0, 0), p(1, -0.65)]},
			{"path": [p(-1, 1.25), p(-1, 0.55), p(0.85, 0.55), p(0.85, -0.6), p(-0.85, -0.6), p(-0.85, -1.25), p(1, -1.25)], "width": 0.33, "holes": [{"p": p(-0.5, 0.82), "r": 0.16}, {"p": p(0.36, -0.85), "r": 0.16}], "stars": [p(0, 0.55), p(0.85, -0.15), p(-0.85, -0.95)]},
			{"path": [p(-1, 1.25), p(-1, 0.5), p(1, 0.5), p(1, -0.5), p(-1, -0.5), p(-1, -1.25), p(1, -1.25)], "width": 0.30, "holes": [], "stars": [p(-0.5, 0.5), p(1, -0.5), p(-1, -1.25)], "gate": p(0, 0.5)},
			{"path": [p(-1.12, 1.27), p(-0.1, 1.27), p(-0.1, 0.45), p(1.05, 0.45), p(1.05, -0.4), p(-1.05, -0.4), p(-1.05, -1.22), p(1.05, -1.22)], "width": 0.27, "holes": [{"p": p(-0.34, 1.01), "r": 0.13}], "stars": [p(-0.1, 0.75), p(1.05, -0.1), p(-1.05, -0.85)], "gate": p(0, -0.4)},
			{"path": [p(-1.05, 1.25), p(0, 0.6), p(-1.05, -0.1), p(0, -0.75), p(1.05, -0.1), p(1.05, -1.25)], "width": 0.24, "holes": [], "stars": [p(0, 0.6), p(-1.05, -0.1), p(0, -0.75)], "gate": p(0, -0.75), "gateTravel": 0.74},
		]
	return _levels.balance


## Put the reflecting face behind the intended sphere-centre contact point.
static func mirror(contact: Vector2, incoming: Vector2, outgoing: Vector2) -> Dictionary:
	var n := outgoing - incoming
	var k := n.length()
	var r := TABLE_RADIUS + 0.045
	return {"x": contact.x - n.x / k * r, "z": contact.y - n.y / k * r, "angle": atan2(-n.x, n.y), "length": 0.91}


static func reflection_route(route: Array, obstacles: Array, length: float) -> Dictionary:
	var mirrors := []
	for i in range(1, route.size() - 1):
		var q: Vector2 = route[i]
		var m := mirror(q, (q - route[i - 1]).normalized(), (route[i + 1] - q).normalized())
		m.length = length
		mirrors.append(m)
	return {"start": route[0], "goal": route[route.size() - 1], "mirrors": mirrors, "solution": mirrors.map(func(m): return m.angle), "obstacles": obstacles, "required": mirrors.size()}


static func ricochet_levels() -> Array:
	if not _levels.has("ricochet"):
		# Leave enough space for the full paddle (including its wooden caps) to rotate
		# inside the tray, not merely for its centre to lie on the play surface.
		var a := mirror(p(-0.82, -1.02), p(0, -1), p(1, 0))
		var b := mirror(p(0.82, -1.02), p(1, 0), p(0, 1))
		var c := mirror(p(0.82, 1.02), p(0, 1), p(-1, 0))
		_levels.ricochet = [
			{"start": p(-0.82, 1.25), "goal": p(0.82, -1.02), "mirrors": [a], "solution": [a.angle], "obstacles": [{"x": 0.0, "z": 0.18, "hx": 0.16, "hz": 0.6}], "required": 1},
			{"start": p(-0.82, 1.25), "goal": p(0.82, 1.25), "mirrors": [a, b], "solution": [a.angle, b.angle], "obstacles": [{"x": 0.0, "z": 0.08, "hx": 0.30, "hz": 0.62}], "required": 2},
			{"start": p(-0.82, 1.25), "goal": p(-0.42, 1.02), "mirrors": [a, b, c], "solution": [a.angle, b.angle, c.angle], "obstacles": [{"x": 0.0, "z": 0.0, "hx": 0.30, "hz": 0.55}], "required": 3},
			reflection_route([p(-0.95, 1.25), p(-0.95, -1.06), p(0.9, -1.06), p(0.9, 0.8), p(-0.7, 0.8)], [{"x": 0.0, "z": -0.1, "hx": 0.27, "hz": 0.40}], 0.7),
			# Four paddles in a hook: up, across, back up the far side and in, then the last
			# leg runs back toward the player across his own first crossing. (The old 8.9-unit
			# loop needed all four paddles exact and an aim within ±1.5°; this one keeps a ~5°
			# window, ricochet_solver_test.)
			reflection_route([p(-0.85, 1.3), p(-0.85, 0.3), p(0.75, 0.3), p(0.75, -0.7), p(-0.05, -0.7), p(-0.05, 0.65)], [{"x": 0.38, "z": -0.2, "hx": 0.12, "hz": 0.18}], 0.8),
		]
	return _levels.ricochet


static func _edge(a: int, b: int) -> String:
	return "%d:%d" % [a, b] if a < b else "%d:%d" % [b, a]


## Fixed seeds define five repeatable mazes. A spanning tree keeps every cell reachable,
## including dead ends; the farthest cell is the finish. No holes.
static func maze_level(cols: int, rows: int, seed: int) -> Dictionary:
	var x_edge := LIMIT_X - MAZE_WALL / 2.0
	var z_edge := LIMIT_Z - MAZE_WALL / 2.0
	var dx := x_edge * 2.0 / cols
	var dz := z_edge * 2.0 / rows
	var centre := func(id: int) -> Vector2:
		return Vector2(-x_edge + (id % cols + 0.5) * dx, -z_edge + (floori(float(id) / cols) + 0.5) * dz)
	var start := (rows - 1) * cols
	var parents := {start: -1}
	var stack := [start]
	var open := {}
	while not stack.is_empty():
		var a: int = stack[stack.size() - 1]
		var x := a % cols
		var z := floori(float(a) / cols)
		var choices := []
		for xz in [[x - 1, z], [x + 1, z], [x, z - 1], [x, z + 1]]:
			if xz[0] >= 0 and xz[0] < cols and xz[1] >= 0 and xz[1] < rows:
				var nb: int = xz[1] * cols + xz[0]
				if not parents.has(nb):
					choices.append(nb)
		if choices.is_empty():
			stack.pop_back()
			continue
		seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF
		var b: int = choices[seed % choices.size()]
		parents[b] = a
		open[_edge(a, b)] = true
		stack.append(b)
	var ids: Array = []
	for key in parents.keys():
		var path := []
		var id: int = key
		while id >= 0:
			path.append(id)
			id = parents[id]
		path.reverse()
		if path.size() > ids.size():
			ids = path
	var route := ids.map(func(i): return centre.call(i))
	var walls := [
		{"x": -x_edge, "z": 0.0, "hx": MAZE_WALL / 2.0, "hz": LIMIT_Z},
		{"x": x_edge, "z": 0.0, "hx": MAZE_WALL / 2.0, "hz": LIMIT_Z},
		{"x": 0.0, "z": -z_edge, "hx": LIMIT_X - MAZE_WALL, "hz": MAZE_WALL / 2.0},
		{"x": 0.0, "z": z_edge, "hx": LIMIT_X - MAZE_WALL, "hz": MAZE_WALL / 2.0},
	]
	var joints := {}
	for z in rows:
		for x in cols:
			var a := z * cols + x
			var c: Vector2 = centre.call(a)
			if x < cols - 1 and not open.has(_edge(a, a + 1)):
				walls.append({"x": c.x + dx / 2.0, "z": c.y, "hx": MAZE_WALL / 2.0, "hz": (dz - MAZE_WALL) / 2.0})
				for j in [[x + 1, z], [x + 1, z + 1]]:
					if j[0] > 0 and j[0] < cols and j[1] > 0 and j[1] < rows:
						joints["%d:%d" % j] = j
			if z < rows - 1 and not open.has(_edge(a, a + cols)):
				walls.append({"x": c.x, "z": c.y + dz / 2.0, "hx": (dx - MAZE_WALL) / 2.0, "hz": MAZE_WALL / 2.0})
				for j in [[x, z + 1], [x + 1, z + 1]]:
					if j[0] > 0 and j[0] < cols and j[1] > 0 and j[1] < rows:
						joints["%d:%d" % j] = j
	# Butt joints fill the junctions exactly once. Overlapping grain-covered tops at the
	# same height would fight in the depth buffer as the board tilts.
	for key in joints:
		var j: Array = joints[key]
		walls.append({"x": -x_edge + j[0] * dx, "z": -z_edge + j[1] * dz, "hx": MAZE_WALL / 2.0, "hz": MAZE_WALL / 2.0})
	var n := route.size() - 1
	return {"start": route[0], "goal": route[n], "walls": walls, "route": route,
		"stars": [route[floori(n * 0.25)], route[floori(n * 0.5)], route[floori(n * 0.75)]]}


static func maze_levels() -> Array:
	if not _levels.has("maze"):
		_levels.maze = [maze_level(3, 3, 17), maze_level(3, 4, 28), maze_level(4, 4, 39), maze_level(4, 5, 50), maze_level(5, 5, 61)]
	return _levels.maze


static func levels_of(m: String) -> Array:
	return balance_levels() if m == "balance" else (ricochet_levels() if m == "ricochet" else maze_levels())


# ---------- the game ----------

func _init(mode_ := "balance") -> void:
	mode = mode_ if mode_ in ["balance", "ricochet", "maze"] else "balance"
	level_count = levels_of(mode).size()
	max_hearts = RICOCHET_HEARTS if mode == "ricochet" else 0
	reset()


func definition() -> Dictionary:
	return levels_of(mode)[level]


func start_point() -> Vector2:
	var l := definition()
	return l.path[0] if mode == "balance" else l.start


## The finish: the balance path's end, or the goal.
func end_point() -> Vector2:
	var l := definition()
	return l.path[l.path.size() - 1] if mode == "balance" else l.goal


func reset(next_level = null) -> void:
	var n: float = float(level) if next_level == null else float(next_level)
	if is_nan(n) or is_inf(n):
		n = 0.0
	level = ((int(n) % level_count) + level_count) % level_count
	phase = "ready"
	elapsed = 0.0
	delay = 0.0
	accumulator = 0.0
	fall = 0.0
	velocity = Vector2.ZERO
	tilt = Vector2.ZERO
	stars.clear()
	bounces.clear()
	attempts = 0
	failures = 0
	hearts = max_hearts
	ball = start_point()
	angles = []
	if mode == "ricochet":
		var ms: Array = definition().mirrors
		for i in ms.size():
			angles.append(snap_mirror_angle(ms[i].angle + (-0.32 if i % 2 else 0.32)))


func _retry() -> void:
	phase = "ready"
	elapsed = 0.0
	delay = 0.0
	fall = 0.0
	velocity = Vector2.ZERO
	stars.clear()
	bounces.clear()
	ball = start_point()


## The player's retry (recall): counts as a failure.
func retry() -> void:
	failures += 1
	_retry()
	accumulator = 0.0


func _win() -> void:
	if phase == "won":
		return
	phase = "won"
	delay = 1.7
	var points := maxi(1, 4 - attempts) if mode == "ricochet" else 3
	score += points
	rounds += 1
	won.emit(points, {"mode": mode, "level": level, "attempts": attempts, "failures": failures, "stars": stars.size()})


func _fail() -> void:
	phase = "falling"
	delay = 0.8
	fall = 0.0
	failures += 1
	velocity = Vector2.ZERO
	if max_hearts > 0:
		hearts = maxi(0, hearts - 1)
		if hearts == 0:
			delay = OUT_DELAY
		heart_lost.emit(hearts)


## The round again from the top with full hearts (ricochet, out of hearts): the paddles as
## they first were; the score, the rounds and the unlocks stay.
func restart() -> void:
	reset(level)
	restarted.emit()


## The moving gate of a balance level, or {} (a box {x, z, hx, hz}).
func gate() -> Dictionary:
	if mode != "balance":
		return {}
	var l := definition()
	if not l.has("gate"):
		return {}
	var g: Vector2 = l.gate
	return {"x": g.x, "z": g.y + sin(elapsed * 1.5) * float(l.get("gateTravel", 0.43)), "hx": 0.08, "hz": 0.21}


func set_tilt(x: float, z: float) -> void:
	tilt.x = clampf(x if is_finite(x) else 0.0, -0.32, 0.32)
	tilt.y = clampf(z if is_finite(z) else 0.0, -0.32, 0.32)


func turn_mirror(index: int, angle: float) -> bool:
	if mode != "ricochet" or phase == "playing" or phase == "won" or not is_finite(angle) or index < 0 or index >= angles.size():
		return false
	angles[index] = snap_mirror_angle(angle)
	return true


func launch(direction: Vector2) -> bool:
	if mode != "ricochet" or phase != "ready" or not is_finite(direction.x) or not is_finite(direction.y):
		return false
	var d := direction.length()
	if d < 0.001:
		return false
	attempts += 1
	bounces.clear()
	phase = "playing"
	elapsed = 0.0
	velocity = direction / d * 3.4
	return true


func _step_balance(dt: float) -> void:
	var l := definition()
	velocity.x += sin(tilt.x) * 7.0 * dt
	velocity.y += sin(tilt.y) * 7.0 * dt
	velocity *= exp(-1.8 * dt)
	var previous := ball
	ball += velocity * dt
	var g := gate()
	if not g.is_empty():
		var hit := sweep(previous, ball - previous, g)
		if hit.x != INF:
			var n := Vector2(hit.y, hit.z)
			ball = previous + (ball - previous) * hit.x + n * 0.002
			var v := velocity.dot(n)
			if v < 0.0:
				velocity -= n * v * 1.3
	var path: Array = l.path
	var supported := false
	for i in range(1, path.size()):
		if segment_distance(ball, path[i - 1], path[i]) <= l.width:
			supported = true
			break
	var holed := false
	for h in l.holes:
		if (h.p as Vector2).distance_to(ball) < h.r * 0.8:
			holed = true
	if not supported or holed:
		_fail()
		return
	for i in l.stars.size():
		if (l.stars[i] as Vector2).distance_to(ball) < 0.24:
			stars[i] = true
	if stars.size() == l.stars.size() and ball.distance_to(path[path.size() - 1]) < 0.24:
		_win()


func _step_ricochet(dt: float) -> void:
	var l := definition()
	var left := dt
	# Several contacts in one fixed tick remain ordered along the actual travelled path.
	var iteration := 0
	while iteration < 5 and left > 1e-7 and phase == "playing":
		iteration += 1
		var delta := velocity * left
		var nearest := NO_HIT
		var board := -1
		for i in l.mirrors.size():
			var m: Dictionary = l.mirrors[i]
			var hit := sweep_box(ball, delta, m.x, m.z, m.length / 2.0, 0.045, angles[i])
			if hit.x < nearest.x:
				nearest = hit
				board = i
		for b in l.obstacles:
			var hit := sweep(ball, delta, b)
			if hit.x < nearest.x:
				nearest = hit
				board = -1
		var travel := nearest.x if nearest.x != INF else 1.0
		var end := ball + delta * travel
		if bounces.size() >= l.required and segment_distance(l.goal, ball, end) < 0.24:
			ball = l.goal
			velocity = Vector2.ZERO
			_win()
			break
		ball = end
		if nearest.x == INF:
			break
		var n := Vector2(nearest.y, nearest.z)
		ball += n * 0.001
		var v := velocity.dot(n)
		if v < 0.0:
			velocity -= 2.0 * n * v
			if board >= 0:
				bounces[board] = true
			else:
				velocity *= 0.8
		left *= 1.0 - nearest.x
	if phase == "playing" and (absf(ball.x) > LIMIT_X + TABLE_RADIUS or absf(ball.y) > LIMIT_Z + TABLE_RADIUS or elapsed > 8.0):
		_fail()


func _step_maze(dt: float) -> void:
	var l := definition()
	var drag := exp(-2.4 * dt)
	velocity.x = (velocity.x + sin(tilt.x) * 7.0 * dt) * drag
	velocity.y = (velocity.y + sin(tilt.y) * 7.0 * dt) * drag
	var left := dt
	var walls: Array = l.walls
	var reach := TABLE_RADIUS + 0.001
	# Sweep each segment, then slide along the contacted wall. Multiple contacts in a
	# corner cannot skip a wall or transfer the ball through a thin divider.
	for _i in 6:
		if left <= 1e-7:
			break
		var delta := velocity * left
		var hit := NO_HIT
		var ax := absf(delta.x) + reach
		var az := absf(delta.y) + reach
		for w in walls:
			# Broad phase (same result): a wall the swept ball cannot reach is skipped.
			if absf(ball.x + delta.x * 0.5 - w.x) > w.hx + ax or absf(ball.y + delta.y * 0.5 - w.z) > w.hz + az:
				continue
			var contact := sweep_box(ball, delta, w.x, w.z, w.hx, w.hz)
			if contact.x < hit.x:
				hit = contact
		var end := ball + delta * (hit.x if hit.x != INF else 1.0)
		for i in l.stars.size():
			if segment_distance(l.stars[i], ball, end) < 0.22:
				stars[i] = true
		if stars.size() == 3 and segment_distance(l.goal, ball, end) < 0.22:
			ball = l.goal
			velocity = Vector2.ZERO
			_win()
			return
		ball = end
		if hit.x == INF:
			break
		var n := Vector2(hit.y, hit.z)
		ball += n * 0.0001
		var inward := velocity.dot(n)
		if inward < 0.0:
			velocity -= n * inward
		left *= 1.0 - hit.x


## Freeze exactly during menus, tracking loss and a released balance grip. No catch-up burst.
func step(dt: float, active := true) -> void:
	if not active or not is_finite(dt) or dt <= 0.0:
		accumulator = 0.0
		return
	accumulator += minf(dt, 0.05)
	while accumulator >= STEP:
		accumulator -= STEP
		if phase == "won" or phase == "falling":
			delay -= STEP
			if phase == "falling":
				fall += STEP * 1.6
			if delay <= 0.0:
				if phase == "won":
					reset(level + 1)
				elif max_hearts > 0 and hearts <= 0:
					restart()
				else:
					_retry()
			continue
		if mode == "balance":
			phase = "playing"
			elapsed += STEP
			_step_balance(STEP)
		elif mode == "maze":
			phase = "playing"
			_step_maze(STEP)
		elif phase == "playing":
			elapsed += STEP
			_step_ricochet(STEP)
