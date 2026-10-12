class_name Ball
extends RefCounted
## Dahrooj's flight, ported from the web game's reference state
## (src/reference/game-state.js): game units (ball radius 0.24, gravity 13), three
## sub-steps per update, the same drag, bounce, roll friction, moods and the
## volley of earlier throws still in the air. The stage supplies collisions and
## scoring through a small interface (collide, update, friction, shot_time,
## touched, on_throw, on_respawn).

signal event(kind: String, data: Dictionary)  # thump, whoosh, success, miss, ooh, splash

const BR := 0.24
const GRAV := 13.0
const UP := Vector3.UP
const VOLLEY_MAX := 3

var stage = null
var stage_name := "goal"
var time := 0.0
var water = null  # optional: depth(x, z) -> float, for the park's pond

# The ball ("S" in the reference).
var pos := Vector3(0, BR + 1.2, 0)
var vel := Vector3.ZERO
var side := Vector3.ZERO
var axis := UP
var d := 0.0
var dv := 0.0
var shot := false
var shot_t := 0.0
var z_max := 6.0
var x_max := 16.0
var scored_t := 0.0
var miss_t := 0.0
var mood := ""
var mood_t := 0.0
var mood_next := ""
var idle := 0.0
var rest_t := 0.0
var hit_t := 0.0
var blink := 0.0
var next_blink := 2.0
var grounded := false
var last_hit := 0.0
var prev := Vector3.ZERO
var wet := false
var held := false
var throw_curve := false
var shot_id := 0
var _next_shot_id := 0
var volley: Array = []
var _rng := RandomNumberGenerator.new()

const _KEYS := ["pos", "vel", "side", "axis", "d", "dv", "shot", "shot_t", "z_max", "x_max", "scored_t",
	"miss_t", "mood", "mood_t", "mood_next", "idle", "rest_t", "hit_t", "blink", "next_blink", "grounded",
	"last_hit", "prev", "wet", "throw_curve", "shot_id"]


func _init() -> void:
	_rng.seed = 2026


func set_stage(s, id: String) -> void:
	stage = s
	stage_name = id
	volley.clear()
	respawn()


func hit(n: Vector3, speed: float, _contact: Vector3) -> void:
	var s := minf(1.0, speed / 14.0)
	if s < 0.05:
		return
	axis = n
	if d < 0.0:
		d *= 0.3
	dv += 4.0 + s * 16.0
	last_hit = time
	event.emit("thump", {"k": s, "pos": pos})
	if s > 0.55:
		hit_t = 0.28


func react(kind: String, dur: float, next := "") -> void:
	mood = kind
	mood_t = dur
	mood_next = next


func success() -> void:
	if scored_t > 0.0 or miss_t > 0.0:
		return
	scored_t = 1.7
	react("joy", 1.7)
	event.emit("success", {"pos": pos, "mode": stage_name, "curve": throw_curve})


func miss() -> void:
	if scored_t > 0.0 or miss_t > 0.0:
		return
	if stage and stage.has_method("touched") and stage.touched():
		miss_t = 1.0
		return
	miss_t = 1.7
	if mood == "wide" and mood_t > 0.0:
		mood_next = "laugh"
	else:
		react("laugh", 1.7)
	event.emit("miss", {"pos": pos, "mode": stage_name})


func ooh() -> void:
	if shot and scored_t <= 0.0 and miss_t <= 0.0 and mood != "wide":
		react("wide", 0.55)


func respawn() -> void:
	miss_t = 0.0
	mood = ""
	mood_t = 0.0
	idle = 0.0
	pos = Vector3(0, BR + 1.0, 0)
	vel = Vector3.ZERO
	side = Vector3.ZERO
	wet = false
	shot = false
	scored_t = 0.0
	rest_t = 0.0
	d = 0.0
	dv = 0.0
	grounded = false
	z_max = 6.0
	x_max = 16.0
	if stage and stage.has_method("on_respawn"):
		stage.on_respawn()


## v: launch velocity in game units per game second; curve -1..1 bends the flight.
func throw_with(v: Vector3, curve := 0.0) -> void:
	var sp := v.length()
	held = false
	vel = v
	side = Vector3.ZERO
	if curve != 0.0:
		var f := Vector3(v.x, 0, v.z)
		if f.length_squared() > 1e-6:
			f = f.normalized()
			side = Vector3(-f.z, 0, f.x) * clampf(curve, -1.0, 1.0) * 9.0
	_next_shot_id += 1
	shot_id = _next_shot_id
	throw_curve = absf(curve) > 0.12
	shot = true
	shot_t = 0.0
	grounded = false
	prev = pos
	z_max = maxf(6.0, pos.z + 3.0)
	x_max = maxf(16.0, absf(pos.x) + 6.0)
	axis = UP
	dv -= 6.0 + minf(1.0, sp / 18.0) * 8.0
	event.emit("whoosh", {"k": minf(1.0, sp / 18.0), "pos": pos})
	if stage and stage.has_method("on_throw"):
		stage.on_throw()


func face() -> String:
	if hit_t > 0.0:
		return "closed"
	if mood != "" and mood_t > 0.0:
		return mood
	if held:
		return "focus"
	if shot and not grounded and vel.length() > 9.0:
		return "wide"
	return "open"


func can_hold() -> bool:
	return not shot and scored_t <= 0.0 and miss_t <= 0.0


