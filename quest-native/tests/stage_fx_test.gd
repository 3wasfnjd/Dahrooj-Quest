extends RefCounted
## Feedback effects: confetti bursts, the jelly score popup, the notification card.


static func run(check: Callable) -> void:
	_confetti(check)
	_popup(check)
	_toast(check)


static func _confetti(check: Callable) -> void:
	var c := Confetti.new()
	c.auto_step = false
	check.call(c.pool.size() == Confetti.POOL and (c.pool[0].mi as MultiMeshInstance3D).multimesh.instance_count == 180, "confetti: four pooled bursts of 180 slips")
	var slot := c.pop(Vector3(1, 0, -2), 1.6, 1.5, 2.0)
	check.call(slot == 0 and c.active_count() == 1 and (c.pool[0].mi as MultiMeshInstance3D).visible, "confetti: a pop takes a free burst and shows it")
	# The slip that leaves first (smallest rp) rises, then falls back down.
	var rp: PackedFloat32Array = c.pool[0].rp
	var first := 0
	for i in Confetti.COUNT:
		if rp[i] < rp[first]:
			first = i
	var heights: Array[float] = []
	var spread := 0.0
	for k in 35:
		c.step(0.1)
		heights.append(c.slip_position(0, first).y)
		if k == 15:
			for i in Confetti.COUNT:
				var o := c.slip_position(0, i)
				spread = maxf(spread, Vector2(o.x, o.z).length())
	var top := heights.max() as float
	var at := heights.find(top)
	check.call(top > 0.0 and at > 0 and at < heights.size() - 1 and heights[heights.size() - 2] < top, "confetti: a slip arcs up and falls (top %.2f)" % top)
	check.call(spread > 0.3 and spread <= 1.6 + 1e-3, "confetti: slips fly out within the radius (%.2f)" % spread)
	check.call(c.active_count() == 0 and not (c.pool[0].mi as MultiMeshInstance3D).visible, "confetti: a burst ends after 3.5 s")
	for k in 4:
		c.pop(Vector3.ZERO)
	check.call(c.pop(Vector3.ZERO) == -1, "confetti: only four bursts at once")
	c.free()


static func _popup(check: Callable) -> void:
	var p := ScorePopup.new()
	p.auto_step = false
	p.observe("goal", 0)
	p.step(0.016)
	check.call(not p.showing(), "popup: a new mode stays hidden")
	p.observe("goal", 3)
	check.call(p.showing() and p.value == 3, "popup: a higher score paints and shows the digits")
	p.step(0.05)
	var early := p.root.scale.y
	var seen_wobble := false
	var y0 := p.root.position.y
	for i in 20:
		p.step(0.02)
		if p.root.scale.x != p.root.scale.y:
			seen_wobble = true
	check.call(early < 0.8 and p.root.scale.y > early and seen_wobble and p.root.position.y > y0, "popup: pops in, wobbles and drifts up")
	check.call(p.opacity > 0.99, "popup: fully seen at its peak")
	for i in 100:
		p.step(0.02)
	check.call(not p.showing() and p.opacity < 0.01, "popup: fades out and hides after 1.65 s")
	p.observe("goal", 12)
	p.observe("goal", 4)
	check.call(not p.showing(), "popup: a lower score hides it")
	check.call(absf(ScorePopup.hsl(140, 0.7, 0.35).g - Color("1b9848").g) < 0.01, "popup: hsl hues as on the web canvas")
	p.free()


static func _toast(check: Callable) -> void:
	var t := ToastCard.new()
	t.auto_step = false
	t.lang = "en"
	var head := Transform3D(Basis.IDENTITY, Vector3(0, 1.6, 0))
	t.place(head)
	var buzzed := {"n": 0}
	t.buzz.connect(func(_k: String) -> void: buzzed.n += 1)
	t.show_text("Strike!")
	t.show_text("Strike!")
	t.show_text("✓ 25 bounces")
	check.call(t.cards.size() == 2, "toast: the same text twice is one card")
	t.step(0.016)
	var p := t.position  # outside the tree its own transform is the global one
	check.call(t.visible and absf(p.z + 0.8) < 0.01 and p.y > 1.6 + 0.23, "toast: the card drops in 0.8 m ahead, above the gaze (%.2f, %.2f)" % [p.y, p.z])
	check.call((t.basis.z - (head.origin - p).normalized()).length() < 0.01 and absf(t.basis.x.y) < 1e-4, "toast: the card faces the eye")
	for i in 20:
		t.step(0.02)
	check.call(t.opacity > 0.99, "toast: fully seen once in")
	var gone := false
	for i in int(2.4 / 0.02) + 5:
		t.step(0.02)
		if t.now.get("title", "") != "Strike!":
			gone = true
			break
	check.call(gone and buzzed.n == 0, "toast: a plain message leaves after 2.4 s")
	t.step(0.016)
	check.call(t.now.get("kind", "") == "challenge" and buzzed.n == 1, "toast: then the challenge card, with a buzz")
	for i in int(3.4 / 0.02) + 5:
		t.step(0.02)
	check.call(not t.visible and t.now.is_empty(), "toast: it fades out and the card hides")
	var fits := true
	for title: String in ["اجمع النجوم وأكمل المتاهة دون إعادة", "Collect the stars and finish without retrying", "Pop 5 Dahroojs above your head"]:
		var size := Glass.fit_size(title, 46, ToastCard.text_width(), 800, -1, 22)
		if Glass.width(title, size, 800) > ToastCard.text_width() + 0.5:
			fits = false
	check.call(fits, "toast: long titles shrink to the card")
	t.free()
