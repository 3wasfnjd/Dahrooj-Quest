extends RefCounted
## The game's sounds: every file rendered from the web game's Web Audio code is there and loads,
## and GameAudio plays each sound (spatial and UI), the music and the ambience without errors.


static func run(check: Callable) -> void:
	_files(check)
	_player(check)


static func _files(check: Callable) -> void:
	var files := GameAudio.all_files()
	var missing: Array[String] = []
	var bad: Array[String] = []
	for f in files:
		var path := GameAudio.DIR + f + (".ogg" if f == "music" or f.ends_with("_loop") else ".wav")
		if not ResourceLoader.exists(path):
			missing.append(f)
			continue
		var s := load(path) as AudioStream
		if s == null or s.get_length() <= 0.05:
			bad.append(f)
	check.call(files.size() == 89, "audio: all %d sound files listed" % files.size())
	check.call(missing.is_empty(), "audio: every rendered file is imported (missing: %s)" % ", ".join(missing))
	check.call(bad.is_empty(), "audio: every file loads as a stream with a length (bad: %s)" % ", ".join(bad))
	var music := load(GameAudio.DIR + "music.ogg") as AudioStream
	check.call(music != null and absf(music.get_length() - 65.0) < 0.2, "audio: music is the 5 s intro plus its 60 s loop")


static func _player(check: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var ga := GameAudio.new()
	# The suite runs from the test scene's _ready (the root is busy): hang the player under that scene.
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root.get_child(tree.root.get_child_count() - 1)
	host.add_child(ga)
	var played := 0
	for snd: String in GameAudio.SFX:
		for k: float in [0.0, 0.3, 0.7, 1.0, 1.35]:
			var chosen: Array = ga.pick(snd, k)
			if ga.stream(chosen[0]) != null:
				played += 1
			ga.sfx(snd, k, Vector3(1.0, 1.0, -2.0))
	ga.ui("chime")
	check.call(played == GameAudio.SFX.size() * 5, "audio: sfx() finds a file for every sound and intensity (%d)" % played)
	var t: Array = ga.pick("thump", 0.3)
	check.call(t[0] == "thump_k25" and float(t[1]) > 0.0, "audio: thump(.3) uses the .25 render, a little louder")
	var w: Array = ga.pick("whoosh", 0.18)
	check.call(w[0] == "whoosh_k20" and is_zero_approx(float(w[1])), "audio: whoosh(.18) uses the .2 render at its own level")
	var f1: Array = ga.pick("firework_burst", 1.0)
	var f2: Array = ga.pick("firework_burst", 1.0)
	check.call(f1[0] != f2[0], "audio: firework cues cycle through their three buffers")
	ga.music(true)
	ga.ambience(true)
	ga.set_environment(0.8, 0.3, 0.0)
	ga.pond_radii = Vector2(4.0, 3.0)
	ga._process(0.5)
	ga._process(7.0)
	check.call(ga._music != null and ga._music.playing and ga._rain != null and ga._crickets.size() == 3, "audio: music and ambience beds play")
	ga.music(false)
	ga.ambience(false)
	ga.set_muted(true)
	ga.set_muted(false)
	host.remove_child(ga)
	ga.free()
