class_name WorldBalls
extends Node3D
## The Dahroojs around the modes and the left-hand blaster (src/reference/xr-runtime.js):
## - thrown balls stay in the world: when a throw is over, that Dahrooj stays where he
##   stopped, rolls on, bumps into the others and now and then sets off on his own;
## - balls that meet hard enough pop; pat one and he giggles; shake the one in your
##   hand and he gets dizzy;
## - the blaster's four shot styles, their sparks, and the pops.
## Lives under GameRoot: positions in game units. `host` is the main scene (scale,
## eye, hands, sounds, haptics, the park and the runtime).

const RESTS_MAX := 8
const REST_LIFE := 12.0
const REST_ROOM := 26.0
const REAL_G := 9.8
const SPARKS_MAX := 128
const SHOTS_MAX := 16
const SHOT_STYLE := {
	"bolt": {"speed": 45.0, "grav": 0.0, "life": 1.2, "r": 0.02, "cool": 0.12},
	"mini": {"speed": 11.0, "grav": 1.0, "life": 3.2, "r": 0.022, "cool": 0.12},
	"bubble": {"speed": 4.2, "grav": -0.06, "life": 3.6, "r": 0.06, "cool": 0.16},
	"firework": {"speed": 20.0, "grav": 0.35, "life": 0.85, "r": 0.025, "cool": 0.2, "burst": 0.55},
}
const FIRE_COLS := ["e2603f", "f2c14e", "6fa8d6", "7bbf8a", "c9a2e6", "fffaf2"]
const INTRO_STYLES := ["jelly", "fur", "bubble"]
## palette.js DAHROOJ_COLORS
const STYLE_COLORS := {"jelly": "ff69b4", "fabric": "b36bff", "clay": "ff9b3d", "fur": "f1ebe1", "bubble": "cfe8ff"}

var host  # main.gd
var ball: Ball
var rests: Array = []  # {age, view, style, p, v, d, dv, wander, blink, next, mood, mood_t, pet_t, wet}
var shots: Array = []  # {kind, node, p, v, dir, t, r, look, wob, skips, float, tap, wet}
var sparks: Array = []  # {p, v, t, max, flash, color, size}
var popped := 0
var fired := 0
var last_shot := {"left": -10.0, "right": -10.0}
var clock := 0.0
var _next_ambient_pop := 0.0
var _rng := RandomNumberGenerator.new()
var _views: Array = []  # spare DahroojViews for the rests
var _spark_mm: MultiMesh
var _tri_cache := {}  # Mesh -> TriangleMesh
var _shot_mats := {}


func _init(main, b: Ball) -> void:
	host = main
	ball = b
	_rng.randomize()
	ball.rest_hook = _on_rest
	var mmi := MultiMeshInstance3D.new()
	_spark_mm = MultiMesh.new()
	_spark_mm.transform_format = MultiMesh.TRANSFORM_3D
	_spark_mm.use_colors = true
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 8
	sm.rings = 6
	_spark_mm.mesh = sm
	_spark_mm.instance_count = SPARKS_MAX
	_spark_mm.visible_instance_count = 0
	mmi.multimesh = _spark_mm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_BACK
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-500, -500, -500), Vector3(1000, 1000, 1000))
	add_child(mmi)


func rnd() -> float:
	return _rng.randf()


# --- thrown balls stay in the world ------------------------------------------------

func _on_rest(pos: Vector3, vel: Vector3) -> void:
	if not host.resting_allowed():
		return
	# It keeps the look it was thrown with.
	var view: DahroojView = _views.pop_back() if not _views.is_empty() else DahroojView.new()
	if view.get_parent() == null:
		add_child(view)
	view.visible = true
	rests.append({"age": 0.0, "view": view, "style": "fur", "p": pos, "v": vel, "d": 0.0, "dv": 0.0,
		"wander": 1.5 + rnd() * 4.0, "blink": 0.0, "next": 1.0 + rnd() * 3.0, "mood": "", "mood_t": 0.0,
		"pet_t": 0.0, "wet": false})
	if rests.size() > RESTS_MAX:
		_drop_rest(0)


