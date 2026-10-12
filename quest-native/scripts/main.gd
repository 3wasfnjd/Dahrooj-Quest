extends Node3D
## Dahrooj — native Meta Quest version of the web game (repository root).
##
## The game world is in the web game's units (ball radius 0.24, gravity 13, the
## goal 11 units ahead) under GameRoot, which maps game units to the room:
## VR: the world at half size around a standing player (the web rig's scale 2),
## MR: the court on the floor in front of the player at 1/8 size. Game time runs
## sqrt(9.8 * scale / 13) times faster than real time, so falls look natural at
## either size (xr-runtime.js timeK).
##
## Desktop (no headset, for screenshots and tests):
##   godot --path . -- --screenshot=out.png [--view=vr|mr] [--hold] [--throw=x,y,z]

const VR_SCALE := 2.0
const AR_SCALE := 8.0
const REAL_G := 9.8
const GAIN := 2.0
const MIN_THROW := 1.0
const MAX_SPEED := 46.0
const SPAN := 0.04
const CURVE_K := 0.4
const FAR_Z := -20.0

var rig: XRRig
var env: Environment
var sun: DirectionalLight3D
var game_root: Node3D
var park: Park
var stage: GoalStage
var ball: Ball
var dahrooj: DahroojView
var volley_views: Array = []
var hud: Label3D
var panel: Panel3D
var xr := false
var desktop_cam: Camera3D
var state := "boot"  # boot, splash, start, play, menu
var scale_now := VR_SCALE
var mode := "vr"
var anchor := {}  # MR: {p: Vector3 (real floor point), theta: float}
var holder := ""
var hist := {"left": [], "right": [], "head": []}
var _args := {}
var _clock := 0.0
var _session_time := -1.0
var _pop_t := 1.0
var counts := {"goal": 0}
var splash: Node3D


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_setup_environment()
	rig = XRRig.new()
	rig.name = "XROrigin3D"
	add_child(rig)
	rig.setup(env)
	game_root = Node3D.new()
	game_root.name = "GameRoot"
	add_child(game_root)
	park = Park.new()
	game_root.add_child(park)
	park.build()
	stage = GoalStage.new()
	game_root.add_child(stage)
	ball = Ball.new()
	ball.water = park
	ball.set_stage(stage, "goal")
	ball.event.connect(_on_ball_event)
	dahrooj = DahroojView.new()
	dahrooj.visible = false
	game_root.add_child(dahrooj)
	for i in Ball.VOLLEY_MAX:
		var v := DahroojView.new()
		v.visible = false
		game_root.add_child(v)
		volley_views.append(v)
	hud = Panel3D.label("", 72, Color(0.17, 0.18, 0.24))
	hud.outline_size = 12
	hud.outline_modulate = Color(1, 1, 1, 0.85)
	hud.visible = false
	add_child(hud)
	panel = Panel3D.new()
	panel.visible = false
	add_child(panel)
	xr = not _args.has("screenshot") and _args.get("xr", "1") != "0" and rig.start()
	if xr:
		rig.button.connect(_on_button)
		rig.menu_pressed.connect(_on_menu)
		rig.grip_tapped.connect(func(h): if h == "recenter": _on_recenter())
		rig.focus_changed.connect(func(f): if not f: _release(holder, true))
		_session_time = 0.0
		state = "boot"
	else:
		_setup_desktop()
	set_mode(Save.mode if xr else String(_args.get("view", "vr")))
	if _args.has("screenshot"):
		_screenshot.call_deferred()
	# Store builds only: verify the purchase within the first seconds of launch.
	var entitlement := StoreEntitlement.new()
	entitlement.name = "StoreEntitlement"
	add_child(entitlement)
	entitlement.run.call_deferred()


func _setup_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# The game's own models: hemisphere light (fff8ee over c1c8d6) as ambient, and the sun.
	env.ambient_light_color = Color("fff1dd").lerp(Color.WHITE, 0.35).lerp(Color("c1c8d6"), 0.35)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = Color("fff1dd")
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	add_child(sun)
	_apply_day()


