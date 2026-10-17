extends RefCounted
## The blaster's shot styles (WorldBalls + ShotCatalog): every style fires, flies or acts,
## hits a stage target through stage.shoot(), pops a resting Dahrooj and keeps its
## cooldown; the laser pierces, lightning chains, the rocket homes, the boomerang comes
## back (hitting on both ways), the confetti cannon fans out, the bouncy ball bounces,
## the jelly glob splats and pops what is near, the dallah sprays beans; locked styles fall
## back to the bolt; the catalog, the menu and the icons agree.

const DT := 1.0 / 72.0
const O := Vector3(0, 1.0, 0)
const FWD := Vector3(0, 0, -1)


## What WorldBalls asks of the main scene, and no more (no park, no room, no intro).
class FakeRuntime:
	extends RefCounted
	var added: Array = []
	var credits: Array = []  # [kind, n] from shot_hits
	var progress: Array = []  # [id, value] from ch_progress
	func ch_add(id: String) -> void:
		added.append(id)
	func shot_hits(kind: String, n: int) -> void:
		credits.append([kind, n])
	func ch_progress(id: String, value: int) -> void:
		progress.append([id, value])
	func credited(kind: String) -> int:
		var n := 0
		for c: Array in credits:
			if c[0] == kind:
				n += int(c[1])
		return n
	func best(id: String) -> int:
		var v := 0
		for c: Array in progress:
			if c[0] == id:
				v = maxi(v, int(c[1]))
		return v


class FakeHost:
	extends Node3D
	var scale_now := 1.0
	var mode := "vr"
	var stage: Node3D = null
	var park = null
	var runtime := FakeRuntime.new()
	var sounds: Array = []
	var recalls := 0
	func note_style() -> void: pass
	func sfx(snd: String, k: float, pos: Vector3) -> void:
		sounds.append([snd, k, pos])
	func buzz(_hand: String, _amp: float, _ms: float) -> void: pass
	func nature_on() -> bool: return false
	func resting_allowed() -> bool: return true
	func eye_game() -> Vector3: return Vector3(0, 1.6, 0)
	func ball_popped() -> void:
		recalls += 1
	func time_k() -> float: return 1.0


## A plain stage: hidden hit spheres (layers = 0, like the arcade modes' targets) that
## take a shot, and walls that do not. sturdy: a target stays up when hit.
class TargetStage:
	extends Node3D
	var hits := 0
	var hit_log: Array = []
	var targets: Array = []
	var sturdy := false
	var fan := 1
	func shot_fan() -> int: return fan
	func add_target(p: Vector3, r: float) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = r
		s.height = r * 2.0
		mi.mesh = s
		mi.layers = 0
		mi.position = p
		add_child(mi)
		targets.append(mi)
		return mi
	func add_wall(p: Vector3, size: Vector3) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = size
		mi.mesh = b
		mi.position = p
		add_child(mi)
		return mi
	func shoot(obj: Node, _point: Vector3, _dir: Vector3) -> bool:
		if obj in targets and (obj as Node3D).visible:
			hits += 1
			hit_log.append(obj)
			if not sturdy:
				(obj as Node3D).visible = false
			return true
		return false


static func _rig() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	# The suite runs from the test scene's _ready (the root is busy): hang it under that scene.
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root.get_child(tree.root.get_child_count() - 1)
	var host := FakeHost.new()
	parent.add_child(host)
	var b := Ball.new()
	var wb := WorldBalls.new(host, b)
	host.add_child(wb)
	return {"host": host, "wb": wb, "ball": b}


static func _stage(rig: Dictionary) -> TargetStage:
	var host: FakeHost = rig.host
	if host.stage:
		host.stage.free()
	var st := TargetStage.new()
	host.add_child(st)
	host.stage = st
	return st


