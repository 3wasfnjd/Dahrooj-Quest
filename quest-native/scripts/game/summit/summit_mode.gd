class_name SummitMode
extends Node3D
## Summit ("الجبل"): the climb as a model mountain (src/reference/mountain-complete.js,
## driven as xr-runtime.js drives it). The same rules as the phone (SummitCore); this
## node builds and moves the 3D pieces. It lives in world space (metres): VR on the
## goal court where the goal stands, MR on the pinned anchor. One ball radius (one core
## unit) is `unit` metres. The mountain slides down into the surface as Dahrooj climbs:
## its materials are clipped to a window VIEW units tall from the surface up, so he
## stays in view.
##
## For main.gd:
##   set_active(on)          show / hide (starts the climb the first time; keeps progress)
##   set_unit(u), unit       metres per unit (CLIMB_VR in VR, CLIMB_AR in MR; the right stick resizes)
##   set_base(h)             height of the surface above the floor (a stone pedestal shows when > 5 cm)
##   set_dir(x)              the left stick, -1..1
##   jump(), throw_ball()    (jump() restarts after the summit once `again`)
##   update(dt, ctx)         ctx: {style, color, accessory, eye (world), on_event: Callable(e)}
##   hud() -> {hearts, max, height, checkpoint, won, again} (empty when not started)
##   sfx: Callable(name, k, pos_world); game: GameCtx (toasts, counts, challenges)

const CLIMB_VR := 0.14  # xr-runtime.js: metres per unit in the VR world
const CLIMB_AR := CLIMB_VR * 2.0 / 8.0  # MR, until pinning sets it from the surface scale
const UNIT_MIN := 0.012
const UNIT_MAX := 0.2
const GOAL_AIM_Z := -11.3  # court-layout.js GOAL_AIM_Z (GoalStage.AIM_Z)
const WIDTH := 16.25
const VIEW := SummitWorld.VIEW
const BELOW := SummitWorld.BELOW

var unit := CLIMB_VR
var state: Dictionary = {}
var cam := 0.0
var base_height := 0.0
var scaler: Node3D
var world: SummitWorld
var hero: DahroojView
var shot_views: Array[DahroojView] = []
var seed_meshes: Array[MeshInstance3D] = []
var parts: Array = []  # sparks {m, mat, p, v, t, max}
var _spare: Array = []
var pedestal: Node3D
var column: MeshInstance3D
var slab: MeshInstance3D
var shadow: MeshInstance3D
## sfx(name, k, pos_world): GameAudio names (thump, whoosh, start_pop, chime).
var sfx: Callable = func(_n, _k, _p): pass
## The game's ctx (complete-game.js climbEvent: toasts, the climb count, challenges).
var game: GameCtx = null
var events_seen: Array = []  # every event of the last update (tests)


func _init() -> void:
	name = "Summit"
	visible = false
	scaler = Node3D.new()  # one ball radius = 1 inside
	scaler.name = "Scaler"
	add_child(scaler)
	world = SummitWorld.new(WIDTH)  # scrolls down as Dahrooj climbs
	scaler.add_child(world)
	scaler.scale = Vector3.ONE * unit
	hero = DahroojView.new(1.0)
	hero.name = "Hero"
	world.add_child(hero)
	# In VR there is no table, so the model stands on a stone pedestal from the floor.
	pedestal = Node3D.new()
	pedestal.name = "Pedestal"
	add_child(pedestal)
	var col := CylinderMesh.new()
	col.top_radius = 1.0
	col.bottom_radius = 1.15
	col.height = 1.0
	col.radial_segments = 24
	column = _plain(col, Color("9d958c"), 0.9)
	pedestal.add_child(column)
	var sl := CylinderMesh.new()
	sl.top_radius = 1.25
	sl.bottom_radius = 1.25
	sl.height = 1.0
	sl.radial_segments = 24
	slab = _plain(sl, Color("857c73"), 0.85)
	pedestal.add_child(slab)
	shadow = MeshInstance3D.new()
	shadow.mesh = SummitWorld.disc_mesh(1.0, 32)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(Color("2c2d3d"), 0.12)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	shadow.material_override = sm
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)
	set_base(0.0)


