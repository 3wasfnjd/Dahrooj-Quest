class_name ParkCycle
extends RefCounted
## DayCycles.js / YearCycles.js / Weather.js as nature.js runs them: a day every four
## minutes on the real clock (or a fixed time), the seasons on the real date, the
## weather from Weather.js's formulas (or a cycle / a forced spell), and the light,
## fog and sky colours that follow. Colours are kept in sRGB (as three.js lerps them)
## and converted to linear only for the shader globals.

const DAY_SECONDS := 4.0 * 60.0
const WEATHER_SECONDS := 6.0 * 60.0
const FIXED := {"day": 0.08, "dusk": 0.25, "night": 0.47, "dawn": 0.8}
const TIMES := ["auto", "day", "dusk", "night", "dawn"]
const WEATHERS := ["auto", "clear", "rain", "snow"]

static var DAY := {
	"day": {"light": Color("fff1dd"), "intensity": 1.35, "shadow": Color("8b9cae"), "fog_a": Color("dcebf4"), "fog_b": Color("83b7e0"), "near": 0.5, "far": 2.0, "temperature": 5.0},
	"dusk": {"light": Color("ffd5b2"), "intensity": 1.05, "shadow": Color("7c7694"), "fog_a": Color("e1b8ad"), "fog_b": Color("7a8dab"), "near": 0.5, "far": 2.0, "temperature": 0.0},
	"night": {"light": Color("b6caff"), "intensity": 0.45, "shadow": Color("263447"), "fog_a": Color("152740"), "fog_b": Color("050e23"), "near": 0.65, "far": 2.4, "temperature": -7.5},
	"dawn": {"light": Color("ffe0c2"), "intensity": 1.15, "shadow": Color("8891a8"), "fog_a": Color("f2d4bd"), "fog_b": Color("9dbbda"), "near": 0.5, "far": 2.0, "temperature": 0.0},
}
static var DAY_KEYS := [["day", 0.0], ["day", 0.15], ["dusk", 0.25], ["night", 0.35], ["night", 0.6], ["dawn", 0.8], ["day", 0.9]]
static var YEAR := {
	"winter": {"temperature": 5.0, "humidity": 0.8, "clouds": 0.65, "wind": 0.3},
	"spring": {"temperature": 15.0, "humidity": 0.65, "clouds": 0.45, "wind": 0.2},
	"summer": {"temperature": 25.0, "humidity": 0.5, "clouds": 0.3, "wind": 0.1},
	"fall": {"temperature": 15.0, "humidity": 0.65, "clouds": 0.65, "wind": 0.25},
}
static var YEAR_KEYS := [["winter", 0.125], ["spring", 0.375], ["summer", 0.625], ["fall", 0.875]]

var time := "auto"
var weather := "auto"
## Blended DayCycles values, YearCycles values and Weather.js state.
var d := {}
var y := {}
var w := {"temperature": 0.0, "humidity": 0.0, "clouds": 0.0, "wind": 0.0, "rain": 0.0, "snow": -1.0, "weather_phase": 0.0}
var day_p := 0.08
var night := 0.0
var stars := 0.0
var cloud := 0.0
var horizon := Color.WHITE
var zenith := Color.WHITE
var sun_dir := Vector3(0.5, 0.6, -0.6)
var fog_near := 32.5
var fog_far := 70.0
var light_intensity := 1.35
var wind_strength := 0.5
var wind_time := 0.0
var progress_delta := 0.0
var _last_day := -1.0
## The clock in seconds (unix time); tests may pin it.
var clock_override := -1.0


static func remap_clamp(v: float, a: float, b: float, c: float, e: float) -> float:
	return c + (e - c) * clampf((v - a) / (b - a), 0.0, 1.0)


static func _noise(x: float) -> float:
	return sin(x) * sin(x * 1.678) * sin(x * 2.345)


## Cycles.js: blend the neighbouring keyframes, wrapping around the end of the cycle.
static func blend(table: Dictionary, keys: Array, p: float, out: Dictionary) -> Dictionary:
	var n := keys.size()
	var ia := n - 1
	for i in n:
		if float(keys[i][1]) <= p:
			ia = i
	var a: Array = keys[ia]
	var b: Array = keys[(ia + 1) % n]
	var pa: float = a[1]
	var pb: float = b[1] if float(b[1]) > pa else float(b[1]) + 1.0
	var pp := p + 1.0 if p < pa else p
	var t := (pp - pa) / (pb - pa) if pb > pa else 0.0
	var va: Dictionary = table[a[0]]
	var vb: Dictionary = table[b[0]]
	for k in va:
		if va[k] is Color:
			out[k] = (va[k] as Color).lerp(vb[k], t)
		else:
			out[k] = lerpf(va[k], vb[k], t)
	return out


