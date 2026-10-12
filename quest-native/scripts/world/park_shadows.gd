class_name ParkShadows
extends Node
## nature.js drop shadows: the trees, bushes, pebbles, poles, benches, lanterns and
## crates cast Motri's shadow on the ground and the grass. Nothing moves on its own,
## so the shadows are drawn into a 1024 x 1024 picture over 112 x 112 game units
## (white = shadow): the still casters once (softened like Motri's filtered shadow
## map, blur 2 px), the shoved props on top whenever one moves (at most every 0.15 s).
## The drawing is Godot's 2D canvas in SubViewports that render only on demand, so it
## costs the headset nothing between redraws. Shapes as nature.js: blob (a disc where
## a point h up lands along the light), stick (a round-capped stroke from h0 to h1),
## box (a turned rectangle).

const PX := 1024
const SIZE := 112.0

var center := Vector2(0, -10)
var kx := 0.0
var kz := 0.0
## Still casters: [0 blob, x, z, h, r, a] / [1 stick, x, z, h0, h1, w, a] / [2 box, x, z, h, rot, hx, hz, a].
var casters: Array = []
## Draws the moving props: func(s: ParkShadows, ci: CanvasItem).
var dynamic_draw := Callable()
var static_dirty := true
var dirty := true
var texture: Texture2D
var _wait := 0.0
var _stage := 0
var _static_vp: SubViewport
var _blur_vp: SubViewport
var _final_vp: SubViewport
var _static_node: Node2D
var _dyn_node: Node2D


func setup(c: Vector2, light_dir: Vector3) -> void:
	name = "Shadows"
	center = c
	kx = -light_dir.x / light_dir.y
	kz = -light_dir.z / light_dir.y
	_static_vp = _viewport("ShadowStatic", true)
	_static_node = Node2D.new()
	_static_node.draw.connect(_draw_static)
	_static_vp.add_child(_static_node)
	_blur_vp = _viewport("ShadowBlur", false)
	var blur := TextureRect.new()
	blur.texture = _static_vp.get_texture()
	blur.size = Vector2(PX, PX)
	var bm := ShaderMaterial.new()
	bm.shader = load("res://shaders/shadow_blur.gdshader")
	blur.material = bm
	_blur_vp.add_child(blur)
	_final_vp = _viewport("ShadowFinal", false)
	var base := TextureRect.new()
	base.texture = _blur_vp.get_texture()
	base.size = Vector2(PX, PX)
	_final_vp.add_child(base)
	_dyn_node = Node2D.new()
	_dyn_node.draw.connect(_draw_dynamic)
	_final_vp.add_child(_dyn_node)
	texture = _final_vp.get_texture()


func _viewport(label: String, transparent: bool) -> SubViewport:
	var vp := SubViewport.new()
	vp.name = label
	vp.size = Vector2i(PX, PX)
	vp.disable_3d = true
	vp.transparent_bg = transparent
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	add_child(vp)
	return vp


func sx(x: float) -> float:
	return (x - center.x) / SIZE * PX + PX * 0.5


func sz(z: float) -> float:
	return (z - center.y) / SIZE * PX + PX * 0.5


func sm(m: float) -> float:
	return m / SIZE * PX


func blob(ci: CanvasItem, x: float, z: float, h: float, r: float, a: float) -> void:
	ci.draw_circle(Vector2(sx(x + kx * h), sz(z + kz * h)), maxf(0.6, sm(r)), Color(1, 1, 1, a), true, -1.0, true)


func stick(ci: CanvasItem, x: float, z: float, h0: float, h1: float, w: float, a: float) -> void:
	var p0 := Vector2(sx(x + kx * h0), sz(z + kz * h0))
	var p1 := Vector2(sx(x + kx * h1), sz(z + kz * h1))
	var r := maxf(0.8, sm(w)) * 0.5
	var d := p1 - p0
	if d.length() < 1e-3:
		ci.draw_circle(p0, r, Color(1, 1, 1, a), true, -1.0, true)
		return
	# One round-capped stroke as a single convex polygon (no double alpha at the caps).
	var ang := d.angle()
	var pts := PackedVector2Array()
	for i in 9:
		var t := ang - PI * 0.5 + PI * i / 8.0
		pts.append(p1 + Vector2(cos(t), sin(t)) * r)
	for i in 9:
		var t := ang + PI * 0.5 + PI * i / 8.0
		pts.append(p0 + Vector2(cos(t), sin(t)) * r)
	ci.draw_colored_polygon(pts, Color(1, 1, 1, a))


func box(ci: CanvasItem, x: float, z: float, h: float, rot: float, hx: float, hz: float, a: float) -> void:
	var c := Vector2(sx(x + kx * h), sz(z + kz * h))
	var e := Vector2(sm(hx), sm(hz))
	var pts := PackedVector2Array([Vector2(-e.x, -e.y), Vector2(e.x, -e.y), Vector2(e.x, e.y), Vector2(-e.x, e.y)])
	for i in 4:
		pts[i] = c + pts[i].rotated(-rot)
	ci.draw_colored_polygon(pts, Color(1, 1, 1, a))


func add_blob(x: float, z: float, h: float, r: float, a: float) -> void:
	casters.append([0, x, z, h, r, a])
	static_dirty = true
	dirty = true


func add_stick(x: float, z: float, h0: float, h1: float, w: float, a: float) -> void:
	casters.append([1, x, z, h0, h1, w, a])
	static_dirty = true
	dirty = true


func _draw_static() -> void:
	for c: Array in casters:
		match int(c[0]):
			0: blob(_static_node, c[1], c[2], c[3], c[4], c[5])
			1: stick(_static_node, c[1], c[2], c[3], c[4], c[5], c[6])
			2: box(_static_node, c[1], c[2], c[3], c[4], c[5], c[6], c[7])


func _draw_dynamic() -> void:
	if dynamic_draw.is_valid():
		dynamic_draw.call(self, _dyn_node)


func _process(delta: float) -> void:
	update(delta)


## Redraw a few times a second at most, and only after something moved. The still
## layer, its blur and the final picture render on three successive frames. Runs on
## its own (_process), so the shadows are baked even before the park is updated.
func update(dt: float) -> void:
	_wait -= dt
	if _stage == 1:
		_blur_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		_stage = 2
		return
	if _stage == 2:
		_dyn_node.queue_redraw()
		_final_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		_stage = 0
		return
	if dirty and _wait <= 0.0:
		dirty = false
		_wait = 0.15
		if static_dirty:
			static_dirty = false
			_static_node.queue_redraw()
			_static_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			_stage = 1
		else:
			_dyn_node.queue_redraw()
			_final_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
