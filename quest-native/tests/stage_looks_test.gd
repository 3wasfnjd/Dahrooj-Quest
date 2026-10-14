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
	_head_cloth(check)
	_world_cup(check)
	_new_accessories(check)
	_menu_pages(check)


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
	check.call(ok, "looks: all %d accessories attach (one draw each, 1.08x on fur); hats hide the ribbon" % (DahroojLooks.ACCESSORIES.size() - 1))
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
	Save.challenges = {"reward:crown": 1, "styles5": 3}
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
	check.call(A.call("", 0, {}) and A.call("party", 0, {"keeper3": 3}) and not A.call("party", 40, {"keeper3": 2}) and A.call("glasses", 0, {"cansOne": 1})
		and A.call("cap", 0, {"curve3": 3}) and not A.call("cap", 40, {}),
		"looks: nothing is always free; party with keeper3, sunglasses with cansOne, cap with curve3 (not a count)")
	check.call(A.call("scarf", 0, {"summit1": 1}) and not A.call("scarf", 40, {}) and A.call("crown", 0, {"reward:crown": 1}),
		"looks: the scarf at the Summit's top; rewards kept from old saves stay")
	check.call(A.call("aviator", 0, {"balance5": 5}) and not A.call("aviator", 0, {"balance5": 4}) and A.call("woodhat", 0, {"ricochet5": 5})
		and A.call("starGlasses", 0, {"maze5": 5}) and A.call("beanie", 0, {"mazeClean": 1}) and not A.call("beanie", 25, {}),
		"looks: aviator, wooden hat, star glasses and beanie unlock with their challenge")
	var all := {}
	for c: Array in GameRuntime.CHALLENGES:
		all[c[0]] = c[3]
	check.call(DahroojLooks.done_count(all) == GameRuntime.CHALLENGES.size() and DahroojLooks.done_count({"keeper3": 2}) == 0, "looks: finished challenges counted (every challenge of the game)")


