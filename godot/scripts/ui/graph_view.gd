## The definition canvas: placed components, open slots, wires and wire checks.
## Port of renderGraph() in web/js/game.js. Graph units are scaled to fit a 540 x 262 view.
class_name GraphView
extends Control

signal place_requested

const VW := 540.0
const VH := 262.0

var battle: Battle
var _origin := Vector2.ZERO   # graph-space top-left of the view
var _scale := 1.0
var _cur_center := Vector2.INF
var _cur_rect := Rect2()
var _pannable := false
var _drag = null


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(_d: float) -> void:
	if battle and battle.cur() != null:
		queue_redraw()   # halo pulse and marching wire dashes


func _to_screen(p: Vector2) -> Vector2:
	return (p - _origin) * _scale


func _gui_input(e: InputEvent) -> void:
	if battle == null:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			var gp: Vector2 = e.position / _scale + _origin
			if _cur_center != Vector2.INF and _cur_rect.grow(6).has_point(gp):
				place_requested.emit()
				return
			if _pannable:
				_drag = e.position
		else:
			_drag = null
	elif e is InputEventMouseMotion and _drag != null:
		battle.pan -= (e.position - _drag) / _scale
		_drag = e.position
		queue_redraw()
	if e is InputEventMouseMotion:
		var gp2: Vector2 = e.position / _scale + _origin
		var over_cur := _cur_center != Vector2.INF and _cur_rect.grow(6).has_point(gp2)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if over_cur else (Control.CURSOR_DRAG if _pannable else Control.CURSOR_ARROW)


static func _bezier(a: Vector2, b: Vector2) -> PackedVector2Array:
	var dx := maxf(24.0, absf(b.x - a.x) * 0.5)
	var c1 := a + Vector2(dx, 0)
	var c2 := b - Vector2(dx, 0)
	var pts := PackedVector2Array()
	for i in 25:
		var t := i / 24.0
		var u := 1.0 - t
		pts.append(u * u * u * a + 3 * u * u * t * c1 + 3 * u * t * t * c2 + t * t * t * b)
	return pts


func _dashed(pts: PackedVector2Array, color: Color, width: float, dash: float, gap: float, offset := 0.0) -> void:
	var pos := -fmod(offset, dash + gap)
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var seg := a.distance_to(b)
		var t := 0.0
		while t < seg:
			var phase := fmod(pos + t + (dash + gap) * 10.0, dash + gap)
			if phase < dash:
				var run := minf(dash - phase, seg - t)
				draw_line(a.lerp(b, t / seg), a.lerp(b, (t + run) / seg), color, width, true)
				t += run
			else:
				t += (dash + gap) - phase
		pos += seg


