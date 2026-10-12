class_name GoalStage
extends Node3D
## The goal (src/reference/stages/goal.js): a 6 x 2.3 goal with a springy net and
## a round keeper with floating gloves who reads the shot and dives. Game units.

const GOAL_Z := -11.0
const AIM_Z := GOAL_Z - 0.3
const GW := 6.0
const GH := 2.3
const GD := 1.8
const PR := 0.07
const KZ := GOAL_Z + 0.35
const KR := 0.42
const HR := 0.135

var aim_z := AIM_Z
var friction = null
var shot_time = null
var solids: Array = []
var back: Dictionary
var k_root: Node3D
var k_body: Node3D
var k_eyes: Array = []
var k_hands: Array = []
var K := {}
var time := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 11
	name = "Goal"
	StageArt.ground_line(self, -14, GOAL_Z, 14, GOAL_Z)
	StageArt.ground_line(self, -GW / 2 - 2.2, GOAL_Z, -GW / 2 - 2.2, GOAL_Z + 2.6)
	StageArt.ground_line(self, GW / 2 + 2.2, GOAL_Z, GW / 2 + 2.2, GOAL_Z + 2.6)
	StageArt.ground_line(self, -GW / 2 - 2.2, GOAL_Z + 2.6, GW / 2 + 2.2, GOAL_Z + 2.6)
	StageArt.ground_line(self, -10, GOAL_Z, -10, GOAL_Z + 9)
	StageArt.ground_line(self, 10, GOAL_Z, 10, GOAL_Z + 9)
	StageArt.ground_line(self, -10, GOAL_Z + 9, 10, GOAL_Z + 9)
	var V := func(x, y, z): return Vector3(x, y, z)
	StageArt.bar(self, V.call(-GW / 2, 0, GOAL_Z), V.call(-GW / 2, GH + PR, GOAL_Z), PR)
	StageArt.bar(self, V.call(GW / 2, 0, GOAL_Z), V.call(GW / 2, GH + PR, GOAL_Z), PR)
	StageArt.bar(self, V.call(-GW / 2 - PR, GH, GOAL_Z), V.call(GW / 2 + PR, GH, GOAL_Z), PR)
	var tb := PR * 0.45
	StageArt.bar(self, V.call(-GW / 2, GH, GOAL_Z), V.call(-GW / 2, GH, GOAL_Z - GD), tb)
	StageArt.bar(self, V.call(GW / 2, GH, GOAL_Z), V.call(GW / 2, GH, GOAL_Z - GD), tb)
	StageArt.bar(self, V.call(-GW / 2, 0, GOAL_Z - GD), V.call(-GW / 2, GH, GOAL_Z - GD), tb)
	StageArt.bar(self, V.call(GW / 2, 0, GOAL_Z - GD), V.call(GW / 2, GH, GOAL_Z - GD), tb)
	StageArt.bar(self, V.call(-GW / 2, GH, GOAL_Z - GD), V.call(GW / 2, GH, GOAL_Z - GD), tb)
	StageArt.bar(self, V.call(-GW / 2, 0.02, GOAL_Z), V.call(-GW / 2, 0.02, GOAL_Z - GD), tb)
	StageArt.bar(self, V.call(GW / 2, 0.02, GOAL_Z), V.call(GW / 2, 0.02, GOAL_Z - GD), tb)
	StageArt.bar(self, V.call(-GW / 2, 0.02, GOAL_Z - GD), V.call(GW / 2, 0.02, GOAL_Z - GD), tb)
	solids = [[V.call(-GW / 2, 0, GOAL_Z), V.call(-GW / 2, GH, GOAL_Z), PR],
		[V.call(GW / 2, 0, GOAL_Z), V.call(GW / 2, GH, GOAL_Z), PR],
		[V.call(-GW / 2, GH, GOAL_Z), V.call(GW / 2, GH, GOAL_Z), PR]]
	_build_keeper()
	back = StageArt.net_grid(self, 31, 13, func(u, v): return Vector3(-GW / 2 + u * GW, v * GH, GOAL_Z - GD))
	StageArt.net_grid(self, 10, 13, func(u, v): return Vector3(-GW / 2, v * GH, GOAL_Z - u * GD))
	StageArt.net_grid(self, 10, 13, func(u, v): return Vector3(GW / 2, v * GH, GOAL_Z - u * GD))
	StageArt.net_grid(self, 31, 10, func(u, v): return Vector3(-GW / 2 + u * GW, GH, GOAL_Z - v * GD))
	keeper_reset()


