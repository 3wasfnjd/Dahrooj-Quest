extends RefCounted
## Headless checks of the park's moving parts (nature.js port): a ball bounces off a
## pole, shoves a lantern that slides and settles, sets off a crate (0.4 s fuse, a
## fireball, on_explode), the crates next to it go up too and all pop back after 25 s;
## a stacked crate drops onto the one below; marks press the tracks; the pond
## ripples; night lights the pole glass.

const DT := 1.0 / 72.0


static func _step(park: Park, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		park.update(DT)


## A ball r from the box face along the item's local x axis, moving back into it.
static func _against(it: Dictionary, hx: float, r: float, y: float, speed: float) -> Array:
	var rot: float = it.rot
	var dir := Vector3(cos(rot), 0, -sin(rot))
	var c := Vector3(it.x, y, it.z)
	return [c + dir * (hx + r - 0.05), -dir * speed]


static func run(check: Callable) -> void:
	# Built outside the tree (the suites run while the root is still adding children).
	var park := Park.new()
	park.build()
	park.set_settings({"time": "day", "weather": "clear"})
	park.update(DT)
	var r := Ball.BR

	# 1. A pole: the ball is pushed out and bounces back.
	var pole: Dictionary = park.props.poles[0]
	var a := _against(pole, 0.2, r, 0.5, 5.0)
	var res := park.collide(a[0], a[1], r)
	var pv: Vector3 = res.v
	var pp: Vector3 = res.p
	check.call(bool(res.hit) and pv.x > 2.0 and pp.x >= float(pole.x) + 0.2 + r - 1e-3, "park: a ball against a pole bounces off (%s)" % str(pv))
	check.call(not park.collide(Vector3(pole.x, 4.0, pole.z), Vector3(0, -1, 0), r).hit, "park: above the poles nothing is hit")

	# 2. A lantern: shoved, it slides, spins, tips and settles back upright.
	var lan: Dictionary = park.props.lanterns[0]
	var start := Vector2(lan.x, lan.z)
	var shown: Array = park.prop_set.items.lanterns.shown
	var shown0: Vector3 = (shown[0] as Transform3D).origin
	a = _against(lan, 0.35 * ParkProps.LANTERN, r, 0.3, 6.0)
	res = park.collide(a[0], a[1], r)
	check.call(bool(res.hit), "park: a ball hits a lantern")
	_step(park, 0.1)
	var ob: Dictionary = {}
	for o: Dictionary in park.prop_set.obstacles:
		if o.it == lan:
			ob = o
	check.call(float(lan.get("tilt", 0.0)) > 0.0, "park: the shoved lantern tips (%.2f)" % float(lan.get("tilt", 0.0)))
	_step(park, 3.0)
	var moved := Vector2(lan.x, lan.z).distance_to(start)
	var still := absf(ob.vx) + absf(ob.vz) + absf(ob.spin) + float(ob.tip) < 0.002
	check.call(moved > 0.3 and still and absf(float(lan.get("tilt", 0.0))) < 0.01, "park: the lantern slid %.2f and settled upright" % moved)
	check.call((shown[0] as Transform3D).origin.distance_to(shown0) > 0.3, "park: the lantern's model moved with it")

	# A lantern shoved into the pond settles half under, with a white line round it.
	var lan2: Dictionary = park.props.lanterns[1]
	lan2.x = -22.0
	lan2.z = -5.0
	for o: Dictionary in park.prop_set.obstacles:
		if o.it == lan2:
			o.vx = 0.01  # wake it
	_step(park, 3.0)
	check.call(float(lan2.get("y", 0.0)) < -0.1 and park.water.line_count() >= 1, "park: a lantern in the pond sinks half under (%.2f) with a water line" % float(lan2.get("y", 0.0)))

	# 3. A stacked crate drops onto the one below.
	var top: Dictionary = park.props.crates[2]
	check.call(absf(float(top.y) - 1.06 * ParkProps.CRATE) < 0.01, "park: the top crate sits on the ones below (%.3f)" % float(top.y))

	# 4. Crates: a touch lights the fuse, 0.4 s later it blows up, the others follow, all come back.
	park.reset()
	var got: Array = []
	park.on_explode = func(at: Vector3, rad: float, bp: bool) -> void: got.append([at, rad, bp])
	var sig: Array = [0]
	var on_sig := func(_at: Vector3, _rad: float, _bp: bool) -> void: sig[0] += 1
	park.exploded.connect(on_sig)
	var c0: Dictionary = park.props.crates[0]
	a = _against(c0, 0.53 * ParkProps.CRATE, r, 0.3, 4.0)
	res = park.collide(a[0], a[1], r)
	check.call(bool(res.hit) and bool(c0.exploded) and float(c0.fuse) > 0.0, "park: touching a crate lights its fuse")
	_step(park, 0.3)
	check.call(got.is_empty(), "park: the fuse burns for a moment")
	_step(park, 0.15)
	check.call(got.size() == 1 and float(got[0][1]) == ParkProps.BLAST and bool(got[0][2]), "park: then the crate explodes (on_explode)")
	check.call(park.prop_set.fires.size() == 1 and float(c0.k) == 0.0, "park: in a fireball, and the crate is gone")
	check.call(park.track_at(c0.x, c0.z) > 0.5, "park: the blast marks the ground")
	_step(park, 0.45)
	check.call(got.size() == 3 and sig[0] == 3, "park: the crates next to it go up too (%d)" % got.size())
	_step(park, 2.5)
	check.call(park.prop_set.fires.is_empty(), "park: the fireballs burn away")
	var p_mid: Dictionary = park.collide_crates(Vector3(c0.x, 0.3, c0.z), Vector3(0, -1, 0), r)
	check.call(not bool(p_mid.hit), "park: a blown crate is no obstacle")
	_step(park, 23.0)
	var all_back := true
	for c: Dictionary in park.props.crates:
		all_back = all_back and not c.exploded and float(c.k) > 0.99
	check.call(all_back and absf(float(c0.x) - float(c0.home.x)) < 1e-6, "park: the crates come back after 25 s")
	park.exploded.disconnect(on_sig)

	# 5. Tracks: a mark presses the ground.
	var before := park.track_at(2.0, -3.0)
	park.mark(2.0, -3.0, 0.4, 0.6)
	check.call(before < 0.01 and park.track_at(2.0, -3.0) > 0.5, "park: mark() presses a track (%.2f)" % park.track_at(2.0, -3.0))
	var pressed := park.track_at(2.0, -3.0)
	_step(park, 5.0)
	check.call(park.track_at(2.0, -3.0) < pressed - 0.05, "park: and it heals slowly (%.2f)" % park.track_at(2.0, -3.0))

	# 6. The pond: splashes ripple, a ball in the water gets its white line.
	park.splash(-22.0, -5.0, 0.8)
	park.water_line(-22.0, 0.0, -5.0, r)
	park.water_line(0.0, 0.0, -10.0, r)  # dry: no line (the other is the sunk lantern)
	park.update(DT)
	check.call(park.water.ripple_count() == 3 and park.water.line_count() == 2, "park: a splash rings the pond, a ball in it has a water line")
	_step(park, 2.5)
	check.call(park.water.ripple_count() == 0, "park: the ripples fade")

	# 7. Night: the pole glass comes on, the stars are out, the moon is up.
	check.call(not park.prop_set.glass_on(), "park: by day the pole glass is off")
	park.set_settings({"time": "night"})
	park.update(DT)
	var sky := park.sky_state()
	check.call(park.prop_set.glass_on() and float(park.pole_glow.get_shader_parameter("on")) == 1.0, "park: at night the pole glass glows")
	check.call(float(sky.night) > 0.99 and float(sky.stars) > 0.9 and float(sky.sun_energy) > 0.0, "park: night sky state (stars %.2f)" % float(sky.stars))
	park.set_settings({"time": "day", "weather": "rain"})
	park.update(DT)
	check.call(park.get_node("WeatherParticles").visible and float(park.sky_state().night) == 0.0, "park: rain falls when asked")

	park.free()
