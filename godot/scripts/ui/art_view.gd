## A character picture (monster or hero) with the web version's CSS animations:
## idle bob, hurt, attack lunge, die, cheer and hit.
class_name ArtView
extends Control

var texture: Texture2D
var bob := true
var bob_amp := 8.0
var bob_period := 3.0
var dead := false
var _anim := ""
var _anim_t := 0.0
var _anim_len := 0.0
var _die_t := 0.0


func set_texture(t: Texture2D) -> void:
	texture = t
	dead = false
	_die_t = 0.0
	queue_redraw()


func play(name: String) -> void:
	_anim = name
	_anim_t = 0.0
	_anim_len = {"hurt": 0.5, "attack": 0.55, "cheer": 0.6, "hit": 0.5}.get(name, 0.5)


func kill() -> void:
	dead = true
	_die_t = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if _anim != "":
		_anim_t += delta
		if _anim_t >= _anim_len:
			_anim = ""
	if dead:
		_die_t = minf(_die_t + delta / 1.2, 1.0)
	queue_redraw()


func _draw() -> void:
	if texture == null:
		return
	var ts := texture.get_size()
	var k := minf(size.x / ts.x, size.y / ts.y)
	var dsz := ts * k
	var off := Vector2.ZERO
	var scl := 1.0
	var rot := 0.0
	var alpha := 1.0
	var flash := 0.0
	var t := Time.get_ticks_msec() / 1000.0
	if bob and not dead:
		off.y -= bob_amp * (0.5 - 0.5 * cos(t * TAU / bob_period))
	if _anim != "":
		var p := _anim_t / _anim_len
		match _anim:
			"hurt", "hit":
				flash = 1.0 - p if p < 0.5 else 0.0
				off.x += (10.0 if p < 0.2 else (-8.0 if p < 0.5 else 0.0)) * (1.0 - p)
			"attack":
				var s := sin(p * PI)
				scl *= 1.0 + 0.18 * s
				off += Vector2(-30, 10) * s
			"cheer":
				var c := sin(p * PI)
				off.y -= 16 * c
				rot -= deg_to_rad(3) * c
	if dead:
		var e := _die_t
		flash = 1.0 - e / 0.3 if e < 0.3 else 0.0
		var m := clampf((e - 0.3) / 0.7, 0.0, 1.0)
		scl *= lerpf(1.0, 0.4, m)
		off.y += 120 * m
		rot += deg_to_rad(18) * m
		alpha = 1.0 - m
	var center := size / 2.0 + off
	draw_set_transform(center, rot, Vector2(scl, scl))
	var rect := Rect2(-dsz / 2.0, dsz)
	draw_texture_rect(texture, rect, false, Color(1, 1, 1, alpha))
	if flash > 0.0:
		draw_texture_rect(texture, rect, false, Color(2, 2, 2, flash * 0.6 * alpha))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
