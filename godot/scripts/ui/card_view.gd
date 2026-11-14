## A component card (or a port card during a wire check). Port of cardHTML() in web/js/game.js.
class_name CardView
extends Control

signal clicked(card_id: String)

var card_id := ""
var battle: Battle
var featured := false
var is_selected := false
var hovered := false

const CURSE := Color("8f2f3a")


func setup(id: String, b: Battle, is_featured := false) -> CardView:
	card_id = id
	battle = b
	featured = is_featured
	size = Vector2(210, 204) if featured else Vector2(196, 226)
	pivot_offset = Vector2(size.x / 2, size.y)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func(): hovered = true; _hover_changed())
	mouse_exited.connect(func(): hovered = false; _hover_changed())
	return self


func _hover_changed() -> void:
	if has_meta("hover_cb"):
		get_meta("hover_cb").call(self)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(card_id)
		accept_event()


func _text_c(text: String, y: float, fs: int, col: Color, font: Font, blur := false) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := (size.x - w) / 2.0
	if blur:
		for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2), Vector2(-1, 1), Vector2(1, -1)]:
			draw_string(font, Vector2(x, y) + o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, 0.16))
		return
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw() -> void:
	if battle == null or card_id == "":
		return
	UIKit.init()
	var r := Rect2(Vector2.ZERO, size)
	# glow when selected / featured
	if is_selected or featured:
		var g := UIKit.box(Color(0, 0, 0, 0), Color("b7d79d") if featured else UIKit.SAGE, 9, 3)
		g.shadow_color = Color(0.66, 0.78, 0.56, 0.55)
		g.shadow_size = 18
		draw_style_box(g, r.grow(3))
	var cursed: bool = battle.effects.icon > 0
	var body := UIKit.box(UIKit.PARCH, CURSE if cursed else Color("8a8064"), 6, 2, 10)
	draw_style_box(body, r)
	draw_rect(Rect2(2, 2, size.x - 4, size.y * 0.55), Color(1, 1, 1, 0.08))
	draw_rect(Rect2(2, size.y - 11, size.x - 4, 9), UIKit.SAGE_DEEP)
	draw_rect(Rect2(2, size.y - 11, size.x - 4, 3), Color("8fb79a"))

	var d = battle.cur()
	var icon_curse: bool = battle.effects.icon > 0
	var blur: bool = battle.effects.blur > 0
	var port := card_id.begins_with("port:")
	var comp: Dictionary
	var cat: String
	var tier: String
	var name: String
	var desc: String
	var chip_opts := {"w": 150.0, "big": true}
	if port:
		if d == null or d.kind != "quiz":
			return
		comp = GHData.comp(battle.node_by_id(d.quiz.target).comp)
		var idx := int(card_id.split(":")[1])
		var p: Array = battle.port_of(d, card_id)
		cat = "WIRE · %s" % ("INPUT" if d.quiz.side == "in" else "OUTPUT")
		tier = str(p[0])
		name = "%s · %s" % [p[0], p[1]]
		desc = "%s %s." % ["Expects" if d.quiz.side == "in" else "Carries", p[2]]
		chip_opts.hl_side = d.quiz.side
		chip_opts.hl_idx = idx
	else:
		comp = GHData.comp(card_id)
		cat = str(comp.cat).to_upper()
		tier = str(int(comp.get("tier", 1)))
		name = comp.name
		desc = comp.desc if battle.L.guidance != "independent" else "Read the icon and ports."
		if comp.id == "slider":
			chip_opts.label = "Slider"
			chip_opts.value = 5
			chip_opts.frac = 0.5

	var top := 9.0 if featured else 10.0
	if not icon_curse:
		draw_string(UIKit.sans_bold, Vector2(12, top + 11), cat, HORIZONTAL_ALIGNMENT_LEFT, size.x - 52, 9, Color("5b5a4c"))
	# tier badge
	var tc := Vector2(size.x - 22, top + 13)
	draw_circle(tc, 13, Color("c8bf9f"))
	draw_circle(tc, 11, Color("253331"))
	var tw := UIKit.serif.get_string_size(tier, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(UIKit.serif, Vector2(tc.x - tw / 2, tc.y + 5), tier, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f4ecd6"))
	# name tag with pointer
	var tag_y := top + 30.0
	if not icon_curse:
		var tag_fs := 15
		var tagw := minf(170.0, UIKit.sans.get_string_size(comp.name, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_fs).x + 16)
		var tag := Rect2((size.x - tagw) / 2, tag_y, tagw, 22)
		draw_rect(tag, Color.WHITE)
		draw_rect(tag, Color("333333"), false, 1.5)
		var tip := Vector2(size.x / 2, tag.end.y + 6)
		draw_colored_polygon(PackedVector2Array([tip, Vector2(tip.x - 6, tag.end.y - 0.5), Vector2(tip.x + 6, tag.end.y - 0.5)]), Color.WHITE)
		draw_polyline(PackedVector2Array([Vector2(tip.x - 6, tag.end.y), tip, Vector2(tip.x + 6, tag.end.y)]), Color("333333"), 1.5)
		if blur:
			_text_c(comp.name, tag.position.y + 17, tag_fs, Color("111111"), UIKit.sans, true)
		else:
			draw_string(UIKit.sans, Vector2(tag.position.x + 8, tag.position.y + 17), comp.name, HORIZONTAL_ALIGNMENT_LEFT, tagw - 12, tag_fs, Color("111111"))
	# the chip itself
	var chip_h := Chip.chip_size(comp, 150).y
	var chip_c := Vector2(size.x / 2, tag_y + 34 + chip_h / 2)
	Chip.draw(self, comp, chip_c, chip_opts)
	# name + description
	var ny := chip_c.y + chip_h / 2 + 26
	if not icon_curse:
		var nfs := 18 if port else 19
		if featured:
			nfs = 17
		_text_c(name, ny, nfs, Color("3a3a30"), UIKit.serif, blur)
		var dfs := 11
		var dy := ny + 8
		var italic: bool = not port and battle.L.guidance == "independent"
		draw_multiline_string(UIKit.sans, Vector2(14, dy + dfs), desc, HORIZONTAL_ALIGNMENT_CENTER, size.x - 28, dfs, 3, Color("555244") if not italic else Color("6d6a5a"))
	if icon_curse:
		_curse_note(int(battle.effects.icon))


## "✦ Icon Curse / name hidden · N more" in a dashed red box, so the empty card explains itself.
func _curse_note(n: int) -> void:
	var r := Rect2(10, size.y - 22 - 40, size.x - 20, 40)
	draw_rect(r, Color(CURSE, 0.08))
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position])
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var L := a.distance_to(b)
		var t := 0.0
		while t < L:
			draw_line(a.lerp(b, t / L), a.lerp(b, minf(t + 4.0, L) / L), CURSE, 1.5)
			t += 7.0
	var title := "Icon Curse"
	var fs := 14
	var tw := UIKit.serif.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var sw := UIKit.sans_bold.get_string_size("✦ ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := (size.x - tw - sw) / 2.0
	draw_string(UIKit.sans_bold, Vector2(x, r.position.y + 18), "✦ ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, CURSE)
	draw_string(UIKit.serif, Vector2(x + sw, r.position.y + 18), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, CURSE)
	_text_c("NAME HIDDEN · %d MORE" % n, r.position.y + 33, 10, Color(CURSE, 0.85), UIKit.sans_bold)