func _draw() -> void:
	if battle == null:
		return
	var L := battle.L
	var d = battle.cur()
	_scale = size.x / VW
	var vh := size.y / _scale
	var slot_num := {}
	for i in L.steps.size():
		slot_num[L.steps[i].key] = i + 1
	var locked_id = battle.effects.locked.node if battle.effects.locked != null else null
	var blur: bool = battle.effects.blur > 0
	var geo := {}
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for n in L.nodes:
		var comp := GHData.comp(n.comp)
		var sz := Chip.chip_size(comp)
		geo[n.id] = {"n": n, "comp": comp, "size": sz, "placed": battle.is_placed(n)}
		var p := Vector2(n.x, n.y)
		mn = mn.min(p - Vector2(sz.x / 2, maxf(sz.y / 2, 24)))
		mx = mx.max(p + Vector2(sz.x / 2, maxf(sz.y / 2, 24) + 26))
	var quiz_cur = d.quiz if d != null and d.kind == "quiz" else null
	var sel_port = int(str(battle.selected).split(":")[1]) if quiz_cur != null and battle.selected != null else null

	# view: fixed zoom centred on the active node; drag to pan
	var pad := 18.0
	var focus = null
	if d != null:
		focus = battle.node_by_id(d.step.key) if d.kind == "comp" else battle.node_by_id(d.quiz.target)
	var b0 := mn - Vector2(pad, pad)
	var b1 := mx + Vector2(pad, pad)
	var base := Vector2(focus.x, focus.y) if focus != null else (b0 + b1) / 2.0
	var f := base + battle.pan
	f.x = (b0.x + b1.x) / 2.0 if b1.x - b0.x <= VW else clampf(f.x, b0.x + VW / 2, b1.x - VW / 2)
	f.y = (b0.y + b1.y) / 2.0 if b1.y - b0.y <= vh else clampf(f.y, b0.y + vh / 2, b1.y - vh / 2)
	battle.pan = f - base
	_pannable = b1.x - b0.x > VW or b1.y - b0.y > vh
	_origin = f - Vector2(VW / 2, vh / 2)
	draw_set_transform(-_origin * _scale, 0, Vector2(_scale, _scale))

	var t := Time.get_ticks_msec() / 1000.0
	var a_nodes := 0.55 if blur else 1.0
	# ports for wires (computed while drawing nodes, so draw nodes to a list first)
	_cur_center = Vector2.INF
	for id in geo:
		var g: Dictionary = geo[id]
		var n: Dictionary = g.n
		var pos := Vector2(n.x, n.y)
		var x0: float = pos.x - g.size.x / 2
		var y0: float = pos.y - g.size.y / 2
		var rows: float = g.size.y
		if g.placed:
			var ports := {"in": [], "out": []}
			if g.comp.id == "slider":
				ports.out.append(Vector2(x0 + g.size.x, pos.y))
			else:
				for i in g.comp.ins.size():
					ports.in.append(Vector2(x0, y0 + 6 + (i + 0.5) * (rows - 12) / g.comp.ins.size()))
				for i in g.comp.outs.size():
					ports.out.append(Vector2(x0 + g.size.x, y0 + 6 + (i + 0.5) * (rows - 12) / g.comp.outs.size()))
			g.ports = ports
		else:
			# empty slot: same size and port layout as the real component (game.js ghost node)
			var gin := []
			var gout := []
			var ni: int = g.comp.ins.size()
			var no: int = g.comp.outs.size()
			for i in ni:
				gin.append(Vector2(x0, y0 + 6 + (i + 0.5) * (rows - 12) / ni))
			for i in no:
				gout.append(Vector2(x0 + g.size.x, y0 + 6 + (i + 0.5) * (rows - 12) / no))
			g.ports = {"in": gin, "out": gout}

	# wires
	var wire_col := Color("d9e6d4")
	for w in L.wires:
		var A: Dictionary = geo[w.from[0]]
		var B: Dictionary = geo[w.to[0]]
		var a: Vector2 = A.ports.out[w.from[1]] if w.from[1] < A.ports.out.size() else Vector2(A.n.x, A.n.y)
		var b: Vector2 = B.ports.in[w.to[1]] if w.to[1] < B.ports.in.size() else Vector2(B.n.x, B.n.y)
		if not (A.placed and B.placed):
			_dashed(_bezier(a, b), Color(Color("9fb3aa"), 0.55), 1.4, 4, 5)
			continue
		if w.quiz != null and not battle.done.has(w.quiz):
			var is_cur: bool = quiz_cur != null and quiz_cur.key == w.quiz
			var unknown_in: bool = w.check == null or w.check.get("side") != "out"
			if unknown_in:
				b = B.ports.in[sel_port] if is_cur and sel_port != null else Vector2(B.n.x - B.size.x / 2 - 16, B.n.y)
			else:
				a = A.ports.out[sel_port] if is_cur and sel_port != null else Vector2(A.n.x + A.size.x / 2 + 16, A.n.y)
			if is_cur:
				_dashed(_bezier(a, b), UIKit.GOLD, 2.2, 6, 5, t * 22.0)
				if sel_port == null:
					var q := b if unknown_in else a
					draw_circle(q, 7, Color("2a4a3c"))
					draw_arc(q, 7, 0, TAU, 24, UIKit.GOLD, 1.0, true)
					Chip._text(self, q.x, q.y + 3.5, "?", 10, UIKit.GOLD, UIKit.sans_xbold)
			else:
				_dashed(_bezier(a, b), Color(UIKit.GOLD, 0.4), 1.6, 3, 5)
			continue
		draw_polyline(_bezier(a, b), wire_col, 1.8, true)

	# nodes
	for id in geo:
		var g: Dictionary = geo[id]
		var n: Dictionary = g.n
		var comp: Dictionary = g.comp
		var pos := Vector2(n.x, n.y)
		var is_cur: bool = d != null and d.kind == "comp" and d.step.key == n.step
		if g.placed:
			var opts := {"label": n.get("label"), "locked": locked_id == n.id, "alpha": a_nodes}
			if quiz_cur != null and quiz_cur.target == n.id and sel_port != null:
				opts.hl_side = quiz_cur.side
				opts.hl_idx = sel_port
			if n.get("param") == null and n.get("value") != null:
				opts.value = n.value
			if n.get("param") != null:
				opts.value = battle.params.get(n.param)
				for p in L.params:
					if p.key == n.param:
						opts.frac = (float(battle.params[p.key]) - float(p.min)) / (float(p.max) - float(p.min))
			if blur:
				for off in [Vector2(-1.5, 0), Vector2(1.5, 0), Vector2(0, 1.5)]:
					var o2: Dictionary = opts.duplicate()
					o2.alpha = 0.25
					Chip.draw(self, comp, pos + off, o2)
			Chip.draw(self, comp, pos, opts)
			var name := "???" if locked_id == n.id else (str(n.label) if n.get("label") != null and comp.id != "slider" else ("" if comp.id == "slider" else str(comp.name)))
			if name != "":
				Chip._text(self, pos.x, pos.y + g.size.y / 2 + 13, name.to_upper(), 9, Color(Color("cfd9cf"), a_nodes), UIKit.sans_bold)
			if quiz_cur != null and quiz_cur.target == n.id:
				var rr := Rect2(pos - g.size / 2 - Vector2(5, 5), g.size + Vector2(10, 10))
				_dashed(PackedVector2Array([rr.position, rr.position + Vector2(rr.size.x, 0), rr.end, rr.position + Vector2(0, rr.size.y), rr.position]), UIKit.GOLD, 1.5, 4, 3)
		else:
			_draw_ghost(g, pos, is_cur, t)
			var y_lab: float = pos.y + g.size.y / 2
			if is_cur:
				_cur_center = pos
				_cur_rect = Rect2(pos - g.size / 2, g.size)
				Chip._text(self, pos.x, y_lab + 14, "NODE %s" % UIKit.pad2(slot_num.get(n.step, 0)), 9, UIKit.GOLD, UIKit.sans_bold)
				draw_line(Vector2(pos.x - 26, y_lab + 19), Vector2(pos.x + 26, y_lab + 19), UIKit.GOLD, 1)
				if L.guidance == "guided":
					var need: String = d.step.need
					if need.length() > 44:
						need = need.substr(0, 42) + "…"
					Chip._text(self, pos.x, y_lab + 31, "needs " + need, 9, UIKit.SAGE, UIKit.sans)
			else:
				Chip._text(self, pos.x, y_lab + 13, "OPEN NODE", 9, Color(Color("cfd9cf"), 0.6), UIKit.sans_bold)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	battle.last_placed = null


