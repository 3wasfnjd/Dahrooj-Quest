extends RefCounted
## One reward per challenge (ChallengeRewards): every challenge opens exactly one
## accessory, shot style or colour; every locked one is reachable by playing (a challenge
## that needs a shot or an accessory comes after the one that opens it); the easy
## challenges give the first rewards; the unlock cards («فتحت طلقة …!») come once; the
## new challenges count from the runtime (shots, modes, the shemagh); old saves keep what
## they had; the challenges page shows each reward.


static func run(check: Callable) -> void:
	_one_each(check)
	_reachable(check)
	_order(check)
	_cards(check)
	_runtime(check)
	_migrate(check)
	_page(check)


static func _ids() -> Array:
	var out: Array = []
	for c: Array in GameRuntime.CHALLENGES:
		out.append(c[0])
	return out


## Every challenge has exactly one reward; every reward names a real challenge, once.
static func _one_each(check: Callable) -> void:
	var bad: Array = []
	for id: String in _ids():
		var n := ChallengeRewards.rewards_for(id).size()
		if n != 1:
			bad.append("%s:%d" % [id, n])
	check.call(bad.is_empty(), "rewards: each of the %d challenges opens exactly one reward %s" % [_ids().size(), bad])
	var orphans: Array = []
	for r: Dictionary in ChallengeRewards.all():
		if not str(r.need) in _ids():
			orphans.append(ChallengeRewards.key(r))
	check.call(orphans.is_empty() and ChallengeRewards.all().size() == _ids().size(), "rewards: every locked item names a challenge of the game %s" % [orphans])
	var kinds := {"acc": 0, "shot": 0, "color": 0}
	for r: Dictionary in ChallengeRewards.all():
		kinds[r.kind] = int(kinds[r.kind]) + 1
	check.call(int(kinds.acc) == MenuCatalog.ACCESSORIES.size() - 1 and int(kinds.shot) == ShotCatalog.ids().size() - 4 and int(kinds.color) == 6,
		"rewards: all accessories but None, the shots but the first four, six colours (%s)" % [kinds])
	var counted := true
	for a: Array in MenuCatalog.ACCESSORIES:
		counted = counted and (a[3] is String or a[0] == "")
	for id: String in ShotCatalog.ids():
		counted = counted and ShotCatalog.need(id) is String
	check.call(counted, "rewards: no reward opens by a count of challenges any more")
	# The starters are open with nothing done.
	var none := {}
	var open_ok := MenuCatalog.accessory_available("", 0, none) and MenuCatalog.color_available("original", none) and MenuCatalog.color_available("pink", none)
	for id: String in ["bolt", "mini", "bubble", "firework"]:
		open_ok = open_ok and ShotCatalog.open_now(id, none)
	check.call(open_ok and ChallengeRewards.open_now(none).is_empty(), "rewards: the starters (None, the first four shots, original and pink) are open from the start")
	# And each one opens with its challenge, not before.
	var wrong: Array = []
	for r: Dictionary in ChallengeRewards.all():
		var c := GameRuntime.challenge(str(r.need))
		var almost := {str(r.need): int(c[3]) - 1}
		var done := {str(r.need): int(c[3])}
		if ChallengeRewards.is_open(r.kind, r.id, almost) or not ChallengeRewards.is_open(r.kind, r.id, done):
			wrong.append(ChallengeRewards.key(r))
	check.call(wrong.is_empty(), "rewards: each opens exactly when its challenge is finished %s" % [wrong])


