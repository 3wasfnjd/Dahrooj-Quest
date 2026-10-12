extends RefCounted
## Tabletops (balance, ricochet, maze): each mode builds its board; tilting the balance board
## with a held grip rolls Dahrooj along the bridge to the goal and wins; maze walls block and
## the maze can be solved; a ricochet paddle turned with the grip bounces a trigger launch
## into the goal; wins record progress as tabletop-progress.ts does; retry resets.

const DT := 1.0 / 72.0


static func _hand(id: String, rot := Quaternion.IDENTITY, origin := Vector3(0, 1, 0), dir := Vector3.DOWN) -> Dictionary:
	return {"id": id, "ray": {"origin": origin, "dir": dir.normalized()}, "position": Vector3(0.2, 0.9, 0.3), "rotation": rot}


## The hand rotation that tilts the board by (tx, tz) from a grip taken level.
static func _tilt_rot(tx: float, tz: float) -> Quaternion:
	return Quaternion(Vector3.UP, Vector3(tan(tx), 1, tan(tz)).normalized())


static func _frame(st: TabletopStage, inputs: Array) -> void:
	st.xr_frame(DT, {"inputs": inputs, "active": true, "style": "jelly", "accessory": "", "eye": Vector3(0, 1.6, 0.6), "english": true})


## Steer the ball through waypoints by tilting a held board (a simple PD driver).
static func _drive(st: TabletopStage, points: Array, limit: float, wins: Array) -> bool:
	var g := st.game
	var i := 0
	var t := 0.0
	var start_level := g.level
	while t < limit and wins.is_empty():
		var target: Vector2 = points[mini(i, points.size() - 1)]
		if g.ball.distance_to(target) < 0.09 and i < points.size() - 1:
			i += 1
			continue
		var want := (target - g.ball).limit_length(0.25) * 2.4
		var acc := (want - g.velocity) * 1.6
		_frame(st, [_hand("right", _tilt_rot(clampf(acc.x * 0.3, -0.3, 0.3), clampf(acc.y * 0.3, -0.3, 0.3)))])
		t += DT
		if g.level != start_level:
			break
	return not wins.is_empty()


