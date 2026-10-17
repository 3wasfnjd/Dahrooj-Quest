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
	var keep_state: String = main.state
	main.state = "play"
	main._on_menu()
	main._on_button("left", "ax", true)
	main._on_button("left", "by", true)
	check(not main.menu.visible, "the opening: the menu, challenges and look stay shut until play starts")
	main.state = keep_state
	for i in 72 * 4:
		main._step_intro(1.0 / 72.0)
	check(main.intro.start_ready, "the start button comes after a moment")
	# A start page only: the trigger anywhere but on its buttons fires nothing.
	wb.clear_blast()
	main.auto_fire.clear()
	main.on_start["right"] = ""
	main._press("right", "trigger")
	check(wb.shots.is_empty() and main.auto_fire.is_empty() and main.intro.active, "the opening: the trigger off the panel does not shoot")
	main.on_start["right"] = "play"
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
	# "Play all 3 styles": throwing Dahrooj in each style counts (not only blaster shots).
	var keep_throw: String = Save.throw_style
	var keep_style: String = Save.style
	Save.throw_style = "trigger"
	Save.styles_used.clear()
	Save.challenges.erase("styles5")
	for st: Array in MenuCatalog.STYLES:
		Save.style = st[0]
		main.ball.respawn()
		main.holder = ""
		main._press("left", "grip")
		main._release("left", false)
	check(int(Save.challenges.get("styles5", 0)) == 3, "three styles: a throw in each completes the challenge (%d)" % int(Save.challenges.get("styles5", 0)))
	Save.throw_style = keep_throw
	Save.style = keep_style
	main.ball.respawn()
	main.holder = ""
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
	# The texts' order in view: challenge card on top, then the HUD's score, then round banners.
	var eye: Vector3 = main.head_transform().origin
	var hp: Vector3 = main.hud.global_position - eye
	var hud_up := rad_to_deg(atan2(hp.y, Vector2(hp.x, hp.z).length()))
	main.toast.show_text("✓ test")
	for i in 30:
		main.toast.place(main.head_transform())
		main.toast.step(1.0 / 30.0)
	var tp: Vector3 = main.toast.global_position - eye
	var toast_up := rad_to_deg(atan2(tp.y, Vector2(tp.x, tp.z).length()))
	check(absf(hud_up - 18.5) < 1.0 and toast_up < -12.0,
		"VR texts: the score %.1f° above the eye line, the challenge card low below the gaze (%.1f°)" % [hud_up, toast_up])
	main.set_mode("mr")
	var after: Vector3 = main.game_root.global_transform * Vector3(0, 0, main.stage.aim_z)
	check(absf(after.length() - 1.6) < 0.3 and main.scale_now == 8.0, "MR: the goal on the floor 1.6 m ahead, 1/8 size")
	# No separate start screen: straight into the opening, whose start panel has the view and
	# the language as icons above Play.
	Save.mode = "vr"
	main._start_game()
	check(main.state == "play" and main.mode == "vr" and main.intro.active and not main.panel.visible,
		"after the splash: straight into the opening, in the saved view")
	check(main.intro.view_mode == "vr" and main.intro.START_ITEMS.has("mr") and main.intro.START_ITEMS.has("lang")
		and (main.intro.START_ITEMS.mr as Rect2).end.y < (main.intro.START_ITEMS.play as Rect2).position.y,
		"the start panel: mixed reality, VR and language icons above Play")
	main.on_start["right"] = "mr"
	main._press("right", "trigger")
	check(main.mode == "mr" and Save.mode == "mr" and main.intro.view_mode == "mr" and main.intro.active, "its MR icon switches the view (the opening goes on)")
	main.on_start["right"] = "vr"
	main._press("right", "trigger")
	check(main.mode == "vr" and Save.mode == "vr", "and its VR icon back")
	var lang_was := Save.language
	main.on_start["right"] = "lang"
	main._press("right", "trigger")
	check(Save.language != lang_was, "its language icon switches the language")
	Save.language = lang_was
	main.on_start["right"] = ""
	main.intro.clear()
	main.stage.visible = true
	# Launch: dark until the session is up, then a fresh start in the saved view (it used to
	# open in VR, build the stage for VR, then switch to mixed reality with that stage).
	var boot_stage: Node3D = main.stage
	main._boot_dark()
	check(not main.park.visible and not main.stage.visible and main.env.background_mode == Environment.BG_COLOR, "launch: dark until the headset session is up (no VR park flash)")
	Save.mode = "mr"
	main._start_game()
	await get_tree().process_frame
	check(main.mode == "mr" and main.stage != boot_stage and not is_instance_valid(boot_stage) and main.intro.active and not main.park.visible,
		"launch: starts fresh in the saved view (mixed reality: stage built for it, start page)")
	main.restart_in_view("vr")
	await get_tree().process_frame
	main.intro.clear()
	main.state = "play"
	main._choose_mode("goal")
	# Switching the view mid-game starts over: the stage is built again for the new view.
	main._choose_mode("meteor")
	main.state = "play"
	var vr_stage: Node3D = main.stage
	main.restart_in_view("mr")
	await get_tree().process_frame
	check(main.mode == "mr" and Save.mode == "mr" and main.stage != vr_stage and not is_instance_valid(vr_stage)
		and main.runtime.mode == "meteor" and main.intro.active and not main.stage.visible and main.world_balls.rests.is_empty(),
		"view switch: a fresh start (new meteor stage for MR, back on the start page)")
	main.restart_in_view("vr")
	await get_tree().process_frame
	main.intro.clear()
	main.state = "play"
	main._choose_mode("goal")
	# The menu's World page: the same switch, as two icon cards.
	main.state = "play"
	main.set_menu(true, "world")
	var view_i := -1
	for i in main.menu.buttons.size():
		if main.menu.buttons[i].kind == "view" and main.menu.buttons[i].id == "mr":
			view_i = i
	check(view_i >= 0, "the World page has the mixed reality / VR cards")
	main._menu_action(view_i)
	check(main.mode == "mr" and not main.menu.visible and main.intro.active, "World page: mixed reality starts over in that view and closes the menu")
	main.intro.clear()
	main.stage.visible = true
	main.state = "play"
	main.set_menu(true, "world")
	for i in main.menu.buttons.size():
		if main.menu.buttons[i].kind == "view" and main.menu.buttons[i].id == "vr":
			view_i = i
	main._menu_action(view_i)
	check(main.mode == "vr" and Save.mode == "vr", "and VR back")
	main.intro.clear()
	main.state = "play"
	main._choose_mode("goal")
	await _world(main)
	_summit_buttons(main)
	_ab_buttons(main)
	await _rain_mode(main)
	await _room_play(main)
	_reward_cards(main)
	await _roomscale(main)
	await _golden_scene(main)
	await _challenge_cards(main)
	var keep_finale := _save_keep()
	load("res://tests/stage_finale_test.gd").call("scene", main, check)
	_save_restore(keep_finale)
	main.queue_free()
	await get_tree().process_frame


