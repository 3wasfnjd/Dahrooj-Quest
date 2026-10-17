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

## The dallah's ding (fair_ding) is soft: its level when fired and when it spills, and the
## least time between two of its dings (a held trigger, both hands, spills landing together).
const DALLAH_FIRE_K := 0.3
const DALLAH_SPILL_K := 0.22
const DALLAH_DING_GAP := 0.3
## The least time between two thumps of the dallah's coffee beans hitting things.
const BEAN_THUMP_GAP := 0.15
const RESTS_MAX := 8
const REST_LIFE := 12.0
const REST_ROOM := 26.0
const REAL_G := 9.8
const SPARKS_MAX := 320
const SHOTS_MAX := 40
## Bouncy balls never wear out: they bounce about the room for good, at most this many at once
## (a new one takes the place of the oldest; the headset keeps its frame rate).
const BOUNCY_MAX := 12
## They keep hopping and rolling (metres a second, × blast_k): at least this high a bounce and
## this fast along the floor; past BOUNCY_ROAM metres from you (VR's open park, a room with no
## scan) they turn back toward you.
const BOUNCY_HOP := 3.2
const BOUNCY_ROLL := 1.6
const BOUNCY_ROAM := 6.0
const ARCS_MAX := 24
const BEAM_SEGS_MAX := 512
## Angle between the shots of a fan (radians): Dahrooj Attack's triple shot.
const FAN_STEP := 0.11
## The flight of each style (ShotCatalog has the list, names and unlocks). Metres and
## seconds, scaled by blast_k(): speed, grav (times g), life, r (hit radius), cool (the
## least time between two shots of a hand; holding the trigger fires at that rate), sk (the
## firing sound's k), and per style: burst (radius), pellets/cone, bounces/pops, range/pierce,
## reach/swing, splat, turn/seek, chain/hop, spray. "bean" is the dallah's pellet.
const SHOT_STYLE := {
	"bolt": {"speed": 45.0, "grav": 0.0, "life": 1.2, "r": 0.02, "cool": 0.12, "sk": 0.18},
	"mini": {"speed": 11.0, "grav": 1.0, "life": 3.2, "r": 0.022, "cool": 0.12, "sk": 0.18},
	"bubble": {"speed": 4.2, "grav": -0.06, "life": 3.6, "r": 0.06, "cool": 0.16, "sk": 0.18},
	"firework": {"speed": 20.0, "grav": 0.35, "life": 0.85, "r": 0.025, "cool": 0.2, "burst": 0.55, "sk": 0.18},
	"confetti": {"speed": 24.0, "grav": 0.45, "life": 0.9, "r": 0.018, "cool": 0.3, "pellets": 5, "cone": 0.12, "sk": 0.5},
	"bouncy": {"speed": 15.0, "grav": 1.0, "life": INF, "r": 0.03, "cool": 0.22, "bounces": 1000000000, "pops": 1000000000, "sk": 1.35},
	"laser": {"speed": 0.0, "grav": 0.0, "life": 0.25, "r": 0.015, "cool": 0.32, "range": 30.0, "pierce": 3, "sk": 0.5},
	"boomerang": {"speed": 10.0, "grav": 0.0, "life": 1.5, "r": 0.06, "cool": 0.55, "reach": 6.0, "swing": 1.6, "sk": 0.5},
	"glob": {"speed": 12.0, "grav": 1.0, "life": 2.5, "r": 0.045, "cool": 0.35, "splat": 0.4, "sk": 0.7},
	"rocket": {"speed": 20.0, "grav": 0.0, "life": 2.6, "r": 0.03, "cool": 0.6, "burst": 0.75, "turn": 6.0, "seek": 16.0, "sk": 1.0},
	"lightning": {"speed": 0.0, "grav": 0.0, "life": 0.32, "r": 0.02, "cool": 0.45, "range": 22.0, "chain": 4, "hop": 3.0, "cone": 0.32, "sk": 1.0},
	"dallah": {"speed": 13.0, "grav": 0.55, "life": 1.1, "r": 0.05, "cool": 0.5, "spray": 0.08, "sk": DALLAH_FIRE_K},
	"bean": {"speed": 7.0, "grav": 1.0, "life": 0.6, "r": 0.014, "cool": 0.0, "sk": 0.5},
}
## How fast a boomerang spins (radians a second): about four turns.
const BOOMERANG_SPIN := 24.0
const FIRE_COLS := ["e2603f", "f2c14e", "6fa8d6", "7bbf8a", "c9a2e6", "fffaf2"]
const CONFETTI_COLS := ["ff5c8a", "ffd23f", "3ec7ff", "7ee05a", "b98cff", "ff8a3d"]
const BOUNCY_COLS := ["ff4f9a", "4fd1ff", "b6f03c", "ffb02e", "a77bff"]
## Arabic coffee beans: lightly roasted, golden to brown, a green cardamom now and then.
const BEAN_COLS := ["b07a3c", "8a5a2b", "c99a5a", "6f8f3a"]
const MUZZLE := {"laser": "ff6b8f", "lightning": "cfe8ff", "glob": "9fe3ff", "confetti": "fff2c2", "rocket": "ffb347", "dallah": "ffe3a0"}
## Mini shots are little eyeless Dahroojs: every style character.js draws, each shot in the next style
## and a colour from the player's colour choices (appearance.ts) or the style's own (palette.js).
const MINI_STYLES := ["jelly", "fur", "bubble", "clay", "fabric"]
const MINI_COLORS := ["", "ff69b4", "ff505c", "ff9b3d", "ffdf45", "58db83", "58b9ff", "b878ff"]
## Bubble shots: soap bubbles (the bubble Dahrooj's swirling film) in soft tints.
const BUBBLE_TINTS := ["cfe8ff", "ffd6f0", "d6ffe4", "fff2c2", "e2d4ff", "c8fff6", "ffe0cc"]
## palette.js DAHROOJ_COLORS
const STYLE_COLORS := {"jelly": "ff69b4", "fabric": "b36bff", "clay": "ff9b3d", "fur": "f1ebe1", "bubble": "cfe8ff"}

var host  # main.gd
var ball: Ball
var rests: Array = []  # {age, view, style, p, v, d, dv, wander, blink, next, mood, mood_t, pet_t, wet}
var shots: Array = []  # {kind, node, p, v, dir, t, r, k, style, color, spin, wob, skips, float, tap, wet, ...}
var sparks: Array = []  # {p, v, t, max, flash, color, size, k, flake}
var arcs: Array = []  # laser beams and lightning arcs: {a, b, n, jit, w, color, t, max, k, pts, tick}
var popped := 0
var fired := 0
var last_shot := {"left": -10.0, "right": -10.0}
var clock := 0.0
var _next_ambient_pop := 0.0
var _rng := RandomNumberGenerator.new()
var _views: Array = []  # spare DahroojViews for the rests
var _spark_mm: MultiMesh
var _beam_mm: MultiMesh
var _hand_sign := 1.0
var _tri_cache := {}  # Mesh -> TriangleMesh
var _shot_mats := {}
var _sound_at := {}  # sound -> clock when the dallah last played it (_dallah_sfx)
## Mini and bubble shots: one crowd (a few MultiMesh draws for every shot in flight).
var shot_crowd: Crowd
var _crowd_drawn := 0


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
	# The sparks, then the round shots (confetti pellets, bouncy balls, coffee beans).
	_spark_mm.instance_count = SPARKS_MAX + SHOTS_MAX
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
	# Laser beams and lightning arcs: glowing stretched boxes.
	var bmi := MultiMeshInstance3D.new()
	bmi.name = "Beams"
	_beam_mm = MultiMesh.new()
	_beam_mm.transform_format = MultiMesh.TRANSFORM_3D
	_beam_mm.use_colors = true
	var bx := BoxMesh.new()
	bx.size = Vector3.ONE
	_beam_mm.mesh = bx
	_beam_mm.instance_count = BEAM_SEGS_MAX
	_beam_mm.visible_instance_count = 0
	bmi.multimesh = _beam_mm
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.vertex_color_use_as_albedo = true
	# Plain alpha, not added light: the colours must read on a bright day and in passthrough.
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bmi.material_override = bm
	bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bmi.custom_aabb = AABB(Vector3(-500, -500, -500), Vector3(1000, 1000, 1000))
	add_child(bmi)
	shot_crowd = Crowd.new(SHOTS_MAX)
	shot_crowd.name = "ShotCrowd"
	for id in shot_crowd.parts:
		(shot_crowd.parts[id].mi as MultiMeshInstance3D).custom_aabb = AABB(Vector3(-500, -500, -500), Vector3(1000, 1000, 1000))
	add_child(shot_crowd)


func rnd() -> float:
	return _rng.randf()


# --- thrown balls stay in the world ------------------------------------------------

