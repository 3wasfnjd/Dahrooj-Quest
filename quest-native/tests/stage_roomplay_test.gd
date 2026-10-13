extends RefCounted
## Room play (mixed reality, all around the room): every converted mode takes its spawns from
## RoomSpots (walls, open floor, furniture tops; a ring without a scan) on every side of the
## player, and keeps its old layout in VR (the provider gives nothing there).

const DT := 1.0 / 72.0
const RS := preload("res://tests/stage_roomspots_test.gd")
const U := RS.U


static func _ctx(b: Ball) -> GameCtx:
	var ctx := GameCtx.new()
	ctx.ball = b
	ctx.counts = {}
	return ctx


## main's provider: n picks of the kinds asked, from the eye.
static func _provider(rs: RoomSpots, eye: Vector3, n: int) -> Callable:
	return func(kinds: Array) -> Array: return rs.pick_many(eye, n, kinds)


static func _vr() -> Callable:
	return func(_kinds: Array) -> Array: return []


static func _on_spot(rs: RoomSpots, p: Vector3, tol: float) -> bool:
	for sp: Dictionary in rs.spots:
		if (sp.pos as Vector3).distance_to(p) <= tol:
			return true
	return false


static func run(check: Callable) -> void:
	var eye := Vector3(0, 1.6, 0) * U
	_mole(check, eye)
	_invasion(check, eye)
	_meteor(check, eye)
	_frenzy(check, eye)
	_giant(check, eye)
	_gallery(check, eye)
	_slime(check, eye)


static func _mole(check: Callable, eye: Vector3) -> void:
	var rs := RS.fresh()
	var st := MoleStage.new()
	var b := Ball.new()
	st.ctx = _ctx(b)
	st.auto_spawn = false
	st.viewer = eye
	st.sink = false
	st.size = RoomSpots.size_for(0.1, MoleStage.R, U)
	st.spots_provider = _provider(rs, eye, 2)
	var secs := {}
	var all_room := true
	for k in 36:
		var i := st.spawn("plain")
		if i < 0:
			continue
		var p: Vector3 = st.moles[i].spot
		all_room = all_room and _on_spot(rs, p, 1e-3)
		secs[RoomSpots.sector_of(eye, p)] = true
		st.moles[i].on = false
	check.call(all_room and secs.size() >= 9, "room play: moles pop out of the room all around the player (%d sectors)" % secs.size())
	check.call(absf(MoleStage.R * st.size / U - 0.1) < 1e-4, "room play: a mole is 20 cm across in the room")
	st.spots_provider = _vr()
	st.sink = true
	st.size = 1.0
	var g := st.spawn("plain")
	check.call(g >= 0 and st.moles[g].n == Vector3.UP and st.moles[g].sink and (st.moles[g].spot as Vector3).z < -4.5, "room play: VR moles keep the field ahead")
	st.free()


static func _invasion(check: Callable, eye: Vector3) -> void:
	var rs := RS.fresh()
	var st := InvasionStage.new()
	var b := Ball.new()
	st.ctx = _ctx(b)
	b.set_stage(st, "invasion")
	st.auto_spawn = false
	st.viewer = eye
	st.size = RoomSpots.size_for(0.11, 0.45, U)
	st.spots_provider = _provider(rs, eye, 1)
	var secs := {}
	var all_room := true
	for k in 30:
		var i := st.spawn("plain")
		if i < 0:
			continue
		var m: Dictionary = st.invaders[i]
		all_room = all_room and m.phase == "emerge" and _on_spot(rs, m.p, 1e-3)
		secs[RoomSpots.sector_of(eye, m.p)] = true
		m.on = false
	check.call(all_room and secs.size() >= 9, "room play: invaders burst out of the room on every side (%d sectors)" % secs.size())
	var bi := st.spawn("boss")
	check.call(bi >= 0 and st.invaders[bi].phase == "drop" and Vector2(st.invaders[bi].p.x - eye.x, st.invaders[bi].p.z - eye.z).length() >= RoomSpots.MIN_DIST * U - 1e-3,
		"room play: the boss drops in at a spot of the room")
	st.invaders[bi].on = false
	var none := RoomSpots.new()
	none.unit = U
	st.spots_provider = _provider(none, eye, 1)
	var ai := -1
	for k in 12:
		ai = st.spawn("plain")
		if st.invaders[ai].phase == "drop":
			break
		st.invaders[ai].on = false
	check.call(ai >= 0 and st.invaders[ai].phase == "drop", "room play: no scan, they drop in around the player from the ring in the air")
	st.deactivate()
	st.spots_provider = _vr()
	st.size = 1.0
	var v := st.spawn("plain")
	check.call(v >= 0 and st.invaders[v].phase == "drop" and absf(st.invaders[v].p.z - InvasionStage.SPAWN_Z) <= 1.6, "room play: VR invaders still come from the far end")
	b.set_stage(null, "")
	st.free()