## The Summit's buttons: right A jumps, a trigger (either hand) throws and holding it keeps
## throwing, the grips do nothing there; A and B do nothing in the other modes.
func _summit_buttons(main: Node) -> void:
	main._choose_mode("climb")
	main.state = "play"
	main.placing = false
	main._step_summit(1.0 / 72.0)
	var s: Dictionary = main.summit.state
	var calm := func() -> void:
		s.input.buffer = 0.0
		s.shots.clear()
		s.ball.cool = 0.0
	calm.call()
	main._on_button("left", "grip", true)
	main._on_button("right", "grip", true)
	main._on_button("left", "grip", false)
	main._on_button("right", "grip", false)
	check(main.summit_on and float(s.input.buffer) == 0.0 and s.shots.is_empty() and main.holder == "", "summit: the grips no longer jump or throw")
	main._on_button("right", "ax", true)
	main._on_button("right", "ax", false)
	check(float(s.input.buffer) > 0.0 and s.shots.is_empty(), "summit: A jumps")
	calm.call()
	main._on_button("right", "trigger", true)
	check(s.shots.size() == 1 and float(s.input.buffer) == 0.0 and main.summit_throw_at > 0.0 and main.auto_fire.is_empty(), "summit: the right trigger throws (no shots)")
	main._on_button("right", "trigger", false)
	check(main.summit_throw_at < 0.0, "summit: letting go of the trigger stops throwing")
	calm.call()
	main._on_button("left", "trigger", true)
	main._on_button("left", "trigger", false)
	check(s.shots.size() == 1, "summit: the left trigger throws too")
	main._on_button("right", "by", true)
	main._on_button("right", "by", false)
	check(float(s.input.buffer) == 0.0, "summit: B does nothing")
	main._choose_mode("goal")
	main.state = "play"
	calm.call()
	var shot0: String = Save.shot_style
	main._on_button("right", "ax", true)
	main._on_button("right", "ax", false)
	check(not main.summit_on and float(s.input.buffer) == 0.0 and main.holder == "" and main.state == "play" and Save.shot_style != shot0,
		"outside the Summit A no longer jumps (it picks the next shot)")
	Save.shot_style = shot0


