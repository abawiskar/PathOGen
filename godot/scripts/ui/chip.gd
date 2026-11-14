## Draws a Grasshopper component "chip" (body, ports, letters, icon) onto any CanvasItem.
## Port of chip() in web/js/game.js.
class_name Chip
extends RefCounted

const ROW := 13.0
const BODY := Color("f3f3ee")
const EDGE := Color("2b2f2e")
const DIV := Color("9aa29f")
const PORT := Color("222222")
const HL := Color("e6c35a")
const HL_TEXT := Color("b3402e")
const ICON := "#2f6d52"


static func chip_size(comp: Dictionary, w := 0.0) -> Vector2:
	if comp.id == "slider":
		return Vector2(108, 22)
	var rows := maxi(maxi(comp.ins.size(), comp.outs.size()), 1)
	return Vector2(w if w > 0 else 92.0, maxf(rows * ROW + 12.0, 30.0))


static func _rect(ci: CanvasItem, r: Rect2, fill: Color, edge: Color, radius: float, bw := 1.4) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = edge
	sb.set_border_width_all(int(ceil(bw)))
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, r)


static func _text(ci: CanvasItem, center_x: float, baseline: float, text: String, size: float, color: Color, font: Font = null) -> void:
	var f := font if font else UIKit.sans_bold
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x
	ci.draw_string(f, Vector2(center_x - w / 2.0, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), color)


## opts: w, big, label, value, frac, locked, hl_side ("in"/"out"), hl_idx, alpha
## Returns { ports: { in: [Vector2], out: [Vector2] }, size: Vector2 }.
static func draw(ci: CanvasItem, comp: Dictionary, c: Vector2, opts := {}) -> Dictionary:
	UIKit.init()
	var a: float = opts.get("alpha", 1.0)
	var sz := chip_size(comp, opts.get("w", 0.0))
	var x0 := c.x - sz.x / 2.0
	var y0 := c.y - sz.y / 2.0
	var ports := {"in": [], "out": []}
	var locked: bool = opts.get("locked", false)
	if comp.id == "slider":
		var val: String = Geo.fmt(opts.value) if opts.get("value") != null else ""
		var lbl: String = "???" if locked else str(opts.get("label", "Slider"))
		var knob: float = x0 + 48 + float(opts.frac) * 34 if opts.get("frac") != null else x0 + 64
		ports.out.append(Vector2(x0 + sz.x, c.y))
		_rect(ci, Rect2(x0, y0, sz.x, sz.y), Color(BODY, a), Color(EDGE, a), 4)
		ci.draw_string(UIKit.sans_bold, Vector2(x0 + 6, c.y + 3.5), lbl.substr(0, 8), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.2, 0.2, 0.2, a))
		ci.draw_line(Vector2(x0 + 48, c.y), Vector2(x0 + 82, c.y), Color(Color("7a827f"), a), 1.5, true)
		ci.draw_rect(Rect2(knob - 2.5, c.y - 5, 5, 10), Color(Color(ICON), a))
		var vw := UIKit.sans_bold.get_string_size(val, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		ci.draw_string(UIKit.sans_bold, Vector2(x0 + sz.x - 6 - vw, c.y + 3.5), val, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(Color(ICON), a))
		ci.draw_circle(Vector2(x0 + sz.x, c.y), 3.4, Color(PORT, a))
		return {"ports": ports, "size": sz}

	var big: bool = opts.get("big", false)
	var zin := (22.0 if big else 18.0) if comp.ins.size() > 0 else 6.0
	var zout := (22.0 if big else 18.0) if comp.outs.size() > 0 else 6.0
	var fs := 13.0 if big else 10.0
	_rect(ci, Rect2(x0, y0, sz.x, sz.y), Color(BODY, a), Color(EDGE, a), 7 if big else 5)
	if comp.ins.size() > 0:
		ci.draw_line(Vector2(x0 + zin, y0 + 3), Vector2(x0 + zin, y0 + sz.y - 3), Color(DIV, a), 1.0)
	if comp.outs.size() > 0:
		ci.draw_line(Vector2(x0 + sz.x - zout, y0 + 3), Vector2(x0 + sz.x - zout, y0 + sz.y - 3), Color(DIV, a), 1.0)
	var port_y := func(i: int, n: int) -> float: return y0 + 6 + (i + 0.5) * (sz.y - 12) / n
	for side in ["in", "out"]:
		var list: Array = comp.ins if side == "in" else comp.outs
		for i in list.size():
			var y: float = port_y.call(i, list.size())
			var hl: bool = opts.get("hl_side") == side and opts.get("hl_idx") == i
			var px := x0 if side == "in" else x0 + sz.x
			var tx := x0 + zin / 2.0 if side == "in" else x0 + sz.x - zout / 2.0
			ports[side].append(Vector2(px, y))
			_text(ci, tx, y + fs * 0.36, "?" if locked else str(list[i][0]), fs, Color(HL_TEXT if hl else Color("222222"), a), UIKit.sans_xbold if hl else UIKit.sans_bold)
			var r := 5.0 if hl else (4.0 if big else 3.2)
			if hl:
				ci.draw_circle(Vector2(px, y), r + 1.0, Color(PORT, a))
			ci.draw_circle(Vector2(px, y), r, Color(HL if hl else PORT, a))
	var isz := minf(30.0 if big else 20.0, sz.y - 8)
	var mid := x0 + zin + (sz.x - zin - zout) / 2.0
	if locked:
		_text(ci, mid, c.y + 6, "?", 16, Color(Color("8a2a36"), a), UIKit.sans_xbold)
	else:
		var tex := UIKit.comp_icon(comp.id, int(isz * 2))
		if tex:
			ci.draw_texture_rect(tex, Rect2(mid - isz / 2.0, c.y - isz / 2.0, isz, isz), false, Color(1, 1, 1, a))
	return {"ports": ports, "size": sz}
