class_name GameAudio
extends Node
## Every sound of the web game, played from files rendered out of its ORIGINAL Web Audio code
## (quest-native/tools/audio/render_audio.mjs -> res://assets/audio/).
##
## SFX files carry the web SFX bus already (sounds.js sfxDest: gain 2.2 into a limiter -8 dB / 12:1),
## so they play at 0 dB; only the per-call gain law (e.g. thump's .05+.28*s) is applied here, relative
## to the variant picked. Spatial sounds use the web panner's law: inverse distance, refDistance =
## ref_distance (sounds.js setListener's `ref`, the world scale), rolloff 1, no distance filter.
## Music: music.js into musicGain .067 (no limiter). Ambience: ambience.js, out gain .7, its beds
## (rain, crickets) and events (birds, pond plops, frogs) scheduled as in its update().

## Web mix (read from sounds.js / ambience.js).
const MUSIC_GAIN := 0.067        # sounds.js unlock(): musicGain.gain.value=.067 -> destination
const AMBIENCE_OUT := 0.7        # ambience.js: out gain .7 while on (events are rendered with it)
## Fixed scales render_audio.mjs applied to the long files (file = original * SCALE).
const SCALE_MUSIC := 0.5
const SCALE_RAIN := 0.35
const SCALE_CRICKETS := 1.0
const MUSIC_INTRO_SECONDS := 5.0 # music.js: two bars of strum (8 beats at 96 bpm), then a 60 s loop

const DIR := "res://assets/audio/"

## name -> {k: rendered values of the call's parameter (empty = none), n: random variants (0 = one file),
## law: [a, b] amplitude a+b*k of the original call (empty = level does not depend on k), ui: plays
## without a panner in the original}.
const SFX := {
	"thump": {"k": [0.25, 0.5, 0.75, 1.0], "n": 0, "law": [0.05, 0.28]},       # sounds.js thump(s)
	"squeak": {"k": [0.7, 1.0, 1.15, 1.35], "n": 0, "law": []},                # squeak(pitch)
	"pew": {"k": [], "n": 3, "law": []},                                       # pew()
	"splash": {"k": [0.25, 0.5, 0.75, 1.0], "n": 3, "law": [0.06, 0.16]},      # splash(k)
	"boom": {"k": [], "n": 3, "law": []},                                      # boom() (includes its thump(1))
	"whoosh": {"k": [0.2, 0.4, 0.6, 0.8, 1.0], "n": 0, "law": []},             # whoosh(p)
	"swish": {"k": [], "n": 3, "law": []},                                     # swish()
	"chime": {"k": [], "n": 0, "law": [], "ui": true},                         # chime() -> sfxDest, never panned
	"start_pop": {"k": [], "n": 0, "law": []},                                 # startPopSound()
	"firework_launch": {"k": [], "n": 3, "law": [], "cycle": true},            # firework-audio.ts play('launch')
	"firework_burst": {"k": [], "n": 3, "law": [], "cycle": true},             # play('burst')
	"cans_clang": {"k": [0.25, 0.5, 0.75, 1.0], "n": 3, "law": [0.02, 0.07]},  # stages/cans.js clang(s)
	"bowling_clack": {"k": [0.25, 0.5, 0.75, 1.0], "n": 3, "law": [0.012, 0.05]}, # stages/bowling.js clack(s)
	"bricks_tink": {"k": [0.0, 0.25, 0.5, 0.75, 1.0], "n": 0, "law": []},     # stages/bricks.js tink(k)
	"fair_ding": {"k": [], "n": 0, "law": []},                                 # stages/fair.js ding()
}
const BIRD_KINDS := 4
const BIRD_VARIANTS := 2
const AMB_EVENT_VARIANTS := 3

