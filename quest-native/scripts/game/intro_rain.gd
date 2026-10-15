class_name IntroRain
extends Node3D
## The opening and Dahrooj Rain (src/reference/xr-runtime.js beginIntro..drawIntro,
## rain-field.ts): Dahrooj balls rain all around you, bounce, wander and hop on the
## floor and push each other apart; the trigger pops them; after 3.2 s a start button
## shows, low and to the side. Rain (begin(true)) is the same as a mode of its own: no
## start button, it never stops, the balls fall in front of you and refill as they pop,
## and two that meet hard pop each other.
##
## Lives at the XR origin: room metres, y = 0 is the floor. Every ball is drawn by one
## Crowd (a handful of instanced draws).
##
## Per frame: step(dt, camera.global_transform). Shots: pop_along() / pop_near(); the
## homing and chaining shots (WorldBalls.targets) aim at target_drops() and pop one with
## pop_ball().
##
## Rain as a mode (main.gd _place_rain): pinned like the other modes' courts. Main sets this
## node's transform (the pinned spot on the floor, turned the way the court faces, scaled by
## the MR zoom) and `pinned`: the drops then fall in the fan ahead of a fixed point pin_back
## behind that spot (VR: where the player stood; MR: 1.6 m before the pin), not ahead of
## wherever the head turns. The opening is never pinned.
## Callbacks (set by main; any may stay empty): sfx(name, k, pos_world),
## buzz(hand, amp, ms), ch_add(id), sky_pop(pos_world).

signal cleared

const INTRO_R := 0.11
## The opening and the rain show every look: all the styles, all the accessories.
const INTRO_STYLES := DahroojLooks.STYLES
const CROWD_MAX := 120
const REAL_G := 9.8
const SPARKS_MAX := 80
## appearance.ts JELLY_COLORS: the rain's seven colours.
const JELLY_COLORS := ["ff69b4", "ff505c", "ff9b3d", "ffdf45", "58db83", "58b9ff", "b878ff"]
const START_W := 0.56
const START_H := 0.35


class Drop:
	extends RefCounted
	var id := 0
	var style := "jelly"
	var R := INTRO_R
	var accessory := ""
	var color = null  # sRGB hex string, or null for the style's own
	var p := Vector3.ZERO
	var v := Vector3.ZERO
	var pending := false
	var born := 0.0
	var gx := 0.0
	var gz := 0.0
	var hop := 0.0
	var d := 0.0
	var dv := 0.0
	var hit := 0.0
	var blink := 0.0
	var next := 0.0
	var popped := false


class Spark:
	extends RefCounted
	var p := Vector3.ZERO
	var v := Vector3.ZERO
	var t := 0.0
	var max_t := 0.5
	var size := 0.015
	var color := Color.WHITE


var sfx: Callable
var buzz: Callable
var ch_add: Callable
var sky_pop: Callable
## The hand to buzz when the player pops a ball (main sets it to the hand that last fired).
var shot_hand := "left"
## Mixed reality: a smaller crowd in a smaller ring (72 within 2.6 m; VR 100 within 4.4 m).
var mixed := false
## Dahrooj Rain only: new drops' size × this (main sets it so mixed reality's rain matches the
## Dahrooj you throw there; 1 in VR).
var drop_k := 1.0
## The start button also shows 3.2 s of wall-clock time after the first spawn (as the original).
var use_wall_clock := true
var rng := RandomNumberGenerator.new()
## Rain pinned to this node's frame (see above), and how far behind its origin (local
## metres, +z) the fan's viewpoint stands.
var pinned := false
var pin_back := 0.0

var crowd: Crowd
var _accessories: Array[String] = []  # every accessory, for the crowd to wear
var start_panel: Node3D
var active := false  # the original's `intro != null`
var rain := false
var balls: Array[Drop] = []
var sparks: Array[Spark] = []
var popped := 0
var start_ready := false  # the original's intro.ready (`ready` is Node's signal)
var leaving := 0.0
var t := 0.0
var frames := 0
var spawned := false
var gap := 0.0
var centre := Vector3.ZERO
var has_centre := false
var wall := 0
var clock := 0.0

