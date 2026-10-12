class_name Glass
extends RefCounted
## The shared frosted-glass look of every headset panel (MenuPanel, Panel3D, the
## intro's start panel; ToastCard draws the same recipe in its own shader).
##
## A real backdrop blur is too expensive on Quest, so the glass is faked once per
## change into a transparent SubViewport: a translucent cool-dark tint with a
## vertical gradient, a soft sheen across the top, two faint coloured glows (the
## "refracted" light), a fine frost grain, and a rim that is bright at the top and
## fades down. The page texture comes out premultiplied (the 2D canvas blends into
## a transparent target that way), so the quad blends it with blend_premul_alpha
## and cuts the rounded corners in its shader. Over the bright park the tint keeps
## text at a high contrast; in passthrough the room shows faintly through.
##
## Text: one type scale for every panel, Baloo at real weights (variable font),
## and every label is measured with the text server (Arabic shaped) and shrunk to
## its box, or wrapped onto lines that each fit. text() returns what it laid out
## so tests can check that nothing spills.

const TEXT := Color(0.97, 0.965, 0.955)
const SUB := Color(0.80, 0.82, 0.88)
const MUTED := Color(0.62, 0.65, 0.72)
const ACCENT := Color(1.0, 0.62, 0.36)
const ACCENT_SOFT := Color(1.0, 0.74, 0.55)
const INK := Color(0.08, 0.085, 0.11)

## The glass: top and bottom tint (alpha is the glass's opacity).
const TINT_TOP := Color(0.135, 0.15, 0.2, 0.80)
const TINT_BOTTOM := Color(0.055, 0.062, 0.088, 0.87)
## Cards on the glass.
const CARD := Color(1, 1, 1, 0.055)
const CARD_EDGE := Color(1, 1, 1, 0.11)
const CARD_HOT := Color(1, 1, 1, 0.12)
const CARD_HOT_EDGE := Color(1, 1, 1, 0.42)
const CARD_OFF := Color(1, 1, 1, 0.025)
const CARD_OFF_EDGE := Color(1, 1, 1, 0.06)
const ICON_REST := Color(0.42, 0.45, 0.56)

## Type scale (design pixels on a ~1200 px wide page).
const T_DISPLAY := 64
const T_TITLE := 40
const T_HEAD := 24
const T_LABEL := 24
const T_BODY := 24
const T_SMALL := 20
const T_TAB := 17
const MIN_SIZE := 14
## Font weights.
const W_TITLE := 800
const W_LABEL := 700
const W_BODY := 600

