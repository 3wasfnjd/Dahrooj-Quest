class_name SummitCore
extends RefCounted
## The Summit's rules (src/reference/summit-core.js), line for line: a side-on climb up
## four themed sections (meadow, cliffs, caves, snow) to a flag at height 148. Units are
## Dahrooj's radius (1); x runs 0..width across the face, y up from the starting ground.
## Platforms move, crumble, freeze or carry spikes; crawlers walk ledges, bats swoop,
## potted spitters shoot seeds, icicles drop. Three hearts; losing them pops Dahrooj
## back at the last checkpoint ledge (36, 72, 108). Stomping a monster from above or
## hitting it with a thrown ball defeats it. step() pushes events into state.events:
## hurt, pop, land, launch, throw, stomp, kill, spit, checkpoint, summit.
##
## The state is plain Dictionaries, like the JS objects (a monster's plat and the ball's
## on refer to the platform dictionaries themselves). JS null for a platform's
## checkpoint is -1 here.

const G := 60.0
const MAX_HEARTS := 3
const MAX_WIDTH := 18.0
const HIT := 0.82  # hazard contact radius, smaller than the drawn ball
const RUN := 10.0
const JUMP := 28.0
const ACCEL := 70.0
const ACCEL_ICE := 14.0
const ACCEL_AIR := 34.0
const COYOTE := 0.1
const BUFFER := 0.13
# Small thrown balls: aim at the nearest monster ahead, otherwise fly straight ahead.
const SHOT_SPEED := 18.0
const SHOT_LIFE := 1.1
const SHOT_COOL := 0.32
const SHOT_MAX := 3
const SHOT_R := 0.32
const AIM_RANGE := 10.0
const THEMES := ["meadow", "cliffs", "caves", "snow"]
# [x as a fraction of the playable width, top surface height, width, options]
const SECTIONS := [
	{"from": 0, "platforms": [
		[0.32, 4, 4.2, {}], [0.70, 8, 4, {"crawler": 1}], [0.36, 12, 3.6, {}], [0.66, 16, 3.6, {"move": [0.14, 1.1]}],
		[0.38, 20, 3.4, {"crawler": 1}], [0.14, 24, 3.2, {}], [0.50, 28, 3.6, {}], [0.82, 32, 3.2, {}]],
		"bats": [], "icicles": []},
	{"from": 36, "platforms": [
		[0.28, 40, 3.2, {"crumble": 1}], [0.66, 44, 3.6, {"spikes": [0, 0.45]}], [0.36, 48, 3, {"crumble": 1}],
		[0.74, 52, 3.2, {"spitter": 0.75}], [0.44, 56, 2.8, {}], [0.16, 60, 3, {"crumble": 1}], [0.56, 64, 3.4, {"crawler": 1}], [0.84, 68, 2.8, {}]],
		"bats": [[46.5, 0.12, 0.62, 0.7, 0], [58.5, 0.38, 0.88, 0.8, 2]], "icicles": []},
	{"from": 72, "platforms": [
		[0.5, 76, 3.2, {"move": [0.2, 0.9]}], [0.2, 80, 3, {"spitter": 0.3}], [0.66, 84, 2.8, {"move": [0.16, 1.6]}],
		[0.38, 88, 3, {"spikes": [0.55, 1]}], [0.78, 92, 2.6, {"crumble": 1}], [0.5, 96, 3, {"crawler": 1}],
		[0.2, 100, 2.8, {"move": [0.12, 1.3]}], [0.6, 104, 2.8, {"spitter": 0.7}]],
		"bats": [[86.5, 0.15, 0.7, 1, 1], [98.5, 0.1, 0.5, 1.1, 0], [98.5, 0.55, 0.9, 1, 3]], "icicles": []},
	{"from": 108, "platforms": [
		[0.3, 112, 3.2, {"ice": 1}], [0.7, 116, 3, {"ice": 1}], [0.4, 120, 2.8, {"ice": 1, "crumble": 1}], [0.12, 124, 2.8, {"ice": 1}],
		[0.5, 128, 2.8, {"ice": 1, "move": [0.15, 1.2]}], [0.84, 132, 2.6, {"ice": 1}], [0.52, 136, 2.8, {"ice": 1, "crawler": 1}],
		[0.2, 140, 2.6, {"ice": 1}], [0.6, 144, 2.6, {"ice": 1, "spitter": 0.5}]],
		"bats": [[122.5, 0.3, 0.9, 1.1, 1], [134.5, 0.15, 0.7, 1.3, 2]], "icicles": [[0.68, 119.5], [0.5, 131.5], [0.22, 147.4]]},
]
const TOP := 148.0