var _ids := 0
var _next_ambient_pop := 0.0
var _spark_mm: MultiMesh
var _start_hot := ""  # the item the ray is on: "play", "mr", "vr", "lang" or ""
var _hit_seen := false
var _start_key := ""
var _start_vp: SubViewport
var _start_sheet: MenuPanel.Sheet
## The line under the button ("Popped 3" / the hint), as last drawn.
var start_line := ""
## The start panel's labels of the last paint (see Glass.text) for the tests.
var start_texts: Array = []


func _init() -> void:
	name = "IntroRain"
	rng.randomize()
	crowd = Crowd.new(CROWD_MAX, true)
	for id: String in DahroojLooks.ACCESSORIES:
		if id != "":
			_accessories.append(id)
			crowd.prepare(id)
	crowd.name = "Crowd"
	add_child(crowd)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Sparks"
	_spark_mm = MultiMesh.new()
	_spark_mm.transform_format = MultiMesh.TRANSFORM_3D
	_spark_mm.use_colors = true
	_spark_mm.mesh = Crowd.merge([[Crowd.sphere(1.0, 8, 6), Transform3D.IDENTITY, Color.WHITE]])
	_spark_mm.instance_count = SPARKS_MAX
	_spark_mm.visible_instance_count = 0
	mmi.multimesh = _spark_mm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-40, -20, -40), Vector3(80, 60, 80))
	add_child(mmi)
	_build_start()


# --- the original's functions --------------------------------------------------------------

## How many and how far: the room in mixed reality, a wider ring in the open VR world.
func crowd_size() -> Vector2:
	return Vector2(72, 2.6) if mixed else Vector2(100, 4.4)


## beginIntro(rain). Main hides the stage (and, for rain, drops the held ball).
func begin(rain_mode := false, mixed_reality := mixed) -> void:
	mixed = mixed_reality
	_clear_sparks()
	active = true
	t = 0.0
	frames = 0
	balls = []
	start_ready = false
	leaving = 0.0
	popped = 0
	spawned = false
	gap = 0.0
	rain = rain_mode
	has_centre = false
	wall = 0
	start_panel.visible = false


## Rain falls in front; the separate opening keeps its original ring.
func drop_ball(delay: float) -> void:
	var R := crowd_size().y
	var c := centre
	var a := rng.randf() * TAU
	var dist := 0.55 + sqrt(rng.randf()) * (R - 0.55)
	var raw := INTRO_R * (0.75 + rng.randf() * 0.5)
	var rad := INTRO_R + (raw - INTRO_R) * 0.5 if rain and raw > INTRO_R else raw
	var sp := 0.2 + rng.randf() * 0.5
	var dir_a := rng.randf() * TAU
	var b := Drop.new()
	# Pick once per spawn; cosmetics never change the player's unlocks or add physics bodies.
	b.accessory = _accessories[int(rng.randf() * _accessories.size())]
	_ids += 1
	b.id = _ids
	b.style = INTRO_STYLES[int(rng.randf() * INTRO_STYLES.size())]
	b.R = rad * (drop_k if rain else 1.0)
	b.color = JELLY_COLORS[_ids % JELLY_COLORS.size()] if b.style in DahroojLooks.TINTED and (rain or rng.randf() < 0.5) else null
	b.p = Vector3(c.x + sin(a) * dist, c.y + 0.6 + rng.randf() * 1.8, c.z - cos(a) * dist)
	b.pending = rain
	b.born = t + delay
	b.gx = cos(dir_a) * sp
	b.gz = sin(dir_a) * sp
	b.hop = 0.5 + rng.randf() * 2.5
	b.next = 1.0 + rng.randf() * 3.0
	balls.append(b)


func _spawn(head_pos: Vector3) -> void:
	spawned = true
	gap = 0.0
	if wall == 0:
		wall = Time.get_ticks_msec()
	if not has_centre:
		centre = head_pos
		has_centre = true
	# They come down over a few seconds, not all at once.
	for i in int(crowd_size().x):
		drop_ball(rng.randf() * 2.6)


## endIntro: the start button was pressed. The balls shrink away over .35 s. Main then
## respawns the game ball, shows the stage (and enters placing in MR). False if it did nothing.
func end_intro() -> bool:
	if not active or leaving > 0.0 or rain:
		return false
	leaving = 0.001
	start_panel.visible = false
	_clear_sparks()
	return true


