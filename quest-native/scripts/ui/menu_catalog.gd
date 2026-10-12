class_name MenuCatalog
extends RefCounted
## The headset menu's fixed lists (src/reference/flat-mode-panel.ts, mode-catalog.ts,
## core/appearance.ts, progression/challenges.ts) and the controls help
## (quest-controls.ts). Every entry is [id, ar, en, ...].

## mode-catalog.ts XR_MODE_CATALOG: the live headset menu's mode cards, in order.
## Plus the native port's Whack-a-Dahrooj ("mole"), after the fair.
const MODES := [
	["goal", "مرمى", "Goal"], ["hoop", "سلة", "Hoop"], ["window", "شباك", "Window"],
	["cans", "علب", "Cans"], ["bowling", "بولينغ", "Bowling"], ["bricks", "الطوب", "Bricks"],
	["fair", "ملاهي", "Fair"], ["mole", "اضرب الدحروج", "Whack-a-Dahrooj"], ["rain", "مطر دحاريج", "Dahrooj Rain"],
	["climb", "الجبل", "Summit"], ["balance", "التوازن", "Balance"], ["ricochet", "الارتداد", "Ricochet"],
	["maze", "المتاهة", "Maze"],
]
const PAGES := [
	["modes", "الأنماط", "Modes"], ["appearance", "المظهر", "Appearance"], ["play", "اللعب", "Play"],
	["world", "العالم", "World"], ["challenges", "التحديات", "Challenges"], ["system", "عام", "General"],
	["about", "عن اللعبة", "About"],
]
const APPEARANCE := [["character", "دحروج", "Dahrooj"], ["accessories", "الإكسسوارات", "Accessories"]]
const STYLES := [["jelly", "جلي", "Jelly"], ["fur", "فرو", "Fur"], ["bubble", "فقاعة", "Bubble"]]
const THROWS := [["trigger", "شحن", "Charge"], ["hand", "يد", "Hand"], ["sling", "نبيطة", "Slingshot"]]
const SHOTS := [["bolt", "برق", "Bolt"], ["mini", "دحروج", "Dahrooj"], ["bubble", "فقاعة", "Bubble"], ["firework", "ألعاب نارية", "Firework"]]
const TIMES := [["auto", "تلقائي", "Auto"], ["day", "نهار", "Day"], ["dusk", "غروب", "Dusk"], ["night", "ليل", "Night"], ["dawn", "فجر", "Dawn"]]
const WEATHERS := [["auto", "تلقائي", "Auto"], ["clear", "صافي", "Clear"], ["rain", "مطر", "Rain"], ["snow", "ثلج", "Snow"]]
## core/appearance.ts DAHROOJ_COLOR_CHOICES: [id, ar, en, hex ("" = the style's own colour)].
const COLORS := [
	["original", "اللون الأصلي", "Original colour", ""],
	["pink", "وردي", "Pink", "ff69b4"], ["red", "أحمر", "Red", "ff505c"], ["orange", "برتقالي", "Orange", "ff9b3d"],
	["yellow", "أصفر", "Yellow", "ffdf45"], ["green", "أخضر", "Green", "58db83"], ["blue", "أزرق", "Blue", "58b9ff"],
	["purple", "بنفسجي", "Purple", "b878ff"],
]
## MENU_ACCESSORIES: [id, ar, en, need] — need is a count of finished challenges or a challenge id.
const ACCESSORIES := [
	["", "بدون", "None", 0], ["party", "قبعة حفلة", "Party hat", 1], ["glasses", "نظارة شمسية", "Sunglasses", 3],
	["cap", "كاب", "Cap", 5], ["flower", "وردة", "Flower", 7], ["crown", "تاج", "Crown", 10],
	["headphones", "سماعات", "Headphones", 12], ["scarf", "وشاح", "Scarf", 14],
	["aviator", "قبعة طيّار", "Aviator cap", "balance5"], ["woodhat", "قبعة خشبية", "Wooden hat", "ricochet5"],
	["starGlasses", "نظارة نجوم", "Star glasses", "maze5"], ["beanie", "طاقية صوف", "Wool hat", "mazeClean"],
]
## progression/challenges.ts CHALLENGES: [id, goal, ar, en] (unlock rules and their hints).
const CHALLENGES := [
	["keeper3", 3, "سجّل على الحارس ٣ مرات", "Score 3 goals"],
	["hoop3", 3, "٣ سلات متتابعة", "3 hoops in a row"],
	["windowMin", 1, "أصغر شباك", "Smallest window"],
	["cansOne", 1, "كل العلب برمية", "Clear cans in one throw"],
	["styles5", 3, "الستايلات الثلاثة", "Play all 3 styles"],
	["summit1", 1, "قمة الجبل", "Reach the summit"],
	["monsters15", 15, "اهزم ١٥ وحشًا", "Defeat 15 monsters"],
	["strike1", 1, "سترايك", "Bowl a strike"],
	["crates5", 5, "فجّر ٥ صناديق", "Explode 5 crates"],
	["skyPop5", 5, "فجّر ٥ دحاريج في السماء", "Pop 5 Dahroojs above your head"],
	["curve3", 3, "٣ أهداف منحنية", "3 curved goals"],
	["bricks20", 20, "اكسر ٢٠ طوبة", "Break 20 bricks"],
	["wall1", 1, "حطّم جدارًا", "Clear a wall"],
	["fair25", 25, "٢٥ نقطة بالملاهي", "25 in one fair round"],
	["bell3", 3, "اضرب الجرس ٣ مرات", "Ring 3 bells"],
	["pop20", 20, "فرقع ٢٠ دحروج", "Pop 20 Dahroojs"],
	["balance1", 1, "أكمل مرحلة توازن", "Complete a balance round"],
	["balance5", 5, "مراحل التوازن الخمس", "All five balance rounds"],
	["balanceClean", 1, "توازن دون سقوط أو إعادة", "Balance without falling or retrying"],
	["ricochet1", 1, "أكمل مرحلة ارتداد", "Complete a ricochet round"],
	["ricochet5", 5, "مراحل الارتداد الخمس", "All five ricochet rounds"],
	["ricochetAce", 1, "ارتداد من أول رمية", "Ricochet on the first throw"],
	["maze1", 1, "أكمل متاهة", "Complete a maze"],
	["maze5", 5, "المتاهات الخمس", "All five mazes"],
	["mazeClean", 1, "اجمع النجوم وأكمل المتاهة دون إعادة", "Collect the stars and finish without retrying"],
]
## Names and descriptions taken from the shipped credits.html.
const CREDITS := [
	["Aboden Games", "دحروج والتصميم والموسيقى والأصوات الأصلية", "Dahrooj, design, original music and sounds"],
	["Bruno Simon", "أصول وأجزاء من العالم", "Environment assets and adapted world work"],
	["Amazon", "نماذج وحدات التحكم", "Controller models"],
	["Meta · Three.js / super-three", "أدوات الواقع الممتد ومكتبات الرسم", "Immersive tools and rendering libraries"],
]


