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
	"weather-rain", "snow", "place", "exit", "up", "down", "star",
]
const ALIAS := {"appearance": "character", "accessories": "party", "palette": "modes", "trophy": "challenges", "clear": "day"}

static var _cache := {}  # id -> [line: Texture2D, tint: Texture2D]
static var _atlas: Image
static var _atlas_tried := false


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
	if pair.size() < 2:
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
	return atlas.save_png(ProjectSettings.globalize_path(path) if path.begins_with("res://") else path)


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
		_:
			d.sf(star(0, 0, 36, 0.46))
	return d.ops
