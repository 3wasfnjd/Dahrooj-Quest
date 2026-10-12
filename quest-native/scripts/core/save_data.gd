extends Node
## Local settings and progress (user://dahrooj.json). Autoload "Save".

const PATH := "user://dahrooj.json"
const VERSION := 1

var language := ""  # "ar" | "en"; empty follows the headset language
var mode := "vr"  # "vr" | "mr"
var haptics := true
var quality := "high"
var muted := false
var counts := {}  # mode id -> scores this session's best
var best := {}


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
	best = d.get("best", {}) if typeof(d.get("best", {})) == TYPE_DICTIONARY else {}


func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"version": VERSION, "language": language, "mode": mode, "haptics": haptics,
		"quality": quality, "muted": muted, "best": best}))
