extends RefCounted
## Ricochet (tabletop): every round can be solved the way a player can, with room to spare,
## and the six hearts.
##
## The solver plays by the game's own rules: the paddles snap to 5° steps (turn_mirror), a
## launch always has the same speed (no power: only the aim direction is chosen), and the
## fixed-step physics decide (TabletopGame.step). With each paddle at its designed angle it
## sweeps the aim all the way round and measures the widest run of aims that win: a round
## that needs a pixel-perfect aim fails here. Then each round is won through the stage
## itself: grip-turn every paddle, aim with the trigger at the middle of that run, release.
##
## Hearts: a miss costs one (a squeak, an "ouch", the heart empties); a cleared round
## refills them; out of hearts the round starts over with six (no game over, the score
## stays); balance and maze have none.

const DT := 1.0 / 72.0
## The narrowest aim window (degrees) any round may need; the last round gets more room.
const MIN_WINDOW := 3.5
const LAST_WINDOW := 4.5


static func _launch(level: int, angles: Array, deg: float) -> TabletopGame:
	var g := TabletopGame.new("ricochet")
	g.reset(level)
	for i in angles.size():
		g.turn_mirror(i, angles[i])
	var a := deg_to_rad(deg)
	g.launch(Vector2(cos(a), sin(a)))
	var n := 0
	while g.phase == "playing" and n < 120 * 10:
		g.step(TabletopGame.STEP)
		n += 1
	return g


static func wins(level: int, angles: Array, deg: float) -> bool:
	return _launch(level, angles, deg).phase == "won"


## The widest run of winning aims (degrees, Vector2(from, to)), or Vector2.ZERO: a 0.5°
## sweep all the way round, then 0.05° steps across the best run's edges.
static func best_window(level: int, angles: Array) -> Vector2:
	var hits: Array = []
	for i in 720:
		hits.append(wins(level, angles, i * 0.5))
	var best := Vector2.ZERO
	var best_n := 0
	for i in 720:
		if not hits[i] or hits[(i + 719) % 720]:
			continue
		var n := 0
		while n < 720 and hits[(i + n) % 720]:
			n += 1
		if n > best_n:
			best_n = n
			best = Vector2(i * 0.5, (i + n - 1) * 0.5)
	if best_n == 0:
		return Vector2.ZERO
	var lo := best.x
	while wins(level, angles, lo - 0.05) and lo > best.x - 0.5:
		lo -= 0.05
	var hi := best.y
	while wins(level, angles, hi + 0.05) and hi < best.y + 0.5:
		hi += 0.05
	return Vector2(lo, hi)


static func _hand(id: String, rot := Quaternion.IDENTITY, origin := Vector3(0, 1, 0), dir := Vector3.DOWN) -> Dictionary:
	return {"id": id, "ray": {"origin": origin, "dir": dir.normalized()}, "position": Vector3(0.2, 0.9, 0.3), "rotation": rot}


static func _frame(st: TabletopStage, inputs: Array, english := true) -> void:
	st.xr_frame(DT, {"inputs": inputs, "active": true, "style": "jelly", "accessory": "", "eye": Vector3(0, 1.6, 0.6), "english": english})


## The player's way: grip each paddle from above and turn the hand until it sits at the
## designed angle, then aim with the trigger toward deg and let go. True on a win.
static func play(st: TabletopStage, deg: float) -> bool:
	var g := st.game
	var l: Dictionary = g.definition()
	_frame(st, [])
	for i in l.mirrors.size():
		var m: Dictionary = l.mirrors[i]
		var above: Vector3 = st._board_xf() * Vector3(m.x, 2.0, m.z)
		if not st.xr_press(_hand("right", Quaternion.IDENTITY, above), "grip"):
			return false
		var want: float = l.solution[i] - g.angles[i]
		want = atan2(sin(want), cos(want))
		_frame(st, [_hand("right", Quaternion(Vector3.UP, -want), above)])
		st.xr_release(_hand("right"), false, "grip")
		_frame(st, [])
	var a := deg_to_rad(deg)
	var b: Vector2 = g.ball
	var aim_at: Vector3 = st._board_xf() * Vector3(b.x + cos(a), TabletopGame.TABLE_RADIUS, b.y + sin(a))
	var eye: Vector3 = st._board_xf() * Vector3(b.x, 3.0, b.y + 0.4)
	var hand := _hand("right", Quaternion.IDENTITY, eye, aim_at - eye)
	if not st.xr_press(hand, "trigger"):
		return false
	_frame(st, [hand])
	st.xr_release(hand, false, "trigger")
	var level := g.level
	for i in 72 * 6:
		_frame(st, [hand])
		if g.phase == "won" or g.level != level:
			return true
		if g.phase != "playing":
			return false
	return false


