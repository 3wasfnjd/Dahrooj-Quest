extends RefCounted
## What gets through costs points, in every mode with something attacking (GameRuntime.penalty
## and its light twin GameRuntime.nibble, wired into a real runtime here):
## - meteor: every meteor that reaches the ground (GROUND_PENALTY by size; at your feet
##   LAND_PENALTY more, the full hit);
## - invasion: the boss's slam (SLAM_PENALTY), besides one reaching the line;
## - giant: his stomp (STOMP_PENALTY; not a small hop), a little one left unpopped
##   (ESCAPE_PENALTY), besides one bouncing off you;
## - castle: a flag planted on the fort (FLAG_PENALTY), the siege tower docking (SIEGE_PENALTY);
## - mole: one that ducks back unwhacked (ESCAPE: 1, golden 2; a sleepy one or a whacked one
##   nothing);
## - gallery: a card / peeker / swinger gone unhit (AWAY_PENALTY), a friendly one hit
##   (FRIEND_PENALTY); the carousel rows and a friendly one let go cost nothing.
## Each: the score drops by that much with its feedback, never below 0; the record, the
## lifetime total and the challenges keep what they had.

const DT := 1.0 / 72.0


static func run(check: Callable) -> void:
	var path: String = Save.PATH
	var had := FileAccess.file_exists(path)
	var before := FileAccess.get_file_as_string(path) if had else ""
	var keep: Dictionary = Save.challenges.duplicate(true)
	var keep_rec: Dictionary = Save.records.duplicate(true)
	var keep_total: int = Save.total_score
	_meteor(check)
	_invasion(check)
	_giant(check)
	_castle(check)
	_mole(check)
	_gallery(check)
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


## A real runtime for mode m with 1,000 points banked (record, total and score1k set); fb
## collects [kind ("hit" | "nibble"), mode, taken, asked].
static func _runtime(m: String, fb: Array) -> Array:
	Save.records = {}
	Save.challenges.clear()
	Save.total_score = 0
	var b := Ball.new()
	var parent := Node3D.new()
	var rt := GameRuntime.new(b, parent)
	rt.on_penalty = func(md: String, taken: int, asked: int, _at: Vector3) -> void: fb.append(["hit", md, taken, asked])
	rt.on_nibble = func(md: String, taken: int, asked: int, _at: Vector3) -> void: fb.append(["nibble", md, taken, asked])
	rt.counts[m] = 1000
	rt.track_scores()
	return [rt, b, parent]


## After the events: the record, the lifetime total and score1k are what they were.
static func _kept(check: Callable, rt: GameRuntime, m: String) -> void:
	rt.track_scores()
	check.call(Save.record(m) == 1000 and Save.total_score == 1000 and int(Save.challenges.get("score1k", 0)) == 1000,
		"%s penalty: the record, the lifetime total and score1k stay (%d, %d)" % [m, Save.record(m), Save.total_score])


## The same event again with only a few points left: the score stops at 0.
static func _floor(check: Callable, rt: GameRuntime, m: String, fb: Array, event: Callable) -> void:
	rt.counts[m] = 3
	var n := fb.size()
	event.call()
	check.call(int(rt.counts[m]) == 0 and fb.size() > n and int(fb[n][2]) <= 3, "%s penalty: never below 0 (%s)" % [m, fb.slice(n)])


static func _until(st: Node, b: Ball, cond: Callable, limit: float) -> bool:
	var t := 0.0
	while t < limit:
		if cond.call():
			return true
		st.call("update", b, DT)
		t += DT
	return cond.call()


static func _meteor(check: Callable) -> void:
	var fb: Array = []
	var made := _runtime("meteor", fb)
	var rt: GameRuntime = made[0]
	var b: Ball = made[1]
	var st := MeteorStage.new()
	st.ctx = rt.ctx
	b.set_stage(st, "meteor")
	st.deactivate()
	st.auto_spawn = false
	st.start()
	st.F.banner_t = 0.0
	st.update(b, DT)
	var land := func(kind: String, at: Vector3) -> void:
		var i := st.spawn(kind, false, {"start": at + Vector3(1, 18, -6), "land": at, "T": 1.5})
		var m: Dictionary = st.meteors[i]
		_until(st, b, func(): return m.phase == "land", 3.0)
	land.call("big", Vector3(1, 0, -9))
	check.call(int(rt.counts.meteor) == 980 and fb == [["nibble", "meteor", 20, 20]], "meteor penalty: a big one on the ground takes 20, lightly (%s)" % [fb])
	land.call("mid", Vector3(-3, 0, -12))
	check.call(int(rt.counts.meteor) == 965 and fb[1] == ["nibble", "meteor", 15, 15], "meteor penalty: a middle one 15 (%d)" % int(rt.counts.meteor))
	var vf := Vector3(st.viewer.x, 0, st.viewer.z - st.near_d() * 1.05)
	land.call("small", vf)
	check.call(int(rt.counts.meteor) == 930 and fb.size() == 4 and fb[2] == ["nibble", "meteor", 10, 10] and fb[3] == ["hit", "meteor", 25, 25],
		"meteor penalty: a small one at your feet: 10 for the ground and the full 25 hit (%s)" % [fb.slice(2)])
	_kept(check, rt, "meteor")
	_floor(check, rt, "meteor", fb, func() -> void: land.call("big", Vector3(2, 0, -10)))
	st.free()
	made[2].free()