## clearIntro: gone at once (also at the end of leaving). Main shows the stage again.
func clear() -> void:
	if not active:
		return
	_clear_sparks()
	active = false
	balls = []
	crowd.begin()
	crowd.end()
	start_panel.visible = false
	cleared.emit()


## setRain(on), the part that is the opening's.
func set_rain(on: bool) -> void:
	if on:
		clear()
		begin(true)
	elif active and rain:
		clear()


func pop_ball(b: Drop, by_player := true) -> void:
	if not active or b.popped:
		return
	var index := balls.find(b)
	if index < 0:
		return
	b.popped = true
	var at := _world() * b.p
	if by_player:
		if sky_pop.is_valid():
			sky_pop.call(at)
		popped += 1
	balls.remove_at(index)
	var col := Color(Crowd.DAHROOJ_COLORS[b.style]).srgb_to_linear()
	var k := 0
	while k < (10 if by_player else 4) and sparks.size() < SPARKS_MAX:
		var s := Spark.new()
		s.color = col if k % 3 else Color("fffaf2").srgb_to_linear()
		s.size = 0.012 + rng.randf() * 0.01
		var a := rng.randf() * TAU
		var e := rng.randf() * PI - PI / 2
		var v := 1.0 + rng.randf() * 1.6
		s.p = b.p
		s.v = Vector3(cos(a) * cos(e) * v, sin(e) * v + 1.0, sin(a) * cos(e) * v)
		s.max_t = 0.45 + rng.randf() * 0.3
		sparks.append(s)
		k += 1
	if by_player or clock >= _next_ambient_pop:
		if sfx.is_valid():
			sfx.call("start_pop", 1.0, at)
		_next_ambient_pop = clock + 0.12
	if by_player:
		if buzz.is_valid():
			buzz.call(shot_hand, 0.35, 40.0)
		if ch_add.is_valid():
			ch_add.call("pop20")
	# Environmental impacts leave a visible gap instead of immediately filling the crowd again.
	if rain:
		drop_ball(0.3 + rng.randf() * 1.5 if by_player else 4.0 + rng.randf() * 4.0)


