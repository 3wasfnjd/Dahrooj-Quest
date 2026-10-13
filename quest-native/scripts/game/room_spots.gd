class_name RoomSpots
extends RefCounted
## Spawn spots all around the player in the real room (mixed reality, game units): on the
## walls at a reachable height, on the open floor (not under furniture) and on furniture tops
## (tables, sofas, beds). The arcade modes take them through their `spots_provider` so the
## targets come from every side, behind you too, and you walk and turn to chase them.
##
## - set_room(planes, boxes): the scanned room in game units. planes as main's
##   room_planes_game(): {pos, normal (into the room), ax, ay (unit, in the plane), half:
##   Vector2, label}; boxes (furniture volumes): {pos, ax, ay, az (unit axes), half: Vector3,
##   label}. Spots are sampled once per room, so they stay put in the room as you walk.
## - look(eye, fwd, dt) every frame: which way the player has been looking lately.
## - pick(eye, kinds) / pick_many(eye, n, kinds): spots at least MIN_DIST from the player,
##   inside the room, spread by angle around them (a sector they were just given counts
##   against it), preferring the directions they have not looked at lately.
## - No scan (or nothing of the kinds asked): a virtual ring around the player, RING metres
##   out, on the floor and in the air at mixed heights.
## A spot: {pos, normal, kind: "wall" | "floor" | "top" | "air", label, room: bool, sector}.
## `pos` sits LIFT off the surface along its normal (never inside a wall or furniture).

const SECTORS := 12
const MIN_DIST := 0.8  # metres from the player (across the floor)
const MAX_DIST := 4.5
const WALL_Y := Vector2(0.6, 2.0)  # metres over the floor where wall spots go
const TOP_Y := Vector2(0.2, 1.4)  # furniture tops between these heights
const RING := Vector2(1.5, 3.0)  # the virtual ring (no scan), metres
const AIR_Y := Vector2(0.6, 1.8)
const STEP := 0.45  # metres between samples on a surface
const EDGE := 0.12  # metres kept from a surface's edges
const LIFT := 0.02  # metres off the surface
const CLEAR := 0.12  # metres kept from furniture (floor and wall spots)
const LOOK_HALF := 0.9  # radians either side of the gaze that count as seen
const LOOK_DECAY := 6.0  # seconds for the seen-heat to fade
const USED_DECAY := 7.0
const SKIP := ["door_frame", "window_frame", "ceiling"]

## Game units per metre (main: the court's scale in the room).
var unit := 8.0
## The real floor's height (game units).
var floor_y := 0.0
## The room's spots (game units), as sampled by set_room().
var spots: Array = []
## The room's floor outline as an XZ box {lo: Vector2, hi: Vector2} (game units), or {}.
var bounds := {}
var walls: Array = []  # the wall planes (for the inside test)
var boxes: Array = []
## Seconds looked at lately, per sector (fixed in the room).
var heat := PackedFloat32Array()
## Spots given lately, per sector.
var used := PackedFloat32Array()
var rng := RandomNumberGenerator.new()


func _init() -> void:
	heat.resize(SECTORS)
	used.resize(SECTORS)
	rng.seed = 9137


## A stage's size so that its typical target (base_r game units at size 1) is world_r metres
## across its radius at `unit` game units per metre.
static func size_for(world_r: float, base_r: float, game_unit: float) -> float:
	return world_r * game_unit / maxf(base_r, 1e-4)


## The sector (0 .. SECTORS-1) of a point seen from the eye: 0 is game -Z, clockwise from above.
static func sector_of(eye: Vector3, p: Vector3) -> int:
	return sector_at(atan2(p.x - eye.x, -(p.z - eye.z)))


static func sector_at(angle: float) -> int:
	var a := fposmod(angle, TAU)
	return int(floor(a / (TAU / SECTORS))) % SECTORS


static func sector_angle(s: int) -> float:
	return (float(s) + 0.5) * TAU / SECTORS


