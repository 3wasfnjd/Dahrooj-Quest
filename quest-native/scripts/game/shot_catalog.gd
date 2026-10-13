class_name ShotCatalog
extends RefCounted
## The blaster's shot styles (the triggers fire them in every mode): their names, menu
## icons, what unlocks them and a line on each. WorldBalls takes its style list from
## here (its SHOT_STYLE holds the flight numbers); the menu's Play page shows them in
## this order (MenuCatalog.SHOTS).

## In menu order: the four first styles, then the ones challenges unlock.
const ORDER := ["bolt", "mini", "bubble", "firework", "confetti", "bouncy", "laser", "boomerang", "glob", "rocket", "lightning", "dallah"]

## What unlocks each style: "" = from the start; a String = that challenge id
## (GameRuntime.CHALLENGES) finished — each challenge opens one reward (ChallengeRewards);
## an int (a count of finished challenges) still works but none is used.
const SHOT_UNLOCKS := {
	"bolt": "", "mini": "", "bubble": "", "firework": "",
	"confetti": "hoop3", "bouncy": "firework10", "laser": "skyPop5", "boomerang": "pop20",
	"glob": "laser30", "rocket": "boomerang3", "lightning": "rocket20", "dallah": "chain4",
}

## id -> {ar, en, icon, sound (its firing sound, GameAudio), ar_desc, en_desc}
const SHOTS := {
	"bolt": {"ar": "برق", "en": "Bolt", "icon": "bolt", "sound": "pew",
		"ar_desc": "طلقة سريعة مضيئة بذيل ووميض", "en_desc": "A fast glowing bolt with a trail and a flash"},
	"mini": {"ar": "دحروج", "en": "Dahrooj", "icon": "mini", "sound": "whoosh",
		"ar_desc": "دحاريج صغيرة تتشقلب وترتد", "en_desc": "Little tumbling Dahroojs that bounce on"},
	"bubble": {"ar": "فقاعة", "en": "Bubble", "icon": "bubble", "sound": "whoosh",
		"ar_desc": "فقاعات صابون ملونة تتمايل ببطء", "en_desc": "Slow, wobbling rainbow soap bubbles"},
	"firework": {"ar": "ألعاب نارية", "en": "Firework", "icon": "firework", "sound": "firework_launch",
		"ar_desc": "صاروخ ناري يتفتح ويفرقع ما حوله", "en_desc": "A rocket that blooms and pops all around it"},
	"confetti": {"ar": "قصاصات", "en": "Confetti", "icon": "confetti", "sound": "swish",
		"ar_desc": "مدفع قصاصات: خمس كرات في مخروط", "en_desc": "Confetti cannon: five pellets in a cone"},
	"bouncy": {"ar": "نطّاطة", "en": "Bouncy", "icon": "bouncy", "sound": "squeak",
		"ar_desc": "كرة مطاطية ترتد عن كل شيء", "en_desc": "A rubber ball that bounces off everything"},
	"laser": {"ar": "ليزر", "en": "Laser", "icon": "laser", "sound": "pew",
		"ar_desc": "شعاع فوري يخترق حتى ٣ أهداف", "en_desc": "An instant beam through up to 3 targets"},
	"boomerang": {"ar": "بوميرانغ", "en": "Boomerang", "icon": "boomerang", "sound": "swish",
		"ar_desc": "ينطلق ويلتف ويعود إلى يدك", "en_desc": "Curves out and comes back to your hand"},
	"glob": {"ar": "جلي", "en": "Jelly", "icon": "glob", "sound": "squeak",
		"ar_desc": "كتلة جلي لزجة تترك بركة تفرقع", "en_desc": "A sticky glob that leaves a popping puddle"},
	"rocket": {"ar": "صاروخ", "en": "Rocket", "icon": "rocket", "sound": "whoosh",
		"ar_desc": "صاروخ موجّه ينفجر عند الهدف", "en_desc": "A homing rocket that explodes on its target"},
	"lightning": {"ar": "صاعقة", "en": "Lightning", "icon": "lightning", "sound": "cans_clang",
		"ar_desc": "صاعقة تقفز بين ٤ أهداف", "en_desc": "Lightning that chains through 4 targets"},
	"dallah": {"ar": "دلّة", "en": "Dallah", "icon": "dallah", "sound": "fair_ding",
		"ar_desc": "دلّة قهوة دوّارة ترش حبات البن", "en_desc": "A spinning coffee pot spraying coffee beans"},
}


static func ids() -> Array:
	return ORDER


static func has(id: String) -> bool:
	return SHOTS.has(id)


static func info(id: String) -> Dictionary:
	return SHOTS.get(id, {})


## What unlocks `id`: "" (open), an int count of finished challenges, or a challenge id.
static func need(id: String) -> Variant:
	return SHOT_UNLOCKS.get(id, "")


## Whether `id` can be picked: completed = finished challenges; progress = challenge id ->
## value (Save.challenges), plus "shot:<id>" = 1 for a style given some other way.
static func available(id: String, completed: int, progress: Dictionary) -> bool:
	if not SHOTS.has(id):
		return false
	if int(progress.get("shot:" + id, 0)) == 1:
		return true
	var n: Variant = need(id)
	if n is int:
		return completed >= int(n)
	if str(n) == "":
		return true
	var c := MenuCatalog.challenge(str(n))
	return not c.is_empty() and int(progress.get(c[0], 0)) >= int(c[1])


## available() from the saved progress alone (Save.challenges): what the menu and the
## blaster ask.
static func open_now(id: String, progress: Dictionary) -> bool:
	return available(id, done_count(progress), progress)


## How many challenges are finished (challenges.ts completedCount): every challenge of the
## game, as the accessories count them.
static func done_count(progress: Dictionary) -> int:
	return DahroojLooks.done_count(progress)


## The locked card's line, [ar, en]: "Needs N challenges" or the challenge's own title.
static func need_text(id: String) -> Array:
	var n: Variant = need(id)
	if n is int:
		return ["يحتاج %d تحديات" % int(n), "Needs %d challenges" % int(n)]
	var c := MenuCatalog.challenge(str(n))
	return [c[2], c[3]] if not c.is_empty() else ["", ""]