## sounds.js setListener ref: the panner refDistance (world scale; 1 at life size).
@export var ref_distance: float = 1.0
@export var pool_size: int = 16
## Ambience inputs (nature.js): 0 day .. 1 night, rain and snow 0..1, trees and the pond (game space).
@export var night: float = 0.0
@export var rain: float = 0.0
@export var snow: float = 0.0
@export var tree_spots: PackedVector3Array = PackedVector3Array()
@export var pond_center: Vector3 = Vector3.ZERO
@export var pond_radii: Vector2 = Vector2.ZERO  # (rx, rz); zero = no pond, no plops or frogs
## Where the listener is; defaults to the active camera.
var listener_override: Node3D = null

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer3D] = []
var _ui: Array[AudioStreamPlayer] = []
var _next3d: int = 0
var _next_ui: int = 0
var _cycle: Dictionary = {}
var _music: AudioStreamPlayer = null
var _amb_on: bool = false
var _amb_out: float = 0.0
var _rain_level: float = 0.0
var _cricket_level: float = 0.0
var _rain: AudioStreamPlayer = null
var _crickets: Array[AudioStreamPlayer3D] = []
var _wait := {"bird": 2.0, "plop": 5.0, "frog": 6.0}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_ensure_players()


func _ensure_players() -> void:
	if not _pool.is_empty():
		return
	for i in pool_size:
		var p := AudioStreamPlayer3D.new()
		_setup_3d(p, ref_distance)
		add_child(p)
		_pool.append(p)
	for i in 4:
		var u := AudioStreamPlayer.new()
		add_child(u)
		_ui.append(u)


func _setup_3d(p: AudioStreamPlayer3D, unit: float) -> void:
	# The web panner: inverse distance from refDistance, rolloff 1, no gain above 1, no air filter.
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.unit_size = unit
	p.max_db = 0.0
	p.max_distance = 0.0
	p.attenuation_filter_db = 0.0
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED


## Lazily loaded stream for a file name (without extension).
func stream(file: String) -> AudioStream:
	if _streams.has(file):
		return _streams[file]
	var s: AudioStream = null
	for ext in [".wav", ".ogg"]:
		var path: String = DIR + file + ext
		if ResourceLoader.exists(path):
			s = load(path) as AudioStream
			break
	_streams[file] = s
	return s


static func _tag(k: float) -> String:
	return "_k%02d" % int(round(k * 100.0))


## Every audio file this player uses (without extension), for checks.
static func all_files() -> PackedStringArray:
	var out := PackedStringArray()
	for snd: String in SFX:
		var e: Dictionary = SFX[snd]
		var ks: Array = e.k
		var n: int = e.n
		var tags: Array[String] = []
		if ks.is_empty():
			tags.append("")
		else:
			for k: float in ks:
				tags.append(_tag(k))
		for t in tags:
			if n == 0:
				out.append(snd + t)
			else:
				for i in n:
					out.append("%s%s_%d" % [snd, t, i + 1])
	for kind in BIRD_KINDS:
		for i in BIRD_VARIANTS:
			out.append("amb_bird_%d_%d" % [kind, i + 1])
	for i in AMB_EVENT_VARIANTS:
		out.append("amb_plop_%d" % (i + 1))
		out.append("amb_frog_%d" % (i + 1))
	out.append_array(PackedStringArray(["amb_rain_loop", "amb_crickets_loop", "music"]))
	return out


## The file and the volume (dB) for a call like the original name(k).
func pick(snd: String, k: float) -> Array:
	var e: Dictionary = SFX[snd]
	var ks: Array = e.k
	var file: String = snd
	var db := 0.0
	if not ks.is_empty():
		var best: float = ks[0]
		for v: float in ks:
			if absf(v - k) < absf(best - k):
				best = v
		file += _tag(best)
		var law: Array = e.law
		if not law.is_empty():
			var a: float = law[0]
			var b: float = law[1]
			db = linear_to_db(maxf(a + b * clampf(k, 0.0, 1.0), 1e-4) / (a + b * best))
	var n: int = e.n
	if n > 0:
		var i: int
		if e.get("cycle", false):
			i = int(_cycle.get(snd, 0)) % n
			_cycle[snd] = i + 1
		else:
			i = _rng.randi_range(0, n - 1)
		file += "_%d" % (i + 1)
	return [file, db]


