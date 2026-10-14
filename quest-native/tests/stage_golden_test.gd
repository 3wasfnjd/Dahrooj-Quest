extends RefCounted
## The Golden Dahrooj (GoldenDahrooj), personal records (Save.records, GameRuntime.track_records)
## and the points an attack takes (GameRuntime.penalty):
## - golden: one every 60–120 s of active play (the clock waits otherwise), never two at once,
##   always in front of the player (±70°, 2 m or more, all through his zig-zag) in VR and in the
##   room; he escapes with a puff after 6–8 s; a catch gives +500 to the mode and counts the two
##   golden challenges (each with its own new reward);
## - records: saved per mode, celebrated once per session when beaten (not the first time a
##   mode scores), kept quietly after that; old saves load them as 0; the menu shows them;
## - attacks: the score drops but never below 0; records, the lifetime total and the
##   challenges keep what they had.

const DT := 0.25


static func run(check: Callable) -> void:
	_timing(check)
	_placement(check)
	_escape_and_catch(check)
	_challenges(check)
	var path: String = Save.PATH
	var had := FileAccess.file_exists(path)
	var before := FileAccess.get_file_as_string(path) if had else ""
	var keep: Dictionary = Save.challenges.duplicate(true)
	var keep_rec: Dictionary = Save.records.duplicate(true)
	var keep_total: int = Save.total_score
	_records(check)
	_penalty(check)
	_migration(check)
	Save.challenges.clear()
	Save.challenges.merge(keep)
	Save.records = keep_rec
	Save.total_score = keep_total
	if had:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(before)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_menu(check)


static func _golden() -> GoldenDahrooj:
	var g := GoldenDahrooj.new()
	g.rng.seed = 4242
	g.wait = g.next_wait()
	g.unit = 2.0
	g.eye = Vector3(0, 3.2, 1.0)
	return g


## Spawn timing: 60–120 s of active play, the clock paused out of play, never two at once.
static func _timing(check: Callable) -> void:
	var g := _golden()
	var asked := {"n": 0}
	var spot := func() -> Variant:
		asked.n += 1
		return GoldenDahrooj.air_spot(g.eye, Vector3.FORWARD, g.unit, 0.0, g.rng)
	check.call(g.wait >= 60.0 and g.wait <= 120.0 and not g.active, "golden: the first one is 60–120 s of play away (%.0f s)" % g.wait)
	for i in int(400.0 / DT):
		g.step(DT, false, spot)
	check.call(not g.active and g.appeared == 0 and asked.n == 0, "golden: the clock waits while you are not playing (menu, other modes)")
	var t := 0.0
	var first := -1.0
	var starts: Array = []
	var was := false
	var two := false
	var calls_while_out := 0
	while t < 1800.0:
		var n0: int = asked.n
		var out := g.active
		g.step(DT, true, spot)
		t += DT
		if out and asked.n > n0:
			calls_while_out += 1
		if g.active and not was:
			starts.append(t)
			if first < 0.0:
				first = t
		was = g.active
		two = two or g.appeared - g.caught - g.escaped > 1
	var gaps_ok := true
	for i in range(1, starts.size()):
		var gap: float = float(starts[i]) - float(starts[i - 1])
		gaps_ok = gaps_ok and gap >= GoldenDahrooj.EVERY.x + GoldenDahrooj.STAY.x - DT and gap <= GoldenDahrooj.EVERY.y + GoldenDahrooj.STAY.y + DT
	check.call(first >= 60.0 and first <= 120.0 + DT, "golden: the first turns up after 60–120 s of play (%.1f s)" % first)
	check.call(starts.size() >= 12 and starts.size() <= 26 and gaps_ok, "golden: about one every 60–120 s (%d in 30 minutes)" % starts.size())
	check.call(not two and calls_while_out == 0, "golden: never more than one at a time")
	g.free()


