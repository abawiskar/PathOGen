## One puzzle (graph) from the Puzzles tab, with its card list.
class_name PuzzleData
extends Resource

@export var id: StringName
@export var display_name: String
@export var grove: String
@export var encounter: int = 1
@export var monster_id: StringName
@export var hearts: int = 4
@export var energy_per_turn: int = 3
## More items than this in the output and the definition Lags.
@export var item_cap: int = 8
@export var required_output: GameEnums.OutputType = GameEnums.OutputType.ANY
@export var par_turns: int = 3
@export_multiline var notes: String
## Optional columns the team may add later.
@export var learning_objective: String
@export var example_challenge: String
@export var entries: Array[PuzzleCardEntry] = []


static func from_row(row: Dictionary) -> PuzzleData:
	var p := PuzzleData.new()
	p.id = StringName(row.get("Puzzle ID", ""))
	p.display_name = row.get("Name", "")
	p.grove = row.get("Grove", "")
	p.encounter = CsvTable.to_int(row.get("Encounter", ""), 1)
	p.monster_id = StringName(row.get("Monster ID", row.get("Bug ID", "")))
	p.hearts = CsvTable.to_int(row.get("Hearts", ""), 4)
	p.energy_per_turn = CsvTable.to_int(row.get("Energy / Turn", ""), 3)
	p.item_cap = CsvTable.to_int(row.get("Item Cap (Lag)", ""), 8)
	p.required_output = GameEnums.parse(GameEnums.OutputType, row.get("Required Output", ""), GameEnums.OutputType.ANY, "required output on " + p.id) as GameEnums.OutputType
	p.par_turns = CsvTable.to_int(row.get("Par Turns", ""), 3)
	p.notes = row.get("Notes", "")
	p.learning_objective = row.get("Learning Objective", "")
	p.example_challenge = row.get("Example Challenge", "")
	return p


## Expands quantities into individual card instances, sorted by zone.
## Returns { "hand": Array[CardData], "deck": Array[CardData],
##           "pre_placed": { slot:int -> CardData }, "locked_slots": Array[int] }
func build_layout(cards: Dictionary) -> Dictionary:
	var hand: Array[CardData] = []
	var deck: Array[CardData] = []
	var pre := {}
	var locked: Array[int] = []
	for e in entries:
		var card: CardData = cards.get(e.card_id)
		if card == null:
			continue
		for i in e.quantity:
			match e.zone:
				GameEnums.Zone.HAND:
					hand.append(card)
				GameEnums.Zone.DECK:
					deck.append(card)
				GameEnums.Zone.PRE_PLACED:
					pre[e.slot] = card
					if e.locked:
						locked.append(e.slot)
	return {"hand": hand, "deck": deck, "pre_placed": pre, "locked_slots": locked}


func total_cards() -> int:
	var n := 0
	for e in entries:
		n += e.quantity
	return n