## Mixed reality out in the room (main.gd room_play): the arcade modes take RoomSpots in front
## of the player (±70° of the court's forward, 2 m away or more: the scan, or an arc ahead
## without one), room-sized targets, the game's ground on the floor; the giant stands where the
## court is pinned and a new pin moves him; VR gives them nothing (their old layouts).
func _room_play(main: Node) -> void:
	main.set_mode("mr")
	# Shrinking or growing the scene while pinning keeps targets and shots in proportion.
	var ratios: Array = []
	var scales: Array = []
	for z in [1.0, 0.5]:
		main.ar_zoom = z
		main._choose_mode("meteor")
		main._setup_stage()
		var meteor_m: float = float(main.stage.size) * 0.85 / main.scale_now
		var shot_m: float = main.world_balls.blast_k() / main.scale_now
		ratios.append(meteor_m / shot_m)
		scales.append(main.scale_now)
	main.ar_zoom = 1.0
	main._setup_stage()
	check(absf(float(ratios[0]) - float(ratios[1])) < 1e-3, "MR zoom: meteors and shots shrink together (%s)" % [ratios])
	check(scales[0] == scales[1], "MR zoom: the room stays the room's size, only the Dahroojs shrink (%s)" % [scales])
	main._choose_mode("mole")
	main.state = "play"
	check(main.room_play() and main.scale_now == 8.0, "MR room play: whack-a-Dahrooj is played out in the room")
	var sps: Array = RoomSpots.ask(main.stage.spots_provider)
	check(not sps.is_empty() and sps.all(func(s: Dictionary) -> bool: return not s.room), "MR room play: no scan, an arc ahead of the player")
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
	var front := true
	var eg: Vector3 = main.eye_game()
	for k in 40:
		for s: Dictionary in RoomSpots.ask(main.stage.spots_provider):
			secs[RoomSpots.sector_of(eg, s.pos)] = true
			var d := Vector2((s.pos as Vector3).x - eg.x, (s.pos as Vector3).z - eg.z)
			if d.length() < RoomSpots.MIN_DIST * main.scale_now - 1e-3 or absf(Vector2(0, -1).angle_to(d)) > deg_to_rad(70.0) + 1e-3:
				front = false
	check(front and secs.size() >= 3, "MR room play: only in front of the player, 2 m away or more, never behind (%d sectors)" % secs.size())
	check((main.play_forward() as Vector3).is_equal_approx(Vector3.FORWARD) and main.room_spots.forward.is_equal_approx(Vector3.FORWARD), "MR room play: the play direction is the court's forward")
	# A sofa against the far wall too: the invaders go round the furniture and the waves keep coming.
	surf.add_test_box(Transform3D(Basis(), c + Vector3(-0.6, 0.4, -2.55)), Vector3(1.8, 0.8, 0.9), "couch")
	main._refresh_room_spots(true)
	main._choose_mode("invasion")
	main.state = "play"
	var invs: InvasionStage = main.stage
	var in_box := 0
	for i in 72 * 40:
		main._game_step(1.0 / 72.0)
		for m in invs.invaders:
			if m.on and m.phase == "march" and float(m.stuck_t) < InvasionStage.STUCK_T:
				var w: Vector3 = main.game_root.global_transform * Vector3(m.p.x, m.r, m.p.z)
				for bx in surf.boxes():
					var l: Vector3 = (bx.xform as Transform3D).affine_inverse() * w
					if absf(l.x) < bx.size.x * 0.5 - 0.01 and absf(l.z) < bx.size.z * 0.5 - 0.01 and absf(l.y) < bx.size.y * 0.5:
						in_box += 1
	check(int(invs.F.wave) >= 4 and in_box == 0, "MR invasion: with a sofa and a table the waves keep coming (wave %d) and nobody walks through them (%d)" % [invs.F.wave, in_box])
	main.state = "menu"
	for k in 40:  # let the waves' confetti and cards settle before the next checks
		main.confetti.step(0.5)
		main.toast.step(0.5)
	await _giant_pin(main, c)
	check(absf(MoleStage.R * float(main.stage.size) / main.scale_now - main.MR_DAHROOJ_R) < 1e-3, "MR room play: a mole the one natural Dahrooj size")
	main._choose_mode("meteor")
	check(main.room_play() and absf(0.85 * float(main.stage.size) / main.scale_now - main.MR_DAHROOJ_R * 1.3) < 1e-3 and main.stage.spots_provider.is_valid(), "MR room play: meteors the natural Dahrooj size (with their fire), from the room's spots")
	# The same natural size in every room mode, the rain too, and the pinning preview shows it.
	var sizes := {}
	main._choose_mode("gallery")
	sizes["gallery"] = GalleryStage.R * float(main.stage.size) / main.scale_now
	main._choose_mode("mole")
	sizes["mole"] = MoleStage.R * float(main.stage.size) / main.scale_now
	main._choose_mode("meteor")
	check(sizes.values().all(func(v: float) -> bool: return absf(v - main.MR_DAHROOJ_R) < 1e-3) and absf(main.preview_radius() - main.MR_DAHROOJ_R * main.ar_zoom) < 1e-4,
		"MR: one natural Dahrooj size across room modes, shown by the pinning preview (%s)" % [sizes])
	# The pace does not change with the pinning zoom.
	var k1: float = main.time_k()
	main.ar_zoom = 0.4
	main.place()
	var k2: float = main.time_k()
	main.ar_zoom = 1.0
	main.place()
	check(absf(k1 - k2) < 1e-4, "MR: shrinking the scene does not speed the game up (%.3f / %.3f)" % [k1, k2])
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