## JS clamp: max(a, min(b, n)) (a wins when a > b, unlike clampf).
static func clamp_js(n: float, a: float, b: float) -> float:
	return maxf(a, minf(b, n))


static func _full(width: float, y: float, theme: int) -> Dictionary:
	return {"x0": 0.0, "x1": width, "base": 0.0, "w": width, "y": y, "theme": theme, "full": true, "dx": 0.0,
		"ground": false, "checkpoint": -1, "summit": false, "ice": false, "spikes": null, "move": null, "crumble": null}


static func build_level(width: float) -> Dictionary:
	var platforms: Array = []
	var monsters: Array = []
	var bats: Array = []
	var icicles: Array = []
	var ground := _full(width, 0.0, 0)
	ground.ground = true
	ground.checkpoint = 0
	platforms.append(ground)
	for s in SECTIONS.size():
		var section: Dictionary = SECTIONS[s]
		for row: Array in section.platforms:
			var fx: float = row[0]
			var y: float = row[1]
			var w: float = row[2]
			var o: Dictionary = row[3]
			var x0 := clamp_js(fx * width - w / 2.0, 0.2, width - 0.2 - w)
			var p := {"x0": x0, "x1": x0 + w, "base": x0, "w": w, "y": y, "theme": s, "dx": 0.0, "full": false,
				"ground": false, "checkpoint": -1, "summit": false, "ice": o.has("ice"),
				"spikes": o.spikes if o.has("spikes") else null,
				"move": {"amp": float(o.move[0]) * width, "speed": float(o.move[1]), "phase": y} if o.has("move") else null,
				"crumble": {"state": "solid", "t": 0.0} if o.has("crumble") else null}
			platforms.append(p)
			if o.has("crawler"):
				monsters.append({"type": "crawler", "plat": p, "x": x0 + w / 2.0, "y": y + 0.6,
					"dir": 1 if fmod(y, 8.0) != 0.0 else -1, "speed": 1.7, "alive": true, "t": 0.0})
			if o.has("spitter"):
				var f: float = o.spitter
				monsters.append({"type": "spitter", "plat": p, "f": f, "alive": true, "cool": 1.2 + fmod(y, 3.0) * 0.4,
					"t": 0.0, "swell": 0.0, "x": x0 + f * w, "y": y + 0.75})
		for bt: Array in section.bats:
			bats.append({"type": "bat", "y0": float(bt[0]), "x0": float(bt[1]) * width, "x1": float(bt[2]) * width,
				"speed": float(bt[3]), "phase": float(bt[4]), "alive": true, "x": 0.0, "y": float(bt[0]), "t": 0.0})
		for ic: Array in section.icicles:
			icicles.append({"x": clamp_js(float(ic[0]) * width, 0.6, width - 0.6), "y0": float(ic[1]), "y": float(ic[1]),
				"state": "hang", "t": 0.0, "vy": 0.0})
	var ledges := [36.0, 72.0, 108.0]
	for i in ledges.size():
		var l := _full(width, ledges[i], i)
		l.checkpoint = i + 1
		platforms.append(l)
	var summit := _full(width, TOP, 3)
	summit.summit = true
	platforms.append(summit)
	return {"width": width, "platforms": platforms, "monsters": monsters + bats, "icicles": icicles, "seeds": []}


static func create_state(width: float) -> Dictionary:
	var state := build_level(width)
	state.merge({"time": 0.0, "events": [], "checkpoint": 0, "won": false, "won_at": 0.0, "started_at": 0.0,
		"input": {"dir": 0.0, "buffer": 0.0}, "shots": [],
		"ball": {"x": width / 2.0, "y": 1.0, "vx": 0.0, "vy": 0.0, "grounded": true, "on": state.platforms[0],
			"hearts": MAX_HEARTS, "inv": 0.0, "dead": 0.0, "d": 0.0, "dv": 0.0, "best": 0.0, "coyote": 0.0,
			"stun": 0.0, "facing": 1.0, "cool": 0.0}})
	return state


static func solid(p) -> bool:
	return p.crumble == null or p.crumble.state != "fallen"


static func checkpoint_platform(state: Dictionary) -> Dictionary:
	for p: Dictionary in state.platforms:
		if p.checkpoint == state.checkpoint:
			return p
	return state.platforms[0]


