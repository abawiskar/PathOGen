## The player's hearts, energy and active monster effects for one puzzle.
class_name PlayerState
extends RefCounted

signal hearts_changed(hearts: int, max_hearts: int)
signal energy_changed(energy: int, max_energy: int)
signal status_added(attack: GameEnums.Attack, turns: int)
signal status_cleared(attack: GameEnums.Attack)
signal died

## How long each non-damage attack lasts, in player turns.
const STATUS_TURNS := {
	GameEnums.Attack.BLURRED_VISION: 2,
	GameEnums.Attack.ICON_CURSE: 2,
	GameEnums.Attack.SCRAMBLE: 1,       # applied once, the UI shuffles the hand
	GameEnums.Attack.LOCKED_COMPONENT: 2,
	GameEnums.Attack.TIME_PRESSURE: 1,  # next decision only
}
## Seconds on the clock while Time Pressure is active.
const TIME_PRESSURE_SECONDS := 10.0

var max_hearts: int = 4
var hearts: int = 4
var max_energy: int = 3
var energy: int = 3
## Attack -> turns left. Only non-damage attacks live here.
var statuses: Dictionary = {}
## Set by the Second Chance LifeSaver; absorbs the next wrong-move penalty.
var second_chance_armed: bool = false


func _init(p_hearts := 4, p_energy := 3) -> void:
	max_hearts = p_hearts
	hearts = p_hearts
	max_energy = p_energy
	energy = p_energy


func is_dead() -> bool:
	return hearts <= 0


func has_status(attack: GameEnums.Attack) -> bool:
	return statuses.get(attack, 0) > 0


func lose_hearts(amount: int) -> void:
	if amount <= 0 or is_dead():
		return
	hearts = maxi(0, hearts - amount)
	hearts_changed.emit(hearts, max_hearts)
	if hearts == 0:
		died.emit()


func heal(amount: int) -> void:
	hearts = mini(max_hearts, hearts + amount)
	hearts_changed.emit(hearts, max_hearts)


## A monster hit. Damage costs hearts; everything else becomes a status.
func receive_attack(attack: GameEnums.Attack, damage: int) -> void:
	if attack == GameEnums.Attack.DAMAGE:
		lose_hearts(damage)
		return
	var turns: int = STATUS_TURNS.get(attack, 1)
	statuses[attack] = maxi(statuses.get(attack, 0), turns)
	status_added.emit(attack, turns)


## Placing a card that doesn't fit, or running an invalid definition.
## Returns true if a heart was lost.
func wrong_move() -> bool:
	if second_chance_armed:
		second_chance_armed = false
		return false
	lose_hearts(1)
	return true


func clear_status(attack: GameEnums.Attack) -> void:
	if statuses.erase(attack):
		status_cleared.emit(attack)


func spend_energy(amount: int) -> bool:
	if amount > energy:
		return false
	energy -= amount
	energy_changed.emit(energy, max_energy)
	return true


## Start of each player turn: refill energy, count down statuses.
func start_turn() -> void:
	energy = max_energy
	energy_changed.emit(energy, max_energy)
	for attack in statuses.keys():
		statuses[attack] -= 1
		if statuses[attack] <= 0:
			clear_status(attack)
