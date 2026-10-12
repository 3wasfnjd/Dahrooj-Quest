extends Node
## Local settings and progress (user://dahrooj.json). Autoload "Save".

const PATH := "user://dahrooj.json"
const VERSION := 1

var language := ""  # "ar" | "en"; empty follows the headset language
var mode := "vr"  # "vr" | "mr"
var haptics := true
var quality := "high"
var muted := false
var throw_style := "trigger"  # trigger | hand | sling (xr-runtime.js throwStyle)
var shot_style := ""  # bolt | mini | bubble | firework; empty until picked (SHOT_STYLE)
var counts := {}  # mode id -> scores this session's best
var best := {}
var challenges := {}  # challenge id -> value (store.data.challenges)
var styles_used: Array = []
## Dahrooj's look (store.ts defaults: fur, pink, nothing worn): jelly | fur | bubble; an
## appearance.ts DAHROOJ_COLOR_CHOICES id; an accessory id ("" for none).
var style := "fur"
var jelly_color := "pink"
var accessory := ""


func _ready() -> void:
	load_data()


func arabic() -> bool:
	if language != "":
		return language == "ar"
	return OS.get_locale_language() != "en"


func text(ar: String, en: String) -> String:
	return ar if arabic() else en


func load_data() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	language = String(d.get("language", language))
	mode = String(d.get("mode", mode))
	haptics = bool(d.get("haptics", haptics))
	quality = String(d.get("quality", quality))
	muted = bool(d.get("muted", muted))
	throw_style = String(d.get("throw_style", throw_style))
	shot_style = String(d.get("shot_style", shot_style))
	challenges = d.get("challenges", {}) if typeof(d.get("challenges", {})) == TYPE_DICTIONARY else {}
	styles_used = d.get("styles_used", []) if typeof(d.get("styles_used", [])) == TYPE_ARRAY else []
	best = d.get("best", {}) if typeof(d.get("best", {})) == TYPE_DICTIONARY else {}
	var look := DahroojLooks.load_look(d, challenges)
	style = look.style
	jelly_color = look.jelly_color
	accessory = look.accessory


func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"version": VERSION, "language": language, "mode": mode, "haptics": haptics,
		"quality": quality, "muted": muted, "throw_style": throw_style, "shot_style": shot_style, "best": best, "challenges": challenges, "styles_used": styles_used,
		"style": style, "jelly_color": jelly_color, "accessory": accessory}))
