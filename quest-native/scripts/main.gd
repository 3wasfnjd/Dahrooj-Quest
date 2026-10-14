extends Node3D
## Dahrooj — native Meta Quest version of the web game (repository root).
##
## The game world is in the web game's units (ball radius 0.24, gravity 13, the
## goal 11 units ahead) under GameRoot, which maps game units to the room:
## Roomscale (OpenXR Stage space): the player walks about the room; the world is set
## around where they stand (place()) and then stays put.
## VR: the world at half size around a standing player (the web rig's scale 2),
## MR: the court on the floor in front of the player at 1/8 size. Game time runs
## sqrt(9.8 * scale / 13) times faster than real time, so falls look natural at
## either size (xr-runtime.js timeK).
##
## Desktop (no headset, for screenshots and tests):
##   godot --path . -- --screenshot=out.png [--view=vr|mr] [--hold] [--throw=x,y,z]

const VR_SCALE := 2.0
const AR_SCALE := 8.0
const AR_TABLE := 16.0
const AR_ZOOM_MIN := 0.35
const AR_ZOOM_MAX := 2.6
const REAL_G := 9.8
const GAIN := 2.0
const MIN_THROW := 1.0
const MAX_SPEED := 46.0
const SPAN := 0.04
const CURVE_K := 0.4
const FAR_Z := -20.0
const SLING_K := 23.0
const SLING_MIN := 0.06
const SLING_MAX := 0.65
# Holding the trigger charges the throw; the power rises and falls so you can pick your moment.
const CHARGE_MIN := 3.0
const CHARGE_MAX := 15.0
const CHARGE_TIME := 1.1
const DOTS := 26
## The modes played out in the room in mixed reality: their targets come from the room's
## walls, floor and furniture in front of the player (RoomSpots: the forward arc, far), and
## the court stands on the floor.
const ROOM_MODES := ["mole", "invasion", "slime", "meteor", "giant", "frenzy", "gallery"]
# The slingshot, held in the left hand (grip space, metres).
const TIP_L := Vector3(-0.04, 0.15, -0.045)
const TIP_R := Vector3(0.04, 0.15, -0.045)
const CROTCH := Vector3(0, 0.07, -0.03)
const POUCH := Vector3(0, 0.14, 0.02)
const FORK_CENTER := Vector3(0, 0.15, -0.045)

