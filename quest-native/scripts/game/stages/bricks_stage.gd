class_name BricksStage
extends Node3D
## The brick wall (src/reference/stages/bricks.js): five levels of stone bricks that grow in,
## break with a tink and a star when Dahrooj (or a blaster shot) hits them, and a castle
## tower each side in a new design every level, with waving flags. Game units.

# Big, so the bricks read clearly, and Dahrooj comes back to you off the wall. In the headset it stands
# about as far off as the goal and the cans (reachZ), a little nearer.
const BZ := -10.0
const WW := 8.6
const WH := 4.1
const FACE := BZ + 0.1
const BW := 0.98
const BH := 0.48
const BD := 0.34
const GAP := 0.07
# Stone bricks in the colours of the headset's slab floor (between its low and high tones), each a
# slightly different shade like the slabs, matte with a soft sheen.
# Each level takes another stone, always a natural one: the slab floor's sandstone, grey granite, red brick,
# dark basalt and pale limestone (low and high tones; the bricks are shades between them).
const PALETTES := [["#a87762", "#ffcf8b"], ["#8f8274", "#dccdb9"], ["#844331", "#c47452"], ["#6f6257", "#b3a492"], ["#b8946a", "#f0dcb8"]]
const SHADES := [.38, .5, .6, .7, .8, .9]
# Levels: rows of columns that hold a brick (8 columns, offset every other row like real masonry).
const LEVELS := [
	["11111111", "11111111", "11111111", "11111111", "11111111", "11111111"],
	["10101010", "01010101", "10101010", "01010101", "10101010", "01010101"],
	["00011000", "00111100", "01111110", "11111111", "11111111", "11111111"],
	["11100111", "11111111", "11111111", "01111110", "00111100", "00011000"],
	["11111111", "11000011", "10111101", "10111101", "11000011", "11111111"],
]
const TX := 4 * (BW + GAP) + (2 * BW + GAP) / 2 + 0.25
const ZC := FACE + BD / 2 + 0.01 - 0.75 + BD / 2
## stand-in for confetti.celebrate's camera distance (the player's head near the throw spot)
const CAMERA := Vector3(0, 1.6, 0)

var aim_z := FACE + BD
var far_z = BZ - 0.5
var reach_z = -18.5
var friction = null
var shot_time = 7.0
var ctx: GameCtx

var B := {"bricks": [], "level": 0, "cleared": false, "broke_shot": false, "fx": [], "stone": null, "make": Callable(), "auto_t": 0.0}
var level: int:
	get:
		return B.level
var brick_mats: Array = []
var mat_cache := {}
var stone_cache := {}
var brick_mesh: Mesh
var star_mat: StandardMaterial3D
var star_mesh: ArrayMesh
var decor: Array = []
var towers: Array = []
var tower_boxes: Array = []
var roof_mats := {}
var flags: Array = []
var pole_mat: StandardMaterial3D
var cloth_mat: StandardMaterial3D
var _ball: Ball
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 23
	name = "Bricks"
	StageArt.ground_line(self, -14, BZ, 14, BZ)
	brick_mats = mats_for(0)
	var proto := StageArt.rbox(BW, BH, BD, 0.07, brick_mats[0])
	brick_mesh = proto.mesh
	proto.free()
	star_mat = StandardMaterial3D.new()
	star_mat.albedo_color = Color("f2c14e")
	star_mat.emission_enabled = true
	star_mat.emission = Color("f2c14e")
	star_mat.emission_energy_multiplier = 0.5
	star_mat.roughness = 0.3
	star_mesh = _octahedron(0.11)
	pole_mat = StandardMaterial3D.new()
	pole_mat.albedo_color = Color("8a5a34")
	pole_mat.roughness = 0.6
	cloth_mat = StandardMaterial3D.new()
	cloth_mat.albedo_color = Color("e2603f")
	cloth_mat.roughness = 0.7
	cloth_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	layout()