## What a stage's spots_provider gives ([] when unset or not an Array). A provider may take
## the kinds wanted (main's do) or nothing (a fixed list, as in the tests).
static func ask(provider: Callable, kinds := []) -> Array:
	if not provider.is_valid():
		return []
	var got: Variant = provider.call(kinds) if provider.get_argument_count() >= 1 else provider.call()
	return got if got is Array else []


func has_room() -> bool:
	return not spots.is_empty()


# ---- the room ----

static func _corners(pl: Dictionary) -> Array:
	var c: Vector3 = pl.get("pos", Vector3.ZERO)
	var ax: Vector3 = pl.get("ax", Vector3.RIGHT)
	var ay: Vector3 = pl.get("ay", Vector3.UP)
	var h: Vector2 = pl.get("half", Vector2.ONE)
	return [c + ax * h.x + ay * h.y, c - ax * h.x + ay * h.y, c - ax * h.x - ay * h.y, c + ax * h.x - ay * h.y]


## What a plane is for spawning: "wall", "floor", "top" or "" (ceiling, frames, too high).
func sort_of(pl: Dictionary) -> String:
	var n: Vector3 = pl.get("normal", Vector3.UP)
	var label := str(pl.get("label", ""))
	if label in SKIP or n.y < -0.7:
		return ""
	var y: float = (pl.get("pos", Vector3.ZERO) as Vector3).y - floor_y
	if label == "floor":
		return "floor"
	if n.y > 0.7:
		if y < TOP_Y.x * unit:
			return "floor"
		return "top" if y <= TOP_Y.y * unit else ""
	if absf(n.y) < 0.3:
		return "wall"
	return ""


## Whether a box (furniture) holds p, grown by `pad` game units.
static func in_box(bx: Dictionary, p: Vector3, pad: float) -> bool:
	var d: Vector3 = p - (bx.get("pos", Vector3.ZERO) as Vector3)
	var h: Vector3 = bx.get("half", Vector3.ONE)
	return absf(d.dot(bx.get("ax", Vector3.RIGHT))) <= h.x + pad and absf(d.dot(bx.get("ay", Vector3.UP))) <= h.y + pad \
		and absf(d.dot(bx.get("az", Vector3.BACK))) <= h.z + pad


## Inside the scanned room: within its floor outline and in front of every wall whose span
## it lies across. Always true without walls.
func inside(p: Vector3) -> bool:
	var tol := 0.05 * unit
	if not bounds.is_empty():
		var lo: Vector2 = bounds.lo
		var hi: Vector2 = bounds.hi
		if p.x < lo.x - tol or p.x > hi.x + tol or p.z < lo.y - tol or p.z > hi.y + tol:
			return false
	for w: Dictionary in walls:
		var n: Vector3 = w.normal
		var d: Vector3 = p - (w.pos as Vector3)
		if d.dot(n) >= -tol:
			continue
		var h: Vector2 = w.half
		var ax: Vector3 = w.ax
		var ay: Vector3 = w.ay
		var hz := ax if absf(ax.y) < 0.5 else ay
		var hl := h.x if absf(ax.y) < 0.5 else h.y
		if absf(d.dot(hz)) <= hl:
			return false
	return true


