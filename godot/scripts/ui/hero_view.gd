## The hero sprite, as heroReact() in game.js: the standing pose bobs gently;
## success, damage and defeat play 4 frames at 140 ms, then success and damage
## return to the standing pose after 600 ms (defeat holds its last frame).
## The picture sits bottom-centred, 8 px above the box's bottom edge.
class_name HeroView
extends Control

const FRAMES := {"success": 4, "damage": 4, "defeat": 4}
const FRAME_SEC := 0.14
const HOLD_SEC := 0.6

## Picture heights: standing pose and reaction frames (web: 236 / 178).
var main_h := 236.0
var frame_h := 178.0
var bob_amp := 6.0
var bob_period := 3.2
## Title screen: fit the width instead and keep bobbing.
var fit_width := false

var _kind := ""        # "" = standing pose
var _frame := 0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func react(kind: String) -> void:
	if not FRAMES.has(kind):
		_kind = ""
	else:
		_kind = kind
		_frame = 0
		_t = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if _kind != "":
		_t += delta
		var n: int = FRAMES[_kind]
		var f := int(_t / FRAME_SEC)
		if f >= n:
			f = n - 1
			if _kind != "defeat" and _t >= n * FRAME_SEC + HOLD_SEC:
				_kind = ""
		_frame = f
	queue_redraw()


func _draw() -> void:
	var tex := UIKit.hero_texture("main" if _kind == "" else "%s-%d" % [_kind, _frame])
	if tex == null:
		return
	var ts := tex.get_size()
	var h := main_h if _kind == "" else frame_h
	var w := ts.x * h / ts.y
	if fit_width:
		w = size.x
		h = ts.y * w / ts.x
	var y := size.y - 8.0 - h
	if _kind == "" or fit_width:
		var t := Time.get_ticks_msec() / 1000.0
		y -= bob_amp * (0.5 - 0.5 * cos(t * TAU / bob_period))
	var r := Rect2(Vector2((size.x - w) / 2.0, y), Vector2(w, h))
	# soft drop shadow like the CSS filter
	draw_texture_rect(tex, Rect2(r.position + Vector2(0, 8), r.size), false, Color(0, 0, 0, 0.3))
	draw_texture_rect(tex, r, false)