## The giant in mixed reality: he stands where the court is pinned (on the line from the
## player through the reticle's spot, his near side 2 m away or more), and pinning somewhere
## else moves him there; in VR he stands on the court far ahead.
func _giant_pin(main: Node, c: Vector3) -> void:
	main._choose_mode("giant")
	main.state = "play"
	main.placing = false
	var head: Vector3 = main.head_transform().origin
	var giant_at := func() -> Vector3:
		return main.game_root.global_transform * (main.stage.room.home as Vector3)
	# On the line from the player through the pin, inside the scanned room (4 x 5 m around c)
	# with his whole body, his near side 1.2 m away at the least (2 m when the room allows).
	var on_ray := func(at: Vector3, pin: Vector3) -> bool:
		var a := Vector2(at.x - head.x, at.z - head.z)
		var b := Vector2(pin.x - head.x, pin.z - head.z)
		var r_m: float = float(main.stage.room.r) / main.scale_now
		var inside := absf(at.x - c.x) <= 2.0 - r_m + 1e-3 and at.z - c.z >= -3.0 + r_m - 1e-3 and at.z - c.z <= 2.0 - r_m + 1e-3
		return absf(a.angle_to(b)) < deg_to_rad(3.0) and inside and a.length() - r_m >= GiantStage.NEAR_MIN - 0.02
	var pins := [c + Vector3(0.3, 0, -1.4), c + Vector3(1.3, 0, -1.1)]
	var at: Array = []
	for pin: Vector3 in pins:
		main.placing = true
		main.anchor = main.anchor_from(pin, Vector3.UP)
		main.place()
		main.placing = false
		main._setup_stage()
		main.stage.paused = false
		for k in 3:
			main.stage.update(main.ball, 1.0 / 72.0)
		var g: Vector3 = giant_at.call()
		at.append(g)
		check(main.room_play() and on_ray.call(g, pin), "MR giant: pinned at %s, he stands on the line through the pin, ahead, inside the room (%s, r %.2f m)" % [pin, g, float(main.stage.room.r) / main.scale_now])
	check((at[0] as Vector3).distance_to(at[1]) > 0.5, "MR giant: pinning elsewhere moves him (%.2f m)" % (at[0] as Vector3).distance_to(at[1]))
	# Mid-fight: a new pin carries him (and his ring) along.
	main.stage.F.state = "fight"
	var ring0: Vector3 = main.game_root.global_transform * main.stage._ring_c
	main.anchor = main.anchor_from(pins[0], Vector3.UP)
	main.place()
	main._setup_stage()
	var g2: Vector3 = main.game_root.global_transform * (main.stage.giant.g as Vector3)
	var ring1: Vector3 = main.game_root.global_transform * main.stage._ring_c
	check(on_ray.call(g2, pins[0]) and ring1.distance_to(ring0) > 0.5, "MR giant: re-pinned mid-fight, he and his level ring go to the new spot")
	main.set_mode("vr")
	main._choose_mode("giant")
	main.stage.paused = false
	for k in 3:
		main.stage.update(main.ball, 1.0 / 72.0)
	var vh: Transform3D = main.head_transform()
	var vf := -vh.basis.z
	vf.y = 0.0
	var gv: Vector3 = giant_at.call()
	check((gv - vh.origin).dot(vf.normalized()) > 6.0, "VR giant: on the court, far ahead of the player (%.1f m)" % (gv - vh.origin).dot(vf.normalized()))
	main.set_mode("mr")
	main._choose_mode("mole")
	main.state = "play"
	await get_tree().process_frame


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


## Keeps the save (file and memory) around a scene test that changes progress.
func _save_keep() -> Dictionary:
	var path: String = Save.PATH
	return {"had": FileAccess.file_exists(path), "file": FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "",
		"ch": Save.challenges.duplicate(true), "rec": Save.records.duplicate(true), "total": Save.total_score, "acc": Save.accessory}


func _save_restore(k: Dictionary) -> void:
	Save.challenges.clear()
	Save.challenges.merge(k.ch)
	Save.records.clear()
	Save.records.merge(k.rec)
	Save.total_score = int(k.total)
	Save.accessory = str(k.acc)
	if bool(k.had):
		var f := FileAccess.open(Save.PATH, FileAccess.WRITE)
		f.store_string(str(k.file))
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.PATH))


func _juice_texts(main: Node) -> Array:
	var out: Array = []
	for it: JuiceText in JuiceText.showing(main.fx):
		out.append(it.text)
	return out


