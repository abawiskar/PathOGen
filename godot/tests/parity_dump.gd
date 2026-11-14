## Dumps preview scenes for every decision state of every level (for comparison with web/js/engine.js).
##   godot --headless --path . -s res://tests/parity_dump.gd -- <out.json>
extends SceneTree
func _init():
	GHData.ensure_loaded()
	LevelLoader.source_dir = LevelLoader.levels_dir()
	var idx = JSON.parse_string(FileAccess.get_file_as_string(LevelLoader.source_dir.path_join("index.json")))
	var out := {}
	var r3 := func(v: Vector3) -> Array: return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]
	for dir in idx.levels:
		var raw = JSON.parse_string(FileAccess.get_file_as_string(LevelLoader.source_dir.path_join(dir).path_join("level.json")))
		var stage = LevelLoader.load_stage(raw, dir, PackedStringArray())
		for df in stage.difficulties:
			_dump(df.level, dir + ":" + str(df.id), out, r3)
	var f := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	quit()


func _dump(L: Dictionary, key: String, out: Dictionary, r3: Callable) -> void:
	var params := {}
	for p in L.params: params[p.key] = p.value
	var dec := []
	for s in L.steps:
		dec.append(s.key)
		for q in s.quizzes: dec.append(q.key)
	var states := {}
	for k in dec.size() + 1:
		var done := dec.slice(0, k)
		var ctx := {"params": params, "placed": func(n): return n.given or done.has(n.id), "wire_active": func(w): return w.quiz == null or done.has(w.quiz)}
		var sc := GHEngine.scene(L, GHEngine.evaluate(L, ctx), ctx)
		states[str(k)] = {"lines": sc.lines.map(func(l): return {"n": l.pts.size(), "c": bool(l.get("closed", false)), "first": r3.call(l.pts[0]), "last": r3.call(l.pts[-1])}),
			"points": sc.points.map(func(p): return r3.call(p.p)), "labels": sc.labels.map(func(l): return l.text), "arrows": sc.arrows.map(func(a): return r3.call(a.to))}
	out[key] = {"states": states}
