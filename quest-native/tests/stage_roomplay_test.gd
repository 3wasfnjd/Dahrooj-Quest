extends RefCounted
## Room play (mixed reality, out in the room): every converted mode takes its spawns from
## RoomSpots (walls, open floor, furniture tops; a virtual arc ahead without a scan) IN FRONT of
## the player: within ±70° of the play direction (game -Z) and 2 m away or more, never
## behind. VR keeps each mode's layout (the provider gives nothing there), and that too only
## spawns in front, as far (4 game units at the VR scale) or more. The giant stands at the
## pinned court (game (0, floor, aim_z)), straight ahead, his near side 2 m away.

const DT := 1.0 / 72.0
const RS := preload("res://tests/stage_roomspots_test.gd")
const U := RS.U
const VR_U := 2.0  # game units per metre in VR


static func _front(eye: Vector3, p: Vector3, unit := U, slack := 0.0) -> bool:
	var d := Vector2(p.x - eye.x, p.z - eye.z)
	return d.length() >= RoomSpots.MIN_DIST * unit - slack - 1e-3 and absf(Vector2(0, -1).angle_to(d)) <= deg_to_rad(70.0) + 1e-3


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
	_castle(check)


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
	var front := true
	for k in 36:
		var i := st.spawn("plain")
		if i < 0:
			continue
		var p: Vector3 = st.moles[i].spot
		all_room = all_room and _on_spot(rs, p, 1e-3)
		front = front and _front(eye, p)
		secs[RoomSpots.sector_of(eye, p)] = true
		st.moles[i].on = false
	check.call(all_room and front and secs.size() >= 3, "room play: moles pop out of the room in front of the player, 2 m away or more (%d sectors)" % secs.size())
	check.call(absf(MoleStage.R * st.size / U - 0.1) < 1e-4, "room play: a mole is 20 cm across in the room")
	st.spots_provider = _vr()
	st.sink = true
	st.size = 1.0
	st.viewer = Vector3(0, 3.2, 11.0)  # main's VR spot for the mole court
	var vr_front := true
	for k in 30:
		var g := st.spawn("plain")
		if g < 0:
			continue
		vr_front = vr_front and st.moles[g].n == Vector3.UP and st.moles[g].sink and _front(st.viewer, st.moles[g].spot, VR_U)
		st.moles[g].on = false
	check.call(vr_front, "room play: VR moles keep the field ahead, far from the player")
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
	var front := true
	for k in 30:
		var i := st.spawn("plain")
		if i < 0:
			continue
		var m: Dictionary = st.invaders[i]
		all_room = all_room and m.phase == "emerge" and _on_spot(rs, m.p, 1e-3)
		front = front and _front(eye, m.p)
		secs[RoomSpots.sector_of(eye, m.p)] = true
		m.on = false
	check.call(all_room and front and secs.size() >= 3, "room play: invaders burst out of the room in front of the player, never behind (%d sectors)" % secs.size())
	var bi := st.spawn("boss")
	check.call(bi >= 0 and st.invaders[bi].phase == "drop" and _front(eye, st.invaders[bi].p),
		"room play: the boss drops in at a spot of the room ahead")
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
	check.call(ai >= 0 and st.invaders[ai].phase == "drop" and _front(eye, st.invaders[ai].p), "room play: no scan, they drop in ahead of the player from the arc in the air")
	st.deactivate()
	st.spots_provider = _vr()
	st.size = 1.0
	st.viewer = Vector3(0, 3.2, 1.0)
	var vr_ok := true
	for k in 20:
		var v := st.spawn("plain")
		if v < 0:
			continue
		vr_ok = vr_ok and st.invaders[v].phase == "drop" and absf(st.invaders[v].p.z - InvasionStage.SPAWN_Z) <= 1.6 and _front(st.viewer, st.invaders[v].p, VR_U)
		st.invaders[v].on = false
	check.call(vr_ok, "room play: VR invaders still come from the far end")
	b.set_stage(null, "")
	st.free()