## The Golden Dahrooj in the real scene: he turns up ahead in VR and in the room, a blaster shot
## and a thrown Dahrooj catch him (+500, the gold banner, the ching, confetti), never in
## Whack-a-Dahrooj; a beaten record gets its rainbow banner; the reset keeps the records; an
## attack takes points with its red flash and the score sinking.
func _golden_scene(main: Node) -> void:
	var keep := _save_keep()
	var g: GoldenDahrooj = main.golden
	main.set_mode("vr")
	main._choose_mode("meteor")
	main.state = "play"
	main.stage.paused = true
	g.wait = 0.0
	main._step_golden(1.0 / 72.0)
	var eye: Vector3 = main.eye_game()
	var u: float = main.scale_now
	var d_m := Vector2(g.pos.x - eye.x, g.pos.z - eye.z).length() / u
	check(g.active and RoomSpots.ahead(eye, g.pos, RoomSpots.MIN_DIST * u, main.play_forward()) and d_m >= 2.5,
		"golden VR: he turns up in front of the player, %.1f m away" % d_m)
	# A blaster shot straight at him.
	var c0 := int(main.runtime.counts.get("meteor", 0))
	var caught0 := g.caught
	main.sounds_played.clear()
	main.world_balls.fire("right", eye, (g.pos - eye).normalized())
	for i in 90:
		main.world_balls.step_blast(1.0 / 72.0)
		if g.caught > caught0:
			break
	check(g.caught == caught0 + 1 and not g.active and int(main.runtime.counts.get("meteor", 0)) == c0 + 500, "golden VR: a blaster shot catches him: +500 (%d)" % (int(main.runtime.counts.get("meteor", 0)) - c0))
	var texts := _juice_texts(main)
	var names: Array = []
	for snd: Array in main.sounds_played:
		names.append(snd[0])
	check(Save.text("دحروج ذهبي! +٥٠٠", "Golden Dahrooj! +500") in texts and "fair_ding" in names and main.confetti.active_count() > 0 and int(Save.challenges.get("golden1", 0)) == 1,
		"golden VR: «دحروج ذهبي! +٥٠٠» in gold, the ching, confetti, golden1 counted %s" % [texts])
	# A thrown Dahrooj.
	main._choose_mode("goal")
	main.state = "play"
	g.wait = 0.0
	main._step_golden(1.0 / 72.0)
	var on_course := g.active
	var b: Ball = main.ball
	b.held = false
	b.shot = true
	b.pos = g.pos + Vector3(0, 0, g.radius())
	var goal0 := int(main.runtime.counts.get("goal", 0))
	main._step_golden(1.0 / 72.0)
	check(on_course and not g.active and int(main.runtime.counts.get("goal", 0)) == goal0 + 500, "golden: over the goal, a thrown Dahrooj catches him too (+500)")
	b.respawn()
	# Not in Whack-a-Dahrooj (its own golden moles), not on the Summit.
	main._choose_mode("mole")
	main.state = "play"
	g.wait = 0.0
	main._step_golden(1.0 / 72.0)
	var mole_none := not g.active
	main._choose_mode("climb")
	g.wait = 0.0
	main._step_golden(1.0 / 72.0)
	check(mole_none and not g.active, "golden: none in Whack-a-Dahrooj or on the Summit")
	# Mixed reality: out in the room, ahead, at room size.
	main.set_mode("mr")
	main._choose_mode("invasion")
	main.state = "play"
	main.placing = false
	main.stage.paused = true
	g.wait = 0.0
	main._step_golden(1.0 / 72.0)
	eye = main.eye_game()
	u = main.scale_now
	var r_m: float = g.radius() / u
	check(g.active and RoomSpots.ahead(eye, g.pos, RoomSpots.MIN_DIST * u, main.play_forward()) and absf(r_m - GoldenDahrooj.R_MR) < 1e-3,
		"golden MR: in the room ahead of the player, %.0f cm across" % (r_m * 200.0))
	g.escape()
	# Attacks: the score drops with the flash, the bump and the sinking score.
	main.runtime.counts["invasion"] = 120
	main.score_popup.observe("invasion", 120.0)
	main.sounds_played.clear()
	main.stage._breach(Vector3(0, 0, -2), "plain")
	main._step_hurt(0.01)
	main.score_popup.observe("invasion", float(main.runtime.counts.invasion))
	texts = _juice_texts(main)
	names.clear()
	for snd: Array in main.sounds_played:
		names.append(snd[0])
	check(int(main.runtime.counts.invasion) == 70 and main.hurt.visible and "-50" in texts and "thump" in names and main.score_popup.showing() and main.score_popup.value == 70 and main.score_popup.dropping,
		"attack: one through takes 50 (120 → 70): «-50», a red flash, a bump, the score sinks %s" % [texts])
	main._step_hurt(1.0)
	check(not main.hurt.visible, "attack: the flash fades")
	# A record beaten: the rainbow banner and fireworks, once.
	main.set_mode("vr")
	main._choose_mode("frenzy")
	main.state = "play"
	Save.records["frenzy"] = 50
	main.runtime._record_seen.erase("frenzy")
	main.runtime.counts["frenzy"] = 60
	main.sounds_played.clear()
	main.runtime.track_scores()
	texts = _juice_texts(main)
	names.clear()
	for snd: Array in main.sounds_played:
		names.append(snd[0])
	check(Save.text("رقم قياسي جديد!", "New record!") in texts and "firework_launch" in names and Save.record("frenzy") == 60, "record: beaten: «رقم قياسي جديد!», fireworks and a fanfare %s" % [texts])
	JuiceText.clear(main.fx)
	main.runtime.counts["frenzy"] = 90
	main.runtime.track_scores()
	check(_juice_texts(main).is_empty() and Save.record("frenzy") == 90, "record: once a session, then quietly kept up")
	# The menu shows it; resetting the challenges keeps the records.
	main.set_menu(true, "modes")
	var found := false
	for bt: Dictionary in main.menu.buttons:
		if bt.kind == "mode" and bt.id == "frenzy" and str(bt.best) == MenuPanel.best_text(90, Save.arabic()):
			found = true
	check(found, "record: the Pop Frenzy card shows its best (%s)" % MenuPanel.best_text(90, Save.arabic()))
	main.set_menu(true, "challenges")
	var reset_i := -1
	for i in main.menu.buttons.size():
		if main.menu.buttons[i].kind == "reset":
			reset_i = i
	main._menu_action(reset_i)
	main._menu_action(reset_i)
	check(reset_i >= 0 and Save.challenges.is_empty() and Save.record("frenzy") == 90, "record: resetting the challenges keeps the records")
	main.set_menu(false)
	main.toast.cards.clear()
	main.toast.now = {}
	JuiceText.clear(main.fx)
	_save_restore(keep)
	await get_tree().process_frame


