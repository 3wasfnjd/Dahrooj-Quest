extends RefCounted
## The headset menu (MenuPanel): the original's button layout per page in Arabic
## and English, mirroring, picking by uv and by ray, scrolling, the catalog rules
## and the icon rasteriser. Logic only (no rendering needed).


static func _model(english: bool, kind := "vr") -> Dictionary:
	var ch: Array = []
	for c: Array in MenuCatalog.CHALLENGES:
		ch.append({"id": c[0], "title": c[2], "en": c[3], "value": 0, "goal": c[1]})
	return {"english": english, "kind": kind, "mode": "hoop", "style": "jelly", "jelly_color": "pink", "throw_style": "trigger",
		"shot_style": "bolt", "time": "auto", "weather": "auto", "accessory": "", "done": 4, "reset_armed": false, "challenges": ch}


static func _count(p: MenuPanel, kind: String) -> int:
	var n := 0
	for b in p.buttons:
		if b.kind == kind:
			n += 1
	return n


static func _find(p: MenuPanel, kind: String, id: String) -> int:
	for i in p.buttons.size():
		if p.buttons[i].kind == kind and p.buttons[i].id == id:
			return i
	return -1


## Every label of every page (both languages, every card hovered so the footer
## shows each name and unlock) is no wider than its box and readable.
static func _fit(p: MenuPanel, check: Callable) -> void:
	var pages := [["modes", "character", "vr"], ["appearance", "character", "vr"], ["appearance", "accessories", "vr"], ["play", "character", "vr"],
		["play", "character", "mr"], ["world", "character", "vr"], ["world", "character", "mr"], ["challenges", "character", "vr"],
		["system", "character", "vr"], ["about", "character", "vr"]]
	var bad: Array = []
	var n := 0
	for en in [false, true]:
		for pg: Array in pages:
			for mode: String in ["hoop", "maze", "climb", "ricochet"]:
				for th: String in ["trigger", "hand", "sling"]:
					if pg[0] != "play" and (mode != "hoop" or th != "trigger"):
						continue
					var m := _model(en, pg[2])
					m.mode = mode
					m.throw_style = th
					m.done = 0
					p.appearance = pg[1]
					p.set_page(pg[0])
					for armed in [false, true]:
						m.reset_armed = armed
						p.draw(m, -1)
						for hv in range(-1, p.buttons.size()):
							p.draw(m, hv)
							for r: Dictionary in p.measure():
								n += 1
								if float(r.w) > float(r.max_w) + 0.5 or int(r.size) < Glass.MIN_SIZE:
									bad.append("%s:%s" % [pg[0], r.s])
	check.call(bad.is_empty() and n > 1000, "menu: every label fits its box in Arabic and English (%d checked) %s" % [n, bad.slice(0, 6)])


static func _start_screen(check: Callable) -> void:
	var sp := Panel3D.new()
	sp.build("دحروج", "اختر طريقة اللعب", [["mr", "الواقع المختلط — في غرفتك"], ["vr", "الواقع الافتراضي — في الحديقة"], ["lang", "English"]])
	var ids: Array = []
	for r: Dictionary in sp.rows:
		ids.append(r.id)
	check.call(ids == ["mr", "vr", "lang"] and sp.rows[0].caption == "في غرفتك" and sp.rows[0].icon == "mr" and sp.rows[2].pill and sp.height > 0.3,
		"start: three buttons (mr, vr cards; the language pill)")
	var head := Transform3D(Basis.IDENTITY, Vector3(0, 1.6, 0))
	sp.place(head, 0.75, 0.05)
	var hits := true
	for r: Dictionary in sp.rows:
		var c: Rect2 = r.rect
		var target := sp.transform * Vector3(c.get_center().x, c.get_center().y, 0)
		if sp.hit(head.origin, (target - head.origin).normalized()) != r.id or sp.hot != r.id:
			hits = false
	var edge := sp.transform * Vector3(0, sp.height / 2.0 - 0.01, 0)
	check.call(hits and sp.hit(head.origin, (edge - head.origin).normalized()) == "" and sp.hit(head.origin, Vector3(0, 0, 1)) == "", "start: rays pick each card; the title and away miss")
	var dist := sp.ray_distance(head.origin, Vector3(0, -0.05, -0.75).normalized())
	check.call(absf(dist - Vector3(0, -0.05, -0.75).length()) < 1e-3 and sp.ray_distance(head.origin, Vector3(0, 1, 0)) < 0.0, "start: ray distance to the panel")
	var bad: Array = []
	for lang: Array in [["دحروج", "اختر طريقة اللعب", "الواقع المختلط — في غرفتك", "الواقع الافتراضي — في الحديقة", "English"],
			["Dahrooj", "Choose how to play", "Mixed reality — in your room", "Virtual reality — in the park", "العربية"]]:
		sp.build(lang[0], lang[1], [["mr", lang[2], "mr"], ["vr", lang[3], "vr"], ["lang", lang[4], "lang"]])
		for r: Dictionary in sp.measure():
			if float(r.w) > float(r.max_w) + 0.5:
				bad.append(r.s)
	check.call(bad.is_empty() and sp.texts.size() == 7, "start: every label fits (%s)" % [bad])
	sp.build("T", "", [["a", "One"], ["b", "Two"]])
	check.call(sp.rows.size() == 2 and sp.rows[1].id == "b", "start: old [id, text] buttons still build")
	sp.free()