static func _meteor(check: Callable, eye: Vector3) -> void:
	var rs := RS.fresh()
	var st := MeteorStage.new()
	st.unit = U
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
		this_ok = this_ok and _front(eye, land)
		if not this_ok and why == "":
			why = "%s %s %s %s" % [m.phase, on_floor, c, land]
		ok = ok and this_ok
		secs[RoomSpots.sector_of(eye, land)] = true
		m.on = false
		m.phase = ""
	check.call(ok and secs.size() >= 3, "room play: meteors crack the ceiling right above open floor in front of the player (%d sectors) %s" % [secs.size(), why])
	# A shower in the room: every streak lands ahead too (it used to come from any side).
	var shower_ok := true
	for k in 6:
		st.start_shower()
		var sd: Vector3 = st.F.shower_dir
		shower_ok = shower_ok and absf(Vector2(0, -1).angle_to(Vector2(sd.x, sd.z))) <= deg_to_rad(70.0)
		for j in 5:
			var i := st.spawn("small", false, {"shower": true})
			if i < 0:
				continue
			shower_ok = shower_ok and _front(eye, st.meteors[i].land)
			st.meteors[i].on = false
			st.meteors[i].phase = ""
	check.call(shower_ok, "room play: meteor showers come from ahead, never behind")
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
		ring_ok = ring_ok and not st.room() and d > 1.0 and d < 3.6 and out.dot(Vector2(land.x - eye.x, land.z - eye.z)) > 0.0 and _front(eye, land)
		rsecs[RoomSpots.sector_of(eye, land)] = true
		m.on = false
		m.phase = ""
	check.call(ring_ok and rsecs.size() >= 3, "room play: no scan, meteors land ahead of the player, coming from beyond (%d sectors)" % rsecs.size())
	# VR: the sky ahead.
	st.spots_provider = _vr()
	st.size = 1.0
	st.unit = VR_U
	st.viewer = Vector3(0, 3.2, 1.0)
	var vr_ok := true
	for k in 20:
		var i := st.spawn("small")
		var land: Vector3 = st.meteors[i].land
		var g: Vector3 = st.goal()
		vr_ok = vr_ok and _front(g, land, VR_U) and (st.meteors[i].c as Vector3).y > 15.0
		st.meteors[i].on = false
		st.meteors[i].phase = ""
	for k in 4:
		st.start_shower()
		for j in 5:
			var i := st.spawn("small", false, {"shower": true})
			if i < 0:
				continue
			vr_ok = vr_ok and _front(st.goal(), st.meteors[i].land, VR_U)
			st.meteors[i].on = false
			st.meteors[i].phase = ""
	check.call(vr_ok, "room play: VR meteors (and showers) still come from the sky ahead, never behind or near")
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
	var front := true
	for k in 60:
		var i := st.spawn("bubble")
		if i < 0:
			continue
		var p: Vector3 = st.items[i].p
		if (st.items[i].v as Vector3).length() > 0.5:
			from_room += 1
		front = front and _front(eye, p)
		secs[RoomSpots.sector_of(eye, p)] = true
		st.items[i].on = false
	check.call(from_room > 15 and front and secs.size() >= 3, "room play: bubbles come out of the room in front of the player, 2 m away or more (%d of 60, %d sectors)" % [from_room, secs.size()])
	st._follow = Vector3(eye.x, 0, eye.z)
	var f := st.field()
	var mid: Vector3 = ((f.lo as Vector3) + (f.hi as Vector3)) * 0.5
	check.call(absf(mid.z - eye.z) < 0.01 and absf(mid.x - eye.x) < 0.01, "room play: no scan, the air around the player on every side")
	st.spots_provider = func(_k: Array) -> Array: return []
	var air_front := true
	for k in 60:
		var i := st.spawn("dahrooj")
		if i < 0:
			continue
		air_front = air_front and _front(eye, st.items[i].p)
		st.items[i].on = false
	check.call(air_front, "room play: no scan, new ones still appear only in front of the player")
	st.around = false
	st.spots_provider = _vr()
	st.size = 1.0
	st.viewer = Vector3(0, 3.2, 1.0)
	st._follow = Vector3(0, 0, 1.0)
	var f2 := st.field()
	var mid2: Vector3 = ((f2.lo as Vector3) + (f2.hi as Vector3)) * 0.5
	var vr_front := true
	for k in 60:
		var i := st.spawn("dahrooj")
		if i < 0:
			continue
		vr_front = vr_front and _front(st.viewer, st.items[i].p, VR_U)
		st.items[i].on = false
	check.call(mid2.z < st.viewer.z - 1.0 and vr_front, "room play: VR bubbles and Dahroojs appear ahead, never behind or near")
	st.free()