## The day preset (DayCycles.js "day"): the park's light and sky.
func _apply_day() -> void:
	var d := {"light": Color("fff1dd"), "intensity": 1.35, "shadow": Color("8b9cae"), "fog_a": Color("dcebf4"), "fog_b": Color("83b7e0"), "near": 0.5, "far": 2.0}
	var phi := 0.63
	var theta := 0.72
	var ldir := Vector3(sin(phi) * sin(theta), cos(phi), sin(phi) * cos(theta)).normalized()
	var horizon: Color = d.fog_a.lerp(Color.WHITE, 0.35)
	var zenith: Color = d.fog_b.lerp(d.fog_a, 0.15)
	var day_p := 0.05
	var sa := day_p * PI * 2.0
	var sun_dir := Vector3(cos(sa) * 0.6, 0.25 + 0.5 * absf(cos(sa * 0.5)), -0.75).normalized()
	var G := RenderingServer
	G.global_shader_parameter_set("dah_light_color", _lin(d.light))
	G.global_shader_parameter_set("dah_light_intensity", d.intensity)
	G.global_shader_parameter_set("dah_shadow_color", _lin(d.shadow))
	G.global_shader_parameter_set("dah_horizon", _lin(horizon))
	G.global_shader_parameter_set("dah_zenith", _lin(zenith))
	G.global_shader_parameter_set("dah_fog_a", _lin(d.fog_a))
	G.global_shader_parameter_set("dah_light_dir", ldir)
	G.global_shader_parameter_set("dah_sun_dir", sun_dir)
	G.global_shader_parameter_set("dah_fog_near", 20.0 + d.near * 25.0)
	G.global_shader_parameter_set("dah_fog_far", 20.0 + d.far * 25.0)
	sun.look_at_from_position(Vector3(3, 10, -4), Vector3(0, 0, -9), Vector3.UP)


## Shader globals take linear colours (the park shades in linear light, as three.js does).
static func _lin(c: Color) -> Vector3:
	var l := c.srgb_to_linear()
	return Vector3(l.r, l.g, l.b)


func _setup_desktop() -> void:
	desktop_cam = Camera3D.new()
	desktop_cam.fov = 75.0
	desktop_cam.near = 0.02
	desktop_cam.far = 200.0
	add_child(desktop_cam)
	desktop_cam.current = true
	desktop_cam.position = Vector3(0, 1.6, 0)
	state = "play"


func head_transform() -> Transform3D:
	return rig.head_transform() if xr else desktop_cam.global_transform


# --- placing the game world in the room ------------------------------------------

func set_mode(m: String) -> void:
	if xr:
		m = rig.set_mode(m)
	else:
		mode = m
	mode = m
	park.visible = m == "vr"
	if m == "mr":
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0, 0, 0, 0)
		get_viewport().transparent_bg = true
		anchor = {}
	else:
		env.background_mode = Environment.BG_SKY
		get_viewport().transparent_bg = false
	place()


func time_k() -> float:
	return sqrt(REAL_G * scale_now / Ball.GRAV)


## VR: every target stands as far as the cans (FAR_Z), the player at the web rig's
## spot. MR: the target point pinned to a floor spot ahead, the court facing you.
func place() -> void:
	if mode != "mr":
		scale_now = VR_SCALE
		var back := maxf(0.0, stage.aim_z - FAR_Z)
		var p := Vector3(0, 0, 0.5 * VR_SCALE + back)
		game_root.transform = Transform3D(Basis().scaled(Vector3.ONE / VR_SCALE), -p / VR_SCALE)
	else:
		scale_now = AR_SCALE
		if anchor.is_empty():
			var head := head_transform()
			var dir := -head.basis.z
			dir.y = 0.0
			dir = dir.normalized() if dir.length_squared() > 0.01 else Vector3.FORWARD
			anchor = {"p": Vector3(head.origin.x, 0, head.origin.z) + dir * 1.6, "theta": atan2(dir.x, -dir.z)}
		var a := Vector3(0, 0, stage.aim_z)
		var b := Basis(Vector3.UP, -anchor.theta).scaled(Vector3.ONE / AR_SCALE)
		game_root.transform = Transform3D(b, anchor.p - b * a)
	hud.position = (game_root.transform * Vector3(0, 0, stage.aim_z)) + Vector3(0, 0.0, 0)
	if mode == "mr":
		hud.position.y = maxf(anchor.p.y + 0.75, 1.55)
		hud.pixel_size = 0.0009
	else:
		hud.position = Vector3(0, 2.02, -3.4)
		hud.pixel_size = 0.0016


func to_game(p: Vector3) -> Vector3:
	return game_root.global_transform.affine_inverse() * p