## Every spot and every point of his flight is in front of the player: within 70° of the play
## direction and 2 m away or more (RoomSpots' rule), in VR, in the room and over the courses.
static func _placement(check: Callable) -> void:
	var g := _golden()
	var bad: Array = []
	var near_m := 99.0
	var widest := 0.0
	for k in 240:
		var unit := 2.0 if k % 2 == 0 else 8.0
		var fwd := RoomSpots.dir_at(Vector3.FORWARD, g.rng.randf_range(-0.6, 0.6))
		var eye := Vector3(g.rng.randf_range(-3, 3), 1.6 * unit, g.rng.randf_range(-2, 4))
		var p: Vector3
		match k % 3:
			0:
				p = GoldenDahrooj.air_spot(eye, fwd, unit, 0.0, g.rng)
			1:
				p = GoldenDahrooj.air_spot(eye, fwd, unit, 0.0, g.rng, Vector2(2.6, 3.6), Vector2(1.0, 1.8))
			_:
				p = GoldenDahrooj.course_spot(eye, fwd, unit, -10.0, g.rng)
		g.unit = unit
		g.mr = unit > 2.0
		g.eye = eye
		g.appear(p)
		var tt := 0.0
		while tt <= g.life:
			var q := g.motion(tt)
			var d := Vector2(q.x - eye.x, q.z - eye.z)
			near_m = minf(near_m, d.length() / unit)
			widest = maxf(widest, absf(RoomSpots.flat_dir(fwd).angle_to(d)))
			if not RoomSpots.ahead(eye, q, RoomSpots.MIN_DIST * unit, fwd):
				bad.append([k, tt])
				break
			tt += 0.1
		g.clear()
	check.call(bad.is_empty() and near_m >= 2.0, "golden: always in front, 2 m away or more, all through his zig-zag (nearest %.2f m, widest %.0f°) %s" % [near_m, rad_to_deg(widest), bad.slice(0, 4)])
	check.call(widest <= deg_to_rad(70.0), "golden: never wider than 70° off the play direction")
	g.free()


## He escapes in a puff if nobody gets him; a hit catches him once.
static func _escape_and_catch(check: Callable) -> void:
	var g := _golden()
	var sounds: Array = []
	g.sfx = func(n: String, _k: float, _p: Vector3) -> void: sounds.append(n)
	var events := {"esc": 0, "caught": [], "appear": 0}
	g.on_escape = func(_p: Vector3) -> void: events.esc += 1
	g.on_appear = func(_p: Vector3) -> void: events.appear += 1
	g.on_caught = func(p: Vector3, how: String) -> void: (events.caught as Array).append([p, how])
	g.appear(Vector3(0, 4, -12))
	check.call(g.active and g.holder.visible and events.appear == 1 and "chime" in sounds and g.life >= 6.0 and g.life <= 8.0, "golden: he appears with a chime, for 6–8 s (%.1f s)" % g.life)
	var p0 := g.pos
	var moved := 0.0
	var tt := 0.0
	while g.active and tt < 10.0:
		g.step(0.05, true, Callable())
		tt += 0.05
		moved = maxf(moved, g.pos.distance_to(p0))
	check.call(not g.active and not g.holder.visible and g.escaped == 1 and events.esc == 1 and tt >= 6.0 - 0.06 and tt <= 8.0 + 0.06 and "whoosh" in sounds and "start_pop" in sounds,
		"golden: nobody got him: he escapes in a puff after %.1f s" % tt)
	check.call(moved > 0.2 and moved < (GoldenDahrooj.SWAY + GoldenDahrooj.BOB + 0.05) * g.unit, "golden: he zig-zags and bobs about his spot (%.2f units)" % moved)
	check.call(g.wait >= 60.0 and g.wait <= 120.0, "golden: and the next one is 60–120 s away again")
	g.appear(Vector3(0, 4, -12))
	g.step(0.1, true, Callable())
	check.call(g.hit_by(g.pos + Vector3(0, 0, g.radius() + Ball.BR * 0.9), Ball.BR) and not g.hit_by(g.pos + Vector3(0, 0, g.radius() * 2.0 + Ball.BR * 2.0), Ball.BR),
		"golden: a ball that reaches him hits, one that passes by does not")
	check.call(g.catch("throw") and not g.catch("throw") and not g.active and g.caught == 1 and (events.caught as Array).size() == 1 and (events.caught as Array)[0][1] == "throw",
		"golden: a hit catches him (once)")
	check.call(g.pals_out() == GoldenDahrooj.PALS and g._sparks.size() > 30, "golden: little bonus Dahroojs and a golden burst pop out of him")
	g.step(1.5, false, Callable())
	check.call(g.pals_out() == 0, "golden: the bonus Dahroojs pop a moment later")
	check.call(not ("mole" in GoldenDahrooj.MODES) and "invasion" in GoldenDahrooj.MODES and "goal" in GoldenDahrooj.MODES and "castle" in GoldenDahrooj.MODES
		and not ("balance" in GoldenDahrooj.MODES) and not ("climb" in GoldenDahrooj.MODES) and not ("rain" in GoldenDahrooj.MODES),
		"golden: in the throwing and arcade modes (mole keeps its own golden moles), not the tabletops, Summit or rain")
	g.free()


