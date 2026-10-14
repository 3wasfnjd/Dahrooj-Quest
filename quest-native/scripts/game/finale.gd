class_name Finale
extends Node3D
## The finale («أبطال العالم!»): the big celebration when the last challenge (GameRuntime.ALL_DONE,
## every other challenge finished) is done, and again from the challenges page once it is.
##
## In front of the player (never behind: everything stands within the forward half, at least
## NEAR_M metres ahead): two rings of Dahroojs in every style wearing every accessory gather
## around a spot ahead and dance (hops that travel round the ring as a wave, squash and stretch,
## spins), mole Dahroojs pop up out of little holes inside the ring, a giant Dahrooj with a crown
## bounces behind, and the World Cup rises out of the floor in the middle, grows, then floats up
## to the player and is presented in front of them. Confetti, fireworks, the chime, haptics and a
## big rainbow banner «أبطال العالم!» with «أتممت دحروج» under it. About DUR seconds, then they
## hop away and it all clears. The first time, Dahrooj puts the World Cup on (the accessory).
##
## Lives under GameRoot: positions in game units; sizes and distances are metres times the
## host's scale_now (game units per metre), so it is the same size in VR and mixed reality.
## The host (main.gd) gives head_transform(), to_game(), scale_now, sfx(), buzz(), confetti,
## world_balls (bloom), fx (texts), _text_k(), toast and _apply_look().

signal finished

