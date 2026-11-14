## Loads levels/<dir>/level.json and normalises them for the game.
## Port of web/js/loader.js; the level format is documented in levels/README.md.
##
## Where levels come from:
##   - Running from the editor inside the repo: <repo>/web/levels, so the web
##     team's edits show up immediately.
##   - Exported game (or no web folder next to the project): res://levels,
##     which tools/sync_from_web.py keeps up to date.
class_name LevelLoader
extends RefCounted

static var source_dir := ""


static func levels_dir() -> String:
	if OS.has_feature("editor"):
		var web := ProjectSettings.globalize_path("res://").path_join("../web/levels").simplify_path()
		if FileAccess.file_exists(web.path_join("index.json")):
			return web
	return "res://levels"


## Returns { levels: Array, errors: PackedStringArray }.
static func load_all() -> Dictionary:
	GHData.ensure_loaded()
	source_dir = levels_dir()
	var errors := PackedStringArray()
	var levels := []
	var idx = _read_json(source_dir.path_join("index.json"))
	if not (idx is Dictionary):
		errors.append("Cannot read %s/index.json" % source_dir)
		return {"levels": levels, "errors": errors}
	for dir in idx.get("levels", []):
		var raw = _read_json(source_dir.path_join(dir).path_join("level.json"))
		if not (raw is Dictionary):
			errors.append("levels/%s/level.json: cannot read or parse" % dir)
			continue
		var stage = load_stage(raw, dir, errors)
		if stage != null:
			levels.append(stage)
	return {"levels": levels, "errors": errors}


## Godot-only difficulty lists (e.g. levels converted from .ghx files) live in
## res://levels_godot/<dir>/difficulties.json and replace the level's own list.
## Their "file" entries are read from that folder. The web sync never touches it.
const GODOT_LEVELS := "res://levels_godot"


## One path stage: its difficulties, each a full playable level (loader.js loadAll).
## The stage itself is its first difficulty plus { difficulties: [{id, name, description, level}] }.
static func load_stage(raw: Dictionary, dir: String, errors: PackedStringArray) -> Variant:
	var list: Array = raw.get("difficulties", [])
	var file_dir := source_dir.path_join(dir)
	var extra = _read_json(GODOT_LEVELS.path_join(dir).path_join("difficulties.json"))
	if extra is Dictionary and not extra.get("difficulties", []).is_empty():
		list = extra.difficulties
		file_dir = GODOT_LEVELS.path_join(dir)
	if list.is_empty():
		list = [{"id": "standard", "name": "Standard"}]
	var base: Dictionary = raw.duplicate(true)
	base.erase("difficulties")
	var diffs := []
	for i in list.size():
		var entry: Dictionary = list[i]
		var def := {}
		if entry.has("file"):
			var d = _read_json(file_dir.path_join(entry.file))
			if not (d is Dictionary):
				errors.append("levels/%s/%s: cannot read or parse" % [dir, entry.file])
				continue
			def = d
		var knobs: Dictionary = entry.duplicate(true)
		for k in ["file", "id", "name", "description"]:
			knobs.erase(k)
		var merged: Dictionary = base.duplicate(true)
		merged.merge(def, true)
		merged.merge(knobs, true)
		# "open": which node ids the player places in this difficulty (the rest start on the canvas)
		if merged.get("open") is Array:
			var open: Array = merged.open
			merged.nodes = merged.get("nodes", []).map(func(n):
				var c: Dictionary = n.duplicate(true)
				c.open = open.has(n.id)
				return c)
		var r := normalize(merged, dir + (("/" + str(entry.file)) if entry.has("file") else ""))
		if r.has("error"):
			errors.append(r.error)
			continue
		var lvl: Dictionary = r.level
		lvl.dir = dir
		lvl.diff_id = str(entry.get("id", i + 1))
		lvl.diff_name = str(entry.get("name", "Difficulty %d" % (i + 1)))
		lvl.diff_desc = str(entry.get("description", ""))
		lvl.diff_index = diffs.size()
		diffs.append({"id": lvl.diff_id, "name": lvl.diff_name, "description": lvl.diff_desc, "level": lvl})
	if diffs.is_empty():
		return null
	for d in diffs:
		d.level.diff_count = diffs.size()
	var stage: Dictionary = diffs[0].level.duplicate()
	stage.difficulties = diffs
	return stage


static func _read_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text()) if f else null


## Returns [node_id, port_index] or an error string.
static func _resolve_port(nodes: Array, ref: String, side: String, where: String) -> Variant:
	var dot := ref.rfind(".")
	var id := ref.substr(0, dot)
	var p := ref.substr(dot + 1)
	var n = null
	for x in nodes:
		if x.id == id:
			n = x
	if n == null:
		return '%s: wire "%s" points at unknown node "%s"' % [where, ref, id]
	var comp := GHData.comp(n.comp)
	var list: Array = comp[side]
	var i := -1
	for k in list.size():
		if list[k][0] == p:
			i = k
			break
	if i < 0 and p.is_valid_int():
		i = p.to_int()
	if i < 0 or i >= list.size():
		return '%s: %s has no %s "%s" (%s)' % [where, comp.name, "input" if side == "ins" else "output", p, ref]
	return [id, i]


