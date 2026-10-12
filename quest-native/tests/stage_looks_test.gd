extends RefCounted
## Dahrooj's looks (dahrooj_looks.gd, dahrooj_view.gd): every style builds with its
## material, the saved colour tints the three playable styles (original = the style's own),
## accessories attach and a hat hides the fur ball's ribbon, the look survives a save, and
## the accessories unlock as challenges.ts says.


static func _tint_of(v: DahroojView) -> Color:
	var m := v.body.material_override
	if m is ShaderMaterial:
		return ((m as ShaderMaterial).get_shader_parameter("tint") as Color).linear_to_srgb()
	return (m as StandardMaterial3D).albedo_color


static func run(check: Callable) -> void:
	_styles(check)
	_colours(check)
	_accessories(check)
	_save(check)
	_unlocks(check)


static func _styles(check: Callable) -> void:
	var v := DahroojView.new()
	check.call(v.style == "fur" and v.color_id == "pink" and v.accessory == "" and v.bow.visible and not v.bandage.visible,
		"looks: a new Dahrooj is pink fur with his ribbon (store defaults)")
	var ok := true
	for s: String in DahroojLooks.STYLES:
		v.set_look(s, "original", "")
		var m := v.body.material_override
		var right := (m is ShaderMaterial) if s in ["jelly", "bubble"] else (m is StandardMaterial3D)
		if s == "jelly":
			right = right and ((m as ShaderMaterial).shader.code.contains("refract")) and v.bandage.visible and not v.bow.visible
		elif s == "bubble":
			right = right and ((m as ShaderMaterial).shader.code.contains("ALPHA")) and not v.bandage.visible and not v.bow.visible \
				and v.body.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif s == "fur":
			right = right and (m as StandardMaterial3D).albedo_texture != null and v.bow.visible
		ok = ok and right and v.style == s
	check.call(ok, "looks: jelly (refraction, bandage), fur (fur coat, ribbon), bubble (soap film, no shadow), fabric and clay build")
	v.set_look("nonsense", "nonsense", "nonsense")
	check.call(v.style == "jelly" and v.color_id == "pink" and v.accessory == "", "looks: unknown values fall back (jelly, pink, nothing)")
	var dv := DahroojView.new(Ball.BR, true)
	check.call((dv.body.mesh as ArrayMesh).get_surface_count() == 1 and dv.body.mesh != v.body.mesh, "looks: a lite Dahrooj has fewer facets")
	dv.free()
	v.free()


static func _colours(check: Callable) -> void:
	var v := DahroojView.new()
	var ok := true
	for id: String in DahroojLooks.COLOR_IDS:
		for s in ["jelly", "fur", "bubble"]:
			v.set_look(s, id, "")
			var want := Color(DahroojLooks.DAHROOJ_COLORS[s]) if id == "original" else Color(DahroojLooks.COLOR_CHOICES[id])
			ok = ok and _tint_of(v).is_equal_approx(want)
	check.call(ok, "looks: the saved colour tints jelly, fur and bubble; original is each style's own")
	v.set_look("clay", "blue", "")
	check.call(_tint_of(v).is_equal_approx(Color("ff9b3d")), "looks: legacy clay keeps its own colour")
	v.set_look("jelly", "green", "")
	var a := v.body.material_override
	var other := DahroojView.new()
	other.set_look("jelly", "green", "")
	check.call(other.body.material_override == a, "looks: one shared material per style and colour")
	check.call(MenuCatalog.COLORS.size() == DahroojLooks.COLOR_IDS.size(), "looks: the menu offers every colour")
	other.free()
	v.free()