## Plays a sound effect. k: the original call's parameter (intensity, pitch or power). pos: world space.
## spatial=false plays it like the web did without playAt (straight into the SFX bus).
func sfx(snd: String, k: float = 0.5, pos: Vector3 = Vector3.ZERO, spatial: bool = true) -> void:
	if not SFX.has(snd):
		push_warning("GameAudio: unknown sound " + snd)
		return
	var e: Dictionary = SFX[snd]
	var chosen: Array = pick(snd, k)
	var s := stream(chosen[0])
	if s == null:
		return
	var vol: float = chosen[1]
	if spatial and not e.get("ui", false):
		_play3d(s, vol, pos, ref_distance)
	else:
		_play_ui(s, vol)


## A sound without a panner (UI).
func ui(snd: String, k: float = 0.5) -> void:
	sfx(snd, k, Vector3.ZERO, false)


func _play3d(s: AudioStream, vol: float, pos: Vector3, unit: float) -> void:
	_ensure_players()
	if not is_inside_tree():
		return
	var p := _pool[_next3d]
	_next3d = (_next3d + 1) % _pool.size()
	p.stop()
	p.stream = s
	p.unit_size = unit
	p.volume_db = vol
	p.max_db = maxf(0.0, vol)
	p.global_position = pos
	p.play()


func _play_ui(s: AudioStream, vol: float) -> void:
	_ensure_players()
	if not is_inside_tree():
		return
	var u := _ui[_next_ui]
	_next_ui = (_next_ui + 1) % _ui.size()
	u.stop()
	u.stream = s
	u.volume_db = vol
	u.play()


## The background tune: two bars of intro, then its 60 s loop, at the web level (musicGain .067).
func music(on: bool) -> void:
	if on:
		if _music == null:
			var s := stream("music") as AudioStreamOggVorbis
			if s == null:
				return
			s.loop = true
			s.loop_offset = MUSIC_INTRO_SECONDS
			_music = AudioStreamPlayer.new()
			_music.stream = s
			_music.volume_db = linear_to_db(MUSIC_GAIN / SCALE_MUSIC)
			add_child(_music)
		if is_inside_tree() and not _music.playing:
			_music.play()
	elif _music != null:
		_music.stop()


## Motri's world sounds (ambience.js): birds by day, crickets and frogs at night, pond plops, rain.
func ambience(on: bool) -> void:
	_amb_on = on
	if on and _rain == null:
		var r := stream("amb_rain_loop") as AudioStreamOggVorbis
		var c := stream("amb_crickets_loop") as AudioStreamOggVorbis
		if r == null or c == null:
			return
		r.loop = true
		c.loop = true
		_rain = AudioStreamPlayer.new()
		_rain.stream = r
		_rain.volume_db = -80.0
		add_child(_rain)
		for i in 3:
			var p := AudioStreamPlayer3D.new()
			_setup_3d(p, 3.0)
			p.stream = c
			p.pitch_scale = [1.0, 0.93, 1.07][i]
			p.volume_db = -80.0
			add_child(p)
			_crickets.append(p)
	if on and is_inside_tree():
		if not _rain.playing:
			_rain.play()
		for p in _crickets:
			if not p.playing:
				p.play(_rng.randf() * 0.1)


func set_environment(night_amount: float, rain_amount: float, snow_amount: float) -> void:
	night = night_amount
	rain = rain_amount
	snow = snow_amount


## Mutes everything (the web suspends its AudioContext when the game loses focus).
func set_muted(m: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), m)


func _eye() -> Vector3:
	if listener_override != null:
		return listener_override.global_position
	var vp := get_viewport()
	var cam: Camera3D = vp.get_camera_3d() if vp != null else null
	return cam.global_position if cam != null else Vector3.ZERO


static func _approach(v: float, target: float, tc: float, dt: float) -> float:
	# AudioParam.setTargetAtTime
	return target + (v - target) * exp(-dt / tc)