func _drop_rest(i: int) -> void:
	var r: Dictionary = rests[i]
	r.view.visible = false
	_views.append(r.view)
	rests.remove_at(i)


func clear_rests() -> void:
	for i in range(rests.size() - 1, -1, -1):
		_drop_rest(i)


## Tracks on the grass and ground wherever a ball touches down or rolls.
func mark_ball(p: Vector3, v: Vector3) -> void:
	var park = host.park
	if not host.nature_on() or p.y > Ball.BR * 1.2 or not park.has_method("mark"):
		return
	var sp := Vector2(v.x, v.z).length()
	var hit := absf(v.y)
	if sp < 0.25 and hit < 1.0:
		return
	park.mark(p.x, p.z, Ball.BR * (0.85 + minf(0.8, hit * 0.08)), minf(0.6, 0.12 + sp * 0.04 + hit * 0.06))


## dt: game seconds; real_dt: for the rest lifetimes (performance.now in the original).
func step_rests(dt: float, real_dt: float) -> void:
	for i in range(rests.size() - 1, -1, -1):
		rests[i].age += real_dt
		if rests[i].age >= REST_LIFE:
			_drop_rest(i)
	var G := Ball.GRAV
	var cx := 0.0
	var cz := -10.0
	var BR := Ball.BR
	var park = host.park
	var stage: Node3D = host.stage
	for r in rests:
		var p: Vector3 = r.p
		var v: Vector3 = r.v
		var prev := p
		v.y -= G * dt
		p += v * dt
		if stage and stage.has_method("collide_body"):
			var res: Dictionary = stage.collide_body(p, v, BR, prev)
			p = res.p
			v = res.v
		var grounded := false
		# In the pond it floats half under and paddles slowly back to the shore.
		var wet: bool = host.nature_on() and park.depth(p.x, p.z) > 0.0
		if wet and p.y < BR:
			if not r.wet:
				r.wet = true
				if park.has_method("splash"):
					park.splash(p.x, p.z, minf(1.0, -v.y / 12.0))
				host.sfx("splash", minf(1.0, -v.y / 10.0), p)
			v.y += (G + (-BR * 0.2 - p.y) * 38.0 - v.y * 4.5) * dt
			var f := pow(0.3, dt)
			v.x *= f
			v.z *= f
		else:
			if p.y > BR * 1.2:
				r.wet = false
			if p.y < BR:
				p.y = BR
				if v.y < -1.4:
					r.dv -= minf(8.0, -v.y)
					v.y *= -0.45
				else:
					v.y = 0.0
					grounded = true
		if grounded:
			var f := pow(0.75, dt)
			v.x *= f
			v.z *= f
			# A life of their own: every few seconds a roll in a random direction, sometimes a hop.
			r.wander -= dt
			if r.wander <= 0.0:
				var a := rnd() * TAU
				var sp := 0.6 + rnd() * 1.8
				v.x += cos(a) * sp
				v.z += sin(a) * sp
				if rnd() < 0.35:
					v.y = 2.0 + rnd() * 2.0
					r.dv -= 3.0
				r.wander = 3.0 + rnd() * 7.0
		# Stay on the field.
		var ox := p.x - cx
		var oz := p.z - cz
		var od := sqrt(ox * ox + oz * oz)
		if od > REST_ROOM:
			v.x -= ox / od * dt * 4.0
			v.z -= oz / od * dt * 4.0
		r.dv += (-r.d * 300.0 - r.dv * 12.0) * dt
		r.d = clampf(r.d + r.dv * dt, -0.3, 0.45)
		r.next -= dt
		if r.next <= 0.0:
			r.blink = 0.14
			r.next = 2.0 + rnd() * 3.0
		r.blink = maxf(0.0, r.blink - dt)
		r.p = p
		r.v = v
		mark_ball(p, v)


