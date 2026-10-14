class_name MenuIcons
extends RefCounted
## The headset menu's icons (after src/reference/menu-art.ts drawMenuIcon), redrawn
## as two-tone vector art for the dark menu: a light line layer (strokes and small
## solid details) over a soft tint layer (the shapes' fills). Both layers are
## rasterised here with exact anti-aliasing (signed distances, no supersampling) on
## a 100-unit box centred on 0 (y down, like the canvas original), baked once into
## res://assets/ui/menu_icons.png (lines in the top half, tints in the bottom half)
## and drawn tinted, with mipmaps, by MenuPanel. Without the baked atlas an icon is
## rasterised on first use.

const CELL := 128  # pixels per icon in the atlas
const SPAN := 112.0  # design units across a cell (-56..56)
const COLS := 10
const ATLAS := "res://assets/ui/menu_icons.png"
const LW := 6.2  # default line width (design units)

const IDS := [
	"goal", "hoop", "window", "cans", "bowling", "bricks", "fair", "climb", "rain", "balance",
	"ricochet", "maze", "modes", "character", "play", "world", "challenges", "system", "about", "close",
	"jelly", "fur", "bubble", "mini", "original", "check", "none", "party", "glasses", "cap",
	"flower", "crown", "headphones", "scarf", "aviator", "woodhat", "starGlasses", "beanie", "lock", "trigger",
	"hand", "sling", "bolt", "firework", "auto", "reset", "day", "dusk", "night", "dawn",
	"weather-rain", "snow", "place", "exit", "up", "down", "star", "mole", "mr", "vr",
	"lang", "invasion", "slime", "meteor", "castle", "giant", "gallery", "frenzy",
	"confetti", "bouncy", "laser", "boomerang", "glob", "rocket", "lightning", "dallah",
	"shemagh", "ghutra", "taqiyah", "kufi", "falcon", "jasmine", "headband", "astronaut", "pirate", "chef",
	"dino", "halo", "bunny", "wizard", "viking", "propeller", "bowtie", "gradcap",
	"umbrella", "goldShades", "turban", "taifRose", "farwa", "diving", "lantern", "palm", "misbaha", "karak",
	"sadu", "medal", "goldAgal", "bisht", "trophy", "goldStar", "goldPal", "worldCup",
]
## The start screen's large icons, baked again at HI_CELL pixels.
const HI_IDS := ["mr", "vr", "lang", "world"]
const HI_CELL := 256
const HI_ATLAS := "res://assets/ui/start_icons.png"
const ALIAS := {"appearance": "character", "accessories": "party", "palette": "modes", "trophy": "challenges", "clear": "day"}

static var _cache := {}  # id -> [line: Texture2D, tint: Texture2D]
static var _atlas: Image
static var _atlas_tried := false
static var _hi_cache := {}
static var _hi_atlas: Image
static var _hi_tried := false


## The start screen's large textures of an icon (rasterised now if not baked).
static func textures_hi(id: String) -> Array:
	if not HI_IDS.has(id):
		return textures(id)
	if _hi_cache.has(id):
		return _hi_cache[id]
	if not _hi_tried:
		_hi_tried = true
		if ResourceLoader.exists(HI_ATLAS):
			var t: Texture2D = load(HI_ATLAS)
			if t != null:
				_hi_atlas = t.get_image()
				if _hi_atlas.is_compressed():
					_hi_atlas.decompress()
				if _hi_atlas.get_size() != Vector2i(HI_IDS.size() * HI_CELL, HI_CELL * 2):
					_hi_atlas = null
	var imgs: Array[Image] = []
	if _hi_atlas != null:
		var i := HI_IDS.find(id)
		imgs = [_hi_atlas.get_region(Rect2i(i * HI_CELL, 0, HI_CELL, HI_CELL)), _hi_atlas.get_region(Rect2i(i * HI_CELL, HI_CELL, HI_CELL, HI_CELL))]
	else:
		imgs = raster(shapes(id), HI_CELL)
	var pair: Array = []
	for img: Image in imgs:
		if img.get_format() != Image.FORMAT_LA8:
			img.convert(Image.FORMAT_LA8)
		img.generate_mipmaps()
		pair.append(ImageTexture.create_from_image(img))
	_hi_cache[id] = pair
	return pair


## draw() with the large textures.
static func draw_hi(ci: CanvasItem, id: String, c: Vector2, size: float, line_col: Color, tint_col: Color) -> void:
	var pair := textures_hi(id)
	if pair.size() < 2 or ci == null:
		return
	var s := size * SPAN / 100.0
	var r := Rect2(c - Vector2(s, s) / 2.0, Vector2(s, s))
	if tint_col.a > 0.0:
		ci.draw_texture_rect(pair[1], r, false, tint_col)
	ci.draw_texture_rect(pair[0], r, false, line_col)


## The line and tint textures of an icon (id after the aliases), or [] if none can be made.
static func textures(id: String) -> Array:
	var key: String = ALIAS.get(id, id)
	if not IDS.has(key):
		key = "star"
	if _cache.has(key):
		return _cache[key]
	var pair: Array = []
	var line: Image = null
	var tint: Image = null
	var atlas := _load_atlas()
	if atlas != null:
		var i := IDS.find(key)
		var at := Vector2i((i % COLS) * CELL, (i / COLS) * CELL)
		line = atlas.get_region(Rect2i(at, Vector2i(CELL, CELL)))
		tint = atlas.get_region(Rect2i(at + Vector2i(0, rows() * CELL), Vector2i(CELL, CELL)))
	else:
		var imgs := raster(shapes(key), CELL)
		line = imgs[0]
		tint = imgs[1]
	for img: Image in [line, tint]:
		if img.get_format() != Image.FORMAT_LA8:
			img.convert(Image.FORMAT_LA8)
		img.generate_mipmaps()
		pair.append(ImageTexture.create_from_image(img))
	_cache[key] = pair
	return pair


static func rows() -> int:
	return int(ceil(IDS.size() / float(COLS)))


static func _load_atlas() -> Image:
	if _atlas_tried:
		return _atlas
	_atlas_tried = true
	if ResourceLoader.exists(ATLAS):
		var t: Texture2D = load(ATLAS)
		if t != null:
			_atlas = t.get_image()
	if _atlas != null and _atlas.is_compressed():
		_atlas.decompress()
	if _atlas != null and _atlas.get_size() != Vector2i(COLS * CELL, rows() * CELL * 2):
		_atlas = null
	return _atlas


## Draws icon `id` centred at `c`, `size` design units for the 100-unit box
## (the original's size argument), lines in `line_col` over tints in `tint_col`.
static func draw(ci: CanvasItem, id: String, c: Vector2, size: float, line_col: Color, tint_col: Color) -> void:
	var pair := textures(id)
	if pair.size() < 2 or ci == null:
		return
	var s := size * SPAN / 100.0
	var r := Rect2(c - Vector2(s, s) / 2.0, Vector2(s, s))
	if tint_col.a > 0.0:
		ci.draw_texture_rect(pair[1], r, false, tint_col)
	ci.draw_texture_rect(pair[0], r, false, line_col)


## Bakes every icon into the atlas PNG (top half lines, bottom half tints).
static func bake(path := ATLAS) -> Error:
	var w := COLS * CELL
	var h := rows() * CELL
	var atlas := Image.create(w, h * 2, false, Image.FORMAT_LA8)
	atlas.fill(Color(1, 1, 1, 0))
	for i in IDS.size():
		var imgs := raster(shapes(IDS[i]), CELL)
		var at := Vector2i((i % COLS) * CELL, (i / COLS) * CELL)
		atlas.blit_rect(imgs[0], Rect2i(0, 0, CELL, CELL), at)
		atlas.blit_rect(imgs[1], Rect2i(0, 0, CELL, CELL), at + Vector2i(0, h))
	var err := atlas.save_png(ProjectSettings.globalize_path(path) if path.begins_with("res://") else path)
	if err != OK or path != ATLAS:
		return err
	var hi := Image.create(HI_IDS.size() * HI_CELL, HI_CELL * 2, false, Image.FORMAT_LA8)
	hi.fill(Color(1, 1, 1, 0))
	for i in HI_IDS.size():
		var imgs := raster(shapes(HI_IDS[i]), HI_CELL)
		hi.blit_rect(imgs[0], Rect2i(0, 0, HI_CELL, HI_CELL), Vector2i(i * HI_CELL, 0))
		hi.blit_rect(imgs[1], Rect2i(0, 0, HI_CELL, HI_CELL), Vector2i(i * HI_CELL, HI_CELL))
	return hi.save_png(ProjectSettings.globalize_path(HI_ATLAS))


# ---------------------------------------------------------------- rasteriser

## [line, tint] FORMAT_LA8 images (white, coverage in alpha) of `ops` at px x px.
static func raster(ops: Array, px: int) -> Array[Image]:
	var line := PackedFloat32Array()
	var tint := PackedFloat32Array()
	line.resize(px * px)
	tint.resize(px * px)
	var k := px / SPAN
	for op: Dictionary in ops:
		var src: PackedVector2Array = op.p
		var p := PackedVector2Array()
		p.resize(src.size())
		for i in src.size():
			p[i] = (src[i] + Vector2(SPAN, SPAN) / 2.0) * k
		var kind: String = op.k
		if kind == "s":
			_stroke(line, px, p, op.c, float(op.w) * k / 2.0)
		elif kind == "f":
			_fill(tint, tint, px, p, 0.0, false)
		elif kind == "S":
			_fill(line, line, px, p, 0.0, false)
		elif kind == "x":
			_fill(line, tint, px, p, float(op.g) * k, true)
	var out: Array[Image] = []
	for buf: PackedFloat32Array in [line, tint]:
		var data := PackedByteArray()
		data.resize(px * px * 2)
		for i in px * px:
			data[i * 2] = 255
			data[i * 2 + 1] = int(round(clampf(buf[i], 0.0, 1.0) * 255.0))
		out.append(Image.create_from_data(px, px, false, Image.FORMAT_LA8, data))
	return out


