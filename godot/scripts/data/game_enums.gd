## Shared enums for PathOGen, plus helpers that turn spreadsheet text
## ("Pre-placed", "Blurred Vision", "50/50") into enum values.
class_name GameEnums
extends RefCounted

enum Category { PARAMS, MATHS, SETS, VECTOR, CURVE, SURFACE, MESH, TRANSFORM }

## What a card (or a whole definition) outputs. Monsters are weak to or resist these.
enum OutputType { ANY, NUMBER, VECTOR, POINT, CURVE, BREP, MESH, SAME_AS_INPUT }

## Where a card starts in a puzzle.
enum Zone { HAND, DECK, PRE_PLACED }

## Monster attacks, from the team's "Monster Attacks and Penalties" table.
enum Attack { DAMAGE, BLURRED_VISION, ICON_CURSE, SCRAMBLE, LOCKED_COMPONENT, TIME_PRESSURE }

## LifeSaver effects, from the team's "LifeSaver Cards" notes.
enum LifeSaverEffect { HINT, HEALTH_POTION, FIFTY_FIFTY, CLEAR_VISION, SECOND_CHANCE, SEARCH }


## "Pre-placed" -> "PRE_PLACED", "50/50" -> "FIFTY_FIFTY".
static func to_key(text: String) -> String:
	var t := text.strip_edges().to_upper()
	if t == "50/50":
		return "FIFTY_FIFTY"
	for ch in [" ", "-", "/"]:
		t = t.replace(ch, "_")
	return t


## Look up [param text] in an enum dictionary (e.g. GameEnums.Zone).
## Returns [param fallback] and warns if the text is not a known value.
static func parse(enum_dict: Dictionary, text: String, fallback: int, context := "") -> int:
	if text.strip_edges().is_empty():
		return fallback
	var key := to_key(text)
	if enum_dict.has(key):
		return enum_dict[key]
	push_warning("PathOGen: unknown value '%s' %s" % [text, context])
	return fallback


static func name_of(enum_dict: Dictionary, value: int) -> String:
	var k = enum_dict.find_key(value)
	return str(k).capitalize() if k != null else "?"