## Closing speed at the first contact during this step (ball-impact.ts).
static func impact_speed(a: Vector3, av: Vector3, b: Vector3, bv: Vector3, radius: float, dt: float) -> float:
	var vv := bv - av
	var speed2 := vv.length_squared()
	if speed2 < 1e-8:
		return 0.0
	var x := b - a - vv * dt
	var approach := x.dot(vv)
	if approach >= 0.0:
		return 0.0
	var gap := x.length_squared() - radius * radius
	var t := 0.0
	if gap > 0.0:
		var disc := approach * approach - speed2 * gap
		if disc < 0.0:
			return 0.0
		t = (-approach - sqrt(disc)) / speed2
		if t < 0.0 or t > dt:
			return 0.0
	var n := x + vv * t
	var length := n.length()
	return maxf(0.0, -n.dot(vv) / length) if length > 1e-6 else 0.0


## Leftovers, previous throws and the current throw push each other apart; a hard
## meeting pops both.
func step_contacts(dt: float) -> void:
	var BR := Ball.BR
	# [kind, index]: "r" rest, "v" volley, "s" the ball
	var bodies: Array = []
	for i in rests.size():
		bodies.append(["r", i])
	for i in ball.volley.size():
		bodies.append(["v", i])
	if ball.shot and not ball.held:
		bodies.append(["s", 0])
	var dead := PackedByteArray()
	dead.resize(bodies.size())
	var threshold: float = 2.4 * host.scale_now / host.time_k()
	for i in bodies.size():
		for j in range(i + 1, bodies.size()):
			if dead[i] or dead[j]:
				continue
			var ap := _bp(bodies[i])
			var av := _bv(bodies[i])
			var bp := _bp(bodies[j])
			var bv := _bv(bodies[j])
			if impact_speed(ap, av, bp, bv, BR * 2.0, dt) >= threshold:
				dead[i] = 1
				dead[j] = 1
				continue
			var n := bp - ap
			var length := n.length()
			if length > 0.0 and length < BR * 2.0:
				n /= length
				var push := (BR * 2.0 - length) / 2.0
				ap -= n * push
				bp += n * push
				var rel := (bv - av).dot(n)
				if rel < 0.0:
					av += n * (rel * 0.9)
					bv -= n * (rel * 0.9)
				_set_body(bodies[i], ap, av)
				_set_body(bodies[j], bp, bv)
	# Remove after detection, in reverse order, so a character can pop only once.
	for i in range(bodies.size() - 1, -1, -1):
		if not dead[i]:
			continue
		var b: Array = bodies[i]
		match b[0]:
			"r":
				burst(rests[b[1]].p, rests[b[1]].style, false)
				_drop_rest(b[1])
			"v":
				burst(ball.volley[b[1]].pos, "fur", false)
				ball.volley.remove_at(b[1])
			"s":
				burst(ball.pos, "fur", false)
				host.ball_popped()


func _bp(b: Array) -> Vector3:
	match b[0]:
		"r":
			return rests[b[1]].p
		"v":
			return ball.volley[b[1]].pos
	return ball.pos


func _bv(b: Array) -> Vector3:
	match b[0]:
		"r":
			return rests[b[1]].v
		"v":
			return ball.volley[b[1]].vel
	return ball.vel


func _set_body(b: Array, p: Vector3, v: Vector3) -> void:
	match b[0]:
		"r":
			rests[b[1]].p = p
			rests[b[1]].v = v
		"v":
			ball.volley[b[1]].pos = p
			ball.volley[b[1]].vel = v
		_:
			ball.pos = p
			ball.vel = v


