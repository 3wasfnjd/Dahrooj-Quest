extends Node
## Store art and screenshots from the real game (not shipped: export_filter excludes tools/*).
## Runs the main scene on the desktop camera, sets a clear day, picks a mode, places extra
## Dahroojs (the game's own DahroojView) for the cover art, fires the blaster on a timeline
## and saves one PNG.
##
## Run through tools/store/shoot.sh WxH out.png [args]; build_art.sh has every store picture.
## Args: --mode=<menu mode id> --t=<seconds simulated before the capture> --cam=x,y,z
##   --look=x,y,z (game units) --fov=<deg> --time=day|dusk|night|dawn --lang=ar|en
##   --hud=0 --hide_stage --menu=<page> [--menu_sub=accessories] --extras_json=res://...
##   --fire=<n> --fire_at=<s> --fire_every=<s> --aim=x,y,z --spread=<k> --shot_style=<id>
##   --style/--color/--acc (the player's look) --view=mr
## Time is fixed-step (--fixed-fps 30), so a given set of args always gives the same picture.

var A := {}
var main: Node3D
var frames := 0
var t := 0.0
var extras: Array = []  # [DahroojView, pos, face]
var fired := 0
var done := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		A[kv[0]] = kv[1] if kv.size() > 1 else "1"
	Save.language = String(A.get("lang", "en"))
	Save.style = String(A.get("style", "fur"))
	Save.jelly_color = String(A.get("color", "pink"))
	Save.accessory = String(A.get("acc", ""))
	Save.shot_style = String(A.get("shot_style", "bolt"))
	Save.throw_style = "trigger"
	Save.muted = true
	# Every challenge done: every look and shot style is open (as for a seasoned player).
	var done_to := float(A.get("progress", "1.0"))
	for c: Array in GameRuntime.CHALLENGES:
		Save.challenges[c[0]] = int(ceil(float(c[3]) * done_to))
	# Simulate without drawing until just before the capture (fast at large sizes).
	RenderingServer.render_loop_enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main.park.set_settings({"time": String(A.get("time", "day")), "weather": "clear"})
	if A.has("fov"):
		main.desktop_cam.fov = float(A.fov)
	var view := String(A.get("view", "vr"))
	if view == "mr":
		main.set_mode("mr")
	var m := String(A.get("mode", ""))
	if m != "":
		main._choose_mode(m)
	main.state = "play"
	_add_extras(String(A.get("extras_json", "")))
	if A.has("menu"):
		main.menu.appearance = String(A.get("menu_sub", "character"))
		main.set_menu(true, String(A.menu))


## Game units: the player stands near z = 1 (VR), the targets ahead (−z).
func g2w(v: Vector3) -> Vector3:
	return main.game_root.global_transform * v


static func v3(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


func _camera() -> void:
	if A.has("cam"):
		main.desktop_cam.global_position = g2w(v3(String(A.cam)))
		main.desktop_cam.look_at(g2w(v3(String(A.get("look", "0,0,-10")))), Vector3.UP)
	if A.has("menu"):
		main.menu.place(main.head_transform())


## Extra Dahroojs for the covers, from a JSON list (crowd_*.json, icon.json): each entry is
## [style, colour ("" = the style's own), accessory, [x, height, z] (game units), radius ×,
## face, yaw (degrees off facing the camera)].
func _add_extras(preset: String) -> void:
	var list: Array = []
	if preset != "":
		for e: Array in JSON.parse_string(FileAccess.get_file_as_string(preset)):
			list.append([e[0], e[1], e[2], Vector3(e[3][0], e[3][1], e[3][2]), e[4], e[5], e[6] if e.size() > 6 else 0.0])
	for e: Array in list:
		var v := DahroojView.new(Ball.BR * float(e[4]))
		main.game_root.add_child(v)
		v.set_look(e[0], e[1] if e[1] != "" else "original", e[2])
		var p: Vector3 = e[3]
		p.y += Ball.BR * float(e[4])  # pos.y: the height above the ground
		extras.append([v, p, e[5], float(e[6]) if e.size() > 6 else 0.0])


func _process(delta: float) -> void:
	if main == null or done:
		return
	frames += 1
	t += delta
	_camera()
	if main.intro.active:
		main.intro.step(minf(delta, 0.05), main.head_transform())
	var eye: Vector3 = main.to_game(main.head_transform().origin)
	for x: Array in extras:
		# Each faces the camera, turned a little by its own yaw (x[3], degrees).
		var to: Vector3 = x[1] + (eye - x[1]).rotated(Vector3.UP, deg_to_rad(float(x[3])))
		(x[0] as DahroojView).show_at(x[1], to, x[2], false)
	if A.has("hide_stage") and main.stage:
		main.stage.visible = false
	if A.get("hud", "1") == "0":
		main.hud.visible = false
	# Fire the blaster from just right of the camera toward a point (game units), a few times.
	var n := int(A.get("fire", "0"))
	var start := float(A.get("fire_at", "1.0"))
	var every := float(A.get("fire_every", "0.25"))
	if fired < n and t >= start + fired * every:
		var aim := v3(String(A.get("aim", "0,1,-10")))
		var from: Vector3 = main.to_game(main.desktop_cam.global_transform * Vector3(0.12, -0.12, -0.2))
		var jitter := Vector3(sin(fired * 1.7) * 0.6, cos(fired * 2.3) * 0.4, 0) * float(A.get("spread", "1.0"))
		main.world_balls.last_shot.clear()
		main.world_balls.fire("right" if fired % 2 == 0 else "left", from, (aim + jitter - from).normalized())
		fired += 1
	if A.has("throw_at") and t >= float(A.throw_at) and not A.has("_thrown"):
		A["_thrown"] = true
		main.ball.pos = main.to_game(main.desktop_cam.global_transform * Vector3(0.15, -0.15, -0.35))
		main.ball.throw_with(v3(String(A.get("throw", "0,4,-10"))))
	if A.has("dump") and frames == 5:
		print("store_shot eye(game)=", eye, " aim_z=", main.stage.get("aim_z"), " scale=", main.scale_now)
	if t >= float(A.get("t", "3.0")) - 0.2:
		RenderingServer.render_loop_enabled = true
	if t >= float(A.get("t", "3.0")):
		done = true
		_capture()


func _capture() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(String(A.get("out", "/tmp/store_shot.png")))
	print("store_shot: ", A.get("out"), " ", img.get_size())
	get_tree().quit()