static func _invasion(check: Callable) -> void:
	var fb: Array = []
	var made := _runtime("invasion", fb)
	var rt: GameRuntime = made[0]
	var b: Ball = made[1]
	var st := InvasionStage.new()
	st.ctx = rt.ctx
	b.set_stage(st, "invasion")
	var i := st.spawn("boss", {"pos": Vector3(0, 0, -18), "normal": Vector3.UP})
	var m: Dictionary = st.invaders[i]
	st._slam(m)
	check.call(int(rt.counts.invasion) == 985 and fb == [["nibble", "invasion", 15, 15]], "invasion penalty: the boss's slam takes 15, lightly (%s)" % [fb])
	_kept(check, rt, "invasion")
	_floor(check, rt, "invasion", fb, func() -> void: st._slam(m))
	st.free()
	made[2].free()


static func _giant(check: Callable) -> void:
	var fb: Array = []
	var made := _runtime("giant", fb)
	var rt: GameRuntime = made[0]
	var b: Ball = made[1]
	var st := GiantStage.new()
	st.ctx = rt.ctx
	b.set_stage(st, "giant")
	var ready := func() -> bool: return st.F.state == "fight" and not st.giant.air and st.giant.act == ""
	check.call(_until(st, b, ready, 10.0), "giant penalty: he is in and fighting")
	check.call(fb.is_empty() and int(rt.counts.giant) == 1000, "giant penalty: his entrance costs nothing (%s)" % [fb])
	st.auto_play = false
	st._start_hop(st.giant, false)
	_until(st, b, func(): return st.giant.air, 2.0)
	_until(st, b, ready, 4.0)
	check.call(fb.is_empty(), "giant penalty: a small hop costs nothing (%s)" % [fb])
	var stomp := func() -> void:
		st._start_hop(st.giant, true)
		_until(st, b, func(): return st.giant.air, 2.0)
		_until(st, b, ready, 5.0)
	stomp.call()
	check.call(int(rt.counts.giant) == 985 and fb == [["nibble", "giant", 15, 15]], "giant penalty: a stomp's shockwave takes 15, lightly (%s)" % [fb])
	# A little one left hopping about unpopped until it gives up.
	st._start_spit(st.giant)
	check.call(_until(st, b, func(): return st.giant_state().minions >= 1, 3.0), "giant penalty: he spits little ones")
	var mi: Dictionary = {}
	for q in st.minions:
		if q.on:
			mi = q
			break
	fb.clear()
	var c0 := int(rt.counts.giant)
	mi.life = 18.5
	mi.bounces = 0
	st._step_minion(mi, DT)
	check.call(not mi.on and int(rt.counts.giant) == c0 - 5 and fb.size() == 1 and fb[0] == ["nibble", "giant", 5, 5], "giant penalty: one left unpopped takes 5 (%s)" % [fb])
	_kept(check, rt, "giant")
	_floor(check, rt, "giant", fb, stomp)
	st.free()
	made[2].free()


static func _castle(check: Callable) -> void:
	var fb: Array = []
	var made := _runtime("castle", fb)
	var rt: GameRuntime = made[0]
	var b: Ball = made[1]
	var st := CastleStage.new()
	st.auto_spawn = false
	st.ctx = rt.ctx
	b.set_stage(st, "castle")
	st.F.wave = 1
	st.F.state = "wave"
	var climb := func() -> int:
		var j := st.spawn_ladder(0, -1.65)
		var dj: Dictionary = st.dudes[j]
		_until(st, b, func(): return dj.phase == "dance", 30.0)
		return j
	var j0: int = climb.call()
	check.call(st.dudes[j0].phase == "dance" and int(rt.counts.castle) == 990 and fb == [["nibble", "castle", 10, 10]],
		"castle penalty: a flag planted on the fort takes 10, lightly (%s)" % [fb])
	st.knock(j0, Vector3.FORWARD)
	_until(st, b, func(): return st.active() == 0, 8.0)
	fb.clear()
	st.F.wave = 4
	st.spawn_siege()
	var c0 := int(rt.counts.castle)
	check.call(_until(st, b, func(): return st.siege.phase != "enter", 30.0) and st.siege.phase == "dock", "castle penalty: the siege tower reaches the wall")
	check.call(int(rt.counts.castle) == c0 - 25 and fb == [["hit", "castle", 25, 25]], "castle penalty: docking takes 25, the full hit (%s)" % [fb])
	_kept(check, rt, "castle")
	_floor(check, rt, "castle", fb, func() -> void: climb.call())
	st.free()
	made[2].free()


