## Progress: best XP and stars per level, and how many levels are unlocked.
## The web version keeps the same thing in localStorage ("pathogen.save.v1").
class_name SaveData
extends RefCounted

const PATH := "user://pathogen_save.json"
const RANKS := [[0, "Novice"], [600, "Apprentice"], [1500, "Wirebender"], [3000, "Definition Smith"], [5000, "Parametric Ranger"], [7500, "Script Master"]]

static var best: Dictionary = {}   # str(level id) -> { xp, stars }
static var unlocked := 1
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


static func write() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"best": best, "unlocked": unlocked}))


static func reset() -> void:
	best = {}
	unlocked = 1
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


static func best_for(level_id: int) -> Dictionary:
	ensure_loaded()
	return best.get(str(level_id), {})


static func record(level_id: int, xp: int, stars: int, level_index: int, level_count: int) -> void:
	ensure_loaded()
	var prev: Dictionary = best.get(str(level_id), {"xp": 0, "stars": 0})
	best[str(level_id)] = {"xp": maxi(int(prev.xp), xp), "stars": maxi(int(prev.stars), stars)}
	unlocked = maxi(unlocked, mini(level_count, level_index + 2))
	write()
