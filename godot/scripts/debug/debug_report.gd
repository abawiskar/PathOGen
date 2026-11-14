## Text summary of the loaded data plus a scripted run of the first puzzle.
## Used by the debug scene and the headless check script.
class_name DebugReport
extends RefCounted


static func build(db: GameDatabase) -> String:
	var out := PackedStringArray()
	out.append("PathOGen data check")
	out.append("Cards %d | Monsters %d | LifeSavers %d | Puzzles %d" % [
		db.cards.size(), db.monsters.size(), db.lifesavers.size(), db.puzzles.size()])
	for key in db.sources:
		out.append("  %s <- %s" % [key, db.sources[key]])
	out.append("")
	for pid in db.puzzle_order:
		var p: PuzzleData = db.puzzles[pid]
		var m: MonsterData = db.get_monster(p.monster_id)
		out.append("%s  %s  vs %s (HP %d, threat %d, %s)" % [
			p.id, p.display_name,
			m.display_name if m else "?", m.max_hp if m else 0,
			m.get_threat_value() if m else 0,
			GameEnums.name_of(GameEnums.Attack, m.signature_attack) if m else "?"])
		out.append("  hearts %d, energy %d, item cap %d, needs %s, par %d, %d cards" % [
			p.hearts, p.energy_per_turn, p.item_cap,
			GameEnums.name_of(GameEnums.OutputType, p.required_output), p.par_turns, p.total_cards()])
		for e in p.entries:
			var c: CardData = db.get_card(e.card_id)
			out.append("    %-16s x%d  %-10s dmg %d  cost %d%s" % [
				c.display_name if c else str(e.card_id), e.quantity,
				GameEnums.name_of(GameEnums.Zone, e.zone),
				e.get_damage(c) if c else 0, e.get_cost(c) if c else 0,
				"  [locked slot %d]" % e.slot if e.locked else ""])
	out.append("")
	if db.warnings.is_empty():
		out.append("No data warnings.")
	else:
		out.append("Warnings:")
		for w in db.warnings:
			out.append("  - " + w)
	out.append("")
	out.append_array(simulate_first(db))
	return "\n".join(out)


## Plays the first puzzle with every card wired in, to sanity-check the rules.
static func simulate_first(db: GameDatabase) -> PackedStringArray:
	var log := PackedStringArray()
	if db.puzzle_order.is_empty():
		return log
	var p: PuzzleData = db.puzzles[db.puzzle_order[0]]
	var m: MonsterData = db.get_monster(p.monster_id)
	if m == null:
		return log
	var s := PuzzleSession.new(p, db.cards, m, db.lifesavers)
	var path := []
	var final_type := GameEnums.OutputType.ANY
	for e in p.entries:
		var c: CardData = db.get_card(e.card_id)
		if c == null or c.id == &"C-SLIDER":
			continue
		path.append({"card": c, "entry": e})
		if c.output_type != GameEnums.OutputType.SAME_AS_INPUT:
			final_type = c.output_type
	log.append("Simulating %s: every card wired, output %s x1" % [
		p.display_name, GameEnums.name_of(GameEnums.OutputType, final_type)])
	s.finished.connect(func(won, stars): log.append("  Finished: %s, %d star(s)" % ["WON" if won else "LOST", stars]))
	for t in 4:
		if s.is_over:
			break
		var r := s.run_definition(path, 1, final_type)
		log.append("  Turn %d: base %d x%d items x%.1f = %d damage%s. %s at %d/%d HP" % [
			t + 1, r.base, r.items, r.multiplier, r.damage, " (LAG)" if r.lagged else "",
			m.display_name, s.monster_hp, m.max_hp])
		if s.is_over:
			break
		var intent := m.intent_for_turn(s.turn)
		s.end_turn()
		log.append("    %s uses %s. Hearts %d/%d. Statuses: %s" % [
			m.display_name, intent, s.player.hearts, s.player.max_hearts,
			", ".join(s.player.statuses.keys().map(func(a): return GameEnums.name_of(GameEnums.Attack, a)))])
	return log