static func _meteor(check: Callable, eye: Vector3) -> void:
	var rs := RS.fresh()
	var st := MeteorStage.new()
	var b := Ball.new()
	st.ctx = _ctx(b)
	b.set_stage(st, "meteor")
	st.auto_spawn = false
	st.viewer = eye
	st.size = RoomSpots.size_for(0.15, 0.85, U)
	var planes: Array = RS.room()[0]
	st.planes_provider = func() -> Array: return planes
	st.spots_provider = _provider(rs, eye, 1)
	st._room_t = 0.0
	st.start()
	st.update(b, DT)
	var secs := {}
	var ok := true
	var why := ""
	for k in 30:
		var i := st.spawn("mid", false, {"ceiling": true})
		var m: Dictionary = st.meteors[i]
		var land: Vector3 = m.land
		var on_floor := rs.spots.any(func(s: Dictionary) -> bool: return String(s.kind) == "floor" and Vector2((s.pos as Vector3).x - land.x, (s.pos as Vector3).z - land.z).length() < 1e-3)
		var c: Vector3 = m.c
		var this_ok: bool = m.phase == "crack" and on_floor and absf(c.y - 2.5 * U) < 0.5 * U and Vector2(c.x - land.x, c.z - land.z).length() <= 1.5 * st.size * 1.5
		if not this_ok and why == "":
			why = "%s %s %s %s" % [m.phase, on_floor, c, land]
		ok = ok and this_ok
		secs[RoomSpots.sector_of(eye, land)] = true
		m.on = false
		m.phase = ""
	check.call(ok and secs.size() >= 8, "room play: meteors crack the ceiling right above open floor all around the player (%d sectors) %s" % [secs.size(), why])
	# No scan: they land on the ring around the player, coming in from beyond it.
	var none := RoomSpots.new()
	none.unit = U
	st.planes_provider = func() -> Array: return []
	st.spots_provider = _provider(none, eye, 1)
	st._room_t = 0.0
	st.update(b, DT)
	var ring_ok := true
	var rsecs := {}
	for k in 30:
		var i := st.spawn("small")
		var m: Dictionary = st.meteors[i]
		var land: Vector3 = m.land
		var d := Vector2(land.x - eye.x, land.z - eye.z).length() / U
		var out := Vector2((m.c as Vector3).x - land.x, (m.c as Vector3).z - land.z)
		ring_ok = ring_ok and not st.room() and d > 1.0 and d < 3.5 and out.dot(Vector2(land.x - eye.x, land.z - eye.z)) > 0.0
		rsecs[RoomSpots.sector_of(eye, land)] = true
		m.on = false
		m.phase = ""
	check.call(ring_ok and rsecs.size() >= 8, "room play: no scan, meteors land around the player from every side (%d sectors)" % rsecs.size())
	# VR: the sky ahead.
	st.spots_provider = _vr()
	st.size = 1.0
	st.viewer = Vector3(0, 3.2, 1.0)
	var vr_ok := true
	for k in 20:
		var i := st.spawn("small")
		var land: Vector3 = st.meteors[i].land
		var g: Vector3 = st.goal()
		vr_ok = vr_ok and absf(atan2(land.x - g.x, -(land.z - g.z))) <= 1.71 and (st.meteors[i].c as Vector3).y > 15.0
		st.meteors[i].on = false
		st.meteors[i].phase = ""
	check.call(vr_ok, "room play: VR meteors still come from the sky ahead")
	b.set_stage(null, "")
	st.free()