# --- the frame -------------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	var w2g := game_root.global_transform.affine_inverse()
	RenderingServer.global_shader_parameter_set("dah_world_to_game", Projection(w2g))
	var head := head_transform()
	RenderingServer.global_shader_parameter_set("dah_cam", w2g * head.origin)
	RenderingServer.global_shader_parameter_set("dah_time", _clock)
	RenderingServer.global_shader_parameter_set("dah_wind_time", _clock * 0.1 * 0.5)
	if xr:
		_xr_states(delta)
		for h in ["left", "right"]:
			_record(h, rig.grip_transform(h).origin)
	if state == "play" or state == "menu" or not xr:
		_game_step(delta)
	if panel.visible and xr:
		for h in ["right", "left"]:
			if rig.tracked(h):
				var r := rig.ray(h)
				panel.hit(r[0], r[1])
				var dist := panel.ray_distance(r[0], r[1])
				rig.set_pointer(h, {"point": r[0] + r[1] * dist, "interactive": true} if dist > 0.0 else null, true)
				break
	elif xr:
		rig.set_pointer("left", null, false)
		rig.set_pointer("right", null, false)


func _xr_states(delta: float) -> void:
	if state == "boot":
		_session_time += delta
		if rig.focused and _session_time > 0.5 and (head_transform().origin.y > 0.3 or _session_time > 3.0):
			_show_splash()


func _record(hand: String, p: Vector3) -> void:
	var h: Array = hist[hand]
	h.append({"t": _clock, "p": p})
	while h.size() > 2 and _clock - h[0].t > 0.25:
		h.pop_front()


func _game_step(delta: float) -> void:
	var dt := minf(delta, 0.05) * time_k()
	if holder != "" and xr:
		var g := rig.grip_transform(holder)
		var fwd := -g.basis.z.normalized()
		ball.pos = to_game(g.origin) + (game_root.global_transform.affine_inverse().basis * fwd).normalized() * Ball.BR * 1.05
		ball.vel = Vector3.ZERO
		ball.grounded = false
	if state != "menu":
		ball.step(dt)
	_pop_t += delta
	var eye := to_game(head_transform().origin)
	var shown := holder != "" or ball.shot
	dahrooj.visible = shown
	if shown:
		var d := ball.d
		dahrooj.show_at(ball.pos, eye, ball.face(), ball.blink > 0.0, Vector2(1.0 + d * 0.75, 1.0 - d))
		if _pop_t < 0.25:
			var k := _pop_t / 0.25
			var e := 1.0 + 2.2 * pow(k - 1.0, 3) + 1.2 * pow(k - 1.0, 2)
			dahrooj.scale *= maxf(0.05, e)
	for i in volley_views.size():
		var v: DahroojView = volley_views[i]
		if i < ball.volley.size():
			var b: Dictionary = ball.volley[i]
			var face: String = "closed" if b.hit_t > 0.0 else (b.mood if b.mood != "" and b.mood_t > 0.0 else "wide")
			v.visible = true
			v.show_at(b.pos, eye, face, false, Vector2(1.0 + b.d * 0.75, 1.0 - b.d))
		else:
			v.visible = false
	hud.visible = state == "play"
	hud.text = "%s  %d" % [Save.text("مرمى", "Goal"), counts.goal]
	hud.look_at(head_transform().origin, Vector3.UP, true)


# --- input -----------------------------------------------------------------------

func _on_button(hand: String, name: String, down: bool) -> void:
	if state == "start" or state == "menu":
		if down and name == "trigger":
			var r := rig.ray(hand)
			var id := panel.hit(r[0], r[1])
			if id != "":
				rig.pulse(hand, 0.2, 0.03)
				_panel_action(id)
		return
	if state != "play":
		return
	if hand == "right" and (name == "grip" or name == "trigger"):
		if down:
			_press(hand)
		elif holder == hand and not _other_grab_down(hand, name):
			_release(hand, false)
	elif hand == "right" and name == "ax" and down:
		_recall()
	elif name == "by" and down:
		_on_menu()


func _other_grab_down(hand: String, released: String) -> bool:
	var c: XRController3D = rig.hands[hand].aim
	if released == "grip":
		return c.get_float("trigger") > 0.75
	return c.get_float("grip") > 0.75