## Samples the room's surfaces into spots (game units). Call it again when the scan or the
## court's placement changes.
func set_room(planes: Array, room_boxes := []) -> void:
	spots = []
	walls = []
	boxes = []
	bounds = {}
	for bx in room_boxes:
		if bx is Dictionary and (bx as Dictionary).has("pos"):
			boxes.append(bx)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var tops: Array = []
	var good: Array = []
	for pl in planes:
		if not (pl is Dictionary and (pl as Dictionary).has("pos") and (pl as Dictionary).has("normal")):
			continue
		var d: Dictionary = pl
		if not d.has("half"):
			continue
		good.append(d)
		var label := str(d.get("label", ""))
		var srt := sort_of(d)
		if srt == "wall" and label in ["wall", "invisible_wall_face", "wall_face", ""]:
			walls.append(d)
		if srt == "top":
			tops.append(d)
		if label in ["wall", "invisible_wall_face", "wall_face", "floor"]:
			for q: Vector3 in _corners(d):
				lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.z))
				hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.z))
	if lo.x < hi.x and lo.y < hi.y and hi.x - lo.x > 0.5 * unit and hi.y - lo.y > 0.5 * unit:
		bounds = {"lo": lo, "hi": hi}
	var step := STEP * unit
	var edge := EDGE * unit
	for pl: Dictionary in good:
		var srt := sort_of(pl)
		if srt == "":
			continue
		var c: Vector3 = pl.pos
		var n: Vector3 = (pl.normal as Vector3).normalized()
		var ax: Vector3 = pl.ax
		var ay: Vector3 = pl.ay
		var h: Vector2 = pl.half
		var hx := h.x - edge
		var hy := h.y - edge
		if hx <= 0.0 or hy <= 0.0:
			continue
		var nx := maxi(1, int(ceil(hx * 2.0 / step)))
		var ny := maxi(1, int(ceil(hy * 2.0 / step)))
		for i in nx:
			for j in ny:
				var u := 0.0 if nx == 1 else lerpf(-hx, hx, float(i) / float(nx - 1))
				var v := 0.0 if ny == 1 else lerpf(-hy, hy, float(j) / float(ny - 1))
				var p := c + ax * u + ay * v
				if srt == "wall":
					var hy_m := (p.y - floor_y) / unit
					if hy_m < WALL_Y.x or hy_m > WALL_Y.y:
						continue
				var at := p + n * LIFT * unit
				if not _clear(at, srt, tops, pl):
					continue
				spots.append({"pos": at, "normal": n, "kind": srt, "label": str(pl.get("label", "")), "room": true})


## Not inside (or right in front of) furniture; a floor spot not under a table top; inside
## the room.
func _clear(p: Vector3, srt: String, tops: Array, own: Dictionary) -> bool:
	if not inside(p):
		return false
	var pad := CLEAR * unit
	for bx: Dictionary in boxes:
		if srt == "top":
			# Just over its own volume's top is fine; inside another one is not.
			if in_box(bx, p, 0.0):
				return false
			continue
		if in_box(bx, p, pad):
			return false
		if srt == "wall" and in_box(bx, p + (own.normal as Vector3) * 0.3 * unit, pad):
			return false
	if srt == "floor":
		for t: Dictionary in tops:
			var d: Vector3 = p - (t.pos as Vector3)
			var h: Vector2 = t.half
			if absf(d.dot(t.ax)) <= h.x + pad and absf(d.dot(t.ay)) <= h.y + pad:
				return false
	return true


# ---- the player ----

## The player looks along fwd (game units, from eye) for dt seconds: those sectors warm up,
## everything cools down.
func look(_eye: Vector3, fwd: Vector3, dt: float) -> void:
	var cool := exp(-dt / LOOK_DECAY)
	var cool_u := exp(-dt / USED_DECAY)
	var flat := Vector2(fwd.x, fwd.z)
	var gaze := atan2(fwd.x, -fwd.z)
	for s in SECTORS:
		heat[s] *= cool
		used[s] *= cool_u
		if flat.length_squared() > 1e-6 and absf(angle_difference(gaze, sector_angle(s))) <= LOOK_HALF:
			heat[s] += dt


## How much a sector is wanted now: the less seen and the less given lately, the more (a
## sector in plain view keeps some weight, so things still come in front now and then).
func want(s: int) -> float:
	return (1.0 - 0.55 * clampf(heat[s] / 3.0, 0.0, 1.0)) / (1.0 + used[s])


# ---- picking ----

## The virtual ring around the eye (no scan): per sector one spot on the floor and one in
## the air, facing the player.
func ring(eye: Vector3) -> Array:
	var out: Array = []
	for s in SECTORS:
		for k in 2:
			var a := sector_angle(s) + rng.randf_range(-0.4, 0.4) * TAU / SECTORS
			var d := Vector3(sin(a), 0.0, -cos(a))
			var r := rng.randf_range(RING.x, RING.y) * unit
			var p := Vector3(eye.x, 0.0, eye.z) + d * r
			if k == 0:
				p.y = floor_y + LIFT * unit
				out.append({"pos": p, "normal": Vector3.UP, "kind": "floor", "label": "ring", "room": false})
			else:
				p.y = floor_y + rng.randf_range(AIR_Y.x, AIR_Y.y) * unit
				out.append({"pos": p, "normal": -d, "kind": "air", "label": "ring", "room": false})
	return out


