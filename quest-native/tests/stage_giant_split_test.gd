extends RefCounted
## Giant Dahrooj's slime split, frame by frame, at the VR size (Lv.1 and a bigger Lv.3) and
## at the mixed-reality size (size 2, a scanned room): the three medium ones are hidden while
## he collapses, come out of the top of the puddle (never inside him), and when they merge
## back each one disappears as it reaches him: none is ever drawn inside his body or over his
## footprint while he closes up and stands again, and none is left over afterwards.

const DT := 1.0 / 72.0


static func _stage(size: float, room: bool) -> Array:
	var st := GiantStage.new()
	var b := Ball.new()
	var ctx := GameCtx.new()
	ctx.ball = b
	ctx.counts = {}
	st.ctx = ctx
	st.size = size
	if room:
		st.viewer = Vector3(0, 12.8, 0)
		st.planes_provider = func() -> Array:
			return [
				{"pos": Vector3(0, 0, -10), "normal": Vector3.UP, "ax": Vector3.RIGHT, "ay": Vector3.FORWARD, "half": Vector2(30, 30), "label": "floor"},
				{"pos": Vector3(0, 40, -10), "normal": Vector3.DOWN, "ax": Vector3.RIGHT, "ay": Vector3.FORWARD, "half": Vector2(30, 30), "label": "ceiling"},
				{"pos": Vector3(0, 10, -60), "normal": Vector3.BACK, "ax": Vector3.RIGHT, "ay": Vector3.UP, "half": Vector2(30, 20), "label": "wall"},
			]
	b.set_stage(st, "giant")
	return [st, b]


## Plays one split through to the end; returns the problems seen (empty when it looks right).
static func split_once(st: GiantStage, b: Ball, lv: int) -> Dictionary:
	var out := {"fight": false, "melt_seen": 0, "inside": [], "over": [], "left": 0, "meds": 0, "frames": 0, "popped": false}
	if lv > 1:
		st.F.lv = lv
		st._begin_level()
	var t := 0.0
	while t < 14.0 and not (st.F.state == "fight" and not st.giant.air and st.giant.act == ""):
		st.update(b, DT)
		t += DT
	out.fight = st.F.state == "fight"
	st.F.phase = 2
	st.F.hp = st.F.max_hp * 0.51
	st._damage(2.0)
	t = 0.0
	var seen_split := false
	while t < GiantStage.SPLIT_T + 8.0:
		st.update(b, DT)
		st.draw()
		t += DT
		out.frames += 1
		var ph: String = st.F.split
		if ph != "":
			seen_split = true
		elif seen_split:
			break
		var g: Dictionary = st.giant
		for m: Dictionary in st.meds:
			var v: DahroojView = m.view
			if not v.visible:
				continue
			out.meds = maxi(out.meds, st.meds.filter(func(x): return (x.view as DahroojView).visible).size())
			if ph == "melt":
				out.melt_seen += 1
			if st.inside(g, m.c):
				out.inside.append("%s %.2f" % [ph, st.F.split_t])
			var d: Vector3 = (m.c as Vector3) - (g.g as Vector3)
			d.y = 0.0
			if ph in ["merge", "reform"] and d.length() < st.footprint(g):
				out.over.append("%s %.2f" % [ph, st.F.split_t])
			if ph == "out" and float(m.k) >= 0.99:
				out.popped = true
	# After he stands again: nothing left, now or a while later.
	for i in 72:
		st.update(b, DT)
	st.draw()
	out.left = st.meds.filter(func(x): return x.on or (x.view as DahroojView).visible).size()
	out.split_done = seen_split and st.F.split == ""
	return out


static func run(check: Callable) -> void:
	for c: Array in [["VR Lv.1", 1.0, false, 1], ["VR Lv.3", 1.0, false, 3], ["MR", 2.0, true, 1], ["MR Lv.2", 2.0, true, 2]]:
		var sb := _stage(float(c[1]), bool(c[2]))
		var st: GiantStage = sb[0]
		var r := split_once(st, sb[1], int(c[3]))
		check.call(r.fight and r.split_done and r.meds == 3 and r.popped, "giant split (%s, r %.1f): he splits into three and they grow out to full size" % [c[0], st.giant.r])
		check.call(r.melt_seen == 0, "giant split (%s): the three stay hidden while he collapses" % c[0])
		check.call(r.inside.is_empty(), "giant split (%s): none is ever drawn inside his body %s" % [c[0], r.inside.slice(0, 4)])
		check.call(r.over.is_empty(), "giant split (%s): merging back, none shows over his footprint as he closes up %s" % [c[0], r.over.slice(0, 4)])
		check.call(r.left == 0, "giant split (%s): none is left under him afterwards (%d)" % [c[0], r.left])
		st.free()
