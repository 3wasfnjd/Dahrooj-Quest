class_name DahroojView
extends Node3D
## Dahrooj as drawn in the web game (src/reference/character.js make()): the body in his
## style (jelly, fur or bubble; legacy fabric and clay too) tinted by the saved colour,
## glossy 3D eyes, the drawn face (mouth and blush) on a cap over the front, the jelly's
## bandage or the fur ball's ribbon, and the accessory he wears. Radius in game units.
## Front is +Z; show_at() turns him toward a point and squashes him. set_look() changes
## style, colour and accessory (materials and meshes shared: dahrooj_looks.gd).
##
## Draws: body, face cap, 6 eye parts, and one each for the ribbon or bandage and the
## accessory when shown.

const FACE_SPAN := PI * 0.62
const EYE_FACES := ["open", "focus", "wide", "joy"]
const FACES := ["open", "focus", "wide", "joy", "closed", "squint", "laugh"]
const BOW_AT := DahroojLooks.BOW_AT

static var _shared := {}

var r := Ball.BR
## Fewer facets (character.js make(style, {lite: true}): the world's resting balls).
var lite := false
var style := ""
var color_id := ""
var accessory := ""
var inner: Node3D
var body: MeshInstance3D
var cap: MeshInstance3D
var eyes: Array = []  # {s, pivot, ball, pupil, white}
var bow: MeshInstance3D
var bandage: MeshInstance3D
var acc: MeshInstance3D
var _face := ""


func _init(radius := Ball.BR, lite_ := false) -> void:
	r = radius
	lite = lite_
	inner = Node3D.new()
	add_child(inner)
	_build()
	set_look("fur", "pink", "")


static func _sphere_mesh(radius: float, segs: int, rings: int) -> ArrayMesh:
	return DahroojLooks.body_mesh(radius, segs, rings)


static func _face_mat(face: String) -> Material:
	return DahroojLooks.face_material(face)


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
	body.mesh = _sphere_mesh(r, 24 if lite else 32, 16 if lite else 20)
	inner.add_child(body)
	# 3D eyes, where the drawing puts them.
	var er := r * 0.19
	var eye_mesh := _sphere_mesh(1.0, 12 if lite else 24, 8 if lite else 16)
	for s in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.rotation_order = EULER_ORDER_YXZ
		inner.add_child(pivot)
		var ball := Node3D.new()
		ball.position.z = r - er * 0.22
		pivot.add_child(ball)
		var white := MeshInstance3D.new()
		white.mesh = eye_mesh
		white.material_override = DahroojLooks.eye_material("sclera")
		white.scale = Vector3(er, er * 1.12, er * 0.55)
		ball.add_child(white)
		var pupil := Node3D.new()
		pupil.position.z = er * 0.42
		ball.add_child(pupil)
		var dot := MeshInstance3D.new()
		dot.mesh = eye_mesh
		dot.material_override = DahroojLooks.eye_material("pupil")
		dot.scale = Vector3(er * 0.55, er * 0.55, er * 0.22)
		pupil.add_child(dot)
		var glint := MeshInstance3D.new()
		glint.mesh = eye_mesh
		glint.material_override = DahroojLooks.eye_material("glint")
		glint.scale = Vector3.ONE * er * 0.15
		glint.position = Vector3(-er * 0.2, er * 0.22, er * 0.2)
		pupil.add_child(glint)
		# Eyes, ribbon and bandage cast no shadow (three's default), only body and accessory.
		for part in [white, dot, glint]:
			(part as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eyes.append({"s": s, "pivot": pivot, "ball": ball, "pupil": pupil, "white": white, "er": er})
	cap = MeshInstance3D.new()
	cap.mesh = _cap_mesh(r * 1.006)
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inner.add_child(cap)
	# The ribbon on top (fur), a little to the left and forward; the bandage (jelly).
	bow = _deco(DahroojLooks.bow_mesh())
	bandage = _deco(DahroojLooks.bandage_mesh())
	acc = _deco(null)
	acc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	set_face("open", false)


func _deco(mesh: Mesh) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = DahroojLooks.acc_material()
	m.scale = Vector3.ONE * r
	m.visible = false
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inner.add_child(m)
	return m


## His look: style (jelly | fur | bubble, or legacy fabric | clay), colour (appearance.ts
## DAHROOJ_COLOR_CHOICES id: original | pink | red | orange | yellow | green | blue | purple)
## and accessory ("" for none). Unknown values fall back as the web store does.
func set_look(style_: String, color: String, accessory_: String) -> void:
	var s := style_ if style_ in DahroojLooks.STYLES else "jelly"
	var c := DahroojLooks.color_id(color)
	var a := DahroojLooks.normalize_accessory(accessory_)
	if s == style and c == color_id and a == accessory:
		return
	style = s
	color_id = c
	accessory = a
	body.material_override = DahroojLooks.body_material(s, c)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if s == "bubble" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	bandage.visible = s == "jelly"
	# A hat takes the place of the fur ball's ribbon.
	bow.visible = s == "fur" and not a in DahroojLooks.HEADWEAR
	acc.visible = a != ""
	if a != "":
		acc.mesh = DahroojLooks.accessory_mesh(a)
		acc.scale = Vector3.ONE * r * (1.08 if s == "fur" else 1.0)
	var sclera := DahroojLooks.eye_material("sclera_felt" if s == "fabric" else "sclera")
	for e in eyes:
		(e.white as MeshInstance3D).material_override = sclera


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
