## Autoload "GameDB". Loads the PathOGen sheet exports.
##
## Load order (later wins, per file):
##   1. res://data/<name>.csv   shipped with the game
##   2. user://data/<name>.csv  drop newer exports here to test without a rebuild
##
## Expected files (one per sheet tab):
##   puzzles.csv, puzzle_cards.csv, cards.csv, monsters.csv, lifesavers.csv
class_name GameDatabase
extends Node

signal reloaded

const FILES := {
	"puzzles": "puzzles.csv",
	"puzzle_cards": "puzzle_cards.csv",
	"cards": "cards.csv",
	"monsters": "monsters.csv",
	"lifesavers": "lifesavers.csv",
}

var cards: Dictionary = {}       # StringName -> CardData
var monsters: Dictionary = {}    # StringName -> MonsterData
var lifesavers: Dictionary = {}  # StringName -> LifeSaverData
var puzzles: Dictionary = {}     # StringName -> PuzzleData
var puzzle_order: Array[StringName] = []
var warnings: PackedStringArray = []
var sources: Dictionary = {}     # file key -> path actually loaded


func _ready() -> void:
	load_all()


func load_all() -> void:
	cards.clear(); monsters.clear(); lifesavers.clear(); puzzles.clear()
	puzzle_order.clear(); warnings.clear(); sources.clear()

	for row in _rows("cards"):
		var c := CardData.from_row(row)
		if c.id != &"":
			cards[c.id] = c
	for row in _rows("monsters"):
		var m := MonsterData.from_row(row)
		if m.id != &"":
			monsters[m.id] = m
	for row in _rows("lifesavers"):
		var l := LifeSaverData.from_row(row)
		if l.id != &"":
			lifesavers[l.id] = l
	for row in _rows("puzzles"):
		var p := PuzzleData.from_row(row)
		if p.id != &"":
			puzzles[p.id] = p
			puzzle_order.append(p.id)
	for row in _rows("puzzle_cards"):
		var pid := StringName(row.get("Puzzle ID", ""))
		if not puzzles.has(pid):
			warnings.append("Puzzle Cards row for unknown puzzle '%s'" % pid)
			continue
		puzzles[pid].entries.append(PuzzleCardEntry.from_row(row))

	_validate()
	for w in warnings:
		push_warning("PathOGen data: " + w)
	reloaded.emit()


func get_puzzle(id: StringName) -> PuzzleData:
	return puzzles.get(id)


func get_card(id: StringName) -> CardData:
	return cards.get(id)


func get_monster(id: StringName) -> MonsterData:
	return monsters.get(id)


func _rows(key: String) -> Array[Dictionary]:
	var file: String = FILES[key]
	for dir in ["user://data/", "res://data/"]:
		var path: String = dir + file
		if FileAccess.file_exists(path):
			sources[key] = path
			return CsvTable.load_rows(path)
	warnings.append("Missing %s (looked in user://data and res://data)" % file)
	return []


func _validate() -> void:
	for pid in puzzle_order:
		var p: PuzzleData = puzzles[pid]
		if not monsters.has(p.monster_id):
			warnings.append("%s uses unknown monster '%s'" % [pid, p.monster_id])
		if p.entries.is_empty():
			warnings.append("%s has no cards in its list" % pid)
		var slots := {}
		for e in p.entries:
			if not cards.has(e.card_id):
				warnings.append("%s lists unknown card '%s'" % [pid, e.card_id])
			if e.zone == GameEnums.Zone.PRE_PLACED:
				if e.slot < 0:
					warnings.append("%s: pre-placed %s has no slot" % [pid, e.card_id])
				elif slots.has(e.slot):
					warnings.append("%s: two cards pre-placed in slot %d" % [pid, e.slot])
				slots[e.slot] = true
