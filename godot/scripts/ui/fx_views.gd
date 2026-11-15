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


## Map card: one dot per difficulty (filled when beaten) and "n/N", as .mn-diff in the web css.
class DiffPips extends Control:
	var done: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var x := 5.0
		for d in done:
			if d:
				draw_circle(Vector2(x, 6), 4.5, UIKit.SAGE)
			else:
				draw_arc(Vector2(x, 6), 4.0, 0, TAU, 20, Color("6f8a83"), 1.5, true)
			x += 13.0
		var n := done.filter(func(v): return v).size()
		draw_string(UIKit.sans_bold, Vector2(x + 2, 10), "%d/%d" % [n, done.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIKit.MUTED)


## The flat campaign map (web: js/campaign-map.js): a continent with region lines and a dotted gold
## route between the stages; routes into locked stages are faded.
class CampaignLand extends Control:
	const CONTINENT := "85 330 130 250 220 264 280 190 370 210 405 270 520 245 595 200 690 225 750 190 850 240 960 210 1040 255 1140 205 1190 170 1260 205 1350 190 1435 260 1490 280 1470 355 1520 425 1470 480 1490 550 1410 590 1360 655 1270 640 1200 685 1130 620 1030 660 930 615 850 660 750 620 665 665 585 615 490 645 435 580 335 600 280 550 200 570 165 495 95 465 115 400"
	const REGIONS := ["405 270 380 350 435 410 395 490 435 580", "750 190 710 300 770 385 720 470 750 620",
		"1040 255 990 345 1065 440 1010 530 1030 660", "1260 205 1220 340 1300 445 1230 550 1270 640"]
	var points: Array = []
	var future: Array = []   # per route segment i (into stage i): locked?

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	static func _pts(s: String) -> PackedVector2Array:
		var n := s.split(" ")
		var out := PackedVector2Array()
		for i in range(0, n.size() - 1, 2):
			out.append(Vector2(float(n[i]), float(n[i + 1])))
		return out

	func _draw() -> void:
		var land := _pts(CONTINENT)
		draw_colored_polygon(land, UIKit.PANEL)
		var closed := land.duplicate()
		closed.append(land[0])
		draw_polyline(closed, UIKit.LINE, 3.0, true)
		for r in REGIONS:
			draw_polyline(_pts(r), Color(UIKit.LINE, 0.7), 2.0, true)
		for i in range(1, points.size()):
			var a: Vector2 = points[i - 1]
			var b: Vector2 = points[i]
			var mx := (a.x + b.x) / 2.0
			var col := Color(UIKit.MUTED, 0.4) if (i < future.size() and future[i]) else UIKit.GOLD
			# cubic bezier a -> (mx,a.y) -> (mx,b.y) -> b, drawn as round dots every 18 px
			var prev := a
			var acc := 0.0
			draw_circle(a, 2.5, col)
			for k in range(1, 121):
				var t := k / 120.0
				var u := 1.0 - t
				var p := u * u * u * a + 3 * u * u * t * Vector2(mx, a.y) + 3 * u * t * t * Vector2(mx, b.y) + t * t * t * b
				acc += p.distance_to(prev)
				prev = p
				if acc >= 18.0:
					acc -= 18.0
					draw_circle(p, 2.5, col)


## A numbered round stage marker on the campaign map: gold ring; filled gold with a sage ring when selected;
## a flag when cleared and a lock when locked.
class StageMarker extends Control:
	var number := 1
	var selected := false
	var done := false
	var locked := false

	func _ready() -> void:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _draw() -> void:
		var c := size / 2.0
		var r := size.x / 2.0
		if selected:
			draw_arc(c, r + 9.5, 0, TAU, 64, UIKit.SAGE, 5.0, true)
		draw_circle(c, r, UIKit.GOLD if selected else Color("1a2a28"))
		draw_arc(c, r - 1.5, 0, TAU, 64, UIKit.GOLD, 3.0, true)
		var txt := "%02d" % number
		var fs := 36
		var w := UIKit.sans_bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(UIKit.sans_bold, Vector2(c.x - w / 2.0, c.y + fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("0f1c1a") if selected else UIKit.GOLD)
		if done:
			draw_string(UIKit.sans_bold, Vector2(c.x - 11, 4), "⚑", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UIKit.SAGE)
		if locked:
			# padlock: shackle arc over a small body
			var p := Vector2(c.x + 30, 2)
			draw_arc(p + Vector2(0, -2), 5.5, PI, TAU, 16, UIKit.TEXT, 2.5, true)
			draw_line(p + Vector2(-5.5, -2), p + Vector2(-5.5, 3), UIKit.TEXT, 2.5)
			draw_line(p + Vector2(5.5, -2), p + Vector2(5.5, 3), UIKit.TEXT, 2.5)
			draw_rect(Rect2(p + Vector2(-8, 2), Vector2(16, 12)), UIKit.TEXT)