static func run(check: Callable) -> void:
	_start_screen(check)
	var p := MenuPanel.new()
	# Button counts per page (7 tabs + Close on every page).
	var want := {"modes": 28, "appearance": 21, "accessories": 24, "play": 23, "world": 18, "world-mr": 9, "challenges": 13, "system": 10, "about": 8}
	for en in [false, true]:
		var bad: Array = []
		for k: String in want:
			p.appearance = "accessories" if k == "accessories" else "character"
			p.set_page("appearance" if k == "accessories" else "world" if k == "world-mr" else k)
			p.draw(_model(en, "mr" if k == "world-mr" else "vr"), -1)
			if p.buttons.size() != int(want[k]) or _count(p, "tab") != 7 or _count(p, "close") != 1:
				bad.append("%s=%d" % [k, p.buttons.size()])
		check.call(bad.is_empty(), "menu (%s): buttons per page as the original %s" % ["en" if en else "ar", bad])
	p.appearance = "character"
	p.set_page("modes")
	var m_ar := _model(false)
	p.draw(m_ar, -1)
	check.call(_count(p, "mode") == 20 and p.buttons[_find(p, "mode", "hoop")].selected and p.buttons[_find(p, "tab", "modes")].selected, "menu: 20 mode cards, the current mode and page selected")
	var order: Array = []
	for b: Dictionary in p.buttons:
		if b.kind == "mode":
			order.append(b.id)
	check.call(order == ["goal", "hoop", "window", "cans", "bowling", "bricks", "fair", "mole", "invasion", "slime", "meteor", "castle", "giant", "gallery", "frenzy", "rain", "climb", "balance", "ricochet", "maze"]
		and p.buttons[_find(p, "mode", "mole")].en == "Whack-a-Dahrooj", "menu: Whack-a-Dahrooj after the fair")
	var inv: Dictionary = p.buttons[_find(p, "mode", "invasion")]
	check.call(inv.en == "Dahrooj Attack" and inv.ar == "هجوم الدحاريج" and inv.icon == "invasion" and MenuIcons.IDS.has("invasion"), "menu: Dahrooj Attack after Whack-a-Dahrooj, with its own icon")
	var sl: Dictionary = p.buttons[_find(p, "mode", "slime")]
	check.call(sl.en == "Slime" and sl.ar == "سلايم" and sl.icon == "slime" and MenuIcons.IDS.has("slime"), "menu: Slime after Dahrooj Attack, with its own icon")
	# The five arcade modes after Slime, each with its own icon.
	var arcade := [["meteor", "نيازك الدحاريج", "Dahrooj Meteors"], ["castle", "حصن الدحاريج", "Dahrooj Fort"],
		["giant", "الدحروج العملاق", "Giant Dahrooj"], ["gallery", "ميدان الرماية", "Dahrooj Gallery"], ["frenzy", "حمّى الفرقعة", "Pop Frenzy"]]
	var arcade_bad: Array = []
	for k in arcade.size():
		var want_m: Array = arcade[k]
		var i := _find(p, "mode", want_m[0])
		var b: Dictionary = p.buttons[i] if i >= 0 else {}
		if i != _find(p, "mode", "slime") + 1 + k or b.ar != want_m[1] or b.en != want_m[2] or b.icon != want_m[0] or not MenuIcons.IDS.has(want_m[0]) or not GameRuntime.MODES.has(want_m[0]):
			arcade_bad.append(want_m[0])
	check.call(arcade_bad.is_empty(), "menu: Meteors, Fort, Giant, Gallery and Frenzy after Slime, with their own icons %s" % [arcade_bad])
	# The grid: five across, four rows, the short last row centred, nothing overlapping.
	var cells_ok := true
	var cards := MenuCatalog.MODES.size()
	for i in cards:
		var a: Dictionary = MenuPanel.mode_cell(i, true)
		if float(a.x) < 219.9 or float(a.x) + float(a.w) > 1108.1 or float(a.y) + float(a.h) > MenuPanel.FOOTER_Y - 8.0:
			cells_ok = false
		for j in range(i + 1, cards):
			var b: Dictionary = MenuPanel.mode_cell(j, true)
			if Rect2(a.x, a.y, a.w, a.h).intersects(Rect2(b.x, b.y, b.w, b.h)):
				cells_ok = false
	# 20 cards: four full rows of 5 (a short last row would be centred under the others).
	var row0: Dictionary = MenuPanel.mode_cell(15, true)
	var last: Dictionary = MenuPanel.mode_cell(cards - 1, true)
	var centre := (float(row0.x) + float(last.x) + float(last.w)) / 2.0
	check.call(cells_ok and cards == 20 and float(MenuPanel.mode_cell(0, true).h) >= 150.0 and absf(float(last.x) + float(last.w) - float(MenuPanel.mode_cell(4, true).x) - float(MenuPanel.mode_cell(4, true).w)) < 0.01 and absf(centre - 664.0) < 0.01 and float(last.x) > float(row0.x) and float(row0.y) == float(last.y), "menu: the mode grid fits (four full rows of tall cards), last row centred")
	var r0 := p.renders
	p.draw(m_ar, -1)
	check.call(p.renders == r0, "menu: an unchanged draw does not re-render")
	p.draw(m_ar, 3)
	check.call(p.renders == r0 + 1 and p.hover == 3, "menu: a new hover re-renders")
	# Picking by uv: every card's centre gives that card.
	var ok := true
	for i in p.buttons.size():
		var b: Dictionary = p.buttons[i]
		var uv := Vector2((b.x + b.w / 2.0) / MenuPanel.W, (b.y + b.h / 2.0) / MenuPanel.H)
		if p.button_at(uv) != i:
			ok = false
	check.call(ok and p.button_at(Vector2(0.5, 0.02)) == -1, "menu: button_at on each card's centre returns it, the margin nothing")
	var g := _find(p, "mode", "goal")
	var gb: Dictionary = p.buttons[g]
	var edge := Vector2((gb.x - 3.0) / MenuPanel.W, (gb.y + 20.0) / MenuPanel.H)
	check.call(p.button_at(edge) == -1 and p.button_at(edge, g) == g, "menu: 6 px of hysteresis keep the hovered card")
	# Mirroring: Arabic puts the tabs on the right and the first card rightmost.
	var ar_goal: float = p.buttons[g].x
	var ar_hoop: float = p.buttons[_find(p, "mode", "hoop")].x
	var ar_tab: float = p.buttons[0].x
	p.draw(_model(true), -1)
	var en_goal: float = p.buttons[_find(p, "mode", "goal")].x
	var en_hoop: float = p.buttons[_find(p, "mode", "hoop")].x
	var cw: float = MenuPanel.mode_cell(0, true).w
	check.call(ar_goal > ar_hoop and en_goal < en_hoop and absf(en_goal - 220.0) < 0.01 and absf(ar_goal + cw - 980.0) < 0.01, "menu: the card grid mirrors by language (en %.0f / ar %.0f)" % [en_goal, ar_goal])
	check.call(ar_tab == 1030.0 and p.buttons[0].x == 58.0, "menu: the tab column swaps sides")
	# Ray picking after placing in front of the head.
	var head := Transform3D(Basis.IDENTITY, Vector3(0, 1.6, 0))
	p.place(head)
	check.call(p.position.distance_to(Vector3(0, 1.4, -1.1)) < 1e-4, "menu: placed 1.1 m ahead and 0.2 m lower")
	var target := p.transform * MenuPanel.mode_point(5, true)
	var h := p.hit(head.origin, (target - head.origin).normalized())
	var bricks := _find(p, "mode", "bricks")
	check.call(int(h.index) == bricks and absf(float(h.distance) - target.distance_to(head.origin)) < 1e-3, "menu: a ray at a card picks it (%s)" % [h.index])
	check.call(int(p.hit(head.origin, Vector3(0, 0, 1)).index) == -1 and int(p.hit(head.origin, Vector3(0, 1, -0.2).normalized()).index) == -1, "menu: rays away from or past the panel miss")
	# Actions and navigation.
	var close: Dictionary = p.action(_find(p, "close", "close"))
	check.call(close.get("kind", "") == "close" and p.action(-1).is_empty() and p.action(99).is_empty(), "menu: action returns the button")
	check.call(p.navigate(p.action(_find(p, "tab", "challenges"))) and p.page == "challenges", "menu: a tab switches the page")
	# Challenge scrolling clamps.
	var m := _model(true)
	p.draw(m, -1)
	var mx := 25.0 * MenuPanel.ROW_HEIGHT - MenuPanel.LIST_HEIGHT
	check.call(p.scroll_max() == mx and p.action(_find(p, "scrollStep", "up")).is_empty(), "menu: the list starts at the top (up disabled, max %.0f)" % mx)
	check.call(not p.scroll_by(-50.0) and p.challenge_offset == 0.0, "menu: no scrolling above the first row")
	p.scroll_by(1e6)
	p.draw(m, -1)
	check.call(p.challenge_offset == mx and p.action(_find(p, "scrollStep", "down")).is_empty(), "menu: scrolling clamps at the end (down disabled)")
	p.scroll_by(-1e6)
	check.call(not p.scroll_axis(0.1, 0.05) and p.scroll_axis(-1.0, 0.05) and absf(p.challenge_offset - 35.0) < 1e-3, "menu: the stick scrolls past its dead zone (pushed down: on)")
	check.call(p.scroll_axis(1.0, 0.05) and p.challenge_offset == 0.0, "menu: pushed up: back")
	p.scroll_drag(0.5, 0.4)
	check.call(absf(p.challenge_offset - 100.0) < 1e-3, "menu: dragging the list up scrolls on")
	p.scroll_drag(0.3, 0.3 + 1.0, true)
	check.call(p.challenge_offset == mx, "menu: dragging the thumb is clamped too")
	p.draw(m, -1)
	p.navigate(p.action(_find(p, "scrollStep", "up")))
	check.call(p.challenge_offset == mx - 2.0 * MenuPanel.ROW_HEIGHT, "menu: the up step moves two rows")
	p.set_page("modes")
	check.call(not p.scroll_by(10.0), "menu: only the challenges page scrolls")
	# Accessories: locked ones are disabled and say what unlocks them.
	p.set_page("appearance")
	p.appearance = "accessories"
	p.draw(_model(true), -1)
	var cap: Dictionary = p.buttons[_find(p, "acc", "cap")]
	var glasses: Dictionary = p.buttons[_find(p, "acc", "glasses")]
	p.acc_page = 1
	p.draw(_model(true), -1)
	var aviator: Dictionary = p.buttons[_find(p, "acc", "aviator")]
	p.acc_page = 0
	check.call(cap.disabled and cap.sub == "3 curved goals" and glasses.disabled and glasses.sub == "Clear cans in one throw" and aviator.sub == "All five balance rounds",
		"menu: locked accessories are disabled with the challenge that opens them")
	check.call(MenuCatalog.accessory_available("beanie", 0, {"mazeClean": 1}) and MenuCatalog.accessory_available("crown", 0, {"reward:crown": 1}) and not MenuCatalog.accessory_available("crown", 9, {}), "menu: accessory unlock rules")
	var qc := MenuCatalog.quest_controls("climb", "sling")
	check.call(qc.left_grip[1] == "Jump" and qc.left_trigger[1] == "—" and qc.right_grip[1] == "Throw a ball"
		and MenuCatalog.quest_controls("maze", "hand").grip[1].begins_with("Grip: hold and tilt"), "menu: the controls help follows mode and throw style")
	var all_fire := true
	for mode: Array in MenuCatalog.MODES:
		for th: Array in MenuCatalog.THROWS:
			var hc := MenuCatalog.quest_controls(str(mode[0]), str(th[0]))
			var no_shots: bool = str(mode[0]) in ["climb", "balance", "maze", "ricochet"]
			if not no_shots and (hc.left_trigger[1] != "Fire shots" or hc.right_trigger[1] != "Fire shots"):
				all_fire = false
			if no_shots and hc.left_trigger[1] == "Fire shots":
				all_fire = false
	check.call(all_fire and MenuCatalog.THROWS[0][0] == "trigger" and MenuCatalog.THROWS[0][2] == "Charge" and MenuCatalog.THROWS[0][1] == "شحن",
		"menu: the triggers fire in the throwing modes, not in the climb and tabletops; the charge throw keeps its id")
	_fit(p, check)
	# Icons: every id draws something; the rasteriser anti-aliases.
	var empty: Array = []
	for id: String in MenuIcons.IDS:
		if MenuIcons.shapes(id).is_empty():
			empty.append(id)
	var imgs := MenuIcons.raster(MenuIcons.shapes("check"), 32)
	var partial := false
	for y in 32:
		for x in 32:
			var a := imgs[0].get_pixel(x, y).a
			if a > 0.1 and a < 0.9:
				partial = true
	check.call(empty.is_empty() and imgs[0].get_used_rect().size.x > 16 and partial, "menu: icons rasterise with soft edges %s" % [empty])
	check.call(ResourceLoader.exists(MenuIcons.ATLAS), "menu: the baked icon atlas is in the project")
	p.free()