## Challenge cards end to end in the real scene, VR and MR: completions from the runtime
## (ch_progress), quiet progress (a score), main.gd (modes played) and the Golden Dahrooj each
## show their challenge card on screen, in front of the eyes and over everything, followed
## by its reward card.
func _challenge_cards(main: Node) -> void:
	var keep := _save_keep()
	var toast: ToastCard = main.toast
	toast.auto_step = false
	var lang_ar := Save.arabic()
	for view: String in ["vr", "mr"]:
		main.set_mode(view)
		main._choose_mode("goal")
		main.state = "play"
		main.placing = false
		Save.challenges.clear()
		main.runtime.forget_scores()
		for m: String in main.runtime.counts:
			main.runtime.counts[m] = 0
		main.runtime.track_scores()
		toast.cards.clear()
		toast.now = {}
		main._known_rewards = {}
		main._reward_check = 0.0
		main._watch_rewards(1.0)
		var steps: Array = [
			["keeper3", func() -> void:
				for k in 3:
					main.runtime.add_count("goal", false)],
			["score1k", func() -> void:
				main.runtime.counts["meteor"] = 1000
				main.runtime.track_scores()],
			["modes5", func() -> void:
				for m: String in ["hoop", "window", "cans", "bowling", "fair"]:
					main._choose_mode(m)
				main.state = "play"],
			["golden1", func() -> void:
				main._choose_mode("meteor")
				main.state = "play"
				main.stage.paused = true
				main.golden.wait = 0.0
				main._step_golden(1.0 / 72.0)
				main.golden.catch("shot")],
		]
		for st: Array in steps:
			var id: String = st[0]
			var c := GameRuntime.challenge(id)
			var want_c: String = c[1] if lang_ar else c[2]
			var want_r: String = ChallengeRewards.card(ChallengeRewards.reward_of(id), lang_ar).title
			(st[1] as Callable).call()
			var seen: Array = []
			var placed := true
			var t := 0.0
			while t < 12.0:
				main._process(1.0 / 30.0)
				toast.step(1.0 / 30.0)
				t += 1.0 / 30.0
				if toast.visible and toast.opacity > 0.9 and not toast.now.is_empty():
					var key := "%s:%s" % [toast.now.kind, toast.now.title]
					if seen.is_empty() or seen[seen.size() - 1] != key:
						seen.append(key)
						var head: Transform3D = main.head_transform()
						var rel: Vector3 = head.affine_inverse() * toast.global_position
						placed = placed and rel.z < -0.6 and rel.z > -1.0 and rel.y < -0.15 and absf(rel.x) < 0.1  # below the gaze
						for l: Label3D in toast._labels:
							placed = placed and l.no_depth_test and not ("✓" in l.text)
				if t > 1.0 and toast.now.is_empty() and toast.cards.is_empty() and seen.has("reward:" + want_r):
					break
			var ci := seen.find("challenge:" + want_c)
			var ri := seen.find("reward:" + want_r)
			check(ci >= 0 and ri > ci and placed, "%s cards: «%s» shows on screen, then its reward «%s» (%s)" % [view.to_upper(), want_c, want_r, seen])
	check(ToastCard.CARD_SHADER.contains("depth_test_disabled"), "cards: the card draws over the room and the court")
	# Many at once: every challenge card waits its turn (none dropped).
	toast.cards.clear()
	toast.now = {}
	for i in 7:
		toast.show_text("✓ title %d" % i)
		toast.notify("reward", "reward %d" % i)
	toast.show_text("✓ title 0")
	check(toast.cards.size() == 15, "cards: seven challenges at once keep all their cards (%d)" % toast.cards.size())
	toast.cards.clear()
	toast.now = {}
	toast.auto_step = true
	main._choose_mode("goal")
	_save_restore(keep)
	await get_tree().process_frame


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