static func _giant(check: Callable, eye: Vector3) -> void:
	var st := GiantStage.new()
	var b := Ball.new()
	st.ctx = _ctx(b)
	st.size = RoomSpots.size_for(0.105, GiantStage.MIN_R, U)
	st.unit = U
	st.viewer = eye
	var rs := RS.fresh()
	var anchor := Vector3(0, 0, st.aim_z)
	# No scan (room spots only): he drops from the sky straight ahead at the pinned court, his
	# near side 2 m away (whatever spot RoomSpots would give).
	st.spots_provider = _provider(rs, eye, 1)
	st._layout()
	var home: Vector3 = st.room.home
	var r: float = st.room.r
	var hd := Vector2(home.x - eye.x, home.z - eye.z).length()
	check.call(st.room.wall.is_empty() and absf(home.x) < 1e-3 and home.z <= anchor.z + 1e-3 and hd >= RoomSpots.MIN_DIST * U + r - 0.2 * U and hd <= RoomSpots.MIN_DIST * U + r + 0.2 * U and _front(eye, home),
		"room play: the giant stands at the pinned court, straight ahead, his near side 2 m away (%s, r %.1f)" % [home, r])
	# The player stands back: the anchor itself is far enough, he stands right on it.
	st.viewer = Vector3(0, 1.6 * U, 3.0 * U)
	st._layout()
	check.call((st.room.home as Vector3).distance_to(anchor) < 0.2 * U, "room play: far enough back, he is right where the court was pinned (%s)" % st.room.home)
	# A side spot behind (the old way: a wall not looked at) changes nothing: he never comes from behind.
	var behind := {"pos": Vector3(0.3 * U, 1.2 * U, 2.0 * U - 0.16), "normal": Vector3.FORWARD, "kind": "wall"}
	st.viewer = eye
	st.spots_provider = func(_kinds: Array) -> Array: return [behind]
	st._layout()
	check.call((st.room.home as Vector3).is_equal_approx(home), "room play: the giant never breaks in behind the player")
	# With the scan: the north wall is right behind his spot (3 m ahead, a small room): he
	# breaks in through it, sized to keep 2 m.
	var planes: Array = RS.room()[0]
	st.planes_provider = func() -> Array: return planes
	st._layout()
	var w: Dictionary = st.room.wall
	var h2: Vector3 = st.room.home
	check.call(not w.is_empty() and (w.normal as Vector3) == Vector3.BACK and absf(h2.x) < 1e-3 and (st.breach.p as Vector3).z < -2.9 * U
		and Vector2(h2.x - eye.x, h2.z - eye.z).length() >= RoomSpots.MIN_DIST * U + float(st.room.r) - 1e-3 and _front(eye, h2),
		"room play: with a scan he breaks in through the wall right behind the court's spot, ahead (%s r %.1f)" % [h2, st.room.r])
	# Cramped: the wall only 1.8 m ahead. He never stands past it (outside the room): inside it,
	# with clearance, smaller, nearer than 2 m but his near side 1.2 m away at the least.
	var tight := Vector3(0, 1.6, -1.2) * U
	st.viewer = tight
	st._layout()
	var h3: Vector3 = st.room.home
	var r3: float = st.room.r
	check.call(not st.room.wall.is_empty() and h3.z - r3 >= -3.0 * U - 1e-3 and h3.z + r3 * 1.12 >= -3.0 * U - 1e-3 and absf(h3.x) < 1e-3
		and Vector2(h3.x - tight.x, h3.z - tight.z).length() - r3 >= GiantStage.NEAR_MIN * U - 1e-3 and _front(tight, h3, U, RoomSpots.MIN_DIST * U),
		"room play: a small room, the giant stays inside the wall, near side 1.2 m or more (%s r %.2f m)" % [h3, r3 / U])
	st.viewer = eye
	# A new pin: the court's frame moves under him (the room in game units turns and shifts); he
	# goes with the court mid-fight.
	st.planes_provider = func() -> Array: return []
	st.spots_provider = _provider(rs, eye, 1)
	st.start()
	st.F.state = "fight"
	var g0: Vector3 = st.giant.g
	st.viewer = Vector3(1.5 * U, 1.6 * U, 1.0 * U)
	st.on_placed()
	var g1: Vector3 = st.giant.g
	check.call(g1.distance_to(st.room.home) < 1e-3 and not g1.is_equal_approx(g0) and _front(st.viewer, g1), "room play: a new pin moves the giant with the court (%s -> %s)" % [g0, g1])
	# VR: the court.
	st.viewer = Vector3(0, 3.2, 1.0)
	st.unit = VR_U
	st.spots_provider = _vr()
	st._layout()
	check.call((st.room.home as Vector3).is_equal_approx(Vector3(0, 0, GiantStage.HOME_Z)) and _front(st.viewer, st.room.home, VR_U), "room play: VR giant on the court, far ahead")
	st.free()


