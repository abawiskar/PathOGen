## Wireframe 3D viewport, ported from the Preview class in web/js/preview.js.
## Drag to orbit, scroll to zoom, double-click to reset.
class_name PreviewView
extends Control

var theta := -0.95
var el := 0.55
var goal_theta := -0.95
var goal_el := 0.55
var target := Vector3.ZERO
var goal_target := Vector3.ZERO
var radius := 8.0
var goal_radius := 8.0
var zoom := 1.0
var view := "perspective"
var auto := true
var scene := {"lines": [], "points": [], "labels": [], "arrows": []}
var bbox = null
var fresh := ""
var fresh_t := 0.0
var blurred := false
var _drag = null
var _auto_at := -1.0
## A still render (the goal thumbnail): no input, no camera easing.
var static_mode := false


func _ready() -> void:
	clip_contents = true
	if static_mode:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG


## Like Preview.snapshot in preview.js: the default 3/4 view, framed, held still.
func snapshot(s: Dictionary) -> void:
	static_mode = true
	set_scene(s)
	theta = -0.95
	goal_theta = theta
	el = 0.5
	goal_el = el
	auto = false
	target = goal_target
	radius = goal_radius
	zoom = 1.25
	queue_redraw()


func set_view(v: String, keep_angles := false) -> void:
	view = v
	if v == "top":
		goal_el = 1.5699
		goal_theta = -PI / 2
		auto = false
	elif v == "front":
		goal_el = 0.02
		goal_theta = -PI / 2
		auto = false
	elif not keep_angles:
		goal_el = 0.55
		goal_theta = -0.95
		auto = true


func set_scene(s: Dictionary, fresh_key := "") -> void:
	scene = s
	var all: Array = []
	for l in s.lines:
		all.append_array(l.pts)
	for p in s.points:
		all.append(p.p)
	for a in s.arrows:
		all.append(a.from)
		all.append(a.to)
	for lb in s.labels:
		all.append(lb.p)
	var mn := Vector3(INF, INF, INF)
	var mx := Vector3(-INF, -INF, -INF)
	for p in all:
		mn = mn.min(p)
		mx = mx.max(p)
	if not all.is_empty():
		bbox = [mn, mx]
		goal_target = (mn + mx) / 2.0
		goal_radius = maxf(4.0, (mx - mn).length() / 2.0)
	else:
		bbox = null
		goal_target = Vector3.ZERO
		goal_radius = 6.0
	if fresh_key != "":
		fresh = fresh_key
		fresh_t = Time.get_ticks_msec() / 1000.0


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.double_click:
				zoom = 1.0
				auto = true
			elif e.pressed:
				_drag = e.position
				auto = false
			else:
				_drag = null
				_auto_at = Time.get_ticks_msec() / 1000.0 + 4.0
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = clampf(zoom * 0.9, 0.35, 3.0)
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = clampf(zoom * 1.1, 0.35, 3.0)
	elif e is InputEventMouseMotion and _drag != null:
		var dd: Vector2 = e.position - _drag
		_drag = e.position
		if view != "perspective":
			set_view("perspective", true)
		goal_theta -= dd.x * 0.008
		goal_el = clampf(goal_el + dd.y * 0.008, -0.2, 1.5)
		theta = goal_theta
		el = goal_el


