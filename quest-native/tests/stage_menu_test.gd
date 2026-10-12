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


static func run(check: Callable) -> void:
	var p := MenuPanel.new()
	# Button counts per page (7 tabs + Close on every page).
	var want := {"modes": 20, "appearance": 21, "accessories": 22, "play": 15, "world": 18, "world-mr": 9, "challenges": 13, "system": 10, "about": 8}
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
	check.call(_count(p, "mode") == 12 and p.buttons[_find(p, "mode", "hoop")].selected and p.buttons[_find(p, "tab", "modes")].selected, "menu: 12 mode cards, the current mode and page selected")
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
	check.call(ar_goal > ar_hoop and en_goal < en_hoop and absf(en_goal - 220.0) < 0.01 and absf(ar_goal + 207.0 - 980.0) < 0.01, "menu: the card grid mirrors by language (en %.0f / ar %.0f)" % [en_goal, ar_goal])
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
	var aviator: Dictionary = p.buttons[_find(p, "acc", "aviator")]
	check.call(cap.disabled and cap.sub == "Needs 5 challenges" and not glasses.disabled and aviator.sub == "All five balance rounds", "menu: locked accessories are disabled with their unlock")
	check.call(MenuCatalog.accessory_available("beanie", 0, {"mazeClean": 1}) and MenuCatalog.accessory_available("crown", 0, {"reward:crown": 1}) and not MenuCatalog.accessory_available("crown", 9, {}), "menu: accessory unlock rules")
	var qc := MenuCatalog.quest_controls("climb", "sling")
	check.call(qc.a[1] == "Jump" and qc.left_trigger[1] == "Jump" and MenuCatalog.quest_controls("maze", "hand").grip[1].begins_with("Grip: hold and tilt"), "menu: the controls help follows mode and throw style")
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
