class_name Crowd
extends Node3D
## Crowds: lots of little Dahroojs in a handful of draws (src/reference/character.js crowd()).
## Used by the opening and Dahrooj Rain (and could carry shots). Each style's bodies are
## one MultiMesh (jelly and bubble keep their own shaders and learn the instance colour),
## the eyes are one MultiMesh per look (open / wide / shut; whites, pupils and glints of
## both eyes merged into one mesh), the fur ball's ribbon one, the jelly's bandage one,
## and each accessory one (materials and meshes shared with the full character:
## dahrooj_looks.gd). Positions and sizes are in this node's units (metres when it
## sits in the rig).
##
## begin(); add(style, pos, radius, toward, squash, eyes, accessory, color) per ball; end().

const DAHROOJ_COLORS := DahroojLooks.DAHROOJ_COLORS
const STYLES := DahroojLooks.STYLES
const HEADWEAR := DahroojLooks.HEADWEAR
## The accessories built up front for crowds (the rain's own seven); any other one of
## DahroojLooks.ACCESSORIES (lite, with its glass) on first use.
const ACCESSORIES := ["party", "glasses", "cap", "flower", "crown", "headphones", "scarf"]
const EYE_LOOKS := {"open": [1.0, 1.0], "wide": [1.0, 0.42 / 0.55], "shut": [0.12, 1.0]}
const ER := 0.19
const BOW_AT := DahroojLooks.BOW_AT

static var _cache := {}

var max_n := 120
var with_accessories := false
## The drawn face (mouth and blush) on a cap: not in the original crowd, so off by default.
var with_faces := false
## Default colour per style (sRGB) when add() gets no colour: DAHROOJ_COLORS.
var tints := {}
var parts := {}  # name -> {mm: MultiMesh, mi: MultiMeshInstance3D, n: int, cap: int}


func _init(max_count := 120, accessories := false, faces := false) -> void:
	max_n = max_count
	with_accessories = accessories
	with_faces = faces
	for s in DAHROOJ_COLORS:
		tints[s] = Color(DAHROOJ_COLORS[s])
	for s in STYLES:
		_part("body_" + s, _body_mesh(), _body_mat(s), max_n, true, 3 if s == "bubble" else 0)
	for look in EYE_LOOKS:
		_part("eyes_" + look, _eyes_mesh(look), _eye_mat(), max_n)
	_part("bow", _bow_mesh(), _deco_mat(), max_n)
	_part("bandage", _bandage_mesh(), _deco_mat(), max_n)
	if with_accessories:
		for id in ACCESSORIES:
			_part("acc_" + id, _accessory_mesh(id), _deco_mat(), max_n)
	if with_faces:
		for f in ["open", "wide"]:
			_part("face_" + f, DahroojView._cap_mesh(1.006), DahroojLooks.face_material(f), max_n)


func _part(id: String, mesh: Mesh, mat: Material, cap: int, colors := false, priority := 0) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	mm.instance_count = cap
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.name = id
	mi.multimesh = mm
	mi.material_override = mat
	mi.sorting_offset = float(priority)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-40, -20, -40), Vector3(80, 60, 80))
	add_child(mi)
	parts[id] = {"mm": mm, "mi": mi, "n": 0, "cap": cap}


func begin() -> void:
	for id in parts:
		parts[id].n = 0


func _put(id: String, m: Transform3D, color = null) -> void:
	var p: Dictionary = parts[id]
	var n: int = p.n
	if n >= int(p.cap):
		return
	var mm: MultiMesh = p.mm
	mm.set_instance_transform(n, m)
	if color != null:
		mm.set_instance_color(n, color)
	p.n = n + 1


static func _color(c) -> Color:
	if c is Color:
		return c
	if c is int:
		return Color.hex(((c as int) << 8) | 0xff)
	return Color(str(c))


