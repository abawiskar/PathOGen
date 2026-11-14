## Small drawn widgets: hearts row, red damage flash, timer pill, dashed box, map path.
class_name FxViews
extends RefCounted


class Hearts extends Control:
	var health := 4
	var max_health := 4
	var shielded := false
	var _lost := {}   # index -> start time

	func set_state(h: int, m: int, shield: bool) -> void:
		for i in range(h, mini(health, m)):
			_lost[i] = Time.get_ticks_msec() / 1000.0
		health = h
		max_health = m
		shielded = shield
		queue_redraw()

	func _process(_d: float) -> void:
		if not _lost.is_empty():
			queue_redraw()

	func _draw() -> void:
		var w := 72.0 if max_health > 4 else 92.0
		var heart_full := UIKit.svg_texture("res://art/heart.svg", 2.0, "#f5e3d0")
		var heart_empty := UIKit.svg_texture("res://art/heart.svg", 2.0, "#26302e")
		var now := Time.get_ticks_msec() / 1000.0
		for i in max_health:
			var full := i < health
			var r := Rect2(18 + i * (w + 8), 10, w, 76)
			var s := 1.0
			if _lost.has(i):
				var p: float = (now - _lost[i]) / 0.6
				if p >= 1.0:
					_lost.erase(i)
				else:
					s = 1.0 + 0.15 * sin(p * PI)
			draw_set_transform(r.get_center(), 0, Vector2(s, s))
			var rr := Rect2(-r.size / 2, r.size)
			var sb := UIKit.box(Color("bf6a6c") if full else Color("424d4a"), Color("d9c9a0") if full else Color("66736f"), 3, 2)
			draw_style_box(sb, rr)
			if full:
				draw_circle(Vector2(0, -6), 26, Color(0.88, 0.6, 0.59, 0.55))
			var tex := heart_full if full else heart_empty
			if tex:
				draw_texture_rect(tex, Rect2(-20, -18, 40, 36), false)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		if shielded:
			var sb2 := UIKit.box(Color(0, 0, 0, 0), Color("8fd0e6"), 6, 2)
			sb2.shadow_color = Color(0.56, 0.82, 0.9, 0.5)
			sb2.shadow_size = 12
			draw_style_box(sb2, Rect2(12, 4, max_health * (w + 8) + 4, 90))


class Flash extends Control:
	var _t := -1.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func play() -> void:
		_t = 0.0

	func _process(delta: float) -> void:
		if _t >= 0:
			_t += delta
			if _t > 0.5:
				_t = -1.0
			queue_redraw()

	func _draw() -> void:
		if _t < 0:
			return
		var p := _t / 0.5
		var a := (p / 0.3) if p < 0.3 else (1.0 - (p - 0.3) / 0.7)
		var c := Color(0.77, 0.16, 0.2, 0.55 * a)
		var z := Color(0.77, 0.16, 0.2, 0)
		var w := size.x
		var h := size.y
		var d := 150.0
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w - d, d), Vector2(d, d)]), PackedColorArray([c, c, z, z]))
		draw_polygon(PackedVector2Array([Vector2(0, h), Vector2(w, h), Vector2(w - d, h - d), Vector2(d, h - d)]), PackedColorArray([c, c, z, z]))
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(0, h), Vector2(d, h - d), Vector2(d, d)]), PackedColorArray([c, c, z, z]))
		draw_polygon(PackedVector2Array([Vector2(w, 0), Vector2(w, h), Vector2(w - d, h - d), Vector2(w - d, d)]), PackedColorArray([c, c, z, z]))


class TimerPill extends Control:
	var left := 0.0
	var total := 1.0

	func _draw() -> void:
		var sb := UIKit.box(Color(0.157, 0.063, 0.078, 0.86), UIKit.RED, 20, 1)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var bar := Rect2(12, size.y / 2 - 3, 110, 6)
		draw_rect(bar, Color(1, 1, 1, 0.15))
		var f := clampf(left / total, 0, 1)
		draw_polygon(PackedVector2Array([bar.position, bar.position + Vector2(bar.size.x * f, 0), bar.position + Vector2(bar.size.x * f, 6), bar.position + Vector2(0, 6)]),
			PackedColorArray([UIKit.STAR, UIKit.RED, UIKit.RED, UIKit.STAR]))
		var txt := str(ceili(maxf(0, left)))
		draw_string(UIKit.serif, Vector2(size.x - 34, size.y / 2 + 6), txt, HORIZONTAL_ALIGNMENT_RIGHT, 24, 16, Color("f3d6d6"))


class DashedBox extends Control:
	func _draw() -> void:
		var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
		for i in range(1, pts.size()):
			var a: Vector2 = pts[i - 1]
			var b: Vector2 = pts[i]
			var n := int(a.distance_to(b) / 9.0)
			for k in n:
				draw_line(a.lerp(b, float(k) / n), a.lerp(b, (k + 0.55) / n), UIKit.LINE, 2.0)


class MapPath extends Control:
	var points: Array = []

	func _draw() -> void:
		if points.size() < 2:
			return
		var line := PackedVector2Array([points[0]])
		for i in range(1, points.size()):
			var a: Vector2 = points[i - 1]
			var b: Vector2 = points[i]
			var c := Vector2((a.x + b.x) / 2 + (0 if i % 2 else 40), (a.y + b.y) / 2 + (60 if i % 2 else -40))
			for s in range(1, 21):
				var t := s / 20.0
				line.append((1 - t) * (1 - t) * a + 2 * (1 - t) * t * c + t * t * b)
		draw_polyline(line, UIKit.LINE, 10, true)
		var acc := 0.0
		for i in range(1, line.size()):
			var seg := line[i - 1].distance_to(line[i])
			var k := acc
			while k < acc + seg:
				if fmod(k, 14.0) < 2.0:
					draw_circle(line[i - 1].lerp(line[i], (k - acc) / seg), 1.4, Color(UIKit.SAGE, 0.7))
				k += 2.0
			acc += seg