static func _frenzy(check: Callable, eye: Vector3) -> void:
	var rs := RS.fresh()
	var st := FrenzyStage.new()
	var b := Ball.new()
	st.ctx = _ctx(b)
	st.auto_spawn = false
	st.viewer = eye
	st.size = U / 2.0
	st.around = true
	st.spots_provider = _provider(rs, eye, 1)
	var secs := {}
	var from_room := 0
	for k in 60:
		var i := st.spawn("bubble")
		if i < 0:
			continue
		var p: Vector3 = st.items[i].p
		if (st.items[i].v as Vector3).length() > 0.5:
			from_room += 1
		secs[RoomSpots.sector_of(eye, p)] = true
		st.items[i].on = false
	check.call(from_room > 15 and secs.size() >= 9, "room play: bubbles come out of the room on every side (%d of 60, %d sectors)" % [from_room, secs.size()])
	st._follow = Vector3(eye.x, 0, eye.z)
	var f := st.field()
	var mid: Vector3 = ((f.lo as Vector3) + (f.hi as Vector3)) * 0.5
	check.call(absf(mid.z - eye.z) < 0.01 and absf(mid.x - eye.x) < 0.01, "room play: no scan, the air around the player on every side")
	st.around = false
	st.spots_provider = _vr()
	st.size = 1.0
	var f2 := st.field()
	var mid2: Vector3 = ((f2.lo as Vector3) + (f2.hi as Vector3)) * 0.5
	check.call(mid2.z < eye.z - 1.0, "room play: VR bubbles keep the field mostly ahead")
	st.free()


static func _giant(check: Callable, eye: Vector3) -> void:
	var st := GiantStage.new()
	var b := Ball.new()
	st.ctx = _ctx(b)
	st.size = RoomSpots.size_for(0.105, GiantStage.MIN_R, U)
	st.viewer = eye
	var planes: Array = RS.room()[0]
	st.planes_provider = func() -> Array: return planes
	st._layout()
	var facing: Vector3 = (st.room.wall as Dictionary).get("normal", Vector3.ZERO)
	# Behind the player: the south wall's spot.
	var behind := {"pos": Vector3(0.3 * U, 1.2 * U, 2.0 * U - 0.16), "normal": Vector3.FORWARD, "kind": "wall"}
	st.spots_provider = func(_kinds: Array) -> Array: return [behind]
	st._layout()
	var w: Dictionary = st.room.wall
	check.call(facing == Vector3.BACK and not w.is_empty() and (w.normal as Vector3) == Vector3.FORWARD and (st.breach.p as Vector3).z > 1.9 * U,
		"room play: the giant breaks in through the wall behind the player, not just the one ahead")
	# No scan: he comes on the side of the spot.
	st.planes_provider = func() -> Array: return []
	var side := {"pos": Vector3(2.0 * U, 1.0 * U, 0.0), "normal": Vector3.LEFT, "kind": "air"}
	st.spots_provider = func(_kinds: Array) -> Array: return [side]
	st._layout()
	var home: Vector3 = st.room.home
	check.call(st.room.wall.is_empty() and home.x > eye.x + 5.0 and absf(home.z - eye.z) < 1.0, "room play: no scan, the giant comes down on the spot's side (%s)" % home)
	st.spots_provider = _vr()
	st._layout()
	check.call((st.room.home as Vector3).is_equal_approx(Vector3(0, 0, GiantStage.HOME_Z)), "room play: VR giant on the court")
	st.free()