## Right A and B in play: A steps to the next shot style the challenges have opened and B to
## the next accessory ("none" among them), both wrapping round and skipping locked ones; the
## pick shows its icon and name by the hand with a click. The Summit keeps A for its jump (B
## does nothing there); ricochet's A picks the next paddle.
func _ab_buttons(main: Node) -> void:
	var keep := _save_keep()
	var shot0: String = Save.shot_style
	main._choose_mode("goal")
	main.state = "play"
	main.placing = false
	Save.challenges.clear()
	Save.shot_style = "bolt"
	Save.accessory = ""
	var press := func(name: String) -> void:
		main._on_button("right", name, true)
		main._on_button("right", name, false)
	var seen: Array = []
	main.sounds_played.clear()
	for i in 5:
		press.call("ax")
		seen.append(Save.shot_style)
	check(seen == ["mini", "bubble", "firework", "bolt", "mini"], "A: the next open shot style, locked ones skipped, wrapping round (%s)" % [seen])
	check(main.quick_pick.icon_line.visible and main.quick_pick.last_icon == "mini" and main.quick_pick.last_text == Save.text("دحروج", "Dahrooj")
		and not JuiceText.showing(main.quick_pick).is_empty() and main.sounds_played.any(func(e): return e[0] == "bricks_tink"),
		"A: the pick's icon and name by the hand, and a click (%s)" % main.quick_pick.last_text)
	Save.challenges["shot:rocket"] = 1
	Save.shot_style = "firework"
	press.call("ax")
	var after_fw: String = Save.shot_style
	press.call("ax")
	check(after_fw == "rocket" and Save.shot_style == "bolt", "A: an opened style joins the round (firework → %s → %s)" % [after_fw, Save.shot_style])
	var open := QuickPick.open_accessories({"keeper3": 3, "cansOne": 1})
	check(open == ["", "party", "glasses"], "B: the accessories open now, none first (%s)" % [open])
	Save.challenges.clear()
	Save.challenges.merge({"keeper3": 3, "cansOne": 1})
	var worn: Array = []
	for i in 4:
		press.call("by")
		worn.append(Save.accessory)
	check(worn == ["party", "glasses", "", "party"], "B: the next open accessory, none among them, wrapping round (%s)" % [worn])
	check(main.dahrooj.accessory == "party" and main.worn() == "party" and main.quick_pick.last_icon == "party", "B: the held Dahrooj wears it at once")
	Save.accessory = "crown"  # locked: worn() reads none, so B goes on from none
	press.call("by")
	check(Save.accessory == "party", "B: from a locked accessory it starts at the first open one")
	# Ricochet: A picks the next paddle, the shot stays; B still changes the accessory.
	main._choose_mode("ricochet")
	main.state = "play"
	main.table.game.reset(1)
	main._step_table(1.0 / 72.0)
	var style_before: String = Save.shot_style
	press.call("ax")
	check(main.table.selected == 1 and Save.shot_style == style_before, "ricochet: A picks the next paddle (not a shot style)")
	press.call("by")
	check(Save.accessory == "glasses", "ricochet: B changes the accessory")
	main._choose_mode("goal")
	Save.shot_style = shot0
	_save_restore(keep)
	main._apply_look()


