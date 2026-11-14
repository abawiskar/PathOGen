## Component library, icons and monsters, loaded from data/*.json.
## Those files are generated from web/js/data.js and web/js/monsters.js by
## tools/sync_from_web.py, so the Godot and web versions share one source.
class_name GHData
extends RefCounted

static var components: Dictionary = {}   # id -> { name, cat, tier, ins:[[L,name,desc]], outs, desc, id }
static var icons: Dictionary = {}        # id -> svg inner markup (24x24, stroke=currentColor)
static var filler: Array = []
static var monsters: Dictionary = {}     # key -> { name, place, img? or art, trait, placeholder? }
static var phases: Array = []            # attack set by level position: { line, intents:{k:w}, frenzy? }
## Preview one monster on every level: run with `-- --monster=<key>` (web: ?monster=<key>).
static var monster_override := ""
## Godot-only components without an icon of their own borrow one: id -> icon id.
static var icon_alias: Dictionary = {}
## Grasshopper's own component icons (img/gh-icons/<file>.svg, David Rutten's artwork): id -> file.
static var gh_icons: Dictionary = {}
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	var c = _read_json("res://data/components.json")
	if c is Dictionary:
		components = c.get("components", {})
		icons = c.get("icons", {})
		filler = c.get("filler", [])
		gh_icons = c.get("gh_icons", {})
	# Godot-only components (from tools/ghx_to_level.py); the web sync never touches this file
	var gc = _read_json("res://data/components_godot.json")
	if gc is Dictionary:
		var extra: Dictionary = gc.get("components", {})
		for id in extra:
			if not components.has(id):
				components[id] = extra[id]
		icon_alias = gc.get("icon_alias", {})
	for id in components:
		components[id]["id"] = id
	var m = _read_json("res://data/monsters.json")
	if m is Dictionary:
		monsters = m.get("options", {})
		phases = m.get("phases", [])
	# Godot-only options (new art the web version doesn't use yet); sync never touches this file
	var extra = _read_json("res://data/monsters_godot.json")
	if extra is Dictionary:
		var opts: Dictionary = extra.get("options", {})
		for key in opts:
			if monsters.has(key):
				monsters[key].merge(opts[key], true)
			else:
				monsters[key] = opts[key]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--monster=") and monsters.has(a.substr(10)):
			monster_override = a.substr(10)
	_loaded = true


static func comp(id: String) -> Dictionary:
	ensure_loaded()
	return components.get(id, {})


static func monster_key(level: Dictionary) -> String:
	ensure_loaded()
	return monster_override if monster_override != "" else str(level.get("monster", "placeholder"))


## The level's monster with the attack phase for its position on the path
## (the last phase repeats when there are more levels than phases).
static func monster_for(level: Dictionary, level_index: int) -> Dictionary:
	ensure_loaded()
	var m: Dictionary = monsters.get(monster_key(level), {}).duplicate(true)
	# a difficulty can pick the attack set ("attacks"); otherwise the level's place on the path
	var ph: int = int(level.attacks) if level.get("attacks") != null else level_index
	if not phases.is_empty():
		m.merge(phases[clampi(ph, 0, phases.size() - 1)], true)
	if level.get("timer") != null and float(level.timer) > 0:
		m.frenzy = float(level.timer)
	if not m.has("intents"):
		m.intents = {"hit": 1}
	return m


## First part of a category, e.g. "Curve / Primitive" -> "Curve".
static func cat_of(id: String) -> String:
	return str(comp(id).get("cat", "")).split(" / ")[0]


static func _read_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("PathOGen: cannot open %s (run tools/sync_from_web.py)" % path)
		return null
	var data = JSON.parse_string(f.get_as_text())
	if data == null:
		push_error("PathOGen: bad JSON in %s" % path)
	return data
