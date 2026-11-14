## One row of the Puzzle Cards tab: a card in a puzzle's card list.
class_name PuzzleCardEntry
extends Resource

@export var card_id: StringName
@export var quantity: int = 1
@export var zone: GameEnums.Zone = GameEnums.Zone.HAND
## Node slot for pre-placed cards. -1 = none.
@export var slot: int = -1
@export var locked: bool = false
## -1 = use the card's own value.
@export var damage_override: int = -1
@export var cost_override: int = -1
@export var notes: String


static func from_row(row: Dictionary) -> PuzzleCardEntry:
	var e := PuzzleCardEntry.new()
	e.card_id = StringName(row.get("Card ID", ""))
	e.quantity = maxi(1, CsvTable.to_int(row.get("Qty", ""), 1))
	e.zone = GameEnums.parse(GameEnums.Zone, row.get("Zone", ""), GameEnums.Zone.HAND, "zone on " + e.card_id) as GameEnums.Zone
	e.slot = CsvTable.to_int(row.get("Slot", ""), -1)
	e.locked = CsvTable.to_bool(row.get("Locked", ""))
	e.damage_override = CsvTable.to_int(row.get("Damage Override", ""), -1)
	e.cost_override = CsvTable.to_int(row.get("Cost Override", ""), -1)
	e.notes = row.get("Notes", "")
	return e


func get_damage(card: CardData) -> int:
	return damage_override if damage_override >= 0 else card.base_damage


func get_cost(card: CardData) -> int:
	return cost_override if cost_override >= 0 else card.energy_cost
