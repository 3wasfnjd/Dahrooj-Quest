extends RefCounted
## RoomSpots (mixed reality, out in the room): spots on the walls at a reachable height,
## the open floor (not under the table or the couch) and furniture tops, inside the room. A
## pick is always in FRONT of the player: within RoomSpots.ARC (70°) either side of the play
## direction and at least RoomSpots.MIN_DIST (2 m) away, never behind; spread across the arc;
## the play direction is `forward` (not where the head looks); a virtual arc ahead without a
## scan or in a room too small to have spots out there; room-relative as the player walks.

const U := 8.0  # game units per metre (the room scale)
const DT := 1.0 / 72.0


static func _m(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z) * U


static func _pl(pos: Vector3, n: Vector3, ax: Vector3, ay: Vector3, half: Vector2, label: String) -> Dictionary:
	return {"pos": pos, "normal": n, "ax": ax, "ay": ay, "half": half * U, "label": label}


## A 4 m x 5 m room (x -2..2, z -3..2, 2.5 m high) with a table (top 0.75 m, near the north
## wall) and a couch (west side, as a volume and its top), in game units.
static func room() -> Array:
	var planes: Array = [
		_pl(_m(0, 0, -0.5), Vector3.UP, Vector3.RIGHT, Vector3.BACK, Vector2(2.0, 2.5), "floor"),
		_pl(_m(0, 2.5, -0.5), Vector3.DOWN, Vector3.RIGHT, Vector3.BACK, Vector2(2.0, 2.5), "ceiling"),
		_pl(_m(0, 1.25, -3.0), Vector3.BACK, Vector3.RIGHT, Vector3.UP, Vector2(2.0, 1.25), "wall"),
		_pl(_m(0, 1.25, 2.0), Vector3.FORWARD, Vector3.RIGHT, Vector3.UP, Vector2(2.0, 1.25), "wall"),
		_pl(_m(-2.0, 1.25, -0.5), Vector3.RIGHT, Vector3.BACK, Vector3.UP, Vector2(2.5, 1.25), "wall"),
		_pl(_m(2.0, 1.25, -0.5), Vector3.LEFT, Vector3.BACK, Vector3.UP, Vector2(2.5, 1.25), "wall"),
		_pl(_m(1.2, 0.75, -2.0), Vector3.UP, Vector3.RIGHT, Vector3.BACK, Vector2(0.5, 0.4), "table"),
		_pl(_m(-1.5, 0.8, 0.5), Vector3.UP, Vector3.RIGHT, Vector3.BACK, Vector2(0.4, 1.0), "couch"),
	]
	var boxes: Array = [{"pos": _m(-1.5, 0.4, 0.5), "ax": Vector3.RIGHT, "ay": Vector3.UP, "az": Vector3.BACK,
		"half": Vector3(0.4, 0.4, 1.0) * U, "label": "couch"}]
	return [planes, boxes]


static func fresh() -> RoomSpots:
	var rs := RoomSpots.new()
	rs.unit = U
	rs.floor_y = 0.0
	var r := room()
	rs.set_room(r[0], r[1])
	return rs


static func _angle(eye: Vector3, p: Vector3) -> float:
	return atan2(p.x - eye.x, -(p.z - eye.z))


## In front: within the arc either side of fwd and at least MIN_DIST away (checked by hand,
## not with RoomSpots.ahead()).
static func in_front(eye: Vector3, p: Vector3, fwd := Vector3.FORWARD, unit := U) -> bool:
	var d := Vector2(p.x - eye.x, p.z - eye.z)
	var f := Vector2(fwd.x, fwd.z).normalized()
	return d.length() >= RoomSpots.MIN_DIST * unit - 1e-3 and absf(f.angle_to(d)) <= deg_to_rad(70.0) + 1e-3


## Behind: more than 90° off the play direction.
static func behind(eye: Vector3, p: Vector3, fwd := Vector3.FORWARD) -> bool:
	return Vector2(p.x - eye.x, p.z - eye.z).dot(Vector2(fwd.x, fwd.z)) < 0.0