## Dahrooj Rain plays like the other modes: pinned (VR where the player stands, MR on the
## pinned spot and resized with the stick) and set again by a recenter or a new pin; the
## trigger fires shots and the grip holds Dahrooj (nothing to score on: he only pops the
## rain); rockets home onto the rain's Dahroojs and lightning chains to them.
func _rain_mode(main: Node) -> void:
	var keep := _save_keep()
	var shot0: String = Save.shot_style
	Save.challenges.merge({"shot:rocket": 1, "shot:lightning": 1}, true)
	var ir: IntroRain = main.intro
	var wb: WorldBalls = main.world_balls
	main.set_mode("vr")
	main._choose_mode("rain")
	main.state = "play"
	main.placing = false
	var va: Dictionary = main.vr_anchor
	var o: Vector3 = ir.global_transform.origin
	check(ir.active and ir.rain and ir.pinned and not main.stage.visible and main.ball.stage == null
		and Vector2(o.x, o.z).distance_to(Vector2((va.p as Vector3).x, (va.p as Vector3).z)) < 1e-3 and absf(o.y) < 1e-4,
		"rain VR: pinned where the player stands, nothing to score on")
	for i in 72 * 3:
		main._step_intro(1.0 / 72.0)
	var live := ir.target_drops()
	var ahead := 0
	for d in live:
		if d.p.z < 0.0:
			ahead += 1
	check(live.size() > 20 and ahead >= live.size() * 0.9, "rain VR: they fall ahead of the pinned spot (%d of %d)" % [ahead, live.size()])
	# The controls of every mode.
	wb.clear_blast()
	main.auto_fire.clear()
	main.ball.respawn()
	main.holder = ""
	Save.shot_style = "bolt"
	wb.last_shot.clear()
	main._press("left", "trigger")
	check(wb.shots.size() > 0 and main.holder == "", "rain: the trigger fires shots")
	main.auto_fire.clear()
	wb.clear_blast()
	main._press("right", "grip")
	check(main.holder == "right", "rain: the grip holds Dahrooj")
	main._release("right", true)
	check(main.holder == "", "rain: letting go puts him back")
	# A thrown Dahrooj pops the ones he meets.
	var hit: IntroRain.Drop = ir.target_drops()[0]
	var pc := ir.popped
	main.ball.respawn()
	main.parked = false
	main.ball.pos = main.to_game(ir.drop_world(hit))
	main.ball.throw_with(Vector3(0, 0, -0.1))
	main._game_step(1.0 / 72.0)
	check(hit.popped and ir.popped > pc, "rain: a thrown Dahrooj pops the rain's Dahroojs he meets")
	main.ball.respawn()
	main.holder = ""
	# Rockets home: one drop left, a rocket fired 25° off it turns and pops it.
	var target: IntroRain.Drop = ir.target_drops()[0]
	var only: Array[IntroRain.Drop] = [target]
	ir.balls = only
	var popped0 := ir.popped
	var at: Vector3 = main.to_game(ir.drop_world(target))
	var from: Vector3 = main.eye_game()
	var straight := (at - from).normalized()
	Save.shot_style = "rocket"
	wb.last_shot.clear()
	wb.fire("right", from, Basis(Vector3.UP, deg_to_rad(25.0)) * straight)
	var locked := false
	for i in 72 * 3:
		if not wb.shots.is_empty() and String((wb.shots[0].target as Dictionary).get("kind", "")) == "i":
			locked = true
		wb.step_blast(1.0 / 72.0)
		if target.popped:
			break
	check(locked and target.popped and ir.popped == popped0 + 1, "rain: a rocket fired 25° off homes onto a rain Dahrooj and pops it")
	wb.clear_blast()
	# Lightning chains to them.
	for i in 72:
		main._step_intro(1.0 / 72.0)  # the rain tops itself up
	var near: IntroRain.Drop = ir.target_drops()[0]
	var p1 := ir.popped
	Save.shot_style = "lightning"
	wb.last_shot.clear()
	wb.fire("right", from, (main.to_game(ir.drop_world(near)) - from).normalized())
	check(near.popped and ir.popped > p1, "rain: lightning strikes the rain's Dahroojs (%d popped)" % (ir.popped - p1))
	wb.clear_blast()
	# A recenter sets it again where the player stands.
	main.replace_here()
	check(ir.pinned and ir.global_transform.origin.distance_to(Vector3((main.vr_anchor.p as Vector3).x, 0, (main.vr_anchor.p as Vector3).z)) < 1e-3, "rain VR: a recenter pins it again")
	# Mixed reality: pinned on the spot, a new pin moves it, the stick resizes it; the trigger pins.
	main.set_mode("mr")
	main.state = "play"
	var ap: Vector3 = main.anchor.p
	o = ir.global_transform.origin
	check(ir.pinned and ir.mixed and Vector2(o.x, o.z).distance_to(Vector2(ap.x, ap.z)) < 1e-3 and absf(o.y) < 1e-4 and absf(ir.pin_back - 1.6) < 1e-6,
		"rain MR: on the floor at the pinned spot, falling ahead of it")
	main.placing = true
	main.anchor = main.anchor_from(Vector3(1.2, 0.0, -2.5), Vector3.UP)
	main.place()
	o = ir.global_transform.origin
	check(Vector2(o.x, o.z).distance_to(Vector2(1.2, -2.5)) < 1e-3, "rain MR: placing moves it with the reticle")
	# The stick resizes the Dahroojs only: the rain keeps the room's size.
	main.ar_zoom = 2.0
	main.place()
	var k := ir.global_transform.basis.get_scale().x
	var dk2: float = ir.drop_k
	check(absf(k - 1.0) < 1e-3, "rain MR: the stick leaves the rain's area as it is (×%.2f)" % k)
	main.ar_zoom = 0.5
	main.place()
	check(absf(dk2 / ir.drop_k - 4.0) < 1e-3, "rain MR: and resizes its Dahroojs (×%.2f)" % (dk2 / ir.drop_k))
	main.ar_zoom = 1.0
	main.place()
	# New drops match the Dahrooj thrown on the MR court (not the VR size, 4x bigger there).
	ir.drop_ball(0.0)
	var newest: IntroRain.Drop = ir.balls[ir.balls.size() - 1]
	var thrown_m: float = Ball.BR / main.ar_scale
	var drop_m: float = ir.drop_radius_world(newest)
	check(ir.drop_k < 1.0 and drop_m < IntroRain.INTRO_R * 0.6 and drop_m < thrown_m * 1.9,
		"rain MR: new Dahroojs about the thrown one's size (%.3f m vs %.3f m)" % [drop_m, thrown_m])
	wb.clear_blast()
	main.auto_fire.clear()
	main._press("right", "trigger")
	check(not main.placing and wb.shots.is_empty(), "rain MR: the trigger pins it (no shot)")
	wb.last_shot.clear()
	Save.shot_style = "bolt"
	main._press("right", "trigger")
	check(wb.shots.size() > 0, "rain MR: then the trigger fires again")
	main.auto_fire.clear()
	wb.clear_blast()
	main.set_mode("vr")
	main._choose_mode("goal")
	check(not ir.active and not ir.pinned and ir.transform == Transform3D.IDENTITY and main.ball.stage == main.stage and main.stage.visible,
		"rain: leaving it brings the court back")
	Save.shot_style = shot0
	wb.last_shot.clear()
	_save_restore(keep)
	await get_tree().process_frame