const QUAD_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, blend_premul_alpha, depth_draw_never, fog_disabled, shadows_disabled%s;
uniform sampler2D page : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 size_px = vec2(1200.0, 1000.0);
uniform float corner = 76.0;
uniform float opacity = 1.0;
void fragment() {
	// Four rotated-grid taps over the screen pixel's footprint: the page is minified
	// in the headset and seen at an angle.
	vec2 dx = dFdx(UV);
	vec2 dy = dFdy(UV);
	vec4 c = texture(page, UV + dx * 0.125 + dy * 0.375);
	c += texture(page, UV - dx * 0.375 + dy * 0.125);
	c += texture(page, UV - dx * 0.125 - dy * 0.375);
	c += texture(page, UV + dx * 0.375 - dy * 0.125);
	c *= 0.25;
	vec2 p = UV * size_px;
	vec2 q = abs(p - size_px * 0.5) - size_px * 0.5 + corner;
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner;
	float aa = max(fwidth(p.x), 0.75);
	float m = clamp(0.5 - d / aa, 0.0, 1.0) * opacity;
	ALBEDO = c.rgb * m;
	ALPHA = c.a * m;
}
"""

static var _fonts := {}
static var _noise: Texture2D
static var _glow: Texture2D
static var _shaders := {}


## Baloo (Arabic face, then Latin) at weight w.
static func font(w: int = W_BODY) -> Font:
	if not _fonts.has(w):
		# Each face gets its own variation (a variation of the shared font leaves its
		# fallback at 400).
		var tag := TextServerManager.get_primary_interface().name_to_tag("wght")
		var latin := FontVariation.new()
		latin.base_font = load("res://assets/fonts/baloo-latin.woff2")
		latin.variation_opentype = {tag: w}
		var arabic_face := (load("res://assets/fonts/baloo-arabic.woff2") as FontFile).duplicate() as FontFile
		arabic_face.fallbacks = []
		var f := FontVariation.new()
		f.base_font = arabic_face
		f.variation_opentype = {tag: w}
		f.fallbacks = [latin]
		_fonts[w] = f
	return _fonts[w]


static func direction_of(s: String) -> int:
	for i in s.length():
		var u := s.unicode_at(i)
		if u >= 0x0600 and u <= 0x06FF or u >= 0xFB50 and u <= 0xFEFF:
			return TextServer.DIRECTION_RTL
	return TextServer.DIRECTION_LTR


static func width(s: String, size: int, weight: int = W_BODY, dir: int = -1) -> float:
	var d := direction_of(s) if dir < 0 else dir
	return font(weight).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, d).x


## The largest size <= `size` (not below `min_size`) at which `s` fits `max_w`.
static func fit_size(s: String, size: int, max_w: float, weight: int = W_BODY, dir: int = -1, min_size: int = MIN_SIZE) -> int:
	var w := width(s, size, weight, dir)
	if w <= max_w:
		return size
	var n := maxi(min_size, int(floor(size * max_w / w)))
	while n > min_size and width(s, n, weight, dir) > max_w:
		n -= 1
	return n


## Greedy word wrap of `s` into lines no wider than max_w at `size` (a word wider
## than the line stays alone on its line).
static func wrap_lines(s: String, size: int, max_w: float, weight: int = W_BODY, dir: int = -1) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in s.split(" ", false):
		var next := word if line == "" else line + " " + word
		if line != "" and width(next, size, weight, dir) > max_w:
			out.append(line)
			line = word
		else:
			line = next
	if line != "":
		out.append(line)
	return out


## One line of text: baseline at y; align "center" | "left" | "right" around x;
## shrunk to max_w. ci may be null (measure only). Returns {s, size, w, max_w, x}.
static func text(ci: CanvasItem, s: String, x: float, y: float, size: int, color: Color, max_w: float, align := "center",
		weight: int = W_BODY, dir: int = -1, min_size: int = MIN_SIZE) -> Dictionary:
	if s == "":
		return {}
	var d := direction_of(s) if dir < 0 else dir
	var n := fit_size(s, size, max_w, weight, d, min_size)
	var f := font(weight)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, n, 3, d).x
	var px := x - w / 2.0 if align == "center" else x if align == "left" else x - w
	if ci != null:
		ci.draw_string(f, Vector2(px, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, n, color, 3, d)
	return {"s": s, "size": n, "w": w, "max_w": max_w, "x": px}


## The best place to break a short label in two (at a space or after a hyphen):
## the pair of lines whose wider line is narrowest; [s] when it cannot break.
static func split_two(s: String, size: int, weight: int = W_LABEL) -> PackedStringArray:
	var best := PackedStringArray([s])
	var best_w := INF
	for i in range(1, s.length() - 1):
		var a := ""
		var b := ""
		if s[i] == " ":
			a = s.substr(0, i)
			b = s.substr(i + 1)
		elif s[i - 1] == "-":
			a = s.substr(0, i)
			b = s.substr(i)
		else:
			continue
		var w := maxf(width(a, size, weight), width(b, size, weight))
		if w < best_w:
			best_w = w
			best = PackedStringArray([a, b])
	return best


## A paragraph centred on a block: wrapped to at most max_lines lines (each then
## shrunk to fit), centred vertically on `cy`. Returns the line records.
static func block(ci: CanvasItem, s: String, x: float, cy: float, size: int, color: Color, max_w: float, max_lines := 2,
		align := "center", weight: int = W_BODY, line_h := 1.3, dir: int = -1) -> Array:
	var n := size
	var lines := wrap_lines(s, n, max_w, weight, dir)
	while lines.size() > max_lines and n > MIN_SIZE:
		n -= 1
		lines = wrap_lines(s, n, max_w, weight, dir)
	if lines.size() > max_lines:
		# Still too many words: keep the first lines, put the rest on the last.
		var head: PackedStringArray = lines.slice(0, max_lines - 1)
		head.append(" ".join(lines.slice(max_lines - 1)))
		lines = head
	var step := n * line_h
	var y0 := cy - step * (lines.size() - 1) / 2.0 + n * 0.36
	var out: Array = []
	for i in lines.size():
		out.append(text(ci, lines[i], x, y0 + i * step, n, color, max_w, align, weight, dir))
	return out


# ---------------------------------------------------------------- glass

## The frost grain: a small tiling noise texture (mipmapped).
static func noise() -> Texture2D:
	if _noise == null:
		var n := 128
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var raw := PackedFloat32Array()
		raw.resize(n * n)
		for i in n * n:
			raw[i] = rng.randf()
		var data := PackedByteArray()
		data.resize(n * n * 2)
		for y in n:
			for x in n:
				# A light 3-tap blur so the grain reads as frost, not pixels.
				var v := (raw[y * n + x] * 2.0 + raw[y * n + (x + 1) % n] + raw[((y + 1) % n) * n + x]) / 4.0
				data[(y * n + x) * 2] = 255
				data[(y * n + x) * 2 + 1] = int(clampf((v - 0.25) * 2.0, 0.0, 1.0) * 255.0)
		var img := Image.create_from_data(n, n, false, Image.FORMAT_LA8, data)
		img.generate_mipmaps()
		_noise = ImageTexture.create_from_image(img)
	return _noise


## A soft round glow (white centre fading to nothing).
static func glow() -> Texture2D:
	if _glow == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 128
		t.height = 128
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_glow = t
	return _glow


## The outline of a rounded rectangle (clockwise from the top-left corner's start).
static func rounded(r: Rect2, radius: float, steps := 10) -> PackedVector2Array:
	var rad := minf(radius, minf(r.size.x, r.size.y) / 2.0)
	var out := PackedVector2Array()
	var cs := [[r.position.x + rad, r.position.y + rad, PI], [r.end.x - rad, r.position.y + rad, PI * 1.5],
		[r.end.x - rad, r.end.y - rad, 0.0], [r.position.x + rad, r.end.y - rad, PI * 0.5]]
	for c: Array in cs:
		for i in steps + 1:
			var t: float = c[2] + PI / 2.0 * i / steps
			out.append(Vector2(c[0] + cos(t) * rad, c[1] + sin(t) * rad))
	return out


static func _lerp_y(pts: PackedVector2Array, y0: float, y1: float, top: Color, bottom: Color) -> PackedColorArray:
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, clampf((p.y - y0) / maxf(1.0, y1 - y0), 0.0, 1.0)))
	return cols


## The glass sheet over rect r (normally the whole page; the quad cuts the corners).
## accent: the colour of the warm glow (a page may tint it).
static func panel(ci: CanvasItem, r: Rect2, radius: float, accent := ACCENT) -> void:
	if ci == null:
		return
	# Tint: a vertical gradient (exact under vertex interpolation: linear in y).
	var full := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	ci.draw_polygon(full, _lerp_y(full, r.position.y, r.end.y, TINT_TOP, TINT_BOTTOM))
	# Refracted light: a warm glow high on one side, a cool one low on the other.
	var g := glow()
	var s := maxf(r.size.x, r.size.y)
	ci.draw_texture_rect(g, Rect2(r.position + Vector2(-0.35, -0.55) * s, Vector2(s, s) * 1.0), false, Color(accent, 0.075))
	ci.draw_texture_rect(g, Rect2(r.end - Vector2(0.62, 0.5) * s, Vector2(s, s) * 1.05), false, Color(0.45, 0.65, 1.0, 0.06))
	# Frost grain.
	ci.draw_texture_rect(noise(), r, true, Color(1, 1, 1, 0.035))
	# Sheen: the top 38% brightens toward the rim.
	var band := Rect2(r.position, Vector2(r.size.x, r.size.y * 0.38))
	var top_pts := PackedVector2Array([band.position, Vector2(band.end.x, band.position.y), band.end, Vector2(band.position.x, band.end.y)])
	ci.draw_polygon(top_pts, _lerp_y(top_pts, band.position.y, band.end.y, Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.0)))
	rim(ci, r.grow(-1.5), radius - 1.5, 0.34, 0.07, 2.5)


## A rim around a rounded rect: `top` alpha at the top fading to `bottom`.
static func rim(ci: CanvasItem, r: Rect2, radius: float, top: float, bottom: float, w := 2.0, color := Color(1, 1, 1)) -> void:
	if ci == null:
		return
	var pts := rounded(r, radius)
	pts.append(pts[0])
	ci.draw_polyline_colors(pts, _lerp_y(pts, r.position.y, r.position.y + minf(r.size.y, 360.0), Color(color, top), Color(color, bottom)), w, true)


## A card on the glass: rest, hover, selected (accent), disabled; `tone` replaces
## the accent (lang, exit, an armed reset).
static func card(ci: CanvasItem, r: Rect2, radius: float, state := "rest", tone := ACCENT) -> void:
	if ci == null:
		return
	var pts := rounded(r, radius, 8)
	match state:
		"selected", "selected-hot":
			# A soft halo, then the tinted card and its accent edge.
			ci.draw_texture_rect(glow(), r.grow(26), false, Color(tone, 0.16))
			ci.draw_polygon(pts, _lerp_y(pts, r.position.y, r.end.y, Color(tone, 0.30 if state == "selected-hot" else 0.24), Color(tone, 0.16 if state == "selected-hot" else 0.11)))
			var closed := pts.duplicate()
			closed.append(pts[0])
			ci.draw_polyline(closed, Color(tone, 0.95), 2.5, true)
			rim(ci, r.grow(-3), radius - 3, 0.22, 0.0, 1.5)
		"done":
			ci.draw_polygon(pts, _lerp_y(pts, r.position.y, r.end.y, Color(tone, 0.14), Color(tone, 0.07)))
			var closed := pts.duplicate()
			closed.append(pts[0])
			ci.draw_polyline(closed, Color(tone, 0.45), 1.5, true)
		"hot":
			ci.draw_polygon(pts, _lerp_y(pts, r.position.y, r.end.y, Color(1, 1, 1, 0.15), Color(1, 1, 1, 0.09)))
			var closed := pts.duplicate()
			closed.append(pts[0])
			ci.draw_polyline(closed, Color(1, 1, 1, 0.42), 2.0, true)
		"off":
			ci.draw_polygon(pts, PackedColorArray([CARD_OFF]))
			var closed := pts.duplicate()
			closed.append(pts[0])
			ci.draw_polyline(closed, CARD_OFF_EDGE, 1.5, true)
		_:
			ci.draw_polygon(pts, _lerp_y(pts, r.position.y, r.end.y, Color(1, 1, 1, 0.075), Color(1, 1, 1, 0.04)))
			rim(ci, r, radius, 0.16, 0.06, 1.5)


# ---------------------------------------------------------------- the quad

## The material showing a premultiplied glass page on a quad (rounded corners cut).
static func material(tex: Texture2D, size_px: Vector2, corner: float, priority: int, depth_test := true) -> ShaderMaterial:
	var key := "nodepth" if not depth_test else "depth"
	if not _shaders.has(key):
		var sh := Shader.new()
		sh.code = QUAD_SHADER % ("" if depth_test else ", depth_test_disabled")
		_shaders[key] = sh
	var m := ShaderMaterial.new()
	m.shader = _shaders[key]
	m.render_priority = priority
	m.set_shader_parameter("page", tex)
	m.set_shader_parameter("size_px", size_px)
	m.set_shader_parameter("corner", corner)
	return m


## A transparent SubViewport for a glass page, rendered only on request.
static func viewport(size: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.disable_3d = true
	vp.transparent_bg = true
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	vp.canvas_item_default_texture_repeat = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_REPEAT_ENABLED
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.gui_disable_input = true
	return vp
