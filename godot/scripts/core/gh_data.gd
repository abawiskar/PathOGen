## Component library, icons and monsters, loaded from data/*.json.
## Those files are generated from web/js/data.js and web/js/monsters.js by
## tools/sync_from_web.py, so the Godot and web versions share one source.
class_name GHData
extends RefCounted

static var components: Dictionary = {}   # id -> { name, cat, tier, ins:[[L,name,desc]], outs, desc, id }
static var icons: Dictionary = {}        # id -> svg inner markup (24x24, stroke=currentColor)
static var filler: Array = []
static var monsters: Dictionary = {}     # key -> { name, place, art, intents:{k:w}, trait, frenzy? }
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	var c = _read_json("res://data/components.json")
	if c is Dictionary:
		components = c.get("components", {})
		icons = c.get("icons", {})
		filler = c.get("filler", [])
		for id in components:
			components[id]["id"] = id
	var m = _read_json("res://data/monsters.json")
	if m is Dictionary:
		monsters = m
	_loaded = true


static func comp(id: String) -> Dictionary:
	ensure_loaded()
	return components.get(id, {})


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