## Dahrooj in flight keeps going and a fresh one comes to the hand.
func _press(hand: String) -> void:
	if ball.shot and not ball.another():
		_recall()
	if holder == "" and ball.can_hold():
		holder = hand
		_pop_t = 0.0
		ball.held = true
		ball.vel = Vector3.ZERO
		ball.shot = false
		rig.pulse(hand, 0.25, 0.025)


func _release(hand: String, lost: bool) -> void:
	if hand == "" or holder != hand:
		return
	holder = ""
	var u = null if lost else _launch(hand)
	if u != null:
		var v := _to_game_speed(u)
		ball.throw_with(v, _curve(hand) * CURVE_K)
		rig.pulse(hand, 0.35 + minf(0.5, v.length() / MAX_SPEED * 0.6), 0.045)
	else:
		ball.held = false
		ball.respawn()


func _recall() -> void:
	ball.volley.clear()
	if ball.shot:
		holder = ""
		ball.respawn()


## Hand velocity (real m/s): the fastest ~40 ms stretch of the last 200 ms.
func _velocity(hand: String) -> Vector3:
	var h: Array = hist[hand]
	var n := h.size()
	var best := Vector3.ZERO
	if n < 2:
		return best
	var now: float = h[n - 1].t
	var j := n - 1
	for i in range(n - 1, 0, -1):
		if now - h[i].t > 0.2:
			break
		j = mini(j, i - 1)
		while j > 0 and h[i].t - h[j].t < SPAN:
			j -= 1
		var dt: float = h[i].t - h[j].t
		if dt < 0.008:
			continue
		var v: Vector3 = (h[i].p - h[j].p) / dt
		if v.length_squared() > best.length_squared():
			best = v
	return best


func _launch(hand: String):
	var u := _velocity(hand) * GAIN
	return null if u.length() < MIN_THROW else u


## Real m/s -> game units per game second (the world is smaller and its time faster).
func _to_game_speed(u: Vector3) -> Vector3:
	var v := game_root.global_transform.affine_inverse().basis * u / time_k()
	return v.limit_length(MAX_SPEED)


## Curve from the bend in the hand's path (-1..1, positive bends right).
func _curve(hand: String) -> float:
	var hs: Array = hist[hand]
	if hs.size() < 6:
		return 0.0
	var n := hs.size()
	var m := n >> 1
	var e: Vector3 = hs[m].p - hs[0].p
	var l: Vector3 = hs[n - 1].p - hs[m].p
	if Vector2(e.x, e.z).length() < 0.02 or Vector2(l.x, l.z).length() < 0.02:
		return 0.0
	var a := atan2(l.x, -l.z) - atan2(e.x, -e.z)
	a = atan2(sin(a), cos(a))
	return 0.0 if absf(a) < 0.08 else clampf(a / 0.6, -1.0, 1.0)


func _on_ball_event(kind: String, data: Dictionary) -> void:
	match kind:
		"success":
			counts[data.mode] = int(counts.get(data.mode, 0)) + 1
			if xr:
				rig.pulse("right", 0.5, 0.12)
		"thump":
			if xr and data.k > 0.3:
				rig.pulse("right", 0.3 * data.k, 0.025)


# --- splash, start screen and menu ---------------------------------------------------

func _show_splash() -> void:
	state = "splash"
	splash = Node3D.new()
	add_child(splash)
	var head := head_transform()
	var fwd := -head.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 0.01 else Vector3.FORWARD
	splash.global_position = head.origin + fwd * 1.4
	splash.look_at(head.origin, Vector3.UP, true)
	var cairo: FontFile = load("res://assets/fonts_cairo/cairo-arabic-700-normal.woff2")
	var latin: FontFile = load("res://assets/fonts_cairo/cairo-latin-500-normal.woff2")
	if cairo and latin:
		cairo.fallbacks = [latin]
	var ar := Panel3D.label("عبودين قيمز", 96, Color(1, 1, 1, 0))
	ar.font = cairo
	ar.pixel_size = 0.0011
	var en := Panel3D.label("ABODEN GAMES", 40, Color(1, 1, 1, 0))
	en.font = cairo
	en.pixel_size = 0.0011
	en.position.y = -0.11
	splash.add_child(ar)
	splash.add_child(en)
	var tw := create_tween()
	tw.tween_property(ar, "modulate:a", 1.0, 0.7)
	tw.parallel().tween_property(en, "modulate:a", 0.9, 0.7)
	tw.tween_interval(3.0)
	tw.tween_property(ar, "modulate:a", 0.0, 0.7)
	tw.parallel().tween_property(en, "modulate:a", 0.0, 0.7)
	tw.tween_callback(func():
		splash.queue_free()
		_show_start())