## A banner hanging in front of a wall: the shot's ray goes through the words to the wall.
static func _through_text(check: Callable, rig: Dictionary) -> void:
	var wb: WorldBalls = rig.wb
	_reset(rig)
	var st := _stage(rig)
	st.add_wall(O + FWD * 3.0, Vector3(3, 3, 0.2))
	var banner := JuiceText.spawn(st, "WAVE 1", O + FWD * 1.5, "banner", 3.0)
	var hit := wb.ray_stage(st, O, FWD, 10.0)
	check.call(banner != null and not hit.is_empty() and (hit.point as Vector3).distance_to(O) > 2.5,
		"shots: fly through floating texts and hit what is behind them (%s)" % [hit.get("point", "none")])


static func _reset(rig: Dictionary) -> void:
	var wb: WorldBalls = rig.wb
	var host: FakeHost = rig.host
	wb.clear_rests()
	wb.clear_blast()
	wb.last_shot = {"left": -10.0, "right": -10.0}
	host.sounds.clear()
	host.runtime.added.clear()
	host.runtime.credits.clear()
	host.runtime.progress.clear()
	if host.stage:
		host.stage.free()
		host.stage = null


static func _rest(rig: Dictionary, p: Vector3) -> void:
	(rig.ball as Ball).rest_hook.call(p, Vector3.ZERO)


static func _run(wb: WorldBalls, seconds: float, until := Callable()) -> void:
	for i in int(seconds / DT):
		wb.step_blast(DT)
		if until.is_valid() and until.call():
			return


## Where a style's first target goes: straight ahead, or a boomerang's far point.
static func _ahead(id: String, d: float) -> Vector3:
	var muzzle := O + FWD * 0.08
	if id == "boomerang":
		var P: Dictionary = WorldBalls.SHOT_STYLE.boomerang
		return muzzle + FWD * float(P.reach) + Vector3.UP * 0.25
	return muzzle + FWD * d


static func run(check: Callable) -> void:
	var keep_style: String = Save.shot_style
	var keep_ch: Dictionary = Save.challenges.duplicate(true)
	_catalog(check)
	_menu(check)
	var rig := _rig()
	var wb: WorldBalls = rig.wb
	var host: FakeHost = rig.host
	# Every style open for the test.
	for id: String in ShotCatalog.ids():
		Save.challenges["shot:" + id] = 1
	_each_style(check, rig)
	_laser(check, rig)
	_lightning(check, rig)
	_rocket(check, rig)
	_boomerang(check, rig)
	_spread(check, rig)
	_bouncy(check, rig)
	_glob(check, rig)
	_dallah(check, rig)
	_scale(check, rig)
	_through_text(check, rig)
	# Locked: with no challenges done a new style is the bolt again.
	_reset(rig)
	Save.challenges = {}
	Save.shot_style = "laser"
	check.call(wb.style_for() == "bolt", "shots: a locked style fires the bolt")
	Save.challenges = {"skyPop5": 5}
	check.call(wb.style_for() == "laser", "shots: its own challenge (skyPop5) unlocks the laser")
	host.free()
	Save.shot_style = keep_style
	Save.challenges = keep_ch


static func _catalog(check: Callable) -> void:
	var bad: Array = []
	var ids: Array = []
	for c: Array in MenuCatalog.SHOTS:
		ids.append(c[0])
		var info := ShotCatalog.info(c[0])
		if info.is_empty() or info.ar != c[1] or info.en != c[2] or not MenuIcons.IDS.has(str(info.icon)):
			bad.append(c[0])
		if not WorldBalls.SHOT_STYLE.has(c[0]) or not ShotCatalog.SHOT_UNLOCKS.has(c[0]):
			bad.append(c[0] + ":style")
		if not GameAudio.SFX.has(str(info.get("sound", ""))):
			bad.append(c[0] + ":sound")
	check.call(bad.is_empty() and ids == ShotCatalog.ids() and ids.size() >= 10, "shots: the catalog, menu, styles, icons and sounds agree %s" % [bad])
	var free_ids: Array = []
	for id: String in ShotCatalog.ids():
		if ShotCatalog.available(id, 0, {}):
			free_ids.append(id)
	check.call(free_ids == ["bolt", "mini", "bubble", "firework"], "shots: the first four are open from the start %s" % [free_ids])
	check.call(not ShotCatalog.available("laser", 40, {}) and ShotCatalog.available("laser", 0, {"skyPop5": 5}) and not ShotCatalog.available("laser", 0, {"skyPop5": 4})
		and ShotCatalog.available("laser", 0, {"shot:laser": 1}) and ShotCatalog.need_text("laser")[1] == "Pop 5 Dahroojs above your head",
		"shots: the laser opens with its challenge (pop 5 above your head), not a count")


