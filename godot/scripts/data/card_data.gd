## One Grasshopper component card, from the Cards tab.
class_name CardData
extends Resource

@export var id: StringName
@export var display_name: String
@export var nickname: String
@export var category: GameEnums.Category = GameEnums.Category.PARAMS
## Port text as written in the sheet, e.g. "G (Geometry), T (Vector)".
## Typed PortDefs come later, once wiring rules are settled.
@export var inputs_text: String
@export var outputs_text: String
@export var output_type: GameEnums.OutputType = GameEnums.OutputType.ANY
@export var base_damage: int = 0
@export var energy_cost: int = 1
@export_multiline var description: String
@export var icon: Texture2D


static func from_row(row: Dictionary) -> CardData:
	var c := CardData.new()
	c.id = StringName(row.get("Card ID", ""))
	c.display_name = row.get("Name", "")
	c.nickname = row.get("Nickname", "")
	c.category = GameEnums.parse(GameEnums.Category, row.get("Category", ""), GameEnums.Category.PARAMS, "category on " + c.id) as GameEnums.Category
	c.inputs_text = row.get("Inputs", "")
	c.outputs_text = row.get("Outputs", "")
	c.output_type = GameEnums.parse(GameEnums.OutputType, row.get("Output Type", ""), GameEnums.OutputType.ANY, "output type on " + c.id) as GameEnums.OutputType
	c.base_damage = CsvTable.to_int(row.get("Base Damage", ""), 0)
	c.energy_cost = CsvTable.to_int(row.get("Energy Cost", ""), 1)
	c.description = row.get("Description", "")
	return c
