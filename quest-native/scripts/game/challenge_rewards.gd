class_name ChallengeRewards
extends RefCounted
## One reward per challenge: every challenge (GameRuntime.CHALLENGES) opens exactly one
## accessory (MenuCatalog.ACCESSORIES), shot style (ShotCatalog.SHOT_UNLOCKS) or Dahrooj
## colour (MenuCatalog.COLORS). Those lists hold the links (each locked item names its
## challenge); this class reads them back: the reward of a challenge, what is open now,
## and the unlock cards main.gd shows when something new opens.

## The challenges that need a reward of another to be played (a shot style to fire, an
## accessory to wear): challenge id -> "kind:id".
const REQUIRES := {
	"firework10": "shot:firework", "bouncy3": "shot:bouncy", "laser30": "shot:laser",
	"boomerang3": "shot:boomerang", "rocket20": "shot:rocket", "chain4": "shot:lightning",
	"dallah15": "shot:dallah", "shemaghPlay": "acc:shemagh",
}
## Accessories that opened by a count of finished challenges before every reward had its
## own challenge: a save from then keeps them (Save.load_data, rewards_version 1).
const LEGACY_COUNTS := {"party": 1, "glasses": 3, "cap": 5, "flower": 7, "crown": 10, "headphones": 12, "scarf": 14}


## Every reward a challenge opens: [{kind: "acc" | "shot" | "color", id, need, ar, en,
## icon, hex}] in the menus' order (accessories, shots, colours).
static func all() -> Array:
	var out: Array = []
	for a: Array in MenuCatalog.ACCESSORIES:
		if a[3] is String and str(a[3]) != "":
			out.append({"kind": "acc", "id": a[0], "need": str(a[3]), "ar": a[1], "en": a[2], "icon": a[0], "hex": ""})
	for id: String in ShotCatalog.ORDER:
		var n: Variant = ShotCatalog.need(id)
		if n is String and str(n) != "":
			var info := ShotCatalog.info(id)
			out.append({"kind": "shot", "id": id, "need": str(n), "ar": str(info.get("ar", id)), "en": str(info.get("en", id)),
				"icon": str(info.get("icon", id)), "hex": ""})
	for c: Array in MenuCatalog.COLORS:
		if c.size() > 4 and str(c[4]) != "":
			out.append({"kind": "color", "id": c[0], "need": str(c[4]), "ar": c[1], "en": c[2], "icon": "palette", "hex": c[3]})
	return out


## The rewards challenge `ch` opens (exactly one for each challenge of the game).
static func rewards_for(ch: String) -> Array:
	var out: Array = []
	for r: Dictionary in all():
		if r.need == ch:
			out.append(r)
	return out


## The reward of challenge `ch`, or {}.
static func reward_of(ch: String) -> Dictionary:
	var r := rewards_for(ch)
	return r[0] if not r.is_empty() else {}


## "kind:id" of a reward.
static func key(r: Dictionary) -> String:
	return "%s:%s" % [r.kind, r.id]


## Whether a reward is open with this progress (Save.challenges).
static func is_open(kind: String, id: String, progress: Dictionary) -> bool:
	match kind:
		"acc":
			return MenuCatalog.accessory_available(id, DahroojLooks.done_count(progress), progress)
		"shot":
			return ShotCatalog.open_now(id, progress)
		"color":
			return MenuCatalog.color_available(id, progress)
	return false


## The rewards open now: "kind:id" -> reward.
static func open_now(progress: Dictionary) -> Dictionary:
	var out := {}
	for r: Dictionary in all():
		if is_open(r.kind, r.id, progress):
			out[key(r)] = r
	return out


## The card for a reward that just opened: {kind: "reward", reward, title, sub} (Arabic or
## English): «فتحت طلقة …!» for a shot, «فتحت لون …!» for a colour, «فتحت …!» otherwise.
static func card(r: Dictionary, arabic: bool) -> Dictionary:
	var title := ""
	var sub := ""
	match str(r.kind):
		"shot":
			title = "فتحت طلقة %s!" % r.ar if arabic else "Unlocked shot %s!" % r.en
			sub = "اخترها من اللعب ← نوع الطلقة" if arabic else "Pick it in Play → Projectile"
		"color":
			title = "فتحت لون %s!" % r.ar if arabic else "Unlocked colour %s!" % r.en
			sub = "اختره من المظهر ← لون دحروج" if arabic else "Pick it in Appearance → Dahrooj’s colour"
		_:
			title = "فتحت %s!" % r.ar if arabic else "%s unlocked!" % r.en
			sub = "البسها من المظهر ← الإكسسوارات" if arabic else "Equip from Appearance → Accessories"
	return {"kind": "reward", "reward": r, "title": title, "sub": sub}


## What opened since the last look: known is the "kind:id" set seen last time (empty on the
## first look, which only takes note). Returns {known: the new set, cards: [card()]}.
static func watch(known: Dictionary, progress: Dictionary, arabic: bool) -> Dictionary:
	var open := open_now(progress)
	var cards: Array = []
	if known.has("_init"):
		for k: String in open:
			if not known.has(k):
				cards.append(card(open[k], arabic))
	var next := {"_init": true}
	for k: String in open:
		next[k] = true
	return {"known": next, "cards": cards}


## A save from before the one-reward-per-challenge links keeps the accessories its count
## had opened ("reward:<id>", which MenuCatalog.accessory_available honours).
static func migrate(progress: Dictionary) -> void:
	var done := DahroojLooks.done_count(progress)
	for id: String in LEGACY_COUNTS:
		if done >= int(LEGACY_COUNTS[id]):
			progress["reward:" + id] = 1


## The menu's line for a locked item: its challenge's title, [ar, en].
static func need_text(ch: String) -> Array:
	var c := MenuCatalog.challenge(ch)
	return [c[2], c[3]] if not c.is_empty() else ["", ""]
