## Headless checks. From the godot folder:
##   godot --headless -s res://tests/run_checks.gd
## Loads every level, solves each graph, plays a perfect run and a messy run.
## Exits with code 1 on any failure.
extends SceneTree

var failures := 0


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("  FAIL: ", msg)


func correct_id(b: Battle) -> String:
	var d = b.cur()
	if d.kind == "comp":
		return d.step.comp
	return "port:%d" % d.quiz.answer_idx


func _init() -> void:
	SaveData.ensure_loaded()
	var loaded := LevelLoader.load_all()
	print("Levels from ", LevelLoader.source_dir, ": ", loaded.levels.size())
	for e in loaded.errors:
		check(false, e)
	var n: int = loaded.levels.size()
	var runs := []
	for i in n:
		for df in loaded.levels[i].difficulties:
			runs.append([i, df.level])
	for run in runs:
		var i: int = run[0]
		var L: Dictionary = run[1]
		# 1. every decision's correct card is in the dealt hand, and a perfect run wins with 3 stars
		var b := Battle.new(L, i, n, 7)
		var guard := 0
		while not b.over and guard < 200:
			guard += 1
			var id := correct_id(b)
			check(b.hand.has(id), "%s: correct card %s not in hand %s" % [L.dir, id, b.hand])
			b.place(id)
		check(b.won, "%s: perfect run did not win" % L.dir)
		var mon := b.monster()
		check(mon.has("line") and mon.has("intents") and mon.has("name"), "%s: monster should merge option + phase" % L.dir)
		var pi: int = int(L.attacks) if L.get("attacks") != null else i
		var ph: Dictionary = GHData.phases[clampi(pi, 0, GHData.phases.size() - 1)]
		check(mon.intents == ph.intents, "%s: monster intents should come from phase %d" % [L.dir, pi])
		if L.get("hand") != null and b.decisions.size() > 0:
			var b2 := Battle.new(L, i, n, 3)
			if b2.cur().kind == "comp":
				check(b2.hand.size() == maxi(2, int(L.hand)), "%s: hand should hold %d cards, has %d" % [L.dir, int(L.hand), b2.hand.size()])
		check(b.score.get("stars", 0) == 3, "%s: perfect run should give 3 stars" % L.dir)
		check(b.hp == 0, "%s: monster HP should reach 0, is %d" % [L.dir, b.hp])
		# full graph solves to some preview geometry
		var ctx := {"params": b.params, "placed": func(nd): return true, "wire_active": func(_w): return true}
		var sc := GHEngine.scene(L, GHEngine.evaluate(L, ctx), ctx)
		check(sc.lines.size() + sc.points.size() > 0, "%s: finished definition previews nothing" % L.dir)

		# 2. messy run: wrong picks trigger attacks; second chance restores; enough mistakes lose
		var m := Battle.new(L, i, n, 11)
		var wrong: String = m.wrong_cards()[0]
		var h0 := m.health
		m.place(wrong)
		check(m.health < h0 or m.effects.blur > 0 or m.effects.icon > 0 or m.effects.locked != null or m.timer != null,
			"%s: wrong pick had no effect" % L.dir)
		check(not m.hand.has(wrong), "%s: wrong card should leave the hand" % L.dir)
		if m.can_use("second"):
			m.use_lifesaver("second")
			check(m.health == h0, "%s: second chance should restore health" % L.dir)
		var g2 := 0
		while not m.over and g2 < 50:
			g2 += 1
			var wc := m.wrong_cards()
			if wc.is_empty():
				m.place(correct_id(m))
			else:
				m.place(wc[0])
		check(m.over, "%s: messy run never ended" % L.dir)
		print("  %-24s %-14s %-20s decisions %2d  perfect %d XP  messy run %s" % [L.dir, L.diff_name, b.monster().get("name", "?"), b.decisions.size(), b.score.get("total", 0), "won" if m.won else "lost"])
	SaveData.reset()
	print("FAILURES: ", failures)
	quit(1 if failures > 0 else 0)
