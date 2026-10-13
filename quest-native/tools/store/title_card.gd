extends Node2D
## The store title over a picture (or on transparency for the logo), drawn the way the game
## draws its festive jelly text (JuiceText: Baloo 800, per-glyph jelly hues with a vertical
## gradient, a dark extruded copy under it and a light rim), at any size. Not shipped.
##
## godot --rendering-driver opengl3 --resolution WxH --path . res://tools/store/title_card.tscn -- \
##   --out=/abs/out.png [--bg=/abs/bg.png] [--cx=0.5 --cy=0.4] [--px=300] [--latin_k=0.42]
##   [--gap=0.05] [--transparent] [--only=ar|en] [--glow=0.35]

var A := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		A[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var size := get_viewport().get_visible_rect().size
	if A.has("transparent"):
		get_viewport().transparent_bg = true
	if A.has("bg"):
		var img := Image.load_from_file(String(A.bg))
		var tr := Sprite2D.new()
		tr.texture = ImageTexture.create_from_image(img)
		tr.centered = false
		tr.scale = size / Vector2(img.get_size())
		add_child(tr)
	var px := float(A.get("px", "300"))
	var latin_k := float(A.get("latin_k", "0.42"))
	var lines: Array = []
	var only := String(A.get("only", ""))
	if only != "en":
		lines.append(["دحروج", px])
	if only != "ar":
		lines.append(["DAHROOJ", px * latin_k])
	# Lay the lines out as one block centred on (cx, cy).
	var shaped: Array = []
	var total := 0.0
	var gap := px * float(A.get("gap", "0.02"))
	for L: Array in lines:
		var s := _shape(String(L[0]), float(L[1]))
		shaped.append(s)
		total += float(s.ink_h)
	total += gap * (shaped.size() - 1)
	var cx := size.x * float(A.get("cx", "0.5"))
	var y := size.y * float(A.get("cy", "0.4")) - total / 2.0
	var glow := float(A.get("glow", "0.0"))
	for s: Dictionary in shaped:
		_draw_line(s, Vector2(cx - float(s.width) / 2.0, y - float(s.ink_top)), glow)
		y += float(s.ink_h) + gap
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var out := get_viewport().get_texture().get_image()
	if not A.has("transparent"):
		out.convert(Image.FORMAT_RGB8)
	out.save_png(String(A.get("out", "/tmp/title.png")))
	print("title_card: ", A.get("out"), " ", out.get_size(), " block=", total)
	get_tree().quit()


func _shape(txt: String, px: float) -> Dictionary:
	var line := TextLine.new()
	var rtl := txt.unicode_at(0) >= 0x0600 and txt.unicode_at(0) <= 0x06FF
	line.direction = TextServer.DIRECTION_RTL if rtl else TextServer.DIRECTION_LTR
	line.add_string(txt, JuiceText.font(), int(px))
	var asc := line.get_line_ascent()
	var ts := TextServerManager.get_primary_interface()
	var top := 1e9
	var bottom := -1e9
	var centers: Array = []
	var x := 0.0
	for g: Dictionary in ts.shaped_text_get_glyphs(line.get_rid()):
		var rid: RID = g.get("font_rid", RID())
		var index: int = g.get("index", 0)
		var adv: float = g.get("advance", 0.0)
		if rid.is_valid():
			var gsize := Vector2i(int(px), 0)
			ts.font_render_glyph(rid, gsize, index)
			var off: Vector2 = ts.font_get_glyph_offset(rid, gsize, index)
			var sz: Vector2 = ts.font_get_glyph_size(rid, gsize, index)
			if sz.y > 0.0:
				var gy: float = g.get("y_off", 0.0)
				top = minf(top, off.y + gy)
				bottom = maxf(bottom, off.y + gy + sz.y)
		if adv > 0.0:
			centers.append(x + adv / 2.0)
		x += adv
	var deep := px * 0.075
	# ink box relative to the baseline; the drawn block adds the extrusion and the outlines.
	var o_deep := px * 0.30
	return {"line": line, "px": px, "asc": asc, "width": line.get_size().x, "centers": centers, "rtl": rtl,
		"ink_top": asc + top - o_deep * 0.5, "ink_h": (bottom - top) + deep + o_deep}


func _draw_line(s: Dictionary, at: Vector2, glow: float) -> void:
	var px := float(s.px)
	var line: TextLine = s.line
	var w := int(ceil(float(s.width))) + 2
	var centers: Array = s.centers
	var hues: Array = []
	for i in centers.size():
		hues.append(JuiceText.FESTIVE[i % JuiceText.FESTIVE.size()])
	var img := Image.create(maxi(w, 2), 1, false, Image.FORMAT_RGB8)
	for x in img.get_width():
		var j := 0
		var best := 1e9
		for i in centers.size():
			var d := absf(float(centers[i]) - x)
			if d < best:
				best = d
				j = i
		var hue: float = hues[j] if not hues.is_empty() else 45.0
		if s.rtl and centers.size() > 1:  # Arabic: blend toward the neighbour
			var c0: float = centers[j]
			var n := j + (1 if x > c0 else -1)
			if n >= 0 and n < centers.size():
				var c1: float = centers[n]
				var tt := clampf((x - c0) / (c1 - c0), 0.0, 0.5)
				var dh := fposmod(float(hues[n]) - hue + 180.0, 360.0) - 180.0
				hue = fposmod(hue + dh * tt, 360.0)
		img.set_pixel(x, 0, Color(hue / 360.0, 1.0, 0.0))
	var hue_tex := ImageTexture.create_from_image(img)
	var shader := Shader.new()
	shader.code = JuiceText.CANVAS_SHADER
	var base_y := at.y + float(s.asc)
	var deep := px * 0.075
	var layers := [[Vector2(0, deep), int(px * 0.30), 0.0], [Vector2(0, deep), 0, 1.0], [Vector2.ZERO, int(px * 0.09), 2.0], [Vector2.ZERO, 0, 3.0]]
	if glow > 0.0:  # a soft light halo so the title reads over a busy picture
		var halo := JuiceText.Ink.new()
		halo.line = line
		halo.at = at + Vector2(0, deep)
		halo.outline = int(px * 0.5)
		halo.modulate = Color(1, 1, 1, glow)
		add_child(halo)
	for L: Array in layers:
		var n := JuiceText.Ink.new()
		n.line = line
		n.at = at + (L[0] as Vector2)
		n.outline = L[1]
		var sm := ShaderMaterial.new()
		sm.shader = shader
		sm.set_shader_parameter("hue_tex", hue_tex)
		sm.set_shader_parameter("mode", L[2])
		sm.set_shader_parameter("y0", base_y - px * 0.62 - at.y)
		sm.set_shader_parameter("y1", base_y + px * 0.08 - at.y)
		sm.set_shader_parameter("w", float(w))
		n.material = sm
		# The shader reads VERTEX in the node's local space: draw at the origin, move the node.
		n.position = n.at
		n.at = Vector2.ZERO
		add_child(n)