## Room physics in metres: gravity, the floor, wandering and hopping, and the balls pushing
## each other. head: the headset's global transform. Draws the crowd too (drawIntro).
func step(dt: float, head: Transform3D) -> void:
	if not active:
		return
	clock += dt
	if not _hit_seen and _start_hot != "":
		_set_hot("")
	_hit_seen = false
	var hl := _head_local(head)
	var hpos: Vector3 = hl[0]
	var dir: Vector3 = hl[1]
	# Where the rain's fan is measured from: the head, or (pinned) a fixed spot facing -z.
	var fan := hpos
	var fan_dir := dir
	if rain and pinned:
		fan = Vector3(0.0, hpos.y, pin_back)
		fan_dir = Vector3(0, 0, -1)
	if leaving > 0.0:
		leaving += dt
		if leaving >= 0.35:
			clear()
			return
		_draw(hpos)
		return
	if not spawned:
		frames += 1
		if frames >= 3:
			_spawn(hpos)
		_draw(hpos)
		return
	t += dt
	# All popped: a new wave a moment later (the rain tops itself up as it goes).
	if balls.is_empty():
		gap += dt
		if gap > 1.0:
			_spawn(hpos)
	var size := crowd_size()
	if rain:
		while balls.size() < int(size.x):
			drop_ball(rng.randf() * 2.0)
	var ROOM := size.y
	var c := centre
	var live: Array[Drop] = []
	for b in balls:
		if t >= b.born:
			live.append(b)
	for b in live:
		if b.pending:
			b.p = rain_spawn(b.p, fan, fan_dir, ROOM, rng.randf(), rng.randf())
			b.p.y = hpos.y + 0.6 + rng.randf() * 1.8
			b.pending = false
		var r := b.R
		var grounded := b.p.y <= r + 0.001 and absf(b.v.y) < 0.01
		b.v.y -= REAL_G * dt
		if grounded:
			b.v.x += (b.gx - b.v.x) * minf(1.0, dt * 2.0)
			b.v.z += (b.gz - b.v.z) * minf(1.0, dt * 2.0)
			b.hop -= dt
			if b.hop <= 0.0:
				b.v.y = 1.6 + rng.randf() * 1.6
				b.hop = 1.0 + rng.randf() * 2.5
				b.dv -= 3.0
				if rng.randf() < 0.5:
					var a := rng.randf() * TAU
					var sp := 0.2 + rng.randf() * 0.5
					b.gx = cos(a) * sp
					b.gz = sin(a) * sp
		b.p += b.v * dt
		if b.p.y < r:
			var sp := -b.v.y
			b.p.y = r
			if sp > 0.6:
				b.v.y = sp * 0.5
				b.dv -= sp * 2.2
				b.hit = 0.2
				if sp > 2.0 and sfx.is_valid() and rng.randf() < 0.35:
					sfx.call("thump", minf(1.0, sp / 6.0) * 0.4, _world() * b.p)
			else:
				b.v.y = 0.0
		if rain:
			# Keep most of the crowd ahead while allowing gentle sideways wandering and physical bounces.
			guide_rain(b, fan, fan_dir, ROOM)
		else:
			var ox := b.p.x - c.x
			var oz := b.p.z - c.z
			var od := Vector2(ox, oz).length()
			if od == 0.0:
				od = 1.0
			var hd := Vector2(b.p.x - hpos.x, b.p.z - hpos.z).length()
			if od > ROOM or hd < 0.45:
				var a := rng.randf() * TAU
				var rr := 0.7 + sqrt(rng.randf()) * (ROOM - 0.9)
				var sp := 0.25 + rng.randf() * 0.4
				var tx := c.x + sin(a) * rr - b.p.x
				var tz := c.z - cos(a) * rr - b.p.z
				var tl := Vector2(tx, tz).length()
				if tl == 0.0:
					tl = 1.0
				b.gx = tx / tl * sp
				b.gz = tz / tl * sp
			if od > ROOM + 0.4:
				b.p.x = c.x + ox / od * (ROOM + 0.4)
				b.p.z = c.z + oz / od * (ROOM + 0.4)
		b.dv += (-b.d * 320.0 - b.dv * 12.0) * dt
		b.d = clampf(b.d + b.dv * dt, -0.3, 0.45)
		b.hit = maxf(0.0, b.hit - dt)
		b.next -= dt
		if b.next <= 0.0:
			b.blink = 0.14
			b.next = 2.0 + rng.randf() * 3.0
		b.blink = maxf(0.0, b.blink - dt)
	_push_apart(live, dt)
	_step_sparks(dt)
	if not rain and not start_ready and (t > 3.2 or (use_wall_clock and Time.get_ticks_msec() - wall > 3200)):
		# In the middle of your view, a little below eye level; it then follows your head.
		start_ready = true
		start_panel.position = _start_spot(hpos, dir)
		start_panel.visible = true
	if start_ready and start_panel.visible:
		# Follows the head gently (turn and it glides back in front of you).
		start_panel.position = start_panel.position.lerp(_start_spot(hpos, dir), 1.0 - exp(-dt * START_FOLLOW))
		var d := hpos - start_panel.position
		if d.length_squared() > 1e-8:
			var dn := d.normalized()
			start_panel.basis = Basis.looking_at(dn, Vector3.UP if absf(dn.y) < 0.9999 else Vector3.BACK, true) * Basis.from_scale(Vector3.ONE * 0.85)
		_refresh_start()
	_draw(hpos)


## Pushing apart, on a coarse grid so a big crowd stays cheap. In the rain, two that meet
## hard (closing at 2.4 m/s or more) pop each other.
func _push_apart(live: Array[Drop], dt: float) -> void:
	var cell := {}
	for b in live:
		var k := Vector2i(floori(b.p.x / 0.3), floori(b.p.z / 0.3))
		if not cell.has(k):
			cell[k] = []
		(cell[k] as Array).append(b)
	for a in live:
		var gx := floori(a.p.x / 0.3)
		var gz := floori(a.p.z / 0.3)
		for ix in range(-1, 2):
			for iz in range(-1, 2):
				var l: Array = cell.get(Vector2i(gx + ix, gz + iz), [])
				for o in l:
					var b: Drop = o
					if b == a or a.id > b.id or a.popped or b.popped:
						continue
					if rain and WorldBalls.impact_speed(a.p, a.v, b.p, b.v, a.R + b.R, dt) >= 2.4:
						pop_ball(a, false)
						pop_ball(b, false)
						continue
					var n := b.p - a.p
					var len := n.length()
					var mn := a.R + b.R
					if not (len > 0.0 and len < mn):
						continue
					n /= len
					var push := (mn - len) / 2.0
					a.p -= n * push
					b.p += n * push
					var rv := (b.v - a.v).dot(n)
					if rv < 0.0:
						a.v += n * rv * 0.8
						b.v -= n * rv * 0.8