## Each style: fires (with its sound), keeps its cooldown, pops a Dahrooj ahead, hits a stage target.
static func _each_style(check: Callable, rig: Dictionary) -> void:
	var wb: WorldBalls = rig.wb
	var host: FakeHost = rig.host
	var fire_bad: Array = []
	var cool_bad: Array = []
	var pop_bad: Array = []
	var hit_bad: Array = []
	for id: String in ShotCatalog.ids():
		var P: Dictionary = WorldBalls.SHOT_STYLE[id]
		Save.shot_style = id
		# Fires, makes its sound, and something is in flight (or a beam is drawn).
		_reset(rig)
		var n0 := wb.fired
		wb.fire("right", O, FWD)
		var snd := str(ShotCatalog.info(id).sound)
		var heard := false
		for s: Array in host.sounds:
			if s[0] == snd:
				heard = true
		if wb.fired != n0 + 1 or not heard or (wb.shots.is_empty() and wb.arcs.is_empty()):
			fire_bad.append(id)
		# Cooldown: not again at once, again once it has passed (the other hand is free).
		wb.fire("right", O, FWD)
		var held := wb.fired == n0 + 1
		wb.fire("left", O, FWD)
		var other := wb.fired == n0 + 2
		wb.clock += float(P.cool) + 0.001
		wb.fire("right", O, FWD)
		if not (held and other and wb.fired == n0 + 3):
			cool_bad.append(id)
		# Pops a resting Dahrooj in front of it.
		_reset(rig)
		_rest(rig, _ahead(id, 2.0))
		var before := wb.popped
		wb.fire("right", O, FWD)
		_run(wb, 3.0, func(): return wb.rests.is_empty())
		if not wb.rests.is_empty() or wb.popped <= before:
			pop_bad.append(id)
		# Hits a target of the mode (stage.shoot).
		_reset(rig)
		var st := _stage(rig)
		st.add_target(_ahead(id, 1.5), 0.2)
		wb.fire("right", O, FWD)
		_run(wb, 3.0, func(): return st.hits > 0)
		if st.hits < 1:
			hit_bad.append(id)
	check.call(fire_bad.is_empty(), "shots: every style fires with its sound %s" % [fire_bad])
	check.call(cool_bad.is_empty(), "shots: every style keeps its cooldown, per hand %s" % [cool_bad])
	check.call(pop_bad.is_empty(), "shots: every style pops a resting Dahrooj %s" % [pop_bad])
	check.call(hit_bad.is_empty(), "shots: every style hits a stage target %s" % [hit_bad])