func _process(dt: float) -> void:
	if _rain == null or not is_inside_tree():
		return
	_amb_out = _approach(_amb_out, AMBIENCE_OUT if _amb_on else 0.0, 0.6, dt)
	var r := clampf(rain, 0.0, 1.0)
	var sn := clampf(snow, 0.0, 1.0)
	_rain_level = _approach(_rain_level, r * r * 0.03 * (1.0 - sn * 0.9), 0.8, dt)
	_cricket_level = _approach(_cricket_level, night * 0.06 * (1.0 - r * 0.8) * (1.0 - sn), 1.5, dt)
	_rain.volume_db = linear_to_db(maxf(_rain_level * _amb_out / SCALE_RAIN, 1e-5))
	var eye := _eye()
	for i in _crickets.size():
		var p := _crickets[i]
		p.volume_db = linear_to_db(maxf(_cricket_level * _amb_out / SCALE_CRICKETS, 1e-5))
		var a := i * 2.1 + 0.4
		var rad := 5.0 + i * 2.0
		p.global_position = Vector3(eye.x + cos(a) * rad, 0.3, eye.z + sin(a) * rad)
	if not _amb_on:
		if _amb_out < 0.01 and _rain.playing:
			_rain.stop()
			for p in _crickets:
				p.stop()
		return
	dt = clampf(dt, 0.0, 0.5)
	var ev := _amb_out / AMBIENCE_OUT  # events are rendered with out .7
	var day := (1.0 - night) * (1.0 - r * 0.9) * (1.0 - sn)
	_wait.bird -= dt
	if _wait.bird <= 0.0:
		_wait.bird = _rng.randf_range(1.2, 4.5) / maxf(0.3, day)
		if day > 0.2:
			var spot := Vector3(eye.x + _rng.randf_range(-20.0, 20.0), 0.0, eye.z - 20.0)
			if not tree_spots.is_empty():
				var near := Array(tree_spots)
				near.sort_custom(func(p: Vector3, q: Vector3) -> bool: return Vector2(p.x - eye.x, p.z - eye.z).length() < Vector2(q.x - eye.x, q.z - eye.z).length())
				spot = near[_rng.randi_range(0, mini(10, near.size()) - 1)]
			var f := "amb_bird_%d_%d" % [_rng.randi_range(0, BIRD_KINDS - 1), _rng.randi_range(1, BIRD_VARIANTS)]
			_play_event(f, Vector3(spot.x, _rng.randf_range(3.5, 6.0), spot.z), 9.0, ev)
	if pond_radii == Vector2.ZERO:
		return
	var pc := pond_center
	_wait.plop -= dt
	if _wait.plop <= 0.0:
		_wait.plop = _rng.randf_range(2.5, 7.0)
		if sn < 0.5 and Vector2(eye.x - pc.x, eye.z - pc.z).length() < pond_radii.y + 14.0:
			var a := _rng.randf() * TAU
			var rr := sqrt(_rng.randf()) * 0.8
			_play_event("amb_plop_%d" % _rng.randi_range(1, AMB_EVENT_VARIANTS), Vector3(pc.x + cos(a) * pond_radii.x * rr, 0.0, pc.z + sin(a) * pond_radii.y * rr), 3.0, ev)
	_wait.frog -= dt
	if _wait.frog <= 0.0:
		_wait.frog = _rng.randf_range(3.0, 8.0)
		if night > 0.5 and sn < 0.3:
			var a := _rng.randf() * TAU
			_play_event("amb_frog_%d" % _rng.randi_range(1, AMB_EVENT_VARIANTS), Vector3(pc.x + cos(a) * pond_radii.x * 1.05, 0.1, pc.z + sin(a) * pond_radii.y * 1.05), 3.0, ev)


func _play_event(file: String, pos: Vector3, unit: float, level: float) -> void:
	var s := stream(file)
	if s != null:
		_play3d(s, linear_to_db(maxf(level, 1e-4)), pos, unit)