func _show_start() -> void:
	state = "start"
	panel.build(Save.text("دحروج", "Dahrooj"), Save.text("اختر طريقة اللعب", "Choose how to play"),
		[["mr", Save.text("الواقع المختلط — في غرفتك", "Mixed reality — in your room")],
		["vr", Save.text("الواقع الافتراضي — في الحديقة", "Virtual reality — in the park")],
		["lang", Save.text("English", "العربية")]])
	panel.place(head_transform(), 0.75, 0.05)
	panel.visible = true


func _on_menu() -> void:
	if state == "play":
		state = "menu"
		_release(holder, true)
		panel.build(Save.text("القائمة", "Menu"), "",
			[["resume", Save.text("متابعة", "Resume")],
			["recall", Save.text("استدعاء دحروج", "Call Dahrooj back")],
			["switch", Save.text("التبديل إلى الواقع الافتراضي", "Switch to virtual reality") if mode == "mr" else Save.text("التبديل إلى الواقع المختلط", "Switch to mixed reality")],
			["recenter", Save.text("وضع الملعب أمامي", "Place the court in front of me")],
			["lang", Save.text("English", "العربية")]])
		panel.place(head_transform())
		panel.visible = true
	elif state == "menu":
		_close_menu()
	elif state == "start":
		panel.place(head_transform(), 0.75, 0.05)


func _close_menu() -> void:
	panel.visible = false
	state = "play"


func _on_recenter() -> void:
	if state == "boot" or state == "splash":
		return
	if state == "start":
		panel.place(head_transform(), 0.75, 0.05)
		return
	anchor = {}
	place()


func _panel_action(id: String) -> void:
	match id:
		"mr", "vr":
			Save.mode = id
			Save.save()
			set_mode(id)
			panel.visible = false
			state = "play"
		"lang":
			Save.language = "en" if Save.arabic() else "ar"
			Save.save()
			if state == "start":
				_show_start()
			else:
				state = "play"
				_on_menu()
		"resume":
			_close_menu()
		"recall":
			_recall()
			_close_menu()
		"switch":
			var m := "vr" if mode == "mr" else "mr"
			Save.mode = m
			Save.save()
			set_mode(m)
			_close_menu()
		"recenter":
			anchor = {}
			place()
			_close_menu()


# --- desktop screenshots -------------------------------------------------------------

func _screenshot() -> void:
	var view := String(_args.get("view", "vr"))
	if view == "mr":
		desktop_cam.position = Vector3(0, 1.3, 0.2)
		desktop_cam.look_at(anchor.p + Vector3(0, 0.1, 0), Vector3.UP)
	else:
		desktop_cam.rotation = Vector3(deg_to_rad(float(_args.get("pitch", "-6"))), deg_to_rad(float(_args.get("yaw", "0"))), 0)
	if _args.has("cam"):  # game-unit camera position and target, for close-ups
		var c := String(_args.cam).split(",")
		var l := String(_args.get("look", "0,0,-10")).split(",")
		desktop_cam.global_position = game_root.global_transform * Vector3(float(c[0]), float(c[1]), float(c[2]))
		desktop_cam.look_at(game_root.global_transform * Vector3(float(l[0]), float(l[1]), float(l[2])), Vector3.UP)
	if _args.has("hold"):
		holder = "right"
		ball.held = true
		ball.pos = to_game(Vector3(0.18, 1.25, -0.35))
	if _args.has("throw"):
		var p := String(_args.throw).split(",")
		ball.pos = to_game(Vector3(0.15, 1.3, -0.3))
		ball.throw_with(Vector3(float(p[0]), float(p[1]), float(p[2])))
		var t := float(_args.get("after", "0.6"))
		var steps := int(t / (1.0 / 72.0))
		for i in steps:
			_game_step(1.0 / 72.0)
	if _args.has("menu"):
		state = "play"
		_on_menu()
		panel.place(head_transform(), 0.7, 0.1)
	if _args.has("start"):
		_show_start()
	for i in 6:
		await get_tree().process_frame
	_game_step(0.0)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(String(_args.screenshot))
	print("screenshot: ", _args.screenshot)
	get_tree().quit()
