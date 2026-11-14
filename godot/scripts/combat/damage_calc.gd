## Damage from running a definition. Proposed model, still open for the team:
##
##   damage = (sum of card damage on the path to the output)
##          x (number of items in the output list)
##          x (monster weakness / resistance to the output type)
##
## If the output holds more items than the puzzle's item cap, the definition
## LAGS: it deals no damage and the player loses a heart.
class_name DamageCalc
extends RefCounted


## [param path] is an Array of { "card": CardData, "entry": PuzzleCardEntry }
## for the cards connected to the output. Loose cards are left out by the caller.
static func compute(path: Array, item_count: int, output_type: GameEnums.OutputType,
		monster: MonsterData, item_cap: int) -> Dictionary:
	var base := 0
	for step in path:
		var card: CardData = step["card"]
		var entry: PuzzleCardEntry = step.get("entry")
		base += entry.get_damage(card) if entry != null else card.base_damage

	var result := {
		"base": base,
		"items": item_count,
		"multiplier": 1.0,
		"damage": 0,
		"lagged": false,
	}
	if item_count > item_cap:
		result.lagged = true
		return result
	var mult := monster.type_multiplier(output_type) if monster != null else 1.0
	result.multiplier = mult
	result.damage = int(floor(base * maxi(item_count, 1) * mult))
	return result
