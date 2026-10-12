class_name WindowStage
extends Node3D
## The window (src/reference/stages/window.js): a square frame on a pole; every hit makes it
## smaller (down to 1.2 ball widths) and moves it somewhere else. Game units.

const WZ := -11.0
const FR := 0.05
const START := 1.15
const MIN := Ball.BR * 2 * 1.2
const SHRINK := 0.85

var aim_z := WZ
var far_z = null
var reach_z = null
var ctx: GameCtx
var friction = null
var shot_time = null
var W := {"size": START, "x": 2.4, "y": 1.6, "frame": null, "bars": [], "pop": 1.0, "won": false, "move_t": 0.0, "pole": null}
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 23
	name = "Window"
	StageArt.ground_line(self, -14, WZ, 14, WZ)
	build()


func build() -> void:
	if W.frame:
		remove_child(W.frame)
		W.frame.free()
	var frame := Node3D.new()
	W.frame = frame
	add_child(frame)
	var h: float = W.size / 2 + FR
	var c := [Vector3(-h, -h, 0), Vector3(h, -h, 0), Vector3(h, h, 0), Vector3(-h, h, 0)]
	for i in 4:
		StageArt.bar(frame, c[i], c[(i + 1) % 4], FR)
	for p in c:
		var k := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = FR * 1.4
		s.height = FR * 2.8
		s.radial_segments = 12
		s.rings = 8
		k.mesh = s
		k.material_override = StageArt.post_mat()
		k.position = p
		frame.add_child(k)
	frame.position = Vector3(W.x, W.y, WZ)
	W.pole = StageArt.bar(frame, Vector3(0, -W.y, 0), Vector3(0, -h, 0), 0.035)
	W.bars = [0, 1, 2, 3].map(func(i): return [c[i], c[(i + 1) % 4]])
	W.pop = 0.0


func relocate() -> void:
	W.size = maxf(MIN, W.size * SHRINK)
	var nx := 0.0
	var ny := 0.0
	var tries := 0
	while true:
		nx = (_rng.randf() * 2 - 1) * 3.2
		ny = 0.9 + _rng.randf() * 1.9
		tries += 1
		if not (Vector2(nx - W.x, ny - W.y).length() < 1.6 and tries < 20):
			break
	W.x = nx
	W.y = ny
	build()
	if W.size <= MIN + 1e-6 and ctx:
		ctx.ch_progress.call("windowMin", 1)


func ft(sp: float) -> float:
	return maxf(0.5, minf(1.25, 1.35 - sp / 2600.0))


func behind(p: Vector3) -> bool:
	return p.z < WZ - 0.05


## The window moves on its own a moment after a hit, whichever Dahrooj scored (in the headset the
## next throw often starts before the scoring ball comes back, so waiting for a respawn left it stuck).
func on_respawn() -> void:
	if W.won and W.move_t <= 0.0:
		W.won = false
		relocate()


func collide(b: Ball) -> void:
	var o: Vector3 = W.frame.position
	for ab in W.bars:
		if b.seg_collide(ab[0] + o, ab[1] + o, FR, 0.6):
			b.ooh()
	b.seg_collide(Vector3(o.x, 0, WZ), Vector3(o.x, o.y - W.size / 2 - FR, WZ), 0.035, 0.5)
	var P := b.pos
	if b.shot and b.scored_t <= 0.0 and b.miss_t <= 0.0 and b.prev.z >= WZ and P.z < WZ:
		var h: float = W.size / 2
		if absf(P.x - o.x) < h and absf(P.y - o.y) < h:
			if not W.won:
				W.won = true
				W.move_t = 1.2
			b.success()
		else:
			b.miss()


func update(_b: Ball, dt: float) -> void:
	if W.won and W.move_t > 0.0:
		W.move_t -= dt
		if W.move_t <= 0.0:
			W.won = false
			relocate()
	if W.pop < 1.0:
		W.pop = minf(1.0, W.pop + dt * 3.5)
		var t: float = W.pop
		var s := 1.0 + sin(t * PI) * 0.25 * (1.0 - t)
		W.frame.scale = Vector3.ONE * maxf(0.001, minf(1.0, t * 1.4) * s if t < 1.0 else 1.0)
