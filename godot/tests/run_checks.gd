## Headless data check. From the godot folder:
##   godot --headless -s res://tests/run_checks.gd
## Exits with code 1 if the data has warnings.
extends SceneTree


func _init() -> void:
	var db := GameDatabase.new()
	db.load_all()
	print(DebugReport.build(db))
	var code := 0 if db.warnings.is_empty() else 1
	db.free()
	quit(code)