## Pat one and he giggles; shake the one in your hand and he gets dizzy.
## hands: {hand: grip position in game units} for the tracked hands.
func feel_hands(dt: float, hands: Dictionary) -> void:
	var BR := Ball.BR
	for r in rests:
		r.mood_t = maxf(0.0, r.mood_t - dt)
		r.pet_t = maxf(0.0, r.pet_t - dt)
	for h in hands:
		var at: Vector3 = hands[h]
		for r in rests:
			if r.pet_t > 0.0 or at.distance_to(r.p) > BR * 1.7:
				continue
			r.pet_t = 1.4
			r.mood = "joy"
			r.mood_t = 1.3
			r.dv -= 4.0
			if r.p.y <= BR * 1.05:
				r.v.y = 2.2
			r.blink = 0.0
			host.sfx("squeak", 1.0 + rnd() * 0.3, r.p)
			host.buzz(h, 0.3, 40)
	# Shaking: the holding hand travels a long way over a quarter second but stays in one place.
	var holder: String = host.holder
	if holder != "":
		var hs: Array = host.hist[holder]
		if hs.size() > 4:
			var path := 0.0
			for i in range(1, hs.size()):
				path += (hs[i].p as Vector3).distance_to(hs[i - 1].p)
			var net := (hs[hs.size() - 1].p as Vector3).distance_to(hs[0].p)
			# The hand history is in real metres here (the original's is in world units, s times larger).
			if path > 0.55 and net < 0.18 and not (ball.mood == "dizzy" and ball.mood_t > 0.0):
				ball.mood = "dizzy"
				ball.mood_t = 1.8
				ball.mood_next = ""
				host.sfx("squeak", 0.7, ball.pos)
				host.buzz(holder, 0.5, 90)


func draw_rests(eye: Vector3, hidden: bool) -> void:
	var BR := Ball.BR
	for r in rests:
		var view: DahroojView = r.view
		view.visible = not hidden
		if hidden:
			continue
		var sp := Vector2(r.v.x, r.v.z).length()
		var face: String = r.mood if r.mood_t > 0.0 else ("wide" if sp > 5.0 else "open")
		view.show_at(Vector3(r.p.x, r.p.y - BR * maxf(0.0, r.d), r.p.z), eye, face, r.blink > 0.0, Vector2(1.0 + r.d * 0.75, 1.0 - r.d))
		view.scale *= minf(1.0, (REST_LIFE - r.age) / 0.75)


# --- the blaster ---------------------------------------------------------------------

func style_for() -> String:
	return Save.shot_style if Save.shot_style != "" else "bolt"


## origin, dir: the hand's ray in game units.
func fire(hand: String, origin: Vector3, dir: Vector3) -> void:
	var kind := style_for()
	var P: Dictionary = SHOT_STYLE[kind]
	if clock - float(last_shot[hand]) < P.cool:
		return
	# Reuse the bounded flight budget instead of stalling a held trigger.
	if shots.size() >= SHOTS_MAX:
		var oldest: Dictionary = shots.pop_front()
		if oldest.node:
			oldest.node.queue_free()
	last_shot[hand] = clock
	fired += 1
	host.note_style()
	var k: float = host.scale_now
	var p := origin + dir * 0.08 * k
	var node := _shot_node(kind, k, INTRO_STYLES[fired % INTRO_STYLES.size()])
	node.position = p
	if kind == "bolt" and dir.length_squared() > 0.0:
		node.basis = Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.999 else Vector3.RIGHT)
	add_child(node)
	shots.append({"kind": kind, "node": node, "p": p, "v": dir * P.speed * k, "dir": dir, "t": 0.0, "r": P.r * k,
		"wob": rnd() * 6.0, "skips": 0, "float": -1.0, "tap": 0.0, "wet": false})
	# Muzzle flash (not for a bubble).
	if kind != "bubble":
		_spark(p, Vector3.ZERO, 0.07, Color("ffe9b0"), 0.05 * k, true)
	host.sfx("pew" if kind == "bolt" else ("firework_launch" if kind == "firework" else "whoosh"), 0.18, p)
	host.buzz(hand, 0.12 if kind == "bubble" else 0.3, 22)


func _mat(key: String) -> Material:
	if _shot_mats.has(key):
		return _shot_mats[key]
	var m := StandardMaterial3D.new()
	match key:
		"trail":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(Color("ffd27a"), 0.95)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		"head":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color("fff4d6")
		"rocket":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color("ffb347")
		"jelly":
			m.albedo_color = Color("ff69b4")
			m.roughness = 0.15
			m.clearcoat_enabled = true
		"fur":
			m.albedo_texture = load("res://assets/character/fur.png")
			m.albedo_color = Color("ff69b4")
			m.roughness = 0.95
		"bubble":
			m.albedo_color = Color(Color("cfe8ff"), 0.45)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.05
			m.rim_enabled = true
			m.rim = 1.0
	_shot_mats[key] = m
	return m


