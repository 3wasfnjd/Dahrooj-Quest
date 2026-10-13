extends RefCounted
## Dahrooj Gallery (gallery): cardboard targets flip up and down, rows roll on their rails,
## swingers and peekers come and go; shots and throws knock them over and score into
## counts[gallery]; the eyes are a bullseye, far ones pay more, a toss is a trick shot; a
## crowned friendly one only says "ouch" and resets the streak (no loss); quick hits build a
## multiplier with banners and fireworks; a drumroll brings a faster rapid round worth double;
## open play escalates and never ends; the cover stops shots; mixed reality uses the room.

const DT := 1.0 / 72.0


static func _until(st: GalleryStage, b: Ball, i: int, phase: String, limit: float) -> bool:
	var t := 0.0
	while t < limit:
		if st.targets[i].phase == phase:
			return true
		st.update(b, DT)
		t += DT
	return st.targets[i].phase == phase


static func _make(sfx: Array, extra: Array) -> Array:
	var st := GalleryStage.new()
	st.auto_spawn = false
	var b := Ball.new()
	var ctx := GameCtx.new()
	ctx.ball = b
	ctx.sfx = func(n, k, _p): sfx.append([n, k])
	ctx.toast = func(t): extra.append(["toast", t])
	ctx.ch_progress = func(id, v): extra.append(["ch", id, v])
	ctx.confetti = func(p, _r, _e, _s): extra.append(["confetti", p])
	st.ctx = ctx
	b.set_stage(st, "gallery")
	return [st, b, ctx]


