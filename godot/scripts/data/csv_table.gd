## Reads a CSV exported from the PathOGen sheet into rows keyed by header.
## Columns are found by header name, so the team can reorder or add
## columns in the sheet without breaking the game.
class_name CsvTable
extends RefCounted


static func load_rows(path: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return rows
	var header := f.get_csv_line()
	# Strip a UTF-8 BOM if the export added one.
	if header.size() > 0 and header[0].begins_with("﻿"):
		header[0] = header[0].substr(1)
	while not f.eof_reached():
		var line := f.get_csv_line()
		if line.size() == 0 or (line.size() == 1 and line[0].strip_edges().is_empty()):
			continue
		var row := {}
		for i in header.size():
			row[header[i].strip_edges()] = line[i].strip_edges() if i < line.size() else ""
		rows.append(row)
	return rows


static func to_int(v: Variant, fallback: int) -> int:
	var s := str(v).strip_edges()
	if s.is_empty() or not s.is_valid_float():
		return fallback
	return roundi(s.to_float())


static func to_float(v: Variant, fallback: float) -> float:
	var s := str(v).strip_edges()
	return s.to_float() if s.is_valid_float() else fallback


static func to_bool(v: Variant) -> bool:
	return str(v).strip_edges().to_upper() in ["TRUE", "YES", "1", "X"]


## "Attack, Attack, Tangle" -> ["Attack", "Attack", "Tangle"]
static func to_list(v: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	for part in str(v).split(",", false):
		var p := part.strip_edges()
		if not p.is_empty():
			out.append(p)
	return out
