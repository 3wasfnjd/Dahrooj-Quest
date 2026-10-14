extends RefCounted
## The finale (Finale): every actor (the rings, the moles, the giant, the cup) stands in front
## of the player, never behind, at the same size in metres in VR and mixed reality; it plays its
## beats (confetti, fireworks, the chime, haptics, the rainbow banner «أبطال العالم!»), presents
## the World Cup in front of the eyes and ends cleanly after about DUR seconds; the first time it
## puts the World Cup on Dahrooj. scene(): in the real game it starts once when the last
## challenge is done (not again), and the challenges page replays it.

const DT := 1.0 / 30.0


## What Finale asks of the main scene: the head looking along -Z (yaw turns it), game units =
## metres times scale_now, the sounds, buzzes, confetti, fireworks and look it uses.
class FakeHost:
	extends Node3D
	var scale_now := 2.0
	var yaw := 0.0
	var confetti: Confetti = null
	var world_balls = null
	var toast = null
	var sounds: Array = []
	var buzzes := 0
	var looks := 0
	func head_transform() -> Transform3D:
		return Transform3D(Basis(Vector3.UP, yaw), Vector3(0.3, 1.6, -0.2))
	func to_game(p: Vector3) -> Vector3:
		return p * scale_now
	func sfx(n: String, k: float, p: Vector3) -> void:
		sounds.append([n, k, p])
	func buzz(_hand: String, _amp: float, _ms: float) -> void:
		buzzes += 1
	func _apply_look() -> void:
		looks += 1


class FakeBlooms:
	extends RefCounted
	var at: Array = []
	func bloom(p: Vector3) -> void:
		at.append(p)


