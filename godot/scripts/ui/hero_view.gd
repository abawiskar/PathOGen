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

## A team avatar (one picture, img/avatars/<id>.png) instead of the Spaghetti Hero's sprite frames:
## it reacts with motion (jump, shake, slump), as the web's .av-success / .av-damage / .av-defeat.
var avatar_path := ""
var avatar_h := 230.0
var avatar_max_w := 300.0

var _kind := ""        # "" = standing pose
var _frame := 0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func react(kind: String) -> void:
	if avatar_path != "":
		_kind = kind if kind in ["success", "damage", "defeat"] else ""
		_t = 0.0
		queue_redraw()
		return
	if not FRAMES.has(kind):
		_kind = ""
	else:
		_kind = kind
		_frame = 0
		_t = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if avatar_path != "":
		_t += delta
		if (_kind == "success" and _t > 0.7) or (_kind == "damage" and _t > 0.6):
			_kind = ""
		queue_redraw()
		return
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
	if avatar_path != "":
		_draw_avatar()
		return
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


static func _ease(keys: Array, t: float) -> float:
	# keys: [[time 0..1, value], ...] sorted; linear between them
	for i in range(1, keys.size()):
		if t <= keys[i][0]:
			var a: Array = keys[i - 1]
			var b: Array = keys[i]
			return lerpf(a[1], b[1], (t - a[0]) / maxf(b[0] - a[0], 1e-6))
	return keys[-1][1]


func _draw_avatar() -> void:
	var tex := UIKit.png_texture(avatar_path)
	if tex == null:
		return
	var ts := tex.get_size()
	var h := avatar_h
	var w := ts.x * h / ts.y
	if w > avatar_max_w:
		w = avatar_max_w
		h = ts.y * w / ts.x
	var off := Vector2.ZERO
	var rot := 0.0
	var tint := Color.WHITE
	var tm := Time.get_ticks_msec() / 1000.0
	match _kind:
		"success":
			var k := _t / 0.7
			off.y = _ease([[0, 0], [0.4, -22], [0.7, -4], [1, 0]], k)
			rot = deg_to_rad(_ease([[0, 0], [0.4, -3], [0.7, 0], [1, 0]], k))
		"damage":
			var k2 := _t / 0.6
			off.x = w * _ease([[0, 0], [0.2, -0.06], [0.45, 0.06], [0.7, -0.02], [1, 0]], k2)
			var red := _ease([[0, 0], [0.2, 1], [0.45, 0], [1, 0]], k2)
			tint = Color.WHITE.lerp(Color(1.6, 0.55, 0.45), red)
		"defeat":
			var k3 := minf(_t / 0.6, 1.0)
			off.y = 26 * k3
			rot = deg_to_rad(-10 * k3)
			tint = Color.WHITE.lerp(Color(0.5, 0.5, 0.5), k3)
		_:
			off.y = -bob_amp * (0.5 - 0.5 * cos(tm * TAU / bob_period))
	var base := Vector2(size.x / 2.0, size.y - 8.0) + off
	draw_set_transform(base, rot, Vector2.ONE)
	var r := Rect2(Vector2(-w / 2.0, -h), Vector2(w, h))
	draw_texture_rect(tex, Rect2(r.position + Vector2(0, 8), r.size), false, Color(0, 0, 0, 0.3))
	draw_texture_rect(tex, r, false, tint)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