static func topo_order(nodes: Array, wires: Array) -> Array:
	var indeg := {}
	var index := {}
	for i in nodes.size():
		indeg[nodes[i].id] = 0
		index[nodes[i].id] = i
	for w in wires:
		indeg[w.to[0]] += 1
	var ready := []
	for n in nodes:
		if indeg[n.id] == 0:
			ready.append(n.id)
	var out := []
	while not ready.is_empty():
		ready.sort_custom(func(a, b): return index[a] < index[b])
		var id = ready.pop_front()
		out.append(id)
		for w in wires:
			if w.from[0] == id:
				indeg[w.to[0]] -= 1
				if indeg[w.to[0]] == 0:
					ready.append(w.to[0])
	return out


static func default_distractors(comp_id: String) -> Array:
	var pool := []
	for k in GHData.components:
		if k != comp_id and GHData.cat_of(k) == GHData.cat_of(comp_id):
			pool.append(k)
	pool.shuffle()
	return pool.slice(0, 5)


## Returns { level } or { error }.
static func normalize(raw: Dictionary, dir: String) -> Dictionary:
	var where := ("levels/%s" % dir) if dir.contains("/") else ("levels/%s/level.json" % dir)
	var nodes := []
	for n in raw.get("nodes", []):
		if not GHData.components.has(n.get("comp", "")):
			return {"error": '%s: unknown component "%s" on node "%s"' % [where, n.get("comp"), n.get("id")]}
		var nn: Dictionary = n.duplicate(true)
		nn.given = not n.get("open", false)
		nn.step = n.id if n.get("open", false) else null
		nodes.append(nn)
	var wires := []
	var raw_wires: Array = raw.get("wires", [])
	for i in raw_wires.size():
		var w: Dictionary = raw_wires[i]
		var from = _resolve_port(nodes, w.from, "outs", where)
		if from is String:
			return {"error": from}
		var to = _resolve_port(nodes, w.to, "ins", where)
		if to is String:
			return {"error": to}
		wires.append({"from": from, "to": to, "check": w.get("check"), "quiz": ("wire:%d" % i) if w.get("check") != null else null})
	var open_ids := nodes.filter(func(n): return n.get("open", false)).map(func(n): return n.id)
	var order: Array
	if raw.has("order"):
		order = raw.order.duplicate()
	else:
		order = topo_order(nodes, wires).filter(func(id): return open_ids.has(id))
	for id in open_ids:
		if not order.has(id):
			return {"error": '%s: open node "%s" missing from "order"' % [where, id]}
	var by_id := {}
	for n in nodes:
		by_id[n.id] = n
	var steps := []
	for id in order:
		var n: Dictionary = by_id[id]
		var c := GHData.comp(n.comp)
		var distractors: Array = n.get("distractors", default_distractors(n.comp))
		steps.append({
			"key": id, "comp": n.comp,
			"need": n.get("need", "the right %s component" % GHData.cat_of(n.comp)),
			"distractors": distractors.filter(func(d): return GHData.components.has(d) and d != n.comp),
			"hint": n.get("hint", "Look in the %s panel." % str(c.cat).replace(" / ", " › ")),
			"why": n.get("correct", "%s: %s" % [c.name, c.desc]),
			"wrong": n.get("wrong", {}), "quizzes": [],
		})
	var pos := func(id: String) -> int:
		return order.find(id) if by_id[id].get("open", false) else -1
	for w in wires:
		if w.check == null:
			continue
		var side := "out" if w.check.get("side") == "out" else "in"
		var target: String = w.to[0] if side == "in" else w.from[0]
		var idx: int = w.to[1] if side == "in" else w.from[1]
		var comp := GHData.comp(by_id[target].comp)
		var port: Array = comp["ins" if side == "in" else "outs"][idx]
		var quiz := {
			"key": w.quiz, "target": target, "side": side, "answer": port[0], "answer_idx": idx,
			"prompt": w.check.get("prompt", "Which %s of %s should this wire connect to?" % ["input" if side == "in" else "output", comp.name]),
			"hint": w.check.get("hint", "It carries %s." % port[2]),
			"why": w.check.get("correct", "%s (%s) expects %s." % [port[0], port[1], port[2]]),
			"wrong": w.check.get("wrong", {}),
		}
		if steps.is_empty():
			continue
		steps[maxi(0, maxi(pos.call(w.from[0]), pos.call(w.to[0])))].quizzes.append(quiz)
	var monster: String = raw.get("monster", "placeholder")
	if not GHData.monsters.has(monster):
		push_warning('%s: unknown monster "%s"' % [where, monster])
		monster = "placeholder"
	var level := {"params": [], "lifesavers": {}, "health": 4, "guidance": "standard"}
	level.merge(raw, true)
	level.dir = dir
	level.monster = monster
	level.nodes = nodes
	level.wires = wires
	level.steps = steps
	level.health = int(level.health)
	level.id = int(level.get("id", 0))
	for k in level.lifesavers:
		level.lifesavers[k] = int(level.lifesavers[k])
	return {"level": level}