static func _gallery(check: Callable, eye: Vector3) -> void:
	var rs := RS.fresh()
	var st := GalleryStage.new()
	var b := Ball.new()
	st.ctx = _ctx(b)
	b.set_stage(st, "gallery")
	st.auto_spawn = false
	st.viewer = eye
	st.size = RoomSpots.size_for(0.15, GalleryStage.R, U)
	var planes: Array = RS.room()[0]
	st.planes_provider = func() -> Array: return planes
	st.spots_provider = _provider(rs, eye, 2)
	st._room_t = 0.0
	st.update(b, DT)
	var secs := {}
	var all_room := true
	for k in 30:
		var i := st.spawn("card", "plain")
		if i < 0:
			continue
		var p: Vector3 = st.targets[i].base
		all_room = all_room and _on_spot(rs, p, 0.12 * st.size + 1e-3)
		secs[RoomSpots.sector_of(eye, p)] = true
		st._off(st.targets[i])
	check.call(st.room() and all_room and secs.size() >= 8, "room play: cardboard targets flip up all around the room (%d sectors)" % secs.size())
	var peeks := 0
	for k in 10:
		var i := st.spawn("peek", "plain")
		if i >= 0:
			peeks += 1
			st._off(st.targets[i])
	check.call(peeks >= 5, "room play: peekers from the room's furniture and walls (%d)" % peeks)
	# No scan: cards on the ring floor around the player, the booth for the rest.
	var none := RoomSpots.new()
	none.unit = U
	st.planes_provider = func() -> Array: return []
	st.spots_provider = _provider(none, eye, 2)
	st._room_t = 0.0
	st.update(b, DT)
	var ring := 0
	for k in 20:
		var i := st.spawn("card", "plain")
		if i >= 0:
			var p: Vector3 = st.targets[i].base
			if Vector2(p.x - eye.x, p.z - eye.z).length() >= 1.5 * U - 1e-3:
				ring += 1
			st._off(st.targets[i])
	check.call(not st.room() and st.booth.visible and ring >= 8, "room play: no scan, cards flip up on the floor around the player (%d of 20)" % ring)
	st.spots_provider = _vr()
	st.size = 1.0
	st.viewer = GalleryStage.VIEW_VR
	var vr_ok := true
	for k in 10:
		var i := st.spawn("card", "plain")
		if i >= 0:
			var p: Vector3 = st.targets[i].base
			vr_ok = vr_ok and GalleryStage.CARD_SPOTS_VR.any(func(q: Vector3) -> bool: return Vector2(q.x - p.x, q.z - p.z).length() < 0.6)
			st._off(st.targets[i])
	check.call(vr_ok, "room play: VR cards stay in the booth")
	b.set_stage(null, "")
	st.free()


static func _slime(check: Callable, eye: Vector3) -> void:
	var rs := RS.fresh()
	var st := SlimeStage.new()
	var b := Ball.new()
	st.ctx = _ctx(b)
	b.set_stage(st, "slime")
	st.viewer = eye
	var planes: Array = RS.room()[0]
	st.planes_provider = func() -> Array: return planes
	st.spots_provider = _provider(rs, eye, 2)
	st._planes_t = 0.0
	st.update(b, DT)
	var p0: Vector3 = st.target.pos
	var n0: Vector3 = st.target.normal
	check.call(bool(st.target.on) and st.room_target.visible and absf(n0.y) < 0.01 and not st.target_lock.is_empty(), "room play: the slime target goes on a wall of the room")
	st.viewer = eye + Vector3(1.0, 0, -1.0) * U
	for k in 72 * 2:
		st.update(b, DT)
	check.call((st.target.pos as Vector3).is_equal_approx(p0), "room play: and stays there while the player walks")
	var moved := 0
	var normals := {}
	normals[n0] = true
	for k in 6:
		var before: Vector3 = st.target.pos
		st._score({"parent": 0, "anchor": before, "level": 1, "ring": -1, "pts": 0})
		for j in 72:
			st.update(b, DT)
		if (st.target.pos as Vector3).distance_to(before) > 0.5 * U:
			moved += 1
		normals[st.target.normal] = true
	check.call(st.hops == 6 and moved >= 5 and normals.size() >= 2, "room play: a hit sends the target to another wall (%d moves, %d walls)" % [moved, normals.size()])
	st.spots_provider = _vr()
	st.planes_provider = func() -> Array: return []
	st._planes_t = 0.0
	st.update(b, DT)
	check.call(st.board.visible and (st.target.pos as Vector3).z == SlimeStage.WALL_Z, "room play: VR keeps the goo wall")
	b.set_stage(null, "")
	st.free()
