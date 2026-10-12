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
## Per frame: step(dt, camera.global_transform). Shots: pop_along() / pop_near().
## Callbacks (set by main; any may stay empty): sfx(name, k, pos_world),
## buzz(hand, amp, ms), ch_add(id), sky_pop(pos_world).

signal cleared

const INTRO_R := 0.11
const INTRO_STYLES := ["jelly", "fur", "bubble"]
const RAIN_ACCESSORIES := ["party", "glasses", "cap", "flower", "crown", "headphones", "scarf"]
const CROWD_MAX := 120
const REAL_G := 9.8
const SPARKS_MAX := 80
## appearance.ts JELLY_COLORS: the rain's seven colours.
const JELLY_COLORS := ["ff69b4", "ff505c", "ff9b3d", "ffdf45", "58db83", "58b9ff", "b878ff"]
const START_W := 0.56
const START_H := 0.28


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
## The start button also shows 3.2 s of wall-clock time after the first spawn (as the original).
var use_wall_clock := true
var rng := RandomNumberGenerator.new()

var crowd: Crowd
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
var _start_hot := false
var _hit_seen := false
var _start_key := ""
var _btn: MeshInstance3D
var _ring: MeshInstance3D
var _title: Label3D
var _play: Label3D
var _line: Label3D


func _init() -> void:
	name = "IntroRain"
	rng.randomize()
	crowd = Crowd.new(CROWD_MAX, true)
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
	b.accessory = RAIN_ACCESSORIES[int(rng.randf() * RAIN_ACCESSORIES.size())] if rain else ""
	_ids += 1
	b.id = _ids
	b.style = INTRO_STYLES[int(rng.randf() * INTRO_STYLES.size())]
	b.R = rad
	b.color = JELLY_COLORS[_ids % JELLY_COLORS.size()] if rain else null
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
	if not _hit_seen and _start_hot:
		_set_hot(false)
	_hit_seen = false
	var hl := _head_local(head)
	var hpos: Vector3 = hl[0]
	var dir: Vector3 = hl[1]
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
			b.p = rain_spawn(b.p, hpos, dir, ROOM, rng.randf(), rng.randf())
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
			guide_rain(b, hpos, dir, ROOM)
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
		# Low and a little to the side, tilted up at you like a lectern, so it never hides the balls you're playing with.
		start_ready = true
		var side := Vector3(-dir.z, 0, dir.x).normalized() * (0.3 if not Save.arabic() else -0.3)
		start_panel.position = Vector3(hpos.x + dir.x * 0.8 + side.x, hpos.y - 0.55, hpos.z + dir.z * 0.8 + side.z)
		start_panel.visible = true
	if start_ready and start_panel.visible:
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
func _head_local(head: Transform3D) -> Array:
	var l := _world().affine_inverse() * head
	var d := -l.basis.z
	d.y = 0.0
	d = d.normalized() if d.length_squared() > 1e-6 else Vector3(0, 0, -1)
	return [l.origin, d]


static func _rounded(w: int, h: int, r: float) -> Texture2D:
	var img := Image.create(w, h, false, Image.FORMAT_LA8)
	for y in h:
		for x in w:
			var dx := maxf(0.0, maxf(r - x - 0.5, x + 0.5 - (w - r)))
			var dy := maxf(0.0, maxf(r - y - 0.5, y + 0.5 - (h - r)))
			img.set_pixel(x, y, Color(1, 1, 1, clampf(r + 0.5 - sqrt(dx * dx + dy * dy), 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func _quad(size: Vector2, color: Color, at: Vector3, priority: int, tex: Texture2D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.albedo_texture = tex
	m.render_priority = priority
	mi.material_override = m
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	start_panel.add_child(mi)
	return mi


## Canvas pixels of the original 1024 x 512 drawing to panel metres.
static func _px(x: float, y: float, z := 0.0) -> Vector3:
	var s := START_W / 1024.0
	return Vector3((x - 512.0) * s, (256.0 - y) * s, z)


func _label(size: int, color: Color, x: float, baseline: float) -> Label3D:
	var l := Panel3D.label("", size, color)
	l.pixel_size = START_W / 1024.0
	l.render_priority = 4
	l.position = _px(x, baseline - size * 0.36, 0.003)
	start_panel.add_child(l)
	return l


## The start panel in the dark menu style: the name, a solid button and a line under it.
func _build_start() -> void:
	start_panel = Node3D.new()
	start_panel.name = "Start"
	start_panel.visible = false
	add_child(start_panel)
	var s := START_W / 1024.0
	_quad(Vector2(START_W, START_H), Panel3D.BG, Vector3.ZERO, 1, _rounded(256, 128, 17.5))
	_title = _label(96, Panel3D.TEXT, 512, 140)
	_quad(Vector2(624, 2) * s, Color(1, 1, 1, 0.12), _px(512, 173, 0.001), 2, null)
	var pill := _rounded(280, 75, 37.5)
	_ring = _quad(Vector2(572, 162) * s, Color(242 / 255.0, 193 / 255.0, 78 / 255.0, 0.9), _px(512, 287, 0.001), 2, _rounded(286, 81, 40.5))
	_ring.visible = false
	_btn = _quad(Vector2(560, 150) * s, Color("3a3c52"), _px(512, 287, 0.002), 3, pill)
	_play = _label(62, Color.WHITE, 540, 306)
	var tri := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in [_px(316, 252, 0.003), _px(368, 287, 0.003), _px(316, 322, 0.003)]:
		st.set_normal(Vector3.BACK)
		st.add_vertex(p)
	tri.mesh = st.commit()
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.albedo_color = Color.WHITE
	tm.render_priority = 4
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	tri.material_override = tm
	tri.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	start_panel.add_child(tri)
	_line = _label(32, Panel3D.SUB, 512, 430)
	_refresh_start()


## drawStart(hot): only when something changed.
func _refresh_start() -> void:
	var key := "%s|%d|%s" % [_start_hot, popped, Save.arabic()]
	if key == _start_key:
		return
	_start_key = key
	_title.text = Save.text("دحروج", "Dahrooj")
	_play.text = Save.text("بدء اللعبة", "Play")
	_line.text = (Save.text("فجّرت %d" % popped, "Popped %d" % popped) if popped > 0
		else Save.text("وجّه يدك واضغط الزناد لتفجير الكور", "Aim and pull the trigger to pop the balls"))
	(_btn.material_override as StandardMaterial3D).albedo_color = Color("4a4d68") if _start_hot else Color("3a3c52")
	_ring.visible = _start_hot


func _set_hot(on: bool) -> void:
	_start_hot = on
	_refresh_start()


## The controller ray (global) on the start panel: true when it points at it (a trigger
## then calls end_intro()); lights the button. Call it for each hand every frame.
func start_hit(origin: Vector3, dir: Vector3) -> bool:
	if not active or not start_panel.visible:
		return false
	var inv := (_world() * start_panel.transform).affine_inverse()
	var o := inv * origin
	var d := inv.basis * dir
	if absf(d.z) < 1e-6:
		return false
	var u := -o.z / d.z
	if u <= 0.0:
		return false
	var p := o + d * u
	if absf(p.x) > START_W / 2 or absf(p.y) > START_H / 2:
		return false
	_hit_seen = true
	if not _start_hot:
		_set_hot(true)
	return true