## three.js Color.lerp works on linear values.
static func _lerp_lin(a: Color, b: Color, k: float) -> Color:
	return a.srgb_to_linear().lerp(b.srgb_to_linear(), k).linear_to_srgb()


func mats_for(pi: int) -> Array:
	if not mat_cache.has(pi):
		var list: Array = []
		for k in SHADES:
			var m := StandardMaterial3D.new()
			m.albedo_color = _lerp_lin(Color(PALETTES[pi][0]), Color(PALETTES[pi][1]), k)
			m.roughness = 0.72
			list.append(m)
		mat_cache[pi] = list
	return mat_cache[pi]


func stone_for(pi: int) -> Array:
	if not stone_cache.has(pi):
		var make: Callable = B.make
		stone_cache[pi] = mats_for(pi).map(func(m): return make.call(m.albedo_color))
	return stone_cache[pi]


func _mats_now() -> Array:
	return B.stone if B.stone != null else brick_mats


static func _octahedron(r: float) -> ArrayMesh:
	var v := [Vector3(r, 0, 0), Vector3(-r, 0, 0), Vector3(0, r, 0), Vector3(0, -r, 0), Vector3(0, 0, r), Vector3(0, 0, -r)]
	var faces := [[0, 2, 4], [0, 4, 3], [0, 3, 5], [0, 5, 2], [1, 2, 5], [1, 5, 3], [1, 3, 4], [1, 4, 2]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in faces:
		var a: Vector3 = v[f[0]]
		var b: Vector3 = v[f[1]]
		var c: Vector3 = v[f[2]]
		var n := (a + b + c).normalized()
		var order := [a, b, c]
		if (b - a).cross(c - a).dot(n) > 0.0:
			order = [a, c, b]
		for p in order:
			st.set_normal(n)
			st.add_vertex(p)
	return st.commit()


func _fx_holds(m: Node) -> bool:
	for f in B.fx:
		if f.brick == m:
			return true
	return false


func layout() -> void:
	for b in B.bricks:
		remove_child(b.mesh)
		if not _fx_holds(b.mesh):
			b.mesh.free()
	B.bricks.clear()
	var pi: int = B.level % PALETTES.size()
	brick_mats = mats_for(pi)
	B.stone = stone_for(pi) if B.make.is_valid() else null
	var rows: Array = LEVELS[B.level % LEVELS.size()].duplicate()
	rows.reverse()  # patterns read top to bottom; row 0 sits on the ground
	for r in rows.size():
		var row: String = rows[r]
		for c in 8:
			if row[c] != "1":
				continue
			# Every other row sits a little over, like laid bricks.
			var x := (c - 3.5) * (BW + GAP) + (0.25 if r % 2 else -0.12)
			var y := 0.01 + r * (BH + GAP * 0.6) + BH / 2
			var mi: int = (r * 5 + c * 3 + B.level) % brick_mats.size()
			var m := MeshInstance3D.new()
			m.mesh = brick_mesh
			m.material_override = _mats_now()[mi]
			m.position = Vector3(x, y, FACE + BD / 2 + 0.01)
			m.scale = Vector3.ONE * 0.001
			add_child(m)
			B.bricks.append({"mesh": m, "mi": mi, "alive": true, "grow": -(r * 8 + c) * 0.025, "half": Vector3(BW / 2, BH / 2, BD / 2)})
	B.cleared = false
	build_towers(B.level)


# The castle front: a tower each side of the wall, of the same bricks, in a new design every level (a square
# keep, round towers with a roof, tall towers with a jutting crown, stepped towers, round towers with
# battlements). They rise out of the ground like the bricks grow in. They don't break; Dahrooj bounces off
# them. Each tower's bricks are merged into one mesh per shade, so a tower costs a handful of draws.
static func row_y(r: float) -> float:
	return 0.01 + r * (BH + GAP * 0.6) + BH / 2


func roof_for(pi: int) -> StandardMaterial3D:
	if not roof_mats.has(pi):
		var m := StandardMaterial3D.new()
		var c := Color(PALETTES[pi][0]).srgb_to_linear()
		m.albedo_color = Color(c.r * 0.72, c.g * 0.72, c.b * 0.72).linear_to_srgb()
		m.roughness = 0.8
		roof_mats[pi] = m
	return roof_mats[pi]


## three.js ConeGeometry(r, h, n) drawn flat-shaded (its roof material has flatShading).
static func _flat_cone(r: float, h: float, n: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var apex := Vector3(0, h / 2, 0)
	for k in n:
		var a0 := float(k) / n * TAU
		var a1 := float(k + 1) / n * TAU
		var p0 := Vector3(r * sin(a0), -h / 2, r * cos(a0))
		var p1 := Vector3(r * sin(a1), -h / 2, r * cos(a1))
		var c := Vector3(0, -h / 2, 0)
		var side_out := Vector3(sin((a0 + a1) / 2), r / h, cos((a0 + a1) / 2))
		for pair in [[[apex, p0, p1], side_out], [[c, p0, p1], Vector3.DOWN]]:
			var tri: Array = pair[0]
			var o: Vector3 = pair[1]
			var A: Vector3 = tri[0]
			var B2: Vector3 = tri[1]
			var C: Vector3 = tri[2]
			var g := (B2 - A).cross(C - A)
			if g.dot(o) > 0.0:  # Godot's front faces wind clockwise
				tri = [A, C, B2]
			var nn := -g.normalized() if g.dot(o) <= 0.0 else g.normalized()
			for v in tri:
				st.set_normal(nn)
				st.add_vertex(v)
	return st.commit()


func merge_parts(parts: Array, mats: Array, into: Node3D) -> void:
	var arrays := brick_mesh.surface_get_arrays(0)
	var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var nor: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx = arrays[Mesh.ARRAY_INDEX]
	for mi in parts.size():
		var list: Array = parts[mi]
		if list.is_empty():
			continue
		var P := PackedVector3Array()
		var N := PackedVector3Array()
		var I := PackedInt32Array()
		var n := pos.size()
		for k in list.size():
			var mat: Transform3D = list[k]
			var nm := mat.basis.inverse().transposed()
			for i in n:
				P.append(mat * pos[i])
				N.append((nm * nor[i]).normalized())
			if idx != null and (idx as PackedInt32Array).size() > 0:
				for j in (idx as PackedInt32Array):
					I.append(j + k * n)
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = P
		a[Mesh.ARRAY_NORMAL] = N
		if not I.is_empty():
			a[Mesh.ARRAY_INDEX] = I
		var g := ArrayMesh.new()
		g.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		var m := MeshInstance3D.new()
		m.mesh = g
		m.material_override = mats[mi]
		into.add_child(m)
		decor.append({"mesh": m, "mi": mi, "roof": false})


## One tower at x = cx in design v; returns its group, its collision box and the height of its top.
func tower(cx: float, side: float, v: int, mats: Array, pi: int) -> Dictionary:
	var parts: Array = []
	for s in SHADES:
		parts.append([])
	var grp2 := Node3D.new()
	var put := func(mi: int, x: float, y: float, z: float, ry: float, sx: float, sy: float, sz: float) -> void:
		var bas := Basis(Vector3.UP, ry) * Basis.from_scale(Vector3(sx, sy, sz))
		parts[posmod(mi, 6)].append(Transform3D(bas, Vector3(x, y, z)))
	# A square shaft w bricks wide and d deep, rows r0..r1, with its core.
	var square := func(w: int, d: float, r0: int, r1: int, dx: float) -> Dictionary:
		var W := w * (BW + GAP) - GAP
		var D := d
		for r in range(r0, r1):
			var y := row_y(r)
			var off := BW * 0.25 if r % 2 else -BW * 0.25
			for fz in [ZC + D / 2 - BD / 2, ZC - D / 2 + BD / 2]:
				for c in w:
					put.call(r * 3 + c * 2 + (1 if side > 0 else 0), cx + dx + (c - (w - 1) / 2.0) * (BW + GAP) + off * 0.4, y, fz, 0.0, 1.0, 1.0, 1.0)
			for sx in [-1, 1]:
				put.call(r * 5 + (1 if sx > 0 else 4), cx + dx + sx * (W / 2 - BD / 2), y, ZC, PI / 2, (D - 2 * BD) / BW * 0.98, 1.0, 1.0)
		put.call(2, cx + dx, (row_y(r0) - BH / 2 + row_y(r1 - 1) + BH / 2) / 2, ZC, 0.0, (W - 0.08) / BW, (row_y(r1 - 1) - row_y(r0) + BH) / BH * 0.98, (D - 0.08) / BD)
		return {"W": W, "D": D}
	# Merlons round the top of a square shaft.
	var merlons := func(W: float, D: float, r: int, dx: float, size: float) -> void:
		var y := row_y(r) - BH * 0.15
		for k in [-1, 0, 1]:
			put.call(k + 3, cx + dx + k * (W / 2 - size / 2), y, ZC + D / 2 - BD / 2, 0.0, size / BW, 1.1, 1.0)
			put.call(k + 4, cx + dx + k * (W / 2 - size / 2), y, ZC - D / 2 + BD / 2, 0.0, size / BW, 1.1, 1.0)
		for sx in [-1, 1]:
			put.call(sx + 3, cx + dx + sx * (W / 2 - BD / 2), y, ZC, PI / 2, size / BW, 1.1, 1.0)
	# A round shaft: n bricks round a ring of radius rad, turned to face out.
	var round_shaft := func(rad: float, n: int, r0: int, r1: int) -> void:
		for r in range(r0, r1):
			var y := row_y(r)
			var a0 := (r % 2) * PI / n
			for k in n:
				var a := a0 + float(k) / n * PI * 2
				put.call(r + k * 2, cx + sin(a) * rad, y, ZC + cos(a) * rad, a, (2 * PI * rad / n) / BW * 0.98, 1.0, 1.0)
		put.call(2, cx, (row_y(r0) - BH / 2 + row_y(r1 - 1) + BH / 2) / 2, ZC, 0.0, (rad * 1.7) / BW, (row_y(r1 - 1) - row_y(r0) + BH) / BH * 0.98, (rad * 1.7) / BD)
	var round_merlons := func(rad: float, n: int, r: int) -> void:
		var y := row_y(r) - BH * 0.15
		for k in range(0, n, 2):
			var a := float(k) / n * PI * 2
			put.call(k, cx + sin(a) * rad, y, ZC + cos(a) * rad, a, (2 * PI * rad / n) / BW * 0.98, 1.1, 1.0)
	var top := 0.0
	var half := Vector3.ZERO
	if v == 0:
		var s: Dictionary = square.call(2, 1.5, 0, 9, 0.0)
		merlons.call(s.W, s.D, 9, 0.0, 0.42)
		top = row_y(9) + BH * 0.4
		half = Vector3(s.W / 2, top / 2, s.D / 2)
	elif v == 1:
		var rad := 0.82
		round_shaft.call(rad, 10, 0, 10)
		top = row_y(10) - BH / 2
		var cone := MeshInstance3D.new()
		cone.mesh = _flat_cone(rad * 1.25, 1.5, 10)  # flatShading: one normal per face
		cone.material_override = roof_for(pi)
		cone.position = Vector3(cx, top + 0.75, ZC)
		grp2.add_child(cone)
		decor.append({"mesh": cone, "roof": true, "mi": 0})
		top += 1.5
		half = Vector3(rad, top / 2, rad)
	elif v == 2:
		square.call(2, 1.4, 0, 11, 0.0)  # a jutting crown: a wider ring of bricks on top
		var c: Dictionary = square.call(3, 2.0, 11, 13, 0.0)
		merlons.call(c.W, c.D, 13, 0.0, 0.4)
		top = row_y(13) + BH * 0.4
		half = Vector3(c.W / 2, top / 2, c.D / 2)
	elif v == 3:
		square.call(3, 2.0, 0, 4, 0.0)
		square.call(2, 1.5, 4, 8, 0.0)
		var c: Dictionary = square.call(1, 1.0, 8, 11, 0.0)
		merlons.call(c.W + 0.3, c.D, 11, 0.0, 0.3)
		top = row_y(11) + BH * 0.4
		half = Vector3((3 * (BW + GAP) - GAP) / 2, top / 2, 1)
	else:
		var rad := 0.95
		round_shaft.call(rad, 12, 0, 8)
		round_merlons.call(rad, 12, 8)
		top = row_y(8) + BH * 0.4
		half = Vector3(rad, top / 2, rad)
	merge_parts(parts, mats, grp2)
	return {"grp": grp2, "box": {"c": Vector3(cx, top / 2, ZC), "h": half}, "top": top, "rise": 0.0}


# Flags: a wooden pole and a coral pennant on each tower top, waving.
func build_towers(lv: int) -> void:
	for t in towers:
		remove_child(t.grp)
		t.grp.free()
	towers = []
	decor = []
	tower_boxes = []
	flags.clear()
	var v := lv % 5
	var pi := lv % PALETTES.size()
	var mats: Array = B.stone if B.stone != null else mats_for(pi)
	for side in [-1.0, 1.0]:
		var t := tower(side * TX, side, v, mats, pi)
		var pole := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.035
		pm.bottom_radius = 0.04
		pm.height = 1.3
		pm.radial_segments = 10
		pm.rings = 1
		pole.mesh = pm
		pole.material_override = pole_mat
		pole.position = Vector3(side * TX, t.top + 0.6, ZC)
		t.grp.add_child(pole)
		var cloth := MeshInstance3D.new()
		cloth.material_override = cloth_mat
		cloth.position = Vector3(side * TX, t.top + 1.05, ZC)
		t.grp.add_child(cloth)
		# PlaneGeometry(0.8, 0.45, 8, 1) moved so its edge sits on the pole
		var base := PackedVector3Array()
		for iy in 2:
			for ix in 9:
				base.append(Vector3(ix * 0.1, 0.225 - iy * 0.45, 0))
		var f := {"cloth": cloth, "base": base, "phase": side, "t": 0.0}
		_flag_mesh(f)
		flags.append(f)
		# Rising out of the ground, the far side a moment after the near.
		t.grp.scale.y = 0.001
		t.rise = -(0.25 if side > 0 else 0.0) - 0.15
		add_child(t.grp)
		towers.append(t)
		tower_boxes.append(t.box)


static func _flag_mesh(f: Dictionary) -> void:
	var base: PackedVector3Array = f.base
	var p := PackedVector3Array()
	for v in base:
		p.append(Vector3(v.x, v.y, sin(v.x * 5 - f.t * 6 + f.phase) * 0.08 * v.x))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in p:
		st.add_vertex(v)
	for ix in 8:
		var a := ix
		var b := ix + 9
		var c := ix + 10
		var d := ix + 1
		# (a b d) (b c d), wound clockwise seen from +z
		for k in [a, d, b, b, d, c]:
			st.add_index(k)
	st.generate_normals()
	(f.cloth as MeshInstance3D).mesh = st.commit()


func _S() -> Ball:
	if ctx and ctx.ball:
		return ctx.ball
	return _ball


func _sfx(n: String, k: float, p: Vector3) -> void:
	if ctx:
		ctx.sfx.call(n, k, p)


## A glassy tink for a broken brick (k: 0..1 picks the pitch).
func tink(k: float, at: Vector3) -> void:
	_sfx("bricks_tink", k, at)


## confetti.celebrate (celebration.js): one burst at the spot, scaled with distance.
func _celebrate(at: Vector3) -> void:
	if not ctx:
		return
	var p := Vector3(at.x, maxf(0.0, at.y - Ball.BR), at.z)
	ctx.confetti.call(p, 1.6, 1.5, maxf(1.0, p.distance_to(CAMERA) / 7.0))


func break_brick(b: Dictionary, _n: Vector3, speed: float) -> void:
	var S := _S()
	b.alive = false
	B.broke_shot = true
	var at: Vector3 = b.mesh.position
	tink(_rng.randf(), at)
	_sfx("thump", minf(1.0, speed / 14.0) * 0.6, at)
	var star := MeshInstance3D.new()
	star.mesh = star_mesh
	star.material_override = star_mat
	star.position = at + Vector3(0, 0, BD)
	add_child(star)
	B.fx.append({"brick": b.mesh, "star": star, "t": 0.0, "dir": Vector3((_rng.randf() - .5) * 1.2, 1.4, 1.2)})
	if ctx:
		ctx.add_count.call("bricks", false)
		ctx.ch_progress.call("bricks20", int(ctx.ch_state.get("bricks20", 0)) + 1)
	# Smashed by a throw: Dahrooj cheers. Smashed by shots while he's in your hand: the wall celebrates on its own
	# (a scored state on a Dahrooj who isn't flying would never run out and he couldn't be thrown again).
	if B.bricks.all(func(x): return not x.alive):
		B.cleared = true
		if ctx:
			ctx.ch_progress.call("wall1", 1)
		if S and S.shot:
			S.scored_t = 0.0
			S.miss_t = 0.0
			S.success()
		else:
			_celebrate(Vector3(0, 1.6, FACE + 0.4))
			_sfx("chime", 1.0, Vector3(0, 1.6, FACE + 0.4))
		if ctx:
			ctx.toast.call(ctx.t("حطّمت الحائط!", "You smashed the wall!"))


## Sphere against an axis-aligned box: push out, bounce, break.
func hit_brick(S: Ball, b: Dictionary) -> bool:
	var p: Vector3 = b.mesh.position
	var h: Vector3 = b.half
	var P := S.pos
	var cp := Vector3(clampf(P.x, p.x - h.x, p.x + h.x), clampf(P.y, p.y - h.y, p.y + h.y), clampf(P.z, p.z - h.z, p.z + h.z))
	var n := P - cp
	var d := n.length()
	if d <= 0.0 or d >= Ball.BR:
		return false
	n /= d
	S.pos = cp + n * Ball.BR
	var vn := S.vel.dot(n)
	if vn < 0.0:
		S.hit(n, -vn, cp)
		S.vel += n * (-1.8 * vn)
		S.side = Vector3.ZERO
		break_brick(b, n, -vn)  # e = 0.8: he comes back to you
	return true


## The towers: solid, Dahrooj bounces off them.
func hit_tower(S: Ball, t: Dictionary) -> void:
	var c: Vector3 = t.c
	var h: Vector3 = t.h
	var P := S.pos
	var cp := Vector3(clampf(P.x, c.x - h.x, c.x + h.x), clampf(P.y, c.y - h.y, c.y + h.y), clampf(P.z, c.z - h.z, c.z + h.z))
	var n := P - cp
	var d := n.length()
	if d <= 0.0 or d >= Ball.BR:
		return
	n /= d
	S.pos = cp + n * Ball.BR
	var vn := S.vel.dot(n)
	if vn < 0.0:
		S.hit(n, -vn, cp)
		S.vel += n * (-1.7 * vn)
		S.side = Vector3.ZERO


func shoot(obj: Node, _point: Vector3, dir: Vector3) -> bool:
	for b in B.bricks:
		if b.alive and b.mesh == obj:
			break_brick(b, -dir, 12)
			return true
	return false


func ft(sp: float) -> float:
	return maxf(0.5, minf(1.25, 1.35 - sp / 2600.0))


func behind(p: Vector3) -> bool:
	return p.z < BZ - 0.05


func touched() -> bool:
	return B.broke_shot


func on_respawn() -> void:
	B.broke_shot = false
	if B.cleared:
		B.level += 1
		layout()


func collide(b: Ball) -> void:
	_ball = b
	for br in B.bricks:
		if br.alive and br.grow >= 1.0:
			hit_brick(b, br)
	for t in tower_boxes:
		hit_tower(b, t)


func update(b: Ball, dt: float) -> void:
	_ball = b
	for t in towers:
		if t.rise < 1.0:
			t.rise = minf(1.0, t.rise + dt * 1.6)
			var k := maxf(0.0, t.rise)
			t.grp.scale.y = maxf(0.001, 1.0 - pow(1.0 - k, 3) * (1.0 - sin(k * PI) * 0.12) if k < 1.0 else 1.0)
	# Cleared with the headset's blaster while Dahrooj is still in hand: a moment later, the next wall.
	if B.cleared and not b.shot:
		B.auto_t += dt
		if B.auto_t > 1.6:
			B.auto_t = 0.0
			B.level += 1
			layout()
	else:
		B.auto_t = 0.0
	for f in flags:
		f.t += dt
		_flag_mesh(f)
	for br in B.bricks:
		if br.grow < 1.0:
			br.grow = minf(1.0, br.grow + dt * 3.2)
			if br.alive:
				var k := maxf(0.0, br.grow)
				var s := 1.0 + sin(k * PI) * 0.18 * (1.0 - k)
				br.mesh.scale = Vector3.ONE * maxf(0.001, k * s)
	for i in range(B.fx.size() - 1, -1, -1):
		var f: Dictionary = B.fx[i]
		f.t += dt
		var k := minf(1.0, f.t / 0.35)
		f.brick.scale = Vector3.ONE * maxf(0.001, 1.0 - k)
		f.brick.rotation.z += dt * 6
		f.star.position += f.dir * dt
		f.dir.y -= dt * 2.5
		f.star.rotation.y += dt * 8
		f.star.scale = Vector3.ONE * maxf(0.001, 1.0 - f.t / 0.9)
		if f.t > 0.9:
			remove_child(f.star)
			f.star.free()
			f.brick.visible = false
			B.fx.remove_at(i)
			if not f.brick.is_inside_tree() and f.brick.get_parent() == null and not _fx_holds(f.brick):
				f.brick.free()  # its wall was already replaced


## The headset's VR world lends its slab-floor shading so the bricks match the floor at every time of day.
## make: Callable(color: Color) -> Material, or an empty Callable to go back to the stage's own stones.
func use_stone(make: Callable) -> void:
	B.make = make
	var pi: int = B.level % PALETTES.size()
	B.stone = stone_for(pi) if make.is_valid() else null
	for b in B.bricks + decor:
		if not b.get("roof", false):
			b.mesh.material_override = _mats_now()[b.mi]


func bricks_left() -> int:
	return B.bricks.filter(func(b): return b.alive).size()


func towers_state() -> Array:
	return towers.map(func(t): return {"top": snappedf(t.top, 0.01), "rise": snappedf(minf(1.0, t.rise), 0.01)})


func next_level() -> void:
	B.level += 1
	layout()


## Tests: break every brick left as shots would.
func smash_all() -> void:
	for b in B.bricks:
		if b.alive:
			break_brick(b, Vector3(0, 0, 1), 12)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for f in B.fx:
			if is_instance_valid(f.brick) and f.brick.get_parent() == null:
				f.brick.free()
