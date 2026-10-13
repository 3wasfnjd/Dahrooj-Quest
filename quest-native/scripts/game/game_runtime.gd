class_name GameRuntime
extends RefCounted
## The glue between the ball, the stages and the player's progress
## (src/reference/complete-game.js): scores per mode, challenges, the hoop streak,
## switching modes (each stage is built once and kept), recall.

## The challenges of the modes in this version (celebration.js `challenges`), easiest
## first: each one opens one reward (ChallengeRewards), in this order.
const CHALLENGES := [
	["keeper3", "سجّل على الحارس ٣ مرات", "Score past the keeper 3 times", 3],
	["hoop3", "٣ سلات ورا بعض", "3 hoops in a row", 3],
	["windowMin", "صغّر الشباك لأصغر حجم", "Shrink the window to its smallest", 1],
	["cansOne", "طيّح كل العلب برمية وحدة", "Knock down every can in one throw", 1],
	["styles5", "العب بالستايلات الثلاثة", "Play in all three styles", 3],
	["firework10", "فجّر ١٠ أهداف بالألعاب النارية", "Blast 10 targets with fireworks", 10],
	["strike1", "سترايك في البولينغ", "A strike in bowling", 1],
	["skyPop5", "فجّر ٥ دحاريج في السماء", "Pop 5 Dahroojs above your head", 5],
	["curve3", "سجّل ٣ أهداف برمية ملتفة في النظارة", "Score 3 curved goals in the headset", 3],
	["bouncy3", "طلقة نطّاطة وحدة تصيب ٣ أهداف", "Hit 3 targets with one bouncy ball", 3],
	["pop20", "فجّر ٢٠ دحروج بالطلقات", "Pop 20 Dahroojs with your shots", 20],
	["crates5", "فجّر ٥ صناديق في عالم النظارة", "Blow up 5 crates in the headset world", 5],
	["laser30", "اصب ٣٠ هدف بالليزر", "Hit 30 targets with the laser", 30],
	["modes5", "العب ٥ أنماط مختلفة", "Play 5 different modes", 5],
	["shemaghPlay", "العب أي نمط وأنت لابس الشماغ", "Play a mode wearing the shemagh", 1],
	["boomerang3", "بوميرانغ يصيب ويرجع ليدك ٣ مرات", "Catch 3 boomerangs that hit something", 3],
	["bricks20", "اكسر ٢٠ طوبة في حائط الطوب", "Break 20 bricks on the brick wall", 20],
	["wall1", "حطّم حائط الطوب كامل", "Smash the whole brick wall", 1],
	["fair25", "اجمع ٢٥ نقطة في زيارة للملاهي", "Score 25 in one visit to the fair", 25],
	["bell3", "اضرب جرس الملاهي ٣ مرات", "Ring the fair bell 3 times", 3],
	["mole20", "اضرب ٢٠ دحروج", "Whack 20 Dahroojs", 20],
	["rocket20", "اصب ٢٠ هدف بالصواريخ", "Hit 20 targets with rockets", 20],
	["chain4", "صاعقة وحدة تصيب ٤ أهداف", "Chain 4 targets with one lightning bolt", 4],
	["dallah15", "اصب ١٥ هدف بالدلّة", "Hit 15 targets with the dallah", 15],
	["combo10", "كومبو ١٠ في نيازك الدحاريج", "A 10-blast combo in Dahrooj Meteors", 10],
	["meteor50", "فجّر ٥٠ نيزك", "Blast 50 meteors", 50],
	["giant3", "اهزم العملاق ٣ مرات", "Knock out the Giant 3 times", 3],
	["invasion10", "اصمد ١٠ موجات", "Survive 10 waves", 10],
	["slime5", "برج سلايم من ٥", "A slime tower of 5", 5],
	["frenzy3", "ادخل الحمّى ٣ مرات", "Enter FRENZY 3 times", 3],
	["castle25", "طيّح ٢٥ دحروج من الحصن", "Knock 25 Dahroojs off the fort", 25],
	["gallery10", "سلسلة ١٠ إصابات في ميدان الرماية", "A 10-hit streak in the shooting gallery", 10],
	["summit1", "اوصل قمة الجبل", "Reach the top of the Summit", 1],
	["monsters15", "اهزم ١٥ وحش في مرحلة القمة", "Beat 15 monsters on the Summit", 15],
	# Tabletops (challenges.ts; tabletop_progress.gd records them).
	["balance1", "أكمل مرحلة توازن", "Complete a balance round", 1],
	["balance5", "مراحل التوازن الخمس", "All five balance rounds", 5],
	["balanceClean", "توازن دون سقوط أو إعادة", "Balance without falling or retrying", 1],
	["ricochet1", "أكمل مرحلة ارتداد", "Complete a ricochet round", 1],
	["ricochet5", "مراحل الارتداد الخمس", "All five ricochet rounds", 5],
	["ricochetAce", "ارتداد من أول رمية", "Ricochet on the first throw", 1],
	["maze1", "أكمل متاهة", "Complete a maze", 1],
	["maze5", "المتاهات الخمس", "All five mazes", 5],
	["mazeClean", "اجمع النجوم وأكمل المتاهة دون إعادة", "Collect the stars and finish without retrying", 1],
]
const MODES := ["goal", "hoop", "window", "cans", "bowling", "bricks", "fair", "mole", "invasion", "slime", "meteor", "giant", "frenzy", "castle", "gallery"]