static func _laser(check: Callable, rig: Dictionary) -> void:
	var wb: WorldBalls = rig.wb
	_reset(rig)
	Save.shot_style = "laser"
	for d in [2.0, 3.0, 4.0, 5.0]:
		_rest(rig, O + FWD * d)
	wb.fire("right", O, FWD)
	check.call(wb.rests.size() == 1 and (wb.rests[0].p as Vector3).z < -4.9 and wb.arcs.size() == 1 and wb.shots.is_empty(),
		"laser: an instant beam pierces three Dahroojs and stops in the third (%d left)" % wb.rests.size())
	var host: FakeHost = rig.host
	check.call(host.runtime.credited("laser") == 3, "laser: its three hits count toward laser30 (%d)" % host.runtime.credited("laser"))
	var arc: Dictionary = wb.arcs[0]
	check.call(absf((arc.b as Vector3).z - (O.z - 4.0)) < 0.1, "laser: the beam ends at the last one it went through")
	_run(wb, 0.4)
	check.call(wb.arcs.is_empty(), "laser: the glowing line fades")
	# Through two of the mode's targets and a Dahrooj; a wall stops it.
	_reset(rig)
	var st := _stage(rig)
	st.add_target(O + FWD * 2.0, 0.2)
	st.add_target(O + FWD * 3.0, 0.2)
	st.add_wall(O + FWD * 4.0, Vector3(2, 2, 0.2))
	_rest(rig, O + FWD * 3.5)
	_rest(rig, O + FWD * 5.0)
	wb.fire("right", O, FWD)
	check.call(st.hits == 2 and wb.rests.size() == 1 and (wb.rests[0].p as Vector3).z < -4.9, "laser: through two targets and a Dahrooj, stopped by a wall")


static func _lightning(check: Callable, rig: Dictionary) -> void:
	var wb: WorldBalls = rig.wb
	_reset(rig)
	Save.shot_style = "lightning"
	for x in [0.0, 1.5, 3.0, 4.5, 6.0]:
		_rest(rig, O + Vector3(x, 0, -4))
	wb.fire("right", O, FWD)
	check.call(wb.rests.size() == 1 and absf((wb.rests[0].p as Vector3).x - 6.0) < 0.01 and wb.arcs.size() == 4,
		"lightning: chains through four Dahroojs, one hop at a time (%d left, %d arcs)" % [wb.rests.size(), wb.arcs.size()])
	var host: FakeHost = rig.host
	check.call(host.runtime.best("chain4") == 4, "lightning: a chain of four counts for chain4")
	var jag := false
	for arc: Dictionary in wb.arcs:
		if int(arc.n) >= 4 and float(arc.jit) > 0.0:
			jag = true
	check.call(jag, "lightning: along jagged arcs")
	# To a stage target and on to a Dahrooj near it.
	_reset(rig)
	var st := _stage(rig)
	st.add_target(O + FWD * 5.0, 0.25)
	_rest(rig, O + Vector3(1.2, 0, -5))
	wb.fire("right", O, FWD)
	check.call(st.hits == 1 and wb.rests.is_empty(), "lightning: from a stage target on to a Dahrooj")