static func run(check: Callable) -> void:
	var sfx: Array = []
	var extra: Array = []
	var made := _make(sfx, extra)
	var st: GalleryStage = made[0]
	var b: Ball = made[1]
	var ctx: GameCtx = made[2]
	var counts := func() -> int: return int(ctx.counts.get("gallery", 0))
	check.call(st.get_node_or_null("Board") == null and not st.gallery_state().has("time") and not st.gallery_state().has("lives"), "gallery: no score board, no clock, no lives")
	check.call(st.rows.size() == 3 and st.booth.visible and st.covers.size() == 4, "gallery: the court's booth: three carousel rows and four pieces of cover")
	st.update(b, DT)
	check.call(st.gallery_state().state == "play" and st.banner.visible, "gallery: it starts on its own with a title banner")
	st.F.banner_t = 0.0
	st.F.next_rapid = 999.0

	# A cardboard target flips up with a clack, stands, flips down.
	sfx.clear()
	var i := st.spawn("card", "plain", {"pos": Vector3(0, 0, -10)})
	var T: Dictionary = st.targets[i]
	check.call(i >= 0 and T.phase == "in" and T.flat and sfx.any(func(s): return s[0] == "bowling_clack"), "gallery: a card flips up with a clack")
	check.call(_until(st, b, i, "up", 0.5) and GalleryStage.hittable(T) and T.proxy.visible and T.proxy.layers == 0, "gallery: up, with an undrawn hit sphere for the blaster")
	st.draw()
	check.call(st._mm.cards.visible_instance_count >= 1 and st.crowd.count() >= 1 and (T.c as Vector3).y > 0.8, "gallery: the card stands on its stick with a painted Dahrooj on it")
	check.call(_until(st, b, i, "out", T.life + 0.5) and _until(st, b, i, "", 1.0) or not T.on, "gallery: it flips back down on a timer")
	check.call(not T.on and counts.call() == 0, "gallery: gone, nothing lost for letting it go")

	# A shot knocks a card over: points to counts[gallery], chips and a clack.
	i = st.spawn("card", "plain", {"pos": Vector3(1, 0, -10)})
	T = st.targets[i]
	_until(st, b, i, "up", 0.5)
	sfx.clear()
	var off_eye: Vector3 = (T.dx as Transform3D) * Vector3(0, -0.6, 0.9)
	check.call(not GalleryStage.bullseye(T, off_eye), "gallery: the chin is not the bullseye")
	var fx0 := st.fx_spawned
	check.call(st.shoot(T.proxy, off_eye, Vector3.FORWARD) and T.phase == "hit", "gallery: a blaster shot knocks the card over")
	var first: int = counts.call()
	check.call(first == GalleryStage.PTS.card and st.gallery_state().hits == 1, "gallery: a near card is worth %d (got %d)" % [GalleryStage.PTS.card, first])
	check.call(sfx.any(func(s): return s[0] == "bowling_clack") and st.fx_spawned > fx0 and not GalleryStage.hittable(T), "gallery: a clack, cardboard chips, and it can't be hit twice")
	check.call(extra.any(func(e): return e[0] == "ch" and e[1] == "gallery10"), "gallery: the streak goes toward the gallery10 challenge")

	# The bullseye: the eyes.
	i = st.spawn("card", "plain", {"pos": Vector3(-1, 0, -10)})
	T = st.targets[i]
	_until(st, b, i, "up", 0.5)
	sfx.clear()
	var eye: Vector3 = (T.dx as Transform3D) * Vector3(0.3, 0.08, 0.95)
	check.call(GalleryStage.bullseye(T, eye), "gallery: the eye is the bullseye")
	var before: int = counts.call()
	st.shoot(T.proxy, eye, Vector3.FORWARD)
	check.call(counts.call() - before == GalleryStage.PTS.card + GalleryStage.BULLSEYE_PTS and st.gallery_state().bullseyes == 1 and sfx.any(func(s): return s[0] == "fair_ding"), "gallery: a bullseye pays +%d with a ding (got %d)" % [GalleryStage.BULLSEYE_PTS, counts.call() - before])

	# Distance bonus: the same target far away pays more.
	st.F.streak = 0
	st.F.mult = 1
	var near := st.spawn("card", "plain", {"pos": Vector3(0, 0, -6)})
	var far := st.spawn("card", "plain", {"pos": Vector3(0, 0, -26)})
	st.update(b, DT)
	var pn: Dictionary = st.points_for(st.targets[near], false)
	var pf: Dictionary = st.points_for(st.targets[far], false)
	check.call(int(pf.total) > int(pn.total) and int(pf.far) > 0 and int(pn.far) == 0, "gallery: a far target pays a distance bonus (%d vs %d)" % [pf.total, pn.total])
	st.targets[near].on = false
	st.targets[far].on = false

	# The friendly crowned one: "ouch", the streak resets, nothing is lost.
	st.F.streak = 4
	st.F.mult = GalleryStage.multiplier(4)
	var fi := st.spawn("peek", "friendly", {"hide": Vector3(0, 1, -12), "out": Vector3(1, 1, -11.5)})
	var Tf: Dictionary = st.targets[fi]
	check.call(Tf.acc == "crown", "gallery: the friendly one wears a crown")
	_until(st, b, fi, "up", 0.5)
	sfx.clear()
	before = counts.call()
	check.call(st.shoot(Tf.proxy, Tf.c, Vector3.FORWARD) and Tf.phase == "ouch", "gallery: shooting a friendly one makes him go ouch")
	check.call(counts.call() == before and st.gallery_state().streak == 0 and st.gallery_state().mult == 1 and st.gallery_state().ouches == 1, "gallery: no points lost, the streak and multiplier reset")
	check.call(sfx.any(func(s): return s[0] == "squeak" and float(s[1]) > 1.3), "gallery: a funny high squeak")
	st.draw()
	check.call(st._mm.stars.visible_instance_count >= 3 and st._eyes(Tf) == "shut", "gallery: dizzy stars, eyes shut")
	check.call(_until(st, b, fi, "out", GalleryStage.OUCH_T + 0.2), "gallery: then he ducks away")

	# A streak: the multiplier steps up with banners, fireworks from ×3.
	st.F.streak = 0
	st.F.mult = 1
	extra.clear()
	sfx.clear()
	var got := []
	for k in 7:
		var q := st.spawn("card", "plain", {"pos": Vector3(-6 + k * 2.0, 0, -9)})
		_until(st, b, q, "up", 0.5)
		var c0: int = counts.call()
		st.shoot(st.targets[q].proxy, (st.targets[q].dx as Transform3D) * Vector3(0, -0.6, 0.9), Vector3.FORWARD)
		got.append(counts.call() - c0)
	check.call(st.gallery_state().streak == 7 and st.gallery_state().mult == 3, "gallery: 7 quick hits, ×3 (×%d)" % st.gallery_state().mult)
	check.call(int(got[6]) > int(got[0]) * 2, "gallery: the multiplier multiplies the points (%s)" % str(got))
	check.call(st.banner.text.contains("3") or st.banner.text.contains("٣"), "gallery: a big streak banner (%s)" % st.banner.text)
	check.call(st.gallery_state().rockets > 0 and sfx.any(func(s): return s[0] == "firework_launch"), "gallery: fireworks go up at ×3")
	for k in 100:
		st.update(b, DT)
	check.call(st.gallery_state().fireworks > 0 and sfx.any(func(s): return s[0] == "firework_burst"), "gallery: and burst")
	# The streak runs out without hits (a miss costs only the combo).
	for k in int((GalleryStage.COMBO_T + 0.3) / DT):
		st.update(b, DT)
	check.call(st.gallery_state().streak == 0 and st.gallery_state().mult == 1 and st.gallery_state().best >= 7, "gallery: a lull ends the streak, the best is kept")

	# A thrown Dahrooj knocks a peeker over.
	var pi := st.spawn("peek", "plain", {"hide": Vector3(0, 1.5, -9.5), "out": Vector3(0, 1.5, -9)})
	var Tp: Dictionary = st.targets[pi]
	_until(st, b, pi, "up", 0.5)
	b.respawn()
	b.pos = (Tp.c as Vector3) + Vector3(0, 0.4, 3.0)
	b.throw_with(Vector3(0, 0.6, -10))
	before = counts.call()
	for k in 72:
		b.step(DT)
		if not Tp.on:
			break
	check.call(not Tp.on and counts.call() > before and st.touched(), "gallery: a thrown Dahrooj pops a peeker")
	b.respawn()

	# A rail target rolls along its row, rising at the start and sinking at the end.
	var ri := st.spawn("rail", "plain", {"row": 1})
	var Tr: Dictionary = st.targets[ri]
	var x0: float = (Tr.c as Vector3).x
	check.call(not GalleryStage.hittable(Tr), "gallery: a row target starts hidden behind its board")
	for k in 72:
		st.update(b, DT)
	check.call(GalleryStage.hittable(Tr) and absf((Tr.c as Vector3).x - x0) > 1.5, "gallery: it rolls along the rail and pops up")
	before = counts.call()
	check.call(st.shoot(Tr.proxy, Tr.c, Vector3.FORWARD) and not Tr.on and counts.call() > before, "gallery: a shot pops it")

	# A swinger comes down on a rope; a toss is a trick shot.
	var si := st.spawn("swing", "plain", {"anchor": Vector3(0, 10, -14), "rope": 5.0})
	var Ts: Dictionary = st.targets[si]
	_until(st, b, si, "up", 1.0)
	var c1: Vector3 = Ts.c
	for k in 30:
		st.update(b, DT)
	check.call(GalleryStage.hittable(Ts) and (Ts.c as Vector3).y < 6.0 and (Ts.c as Vector3).distance_to(c1) > 0.1, "gallery: the swinger hangs on its rope and swings")
	st.draw()
	check.call(st._mm.ropes.visible_instance_count >= 1, "gallery: the rope is drawn")
	var ti := st.spawn("toss", "plain", {"from": Vector3(2, 0.6, -12), "v": Vector3(0, 9, 0)})
	var Tt: Dictionary = st.targets[ti]
	for k in 20:
		st.update(b, DT)
	check.call(GalleryStage.hittable(Tt) and (Tt.c as Vector3).y > 2.0, "gallery: a Dahrooj tossed up into the air")
	st.F.streak = 0
	st.F.mult = 1
	before = counts.call()
	st.shoot(Tt.proxy, (Tt.dx as Transform3D) * Vector3(0, -0.6, 0.9), Vector3.FORWARD)
	check.call(counts.call() - before >= GalleryStage.PTS.toss and st.gallery_state().tricks == 1, "gallery: a trick shot pays %d (got %d)" % [GalleryStage.PTS.toss, counts.call() - before])
	var tj := st.spawn("toss", "plain", {"from": Vector3(-2, 0.6, -12), "v": Vector3(0, 8, 0)})
	for k in 200:
		st.update(b, DT)
	check.call(not st.targets[tj].on, "gallery: an untouched toss lands behind its cover and is gone (no loss)")

	# Cover is solid: a shot on it scores nothing.
	var cv: Dictionary = st.covers[0]
	before = counts.call()
	check.call(cv.node is MeshInstance3D and cv.node.layers != 0 and not st.shoot(cv.node, cv.pos, Vector3.FORWARD) and counts.call() == before, "gallery: the cover stops shots")
	var edges := st.cover_edges(cv)
	var d := ((cv.pos as Vector3) - GalleryStage.VIEW_VR) * Vector3(1, 0, 1)
	d = d.normalized()
	check.call(edges.size() >= 2 and edges.all(func(e): return ((e.hide as Vector3) - GalleryStage.VIEW_VR).dot(d) > ((cv.pos as Vector3) - GalleryStage.VIEW_VR).dot(d)), "gallery: peekers hide behind the cover")
	st.free()

	# The rapid round: a drumroll, then faster and double points, then back.
	sfx.clear()
	made = _make(sfx, extra)
	st = made[0]
	b = made[1]
	ctx = made[2]
	st.update(b, DT)
	var pace0 := st.pace()
	st.F.next_rapid = 0.05
	for k in int(0.6 / DT):
		st.update(b, DT)
	check.call(st.F.rapid == "roll" and sfx.filter(func(s): return s[0] == "thump").size() >= 6, "gallery: a drumroll before the rapid round")
	for k in int(GalleryStage.ROLL_T / DT):
		st.update(b, DT)
	var pace_on := st.pace()
	check.call(st.F.rapid == "on" and pace_on > pace0 * 1.3 and st.banner.visible, "gallery: rapid round! everything speeds up (pace %.2f -> %.2f)" % [pace0, pace_on])
	var ci := st.spawn("card", "plain", {"pos": Vector3(0, 0, -10)})
	_until(st, b, ci, "up", 0.5)
	var cb := int(ctx.counts.get("gallery", 0))
	st.shoot(st.targets[ci].proxy, (st.targets[ci].dx as Transform3D) * Vector3(0, -0.6, 0.9), Vector3.FORWARD)
	check.call(int(ctx.counts.get("gallery", 0)) - cb == GalleryStage.PTS.card * 2, "gallery: every hit counts double in a rapid round")
	for k in int((GalleryStage.RAPID_T + 0.2) / DT):
		st.update(b, DT)
	check.call(st.F.rapid == "" and st.pace() < pace_on and st.gallery_state().rapids == 1, "gallery: the rapid round ends")
	st.free()

	# Open play: they keep coming, it escalates, and nothing ever ends it.
	made = _make(sfx, extra)
	st = made[0]
	b = made[1]
	ctx = made[2]
	st.auto_spawn = true
	check.call(GalleryStage.spawn_interval(6.0) < GalleryStage.spawn_interval(0.0) and GalleryStage.cap_at(6.0) > GalleryStage.cap_at(0.0), "gallery: more targets, more often as the minutes go by")
	var seen := {}
	var early := 0
	var late := 0
	var t := 0.0
	var spawned := 0
	var was_on := {}
	var shots := 0
	var last_count := 0
	var never_down := true
	while t < 300.0:
		st.update(b, DT)
		t += DT
		for k in st.targets.size():
			var q: Dictionary = st.targets[k]
			if q.on and not was_on.get(k, false):
				spawned += 1
				seen[q.mover] = true
				if t < 60.0:
					early += 1
				elif t > 240.0:
					late += 1
			was_on[k] = q.on
			# Shoot every other plain target once it's up.
			if GalleryStage.hittable(q) and q.kind != "friendly" and (k + int(t)) % 2 == 0 and q.phase == "up":
				st.shoot(q.proxy, q.c, Vector3.FORWARD)
				shots += 1
		var cnow := int(ctx.counts.get("gallery", 0))
		if cnow < last_count:
			never_down = false
		last_count = cnow
	check.call(seen.has("card") and seen.has("rail") and seen.has("peek") and seen.has("swing") and seen.has("toss"), "gallery: cards, rows, peekers, swingers and tosses all appear (%s)" % str(seen.keys()))
	check.call(late > early, "gallery: it escalates (%d in the first minute, %d in the last)" % [early, late])
	check.call(st.gallery_state().state == "play" and never_down and last_count > 0 and st.gallery_state().rapids >= 4, "gallery: five minutes of open play, never over, the score only grows (%d, %d rapid rounds)" % [last_count, st.gallery_state().rapids])
	check.call(st.crowd.count() <= GalleryStage.SLOTS and st.gallery_state().alive <= GalleryStage.SLOTS, "gallery: bounded (%d targets)" % st.gallery_state().alive)
	st.deactivate()
	check.call(st.gallery_state().alive == 0 and st.gallery_state().score == 0 and st.F.state == "idle", "gallery: deactivate clears it")
	st.free()

	# Mixed reality: the room's planes.
	made = _make(sfx, extra)
	st = made[0]
	b = made[1]
	st.size = 2.0
	st.viewer = Vector3(0, 13, 4)
	var room := [
		{"pos": Vector3(0, 0, -14), "normal": Vector3.UP, "ax": Vector3.RIGHT, "ay": Vector3.BACK, "half": Vector2(20, 18), "label": "floor"},
		{"pos": Vector3(0, 12, -30), "normal": Vector3.BACK, "ax": Vector3.RIGHT, "ay": Vector3.UP, "half": Vector2(20, 12), "label": "wall"},
		{"pos": Vector3(-20, 12, -14), "normal": Vector3.RIGHT, "ax": Vector3.BACK, "ay": Vector3.UP, "half": Vector2(16, 12), "label": "wall"},
		{"pos": Vector3(0, 24, -14), "normal": Vector3.DOWN, "ax": Vector3.RIGHT, "ay": Vector3.BACK, "half": Vector2(20, 18), "label": "ceiling"},
		{"pos": Vector3(6, 6, -18), "normal": Vector3.UP, "ax": Vector3.RIGHT, "ay": Vector3.BACK, "half": Vector2(5, 3), "label": "table"},
	]
	var calls := [0]
	st.planes_provider = func() -> Array:
		calls[0] += 1
		return room
	st.update(b, DT)
	check.call(calls[0] > 0 and st.room() and not st.booth.visible, "gallery: mixed reality reads the room and hides the court's booth")
	check.call(st.rows.size() == 2 and st.rows.all(func(r): return absf((r.a as Vector3).z + 30.0) < 3.0 or absf((r.a as Vector3).x + 20.0) < 3.0), "gallery: the rows run along the two widest walls")
	var ok_card := true
	var ok_swing := true
	var ok_peek := true
	var ok_toss := true
	for k in 12:
		var a := st.spawn("card")
		if a >= 0:
			var p: Vector3 = st.targets[a].base
			ok_card = ok_card and (absf(p.y) < 0.5 or absf(p.y - 6.0) < 0.5 or absf(p.z + 30.0) < 1.0 or absf(p.x + 20.0) < 1.0)
			st.targets[a].on = false
		var s2 := st.spawn("swing")
		if s2 >= 0:
			ok_swing = ok_swing and absf((st.targets[s2].anchor as Vector3).y - 24.0) < 0.5
			st.targets[s2].on = false
		var p2 := st.spawn("peek")
		if p2 >= 0:
			var hp: Vector3 = st.targets[p2].out_p
			ok_peek = ok_peek and st.targets[p2].grow and (absf(hp.y - 6.0) < 3.0 or absf(hp.z + 30.0) < 3.0 or absf(hp.x + 20.0) < 3.0)
			st.targets[p2].on = false
		var t2 := st.spawn("toss")
		if t2 >= 0:
			var tp: Vector3 = st.targets[t2].p
			ok_toss = ok_toss and (absf(tp.y - 1.2) < 0.6 or absf(tp.y - 7.2) < 0.6)
			st.targets[t2].on = false
	check.call(ok_card, "gallery: room cards stand on the floor, the table or the walls")
	check.call(ok_swing, "gallery: room swingers hang from the ceiling")
	check.call(ok_peek, "gallery: room peekers come over the table's edge or out of wall edges, growing out")
	check.call(ok_toss, "gallery: room tosses go up from the floor or the table")
	var wall_card := st.spawn("card", "plain", {"pos": Vector3(0, 12, -29.8), "face": Vector3.BACK, "wall": true})
	check.call(st.targets[wall_card].flip == "spin", "gallery: a card on a wall spins round to face the room")
	st.free()
	# No scan: the court's booth.
	made = _make(sfx, extra)
	st = made[0]
	b = made[1]
	st.planes_provider = func() -> Array: return []
	st.update(b, DT)
	check.call(not st.room() and st.booth.visible and st.rows.size() == 3, "gallery: no scan, the court's booth")
	st.free()
