class_name ParkTracks
extends RefCounted
## Tracks.js as nature.js draws them: a black 512 x 512 picture over 64 x 64 game
## units around the court, white where a ball pressed the grass, dug the snow or
## marked the ground (a radial gradient per mark). It fades back slowly (2 % every
## half second, as the canvas fill rgba(0,0,0,.02)), so old tracks heal. Drawn on the
## CPU into an Image with native blends; the fade runs a band of rows per frame so no
## frame pays for the whole picture, and the texture is uploaded a few times a second
## at most. Ground, grass and snow read it through the dah_tracks global.

const PX := 512
const SIZE := 64.0
const FADE_EVERY := 0.5
const UPLOAD_EVERY := 0.08
## Nothing pressed for this long: the picture has faded to black; stop working.
const QUIET := 90.0

var center := Vector2(0, -10)
var image: Image
var texture: ImageTexture
var _fade_band: Image
var _brushes := {}
var _dirty := false
var _fade_rows := 0.0
var _fade_row := 0
var _upload := 0.0
var _since_mark := QUIET + 1.0
var _since_fade_upload := 0.0


func _init(c := Vector2(0, -10)) -> void:
	center = c
	image = Image.create(PX, PX, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	_fade_band = Image.create(PX, PX, false, Image.FORMAT_RGBA8)
	_fade_band.fill(Color(0, 0, 0, 0.02))
	texture = ImageTexture.create_from_image(image)


## Press a track at (x, z): radius in game units, strength 0–1.
func mark(x: float, z: float, radius: float, strength: float) -> void:
	var u := (x - center.x) / SIZE + 0.5
	var v := (z - center.y) / SIZE + 0.5
	if u < 0.0 or v < 0.0 or u > 1.0 or v > 1.0:
		return
	var r := maxf(1.5, radius / SIZE * PX)
	var brush := _brush(r, clampf(strength, 0.0, 1.0))
	var half := brush.get_width() / 2
	image.blend_rect(brush, Rect2i(0, 0, brush.get_width(), brush.get_height()), Vector2i(int(floor(u * PX)) - half, int(floor(v * PX)) - half))
	_dirty = true
	_since_mark = 0.0


## A white disc whose alpha falls from strength at the middle to 0 at r (cached by
## quarter pixel radius and 1/64 strength).
func _brush(r: float, s: float) -> Image:
	var rq := roundi(r * 4.0)
	var sq := roundi(s * 64.0)
	var key := rq * 1000 + sq
	if _brushes.has(key):
		return _brushes[key]
	var rr := rq / 4.0
	var ss := sq / 64.0
	var c := int(ceil(rr))
	var n := c * 2 + 1
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for j in n:
		for i in n:
			var dd := Vector2(i - c, j - c).length()
			img.set_pixel(i, j, Color(1, 1, 1, ss * maxf(0.0, 1.0 - dd / rr)))
	_brushes[key] = img
	return img


## How pressed the ground is at (x, z), 0–1.
func at(x: float, z: float) -> float:
	var u := (x - center.x) / SIZE + 0.5
	var v := (z - center.y) / SIZE + 0.5
	if u < 0.0 or v < 0.0 or u > 1.0 or v > 1.0:
		return 0.0
	return image.get_pixel(mini(int(u * PX), PX - 1), mini(int(v * PX), PX - 1)).r


func update(dt: float) -> void:
	_since_mark += dt
	_upload += dt
	if _since_mark < QUIET:
		# The fade: every row darkens by 2 % once per half second, a band at a time.
		_fade_rows += dt / FADE_EVERY * PX
		var rows := mini(int(_fade_rows), PX)
		if rows > 0:
			_fade_rows -= rows
			while rows > 0:
				var k := mini(rows, PX - _fade_row)
				image.blend_rect(_fade_band, Rect2i(0, 0, PX, k), Vector2i(0, _fade_row))
				_fade_row = (_fade_row + k) % PX
				rows -= k
			_since_fade_upload += dt
	elif _since_mark < QUIET + 1.0:
		# Long quiet: what is left (8-bit leftovers the fade can't reach) heals at once.
		image.fill(Color.BLACK)
		_since_mark = QUIET + 1.0
		_dirty = true
	# Upload a few times a second while marks come in, every half second while only fading.
	if _upload > UPLOAD_EVERY and (_dirty or _since_fade_upload > FADE_EVERY):
		_upload = 0.0
		_dirty = false
		_since_fade_upload = 0.0
		texture.update(image)