func _step_sparks(dt: float) -> void:
	for k in range(sparks.size() - 1, -1, -1):
		var s := sparks[k]
		s.t += dt
		s.v.y -= REAL_G * 0.5 * dt
		s.p += s.v * dt
		if s.t >= s.max_t:
			sparks.remove_at(k)
	var n := 0
	for s in sparks:
		_spark_mm.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3.ONE * s.size), s.p))
		_spark_mm.set_instance_color(n, Color(s.color, 1.0 - s.t / s.max_t))
		n += 1
	_spark_mm.visible_instance_count = n


func _clear_sparks() -> void:
	sparks.clear()
	_spark_mm.visible_instance_count = 0


## drawIntro: every ball that has come down, facing you; squashed as it lands, eyes shut
## when hit or blinking, wide while falling; shrinking away while leaving.
func _draw(eye: Vector3) -> void:
	var k := maxf(0.001, 1.0 - leaving / 0.35) if leaving > 0.0 else 1.0
	crowd.begin()
	for b in balls:
		if t < b.born or b.pending:
			continue
		var falling := b.p.y > b.R + 0.02 and b.v.y < -1.5
		var face := "shut" if b.hit > 0.0 or b.blink > 0.0 else ("wide" if falling else "open")
		crowd.add(b.style, Vector3(b.p.x, b.p.y - b.R * maxf(0.0, b.d), b.p.z), b.R * k, eye,
			Vector2(1.0 + b.d * 0.75, 1.0 - b.d), face, b.accessory, b.color)
	crowd.end()


# --- rain-field.ts ---------------------------------------------------------------------------

## Sample an even-area, 128-degree fan in front of the current horizontal headset pose (x, z).
static func rain_spawn(out: Vector3, head: Vector3, forward: Vector3, radius: float, angle_sample: float, distance_sample: float) -> Vector3:
	var angle := (angle_sample - 0.5) * 2.24
	var near := 1.0
	var distance := sqrt(near * near + distance_sample * (radius * radius - near * near))
	var ahead := cos(angle) * distance
	var side := sin(angle) * distance
	out.x = head.x + forward.x * ahead - forward.z * side
	out.z = head.z + forward.z * ahead + forward.x * side
	return out


## A soft return: change the wandering target velocity, never teleport a visible ball.
static func guide_rain(b: Drop, head: Vector3, forward: Vector3, radius: float) -> void:
	var x := b.p.x - head.x
	var z := b.p.z - head.z
	var ahead := x * forward.x + z * forward.z
	var side := -x * forward.z + z * forward.x
	if ahead >= 0.6 and ahead <= radius + 0.3 and absf(side) <= radius + 0.25:
		return
	var target_ahead := maxf(1.15, minf(radius - 0.15, ahead))
	var target_side := maxf(-radius * 0.85, minf(radius * 0.85, side))
	var da := target_ahead - ahead
	var ds := target_side - side
	var length := Vector2(da, ds).length()
	if length < 1e-6:
		return
	var speed := 0.65 / length
	b.gx = (forward.x * da - forward.z * ds) * speed
	b.gz = (forward.z * da + forward.x * ds) * speed


# --- shots (the blaster in world_balls.gd) --------------------------------------------------