## From nothing, finishing every challenge that can be played (its shot or accessory open)
## opens everything: no locked item is out of reach.
static func _reachable(check: Callable) -> void:
	var progress := {}
	var changed := true
	var rounds := 0
	while changed and rounds < 100:
		changed = false
		rounds += 1
		for c: Array in GameRuntime.CHALLENGES:
			if int(progress.get(c[0], 0)) >= int(c[3]):
				continue
			var req := str(ChallengeRewards.REQUIRES.get(c[0], ""))
			if req != "" and not ChallengeRewards.is_open(req.get_slice(":", 0), req.get_slice(":", 1), progress):
				continue
			progress[c[0]] = c[3]
			changed = true
	var locked: Array = []
	for r: Dictionary in ChallengeRewards.all():
		if not ChallengeRewards.is_open(r.kind, r.id, progress):
			locked.append(ChallengeRewards.key(r))
	check.call(locked.is_empty() and DahroojLooks.done_count(progress) == GameRuntime.CHALLENGES.size(), "rewards: every locked accessory, shot and colour is reachable %s" % [locked])
	var reqs_ok := true
	for ch: String in ChallengeRewards.REQUIRES:
		var req := str(ChallengeRewards.REQUIRES[ch])
		reqs_ok = reqs_ok and ch in _ids() and _ids().find(ch) > _ids().find(_opener(req))
	check.call(reqs_ok, "rewards: a challenge that needs a shot or an accessory comes after the one that opens it")


## The challenge that opens "kind:id" ("" for a starter).
static func _opener(k: String) -> String:
	for r: Dictionary in ChallengeRewards.all():
		if ChallengeRewards.key(r) == k:
			return str(r.need)
	return ""


## Easy first: the accessories and the shots come in the order their challenges do.
static func _order(check: Callable) -> void:
	var ids := _ids()
	var acc: Array = []
	for a: Array in MenuCatalog.ACCESSORIES:
		if a[3] is String:
			acc.append(ids.find(str(a[3])))
	var shots: Array = []
	for id: String in ShotCatalog.ids():
		if str(ShotCatalog.need(id)) != "":
			shots.append(ids.find(str(ShotCatalog.need(id))))
	var sa := acc.duplicate()
	sa.sort()
	var ss := shots.duplicate()
	ss.sort()
	check.call(acc == sa and shots == ss, "rewards: accessories and shots open in their menu order, the easiest challenges first")
	check.call(ChallengeRewards.reward_of("keeper3").id == "party" and ChallengeRewards.reward_of("hoop3").id == "confetti"
		and ChallengeRewards.reward_of("mazeClean").id == "beanie", "rewards: the first goals give the party hat and the confetti shot")


## The unlock cards: none on the first look, then one for each new reward.
static func _cards(check: Callable) -> void:
	var w := ChallengeRewards.watch({}, {}, true)
	check.call(w.cards.is_empty() and w.known.has("_init"), "reward cards: the first look only takes note")
	var p := {"hoop3": 3}
	var w2 := ChallengeRewards.watch(w.known, p, true)
	check.call(w2.cards.size() == 1 and w2.cards[0].title == "فتحت طلقة قصاصات!" and w2.cards[0].kind == "reward",
		"reward cards: «فتحت طلقة قصاصات!» when a shot opens %s" % [w2.cards])
	var w3 := ChallengeRewards.watch(w2.known, p, true)
	check.call(w3.cards.is_empty(), "reward cards: once only")
	p["keeper3"] = 3
	p["windowMin"] = 1
	var w4 := ChallengeRewards.watch(w3.known, p, false)
	var titles: Array = []
	for c: Dictionary in w4.cards:
		titles.append(c.title)
	check.call(titles.size() == 2 and "Party hat unlocked!" in titles and "Unlocked colour Orange!" in titles,
		"reward cards: an accessory and a colour, in English %s" % [titles])
	var en := ChallengeRewards.card(ChallengeRewards.reward_of("skyPop5"), false)
	check.call(en.title == "Unlocked shot Laser!" and str(en.sub) != "", "reward cards: \"Unlocked shot Laser!\"")


