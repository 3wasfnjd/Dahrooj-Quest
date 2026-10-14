extends RefCounted
## Ricochet (tabletop): the five original rounds (as before 0.10: no aim snapping) can each be
## solved the way a player can, the paddles turn with the left stick and A picks the next
## one, and the six hearts.
##
## The solver plays by the game's own rules: the paddles snap to 5° steps (turn_mirror), a
## launch always has the same speed (no power: only the aim direction is chosen), and the
## fixed-step physics decide (TabletopGame.step). With each paddle at its designed angle it
## sweeps the aim all the way round and measures the widest run of aims that win: a round
## that needs a pixel-perfect aim fails here. Then each round is won through the stage
## itself: A to each paddle in turn, the left stick until it sits at its designed angle, aim
## with the trigger at the middle of that run, release.
##
## Hearts: a miss costs one (a squeak, an "ouch", the heart empties); a cleared round
## refills them; out of hearts the round starts over with six (no game over, the score
## stays); balance and maze have none.

const DT := 1.0 / 72.0
## The narrowest aim window (degrees) any round may need. The original rounds measure about
## 7.0°, 4.4°, 3.8°, 3.6° and 3.65° (round 5, the four-paddle route).
const MIN_WINDOW := 3.5
const LAST_WINDOW := 3.5


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


static func _frame(st: TabletopStage, inputs: Array, english := true, stick := Vector2.ZERO) -> void:
	st.xr_frame(DT, {"inputs": inputs, "active": true, "stick": stick, "style": "jelly", "accessory": "", "eye": Vector3(0, 1.6, 0.6), "english": english})


## Holds the left stick toward the designed angle of the selected paddle until it sits there
## (full push: one step at once, then repeating), then lets go. True when it got there.
static func stick_to(st: TabletopStage, want: float) -> bool:
	var g := st.game
	for n in 72 * 12:
		var d := angle_difference(g.angles[st.selected], TabletopGame.snap_mirror_angle(want))
		if absf(d) < 1e-6:
			_frame(st, [])
			return true
		_frame(st, [], true, Vector2(1.0 if d > 0.0 else -1.0, 0.0))
	return false


## The player's way: A to each paddle in turn and the left stick until it sits at the
## designed angle, then aim with the trigger toward deg and let go. True on a win.
static func play(st: TabletopStage, deg: float) -> bool:
	var g := st.game
	var l: Dictionary = g.definition()
	_frame(st, [])
	for i in l.mirrors.size():
		if i > 0 and not st.next_paddle():
			return false
		if st.selected != i or not stick_to(st, l.solution[i]):
			return false
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
	_controls(check)
	var levels := TabletopGame.ricochet_levels()
	# The original five rounds (before 0.10): 1, 2, 3, 3 and 4 paddles; round 5 the long
	# four-paddle route round a block.
	var counts: Array = levels.map(func(l): return (l.mirrors as Array).size())
	check.call(levels.size() == 5 and counts == [1, 2, 3, 3, 4] and (levels[4].start as Vector2).is_equal_approx(Vector2(-0.9, 1.32)),
		"ricochet: the original rounds are back (paddles %s)" % [counts])
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
		# Through the stage: A and the left stick for every paddle, aim with the trigger, release.
		st.game.reset(lv)
		_frame(st, [])
		var ok := w.y > w.x and play(st, (w.x + w.y) * 0.5)
		check.call(ok and won_rounds.size() > 0 and int(won_rounds[won_rounds.size() - 1].level) == lv,
			"ricochet: round %d won the player's way (A and the left stick turn the paddles, a trigger aim at %.1f°)" % [lv + 1, (w.x + w.y) * 0.5])
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