static func run(check: Callable) -> void:
	var sfx: Array = []
	# Every mode builds.
	for m in ["balance", "ricochet", "maze"]:
		var st := TabletopStage.new(m)
		st.place_table(Transform3D(Basis.IDENTITY, Vector3(0, 0.8, -0.8)), 0.32)
		_frame(st, [])
		var ok: bool = st.board != null and st.floor_mesh != null and st.goal != null and st.sign_lines.size() == 3 and st.character != null
		ok = ok and absf(st.scale.x - 0.32) < 1e-5 and st.game.level == 0 and st.game.phase == "ready"
		ok = ok and (st.sign_lines[0] as Label3D).text.begins_with(m.capitalize() + " · Round 1 / 5")
		if m == "ricochet":
			ok = ok and st.mirrors[0].visible and not st.mirrors[1].visible and st.obstacles[0].visible and not st.stars[0].visible and not st.handles[0].visible
		else:
			ok = ok and st.stars.all(func(s): return s.visible) and not st.mirrors[0].visible and st.handles[0].visible
		if m == "maze":
			ok = ok and st.maze_walls.multimesh.visible_instance_count == TabletopGame.maze_levels()[0].walls.size()
		check.call(ok, "tabletop %s: the board, sign, goal and pieces build" % m)
		st.free()

	# Levels as the reference defines them.
	var rl := TabletopGame.ricochet_levels()
	check.call(TabletopGame.balance_levels().size() == 5 and rl.size() == 5 and TabletopGame.maze_levels().size() == 5, "tabletop: five levels per mode")
	check.call(rl[3].mirrors.size() == 3 and rl[4].mirrors.size() == 4 and absf(rl[0].mirrors[0].angle + PI / 4) < 1e-9, "tabletop: ricochet routes and their paddles")
	var mz: Dictionary = TabletopGame.maze_levels()[0]
	check.call(mz.route.size() >= 3 and mz.walls.size() > 4 and mz.start == mz.route[0], "tabletop: a seeded maze with a route from the start")

	# Balance: the grip holds the board; tilting rolls Dahrooj to the goal.
	var st := TabletopStage.new("balance")
	st.place_table(Transform3D.IDENTITY, 0.32)
	st.sfx = func(n, k, _p): sfx.append([n, k])
	var wins: Array = []
	var best := {}
	var progress: Array = []
	st.tabletop_win = func(r): wins.append(r)
	check.call(not st.xr_press(_hand("right"), "trigger"), "balance: the trigger is left to the runtime (shots)")
	check.call(st.xr_press(_hand("right"), "grip"), "balance: the grip takes hold of the board")
	_frame(st, [_hand("right", _tilt_rot(0.2, 0.0))])
	check.call(st.game.tilt.x > 0.15 and absf(st.board.rotation.z + st.game.tilt.x) < 1e-6 and st.handles[0].material_override == st.mats.gold, "balance: turning the held hand tilts the board (handles go gold)")
	var start := st.game.ball
	for i in 20:
		_frame(st, [_hand("right", _tilt_rot(0.0, -0.25))])
	check.call(st.game.ball.y < start.y - 0.02, "balance: Dahrooj rolls downhill")
	st.xr_release(_hand("right"), false, "grip")
	var frozen := st.game.ball
	_frame(st, [_hand("right")])
	check.call(st.game.tilt == Vector2.ZERO and st.game.ball == frozen, "balance: letting go levels the board and freezes the ball")
	st.retry()
	check.call(st.game.ball == st.game.start_point() and st.game.failures == 1 and st.game.phase == "ready", "tabletop: retry puts Dahrooj back at the start (and counts)")
	st.game.reset(0)
	st.xr_press(_hand("right"), "grip")
	var l0: Dictionary = st.game.definition()
	var route := [l0.path[1], l0.path[2], l0.path[3]]
	var won := _drive(st, route, 40.0, wins)
	check.call(won and wins[0].mode == "balance" and wins[0].level == 0 and wins[0].stars == 3, "balance: tilting along the bridge collects the stars and wins (%s)" % [wins])
	check.call(sfx.any(func(s): return s[0] == "chime") and st.game.score == 3 and st.game.phase == "won", "balance: a win chimes and scores 3")
	for i in 72 * 2:
		_frame(st, [_hand("right")])
	check.call(st.game.level == 1 and st.game.phase != "won" and st.game.ball == st.game.start_point(), "balance: the next round follows")
	if not wins.is_empty():
		TabletopProgress.record_win(best, func(id, v): progress.append([id, v]), wins[0])
	check.call(best.get("tabletop:balance:cleared") == 1 and progress.has(["balance1", 1]) and progress.has(["balance5", 1]), "progress: a balance win records balance1 / balance5 (%s)" % [progress])
	check.call(progress.has(["balanceClean", 1]) == (wins.size() > 0 and wins[0].failures == 0), "progress: balanceClean only without falls")
	# Off the edge: a fall, then back to the start.
	st.game.reset(0)
	_frame(st, [_hand("right")])
	st.xr_press(_hand("right"), "grip")
	st.game.ball = Vector2(-1.55, 1.25)
	st.game.velocity = Vector2(-1, 0)
	_frame(st, [_hand("right")])
	check.call(st.game.phase == "falling" and st.game.failures == 1, "balance: off the bridge he falls")
	for i in 72:
		_frame(st, [_hand("right")])
	check.call(st.game.phase != "falling" and st.game.ball.distance_to(st.game.start_point()) < 0.2, "balance: and comes back to the start")
	st.free()

	# Progression edge cases.
	best = {"tabletop:maze:cleared": 0b10111}
	progress = []
	TabletopProgress.record_win(best, func(id, v): progress.append([id, v]), {"mode": "maze", "level": 3, "attempts": 0, "failures": 0, "stars": 3})
	check.call(best["tabletop:maze:cleared"] == 31 and progress.has(["maze5", 5]) and progress.has(["mazeClean", 1]), "progress: the fifth distinct maze fills maze5; clean run")
	progress = []
	TabletopProgress.record_win(best, func(id, v): progress.append([id, v]), {"mode": "maze", "level": 7, "attempts": 0, "failures": 0, "stars": 3})
	TabletopProgress.record_win(best, func(id, v): progress.append([id, v]), {"mode": "ricochet", "level": 0, "attempts": 2, "failures": 0, "stars": 0})
	check.call(not progress.has(["maze1", 1]) and progress.has(["ricochet1", 1]) and not progress.has(["ricochetAce", 1]), "progress: bad levels ignored; Ace only on the first throw")
	TabletopProgress.clear(best)
	check.call(best.is_empty(), "progress: clearing forgets the tabletop rounds")
	check.call(not GameRuntime.challenge("balance5").is_empty() and not GameRuntime.challenge("mazeClean").is_empty() and not GameRuntime.challenge("ricochetAce").is_empty(), "progress: the tabletop challenges exist")

	# Maze: walls block.
	st = TabletopStage.new("maze")
	st.place_table(Transform3D.IDENTITY, 0.32)
	wins = []
	st.tabletop_win = func(r): wins.append(r)
	var g := st.game
	st.xr_press(_hand("left"), "grip")
	for i in 72 * 3:
		_frame(st, [_hand("left", _tilt_rot(0.3, 0.0))])
	var x_edge := TabletopGame.LIMIT_X - TabletopGame.MAZE_WALL
	check.call(g.ball.x <= x_edge - TabletopGame.TABLE_RADIUS + 1e-3 and absf(g.velocity.x) < 0.05, "maze: Dahrooj stops at a wall (x %.3f)" % g.ball.x)
	# An inner divider between two cells.
	var divider := {}
	for w in g.definition().walls.slice(4):
		if w.hz > w.hx * 3.0:
			divider = w
			break
	var blocked := true
	if not divider.is_empty():
		g.ball = Vector2(divider.x - 0.3, divider.z)
		g.velocity = Vector2.ZERO
		for i in 72 * 2:
			_frame(st, [_hand("left", _tilt_rot(0.32, 0.0))])
			if g.ball.x > divider.x - divider.hx - TabletopGame.TABLE_RADIUS + 1e-3:
				blocked = false
	check.call(not divider.is_empty() and blocked, "maze: an inner divider stops him")
	# Fast into a wall: the sweep doesn't tunnel.
	var w0: Dictionary = g.definition().walls[0]
	g.ball = Vector2(w0.x + 0.3, 0.0)
	g.velocity = Vector2(-40.0, 0.0)
	g.step(1.0 / 60.0)
	check.call(g.ball.x >= w0.x + w0.hx + TabletopGame.TABLE_RADIUS - 1e-3, "maze: a fast ball can't pass through a wall")
	st.retry()
	st.xr_press(_hand("right"), "grip")
	var mroute: Array = g.definition().route.slice(1)
	won = _drive(st, mroute, 90.0, wins)
	check.call(won and wins[0].mode == "maze" and wins[0].stars == 3, "maze: following the route collects the stars and reaches the goal")
	st.free()

	# Ricochet: turn the paddle with the grip, launch with the trigger, bounce into the goal.
	st = TabletopStage.new("ricochet")
	st.place_table(Transform3D.IDENTITY, 0.32)
	sfx = []
	st.sfx = func(n, k, _p): sfx.append([n, k])
	wins = []
	st.tabletop_win = func(r): wins.append(r)
	g = st.game
	_frame(st, [])
	var l: Dictionary = g.definition()
	var m: Dictionary = l.mirrors[0]
	var above: Vector3 = st._board_xf() * Vector3(m.x, 2.0, m.z)
	check.call(not st.xr_press(_hand("right", Quaternion.IDENTITY, st._board_xf() * Vector3(-1.4, 2, 1.0)), "grip"), "ricochet: a grip pointing at no paddle does nothing")
	check.call(st.xr_press(_hand("right", Quaternion.IDENTITY, above), "grip") and st.grips.has("right"), "ricochet: the grip takes the paddle it points at")
	var want: float = l.solution[0] - g.angles[0]
	_frame(st, [_hand("right", Quaternion(Vector3.UP, -want), above)])
	check.call(absf(g.angles[0] - l.solution[0]) < 1e-6 and st.mirrors[0].material_override == st.mats.honey, "ricochet: turning the hand turns the paddle in 5° steps")
	st.xr_release(_hand("right"), false, "grip")
	var s0: Vector2 = l.start
	var aim_at: Vector3 = st._board_xf() * Vector3(s0.x, TabletopGame.TABLE_RADIUS, s0.y - 1.0)
	var eye: Vector3 = st._board_xf() * Vector3(s0.x, 3.0, s0.y + 0.5)
	var hand := _hand("right", Quaternion.IDENTITY, eye, aim_at - eye)
	check.call(st.xr_press(hand, "trigger") and st.trigger == "right", "ricochet: the trigger aims")
	_frame(st, [hand])
	check.call(st.aim.distance_to(Vector2(0, -1)) < 0.01 and st.dots[0].visible, "ricochet: the aim dots point where the hand aims")
	st.xr_release(hand, false, "trigger")
	check.call(g.phase == "playing" and g.attempts == 1 and sfx.any(func(s): return s[0] == "whoosh"), "ricochet: releasing the trigger launches him (whoosh)")
	for i in 72 * 3:
		_frame(st, [hand])
		if not wins.is_empty():
			break
	check.call(not wins.is_empty() and wins[0].mode == "ricochet" and g.bounces.has(0) and g.score == 3, "ricochet: off the paddle and into the goal")
	if not wins.is_empty():
		best = {}
		progress = []
		TabletopProgress.record_win(best, func(id, v): progress.append([id, v]), wins[0])
		check.call(progress.has(["ricochet1", 1]) and progress.has(["ricochetAce", 1]), "progress: first-throw ricochet is an Ace")
	# A wrong angle misses and comes back for another go.
	g.reset(0)
	g.launch(Vector2(0, -1))
	for i in 72 * 10:
		g.step(DT)
		if g.phase == "ready":
			break
	check.call(g.phase == "ready" and g.failures == 1 and g.ball == l.start, "ricochet: a miss falls and he returns to the start")
	st.free()