static func challenge(id: String) -> Array:
	for c: Array in CHALLENGES:
		if c[0] == id:
			return c
	return []


static func accessory(id: String) -> Array:
	for a: Array in ACCESSORIES:
		if a[0] == id:
			return a
	return []


## challenges.ts accessoryAvailable: completed = finished challenges; progress =
## challenge id -> value, plus "reward:<id>" = 1 for rewards kept from older saves.
static func accessory_available(id: String, completed: int, progress: Dictionary) -> bool:
	if id == "":
		return true
	var a := accessory(id)
	if a.is_empty():
		return false
	if int(progress.get("reward:" + id, 0)) == 1:
		return true
	var need: Variant = a[3]
	if need is int:
		return completed >= int(need)
	var c := challenge(str(need))
	return not c.is_empty() and int(progress.get(c[0], 0)) >= int(c[1])


## The Touch-controller bindings for a mode and throw style (after quest-controls.ts,
## with the native control scheme: in every mode the triggers fire shots and a
## grip holds Dahrooj): {a, left_trigger, right_trigger, left_grip, right_grip,
## grip}, each [ar, en] (grip: one line on how to throw).
static func quest_controls(mode: String, throw_style: String) -> Dictionary:
	var tilting := mode == "balance" or mode == "maze"
	var tabletop := tilting or mode == "ricochet"
	var fire := ["إطلاق المقذوفات", "Fire shots"]
	var grab := ["إمساك دحروج", "Grab Dahrooj"]
	var left_grip := grab
	var right_grip := grab
	var grip := ["القبضة: امسك دحروج · اضغط للشحن وأفلت للرمي", "Grip: hold Dahrooj · hold to charge, release to throw"]
	var a := ["استرجاع دحروج", "Recall Dahrooj"]
	if throw_style == "hand":
		grip = ["القبضة: امسك دحروج، حرّك يدك ثم أفلت", "Grip: grab Dahrooj, swing your hand, then release"]
	elif throw_style == "sling":
		left_grip = ["مسك النبيطة", "Hold slingshot"]
		right_grip = ["سحب ثم إفلات", "Pull, then release"]
		grip = ["النبيطة باليسرى · اسحب بقبضة اليمنى ثم أفلت", "Slingshot in the left hand · pull with the right grip, release"]
	if tabletop:
		a = ["إعادة المحاولة", "Retry round"]
		if tilting:
			left_grip = ["إمساك اللوح وإمالته", "Hold and tilt board"]
			grip = ["القبضة: امسك اللوح وأمله · الإفلات يوقفه", "Grip: hold and tilt the board · release to pause"]
		else:
			left_grip = ["تدوير لوح خشبي", "Turn a paddle"]
			grip = ["القبضة: وجّه للوح الخشبي وأدره بخطوات ٥°", "Grip: point at a wooden paddle and turn it in 5° steps"]
		right_grip = left_grip
	elif mode == "climb":
		a = ["قفز", "Jump"]
		grip = ["القير الأيسر: حركة · القير الأيمن: تكبير وتصغير الجبل", "Left stick: move · right stick: resize the mountain"]
	return {"a": a, "left_trigger": fire, "right_trigger": fire, "left_grip": left_grip, "right_grip": right_grip, "grip": grip}
