## One fight: the rules from web/js/game.js without any UI.
## The battle screen calls select/place/use_lifesaver/tick and listens to `fx`
## for toasts, floating numbers and animations, and to `changed` to redraw.
class_name Battle
extends RefCounted

signal changed
## kind: "toast" {msg, cls} | "float" {target, text, cls} | "anim" {target, name}
##       | "preview" {fresh} | "victory" {} | "defeat" {} | "dealt" {}
signal fx(kind: String, data: Dictionary)

const HAND_SIZE := {"guided": 4, "standard": 5, "independent": 6}
const LS_ORDER := ["hint", "potion", "fifty", "clear", "shield", "second"]
const LS_INFO := {
	"hint": ["Hint", "Reveals a clue about the missing component or port."],
	"potion": ["Health Potion", "Restores one heart."],
	"fifty": ["50/50", "Removes two incorrect cards from your hand."],
	"clear": ["Clear Vision", "Removes blur, the icon curse and hidden node labels."],
	"shield": ["Shield", "Blocks the next monster attack completely."],
	"second": ["Second Chance", "Undo your last mistake: health, penalty and card restored."],
}
const INTENT_TXT := {"hit": "1 damage", "damage": "2 damage", "blur": "1 dmg + blur", "icon": "1 dmg + icon curse", "scramble": "1 dmg + scramble", "locked": "1 dmg + lock node", "time": "1 dmg + time pressure"}
const ATTACK_NAME := {"hit": "Strike", "damage": "Heavy Strike", "blur": "Blurred Vision", "icon": "Icon Curse", "scramble": "Scramble", "locked": "Locked Component", "time": "Time Pressure"}

var rng := RandomNumberGenerator.new()
var idx: int
var L: Dictionary
var level_count: int
var health: int
var max_health: int
var di := 0
var decisions: Array = []
var done := {}
var hand: Array = []           # component ids, or "port:<i>" during a wire check
var selected = null            # id or null
var effects := {"blur": 0, "icon": 0, "locked": null}   # locked: { node, turns }
var timer = null               # { total, left } or null
var shield := false
var snap = null                # state before the last mistake, for Second Chance
var ls := {}
var xp := 0
var mistakes := 0
var aids := 0
var attempts := 0
var streak := 0
var drops := 0
var dec_mistakes := 0
var hint_shown := false
var params := {}
var journal: Array = []
var over := false
var won := false
var intent := "hit"
var last_placed = null
var fb := {}
var hp := 0
var hp_max := 0
var deal_anim := true
var pan := Vector2.ZERO
var score := {}                # filled on victory