static func _rocket(check: Callable, rig: Dictionary) -> void:
	var wb: WorldBalls = rig.wb
	_reset(rig)
	Save.shot_style = "rocket"
	_rest(rig, O + Vector3(2.0, 0, -5))
	wb.fire("right", O, FWD)
	var s: Dictionary = wb.shots[0]
	var slow: float = (s.v as Vector3).length()
	var side := 0.0
	for i in int(3.0 / DT):
		wb.step_blast(DT)
		side = maxf(side, (s.p as Vector3).x)
		if wb.rests.is_empty():
			break
	check.call(slow < 0.3 * float(WorldBalls.SHOT_STYLE.rocket.speed), "rocket: starts slow (%.1f)" % slow)
	check.call(wb.rests.is_empty() and side > 1.0, "rocket: homes in on a Dahrooj off to the side (%.2f)" % side)
	# Its blast pops what is around it.
	_reset(rig)
	var st := _stage(rig)
	st.add_target(O + FWD * 4.0, 0.2)
	_rest(rig, O + Vector3(0.5, 0, -4.0))
	wb.fire("right", O, FWD)
	_run(wb, 3.0, func(): return wb.shots.is_empty())
	check.call(st.hits == 1 and wb.rests.is_empty(), "rocket: explodes with a radius")
	var host: FakeHost = rig.host
	check.call(host.runtime.credited("rocket") >= 2, "rocket: what its blast hits counts toward rocket20 (%d)" % host.runtime.credited("rocket"))
	# Two rockets one after the other each go for their own Dahrooj.
	_reset(rig)
	_rest(rig, O + Vector3(-1.5, 0, -5))
	_rest(rig, O + Vector3(1.5, 0, -5))
	wb.fire("right", O, FWD)
	wb.fire("left", O, FWD)
	var r1: Dictionary = wb.shots[0]
	var r2: Dictionary = wb.shots[1]
	for i in int(0.4 / DT):
		wb.step_blast(DT)
	check.call(not (r1.target as Dictionary).is_empty() and not (r2.target as Dictionary).is_empty() and not is_same(r1.target.ref, r2.target.ref),
		"rocket: two in the air pick different targets")
	# The triple shot: its three rockets share out the targets too.
	_reset(rig)
	var fs := _stage(rig)
	fs.fan = 3
	for x: float in [-1.2, 0.0, 1.2]:
		fs.add_target(O + Vector3(x, 0, -5), 0.15)
	wb.fire("right", O, FWD)
	for i in int(0.4 / DT):
		wb.step_blast(DT)
	var refs := []
	for o: Dictionary in wb.shots:
		if o.kind == "rocket" and not (o.target as Dictionary).is_empty() and not refs.any(func(r) -> bool: return is_same(r, o.target.ref)):
			refs.append(o.target.ref)
	check.call(refs.size() == 3, "rocket: the triple shot's three rockets go for three targets (%d)" % refs.size())
	fs.fan = 1


static func _boomerang(check: Callable, rig: Dictionary) -> void:
	var wb: WorldBalls = rig.wb
	_reset(rig)
	Save.shot_style = "boomerang"
	wb.fire("right", O, FWD)
	var s: Dictionary = wb.shots[0]
	var far := 0.0
	var last := O
	# The model: a classic boomerang (two curved arms, flat), leaning into its curve and spinning
	# flat in its own plane.
	var nd: Node3D = s.node
	var sp := nd.get_node_or_null("Tilt/Spin") as Node3D
	var mesh := WorldBalls.boomerang_mesh()
	var bb := mesh.get_aabb()
	check.call(sp != null and sp.get_child_count() == 1 and (sp.get_child(0) as MeshInstance3D).mesh == mesh
		and bb.size.x > 0.25 and bb.size.x < 0.36 and bb.size.y < 0.02 and bb.size.z > 0.06 and bb.size.z < bb.size.x * 0.6
		and absf(bb.get_center().x) < 0.01,
		"boomerang: a curved V, about 0.3 tip to tip and thin (%s)" % [bb])
	var spins: Array = []
	var banks: Array = []
	for i in int(4.0 / DT):
		wb.step_blast(DT)
		if i % 6 == 0 and sp != null and is_instance_valid(sp):
			spins.append(sp.rotation.y)
			banks.append(absf(float(s.bank)))
		last = s.p
		far = maxf(far, (s.p as Vector3).distance_to(O))
		if wb.shots.is_empty():
			break
	check.call(far > 5.0 and s.caught and last.distance_to(s.o) < 0.3 and wb.shots.is_empty(),
		"boomerang: curves out (%.1f) and comes back to the hand (%.2f)" % [far, last.distance_to(s.o)])
	var turned := 0.0
	for i in range(1, spins.size()):
		turned += absf(angle_difference(float(spins[i - 1]), float(spins[i])))
	check.call(turned > 2.0 and banks.max() > 0.1,
		"boomerang: it spins (%.1f rad seen) and banks into its curve (%.2f)" % [turned, banks.max()])
	# A big target in its way: hit on the way out and again on the way back.
	_reset(rig)
	var st := _stage(rig)
	st.sturdy = true
	st.add_target(O + FWD * 1.8, 1.0)
	wb.fire("right", O, FWD)
	_run(wb, 3.0, func(): return wb.shots.is_empty())
	var host: FakeHost = rig.host
	check.call(st.hits >= 2, "boomerang: hits on both ways (%d)" % st.hits)
	check.call(host.runtime.added.count("boomerang3") == 1, "boomerang: caught after a hit, it counts for boomerang3")
	# A wall sends it straight home.
	_reset(rig)
	st = _stage(rig)
	st.add_wall(O + FWD * 3.0, Vector3(6, 4, 0.2))
	wb.fire("right", O, FWD)
	s = wb.shots[0]
	_run(wb, 0.5)
	var back: bool = s.ret
	_run(wb, 3.0, func(): return wb.shots.is_empty())
	check.call(back and s.caught and wb.shots.is_empty() and not host.runtime.added.has("boomerang3"), "boomerang: knocked back by a wall, it flies home (no hit, no credit)")