func set_settings(s: Dictionary) -> void:
	if s.has("time") and String(s.time) in TIMES:
		time = String(s.time)
	if s.has("weather") and String(s.weather) in WEATHERS:
		weather = String(s.weather)


func now() -> float:
	return clock_override if clock_override >= 0.0 else Time.get_unix_time_from_system()


func update(dt: float) -> void:
	var t := now()
	var day_abs := t / DAY_SECONDS
	if _last_day < 0.0:
		_last_day = day_abs
	progress_delta = maxf(0.0, day_abs - _last_day)
	_last_day = day_abs
	day_p = fposmod(day_abs, 1.0) if time == "auto" else float(FIXED[time])
	var year_p := fposmod(t / (60.0 * 60.0 * 24.0 * 365.0), 1.0)
	blend(DAY, DAY_KEYS, day_p, d)
	blend(YEAR, YEAR_KEYS, year_p, y)
	# Weather.js formulas.
	w.temperature = float(y.temperature) + float(d.temperature) + _noise(day_abs * 0.4) * 7.5
	w.humidity = float(y.humidity) + _noise(day_abs * 0.36) * 0.2
	w.clouds = _noise(day_abs * 0.44)
	w.wind = _noise(day_abs) * 0.5 + 0.5
	w.rain = remap_clamp(w.humidity, 0.65, 1.0, 0.0, 1.0) * remap_clamp(w.clouds, 0.0, 1.0, 0.0, 1.0)
	w.snow = remap_clamp(w.rain, 0.05, 0.3, 0.0, 1.0) * remap_clamp(w.temperature, 0.0, -5.0, 0.0, 1.0) + remap_clamp(w.temperature, 0.0, 10.0, 0.0, -1.0)
	# Auto: a cycle on the clock: clear, rain, clear, snow.
	if weather == "auto":
		var q := fposmod(t / WEATHER_SECONDS, 1.0)
		var band := func(a: float, b: float) -> float: return clampf(minf((q - a) / 0.04, (b - q) / 0.04), 0.0, 1.0)
		var rainy: float = band.call(0.22, 0.45)
		var snowy: float = band.call(0.68, 0.92)
		w.rain = maxf(rainy * 0.85, snowy * 0.8)
		w.snow = snowy * 2.0 - 1.0 if snowy > 0.0 else -1.0
		w.wind = maxf(w.wind, rainy * 0.65)
		w.weather_phase = q
	# The menu can force a spell, like Motri's weather override.
	if weather == "clear":
		w.rain = 0.0
		w.snow = -1.0
	elif weather == "rain":
		w.rain = 0.8
		w.snow = -1.0
		w.wind = maxf(w.wind, 0.6)
	elif weather == "snow":
		w.rain = 0.8
		w.snow = 1.0
	# A gentler sky than the raw fog colours: a pale horizon and a deep top, greyer when it rains.
	night = clampf(minf((day_p - 0.22) / 0.08, (0.75 - day_p) / 0.08), 0.0, 1.0)
	cloud = clampf(float(w.rain) * 1.2, 0.0, 1.0)
	var grey := Color("9aa0b0").lerp(Color("142036"), night)
	var fa: Color = d.fog_a
	var fb: Color = d.fog_b
	horizon = fa.lerp(Color.WHITE, 0.35 * (1.0 - night) + 0.012 * night).lerp(grey, cloud * 0.5)
	var grey7 := Color(grey.r * 0.7, grey.g * 0.7, grey.b * 0.7)
	zenith = fb.lerp(fa, 0.15).lerp(grey7, cloud * 0.6)
	var sa := day_p * PI * 2.0
	sun_dir = Vector3(cos(sa) * 0.6, 0.25 + 0.5 * absf(cos(sa * 0.5)), -0.75).normalized()
	stars = (1.0 - cloud) * clampf(minf((day_p - 0.25) / 0.1, (0.7 - day_p) / 0.1), 0.0, 1.0)
	fog_near = 20.0 + float(d.near) * 25.0
	fog_far = 20.0 + float(d.far) * 25.0
	light_intensity = float(d.intensity) * (1.0 - night * 0.35) + night * 0.18
	# Wind.js
	wind_strength = remap_clamp(w.wind, 0.0, 1.0, 0.1, 1.0)
	wind_time += dt * 0.1 * wind_strength