static func reset_hazards(state: Dictionary) -> void:
	for p: Dictionary in state.platforms:
		if p.crumble != null:
			p.crumble.state = "solid"
			p.crumble.t = 0.0
	for m: Dictionary in state.monsters:
		m.alive = true
		m.t = 0.0
		if m.type == "crawler":
			m.x = (m.plat.x0 + m.plat.x1) / 2.0
	for i: Dictionary in state.icicles:
		i.state = "hang"
		i.y = i.y0
		i.vy = 0.0
		i.t = 0.0
	state.seeds.clear()
	state.shots.clear()


static func respawn(state: Dictionary) -> void:
	var b: Dictionary = state.ball
	var p := checkpoint_platform(state)
	b.merge({"x": state.width / 2.0, "y": p.y + 1.0, "vx": 0.0, "vy": 0.0, "grounded": true, "on": p,
		"hearts": MAX_HEARTS, "inv": 1.0, "dead": 0.0, "d": 0.0, "dv": 0.0, "coyote": 0.0, "stun": 0.0}, true)
	state.input.buffer = 0.0
	reset_hazards(state)


static func restart(state: Dictionary) -> void:
	state.checkpoint = 0
	state.won = false
	state.started_at = state.time
	state.ball.best = 0.0
	respawn(state)
	state.ball.inv = 0.0


static func hurt(state: Dictionary, from_x: float) -> void:
	var b: Dictionary = state.ball
	if b.inv > 0.0 or b.dead != 0.0 or state.won:
		return
	b.hearts -= 1
	state.events.append({"type": "hurt"})
	if b.hearts <= 0:
		b.dead = 0.001
		b.grounded = false
		state.events.append({"type": "pop", "x": b.x, "y": b.y})
		return
	b.inv = 1.6
	b.stun = 0.3
	b.grounded = false
	b.on = null
	b.coyote = 0.0
	b.vy = 14.0
	b.vx = (1.0 if b.x >= from_x else -1.0) * 8.0


## dir: -1 left, 0 stop, 1 right (fractions allowed). jump() is buffered briefly before landing.
static func set_dir(state: Dictionary, dir: float) -> void:
	state.input.dir = clamp_js(dir if is_finite(dir) else 0.0, -1.0, 1.0)


static func jump(state: Dictionary) -> void:
	if state.ball.dead == 0.0 and not state.won:
		state.input.buffer = BUFFER


static func monster_y(m: Dictionary) -> float:
	return m.plat.y + 0.6 if m.type == "crawler" else float(m.y)


static func throw_ball(state: Dictionary) -> bool:
	var b: Dictionary = state.ball
	if b.dead != 0.0 or state.won or b.cool > 0.0 or state.shots.size() >= SHOT_MAX:
		return false
	var vx: float = b.facing * SHOT_SPEED
	var vy := 3.0
	var best := AIM_RANGE
	for m: Dictionary in state.monsters:
		if not m.alive:
			continue
		var dx: float = m.x - b.x
		var dy: float = monster_y(m) - b.y
		var d := Vector2(dx, dy).length()
		# Ahead of Dahrooj, within about 70 degrees of the facing direction; lead for the shot's drop.
		if d < best and dx * b.facing > 0.0 and absf(dy) < absf(dx) * 2.8:
			best = d
			vx = dx / d * SHOT_SPEED
			vy = dy / d * SHOT_SPEED + G * 0.125 * d / SHOT_SPEED
	var sx := signf(vx) if vx != 0.0 else signf(b.facing)
	state.shots.append({"x": b.x + sx * 0.9, "y": b.y + 0.2, "vx": vx, "vy": vy, "t": 0.0})
	b.cool = SHOT_COOL
	state.events.append({"type": "throw"})
	return true


static func approach(v: float, target: float, rate: float) -> float:
	return minf(target, v + rate) if v < target else maxf(target, v - rate)


static func land(state: Dictionary, p: Dictionary, impact: float) -> void:
	var b: Dictionary = state.ball
	b.y = p.y + 1.0
	b.on = p
	b.dv += minf(18.0, impact * 0.9)
	state.events.append({"type": "land", "power": minf(1.0, impact / 30.0)})
	b.vy = 0.0
	b.grounded = true
	b.coyote = 0.0
	if p.crumble != null and p.crumble.state == "solid":
		p.crumble.state = "shaking"
		p.crumble.t = 0.0
	if p.checkpoint > state.checkpoint:
		state.checkpoint = p.checkpoint
		state.events.append({"type": "checkpoint", "index": p.checkpoint})
	if p.summit and not state.won:
		state.won = true
		state.won_at = state.time
		state.events.append({"type": "summit", "time": state.time - state.started_at})