static func _seg_dist(q: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	var t := 0.0 if l2 < 1e-9 else clampf((q - a).dot(ab) / l2, 0.0, 1.0)
	return q.distance_to(a + ab * t)


## Round-capped, round-joined polyline of half width hw (pixels).
static func _stroke(buf: PackedFloat32Array, px: int, p: PackedVector2Array, closed: bool, hw: float) -> void:
	var n := p.size()
	var segs := n if closed else n - 1
	if n == 1:
		segs = 1
	for s in segs:
		var a := p[s]
		var b := p[(s + 1) % n]
		var x0 := maxi(0, int(floor(minf(a.x, b.x) - hw - 1.0)))
		var x1 := mini(px - 1, int(ceil(maxf(a.x, b.x) + hw + 1.0)))
		var y0 := maxi(0, int(floor(minf(a.y, b.y) - hw - 1.0)))
		var y1 := mini(px - 1, int(ceil(maxf(a.y, b.y) + hw + 1.0)))
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var cov := clampf(hw - _seg_dist(Vector2(x + 0.5, y + 0.5), a, b) + 0.5, 0.0, 1.0)
				var i := y * px + x
				if cov > buf[i]:
					buf[i] = cov


## A filled polygon (nonzero winding), grown by `grow` pixels. cut: clears both
## buffers under it instead of painting.
static func _fill(a_buf: PackedFloat32Array, b_buf: PackedFloat32Array, px: int, p: PackedVector2Array, grow: float, cut: bool) -> void:
	var n := p.size()
	if n < 3:
		return
	var lo := p[0]
	var hi := p[0]
	for v in p:
		lo = lo.min(v)
		hi = hi.max(v)
	var x0 := maxi(0, int(floor(lo.x - grow - 1.0)))
	var x1 := mini(px - 1, int(ceil(hi.x + grow + 1.0)))
	var y0 := maxi(0, int(floor(lo.y - grow - 1.0)))
	var y1 := mini(px - 1, int(ceil(hi.y + grow + 1.0)))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var q := Vector2(x + 0.5, y + 0.5)
			var wn := 0
			var d := 1e9
			for e in n:
				var a := p[e]
				var b := p[(e + 1) % n]
				d = minf(d, _seg_dist(q, a, b))
				var cr := (b.x - a.x) * (q.y - a.y) - (q.x - a.x) * (b.y - a.y)
				if a.y <= q.y:
					if b.y > q.y and cr > 0.0:
						wn += 1
				elif b.y <= q.y and cr < 0.0:
					wn -= 1
			var sd := d if wn != 0 else -d
			var cov := clampf(sd + grow + 0.5, 0.0, 1.0)
			if cov <= 0.0:
				continue
			var i := y * px + x
			if cut:
				a_buf[i] *= 1.0 - cov
				b_buf[i] *= 1.0 - cov
			elif cov > a_buf[i]:
				a_buf[i] = cov


# ---------------------------------------------------------------- shape helpers

## Collects drawing ops; `xf` transforms every following shape (rotated groups).
class Pen:
	var ops: Array = []
	var w := MenuIcons.LW
	var xf := Transform2D.IDENTITY

	## A line (closed: a loop).
	func s(p: PackedVector2Array, closed := false, width := -1.0) -> void:
		ops.append({"k": "s", "p": xf * p, "c": closed, "w": w if width < 0.0 else width})

	## A soft tint fill.
	func f(p: PackedVector2Array) -> void:
		ops.append({"k": "f", "p": xf * p})

	## A solid fill on the line layer (eyes, dots, small solid parts).
	func ink(p: PackedVector2Array) -> void:
		ops.append({"k": "S", "p": xf * p})

	## Clears both layers under a shape grown by `grow` units (a knock-out gap).
	func cut(p: PackedVector2Array, grow := 0.0) -> void:
		ops.append({"k": "x", "p": xf * p, "g": grow})

	## Tint fill and outline.
	func sf(p: PackedVector2Array, width := -1.0) -> void:
		f(p)
		s(p, true, width)

	## Dahrooj's face: a tinted ball with two eyes, cut out of what lies under it.
	func face(x: float, y: float, r: float, gap := 4.5) -> void:
		var c := MenuIcons.ell(x, y, r, r)
		cut(c, gap)
		sf(c)
		cut(MenuIcons.ell(x - r * 0.31, y - r * 0.04, r * 0.14, r * 0.2, 16))
		cut(MenuIcons.ell(x + r * 0.31, y - r * 0.04, r * 0.14, r * 0.2, 16))


static func P(a: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v: Array in a:
		out.append(Vector2(v[0], v[1]))
	return out


static func ell(cx: float, cy: float, rx: float, ry: float, n := 56) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var t := TAU * i / n
		out.append(Vector2(cx + cos(t) * rx, cy + sin(t) * ry))
	return out


## A canvas arc (y down): clockwise from a0 to a1 unless ccw.
static func arc(cx: float, cy: float, r: float, a0: float, a1: float, ccw := false) -> PackedVector2Array:
	var sweep := fposmod(a0 - a1, TAU) if ccw else fposmod(a1 - a0, TAU)
	if sweep < 1e-4:
		sweep = TAU
	var n := maxi(4, int(ceil(sweep / TAU * 64.0)))
	var out := PackedVector2Array()
	for i in n + 1:
		var t := a0 + (-sweep if ccw else sweep) * i / n
		out.append(Vector2(cx + cos(t) * r, cy + sin(t) * r))
	return out


static func rr(x: float, y: float, w: float, h: float, r: float) -> PackedVector2Array:
	r = minf(r, minf(w, h) / 2.0)
	var out := PackedVector2Array()
	var cs := [[x + w - r, y + r, -PI / 2.0], [x + w - r, y + h - r, 0.0], [x + r, y + h - r, PI / 2.0], [x + r, y + r, PI]]
	for c: Array in cs:
		for i in 9:
			var t: float = c[2] + PI / 2.0 * i / 8.0
			out.append(Vector2(c[0] + cos(t) * r, c[1] + sin(t) * r))
	return out


static func star(x: float, y: float, r: float, inner := 0.44) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 10:
		var a := i * PI / 5.0 - PI / 2.0
		var s := r * inner if i % 2 == 1 else r
		out.append(Vector2(x + cos(a) * s, y + sin(a) * s))
	return out


## Appends a cubic Bezier from the last point of `p`.
static func bez(p: PackedVector2Array, c1: Vector2, c2: Vector2, e: Vector2, n := 20) -> PackedVector2Array:
	var a := p[p.size() - 1]
	for i in range(1, n + 1):
		var t := float(i) / n
		var u := 1.0 - t
		p.append(a * u * u * u + c1 * 3.0 * u * u * t + c2 * 3.0 * u * t * t + e * t * t * t)
	return p


# ---------------------------------------------------------------- the icons

static func shapes(id: String) -> Array:
	var d := Pen.new()
	match id:
		"goal":
			d.f(P([[-43, -33], [27, -33], [39, -20], [39, 5], [27, 5], [27, 24], [-32, 24], [-32, 31], [-43, 31]]))
			d.s(P([[-32, -20], [-32, 24], [27, 24]]), false, 4.0)
			for x in [-14, 6]:
				d.s(P([[x, -20], [x, 24]]), false, 4.0)
			d.s(P([[-32, 2], [27, 2]]), false, 4.0)
			d.s(P([[-43, 31], [-43, -33], [27, -33], [27, 22]]))
			d.s(P([[-43, -33], [-32, -20], [39, -20], [27, -33]]), false, 4.5)
			d.s(P([[39, -20], [39, 8]]), false, 4.5)
			d.face(29, 28, 16)
		"hoop":
			d.sf(rr(-40, -40, 66, 40, 8))
			d.s(rr(-19, -26, 26, 20, 3), true, 4.5)
			d.s(P([[-29, 10], [-21, 40], [8, 40], [17, 10]]), false, 4.5)
			d.s(P([[-19, 11], [2, 38]]), false, 4.0)
			d.s(P([[7, 11], [-13, 38]]), false, 4.0)
			d.s(ell(-6, 7, 26, 6))
			d.face(32, -17, 14)
		"window":
			d.sf(rr(-31, -40, 62, 72, 7))
			d.s(P([[0, -40], [0, 32]]))
			d.s(P([[-31, -4], [31, -4]]))
			d.s(P([[-21, -29], [-12, -20]]), false, 4.5)
			d.s(P([[-21, -18], [-17, -14]]), false, 4.5)
			d.s(P([[11, 8], [21, 18]]), false, 4.5)
			d.sf(rr(-42, 33, 84, 10, 4))
		"bricks":
			var bs := [[-42, 18], [-13, 18], [16, 18], [-28, -6], [1, -6], [-14, -30]]
			for b: Array in bs:
				d.sf(rr(b[0], b[1], 26, 20, 4))
			d.s(P([[24, -27], [34, -38]]), false, 4.5)
			d.s(P([[33, -14], [44, -17]]), false, 4.5)
			d.ink(rr(38, -30, 6, 6, 1.5))
		"cans":
			for c: Array in [[-36, 4], [8, 4], [-14, -38]]:
				var x: float = c[0]
				var y: float = c[1]
				var body := P([[x, y + 6], [x, y + 29]])
				bez(body, Vector2(x, y + 37), Vector2(x + 28, y + 37), Vector2(x + 28, y + 29))
				body.append(Vector2(x + 28, y + 6))
				var shape := body.duplicate()
				for i in range(1, 17):
					var t := -PI * i / 16.0
					shape.append(Vector2(x + 14 + cos(t) * 14, y + 6 + sin(t) * 5))
				d.f(shape)
				d.s(body)
				d.s(ell(x + 14, y + 6, 14, 5))
				d.s(P([[x + 1, y + 20], [x + 27, y + 20]]), false, 4.0)
		"bowling":
			var pin := P([[-27, 40]])
			bez(pin, Vector2(-41, 15), Vector2(-21, 3), Vector2(-26, -15))
			bez(pin, Vector2(-33, -45), Vector2(-3, -45), Vector2(-10, -15))
			bez(pin, Vector2(-15, 3), Vector2(5, 15), Vector2(-9, 40))
			d.sf(pin)
			d.s(P([[-25, -9], [-11, -9]]), false, 4.5)
			d.s(P([[-26, -1], [-10, -1]]), false, 4.5)
			d.sf(ell(23, 22, 21, 21))
			for h: Array in [[18, 13], [28, 15], [20, 24]]:
				d.ink(ell(h[0], h[1], 3.4, 3.4, 16))
		"climb":
			d.sf(P([[-44, 37], [-13, -21], [18, 37]]))
			d.cut(P([[3, 4], [21, -16], [47, 37], [18, 37]]), 3.0)
			d.sf(P([[3, 4], [21, -16], [47, 37], [18, 37]]))
			d.s(P([[-23, -3], [-13, 5], [-4, -3]]), false, 4.5)
			d.s(P([[-13, -21], [-13, -46]]), false, 4.5)
			d.ink(P([[-13, -47], [9, -39], [-13, -30]]))
		"fair":
			d.f(P([[0, -36], [-42, -3], [-16, -3]]))
			d.f(P([[0, -36], [16, -3], [42, -3]]))
			d.s(P([[-42, -3], [0, -36], [42, -3]]), true)
			d.s(P([[0, -36], [-16, -3]]), false, 4.5)
			d.s(P([[0, -36], [16, -3]]), false, 4.5)
			d.s(P([[-34, -3], [-37, 38], [-13, 38], [0, 6], [13, 38], [37, 38], [34, -3]]))
			d.s(P([[0, -36], [0, -50]]), false, 4.5)
			d.ink(P([[0, -51], [17, -45], [0, -39]]))
		"rain":
			d.s(P([[-28, -36], [-28, -18]]), false, 4.5)
			d.s(P([[8, -48], [8, -38]]), false, 4.5)
			d.s(P([[38, -16], [38, 6]]), false, 4.5)
			d.s(P([[-7, 22], [-7, 40]]), false, 4.5)
			d.face(-27, 9, 14)
			d.face(9, -16, 16)
			d.face(28, 31, 12)
		"balance":
			d.xf = Transform2D(-0.16, Vector2.ZERO)
			d.sf(rr(-36, -18, 72, 52, 10))
			d.s(P([[-24, 11], [0, 11], [0, -6], [24, -6]]), false, 4.5)
			d.sf(rr(-49, -6, 12, 28, 5))
			d.sf(rr(37, -6, 12, 28, 5))
			d.face(-18, -27, 12)
			d.xf = Transform2D.IDENTITY
		"ricochet":
			d.s(P([[-30, 9], [-30, -24], [30, -24], [30, 26]]), false, 4.5)
			d.s(P([[19, 15], [30, 27], [41, 15]]), false, 5.0)
			d.s(P([[-45, -12], [-18, -39]]), false, 8.5)
			d.s(P([[18, -39], [45, -12]]), false, 8.5)
			d.face(-30, 30, 12)
			d.s(P([[18, 42], [42, 42]]), false, 8.5)
		"maze":
			d.sf(rr(-42, -42, 84, 84, 11))
			d.s(P([[-42, -14], [-14, -14], [-14, 13], [13, 13], [13, 42]]))
			d.s(P([[13, -42], [13, -14], [42, -14]]))
			d.s(P([[-42, 16], [-28, 16]]))
			d.face(-27, -28, 8, 0.0)
			d.ink(star(28, 27, 10, 0.48))
		"modes", "palette":
			for x in [-31, 7]:
				for y in [-31, 7]:
					var sq := rr(x, y, 24, 24, 6)
					if (x < 0) == (y < 0):
						d.f(sq)
					d.s(sq, true)
		"character", "mini", "jelly", "bubble":
			d.sf(ell(0, 3, 36, 36))
			d.s(arc(0, 3, 26, PI * 1.08, PI * 1.38), false, 4.5)
			d.cut(ell(-12, 4, 4.4, 6.6, 20))
			d.cut(ell(12, 4, 4.4, 6.6, 20))
			if id == "jelly":
				d.xf = Transform2D(-0.55, Vector2(20, -24))
				d.cut(rr(-17, -5, 34, 10, 4), 3.0)
				d.sf(rr(-17, -5, 34, 10, 4), 4.5)
				d.s(P([[-4, -4], [-4, 4]]), false, 3.5)
				d.s(P([[4, -4], [4, 4]]), false, 3.5)
				d.xf = Transform2D.IDENTITY
			if id == "bubble":
				d.ink(ell(-15, -19, 7, 4, 20))
				d.ink(ell(18, 23, 3.4, 3.4, 16))
				d.s(ell(36, -32, 7, 7, 24), true, 4.0)
		"fur":
			var pts := PackedVector2Array()
			for i in 40:
				var a := i * PI / 20.0
				var r := 31.0 if i % 2 == 1 else 37.0
				pts.append(Vector2(cos(a) * r, sin(a) * r + 4))
			d.sf(pts)
			d.cut(ell(-12, 5, 4.4, 6.6, 20))
			d.cut(ell(12, 5, 4.4, 6.6, 20))
			var bow := P([[-4, -33], [-23, -45], [-23, -21], [-4, -33], [4, -33], [23, -45], [23, -21], [4, -33]])
			d.cut(P([[-4, -33], [-23, -45], [-23, -21]]), 3.5)
			d.cut(P([[4, -33], [23, -45], [23, -21]]), 3.5)
			d.f(P([[-4, -33], [-23, -45], [-23, -21]]))
			d.f(P([[4, -33], [23, -45], [23, -21]]))
			d.s(bow, false, 5.0)
			d.ink(ell(0, -33, 4.5, 4.5, 16))
		"original":
			d.sf(ell(0, 3, 31, 31))
			d.cut(ell(-11, 4, 4.2, 6.2, 20))
			d.cut(ell(11, 4, 4.2, 6.2, 20))
			d.s(arc(0, 3, 44, PI * 0.7, PI * 1.8))
			d.s(P([[15, -46], [30, -33], [13, -26]]))
		"check":
			d.s(P([[-26, 1], [-7, 21], [29, -23]]), false, 8.5)
		"none":
			d.s(ell(0, 0, 34, 34), true)
			d.s(P([[-23, 24], [23, -24]]))
		"party":
			d.sf(P([[-31, 36], [0, -38], [31, 36]]))
			d.s(P([[-38, 40], [38, 40]]))
			d.s(P([[-15, 0], [15, 0]]), false, 5.0)
			d.s(P([[-22, 18], [22, 18]]), false, 5.0)
			d.cut(ell(0, -44, 7, 7), 2.5)
			d.ink(ell(0, -44, 7, 7, 24))
		"glasses":
			d.sf(rr(-44, -15, 36, 30, 9))
			d.sf(rr(8, -15, 36, 30, 9))
			d.s(P([[-8, -3], [8, -3]]))
			d.s(P([[-37, -8], [-30, -8]]), false, 3.5)
			d.s(P([[15, -8], [22, -8]]), false, 3.5)
		"starGlasses":
			d.sf(star(-23, 0, 23, 0.5))
			d.sf(star(23, 0, 23, 0.5))
			d.s(P([[-8, -2], [8, -2]]))
		"cap":
			var dome := arc(0, 4, 29, PI, 0)
			d.sf(dome)
			d.sf(rr(-31, 3, 72, 11, 5))
			d.ink(ell(0, -26, 4, 3, 16))
			d.s(P([[0, -24], [0, 2]]), false, 3.5)
		"woodhat":
			d.sf(rr(-23, -36, 46, 52, 5))
			d.sf(rr(-41, 14, 82, 9, 4))
			d.s(P([[-23, 1], [23, 1]]), false, 5.0)
			d.s(P([[-10, -26], [-10, -12]]), false, 3.5)
			d.s(P([[8, -24], [8, -14]]), false, 3.5)
		"flower":
			for i in 5:
				var a := i * TAU / 5.0 - PI / 2.0
				d.f(ell(cos(a) * 22, sin(a) * 22, 13, 13))
			for i in 5:
				var a := i * TAU / 5.0 - PI / 2.0
				d.s(arc(cos(a) * 22, sin(a) * 22, 13, a - PI * 0.62, a + PI * 0.62), false, 5.0)
			d.cut(ell(0, 0, 11, 11), 2.0)
			d.ink(ell(0, 0, 10, 10, 32))
		"crown":
			d.sf(P([[-36, 25], [-38, -22], [-17, -5], [0, -34], [17, -5], [38, -22], [36, 25]]))
			d.s(P([[-36, 13], [36, 13]]))
			for j: Array in [[-38, -27], [0, -40], [38, -27]]:
				d.ink(ell(j[0], j[1], 4.5, 4.5, 16))
			d.ink(ell(0, 0, 4.5, 4.5, 16))
		"headphones":
			d.s(arc(0, 2, 33, PI, 0))
			d.sf(rr(-42, -4, 16, 34, 7))
			d.sf(rr(26, -4, 16, 34, 7))
			d.s(P([[-26, 4], [-26, 22]]), false, 4.0)
			d.s(P([[26, 4], [26, 22]]), false, 4.0)
		"scarf":
			var tail := P([[4, -2], [22, -2], [29, 34], [11, 37]])
			d.sf(tail)
			for x in [15, 23]:
				d.s(P([[x, 37], [x + 1, 45]]), false, 4.0)
			var band := arc(0, -52, 46, PI * 0.3, PI * 0.7)
			var inner := arc(0, -52, 26, PI * 0.7, PI * 0.3, true)
			band.append_array(inner)
			d.cut(band, 3.0)
			d.sf(band)
			d.s(P([[-14, -14], [-11, -2]]), false, 3.5)
			d.s(P([[2, -12], [2, 0]]), false, 3.5)
		"aviator":
			var helm := arc(0, 2, 33, PI, 0)
			helm.append(Vector2(33, 28))
			helm.append(Vector2(23, 28))
			helm.append(Vector2(23, 6))
			helm.append(Vector2(-23, 6))
			helm.append(Vector2(-23, 28))
			helm.append(Vector2(-33, 28))
			d.sf(helm)
			d.cut(rr(-27, -14, 24, 20, 8), 3.0)
			d.cut(rr(3, -14, 24, 20, 8), 3.0)
			d.s(rr(-27, -14, 24, 20, 8), true)
			d.s(rr(3, -14, 24, 20, 8), true)
			d.s(P([[-3, -5], [3, -5]]), false, 4.0)
		"beanie":
			var dome := arc(0, 8, 31, PI, TAU)
			d.sf(dome)
			d.cut(ell(0, -35, 11, 11), 3.0)
			d.sf(ell(0, -35, 10, 10))
			d.cut(rr(-37, 7, 74, 24, 7), 3.0)
			d.sf(rr(-37, 7, 74, 24, 7))
			for x in [-23, -8, 8, 23]:
				d.s(P([[x, 14], [x, 24]]), false, 4.0)
			d.s(P([[-18, -3], [-13, -14], [-8, -3]]), false, 4.0)
			d.s(P([[8, -3], [13, -14], [18, -3]]), false, 4.0)
		"lock":
			d.s(arc(0, -13, 18, PI, 0))
			d.s(P([[-18, -13], [-18, -4]]))
			d.s(P([[18, -13], [18, -4]]))
			d.sf(rr(-27, -6, 54, 42, 9))
			d.ink(ell(0, 10, 5, 5, 16))
			d.s(P([[0, 11], [0, 22]]), false, 5.0)
		"trigger":
			d.sf(rr(-22, -36, 44, 76, 18))
			d.cut(ell(0, -15, 12, 12), 1.5)
			d.s(ell(0, -15, 11, 11), true)
			d.ink(ell(0, -15, 4, 4, 16))
			d.s(P([[0, 11], [12, 22]]))
		"hand":
			d.sf(P([[-28, 18], [-36, -2], [-28, -9], [-15, 3], [-15, -30], [-7, -34], [-2, -9], [3, -39], [12, -37], [14, -9], [22, -28], [29, -25], [26, 4], [33, -7], [40, -3], [33, 24], [13, 38], [-9, 36]]))
		"sling":
			d.s(P([[-7, 40], [-7, -3], [-32, -34]]))
			d.s(P([[7, 40], [7, -3], [32, -34]]))
			d.s(P([[-7, 40], [7, 40]]))
			d.s(P([[-32, -34], [0, -13], [32, -34]]), false, 4.0)
			d.face(0, -14, 10, 2.5)
		"bolt":
			d.sf(P([[8, -43], [-29, 5], [-3, 5], [-12, 44], [32, -12], [7, -12]]))
		"firework":
			d.xf = Transform2D(0.6, Vector2.ZERO)
			d.sf(rr(-14, -20, 28, 50, 4))
			d.ink(P([[-18, -20], [0, -42], [18, -20]]))
			d.s(P([[-14, 0], [14, 0]]), false, 4.0)
			d.s(P([[0, 30], [0, 46]]), false, 4.5)
			d.xf = Transform2D.IDENTITY
			d.ink(star(33, -32, 10, 0.45))
			d.s(P([[18, -44], [21, -40]]), false, 3.5)
			d.s(P([[44, -16], [40, -19]]), false, 3.5)
		"auto", "reset":
			if id == "auto":
				var half := arc(0, 0, 17, -PI / 2.0, PI / 2.0)
				d.f(half)
				d.s(P([[0, -12], [0, 0], [9, 6]]), false, 4.5)
			d.s(arc(0, 0, 32, -PI * 0.35, PI * 1.17))
			d.s(P([[-42, -8], [-28, -22], [-13, -11]]))
		"day":
			d.sf(ell(0, 0, 21, 21))
			for i in 8:
				var a := i * PI / 4.0
				d.s(P([[cos(a) * 32, sin(a) * 32], [cos(a) * 42, sin(a) * 42]]))
		"night":
			var moon := arc(0, 0, 34, PI * 1.48, PI * 0.25, true)
			bez(moon, Vector2(-14, 19), Vector2(-19, -13), Vector2(0, -34))
			d.sf(moon)
			d.ink(star(28, -24, 9, 0.46))
		"dawn", "dusk":
			var sun := arc(0, 13, 25, PI, TAU)
			d.sf(sun)
			d.s(P([[-42, 14], [42, 14]]))
			d.s(P([[-28, 30], [28, 30]]))
			d.s(P([[0, -20], [0, -40]]), false, 5.0)
			d.s(P([[-8, -31], [0, -40], [8, -31]]) if id == "dawn" else P([[-8, -29], [0, -20], [8, -29]]), false, 5.0)
		"weather-rain", "snow":
			var cloud := P([[-29, 4]])
			bez(cloud, Vector2(-55, -1), Vector2(-39, -31), Vector2(-20, -23))
			bez(cloud, Vector2(-12, -51), Vector2(26, -41), Vector2(27, -18))
			bez(cloud, Vector2(51, -21), Vector2(51, 6), Vector2(29, 6))
			d.sf(cloud)
			for x in [-26, 0, 26]:
				if id == "snow":
					d.s(P([[x, 22], [x, 38]]), false, 4.0)
					d.s(P([[x - 7, 26], [x + 7, 34]]), false, 4.0)
					d.s(P([[x + 7, 26], [x - 7, 34]]), false, 4.0)
				else:
					d.s(P([[x + 3, 20], [x - 3, 36]]), false, 5.0)
		"place":
			d.s(ell(0, 36, 30, 8), true, 4.5)
			var pin := P([[0, 33]])
			bez(pin, Vector2(-52, -14), Vector2(-22, -45), Vector2(0, -42))
			bez(pin, Vector2(22, -45), Vector2(52, -14), Vector2(0, 33))
			d.cut(pin, 3.5)
			d.sf(pin)
			d.cut(ell(0, -16, 10, 10), 0.0)
			d.s(ell(0, -16, 10, 10), true)
		"exit":
			d.f(P([[-31, -37], [5, -37], [5, 37], [-31, 37]]))
			d.s(P([[5, -24], [5, -37], [-31, -37], [-31, 37], [5, 37], [5, 24]]))
			d.cut(P([[-7, -6], [39, -6], [39, 6], [-7, 6]]), 1.0)
			d.s(P([[-8, 0], [38, 0]]))
			d.s(P([[22, -16], [39, 0], [22, 16]]))
		"up", "down":
			var sg := -1.0 if id == "up" else 1.0
			d.s(P([[-25, -sg * 11], [0, sg * 14], [25, -sg * 11]]), false, 9.0)
		"close":
			d.s(P([[-24, -24], [24, 24]]), false, 7.5)
			d.s(P([[24, -24], [-24, 24]]), false, 7.5)
		"play":
			d.sf(rr(-43, -27, 86, 58, 19))
			d.s(P([[-30, 1], [-8, 1]]))
			d.s(P([[-19, -10], [-19, 12]]))
			d.ink(ell(17, -6, 5, 5, 16))
			d.ink(ell(29, 7, 5, 5, 16))
		"world":
			d.sf(ell(0, 0, 38, 38))
			d.s(ell(0, 0, 17, 38), true, 4.5)
			d.s(P([[-35, -13], [35, -13]]), false, 4.5)
			d.s(P([[-35, 13], [35, 13]]), false, 4.5)
		"challenges":
			d.s(P([[-24, -23], [-40, -23], [-38, -3], [-19, 5]]))
			d.s(P([[24, -23], [40, -23], [38, -3], [19, 5]]))
			var cup := P([[-24, -35], [24, -35], [21, -3]])
			bez(cup, Vector2(19, 8), Vector2(9, 14), Vector2(0, 14), 8)
			bez(cup, Vector2(-9, 14), Vector2(-19, 8), Vector2(-21, -3), 8)
			d.sf(cup)
			d.s(P([[0, 14], [0, 32]]))
			d.sf(rr(-20, 32, 40, 9, 4))
			d.ink(star(0, -14, 8, 0.5))
		"system":
			var gear := PackedVector2Array()
			for i in 32:
				var a := (i + 0.5) * PI / 16.0
				var r := 41.0 if i % 4 < 2 else 31.0
				gear.append(Vector2(cos(a) * r, sin(a) * r))
			d.sf(gear)
			d.cut(ell(0, 0, 13, 13), 0.0)
			d.s(ell(0, 0, 13, 13), true)
		"about":
			d.sf(ell(0, 0, 37, 37))
			d.ink(ell(0, -18, 4.5, 4.5, 16))
			d.s(P([[0, -4], [0, 21]]), false, 7.0)
		"mole":
			# A Dahrooj peeking out of a hole, a mallet coming down, an impact mark.
			var hole := ell(0, 30, 44, 11)
			var back := PackedVector2Array()
			var front := PackedVector2Array()
			for v in hole:
				if v.y <= 30.0:
					back.append(v)
				else:
					front.append(v)
			back.sort()
			d.f(hole)
			d.s(back, false, 4.5)
			d.face(-6, 8, 24)
			d.cut(P([[-56, 30], [56, 30], [56, 56], [-56, 56]]))
			var lip := P([[-44, 30]])
			for i in range(1, 32):
				var t := PI - PI * i / 32.0
				lip.append(Vector2(cos(t) * 44, 30 + sin(t) * 11))
			lip.append(Vector2(44, 30))
			d.f(lip)
			d.s(lip, false, 4.5)
			d.xf = Transform2D(0.62, Vector2(30, -28))
			d.sf(rr(-17, -10, 34, 20, 5))
			d.s(P([[0, 10], [0, 34]]), false, 6.0)
			d.xf = Transform2D.IDENTITY
			d.s(P([[-40, -22], [-48, -30]]), false, 4.0)
			d.s(P([[-30, -32], [-32, -44]]), false, 4.0)
			d.s(P([[-44, -8], [-54, -8]]), false, 4.0)
		"invasion":
			# Dahrooj Attack: a cheeky line of them hopping in from the distance (small at the
			# back, big at the front with a mischievous grin), a blaster bolt striking the front one.
			d.s(P([[44, -20], [52, -20]]), false, 3.5)
			d.s(P([[33, 2], [44, 2]]), false, 3.5)
			d.face(37, -36, 9.5, 3.5)
			d.face(17, -15, 14.5, 4.0)
			d.face(-15, 13, 27, 5.0)
			# Brows angled in, and a grin.
			d.s(P([[-31, -3], [-20, 2]]), false, 4.5)
			d.s(P([[1, -3], [-10, 2]]), false, 4.5)
			d.s(arc(-15, 18, 12, PI * 0.18, PI * 0.82), false, 4.5)
			# The bolt and its spark.
			d.s(P([[50, 46], [26, 35]]), false, 4.0)
			d.ink(star(19, 32, 8.5, 0.4))
		"slime":
			# Slime: a Dahrooj splatted flat on a wall, melting, with a flared gooey skirt, drips
			# running down off it, splash droplets flying and impact lines over his head.
			d.xf = Transform2D(0.0, Vector2(0.9, 0.9), 0.0, Vector2(0, 2))
			var body := PackedVector2Array()
			body.append(Vector2(-50, 22))
			body.append(Vector2(-41, 17))
			body.append(Vector2(-34, 9))
			for i in range(0, 25):
				var t := PI + PI * i / 24.0
				body.append(Vector2(cos(t) * 31.0, 4.0 + sin(t) * 29.0))
			body.append(Vector2(34, 9))
			body.append(Vector2(42, 16))
			body.append(Vector2(51, 21))
			body.append(Vector2(36, 25))
			body.append(Vector2(20, 26))
			body.append(Vector2(2, 24))
			body.append(Vector2(-16, 27))
			body.append(Vector2(-34, 26))
			d.cut(body, 4.0)
			d.sf(body)
			# Drips: [x, length, width] off the lower rim, each with a bulb.
			for dr: Array in [[-24.0, 19.0, 5.0], [12.0, 26.0, 6.0], [33.0, 12.0, 4.0]]:
				var x: float = dr[0]
				var ln: float = dr[1]
				var w: float = dr[2]
				var y0 := 24.0
				var drip := P([[x - w, y0], [x - w * 0.8, y0 + ln]])
				for i in range(0, 17):
					var t := PI - PI * i / 16.0
					drip.append(Vector2(x + cos(t) * w * 1.25, y0 + ln + sin(t) * w * 1.25))
				drip.append(Vector2(x + w * 0.8, y0 + ln))
				drip.append(Vector2(x + w, y0))
				d.cut(drip, 0.0)
				d.f(drip)
				d.s(drip, false, 5.0)
			# His melted face: happy closed eyes and a wobbly smile.
			d.s(arc(-11, -2, 6, PI * 1.1, PI * 1.9), false, 4.5)
			d.s(arc(11, -2, 6, PI * 1.1, PI * 1.9), false, 4.5)
			d.s(P([[-9, 9], [-4, 13], [0, 11], [4, 13], [9, 9]]), false, 4.0)
			# Splash droplets and impact lines.
			d.ink(ell(-45, -8, 4.5, 4.5, 20))
			d.ink(ell(-36, -25, 3.0, 3.0, 16))
			d.ink(ell(44, -14, 4.0, 4.0, 20))
			d.ink(ell(50, 3, 2.6, 2.6, 16))
			d.s(P([[-14, -36], [-19, -46]]), false, 4.0)
			d.s(P([[0, -38], [0, -50]]), false, 4.0)
			d.s(P([[14, -36], [19, -46]]), false, 4.0)
			d.xf = Transform2D.IDENTITY
		"meteor":
			# Dahrooj Meteors: a smiling Dahrooj riding the head of a fire teardrop that
			# streaks down from the upper right, flame tongues licking off its tail, speed
			# lines alongside and a golden spark ahead of it.
			var hc := Vector2(-12, 14)
			var tip := Vector2(44, -44)
			var ux := (tip - hc).normalized()
			var vx := Vector2(-ux.y, ux.x)
			var at := func(u: float, v: float) -> Vector2: return hc + ux * u + vx * v
			var a := ux.angle()
			var off := deg_to_rad(66.0)
			var fire := arc(hc.x, hc.y, 27, a + off, a - off)
			for q: Array in [[30, -27], [34, -14], [52, -20], [54, -7], [81, 0], [60, 8], [48, 12], [50, 24], [30, 22]]:
				fire.append(at.call(q[0], q[1]))
			d.cut(fire, 4.0)
			d.sf(fire)
			# Inner flame lick along the tail.
			d.s(PackedVector2Array([at.call(34, -6), at.call(56, -1), at.call(38, 8)]), false, 4.0)
			# The fireball's head is Dahrooj himself: eyes and a grin.
			d.cut(ell(hc.x - 9, hc.y - 1, 4.2, 6.0, 16))
			d.cut(ell(hc.x + 8, hc.y - 1, 4.2, 6.0, 16))
			d.s(arc(hc.x - 0.5, hc.y + 5, 9, PI * 0.2, PI * 0.8), false, 4.0)
			# Speed lines and the golden spark.
			d.s(PackedVector2Array([at.call(28, -40), at.call(52, -40)]), false, 4.0)
			d.s(PackedVector2Array([at.call(46, 34), at.call(64, 34)]), false, 4.0)
			d.ink(star(-42, -26, 11, 0.36))
			d.ink(ell(-26, -42, 3.2, 3.2, 16))
			d.ink(ell(-49, -4, 2.6, 2.6, 16))
		"castle":
			# Dahrooj Fort: a pink-roofed tower beside a crenellated wall, a cheeky
			# Dahrooj on the battlements waving a googly-eyed flag.
			var tower := P([[-46, -6], [-24, -6], [-24, 46], [-46, 46]])
			var roof := P([[-51, -4], [-35, -42], [-19, -4]])
			d.sf(tower)
			d.cut(roof, 3.5)
			d.sf(roof)
			d.ink(rr(-38, 8, 6, 13, 3))
			var wall := P([[-24, 8], [-12, 8], [-12, 18], [28, 18], [28, 8], [40, 8], [40, 46], [-24, 46]])
			d.cut(wall, 3.5)
			d.sf(wall)
			var door := P([[0, 46], [0, 34]])
			bez(door, Vector2(0, 26), Vector2(16, 26), Vector2(16, 34), 10)
			door.append(Vector2(16, 46))
			d.s(door, false, 4.5)
			d.face(8, 6, 14, 3.5)
			d.s(arc(8, 9, 6, PI * 0.15, PI * 0.85), false, 3.5)
			# The waving arm, the pole and the flag with googly eyes.
			d.s(P([[21, 9], [30, 2]]), false, 5.0)
			d.s(P([[30, 6], [30, -48]]), false, 4.5)
			var flag := P([[30, -48]])
			bez(flag, Vector2(38, -54), Vector2(44, -42), Vector2(53, -48), 8)
			flag.append(Vector2(53, -26))
			bez(flag, Vector2(44, -20), Vector2(38, -32), Vector2(30, -26), 8)
			d.sf(flag, 4.0)
			for e: Array in [[37.5, -36.5], [46.5, -36]]:
				d.cut(ell(e[0], e[1], 4.6, 4.6, 20))
				d.s(ell(e[0], e[1], 4.6, 4.6, 20), true, 2.2)
				d.ink(ell(e[0] + 1.4, e[1] + 1.6, 2.0, 2.0, 12))
		"giant":
			# Giant Dahrooj: a huge Dahrooj in a bow tie, a glowing gold target on one eye,
			# a segmented HP arc over his head and a tiny Dahrooj at his feet for scale.
			var g := Vector2(4, 2)
			var hr := 33.0
			var head := ell(g.x, g.y, hr, hr)
			d.sf(head)
			d.cut(ell(g.x - 11, g.y - 3, 4.8, 6.8, 16))
			# The target eye: rings, a bullseye and a glow.
			var te := Vector2(g.x + 12, g.y - 3)
			d.cut(ell(te.x, te.y, 10.5, 10.5, 28))
			d.s(ell(te.x, te.y, 8.5, 8.5, 28), true, 3.0)
			d.ink(ell(te.x, te.y, 3.6, 3.6, 16))
			for i in 4:
				var t := PI * 0.25 + PI * 0.5 * i
				d.s(PackedVector2Array([te + Vector2(cos(t), sin(t)) * 13.0, te + Vector2(cos(t), sin(t)) * 16.0]), false, 2.6)
			d.s(arc(g.x - 1, g.y + 9, 9, PI * 0.2, PI * 0.8), false, 4.0)
			# Bow tie under the chin.
			var bow := P([[g.x, g.y + 36], [g.x - 15, g.y + 28], [g.x - 15, g.y + 44]])
			var bow2 := P([[g.x, g.y + 36], [g.x + 15, g.y + 28], [g.x + 15, g.y + 44]])
			d.cut(P([[g.x - 15, g.y + 28], [g.x + 15, g.y + 28], [g.x + 15, g.y + 44], [g.x - 15, g.y + 44]]), 3.0)
			d.sf(bow, 4.0)
			d.sf(bow2, 4.0)
			d.ink(ell(g.x, g.y + 36, 4.5, 4.5, 16))
			# HP arc: five segments, the last two spent.
			var a0 := PI * 1.13
			var sweep := PI * 0.74
			var gap := 0.09
			for i in 5:
				var s0 := a0 + sweep * i / 5.0 + gap / 2.0
				var s1 := a0 + sweep * (i + 1) / 5.0 - gap / 2.0
				d.s(arc(g.x, g.y, 45, s0, s1), false, 7.0 if i < 3 else 3.0)
			# The tiny one at his feet.
			d.face(-38, 40, 9, 3.0)
		"gallery":
			# Dahrooj Gallery: a ringed cardboard target on a stick, a little Dahrooj face as
			# its bullseye, a tiny crown peeking out behind it.
			var tc := Vector2(-2, -6)
			var crown := P([[16, -26], [16, -48], [24, -38], [31, -52], [38, -38], [46, -48], [46, -26]])
			d.sf(crown, 4.5)
			d.ink(ell(31, -55, 3.0, 3.0, 12))
			var stick := rr(tc.x - 5, 24, 10, 28, 3)
			d.sf(stick, 4.5)
			var board := ell(tc.x, tc.y, 37, 37)
			d.cut(board, 4.0)
			d.sf(board)
			d.s(ell(tc.x, tc.y, 26, 26), true, 9.0)
			d.cut(ell(tc.x, tc.y, 17, 17), 0.0)
			d.s(ell(tc.x, tc.y, 17, 17), true, 3.0)
			d.face(tc.x, tc.y, 11, 3.0)
			# A hit mark on the ring.
			d.s(P([[-34, -36], [-40, -42]]), false, 3.5)
			d.s(P([[-28, -42], [-29, -50]]), false, 3.5)
			d.s(P([[-40, -28], [-49, -28]]), false, 3.5)
		"frenzy":
			# Pop Frenzy: a big shiny bubble with a tiny Dahrooj inside, and three small
			# bubbles bursting in a golden spark.
			var bc := Vector2(-8, 8)
			var br := 38.0
			d.sf(ell(bc.x, bc.y, br, br))
			# The sheen: two bands of highlight in the upper left and a glint lower right.
			d.cut(arc(bc.x, bc.y, 28, PI * 1.08, PI * 1.42) + arc(bc.x, bc.y, 22, PI * 1.42, PI * 1.08, true), 0.0)
			d.s(arc(bc.x, bc.y, 25, PI * 1.12, PI * 1.38), false, 3.0)
			d.s(arc(bc.x, bc.y, 30, PI * 0.12, PI * 0.38), false, 4.0)
			d.face(bc.x + 2, bc.y + 6, 14, 3.5)
			d.s(arc(bc.x + 2, bc.y + 9, 5, PI * 0.15, PI * 0.85), false, 3.0)
			# Three little bubbles: two still whole, one bursting.
			for b: Array in [[40, -12, 8.0], [21, -40, 6.0]]:
				d.cut(ell(b[0], b[1], b[2], b[2], 24), 3.0)
				d.sf(ell(b[0], b[1], b[2], b[2], 24), 3.5)
			var pc := Vector2(43, -40)
			for i in 8:
				var t := TAU * i / 8.0 + 0.2
				d.s(PackedVector2Array([pc + Vector2(cos(t), sin(t)) * 7.0, pc + Vector2(cos(t), sin(t)) * 11.5]), false, 3.2)
			d.ink(star(pc.x, pc.y, 6.5, 0.4))
			d.ink(ell(52, -24, 2.4, 2.4, 12))
		"mr":
			# Mixed reality: your room's back corner through a viewfinder, a cube on the floor.
			d.s(P([[-46, 34], [-20, 16], [20, 16], [46, 34]]), false, 4.0)
			d.s(P([[-20, 16], [-20, -30]]), false, 4.0)
			d.s(P([[20, 16], [20, -30]]), false, 4.0)
			var top := P([[0, -6], [17, 2], [0, 10], [-17, 2]])
			var left := P([[-17, 2], [0, 10], [0, 31], [-17, 23]])
			var right := P([[0, 10], [17, 2], [17, 23], [0, 31]])
			d.cut(P([[0, -6], [17, 2], [17, 23], [0, 31], [-17, 23], [-17, 2]]), 4.0)
			d.sf(top, 4.0)
			d.sf(left, 4.0)
			d.sf(right, 4.0)
			for c: Array in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
				var x: float = c[0] * 48.0
				var y: float = c[1] * 44.0
				d.s(P([[x, y - c[1] * 16.0], [x, y], [x - c[0] * 16.0, y]]), false, 5.0)
		"vr":
			# Virtual reality: a headset whose visor shows the park (hills, a tree, the sun).
			var body := rr(-46, -30, 92, 60, 20)
			d.f(body)
			d.s(body, true, 5.0)
			d.s(P([[-46, -4], [-54, -4]]), false, 6.0)
			d.s(P([[46, -4], [54, -4]]), false, 6.0)
			var view := rr(-34, -19, 68, 38, 11)
			d.cut(view, 0.0)
			d.s(view, true, 3.5)
			d.ink(ell(18, -7, 5.5, 5.5, 20))
			var hill := P([[-33, 14], [-20, 3], [-8, 9], [6, 0], [33, 14]])
			d.s(hill, false, 3.5)
			d.ink(ell(-15, -6, 7, 7, 20))
			d.s(P([[-15, -2], [-15, 7]]), false, 3.0)
			d.cut(P([[-9, 31], [-6, 22], [6, 22], [9, 31]]), 0.0)
			d.s(P([[-12, 30], [-6, 20], [6, 20], [12, 30]]), false, 4.5)
		"lang":
			# A speech bubble with two glyph strokes (the language card on the start screen).
			var b := rr(-42, -34, 84, 58, 16)
			d.cut(b, 0.0)
			d.f(b)
			d.s(b, true)
			d.s(P([[-14, 24], [-22, 40], [2, 24]]), false, 5.0)
			d.s(P([[-26, 8], [-16, -18], [-6, 8]]), false, 5.0)
			d.s(P([[-22, -1], [-10, -1]]), false, 4.5)
			d.s(arc(17, -6, 10, PI * 0.5, PI * 1.6), false, 4.5)
			d.s(P([[13, 3], [27, 6], [17, 12]]), false, 4.5)
		"laser":
			# The laser: an emitter, a straight beam through two ringed targets, a spark at its end.
			d.f(P([[-24, 15], [42, -37], [46, -29], [-20, 23]]))
			d.sf(rr(-48, 16, 28, 20, 6))
			d.s(P([[-22, 22], [42, -30]]), false, 6.5)
			d.s(ell(4, 1.5, 10, 10), true, 4.0)
			d.s(ell(24, -14.2, 10, 10), true, 4.0)
			d.ink(star(44, -32, 9, 0.4))
		"confetti":
			# The confetti cannon: a tilted barrel spraying slips and dots.
			d.xf = Transform2D(-0.65, Vector2(-20, 22))
			d.sf(rr(-22, -12, 40, 24, 6))
			d.s(P([[18, -15], [18, 15]]), false, 5.0)
			d.xf = Transform2D.IDENTITY
			d.s(P([[-42, 40], [-8, 40]]), false, 4.5)
			for c: Array in [[10, -22, 0.5], [30, -6, -0.6], [-2, -42, 1.1], [26, -38, 0.2], [44, 12, 0.9], [44, -26, -0.3]]:
				d.xf = Transform2D(float(c[2]), Vector2(float(c[0]), float(c[1])))
				d.sf(rr(-6, -3, 12, 6, 1.5), 3.5)
			d.xf = Transform2D.IDENTITY
			for c: Array in [[16, 10], [8, -36], [40, -46], [36, 30]]:
				d.ink(ell(float(c[0]), float(c[1]), 3.2, 3.2, 16))
		"bouncy":
			# The bouncy ball: a striped ball and the hops it took to get there.
			var hop := P([[-46, -32]])
			bez(hop, Vector2(-38, -32), Vector2(-22, -4), Vector2(-16, 36))
			d.s(hop, false, 3.5)
			var hop2 := P([[-16, 36]])
			bez(hop2, Vector2(-10, 10), Vector2(0, 0), Vector2(10, -2))
			d.s(hop2, false, 3.5)
			d.s(P([[-34, 44], [4, 44]]), false, 4.5)
			d.s(P([[-24, 32], [-29, 27]]), false, 3.5)
			d.s(P([[-8, 32], [-3, 27]]), false, 3.5)
			d.sf(ell(25, -12, 19, 19))
			d.s(arc(25, -12, 12, PI * 0.95, PI * 1.6), false, 4.5)
			d.s(P([[8, -4], [42, -20]]), false, 4.0)
		"boomerang":
			# The boomerang: a V of two arms and the loop that brings it back.
			var arm := rr(0, -8, 46, 16, 8)
			d.xf = Transform2D(0.62, Vector2(-30, -2))
			d.sf(arm)
			d.xf = Transform2D(-0.62, Vector2(-30, 2))
			d.cut(arm, 3.0)
			d.sf(arm)
			d.xf = Transform2D.IDENTITY
			d.s(arc(8, 0, 40, -1.05, 1.35), false, 4.0)
			d.s(P([[23.6, 33.1], [16.8, 39.0], [25.4, 41.5]]), false, 4.0)
		"glob":
			# The jelly glob: a gooey wobbling blob with drips, droplets and a shine.
			var blob := PackedVector2Array()
			for i in 48:
				var t := TAU * i / 48.0
				var r := 28.0 + 4.0 * sin(5.0 * t + 0.6) + 2.0 * sin(3.0 * t)
				blob.append(Vector2(cos(t) * r * 1.1, -4.0 + sin(t) * r * 0.9))
			d.sf(rr(-14, 8, 10, 34, 5), 4.5)
			d.sf(rr(10, 8, 9, 26, 4.5), 4.5)
			d.cut(blob, 0.0)
			d.sf(blob)
			d.ink(ell(-14, -16, 6, 3.5, 16))
			d.cut(ell(-8, 0, 3.5, 5, 16))
			d.cut(ell(8, 0, 3.5, 5, 16))
			d.ink(ell(-44, -30, 4, 4, 16))
			d.ink(ell(42, -36, 3, 3, 16))
			d.ink(ell(-38, 30, 3, 3, 16))
		"rocket":
			# The homing rocket: nose up and to the right, fins, a window and its flame.
			d.xf = Transform2D(PI / 4.0, Vector2(-2, 4))
			var flame := P([[-8, 22], [0, 46], [8, 22]])
			d.f(flame)
			d.s(flame, false, 4.0)
			for sx in [-1.0, 1.0]:
				var fin := P([[sx * 12, 2], [sx * 25, 18], [sx * 25, 27], [sx * 12, 20]])
				d.sf(fin, 4.5)
			var body := P([[0, -44]])
			bez(body, Vector2(10, -38), Vector2(13, -22), Vector2(13, -6))
			body.append(Vector2(13, 22))
			body.append(Vector2(-13, 22))
			body.append(Vector2(-13, -6))
			bez(body, Vector2(-13, -22), Vector2(-10, -38), Vector2(0, -44))
			d.cut(body, 3.0)
			d.sf(body)
			d.cut(ell(0, -12, 6, 6, 20), 0.0)
			d.s(ell(0, -12, 6, 6, 20), true, 4.0)
			d.xf = Transform2D.IDENTITY
			# The target it has locked on to.
			d.s(ell(36, -36, 9, 9, 28), true, 3.5)
			for c: Array in [[36, -50, 36, -44], [36, -28, 36, -22], [22, -36, 28, -36], [44, -36, 50, -36]]:
				d.s(P([[c[0], c[1]], [c[2], c[3]]]), false, 3.5)
		"lightning":
			# Chain lightning: a jagged arc leaping from one Dahrooj to the next, and the next.
			d.s(P([[-36, -26], [-28, -14], [-34, -8], [-18, 2], [-22, 8], [-8, 14]]), false, 4.5)
			d.s(P([[6, 12], [12, 2], [8, -4], [22, -10], [18, -16], [28, -24]]), false, 4.5)
			d.s(P([[34, -16], [38, -2], [32, 4], [40, 18], [36, 24]]), false, 4.5)
			d.face(-38, -34, 11, 3.0)
			d.face(0, 20, 12, 3.0)
			d.face(36, -30, 10, 3.0)
			d.face(34, 36, 9, 3.0)
			d.ink(star(-50, -14, 5, 0.4))
		"dallah":
			# The dallah: the Arabic coffee pot (round belly, waist, flared top, domed lid and
			# finial, the long beaked spout and the handle) and two coffee beans.
			var spout := P([[-14, 26]])
			bez(spout, Vector2(-32, 22), Vector2(-38, 0), Vector2(-48, -22))
			spout.append(Vector2(-38, -22))
			bez(spout, Vector2(-30, -4), Vector2(-24, 12), Vector2(-10, 12))
			d.sf(spout, 4.5)
			var handle := P([[14, -6]])
			bez(handle, Vector2(36, -8), Vector2(38, 22), Vector2(18, 28))
			d.s(handle, false, 5.0)
			var pot := P([[-20, 38], [20, 38]])
			bez(pot, Vector2(28, 28), Vector2(14, 14), Vector2(9, 4))
			bez(pot, Vector2(6, -2), Vector2(16, -6), Vector2(17, -12))
			pot.append(Vector2(-17, -12))
			bez(pot, Vector2(-16, -6), Vector2(-6, -2), Vector2(-9, 4))
			bez(pot, Vector2(-14, 14), Vector2(-28, 28), Vector2(-20, 38))
			d.cut(pot, 3.0)
			d.sf(pot)
			d.s(P([[-14, 24], [14, 24]]), false, 3.5)
			var lid := arc(0, -13, 13, PI, TAU)
			d.sf(lid, 4.5)
			d.s(P([[0, -26], [0, -33]]), false, 4.5)
			d.ink(ell(0, -37, 4, 4, 16))
			for c: Array in [[34, -36, 0.5], [46, -20, -0.4]]:
				d.xf = Transform2D(float(c[2]), Vector2(float(c[0]), float(c[1])))
				d.sf(ell(0, 0, 7, 4.5, 20), 3.5)
				d.s(P([[-4, 0], [4, 0]]), false, 2.5)
			d.xf = Transform2D.IDENTITY
		"shemagh", "ghutra", "goldAgal":
			# Dahrooj in a head-cloth lying smooth over the crown (no peak) under the double
			# agal; the shemagh is checked, the golden agal sparkles.
			var hood := arc(0, 4, 40, PI, 0)
			hood.append_array(P([[40, 46], [24, 40], [-24, 40], [-40, 46]]))
			d.sf(hood)
			if id == "shemagh":
				for gy in range(-30, 46, 9):
					for gx in range(-36, 40, 9):
						var q := Vector2(gx, gy)
						if (gy < 4 and q.distance_to(Vector2(0, 4)) > 34.0) or (gy >= -24 and gy <= -6) or q.distance_to(Vector2(0, 16)) < 28.0 or gy > 36:
							continue
						d.ink(rr(gx - 2.4, gy - 2.4, 4.8, 4.8, 1.0))
			for y in [-21.0, -11.0]:
				var band := PackedVector2Array()
				for k in 25:
					var t := PI * k / 24.0
					band.append(Vector2(cos(t) * 41.0, y + sin(t) * 6.0))
				d.cut(band, 2.0)
				d.s(band, false, 6.5)
			d.face(0, 16, 22, 3.5)
			if id == "goldAgal":
				d.ink(star(-40, -38, 8, 0.4))
				d.ink(star(40, -30, 6, 0.4))
		"taqiyah":
			# A crocheted skullcap: rows of little holes over a rolled rim.
			var dome := arc(0, 12, 36, PI, 0)
			d.sf(dome)
			d.cut(rr(-39, 8, 78, 13, 6), 2.5)
			d.sf(rr(-39, 8, 78, 13, 6))
			for row: Array in [[-1.0, 6, 11.0], [-12.0, 5, 11.0], [-23.0, 3, 11.0]]:
				var n: int = row[1]
				for k in n:
					var x := (k - (n - 1) / 2.0) * float(row[2])
					d.cut(ell(x, row[0], 3.2, 3.2, 16))
			d.ink(ell(0, -31, 3.5, 3.5, 16))
		"kufi":
			# An embroidered pillbox cap: a zigzag band between two borders.
			var body := P([[-34, -20], [34, -20], [37, 24], [-37, 24]])
			d.sf(body)
			d.cut(ell(0, -20, 34, 9), 2.5)
			d.sf(ell(0, -20, 34, 9))
			d.s(P([[-35, -9], [35, -9]]), false, 3.5)
			d.s(P([[-36, 14], [36, 14]]), false, 3.5)
			var zz := PackedVector2Array()
			for k in 9:
				zz.append(Vector2(-32 + k * 8, -5 if k % 2 == 0 else 10))
			d.s(zz, false, 3.5)
			d.ink(star(0, -20, 6, 0.45))
		"falcon":
			# A falcon in profile on a perch: hooked beak, folded wing, long tail.
			d.s(P([[-34, 40], [36, 40]]))
			var tail := P([[-14, 26], [-34, 44], [-24, 48], [-2, 30]])
			d.sf(tail)
			var body := ell(-2, 8, 19, 27)
			d.cut(body, 3.0)
			d.sf(body)
			var head := ell(8, -24, 14, 14)
			d.cut(head, 3.0)
			d.sf(head)
			var beak := P([[19, -31], [31, -27], [30, -19], [25, -22], [19, -19]])
			d.cut(beak, 2.0)
			d.sf(beak, 4.0)
			var wing := P([[-18, -6], [8, 0], [2, 26], [-22, 40], [-22, 10]])
			d.cut(wing, 2.5)
			d.sf(wing)
			d.ink(ell(12, -27, 3.5, 3.5, 16))
			d.s(P([[12, -21], [10, -14]]), false, 3.5)
			d.s(P([[0, 34], [2, 40]]), false, 4.0)
			d.s(P([[8, 33], [10, 40]]), false, 4.0)
		"jasmine":
			# A crown of five little jasmine stars on a vine.
			d.s(arc(0, 26, 38, PI * 1.08, PI * 1.92), false, 4.0)
			for k in 4:
				var a := PI * (1.2 + 0.2 * k)
				d.f(ell(cos(a) * 38.0, 26.0 + sin(a) * 38.0, 5, 5, 16))
			for k in 5:
				var a := PI * (1.1 + 0.2 * k)
				var cx := cos(a) * 38.0
				var cy := 26.0 + sin(a) * 38.0
				var fl := star(cx, cy, 13, 0.45)
				d.cut(fl, 2.5)
				d.sf(fl, 4.0)
				d.ink(ell(cx, cy, 3, 3, 16))
		"headband":
			# Dahrooj with a striped sports band tied at the side.
			d.face(0, 8, 34, 3.0)
			var band := rr(-39, -22, 78, 15, 5)
			d.cut(band, 2.5)
			d.sf(band)
			d.s(P([[-34, -14], [34, -14]]), false, 3.0)
			d.ink(ell(40, -14, 5.5, 5.5, 16))
			d.s(P([[42, -10], [46, 8]]), false, 5.0)
			d.s(P([[44, -12], [54, 0]]), false, 5.0)
		"astronaut":
			# A glass helmet bowl on a collar, with a little antenna light.
			d.f(ell(0, -4, 38, 38))
			d.s(ell(0, -4, 38, 38), true)
			d.face(0, 2, 22, 3.0)
			d.s(arc(0, -4, 30, PI * 1.15, PI * 1.4), false, 4.0)
			d.cut(rr(-32, 28, 64, 16, 8), 2.5)
			d.sf(rr(-32, 28, 64, 16, 8))
			d.s(P([[0, -42], [0, -50]]), false, 3.5)
			d.ink(ell(0, -52, 4, 4, 16))
		"pirate":
			# A bicorne with a skull and crossbones.
			var hat := PackedVector2Array()
			for k in 33:
				var t := PI + PI * k / 32.0
				hat.append(Vector2(cos(t) * 46.0, 18.0 + sin(t) * 40.0))
			d.sf(hat)
			d.s(P([[-46, 18], [46, 18]]))
			d.s(P([[-11, 6], [11, 16]]), false, 4.5)
			d.s(P([[-11, 16], [11, 6]]), false, 4.5)
			d.cut(ell(0, -4, 10, 9), 2.0)
			d.ink(ell(0, -4, 9, 8.5, 24))
			d.cut(ell(-3.5, -5, 2.5, 2.5, 12))
			d.cut(ell(3.5, -5, 2.5, 2.5, 12))
		"chef":
			# A chef's toque: a puffy top over a pleated band.
			d.sf(rr(-22, 8, 44, 30, 4))
			for x in [-11, 0, 11]:
				d.s(P([[x, 14], [x, 32]]), false, 3.0)
			for c: Array in [[-20, -6, 16], [20, -6, 16], [0, -18, 21]]:
				var e := ell(c[0], c[1], c[2], c[2])
				d.cut(e, 2.5)
				d.sf(e)
		"dino":
			# A dinosaur hood: spikes along the top, soft teeth over the brow, two eyes.
			for k in 5:
				var a := PI * (1.15 + 0.175 * k)
				var bx := cos(a) * 36.0
				var by := 14.0 + sin(a) * 36.0
				var o := Vector2(cos(a), sin(a))
				var side := Vector2(-o.y, o.x) * 7.0
				d.sf(PackedVector2Array([Vector2(bx, by) + side, Vector2(bx, by) + o * 14.0, Vector2(bx, by) - side]), 4.0)
			var hood := arc(0, 14, 36, PI, 0)
			hood.append_array(P([[36, 38], [24, 38], [24, 14], [-24, 14], [-24, 38], [-36, 38]]))
			d.cut(hood, 2.5)
			d.sf(hood)
			var teeth := PackedVector2Array()
			for k in 9:
				teeth.append(Vector2(-22 + k * 5.5, 14 if k % 2 == 0 else 21))
			d.s(teeth, false, 3.5)
			for sx in [-12.0, 12.0]:
				d.cut(ell(sx, -18, 8, 8, 24), 2.0)
				d.s(ell(sx, -18, 7, 7, 24), true, 3.5)
				d.ink(ell(sx, -17, 3.2, 3.2, 16))
		"halo":
			# Dahrooj under a glowing ring with sparkles.
			d.face(0, 16, 28, 3.0)
			d.s(ell(0, -30, 26, 8), true, 6.0)
			d.ink(star(-36, -40, 7, 0.4))
			d.ink(star(38, -34, 6, 0.4))
		"bunny":
			# Dahrooj with two tall bunny ears.
			for sx in [-15.0, 15.0]:
				var ear := ell(sx, -26, 10, 24)
				d.sf(ear)
				d.s(P([[sx, -40], [sx, -16]]), false, 3.5)
			d.face(0, 18, 28, 3.0)
		"wizard":
			# A pointed hat leaning over, on a wide brim, with stars.
			d.sf(P([[-27, 20], [27, 20], [12, -18], [-2, -40], [-12, -20]]))
			d.ink(star(-4, 2, 7, 0.45))
			d.ink(star(10, -16, 5, 0.45))
			var brim := ell(0, 23, 45, 10)
			d.cut(brim, 2.5)
			d.sf(brim)
		"viking":
			# A round helmet with a band and two horns curling up.
			for sx in [-1.0, 1.0]:
				d.sf(P([[sx * 22, 0], [sx * 40, -6], [sx * 48, -24], [sx * 46, -42], [sx * 38, -18], [sx * 26, -12]]))
			var dome := arc(0, 16, 32, PI, 0)
			d.cut(dome, 2.5)
			d.sf(dome)
			d.sf(rr(-35, 12, 70, 12, 5))
			d.s(P([[0, -16], [0, 12]]), false, 4.0)
			for x in [-22.0, -8.0, 8.0, 22.0]:
				d.ink(ell(x, 18, 2.6, 2.6, 12))
		"propeller":
			# A cap with a peak and a little propeller on top.
			var dome := arc(0, 18, 30, PI, 0)
			d.sf(dome)
			d.s(P([[-10, -11], [-4, 18]]), false, 3.5)
			d.s(P([[10, -11], [4, 18]]), false, 3.5)
			d.sf(rr(-4, 14, 46, 10, 5))
			d.s(P([[0, -12], [0, -28]]), false, 4.0)
			d.sf(ell(-17, -31, 15, 5))
			d.sf(ell(17, -31, 15, 5))
			d.ink(ell(0, -30, 4.5, 4.5, 16))
		"bowtie":
			# A bow tie with polka dots.
			d.sf(P([[-6, -4], [-42, -22], [-42, 22], [-6, 4]]))
			d.sf(P([[6, -4], [42, -22], [42, 22], [6, 4]]))
			for c: Array in [[-28, -6], [-30, 9], [28, -6], [30, 9]]:
				d.ink(ell(c[0], c[1], 3.2, 3.2, 12))
			var knot := rr(-9, -11, 18, 22, 6)
			d.cut(knot, 2.5)
			d.sf(knot)
		"gradcap":
			# A mortarboard over its cap, the tassel hanging at the side.
			d.sf(P([[-26, -6], [-26, 16], [-14, 22], [14, 22], [26, 16], [26, -6]]))
			var board := P([[0, -32], [46, -14], [0, 4], [-46, -14]])
			d.cut(board, 2.5)
			d.sf(board)
			d.ink(ell(0, -14, 4, 3, 16))
			d.s(P([[0, -14], [36, -8], [36, 16]]), false, 3.5)
			d.ink(rr(32, 14, 8, 14, 3))
		"umbrella":
			# Dahrooj under a striped beach umbrella.
			var can := arc(0, -4, 42, PI, TAU)
			d.sf(can)
			for x in [-15.0, 15.0]:
				d.s(P([[0, -46], [x, -4]]), false, 3.5)
			d.s(P([[0, -4], [0, 10]]), false, 4.0)
			d.face(0, 28, 17, 3.0)
		"goldShades":
			# Teardrop aviator lenses on a double bridge.
			for sx in [-1.0, 1.0]:
				var lens := PackedVector2Array()
				for i in 40:
					var t := TAU * i / 40.0
					var bulge := maxf(0.0, sin(t))
					lens.append(Vector2(sx * 22.0 + cos(t) * 17.0 + sx * bulge * 4.0, -2.0 + sin(t) * (13.0 + 6.0 * bulge)))
				d.sf(lens)
				d.s(P([[sx * 38.0, -10], [sx * 48.0, -16]]), false, 4.0)
				d.s(P([[sx * 15.0, -8], [sx * 22.0, -11]]), false, 3.0)
			d.s(P([[-7, -12], [7, -12]]), false, 3.5)
			d.s(arc(0, -2, 6, PI, TAU), false, 3.5)
		"turban":
			# A wrapped turban: a dome over crossing folds, a jewel and a feather.
			var dome := arc(0, 4, 32, PI, TAU)
			d.sf(dome)
			var band := rr(-40, 0, 80, 22, 11)
			d.cut(band, 2.5)
			d.sf(band)
			d.s(P([[-28, -12], [8, -30]]), false, 3.5)
			d.s(P([[-30, 4], [26, 18]]), false, 3.5)
			var plume := ell(6, -12, 5, 15)
			d.cut(plume, 2.0)
			d.sf(plume)
			d.cut(ell(2, 10, 8, 8), 2.0)
			d.ink(ell(2, 10, 6, 6, 24))
		"taifRose":
			# A ring of roses on a green vine.
			d.s(arc(0, 34, 44, PI * 1.12, PI * 1.88), false, 4.0)
			d.f(ell(-22, 6, 9, 5))
			d.f(ell(22, 6, 9, 5))
			for r: Array in [[-32, 10, 10.0], [-15, -4, 12.0], [15, -4, 12.0], [32, 10, 10.0], [0, -12, 13.0]]:
				var c := ell(r[0], r[1], r[2], r[2])
				d.cut(c, 2.5)
				d.sf(c)
				d.s(arc(r[0], r[1], float(r[2]) * 0.45, 0.0, PI * 1.5), false, 3.0)
		"farwa":
			# A suede hat with a fluffy wool rim and a tuft on top.
			d.sf(arc(0, 12, 32, PI, TAU))
			d.sf(ell(0, -24, 8, 8))
			for i in 7:
				var c := ell(-36.0 + i * 12.0, 14, 8, 8)
				d.cut(c, 1.5)
				d.sf(c)
		"diving":
			# Diving goggles on their strap, a snorkel up the side.
			d.s(P([[-50, 0], [-38, 0]]), false, 5.0)
			d.s(P([[38, 0], [44, 0]]), false, 5.0)
			for x in [-38.0, 4.0]:
				var lens := rr(x, -14, 34, 28, 11)
				d.cut(lens, 2.5)
				d.sf(lens)
				d.s(P([[x + 7, -6], [x + 13, -9]]), false, 3.0)
			d.s(P([[-4, -1], [4, -1]]), false, 4.0)
			d.s(P([[44, 16], [46, -28], [40, -38]]), false, 6.0)
			d.ink(rr(32, -46, 12, 10, 3))
		"lantern":
			# A Ramadan lantern: a hexagonal glass body under a roof, a crescent on top.
			var body := P([[-16, -18], [16, -18], [22, -10], [22, 16], [16, 24], [-16, 24], [-22, 16], [-22, -10]])
			d.sf(body)
			d.s(P([[-7, -18], [-7, 24]]), false, 3.0)
			d.s(P([[7, -18], [7, 24]]), false, 3.0)
			d.ink(ell(0, 3, 4, 6, 20))
			var roof := P([[-22, -18], [0, -34], [22, -18]])
			d.cut(roof, 2.0)
			d.sf(roof)
			d.sf(rr(-18, 24, 36, 9, 3))
			d.s(P([[0, -34], [0, -40]]), false, 3.5)
			d.s(arc(0, -46, 6, PI * 0.3, PI * 1.6), false, 3.5)
		"palm":
			# Palm fronds fanning out of a woven band, dates in front.
			for i in 7:
				var a := lerpf(-PI * 0.92, -PI * 0.08, i / 6.0)
				d.xf = Transform2D(a, Vector2(0, 18))
				d.sf(ell(24, 0, 22, 6.5))
				d.xf = Transform2D.IDENTITY
			var band := rr(-34, 14, 68, 13, 6)
			d.cut(band, 2.5)
			d.sf(band)
			for c: Array in [[-6, 34], [6, 34], [0, 42]]:
				d.ink(ell(c[0], c[1], 4.5, 5.5, 20))
		"misbaha":
			# A loop of prayer beads, a tassel hanging below.
			for i in 17:
				var t := -PI * 0.5 + TAU * (i + 0.5) / 18.0
				if absf(wrapf(t - PI * 0.5, -PI, PI)) < 0.2:
					continue
				d.sf(ell(cos(t) * 30.0, -6.0 + sin(t) * 32.0, 5.0, 5.0, 20))
			d.ink(ell(0, 30, 5, 5, 20))
			d.sf(P([[-5, 36], [5, 36], [11, 52], [-11, 52]]))
		"karak":
			# A glass of tea on a saucer, steam curling up.
			d.sf(ell(0, 28, 36, 8))
			var glass := P([[-21, -12], [21, -12], [15, 27], [-15, 27]])
			d.cut(glass, 2.5)
			d.sf(glass)
			d.s(P([[-20, -3], [20, -3]]), false, 3.0)
			d.s(P([[-17, 13], [17, 13]]), false, 3.0)
			d.s(bez(P([[-7, -20]]), Vector2(-15, -28), Vector2(2, -36), Vector2(-6, -48)), false, 3.5)
			d.s(bez(P([[8, -20]]), Vector2(0, -28), Vector2(17, -34), Vector2(9, -46)), false, 3.5)
		"sadu":
			# A scarf woven in Sadu bands: diamonds along it, fringed tails.
			var tail := P([[6, 0], [24, 0], [29, 38], [11, 40]])
			d.sf(tail)
			for x in [15, 23]:
				d.s(P([[x, 40], [x + 1, 48]]), false, 4.0)
			var band := rr(-42, -22, 84, 24, 12)
			d.cut(band, 3.0)
			d.sf(band)
			for x in [-27.0, -9.0, 9.0, 27.0]:
				d.ink(P([[x, -16], [x + 6, -10], [x, -4], [x - 6, -10]]))
			d.s(P([[12, 18], [26, 18]]), false, 3.0)
		"medal":
			# A medal with a star, on a ribbon.
			d.sf(P([[-28, -46], [-13, -46], [5, -2], [-10, -2]]))
			d.sf(P([[28, -46], [13, -46], [-5, -2], [10, -2]]))
			var disc := ell(0, 20, 23, 23)
			d.cut(disc, 3.0)
			d.sf(disc)
			d.ink(star(0, 20, 12, 0.45))
		"bisht":
			# Dahrooj in a bisht: the cloak open at the front, gold edges.
			d.sf(P([[-14, 4], [-44, 46], [-6, 46], [-4, 12]]))
			d.sf(P([[14, 4], [44, 46], [6, 46], [4, 12]]))
			d.s(P([[-8, 14], [-10, 46]]), false, 3.0)
			d.s(P([[8, 14], [10, 46]]), false, 3.0)
			d.face(0, -14, 24, 3.5)
		"trophy":
			# A trophy cup with two handles and a star.
			var cup := arc(0, -24, 27, 0, PI)
			d.sf(cup)
			d.s(arc(-27, -14, 10, PI * 0.5, PI * 1.5), false, 4.5)
			d.s(arc(27, -14, 10, -PI * 0.5, PI * 0.5), false, 4.5)
			d.s(P([[0, 4], [0, 22]]), false, 6.0)
			d.sf(rr(-20, 22, 40, 12, 4))
			d.ink(star(0, -13, 9, 0.45))
		"worldCup":
			# The World Cup: a banded base, a waisted stem with spiralling ribbons, a globe on
			# top with its meridians, and a twinkle.
			var stem := P([[-16, -12]])
			bez(stem, Vector2(-6, -2), Vector2(-4, 14), Vector2(-13, 27))
			stem.append(Vector2(13, 27))
			bez(stem, Vector2(4, 14), Vector2(6, -2), Vector2(16, -12))
			d.sf(stem)
			var rib := P([[-10, 24]])
			bez(rib, Vector2(-2, 14), Vector2(8, 4), Vector2(5, -10))
			d.s(rib, false, 3.2)
			var rib2 := P([[10, 24]])
			bez(rib2, Vector2(3, 16), Vector2(-9, 2), Vector2(-6, -10))
			d.s(rib2, false, 3.2)
			var globe := ell(0, -27, 18, 18)
			d.cut(globe, 2.5)
			d.sf(globe)
			d.s(ell(0, -27, 7.5, 18), true, 3.0)
			d.s(P([[-18, -27], [18, -27]]), false, 3.0)
			var foot := rr(-21, 27, 42, 17, 4)
			d.cut(foot, 2.0)
			d.sf(foot)
			d.s(P([[-21, 35.5], [21, 35.5]]), false, 3.5)
			d.ink(star(33, -38, 7, 0.4))
			d.ink(star(-33, -14, 5, 0.4))
		"goldStar":
			# A plump star with a smile, and twinkles beside it.
			var st := star(-4, 4, 38, 0.5)
			d.cut(st, 3.0)
			d.sf(st)
			d.ink(ell(-12, 2, 3.5, 4.5))
			d.ink(ell(4, 2, 3.5, 4.5))
			d.s(arc(-4, 8, 7, 0.2, PI - 0.2), false, 3.5)
			d.ink(star(34, -32, 10, 0.35))
			d.ink(star(36, 30, 7, 0.35))
		"goldPal":
			# Dahrooj with a little crowned Dahrooj sitting on his head.
			d.face(0, 18, 28, 4.0)
			var pal := ell(0, -24, 15, 14)
			d.cut(pal, 3.0)
			d.sf(pal)
			d.ink(ell(-5, -25, 2.5, 3.2))
			d.ink(ell(5, -25, 2.5, 3.2))
			d.sf(P([[-11, -37], [-11, -46], [-5, -41], [0, -48], [5, -41], [11, -46], [11, -37]]))
		_:
			d.sf(star(0, 0, 36, 0.46))
	return d.ops