static func _gallery(check: Callable, eye: Vector3) -> void:
	var rs := RS.fresh()
	var st := GalleryStage.new()
	st.unit = U
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
	var front := true
	var slack := 0.12 * st.size
	for k in 30:
		var i := st.spawn("card", "plain")
		if i < 0:
			continue
		var p: Vector3 = st.targets[i].base
		all_room = all_room and _on_spot(rs, p, 0.12 * st.size + 1e-3)
		front = front and _front(eye, p, U, slack)
		secs[RoomSpots.sector_of(eye, p)] = true
		st._off(st.targets[i])
	check.call(st.room() and all_room and front and secs.size() >= 3, "room play: cardboard targets flip up in the room in front of the player (%d sectors)" % secs.size())
	var rows_front := true
	for row: Dictionary in st.rows:
		rows_front = rows_front and _front(eye, row.a, U, slack) and _front(eye, row.b, U, slack)
	check.call(rows_front, "room play: the gallery's rails only run along the walls out in front (%d rails)" % st.rows.size())
	var peeks := 0
	var peek_front := true
	for k in 10:
		var i := st.spawn("peek", "plain")
		if i >= 0:
			peeks += 1
			peek_front = peek_front and _front(eye, st.targets[i].out_p, U, slack) and _front(eye, st.targets[i].hide, U, slack)
			st._off(st.targets[i])
	check.call(peeks >= 3 and peek_front, "room play: peekers from the room's furniture and walls in front (%d)" % peeks)
	var other_front := true
	for k in 10:
		for mv in ["swing", "toss"]:
			var i := st.spawn(mv, "plain")
			if i >= 0:
				var at: Vector3 = st.targets[i].anchor if mv == "swing" else st.targets[i].p
				other_front = other_front and _front(eye, at, U, slack)
				st._off(st.targets[i])
	check.call(other_front, "room play: swingers and tosses start in front of the player too")
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
			if _front(eye, p):
				ring += 1
			st._off(st.targets[i])
	check.call(not st.room() and st.booth.visible and ring >= 8, "room play: no scan, cards flip up on the floor ahead of the player (%d of 20)" % ring)
	st.spots_provider = _vr()
	st.size = 1.0
	st.unit = VR_U
	st.viewer = GalleryStage.VIEW_VR
	var vr_ok := true
	for k in 10:
		var i := st.spawn("card", "plain")
		if i >= 0:
			var p: Vector3 = st.targets[i].base
			vr_ok = vr_ok and GalleryStage.CARD_SPOTS_VR.any(func(q: Vector3) -> bool: return Vector2(q.x - p.x, q.z - p.z).length() < 0.6)
			vr_ok = vr_ok and _front(st.viewer, p, VR_U)
			st._off(st.targets[i])
	for row: Dictionary in st.rows:
		vr_ok = vr_ok and _front(st.viewer, row.a, VR_U) and _front(st.viewer, row.b, VR_U)
	check.call(vr_ok, "room play: VR cards stay in the booth, ahead of the player")
	b.set_stage(null, "")
	st.free()