static func on_spikes(p: Dictionary, x: float) -> bool:
	if p.spikes == null:
		return false
	var a: float = p.x0 + float(p.spikes[0]) * (p.x1 - p.x0)
	var c: float = p.x0 + float(p.spikes[1]) * (p.x1 - p.x0)
	return x > a - 0.45 and x < c + 0.45


static func step_world(state: Dictionary, dt: float) -> void:
	state.time += dt
	for p: Dictionary in state.platforms:
		if p.move != null:
			var x0: float = p.base + p.move.amp * sin(state.time * p.move.speed + p.move.phase)
			p.dx = x0 - p.x0
			p.x0 = x0
			p.x1 = x0 + p.w
		if p.crumble != null:
			var c: Dictionary = p.crumble
			c.t += dt
			if c.state == "shaking" and c.t > 0.6:
				c.state = "fallen"
				c.t = 0.0
			elif c.state == "fallen" and c.t > 3.0:
				c.state = "solid"
				c.t = 0.0
	var b: Dictionary = state.ball
	for m: Dictionary in state.monsters:
		m.t += dt
		if not m.alive:
			continue
		if m.type == "crawler":
			m.x += m.dir * m.speed * dt + m.plat.dx
			if m.x < m.plat.x0 + 0.7:
				m.x = m.plat.x0 + 0.7
				m.dir = 1
			if m.x > m.plat.x1 - 0.7:
				m.x = m.plat.x1 - 0.7
				m.dir = -1
			if not solid(m.plat):
				m.alive = false
		elif m.type == "bat":
			var k: float = (sin(m.t * m.speed + m.phase) + 1.0) / 2.0
			m.x = m.x0 + (m.x1 - m.x0) * k
			m.y = m.y0 + 0.6 * sin(m.t * 3.1 + m.phase)
		elif m.type == "spitter":
			m.x = m.plat.x0 + m.f * (m.plat.x1 - m.plat.x0)
			m.y = m.plat.y + 0.75
			m.cool -= dt
			m.swell = maxf(0.0, 1.0 - m.cool / 0.5)
			if m.cool <= 0.0:
				m.cool = 2.4
				if b.dead == 0.0 and absf(b.y - m.y) < 5.0 and absf(b.x - m.x) < 12.0:
					var dir := 1.0 if b.x >= m.x else -1.0
					state.seeds.append({"x": m.x + dir * 0.6, "y": m.y + 0.1, "vx": dir * 7.0, "t": 0.0})
					state.events.append({"type": "spit"})
	for s: Dictionary in state.seeds:
		s.x += s.vx * dt
		s.t += dt
	var w: float = state.width
	state.seeds = state.seeds.filter(func(s: Dictionary) -> bool: return s.t < 3.0 and s.x > -1.0 and s.x < w + 1.0)
	for i: Dictionary in state.icicles:
		i.t += dt
		if i.state == "hang" and b.dead == 0.0 and absf(b.x - i.x) < 1.7 and b.y < i.y and b.y > i.y - 9.0:
			i.state = "shake"
			i.t = 0.0
		elif i.state == "shake" and i.t > 0.45:
			i.state = "fall"
			i.t = 0.0
			i.vy = 0.0
		elif i.state == "fall":
			i.vy -= G * 0.8 * dt
			i.y += i.vy * dt
			if i.y < i.y0 - 12.0:
				i.state = "gone"
				i.t = 0.0
		elif i.state == "gone" and i.t > 3.0:
			i.state = "hang"
			i.y = i.y0
			i.t = 0.0