## The head-cloths, caps, falcon, flowers and the rest: each builds full and lite, attaches
## (hiding the ribbon when it is headwear), unlocks on schedule, and crowds wear it too.
static func _new_accessories(check: Callable) -> void:
	var added := ["shemagh", "ghutra", "taqiyah", "kufi", "falcon", "jasmine", "headband", "astronaut", "pirate", "chef", "dino", "halo",
		"bunny", "wizard", "viking", "propeller", "bowtie", "gradcap",
		"umbrella", "goldShades", "turban", "taifRose", "farwa", "diving", "lantern", "palm", "misbaha", "karak", "sadu", "medal",
		"goldAgal", "bisht", "trophy", "goldStar", "goldPal"]
	var v := DahroojView.new()
	var bad: Array = []
	for id: String in added:
		var full := DahroojLooks.accessory_mesh(id)
		var lite := DahroojLooks.accessory_mesh(id, true)
		var named: bool = not MenuCatalog.accessory(id).is_empty() and MenuCatalog.accessory(id)[1] != "" and MenuCatalog.accessory(id)[2] != ""
		var aabb := full.get_aabb()
		for s in ["fur", "jelly", "bubble"]:
			v.set_look(s, "pink", id)
			var hat := id in DahroojLooks.HEADWEAR
			if v.accessory != id or not v.acc.visible or v.acc.mesh != full or v.bow.visible != (s == "fur" and not hat) \
					or v.glass.visible != (id == "astronaut"):
				bad.append("%s/%s" % [id, s])
		if not named or full.surface_get_array_index_len(0) < 300 or lite.surface_get_array_len(0) >= full.surface_get_array_len(0) \
				or not (full.surface_get_format(0) & Mesh.ARRAY_FORMAT_TEX_UV2) or aabb.size.x > 3.0 or aabb.end.y > 2.0 or aabb.position.y < -1.1:
			bad.append(id)
	check.call(bad.is_empty(), "looks: the %d newer accessories build (lite smaller), fit on the head, attach and hide the ribbon when worn on it %s" % [added.size(), bad])
	check.call("shemagh" in DahroojLooks.HEADWEAR and "ghutra" in DahroojLooks.HEADWEAR and "taqiyah" in DahroojLooks.HEADWEAR
		and not "halo" in DahroojLooks.HEADWEAR and not "headband" in DahroojLooks.HEADWEAR, "looks: cloths and caps are headwear; the halo and the headband keep the ribbon")
	v.set_look("jelly", "pink", "")
	check.call(not v.glass.visible and DahroojLooks.accessory_glass("shemagh") == null and DahroojLooks.accessory_glass("astronaut") != null,
		"looks: only the space helmet has glass")
	# The shemagh is red and white with its black agal; the ghutra all white.
	var sh := DahroojLooks.accessory_mesh("shemagh")
	var cols: PackedColorArray = sh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var black := 0
	for c in cols:
		if c.r < 0.05 and c.g < 0.05:
			black += 1
	check.call(black > 200 and DahroojLooks.ACC_SHADER.contains("hound("), "looks: the shemagh has its agal and its houndstooth")
	var A := func(id: String, done: int, p: Dictionary) -> bool: return DahroojLooks.accessory_available(id, done, p)
	check.call(A.call("ghutra", 0, {"strike1": 1}) and not A.call("ghutra", 40, {}) and A.call("shemagh", 0, {"modes5": 5}) and not A.call("shemagh", 0, {"modes5": 4})
		and A.call("falcon", 0, {"ricochetAce": 1}) and A.call("halo", 0, {"balanceClean": 1}) and A.call("wizard", 0, {"combo10": 10}) and A.call("bowtie", 0, {"balance1": 1}),
		"looks: ghutra with a strike, shemagh with 5 modes, falcon with a first-throw ricochet, wizard hat with a 10 combo")
	check.call(A.call("umbrella", 0, {"score1k": 1000}) and not A.call("umbrella", 60, {"score1k": 999}) and A.call("trophy", 0, {"total250k": 250000})
		and not A.call("trophy", 0, {"total250k": 249999}) and A.call("goldAgal", 0, {"modesAll": 20}) and A.call("bisht", 0, {"total100k": 100000}),
		"looks: the big-number rewards open with their challenge (umbrella at 1,000, trophy at 250,000)")
	check.call("goldAgal" in DahroojLooks.HEADWEAR and "trophy" in DahroojLooks.HEADWEAR and not "medal" in DahroojLooks.HEADWEAR
		and not "misbaha" in DahroojLooks.HEADWEAR and not "goldShades" in DahroojLooks.HEADWEAR and DahroojLooks.ACC_SHADER.contains("Sadu"),
		"looks: hats hide the ribbon, the medal, beads and glasses keep it; the Sadu weave is drawn")
	var ga: PackedColorArray = DahroojLooks.accessory_mesh("goldAgal").surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var golden := 0
	for c in ga:
		if c.r > 0.6 and c.b < 0.15:
			golden += 1
	check.call(golden > 200, "looks: the golden agal is gold (%d)" % golden)
	check.call(A.call("astronaut", 0, {"meteor50": 50}) and not A.call("astronaut", 30, {"meteor50": 49}) and A.call("dino", 0, {"giant3": 3}),
		"looks: the space helmet and dino hood unlock with their arcade challenge")
	var needs: Array = []
	for a: Array in MenuCatalog.ACCESSORIES:
		if a[3] is int:
			needs.append(a[3])
		else:
			check.call(not MenuCatalog.challenge(str(a[3])).is_empty(), "looks: %s's challenge exists" % a[0])
	var sorted := needs.duplicate()
	sorted.sort()
	var all_ids := true
	for id: String in DahroojLooks.ACCESSORIES:
		all_ids = all_ids and not MenuCatalog.accessory(id).is_empty()
	check.call(all_ids and needs == sorted and MenuCatalog.ACCESSORIES.size() == DahroojLooks.ACCESSORIES.size(), "looks: every accessory has a menu entry; rewards come in order")
	v.free()
	# Crowds build any accessory the first time it is worn (lite, with the helmet's glass).
	var c := Crowd.new(6, true)
	c.begin()
	c.add("fur", Vector3.ZERO, 0.1, null, Vector2.ONE, "open", "shemagh")
	c.add("jelly", Vector3.ONE, 0.1, null, Vector2.ONE, "open", "astronaut")
	c.add("fur", Vector3.ONE * 2.0, 0.1, null, Vector2.ONE, "open", "halo")
	c.end()
	check.call(c.part_count("acc_shemagh") == 1 and c.part_count("acc_astronaut") == 1 and c.part_count("glass_astronaut") == 1
		and c.part_count("bow") == 1 and (c.parts["acc_shemagh"].mm as MultiMesh).mesh == DahroojLooks.accessory_mesh("shemagh", true),
		"looks: crowds wear the new accessories (lite), the helmet with its glass; the halo keeps the ribbon")
	c.free()


