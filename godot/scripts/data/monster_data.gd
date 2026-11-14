## A monster (bug) from the Monsters tab.
class_name MonsterData
extends Resource

@export var id: StringName
@export var display_name: String
@export var grove: String
@export var max_hp: int = 10
## Hearts taken by a Damage attack.
@export var damage: int = 1
## Attacks every N turns. 1 = every turn.
@export var attack_interval: int = 1
## Telegraphed intents shown above its head, cycling, e.g. ["Attack", "Attack", "Tangle"].
@export var intent_pattern: PackedStringArray = []
@export var signature_attack: GameEnums.Attack = GameEnums.Attack.DAMAGE
## How nasty the signature attack is, for the threat value.
@export var attack_weight: float = 0.0
@export var weak_to: GameEnums.OutputType = GameEnums.OutputType.ANY
@export var resists: GameEnums.OutputType = GameEnums.OutputType.ANY
@export var has_weakness: bool = false
@export var has_resistance: bool = false
@export_multiline var notes: String
@export var art: Texture2D

const WEAK_MULT := 2.0
const RESIST_MULT := 0.5


static func from_row(row: Dictionary) -> MonsterData:
	var m := MonsterData.new()
	m.id = StringName(row.get("Monster ID", row.get("Bug ID", "")))
	m.display_name = row.get("Name", "")
	m.grove = row.get("Grove", "")
	m.max_hp = CsvTable.to_int(row.get("HP", ""), 10)
	m.damage = CsvTable.to_int(row.get("Damage", ""), 1)
	m.attack_interval = maxi(1, CsvTable.to_int(row.get("Attacks Every (turns)", ""), 1))
	m.intent_pattern = CsvTable.to_list(row.get("Intent Pattern", ""))
	m.signature_attack = GameEnums.parse(GameEnums.Attack, row.get("Signature Attack", ""), GameEnums.Attack.DAMAGE, "attack on " + m.id) as GameEnums.Attack
	m.attack_weight = CsvTable.to_float(row.get("Attack Weight", ""), 0.0)
	var weak: String = row.get("Weak To", "")
	var res: String = row.get("Resists", "")
	m.has_weakness = not weak.strip_edges().is_empty()
	m.has_resistance = not res.strip_edges().is_empty()
	m.weak_to = GameEnums.parse(GameEnums.OutputType, weak, GameEnums.OutputType.ANY, "weakness on " + m.id) as GameEnums.OutputType
	m.resists = GameEnums.parse(GameEnums.OutputType, res, GameEnums.OutputType.ANY, "resistance on " + m.id) as GameEnums.OutputType
	m.notes = row.get("Notes", "")
	return m


## Same formula as the sheet's Threat Value column.
func get_threat_value() -> int:
	return roundi(float(damage) / attack_interval * 2.0 + max_hp / 5.0 + attack_weight)


## Multiplier for a definition whose final output is [param output].
func type_multiplier(output: GameEnums.OutputType) -> float:
	if has_weakness and output == weak_to:
		return WEAK_MULT
	if has_resistance and output == resists:
		return RESIST_MULT
	return 1.0


func attacks_on_turn(turn: int) -> bool:
	return (turn + 1) % attack_interval == 0


func intent_for_turn(turn: int) -> String:
	if intent_pattern.is_empty():
		return "Attack"
	return intent_pattern[turn % intent_pattern.size()]