static func _plain(m: Mesh, c: Color, rough: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	var sm := StandardMaterial3D.new()
	sm.albedo_color = c
	sm.roughness = rough
	mi.material_override = sm
	return mi


## The climb from the bottom (the first show does this).
func start() -> void:
	if state.is_empty():
		state = SummitCore.create_state(WIDTH)
		world.build(state)
	SummitCore.restart(state)
	cam = 0.0
	visible = true


func set_active(on: bool) -> void:
	visible = on
	if on and state.is_empty():
		start()
	if not state.is_empty():
		SummitCore.set_dir(state, 0.0)


func active() -> bool:
	return visible and not state.is_empty()


func set_unit(u: float) -> void:
	unit = u
	scaler.scale = Vector3.ONE * u
	set_base(base_height)


## Height of the surface above the floor: a pedestal in VR, nothing on a real table in AR.
func set_base(height: float) -> void:
	base_height = height
	var r := (WIDTH / 2.0 + 2.2) * unit
	pedestal.visible = height > 0.05
	column.scale = Vector3(r * 0.55, maxf(0.001, height - 0.03), r * 0.55)
	column.position.y = -height / 2.0 - 0.015
	slab.scale = Vector3(r, 0.03, r)
	slab.position.y = -0.015
	shadow.scale = Vector3.ONE * r * 1.05
	shadow.position.y = 0.001 if height > 0.05 else 0.002
	shadow.visible = false  # no shadows in any mode (owner's call)


func set_dir(d: float) -> void:
	if not state.is_empty():
		SummitCore.set_dir(state, d)


func jump() -> void:
	if state.is_empty():
		return
	if state.won and state.time - state.won_at > 1.2:
		SummitCore.restart(state)
		return
	SummitCore.jump(state)


func throw_ball() -> bool:
	return false if state.is_empty() else SummitCore.throw_ball(state)


## The right stick's resize (xr-runtime.js, past a 0.4 dead zone): stick_y is Godot's (up = +),
## the web's axes[3] is down = +, so up makes the mountain bigger, as there.
static func zoom_unit(u: float, stick_y: float, dt: float) -> float:
	return clampf(u * exp(stick_y * dt * 0.9), UNIT_MIN, UNIT_MAX)


## VR: on the ground where the goal stands, a few centimetres up (game_root: the game-to-world transform).
static func vr_spot(game_root: Transform3D) -> Vector3:
	var p := game_root * Vector3(0, 0, GOAL_AIM_Z)
	return Vector3(p.x, 0.04, p.z)


## MR: the size from the surface's scale and the player's zoom.
static func ar_unit(ar_scale: float, zoom: float) -> float:
	return clampf(CLIMB_VR * 2.0 / ar_scale * zoom, UNIT_MIN, UNIT_MAX)


## Where the hearts board goes: {position, scale} (VR: high on the usual board; MR: over the mountain).
func hud_place(mr: bool) -> Dictionary:
	if mr:
		return {"position": position + Vector3(0, 24.0 * unit + 0.16, 0), "scale": 0.85}
	return {"position": Vector3(0, 2.75, -3.4), "scale": 1.8}


func hud() -> Dictionary:
	if state.is_empty():
		return {}
	var b: Dictionary = state.ball
	return {"hearts": 0 if b.dead != 0.0 else int(b.hearts), "max": SummitCore.MAX_HEARTS,
		"height": maxi(0, roundi(b.y - 1.0)), "checkpoint": int(state.checkpoint), "won": bool(state.won),
		"again": bool(state.won and state.time - state.won_at > 1.2)}


# --- transforms (also outside the scene tree, for tests) -------------------------------------

func _group_xf() -> Transform3D:
	return global_transform if is_inside_tree() else transform


func scaler_xf() -> Transform3D:
	return _group_xf() * scaler.transform


func world_xf() -> Transform3D:
	return scaler_xf() * world.transform


## A point of the climb (core x, y) in world space.
func to_world(x: float, y: float, z := 0.3) -> Vector3:
	return world_xf() * Vector3(world.X(x), y, z)


# --- the frame -------------------------------------------------------------------------------

func update(dt: float, ctx := {}) -> void:
	if state.is_empty() or not visible:
		return
	SummitCore.step(state, dt)
	var on_event: Callable = ctx.get("on_event", Callable())
	events_seen = state.events.duplicate()
	for e: Dictionary in events_seen:
		if e.type == "pop":
			_burst(e.x, e.y, [Color("2c2d3d"), Color("fffaf2"), Color("c8584b")], 14, 9.0)
		elif e.type == "stomp" or e.type == "kill":
			_burst(e.x, e.y, [Color("5b3a59"), Color("fffaf2"), Color("2c2d3d")], 10, 7.0)
		elif e.type == "summit":
			_burst(state.ball.x, state.ball.y + 1.0, [Color("c8584b"), Color("e2b04a"), Color("7f9a5b"), Color("5b8bb5"), Color("fffaf2")], 30, 14.0)
		climb_event(e)
		if on_event.is_valid():
			on_event.call(e)
	state.events.clear()
	var b: Dictionary = state.ball
	var target := maxf(0.0, b.y - 6.0)
	cam += (target - cam) * (1.0 - exp(-(9.0 if b.vy < -15.0 else 5.0) * dt))
	world.position.y = -cam
	# Clip to a window from the surface up: the mountain slides down into the table.
	# The lower cut sits a hair under the surface: the starting ground's top lies exactly on it.
	var sx := scaler_xf()
	var base := sx * Vector3(0, -0.06, 0)
	var top := sx * Vector3(0, VIEW, 0)
	var up := (sx * Vector3(0, 1, 0) - sx * Vector3.ZERO).normalized()
	world.set_clip(up, up.dot(base), up.dot(top))
	world.draw(state, cam)
	var wx := world_xf()
	# Dahrooj, on the front of the ledges.
	hero.set_look(String(ctx.get("style", "jelly")), String(ctx.get("color", "original")), String(ctx.get("accessory", "")))
	var blink_out: bool = b.inv > 0.0 and int(floor(b.inv * 12.0)) % 2 == 1
	hero.visible = b.dead == 0.0 and not blink_out
	var face := "open"
	if state.won:
		face = "joy"
	elif b.inv > 1.0:
		face = "closed"
	elif not b.grounded and b.vy < -22.0:
		face = "wide"
	elif not b.grounded:
		face = "focus"
	var eye = ctx.get("eye", null)
	var toward = wx.affine_inverse() * (eye as Vector3) if eye is Vector3 else null
	var d: float = b.d
	hero.show_at(Vector3(world.X(b.x), b.y - (d if d > 0.0 else 0.0), 0.4), toward, face, false, Vector2(1.0 + d * 0.75, 1.0 - d))
	hero.set_face(face, false, Vector2(clampf(b.vx / 10.0, -1.0, 1.0) * 0.8, 0.0))
	# Thrown balls: eyeless, in Dahrooj's style.
	var shots: Array = state.shots
	for k in shots.size():
		if k >= shot_views.size():
			var v := DahroojView.new(0.42, true)
			v.cap.visible = false
			for e: Dictionary in v.eyes:
				(e.pivot as Node3D).visible = false
			world.add_child(v)
			shot_views.append(v)
		var sv := shot_views[k]
		sv.set_look(hero.style, hero.color_id, "")
		sv.position = Vector3(world.X(shots[k].x), shots[k].y, 0.4)
		sv.visible = true
	for k in range(shots.size(), shot_views.size()):
		shot_views[k].visible = false
	var seeds: Array = state.seeds
	for k in seeds.size():
		if k >= seed_meshes.size():
			var m := MeshInstance3D.new()
			m.mesh = SummitWorld.ball_mesh()
			m.material_override = world.seed_mat
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			world.add_child(m)
			seed_meshes.append(m)
		var sm := seed_meshes[k]
		sm.scale = Vector3(0.28, 0.2, 0.2)
		sm.position = Vector3(world.X(seeds[k].x), seeds[k].y, 0.3)
		sm.visible = true
	for k in range(seeds.size(), seed_meshes.size()):
		seed_meshes[k].visible = false
	# Sparks.
	for p: Dictionary in parts:
		p.t += dt
		p.v.y -= SummitCore.G * 0.35 * dt
		p.p += p.v * dt
		(p.m as Node3D).position = p.p
		(p.mat as ShaderMaterial).set_shader_parameter("albedo", Color(p.c, maxf(0.0, 1.0 - p.t / p.max)))
	var keep: Array = []
	for p: Dictionary in parts:
		if p.t < p.max:
			keep.append(p)
		else:
			(p.m as Node3D).visible = false
			_spare.append(p)
	parts = keep


func _burst(x: float, y: float, colors: Array, count: int, speed: float) -> void:
	for i in count:
		var a := randf() * TAU
		var bb := randf() * PI - PI / 2.0
		var v := speed * (0.4 + randf() * 0.8)
		var p: Dictionary
		if _spare.is_empty():
			var mt := world.mat(Color.WHITE, {"transparent": true})
			var m := MeshInstance3D.new()
			m.mesh = SummitWorld.ball_mesh()
			m.material_override = mt
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			world.add_child(m)
			p = {"m": m, "mat": mt}
		else:
			p = _spare.pop_back()
		var c: Color = colors[i % colors.size()]
		(p.mat as ShaderMaterial).set_shader_parameter("albedo", c)
		var m3: MeshInstance3D = p.m
		m3.visible = true
		m3.scale = Vector3.ONE * (0.12 + randf() * 0.1)
		p.merge({"c": c, "p": Vector3(world.X(x), y, 0.3), "t": 0.0, "max": 0.5 + randf() * 0.4,
			"v": Vector3(cos(a) * cos(bb) * v, sin(bb) * v + speed * 0.3, sin(a) * cos(bb) * v)}, true)
		m3.position = p.p
		parts.append(p)


## The sounds and the game's response to an event (xr-runtime.js climbEvent, then
## complete-game.js climbEvent).
func climb_event(e: Dictionary) -> void:
	var at := to_world(float(e.get("x", state.ball.x)), float(e.get("y", state.ball.y)))
	match String(e.type):
		"land":
			if e.power > 0.08:
				sfx.call("thump", e.power * 0.8, at)
		"launch":
			sfx.call("whoosh", float(e.power), at)
		"throw":
			sfx.call("whoosh", 0.25, at)
		"hurt":
			sfx.call("thump", 1.0, at)
	if e.type in ["pop", "stomp", "kill"]:
		sfx.call("start_pop", 0.5, at)
	if e.type in ["stomp", "kill"] and game != null:
		game.ch_progress.call("monsters15", int(game.ch_state.get("monsters15", 0)) + 1)
	if e.type == "checkpoint":
		sfx.call("chime", 1.0, at)
		if game != null:
			game.toast.call("نقطة حفظ ✓")
	if e.type == "summit":
		sfx.call("chime", 1.0, at)
		if game != null:
			game.add_count.call("climb", false)
			game.ch_progress.call("summit1", 1)
			game.toast.call(summit_toast(float(e.time)))


## complete-game.js: «وصلت القمة في [m د ]s ث», Arabic-Indic digits.
static func summit_toast(t: float) -> String:
	var m := floori(t / 60.0)
	var s := roundi(fmod(t, 60.0))
	return "وصلت القمة في %s%s ث" % [(GameCtx.ar_digits(m) + " د ") if m else "", GameCtx.ar_digits(s)]