## A catch: +500 on the mode's score, golden1 done (its card), golden25 counts; each has its own
## new reward, early and late in the list.
static func _challenges(check: Callable) -> void:
	var keep: Dictionary = Save.challenges.duplicate(true)
	Save.challenges.clear()
	var b := Ball.new()
	var parent := Node3D.new()
	var rt := GameRuntime.new(b, parent)
	var toasts: Array = []
	rt.ctx.toast = func(t: String) -> void: toasts.append(t)
	rt.counts["meteor"] = 40
	rt.golden_caught("meteor")
	check.call(int(rt.counts.meteor) == 540 and GameRuntime.GOLDEN_POINTS == 500, "golden: a catch gives +500 to the mode's score")
	check.call(int(Save.challenges.get("golden1", 0)) == 1 and int(Save.challenges.get("golden25", 0)) == 1 and toasts.size() == 1 and str(toasts[0]).begins_with("✓ "),
		"golden: «اصطد أول دحروج ذهبي» done with its card, one toward 25 (%s)" % [toasts])
	for i in 24:
		rt.golden_caught("goal")
	check.call(int(Save.challenges.get("golden25", 0)) == 25 and toasts.size() == 2, "golden: 25 caught: «اصطد ٢٥ دحروج ذهبي» done with its card")
	var r1 := ChallengeRewards.reward_of("golden1")
	var r25 := ChallengeRewards.reward_of("golden25")
	check.call(r1.get("id", "") == "goldStar" and r25.get("id", "") == "goldPal" and r1.kind == "acc" and r25.kind == "acc",
		"golden: the golden star for the first, the little golden Dahrooj for 25")
	var ids: Array = []
	for c: Array in GameRuntime.CHALLENGES:
		ids.append(c[0])
	check.call(ids.find("golden1") == ids.find("pop20") + 1 and ids.find("golden25") == ids.find("pop500") + 1 and ids.find("golden1") < ids.find("mazeClean"),
		"golden: the first catch among the early challenges, 25 among the big ones")
	parent.free()
	Save.challenges.clear()
	Save.challenges.merge(keep)


## Records: the first score in a mode is just saved; a later session that beats it celebrates
## once; after that the best keeps up silently; saved with the game.
static func _records(check: Callable) -> void:
	Save.records = {}
	Save.challenges.clear()
	var b := Ball.new()
	var parent := Node3D.new()
	var rt := GameRuntime.new(b, parent)
	var got: Array = []
	rt.on_record = func(m: String, s: int, prev: int) -> void: got.append([m, s, prev])
	rt.counts["meteor"] = 100
	rt.track_scores()
	check.call(Save.record("meteor") == 100 and got.is_empty(), "records: a first score is saved as the best, no fanfare")
	rt.counts["meteor"] = 180
	rt.track_scores()
	check.call(Save.record("meteor") == 180 and got.is_empty(), "records: ... and keeps up quietly that session")
	rt.flush()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Save.PATH))
	check.call(int((saved.get("records", {}) as Dictionary).get("meteor", 0)) == 180, "records: saved with the game")
	parent.free()
	# The next session.
	var parent2 := Node3D.new()
	var rt2 := GameRuntime.new(b, parent2)
	rt2.on_record = func(m: String, s: int, prev: int) -> void: got.append([m, s, prev])
	rt2.counts["meteor"] = 150
	rt2.track_scores()
	check.call(got.is_empty() and Save.record("meteor") == 180, "records: below the best, nothing")
	rt2.counts["meteor"] = 190
	rt2.track_scores()
	check.call(got.size() == 1 and got[0] == ["meteor", 190, 180] and Save.record("meteor") == 190, "records: beaten: celebrated (%s)" % [got])
	rt2.counts["meteor"] = 400
	rt2.track_scores()
	rt2.counts["meteor"] = 900
	rt2.track_scores()
	check.call(got.size() == 1 and Save.record("meteor") == 900, "records: only once a session, then kept up silently (900)")
	rt2.counts["goal"] = 3
	rt2.track_scores()
	check.call(got.size() == 1 and Save.record("goal") == 3, "records: each mode its own")
	parent2.free()


