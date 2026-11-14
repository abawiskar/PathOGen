## Placeholder main scene: shows what GameDB loaded. Press F5 to reload
## after dropping new CSV exports into the data folder.
extends Control

var _label: RichTextLabel


func _ready() -> void:
	_label = RichTextLabel.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 24
	_label.offset_top = 24
	_label.offset_right = -24
	_label.offset_bottom = -24
	_label.add_theme_font_size_override("normal_font_size", 16)
	_label.scroll_following = false
	add_child(_label)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F5:
		GameDB.load_all()
		_refresh()


func _refresh() -> void:
	_label.text = DebugReport.build(GameDB) + "\n\n(F5 reloads the CSVs)"