var ball: Ball
var ctx := GameCtx.new()
var parent: Node3D  # where stages live (game units)
var mode := ""
var stage: Node3D
var counts := {"goal": 0, "hoop": 0, "window": 0, "cans": 0, "bowling": 0, "bricks": 0, "fair": 0, "mole": 0, "invasion": 0, "slime": 0, "meteor": 0, "giant": 0, "frenzy": 0, "castle": 0, "gallery": 0, "climb": 0}
var hoop_streak := 0
var cache := {}
## chime(): a challenge was completed (the runtime plays the chime).
var on_chime: Callable = func(): pass


func _init(b: Ball, stage_parent: Node3D) -> void:
	ball = b
	parent = stage_parent
	ctx.ball = b
	ctx.counts = counts
	ctx.ch_state = Save.challenges
	ctx.lang = "ar" if Save.arabic() else "en"
	ctx.add_count = add_count
	ctx.ch_progress = ch_progress
	ball.event.connect(_on_ball)
	for id in ["hoop3", "fair25"]:
		ch_progress(id, 0)


static func challenge(id: String) -> Array:
	for c in CHALLENGES:
		if c[0] == id:
			return c
	return []


## Attempt-scoped progress may fall; earned achievements stay earned (challenge-rules.js).
static func challenge_value(id: String, current: int, goal: int, next: int) -> int:
	if current >= goal:
		return goal
	var value := clampi(next, 0, goal)
	return value if id == "hoop3" or id == "fair25" else maxi(current, value)


func ch_progress(id: String, value: int) -> void:
	var c := challenge(id)
	if c.is_empty():
		return
	var before := int(Save.challenges.get(id, 0))
	var next := challenge_value(id, before, c[3], value)
	if next == before:
		return
	Save.challenges[id] = next
	Save.save()
	if before < c[3] and value >= c[3]:
		ctx.toast.call("✓ " + (c[2] if ctx.lang == "en" else c[1]))
		on_chime.call()


func ch_add(id: String) -> void:
	ch_progress(id, int(Save.challenges.get(id, 0)) + 1)


func reset_streak() -> void:
	hoop_streak = 0
	ch_progress("hoop3", 0)


func add_count(m: String, reset: bool) -> void:
	counts[m] = 0 if reset else int(counts.get(m, 0)) + 1
	if m == "goal" and not reset:
		ch_progress("keeper3", int(Save.challenges.get("keeper3", 0)) + 1)
	if m == "hoop":
		hoop_streak += 1
		ch_progress("hoop3", hoop_streak)


func curved_goal() -> void:
	ch_progress("curve3", int(Save.challenges.get("curve3", 0)) + 1)


## The shot styles whose hits count toward a challenge (the dallah's beans for the dallah).
const SHOT_CHALLENGES := {"firework": "firework10", "laser": "laser30", "rocket": "rocket20", "dallah": "dallah15", "bean": "dallah15"}


## The blaster's `kind` hit n targets (WorldBalls): toward that style's challenge.
func shot_hits(kind: String, n: int) -> void:
	if n <= 0 or not SHOT_CHALLENGES.has(kind):
		return
	var id: String = SHOT_CHALLENGES[kind]
	ch_progress(id, int(Save.challenges.get(id, 0)) + n)


## A mode was chosen (main.gd): modes5 counts the different ones ("played:<id>" in the saved
## progress), and wearing the shemagh there counts for shemaghPlay.
func note_mode(id: String, worn: String) -> void:
	if id == "":
		return
	if not Save.challenges.has("played:" + id):
		Save.challenges["played:" + id] = 1
		Save.save()
	var n := 0
	for k: Variant in Save.challenges.keys():
		if str(k).begins_with("played:"):
			n += 1
	ch_progress("modes5", n)
	if worn == "shemagh":
		ch_progress("shemaghPlay", 1)


func note_style(style: String) -> void:
	if not style in Save.styles_used:
		Save.styles_used.append(style)
	ch_progress("styles5", Save.styles_used.size())
	Save.save()


func _on_ball(kind: String, data: Dictionary) -> void:
	# game-state.js success(): the goal, hoop and window count their scores here.
	if kind == "success":
		if mode in ["goal", "hoop", "window"]:
			add_count(mode, false)
		if mode == "goal" and float(data.get("curve", 0.0)) != 0.0:
			curved_goal()
	# ctx.miss: a miss in the hoop breaks the streak.
	if kind == "miss" and mode == "hoop":
		reset_streak()


## Each stage is built the first time its mode is chosen, then kept (hidden).
func set_mode(id: String) -> void:
	if not id in MODES:
		return
	if mode != id:
		reset_streak()
	ball.volley.clear()
	if stage:
		if stage.has_method("deactivate"):
			stage.deactivate()
		stage.visible = false
	mode = id
	if not cache.has(id):
		var sc: GDScript = load("res://scripts/game/stages/%s_stage.gd" % id)
		var st: Node3D = sc.new()
		st.name = id.capitalize() + "Stage"
		st.set("ctx", ctx)
		parent.add_child(st)
		cache[id] = st
	stage = cache[id]
	stage.visible = true
	ball.set_stage(stage, id)


func recall() -> void:
	if ball.shot and ball.scored_t <= 0.0 and ball.miss_t <= 0.0 and mode == "hoop":
		reset_streak()
	ball.respawn()


func step(dt: float) -> void:
	ctx.time = ball.time
	ctx.lang = "ar" if Save.arabic() else "en"
	ball.step(dt)