## The runtime counts the new challenges: shot hits, different modes, the shemagh worn.
static func _runtime(check: Callable) -> void:
	var path: String = Save.PATH
	var had := FileAccess.file_exists(path)
	var before := FileAccess.get_file_as_string(path) if had else ""
	var keep: Dictionary = Save.challenges.duplicate(true)
	Save.challenges.clear()
	var b := Ball.new()
	var parent := Node3D.new()
	var rt := GameRuntime.new(b, parent)
	var toasts: Array = []
	rt.ctx.toast = func(t: String) -> void: toasts.append(t)
	rt.shot_hits("laser", 12)
	rt.shot_hits("laser", 20)
	rt.shot_hits("bean", 3)
	rt.shot_hits("bolt", 5)
	rt.shot_hits("rocket", 0)
	check.call(int(Save.challenges.get("laser30", 0)) == 30 and int(Save.challenges.get("dallah15", 0)) == 3 and not Save.challenges.has("rocket20")
		and toasts.size() == 1, "runtime: laser hits fill laser30 (with its card), the dallah's beans count, the bolt does not")
	for m: String in ["goal", "hoop", "goal", "mole", "climb"]:
		rt.note_mode(m, "")
	check.call(int(Save.challenges.get("modes5", 0)) == 4 and not Save.challenges.has("shemaghPlay"), "runtime: modes5 counts different modes (4)")
	rt.note_mode("maze", "shemagh")
	check.call(int(Save.challenges.get("modes5", 0)) == 5 and int(Save.challenges.get("shemaghPlay", 0)) == 1, "runtime: a fifth mode, in the shemagh: modes5 and shemaghPlay")
	rt.ch_progress("combo10", 6)
	rt.ch_progress("combo10", 3)
	check.call(int(Save.challenges.get("combo10", 0)) == 6, "runtime: the best combo is kept")
	parent.free()
	Save.challenges.clear()
	Save.challenges.merge(keep)
	if had:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(before)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## A save from before the links keeps its accessories and its colour; locked colours are
## refused on loading a new save.
static func _migrate(check: Callable) -> void:
	var p := {"keeper3": 3, "hoop3": 3, "windowMin": 1, "cansOne": 1, "strike1": 1}
	ChallengeRewards.migrate(p)
	check.call(int(p.get("reward:party", 0)) == 1 and int(p.get("reward:glasses", 0)) == 1 and int(p.get("reward:cap", 0)) == 1 and not p.has("reward:flower"),
		"rewards: an old save with 5 finished keeps the party hat, sunglasses and cap")
	var l := DahroojLooks.load_look({"jelly_color": "blue"}, {})
	var l2 := DahroojLooks.load_look({"jelly_color": "blue"}, {"slime5": 5})
	check.call(l.jelly_color == "pink" and l2.jelly_color == "blue", "rewards: a locked colour loads as pink, an opened one stays")


## The challenges page: a pill with each row's reward; every label fits; locked colours on
## the appearance page.
static func _page(check: Callable) -> void:
	var p := MenuPanel.new()
	var ch: Array = []
	for c: Array in GameRuntime.CHALLENGES:
		ch.append({"id": c[0], "title": c[1], "en": c[2], "value": c[3] if c[0] == "keeper3" else 0, "goal": c[3]})
	var bad: Array = []
	var named := 0
	for en in [false, true]:
		var m := {"english": en, "kind": "vr", "accessory": "", "done": 1, "reset_armed": false, "rewards": {"keeper3": 3}, "challenges": ch}
		p.set_page("challenges")
		p.challenge_offset = 0.0
		p.draw(m, -1)
		while true:
			for r: Dictionary in p.measure():
				if float(r.w) > float(r.max_w) + 0.5 or int(r.size) < Glass.MIN_SIZE:
					bad.append(r.s)
				if str(r.s) in ["Party hat", "قبعة حفلة", "Confetti shot", "طلقة قصاصات", "Beanie", "Wool hat", "طاقية صوف"]:
					named += 1
			if not p.scroll_by(MenuPanel.LIST_HEIGHT * 0.5):
				break
			p.draw(m, -1)
	check.call(bad.is_empty() and named >= 4, "menu: each challenge row names its reward and every label fits (%d) %s" % [named, bad.slice(0, 6)])
	p.set_page("appearance")
	p.appearance = "character"
	p.draw({"english": true, "kind": "vr", "jelly_color": "pink", "done": 0, "rewards": {"styles5": 3}, "challenges": []}, -1)
	var locked: Array = []
	var purple_open := false
	for b: Dictionary in p.buttons:
		if b.kind == "jellyColor" and b.disabled:
			locked.append(b.id)
		if b.kind == "jellyColor" and b.id == "purple":
			purple_open = not b.disabled
	check.call(locked.size() == 5 and purple_open and not "pink" in locked and not "original" in locked,
		"menu: the colours a challenge opens are locked until then %s" % [locked])
	p.free()