## The progress key set once the finale has played for the final challenge (cleared with
## the challenges, so finishing everything again celebrates again).
const SEEN := "seen:finale"
const ACCESSORY := "worldCup"
const DUR := 13.5
const AHEAD_M := 2.6  # the ring's centre, ahead of the player
const NEAR_M := 0.8  # nothing comes closer ahead than this (but the presented cup)
const INNER := {"n": 16, "r_m": 1.0, "size_m": 0.12, "spin": 0.35}
const OUTER := {"n": 24, "r_m": 1.6, "size_m": 0.14, "spin": -0.22}
const MOLES := 8
const MOLE_UP := 1.4  # seconds a mole stays up
const GIANT_M := 0.85  # the giant's radius
const GIANT_BACK_M := 2.7  # behind the ring's centre
const GIANT_SIDE_M := -1.2  # and off to one side, so the cup stands clear of him
const CUP_M := 1.0  # the World Cup's height in the middle
const CUP_NEAR_M := 0.34  # its height when presented
const PRESENT_M := 0.7  # how far in front of the eyes it is presented
## The big cup's shimmering gold (after GoldenDahrooj's body): its vertex colours shaded by
## the view, a band of light sweeping over the metal, a highlight and a warm rim; the green
## bands of the foot stay matt.
const CUP_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float ndv = clamp(dot(n, v), 0.0, 1.0);
	vec3 c = COLOR.rgb;
	float metal = clamp((c.r - c.b) * 3.0, 0.0, 1.0);
	vec3 wn = (INV_VIEW_MATRIX * vec4(n, 0.0)).xyz;
	float band = smoothstep(0.8, 1.0, sin(wn.y * 3.2 + wn.x * 2.1 - TIME * 3.0));
	vec3 l = normalize((VIEW_MATRIX * vec4(0.35, 0.8, 0.5, 0.0)).xyz);
	float spec = pow(clamp(dot(reflect(-v, n), l), 0.0, 1.0), 24.0);
	float rim = pow(1.0 - ndv, 2.5);
	vec3 base = c * mix(0.4, 1.15, pow(ndv, 0.6));
	ALBEDO = base + metal * (vec3(1.0, 0.95, 0.75) * (band * 0.5 + spec * 0.9) + vec3(1.0, 0.86, 0.45) * rim * 0.5)
		+ (1.0 - metal) * c * (0.25 + spec * 0.4);
}
"""
const COLORS := ["", "ff69b4", "58b9ff", "ffdf45", "58db83", "b878ff", "ff9b3d", "2fcdbd", "ff505c", "e8b23a"]
## [time, what]: the beats of the show.
const BEATS := [
	[0.0, "start"], [0.35, "confetti"], [1.2, "rise"], [2.0, "banner"], [4.0, "confetti"], [7.4, "present"],
	[7.6, "confetti"], [10.6, "equip"], [11.2, "farewell"], [11.4, "confetti"],
]

var host: Node
## When false the owner calls step(dt) itself (tests).
var auto_step := true
var active := false
var t := 0.0
## How many times it has played (tests), and whether this run is the first (it equips).
var runs := 0
var first := false
var unit := 1.0
var centre := Vector3.ZERO  # the ring's centre on the floor (game units)
var eye := Vector3.ZERO
var fwd := Vector3.FORWARD  # the player's level forward at the start (game space)
var floor_y := 0.0
var crowd: Crowd
var cup: MeshInstance3D
var pedestal: MeshInstance3D
var glow: OmniLight3D
var banner: JuiceText
var sub: JuiceText
var holes: Array[MeshInstance3D] = []
## Every actor drawn this frame: [pos (game units), radius] (tests: all of them ahead).
var drawn: Array = []
var _beat := 0
var _accs: Array = []  # the accessories the actors wear, in order
var _ready_accs := {}  # accessory -> built (Crowd.prepare), a few each frame
var _moles: Array = []  # {at: Vector3 offset from centre (game units), t0}
var _fireworks: Array = []  # {t, p, launched}
var _rng := RandomNumberGenerator.new()
var _equipped := false


func _init() -> void:
	name = "Finale"
	visible = false
	crowd = Crowd.new(INNER.n + OUTER.n + MOLES + 2, true, true)
	crowd.name = "FinaleCrowd"
	add_child(crowd)
	cup = MeshInstance3D.new()
	cup.name = "WorldCup"
	var cm := ShaderMaterial.new()
	cm.shader = Shader.new()
	cm.shader.code = CUP_SHADER
	cup.material_override = cm
	cup.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cup)
	pedestal = MeshInstance3D.new()
	pedestal.name = "Pedestal"
	var tor := TorusMesh.new()
	tor.inner_radius = 0.82
	tor.outer_radius = 1.0
	tor.rings = 48
	tor.ring_segments = 8
	pedestal.mesh = tor
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.albedo_color = Color(1.0, 0.82, 0.3, 0.8)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pedestal.material_override = pm
	pedestal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pedestal)
	glow = OmniLight3D.new()
	glow.name = "Glow"
	glow.light_color = Color(1.0, 0.85, 0.5)
	glow.shadow_enabled = false
	add_child(glow)
	var hole_mesh := CylinderMesh.new()
	hole_mesh.top_radius = 1.0
	hole_mesh.bottom_radius = 1.0
	hole_mesh.height = 0.02
	hole_mesh.radial_segments = 20
	hole_mesh.rings = 1
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color("3b2717")
	hm.roughness = 1.0
	for i in MOLES:
		var h := MeshInstance3D.new()
		h.name = "Hole%d" % i
		h.mesh = hole_mesh
		h.material_override = hm
		h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(h)
		holes.append(h)
	for id: String in DahroojLooks.ACCESSORIES:
		if id != "":
			_accs.append(id)


## Whether the finale is due: every challenge done and not celebrated yet.
static func due(progress: Dictionary) -> bool:
	return GameRuntime.all_done(progress) and int(progress.get(SEEN, 0)) == 0


## Starts the show in front of the player. celebrate_first: the real completion (notes it in
## the progress and puts the World Cup on Dahrooj at the end); false: a replay.
func start(celebrate_first := false) -> void:
	if host == null:
		return
	first = celebrate_first
	if first:
		Save.challenges[SEEN] = 1
		Save.save()
	runs += 1
	active = true
	visible = true
	t = 0.0
	_beat = 0
	_equipped = false
	_rng.randomize()
	unit = float(host.scale_now)
	var head: Transform3D = host.head_transform()
	var f := -head.basis.z
	f.y = 0.0
	f = f.normalized() if f.length_squared() > 1e-6 else Vector3.FORWARD
	eye = host.to_game(head.origin)
	floor_y = (host.to_game(Vector3(head.origin.x, 0.0, head.origin.z)) as Vector3).y
	var ahead: Vector3 = host.to_game(head.origin + f)
	fwd = Vector3(ahead.x - eye.x, 0.0, ahead.z - eye.z).normalized()
	centre = Vector3(eye.x, floor_y, eye.z) + fwd * AHEAD_M * unit
	# The moles: spots inside the inner ring (not on the cup), each up in its own moment.
	_moles.clear()
	for i in MOLES:
		var a := TAU * (i + 0.5) / MOLES + _rng.randf_range(-0.2, 0.2)
		var r := _rng.randf_range(0.45, 0.75) * unit
		_moles.append({"at": Vector3(sin(a) * r, 0.0, cos(a) * r), "t0": 2.4 + i * 0.95 + _rng.randf_range(0.0, 0.3)})
	# Fireworks over the ring.
	_fireworks.clear()
	var ft := 2.6
	while ft < 10.8:
		var side := fwd.cross(Vector3.UP)
		var p := centre + side * _rng.randf_range(-1.6, 1.6) * unit + fwd * _rng.randf_range(-0.4, 1.4) * unit + Vector3.UP * _rng.randf_range(1.9, 2.7) * unit
		_fireworks.append({"t": ft, "p": p, "launched": false, "bloomed": false})
		ft += _rng.randf_range(0.45, 0.8)
	glow.omni_range = 3.0 * unit
	glow.position = centre + Vector3.UP * 1.3 * unit
	pedestal.position = centre + Vector3.UP * 0.01 * unit
	pedestal.rotation = Vector3.ZERO
	cup.visible = false
	if cup.mesh == null:
		cup.mesh = DahroojLooks.world_cup_mesh(1.0)
	_ensure_texts()
	banner.visible = false
	sub.visible = false
	_step_actors()


## Ends the show at once (tidy: nothing left showing).
func stop() -> void:
	if not active:
		return
	active = false
	visible = false
	crowd.begin()
	crowd.end()
	drawn.clear()
	if banner:
		banner.visible = false
		sub.visible = false
	finished.emit()


func _process(delta: float) -> void:
	if auto_step and active:
		step(minf(delta, 0.05))


func step(dt: float) -> void:
	if not active:
		return
	t += dt
	while _beat < BEATS.size() and t >= float(BEATS[_beat][0]):
		_on_beat(str(BEATS[_beat][1]))
		_beat += 1
	_prepare_some()
	_step_cup()
	_step_actors()
	_step_fireworks()
	_step_texts(dt)
	glow.light_energy = (0.0 if t < 1.0 else 1.4 + 0.4 * sin(t * 5.0)) * clampf((DUR - t) / 1.5, 0.0, 1.0)
	var pm := pedestal.material_override as StandardMaterial3D
	var ring_on := clampf((t - 0.8) / 0.6, 0.0, 1.0) * clampf((DUR - 0.8 - t) / 1.0, 0.0, 1.0)
	pedestal.scale = Vector3.ONE * 0.42 * unit * (0.4 + 0.6 * ring_on) * (1.0 + 0.04 * sin(t * 6.0))
	pedestal.rotation.y = t * 0.6
	pm.albedo_color.a = 0.75 * ring_on
	if t >= DUR:
		stop()


func _on_beat(what: String) -> void:
	match what:
		"start":
			_sfx("chime", 1.0, eye)
			_buzz(0.8, 220)
		"confetti":
			if host.confetti:
				(host.confetti as Confetti).celebrate(centre + Vector3.UP * 0.6 * unit, eye)
		"rise":
			cup.visible = true
			_sfx("whoosh", 0.8, centre)
			_buzz(0.5, 160)
		"banner":
			banner.position = centre + Vector3.UP * 2.2 * unit
			sub.position = centre + Vector3.UP * 1.8 * unit
			banner.visible = true
			sub.visible = true
			_sfx("chime", 1.0, eye)
		"present":
			_sfx("whoosh", 1.0, centre)
			_buzz(0.45, 120)
		"equip":
			var at := _cup_pos()
			if host.world_balls:
				host.world_balls.bloom(at)
			_sfx("fair_ding", 1.0, at)
			_sfx("chime", 1.0, eye)
			_buzz(0.95, 260)
			if first and not _equipped:
				_equipped = true
				Save.accessory = ACCESSORY
				Save.save()
				if host.has_method("_apply_look"):
					host._apply_look()
				if host.toast:
					host.toast.notify("reward", Save.text("دحروج لابس كأس العالم!", "Dahrooj is wearing the World Cup!"),
						Save.text("مبروك يا بطل العالم", "Congratulations, world champion"))
		"farewell":
			_sfx("start_pop", 1.0, centre)


## The accessories are built a few a frame (the first time), so the show does not stall.
func _prepare_some() -> void:
	var n := 0
	for id: String in _accs:
		if _ready_accs.has(id):
			continue
		crowd.prepare(id)
		_ready_accs[id] = true
		n += 1
		if n >= 3:
			return


func _acc(i: int) -> String:
	var id: String = _accs[i % _accs.size()]
	return id if _ready_accs.has(id) else ""


## Where the cup is now (game units): rising in the middle, then floating up to the player.
func _cup_pos() -> Vector3:
	var present := eye + fwd * PRESENT_M * unit + Vector3.DOWN * 0.05 * unit
	var q := clampf((t - 7.4) / 2.6, 0.0, 1.0)
	var e := q * q * (3.0 - 2.0 * q)
	var rise := clampf((t - 1.2) / 2.4, 0.0, 1.0)
	var lift := 0.08 * unit * (1.0 - pow(1.0 - rise, 3.0))
	var p := (centre + Vector3.UP * lift).lerp(present - Vector3.UP * CUP_NEAR_M * 0.5 * unit, e)
	p += Vector3.UP * sin(PI * e) * 0.5 * unit
	if q >= 1.0:
		p += Vector3.UP * sin(t * 2.2) * 0.02 * unit
	return p


func _step_cup() -> void:
	if not cup.visible:
		return
	var rise := clampf((t - 1.2) / 2.4, 0.0, 1.0)
	var grow := 1.0 - pow(1.0 - rise, 3.0)
	var q := clampf((t - 7.4) / 2.6, 0.0, 1.0)
	var e := q * q * (3.0 - 2.0 * q)
	var h := lerpf(CUP_M, CUP_NEAR_M, e) * maxf(0.02, grow)
	# Gone into Dahrooj's wardrobe at the equip beat.
	var gone := clampf((t - 10.6) / 0.35, 0.0, 1.0)
	h *= 1.0 - gone
	cup.visible = gone < 1.0
	cup.position = _cup_pos()
	cup.scale = Vector3.ONE * maxf(1e-4, h * unit)
	# It spins as it rises, then turns slowly to show itself, facing the player at the end.
	var spin := (1.0 - grow) * 9.0 + t * 0.7 * (1.0 - e) + 0.25 * sin(t * 1.7) * e
	cup.basis = Basis(Vector3.UP, spin + atan2(fwd.x, fwd.z) + PI).scaled(cup.scale)


## The dancers: in, dancing, and away (positions about the centre, faces toward the player).
func _step_actors() -> void:
	drawn.clear()
	crowd.begin()
	var side := fwd.cross(Vector3.UP).normalized()
	var come := clampf(t / 2.2, 0.0, 1.0)
	var come_e := 1.0 - pow(1.0 - come, 3.0)
	var go := clampf((t - 11.2) / 2.0, 0.0, 1.0)
	var dance := clampf((t - 2.0) / 0.6, 0.0, 1.0) * (1.0 - go)
	var k := 0
	for ri in 2:
		var ring: Dictionary = INNER if ri == 0 else OUTER
		var n: int = ring.n
		var size: float = float(ring.size_m) * unit
		for i in n:
			var a := TAU * (i + 0.5) / n + float(ring.spin) * maxf(0.0, t - 1.0)
			# They come in from further ahead and hop away the same way: never toward the player.
			var r := float(ring.r_m) * lerpf(0.6, 1.0, come_e) * unit
			var away := (2.5 * (1.0 - come_e) + 3.0 * go * go) * unit
			var at := centre + (side * sin(a) + fwd * cos(a)) * r + fwd * away
			var phase := fposmod(t * 1.7 + i * 0.13 + (0.5 if ri == 1 else 0.0), 1.0)
			# Hops (the wave travels around the ring), squash on landing, stretch on the way up.
			var hop := sin(PI * phase)
			var walk := (1.0 - dance) * 0.35 * absf(sin(t * 9.0 + i))
			var up := (hop * 0.2 * dance + walk * 0.12) * unit
			var sy := 1.0 + dance * (0.14 * pow(cos(PI * phase), 2.0) - 0.3 * exp(-pow(minf(phase, 1.0 - phase) / 0.06, 2.0)))
			var sq := Vector2(1.0 / sqrt(maxf(0.4, sy)), sy)
			var grow := clampf(come * 3.0, 0.0, 1.0) * (1.0 - go)
			var rad := size * maxf(0.001, grow)
			var pos := at + Vector3.UP * (rad * sy + up)
			# Each one spins round now and then, in turn.
			var spin_ph := fposmod(t * 0.33 + float(i) / n, 1.0)
			var spin := TAU * smoothstep(0.0, 0.18, spin_ph) * dance
			var look := (Vector3(eye.x, pos.y, eye.z) - pos).normalized().rotated(Vector3.UP, spin)
			var eyes := "wide" if hop > 0.75 else ("shut" if fposmod(t * 0.7 + i * 0.37, 1.0) < 0.04 else "open")
			var style: String = DahroojLooks.STYLES[(i + 2 * ri) % DahroojLooks.STYLES.size()]
			var hex: String = COLORS[(i * 3 + k) % COLORS.size()]
			var col: Variant = null
			if hex != "" and style in DahroojLooks.TINTED:
				col = Color(hex)
			crowd.add(style, pos, rad, pos + look, sq, eyes, _acc(k), col)
			drawn.append([pos, rad])
			k += 1
	# The moles: up out of their holes, a look around, back down.
	for i in _moles.size():
		var m: Dictionary = _moles[i]
		var hole := holes[i]
		var mt := t - float(m.t0)
		var cyc := fposmod(mt, MOLE_UP + 1.6)
		var up_k := 0.0
		if mt >= 0.0 and t < 11.4 and cyc < MOLE_UP:
			up_k = sin(PI * clampf(cyc / MOLE_UP, 0.0, 1.0))
		var base := centre + (m.at as Vector3)
		hole.visible = mt > -0.4 and t < 12.0
		hole.position = base + Vector3.UP * 0.006 * unit
		hole.scale = Vector3(0.12, 1.0, 0.12) * unit * clampf((mt + 0.4) / 0.3, 0.0, 1.0) * clampf((12.0 - t) / 0.5, 0.0, 1.0)
		if up_k <= 0.01:
			continue
		if cyc < 0.08 and int(m.get("popped", -1)) != int(mt / (MOLE_UP + 1.6)):
			m.popped = int(mt / (MOLE_UP + 1.6))
			_sfx("start_pop", 0.7, base)
		var rad := 0.1 * unit * (0.35 + 0.65 * up_k)
		var pos := base + Vector3.UP * rad * (0.15 + 0.75 * up_k)
		var sy := 1.0 + 0.15 * sin(cyc * 18.0) * up_k
		var look := (Vector3(eye.x, pos.y, eye.z) - pos).normalized().rotated(Vector3.UP, 0.5 * sin(cyc * 5.0))
		crowd.add(DahroojLooks.STYLES[i % DahroojLooks.STYLES.size()], pos, rad, pos + look, Vector2(1.0 / sqrt(sy), sy), "wide", _acc(INNER.n + OUTER.n + i))
		drawn.append([pos, rad])
	# The giant, behind the ring: grows up out of the floor, bounces slowly, beams at you.
	var g_on := clampf((t - 0.4) / 1.8, 0.0, 1.0) * (1.0 - clampf((t - 11.6) / 1.6, 0.0, 1.0))
	if g_on > 0.0:
		var gph := fposmod(t * 0.9, 1.0)
		var gsy := 1.0 + 0.1 * cos(TAU * gph) * dance
		var grad := GIANT_M * unit * (1.0 - pow(1.0 - g_on, 3.0))
		var gpos := centre + fwd * GIANT_BACK_M * unit + side * GIANT_SIDE_M * unit + Vector3.UP * (grad * gsy + 0.15 * unit * absf(sin(PI * gph)) * dance)
		crowd.add("jelly", gpos, grad, Vector3(eye.x, gpos.y, eye.z), Vector2(1.0 / sqrt(gsy), gsy), "wide" if dance > 0.5 else "open", "crown")
		drawn.append([gpos, grad])
	crowd.end()


func _step_fireworks() -> void:
	for f: Dictionary in _fireworks:
		if not f.launched and t >= float(f.t):
			f.launched = true
			_sfx("firework_launch", 1.0, f.p)
		if not f.bloomed and t >= float(f.t) + 0.45:
			f.bloomed = true
			if host.world_balls:
				host.world_balls.bloom(f.p)
			_buzz(0.25, 40)


func _ensure_texts() -> void:
	if banner != null:
		banner.set_text(Save.text("أبطال العالم!", "World Champion!"))
		sub.set_text(Save.text("أتممت دحروج", "You completed Dahrooj"))
		return
	banner = JuiceText.make("banner")
	banner.name = "FinaleBanner"
	add_child(banner)
	banner.set_text(Save.text("أبطال العالم!", "World Champion!"))
	sub = JuiceText.make("sub")
	sub.name = "FinaleSub"
	add_child(sub)
	sub.set_text(Save.text("أتممت دحروج", "You completed Dahrooj"))


func _step_texts(_dt: float) -> void:
	if banner == null or not banner.visible:
		return
	var k := 0.9 * unit / 2.0
	var fade := clampf((12.4 - t) / 1.0, 0.0, 1.0)
	banner.scale = Vector3.ONE * k * (1.0 + 0.04 * sin(t * 3.0))
	sub.scale = Vector3.ONE * k
	banner.position = centre + Vector3.UP * (2.2 + 0.05 * sin(t * 1.5)) * unit
	banner.modulate = Color(1, 1, 1, fade)
	sub.modulate = Color(1, 1, 1, fade)
	if fade <= 0.0:
		banner.visible = false
		sub.visible = false


func _sfx(n: String, k: float, p: Vector3) -> void:
	if host and host.has_method("sfx"):
		host.sfx(n, k, p)


func _buzz(amp: float, ms: float) -> void:
	if host and host.has_method("buzz"):
		host.buzz("left", amp, ms)
		host.buzz("right", amp, ms)