static func step_ball(state: Dictionary, dt: float) -> void:
	var b: Dictionary = state.ball
	var W: float = state.width
	b.inv = maxf(0.0, b.inv - dt)
	b.dv += (-b.d * 260.0 - b.dv * 12.0) * dt
	b.d = clampf(b.d + b.dv * dt, -0.25, 0.4)
	if b.dead != 0.0:
		b.dead += dt
		if b.dead > 1.1:
			respawn(state)
		return
	b.stun = maxf(0.0, b.stun - dt)
	b.coyote = maxf(0.0, b.coyote - dt)
	var input: Dictionary = state.input
	var dir: float = 0.0 if b.stun > 0.0 or state.won else float(input.dir)
	input.buffer = maxf(0.0, input.buffer - dt)
	b.cool = maxf(0.0, b.cool - dt)
	if dir != 0.0:
		b.facing = signf(dir)
	if b.grounded:
		var p = b.on
		if p == null or not solid(p):
			b.grounded = false
			b.on = null
			b.coyote = COYOTE
		else:
			b.x += p.dx
			b.y = p.y + 1.0
			b.vx = approach(b.vx, dir * RUN, (ACCEL_ICE if p.ice else ACCEL) * dt)
			b.x += b.vx * dt
			if not p.full and (b.x < p.x0 - 0.3 or b.x > p.x1 + 0.3):
				b.grounded = false
				b.on = null
				b.coyote = COYOTE
			elif on_spikes(p, b.x):
				hurt(state, (p.x0 + p.x1) / 2.0)
	if input.buffer > 0.0 and (b.grounded or b.coyote > 0.0) and b.dead == 0.0:
		b.vy = JUMP
		b.grounded = false
		b.on = null
		b.coyote = 0.0
		input.buffer = 0.0
		b.dv -= 6.0
		state.events.append({"type": "launch", "power": 0.6})
	if not b.grounded:
		var prev_bottom: float = b.y - 1.0
		b.vy = maxf(-40.0, b.vy - G * dt)
		if b.stun <= 0.0:
			b.vx = approach(b.vx, dir * RUN, ACCEL_AIR * dt)
		b.x += b.vx * dt
		b.y += b.vy * dt
		if b.vy <= 0.0:
			for p: Dictionary in state.platforms:
				if not solid(p):
					continue
				if prev_bottom >= p.y - 0.001 and b.y - 1.0 <= p.y and b.x >= p.x0 - 0.35 and b.x <= p.x1 + 0.35:
					land(state, p, -b.vy)
					if on_spikes(p, b.x):
						hurt(state, (p.x0 + p.x1) / 2.0)
					break
	if b.x < 1.0:
		b.x = 1.0
		b.vx = absf(b.vx) * 0.55
	if b.x > W - 1.0:
		b.x = W - 1.0
		b.vx = -absf(b.vx) * 0.55
	b.best = maxf(b.best, b.y - 1.0)
	# Monsters, seeds and icicles.
	for m: Dictionary in state.monsters:
		if not m.alive or b.dead != 0.0:
			continue
		var my: float = m.plat.y + 0.6 if m.type == "crawler" else float(m.y)
		var r := 0.45 if m.type == "bat" else 0.7
		if Vector2(b.x - m.x, b.y - my).length() > HIT + r:
			continue
		if m.type != "bat" and b.vy < -2.0 and b.y > my + 0.3:
			m.alive = false
			m.t = 0.0
			b.vy = 18.0
			b.grounded = false
			b.on = null
			state.events.append({"type": "stomp", "x": m.x, "y": my})
		else:
			hurt(state, m.x)
	for s: Dictionary in state.seeds:
		if b.dead == 0.0 and Vector2(b.x - s.x, b.y - s.y).length() < HIT + 0.2:
			s.t = 99.0
			hurt(state, s.x)
	# Thrown balls: one hit defeats any monster and knocks seeds out of the air.
	for shot: Dictionary in state.shots:
		shot.t += dt
		shot.vy -= G * 0.25 * dt
		shot.x += shot.vx * dt
		shot.y += shot.vy * dt
		if shot.x < 0.0 or shot.x > W:
			shot.t = SHOT_LIFE
		for m: Dictionary in state.monsters:
			if not m.alive or shot.t >= SHOT_LIFE:
				continue
			var r := 0.55 if m.type == "bat" else 0.75
			if Vector2(shot.x - m.x, shot.y - monster_y(m)).length() < r + SHOT_R:
				m.alive = false
				m.t = 0.0
				shot.t = SHOT_LIFE
				state.events.append({"type": "kill", "x": m.x, "y": monster_y(m)})
		for seed: Dictionary in state.seeds:
			if shot.t < SHOT_LIFE and Vector2(shot.x - seed.x, shot.y - seed.y).length() < 0.3 + SHOT_R:
				seed.t = 99.0
				shot.t = SHOT_LIFE
	state.shots = state.shots.filter(func(shot: Dictionary) -> bool: return shot.t < SHOT_LIFE)
	for i: Dictionary in state.icicles:
		if i.state == "fall" and b.dead == 0.0 and Vector2(b.x - i.x, b.y - (i.y - 0.6)).length() < HIT + 0.2:
			i.state = "gone"
			i.t = 0.0
			hurt(state, i.x)


static func step(state: Dictionary, dt: float) -> void:
	var n := maxi(1, ceili(dt / (1.0 / 240.0)))
	for i in n:
		step_world(state, dt / n)
		step_ball(state, dt / n)