## A shot's stretch of flight this frame, a -> b (global), of radius r (global units): pops
## every ball it reaches (by the player). True if any popped.
func pop_along(a_world: Vector3, b_world: Vector3, r_world: float) -> bool:
	if not active or leaving > 0.0:
		return false
	var w := _world()
	var k := w.basis.get_scale().x
	var seg := b_world - a_world
	var len2 := seg.length_squared()
	var any := false
	for b: Drop in balls.duplicate():
		if t < b.born:
			continue
		var p := w * b.p
		var u := clampf((p - a_world).dot(seg) / (len2 if len2 > 0.0 else 1.0), 0.0, 1.0)
		if (a_world + seg * u).distance_to(p) < b.R * k + r_world:
			pop_ball(b)
			any = true
	return any


## A burst (a firework's) at p of the given reach (global units): pops every ball it
## touches. Returns how many.
func pop_near(p_world: Vector3, radius_world: float, by_player := true) -> int:
	if not active or leaving > 0.0:
		return 0
	var w := _world()
	var k := w.basis.get_scale().x
	var n := 0
	for b: Drop in balls.duplicate():
		if t < b.born:
			continue
		if (w * b.p).distance_to(p_world) < radius_world + b.R * k:
			pop_ball(b, by_player)
			n += 1
	return n


## The drops a homing or chaining shot can go for: come down, drawn and not popped.
func target_drops() -> Array[Drop]:
	var out: Array[Drop] = []
	if not active or leaving > 0.0:
		return out
	for b in balls:
		if t >= b.born and not b.pending and not b.popped:
			out.append(b)
	return out


## Whether a drop is still there to hit.
func has_drop(b: Drop) -> bool:
	return active and leaving <= 0.0 and b != null and not b.popped and balls.has(b)


## A drop's centre (global).
func drop_world(b: Drop) -> Vector3:
	return _world() * b.p


## A drop's radius (global units).
func drop_radius_world(b: Drop) -> float:
	return b.R * _world().basis.get_scale().x


## Balls that have come down (and are drawn).
func live_count() -> int:
	var n := 0
	for b in balls:
		if t >= b.born and not b.pending:
			n += 1
	return n


# --- the start button ------------------------------------------------------------------------

func _world() -> Transform3D:
	return global_transform if is_inside_tree() else transform


## [head position, horizontal forward] in this node's space.
## Where the start panel wants to be: straight ahead of the head, just below eye level.
func _start_spot(hpos: Vector3, dir: Vector3) -> Vector3:
	return hpos + dir * START_AHEAD + Vector3.DOWN * START_DROP


func _head_local(head: Transform3D) -> Array:
	var l := _world().affine_inverse() * head
	var d := -l.basis.z
	d.y = 0.0
	d = d.normalized() if d.length_squared() > 1e-6 else Vector3(0, 0, -1)
	return [l.origin, d]


const START_PX := Vector2i(1024, 640)
## The start panel: how far ahead and how far below the eyes (m), and how fast it follows.
const START_AHEAD := 0.85
const START_DROP := 0.18
const START_FOLLOW := 2.5
## The start panel's buttons (layout px): mixed reality, VR and the language in a row of
## icons above Play.
const START_ITEMS := {
	"mr": Rect2(232, 150, 170, 120), "vr": Rect2(427, 150, 170, 120), "lang": Rect2(622, 150, 170, 120),
	"play": Rect2(232, 300, 560, 150),
}
## Main: the current view ("mr" / "vr"), shown selected among the icons.
var view_mode := "vr"


