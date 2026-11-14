## A LifeSaver from the LifeSavers tab: Hint, Health Potion, 50/50,
## Clear Vision, Second Chance, Search.
## Whether these are cards in hand or separate buttons is still open,
## so this only holds the data; PuzzleSession tracks uses.
class_name LifeSaverData
extends Resource

@export var id: StringName
@export var display_name: String
@export var command: String
@export var effect: GameEnums.LifeSaverEffect = GameEnums.LifeSaverEffect.HINT
## Meaning depends on effect: hearts healed, cards removed, etc.
@export var value: int = 1
@export var uses_per_puzzle: int = 1
## Stars lost at the end of the puzzle for each use.
@export var star_cost: int = 1
@export_multiline var help_text: String
@export var icon: Texture2D


static func from_row(row: Dictionary) -> LifeSaverData:
	var l := LifeSaverData.new()
	l.id = StringName(row.get("LifeSaver ID", ""))
	l.display_name = row.get("Name", "")
	l.command = row.get("Command", "")
	l.effect = GameEnums.parse(GameEnums.LifeSaverEffect, row.get("Effect", ""), GameEnums.LifeSaverEffect.HINT, "effect on " + l.id) as GameEnums.LifeSaverEffect
	l.value = CsvTable.to_int(row.get("Value", ""), 1)
	l.uses_per_puzzle = CsvTable.to_int(row.get("Uses / Puzzle", ""), 1)
	l.star_cost = CsvTable.to_int(row.get("Star Cost", ""), 1)
	l.help_text = row.get("Help Text", "")
	return l
