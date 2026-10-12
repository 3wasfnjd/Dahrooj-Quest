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
			sc.call("run", check)


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
	main.queue_free()
	await get_tree().process_frame