func _on_rest(pos: Vector3, vel: Vector3) -> void:
	if not host.resting_allowed():
		return
	# It keeps the look it was thrown with.
	var view: DahroojView = _views.pop_back() if not _views.is_empty() else DahroojView.new(Ball.BR, true)
	if view.get_parent() == null:
		add_child(view)
	# The look he was thrown in (a mode may dress him: Slime's coloured jelly), else the saved one.
	var thrown = host.get("dahrooj")
	var style: String = thrown.style if thrown is DahroojView and thrown.style != "" else Save.style
	var color: String = thrown.color_id if thrown is DahroojView and thrown.style != "" else Save.jelly_color
	view.set_look(style, color, String(host.worn()) if host.has_method("worn") else Save.accessory)
	view.visible = true
	rests.append({"age": 0.0, "view": view, "style": style, "p": pos, "v": vel, "d": 0.0, "dv": 0.0,
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
		# Mixed reality: the real walls and furniture (main.gd room_hit, game units).
		if host.has_method("room_hit") and host.room_active():
			var rh: Dictionary = host.room_hit(p, v, prev, BR)
			p = rh.p
			v = rh.v
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
				burst(ball.volley[b[1]].pos, Save.style, false)
				ball.volley.remove_at(b[1])
			"s":
				burst(ball.pos, Save.style, false)
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

## The size of the blaster's world (game units per metre, for the shots, their sparks and bursts):
## the court's scale as placed, so in mixed reality the shots grow and shrink with the court when you
## zoom it (ar_zoom), like the goal and Dahrooj. Hand-relative things (the muzzle) use scale_now.
## Mixed reality: shots at the room's small court are drawn smaller (owner's request).
const AR_SHOT := 0.4


func blast_k() -> float:
	var k: float = host.scale_now
	if host.get("mode") == "mr" and host.get("ar_zoom") != null:
		k *= float(host.get("ar_zoom")) * AR_SHOT
	return k


## The saved shot style while it is unlocked (ShotCatalog), else the bolt.
func style_for() -> String:
	var id: String = Save.shot_style
	if id == "" or not SHOT_STYLE.has(id) or not ShotCatalog.has(id):
		return "bolt"
	return id if ShotCatalog.open_now(id, Save.challenges) else "bolt"


## origin, dir: the hand's ray in game units.
func fire(hand: String, origin: Vector3, dir: Vector3) -> void:
	var kind := style_for()
	var P: Dictionary = SHOT_STYLE[kind]
	if clock - float(last_shot.get(hand, -10.0)) < P.cool:
		return
	last_shot[hand] = clock
	fired += 1
	host.note_style()
	var hk: float = host.scale_now
	var k := blast_k()
	var p := origin + dir * 0.08 * hk
	_hand_sign = -1.0 if hand == "left" else 1.0
	# A power-up of the mode (Dahrooj Attack's triple shot) fans the shot out.
	var fan := 1
	var st: Node3D = host.stage
	if st and st.is_visible_in_tree() and st.has_method("shot_fan"):
		fan = clampi(int(st.shot_fan()), 1, 5)
	for j in fan:
		var d := dir.rotated(Vector3.UP, (j - (fan - 1) / 2.0) * FAN_STEP) if fan > 1 else dir
		match kind:
			"laser":
				_laser(p, d, k, P)
			"lightning":
				_lightning(p, d, k, P)
			"confetti":
				# The cannon: one pellet down the middle, the others in a ring around it.
				var phase := rnd() * TAU
				for c in int(P.pellets):
					var cd := d if c == 0 else cone_dir(d, float(P.cone) * (0.65 + 0.35 * rnd()), phase + (c - 1) * TAU / (int(P.pellets) - 1))
					_add_shot(kind, P, p, cd, k, j * 8 + c, hand)
			_:
				_add_shot(kind, P, p, d, k, j, hand)
	# Muzzle flash (not for a bubble), at the hand.
	if kind != "bubble":
		_spark(p, Vector3.ZERO, 0.07, Color(String(MUZZLE.get(kind, "ffe9b0"))), (0.07 if kind == "bolt" else 0.05) * hk, true)
	var info := ShotCatalog.info(kind)
	if kind == "dallah":
		_dallah_sfx("fair_ding", float(P.sk), p)
	else:
		host.sfx(String(info.get("sound", "pew")), float(P.sk), p)
	if kind == "confetti":
		host.sfx("start_pop", 0.5, p)
	host.buzz(hand, 0.12 if kind == "bubble" else (0.45 if kind in ["rocket", "lightning", "laser"] else 0.3), 22)


## The dallah's sounds, kept soft and spaced: one `snd` at most every `gap` seconds.
func _dallah_sfx(snd: String, k: float, p: Vector3, gap := DALLAH_DING_GAP) -> void:
	var last := float(_sound_at.get(snd, -10.0))
	if clock - last < gap and clock >= last:
		return
	_sound_at[snd] = clock
	host.sfx(snd, k, p)


## A direction `ang` radians off `d`, turned `az` around it.
static func cone_dir(d: Vector3, ang: float, az: float) -> Vector3:
	var u := d.cross(Vector3.UP) if absf(d.y) < 0.99 else d.cross(Vector3.RIGHT)
	u = u.normalized()
	var w := d.cross(u).normalized()
	return (d * cos(ang) + (u * cos(az) + w * sin(az)) * sin(ang)).normalized()


## A shot taken out of the air (the oldest bouncy ball when a new one comes): a little pop.
func _drop_shot(o: Dictionary) -> void:
	var at := _index_of(shots, o)
	if at < 0:
		return
	impact(o.p, Vector3.UP, o.color)
	if o.node:
		o.node.queue_free()
	shots.remove_at(at)


## One shot in flight (j: its place in a fan or a cannon's spray).
func _add_shot(kind: String, P: Dictionary, p: Vector3, dir: Vector3, k: float, j: int, hand := "") -> Dictionary:
	# Reuse the bounded flight budget instead of stalling a held trigger (a dallah's
	# beans only take free places).
	if kind == "bouncy":
		var mine := shots.filter(func(o: Dictionary) -> bool: return o.kind == "bouncy")
		if mine.size() >= BOUNCY_MAX:
			_drop_shot(mine[0])
	if shots.size() >= SHOTS_MAX:
		if kind == "bean":
			return {}
		var oldest: Dictionary = shots.pop_front()
		if oldest.node:
			oldest.node.queue_free()
	var node: Node3D = null
	var style := ""
	var color := Color.WHITE
	match kind:
		"mini":
			style = MINI_STYLES[(fired + j) % MINI_STYLES.size()]
			var hex: String = MINI_COLORS[_rng.randi() % MINI_COLORS.size()]
			color = Color(hex if hex != "" else String(STYLE_COLORS[style]))
		"bubble":
			style = "bubble"
			color = Color(BUBBLE_TINTS[_rng.randi() % BUBBLE_TINTS.size()])
		"confetti":
			color = Color(CONFETTI_COLS[(fired + j) % CONFETTI_COLS.size()])
		"bouncy":
			color = Color(BOUNCY_COLS[_rng.randi() % BOUNCY_COLS.size()])
		"bean":
			color = Color(BEAN_COLS[_rng.randi() % BEAN_COLS.size()])
		_:
			node = _shot_node(kind, k)
			node.position = p
			if dir.length_squared() > 0.0 and kind in ["bolt", "rocket"]:
				node.basis = Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.999 else Vector3.RIGHT)
			add_child(node)
	var side := dir.cross(Vector3.UP)
	side = side.normalized() if side.length_squared() > 1e-6 else Vector3.RIGHT
	var speed: float = P.speed * k
	if kind == "rocket":
		speed *= 0.15  # it starts slow and speeds up
	var s := {"kind": kind, "node": node, "p": p, "v": dir * speed, "dir": dir, "t": 0.0, "r": P.r * k,
		"k": k, "style": style, "color": color, "spin": rnd() * TAU,
		"wob": rnd() * 6.0, "skips": 0, "float": -1.0, "tap": 0.0, "wet": false,
		"o": p, "side": side * _hand_sign, "hand": hand, "ret": false, "caught": false, "hits": {}, "pops": 0, "bounces": 0,
		"target": {}, "seek_t": 0.0, "size": 1.0, "axis": Vector3(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5).normalized(),
		"hue": rnd(), "spray_t": 0.0, "n": Vector3.UP, "bank": 0.0, "pv": dir * speed}
	if kind == "mini":
		# Every little Dahrooj his own size and tumble.
		s.size = 0.8 + rnd() * 0.5
		s.wob = 6.0 + rnd() * 8.0
	shots.append(s)
	return s


const MATS := {
	"trail": ["ffe9a8", 0.95, "add"], "head": ["ffffff", 1.0, "flat"], "bolt_glow": ["ffb547", 0.55, "add"],
	"rocket": ["ffb347", 1.0, "flat"], "fw_glow": ["ff9a3c", 0.5, "add"], "flame": ["ffcf6a", 0.85, "add"],
	"rk_body": ["e8473c", 1.0, "lit"], "rk_nose": ["f4efe6", 1.0, "lit"], "rk_fin": ["3a6fd8", 1.0, "lit"],
	"glob": ["3fb4ff", 0.75, "alpha"], "glob_core": ["c9f1ff", 0.55, "add"],
	"brass": ["dcaa48", 1.0, "metal"], "brass_dark": ["9c6b22", 1.0, "metal"], "dallah_glow": ["ffd98a", 0.3, "add"],
}


func _mat(key: String) -> Material:
	if _shot_mats.has(key):
		return _shot_mats[key]
	var spec: Array = MATS.get(key, ["ffffff", 1.0, "flat"])
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(Color(String(spec[0])), float(spec[1]))
	match String(spec[2]):
		"flat":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		"add":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		"alpha":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.15
			m.rim_enabled = true
			m.rim = 0.6
		"metal":
			m.metallic = 0.75
			m.roughness = 0.3
		_:
			m.roughness = 0.55
	_shot_mats[key] = m
	return m


static func _mesh_mi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _sphere(r: float, segs := 10) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = maxi(4, int(segs * 0.8))
	return s


static func _cyl(top: float, bottom: float, h: float, segs := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return c


static var _boomerang: ArrayMesh

## The boomerang (game units at k = 1, about 0.3 tip to tip, flat in XZ, spinning about its
## centre of mass at the origin): a smooth banana-curved V with a rounded elbow, arms
## tapering to round tips, an airfoil section (domed on top, flatter below) thinning toward
## the tips; natural wood painted with teal tips, red and yellow bands and white dots.
static func boomerang_mesh() -> ArrayMesh:
	if _boomerang != null:
		return _boomerang
	const L := 0.15  # half span
	const D := 0.1  # how far the arms sweep back
	const E := 0.32  # the elbow's roundness
	const W := 0.024  # half width at the elbow
	const T := 0.0058  # half thickness at the elbow
	var centre := func(u: float) -> Vector3:
		return Vector3(u * L, 0.0, D * (sqrt(u * u + E * E) - E) / (sqrt(1.0 + E * E) - E) + 0.012 * u * u * u * u)
	# The centre of mass (roughly: the centreline's mean), so it spins about the right spot.
	var com := Vector3.ZERO
	for k in 41:
		com += centre.call(-1.0 + 2.0 * k / 40.0)
	com /= 41.0
	var wood := Color("c8894c")
	var dark := Color("8a5428")
	var teal := Color("1fb5a6")
	var red := Color("e2483a")
	var yellow := Color("f6c445")
	var ws := [0.55, 0.0, 0, 0.35]
	var paint := [0.38, 0.0, 0, 0.45]
	# Bands along the span (|u| from the elbow out), mirrored on both arms.
	var bands: Array = [[0.0, 0.12, red], [0.12, 0.16, yellow], [0.16, 0.58, wood], [0.58, 0.62, dark], [0.62, 0.68, red],
		[0.68, 0.72, yellow], [0.72, 0.78, red], [0.78, 0.84, wood], [0.84, 1.0, teal]]
	var list := []
	for side: float in [-1.0, 1.0]:
		for b: Array in bands:
			var u0: float = b[0]
			var u1: float = b[1]
			var n := maxi(2, int(ceil((u1 - u0) * 48.0)))
			list.append([_boomerang_strip(centre, com, side, u0, u1, n, W, T), Transform3D.IDENTITY, b[2], ws if b[2] == wood or b[2] == dark else paint])
		# Painted dots down the middle of each arm, on the top face.
		for k in 6:
			var u := 0.24 + k * 0.058
			var c: Vector3 = (centre.call(u * side) as Vector3) - com
			var top := _boomerang_half_thick(u, T) * 0.92
			list.append([DahroojLooks.sphere(0.0042, 8, 4, 0.0, TAU, 0.0, PI / 2.0), DahroojLooks.xf(c + Vector3(0, top, 0), Vector3.ZERO, Vector3(1, 0.5, 1)),
				Color("fff6e0"), paint])
	_boomerang = DahroojLooks.merge(list)
	return _boomerang


## The round end of an arm: 1 along it, falling to 0 at the very tip (|u| = 1).
static func _boomerang_tip(u: float) -> float:
	if u <= 0.89:
		return 1.0
	var q := (u - 0.89) / 0.11
	return sqrt(maxf(0.0, 1.0 - q * q))


static func _boomerang_width(u: float, W: float) -> float:
	return W * (1.0 - 0.3 * u) * _boomerang_tip(u)


static func _boomerang_half_thick(u: float, T: float) -> float:
	return T * (1.0 - 0.35 * u) * sqrt(_boomerang_tip(u))


## One stretch of an arm, |u| from u0 to u1 on `side`: rings of an airfoil section (domed
## on top, flatter underneath) around the centreline, normals from the surface.
static func _boomerang_strip(centre: Callable, com: Vector3, side: float, u0: float, u1: float, n: int, W: float, T: float) -> Dictionary:
	const M := 16
	var pv := PackedVector3Array()
	var pn := PackedVector3Array()
	var puv := PackedVector2Array()
	var pi := PackedInt32Array()
	var at := func(u: float, a: float) -> Vector3:
		var c: Vector3 = (centre.call(u * side) as Vector3) - com
		var d: Vector3 = (centre.call(minf(u + 0.01, 1.0) * side) as Vector3) - (centre.call(maxf(u - 0.01, 0.0) * side) as Vector3)
		if d.length_squared() < 1e-12:
			d = Vector3(side, 0, 0)
		var tw := d.normalized()
		var across := Vector3(tw.z, 0.0, -tw.x)
		var w := _boomerang_width(u, W)
		var th := _boomerang_half_thick(u, T)
		var sa := sin(a)
		return c + across * w * cos(a) + Vector3.UP * th * sa * (1.0 if sa > 0.0 else 0.6)
	for j in n + 1:
		var u := lerpf(u0, u1, float(j) / n)
		var c: Vector3 = (centre.call(u * side) as Vector3) - com
		for i in M + 1:
			var a := TAU * i / M
			var p: Vector3 = at.call(u, a)
			var du: Vector3 = (at.call(minf(u + 0.004, 1.0), a) as Vector3) - (at.call(maxf(u - 0.004, 0.0), a) as Vector3)
			var da: Vector3 = (at.call(u, a + 0.05) as Vector3) - (at.call(u, a - 0.05) as Vector3)
			var nrm := du.cross(da)
			if nrm.length_squared() < 1e-16 or u >= 0.999:
				nrm = p - c
			nrm = nrm.normalized()
			if nrm.dot(p - c) < 0.0:
				nrm = -nrm
			pv.append(p)
			pn.append(nrm)
			puv.append(Vector2(u, float(i) / M))
	var row := M + 1
	for j in n:
		for i in M:
			var q := j * row + i
			pi.append_array([q, q + 1, q + row + 1, q, q + row + 1, q + row])
	return {"v": pv, "n": pn, "uv": puv, "i": pi}


## A shot drawn as its own little model (mini and bubble shots are drawn by shot_crowd,
## pellets, bouncy balls and beans with the sparks). Looks along -z.
func _shot_node(kind: String, k: float) -> Node3D:
	var root := Node3D.new()
	match kind:
		"bolt":
			# A hot white core in an amber glow, a long tapering trail behind.
			for t: Array in [[0.016, 0.52, "bolt_glow"], [0.006, 0.42, "trail"]]:
				var tr := _mesh_mi(_cyl(0.0015 * k, float(t[0]) * k, float(t[1]) * k, 8), _mat(String(t[2])))
				tr.rotation.x = PI / 2  # +y (the thin end) behind the head (the head looks along -z)
				tr.position.z = float(t[1]) * 0.5 * k
				root.add_child(tr)
			root.add_child(_mesh_mi(_sphere(0.03 * k), _mat("bolt_glow")))
			root.add_child(_mesh_mi(_sphere(0.013 * k), _mat("head")))
		"firework":
			root.add_child(_mesh_mi(_sphere(0.017 * k), _mat("rocket")))
			root.add_child(_mesh_mi(_sphere(0.04 * k), _mat("fw_glow")))
		"rocket":
			var body := _mesh_mi(_cyl(0.018 * k, 0.018 * k, 0.11 * k, 10), _mat("rk_body"))
			body.rotation.x = -PI / 2  # +y (the nose end) forward, -z
			root.add_child(body)
			var nose := _mesh_mi(_cyl(0.0, 0.018 * k, 0.045 * k, 10), _mat("rk_nose"))
			nose.rotation.x = -PI / 2
			nose.position.z = -0.0775 * k
			root.add_child(nose)
			for i in 3:
				var fin := _mesh_mi(BoxMesh.new(), _mat("rk_fin"))
				(fin.mesh as BoxMesh).size = Vector3(0.004, 0.03, 0.035) * k
				var a := i * TAU / 3.0
				fin.position = Vector3(cos(a) * 0.024 * k, sin(a) * 0.024 * k, 0.045 * k)
				fin.rotation.z = a - PI / 2
				root.add_child(fin)
			var flame := _mesh_mi(_sphere(0.022 * k, 8), _mat("flame"))
			flame.name = "Flame"
			flame.position.z = 0.07 * k
			root.add_child(flame)
		"boomerang":
			# A classic wooden boomerang (boomerang_mesh): it leans into its curve (Tilt) and
			# spins flat in its own plane (Spin).
			var tilt := Node3D.new()
			tilt.name = "Tilt"
			root.add_child(tilt)
			var spin := Node3D.new()
			spin.name = "Spin"
			tilt.add_child(spin)
			var mi := _mesh_mi(boomerang_mesh(), DahroojLooks.acc_material())
			mi.scale = Vector3.ONE * k
			spin.add_child(mi)
		"glob":
			var blob := _mesh_mi(_sphere(0.045 * k, 14), _mat("glob"))
			blob.name = "Blob"
			root.add_child(blob)
			var core := _mesh_mi(_sphere(0.026 * k, 10), _mat("glob_core"))
			core.position = Vector3(-0.012, 0.014, 0.0) * k
			root.add_child(core)
		"dallah":
			# The Arabic coffee pot: a round-bellied brass body, a waisted neck, a domed lid
			# with its finial, the long beaked spout and the handle at the back.
			var pot := Node3D.new()
			pot.name = "Spin"
			pot.scale = Vector3.ONE * 1.3
			root.add_child(pot)
			pot.add_child(_mesh_mi(_cyl(0.02 * k, 0.034 * k, 0.045 * k, 14), _mat("brass")))
			var base := _mesh_mi(_cyl(0.034 * k, 0.03 * k, 0.008 * k, 14), _mat("brass_dark"))
			base.position.y = -0.026 * k
			pot.add_child(base)
			var neck := _mesh_mi(_cyl(0.023 * k, 0.016 * k, 0.03 * k, 12), _mat("brass"))
			neck.position.y = 0.037 * k
			pot.add_child(neck)
			var lid := _mesh_mi(_cyl(0.004 * k, 0.024 * k, 0.018 * k, 12), _mat("brass_dark"))
			lid.position.y = 0.061 * k
			pot.add_child(lid)
			var fin := _mesh_mi(_sphere(0.007 * k, 8), _mat("brass"))
			fin.position.y = 0.074 * k
			pot.add_child(fin)
			var spout := _mesh_mi(_cyl(0.004 * k, 0.008 * k, 0.07 * k, 8), _mat("brass"))
			spout.position = Vector3(0.0, 0.03 * k, -0.04 * k)
			spout.rotation.x = -0.75
			pot.add_child(spout)
			var handle := _mesh_mi(TorusMesh.new(), _mat("brass_dark"))
			(handle.mesh as TorusMesh).inner_radius = 0.016 * k
			(handle.mesh as TorusMesh).outer_radius = 0.021 * k
			handle.rotation.z = PI / 2
			handle.position = Vector3(0.0, 0.012 * k, 0.03 * k)
			pot.add_child(handle)
			pot.add_child(_mesh_mi(_sphere(0.07 * k, 10), _mat("dallah_glow")))
	return root


## The shots drawn by the crowd: tumbling little Dahroojs (no eyes), each his own size and
## tumble, and iridescent soap bubbles that wobble as they drift.
func _draw_shots() -> void:
	var n := 0
	for s in shots:
		if s.style != "":
			n += 1
	if n == 0 and _crowd_drawn == 0:
		return
	shot_crowd.begin()
	for s in shots:
		if s.style == "":
			continue
		var p: Vector3 = s.p
		var spin: float = s.spin
		if s.kind == "mini":
			var tumble := Basis(s.axis as Vector3, spin) * Vector3.FORWARD
			var sq := sin(float(s.t) * float(s.wob)) * 0.08
			shot_crowd.add(s.style, p, s.r * float(s.size), p + tumble, Vector2(1.0 + sq, 1.0 - sq), "", "", s.color)
		else:
			var wob: float = s.wob
			var w := sin(wob * 2.3) * 0.08 + sin(wob * 3.7 + 1.3) * 0.04
			# The film's colours slide around as it turns.
			var base: Color = s.color
			var film := Color.from_hsv(fposmod(float(s.hue) + float(s.t) * 0.35 + sin(wob) * 0.08, 1.0), 0.3, 1.0)
			shot_crowd.add("bubble", p, s.r, p + Vector3(sin(spin), 0.0, cos(spin)), Vector2(1.0 + w, 1.0 - w), "", "", base.lerp(film, 0.6))
	shot_crowd.end()
	_crowd_drawn = n


func _spark(p: Vector3, v: Vector3, life: float, color: Color, size: float, flash := false, flake := false) -> void:
	if sparks.size() >= SPARKS_MAX:
		return
	sparks.append({"p": p, "v": v, "t": 0.0, "max": life, "flash": flash, "color": color, "size": size, "k": blast_k(),
		"flake": flake, "axis": Vector3(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5).normalized() if flake else Vector3.UP, "rot": rnd() * TAU})


## A little spray of sparks where a shot lands, with a quick flash.
func impact(p: Vector3, n: Vector3, color := Color("ffd27a")) -> void:
	var k := blast_k()
	_spark(p, Vector3.ZERO, 0.08, Color("fffaf2"), 0.05 * k, true)
	for i in 8:
		var d := Vector3(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5).normalized()
		d = (d + n * 1.2).normalized() * ((1.0 + rnd() * 1.5) * k)
		_spark(p, d, 0.25 + rnd() * 0.2, color if i % 2 else Color("fffaf2"), (0.008 + rnd() * 0.008) * k)


## A firework's bloom: a flash, a round shell of sparks in two colours and white glitter.
func bloom(p: Vector3) -> void:
	var k := blast_k()
	var c1 := Color(FIRE_COLS[_rng.randi() % (FIRE_COLS.size() - 1)])
	var c2 := Color(FIRE_COLS[_rng.randi() % FIRE_COLS.size()])
	_spark(p, Vector3.ZERO, 0.1, Color("fffaf2"), 0.07 * k, true)
	for i in 36:
		var d := Vector3(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5).normalized() * ((2.2 + rnd() * 0.5) * k)
		_spark(p, d, 0.65 + rnd() * 0.3, c1 if i % 2 else c2, (0.011 + rnd() * 0.006) * k)
	for _i in 12:
		var d := Vector3(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5).normalized() * ((0.6 + rnd() * 1.2) * k)
		_spark(p, d, 0.8 + rnd() * 0.4, Color("fffaf2"), 0.007 * k)
	host.sfx("firework_burst", 1.0, p)


## A rocket's blast: a flash, fire and smoke.
func explosion(p: Vector3) -> void:
	var k := blast_k()
	_spark(p, Vector3.ZERO, 0.12, Color("fff4d6"), 0.09 * k, true)
	for i in 26:
		var d := Vector3(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5).normalized() * ((1.0 + rnd() * 2.4) * k)
		_spark(p, d, 0.35 + rnd() * 0.35, Color("ff7a2e") if i % 3 else Color("ffd34d"), (0.016 + rnd() * 0.014) * k)
	for _i in 10:
		var d := Vector3(rnd() - 0.5, rnd() * 0.8, rnd() - 0.5) * 1.2 * k
		_spark(p, d, 0.7 + rnd() * 0.4, Color("8a8580"), (0.03 + rnd() * 0.02) * k, true)
	host.sfx("boom", 1.0, p)


## The water shot's splash: blue drops every way.
func splat(p: Vector3, n: Vector3) -> void:
	var k := blast_k()
	for i in 16:
		var d := (Vector3(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5).normalized() + n).normalized() * ((1.0 + rnd() * 2.0) * k)
		_spark(p, d, 0.4 + rnd() * 0.3, Color("3fb4ff") if i % 3 else Color("c9f1ff"), (0.012 + rnd() * 0.014) * k)
	host.sfx("splash", 0.75, p)
	host.sfx("squeak", 0.7, p)


func sky_pop(p: Vector3) -> void:
	if p.y > host.eye_game().y + 0.25 * host.scale_now:
		host.runtime.ch_add("skyPop5")


## A Dahrooj pops: a puff of sparks in his colour.
func burst(p: Vector3, style: String, by_player := true) -> void:
	if by_player:
		sky_pop(p)
	var k := blast_k()
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


## Challenge credit for the blaster (GameRuntime): n targets hit by a `kind` shot.
func _credit(kind: String, n: int) -> void:
	var rt = host.get("runtime")
	if n > 0 and rt != null and rt.has_method("shot_hits"):
		rt.shot_hits(kind, n)


## A challenge's progress set to `value` (GameRuntime.ch_progress keeps the best).
func _ch(id: String, value: int) -> void:
	var rt = host.get("runtime")
	if rt != null and rt.has_method("ch_progress"):
		rt.ch_progress(id, value)


# --- what the homing and chaining shots go for -----------------------------------------

## Everything a rocket or a lightning arc can go for: [{kind, ref, p}] — leftovers ("r"),
## earlier throws ("v"), the throw in flight ("b"), the Golden Dahrooj ("g", main's
## GoldenDahrooj while he is out), the stage's hidden hit spheres ("s": the layers = 0
## MeshInstance3Ds the blaster's ray finds) and the rain's Dahroojs ("i": IntroRain drops,
## drawn by its Crowd, so they have no spheres of their own).
func targets() -> Array:
	var out: Array = []
	var g := golden()
	if g != null:
		out.append({"kind": "g", "ref": g, "p": g.pos})
	var ir := rain()
	if ir != null:
		var w2l := global_transform.affine_inverse()
		for d: IntroRain.Drop in ir.target_drops():
			out.append({"kind": "i", "ref": d, "p": w2l * ir.drop_world(d)})
	for r in rests:
		out.append({"kind": "r", "ref": r, "p": r.p})
	for v in ball.volley:
		out.append({"kind": "v", "ref": v, "p": v.pos})
	if ball.shot and not ball.held:
		out.append({"kind": "b", "ref": null, "p": ball.pos})
	var st: Node3D = host.stage
	if st and st.is_visible_in_tree() and st.has_method("shoot"):
		for mi in st.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.layers == 0 and m.mesh != null and m.is_visible_in_tree():
				out.append({"kind": "s", "ref": m, "p": _proxy_center(m)})
	return out


## The Golden Dahrooj while he is out (main's `golden`), or null.
func golden() -> GoldenDahrooj:
	var g = host.get("golden") if host != null else null
	if g is GoldenDahrooj and (g as GoldenDahrooj).active:
		return g as GoldenDahrooj
	return null


## Main's rain (the opening or Dahrooj Rain) while it is falling, or null.
func rain() -> IntroRain:
	var ir = host.get("intro") if host != null else null
	if ir is IntroRain and (ir as IntroRain).active and (ir as IntroRain).leaving <= 0.0:
		return ir as IntroRain
	return null


## How close a shot must pass a target of this kind (beyond its own radius R).
func _target_r(t: Dictionary) -> float:
	if String(t.kind) == "g":
		return (t.ref as GoldenDahrooj).radius() * 1.15
	if String(t.kind) == "i":
		var ir := rain()
		return ir.drop_radius_world(t.ref) * global_transform.affine_inverse().basis.get_scale().x if ir != null else Ball.BR
	return Ball.BR


func _proxy_center(m: MeshInstance3D) -> Vector3:
	return global_transform.affine_inverse() * m.global_transform * m.mesh.get_aabb().get_center()


static func _index_of(list: Array, ref) -> int:
	for i in list.size():
		if is_same(list[i], ref):
			return i
	return -1


## Where a target is now, or null once it is gone.
func target_at(t: Dictionary) -> Variant:
	if t.is_empty():
		return null
	match String(t.kind):
		"r":
			var i := _index_of(rests, t.ref)
			return rests[i].p if i >= 0 else null
		"v":
			var i := _index_of(ball.volley, t.ref)
			return ball.volley[i].pos if i >= 0 else null
		"b":
			return ball.pos if ball.shot and not ball.held else null
		"g":
			var g := golden()
			return g.pos if g != null and is_same(g, t.ref) else null
		"i":
			var ir := rain()
			if ir != null and ir.has_drop(t.ref):
				return global_transform.affine_inverse() * ir.drop_world(t.ref)
		"s":
			var m = t.ref
			if is_instance_valid(m) and (m as MeshInstance3D).is_visible_in_tree():
				return _proxy_center(m)
	return null


## Hits a target: a Dahrooj pops, a stage target takes the shot. True when it counted.
func hit_target(t: Dictionary, dir: Vector3) -> bool:
	match String(t.kind):
		"r":
			var i := _index_of(rests, t.ref)
			if i < 0:
				return false
			burst(rests[i].p, rests[i].style)
			_drop_rest(i)
			return true
		"v":
			var i := _index_of(ball.volley, t.ref)
			if i < 0:
				return false
			burst(ball.volley[i].pos, Save.style)
			ball.volley.remove_at(i)
			return true
		"b":
			if not (ball.shot and not ball.held):
				return false
			burst(ball.pos, Save.style)
			host.ball_popped()
			return true
		"g":
			var g := golden()
			if g == null or not is_same(g, t.ref):
				return false
			impact(g.pos, -dir if dir.length_squared() > 0.0 else Vector3.BACK, Color("ffc928"))
			return g.catch("shot")
		"i":
			var ir := rain()
			if ir == null or not ir.has_drop(t.ref):
				return false
			ir.pop_ball(t.ref)
			return true
		"s":
			var m = t.ref
			var st: Node3D = host.stage
			if not is_instance_valid(m) or st == null or not st.has_method("shoot"):
				return false
			var at := _proxy_center(m)
			var took: bool = st.shoot(m, at, dir if dir.length_squared() > 0.0 else Vector3.FORWARD)
			impact(at, -dir, Color("ffd27a") if took else Color("fffaf2"))
			return took
	return false


## Pops what is within RR of c (Dahroojs, earlier throws, the opening's rain and the
## stage's targets). Returns how many.
func pop_radius(c: Vector3, RR: float) -> int:
	var n := 0
	var BR := Ball.BR
	var hk: float = host.scale_now
	var intro = host.get("intro")
	if intro and intro.active:
		intro.pop_near(to_global(c), RR / hk)
	for j in range(rests.size() - 1, -1, -1):
		if (rests[j].p as Vector3).distance_to(c) < RR + BR:
			burst(rests[j].p, rests[j].style)
			_drop_rest(j)
			n += 1
	for j in range(ball.volley.size() - 1, -1, -1):
		if (ball.volley[j].pos as Vector3).distance_to(c) < RR + BR:
			burst(ball.volley[j].pos, Save.style)
			ball.volley.remove_at(j)
			n += 1
	var g := golden()
	if g != null and g.pos.distance_to(c) < RR + g.radius():
		var gd := g.pos - c
		if hit_target({"kind": "g", "ref": g, "p": g.pos}, gd.normalized() if gd.length_squared() > 1e-8 else Vector3.FORWARD):
			n += 1
	for t in targets():
		if t.kind == "s" and (t.p as Vector3).distance_to(c) < RR + _proxy_radius(t.ref):
			var d: Vector3 = (t.p as Vector3) - c
			if hit_target(t, d.normalized() if d.length_squared() > 1e-8 else Vector3.FORWARD):
				n += 1
	return n


func _proxy_radius(m: MeshInstance3D) -> float:
	var xf := global_transform.affine_inverse() * m.global_transform
	return m.mesh.get_aabb().size.length() * 0.35 * xf.basis.get_scale().x


## The nearest target ahead of a rocket (within `far`, in front of it), or {}. Each rocket picks
## its own: one another rocket in the air is already after is passed over while there are others.
func _seek(p: Vector3, fwd: Vector3, far: float, me := {}) -> Dictionary:
	var taken := []
	for o: Dictionary in shots:
		if o.kind == "rocket" and not is_same(o, me) and not (o.target as Dictionary).is_empty():
			taken.append(o.target.ref)
	var best := {}
	var best_score := INF
	var spare := {}
	var spare_score := INF
	for t in targets():
		var to: Vector3 = (t.p as Vector3) - p
		var d := to.length()
		if d < 1e-4 or d > far:
			continue
		var facing := fwd.dot(to / d)
		if facing < 0.3:
			continue
		var score := d * (1.6 - facing)
		if taken.any(func(r) -> bool: return is_same(r, t.ref)):
			if score < spare_score:
				spare_score = score
				spare = t
			continue
		if score < best_score:
			best_score = score
			best = t
	return best if not best.is_empty() else spare


func _floor_y() -> float:
	var intro = host.get("intro")
	if intro and intro.active:
		return to_local(host.rig.global_position).y
	return 0.0


# --- the instant shots: laser and lightning ---------------------------------------------

## How far a beam from p along dir goes before the floor or a wall of the room.
func _beam_reach(p: Vector3, dir: Vector3, far: float, R: float) -> float:
	var end := far
	var fy := _floor_y()
	if dir.y < -1e-4 and p.y > fy:
		end = minf(end, (fy - p.y) / dir.y)
	if host.has_method("room_hit") and host.room_active():
		var step := 0.5 * blast_k()
		var d := 0.0
		while d < end:
			var nd := minf(end, d + step)
			var rh: Dictionary = host.room_hit(p + dir * nd, dir * 40.0 * blast_k(), p + dir * d, R)
			if float(rh.hit) > 0.0:
				return maxf(0.0, ((rh.p as Vector3) - p).dot(dir))
			d = nd
	return end


## The laser: an instant beam that pops (or hits) up to `pierce` targets along the way,
## stopping at a wall; a glowing line that fades.
func _laser(p: Vector3, dir: Vector3, k: float, P: Dictionary) -> void:
	var R: float = P.r * k
	var end := _beam_reach(p, dir, P.range * k, R)
	var cur := 0.0
	var hits := 0
	var seen: Array = []
	var st: Node3D = host.stage
	var blocked := false
	var col := Color("ff3b6b")
	while hits < int(P.pierce):
		# The nearest Dahrooj along the beam...
		var best := {}
		var best_d := end
		for t in targets():
			if t.kind == "s":
				continue
			var along := ((t.p as Vector3) - p).dot(dir)
			if along < cur or along > best_d:
				continue
			if (p + dir * along).distance_to(t.p) < _target_r(t) + R:
				best_d = along
				best = t
		# ... or the first thing of the stage before it.
		var sh := {}
		if st and st.is_visible_in_tree() and best_d > cur:
			sh = ray_stage(st, p + dir * cur, dir, best_d - cur, seen)
		if not sh.is_empty():
			var d := ((sh.point as Vector3) - p).dot(dir)
			seen.append(sh.node)
			var took: bool = st.has_method("shoot") and st.shoot(sh.node, sh.point, dir)
			impact(sh.point, sh.normal, col if took else Color("fffaf2"))
			if took:
				hits += 1
				cur = d
				continue
			end = d
			blocked = true
			host.sfx("thump", 0.25, sh.point)
			break
		if best.is_empty():
			break
		hit_target(best, dir)
		hits += 1
		cur = best_d
	_credit("laser", hits)
	if hits >= int(P.pierce):
		end = cur  # the beam stops in the last one
	elif not blocked and end < P.range * k - 1e-3:
		impact(p + dir * end, -dir, col)
	var intro = host.get("intro")
	if intro and intro.active:
		intro.pop_along(to_global(p), to_global(p + dir * end), R / float(host.scale_now))
	_arc(p, p + dir * maxf(end, 0.05 * k), 1, 0.0, 0.022 * k, col, P.life)


## Lightning: an arc to the target nearest the aim, then on to the nearest one within a
## hop of it, up to `chain` targets, along jagged flickering arcs.
func _lightning(p: Vector3, dir: Vector3, k: float, P: Dictionary) -> void:
	var col := Color("5aa8ff")
	var all := targets()
	var first := {}
	var best := INF
	var far: float = P.range * k
	for t in all:
		var to: Vector3 = (t.p as Vector3) - p
		var d := to.length()
		if d < 1e-4 or d > far:
			continue
		var ang := dir.angle_to(to)
		if ang > float(P.cone):
			continue
		var score := ang * 4.0 + d / far
		if score < best:
			best = score
			first = t
	if first.is_empty():
		# Nothing to go for: a crackle straight ahead, to whatever is there.
		var end := _beam_reach(p, dir, far * 0.5, P.r * k)
		var st: Node3D = host.stage
		if st and st.is_visible_in_tree():
			var sh := ray_stage(st, p, dir, end)
			if not sh.is_empty():
				end = ((sh.point as Vector3) - p).dot(dir)
				var took: bool = st.has_method("shoot") and st.shoot(sh.node, sh.point, dir)
				impact(sh.point, sh.normal, col if took else Color("cfe8ff"))
		_arc(p, p + dir * end, maxi(4, int(end / (0.35 * k))), 0.1, 0.02 * k, col, P.life)
		return
	var from := p
	var cur := first
	var chain := 0
	var zapped := 0
	var done: Array = []
	while not cur.is_empty():
		var at: Vector3 = cur.p
		_arc(from, at, clampi(int(from.distance_to(at) / (0.3 * k)), 4, 12), 0.12, 0.016 * k, col, P.life)
		done.append(cur.ref)
		var d := (at - from).normalized() if at.distance_to(from) > 1e-5 else dir
		if hit_target(cur, d):
			zapped += 1
		_spark(at, Vector3.ZERO, 0.1, Color("e8f4ff"), 0.04 * k, true)
		chain += 1
		if chain > 1:
			host.sfx("bricks_tink", 1.0, at)
		if chain >= int(P.chain):
			break
		from = at
		var nxt := {}
		var nd: float = P.hop * k
		for t in all:
			if done.any(func(x): return is_same(x, t.ref)):
				continue
			if t.kind == "s" and not (t.ref as MeshInstance3D).is_visible_in_tree():
				continue
			if t.kind != "s" and target_at(t) == null:
				continue
			var dd := (t.p as Vector3).distance_to(from)
			if dd < nd:
				nd = dd
				nxt = t
		cur = nxt
	_ch("chain4", zapped)
	var intro = host.get("intro")
	if intro and intro.active:
		intro.pop_along(to_global(p), to_global(p + dir * far * 0.5), P.r * k / float(host.scale_now))


func _arc(a: Vector3, b: Vector3, n: int, jit: float, w: float, color: Color, life: float) -> void:
	if arcs.size() >= ARCS_MAX:
		arcs.pop_front()
	arcs.append({"a": a, "b": b, "n": maxi(1, n), "jit": jit, "w": w, "color": color, "t": 0.0, "max": life,
		"k": blast_k(), "pts": PackedVector3Array(), "tick": -1})


func _arc_points(arc: Dictionary) -> PackedVector3Array:
	var a: Vector3 = arc.a
	var b: Vector3 = arc.b
	var n: int = arc.n
	var pts := PackedVector3Array()
	var d := b - a
	var L := d.length()
	var u := d.cross(Vector3.UP)
	if u.length_squared() < 1e-8:
		u = d.cross(Vector3.RIGHT)
	u = u.normalized()
	var w := d.cross(u).normalized()
	for i in n + 1:
		var f := i / float(n)
		var q := a + d * f
		if i > 0 and i < n and float(arc.jit) > 0.0:
			var amp: float = float(arc.jit) * L / sqrt(float(n)) * sin(PI * f)
			q += (u * (rnd() - 0.5) + w * (rnd() - 0.5)) * 2.0 * amp
		pts.append(q)
	return pts


func _draw_arcs(dt: float, k: float) -> void:
	var n := 0
	for i in range(arcs.size() - 1, -1, -1):
		var arc: Dictionary = arcs[i]
		arc.t += dt
		if arc.t >= arc.max:
			arcs.remove_at(i)
	for arc in arcs:
		if absf(float(arc.k) - k) > 1e-6:
			arc.w *= k / float(arc.k)
			arc.k = k
		# Lightning flickers: a new jag 30 times a second.
		var tick := int(float(arc.t) * 30.0)
		if tick != int(arc.tick) or (arc.pts as PackedVector3Array).is_empty():
			arc.tick = tick
			arc.pts = _arc_points(arc)
		var f: float = 1.0 - float(arc.t) / float(arc.max)
		var pts: PackedVector3Array = arc.pts
		for j in pts.size() - 1:
			for layer in 2:
				if n >= BEAM_SEGS_MAX:
					break
				var w: float = float(arc.w) * (1.0 if layer == 0 else 0.28) * (0.4 + 0.6 * f)
				# A coloured glow round a pale core of the same hue.
				var c: Color = arc.color if layer == 0 else (arc.color as Color).lerp(Color.WHITE, 0.55)
				_beam_mm.set_instance_transform(n, _seg_xf(pts[j], pts[j + 1], w))
				_beam_mm.set_instance_color(n, Color(c, (0.6 if layer == 0 else 1.0) * f))
				n += 1
	_beam_mm.visible_instance_count = n


static func _seg_xf(a: Vector3, b: Vector3, w: float) -> Transform3D:
	var d := b - a
	var L := d.length()
	if L < 1e-6:
		return Transform3D(Basis.from_scale(Vector3.ONE * w), a)
	var bz := Basis.looking_at(d / L, Vector3.UP if absf(d.y / L) < 0.999 else Vector3.RIGHT)
	return Transform3D(Basis(bz.x * w, bz.y * w, bz.z * L), (a + b) * 0.5)


# --- the shots in flight -----------------------------------------------------------------

## How a shot moves this step (before it meets anything).
func _move(s: Dictionary, P: Dictionary, dt: float, k: float) -> void:
	var G := REAL_G * k
	match String(s.kind):
		"rocket":
			s.seek_t -= dt
			var tp = target_at(s.target)
			if tp == null and s.seek_t <= 0.0:
				s.seek_t = 0.1
				var fwd0: Vector3 = (s.v as Vector3).normalized() if (s.v as Vector3).length_squared() > 1e-10 else s.dir
				s.target = _seek(s.p, fwd0, P.seek * k, s)
				tp = target_at(s.target)
			var fwd: Vector3 = (s.v as Vector3).normalized() if (s.v as Vector3).length_squared() > 1e-10 else s.dir
			# It locks on after a moment and turns toward its target.
			if tp != null and s.t > 0.1:
				var want: Vector3 = ((tp as Vector3) - (s.p as Vector3)).normalized()
				var ang := fwd.angle_to(want)
				if ang > 1e-4:
					fwd = fwd.slerp(want, minf(1.0, float(P.turn) * dt / ang)).normalized()
			var sp: float = lerpf(0.15, 1.0, smoothstep(0.0, 0.5, float(s.t))) * P.speed * k
			s.v = fwd * sp
			s.p += s.v * dt
		"boomerang":
			var T: float = P.life
			if not s.ret:
				var u := clampf(float(s.t) / T, 0.0, 1.0)
				var back: Vector3 = _hand_at(s) - (s.o as Vector3)
				var want: Vector3 = (s.o as Vector3) + (s.dir as Vector3) * (P.reach * k * sin(PI * u)) \
					+ (s.side as Vector3) * (P.swing * k * sin(TAU * u)) + Vector3.UP * (0.25 * k * sin(PI * u)) + back * u
				s.v = (want - (s.p as Vector3)) / dt if dt > 0.0 else Vector3.ZERO
				s.p = want
				if u >= 1.0:
					s.caught = true
			else:
				# Knocked back: straight home to the hand.
				var to: Vector3 = _hand_at(s) - (s.p as Vector3)
				if to.length() < float(s.r) * 3.0 or s.t > T + 2.0:
					s.caught = true
				s.v = to.normalized() * P.speed * k
				s.p += s.v * minf(dt, to.length() / maxf(1e-6, P.speed * k))
		_:
			s.v.y -= G * P.grav * dt
			if s.kind == "bubble":
				s.wob += dt * 3.0
				s.v.x += sin(s.wob) * 0.25 * k * dt
				s.v.z += cos(s.wob * 0.8) * 0.25 * k * dt
			s.p += s.v * dt


## Where a boomerang comes back to: the hand that threw it, else where it left.
func _hand_at(s: Dictionary) -> Vector3:
	var rig = host.get("rig")
	var gr = host.get("game_root")
	if s.hand != "" and rig and gr and rig.has_method("aim_transform") and host.get("xr") == true:
		var a: Transform3D = rig.aim_transform(s.hand)
		return (gr as Node3D).global_transform.affine_inverse() * a.origin
	return s.o


## The trail a shot leaves.
func _trail(s: Dictionary, k: float, dt: float) -> void:
	var p: Vector3 = s.p
	var v: Vector3 = s.v
	match String(s.kind):
		"bolt":
			if rnd() < 0.5:
				_spark(p, -v * 0.02 + Vector3(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5) * 0.2 * k, 0.16, Color("ffe9a8"), 0.006 * k, true)
		"firework":
			# Gold glitter and orange embers.
			for i in 2:
				var c := Color("ffd76a") if i == 0 else Color("ff8a3c")
				_spark(p, -v * 0.06 + Vector3(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5) * 0.4 * k, 0.3 + rnd() * 0.2,
					c if rnd() < 0.85 else Color("fffaf2"), (0.005 + rnd() * 0.004) * k)
		"confetti":
			if rnd() < 0.7:
				_spark(p, -v * 0.03 + Vector3(rnd() - 0.5, rnd() * 0.3, rnd() - 0.5) * 0.4 * k, 0.6 + rnd() * 0.3,
					Color(CONFETTI_COLS[_rng.randi() % CONFETTI_COLS.size()]), (0.01 + rnd() * 0.006) * k, false, true)
		"rocket":
			_spark(p - v.normalized() * 0.07 * k, -v * 0.05, 0.12, Color("ffcf6a"), 0.02 * k, true)
			if rnd() < 0.7:
				_spark(p - v.normalized() * 0.08 * k, Vector3(rnd() - 0.5, rnd() * 0.5, rnd() - 0.5) * 0.25 * k, 0.6 + rnd() * 0.3,
					Color("bdb8b0"), (0.012 + rnd() * 0.01) * k, true)
		"glob":
			if rnd() < 0.25:
				_spark(p, v * 0.2, 0.4, Color("3fb4ff"), 0.008 * k)
		"boomerang":
			if rnd() < 0.35:
				_spark(p, Vector3.ZERO, 0.22, Color(1, 1, 1, 0.6), 0.008 * k, true)
		"dallah":
			# It sprays coffee beans as it spins, with a wisp of steam.
			s.spray_t -= dt
			if s.spray_t <= 0.0:
				s.spray_t = SHOT_STYLE.dallah.spray
				var d := cone_dir(((s.side as Vector3).rotated(Vector3.UP, float(s.spin)) * 0.6 + v.normalized()).normalized(), 0.5, rnd() * TAU)
				var b := _add_shot("bean", SHOT_STYLE.bean, p, d, k, 0)
				if not b.is_empty():
					b.v += v * 0.5
			if rnd() < 0.3:
				_spark(p + Vector3.UP * 0.06 * k, Vector3(0, 0.4, 0) * k, 0.5, Color(1, 1, 1, 0.5), 0.012 * k, true)


## A shot popped `n` Dahroojs along its way: does it stop?
func _on_pop(s: Dictionary, P: Dictionary, n: int) -> bool:
	match String(s.kind):
		"mini":
			s.v *= 0.6
			return false
		"bouncy":
			s.pops += n
			s.v *= 0.85
			_ch("bouncy3", int(s.pops))
			return s.pops >= int(P.pops)
		"boomerang":
			s.pops += n
			return false
		"dallah":
			return false
	return true


## A shot meets something solid (took: a stage target took it): does it stop?
func _on_solid(s: Dictionary, P: Dictionary, point: Vector3, n: Vector3, took: bool) -> bool:
	var R: float = s.r
	match String(s.kind):
		"mini":
			if took:
				return true
			s.p = point + n * R
			var vn: float = (s.v as Vector3).dot(n)
			if vn < 0.0:
				s.v -= n * 1.5 * vn
			return false
		"bouncy":
			s.p = point + n * R
			var vn: float = (s.v as Vector3).dot(n)
			if vn < 0.0:
				s.v -= n * 1.8 * vn
			s.bounces += 1
			if took:
				s.pops += 1
				_ch("bouncy3", int(s.pops))
			host.sfx("bricks_tink", clampf((s.v as Vector3).length() / (15.0 * float(s.k)), 0.0, 1.0), s.p)
			return s.bounces > int(P.bounces) or s.pops >= int(P.pops)
		"boomerang":
			if not took:
				s.ret = true
				s.p = point + n * R
			return false
	s.p = point
	s.n = n
	return true


## A boomerang's pose: it faces along its flight, leans into the curve it is turning (from its
## sideways acceleration; thrown on edge, it lies down flatter as it comes back) and spins
## flat in its own plane.
func _boomerang_pose(s: Dictionary, nd: Node3D, dt: float) -> void:
	var tilt := nd.get_node_or_null("Tilt") as Node3D
	var sp := nd.get_node_or_null("Tilt/Spin") as Node3D
	if tilt == null or sp == null:
		return
	var v: Vector3 = s.v
	var hv := Vector3(v.x, 0.0, v.z)
	if hv.length_squared() > 1e-10 and dt > 0.0:
		var f := hv.normalized()
		var right := f.cross(Vector3.UP)
		var lat := ((v - (s.pv as Vector3)) / dt).dot(right) / maxf(1e-3, float(s.k))
		var life := float(SHOT_STYLE.boomerang.life)
		var lean := lerpf(0.9, 0.25, clampf(float(s.t) / life, 0.0, 1.0))
		var want := clampf(-lat * 0.03, -lean, lean)
		s.bank = lerpf(float(s.bank), want, 1.0 - exp(-10.0 * dt))
		tilt.basis = Basis.looking_at(f, Vector3.UP) * Basis(Vector3.FORWARD, float(s.bank)) * Basis(Vector3.RIGHT, 0.1)
	s.pv = v
	sp.rotation = Vector3(0.0, float(s.spin), 0.0)


## Ends a shot: a firework blooms, a rocket blows up, a glob splats, a dallah spills.
func _finish(s: Dictionary, P: Dictionary, k: float) -> void:
	if s.wet:
		return
	match String(s.kind):
		"firework":
			_credit("firework", pop_radius(s.p, P.burst * k))
			bloom(s.p)
		"rocket":
			_credit("rocket", pop_radius(s.p, P.burst * k))
			explosion(s.p)
		"glob":
			var n: Vector3 = s.n
			pop_radius(s.p, P.splat * k)
			splat(s.p, n)  # a burst of jelly drops, no puddle left behind (owner's call)
		"dallah":
			for i in 6:
				var d := cone_dir(Vector3.UP, 1.1, i * TAU / 6.0)
				_add_shot("bean", SHOT_STYLE.bean, s.p, d, k, i)
			impact(s.p, Vector3.UP, Color("dcaa48"))
			_dallah_sfx("fair_ding", DALLAH_SPILL_K, s.p)
		"boomerang":
			if s.caught:
				host.sfx("thump", 0.25, s.p)
				host.buzz(String(s.hand), 0.35, 30)
				# Back in the hand after hitting something: toward boomerang3.
				var rt = host.get("runtime")
				if (int(s.pops) > 0 or not (s.hits as Dictionary).is_empty()) and rt != null and rt.has_method("ch_add"):
					rt.ch_add("boomerang3")


func step_blast(dt: float) -> void:
	clock += dt
	var k := blast_k()
	if shots.is_empty() and sparks.is_empty() and arcs.is_empty():
		_spark_mm.visible_instance_count = 0
		_beam_mm.visible_instance_count = 0
		_draw_shots()
		return
	var hk: float = host.scale_now
	var G := REAL_G * k
	var BR := Ball.BR
	var park = host.park
	var stage: Node3D = host.stage
	var i := shots.size() - 1
	while i >= 0:
		if i >= shots.size():
			i = shots.size() - 1
			continue
		var s: Dictionary = shots[i]
		var P: Dictionary = SHOT_STYLE[s.kind]
		# The court was zoomed since the last step: the shot keeps its size and speed on the court.
		if absf(float(s.k) - k) > 1e-6:
			var ratio: float = k / float(s.k)
			s.v *= ratio
			s.r *= ratio
			s.k = k
			if s.node:
				(s.node as Node3D).scale *= ratio
		var R: float = s.r
		s.t += dt
		s.spin += dt * (9.0 if s.kind == "mini" else (BOOMERANG_SPIN if s.kind == "boomerang" else (14.0 if s.kind == "dallah" else 1.2)))
		var a: Vector3 = s.p
		_move(s, P, dt, k)
		var seg: Vector3 = s.p - a
		var len := seg.length()
		var dir_n := seg / len if len > 0.0 else seg
		var near_seg := func(p: Vector3, rr: float) -> bool:
			var t := clampf((p - a).dot(seg) / (len * len if len > 0.0 else 1.0), 0.0, 1.0)
			return (a + seg * t).distance_to(p) < rr + R
		var done: bool = s.caught
		var popped_n := 0
		# Dahroojs it reaches pop.
		for j in range(rests.size() - 1, -1, -1):
			if near_seg.call(rests[j].p, BR):
				burst(rests[j].p, rests[j].style)
				_drop_rest(j)
				popped_n += 1
		for j in range(ball.volley.size() - 1, -1, -1):
			if near_seg.call(ball.volley[j].pos, BR):
				burst(ball.volley[j].pos, Save.style)
				ball.volley.remove_at(j)
				popped_n += 1
		var intro = host.get("intro")
		if intro and intro.active and intro.pop_along(to_global(a), to_global(s.p), R / hk):
			popped_n += 1
		if ball.shot and not ball.held and near_seg.call(ball.pos, BR):
			burst(ball.pos, Save.style)
			host.ball_popped()
			popped_n += 1
		# The Golden Dahrooj: any shot that reaches him catches him.
		var gold := golden()
		if gold != null and near_seg.call(gold.pos, gold.radius() * 1.15):
			if hit_target({"kind": "g", "ref": gold, "p": gold.pos}, dir_n):
				popped_n += 1
		# A rocket goes off right by its target.
		if s.kind == "rocket" and not done:
			var tp = target_at(s.target)
			if tp != null and (tp as Vector3).distance_to(s.p) < R + BR * 0.8:
				done = true
		if popped_n > 0:
			_credit(String(s.kind), popped_n)
		if popped_n > 0 and not done:
			done = _on_pop(s, P, popped_n)
		# The pond: a bolt plunges in, a mini or bouncy ball skips off the surface while fast
		# and low, else sinks; a bubble settles on the water and pops; a firework fizzles.
		if not done and s.kind != "boomerang" and host.nature_on() and s.p.y < R * 1.05 and a.y >= R * 0.5 and park.depth(s.p.x, s.p.z) > 0.0:
			var hs := Vector2(s.v.x, s.v.z).length()
			var vs: float = -s.v.y
			if (s.kind == "mini" or s.kind == "bouncy") and hs > 2.2 * k and vs < hs * 0.7 and s.skips < 4:
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
				var big: bool = s.kind in ["firework", "rocket", "glob", "dallah"]
				_park_splash(s.p, 0.6 if big else (0.35 if s.kind == "mini" else 0.25))
				host.sfx("splash", 0.5 if big else 0.25, s.p)
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
			# A boomerang going through a target hits it once on the way out and once back.
			var skip: Array = []
			for node in (s.hits as Dictionary).keys():
				if is_instance_valid(node) and float(s.t) - float(s.hits[node]) < 0.3:
					skip.append(node)
			var hit := ray_stage(stage, a, dir_n, len + R, skip)
			if not hit.is_empty():
				var n: Vector3 = hit.normal
				var took: bool = stage.has_method("shoot") and stage.shoot(hit.node, hit.point, dir_n)
				impact(hit.point, n, Color("ffd27a") if took else Color("fffaf2"))
				if took:
					s.hits[hit.node] = s.t
					_credit(String(s.kind), 1)
				elif s.kind == "bean":
					_dallah_sfx("thump", 0.25, hit.point, BEAN_THUMP_GAP)
				elif s.kind != "bouncy":
					host.sfx("thump", 0.25, hit.point)
				done = _on_solid(s, P, hit.point, n, took)
		# The world's props (crates go off), the walls of your room, and the floor.
		if not done and host.nature_on() and park.has_method("collide"):
			var res: Dictionary = park.collide(s.p, s.v, R)
			if res.hit:
				if s.kind == "mini" or s.kind == "bouncy":
					s.p = res.p
					s.v = res.v
					if s.kind == "bouncy":
						s.bounces += 1
						host.sfx("bricks_tink", 0.75, s.p)
						done = s.bounces > int(P.bounces)
				elif s.kind == "boomerang":
					s.ret = true
				else:
					impact(res.p, -dir_n)
					done = _on_solid(s, P, res.p, -dir_n, false)
		# Mixed reality: the real walls and furniture (main.gd room_hit, game units; xr-runtime.js).
		if not done and host.has_method("room_hit") and host.room_active():
			var rh: Dictionary = host.room_hit(s.p, s.v, a, R)
			if float(rh.hit) > 0.0:
				if s.kind == "mini" or s.kind == "bouncy":
					s.p = rh.p
					s.v = rh.v * (1.25 if s.kind == "bouncy" else 1.0)
					if float(rh.hit) > 1.5 * hk and s.t - s.tap > 0.15:
						s.tap = s.t
						host.sfx("bricks_tink" if s.kind == "bouncy" else "thump", 0.15 if s.kind == "mini" else 0.75, s.p)
						if s.kind == "bouncy":
							s.bounces += 1
							done = s.bounces > int(P.bounces)
				elif s.kind == "boomerang":
					s.ret = true
				else:
					impact(s.p, -dir_n)
					var wn: Vector3 = ((rh.p as Vector3) - s.p).normalized() if (rh.p as Vector3).distance_to(s.p) > 1e-6 else -dir_n
					done = _on_solid(s, P, rh.p, wn, false)
		# A bouncy ball too far from you (no wall out there) turns back your way.
		if not done and s.kind == "bouncy":
			var eye: Vector3 = host.eye_game()
			var off := Vector2(s.p.x - eye.x, s.p.z - eye.z)
			var roam: float = BOUNCY_ROAM * float(host.scale_now)
			if off.length() > roam and Vector2(s.v.x, s.v.z).dot(off) > 0.0:
				var nrm := off.normalized()
				var fv := Vector2(s.v.x, s.v.z)
				fv -= nrm * 2.0 * fv.dot(nrm)
				s.v.x = fv.x
				s.v.z = fv.y
		# The floor: the room's floor during the opening and the rain, the court's ground otherwise.
		var floor_y := _floor_y()
		if not done and s.p.y < floor_y + R:
			match String(s.kind):
				"mini":
					s.p.y = floor_y + R
					if s.v.y < -0.8 * k:
						s.v.y *= -0.45
					else:
						s.v.y = 0.0
					var f := pow(0.55, dt)
					s.v.x *= f
					s.v.z *= f
				"bouncy":
					# It never settles: every bounce at least BOUNCY_HOP high, on along the floor.
					s.p.y = floor_y + R
					if s.v.y < 0.0:
						var up: float = maxf(-s.v.y * 0.8, BOUNCY_HOP * k)
						host.sfx("bricks_tink", clampf(-s.v.y / (8.0 * k), 0.0, 1.0), s.p)
						s.v.y = up
						s.bounces += 1
					var flat := Vector2(s.v.x, s.v.z)
					if flat.length() < BOUNCY_ROLL * k:
						flat = (flat.normalized() if flat.length() > 1e-4 else Vector2(rnd() - 0.5, rnd() - 0.5).normalized()) * BOUNCY_ROLL * k
						s.v.x = flat.x
						s.v.z = flat.y
				"boomerang":
					s.p.y = floor_y + R
					s.ret = true
				_:
					s.p.y = floor_y
					s.n = Vector3.UP
					impact(s.p, Vector3.UP)
					done = true
		if not done:
			_trail(s, k, dt)
		if s.node:
			var nd: Node3D = s.node
			nd.position = s.p
			match String(s.kind):
				"rocket":
					var v: Vector3 = s.v
					if v.length_squared() > 1e-10:
						nd.basis = Basis.looking_at(v.normalized(), Vector3.UP if absf(v.normalized().y) < 0.999 else Vector3.RIGHT).scaled(nd.basis.get_scale())
					var fl := nd.get_node_or_null("Flame") as Node3D
					if fl:
						fl.scale = Vector3.ONE * (0.8 + rnd() * 0.5)
				"boomerang":
					_boomerang_pose(s, nd, dt)
				"dallah":
					var sp := nd.get_node_or_null("Spin") as Node3D
					if sp:
						sp.rotation = Vector3(float(s.spin) * 0.6, 0.4, float(s.spin) * 0.25)
				"glob":
					var bl := nd.get_node_or_null("Blob") as Node3D
					if bl:
						var w := sin(float(s.t) * 18.0) * 0.12
						bl.scale = Vector3(1.0 + w, 1.0 - w, 1.0 + w * 0.5)
		var life: float = P.life + (2.0 if s.ret else 0.0)
		var expired: bool = s.t > life and s.float < 0.0
		if done or expired:
			if s.kind in ["firework", "rocket", "glob", "dallah"] or s.caught:
				_finish(s, P, k)
			if s.kind == "bubble" and not done:
				host.sfx("start_pop", 1.0, s.p)
			if s.node:
				s.node.queue_free()
			var at := _index_of(shots, s)
			if at >= 0:
				shots.remove_at(at)
		i -= 1
	_draw_shots()
	var n := 0
	for j in range(sparks.size() - 1, -1, -1):
		var s: Dictionary = sparks[j]
		if absf(float(s.k) - k) > 1e-6:
			var ratio: float = k / float(s.k)
			s.v *= ratio
			s.size *= ratio
			s.k = k
		s.t += dt
		if s.flake:
			# Confetti flutters down slowly.
			s.v.y -= G * 0.25 * dt
			s.v *= pow(0.25, dt)
		elif not s.flash:
			s.v.y -= G * 0.5 * dt
		s.p += s.v * dt
		if s.t >= s.max:
			sparks.remove_at(j)
	for s in sparks:
		var b := Basis().scaled(Vector3.ONE * s.size)
		if s.flake:
			b = Basis(s.axis as Vector3, float(s.rot) + float(s.t) * 9.0) * Basis.from_scale(Vector3(s.size, s.size * 0.18, s.size * 0.7))
		_spark_mm.set_instance_transform(n, Transform3D(b, s.p))
		_spark_mm.set_instance_color(n, Color(s.color, (s.color as Color).a * (1.0 - s.t / s.max)))
		n += 1
	# The round shots, drawn with the sparks: a highlight on each.
	for s in shots:
		if s.node != null or s.style != "" or n >= SPARKS_MAX + SHOTS_MAX:
			continue
		var c: Color = s.color
		_spark_mm.set_instance_transform(n, Transform3D(Basis().scaled(Vector3.ONE * float(s.r)), s.p))
		_spark_mm.set_instance_color(n, c)
		n += 1
	_spark_mm.visible_instance_count = n
	_draw_arcs(dt, k)


func _park_splash(p: Vector3, k: float) -> void:
	if host.park.has_method("splash"):
		host.park.splash(p.x, p.z, k)


func clear_blast() -> void:
	for s in shots:
		if s.node:
			s.node.queue_free()
	shots.clear()
	sparks.clear()
	arcs.clear()
	_spark_mm.visible_instance_count = 0
	_beam_mm.visible_instance_count = 0
	_draw_shots()


## The first solid stage mesh along a ray (game units): {node, point, normal} or {}.
## The stages' guide lines on the ground and the nets don't stop a shot; nor do the
## meshes in `exclude` (a beam already went through them).
## Whether a mesh belongs to a JuiceText (up to the stage).
static func _in_text(n: Node, stop: Node) -> bool:
	while n != null and n != stop:
		if n is JuiceText:
			return true
		n = n.get_parent()
	return false


func ray_stage(stage: Node3D, from: Vector3, dir: Vector3, far: float, exclude: Array = []) -> Dictionary:
	var best := {}
	var best_d := far
	var to_root: Transform3D = global_transform.affine_inverse()
	for mi in stage.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree() or exclude.has(m):
			continue
		var mat := m.material_override
		if mat == StageArt.line_mat() or mat == StageArt.net_mat() or m.mesh is ImmediateMesh:
			continue
		# Floating texts (banners, points, combos) are pictures, not things: shots fly through.
		if _in_text(m, stage):
			continue
		# Ray into the mesh's space.
		var xf: Transform3D = to_root * m.global_transform
		var inv := xf.affine_inverse()
		var lo := inv * from
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