func _shot_node(kind: String, k: float, look: String) -> Node3D:
	var root := Node3D.new()
	var sphere := func(r: float, mat: Material) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = r
		s.height = r * 2.0
		s.radial_segments = 10
		s.rings = 8
		mi.mesh = s
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return mi
	match kind:
		"bolt":
			var tr := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.006 * k
			c.bottom_radius = 0.006 * k
			c.height = 0.35 * k
			c.radial_segments = 6
			c.cap_top = false
			c.cap_bottom = false
			tr.mesh = c
			tr.material_override = _mat("trail")
			tr.rotation.x = PI / 2
			tr.position.z = 0.175 * k  # behind the head (the head looks along -z)
			tr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(tr)
			root.add_child(sphere.call(0.012 * k, _mat("head")))
		"firework":
			root.add_child(sphere.call(0.012 * 1.4 * k, _mat("rocket")))
		"mini":
			root.add_child(sphere.call(SHOT_STYLE.mini.r * k, _mat(look)))
		"bubble":
			root.add_child(sphere.call(SHOT_STYLE.bubble.r * k, _mat("bubble")))
	return root


func _spark(p: Vector3, v: Vector3, life: float, color: Color, size: float, flash := false) -> void:
	if sparks.size() >= SPARKS_MAX:
		return
	sparks.append({"p": p, "v": v, "t": 0.0, "max": life, "flash": flash, "color": color, "size": size})


## A little spray of sparks where a shot lands.
func impact(p: Vector3, n: Vector3, color := Color("ffd27a")) -> void:
	var k: float = host.scale_now
	for i in 8:
		var d := Vector3(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5).normalized()
		d = (d + n * 1.2).normalized() * ((1.0 + rnd() * 1.5) * k)
		_spark(p, d, 0.25 + rnd() * 0.2, color if i % 2 else Color("fffaf2"), (0.008 + rnd() * 0.008) * k)


## A firework's bloom: coloured sparks every way.
func bloom(p: Vector3) -> void:
	var k: float = host.scale_now
	for i in 26:
		var d := Vector3(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5).normalized() * ((1.6 + rnd() * 1.6) * k)
		_spark(p, d, 0.5 + rnd() * 0.35, Color(FIRE_COLS[i % FIRE_COLS.size()]), (0.01 + rnd() * 0.01) * k)
	host.sfx("firework_burst", 1.0, p)


func sky_pop(p: Vector3) -> void:
	if p.y > host.eye_game().y + 0.25 * host.scale_now:
		host.runtime.ch_add("skyPop5")


## A Dahrooj pops: a puff of sparks in his colour.
func burst(p: Vector3, style: String, by_player := true) -> void:
	if by_player:
		sky_pop(p)
	var k: float = host.scale_now
	var col := Color(STYLE_COLORS.get(style, "fffaf2"))
	for i in (14 if by_player else 6):
		var a := rnd() * TAU
		var e := rnd() * PI - PI / 2
		var sp := (1.2 + rnd() * 1.8) * k
		_spark(p, Vector3(cos(a) * cos(e) * sp, sin(e) * sp + k, sin(a) * cos(e) * sp), 0.45 + rnd() * 0.3,
			col if i % 3 else Color("fffaf2"), (0.012 + rnd() * 0.012) * k)
	popped += 1
	if by_player or clock >= _next_ambient_pop:
		host.sfx("start_pop", 1.0, p)
		_next_ambient_pop = clock + 0.12
	if by_player:
		host.buzz("left", 0.35, 40)
		host.runtime.ch_add("pop20")