func _init(level: Dictionary, level_index: int, total_levels: int, seed_value := -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	L = level
	idx = level_index
	level_count = total_levels
	health = int(L.health)
	max_health = health
	for s in L.steps:
		decisions.append({"kind": "comp", "key": s.key, "step": s})
		for q in s.quizzes:
			decisions.append({"kind": "quiz", "key": q.key, "step": s, "quiz": q})
	for k in L.lifesavers:
		ls[k] = int(L.lifesavers[k])
	for p in L.params:
		params[p.key] = float(p.value)
	for d in decisions:
		hp_max += 10 if d.kind == "comp" else 5
	hp = hp_max
	_roll_intent()
	_deal_hand()
	fb = {"cls": "", "head": "Field notes", "title": L.title, "body": L.objective, "meta": "[b]Skill:[/b] " + str(L.get("learn", ""))}


# ───── helpers ─────
func monster() -> Dictionary:
	return GHData.monsters.get(L.monster, GHData.monsters.get("rootbound", {}))

func cur():
	return decisions[di] if di < decisions.size() else null

func node_by_id(id: String) -> Dictionary:
	for n in L.nodes:
		if n.id == id:
			return n
	return {}

func is_placed(n: Dictionary) -> bool:
	return n.given or done.has(n.step)

func _shuffle(a: Array) -> Array:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t
	return a

func is_correct(d: Dictionary, id: String) -> bool:
	if d.kind == "comp":
		return id == d.step.comp
	return int(id.split(":")[1]) == d.quiz.answer_idx

func port_of(d: Dictionary, id: String) -> Array:
	var comp := GHData.comp(node_by_id(d.quiz.target).comp)
	return comp["ins" if d.quiz.side == "in" else "outs"][int(id.split(":")[1])]

func wrong_cards() -> Array:
	var d = cur()
	return hand.filter(func(id): return not is_correct(d, id)) if d != null else []


func _roll_intent() -> void:
	var w: Dictionary = monster().get("intents", {"hit": 1})
	var tot := 0.0
	for k in w:
		tot += float(w[k])
	var r := rng.randf() * tot
	intent = ""
	for k in w:
		r -= float(w[k])
		if r <= 0:
			intent = k
			break
	if intent == "":
		intent = w.keys()[0]


func _deal_hand(anim := true) -> void:
	var d = cur()
	if d == null:
		hand = []
		return
	if d.kind == "comp":
		var ids: Array = [d.step.comp] + d.step.distractors
		var size := maxi(int(HAND_SIZE.get(L.guidance, 5)), ids.size())
		var fill := _shuffle(GHData.filler.filter(func(f): return not ids.has(f)))
		while ids.size() < size and not fill.is_empty():
			ids.append(fill.pop_back())
		hand = _shuffle(ids.slice(0, size))
	else:
		var comp := GHData.comp(node_by_id(d.quiz.target).comp)
		hand = []
		for i in comp["ins" if d.quiz.side == "in" else "outs"].size():
			hand.append("port:%d" % i)
	selected = null
	hint_shown = false
	deal_anim = anim
	pan = Vector2.ZERO
	fx.emit("dealt", {})


# ───── core actions ─────
func select(id) -> void:
	if over:
		return
	selected = null if selected == id else id
	changed.emit()


func place(id = null) -> void:
	if id == null:
		id = selected
	if over or id == null:
		return
	var d = cur()
	if d == null:
		return
	attempts += 1
	snap = null
	if is_correct(d, id):
		_on_correct(d, id)
	else:
		_on_wrong(d, id)


func _io_meta(c: Dictionary) -> String:
	var f := func(arr: Array) -> String:
		if arr.is_empty():
			return "—"
		return " · ".join(arr.map(func(p): return "%s %s" % [p[0], p[1]]))
	return "[b]In:[/b] %s\n[b]Out:[/b] %s" % [f.call(c.ins), f.call(c.outs)]


func _on_correct(d: Dictionary, id: String) -> void:
	clear_timer()
	done[d.key] = true
	var clean := dec_mistakes == 0
	var gain := (100 if d.kind == "comp" else 60) + (40 if clean else 0)
	xp += gain
	var dmg := 10 if d.kind == "comp" else 5
	hp = maxi(0, hp - dmg)
	streak += 1
	last_placed = d.step.key if d.kind == "comp" else null
	fx.emit("float", {"target": "monster", "text": "-%d" % dmg, "cls": ""})
	fx.emit("float", {"target": "health", "text": "+%d XP" % gain, "cls": "good"})
	fx.emit("anim", {"target": "monster", "name": "hurt"})
	fx.emit("anim", {"target": "hero", "name": "cheer"})
	if d.kind == "comp":
		var c := GHData.comp(id)
		fb = {"cls": "ok", "head": "Correct", "title": c.name, "body": d.step.why, "meta": _io_meta(c)}
		journal.append({"cls": "ok", "title": "✓ " + c.name, "text": d.step.why})
	else:
		var p := port_of(d, id)
		fb = {"cls": "ok", "head": "Wire connected", "title": "%s · %s" % [p[0], p[1]], "body": d.quiz.why, "meta": ""}
		journal.append({"cls": "ok", "title": "✓ Wire → %s (%s)" % [p[0], p[1]], "text": d.quiz.why})
	# penalties wear off as you make progress
	if effects.blur > 0:
		effects.blur -= 1
	if effects.icon > 0:
		effects.icon -= 1
	if effects.locked != null:
		effects.locked.turns -= 1
		if effects.locked.turns <= 0:
			effects.locked = null
	# streak drop
	if streak % 3 == 0 and drops < 2:
		drops += 1
		var k: String = ["hint", "potion", "shield", "fifty"][rng.randi_range(0, 3)]
		ls[k] = int(ls.get(k, 0)) + 1
		fx.emit("toast", {"msg": "Streak bonus: +1 " + LS_INFO[k][0], "cls": "good", "delay": 0.5})
	dec_mistakes = 0
	di += 1
	var fresh: String
	if d.kind == "comp":
		fresh = d.step.key
	elif d.quiz.side == "in":
		fresh = d.quiz.target
	else:
		fresh = d.quiz.target
		for w in L.wires:
			if w.quiz == d.key:
				fresh = w.to[0]
	fx.emit("preview", {"fresh": fresh})
	if di >= decisions.size():
		hand = []
		selected = null
		_victory()
		return
	_deal_hand()
	changed.emit()
	if monster().has("frenzy"):
		start_timer(float(monster().frenzy))


func _on_wrong(d: Dictionary, id: String) -> void:
	mistakes += 1
	dec_mistakes += 1
	streak = 0
	var s := {"health": health, "effects": effects.duplicate(true), "hand": hand.duplicate(), "intent": intent,
		"timer_left": timer.left if timer != null else null, "timer_total": timer.total if timer != null else null, "shield": shield, "id": id}
	hand = hand.filter(func(h): return h != id)
	selected = null
	var title: String
	var body: String
	if d.kind == "comp":
		var c := GHData.comp(id)
		title = c.name
		body = d.step.wrong.get(id, d.step.wrong.get("*", "%s: %s But this slot needs %s." % [c.name, c.desc, d.step.need]))
		fb = {"cls": "bad", "head": "Not quite", "title": title, "body": body, "meta": _io_meta(c)}
	else:
		var p := port_of(d, id)
		title = "%s · %s" % [p[0], p[1]]
		body = d.quiz.wrong.get(p[0], d.quiz.wrong.get("*", "%s (%s) expects %s." % [p[0], p[1], p[2]]))
		fb = {"cls": "bad", "head": "Wrong port", "title": title, "body": body, "meta": ""}
	journal.append({"cls": "bad", "title": "✗ " + title, "text": body})
	_monster_attack(s)


func _monster_attack(s: Dictionary) -> void:
	if shield:
		shield = false
		fx.emit("toast", {"msg": "Your shield blocks the attack!", "cls": "good"})
		fx.emit("anim", {"target": "monster", "name": "attack"})
		changed.emit()
		return
	var it := intent
	var dmg := 1
	fx.emit("anim", {"target": "monster", "name": "attack"})
	fx.emit("anim", {"target": "flash", "name": "red", "delay": 0.22})
	fx.emit("anim", {"target": "hero", "name": "hit", "delay": 0.22})
	match it:
		"damage":
			dmg = 2
		"blur":
			effects.blur = 2
		"icon":
			effects.icon = 2
		"scramble":
			var before := ",".join(hand)
			var n := 0
			while true:
				_shuffle(hand)
				n += 1
				if not (",".join(hand) == before and hand.size() > 1 and n < 8):
					break
			deal_anim = true
		"locked":
			var cands: Array = L.nodes.filter(func(nd): return is_placed(nd))
			if not cands.is_empty():
				effects.locked = {"node": cands[rng.randi_range(0, cands.size() - 1)].id, "turns": 3}
			else:
				dmg = 2
		"time":
			start_timer(15.0)
	health = maxi(0, health - dmg)
	fx.emit("toast", {"msg": "%s: %s!%s" % [monster().get("name", "Monster"), ATTACK_NAME.get(it, it), " (-2)" if dmg > 1 else ""], "cls": "bad", "delay": 0.25})
	fx.emit("float", {"target": "hearts", "text": "-%d" % dmg, "cls": "bad"})
	snap = s
	_roll_intent()
	changed.emit()
	fx.emit("anim", {"target": "intent", "name": "flash"})
	if health <= 0:
		_defeat()


func _on_timeout() -> void:
	clear_timer()
	if over:
		return
	mistakes += 1
	streak = 0
	if shield:
		shield = false
		fx.emit("toast", {"msg": "Out of time, but your shield absorbs the hit.", "cls": "good"})
	else:
		health = maxi(0, health - 1)
		fx.emit("anim", {"target": "monster", "name": "attack"})
		fx.emit("anim", {"target": "flash", "name": "red"})
		fx.emit("anim", {"target": "hero", "name": "hit"})
		fx.emit("toast", {"msg": "Too slow! The monster strikes.", "cls": "bad"})
		fx.emit("float", {"target": "hearts", "text": "-1", "cls": "bad"})
	journal.append({"cls": "bad", "title": "✗ Out of time", "text": "Hesitation cost a heart. Lifesavers like Hint and 50/50 can speed up a tough decision."})
	changed.emit()
	if health <= 0:
		_defeat()
		return
	if monster().has("frenzy"):
		start_timer(float(monster().frenzy))


# ───── timer ─────
func start_timer(sec: float) -> void:
	timer = {"total": sec, "left": sec}
	changed.emit()

func clear_timer() -> void:
	timer = null

## Call every frame from the battle screen. Pass paused=true while a modal is open.
func tick(delta: float, paused := false) -> void:
	if timer == null or paused or over:
		return
	timer.left -= delta
	if timer.left <= 0:
		_on_timeout()


# ───── lifesavers ─────
func can_use(k: String) -> bool:
	if over and not (k == "second" and snap != null and not won):
		return false
	if int(ls.get(k, 0)) <= 0:
		return false
	match k:
		"hint": return not hint_shown and cur() != null
		"potion": return health < max_health
		"fifty": return cur() != null and wrong_cards().size() >= 2
		"clear": return effects.blur > 0 or effects.icon > 0 or effects.locked != null
		"shield": return not shield
		"second": return snap != null
	return false


func use_lifesaver(k: String) -> void:
	if not can_use(k):
		return
	ls[k] = int(ls[k]) - 1
	aids += 1
	var d = cur()
	match k:
		"hint":
			hint_shown = true
			var txt: String = d.step.hint if d.kind == "comp" else d.quiz.hint
			fb = {"cls": "hint", "head": "Hint", "title": "Looking for…" if d.kind == "comp" else "Wire check", "body": txt,
				"meta": ("This slot needs %s." % d.step.need) if d.kind == "comp" else ""}
			journal.append({"cls": "aid", "title": "★ Hint", "text": txt})
		"potion":
			health = mini(max_health, health + 1)
			fx.emit("toast", {"msg": "+1 heart", "cls": "good"})
			fx.emit("float", {"target": "hearts", "text": "+1", "cls": "good"})
		"fifty":
			var rm := _shuffle(wrong_cards()).slice(0, 2)
			hand = hand.filter(func(h): return not rm.has(h))
			if rm.has(selected):
				selected = null
			fx.emit("toast", {"msg": "Two wrong cards removed", "cls": "good"})
		"clear":
			effects = {"blur": 0, "icon": 0, "locked": null}
			fx.emit("toast", {"msg": "Your vision clears", "cls": "good"})
		"shield":
			shield = true
			fx.emit("toast", {"msg": "Shield raised", "cls": "good"})
		"second":
			var s: Dictionary = snap
			snap = null
			health = s.health
			effects = s.effects
			hand = s.hand
			intent = s.intent
			shield = s.shield
			mistakes = maxi(0, mistakes - 1)
			dec_mistakes = maxi(0, dec_mistakes - 1)
			if s.timer_left == null:
				clear_timer()
			else:
				timer = {"total": s.timer_total, "left": s.timer_left}
			if over:
				over = false
				fx.emit("revived", {})
			fb = {"cls": "hint", "head": "Second chance", "title": "Mistake undone", "body": "Health, penalties and your hand are restored. Think it through: the explanation still applies.", "meta": ""}
			journal.append({"cls": "aid", "title": "↺ Second Chance", "text": "Last mistake undone."})
			fx.emit("toast", {"msg": "Time rewinds…", "cls": "good"})
	changed.emit()


# ───── victory / defeat ─────
func _victory() -> void:
	over = true
	won = true
	clear_timer()
	var perfect := mistakes == 0 and aids == 0
	var eff := roundi(200.0 * decisions.size() / maxi(attempts, 1))
	var hp_bonus := health * 50
	var perf_bonus := 500 if perfect else 0
	var total := xp + eff + hp_bonus + perf_bonus
	var stars := 3 if mistakes == 0 else (2 if mistakes <= 2 else 1)
	score = {"xp": xp, "eff": eff, "hp_bonus": hp_bonus, "perfect": perfect, "perf_bonus": perf_bonus, "total": total, "stars": stars}
	SaveData.record(int(L.id), total, stars, idx, level_count)
	fb = {"cls": "ok", "head": "Definition complete", "title": "Your script runs!", "body": "Drag the sliders in the preview: the whole definition updates live. That is parametric design.", "meta": ""}
	changed.emit()
	fx.emit("victory", {})


func _defeat() -> void:
	if won:
		return
	over = true
	clear_timer()
	changed.emit()
	fx.emit("defeat", {})
