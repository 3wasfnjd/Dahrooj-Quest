class_name DahroojView
extends Node3D
## Dahrooj as drawn in the web game (src/reference/character.js, fur style, the
## default): a fur ball with soft patches, tinted by the saved colour (pink by
## default), glossy 3D eyes, the drawn face (mouth and blush) on a cap over the
## front, and the red ribbon on top. Radius in game units. Front is +Z; show_at()
## turns him toward a point and squashes him.

const FACE_SPAN := PI * 0.62
const EYE_FACES := ["open", "focus", "wide", "joy"]
const FACES := ["open", "focus", "wide", "joy", "closed", "squint", "laugh"]
const BOW_AT := Vector3(-0.1, 0.86, 0.5)

static var _shared := {}

var r := Ball.BR
var inner: Node3D
var body: MeshInstance3D
var cap: MeshInstance3D
var eyes: Array = []  # {s, pivot, ball, pupil}
var bow: Node3D
var _face := ""


func _init(radius := Ball.BR) -> void:
	r = radius
	inner = Node3D.new()
	add_child(inner)
	_build()


static func _tex(path: String) -> Texture2D:
	if not _shared.has(path):
		_shared[path] = load(path)
	return _shared[path]


static func _mat(key: String) -> Material:
	if _shared.has(key):
		return _shared[key]
	var m := StandardMaterial3D.new()
	match key:
		"fur":
			m.albedo_texture = _tex("res://assets/character/fur.png")
			m.albedo_color = Color("ff69b4")  # the saved colour (pink by default) tints the fur
			m.roughness = 0.95
			m.metallic_specular = 0.25
		"sclera":
			m.albedo_color = Color("fffaf2")
			m.roughness = 0.2
			m.clearcoat_enabled = true
			m.clearcoat = 1.0
		"pupil":
			m.albedo_color = Color("2c2d3d")
			m.roughness = 0.06
			m.clearcoat_enabled = true
			m.clearcoat = 1.0
		"glint":
			m.albedo_color = Color.WHITE
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		"bow":
			m.albedo_color = Color("d8452f")
			m.roughness = 0.45
		"bow_dark":
			m.albedo_color = Color("b8432a")
			m.roughness = 0.6
	_shared[key] = m
	return m


static func _face_mat(face: String) -> Material:
	var key := "face_" + face
	if not _shared.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = _tex("res://assets/character/face_%s.png" % face)
		m.render_priority = 1
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_shared[key] = m
	return _shared[key]


static func _sphere_mesh(radius: float, segs: int, rings: int) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = segs
	s.rings = rings
	return s


## The cap for the drawn face: a patch of the sphere where angle maps linearly to
## the face picture, as three.js's SphereGeometry(phiStart, phiLength, thetaStart,
## thetaLength) does in the web game.
static func _cap_mesh(radius: float) -> ArrayMesh:
	var key := "cap_%f" % radius
	if _shared.has(key):
		return _shared[key]
	var n := 24
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p0 := PI / 2 - FACE_SPAN / 2
	var verts := []
	for j in n + 1:
		for i in n + 1:
			var phi := p0 + FACE_SPAN * i / n
			var theta := p0 + FACE_SPAN * j / n
			var dir := Vector3(-cos(phi) * sin(theta), cos(theta), sin(phi) * sin(theta))
			verts.append([dir * radius, dir, Vector2(float(i) / n, float(j) / n)])
	for j in n:
		for i in n:
			var a := j * (n + 1) + i
			for k in [a, a + n + 1, a + 1, a + 1, a + n + 1, a + n + 2]:
				st.set_normal(verts[k][1])
				st.set_uv(verts[k][2])
				st.add_vertex(verts[k][0])
	var mesh := st.commit()
	_shared[key] = mesh
	return mesh