## The paddle controls: one paddle is selected (it glows, the arrow over it); A steps to the
## next one and wraps; the left stick turns it in 5° steps (one on a push, repeating when
## held, faster pushed all the way, nothing under the dead zone, never while he rolls); the
## grip no longer takes a paddle; the trigger still aims and launches.
static func _controls(check: Callable) -> void:
	var st := TabletopStage.new("ricochet")
	st.place_table(Transform3D.IDENTITY, 0.32)
	var sfx: Array = []
	st.sfx = func(n, k, _p): sfx.append([n, k])
	var g := st.game
	g.reset(2)  # three paddles
	_frame(st, [])
	check.call(st.selected == 0 and st.paddle_count() == 3 and st.mirrors[0].material_override == st.mats.selected
		and st.mirrors[1].material_override != st.mats.selected and st.marker.visible
		and absf(st.marker.position.x - st.mirrors[0].position.x) < 1e-4, "ricochet controls: the first paddle starts selected (it glows, the arrow over it)")
	var picks: Array = []
	for k in 3:
		st.next_paddle()
		_frame(st, [])
		picks.append(st.selected)
	check.call(picks == [1, 2, 0] and st.mirrors[1].material_override != st.mats.selected and sfx.any(func(e): return e[0] == "bricks_tink"),
		"ricochet controls: A steps through the paddles and wraps round (%s), a click each" % [picks])
	var step := TabletopGame.MIRROR_ANGLE_STEP
	var others := [g.angles[1], g.angles[2]]
	var a0: float = g.angles[0]
	_frame(st, [], true, Vector2(0.4, 0))
	check.call(absf(g.angles[0] - a0) < 1e-6, "ricochet controls: a light touch of the stick (dead zone) does nothing")
	_frame(st, [], true, Vector2(0.8, 0))
	var one := angle_difference(a0, g.angles[0])
	for i in int(0.25 / DT):
		_frame(st, [], true, Vector2(0.8, 0))
	var still := angle_difference(a0, g.angles[0])
	check.call(absf(one - step) < 1e-6 and absf(still - step) < 1e-6, "ricochet controls: pushing the left stick right turns the selected paddle one 5° step (%.1f°, %.1f° after .25 s)" % [rad_to_deg(one), rad_to_deg(still)])
	for i in int(0.75 / DT):
		_frame(st, [], true, Vector2(0.55, 0))
	var slow := roundi(angle_difference(a0, g.angles[0]) / step)
	_frame(st, [])
	var b0: float = g.angles[0]
	_frame(st, [], true, Vector2(-1, 0))
	for i in int(1.0 / DT) - 1:
		_frame(st, [], true, Vector2(-1, 0))
	var fast := roundi(-angle_difference(b0, g.angles[0]) / step)
	check.call(slow >= 3 and fast > slow + 3, "ricochet controls: held, it repeats, faster pushed all the way (%d steps in 1 s eased, %d steps in 1 s full left)" % [slow, fast])
	_frame(st, [])
	check.call([g.angles[1], g.angles[2]] == others, "ricochet controls: only the selected paddle turns")
	st.next_paddle()
	var c0: float = g.angles[1]
	_frame(st, [], true, Vector2(1, 0))
	_frame(st, [])
	check.call(absf(angle_difference(c0, g.angles[1]) - step) < 1e-6, "ricochet controls: after A the stick turns the next paddle")
	# The grip no longer turns a paddle; the trigger still aims and launches.
	var m: Dictionary = g.definition().mirrors[1]
	var above: Vector3 = st._board_xf() * Vector3(m.x, 2.0, m.z)
	check.call(not st.xr_press(_hand("right", Quaternion.IDENTITY, above), "grip") and st.grips.is_empty(), "ricochet controls: the grip leaves the paddles alone")
	var s0: Vector2 = g.ball
	var aim_at: Vector3 = st._board_xf() * Vector3(s0.x + 0.08, TabletopGame.TABLE_RADIUS, s0.y - 1.0)
	var eye: Vector3 = st._board_xf() * Vector3(s0.x, 3.0, s0.y + 0.5)
	var hand := _hand("right", Quaternion.IDENTITY, eye, aim_at - eye)
	check.call(st.xr_press(hand, "trigger"), "ricochet controls: the trigger aims")
	_frame(st, [hand])
	var aim := st.aim
	st.xr_release(hand, false, "trigger")
	check.call(g.phase == "playing" and aim.x > 0.05, "ricochet controls: and launches where the hand points, 4.6° off straight ahead stays off (no aim snapping: %.3f, %.3f)" % [aim.x, aim.y])
	var d0: float = g.angles[1]
	_frame(st, [], true, Vector2(1, 0))
	check.call(g.angles[1] == d0, "ricochet controls: the paddles hold still while he rolls")
	st.free()