static func run(check: Callable) -> void:
	var levels := TabletopGame.ricochet_levels()
	var windows: Array = []
	var st := TabletopStage.new("ricochet")
	st.place_table(Transform3D.IDENTITY, 0.32)
	var won_rounds: Array = []
	st.tabletop_win = func(r): won_rounds.append(r)
	for lv in levels.size():
		var l: Dictionary = levels[lv]
		# The designed angles are paddle positions a player can reach (5° steps).
		var reachable := true
		for a: float in l.solution:
			if absf(TabletopGame.snap_mirror_angle(a) - atan2(sin(a), cos(a))) > 1e-6:
				reachable = false
		var w := best_window(lv, l.solution)
		windows.append(snappedf(w.y - w.x, 0.05))
		var need := LAST_WINDOW if lv == levels.size() - 1 else MIN_WINDOW
		check.call(reachable and w.y - w.x >= need,
			"ricochet solver: round %d can be solved with room to spare (aims %.2f°..%.2f°, a %.2f° window, needs %.1f°)" % [lv + 1, w.x, w.y, w.y - w.x, need])
		# Through the stage: turn every paddle with the grip, aim with the trigger, release.
		st.game.reset(lv)
		var ok := w.y > w.x and play(st, (w.x + w.y) * 0.5)
		check.call(ok and won_rounds.size() > 0 and int(won_rounds[won_rounds.size() - 1].level) == lv,
			"ricochet: round %d won the player's way (grip-turned paddles, a trigger aim at %.1f°)" % [lv + 1, (w.x + w.y) * 0.5])
		# A paddle left as the round starts it misses that aim.
		check.call(not wins(lv, [], (w.x + w.y) * 0.5), "ricochet: round %d is a puzzle (the starting paddles miss)" % (lv + 1))
	check.call(windows.all(func(w): return w >= MIN_WINDOW), "ricochet: every round's aim window in degrees %s" % [windows])
	st.free()

	# Hearts: six; a miss costs one with a squeak, an "ouch" and the heart emptying.
	st = TabletopStage.new("ricochet")
	st.place_table(Transform3D.IDENTITY, 0.32)
	var sfx: Array = []
	st.sfx = func(n, k, _p): sfx.append([n, k])
	var lost: Array = []
	var restarts: Array = []
	var g := st.game
	g.heart_lost.connect(func(left): lost.append(left))
	g.restarted.connect(func(): restarts.append(g.level))
	_frame(st, [])
	check.call(g.hearts == 6 and g.max_hearts == TabletopGame.RICOCHET_HEARTS and st.hearts.size() == 6 and st.heart_row.visible
		and st.hearts.all(func(h): return h.material_override == st.mats.heart), "ricochet hearts: six full hearts on the sign")
	var miss_aim := 90.0  # straight back off the near edge
	g.launch(Vector2(cos(deg_to_rad(miss_aim)), sin(deg_to_rad(miss_aim))))
	for i in 72 * 3:
		_frame(st, [])
		if g.phase == "falling":
			break
	check.call(g.phase == "falling" and g.hearts == 5 and lost == [5], "ricochet hearts: a missed launch costs one (%d left)" % g.hearts)
	check.call(sfx.any(func(e): return e[0] == "squeak") and not JuiceText.showing(st).is_empty() and (st.sign_lines[1] as Label3D).text.begins_with("Lost a heart! 5 left"),
		"ricochet hearts: a squeak, an ouch and the sign says so (%s)" % (st.sign_lines[1] as Label3D).text)
	var popped := (st.hearts[5] as MeshInstance3D).basis.get_scale().x / TabletopStage.HEART_SIZE
	for i in 72:
		_frame(st, [])
	check.call(popped > 1.05 and st.hearts[5].material_override == st.mats.heart_empty and st.hearts[4].material_override == st.mats.heart and g.phase == "ready",
		"ricochet hearts: the lost heart pops (×%.2f) then sits empty; he is back at the start" % popped)
	# A cleared round refills them.
	var score0 := g.score
	var w0 := best_window(0, levels[0].solution)
	for i in g.angles.size():
		g.turn_mirror(i, levels[0].solution[i])
	var a0 := deg_to_rad((w0.x + w0.y) * 0.5)
	g.launch(Vector2(cos(a0), sin(a0)))
	for i in 72 * 6:
		_frame(st, [])
		if g.level == 1:
			break
	_frame(st, [])
	check.call(g.level == 1 and g.hearts == 6 and g.score > score0 and st.hearts.all(func(h): return h.material_override == st.mats.heart), "ricochet hearts: a cleared round refills them")
	# Out of hearts: the round again from the top with six (no game over, the score stays).
	var start_angles: Array = g.angles.duplicate()
	g.turn_mirror(0, g.angles[0] + 0.5)
	var score1 := g.score
	lost.clear()
	for k in 6:
		g.launch(Vector2(cos(deg_to_rad(miss_aim)), sin(deg_to_rad(miss_aim))))
		for i in 72 * 3:
			_frame(st, [])
			if g.phase == "falling":
				break
		if k == 5:
			check.call(g.hearts == 0 and (st.sign_lines[1] as Label3D).text.begins_with("Out of hearts!"), "ricochet hearts: the last one goes (%s)" % (st.sign_lines[1] as Label3D).text)
		for i in 72 * 2:
			_frame(st, [])
			if g.phase == "ready":
				break
	check.call(lost == [5, 4, 3, 2, 1, 0] and restarts == [1], "ricochet hearts: six misses, then the round restarts (%s, %s)" % [lost, restarts])
	check.call(g.hearts == 6 and g.level == 1 and g.phase == "ready" and g.score == score1 and g.attempts == 0 and g.angles == start_angles and g.ball == g.start_point(),
		"ricochet hearts: full hearts, the same round from the top, the score kept")
	for i in 30:
		_frame(st, [])
	check.call(st.hearts.all(func(h): return h.material_override == st.mats.heart) and sfx.any(func(e): return e[0] == "swish"), "ricochet hearts: they all pop back in")
	st.free()

	# Only in ricochet.
	for m in ["balance", "maze"]:
		var t := TabletopStage.new(m)
		t.place_table(Transform3D.IDENTITY, 0.32)
		t.game.ball = Vector2(-1.55, 1.25)
		t.game.velocity = Vector2(-1, 0)
		t.game.phase = "playing"
		t.game._fail()
		check.call(t.game.max_hearts == 0 and t.game.hearts == 0 and t.hearts.is_empty() and t.heart_row == null, "%s: no hearts (only ricochet has them)" % m)
		t.free()