var rig: XRRig
var env: Environment
var sun: DirectionalLight3D
var game_root: Node3D
var park: Park
var stage: Node3D  # the current mode's stage (GoalStage, HoopStage, ...)
var ball: Ball
var dahrooj: DahroojView
var volley_views: Array = []
var hud: Node3D  # the score board pane (rig space); the jelly score pops up on it
var score_popup: ScorePopup
var confetti: Confetti
var toast: ToastCard
var audio: GameAudio
var intro: IntroRain
var quick_pick: QuickPick  # A / B in play: the next shot style / accessory, shown by the hand
var _slime_look := false
var summit: SummitMode
var _known_rewards := {}  # "kind:id" -> true for the rewards open when last checked (ChallengeRewards.watch)
var _reward_check := 0.0
var summit_hud: SummitHud
var summit_on := false
var summit_zoom := 1.0
var summit_throw_at := -1.0
var summit_throw_hand := ""  # the trigger that keeps throwing on the Summit
var tabletops := {}  # mode -> TabletopStage (built once, kept)
var table: TabletopStage = null  # the tabletop in play, or null
var table_spot = null  # VR: Transform3D in front of you
var menu: MenuPanel
var menu_hover := -1
var menu_hand := "right"
var scroll_drag := {}  # {v, track} while the trigger drags the challenge list
var reset_arm := 0.0
var on_start := {"left": false, "right": false}
var _sound_state := ""
var panel: Panel3D
var xr := false
var desktop_cam: Camera3D
var state := "boot"  # boot, start, play, menu
var scale_now := VR_SCALE
var mode := "vr"
var anchor := {}  # MR: {p: Vector3 (real surface point), theta: float}
## VR: where the player stood when the court was placed: {p: the floor under the head, theta:
## the way they faced}. The headset's origin is the middle of the play area (the Stage space,
## roomscale), so the court is set around the player, then stays put in the room while they
## walk; it moves only on a new mode, VR/MR switch or recenter.
var vr_anchor := {}
var _sun_basis := Basis()
var placing := false  # MR: aim at a surface and the court follows; the trigger pins it
var ar_scale := AR_SCALE
var ar_zoom := 1.0
var reticle: MeshInstance3D
var surfaces: SceneSurfaces
var room: RoomColliders
var place_hint: Panel3D
var _place_hint_lang := ""
var holder := ""
var parked := false
var charge_t := {"left": 0.0, "right": 0.0}
var last_thrower := "right"
var dots: Array = []
var fork: Slingshot
var _frames := 0
var _rig_game_z := 1.0  # the player's spot on the court (game z)
var hist := {"left": [], "right": [], "head": []}
var _args := {}
var _clock := 0.0
var _session_time := -1.0
var _pop_t := 1.0
var runtime: GameRuntime
var world_balls: WorldBalls
var auto_fire := {}  # hand -> next shot time while the left trigger is held
var sounds_played: Array = []  # [name, k, pos] (tests; the audio player plays them)
var room_spots := RoomSpots.new()  # MR: spawn spots in front of the player (game units)
## The rare Golden Dahrooj (GoldenDahrooj): out now and then in the modes that have him.
var golden: GoldenDahrooj
## The finale (Finale): every challenge done, or replayed from the challenges page.
var finale: Finale
## Festive texts in the game's space (the golden banner, the record, the ouch of an attack).
var fx: Node3D
## The red flash at the edges of your sight when an attack takes points (HURT_T seconds).
var hurt: MeshInstance3D
var _hurt_mat: ShaderMaterial
var _hurt_t := 0.0
## When the last light «-N» sound and buzz played (ms): rapid repeats share one.
var _nibble_ms := -1000
const HURT_T := 0.6
const HURT_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_front, shadows_disabled, fog_disabled;
uniform float strength = 0.0;
void fragment() {
	vec3 d = normalize(VERTEX);
	float e = length(d.xy);
	float a = smoothstep(0.42, 0.95, e);
	ALBEDO = mix(vec3(1.0, 0.1, 0.18), vec3(0.75, 0.0, 0.08), a);
	ALPHA = a * 0.7 * strength;
}
"""
var _spots_sig := ""
var _spots_t := 0.0


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
	ball = Ball.new()
	ball.water = park
	runtime = GameRuntime.new(ball, game_root)
	runtime.set_mode("goal")
	stage = runtime.stage
	ball.event.connect(_on_ball_event)
	dahrooj = DahroojView.new()
	dahrooj.visible = false
	game_root.add_child(dahrooj)
	for i in Ball.VOLLEY_MAX:
		var v := DahroojView.new()
		v.visible = false
		game_root.add_child(v)
		volley_views.append(v)
	world_balls = WorldBalls.new(self, ball)
	world_balls.name = "WorldBalls"
	game_root.add_child(world_balls)
	runtime.ctx.sfx = sfx
	_apply_look.call_deferred()
	_build_throw_aids()
	park.on_explode = _on_crate_blast
	intro = IntroRain.new()
	intro.name = "IntroRain"
	rig.add_child(intro)
	intro.sfx = func(n: String, k: float, p: Vector3): sfx(n, k, to_game(p))
	intro.buzz = buzz
	intro.ch_add = func(id: String): runtime.ch_add(id)
	intro.sky_pop = func(p: Vector3): world_balls.sky_pop(to_game(p))
	intro.cleared.connect(func():
		_place_rain()
		if ball.stage == null:
			ball.set_stage(runtime.stage, runtime.mode)  # back from Dahrooj Rain
		_anchor_vr_here()
		stage.visible = true)
	hud = Node3D.new()
	hud.name = "Hud"
	hud.visible = false
	add_child(hud)
	summit = SummitMode.new()
	summit.name = "Summit"
	add_child(summit)
	summit.sfx = func(n: String, k: float, pos: Vector3): sfx(n, k, to_game(pos))
	summit.game = runtime.ctx
	summit_hud = SummitHud.new()
	hud.add_child(summit_hud)
	summit_hud.visible = false
	score_popup = ScorePopup.new()
	hud.add_child(score_popup)
	confetti = Confetti.new()
	game_root.add_child(confetti)
	audio = GameAudio.new()
	audio.name = "GameAudio"
	add_child(audio)
	audio.set_muted(Save.muted)
	toast = ToastCard.new()
	add_child(toast)
	toast.buzz.connect(func(_k): buzz("left", 0.35, 60); buzz("right", 0.35, 60))
	quick_pick = QuickPick.new()
	add_child(quick_pick)
	runtime.ctx.toast = toast.show_text
	runtime.ctx.confetti = func(p: Vector3, r: float, e: float, k: float): confetti.pop(p, r, e, k)
	runtime.on_chime = func(): sfx("chime", 1.0, eye_game())
	runtime.on_record = _on_record
	runtime.on_penalty = _on_penalty
	runtime.on_nibble = _on_nibble
	fx = Node3D.new()
	fx.name = "Fx"
	game_root.add_child(fx)
	finale = Finale.new()
	finale.host = self
	game_root.add_child(finale)
	golden = GoldenDahrooj.new()
	game_root.add_child(golden)
	golden.sfx = sfx
	golden.on_caught = _on_golden_caught
	_build_hurt()
	panel = Panel3D.new()
	panel.visible = false
	add_child(panel)
	_build_placing()
	menu = MenuPanel.new()
	menu.name = "Menu"
	menu.visible = false
	add_child(menu)
	xr = not _args.has("screenshot") and _args.get("xr", "1") != "0" and rig.start()
	if xr:
		surfaces.attach(rig)
		rig.button.connect(_on_button)
		rig.menu_pressed.connect(_on_menu)
		rig.grip_tapped.connect(func(h): if h == "recenter": _on_recenter())
		rig.focus_changed.connect(func(f):
			if not f:
				_release(holder, true)
				runtime.flush())
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


## MR placement: a ring where you aim and a hint (xr-runtime.js reticle, drawHud placing).
func _build_placing() -> void:
	reticle = MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 40:
		var a0 := TAU * i / 40.0
		var a1 := TAU * (i + 1) / 40.0
		var q := [Vector3(cos(a0) * 0.07, 0, sin(a0) * 0.07), Vector3(cos(a0) * 0.09, 0, sin(a0) * 0.09),
			Vector3(cos(a1) * 0.07, 0, sin(a1) * 0.07), Vector3(cos(a1) * 0.09, 0, sin(a1) * 0.09)]
		for v in [q[0], q[2], q[1], q[1], q[2], q[3]]:
			st.add_vertex(v)
	reticle.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(Color("fffaf2"), 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = 4
	reticle.material_override = m
	reticle.visible = false
	add_child(reticle)
	# The same glass panel as the menus and the start screen.
	place_hint = Panel3D.new()
	place_hint.name = "PlaceHint"
	place_hint.visible = false
	add_child(place_hint)
	surfaces = SceneSurfaces.new()
	surfaces.name = "SceneSurfaces"
	add_child(surfaces)
	room = RoomColliders.new(surfaces)
	room.name = "RoomColliders"
	add_child(room)


## The headset's own surfaces (tables from Space Setup) first, the floor otherwise.
func _aim_at_surface():
	var hand := "right" if rig.tracked("right") else ("left" if rig.tracked("left") else "")
	if hand == "":
		return null
	var r := rig.ray(hand)
	# The headset's scanned surfaces (walls, tables, furniture) first, the floor otherwise.
	var hit := surfaces.ray_surface(r[0], r[1], 8.0, true)
	return null if hit.is_empty() else hit


## The far end of the current stage (game z), from its meshes.
func _stage_min_z() -> float:
	var inv := stage.global_transform.affine_inverse()
	var mz := float(stage.aim_z)
	for mi in stage.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.visible:
			continue
		var bb: AABB = (inv * m.global_transform) * m.mesh.get_aabb()
		mz = minf(mz, bb.position.z)
	return mz


## Where the court goes for a spot on a surface. A raised surface facing up (a table,
## a bed) gets the smaller court; the floor the usual one.
func anchor_from(P: Vector3, n: Vector3) -> Dictionary:
	ar_scale = (AR_TABLE if n.y > 0.5 and P.y > 0.35 else AR_SCALE) / ar_zoom
	# On a wall the court stands on the floor below with its back against the wall:
	# the goal's net or the hoop's board touches it.
	if absf(n.y) < 0.5:
		var f := Vector3(n.x, 0.0, n.z).normalized()
		var back := maxf(0.0, float(stage.aim_z) - _stage_min_z()) / ar_scale + 0.03
		return {"p": Vector3(P.x, 0.0, P.z) + f * back, "theta": atan2(-f.x, f.z), "wall": true}
	var pos := head_transform().origin
	var dx := P.x - pos.x
	var dz := P.z - pos.z
	return {"p": P, "theta": atan2(dx, -dz) if Vector2(dx, dz).length() > 0.05 else float(anchor.get("theta", 0.0))}


func _step_placing(dt: float) -> void:
	room.show_planes(placing and mode == "mr")
	if not placing:
		reticle.visible = false
		place_hint.visible = false
		return
	var hit = _aim_at_surface()
	if hit != null:
		anchor = anchor_from(hit.p, hit.n)
		place()
		var nn: Vector3 = hit.n
		reticle.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, nn.normalized())) if nn.dot(Vector3.UP) > -0.999 else Basis(), hit.p + nn * 0.002)
		reticle.visible = true
	# The stick: bigger and smaller, until you pin.
	var sy := rig.stick("right").y
	if absf(sy) > 0.4:
		var z := clampf(ar_zoom * exp(sy * dt * 0.9), AR_ZOOM_MIN, AR_ZOOM_MAX)
		ar_scale *= ar_zoom / z
		ar_zoom = z
		place()
	var lang := "ar" if Save.arabic() else "en"
	if lang != _place_hint_lang:
		_place_hint_lang = lang
		place_hint.build(Save.text("ثبّت الملعب", "Pin the court"),
			Save.text("وجّه على سطح واضغط الزناد · العصا تكبّر وتصغّر", "Aim at a surface, pull the trigger · stick: bigger / smaller"), [])
	var head := head_transform()
	var fwd := -head.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 0.01 else Vector3.FORWARD
	place_hint.global_position = head.origin + fwd * 1.0 + Vector3(0, 0.25, 0)
	place_hint.look_at(head.origin, Vector3.UP, true)
	place_hint.scale = Vector3.ONE * 0.8
	place_hint.visible = true


## The dotted flight preview and the slingshot (xr-runtime.js: fork, bands, dots).
func _build_throw_aids() -> void:
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = Color(Color("2c2d3d"), 0.55)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 8
	sm.rings = 6
	for i in DOTS:
		var d := MeshInstance3D.new()
		d.mesh = sm
		d.material_override = dm
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		d.visible = false
		game_root.add_child(d)
		dots.append(d)
	fork = Slingshot.new()
	fork.name = "Slingshot"
	fork.visible = false
	add_child(fork)


func _stick(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material, segs := 10) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = 1.0
	c.radial_segments = segs
	c.rings = 1
	m.mesh = c
	m.material_override = mat
	parent.add_child(m)
	_stretch(m, a, b)
	return m


func _stretch(m: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var l := d.length()
	var q := Quaternion.IDENTITY
	if l > 1e-6:
		var u := d / l
		q = Quaternion(Vector3.UP, u) if u.dot(Vector3.UP) > -0.9999 else Quaternion(Vector3.RIGHT, PI)
	m.transform = Transform3D(Basis(q).scaled(Vector3(1, maxf(l, 1e-4), 1)), (a + b) * 0.5)
	m.visible = true


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
	_sun_basis = sun.basis


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
		ar_scale = AR_SCALE
		ar_zoom = 1.0
		placing = xr
	else:
		env.background_mode = Environment.BG_SKY
		get_viewport().transparent_bg = false
		placing = false
	summit_zoom = 1.0
	if summit:
		summit.set_unit(SummitMode.CLIMB_AR if m == "mr" else SummitMode.CLIMB_VR)
	# VR: the court around wherever the player stands now.
	vr_anchor = {}
	table_spot = null
	place()
	if stage != null:
		_setup_stage()


func time_k() -> float:
	return sqrt(REAL_G * scale_now / Ball.GRAV)


## The floor under the head and the way it faces (yaw), for placing the world around the player.
func head_anchor() -> Dictionary:
	var head := head_transform()
	var dir := -head.basis.z
	dir.y = 0.0
	dir = dir.normalized() if dir.length_squared() > 0.01 else Vector3.FORWARD
	return {"p": Vector3(head.origin.x, 0.0, head.origin.z), "theta": atan2(dir.x, -dir.z)}


## VR: the court set again around where the player stands and faces now, as play begins
## (the start screen's pose can be stale or untracked).
func _anchor_vr_here() -> void:
	if mode == "mr" or summit_on or table != null:
		return
	vr_anchor = {}
	place()
	if stage != null:
		_setup_stage()


## VR: the player's spot when the court was placed, as a room transform (floor, facing -Z).
func vr_frame() -> Transform3D:
	if vr_anchor.is_empty():
		return Transform3D()
	return Transform3D(Basis(Vector3.UP, -float(vr_anchor.theta)), vr_anchor.p as Vector3)


## The game world's turn in the room (radians about +Y): the sky and the sun turn with it so
## the park's sun, sky and shading still agree.
func _world_yaw() -> float:
	if mode == "mr":
		return -float(anchor.get("theta", 0.0))
	return -float(vr_anchor.get("theta", 0.0))


## VR: every target stands as far as the cans (FAR_Z), the player at the web rig's
## spot, set where the player stands (vr_anchor) and then fixed in the room so they can
## walk up to the targets. MR: the target point pinned to a floor spot ahead, the court facing you.
func place() -> void:
	if mode != "mr":
		scale_now = VR_SCALE
		# Every target stands as far away as the cans: you step back from the nearer ones.
		# Bowling keeps its own lane (farZ); the wall and the fair keep their backdrop
		# (farZ) but stand back like the rest, a little nearer (reachZ).
		var back := 0.0
		if summit_on:
			back = maxf(0.0, SummitMode.GOAL_AIM_Z - FAR_Z)
		elif stage.far_z == null or stage.reach_z != null:
			back = maxf(0.0, stage.aim_z - (stage.reach_z if stage.reach_z != null else FAR_Z))
		var p := Vector3(0, 0, 0.5 * VR_SCALE + back)
		_rig_game_z = p.z
		if vr_anchor.is_empty() or bool(vr_anchor.get("stale", false)):
			vr_anchor = head_anchor()
			# Before the headset tracks, the head sits at the origin: place again once it does.
			if xr and (vr_anchor.p as Vector3).length() < 1e-4 and absf(float(vr_anchor.theta)) < 1e-4:
				vr_anchor["stale"] = true
		# The player's game spot p lands on the floor where they stood, the court ahead of them.
		var vb := Basis(Vector3.UP, -float(vr_anchor.theta)).scaled(Vector3.ONE / VR_SCALE)
		game_root.transform = Transform3D(vb, (vr_anchor.p as Vector3) - vb * p)
	else:
		scale_now = ar_scale
		if anchor.is_empty():
			var ha := head_anchor()
			var dir := Vector3(sin(float(ha.theta)), 0.0, -cos(float(ha.theta)))
			anchor = {"p": (ha.p as Vector3) + dir * 1.6, "theta": ha.theta}
		var ap: Vector3 = anchor.p
		# Played all around the room: the game's ground is the room's floor (even when the court
		# was pinned on a table), at the usual room scale.
		if room_play():
			scale_now = AR_SCALE / ar_zoom
			ap.y = 0.0
		var a := Vector3(0, 0, SummitMode.GOAL_AIM_Z if summit_on else float(stage.aim_z))
		var b := Basis(Vector3.UP, -anchor.theta).scaled(Vector3.ONE / scale_now)
		game_root.transform = Transform3D(b, ap - b * a)
	hud.position = (game_root.transform * Vector3(0, 0, stage.aim_z)) + Vector3(0, 0.0, 0)
	if mode == "mr":
		hud.position.y = maxf(anchor.p.y + 0.75, 1.55)
		hud.scale = Vector3.ONE * 0.95
	else:
		# High over the play area, clear of the line of throw, and a little larger so it reads at a glance.
		hud.position = vr_frame() * Vector3(0, 2.02, -3.4)
		hud.scale = Vector3.ONE * 1.8
	var yaw := _world_yaw()
	env.sky_rotation = Vector3(0.0, yaw, 0.0)
	sun.basis = Basis(Vector3.UP, yaw) * _sun_basis
	if summit_on:
		_place_summit()
	_place_rain()


## Dahrooj Rain is pinned like a court: on the floor at the pinned spot (MR, scaled by the
## zoom the stick sets while pinning) or where the player stood (VR), turned the way the
## court faces; it falls ahead of that spot (IntroRain.pinned). The opening stays at the
## origin around the head.
func _place_rain() -> void:
	if intro == null or rig == null:
		return
	intro.mixed = mode == "mr"
	if not (intro.active and intro.rain):
		intro.pinned = false
		intro.transform = Transform3D.IDENTITY
		return
	var a: Dictionary = anchor if mode == "mr" else vr_anchor
	if a.is_empty():
		intro.pinned = false
		intro.transform = Transform3D.IDENTITY
		return
	var p: Vector3 = a.p
	var k := ar_zoom if mode == "mr" else 1.0
	var xf := Transform3D(Basis(Vector3.UP, -float(a.theta)).scaled(Vector3.ONE * k), Vector3(p.x, 0.0, p.z))
	intro.transform = (rig.global_transform.affine_inverse() if rig.is_inside_tree() else rig.transform.affine_inverse()) * xf
	intro.pinned = true
	intro.pin_back = 1.6 if mode == "mr" else 0.0


## The opening's rain (with its start button), not Dahrooj Rain the mode.
func _opening() -> bool:
	return intro.active and not intro.rain


func to_game(p: Vector3) -> Vector3:
	return game_root.global_transform.affine_inverse() * p


# --- the frame -------------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	if state + mode != _sound_state:
		_sound_state = state + mode
		_sound_scene()
	var w2g := game_root.global_transform.affine_inverse()
	RenderingServer.global_shader_parameter_set("dah_world_to_game", Projection(w2g))
	var head := head_transform()
	RenderingServer.global_shader_parameter_set("dah_cam", w2g * head.origin)
	if nature_on():
		# The stone runs from behind the player to just past the target, in every mode.
		var far: float = SummitMode.GOAL_AIM_Z if summit_on else (stage.far_z if stage.far_z != null else float(stage.aim_z))
		park.set_pitch(far, _rig_game_z + 3.0)
		park.update(delta, w2g * head.origin)
		var sk := park.sky_state()
		sun.light_color = sk.sun_color
		sun.light_energy = sk.sun_energy
		env.ambient_light_color = sk.ambient_color
		env.ambient_light_energy = sk.ambient_energy
		audio.set_environment(park.night(), clampf(float(park.weather().get("rain", 0.0)), 0.0, 1.0), clampf(float(park.weather().get("snow", 0.0)), 0.0, 1.0))
	RenderingServer.global_shader_parameter_set("dah_time", _clock)
	if xr:
		_xr_states(delta)
		for h in ["left", "right"]:
			_record(h, rig.grip_transform(h).origin)
	if xr:
		_step_intro(minf(delta, 0.05))
		_step_placing(minf(delta, 0.05) if state == "play" else 0.0)
	if state == "play" or state == "menu" or not xr:
		_game_step(delta)
		_step_table(minf(delta, 0.05))
		_step_summit(minf(delta, 0.05))
		_watch_rewards(delta)
	if menu.visible:
		_step_menu(delta)
	elif panel.visible and xr:
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
			_show_start()  # the studio logo is the Meta system splash (vr_splash.png)


func _record(hand: String, p: Vector3) -> void:
	var h: Array = hist[hand]
	h.append({"t": _clock, "p": p})
	while h.size() > 2 and _clock - h[0].t > 0.25:
		h.pop_front()


func _game_step(delta: float) -> void:
	var dt := minf(delta, 0.05)
	_frames += 1
	if xr and mode != "mr" and bool(vr_anchor.get("stale", false)) and head_transform().origin.length() > 1e-4:
		place()
	var F := _fork_hand()
	fork.visible = F != ""
	if F != "":
		fork.global_transform = rig.grip_transform(F)
	# Dahrooj waits by your hand (or in the slingshot) between throws; only once the
	# headset has reported a few poses, so he doesn't appear somewhere else first.
	if xr and state == "play" and not placing and not _opening() and table == null and not summit_on and not ball.shot and holder == "" and not parked and _frames > 3:
		parked = true
		_pop_t = 0.0
		ball.pos = to_game(_park_spot(F))
	if parked:
		ball.held = true
		ball.pos = ball.pos.lerp(to_game(_park_spot(F)), 1.0 - exp(-dt * 10.0))
		ball.vel = Vector3.ZERO
		ball.grounded = false
	_pop_t += delta
	# The held ball rides in front of the hand (in the pouch with the slingshot).
	if holder != "" and xr:
		var g := rig.grip_transform(holder)
		# BR * 1.05 game units in front of the grip (game units are 1/scale_now metres).
		var target := g.origin if F != "" else g.origin + (-g.basis.z.normalized()) * Ball.BR * 1.05 / scale_now
		ball.pos = to_game(target)
		ball.vel = Vector3.ZERO
		ball.grounded = false
	# Slingshot bands follow the pouch: Dahrooj, or the rest spot.
	if F != "":
		if holder != "" or parked:
			fork.set_pouch(game_root.global_transform * ball.pos, Ball.BR / scale_now)
		else:
			fork.rest()
	# The flight preview while pulling.
	if holder != "":
		charge_t[holder] += dt
	var u = _launch(holder, ball.pos) if holder != "" and xr and (F != "" or Save.throw_style == "trigger") else null
	if u != null:
		var v := _to_game_speed(u)
		var p := ball.pos
		var step := 0.05
		var r := 0.012 * scale_now
		# The same sideways pull the throw will get, so the dots show the bend.
		var c := _curve(holder) * CURVE_K
		var f := Vector3(v.x, 0, v.z).normalized()
		var side := Vector3(-f.z, 0, f.x) * (c * 9.0)
		for d in dots:
			for k in 3:
				v.y -= Ball.GRAV * step / 3.0
				v.x += side.x * step / 3.0
				v.z += side.z * step / 3.0
				v *= pow(0.9, step / 3.0)
				p += v * (step / 3.0)
			d.position = p
			d.scale = Vector3.ONE * r
			d.visible = p.y > 0.0
	else:
		for d in dots:
			d.visible = false
	# Holding a shooting trigger keeps firing.
	for h in auto_fire.keys():
		if state != "play":
			auto_fire.erase(h)
		elif _clock >= auto_fire[h]:
			auto_fire[h] = _clock + 0.13
			_blast_from(h)
	world_balls.step_blast(dt)
	_step_room_play(dt)
	if stage is MoleStage:
		(stage as MoleStage).viewer = eye_game()
	if stage is SlimeStage:
		(stage as SlimeStage).viewer = eye_game()
	if stage != null and not (stage is MoleStage or stage is InvasionStage or stage is SlimeStage):
		if "viewer" in stage:
			stage.set("viewer", eye_game())
		if "paused" in stage:
			stage.set("paused", state != "play" or placing)
	var inv := stage as InvasionStage
	var slow := 1.0
	if inv != null:
		inv.viewer = eye_game()
		inv.paused = state != "play" or placing
		if inv.visible and not summit_on:
			slow = inv.time_scale
	var fz := stage as FrenzyStage
	if fz != null:
		var hs := {}
		if xr:
			for h in ["left", "right"]:
				if rig.tracked(h):
					hs[h] = game_root.global_transform.affine_inverse() * rig.grip_transform(h)
		fz.hands = hs
		if fz.visible and not summit_on:
			slow = fz.time_scale
	# Slow motion (Dahrooj Attack, Pop Frenzy): the game slows, music and sounds drop in pitch.
	AudioServer.playback_speed_scale = 1.0 - (1.0 - slow) * 0.5
	if true:
		var gdt := dt * time_k() * slow
		runtime.step(gdt)
		world_balls.step_rests(gdt, dt)
		world_balls.step_contacts(gdt)
		var hands := {}
		if xr:
			for h in ["left", "right"]:
				if rig.tracked(h):
					hands[h] = to_game(rig.grip_transform(h).origin)
		world_balls.feel_hands(gdt, hands)
		if not ball.held:
			world_balls.mark_ball(ball.pos, ball.vel)
		for b in ball.volley:
			world_balls.mark_ball(b.pos, b.vel)
		# Dahrooj Rain: a thrown Dahrooj pops the ones he meets.
		if intro.active and intro.rain and not intro.leaving:
			var gx := game_root.global_transform
			if ball.shot and not ball.held:
				intro.pop_near(gx * ball.pos, Ball.BR / scale_now)
			for b in ball.volley:
				intro.pop_near(gx * (b.pos as Vector3), Ball.BR / scale_now)
		# Mixed reality: the real walls and furniture.
		if room_active():
			if ball.shot and not ball.held:
				var h := room_hit(ball.pos, ball.vel, ball.pos - ball.vel * gdt, Ball.BR)
				ball.pos = h.p
				ball.vel = h.v
				if float(h.hit) > 1.0:
					sfx("thump", minf(1.0, float(h.hit) / 12.0), ball.pos)
					buzz(last_thrower, 0.3, 25)
			for b in ball.volley:
				var h := room_hit(b.pos, b.vel, b.pos - b.vel * gdt, Ball.BR)
				b.pos = h.p
				b.vel = h.v
		# The world's props: Dahrooj bounces off poles and benches, shoves lanterns and sets off crates.
		if nature_on() and park.has_method("collide"):
			if ball.shot and not ball.held:
				var r: Dictionary = park.collide(ball.pos, ball.vel, Ball.BR)
				ball.pos = r.p
				ball.vel = r.v
				if r.hit:
					sfx("thump", minf(1.0, Vector2(ball.vel.x, ball.vel.z).length() / 12.0), ball.pos)
					buzz(last_thrower, 0.3, 25)
			for b in ball.volley:
				var r: Dictionary = park.collide(b.pos, b.vel, Ball.BR)
				b.pos = r.p
				b.vel = r.v
			for rr in world_balls.rests:
				var r: Dictionary = park.collide(rr.p, rr.v, Ball.BR)
				rr.p = r.p
				rr.v = r.v
	_step_golden(dt)
	_step_hurt(delta)
	var eye := to_game(head_transform().origin)
	# Dahrooj shows only while the trigger holds him or he flies; waiting, he's out of
	# sight (in the slingshot he waits in the pouch).
	var shown := not placing and not _opening() and table == null and not summit_on and ((parked and F != "") or holder != "" or ball.shot)
	dahrooj.visible = shown
	if shown:
		var d := ball.d
		var face := "open" if parked and not (ball.mood != "" and ball.mood_t > 0.0) else ball.face()
		dahrooj.show_at(ball.pos, eye, face, ball.blink > 0.0, Vector2(1.0 + d * 0.75, 1.0 - d))
		# Pop in: grow from small with a slight overshoot.
		if _pop_t < 0.25:
			var k := _pop_t / 0.25
			var e := 1.0 + 2.2 * pow(k - 1.0, 3) + 1.2 * pow(k - 1.0, 2)
			dahrooj.scale *= maxf(0.05, e)
	# Slime: each Dahrooj is a jelly in the colour he will splat in.
	if stage is SlimeStage and stage.visible and not summit_on and table == null:
		var sl := stage as SlimeStage
		dahrooj.set_look("jelly", sl.color_for(ball.shot_id) if ball.shot else sl.next_color, worn())
		for i in mini(volley_views.size(), ball.volley.size()):
			(volley_views[i] as DahroojView).set_look("jelly", sl.color_for(int(ball.volley[i].shot_id)), worn())
		_slime_look = true
	elif _slime_look:
		_slime_look = false
		_apply_look()
	world_balls.draw_rests(eye, (state != "play" and state != "menu") or summit_on)
	for i in volley_views.size():
		var v: DahroojView = volley_views[i]
		if i < ball.volley.size():
			var b: Dictionary = ball.volley[i]
			var face: String = "closed" if b.hit_t > 0.0 else (b.mood if b.mood != "" and b.mood_t > 0.0 else "wide")
			v.visible = true
			v.show_at(b.pos, eye, face, false, Vector2(1.0 + b.d * 0.75, 1.0 - b.d))
		else:
			v.visible = false
	hud.visible = state == "play" and not placing and (not intro.active or intro.rain)
	if placing:
		score_popup.observe("placing", 0.0)
	elif summit_on:
		score_popup.observe("climb", 0.0)
	elif intro.active and intro.rain:
		score_popup.observe("rain", float(intro.popped))
	else:
		var m: String = String(table.name).trim_prefix("Table_") if table else runtime.mode
		score_popup.observe(m, float(runtime.counts.get(m, 0)))
	toast.busy = state == "menu"
	toast.world_scale = 1.0
	toast.place(head_transform())
	hud.look_at(head_transform().origin, Vector3.UP, true)


## The hand holding the slingshot (the left), when the slingshot is chosen.
func _fork_hand() -> String:
	return "left" if xr and Save.throw_style == "sling" and rig.tracked("left") else ""


## Between throws Dahrooj sits in the slingshot, or floats just in front of you at
## chest height (world space).
func _park_spot(F: String) -> Vector3:
	if F != "":
		return fork.global_transform * POUCH
	var head := head_transform()
	var pos := head.origin
	var dir := -head.basis.z
	dir.y = 0.0
	dir = dir.normalized() if dir.length_squared() > 1e-6 else Vector3.FORWARD
	var spot := Vector3(pos.x + dir.x * 0.38 - dir.z * 0.1, maxf(0.45, pos.y - 0.38), pos.z + dir.z * 0.38 + dir.x * 0.1)
	spot.y = maxf(spot.y, Ball.BR / scale_now)
	return spot


# --- input -----------------------------------------------------------------------

func _on_button(hand: String, name: String, down: bool) -> void:
	# Owner's layout: the menu button opens the mode list, left X the challenges, left Y
	# Dahrooj's look. Right A: the Summit's jump, ricochet's next paddle, elsewhere the next
	# open shot style; right B: the next open accessory (not on the Summit).
	if down and _menus_ready() and hand == "left" and name == "by":
		toggle_menu("appearance")
		return
	if down and _menus_ready() and hand == "left" and name == "ax":
		toggle_menu("challenges")
		return
	if hand == "right" and (name == "ax" or name == "by"):
		if down and state == "play" and not placing:
			if name == "ax" and summit_on:
				summit.jump()
			elif name == "ax" and table != null and table.mode == "ricochet":
				if table.next_paddle():
					buzz("right", 0.2, 20)
			elif name == "ax":
				cycle_shot()
			elif not summit_on:
				cycle_accessory()
		return
	if state == "menu":
		if name == "trigger" and down and hand == menu_hand:
			var hit := menu.hit(rig.ray(hand)[0], rig.ray(hand)[1], menu_hover)
			var b := menu.action(int(hit.index))
			if b.get("kind", "") == "scroll":
				scroll_drag = {"v": (hit.uv as Vector2).y, "track": b.id == "track"}
			elif not b.is_empty():
				rig.pulse(hand, 0.2, 0.03)
				_menu_action(int(hit.index))
		elif name == "trigger" and not down:
			scroll_drag = {}
		return
	if state == "start":
		if down and name == "trigger":
			var r := rig.ray(hand)
			var id := panel.hit(r[0], r[1])
			if id != "":
				rig.pulse(hand, 0.2, 0.03)
				_panel_action(id)
		return
	if state != "play":
		return
	# Summit: right A jumps (above); a trigger throws (held: keeps throwing), so no shots
	# there; the grips do nothing.
	if summit_on and not placing:
		if name == "trigger":
			if down:
				summit.throw_ball()
				summit_throw_at = _clock + 0.3
				summit_throw_hand = hand
			elif hand == summit_throw_hand:
				summit_throw_at = -1.0
				summit_throw_hand = ""
			return
		if name == "grip":
			return
	# Tabletop: the grip holds the board / turns a paddle; a trigger the board doesn't
	# take fires shots; A retries.
	if table != null and not placing:
		if name == "trigger" or name == "grip":
			if down:
				# No shots in the tabletop modes.
				table.xr_press(_table_input(hand), name)
			else:
				auto_fire.erase(hand)
				table.xr_release(hand, false, name)
			return
	# Every mode: the trigger fires shots, the grip (either hand) holds Dahrooj.
	if name == "trigger":
		if down:
			_press(hand, name)
		else:
			auto_fire.erase(hand)
	elif name == "grip":
		if down:
			_press(hand, name)
		elif holder == hand:
			_release(hand, false)


func _other_grab_down(hand: String, released: String) -> bool:
	var c: XRController3D = rig.hands[hand].aim
	if released == "grip":
		return c.get_float("trigger") > 0.75
	return c.get_float("grip") > 0.75


## Dahrooj in flight keeps going and a fresh one comes to the hand: throw them back
## to back. He appears straight in the hand with a little pop.
func _press(hand: String, how: String) -> void:
	# The opening: the start button, or a shot (holding keeps firing). Dahrooj Rain plays as
	# every mode does (pinning, the trigger's shots, the grip holds Dahrooj).
	if _opening() and not intro.leaving:
		if how != "trigger":
			return
		if on_start[hand] and intro.end_intro():
			placing = mode == "mr"
			_anchor_vr_here()
			ball.respawn()
			stage.visible = true
		else:
			intro.shot_hand = hand
			_fire_blast(hand)
		return
	if placing:
		if how == "trigger" and not anchor.is_empty():
			placing = false
			ball.respawn()
			_setup_stage()
		return
	# The trigger is a blaster in every mode (holding keeps firing).
	if how == "trigger":
		_fire_blast(hand)
		return
	if hand == _fork_hand():
		return  # this hand holds the slingshot
	if ball.shot and not ball.another():
		runtime.recall()
	if holder == "" and ball.can_hold():
		holder = hand
		_pop_t = 0.0
		charge_t[hand] = 0.0
		parked = false
		ball.held = true
		ball.vel = Vector3.ZERO
		ball.shot = false
		rig.pulse(hand, 0.25, 0.025)


func _release(hand: String, lost: bool) -> void:
	if hand == "" or holder != hand:
		return
	holder = ""
	var u = null if lost else _launch(hand, ball.pos)
	if u != null:
		var v := _to_game_speed(u)
		ball.throw_with(v, _curve(hand) * CURVE_K)
		note_style()  # "Play all 3 styles" counts throws, not only blaster shots
		last_thrower = hand
		parked = false
		rig.pulse(hand, 0.35 + minf(0.5, (u as Vector3).length() / MAX_SPEED * 0.6), 0.045)
	else:
		parked = true
		_pop_t = 0.0
		ball.pos = to_game(_park_spot(_fork_hand()))


## The left-hand blaster; holding the trigger keeps firing.
func _fire_blast(hand: String) -> void:
	intro.shot_hand = hand
	_blast_from(hand)
	auto_fire[hand] = _clock + 0.13


func _blast_from(hand: String) -> void:
	var a := rig.aim_transform(hand)
	var w2g := game_root.global_transform.affine_inverse()
	world_balls.fire(hand, w2g * a.origin, (w2g.basis * -a.basis.z).normalized())


## The opening: Dahrooj balls rain all around you, then a start button.
func begin_opening() -> void:
	holder = ""
	parked = false
	placing = false
	stage.visible = false
	intro.begin(false, mode == "mr")
	_place_rain()


func _step_intro(dt: float) -> void:
	if not intro.active:
		on_start = {"left": false, "right": false}
		return
	intro.step(dt, head_transform())
	for h in ["left", "right"]:
		if rig.tracked(h):
			var r := rig.ray(h)
			on_start[h] = intro.start_hit(r[0], r[1])


## Crate blasts clear nearby characters in a 3D radius, never the ball held by the player.
func _on_crate_blast(at: Vector3, radius: float, by_player := true) -> void:
	sfx("boom", 1.0, at)
	buzz("left", 0.9, 180)
	buzz("right", 0.9, 180)
	if by_player:
		runtime.ch_add("crates5")
	var reach := (radius + Ball.BR) * (radius + Ball.BR)
	for i in range(world_balls.rests.size() - 1, -1, -1):
		var r: Dictionary = world_balls.rests[i]
		if (r.p as Vector3).distance_squared_to(at) <= reach:
			world_balls.burst(r.p, r.style, false)
			world_balls._drop_rest(i)
	for i in range(ball.volley.size() - 1, -1, -1):
		if (ball.volley[i].pos as Vector3).distance_squared_to(at) <= reach:
			world_balls.burst(ball.volley[i].pos, "fur", false)
			ball.volley.remove_at(i)
	if ball.shot and not ball.held and ball.pos.distance_squared_to(at) <= reach:
		world_balls.burst(ball.pos, "fur", false)
		ball_popped()


## Mixed reality: the real room (walls, furniture) is solid.
func room_active() -> bool:
	return mode == "mr" and room != null and room.has_any()


## A ball against the room, in game units (hit: closing speed, game units per second).
func room_hit(pos: Vector3, vel: Vector3, prev: Vector3, r: float) -> Dictionary:
	var gt: Transform3D = game_root.global_transform
	var k := gt.basis.get_scale().x  # metres per game unit
	var res := room.collide(gt * pos, gt.basis * vel, r * k, gt * prev)
	var inv := gt.affine_inverse()
	return {"hit": float(res.hit_speed) / k, "p": inv * (res.p as Vector3), "v": inv.basis * (res.v as Vector3)}


# --- what the world asks of the scene (WorldBalls, stages) ---------------------------

func resting_allowed() -> bool:
	return state == "play" or state == "menu"


## The park's world is on (VR); in mixed reality it is your room.
func nature_on() -> bool:
	return mode == "vr"


func eye_game() -> Vector3:
	return to_game(head_transform().origin)


func note_style() -> void:
	runtime.note_style(Save.style)


## xr-runtime.js wornNow(): the saved accessory, if still unlocked.
func worn() -> String:
	var done := DahroojLooks.done_count(Save.challenges)
	return Save.accessory if DahroojLooks.accessory_available(Save.accessory, done, Save.challenges) else ""


## xr-runtime.js watchRewards: a card, the chime and confetti when a challenge opens a
## reward (an accessory, a shot style or a colour; ChallengeRewards.watch).
func _watch_rewards(dt: float) -> void:
	_reward_check -= dt
	if _reward_check > 0.0:
		return
	_reward_check = 0.5
	var w := ChallengeRewards.watch(_known_rewards, Save.challenges, Save.arabic())
	_known_rewards = w.known
	for c: Dictionary in w.cards:
		toast.notify("reward", str(c.title), str(c.sub))
		sfx("chime", 1.0, eye_game())
		_reward_confetti()
	# Every challenge done: the finale (once; the menu replays it).
	if not finale.active and not menu.visible and Finale.due(Save.challenges):
		finale.start(true)


## Confetti a little ahead of the eyes (in the game's units).
func _reward_confetti() -> void:
	if confetti == null:
		return
	var head := head_transform()
	var fwd := -head.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 1e-6 else Vector3.FORWARD
	confetti.celebrate(to_game(head.origin + fwd * 1.4 + Vector3.DOWN * 0.3), eye_game())


func _apply_look() -> void:
	var acc := worn()
	dahrooj.set_look(Save.style, Save.jelly_color, acc)
	for v: DahroojView in volley_views:
		v.set_look(Save.style, Save.jelly_color, acc)
	# The colour is global; resting balls keep their own style and accessory.
	for r in world_balls.rests:
		var rv: DahroojView = r.view
		rv.set_look(rv.style, Save.jelly_color, rv.accessory)


## Right A: the next shot style the challenges have opened (wrapping round), saved, with its
## icon and name by the hand and a click.
func cycle_shot() -> String:
	var id := QuickPick.next_shot(Save.shot_style, Save.challenges)
	Save.shot_style = id
	Save.save()
	var nm := QuickPick.shot_name(id)
	_quick_feedback(str(ShotCatalog.info(id).get("icon", id)), Save.text(nm[0], nm[1]))
	return id


## Right B: the next accessory open to wear ("none" among them, wrapping round), put on the
## held Dahrooj at once, with its icon and name by the hand and a click.
func cycle_accessory() -> String:
	var id := QuickPick.next_accessory(worn(), Save.challenges)
	Save.accessory = id
	Save.save()
	_apply_look()
	var nm := QuickPick.accessory_name(id)
	_quick_feedback(id if id != "" else "none", Save.text(nm[0], nm[1]))
	return id


func _quick_feedback(icon: String, text: String) -> void:
	var at: Vector3
	if xr and rig.tracked("right"):
		at = rig.aim_transform("right").origin + Vector3.UP * 0.09
	else:
		var head := head_transform()
		at = head.origin - head.basis.z * 0.5 + Vector3.DOWN * 0.15
	quick_pick.show_pick(icon, text, at)
	sfx("bricks_tink", 0.75, to_game(at))
	buzz("right", 0.2, 20)


## A shot or a hard meeting popped the ball in play: a fresh one for the hand.
func ball_popped() -> void:
	holder = ""
	runtime.recall()


func buzz(hand: String, amp: float, ms: float) -> void:
	if xr and hand != "" and Save.haptics:
		rig.pulse(hand, amp, ms / 1000.0)


## A sound at a point of the game world (game units).
func sfx(name: String, k: float, pos: Vector3) -> void:
	sounds_played.append([name, k, pos])
	if sounds_played.size() > 64:
		sounds_played.pop_front()
	if audio:
		audio.sfx(name, k, game_root.global_transform * pos)


## Music and the park's sounds while playing (the park's only in the VR world).
func _sound_scene() -> void:
	audio.music(state == "play" or state == "menu")
	audio.ambience((state == "play" or state == "menu") and nature_on())
	var xf := game_root.global_transform
	var trees := PackedVector3Array()
	for t in park.spots:
		trees.append(xf * Vector3(t.x, 0, t.z))
	audio.tree_spots = trees
	audio.pond_center = xf * Vector3(-22, 0, -5)
	audio.pond_radii = Vector2(7, 10) / scale_now if nature_on() else Vector2.ZERO


func _recall() -> void:
	ball.volley.clear()
	if ball.shot:
		holder = ""
		runtime.recall()


## Hand velocity (real m/s): the fastest ~40 ms stretch of the last 200 ms. Players
## often let go just after the peak of a swing, so the latest instant alone would feel weak.
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


## Launch velocity in real metres per second (world directions), or null for too
## gentle a release. from: the ball, game units.
func _launch(hand: String, from: Vector3):
	var F := _fork_hand()
	if F != "" and F != hand:
		var pull := (fork.global_transform * FORK_CENTER) - game_root.global_transform * from
		if pull.length() < SLING_MIN:
			return null
		if pull.length() > SLING_MAX:
			pull = pull.normalized() * SLING_MAX
		return pull * SLING_K
	if Save.throw_style == "trigger":
		# Along the hand's ray, as fast as the charge: real metres per second.
		var d := -rig.aim_transform(hand).basis.z.normalized()
		return d * (CHARGE_MIN + (CHARGE_MAX - CHARGE_MIN) * charge_power(hand))
	var u := _velocity(hand) * GAIN
	return null if u.length() < MIN_THROW else u


func charge_power(hand: String) -> float:
	var p := fmod(charge_t[hand] / CHARGE_TIME, 2.0)
	return maxf(0.08, p if p < 1.0 else 2.0 - p)


## Real m/s -> game units per game second (the world is smaller and its time faster).
func _to_game_speed(u: Vector3) -> Vector3:
	var v := game_root.global_transform.affine_inverse().basis * u / time_k()
	return v.limit_length(MAX_SPEED)


## Curve for a throw (-1..1, positive bends right). Trigger: tilt the controller
## sideways as you let go, like spinning a frisbee. Hand: the ball follows the bend
## in the hand's path. Slingshot: straight.
func _curve(hand: String) -> float:
	if _fork_hand() != "":
		return 0.0
	if Save.throw_style == "trigger":
		var tilt := -rig.aim_transform(hand).basis.x.normalized().y
		return 0.0 if absf(tilt) < 0.12 else clampf((tilt - signf(tilt) * 0.12) / 0.45, -1.0, 1.0)
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
	if kind in ["thump", "whoosh", "splash"]:
		sfx(kind, float(data.get("k", 0.5)), data.get("pos", ball.pos))
	match kind:
		"success":
			confetti.celebrate(data.get("pos", ball.pos), eye_game())
			if xr:
				rig.pulse("right", 0.5, 0.12)
		"thump":
			if xr and data.k > 0.3:
				rig.pulse("right", 0.3 * data.k, 0.025)


# --- the Golden Dahrooj, records and attacks ------------------------------------------

## The Golden Dahrooj can be out: a mode that has him (GoldenDahrooj.MODES), its court shown,
## not the Summit, a tabletop or the opening's rain.
func golden_on() -> bool:
	return runtime != null and runtime.mode in GoldenDahrooj.MODES and stage != null and stage.visible \
		and not summit_on and table == null and not intro.active


## His clock runs only in active play; a thrown Dahrooj (or one of a volley) that reaches him
## catches him (the blaster's shots: WorldBalls).
func _step_golden(dt: float) -> void:
	golden.unit = scale_now
	golden.mr = mode == "mr"
	golden.eye = eye_game()
	if golden.active and not golden_on():
		golden.clear()
	golden.step(dt, golden_on() and state == "play" and not placing, _golden_spot)
	if not golden.active:
		return
	if ball.shot and not ball.held and golden.hit_by(ball.pos, Ball.BR):
		golden.catch("throw")
		return
	for b: Dictionary in ball.volley:
		if golden.hit_by(b.pos, Ball.BR):
			golden.catch("throw")
			return


## Where the Golden Dahrooj turns up (game units), always in front of the player and far
## (GoldenDahrooj.settle: the forward arc, 2.5 m away or more): over the target of a throwing
## course; in mixed reality out of the room (RoomSpots: off a wall or furniture, or in the
## air ahead without a scan); in VR up in the air far ahead.
func _golden_spot() -> Variant:
	var eye := eye_game()
	var fwd := play_forward()
	var u := scale_now
	if runtime.mode in GoldenDahrooj.COURSES:
		return GoldenDahrooj.course_spot(eye, fwd, u, float(stage.aim_z), golden.rng)
	var floor_y := to_game(Vector3.ZERO).y if mode == "mr" else 0.0
	if room_play():
		_refresh_room_spots(false)
		if room_spots.has_room():
			var sp := room_spots.pick(eye, ["wall", "top", "air"])
			if not sp.is_empty():
				var p: Vector3 = (sp.pos as Vector3) + (sp.normal as Vector3) * 0.45 * u
				p.y = maxf(p.y, floor_y + 0.9 * u)
				return GoldenDahrooj.settle(eye, p, fwd, u)
	if mode == "mr":
		return GoldenDahrooj.air_spot(eye, fwd, u, floor_y, golden.rng, Vector2(2.6, 3.6), Vector2(1.0, 1.8))
	return GoldenDahrooj.air_spot(eye, fwd, u, 0.0, golden.rng)


## How big a festive text at `at` (game units) is drawn: the same size in metres in VR and in
## mixed reality, a little bigger far away.
func _text_k(at: Vector3, base := 0.6) -> float:
	var dist_m := at.distance_to(eye_game()) / scale_now
	return base * scale_now / VR_SCALE * maxf(1.0, dist_m / 4.5)


## A point ahead of the eyes (game units): metres out along the head's level forward, raised.
func _ahead_game(metres: float, up := 0.0) -> Vector3:
	var head := head_transform()
	var f := -head.basis.z
	f.y = 0.0
	f = f.normalized() if f.length_squared() > 1e-6 else Vector3.FORWARD
	return to_game(head.origin + f * metres + Vector3.UP * up)


## Caught! +500 on this mode's score with a big gold banner, confetti, a golden firework,
## the ching and a buzz in both hands; the golden challenges count one more.
func _on_golden_caught(at: Vector3, _how: String) -> void:
	var m: String = runtime.mode
	runtime.golden_caught(m)
	var pts := GameRuntime.GOLDEN_POINTS
	var text := Save.text("دحروج ذهبي! +%s" % GameCtx.ar_digits(pts), "Golden Dahrooj! +%d" % pts)
	JuiceText.spawn(fx, text, at + Vector3.UP * golden.radius() * 2.4, "banner", _text_k(at), GoldenDahrooj.GOLD)
	confetti.celebrate(at, eye_game())
	world_balls.bloom(at)
	sfx("fair_ding", 1.0, at)
	sfx("chime", 1.0, eye_game())
	buzz("left", 0.85, 180)
	buzz("right", 0.85, 180)


## This session just beat the mode's best for the first time: fireworks and confetti ahead, a
## big rainbow «رقم قياسي جديد!», a fanfare and a buzz (once per mode and session).
func _on_record(_m: String, score: int, _previous: int) -> void:
	# Below the score board (its digits pop up there), rising toward it.
	var at := _ahead_game(2.4, -0.5)
	JuiceText.spawn(fx, Save.text("رقم قياسي جديد!", "New record!"), at, "banner", _text_k(at, 0.7))
	JuiceText.spawn(fx, Save.text("الأفضل: %s" % GameCtx.grouped(score, true), "Best: %s" % GameCtx.grouped(score)), at - Vector3.UP * 0.36 * scale_now, "sub", _text_k(at, 0.7))
	confetti.celebrate(_ahead_game(1.6, -0.3), eye_game())
	for i in 3:
		world_balls.bloom(_ahead_game(3.2, 1.0 + 0.35 * i) + Vector3((i - 1) * 1.1 * scale_now, 0, 0))
	sfx("firework_launch", 1.0, at)
	sfx("chime", 1.0, eye_game())
	buzz("left", 0.7, 220)
	buzz("right", 0.7, 220)


## An attack got through and took points: the score sinks to its new value, a soft «-50» in
## front of you, a red flash at the edges of your sight, a bump and a buzz in both hands.
func _on_penalty(m: String, taken: int, _asked: int, _at: Vector3) -> void:
	_hurt_t = HURT_T
	sfx("thump", 1.0, eye_game())
	buzz("left", 0.8, 140)
	buzz("right", 0.8, 140)
	if taken > 0:
		var at := _ahead_game(1.5, -0.1)
		JuiceText.spawn(fx, "-%d" % taken, at, "ouch", _text_k(at, 0.55))
		if m == runtime.mode:
			score_popup.drop(int(runtime.counts.get(m, 0)))


## A small thing got through (a meteor on the ground, a mole gone): a small grey «-N» where it
## happened and a soft bump (one per quarter second when they come fast); no red flash.
func _on_nibble(m: String, taken: int, _asked: int, at: Vector3) -> void:
	if taken <= 0:
		return
	JuiceText.spawn(fx, "-%d" % taken, at + Vector3.UP * 0.4 * scale_now / VR_SCALE, "miss", _text_k(at, 0.4))
	if m == runtime.mode:
		score_popup.drop(int(runtime.counts.get(m, 0)))
	var now := Time.get_ticks_msec()
	if now - _nibble_ms > 250:
		_nibble_ms = now
		sfx("thump", 0.35, at)
		buzz("left", 0.25, 40)
		buzz("right", 0.25, 40)


func _build_hurt() -> void:
	hurt = MeshInstance3D.new()
	hurt.name = "HurtFlash"
	var sm := SphereMesh.new()
	sm.radius = 0.25
	sm.height = 0.5
	sm.radial_segments = 24
	sm.rings = 12
	hurt.mesh = sm
	_hurt_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = HURT_SHADER
	_hurt_mat.shader = sh
	_hurt_mat.render_priority = 10
	hurt.material_override = _hurt_mat
	hurt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hurt.visible = false
	add_child(hurt)


func _step_hurt(dt: float) -> void:
	_hurt_t = maxf(0.0, _hurt_t - dt)
	hurt.visible = _hurt_t > 0.0
	if hurt.visible:
		hurt.global_position = head_transform().origin
		var k := _hurt_t / HURT_T
		_hurt_mat.set_shader_parameter("strength", k * k * (3.0 - 2.0 * k))


# --- splash, start screen and menu ---------------------------------------------------

func _show_start() -> void:
	state = "start"
	panel.build(Save.text("دحروج", "Dahrooj"), Save.text("اختر طريقة اللعب", "Choose how to play"),
		[["mr", Save.text("الواقع المختلط — في غرفتك", "Mixed reality — in your room")],
		["vr", Save.text("الواقع الافتراضي — في الحديقة", "Virtual reality — in the park")],
		["lang", Save.text("English", "العربية")]])
	panel.place(head_transform(), 0.75, 0.05)
	panel.visible = true


## Menus open only once the game has started: not on the start screen or during the opening.
func _menus_ready() -> bool:
	return (state == "play" or state == "menu") and not _opening()


func _on_menu() -> void:
	if _menus_ready():
		toggle_menu("modes")
	elif state == "start":
		panel.place(head_transform(), 0.75, 0.05)


func _close_menu() -> void:
	set_menu(false)


## The headset menu (xr-runtime.js setMenu / toggleMenu).
func set_menu(on: bool, page := "modes") -> void:
	var was := menu.visible
	if on:
		_release(holder, true)
		auto_fire.clear()
		if table:
			table.xr_cancel()
		menu.set_page(page)
		if not was:
			menu.place(head_transform())
		state = "menu"
	else:
		reset_arm = 0.0
		menu_hover = -1
		scroll_drag = {}
		if state == "menu":
			state = "play"
	menu.visible = on
	if on:
		menu.draw(_menu_model(), menu_hover)


func toggle_menu(page: String) -> void:
	set_menu(not (menu.visible and menu.page == page), page)


func _menu_model() -> Dictionary:
	var list := []
	for c in GameRuntime.CHALLENGES:
		list.append({"id": c[0], "title": c[1], "en": c[2], "value": mini(int(Save.challenges.get(c[0], 0)), c[3]), "goal": c[3]})
	var done := 0
	for c in list:
		if c.value >= c.goal:
			done += 1
	var sky := park.settings() if park.has_method("settings") else {"time": "auto", "weather": "auto"}
	return {"english": not Save.arabic(), "kind": mode, "mode": "climb" if summit_on else "rain" if intro.active and intro.rain else (String(table.name).trim_prefix("Table_") if table else runtime.mode),
		"style": Save.style, "jelly_color": Save.jelly_color, "throw_style": Save.throw_style, "shot_style": Save.shot_style,
		"time": sky.time, "weather": sky.weather, "accessory": worn(), "done": done, "reset_armed": reset_arm > 0.0,
		"rewards": Save.challenges, "challenges": list, "records": Save.records}


func _step_menu(dt: float) -> void:
	reset_arm = maxf(0.0, reset_arm - dt)
	if xr:
		if not rig.tracked(menu_hand):
			menu_hand = "left" if menu_hand == "right" else "right"
		var r := rig.ray(menu_hand)
		var hit := menu.hit(r[0], r[1], menu_hover)
		menu_hover = int(hit.index)
		var d: float = hit.distance
		rig.set_pointer(menu_hand, {"point": r[0] + r[1] * d, "interactive": menu_hover >= 0} if d > 0.0 else null, true)
		var other := "left" if menu_hand == "right" else "right"
		rig.set_pointer(other, null, false)
		if not scroll_drag.is_empty() and d > 0.0:
			var v: float = (hit.uv as Vector2).y
			menu.scroll_drag(scroll_drag.v, v, scroll_drag.track)
			scroll_drag.v = v
		var sy := rig.stick("right").y
		if absf(sy) > 0.05:
			menu.scroll_axis(sy, dt)
	menu.draw(_menu_model(), menu_hover)


## What each menu button does (xr-runtime.js menuAction).
func _menu_action(i: int) -> void:
	var b := menu.action(i)
	if b.is_empty():
		return
	if menu.navigate(b):
		menu_hover = -1
		return
	match String(b.kind):
		"mode":
			_choose_mode(String(b.id))
			return
		"close":
			set_menu(false)
			return
		"throw":
			holder = ""
			Save.throw_style = String(b.id)
			Save.save()
		"shot":
			# A style the challenges have not unlocked yet is refused (its card is locked too).
			if ShotCatalog.open_now(String(b.id), Save.challenges):
				Save.shot_style = String(b.id)
				Save.save()
		"lang":
			Save.language = "en" if Save.arabic() else "ar"
			Save.save()
			menu_hover = -1
		"time", "weather":
			if nature_on():
				park.set_settings({String(b.kind): String(b.id)})
		"place":
			set_menu(false)
			if mode == "mr" and xr:
				holder = ""
				placing = true
			else:
				replace_here()
		"finale":
			if GameRuntime.all_done(Save.challenges):
				set_menu(false)
				finale.stop()
				finale.start(false)
			return
		"reset":
			if reset_arm > 0.0:
				reset_arm = 0.0
				Save.challenges.clear()
				Save.styles_used.clear()
				Save.total_score = 0
				runtime.forget_scores()
				Save.accessory = ""
				if not MenuCatalog.color_available(Save.jelly_color, Save.challenges):
					Save.jelly_color = "pink"
				TabletopProgress.clear(Save.best)
				Save.save()
				_apply_look()
				toast.notify("info", Save.text("صفّرت التحديات", "Challenges reset"), Save.text("ابدأ من جديد!", "Start again!"))
			else:
				reset_arm = 3.0
		"exit":
			set_menu(false)
			get_tree().quit()
		"style":
			if String(b.id) in DahroojLooks.PLAYABLE_STYLES:
				Save.style = String(b.id)
				Save.save()
				_apply_look()
		"jellyColor":
			# A colour the challenges have not opened yet is refused (its card is locked too).
			if MenuCatalog.color_available(DahroojLooks.color_id(b.id), Save.challenges):
				Save.jelly_color = DahroojLooks.color_id(b.id)
				Save.save()
				_apply_look()
		"acc":
			var id := String(b.id)
			if DahroojLooks.accessory_available(id, DahroojLooks.done_count(Save.challenges), Save.challenges):
				Save.accessory = id
				Save.save()
				_apply_look()


## Whack-a-Dahrooj: in VR from the court's ground; in mixed reality in front of the player,
## out of the room's walls, open floor and furniture tops (RoomSpots; a ring on the floor and in
## the air when the room has no scan).
func _setup_mole() -> void:
	var mole := stage as MoleStage
	if mole == null:
		return
	mole.sink = mode != "mr"
	mole.size = RoomSpots.size_for(0.1, MoleStage.R, scale_now) if mode == "mr" else 1.0
	mole.spots_provider = room_spots_for(2)


## The Summit: Dahrooj climbs the mountain on the goal court (VR) or on the pinned spot.
func set_summit(on: bool) -> void:
	if on and intro.active:
		intro.set_rain(false)
		intro.clear()
	summit_on = on
	summit.set_active(on)
	stage.visible = not on
	holder = ""
	parked = false
	ball.held = false
	ball.volley.clear()
	auto_fire.clear()
	summit_throw_at = -1.0
	summit_throw_hand = ""
	summit_hud.visible = on
	place()
	if not on:
		summit_hud.show_hud({})


func _place_summit() -> void:
	if mode == "mr" and not anchor.is_empty():
		summit.position = anchor.p
		summit.rotation = Vector3(0, -float(anchor.theta), 0)
		var u := SummitMode.ar_unit(ar_scale, summit_zoom)
		if absf(u - summit.unit) > 1e-6:
			summit.set_unit(u)
		summit.set_base(0.0)
	else:
		summit.position = SummitMode.vr_spot(game_root.transform)
		summit.rotation = Vector3(0, -float(vr_anchor.get("theta", 0.0)), 0)
		summit.set_base(summit.position.y)
	var hp := summit.hud_place(mode == "mr")
	hud.position = hp.position if mode == "mr" else vr_frame() * (hp.position as Vector3)
	hud.scale = Vector3.ONE * float(hp.scale)


func _step_summit(dt: float) -> void:
	if not summit_on:
		return
	if xr and state == "play" and not placing:
		var st := rig.stick("left") if rig.tracked("left") else rig.stick("right")
		summit.set_dir(st.x if absf(st.x) > 0.25 else 0.0)
		var sy := rig.stick("right").y
		if absf(sy) > 0.4:
			var u := SummitMode.zoom_unit(summit.unit, sy, dt)
			if mode == "mr":
				summit_zoom = u * ar_scale / (SummitMode.CLIMB_VR * VR_SCALE)
			summit.set_unit(u)
		if summit_throw_at >= 0.0 and _clock >= summit_throw_at:
			summit.throw_ball()
			summit_throw_at = _clock + 0.3
	else:
		summit.set_dir(0.0)
	_place_summit()
	summit.update(dt, {"style": Save.style, "color": Save.jelly_color, "accessory": "",
		"eye": head_transform().origin, "on_event": func(_e: Dictionary): pass})
	summit_hud.show_hud(summit.hud(), "ar" if Save.arabic() else "en")


## The tabletop modes (balance, ricochet, maze): a small board in front of you (VR) or
## on the pinned surface (MR), played with the grip; "" leaves tabletop play.
func _set_table(m: String) -> void:
	if table:
		table.xr_cancel()
		table.deactivate()
		table.visible = false
		table = null
	if m == "":
		return
	if not tabletops.has(m):
		var st := TabletopStage.new(m)
		st.name = "Table_" + m
		add_child(st)
		st.sfx = func(n: String, k: float, pos: Vector3): audio.sfx(n, k, pos)
		st.won.connect(_on_table_won)
		tabletops[m] = st
	table = tabletops[m]
	table.visible = true
	table_spot = null
	ball.respawn()


func _on_table_won(_points: int, result: Dictionary, at: Vector3) -> void:
	TabletopProgress.record_win(Save.best, runtime.ch_progress, result)
	Save.save()
	runtime.add_count(String(result.mode), false)
	confetti.celebrate(to_game(at), eye_game())


## xr-runtime.js placeTable.
func _place_table() -> void:
	var spot: Transform3D
	var unit := 0.32
	if mode == "mr" and not anchor.is_empty():
		spot = Transform3D(Basis(Vector3.UP, -float(anchor.theta)), (anchor.p as Vector3) + Vector3(0, 0.07, 0))
		unit = clampf(3.2 / ar_scale, 0.1, 0.44)
	else:
		if table_spot == null:
			var h := head_transform()
			var dir := -h.basis.z
			dir.y = 0.0
			dir = dir.normalized() if dir.length_squared() > 1e-4 else Vector3.FORWARD
			var p := h.origin + dir * 0.82
			p.y = maxf(0.55, h.origin.y - 0.62)
			table_spot = Transform3D(Basis.looking_at(dir, Vector3.UP), p)
		spot = table_spot
	table.place_table(spot, unit)


func _table_input(hand: String) -> Dictionary:
	var r := rig.ray(hand)
	var g := rig.grip_transform(hand)
	return {"id": hand, "ray": {"origin": r[0], "dir": r[1]}, "position": g.origin, "rotation": g.basis.get_rotation_quaternion()}


func _step_table(dt: float) -> void:
	if table == null:
		return
	_place_table()
	var ins := []
	if xr:
		for h in ["left", "right"]:
			if rig.tracked(h):
				ins.append(_table_input(h))
	var stick := Vector2.ZERO
	if xr:
		stick = rig.stick("left") if rig.tracked("left") else rig.stick("right")
	table.xr_frame(dt, {"inputs": ins, "active": state == "play" and not placing, "stick": stick, "style": Save.style,
		"color": Save.jelly_color, "accessory": worn(), "eye": head_transform().origin, "english": not Save.arabic()})


## Dahrooj Attack: in mixed reality they burst out of the room's walls, floor and furniture
## in front of the player (RoomSpots), room-sized; haptics through buzz().
func _setup_invasion() -> void:
	var inv := stage as InvasionStage
	if inv == null:
		return
	inv.size = RoomSpots.size_for(0.11, 0.45, scale_now) if mode == "mr" else 1.0
	inv.buzz = buzz
	inv.spots_provider = room_spots_for(1)


## Slime: in mixed reality Dahrooj sticks to the scanned walls, floor and furniture.
func _setup_slime() -> void:
	var slime := stage as SlimeStage
	if slime == null:
		return
	slime.spots_provider = room_spots_for(2)
	slime.planes_provider = func() -> Array:
		var out := []
		if mode != "mr":
			return out
		var to_game := game_root.global_transform.affine_inverse()
		var add := func(c: Vector3, n: Vector3, u: Vector3, v: Vector3, label: String) -> void:
			var ax: Vector3 = to_game.basis * u
			var ay: Vector3 = to_game.basis * v
			out.append({"pos": to_game * c, "normal": (to_game.basis * n).normalized(), "ax": ax.normalized(),
				"ay": ay.normalized(), "half": Vector2(ax.length(), ay.length()), "label": label})
		for pl in surfaces.planes():
			var x: Transform3D = pl.xform
			var sz: Vector2 = pl.size
			add.call(x.origin, pl.normal, x.basis.x.normalized() * sz.x * 0.5, x.basis.y.normalized() * sz.y * 0.5, pl.label)
		# Furniture volumes: their top and sides.
		for bx in surfaces.boxes():
			var x: Transform3D = bx.xform
			var sz: Vector3 = bx.size
			var e := [x.basis.x.normalized(), x.basis.y.normalized(), x.basis.z.normalized()]
			for i in 3:
				for sgn in [-1.0, 1.0]:
					if i == 1 and sgn < 0.0:
						continue
					var n: Vector3 = e[i] * sgn
					add.call(x.origin + n * sz[i] * 0.5, n, e[(i + 1) % 3] * sz[(i + 1) % 3] * 0.5, e[(i + 2) % 3] * sz[(i + 2) % 3] * 0.5, bx.label)
		return out


## The scanned room in game units (the format the newer stages take: SlimeStage's).
func room_planes_game() -> Array:
	var out := []
	if mode != "mr":
		return out
	var to_game := game_root.global_transform.affine_inverse()
	for pl in surfaces.planes():
		var x: Transform3D = pl.xform
		var sz: Vector2 = pl.size
		var ax: Vector3 = to_game.basis * (x.basis.x.normalized() * sz.x * 0.5)
		var ay: Vector3 = to_game.basis * (x.basis.y.normalized() * sz.y * 0.5)
		out.append({"pos": to_game * x.origin, "normal": (to_game.basis * (pl.normal as Vector3)).normalized(),
			"ax": ax.normalized(), "ay": ay.normalized(), "half": Vector2(ax.length(), ay.length()), "label": pl.label})
	return out


## Every mode's setup for the current world (VR or MR) and scale.
func _setup_stage() -> void:
	_setup_mole()
	_setup_invasion()
	_setup_slime()
	_setup_new_mode()
	# Every mode spawns in front of the player and some metres away: the stages measure that in
	# game units per metre. A mode with its own layout (the giant) sets it again for where the
	# court is now (a new pin moves him with it).
	if stage != null:
		if "unit" in stage:
			stage.set("unit", scale_now)
		if "viewer" in stage:
			stage.set("viewer", eye_game())
		if stage.has_method("on_placed"):
			stage.call("on_placed")


## Mixed reality, a mode played out in the room (ROOM_MODES), not the Summit or a tabletop.
func room_play() -> bool:
	return mode == "mr" and runtime != null and stage != null and stage.visible and runtime.mode in ROOM_MODES \
		and not summit_on and table == null


## A stage's spots_provider: n spots in front of the player (RoomSpots) of the kinds asked, in
## room play; [] otherwise (VR: the stage keeps its own layout).
func room_spots_for(n: int) -> Callable:
	return func(kinds: Array) -> Array:
		if not room_play():
			return []
		_refresh_room_spots(false)
		return room_spots.pick_many(eye_game(), n, kinds)


## The room for RoomSpots, game units: the scanned planes plus the furniture volumes and their
## tops. [planes, boxes].
func room_for_spots() -> Array:
	var planes := room_planes_game()
	var bxs := []
	if mode != "mr":
		return [planes, bxs]
	var to_game := game_root.global_transform.affine_inverse()
	for bx in surfaces.boxes():
		var x: Transform3D = bx.xform
		var sz: Vector3 = bx.size
		var e: Array = [x.basis.x.normalized(), x.basis.y.normalized(), x.basis.z.normalized()]
		var g: Array = []
		for i in 3:
			g.append(to_game.basis * ((e[i] as Vector3) * sz[i] * 0.5))
		bxs.append({"pos": to_game * x.origin, "ax": (g[0] as Vector3).normalized(), "ay": (g[1] as Vector3).normalized(),
			"az": (g[2] as Vector3).normalized(), "half": Vector3((g[0] as Vector3).length(), (g[1] as Vector3).length(), (g[2] as Vector3).length()), "label": bx.label})
		# Its top: the face looking up.
		var up := 0
		for i in 3:
			if absf((e[i] as Vector3).y) > absf((e[up] as Vector3).y):
				up = i
		var sgn := 1.0 if (e[up] as Vector3).y >= 0.0 else -1.0
		var n: Vector3 = (e[up] as Vector3) * sgn
		if n.y < 0.7:
			continue
		var u: Vector3 = g[(up + 1) % 3]
		var v: Vector3 = g[(up + 2) % 3]
		planes.append({"pos": to_game * (x.origin + n * sz[up] * 0.5), "normal": (to_game.basis * n).normalized(),
			"ax": u.normalized(), "ay": v.normalized(), "half": Vector2(u.length(), v.length()), "label": bx.label})
	return [planes, bxs]


## Keeps RoomSpots in step with the scan and the court's placement (checked at most once a
## second unless forced).
func _refresh_room_spots(force: bool) -> void:
	room_spots.forward = play_forward()
	if not force and _spots_t > 0.0 and _spots_sig != "":
		return
	_spots_t = 1.0
	var n_planes := surfaces.planes().size()
	var n_boxes := surfaces.boxes().size()
	var sig := "%d|%d|%s|%s" % [n_planes, n_boxes, str(game_root.global_transform), surfaces.status]
	if sig == _spots_sig:
		return
	_spots_sig = sig
	room_spots.unit = scale_now
	room_spots.floor_y = to_game(Vector3.ZERO).y
	var r := room_for_spots()
	room_spots.set_room(r[0], r[1])


## Room play, every frame: RoomSpots keeps to the play direction (in front of the player).
func _step_room_play(dt: float) -> void:
	if not room_play() or placing:
		return
	_spots_t -= dt
	room_spots.forward = play_forward()
	room_spots.cool(dt)


## The play direction in game units (horizontal): the court's forward, which is game -Z (the
## pinned anchor in mixed reality, the court's facing in VR); the head's yaw when mixed
## reality has no anchor yet.
func play_forward() -> Vector3:
	if mode == "mr" and anchor.is_empty():
		var f: Vector3 = game_root.global_transform.affine_inverse().basis * -head_transform().basis.z
		f.y = 0.0
		if f.length_squared() > 1e-6:
			return f.normalized()
	return Vector3.FORWARD


## The action modes (meteor, castle, giant, gallery, frenzy) share one setup: size in
## mixed reality, haptics, and the scanned room when the stage takes it.
func _setup_new_mode() -> void:
	if stage == null or not stage.get_script() or stage is MoleStage or stage is InvasionStage or stage is SlimeStage:
		return
	if "size" in stage and ("planes_provider" in stage or "spots_provider" in stage):
		stage.set("size", 2.0 if mode == "mr" else 1.0)
	if "buzz" in stage:
		stage.set("buzz", buzz)
	if "planes_provider" in stage:
		stage.set("planes_provider", room_planes_game)
	if stage is FrenzyStage:
		stage.set("size", scale_now / VR_SCALE if mode == "mr" else 1.0)  # bubbles keep their real size
		stage.set("around", mode == "mr")
	# Played out in the room: room spots, and targets sized for the room (cm, whatever the
	# court's scale).
	if "spots_provider" in stage:
		stage.set("spots_provider", room_spots_for(2 if stage is GalleryStage else 1))
	if stage is GalleryStage:
		stage.set("mixed", mode == "mr")
	if mode == "mr":
		if stage is MeteorStage:
			stage.set("size", RoomSpots.size_for(0.15, 0.85, scale_now))
		elif stage is GalleryStage:
			stage.set("size", RoomSpots.size_for(0.15, GalleryStage.R, scale_now))
		elif stage is GiantStage:
			stage.set("size", RoomSpots.size_for(0.105, GiantStage.MIN_R, scale_now))
	if stage is CastleStage:
		stage.set("size", 1.25 if mode == "mr" else 1.0)  # a small fort on the floor or a table


## A mode card (xr-runtime.js choosePlaza).
func _choose_mode(id: String) -> void:
	var sound_pos := to_game(menu.global_position)
	if golden:
		golden.clear()
	if id == "climb":
		set_menu(false)
		_set_table("")
		if mode != "mr":
			vr_anchor = {}
		set_summit(true)
		sfx("whoosh", 0.5, sound_pos)
		runtime.note_mode(id, worn())
		return
	if not (id in GameRuntime.MODES or id in ["rain", "balance", "ricochet", "maze", "climb"]):
		toast.show_text(Save.text("قريبًا في النسخة القادمة", "Coming in the next version"))
		return
	holder = ""
	parked = false
	ball.held = false
	set_menu(false)
	_set_table("")
	# VR: a new mode is set around wherever the player has walked to (MR keeps its pinned spot).
	if mode != "mr":
		vr_anchor = {}
	if summit_on:
		set_summit(false)
	if id in ["balance", "ricochet", "maze"]:
		if intro.active:
			intro.set_rain(false)
			intro.clear()
		stage.visible = false
		_set_table(id)
		place()
	elif id == "rain":
		intro.set_rain(true)
		stage.visible = false  # (after: clearing a rain already falling shows the stage)
		ball.set_stage(null, "rain")  # nothing to score on: Dahrooj only pops the rain
		place()
	else:
		if intro.active:
			intro.set_rain(false)
			intro.clear()
		runtime.set_mode(id)
		stage = runtime.stage
		stage.visible = true
		place()
		_setup_stage()
	runtime.note_mode(id, worn())
	sfx("whoosh", 0.5, sound_pos)
	buzz("left", 0.45, 70)
	buzz("right", 0.45, 70)


func _on_recenter() -> void:
	if state == "boot":
		return
	if state == "start":
		panel.place(head_transform(), 0.75, 0.05)
		return
	replace_here()


## Recenter: the court (VR: and the park), the tabletop and the Summit set again around where
## the player stands now, facing the way they look.
func replace_here() -> void:
	anchor = {}
	vr_anchor = {}
	table_spot = null
	place()
	# A mode with its own layout (the giant) lays out again for the court's new spot.
	if stage != null and stage.has_method("on_placed"):
		if "viewer" in stage:
			stage.set("viewer", eye_game())
		stage.call("on_placed")


func _panel_action(id: String) -> void:
	match id:
		"mr", "vr":
			Save.mode = id
			Save.save()
			set_mode(id)
			panel.visible = false
			state = "play"
			if xr:
				begin_opening()
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
			replace_here()
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