## The accessories page: twelve cards a page, page arrows, every label fits.
static func _menu_pages(check: Callable) -> void:
	var p := MenuPanel.new()
	p.set_page("appearance")
	p.appearance = "accessories"
	var seen := {}
	var bad: Array = []
	var pages := MenuPanel.acc_pages()
	for en in [false, true]:
		var m := {"english": en, "kind": "vr", "accessory": "falcon", "done": 30, "rewards": {}, "challenges": []}
		for pg in pages:
			p.acc_page = pg
			p.draw(m, -1)
			var cards := 0
			for i in p.buttons.size():
				var b: Dictionary = p.buttons[i]
				if b.kind == "acc":
					cards += 1
					seen[b.id] = true
					if float(b.y) + float(b.h) > 820.0:
						bad.append("low:" + str(b.id))
			if cards > MenuPanel.ACC_PER_PAGE or cards == 0:
				bad.append("cards:%d" % cards)
			for hv in range(-1, p.buttons.size()):
				p.draw(m, hv)
				for r: Dictionary in p.measure():
					if float(r.w) > float(r.max_w) + 0.5 or int(r.size) < Glass.MIN_SIZE:
						bad.append(r.s)
	check.call(pages >= 2 and seen.size() == MenuCatalog.ACCESSORIES.size() and bad.is_empty(),
		"menu: the accessories page pages through all %d accessories and every label fits %s" % [seen.size(), bad.slice(0, 6)])
	var m := {"english": true, "kind": "vr", "accessory": "", "done": 0, "rewards": {}, "challenges": []}
	p.appearance = "character"
	p.model = m
	p.acc_page = 0
	p.draw(m, -1)
	p.navigate({"kind": "appearance", "id": "accessories"})
	p.draw(m, -1)
	var prev := -1
	var next := -1
	for i in p.buttons.size():
		if p.buttons[i].kind == "accPage":
			if p.buttons[i].id == "prev":
				prev = i
			else:
				next = i
	check.call(prev >= 0 and next >= 0 and p.action(prev).is_empty() and not p.action(next).is_empty() and p.buttons[prev].x < p.buttons[next].x,
		"menu: on the first page only Next turns (English: Previous on the left)")
	p.navigate(p.action(next))
	p.draw(m, -1)
	var crown := -1
	for i in p.buttons.size():
		if p.buttons[i].kind == "acc" and p.buttons[i].id == "crown":
			crown = i
	check.call(p.acc_page == 1 and crown >= 0 and p.buttons[crown].disabled and p.buttons[crown].sub == "Knock 25 Dahroojs off the fort",
		"menu: Next shows the second page (the crown, locked: the fort's challenge)")
	var astro := -1
	for i in p.buttons.size():
		if p.buttons[i].kind == "acc" and p.buttons[i].id == "astronaut":
			astro = i
	check.call(astro >= 0 and p.buttons[astro].sub == "Blast 50 meteors", "menu: an arcade challenge prize names its challenge")
	p.model = {"english": false, "accessory": "shemagh"}
	p.appearance = "character"
	p.navigate({"kind": "appearance", "id": "accessories"})
	check.call(p.acc_page == 0, "menu: opening the accessories shows the page of the one worn")
	p.model = {"english": false, "accessory": "dino"}
	p.appearance = "character"
	p.navigate({"kind": "appearance", "id": "accessories"})
	check.call(p.acc_page == 1, "menu: ... on the second page too")
	p.free()


## The shemagh and the ghutra (and the golden agal's ghutra) lie smooth over the crown under
## the agal: nothing stands up above the head (no peak), full or crowd (lite).
static func _head_cloth(check: Callable) -> void:
	var tops: Array = []
	var ok := true
	for id: String in ["shemagh", "ghutra", "goldAgal"]:
		for lite: bool in [false, true]:
			var top := DahroojLooks.accessory_mesh(id, lite).get_aabb().end.y
			tops.append("%s%s %.2f" % [id, " lite" if lite else "", top])
			ok = ok and top < 1.13
	check.call(ok and float(DahroojLooks.SAUDI_CLOTH.crest) == 0.0, "looks: the shemagh and ghutra sit smooth on the head, no peak on top %s" % [tops])


## The World Cup: worn on the head (a hat), standing on the crown; the finale's big one is a
## head's height of trophy, foot at its origin.
static func _world_cup(check: Callable) -> void:
	var bb := DahroojLooks.accessory_mesh("worldCup").get_aabb()
	var big := DahroojLooks.world_cup_mesh(1.0).get_aabb()
	check.call("worldCup" in DahroojLooks.ACCESSORIES and "worldCup" in DahroojLooks.HEADWEAR and bb.position.y > 0.8 and bb.end.y > 2.0 and bb.size.x < 0.8,
		"looks: the World Cup stands on the crown (%.2f .. %.2f)" % [bb.position.y, bb.end.y])
	check.call(absf(big.position.y) < 0.01 and absf(big.end.y - 1.1) < 0.12 and absf(big.get_center().x) < 0.01,
		"looks: the finale's World Cup is about its height tall, foot at the origin (%s)" % [big])
