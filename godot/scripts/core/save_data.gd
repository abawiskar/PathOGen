## Progress: best XP and stars per level, and how many levels are unlocked.
## The web version keeps the same thing in localStorage ("pathogen.save.v1").
class_name SaveData
extends RefCounted

const PATH := "user://pathogen_save.json"
const RANKS := [[0, "Novice"], [600, "Apprentice"], [1500, "Wirebender"], [3000, "Definition Smith"], [5000, "Parametric Ranger"], [7500, "Script Master"]]

static var best: Dictionary = {}   # "<level id>:<difficulty id>" -> { xp, stars }
static var unlocked := 1
static var diff: Dictionary = {}   # str(level id) -> last difficulty index played
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		best = d.get("best", {})
		unlocked = int(d.get("unlocked", 1))
		diff = d.get("diff", {})


static func write() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"best": best, "unlocked": unlocked, "diff": diff}))


static func reset() -> void:
	best = {}
	unlocked = 1
	diff = {}
	write()


static func total_xp() -> int:
	ensure_loaded()
	var t := 0
	for k in best:
		t += int(best[k].get("xp", 0))
	return t


static func rank_for(xp: int) -> String:
	var r := "Novice"
	for e in RANKS:
		if xp >= e[0]:
			r = e[1]
	return r


## Saves are per level and difficulty, as bestKey() in game.js.
static func key_for(level: Dictionary) -> String:
	return "%d:%s" % [int(level.id), str(level.get("diff_id", "standard"))]


static func best_for(key: String) -> Dictionary:
	ensure_loaded()
	return best.get(key, {})


## Best of any difficulty of a stage (for the map card).
static func stage_best(stage: Dictionary) -> Dictionary:
	var out := {}
	for d in stage.get("difficulties", []):
		var b := best_for(key_for(d.level))
		if not b.is_empty():
			out = {"xp": maxi(int(out.get("xp", 0)), int(b.xp)), "stars": maxi(int(out.get("stars", 0)), int(b.stars))}
	return out


static func last_diff(stage: Dictionary) -> int:
	ensure_loaded()
	return mini(int(diff.get(str(int(stage.id)), 0)), stage.get("difficulties", [0]).size() - 1)


static func set_last_diff(stage: Dictionary, d: int) -> void:
	diff[str(int(stage.id))] = d
	write()


static func record(key: String, xp: int, stars: int, level_index: int, level_count: int) -> void:
	ensure_loaded()
	var prev: Dictionary = best.get(key, {"xp": 0, "stars": 0})
	best[key] = {"xp": maxi(int(prev.xp), xp), "stars": maxi(int(prev.stars), stars)}
	unlocked = maxi(unlocked, mini(level_count, level_index + 2))
	write()