func step_blast(dt: float) -> void:
	clock += dt
	if shots.is_empty() and sparks.is_empty():
		_spark_mm.visible_instance_count = 0
		return
	var k: float = host.scale_now
	var G := REAL_G * k
	var BR := Ball.BR
	var park = host.park
	var stage: Node3D = host.stage
	for i in range(shots.size() - 1, -1, -1):
		var s: Dictionary = shots[i]
		var P: Dictionary = SHOT_STYLE[s.kind]
		var R: float = s.r
		s.t += dt
		var a: Vector3 = s.p
		s.v.y -= G * P.grav * dt
		if s.kind == "bubble":
			s.wob += dt * 3.0
			s.v.x += sin(s.wob) * 0.25 * k * dt
			s.v.z += cos(s.wob * 0.8) * 0.25 * k * dt
		s.p += s.v * dt
		var seg: Vector3 = s.p - a
		var len := seg.length()
		var dir_n := seg / len if len > 0.0 else seg
		var near_seg := func(p: Vector3, rr: float) -> bool:
			var t := clampf((p - a).dot(seg) / (len * len if len > 0.0 else 1.0), 0.0, 1.0)
			return (a + seg * t).distance_to(p) < rr + R
		var done := false
		var was_popped := false
		# Dahroojs it reaches pop.
		for j in range(rests.size() - 1, -1, -1):
			if near_seg.call(rests[j].p, BR):
				burst(rests[j].p, rests[j].style)
				_drop_rest(j)
				was_popped = true
		for j in range(ball.volley.size() - 1, -1, -1):
			if near_seg.call(ball.volley[j].pos, BR):
				burst(ball.volley[j].pos, "fur")
				ball.volley.remove_at(j)
				was_popped = true
		if ball.shot and not ball.held and near_seg.call(ball.pos, BR):
			burst(ball.pos, "fur")
			host.ball_popped()
			was_popped = true
		# A mini Dahrooj carries on, slowed; anything else stops (a firework bursts).
		if was_popped:
			if s.kind == "mini":
				s.v *= 0.6
			else:
				done = true
		# The pond: a bolt plunges in, a mini skips off the surface while fast and low,
		# else sinks; a bubble settles on the water and pops; a firework fizzles.
		if not done and host.nature_on() and s.p.y < R * 1.05 and a.y >= R * 0.5 and park.depth(s.p.x, s.p.z) > 0.0:
			var hs := Vector2(s.v.x, s.v.z).length()
			var vs: float = -s.v.y
			if s.kind == "mini" and hs > 2.2 * k and vs < hs * 0.7 and s.skips < 4:
				s.skips += 1
				s.p.y = R
				s.v.y = maxf(0.6 * k, vs * 0.55)
				s.v.x *= 0.82
				s.v.z *= 0.82
				_park_splash(s.p, 0.2)
				host.sfx("splash", 0.15, s.p)
			elif s.kind == "bubble":
				s.p.y = R
				s.v = Vector3.ZERO
				s.float = maxf(0.0, s.float)
			else:
				_park_splash(s.p, 0.6 if s.kind == "firework" else (0.35 if s.kind == "mini" else 0.25))
				host.sfx("splash", 0.5 if s.kind == "firework" else 0.25, s.p)
				if s.kind == "firework":
					impact(s.p, Vector3.UP, Color("fffaf2"))
				done = true
				s.wet = true
		if s.float >= 0.0 and not done:
			s.float += dt
			s.p.y = R
			if park.has_method("water_line"):
				park.water_line(s.p.x, 0.0, s.p.z, R)
			if s.float > 0.9:
				_park_splash(s.p, 0.15)
				host.sfx("start_pop", 1.0, s.p)
				done = true
		# The mode itself: the first visible thing along the way.
		if not done and stage and stage.is_visible_in_tree() and len > 0.0:
			var hit := ray_stage(stage, a, dir_n, len + R)
			if not hit.is_empty():
				var n: Vector3 = hit.normal
				var took: bool = stage.has_method("shoot") and stage.shoot(hit.node, hit.point, dir_n)
				impact(hit.point, n, Color("ffd27a") if took else Color("fffaf2"))
				if not took:
					host.sfx("thump", 0.25, hit.point)
				if s.kind == "mini" and not took:
					s.p = hit.point + n * R
					var vn: float = s.v.dot(n)
					if vn < 0.0:
						s.v -= n * 1.5 * vn
				else:
					done = true
		# The world's props (crates go off), the walls of your room, and the floor.
		if not done and host.nature_on() and park.has_method("collide"):
			var res: Dictionary = park.collide(s.p, s.v, R)
			if res.hit:
				s.p = res.p
				if s.kind == "mini":
					s.v = res.v
				else:
					impact(s.p, -dir_n)
					done = true
		if not done and s.p.y < R:
			if s.kind == "mini":
				s.p.y = R
				if s.v.y < -0.8 * k:
					s.v.y *= -0.45
				else:
					s.v.y = 0.0
				var f := pow(0.55, dt)
				s.v.x *= f
				s.v.z *= f
			else:
				s.p.y = 0.0
				impact(s.p, Vector3.UP)
				done = true
		if s.kind == "firework" and not s.wet and (done or s.t > P.life):
			# The burst pops every Dahrooj near it.
			var RR: float = P.burst * k
			for j in range(rests.size() - 1, -1, -1):
				if (rests[j].p as Vector3).distance_to(s.p) < RR + BR:
					burst(rests[j].p, rests[j].style)
					_drop_rest(j)
			bloom(s.p)
			done = true
		if s.kind == "firework" and not done and rnd() < 0.6:
			_spark(s.p, Vector3(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5) * 0.3 * k, 0.25, Color("ffc070"), 0.006 * k)
		if s.node:
			s.node.position = s.p
		if done or (s.t > P.life and s.float < 0.0):
			if s.node:
				s.node.queue_free()
			if s.kind == "bubble" and not done:
				host.sfx("start_pop", 1.0, s.p)
			shots.remove_at(i)
	var n := 0
	for i in range(sparks.size() - 1, -1, -1):
		var s: Dictionary = sparks[i]
		s.t += dt
		if not s.flash:
			s.v.y -= G * 0.5 * dt
		s.p += s.v * dt
		if s.t >= s.max:
			sparks.remove_at(i)
	for s in sparks:
		_spark_mm.set_instance_transform(n, Transform3D(Basis().scaled(Vector3.ONE * s.size), s.p))
		_spark_mm.set_instance_color(n, Color(s.color, 1.0 - s.t / s.max))
		n += 1
	_spark_mm.visible_instance_count = n