## One sub-step of flight. extra: an earlier throw in the volley (no stage update).
## Returns true when a volley ball is finished.
func _ball_step(dt: float, extra: bool) -> bool:
	prev = pos
	if not grounded:
		vel.y -= GRAV * dt
		vel.x += side.x * dt
		vel.z += side.z * dt
	vel *= pow(0.9, dt)
	pos += vel * dt
	var in_water: bool = water != null and water.depth(pos.x, pos.z) > 0.0
	if in_water and pos.y < BR:
		if not wet:
			wet = true
			event.emit("splash", {"pos": pos, "k": minf(1.0, (-vel.y + Vector2(vel.x, vel.z).length() * 0.3) / 12.0)})
			side = Vector3.ZERO
		grounded = false
		vel.y += (GRAV + (-BR * 0.2 - pos.y) * 38.0 - vel.y * 4.5) * dt
		var f := pow(0.3, dt)
		vel.x *= f
		vel.z *= f
		if pos.y < -BR * 0.85:
			pos.y = -BR * 0.85
			if vel.y < 0.0:
				vel.y = 0.0
	else:
		if pos.y > BR * 1.2:
			wet = false
		if pos.y < BR:
			pos.y = BR
			if vel.y < -1.4:
				hit(UP, -vel.y, Vector3(pos.x, 0, pos.z))
				vel.y = -vel.y * 0.55
				vel.x *= 0.85
				vel.z *= 0.85
				side = Vector3.ZERO
			else:
				vel.y = 0.0
				grounded = true
		elif grounded and pos.y > BR + 0.01:
			grounded = false
	if grounded:
		var fr := pow(float(stage.get("friction") if stage and stage.get("friction") != null else 0.7), dt)
		vel.x *= fr
		vel.z *= fr
		side = Vector3.ZERO
	if stage:
		stage.collide(self)
		if not extra:
			stage.update(self, dt)
	if shot:
		shot_t += dt
		var still := (grounded or wet) and vel.length() < 0.35
		rest_t = rest_t + dt if still else 0.0
		var shot_time: float = stage.get("shot_time") if stage and stage.get("shot_time") != null else 5.0
		if scored_t > 0.0:
			scored_t -= dt
			if scored_t <= 0.0:
				return _end(extra)
		elif miss_t > 0.0:
			miss_t -= dt
			if miss_t <= 0.0:
				return _end(extra)
		elif rest_t > 0.5 or shot_t > shot_time or absf(pos.x) > x_max or pos.z < -34.0 or pos.z > z_max:
			miss()
	return false


func _end(extra: bool) -> bool:
	if extra:
		return true
	respawn()
	return false


func _snap() -> Dictionary:
	var o := {}
	for k in _KEYS:
		o[k] = get(k)
	return o


func _load(o: Dictionary) -> void:
	for k in _KEYS:
		set(k, o[k])


## Keep the ball in flight as part of the volley and free the main ball for a new throw.
func another() -> bool:
	if not shot:
		return false
	if volley.size() >= VOLLEY_MAX:
		volley.pop_front()
	volley.append(_snap())
	miss_t = 0.0
	mood = ""
	mood_t = 0.0
	idle = 0.0
	shot = false
	scored_t = 0.0
	rest_t = 0.0
	d = 0.0
	dv = 0.0
	vel = Vector3.ZERO
	side = Vector3.ZERO
	return true


func _step_volley(dt: float) -> void:
	if volley.is_empty():
		return
	var main := _snap()
	var was_held := held
	held = false
	for i in range(volley.size() - 1, -1, -1):
		_load(volley[i])
		var done := _ball_step(dt, true)
		dv += ((0.0 - d) * 420.0 - dv * 13.0) * dt
		d = clampf(d + dv * dt, -0.3, 0.5)
		if mood_t > 0.0:
			mood_t -= dt
		hit_t = maxf(0.0, hit_t - dt)
		if done:
			volley.remove_at(i)
		else:
			volley[i] = _snap()
	_load(main)
	held = was_held


func _update3(dt: float) -> void:
	if held:
		if stage:
			stage.update(self, dt)
		_step_volley(dt)
	else:
		_ball_step(dt, false)
		_step_volley(dt)
	if mood_t > 0.0:
		mood_t -= dt
		if mood_t <= 0.0:
			if mood_next != "":
				react(mood_next, 1.4)
			else:
				mood = ""
	if mood == "joy" and grounded and vel.y == 0.0 and mood_t > 0.5:
		vel.y = 3.6
		grounded = false
	idle = 0.0 if shot else idle + dt
	var speed := vel.length()
	var target := 0.0
	if not grounded and speed > 2.0 and time - last_hit > 0.12:
		if absf(d) < 0.12:
			axis = vel.normalized()
		target = -minf(0.22, speed / 90.0)
	elif grounded:
		axis = UP
		target = 0.018 * sin(time * 2.4)
	dv += ((target - d) * 420.0 - dv * 13.0) * dt
	d = clampf(d + dv * dt, -0.3, 0.5)
	next_blink -= dt
	if next_blink <= 0.0:
		blink = 0.14
		next_blink = 2.0 + _rng.randf() * 3.5
	blink = maxf(0.0, blink - dt)
	hit_t = maxf(0.0, hit_t - dt)


## Advance game time by dt (game seconds): three sub-steps, as the reference does.
func step(dt: float) -> void:
	time += dt
	for i in 3:
		_update3(dt / 3.0)


# --- collision helpers shared by the stages (stage-art.js segCollide / pointCollide) ---

func seg_collide(a: Vector3, b: Vector3, r: float, e := 0.7) -> bool:
	var ab := b - a
	var t := clampf((pos - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return point_collide(a + ab * t, r, e)


func point_collide(cp: Vector3, r: float, e := 0.7) -> bool:
	var n := pos - cp
	var dist := n.length()
	if dist > 0.0 and dist < BR + r:
		n /= dist
		pos = cp + n * (BR + r)
		var vn := vel.dot(n)
		if vn < 0.0:
			hit(n, -vn, cp + n * r)
			vel -= n * (1.0 + e) * vn
			side = Vector3.ZERO
		return true
	return false
