extends RefCounted
## Headless checks of the scanned room (xr-runtime.js updateRoom / roomCollide port):
## stand-in walls, a table top, a couch volume and the floor through SceneSurfaces
## test planes; RoomColliders bounces balls off them; ray_surface finds them.

const R := 0.12
const DT := 1.0 / 72.0
const G := 9.8


## Flies a ball (gravity, world space) for n steps through the room; returns
## {p, v, max_hit, first_hit_step}.
static func _fly(rc: RoomColliders, p: Vector3, v: Vector3, n: int, gravity := true) -> Dictionary:
	var max_hit := 0.0
	var first := -1
	for i in n:
		var prev := p
		if gravity:
			v.y -= G * DT
		p += v * DT
		var res := rc.collide(p, v, R, prev)
		p = res.p
		v = res.v
		if float(res.hit_speed) > 0.0:
			max_hit = maxf(max_hit, res.hit_speed)
			if first < 0:
				first = i
	return {"p": p, "v": v, "max_hit": max_hit, "first": first}


## A plane facing up (Meta: local Z up, local XY horizontal).
static func _up(at: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP), at)


static func run(check: Callable) -> void:
	var s := SceneSurfaces.new()
	var rc := RoomColliders.new(s)
	check.call(not rc.has_any() and s.planes().is_empty(), "room: nothing detected, nothing collides")
	# A wall 2 m ahead (normal +Z, toward the player), a table, the floor, a couch to the right.
	s.add_test_plane(Transform3D(Basis(), Vector3(0, 1.5, -2)), Vector2(4, 3), "wall")
	s.add_test_plane(_up(Vector3(0, 0.75, -0.8)), Vector2(1.0, 0.6), "table")
	s.add_test_plane(_up(Vector3(0, 0, 0)), Vector2(8, 8), "floor")
	s.add_test_box(Transform3D(Basis(), Vector3(2.5, 0.4, 0)), Vector3(0.8, 0.8, 2.0), "couch")
	check.call(s.planes().size() == 3 and s.boxes().size() == 1 and s.status == "ready", "room: test planes and volume are listed")
	var w: Dictionary = s.planes()[0]
	check.call(w.normal.is_equal_approx(Vector3.BACK) and w.size == Vector2(4, 3), "room: a plane's normal is its local +Z")
	check.call(s.has_table() and s.surfaces().size() == 2, "room: legacy surfaces() lists the table and floor (%d)" % s.surfaces().size())

	# Out of sight behind real things: behind the couch, under the table, beyond the wall.
	var eye := Vector3(0, 1.6, 1.0)
	check.call(rc.blocked(eye, Vector3(3.2, 0.1, 0.0), 0.05), "room: a Dahrooj behind the couch is out of sight")
	check.call(rc.blocked(Vector3(0, 1.6, -0.3), Vector3(0, 0.1, -0.9), 0.05), "room: one under the table (standing by it, looking down) is out of sight")
	check.call(rc.blocked(eye, Vector3(0, 1.0, -3.0), 0.05), "room: one beyond the wall is out of sight")
	check.call(not rc.blocked(eye, Vector3(0, 1.2, -0.3), 0.05) and not rc.blocked(eye, Vector3(1.0, 0.1, 0.3), 0.05),
		"room: in the open (or on the floor in front) it stays in sight")
	# Walkers go round the couch (x 2.1..2.9, z -1..1), never through it, and get to the goal
	# on its far side; over a table they pass; the sofa you sit on is not in their way.
	var walk := func(from: Vector3, goal: Vector3, secs: float) -> Dictionary:
		var wk := from
		var mem := {}
		var inside := false
		for i in int(secs * 60.0):
			var to := goal - wk
			to.y = 0.0
			if to.length() < 0.05:
				return {"at": true, "inside": inside, "p": wk}
			wk = rc.push_out(wk + to.normalized() * 0.8 / 60.0, 0.05, wk, goal, mem)
			for bx in s.boxes():
				var l: Vector3 = (bx.xform as Transform3D).affine_inverse() * wk
				inside = inside or (absf(l.x) < bx.size.x * 0.5 and absf(l.z) < bx.size.z * 0.5 and absf(l.y) < bx.size.y * 0.5)
		return {"at": false, "inside": inside, "p": wk}
	var w1: Dictionary = walk.call(Vector3(3.3, 0.05, 0.05), Vector3(1.0, 0.05, -0.1), 12.0)
	check.call(w1.at and not w1.inside, "room: a walker behind the couch goes round it to you (%s)" % [w1])
	var w2: Dictionary = walk.call(Vector3(3.3, 0.05, 0.9), Vector3(1.0, 0.05, 0.9), 12.0)
	check.call(w2.at and not w2.inside, "room: from near its end too (%s)" % [w2])
	var w3: Dictionary = walk.call(Vector3(1.5, 0.05, 0.0), Vector3(2.5, 0.6, 0.0), 6.0)
	check.call(w3.at, "room: a goal on the sofa itself (you sit there) is reached (%s)" % [w3])
	check.call(rc.push_out(Vector3(2.5, 0.85, 0), 0.05, Vector3(2.45, 0.85, 0), Vector3.ZERO, {}) == Vector3(2.5, 0.85, 0), "room: standing on top of it, it is left alone")
	# Meta's volumes may stand on local Z: the same couch, turned so, is gone round the same way.
	var sz := SceneSurfaces.new()
	sz.add_test_box(Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(2.5, 0.4, 0)), Vector3(0.8, 2.0, 0.8), "couch")
	var rz := RoomColliders.new(sz)
	var wz := rz.push_out(Vector3(2.2, 0.05, 0.1), 0.05, Vector3(2.0, 0.05, 0.1), Vector3(3.5, 0.05, 0.1), {})
	check.call(RoomColliders.up_axis(sz.boxes()[0].xform.basis) == 2 and wz.x < 2.06 and absf(wz.y - 0.05) < 1e-4, "room: a Z-up volume is a sofa on the floor too (%s)" % wz)
	rz.free()
	sz.free()
	# What hides it on the headset: a mask of every wall, table and volume but the floor.
	rc.occlude(true)
	check.call(rc.occluder_triangles() == 2 * 2 + 12, "room: the hiding mask covers the wall, the table and the couch (%d)" % rc.occluder_triangles())
	rc.occlude(false)
	check.call(rc.occluder_triangles() == 0, "room: no mask outside mixed reality")
	# A ball thrown at the wall comes back.
	var a := _fly(rc, Vector3(0, 1.6, -1.2), Vector3(0, 0.5, -6), 40)
	check.call(a.v.z > 0.5 and a.p.z > -2.0 + R * 0.99 and a.max_hit > 4.0,
		"room: a ball thrown at a wall bounces back (vz %.2f, z %.2f, hit %.1f)" % [a.v.z, a.p.z, a.max_hit])
	var b := _fly(rc, Vector3(0, 1.6, -1.6), Vector3(0, 0, -6), 6, false)
	check.call(absf(b.v.z - 6.0 * 0.55 * RoomColliders.DAMP) < 0.05,
		"room: the bounce keeps 55%% of the speed, then x0.92 (%.2f)" % b.v.z)
	# A fast one (2.2 m per frame) doesn't tunnel.
	var c := _fly(rc, Vector3(0, 1.5, -0.5), Vector3(0, 0, -160), 3, false)
	check.call(c.p.z > -2.0 and c.v.z > 0.0 and c.first == 0, "room: a fast throw can't slip through the wall (z %.2f)" % c.p.z)
	# Beside the wall: no contact.
	var d := _fly(rc, Vector3(3.0, 1.5, -1.5), Vector3(0, 0, -6), 20, false)
	check.call(d.max_hit == 0.0 and d.p.z < -2.5, "room: past the wall's edge it flies on")
	# Dropped on the table top: bounces up and stays on it.
	var e := _fly(rc, Vector3(0.1, 1.4, -0.8), Vector3.ZERO, 30)
	check.call(e.first >= 0 and e.v.y > 0.0 and e.p.y >= 0.75 + R * 0.99,
		"room: a ball dropped on a table bounces up (vy %.2f, y %.2f)" % [e.v.y, e.p.y])
	# The floor plane is the game's own floor: ignored.
	var f := _fly(rc, Vector3(-2, 0.3, 1.0), Vector3(0, -3, 0), 10)
	check.call(f.max_hit == 0.0 and f.p.y < 0.0, "room: the scanned floor is ignored")
	# Thrown at the couch volume, fast or slow: comes back off its side.
	var g := _fly(rc, Vector3(1.0, 0.4, 0), Vector3(5, 0, 0), 30, false)
	var g2 := _fly(rc, Vector3(1.6, 0.4, 0.3), Vector3(120, 0, 0), 2, false)
	check.call(g.v.x < 0.0 and g.p.x < 2.1 - R * 0.99 and g2.v.x < 0.0 and g2.p.x < 2.1,
		"room: a ball bounces off the couch (x %.2f / %.2f)" % [g.p.x, g2.p.x])
	# Resting on the couch seat: pushed out, not through.
	var h := _fly(rc, Vector3(2.5, 1.2, 0.5), Vector3.ZERO, 60)
	check.call(h.p.y > 0.8 + R * 0.9, "room: a ball lands on the couch (y %.2f)" % h.p.y)

	# Aiming.
	var rw := s.ray_surface(Vector3(0, 1.5, 0), Vector3(0, 0, -1))
	check.call(rw.get("label", "") == "wall" and absf(rw.p.z + 2.0) < 1e-3 and rw.n.is_equal_approx(Vector3.BACK),
		"room: ray_surface finds the wall")
	var rt := s.ray_surface(Vector3(0, 1.6, 0), Vector3(0, 0.75, -0.8) - Vector3(0, 1.6, 0))
	check.call(rt.get("label", "") == "table" and absf(rt.p.y - 0.75) < 1e-3, "room: ray_surface finds the table")
	var rcch := s.ray_surface(Vector3(2.5, 1.6, 1.5), Vector3(0, -1, -1))
	check.call(rcch.get("label", "") == "couch" and rcch.n.is_equal_approx(Vector3.UP), "room: ray_surface finds the couch seat")
	var rf := s.ray_surface(Vector3(-2, 1.6, 0), Vector3(0, -1, 0.3))
	check.call(rf.get("label", "") == "floor" and rf.n.is_equal_approx(Vector3.UP), "room: ray_surface finds the floor")
	check.call(s.ray_surface(Vector3(0, 1.5, -3), Vector3(0, 0, 1)).is_empty(), "room: a wall is not hit from behind")
	check.call(s.ray_surface(Vector3(0, 1.5, 0), Vector3(0, 0, -1), 1.5).is_empty(), "room: beyond max_dist is a miss")

	rc.show_planes(true)
	check.call(rc.line_count() == 3 * 4 + 12, "room: outlines of planes and volume (%d)" % rc.line_count())
	rc.show_planes(false)
	rc.free()
	s.free()