static func run(check: Callable) -> void:
	var rs := fresh()
	var kinds := {}
	for sp: Dictionary in rs.spots:
		kinds[sp.kind] = int(kinds.get(sp.kind, 0)) + 1
	check.call(rs.spots.size() > 60 and kinds.has("wall") and kinds.has("floor") and kinds.has("top") and not kinds.has("air"),
		"room spots: walls, floor and furniture tops from the scan (%s)" % str(kinds))

	# Inside the room, walls at a reachable height, off the surface, nothing in furniture.
	var inside := true
	var wall_h := true
	var lifted := true
	var under := 0
	var tops := {"table": 0, "couch": 0}
	for sp: Dictionary in rs.spots:
		var p: Vector3 = sp.pos
		if p.x < -2.0 * U or p.x > 2.0 * U or p.z < -3.0 * U or p.z > 2.0 * U or p.y < 0.0 or p.y > 2.5 * U:
			inside = false
		match String(sp.kind):
			"wall":
				var hm := p.y / U
				if hm < 0.6 - 1e-3 or hm > 2.0 + 1e-3:
					wall_h = false
				var n: Vector3 = sp.normal
				var on_wall := minf(minf(p.x + 2.0 * U, 2.0 * U - p.x), minf(p.z + 3.0 * U, 2.0 * U - p.z))
				if absf(n.y) > 0.01 or on_wall < 0.01 * U or on_wall > 0.05 * U:
					lifted = false
			"floor":
				if absf(p.y - RoomSpots.LIFT * U) > 1e-3:
					lifted = false
				var in_table := absf(p.x - 1.2 * U) <= 0.5 * U and absf(p.z + 2.0 * U) <= 0.4 * U
				var in_couch := absf(p.x + 1.5 * U) <= 0.4 * U and absf(p.z - 0.5 * U) <= 1.0 * U
				if in_table or in_couch:
					under += 1
			"top":
				tops[sp.label] = int(tops.get(sp.label, 0)) + 1
				if not RoomSpots.in_box(rs.boxes[0], p, 0.0) and p.y < 0.7 * U:
					lifted = false
	check.call(inside, "room spots: all inside the room's bounds")
	check.call(wall_h, "room spots: wall spots between 0.6 and 2.0 m over the floor")
	check.call(lifted, "room spots: a little off their surface along its normal (never in it)")
	check.call(under == 0, "room spots: no floor spot under the table or the couch (%d)" % under)
	check.call(int(tops.table) > 0 and int(tops.couch) > 0, "room spots: on the table top and the couch (%s)" % str(tops))
	check.call(not rs.spots.any(func(s: Dictionary) -> bool: return String(s.kind) != "top" and RoomSpots.in_box(rs.boxes[0], s.pos, 0.05 * U)),
		"room spots: none inside the couch")
	check.call(rs.inside(_m(0, 1, 0)) and not rs.inside(_m(0, 1, -3.5)) and not rs.inside(_m(2.6, 1, 0)), "room spots: the inside test")

	check.call(absf(RoomSpots.ARC - deg_to_rad(70.0)) < 1e-4 and RoomSpots.MIN_DIST == 2.0, "room spots: the forward arc is ±70°, the least distance 2 m")

	# In front only, at least 2 m away, from a player in the middle of the room facing -Z.
	var eye := _m(0, 1.6, 0)
	var secs := {}
	var front_ok := true
	var behind_n := 0
	var room_n := 0
	var far_n := 0
	for i in 240:
		var sp := rs.pick(eye)
		if sp.is_empty():
			front_ok = false
			continue
		var p: Vector3 = sp.pos
		if not in_front(eye, p):
			front_ok = false
		if behind(eye, p):
			behind_n += 1
		if sp.room:
			room_n += 1
		if Vector2(p.x - eye.x, p.z - eye.z).length() > 2.6 * U:
			far_n += 1
		secs[RoomSpots.sector_of(eye, p)] = true
		rs.cool(0.3)
	check.call(front_ok and behind_n == 0, "room spots: every pick within ±70° of the play direction and 2 m away or more (%d behind)" % behind_n)
	check.call(room_n == 240, "room spots: the room's own spots when it has them out there")
	check.call(secs.size() >= 4, "room spots: spread across the forward arc (%d sectors)" % secs.size())
	check.call(far_n > 60, "room spots: mostly from far (%d of 240 over 2.6 m)" % far_n)
	var all_front := true
	for sp: Dictionary in rs._pool(eye, []):
		all_front = all_front and in_front(eye, sp.pos)
	check.call(all_front, "room spots: the whole pool is out in front")

	# The play direction, not the head: turned to +X, the picks follow it; where the head looks
	# plays no part (there is no look() any more).
	var east := fresh()
	east.forward = Vector3.RIGHT
	var east_ok := true
	for i in 120:
		var sp := east.pick(eye)
		east_ok = east_ok and not sp.is_empty() and in_front(eye, sp.pos, Vector3.RIGHT) and not behind(eye, sp.pos, Vector3.RIGHT)
	check.call(east_ok and not east.has_method("look"), "room spots: the arc follows the play direction (+X), never the gaze")
	check.call(RoomSpots.ahead(eye, eye + Vector3(0, 0, -2.5) * U, 2.0 * U) and not RoomSpots.ahead(eye, eye + Vector3(0, 0, 2.5) * U, 2.0 * U)
		and not RoomSpots.ahead(eye, eye + Vector3(0, 0, -1.5) * U, 2.0 * U) and not RoomSpots.ahead(eye, eye + Vector3(3.0, 0, -0.5) * U, 2.0 * U)
		and RoomSpots.ahead(eye, eye + Vector3(2.0, 0, -1.0) * U, 2.0 * U), "room spots: ahead() is the arc and the distance")
	var moved := RoomSpots.into_arc(eye, eye + Vector3(0.5, 0.3, 1.0) * U, 2.0 * U)
	check.call(in_front(eye, moved) and absf(moved.y - (eye.y + 0.3 * U)) < 1e-4, "room spots: into_arc() brings a point behind into the arc, far enough")
	var used0 := fresh()
	used0.used[0] = 3.0
	used0.cool(RoomSpots.USED_DECAY)
	check.call(absf(used0.used[0] - 3.0 * exp(-1.0)) < 1e-3 and used0.want(1) == 1.0 and used0.want(0) < 1.0, "room spots: a sector just given counts against it a while")

	# A small room: nothing of it 2 m out in front (the north wall 0.6 m ahead): the virtual arc.
	var cramped := _m(0, 1.6, -2.4)
	var small_ok := true
	for i in 60:
		var sp := rs.pick(cramped)
		small_ok = small_ok and not sp.is_empty() and not sp.room and in_front(cramped, sp.pos)
	check.call(small_ok, "room spots: a small room, then a virtual spot ahead (never a near one)")

	# Kinds.
	var all_kind := func(list: Array, k: String) -> bool:
		return not list.is_empty() and list.all(func(s: Dictionary) -> bool: return String(s.kind) == k)
	check.call(all_kind.call(rs.pick_many(eye, 4, ["top"]), "top") and all_kind.call(rs.pick_many(eye, 4, ["wall"]), "wall") and all_kind.call(rs.pick_many(eye, 4, ["floor"]), "floor"),
		"room spots: walls, floor or tops on request")
	var many := rs.pick_many(eye, 3)
	check.call(many.size() == 3 and (many[0].pos as Vector3).distance_to(many[1].pos) >= 0.5 * U - 1e-3 and (many[1].pos as Vector3).distance_to(many[2].pos) >= 0.5 * U - 1e-3,
		"room spots: a few at once, apart")
	var pw := RoomSpots.plane_of(rs.pick(eye, ["wall"]), room()[0], 0.3 * U)
	check.call(not pw.is_empty() and String(pw.label) == "wall", "room spots: a spot finds its plane")

	# The player walks: the spots stay where they are in the room, picks stay in front.
	var walked := _m(1.3, 1.6, -1.6)
	var stays := true
	for i in 60:
		var sp := rs.pick(walked)
		var p: Vector3 = sp.pos
		if not in_front(walked, p) or not rs.spots.any(func(s: Dictionary) -> bool: return (s.pos as Vector3).is_equal_approx(p)):
			stays = false
	check.call(stays, "room spots: room-relative as the player walks (and still in front, 2 m away)")

	# No scan: a virtual arc ahead of the player, 2.2 - 3.5 m out, on the floor and in the air.
	var none := RoomSpots.new()
	none.unit = U
	none.set_room([], [])
	var ring_ok := true
	var ring_secs := {}
	var air := 0
	var flo := 0
	var ring_behind := 0
	for i in 120:
		var sp := none.pick(eye)
		var p: Vector3 = sp.pos
		var d := Vector2(p.x - eye.x, p.z - eye.z).length() / U
		if sp.room or d < RoomSpots.RING.x - 1e-3 or d > RoomSpots.RING.y + 1e-3 or not in_front(eye, p):
			ring_ok = false
		if behind(eye, p):
			ring_behind += 1
		if String(sp.kind) == "air":
			air += 1
			var hm := p.y / U
			var n: Vector3 = sp.normal
			if hm < 0.6 - 1e-3 or hm > 1.8 + 1e-3 or n.dot((eye - p).normalized()) < 0.3:
				ring_ok = false
		elif String(sp.kind) == "floor":
			flo += 1
		ring_secs[RoomSpots.sector_of(eye, p)] = true
		none.cool(0.3)
	check.call(not none.has_room() and ring_ok and air > 20 and flo > 20 and ring_behind == 0, "room spots: no scan, an arc ahead of the player 2.2-3.5 m out (%d air, %d floor)" % [air, flo])
	check.call(ring_secs.size() >= 4, "room spots: the arc spreads across the front (%d sectors)" % ring_secs.size())
	var ring_wall := none.pick(eye, ["wall"])
	check.call(not ring_wall.is_empty() and not ring_wall.room and in_front(eye, ring_wall.pos), "room spots: a kind the arc lacks still gets a spot ahead")

	# Sizes for the room and the providers.
	check.call(absf(RoomSpots.size_for(0.1, 0.34, 8.0) * 0.34 / 8.0 - 0.1) < 1e-5 and absf(RoomSpots.size_for(0.1, 0.34, 16.0) - 2.0 * RoomSpots.size_for(0.1, 0.34, 8.0)) < 1e-5,
		"room spots: size_for keeps the target's real size at any court scale")
	var seen_kinds: Array = []
	var p1 := func(k: Array) -> Array:
		seen_kinds.append(k)
		return [{"pos": Vector3.ONE}]
	var p0 := func() -> Array: return [{"pos": Vector3.ZERO}]
	check.call(RoomSpots.ask(p1, ["wall"]).size() == 1 and seen_kinds[0] == ["wall"] and RoomSpots.ask(p0, ["wall"]).size() == 1 and RoomSpots.ask(Callable()).is_empty(),
		"room spots: ask() takes providers with or without the kinds")


