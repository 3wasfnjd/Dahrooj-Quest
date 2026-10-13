extends Node
## Headless checks of the ported rules: Dahrooj's flight, the goal and its keeper,
## the volley, the pond, and the main scene booting with every system.
## godot --headless --xr-mode off --path . res://tests/run_tests.tscn [-- --report=out.txt]
## (a scene, so the Save autoload exists)

var failures: Array = []
var lines: Array = []


func check(ok: bool, what: String) -> void:
	lines.append(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures.append(what)


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	_physics()
	_goal()
	_volley()
	_art()
	_suites()
	await _scene()
	check(lines.size() >= 15, "every check ran (%d)" % lines.size())
	var report := "\n".join(lines)
	print(report)
	print("RESULT: %s — %d failure(s) in %.1fs" % ["PASS" if failures.is_empty() else "FAIL", failures.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--report="):
			var f := FileAccess.open(a.trim_prefix("--report="), FileAccess.WRITE)
			if f:
				f.store_string(report + "\n" + ("PASS" if failures.is_empty() else "FAIL") + "\n")
	get_tree().quit(0 if failures.is_empty() else 1)


class FlatStage:
	var friction = null
	var shot_time = null
	func collide(_b) -> void: pass
	func update(_b, _dt) -> void: pass


func _physics() -> void:
	var b := Ball.new()
	b.set_stage(FlatStage.new(), "flat")
	b.pos = Vector3(0, 2, 0)
	b.throw_with(Vector3(0, 0, -3))
	var seen := {"bounce": false}
	b.event.connect(func(k, _d): if k == "thump": seen.bounce = true)
	for i in 72 * 9:
		b.step(1.0 / 72.0)
	check(seen.bounce, "Dahrooj bounces when he lands")
	check(not b.shot, "a throw that comes to rest ends (and he comes back)")
	b.pos = Vector3(0, 2, 0)
	b.vel = Vector3.ZERO
	b.shot = true
	b.shot_t = 0.0
	for i in 72 * 4:
		b.step(1.0 / 72.0)
		if b.grounded:
			break
	check(b.grounded and absf(b.pos.y - Ball.BR) < 1e-3, "he rests on the ground at his radius (%.3f)" % b.pos.y)


## Shots from the player's spot (VR hand height); some must score past the keeper
## and a wide one must miss.
func _goal() -> void:
	var scored := 0
	var missed := 0
	for i in 12:
		var g := GoalStage.new()
		var b := Ball.new()
		b.set_stage(g, "goal")
		var got := {"s": false, "m": false}
		b.event.connect(func(k, _d):
			if k == "success": got.s = true
			if k == "miss": got.m = true)
		b.pos = Vector3(0.3, 2.5, 9.0)
		var x := -2.2 if i % 2 == 0 else 2.2
		b.throw_with(Vector3(x * 1.0, 6.2, -21.0))
		for k in 72 * 4:
			b.step(1.0 / 72.0)
			if got.s or got.m:
				break
		if got.s:
			scored += 1
		g.free()
	check(scored >= 6, "corner shots score past the keeper (%d / 12)" % scored)
	var g2 := GoalStage.new()
	var w := Ball.new()
	w.set_stage(g2, "goal")
	var wide := {"m": false}
	w.event.connect(func(k, _d): if k == "miss": wide.m = true)
	w.pos = Vector3(0.3, 2.5, 9.0)
	w.throw_with(Vector3(9.0, 6.0, -20.0))
	for k in 72 * 6:
		w.step(1.0 / 72.0)
		if wide.m:
			break
	check(wide.m, "a wide shot misses")
	g2.free()


func _volley() -> void:
	var b := Ball.new()
	b.set_stage(FlatStage.new(), "flat")
	b.pos = Vector3(0, 2, 0)
	b.throw_with(Vector3(0, 3, -6))
	b.step(0.05)
	check(b.another() and not b.shot and b.volley.size() == 1, "a second Dahrooj while the first still flies")
	for i in 72 * 9:
		b.step(1.0 / 72.0)
	check(b.volley.is_empty(), "earlier throws finish on their own")


func _art() -> void:
	var box := StageArt.rbox(1.0, 0.5, 0.3, 0.05, StandardMaterial3D.new())
	var bb := box.mesh.get_aabb()
	check(bb.size.distance_to(Vector3(1, 0.5, 0.3)) < 0.01, "a rounded box has the asked size")
	box.free()
	var g := Node3D.new()
	StageArt.ground_arc(g, 0, 0, 2, 0, PI)
	var ab: AABB = g.get_child(0).mesh.get_aabb()
	check(absf(ab.size.x - 4.07) < 0.02 and ab.end.z < 0.01, "a ground arc from +x through -z")
	g.free()
	var body := {"mesh": null, "x": Vector3.ZERO, "v": Vector3.ZERO, "w": Vector3.ZERO, "sleep": true}
	StageArt.shove(body, Vector3(0, 0, -1), Vector3(0.1, 0, 0), 2.0)
	check(body.v == Vector3(0, 0, -2) and not body.sleep and body.w.y > 0.0, "a shove pushes, spins and wakes a body")


## Each stage's own checks: tests/stage_<id>_test.gd with static run(check).
func _suites() -> void:
	var files := DirAccess.get_files_at("res://tests")
	files.sort()
	for f in files:
		if f.begins_with("stage_") and f.ends_with("_test.gd"):
			var sc: GDScript = load("res://tests/" + f)
			# A suite that fails to parse must fail the run, not vanish silently.
			if sc == null or not sc.can_instantiate() or not sc.has_method("run"):
				check(false, "suite %s loads" % f)
				continue
			sc.call("run", check)


## Charged throws, balls that stay in the world, the blaster.
func _world(main: Node) -> void:
	main.charge_t["right"] = 0.55
	check(absf(main.charge_power("right") - 0.5) < 0.01, "the trigger charge rises (half way at 0.55 s)")
	main.charge_t["right"] = 1.65
	check(absf(main.charge_power("right") - 0.5) < 0.01, "and falls again (ping-pong)")
	main.charge_t["right"] = 2.2
	check(absf(main.charge_power("right") - 0.08) < 0.01, "never below the minimum power")
	var wb: WorldBalls = main.world_balls
	var b: Ball = main.ball
	b.respawn()
	b.pos = Vector3(3, 1, -6)
	b.throw_with(Vector3(0, 0, -0.5))
	for i in 72 * 4:
		main.runtime.step(1.0 / 72.0)
	check(wb.rests.size() == 1, "a finished throw stays in the world (%d)" % wb.rests.size())
	var start: Vector3 = wb.rests[0].p
	for i in 72 * 12:
		wb.step_rests(1.0 / 72.0, 0.001)
	check(wb.rests[0].p.distance_to(start) > 0.3, "and sets off on his own now and then")
	# They hop now and then on their own, so test the ground, not a moment of rest:
	# never below it, and back down on it within a couple of seconds.
	var lowest := INF
	for i in 72 * 3:
		wb.step_rests(1.0 / 72.0, 0.001)
		lowest = minf(lowest, wb.rests[0].p.y)
	check(lowest >= Ball.BR - 0.01 and lowest < Ball.BR + 0.05, "resting on the ground (lowest %.3f)" % lowest)
	wb.rests[0].age = WorldBalls.REST_LIFE - 0.01
	wb.step_rests(0.0, 0.02)
	check(wb.rests.is_empty(), "leftovers go after their time")
	# Two leftovers meeting fast pop; slowly they push apart.
	b.rest_hook.call(Vector3(0, Ball.BR, -5), Vector3(4, 0, 0))
	b.rest_hook.call(Vector3(0.4, Ball.BR, -5), Vector3(-4, 0, 0))
	wb.step_contacts(0.1)
	check(wb.rests.is_empty(), "a hard meeting pops both")
	b.rest_hook.call(Vector3(0, Ball.BR, -5), Vector3.ZERO)
	b.rest_hook.call(Vector3(0.3, Ball.BR, -5), Vector3.ZERO)
	wb.step_contacts(0.01)
	check(wb.rests.size() == 2 and wb.rests[0].p.distance_to(wb.rests[1].p) >= Ball.BR * 2.0 - 1e-3, "touching ones push apart")
	# A bolt from in front of a leftover pops it.
	var target: Vector3 = wb.rests[0].p
	var before: int = wb.popped
	wb.fire("left", target + Vector3(0, 0, 3), Vector3(0, 0, -1))
	for i in 20:
		wb.step_blast(1.0 / 72.0)
	check(wb.popped > before and wb.rests.size() == 1, "a blaster bolt pops a Dahrooj")
	check(wb.sparks.size() > 0, "with a puff of sparks")
	wb.clear_rests()
	# A bolt into the goal's post hits the stage.
	var hit := wb.ray_stage(main.stage, Vector3(3.0, 1.0, -6.0), Vector3(0, 0, -1), 20.0)
	check(not hit.is_empty() and absf(hit.point.z - (-11.0)) < 0.2, "a shot meets the goal's post (%s)" % [hit.get("point", "none")])
	wb.clear_blast()
	main.begin_opening()
	check(main.intro.active and not main.stage.visible, "the opening: Dahroojs rain, the court waits")
	for i in 72 * 4:
		main._step_intro(1.0 / 72.0)
	check(main.intro.start_ready, "the start button comes after a few seconds")
	main.on_start["right"] = true
	main.intro.leaving = 0.0
	main._press("right", "trigger")
	for i in 40:
		main._step_intro(1.0 / 72.0)
	check(not main.intro.active and main.stage.visible, "pressing start brings the court")
	main.set_menu(true, "modes")
	check(main.menu.visible and main.state == "menu", "the menu opens on the mode cards")
	var hoop_i := -1
	for i in main.menu.buttons.size():
		if main.menu.buttons[i].kind == "mode" and main.menu.buttons[i].id == "hoop":
			hoop_i = i
	main._menu_action(hoop_i)
	check(main.runtime.mode == "hoop" and main.stage is HoopStage and not main.menu.visible, "a mode card switches to that mode")
	var back: Vector3 = main.game_root.global_transform * Vector3(0, 0, main.stage.aim_z)
	check(back.z < -9.0, "and the hoop stands as far as the cans (%.1f)" % back.z)
	main.set_menu(true, "play")
	for i in main.menu.buttons.size():
		if main.menu.buttons[i].kind == "throw" and main.menu.buttons[i].id == "hand":
			main._menu_action(i)
	check(Save.throw_style == "hand", "the play page picks the throw style")
	Save.throw_style = "trigger"
	main.set_menu(false)
	main._choose_mode("mole")
	check(main.stage is MoleStage and main.runtime.mode == "mole", "the mole card starts Whack-a-Dahrooj")
	main._choose_mode("invasion")
	var back_inv: Vector3 = main.game_root.global_transform * Vector3(0, 0, main.stage.aim_z)
	check(main.stage is InvasionStage and main.runtime.mode == "invasion" and back_inv.z > -6.0 and back_inv.z < -4.0, "the invasion card starts Dahrooj Attack, the player near the court (%.1f)" % back_inv.z)
	main._choose_mode("maze")
	main._step_table(1.0 / 72.0)
	check(main.table is TabletopStage and main.table.visible and not main.stage.visible, "the maze card brings the tabletop board")
	main._choose_mode("climb")
	main._step_summit(1.0 / 72.0)
	check(main.summit_on and main.summit.visible and not main.stage.visible, "the climb card starts the Summit")
	main._choose_mode("meteor")
	check(main.stage is MeteorStage and main.stage.get("planes_provider").is_valid(), "the meteor mode starts with the room provider")
	main._choose_mode("giant")
	check(main.stage is GiantStage and main.stage.get("planes_provider").is_valid(), "the giant mode starts with the room provider")
	main._choose_mode("frenzy")
	check(main.stage is FrenzyStage and main.stage.get("planes_provider").is_valid(), "the frenzy mode starts with the room provider")
	main._choose_mode("castle")
	check(main.stage is CastleStage and main.stage.get("planes_provider").is_valid(), "the castle mode starts with the room provider")
	main._choose_mode("gallery")
	check(main.stage is GalleryStage and main.stage.get("planes_provider").is_valid(), "the gallery mode starts with the room provider")
	main._choose_mode("slime")
	check(main.stage is SlimeStage, "the slime card starts Slime")
	main._choose_mode("goal")
	check(not main.summit_on, "leaving the Summit for a mode")
	check(main.table == null and main.stage.visible, "and a throwing mode puts it away")
	main.ball.respawn()
	main.holder = ""
	main._press("left", "trigger")
	check(main.holder == "", "the trigger fires, it does not grab")
	main._press("left", "grip")
	check(main.holder == "left", "either grip holds Dahrooj")
	main._release("left", true)
	main.place_hint.build("ثبّت الملعب", "وجّه على سطح واضغط الزناد · العصا تكبّر وتصغّر", [])
	check(main.place_hint is Panel3D and main.place_hint.height > 0.0, "the MR pin hint is the menus' glass panel")
	main.ar_zoom = 1.0
	main.anchor_from(Vector3(0, 0.7, -1), Vector3.UP)
	check(main.ar_scale == 16.0, "MR: a table gets the smaller court (1/16)")
	main.anchor_from(Vector3(0, 0, -1.5), Vector3.UP)
	check(main.ar_scale == 8.0, "MR: the floor the usual one (1/8)")
	await get_tree().process_frame


func _scene() -> void:
	await get_tree().process_frame  # the tree must finish setting up before adding the game
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	for i in 30:
		await get_tree().process_frame
	var park: Park = main.park
	check(park.depth(-22, -5) > 0.0, "the pond is water in the middle")
	check(park.depth(0, -10) == 0.0, "the court is dry")
	check(park.get_node_or_null("Grass") != null and park.get_node_or_null("Foliage0") != null, "the park has grass and trees")
	check(main.stage is GoalStage, "the goal stands on the court")
	var before: Vector3 = main.game_root.global_transform * Vector3(0, 0, main.stage.aim_z)
	check(before.z < -9.0 and before.z > -12.0, "VR: the goal is about 10 m ahead (%.1f)" % before.z)
	main.set_mode("mr")
	var after: Vector3 = main.game_root.global_transform * Vector3(0, 0, main.stage.aim_z)
	check(absf(after.length() - 1.6) < 0.3 and main.scale_now == 8.0, "MR: the goal on the floor 1.6 m ahead, 1/8 size")
	main._show_start()
	check(main.panel.visible and main.panel.rows.size() == 3, "start screen offers mixed reality, VR and the language")
	main._panel_action("vr")
	check(main.state == "play" and main.mode == "vr", "choosing VR starts the game")
	await _world(main)
	_room_play(main)
	_reward_cards(main)
	await _roomscale(main)
	main.queue_free()
	await get_tree().process_frame


## Mixed reality all around the room (main.gd room_play): the arcade modes take RoomSpots
## around the player (the scan, or a ring without one), room-sized targets, the game's ground on
## the floor, a chevron toward a new target behind; VR gives them nothing (their old layouts).
func _room_play(main: Node) -> void:
	main.set_mode("mr")
	main._choose_mode("mole")
	main.state = "play"
	check(main.room_play() and main.scale_now == 8.0, "MR room play: whack-a-Dahrooj is played all around the room")
	var sps: Array = RoomSpots.ask(main.stage.spots_provider)
	check(not sps.is_empty() and sps.all(func(s: Dictionary) -> bool: return not s.room), "MR room play: no scan, a ring around the player")
	var surf: SceneSurfaces = main.surfaces
	var h: Vector3 = main.head_transform().origin
	var c := Vector3(h.x, 0, h.z)
	surf.add_test_plane(Transform3D(Basis(), c + Vector3(0, 1.25, -3.0)), Vector2(4.0, 2.5), "wall")
	surf.add_test_plane(Transform3D(Basis(Vector3.UP, PI), c + Vector3(0, 1.25, 2.0)), Vector2(4.0, 2.5), "wall")
	surf.add_test_plane(Transform3D(Basis(Vector3.UP, PI / 2.0), c + Vector3(-2.0, 1.25, -0.5)), Vector2(5.0, 2.5), "wall")
	surf.add_test_plane(Transform3D(Basis(Vector3.UP, -PI / 2.0), c + Vector3(2.0, 1.25, -0.5)), Vector2(5.0, 2.5), "wall")
	surf.add_test_plane(Transform3D(Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP), c + Vector3(0, 0, -0.5)), Vector2(4.0, 5.0), "floor")
	surf.add_test_box(Transform3D(Basis(), c + Vector3(1.4, 0.37, -2.2)), Vector3(0.9, 0.74, 0.6), "table")
	main._refresh_room_spots(true)
	var rs: RoomSpots = main.room_spots
	sps = RoomSpots.ask(main.stage.spots_provider)
	var tops := rs.spots.filter(func(s: Dictionary) -> bool: return s.kind == "top")
	check(rs.has_room() and not tops.is_empty() and not sps.is_empty() and sps.all(func(s: Dictionary) -> bool: return s.room), "MR room play: the scanned walls, floor and the table's top (%d spots)" % rs.spots.size())
	var secs := {}
	for k in 40:
		for s: Dictionary in RoomSpots.ask(main.stage.spots_provider):
			secs[RoomSpots.sector_of(main.eye_game(), s.pos)] = true
	check(secs.size() >= 9, "MR room play: from every side of the player (%d sectors)" % secs.size())
	check(absf(MoleStage.R * float(main.stage.size) / main.scale_now - 0.1) < 1e-3, "MR room play: a mole 20 cm across in the room")
	main._choose_mode("meteor")
	check(main.room_play() and absf(0.85 * float(main.stage.size) / main.scale_now - 0.15) < 1e-3 and main.stage.spots_provider.is_valid(), "MR room play: meteors room-sized, from the room's spots")
	# Pinned on a table: the game's ground stays the floor, at the room scale.
	main.anchor = main.anchor_from(Vector3(c.x, 0.7, c.z - 1.0), Vector3.UP)
	main.place()
	var ground: Vector3 = main.game_root.global_transform * Vector3.ZERO
	check(main.ar_scale == 16.0 and main.scale_now == 8.0 and absf(ground.y) < 1e-4, "MR room play: pinned on a table, the ground is still the floor (y %.2f)" % ground.y)
	# VR: no room spots, the usual sizes.
	main.set_mode("vr")
	main._step_room_play(1.0 / 72.0)
	check(not main.room_play() and RoomSpots.ask(main.stage.spots_provider).is_empty() and float(main.stage.size) == 1.0,
		"VR: no room spots, the modes keep their layouts")
	surf.clear_tests()
	main._choose_mode("goal")


## The reward watch (main.gd _watch_rewards): a card «فتحت طلقة …!» with the chime and
## confetti when a challenge opens a shot, and for an accessory too.
func _reward_cards(main: Node) -> void:
	var keep: Dictionary = Save.challenges.duplicate(true)
	var toast: ToastCard = main.toast
	Save.challenges.clear()
	main._known_rewards = {}
	main._reward_check = 0.0
	main._watch_rewards(1.0)
	toast.cards.clear()
	var conf: Confetti = main.confetti
	var c0 := conf.active_count()
	Save.challenges["hoop3"] = 3
	main._reward_check = 0.0
	main._watch_rewards(1.0)
	var shot_card := toast.cards.any(func(n: Dictionary) -> bool: return n.kind == "reward" and n.title == Save.text("فتحت طلقة قصاصات!", "Unlocked shot Confetti!"))
	check(shot_card and toast.cards.size() == 1 and conf.active_count() > c0, "rewards: a shot that opens gets its card («فتحت طلقة قصاصات!») and confetti")
	Save.challenges["keeper3"] = 3
	main._reward_check = 0.0
	main._watch_rewards(1.0)
	check(toast.cards.size() == 2 and toast.cards[1].title == Save.text("فتحت قبعة حفلة!", "Party hat unlocked!"), "rewards: and an accessory its own card")
	main._reward_check = 0.0
	main._watch_rewards(1.0)
	check(toast.cards.size() == 2, "rewards: each card once")
	toast.cards.clear()
	Save.challenges.clear()
	Save.challenges.merge(keep)


## Roomscale (Stage space): the headset's origin is the middle of the play area, so the VR court
## is set around wherever the player stands and faces, then stays put while they walk; recenter
## and a new mode set it again. The desktop camera stands in for the head.
func _roomscale(main: Node) -> void:
	main.set_mode("vr")
	main._choose_mode("goal")
	main.state = "play"
	var cam: Camera3D = main.desktop_cam
	var keep := cam.global_transform
	# Start of play: the player 1.5 m to the side of the play area's middle, turned 50 degrees.
	cam.global_transform = Transform3D(Basis(Vector3.UP, 0.87), Vector3(1.5, 1.6, -0.7))
	var fwd := Vector3(-sin(0.87), 0.0, -cos(0.87))
	main.set_mode("vr")
	var head: Vector3 = cam.global_position
	var floor_head := Vector3(head.x, 0.0, head.z)
	var gr: Transform3D = main.game_root.global_transform
	var goal: Vector3 = gr * Vector3(0, 0, main.stage.aim_z)
	var to_goal := Vector3(goal.x - head.x, 0.0, goal.z - head.z)
	check(to_goal.normalized().dot(fwd) > 0.999 and to_goal.length() > 9.0 and to_goal.length() < 12.0,
		"roomscale VR: the court is set around the head off the middle, the goal %.1f m the way it faces" % to_goal.length())
	var spot: Vector3 = gr * Vector3(0, 0, main._rig_game_z)
	check(spot.distance_to(floor_head) < 1e-3, "roomscale VR: the throw spot is on the floor under the head (%s)" % spot)
	var eye: Vector3 = main.eye_game()
	check(absf(eye.x) < 1e-3 and absf(eye.z - main._rig_game_z) < 1e-3, "roomscale VR: in game units the player stands at the throw spot (%s)" % eye)
	var park_c: Vector3 = main.park.global_transform * Vector3(0, 0, main.stage.aim_z)
	check(park_c.distance_to(goal) < 1e-3, "roomscale VR: the park moves with the court")
	check((main.hud.global_position - head).dot(fwd) > 3.0, "roomscale VR: the score board ahead of the player")
	check(absf(main.env.sky_rotation.y - 0.87) < 1e-3, "roomscale VR: the sky turns with the park (%.2f)" % main.env.sky_rotation.y)
	# Walking: the court stays put in the room, the goal comes closer.
	var fixed: Transform3D = main.game_root.global_transform
	cam.global_transform = Transform3D(Basis(Vector3.UP, 0.3), head + fwd * 2.0 + Vector3(0.4, 0, 0))
	for i in 5:
		await get_tree().process_frame
	main.place()
	var walked: Vector3 = cam.global_position
	var near := Vector2(goal.x - walked.x, goal.z - walked.z).length()
	check(main.game_root.global_transform.is_equal_approx(fixed) and near < to_goal.length() - 1.5,
		"roomscale VR: walking toward the goal keeps the court fixed and brings it closer (%.1f m)" % near)
	# The system recenter: set again around where the player is now, facing their new way.
	var fwd2 := Vector3(-sin(0.3), 0.0, -cos(0.3))
	main._on_recenter()
	goal = main.game_root.global_transform * Vector3(0, 0, main.stage.aim_z)
	var to_goal2 := Vector3(goal.x - walked.x, 0.0, goal.z - walked.z)
	check(not main.game_root.global_transform.is_equal_approx(fixed) and to_goal2.normalized().dot(fwd2) > 0.999
		and absf(to_goal2.length() - to_goal.length()) < 1e-3, "roomscale VR: recenter sets the court in front of the player again")
	# A new mode: set around the player too; the Summit faces them.
	cam.global_transform = Transform3D(Basis(Vector3.UP, -1.2), Vector3(-1.0, 1.6, 0.9))
	var fwd3 := Vector3(-sin(-1.2), 0.0, -cos(-1.2))
	main._choose_mode("hoop")
	goal = main.game_root.global_transform * Vector3(0, 0, main.stage.aim_z)
	check(Vector3(goal.x + 1.0, 0.0, goal.z - 0.9).normalized().dot(fwd3) > 0.999, "roomscale VR: a new mode is set where the player stands")
	main._choose_mode("climb")
	var to_sum: Vector3 = main.summit.position - Vector3(-1.0, 0.0, 0.9)
	check(Vector3(to_sum.x, 0.0, to_sum.z).normalized().dot(fwd3) > 0.999 and absf(main.summit.rotation.y + 1.2) < 1e-3,
		"roomscale VR: the Summit ahead of the player, facing them")
	# MR: the court 1.6 m ahead of the head, wherever it is.
	main.set_mode("mr")
	var mr_goal: Vector3 = main.anchor.p
	check(Vector3(mr_goal.x + 1.0, 0.0, mr_goal.z - 0.9).distance_to(fwd3 * 1.6) < 1e-3, "roomscale MR: the court 1.6 m ahead of the player off the middle")
	main.set_mode("vr")
	cam.global_transform = keep
	main.replace_here()
	main._choose_mode("goal")