static func _slime(check: Callable, eye: Vector3) -> void:
	var rs := RS.fresh()
	var st := SlimeStage.new()
	st.unit = U
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
	check.call(bool(st.target.on) and st.room_target.visible and absf(n0.y) < 0.01 and not st.target_lock.is_empty() and _front(eye, p0, U, 0.3 * U),
		"room play: the slime target goes on a wall of the room in front of the player")
	st.viewer = eye + Vector3(1.0, 0, -1.0) * U
	for k in 72 * 2:
		st.update(b, DT)
	check.call((st.target.pos as Vector3).is_equal_approx(p0), "room play: and stays there while the player walks")
	var moved := 0
	var normals := {}
	var hop_front := true
	normals[n0] = true
	for k in 6:
		var before: Vector3 = st.target.pos
		st._score({"parent": 0, "anchor": before, "level": 1, "ring": -1, "pts": 0})
		for j in 72:
			st.update(b, DT)
		if (st.target.pos as Vector3).distance_to(before) > 0.5 * U:
			moved += 1
		normals[st.target.normal] = true
		hop_front = hop_front and _front(eye, st.target.pos, U, 0.3 * U)
	check.call(st.hops == 6 and moved >= 5 and normals.size() >= 2 and hop_front, "room play: a hit sends the target to another wall, never one behind (%d moves, %d walls)" % [moved, normals.size()])
	st.spots_provider = _vr()
	st.planes_provider = func() -> Array: return []
	st._planes_t = 0.0
	st.update(b, DT)
	check.call(st.board.visible and (st.target.pos as Vector3).z == SlimeStage.WALL_Z, "room play: VR keeps the goo wall")
	b.set_stage(null, "")
	st.free()


## The fort (VR, and mixed reality on the court): walkers, catapults and the siege tower set out
## in front of the player and far, never behind them (they used to come round the sides).
static func _castle(check: Callable) -> void:
	for vr in [true, false]:
		var st := CastleStage.new()
		var b := Ball.new()
		st.ctx = _ctx(b)
		st.auto_spawn = false
		b.set_stage(st, "castle")
		st.F.wave = 1
		st.F.state = "wave"
		st.viewer = Vector3(0, 3.2, 1.0) if vr else Vector3(0, 1.6 * U, -10.0 + 1.6 * U)
		st.unit = VR_U if vr else U
		if not vr:
			st.size = 1.25
			st._sync_root()
		var unit: float = st.unit
		var ok := true
		var why := ""
		for k in 40:
			for f: int in st.faces():
				var p := st.to_game(st._spawn_point(f))
				if not _front(st.viewer, p, unit):
					ok = false
					why = str(p)
		for k in 6:
			var ci := st.spawn_catapult(1)
			if ci >= 0:
				var p := st.to_game(st.cats[ci].from)
				if not _front(st.viewer, p, unit):
					ok = false
					why = "cat %s" % p
				st.cats[ci].on = false
		if st.spawn_siege():
			var p := st.to_game(st.siege.from)
			if not _front(st.viewer, p, unit):
				ok = false
				why = "siege %s" % p
		check.call(ok, "room play: %s castle walkers, catapults and the siege tower set out in front of the player %s" % ["VR" if vr else "MR", why])
		b.set_stage(null, "")
		st.free()