func _park_splash(p: Vector3, k: float) -> void:
	if host.park.has_method("splash"):
		host.park.splash(p.x, p.z, k)


func clear_blast() -> void:
	for s in shots:
		if s.node:
			s.node.queue_free()
	shots.clear()
	sparks.clear()
	_spark_mm.visible_instance_count = 0


## The first solid stage mesh along a ray (game units): {node, point, normal} or {}.
## The stages' guide lines on the ground and the nets don't stop a shot.
func ray_stage(stage: Node3D, from: Vector3, dir: Vector3, far: float) -> Dictionary:
	var best := {}
	var best_d := far
	var to_root: Transform3D = global_transform.affine_inverse()
	for mi in stage.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		var mat := m.material_override
		if mat == StageArt.line_mat() or mat == StageArt.net_mat() or m.mesh is ImmediateMesh:
			continue
		# Ray into the mesh's space.
		var xf: Transform3D = to_root * m.global_transform
		var inv := xf.affine_inverse()
		var lo := inv * from
		var ld := inv.basis * dir
		var lend := inv * (from + dir * best_d)
		if not m.mesh.get_aabb().grow(0.001).intersects_segment(lo, lend):
			continue
		var tri: TriangleMesh = _tri_cache.get(m.mesh)
		if tri == null:
			tri = m.mesh.generate_triangle_mesh()
			_tri_cache[m.mesh] = tri
		if tri == null:
			continue
		var r: Dictionary = tri.intersect_segment(lo, lend)
		if r.is_empty():
			continue
		var wp: Vector3 = xf * (r.position as Vector3)
		var d := (wp - from).dot(dir)
		if d >= 0.0 and d < best_d:
			best_d = d
			var nrm: Vector3 = (xf.basis.inverse().transposed() * (r.normal as Vector3)).normalized()
			if nrm.dot(dir) > 0.0:
				nrm = -nrm
			best = {"node": m, "point": wp, "normal": nrm}
	return best
