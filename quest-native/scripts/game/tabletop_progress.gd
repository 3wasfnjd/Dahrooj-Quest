class_name TabletopProgress
extends RefCounted
## Tabletop progression (src/progression/tabletop-progress.ts). Five distinct rounds
## survive mode switches and reloads; replaying one cannot fill the set.


## best: Save.best; progress(id: String, value: int): GameRuntime.ch_progress;
## result: TabletopGame won() result {mode, level, attempts, failures, stars}.
static func record_win(best: Dictionary, progress: Callable, result: Dictionary) -> void:
	var mode := str(result.get("mode", ""))
	var lv = result.get("level", -1)
	if not mode in ["balance", "ricochet", "maze"] or typeof(lv) != TYPE_INT or lv < 0 or lv >= 5:
		return
	var level: int = lv
	var attempts := int(result.get("attempts", 0))
	var failures := int(result.get("failures", 0))
	var stars := int(result.get("stars", 0))
	var key := "tabletop:%s:cleared" % mode
	var mask := (int(best.get(key, 0)) | (1 << level)) & 31
	best[key] = mask
	var count := 0
	for i in 5:
		count += (mask >> i) & 1
	progress.call(mode + "1", 1)
	progress.call(mode + "5", count)
	if mode == "balance" and failures == 0:
		progress.call("balanceClean", 1)
	if mode == "ricochet" and attempts == 1 and failures == 0:
		progress.call("ricochetAce", 1)
	if mode == "maze" and stars == 3 and failures == 0:
		progress.call("mazeClean", 1)


## On resetting the challenges (complete-game.js resetChallenges).
static func clear(best: Dictionary) -> void:
	for key in best.keys():
		if str(key).begins_with("tabletop:"):
			best.erase(key)