func _build() -> void:
	body = MeshInstance3D.new()
	body.mesh = _sphere_mesh(r, 32, 20)
	body.material_override = _mat("fur")
	inner.add_child(body)
	# 3D eyes, where the drawing puts them.
	var er := r * 0.19
	for s in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.rotation_order = EULER_ORDER_YXZ
		inner.add_child(pivot)
		var ball := Node3D.new()
		ball.position.z = r - er * 0.22
		pivot.add_child(ball)
		var white := MeshInstance3D.new()
		white.mesh = _sphere_mesh(1.0, 24, 16)
		white.material_override = _mat("sclera")
		white.scale = Vector3(er, er * 1.12, er * 0.55)
		ball.add_child(white)
		var pupil := Node3D.new()
		pupil.position.z = er * 0.42
		ball.add_child(pupil)
		var dot := MeshInstance3D.new()
		dot.mesh = white.mesh
		dot.material_override = _mat("pupil")
		dot.scale = Vector3(er * 0.55, er * 0.55, er * 0.22)
		pupil.add_child(dot)
		var glint := MeshInstance3D.new()
		glint.mesh = white.mesh
		glint.material_override = _mat("glint")
		glint.scale = Vector3.ONE * er * 0.15
		glint.position = Vector3(-er * 0.2, er * 0.22, er * 0.2)
		pupil.add_child(glint)
		eyes.append({"s": s, "pivot": pivot, "ball": ball, "pupil": pupil, "er": er})
	cap = MeshInstance3D.new()
	cap.mesh = _cap_mesh(r * 1.006)
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inner.add_child(cap)
	# The ribbon on top, a little to the left and forward.
	bow = Node3D.new()
	bow.position = BOW_AT.normalized() * r * 1.06
	bow.rotation = Vector3(-0.15, -0.1, 0.15)
	inner.add_child(bow)
	for s in [-1.0, 1.0]:
		var loop := MeshInstance3D.new()
		loop.mesh = _sphere_mesh(r * 0.17, 20, 14)
		loop.material_override = _mat("bow")
		loop.scale = Vector3(1.2, 0.9, 0.6)
		loop.position = Vector3(s * r * 0.2, 0, 0)
		loop.rotation.z = s * 0.35
		bow.add_child(loop)
		var tail := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = r * 0.06
		cone.height = r * 0.3
		cone.radial_segments = 10
		tail.mesh = cone
		tail.material_override = _mat("bow_dark")
		tail.position = Vector3(s * r * 0.09, -r * 0.19, r * 0.12)
		tail.rotation = Vector3(0.35, 0, s * 0.35)
		bow.add_child(tail)
	var knot := MeshInstance3D.new()
	knot.mesh = _sphere_mesh(r * 0.07, 12, 10)
	knot.material_override = _mat("bow_dark")
	bow.add_child(knot)
	set_face("open", false)


func set_face(face: String, blink: bool, look := Vector2.ZERO) -> void:
	var with_eyes := face in EYE_FACES
	for e in eyes:
		e.pivot.visible = with_eyes
		if not with_eyes:
			continue
		var open := 0.12 if blink else (0.6 if face == "focus" else 1.0)
		var pr := (0.42 if face == "wide" else (0.66 if face == "joy" else 0.55)) / 0.55
		e.pivot.rotation = Vector3(-(0.08 - look.y * 0.06), e.s * 0.31 + look.x * 0.08, 0)
		e.ball.scale = Vector3(1, open, 1)
		e.pupil.position.x = look.x * e.er * 0.42
		e.pupil.position.y = -look.y * e.er * 0.48
		e.pupil.scale = Vector3(pr, pr, 1)
	if face != _face:
		_face = face
		cap.material_override = _face_mat(face if face in FACES else "open")


## pos: centre (parent units); toward: a point he faces; squash: (sx, sy).
func show_at(p: Vector3, toward, face: String, blink: bool, squash := Vector2.ONE) -> void:
	position = p
	scale = Vector3(squash.x, squash.y, squash.x)
	if toward != null:
		var dir: Vector3 = toward - p
		if dir.length_squared() > 1e-6:
			inner.basis = Basis.looking_at(-dir.normalized(), Vector3.UP)
	set_face(face, blink)