## One ball: style, centre, radius, the point it faces (or null), squash (sx, sy),
## eyes "open" | "wide" | "shut" | "" (none), accessory id ("" for none), colour
## (Color, 0xRRGGBB or "rrggbb"; null for the style's own).
func add(style: String, pos: Vector3, radius: float, toward, squash := Vector2.ONE, eyes := "open", accessory := "", color = null) -> void:
	var body := "body_" + style
	if not parts.has(body):
		body = "body_jelly"
	if int(parts[body].n) >= max_n:
		return
	var m := place(pos, radius, toward, squash)
	var tint: Color = _color(color) if color != null else (tints.get(style, Color.WHITE) as Color)
	_put(body, m, tint.srgb_to_linear())
	if style == "jelly":
		_put("bandage", m)
	if with_accessories and accessory != "" and not parts.has("acc_" + accessory) and accessory in DahroojLooks.ACCESSORIES:
		# The other accessories are built the first time a ball wears one.
		_part("acc_" + accessory, _accessory_mesh(accessory), _deco_mat(), max_n)
		if accessory in DahroojLooks.GLASS:
			_part("glass_" + accessory, DahroojLooks.accessory_glass(accessory, true), DahroojLooks.glass_material(), max_n)
	if parts.has("acc_" + accessory):
		var am := m * Transform3D(Basis.from_scale(Vector3.ONE * 1.08), Vector3.ZERO) if style == "fur" else m
		_put("acc_" + accessory, am)
		if parts.has("glass_" + accessory):
			_put("glass_" + accessory, am)
	if style == "fur" and accessory not in HEADWEAR:
		_put("bow", m)
	if eyes != "":
		_put("eyes_" + (eyes if EYE_LOOKS.has(eyes) else "open"), m)
		if with_faces:
			_put("face_" + ("wide" if eyes == "wide" else "open"), m)


## A ball's instance transform: at pos, radius big, squashed (in world axes), its +Z (face)
## toward the point asked.
static func place(pos: Vector3, radius: float, toward, squash := Vector2.ONE) -> Transform3D:
	var r := Basis.IDENTITY
	if toward != null:
		var d: Vector3 = (toward as Vector3) - pos
		if d.length_squared() > 1e-12:
			var dn := d.normalized()
			r = Basis.looking_at(dn, Vector3.UP if absf(dn.y) < 0.9999 else Vector3.BACK, true)
	return Transform3D(Basis.from_scale(Vector3(radius * squash.x, radius * squash.y, radius * squash.x)) * r, pos)


func end() -> void:
	for id in parts:
		(parts[id].mm as MultiMesh).visible_instance_count = int(parts[id].n)


## Balls drawn (bodies of every style).
func count() -> int:
	var n := 0
	for s in STYLES:
		n += int(parts["body_" + s].n)
	return n


func part_count(id: String) -> int:
	return int(parts[id].n) if parts.has(id) else 0


# --- materials (dahrooj_looks.gd) ------------------------------------------------------------

## Eyes: glossy whites and pupils (roughness in the vertex alpha) and glowing glints (alpha 1).
const EYE_SHADER := """
shader_type spatial;
render_mode cull_back;
void fragment() {
	if (COLOR.a > 0.99) {
		ALBEDO = vec3(0.0);
		EMISSION = COLOR.rgb;
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
	} else {
		ALBEDO = COLOR.rgb;
		ROUGHNESS = COLOR.a;
		SPECULAR = 0.6;
	}
}
"""




static func _shader_mat(key: String, code: String) -> ShaderMaterial:
	if not _cache.has(key):
		var sh := Shader.new()
		sh.code = code
		var m := ShaderMaterial.new()
		m.shader = sh
		_cache[key] = m
	return _cache[key]


## Each style's body, its colour from the instance; bubbles draw after the rest.
static func _body_mat(style: String) -> Material:
	if style == "bubble":
		if not _cache.has("bubble"):
			var b := (DahroojLooks.body_material("bubble", "", true) as ShaderMaterial).duplicate() as ShaderMaterial
			b.render_priority = 3
			_cache["bubble"] = b
		return _cache["bubble"]
	return DahroojLooks.body_material(style, "", true)


