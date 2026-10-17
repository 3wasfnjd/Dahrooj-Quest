class_name MenuCatalog
extends RefCounted
## The headset menu's fixed lists (src/reference/flat-mode-panel.ts, mode-catalog.ts,
## core/appearance.ts, progression/challenges.ts) and the controls help
## (quest-controls.ts). Every entry is [id, ar, en, ...].

## mode-catalog.ts XR_MODE_CATALOG: the live headset menu's mode cards, in order.
## Plus the native port's Whack-a-Dahrooj ("mole"), after the fair, and Dahrooj Attack
## ("invasion") after it, Slime ("slime") after that, then Dahrooj Meteors, Dahrooj Fort,
## Giant Dahrooj, Dahrooj Gallery and Pop Frenzy.
const MODES := [
	["goal", "مرمى", "Goal"], ["hoop", "سلة", "Hoop"], ["window", "شباك", "Window"],
	["cans", "علب", "Cans"], ["bowling", "بولينغ", "Bowling"], ["bricks", "الطوب", "Bricks"],
	["fair", "ملاهي", "Fair"], ["mole", "اضرب الدحروج", "Whack-a-Dahrooj"],
	["invasion", "هجوم الدحاريج", "Dahrooj Attack"], ["slime", "سلايم", "Slime"],
	["meteor", "نيازك الدحاريج", "Dahrooj Meteors"], ["castle", "حصن الدحاريج", "Dahrooj Fort"],
	["giant", "الدحروج العملاق", "Giant Dahrooj"], ["gallery", "ميدان الرماية", "Dahrooj Gallery"],
	["frenzy", "حمّى الفرقعة", "Pop Frenzy"],
	["rain", "مطر دحاريج", "Dahrooj Rain"], ["climb", "الجبل", "Summit"], ["balance", "التوازن", "Balance"],
	["ricochet", "الارتداد", "Ricochet"], ["maze", "المتاهة", "Maze"],
]
const PAGES := [
	["modes", "الأنماط", "Modes"], ["appearance", "المظهر", "Appearance"], ["play", "اللعب", "Play"],
	["world", "العالم", "World"], ["challenges", "التحديات", "Challenges"], ["system", "عام", "General"],
	["about", "عن اللعبة", "About"],
]
const APPEARANCE := [["character", "دحروج", "Dahrooj"], ["accessories", "الإكسسوارات", "Accessories"]]
const STYLES := [["jelly", "جلي", "Jelly"], ["fur", "فرو", "Fur"], ["bubble", "فقاعة", "Bubble"]]
const THROWS := [["trigger", "شحن", "Charge"], ["hand", "يد", "Hand"], ["sling", "نبيطة", "Slingshot"]]
## The blaster's shot styles, in ShotCatalog.ORDER (which has their icons, unlocks and lines).
const SHOTS := [
	["bolt", "برق", "Bolt"], ["mini", "دحروج", "Dahrooj"], ["bubble", "فقاعة", "Bubble"], ["firework", "ألعاب نارية", "Firework"],
	["confetti", "قصاصات", "Confetti"], ["bouncy", "نطّاطة", "Bouncy"], ["laser", "ليزر", "Laser"], ["boomerang", "بوميرانغ", "Boomerang"],
	["glob", "ماء", "Water"], ["rocket", "صاروخ", "Rocket"], ["lightning", "صاعقة", "Lightning"], ["dallah", "دلّة", "Dallah"],
]
const TIMES := [["auto", "تلقائي", "Auto"], ["day", "نهار", "Day"], ["dusk", "غروب", "Dusk"], ["night", "ليل", "Night"], ["dawn", "فجر", "Dawn"]]
const WEATHERS := [["auto", "تلقائي", "Auto"], ["clear", "صافي", "Clear"], ["rain", "مطر", "Rain"], ["snow", "ثلج", "Snow"]]
## core/appearance.ts DAHROOJ_COLOR_CHOICES: [id, ar, en, hex ("" = the style's own colour),
## need ("" = open from the start, else the challenge id that opens it)].
const COLORS := [
	["original", "اللون الأصلي", "Original colour", "", ""],
	["pink", "وردي", "Pink", "ff69b4", ""], ["red", "أحمر", "Red", "ff505c", "ricochet1"], ["orange", "برتقالي", "Orange", "ff9b3d", "windowMin"],
	["yellow", "أصفر", "Yellow", "ffdf45", "bouncy3"], ["green", "أخضر", "Green", "58db83", "shemaghPlay"], ["blue", "أزرق", "Blue", "58b9ff", "slime5"],
	["purple", "بنفسجي", "Purple", "b878ff", "styles5"],
	["turquoise", "فيروزي", "Turquoise", "2fcdbd", "mole100"], ["maroon", "عنابي", "Maroon", "a8304a", "score5k"],
	["navy", "كحلي", "Navy", "3d5ab0", "invasion25"], ["gold", "ذهبي", "Gold", "e8b23a", "score25k"],
]
## MENU_ACCESSORIES: [id, ar, en, need] — need is 0 for the one open from the start, else the
## challenge id (GameRuntime's) that opens it; each challenge opens one reward
## (ChallengeRewards). In the order the challenges give them, easiest first.
const ACCESSORIES := [
	["", "بدون", "None", 0], ["party", "قبعة حفلة", "Party hat", "keeper3"], ["glasses", "نظارة شمسية", "Sunglasses", "cansOne"],
	["ghutra", "غترة وعقال", "Ghutra & agal", "strike1"], ["cap", "كاب", "Cap", "curve3"],
	["goldStar", "نجمة ذهبية", "Golden star", "golden1"], ["taqiyah", "طاقية", "Taqiyah", "crates5"],
	["shemagh", "شماغ وعقال", "Shemagh & agal", "modes5"], ["chef", "قبعة طباخ", "Chef’s hat", "bricks20"], ["flower", "وردة", "Flower", "wall1"],
	["jasmine", "طوق ياسمين", "Jasmine crown", "fair25"], ["headphones", "سماعات", "Headphones", "bell3"], ["bunny", "آذان أرنب", "Bunny ears", "mole20"],
	["kufi", "طاقية مطرزة", "Embroidered cap", "dallah15"], ["wizard", "قبعة ساحر", "Wizard hat", "combo10"],
	["astronaut", "خوذة فضاء", "Space helmet", "meteor50"], ["dino", "قبعة ديناصور", "Dino hood", "giant3"],
	["viking", "خوذة فايكنغ", "Viking helmet", "invasion10"], ["propeller", "طاقية مروحة", "Propeller cap", "frenzy3"],
	["crown", "تاج", "Crown", "castle25"], ["pirate", "قبعة قرصان", "Pirate hat", "gallery10"], ["scarf", "وشاح", "Scarf", "summit1"],
	["headband", "عصابة رياضية", "Sports headband", "monsters15"], ["bowtie", "بابيون", "Bow tie", "balance1"],
	["aviator", "قبعة طيّار", "Aviator cap", "balance5"], ["halo", "هالة", "Halo", "balanceClean"], ["woodhat", "قبعة خشبية", "Wooden hat", "ricochet5"],
	["falcon", "صقر", "Falcon", "ricochetAce"], ["gradcap", "قبعة تخرّج", "Graduation cap", "maze1"],
	["starGlasses", "نظارة نجوم", "Star glasses", "maze5"], ["beanie", "طاقية صوف", "Wool hat", "mazeClean"],
	# The big-number challenges' rewards.
	["umbrella", "قبعة مظلة", "Umbrella hat", "score1k"], ["goldShades", "نظارة طيّار ذهبية", "Gold aviators", "modes10"],
	["turban", "عمامة", "Turban", "bricks100"], ["taifRose", "طوق ورد طائفي", "Taif rose crown", "castle200"],
	["farwa", "قبعة فروة", "Fleece hat", "frenzy500"], ["diving", "نظارة غوص", "Diving mask", "meteor500"],
	["lantern", "فانوس رمضان", "Ramadan lantern", "combo25"], ["palm", "تاج سعف", "Palm-frond crown", "pop500"],
	["goldPal", "دحروج ذهبي صغير", "Little golden Dahrooj", "golden25"],
	["misbaha", "مسبحة", "Misbaha", "total50k"], ["karak", "كوب كرك", "Karak cup", "score10k"],
	["sadu", "وشاح سدو", "Sadu scarf", "giant30"], ["medal", "ميدالية ذهبية", "Gold medal", "shots1000"],
	["goldAgal", "غترة وعقال ذهبي", "Ghutra & gold agal", "modesAll"], ["bisht", "بشت", "Bisht", "total100k"],
	["trophy", "كأس البطولة", "Trophy", "total250k"],
	# The last of all: every other challenge finished (GameRuntime.ALL_DONE; the finale).
	["worldCup", "كأس العالم", "World Cup", "allDone"],
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
	["fair25", 25, "٢٥ نقطة بالملاهي", "25 in one fair visit"],
	["bell3", 3, "اضرب الجرس ٣ مرات", "Ring the bell 3 times"],
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
## The studio site and the hosted privacy policy, shown on the About page.
const WEBSITE := "abodengames.com"
const PRIVACY_URL := "abodengames.com/dahrooj-privacy.html"
## Names and descriptions taken from the shipped credits.html.
const CREDITS := [
	["Aboden Games", "دحروج والتصميم والموسيقى والأصوات الأصلية", "Dahrooj, design, original music and sounds"],
	["Bruno Simon", "أصول وأجزاء من العالم", "Environment assets and adapted world work"],
	["Amazon", "نماذج وحدات التحكم", "Controller models"],
	["Meta · Three.js / super-three", "أدوات الواقع الممتد ومكتبات الرسم", "Immersive tools and rendering libraries"],
]


## [id, goal, ar, en] of a challenge: this list's, else the game's (GameRuntime.CHALLENGES).
static func challenge(id: String) -> Array:
	for c: Array in CHALLENGES:
		if c[0] == id:
			return c
	var g := GameRuntime.challenge(id)
	return [] if g.is_empty() else [g[0], g[3], g[1], g[2]]


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


static func color(id: String) -> Array:
	for c: Array in COLORS:
		if c[0] == id:
			return c
	return []


## Whether Dahrooj's colour `id` can be picked: open from the start, its challenge finished
## (progress = challenge id -> value), or "reward:<id>" = 1.
static func color_available(id: String, progress: Dictionary) -> bool:
	var c := color(id)
	if c.is_empty():
		return false
	var need := str(c[4]) if c.size() > 4 else ""
	if need == "" or int(progress.get("reward:" + id, 0)) == 1:
		return true
	var ch := challenge(need)
	return not ch.is_empty() and int(progress.get(ch[0], 0)) >= int(ch[1])


## The Touch-controller bindings for a mode and throw style (after quest-controls.ts,
## with the native control scheme: in every mode the triggers fire shots and a
## grip holds Dahrooj): {a, b, left_trigger, right_trigger, left_grip, right_grip,
## grip}, each [ar, en] (grip: one line on how to throw). Right A steps to the next open
## shot style and B to the next accessory, but on the Summit A jumps (B is empty, "") and in
## ricochet A picks the next paddle.
static func quest_controls(mode: String, throw_style: String) -> Dictionary:
	var tilting := mode == "balance" or mode == "maze"
	var tabletop := tilting or mode == "ricochet"
	var fire := ["إطلاق المقذوفات", "Fire shots"]
	var grab := ["إمساك دحروج", "Grab Dahrooj"]
	var left_grip := grab
	var right_grip := grab
	var grip := ["القبضة: امسك دحروج · اضغط للشحن وأفلت للرمي", "Grip: hold Dahrooj · hold to charge, release to throw"]
	# Right A and B (main.gd _on_button): the next open shot style and accessory.
	var a := ["الطلقة التالية", "Next shot"]
	var b := ["الإكسسوار التالي", "Next accessory"]
	if throw_style == "hand":
		grip = ["القبضة: امسك دحروج، حرّك يدك ثم أفلت", "Grip: grab Dahrooj, swing your hand, then release"]
	elif throw_style == "sling":
		left_grip = ["مسك النبيطة", "Hold slingshot"]
		right_grip = ["سحب ثم إفلات", "Pull, then release"]
		grip = ["النبيطة باليسرى · اسحب بقبضة اليمنى ثم أفلت", "Slingshot in the left hand · pull with the right grip, release"]
	if tabletop:
		# No shots in the tabletop modes.
		fire = ["—", "—"] if tilting else ["تصويب وإطلاق دحروج", "Aim and launch Dahrooj"]
		if tilting:
			left_grip = ["إمساك اللوح وإمالته", "Hold and tilt board"]
			grip = ["القبضة: امسك اللوح وأمله · الإفلات يوقفه", "Grip: hold and tilt the board · release to pause"]
		else:
			# The left stick turns the selected paddle, A picks the next one; the grips are free.
			a = ["اللوح التالي", "Next paddle"]
			left_grip = ["—", "—"]
			grip = ["القير الأيسر: تدوير اللوح المحدد بخطوات ٥° · A: اللوح التالي · الزناد: وجّه وأطلق", "Left stick: turn the glowing paddle in 5° steps · A: next paddle · trigger: aim, launch"]
		right_grip = left_grip
	elif mode == "climb":
		# A jumps, a trigger throws (no shots on the Summit); the grips are free.
		a = ["قفز", "Jump"]
		b = ["", ""]
		fire = ["رمي كرة", "Throw a ball"]
		left_grip = ["—", "—"]
		right_grip = ["—", "—"]
		grip = ["زر A: قفز · الزناد: رمي · القير الأيسر: حركة · الأيمن: حجم الجبل", "A: jump · trigger: throw · left stick: move · right stick: resize"]
	return {"a": a, "b": b, "left_trigger": fire, "right_trigger": fire, "left_grip": left_grip, "right_grip": right_grip, "grip": grip}