static func _mole(check: Callable) -> void:
	var fb: Array = []
	var made := _runtime("mole", fb)
	var rt: GameRuntime = made[0]
	var b: Ball = made[1]
	var st := MoleStage.new()
	st.auto_spawn = false
	st.ctx = rt.ctx
	b.set_stage(st, "mole")
	var spot := {"pos": Vector3(0, 0, -8), "normal": Vector3.UP}
	var away := func(kind: String) -> void:
		var i := st.spawn(kind, spot)
		var m: Dictionary = st.moles[i]
		_until(st, b, func(): return not m.on, 6.0)
	away.call("plain")
	check.call(int(rt.counts.mole) == 999 and fb == [["nibble", "mole", 1, 1]], "mole penalty: one that ducks back unwhacked takes 1, lightly (%s)" % [fb])
	away.call("gold")
	check.call(int(rt.counts.mole) == 997 and fb.size() == 2 and fb[1] == ["nibble", "mole", 2, 2], "mole penalty: a golden one let go takes 2 (%s)" % [fb])
	away.call("sleepy")
	check.call(int(rt.counts.mole) == 997 and fb.size() == 2, "mole penalty: letting a sleepy one go is right: nothing (%s)" % [fb])
	var i := st.spawn("plain", spot)
	var m: Dictionary = st.moles[i]
	_until(st, b, func(): return MoleStage.hittable(m) and m.phase == "up", 2.0)
	st.whack(m, Vector3.FORWARD)
	_until(st, b, func(): return not m.on, 4.0)
	check.call(int(rt.counts.mole) == 998 and fb.size() == 2, "mole penalty: a whacked one scores and costs nothing as it goes (%d)" % int(rt.counts.mole))
	_kept(check, rt, "mole")
	_floor(check, rt, "mole", fb, func() -> void:
		rt.counts["mole"] = 1
		away.call("gold"))
	st.free()
	made[2].free()


static func _gallery(check: Callable) -> void:
	var fb: Array = []
	var made := _runtime("gallery", fb)
	var rt: GameRuntime = made[0]
	var b: Ball = made[1]
	var st := GalleryStage.new()
	st.auto_spawn = false
	st.ctx = rt.ctx
	b.set_stage(st, "gallery")
	st.update(b, DT)
	st.F.banner_t = 0.0
	st.F.next_rapid = 999.0
	var away := func(mover: String, kind: String, at: Dictionary) -> void:
		var i := st.spawn(mover, kind, at)
		var T: Dictionary = st.targets[i]
		_until(st, b, func(): return not T.on, 40.0)
	away.call("card", "plain", {"pos": Vector3(0, 0, -10)})
	check.call(int(rt.counts.gallery) == 995 and fb == [["nibble", "gallery", 5, 5]], "gallery penalty: a card gone unhit takes 5, lightly (%s)" % [fb])
	away.call("card", "friendly", {"pos": Vector3(2, 0, -10)})
	check.call(int(rt.counts.gallery) == 995 and fb.size() == 1, "gallery penalty: letting a friendly one go costs nothing (%s)" % [fb])
	away.call("rail", "plain", {"row": 0})
	check.call(int(rt.counts.gallery) == 995 and fb.size() == 1, "gallery penalty: a carousel target rolling past costs nothing (%s)" % [fb])
	var shoot_friend := func() -> void:
		var i := st.spawn("card", "friendly", {"pos": Vector3(-2, 0, -10)})
		var T: Dictionary = st.targets[i]
		_until(st, b, func(): return T.phase == "up", 1.0)
		st.shoot(T.proxy, T.c, Vector3.FORWARD)
		_until(st, b, func(): return not T.on, 6.0)
	shoot_friend.call()
	check.call(int(rt.counts.gallery) == 980 and fb.size() == 2 and fb[1] == ["nibble", "gallery", 15, 15], "gallery penalty: hitting a friendly one takes 15 (%s)" % [fb])
	_kept(check, rt, "gallery")
	_floor(check, rt, "gallery", fb, shoot_friend)
	st.free()
	made[2].free()