## Attacks: the session score drops (floor 0); the record, the lifetime total and earned
## challenges stay.
static func _penalty(check: Callable) -> void:
	Save.records = {}
	Save.challenges.clear()
	Save.total_score = 0
	var b := Ball.new()
	var parent := Node3D.new()
	var rt := GameRuntime.new(b, parent)
	var fb: Array = []
	rt.on_penalty = func(m: String, taken: int, asked: int, _at: Vector3) -> void: fb.append([m, taken, asked])
	rt.counts["invasion"] = 1200
	rt.track_scores()
	check.call(int(Save.challenges.get("score1k", 0)) == 1000 and Save.total_score == 1200, "attacks: 1,200 scored (score1k done)")
	var t1 := rt.ctx.penalty.call("invasion", 50, Vector3.ZERO) as int
	rt.track_scores()
	check.call(t1 == 50 and int(rt.counts.invasion) == 1150 and fb.size() == 1 and fb[0] == ["invasion", 50, 50], "attacks: -50 off the score, with its feedback")
	check.call(Save.record("invasion") == 1200 and Save.total_score == 1200 and int(Save.challenges.get("score1k", 0)) == 1000,
		"attacks: the record, the lifetime total and the challenge stay")
	rt.counts["invasion"] = 30
	var t2 := rt.penalty("invasion", 100)
	check.call(t2 == 30 and int(rt.counts.invasion) == 0 and fb[1] == ["invasion", 30, 100], "attacks: never below 0 (took 30 of 100)")
	var t3 := rt.penalty("invasion", 25)
	check.call(t3 == 0 and int(rt.counts.invasion) == 0 and fb.size() == 3, "attacks: at 0 nothing more is taken (the bump and flash still come)")
	rt.counts["invasion"] = 200
	rt.track_scores()
	check.call(Save.total_score == 1200 and Save.record("invasion") == 1200, "attacks: winning points back does not count twice")
	parent.free()


## An old save (no records) loads them as 0; odd values are dropped.
static func _migration(check: Callable) -> void:
	var old := {"version": 1, "language": "ar", "challenges": {"keeper3": 3}, "total_score": 50}
	var f := FileAccess.open(Save.PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	Save.records = {"goal": 5}
	Save.load_data()
	check.call(Save.records.is_empty() and Save.record("goal") == 0 and Save.record("meteor") == 0 and int(Save.challenges.get("keeper3", 0)) == 3,
		"records: a save from before them loads every record as 0")
	old["records"] = {"goal": 12, "meteor": 340.0, "bad": "x", "neg": -4}
	f = FileAccess.open(Save.PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	Save.load_data()
	check.call(Save.record("goal") == 12 and Save.record("meteor") == 340 and not Save.records.has("bad") and not Save.records.has("neg"), "records: loaded, odd values dropped")


## The mode cards: «الأفضل: ١٢٬٣٤٠» / "Best: 12,340" under the name, grouped, fitting in both
## languages; nothing before a mode has a record.
static func _menu(check: Callable) -> void:
	check.call(MenuPanel.best_text(12340, false) == "Best: 12,340" and MenuPanel.best_text(12340, true) == "الأفضل: ١٢٬٣٤٠" and MenuPanel.best_text(0, true) == "",
		"records: «الأفضل: ١٢٬٣٤٠» / \"Best: 12,340\"")
	var p := MenuPanel.new()
	var recs := {}
	for c: Array in MenuCatalog.MODES:
		recs[c[0]] = 1234567
	recs["goal"] = 12340
	recs.erase("hoop")
	var bad: Array = []
	var shown: Array = []
	for en in [false, true]:
		p.set_page("modes")
		p.draw({"english": en, "kind": "vr", "mode": "goal", "records": recs, "challenges": []}, -1)
		for r: Dictionary in p.measure():
			if float(r.w) > float(r.max_w) + 0.5 or int(r.size) < Glass.MIN_SIZE:
				bad.append(r.s)
			if str(r.s) in ["Best: 12,340", "الأفضل: ١٢٬٣٤٠"]:
				shown.append(r.s)
		var hoop: Dictionary = {}
		for b: Dictionary in p.buttons:
			if b.kind == "mode" and b.id == "hoop":
				hoop = b
		if str(hoop.get("best", "x")) != "":
			bad.append("hoop has a best")
	check.call(bad.is_empty() and shown.size() == 2, "records: each mode card shows its best, fitting in Arabic and English %s %s" % [shown, bad.slice(0, 4)])
	p.free()