static func _eye_mat() -> Material:
	return _shader_mat("eyes", EYE_SHADER)


static func _deco_mat() -> Material:
	return DahroojLooks.acc_material()


# --- geometry (dahrooj_looks.gd: three.js generators, so the shapes match) ------------------

static func sphere(r: float, ws: int, hs: int, phi0 := 0.0, phi_len := TAU, th0 := 0.0, th_len := PI) -> Dictionary:
	return DahroojLooks.sphere(r, ws, hs, phi0, phi_len, th0, th_len)


static func cylinder(rt: float, rb: float, h: float, rs: int, open := false, th0 := 0.0, th_len := TAU) -> Dictionary:
	return DahroojLooks.cylinder(rt, rb, h, rs, open, th0, th_len)


static func torus(R: float, tube: float, rs: int, ts: int, arc := TAU) -> Dictionary:
	return DahroojLooks.torus(R, tube, rs, ts, arc)


static func box(w: float, h: float, d: float) -> Dictionary:
	return DahroojLooks.box(w, h, d)


static func circle(r: float, segs: int) -> Dictionary:
	return DahroojLooks.circle(r, segs)


static func xf(pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, order := EULER_ORDER_XYZ) -> Transform3D:
	return DahroojLooks.xf(pos, rot, scl, order)


static func merge(list: Array, with_uv := false) -> ArrayMesh:
	return DahroojLooks.merge(list, with_uv)


static func _cached(key: String, build: Callable) -> ArrayMesh:
	if not _cache.has(key):
		_cache[key] = build.call()
	return _cache[key]


## Small balls need fewer facets: SphereGeometry(r, 16, 12), unit radius.
static func _body_mesh() -> ArrayMesh:
	return DahroojLooks.body_mesh(1.0, 16, 12)


## Both eyes for one look, in the ball's own frame (unit radius): [white, pupil, glint] per side.
static func _eyes_mesh(look: String) -> ArrayMesh:
	return _cached("eyes_" + look, func() -> ArrayMesh:
		var open: float = EYE_LOOKS[look][0]
		var pr: float = EYE_LOOKS[look][1]
		var eye := sphere(1.0, 10, 6)
		var glint := sphere(1.0, 6, 4)
		var list := []
		for s in [-1.0, 1.0]:
			var pivot := Transform3D(Basis.from_euler(Vector3(-0.08, s * 0.31, 0), EULER_ORDER_YXZ), Vector3.ZERO)
			var ball := pivot * xf(Vector3(0, 0, 1.0 - ER * 0.22), Vector3.ZERO, Vector3(1, open, 1))
			var pupil := ball * xf(Vector3(0, 0, ER * 0.42), Vector3.ZERO, Vector3(pr, pr, 1))
			list.append([eye, ball * xf(Vector3.ZERO, Vector3.ZERO, Vector3(ER, ER * 1.12, ER * 0.55)), Color(Color("fffaf2"), 0.2)])
			list.append([eye, pupil * xf(Vector3.ZERO, Vector3.ZERO, Vector3(ER * 0.55, ER * 0.55, ER * 0.22)), Color(Color("2c2d3d"), 0.06)])
			list.append([glint, pupil * xf(Vector3(-ER * 0.2, ER * 0.22, ER * 0.2), Vector3.ZERO, Vector3.ONE * ER * 0.15), Color(1, 1, 1, 1)])
		return merge(list))


## The fur ball's ribbon: two loops and a knot where bow() puts them.
static func _bow_mesh() -> ArrayMesh:
	return DahroojLooks.bow_mesh(true)


## The jelly's bandage on its surface, tilted.
static func _bandage_mesh() -> ArrayMesh:
	return DahroojLooks.bandage_mesh()


## The lite (crowd) accessories of character.js accessory(id, true), unit radius, face +Z.
static func _accessory_mesh(id: String) -> ArrayMesh:
	return DahroojLooks.accessory_mesh(id, true)