func _pool(eye: Vector3, kinds: Array) -> Array:
	var near := MIN_DIST * unit
	var far := MAX_DIST * unit
	var src: Array = []
	for sp: Dictionary in spots:
		if kinds.is_empty() or sp.kind in kinds:
			src.append(sp)
	if src.is_empty():
		var rg := ring(eye)
		for sp: Dictionary in rg:
			if kinds.is_empty() or sp.kind in kinds:
				src.append(sp)
		if src.is_empty():
			src = rg
	var out: Array = []
	var spare: Array = []
	for sp: Dictionary in src:
		var p: Vector3 = sp.pos
		var hd := Vector2(p.x - eye.x, p.z - eye.z).length()
		if hd < near:
			continue
		if hd > far:
			spare.append(sp)
			continue
		out.append(sp)
	return out if not out.is_empty() else spare


## One spot for something new, or {} (nothing far enough from the player). kinds: [] for any
## of "wall", "floor", "top", "air"; avoid: points (game units) to keep `gap` from.
func pick(eye: Vector3, kinds := [], avoid := [], gap := 0.0) -> Dictionary:
	var pool := _pool(eye, kinds)
	if pool.is_empty():
		return {}
	var by: Array = []
	by.resize(SECTORS)
	for s in SECTORS:
		by[s] = []
	for sp: Dictionary in pool:
		var p: Vector3 = sp.pos
		var ok := true
		for q in avoid:
			if (q as Vector3).distance_to(p) < gap:
				ok = false
				break
		if ok:
			(by[sector_of(eye, p)] as Array).append(sp)
	var total := 0.0
	var w := PackedFloat32Array()
	w.resize(SECTORS)
	for s in SECTORS:
		w[s] = want(s) if not (by[s] as Array).is_empty() else 0.0
		total += w[s]
	if total <= 0.0:
		return {}
	var r := rng.randf() * total
	var pick_s := 0
	for s in SECTORS:
		if w[s] <= 0.0:
			continue
		pick_s = s
		r -= w[s]
		if r <= 0.0:
			break
	var list: Array = by[pick_s]
	var sp: Dictionary = (list[rng.randi() % list.size()] as Dictionary).duplicate()
	sp.sector = pick_s
	used[pick_s] += 1.0
	return sp


## n spots, apart from each other (0.5 m), for the stages that pick among a few.
func pick_many(eye: Vector3, n: int, kinds := []) -> Array:
	var out: Array = []
	var avoid: Array = []
	for i in n:
		var sp := pick(eye, kinds, avoid, 0.5 * unit)
		if sp.is_empty():
			break
		out.append(sp)
		avoid.append(sp.pos)
	return out


## The plane (of `planes`) a spot lies on, or {}.
static func plane_of(sp: Dictionary, planes: Array, tol := 0.3) -> Dictionary:
	var p: Vector3 = sp.get("pos", Vector3.ZERO)
	var n: Vector3 = sp.get("normal", Vector3.UP)
	var best := {}
	var best_d := INF
	for pl in planes:
		if not (pl is Dictionary and (pl as Dictionary).has("half")):
			continue
		var d: Dictionary = pl
		if (d.normal as Vector3).dot(n) < 0.9:
			continue
		var q: Vector3 = p - (d.pos as Vector3)
		var dist := absf(q.dot(d.normal))
		var h: Vector2 = d.half
		if dist > tol or absf(q.dot(d.ax)) > h.x + 1e-3 or absf(q.dot(d.ay)) > h.y + 1e-3:
			continue
		if dist < best_d:
			best_d = dist
			best = d
	return best