static func _spread(check: Callable, rig: Dictionary) -> void:
	var wb: WorldBalls = rig.wb
	_reset(rig)
	Save.shot_style = "confetti"
	wb.fire("right", O, FWD)
	var cone: float = WorldBalls.SHOT_STYLE.confetti.cone
	var angles: Array = []
	var dirs: Array = []
	for s: Dictionary in wb.shots:
		if s.kind == "confetti":
			angles.append(FWD.angle_to(s.dir))
			dirs.append(s.dir)
	var off := 0
	var inside := true
	for a: float in angles:
		if a > 0.05:
			off += 1
		if a > cone + 1e-3:
			inside = false
	var distinct := true
	for i in dirs.size():
		for j in range(i + 1, dirs.size()):
			if (dirs[i] as Vector3).angle_to(dirs[j]) < 0.02:
				distinct = false
	check.call(angles.size() == 5 and off == 4 and inside and distinct, "confetti: five pellets fan out in a cone %s" % [angles])
	_run(wb, 0.3)
	var flakes := 0
	for sp: Dictionary in wb.sparks:
		if sp.flake:
			flakes += 1
	check.call(flakes > 5, "confetti: with confetti trails (%d)" % flakes)


static func _bouncy(check: Callable, rig: Dictionary) -> void:
	var wb: WorldBalls = rig.wb
	_reset(rig)
	Save.shot_style = "bouncy"
	wb.fire("right", O, Vector3(0, -0.6, -1).normalized())
	var s: Dictionary = wb.shots[0]
	var up := false
	for i in int(1.5 / DT):
		wb.step_blast(DT)
		if int(s.bounces) >= 1 and (s.v as Vector3).y > 0.0:
			up = true
			break
	check.call(up and not wb.shots.is_empty(), "bouncy: bounces off the floor and carries on")
	# It pops on through a few Dahroojs.
	_reset(rig)
	_rest(rig, O + FWD * 1.5)
	_rest(rig, O + FWD * 2.4 + Vector3.DOWN * 0.1)
	wb.fire("right", O, FWD)
	_run(wb, 2.0, func(): return wb.rests.is_empty())
	check.call(wb.rests.is_empty(), "bouncy: pops on through more than one")
	var host: FakeHost = rig.host
	check.call(host.runtime.best("bouncy3") >= 2, "bouncy: the hits of one ball count toward bouncy3 (%d)" % host.runtime.best("bouncy3"))
	# It never wears out (still hopping long after), and at most BOUNCY_MAX at once: the oldest goes.
	_reset(rig)
	wb.fire("right", O, Vector3(0.3, -0.2, -1).normalized())
	var first: Dictionary = wb.shots[0]
	_run(wb, 6.0)
	var hops := false
	for i in int(2.0 / DT):
		wb.step_blast(DT)
		hops = hops or (first.v as Vector3).y > 0.5
	check.call(wb.shots.has(first) and hops, "bouncy: still bouncing about after 6 s")
	_run(wb, 3.0)
	check.call(not wb.shots.has(first), "bouncy: gone after its ten seconds")
	_reset(rig)
	wb.fire("right", O, Vector3(0.3, -0.2, -1).normalized())
	first = wb.shots[0]
	for i in WorldBalls.BOUNCY_MAX + 3:
		wb.last_shot = {}
		wb.fire("right", O, Vector3(0, 0.2, -1).normalized())
	var n := wb.shots.filter(func(o: Dictionary) -> bool: return o.kind == "bouncy").size()
	check.call(n == WorldBalls.BOUNCY_MAX and not wb.shots.has(first), "bouncy: at most %d at once, the oldest makes way (%d)" % [WorldBalls.BOUNCY_MAX, n])