func _process(_d: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if _auto_at > 0 and now > _auto_at:
		_auto_at = -1.0
		if view == "perspective":
			auto = true
	var k := 0.12
	if auto:
		goal_theta += 0.0016
	theta += (goal_theta - theta) * k
	el += (goal_el - el) * k
	radius += (goal_radius - radius) * k
	target += (goal_target - target) * k
	queue_redraw()


func _camera() -> Dictionary:
	var dist := radius * 2.9 * zoom
	var pos := target + Vector3(dist * cos(el) * cos(theta), dist * cos(el) * sin(theta), dist * sin(el))
	var f := (target - pos).normalized()
	var r := f.cross(Vector3(0, 0, 1))
	if r.length() < 1e-6:
		r = Vector3(1, 0, 0)
	r = r.normalized()
	var u := r.cross(f)
	return {"pos": pos, "f": f, "r": r, "u": u, "fl": (size.y / 2.0) / tan(0.375)}


func _project(p: Vector3, cam: Dictionary):
	var rel: Vector3 = p - cam.pos
	var z := rel.dot(cam.f)
	if z < 0.05:
		return null
	return Vector2(size.x / 2 + rel.dot(cam.r) * cam.fl / z, size.y / 2 - rel.dot(cam.u) * cam.fl / z)


func _seg(a: Vector3, b: Vector3, cam: Dictionary, col: Color, w := 1.0) -> void:
	var p = _project(a, cam)
	var q = _project(b, cam)
	if p != null and q != null:
		draw_line(p, q, col, w, true)


static func _nice_step(x: float) -> float:
	var p := pow(10.0, floor(log(x) / log(10.0)))
	var m := x / p
	return (1.0 if m < 1.5 else (2.0 if m < 3.5 else (5.0 if m < 7.5 else 10.0))) * p


func _polyline(pts: Array, closed: bool, cam: Dictionary, col: Color, w: float) -> void:
	var run := PackedVector2Array()
	var all := pts + [pts[0]] if closed else pts
	for p in all:
		var q = _project(p, cam)
		if q == null:
			if run.size() > 1:
				draw_polyline(run, col, w, true)
			run = PackedVector2Array()
			continue
		run.append(q)
	if run.size() > 1:
		draw_polyline(run, col, w, true)


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([Color("c9d1d3"), Color("c9d1d3"), Color("a9b4b7"), Color("a9b4b7")]))
	var cam := _camera()
	# ground grid on z = 0
	var step := _nice_step(radius / 3.0)
	var ext := ceilf(radius * 1.8 / step) * step
	var cx := roundf(target.x / step) * step
	var cy := roundf(target.y / step) * step
	var i := -ext
	while i <= ext + 1e-9:
		var major := int(absf(roundf((cx + i) / step))) % 5 == 0
		var gc := Color(1, 1, 1, 0.42 if major else 0.22)
		_seg(Vector3(cx + i, cy - ext, 0), Vector3(cx + i, cy + ext, 0), cam, gc)
		_seg(Vector3(cx - ext, cy + i, 0), Vector3(cx + ext, cy + i, 0), cam, gc)
		i += step
	_seg(Vector3.ZERO, Vector3(ext * 0.35, 0, 0), cam, Color(0.667, 0.235, 0.235, 0.55), 1.4)
	_seg(Vector3.ZERO, Vector3(0, ext * 0.35, 0), cam, Color(0.235, 0.549, 0.314, 0.55), 1.4)
	# faint bounding box
	if bbox != null and not scene.lines.is_empty():
		var pad := radius * 0.18
		var a: Vector3 = bbox[0] - Vector3(pad, pad, pad)
		var b: Vector3 = bbox[1] + Vector3(pad, pad, pad)
		var C := [Vector3(a.x, a.y, a.z), Vector3(b.x, a.y, a.z), Vector3(b.x, b.y, a.z), Vector3(a.x, b.y, a.z),
			Vector3(a.x, a.y, b.z), Vector3(b.x, a.y, b.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z)]
		for e in [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7]]:
			_seg(C[e[0]], C[e[1]], cam, Color(0.745, 0.314, 0.373, 0.28))
	var age := Time.get_ticks_msec() / 1000.0 - fresh_t
	var glow := 1.0 - maxf(0.0, age - 2.2) if fresh != "" and age < 3.2 else 0.0
	var is_fresh := func(k) -> bool: return glow > 0 and k == fresh
	var passes := [[3.2, 0.18], [1.0, 0.55]] if blurred else [[0.0, 1.0]]
	for ps in passes:
		for l in scene.lines:
			var fr: bool = is_fresh.call(l.k)
			var col: Color = Color(0.122, 0.588, 0.353, 0.55 + 0.45 * glow) if fr else l.get("color", Color(0.769, 0.173, 0.259, 0.9))
			var lw: float = (l.w if l.get("w") != null else 1.35) + (1.2 * glow if fr else 0.0) + ps[0]
			col.a *= ps[1]
			_polyline(l.pts, l.get("closed", false), cam, col, lw)
		for ar in scene.arrows:
			var p = _project(ar.from, cam)
			var q = _project(ar.to, cam)
			if p == null or q == null:
				continue
			var fr2: bool = is_fresh.call(ar.k)
			var c2 := Color("1f965a") if fr2 else Color("2f5f8a")
			c2.a *= ps[1]
			draw_line(p, q, c2, (2.4 if fr2 else 1.6) + ps[0], true)
			var ang := (q - p).angle()
			draw_colored_polygon(PackedVector2Array([q, q - Vector2.from_angle(ang - 0.4) * 9, q - Vector2.from_angle(ang + 0.4) * 9]), c2)
		for pt in scene.points:
			var q2 = _project(pt.p, cam)
			if q2 == null:
				continue
			var fr3: bool = is_fresh.call(pt.k)
			var s := 3.4 + (1.2 if fr3 else 0.0)
			var c3 := Color("1f965a") if fr3 else Color("8a1a2c")
			c3.a *= ps[1]
			draw_line(q2 - Vector2(s, s), q2 + Vector2(s, s), c3, (2.0 if fr3 else 1.6) + ps[0], true)
			draw_line(q2 + Vector2(s, -s), q2 + Vector2(-s, s), c3, (2.0 if fr3 else 1.6) + ps[0], true)
	if blurred:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.75, 0.78, 0.8, 0.35))
	for lb in scene.labels:
		var q3 = _project(lb.p, cam)
		if q3 == null:
			continue
		var tw := UIKit.sans_bold.get_string_size(lb.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_rect(Rect2(q3.x + 6, q3.y - 16, tw + 10, 17), Color(1, 1, 1, 0.78))
		draw_string(UIKit.sans_bold, Vector2(q3.x + 11, q3.y - 4), lb.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("14774a") if is_fresh.call(lb.k) else Color("2a3436"))