## The start panel in the frosted-glass style (Glass): the name, an accent "Play"
## button and a line under it, drawn into a small transparent SubViewport once per
## change and shown on a quad.
func _build_start() -> void:
	start_panel = Node3D.new()
	start_panel.name = "Start"
	start_panel.visible = false
	add_child(start_panel)
	_start_vp = Glass.viewport(START_PX)
	start_panel.add_child(_start_vp)
	_start_sheet = MenuPanel.Sheet.new()
	_start_sheet.paint = _paint_start
	_start_vp.add_child(_start_sheet)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(START_W, START_H)
	mi.mesh = q
	mi.material_override = Glass.material(_start_vp.get_texture(), Vector2(START_PX), 64.0, 2, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	start_panel.add_child(mi)
	_refresh_start()


## drawStart(hot): only when something changed.
func _refresh_start() -> void:
	var key := "%s|%d|%s|%s" % [_start_hot, popped, Save.arabic(), view_mode]
	if key == _start_key:
		return
	_start_key = key
	start_line = (Save.text("فجّرت %d" % popped, "Popped %d" % popped) if popped > 0
		else Save.text("وجّه يدك واضغط الزناد لتفجير الكور", "Aim and pull the trigger to pop the balls"))
	_start_sheet.queue_redraw()
	_start_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


## Paints the start panel (ci null: lays the labels out only): the name, the row of icons
## (mixed reality, VR, the language) and the accent Play button with a line under it.
func _paint_start(ci: CanvasItem) -> void:
	start_texts = []
	Glass.panel(ci, Rect2(Vector2.ZERO, Vector2(START_PX)), 64.0)
	start_texts.append(Glass.text(ci, Save.text("دحروج", "Dahrooj"), 512, 112, 72, Glass.TEXT, 900, "center", Glass.W_TITLE))
	for id: String in ["mr", "vr", "lang"]:
		var r: Rect2 = START_ITEMS[id]
		var on := id == view_mode
		var hot := id == _start_hot
		Glass.card(ci, r, 30, ("selected-hot" if hot else "selected") if on else ("hot" if hot else "rest"))
		var c := r.get_center()
		if id == "lang":
			MenuPanel.lang_icon(ci, c, 82)
		elif ci != null:
			MenuIcons.draw_hi(ci, id, c, 92, Glass.TEXT, Color(Glass.ACCENT, 0.95 if on else 0.55))
	var btn: Rect2 = START_ITEMS.play
	var play_hot := _start_hot == "play"
	Glass.card(ci, btn, 75, "selected-hot" if play_hot else "selected")
	if play_hot and ci != null:
		# The ring of the original's lit button.
		var ring := Glass.rounded(btn.grow(9), 84, 10)
		ring.append(ring[0])
		ci.draw_polyline(ring, Color(0.95, 0.76, 0.31, 0.9), 4.0, true)
	var label := Save.text("بدء اللعبة", "Play")
	var fs := Glass.fit_size(label, 60, 380, Glass.W_TITLE)
	var tw := Glass.width(label, fs, Glass.W_TITLE)
	var gw := 52.0 + 22.0 + tw
	var x0 := 512.0 - gw / 2.0
	var cy := btn.get_center().y
	var tri_x := x0 if not Save.arabic() else x0 + gw - 52.0
	if ci != null:
		var c := Vector2(tri_x + 26.0, cy)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-18, -28), c + Vector2(26, 0), c + Vector2(-18, 28)]), Glass.TEXT)
	var tx := x0 + 74.0 if not Save.arabic() else x0 + tw
	start_texts.append(Glass.text(ci, label, tx, cy + fs * 0.36, fs, Glass.TEXT, 380, "left" if not Save.arabic() else "right", Glass.W_TITLE))
	start_texts.append(Glass.text(ci, start_line, 512, 540, 32, Glass.SUB, 900, "center", Glass.W_BODY))


## Every label the start panel draws (measured, not drawn).
func measure_start() -> Array:
	_paint_start(null)
	return start_texts


func _set_hot(item: String) -> void:
	_start_hot = item
	_refresh_start()


## The controller ray (global) on the start panel: the button it points at ("play", "mr",
## "vr", "lang"), or "" (the panel's empty glass counts as nothing). Lights that button. Call
## it for each hand every frame; main acts on the trigger.
func start_item(origin: Vector3, dir: Vector3) -> String:
	if not active or not start_panel.visible:
		return ""
	var inv := (_world() * start_panel.transform).affine_inverse()
	var o := inv * origin
	var d := inv.basis * dir
	if absf(d.z) < 1e-6:
		return ""
	var u := -o.z / d.z
	if u <= 0.0:
		return ""
	var p := o + d * u
	if absf(p.x) > START_W / 2 or absf(p.y) > START_H / 2:
		return ""
	var px := Vector2((p.x / START_W + 0.5) * START_PX.x, (0.5 - p.y / START_H) * START_PX.y)
	for id: String in START_ITEMS:
		if (START_ITEMS[id] as Rect2).grow(8).has_point(px):
			_hit_seen = true
			if _start_hot != id:
				_set_hot(id)
			return id
	return ""


## Whether the ray is on the Play button.
func start_hit(origin: Vector3, dir: Vector3) -> bool:
	return start_item(origin, dir) == "play"