static func _glob(check: Callable, rig: Dictionary) -> void:
	var wb: WorldBalls = rig.wb
	_reset(rig)
	Save.shot_style = "glob"
	# Where the glob lands on the floor (the last place it flew), then a Dahrooj there.
	var dir := Vector3(0, -0.5, -1).normalized()
	wb.fire("right", O, dir)
	var landed := {"p": O}
	_run(wb, 2.0, func():
		if wb.shots.is_empty():
			return true
		landed.p = wb.shots[0].p
		return false)
	check.call(wb.shots.is_empty() and absf((landed.p as Vector3).y) < 0.3, "jelly: the glob splats on the floor")
	check.call(not ("puddles" in wb), "jelly: no green puddle left behind")
	_reset(rig)
	Save.shot_style = "glob"
	_rest(rig, Vector3((landed.p as Vector3).x + 0.1, Ball.BR, (landed.p as Vector3).z))
	wb.fire("right", O, dir)
	_run(wb, 2.0, func(): return wb.shots.is_empty())
	check.call(wb.rests.is_empty(), "jelly: and the splat pops a Dahrooj sitting there")
	# The splat on a wall pops a Dahrooj beside the spot (out of the glob's own path).
	_reset(rig)
	var st := _stage(rig)
	st.add_wall(O + FWD * 3.0, Vector3(3, 3, 0.2))
	_rest(rig, O + FWD * 2.8 + Vector3(0.45, -0.3, 0))
	wb.fire("right", O, FWD)
	_run(wb, 2.0, func(): return wb.shots.is_empty())
	check.call(wb.rests.is_empty(), "jelly: the splat on a wall pops a Dahrooj beside it")


static func _dallah(check: Callable, rig: Dictionary) -> void:
	var wb: WorldBalls = rig.wb
	_reset(rig)
	Save.shot_style = "dallah"
	wb.fire("right", O + Vector3.UP, FWD)
	var beans := 0
	for i in int(0.4 / DT):
		wb.step_blast(DT)
		for s: Dictionary in wb.shots:
			if s.kind == "bean":
				beans += 1
	check.call(beans > 0 and wb.shots.size() < WorldBalls.SHOTS_MAX, "dallah: the pot sprays coffee beans as it flies")
	# Its ding is soft and spaced: both hands holding the trigger for two seconds.
	_reset(rig)
	var host: FakeHost = rig.host
	var st := _stage(rig)
	st.sturdy = true
	st.add_wall(O + FWD * 2.5, Vector3(6, 4, 0.2))
	for i in int(2.0 / DT):
		for h: String in ["left", "right"]:
			wb.fire(h, O + Vector3.UP, FWD)
		wb.step_blast(DT)
	var dings: Array = host.sounds.filter(func(x: Array) -> bool: return x[0] == "fair_ding")
	var thumps: Array = host.sounds.filter(func(x: Array) -> bool: return x[0] == "thump")
	var loud: Array = dings.filter(func(x: Array) -> bool: return float(x[1]) > 0.31)
	check.call(dings.size() > 0 and dings.size() <= int(2.0 / WorldBalls.DALLAH_DING_GAP) + 1 and loud.is_empty() and thumps.size() <= int(2.0 / WorldBalls.BEAN_THUMP_GAP) + 1,
		"dallah: its dings are soft and spaced (%d dings, %d thumps in 2 s, both hands)" % [dings.size(), thumps.size()])
	var ga := GameAudio.new()
	check.call(float(ga.pick("fair_ding", WorldBalls.DALLAH_FIRE_K)[1]) < -9.0 and is_zero_approx(float(ga.pick("fair_ding", 1.0)[1])),
		"dallah: its ding plays %.1f dB under the fair's bell (which keeps its level)" % float(ga.pick("fair_ding", WorldBalls.DALLAH_FIRE_K)[1]))
	ga.free()


