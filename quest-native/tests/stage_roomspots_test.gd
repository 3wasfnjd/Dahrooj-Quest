extends RefCounted
## RoomSpots (mixed reality, all around the room): spots on the walls at a reachable height,
## the open floor (not under the table or the couch) and furniture tops, inside the room,
## at least 0.8 m from the player, spread over all 360°, the directions the player has not
## looked at preferred; a ring around the player without a scan; room-relative as the player
## walks.

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

	# 360°, at least 0.8 m away, from a player in the middle of the room.
	var eye := _m(0, 1.6, 0)
	var secs := {}
	var near_ok := true
	var behind := 0
	for i in 240:
		var sp := rs.pick(eye)
		if sp.is_empty():
			near_ok = false
			continue
		var p: Vector3 = sp.pos
		if Vector2(p.x - eye.x, p.z - eye.z).length() < RoomSpots.MIN_DIST * U - 1e-3:
			near_ok = false
		secs[RoomSpots.sector_of(eye, p)] = true
		if absf(_angle(eye, p)) > deg_to_rad(120.0):
			behind += 1
		for s in RoomSpots.SECTORS:
			rs.used[s] *= 0.9
	check.call(near_ok, "room spots: never closer than 0.8 m to the player")
	check.call(secs.size() >= 11, "room spots: from every side (%d of 12 sectors)" % secs.size())
	check.call(behind > 25, "room spots: some from behind (%d of 240)" % behind)

	# Turn: the ways the player has looked at lately are given less often.
	var front_share := func(fwd: Vector3) -> float:
		var r2 := fresh()
		for k in 72 * 8:
			r2.look(eye, fwd, DT)
		var front := 0
		for k in 300:
			var sp2 := r2.pick(eye)
			if absf(angle_difference(_angle(eye, sp2.pos), 0.0)) < deg_to_rad(50.0):
				front += 1
			for s in RoomSpots.SECTORS:
				r2.used[s] *= 0.9
		return float(front) / 300.0
	var looked_front: float = front_share.call(Vector3.FORWARD)
	var looked_back: float = front_share.call(Vector3.BACK)
	check.call(looked_front < looked_back * 0.75 and looked_front > 0.03, "room spots: fewer where the player keeps looking (%.2f looking there, %.2f looking away)" % [looked_front, looked_back])
	var hot := RoomSpots.new()
	for k in 72 * 5:
		hot.look(eye, Vector3.FORWARD, DT)
	check.call(hot.want(0) < hot.want(6) and hot.want(0) > 0.3, "room spots: the sector in view keeps some weight (%.2f vs %.2f)" % [hot.want(0), hot.want(6)])

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

	# The player walks: the spots stay where they are in the room, picks keep their distance.
	var walked := _m(1.3, 1.6, -1.6)
	var stays := true
	for i in 60:
		var sp := rs.pick(walked)
		var p: Vector3 = sp.pos
		if Vector2(p.x - walked.x, p.z - walked.z).length() < RoomSpots.MIN_DIST * U - 1e-3 or not rs.spots.any(func(s: Dictionary) -> bool: return (s.pos as Vector3).is_equal_approx(p)):
			stays = false
	check.call(stays, "room spots: room-relative as the player walks (and still 0.8 m away)")

	# No scan: a ring around the player at 1.5 - 3 m, on the floor and in the air.
	var none := RoomSpots.new()
	none.unit = U
	none.set_room([], [])
	var ring_ok := true
	var ring_secs := {}
	var air := 0
	var flo := 0
	for i in 120:
		var sp := none.pick(eye)
		var p: Vector3 = sp.pos
		var d := Vector2(p.x - eye.x, p.z - eye.z).length() / U
		if sp.room or d < RoomSpots.RING.x - 1e-3 or d > RoomSpots.RING.y + 1e-3:
			ring_ok = false
		if String(sp.kind) == "air":
			air += 1
			var hm := p.y / U
			var n: Vector3 = sp.normal
			if hm < 0.6 - 1e-3 or hm > 1.8 + 1e-3 or n.dot((eye - p).normalized()) < 0.3:
				ring_ok = false
		elif String(sp.kind) == "floor":
			flo += 1
		ring_secs[RoomSpots.sector_of(eye, p)] = true
	check.call(not none.has_room() and ring_ok and air > 20 and flo > 20, "room spots: no scan, a ring around the player 1.5-3 m out (%d air, %d floor)" % [air, flo])
	check.call(ring_secs.size() >= 11, "room spots: the ring goes all the way round (%d sectors)" % ring_secs.size())
	var ring_wall := none.pick(eye, ["wall"])
	check.call(not ring_wall.is_empty() and not ring_wall.room, "room spots: a kind the ring lacks still gets a ring spot")

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