static func _circle_pts(c: Vector2, r: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 41:
		p.append(c + Vector2.from_angle(i / 40.0 * TAU) * r)
	return p


## Greyed-out node of the component's real size: dashed body, port dots, zone dividers
## and a question mark. The current slot is gold with a pulsing halo (sage once armed).
func _draw_ghost(g: Dictionary, pos: Vector2, is_cur: bool, t: float) -> void:
	var sz: Vector2 = g.size
	var r := Rect2(pos - sz / 2, sz)
	var ni: int = g.comp.ins.size()
	var no: int = g.comp.outs.size()
	var armed: bool = is_cur and battle.selected != null
	var fill := Color(0.784, 0.816, 0.8, 0.16)
	var stroke := Color("8a9a94")
	var sw := 1.4
	var port_col := Color("6f807a")
	var q_col := Color("a9b8b2")
	if is_cur:
		var pulse := 0.5 + 0.5 * sin(t * TAU / 1.6)
		var hr := r.grow(4)
		draw_polyline(_rect_pts(hr), Color(UIKit.GOLD, 0.2 + 0.25 * pulse), 5, true)
		fill = Color(0.659, 0.776, 0.565, 0.28) if armed else Color(0.91, 0.863, 0.69, 0.14)
		stroke = UIKit.SAGE if armed else UIKit.GOLD
		sw = 1.8
		port_col = Color("c9b26a")
		q_col = Color(UIKit.GOLD, 0.65 + 0.35 * sin(t * TAU / 1.2))
	draw_rect(r, fill)
	_dashed(_rect_pts(r), stroke, sw, 4, 3)
	var zin := 18.0 if ni > 0 else 6.0
	var zout := 18.0 if no > 0 else 6.0
	var div := Color(0.627, 0.686, 0.667, 0.4)
	if ni > 0:
		draw_line(Vector2(r.position.x + zin, r.position.y + 4), Vector2(r.position.x + zin, r.end.y - 4), div, 1)
	if no > 0:
		draw_line(Vector2(r.end.x - zout, r.position.y + 4), Vector2(r.end.x - zout, r.end.y - 4), div, 1)
	for p in g.ports.in + g.ports.out:
		draw_circle(p, 3.2, port_col)
	var qs := minf(20.0, sz.y - 6)
	var qx := r.position.x + zin + (sz.x - zin - zout) / 2
	Chip._text(self, qx, pos.y + qs * 0.36, "?", int(qs), q_col, UIKit.serif)


static func _rect_pts(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position])