static func _sphere(r: float, mat: Material, segs := 24) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = segs / 2
	m.mesh = s
	m.material_override = mat
	return m


static func _mat(c: Color, rough := 0.5, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _build_keeper() -> void:
	k_root = Node3D.new()
	add_child(k_root)
	k_body = Node3D.new()
	k_root.add_child(k_body)
	var ball := _sphere(KR, _mat(Color("e2603f"), 0.5), 36)
	ball.position.y = KR
	k_body.add_child(ball)
	var white := _mat(Color("fffaf2"), 0.5, true)
	var dark := _mat(Color("151515"), 0.5, true)
	var ey := KR * 1.12
	for sx in [-1.0, 1.0]:
		var w := _sphere(0.085, white, 16)
		w.scale = Vector3(1, 1.15, 0.45)
		w.position = Vector3(sx * 0.13, ey, KR * 0.9)
		k_body.add_child(w)
		var p := _sphere(0.044, dark, 12)
		p.scale = Vector3(1, 1, 0.4)
		p.position = Vector3(sx * 0.13, ey, KR * 0.9 + 0.035)
		k_body.add_child(p)
		k_eyes.append({"w": w, "p": p, "sx": sx})
	var glove := _mat(Color("f3ead9"), 0.6)
	for sx in [-1.0, 1.0]:
		var h := _sphere(HR, glove, 18)
		k_root.add_child(h)
		k_hands.append({"h": h, "sx": sx})


func keeper_reset() -> void:
	K = {"x": 0.0, "y": 0.0, "vy": 0.0, "ang": 0.0, "tx": 0.0, "tang": 0.0, "plan": false, "wait": 0.0,
		"recover": 0.0, "saved": false, "jump": false, "plans": int(K.get("plans", 0))}


func _keeper_plan(b: Ball) -> void:
	var P := b.pos
	var v := b.vel
	if v.z >= -0.5:
		return
	var t := (KZ - P.z) / v.z
	var px := P.x + v.x * t + 0.5 * b.side.x * t * t
	var py := P.y + v.y * t - 0.5 * Ball.GRAV * t * t
	if _rng.randf() < 0.07:
		px = K.x - (px - K.x) * 0.6  # rarely guesses the wrong side
	else:
		px += (_rng.randf() - 0.5) * 0.3
	K.tx = clampf(px, -GW / 2 + 0.35, GW / 2 - 0.35)
	var dx: float = K.tx - K.x
	K.tang = -signf(dx) * minf(1.35, absf(dx) * 0.75) if absf(dx) > 0.5 else 0.0
	K.jump = py > 1.15
	K.wait = 0.07 + _rng.randf() * 0.06
	K.plan = true
	K.plans = int(K.plans) + 1


func _keeper_update(b: Ball, dt: float) -> void:
	if b.shot and not K.plan and b.shot_t > 0.02:
		_keeper_plan(b)
	if not b.shot:
		K.tx = b.pos.x * 0.55 + sin(time * 0.9) * 0.25  # cuts the angle to the ball
		K.tang = 0.0
	if K.wait > 0.0:
		K.wait -= dt
		if K.wait <= 0.0 and K.jump and K.y <= 0.0:
			K.vy = 5.6
	else:
		var sp := 8.0 if K.plan else 2.4
		var dx: float = K.tx - K.x
		K.x += signf(dx) * minf(absf(dx), sp * dt)
		var da: float = K.tang - K.ang
		K.ang += signf(da) * minf(absf(da), 9.0 * dt)
	if K.y > 0.0 or K.vy > 0.0:
		K.vy -= Ball.GRAV * dt
		K.y = maxf(0.0, K.y + K.vy * dt)
		if K.y == 0.0:
			K.vy = 0.0
	if K.plan and b.shot_t > 1.2:
		K.tang = 0.0
	k_root.position = Vector3(K.x, K.y + absf(sin(K.ang)) * 0.25, KZ)
	k_root.rotation.z = K.ang
	var lift := minf(1.0, absf(K.ang) / 1.1 + (0.8 if K.y > 0.05 else 0.0))
	var st := 1.0 + lift * 0.32 + sin(time * 3.0) * 0.015
	k_body.scale = Vector3(1.0 / sqrt(st), st, 1.0 / sqrt(st))
	for hd in k_hands:
		var idle := Vector3(hd.sx * (KR + 0.19), KR + sin(time * 2.4 + hd.sx) * 0.05, 0.12)
		var reach := Vector3(hd.sx * 0.22, KR * 2.0 * st + 0.34, 0.05)
		hd.h.position = idle.lerp(reach, lift)
	var lx := clampf((b.pos.x - K.x) / 2.0, -1.0, 1.0)
	var ly := clampf((b.pos.y - (K.y + KR)) / 2.0, -1.0, 1.0)
	for e in k_eyes:
		e.p.position.x = e.sx * 0.13 + lx * 0.03
		e.p.position.y = KR * 1.12 + ly * 0.035


func _keeper_collide(b: Ball) -> void:
	var ang: float = K.ang
	var st := k_body.scale.y
	var rr := KR * k_body.scale.x
	var ku := Vector3(-sin(ang), cos(ang), 0)
	var kf := Vector3(K.x, K.y + absf(sin(ang)) * 0.25, KZ)
	var hit_k := b.seg_collide(kf + ku * rr, kf + ku * (KR * 2.0 * st - rr), rr, 0.45)
	for hd in k_hands:
		var w: Vector3 = k_root.transform * hd.h.position
		if b.point_collide(w, HR, 0.5):
			hit_k = true
	if hit_k and b.shot and not K.saved:
		K.saved = true
		b.ooh()


func on_respawn() -> void:
	keeper_reset()


## Every new throw gets a fresh save attempt, even before the last ball comes back.
func on_throw() -> void:
	K.plan = false
	K.saved = false
	K.wait = 0.0


func behind(p: Vector3) -> bool:
	return p.z < GOAL_Z - 0.05


func collide(b: Ball) -> void:
	_keeper_collide(b)
	for s in solids:
		if b.seg_collide(s[0], s[1], s[2]):
			b.ooh()
	var P := b.pos
	var in_x := absf(P.x) < GW / 2
	if in_x and P.y < GH and P.z < GOAL_Z:
		if P.z - Ball.BR < GOAL_Z - GD:
			b.pos.z = GOAL_Z - GD + Ball.BR
			if b.vel.z < 0.0:
				StageArt.net_poke(back, P.x, P.y, -b.vel.z * 1.6)
				b.event.emit("swish", {"pos": b.pos})
				b.vel.z = -b.vel.z * 0.12
				b.vel.x *= 0.5
				b.vel.y *= 0.6
		if absf(b.pos.x) > GW / 2 - Ball.BR:
			b.pos.x = signf(b.pos.x) * (GW / 2 - Ball.BR)
			b.vel.x *= -0.15
		if b.pos.y > GH - Ball.BR:
			b.pos.y = GH - Ball.BR
			if b.vel.y > 0.0:
				b.vel.y *= -0.15
	P = b.pos
	if in_x and P.y > GH and P.y - Ball.BR < GH and P.z < GOAL_Z and P.z > GOAL_Z - GD:
		b.pos.y = GH + Ball.BR
		if b.vel.y < 0.0:
			b.vel.y = -b.vel.y * 0.2
		b.vel.x *= 0.8
		b.vel.z *= 0.8
	P = b.pos
	if not in_x and absf(P.x) - Ball.BR < GW / 2 and P.z < GOAL_Z and P.z > GOAL_Z - GD and P.y < GH:
		b.pos.x = signf(P.x) * (GW / 2 + Ball.BR)
		b.vel.x = -b.vel.x * 0.2
	P = b.pos
	if b.shot and b.scored_t <= 0.0 and b.prev.z >= GOAL_Z and P.z < GOAL_Z:
		if absf(P.x) < GW / 2 and P.y < GH:
			b.success()
		else:
			b.miss()


func update(b: Ball, dt: float) -> void:
	time += dt
	_keeper_update(b, dt)
	StageArt.net_update(back, dt)