static func _accessories(check: Callable) -> void:
	var v := DahroojView.new()
	var ok := true
	for id: String in DahroojLooks.ACCESSORIES:
		if id == "":
			continue
		v.set_look("fur", "pink", id)
		var mesh := v.acc.mesh as ArrayMesh
		var hat := id in DahroojLooks.HEADWEAR
		var tris := mesh.surface_get_array_index_len(0) if mesh else 0
		ok = ok and v.acc.visible and mesh != null and tris > 60 and v.bow.visible == (not hat) \
			and absf(v.acc.scale.x - Ball.BR * 1.08) < 1e-5 and mesh.get_surface_count() == 1
	check.call(ok, "looks: all eleven accessories attach (one draw each, 1.08x on fur); hats hide the ribbon")
	v.set_look("jelly", "pink", "crown")
	check.call(absf(v.acc.scale.x - Ball.BR) < 1e-5 and not v.bow.visible, "looks: no ribbon or scale-up off the fur")
	v.set_look("fur", "pink", "")
	check.call(not v.acc.visible and v.bow.visible, "looks: taking it off brings the ribbon back")
	check.call(DahroojLooks.normalize_accessory("laurel") == "aviator", "looks: the retired laurel is the aviator cap")
	var party := DahroojLooks.accessory_mesh("party")
	var lite := DahroojLooks.accessory_mesh("party", true)
	check.call(lite.surface_get_array_len(0) < party.surface_get_array_len(0) and party.surface_get_format(0) & Mesh.ARRAY_FORMAT_TEX_UV2,
		"looks: crowds get the lite accessories; surfaces carry their finish")
	var draws := 0
	v.set_look("jelly", "pink", "headphones")
	for n in v.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).visible:
			draws += 1
	check.call(draws <= 10, "looks: a handful of draws per Dahrooj (%d)" % draws)
	v.free()


static func _save(check: Callable) -> void:
	var path: String = Save.PATH
	var had := FileAccess.file_exists(path)
	var before := FileAccess.get_file_as_string(path) if had else ""
	var keep := [Save.style, Save.jelly_color, Save.accessory, Save.challenges.duplicate()]
	Save.style = "bubble"
	Save.jelly_color = "purple"
	Save.challenges = {"reward:crown": 1}
	Save.accessory = "crown"
	Save.save()
	Save.style = "fur"
	Save.jelly_color = "pink"
	Save.accessory = ""
	Save.load_data()
	check.call(Save.style == "bubble" and Save.jelly_color == "purple" and Save.accessory == "crown", "looks: style, colour and accessory survive a save")
	var l := DahroojLooks.load_look({"style": "fabric", "jelly_color": "teal", "accessory": "crown"}, {})
	check.call(l.style == "fur" and l.jelly_color == "pink" and l.accessory == "", "looks: loading folds fabric into fur, unknown colours to pink, locked accessories off")
	check.call(DahroojLooks.load_look({}, {}).style == "fur" and DahroojLooks.load_look({"style": "clay"}, {}).style == "jelly",
		"looks: no saved style is fur; legacy clay is jelly")
	Save.style = keep[0]
	Save.jelly_color = keep[1]
	Save.accessory = keep[2]
	Save.challenges = keep[3]
	if had:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(before)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _unlocks(check: Callable) -> void:
	var A := func(id: String, done: int, p: Dictionary) -> bool: return DahroojLooks.accessory_available(id, done, p)
	check.call(A.call("", 0, {}) and A.call("party", 1, {}) and not A.call("party", 0, {}) and A.call("glasses", 3, {}) and not A.call("cap", 4, {}),
		"looks: nothing is always free; party at 1, glasses at 3, cap at 5")
	check.call(A.call("scarf", 14, {}) and not A.call("scarf", 13, {}) and A.call("crown", 0, {"reward:crown": 1}),
		"looks: scarf at 14; rewards kept from old saves stay")
	check.call(A.call("aviator", 0, {"balance5": 5}) and not A.call("aviator", 0, {"balance5": 4}) and A.call("woodhat", 0, {"ricochet5": 5})
		and A.call("starGlasses", 0, {"maze5": 5}) and A.call("beanie", 0, {"mazeClean": 1}) and not A.call("beanie", 25, {}),
		"looks: aviator, wooden hat, star glasses and beanie unlock with their challenge")
	var all := {}
	for c: Array in MenuCatalog.CHALLENGES:
		all[c[0]] = c[1]
	check.call(DahroojLooks.done_count(all) == MenuCatalog.CHALLENGES.size() and DahroojLooks.done_count({"keeper3": 2}) == 0, "looks: finished challenges counted")