## Mixed reality: the shots grow and shrink with the court (blast_k).
static func _scale(check: Callable, rig: Dictionary) -> void:
	var wb: WorldBalls = rig.wb
	var host: FakeHost = rig.host
	_reset(rig)
	host.scale_now = 8.0
	var bad: Array = []
	for id: String in ["bolt", "rocket", "boomerang", "glob", "confetti"]:
		Save.shot_style = id
		wb.last_shot = {"left": -10.0, "right": -10.0}
		wb.clear_blast()
		wb.fire("right", O * 8.0, FWD)
		var s: Dictionary = wb.shots[0]
		if absf(float(s.r) - float(WorldBalls.SHOT_STYLE[id].r) * 8.0) > 1e-4:
			bad.append(id)
	Save.shot_style = "laser"
	wb.clear_blast()
	wb.last_shot = {"left": -10.0, "right": -10.0}
	wb.fire("right", O * 8.0, FWD)
	if wb.arcs.is_empty() or absf(float(wb.arcs[0].w) - 0.022 * 8.0) > 1e-4:
		bad.append("laser")
	check.call(bad.is_empty(), "shots: sizes scale with the court (blast_k) %s" % [bad])
	host.scale_now = 1.0
	wb.clear_blast()


## The Play page: twelve shot cards, the ones not yet unlocked locked with what they need.
static func _menu(check: Callable) -> void:
	var p := MenuPanel.new()
	p.set_page("play")
	var ch: Array = []
	for c: Array in MenuCatalog.CHALLENGES:
		ch.append({"id": c[0], "title": c[2], "en": c[3], "value": 0, "goal": c[1]})
	var m := {"english": true, "kind": "vr", "mode": "hoop", "style": "jelly", "jelly_color": "pink", "throw_style": "trigger",
		"shot_style": "bolt", "time": "auto", "weather": "auto", "accessory": "", "done": 0, "reset_armed": false, "challenges": ch}
	p.draw(m, -1)
	var shots: Array = []
	var locked: Array = []
	var subs_ok := true
	var inside := true
	for b: Dictionary in p.buttons:
		if b.kind != "shot":
			continue
		shots.append(b.id)
		if b.disabled:
			locked.append(b.id)
			if str(b.sub) == "" or str(b.sub) != str(MenuCatalog.challenge(str(ShotCatalog.need(b.id)))[3]):
				subs_ok = false
		if float(b.y) + float(b.h) > 548.0 or float(b.x) < 0.0 or float(b.x) + float(b.w) > 1200.0:
			inside = false
	check.call(shots == ShotCatalog.ids() and locked.size() == shots.size() - 4 and subs_ok and inside,
		"menu: the Play page shows every shot, the new ones locked with what they need %s" % [locked])
	var lock_i := -1
	for i in p.buttons.size():
		if p.buttons[i].kind == "shot" and p.buttons[i].id == "laser":
			lock_i = i
	check.call(lock_i >= 0 and p.action(lock_i).is_empty(), "menu: a locked shot card cannot be picked")
	m.done = 40
	p.draw(m, -1)
	check.call(p.action(lock_i).is_empty(), "menu: a count of finished challenges does not open it")
	m["rewards"] = {"skyPop5": 5}
	p.draw(m, -1)
	check.call(not p.action(lock_i).is_empty() and p.buttons[lock_i].id == "laser", "menu: its challenge opens the laser card")
	p.free()