static func run(check: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root.get_child(tree.root.get_child_count() - 1)
	var keep_acc: String = Save.accessory
	var keep_ch: Dictionary = Save.challenges.duplicate(true)
	var path: String = Save.PATH
	var had := FileAccess.file_exists(path)
	var before := FileAccess.get_file_as_string(path) if had else ""
	for view: Array in [[2.0, 0.0], [8.0, 2.3]]:
		var host := FakeHost.new()
		host.scale_now = float(view[0])
		host.yaw = float(view[1])
		parent.add_child(host)
		host.confetti = Confetti.new()
		host.add_child(host.confetti)
		host.world_balls = FakeBlooms.new()
		var f := Finale.new()
		f.host = host
		f.auto_step = false
		host.add_child(f)
		var ended := [0]
		f.finished.connect(func() -> void: ended[0] += 1)
		f.start(true)
		var head := host.head_transform()
		var eye := host.to_game(head.origin)
		var fwd := -head.basis.z
		fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
		var u := host.scale_now
		var behind := 0
		var near := 999.0
		var most := 0
		var cup_ahead := true
		var presented := false
		var banner_seen := false
		var peak_text := ""
		while f.active and f.t < Finale.DUR + 2.0:
			f.step(DT)
			most = maxi(most, f.drawn.size())
			for a: Array in f.drawn:
				var d := (a[0] as Vector3) - eye
				var ahead := Vector3(d.x, 0.0, d.z).dot(fwd) / u
				if ahead < 0.0:
					behind += 1
				near = minf(near, ahead)
			if f.cup.visible:
				var cd := f.cup.position - eye
				var ca := Vector3(cd.x, 0.0, cd.z).dot(fwd) / u
				cup_ahead = cup_ahead and ca > Finale.PRESENT_M * 0.9
				if f.t > 10.0 and f.t < 10.5:
					presented = presented or (absf(ca - Finale.PRESENT_M) < 0.05 and absf(Vector3(cd.x, 0.0, cd.z).length() / u - Finale.PRESENT_M) < 0.05)
			if f.banner != null and f.banner.visible:
				banner_seen = true
				peak_text = f.banner.text
		var names: Array = []
		for snd: Array in host.sounds:
			names.append(snd[0])
		var tag := "VR" if u == 2.0 else "MR"
		var want_n := Finale.GROUND + Finale.FLYERS + 1
		check.call(most >= want_n and behind == 0 and near >= Finale.NEAR_M - 0.05,
			"finale %s: %d dancers, all in front (nearest %.2f m ahead, %d behind)" % [tag, most, near, behind])
		check.call(cup_ahead and presented, "finale %s: the World Cup rises ahead, then is presented %.1f m in front of the eyes" % [tag, Finale.PRESENT_M])
		check.call(banner_seen and peak_text == Save.text("أبطال العالم!", "World Champion!") and f.sub.text == Save.text("أتممت دحروج", "You completed Dahrooj"),
			"finale %s: the rainbow banner «%s»" % [tag, peak_text])
		check.call("chime" in names and "firework_launch" in names and (host.world_balls as FakeBlooms).at.size() >= 8 and host.buzzes >= 10,
			"finale %s: chime, %d fireworks and haptics" % [tag, (host.world_balls as FakeBlooms).at.size()])
		check.call(not f.active and not f.visible and ended[0] == 1 and f.t >= Finale.DUR and f.t < Finale.DUR + 0.1 and f.crowd.count() == 0 and not f.banner.visible,
			"finale %s: it ends cleanly after %.1f s (nothing left showing)" % [tag, f.t])
		check.call(Save.accessory == Finale.ACCESSORY and host.looks == 1 and int(Save.challenges.get(Finale.SEEN, 0)) == 1,
			"finale %s: the first time, Dahrooj puts the World Cup on" % tag)
		# A replay keeps the look the player chose.
		Save.accessory = "crown"
		f.start(false)
		while f.active:
			f.step(DT)
		check.call(Save.accessory == "crown" and f.runs == 2 and ended[0] == 2, "finale %s: a replay plays it again without changing the look" % tag)
		host.free()
	Save.accessory = keep_acc
	Save.challenges.clear()
	Save.challenges.merge(keep_ch)
	if had:
		var fl := FileAccess.open(path, FileAccess.WRITE)
		fl.store_string(before)
		fl.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## In the real game (the caller keeps and restores the save): finishing the last challenge
## starts the finale once, in front of the player; the challenges page replays it.
static func scene(main: Node, check: Callable) -> void:
	var f: Finale = main.finale
	f.auto_step = false
	main.set_mode("vr")
	main._choose_mode("goal")
	main.state = "play"
	main.placing = false
	Save.challenges.clear()
	for c: Array in GameRuntime.CHALLENGES:
		if c[0] != GameRuntime.ALL_DONE and c[0] != "keeper3":
			Save.challenges[c[0]] = c[3]
	Save.challenges["keeper3"] = 2
	GameRuntime.sync_all_done(Save.challenges)
	main._known_rewards = {}
	main._reward_check = 0.0
	main._watch_rewards(1.0)
	var started_early := f.active
	main.runtime.add_count("goal", false)
	main._reward_check = 0.0
	main._watch_rewards(1.0)
	var eye: Vector3 = main.eye_game()
	var head: Transform3D = main.head_transform()
	var fwd: Vector3 = main.to_game(head.origin - head.basis.z) - eye
	fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
	var ahead := (f.centre - eye).dot(fwd) / float(main.scale_now)
	check.call(not started_early and GameRuntime.all_done(Save.challenges) and f.active and f.first and f.runs == 1 and absf(ahead - Finale.AHEAD_M) < 0.05,
		"finale: finishing the last challenge starts it, %.1f m ahead of the player" % ahead)
	var cards: Array = (main.toast.cards as Array).map(func(c: Dictionary) -> String: return str(c.title))
	check.call(cards.has(Save.text("فتحت كأس العالم!", "World Cup unlocked!")), "finale: the World Cup's reward card %s" % [cards])
	while f.active:
		f.step(DT)
	main._reward_check = 0.0
	main._watch_rewards(1.0)
	check.call(not f.active and f.runs == 1 and Save.accessory == Finale.ACCESSORY and main.worn() == Finale.ACCESSORY and main.dahrooj.accessory == Finale.ACCESSORY,
		"finale: it plays once; Dahrooj wears the World Cup")
	# The challenges page replays it.
	main.set_menu(true, "challenges")
	main._step_menu(0.0)
	var i := -1
	for k in main.menu.buttons.size():
		if main.menu.buttons[k].kind == "finale":
			i = k
	if i >= 0:
		main._menu_action(i)
	check.call(i >= 0 and f.active and not f.first and f.runs == 2 and not main.menu.visible, "finale: the challenges page plays it again")
	f.stop()
	f.auto_step = true
	main.toast.cards.clear()
