## Runs one puzzle: hand and deck, monster HP, turns, LifeSavers, stars.
## No UI here; scenes listen to the signals and call these methods.
class_name PuzzleSession
extends RefCounted

signal monster_hp_changed(hp: int, max_hp: int)
signal monster_acted(intent: String, attack: GameEnums.Attack)
signal definition_ran(result: Dictionary)
signal card_drawn(card: CardData)
signal finished(won: bool, stars: int)

var puzzle: PuzzleData
var monster: MonsterData
var player: PlayerState
var cards: Dictionary
var hand: Array[CardData] = []
var deck: Array[CardData] = []
var pre_placed: Dictionary = {}
var locked_slots: Array[int] = []
var monster_hp: int = 0
var turn: int = 0
var lifesaver_uses: Dictionary = {}  # id -> uses left
var stars_spent: int = 0
var is_over: bool = false


func _init(p_puzzle: PuzzleData, p_cards: Dictionary, p_monster: MonsterData,
		p_lifesavers: Dictionary) -> void:
	puzzle = p_puzzle
	cards = p_cards
	monster = p_monster
	player = PlayerState.new(puzzle.hearts, puzzle.energy_per_turn)
	var layout := puzzle.build_layout(cards)
	hand = layout.hand
	deck = layout.deck
	pre_placed = layout.pre_placed
	locked_slots = layout.locked_slots
	monster_hp = monster.max_hp if monster else 0
	for id in p_lifesavers:
		lifesaver_uses[id] = (p_lifesavers[id] as LifeSaverData).uses_per_puzzle


## Run the definition. [param path] as in DamageCalc.compute.
func run_definition(path: Array, item_count: int, output_type: GameEnums.OutputType) -> Dictionary:
	var result := DamageCalc.compute(path, item_count, output_type, monster, puzzle.item_cap)
	result["meets_required_output"] = puzzle.required_output == GameEnums.OutputType.ANY \
		or output_type == puzzle.required_output
	if result.lagged:
		player.lose_hearts(1)
	else:
		monster_hp = maxi(0, monster_hp - result.damage)
		monster_hp_changed.emit(monster_hp, monster.max_hp)
	definition_ran.emit(result)
	if monster_hp == 0 and result.meets_required_output:
		_finish(true)
	elif player.is_dead():
		_finish(false)
	return result


## Monster's turn, then the next player turn begins with a draw.
func end_turn() -> void:
	if is_over:
		return
	if monster.attacks_on_turn(turn):
		var intent := monster.intent_for_turn(turn)
		var attack := GameEnums.Attack.DAMAGE if intent.to_lower() == "attack" else monster.signature_attack
		player.receive_attack(attack, monster.damage)
		monster_acted.emit(intent, attack)
		if player.is_dead():
			_finish(false)
			return
	turn += 1
	player.start_turn()
	draw(1)


func draw(count: int) -> void:
	for i in count:
		if deck.is_empty():
			return
		var c: CardData = deck.pop_front()  # puzzles draw in sheet order
		hand.append(c)
		card_drawn.emit(c)


## Applies the parts of a LifeSaver this layer can do. UI-only effects
## (Hint, 50/50, Search) return true here and the UI does the rest.
func use_lifesaver(ls: LifeSaverData) -> bool:
	if is_over or lifesaver_uses.get(ls.id, 0) <= 0:
		return false
	lifesaver_uses[ls.id] -= 1
	stars_spent += ls.star_cost
	match ls.effect:
		GameEnums.LifeSaverEffect.HEALTH_POTION:
			player.heal(ls.value)
		GameEnums.LifeSaverEffect.CLEAR_VISION:
			for a in [GameEnums.Attack.BLURRED_VISION, GameEnums.Attack.ICON_CURSE, GameEnums.Attack.LOCKED_COMPONENT]:
				player.clear_status(a)
		GameEnums.LifeSaverEffect.SECOND_CHANCE:
			player.second_chance_armed = true
	return true


## 1 star for winning, +1 for finishing within par, +1 for spending no stars on LifeSavers.
func star_rating(won: bool) -> int:
	if not won:
		return 0
	var stars := 1
	if turn + 1 <= puzzle.par_turns:
		stars += 1
	if stars_spent == 0:
		stars += 1
	return stars


func _finish(won: bool) -> void:
	if is_over:
		return
	is_over = true
	finished.emit(won, star_rating(won))
