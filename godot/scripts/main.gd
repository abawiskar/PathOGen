## PathOGen: title, map and battle screens. Port of web/index.html + web/js/game.js (UI parts).
## The rules live in Battle (scripts/core/battle.gd); this file only draws and routes input.
extends Control

const MAP_POS := [Vector2(250, 270), Vector2(560, 235), Vector2(870, 270), Vector2(1180, 235), Vector2(1390, 430), Vector2(1110, 580), Vector2(790, 610), Vector2(480, 720)]

var levels: Array = []
var load_errors := PackedStringArray()
var battle: Battle
var unlock_all := false

var screens := {}
var modal_layer: Control
var modal_box: VBoxContainer
var modal_panel: PanelContainer
var modal_scroll: ScrollContainer
var modal_on_close = null
var toast_box: VBoxContainer

# battle widgets
var graph: GraphView
var graph_sub: Label
var graph_foot: RichTextLabel
var preview: PreviewView
var view_btn: OptionButton
var params_box: VBoxContainer
var preview_foot: Label
var timer_pill: FxViews.TimerPill
var hp_text: Label
var hearts: FxViews.Hearts
var level_chip: Label
var xp_text: Label
var effects_box: HBoxContainer
var mon_panel: Panel
var mon_name: Label
var mon_sub: Label
var mon_intent: Label
var mon_intent_box: PanelContainer
var mon_hp_text: Label
var mon_hp_fill: ColorRect
var mon_art: ArtView
var featured: Control
var fb_panel: Panel
var fb_head: Label
var fb_count: Label
var fb_title: Label
var fb_body: RichTextLabel
var fb_meta: RichTextLabel
var ls_buttons := {}
var hero: ArtView
var hand_box: Control
var hand_sub: Label
var flash: FxViews.Flash
var health_panel: Panel
var _hand_ids: Array = []
var _cards: Array = []
var _hp_shown := -1.0


func _ready() -> void:
	UIKit.init()
	GHData.ensure_loaded()
	SaveData.ensure_loaded()
	theme = UIKit.make_theme()
	unlock_all = OS.get_cmdline_user_args().has("--all") or OS.get_cmdline_args().has("--all")
	size = Vector2(1600, 900)
	_build_background()
	screens.title = _screen(_build_title)
	screens.map = _screen(_build_map_frame)
	screens.battle = _screen(_build_battle)
	_build_overlays()
	var r := LevelLoader.load_all()
	levels = r.levels
	load_errors = r.errors
	if unlock_all:
		SaveData.unlocked = levels.size()
	show_screen("title")
	if not load_errors.is_empty():
		modal(func(b):
			_m_h2(b, "Some levels couldn't load")
			_m_p(b, "\n".join(load_errors))
			_m_p(b, "[color=#8fa29b]Levels are read from %s. Run tools/sync_from_web.py after pulling web changes.[/color]" % LevelLoader.source_dir)
			_m_actions(b, [["OK", "primary", close_modal]]))


func _process(delta: float) -> void:
	if battle != null and screens.battle.visible:
		battle.tick(delta, modal_layer.visible)
		_render_timer()
		# ease the monster HP bar like the CSS width transition
		var goal := float(battle.hp) / maxf(1.0, battle.hp_max)
		_hp_shown = goal if _hp_shown < 0 else lerpf(_hp_shown, goal, minf(1.0, delta * 6.0))
		mon_hp_fill.size.x = (mon_hp_fill.get_parent() as Control).size.x * _hp_shown


# ═════════════════════ layout helpers ═════════════════════
func _screen(builder: Callable) -> Control:
	var s := Control.new()
	s.size = Vector2(1600, 900)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(s)
	builder.call(s)
	return s


func show_screen(id: String) -> void:
	for k in screens:
		screens[k].visible = k == id


func _build_background() -> void:
	var bg := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color("1b2c2a"))
	g.set_color(1, Color("0c1514"))
	g.add_point(0.7, Color("111c1b"))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.1, 1.1)
	gt.width = 512
	gt.height = 288
	bg.texture = gt
	bg.size = Vector2(1600, 900)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var frame := Panel.new()
	frame.position = Vector2(14, 14)
	frame.size = Vector2(1572, 872)
	frame.add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0), UIKit.LINE_SOFT, 0, 1))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	for p in [Vector2(26, 26), Vector2(1552, 26), Vector2(26, 852), Vector2(1552, 852)]:
		UIKit.label(self, "✦", 22, Color("6d7f6f"), UIKit.sans, p)


# ═════════════════════ title ═════════════════════
func _build_title(s: Control) -> void:
	var mon := ArtView.new()
	mon.position = Vector2(1180, 110)
	mon.size = Vector2(360, 340)
	mon.bob_period = 3.4
	mon.set_texture(UIKit.monster_texture("rootbound"))
	s.add_child(mon)
	var hr := ArtView.new()
	hr.position = Vector2(80, 520)
	hr.size = Vector2(330, 340)
	hr.bob = false
	hr.set_texture(UIKit.hero_texture())
	s.add_child(hr)
	var logo := RichTextLabel.new()
	logo.bbcode_enabled = true
	logo.fit_content = true
	logo.scroll_active = false
	logo.autowrap_mode = TextServer.AUTOWRAP_OFF
	logo.add_theme_font_override("normal_font", UIKit.serif)
	logo.add_theme_font_size_override("normal_font_size", 128)
	logo.add_theme_color_override("default_color", UIKit.GOLD)
	logo.add_theme_constant_override("shadow_offset_y", 6)
	logo.add_theme_color_override("font_shadow_color", Color("0b1312"))
	logo.text = "[center]Path[color=#a8c690]O[/color]Gen[/center]"
	logo.position = Vector2(0, 250)
	logo.size = Vector2(1600, 170)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(logo)
	var tag := UIKit.label(s, "Build the Script. Survive the Monster. Master Grasshopper.", 22, UIKit.GOLD_DIM, UIKit.serif, Vector2(0, 430))
	tag.size.x = 1600
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.position = Vector2(0, 500)
	row.size = Vector2(1600, 60)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	s.add_child(row)
	var start := UIKit.button("Begin the Hunt", "primary")
	start.pressed.connect(func(): open_map() if not levels.is_empty() else toast("No levels loaded", "bad"))
	row.add_child(start)
	var help := UIKit.button("How to Play")
	help.pressed.connect(help_modal)
	row.add_child(help)


# ═════════════════════ map ═════════════════════
var _map_nodes: Control
var _map_path: FxViews.MapPath
var _map_xp: Label
var _map_rank: Label


func _build_map_frame(s: Control) -> void:
	UIKit.label(s, "The Path", 40, UIKit.GOLD, UIKit.serif, Vector2(60, 40))
	UIKit.sub(s, "Each encounter teaches a real Grasshopper skill", Vector2(62, 96), 0, 11)
	var stat := func(title: String, x: float) -> Label:
		UIKit.sub(s, title, Vector2(x, 44), 0, 10)
		return UIKit.label(s, "0", 26, UIKit.GOLD, UIKit.serif, Vector2(x, 58))
	_map_xp = stat.call("Total XP", 1150)
	_map_rank = stat.call("Rank", 1260)
	var help := UIKit.button("Help", "", "small")
	help.position = Vector2(1430, 66)
	help.pressed.connect(help_modal)
	s.add_child(help)
	var reset := UIKit.button("Reset", "ghost", "small")
	reset.position = Vector2(1500, 66)
	reset.pressed.connect(func(): modal(func(b):
		_m_h2(b, "Reset progress?")
		_m_p(b, "This clears all XP, stars and unlocked levels on this device.")
		_m_actions(b, [["Cancel", "", close_modal], ["Reset", "warm", func():
			SaveData.reset()
			close_modal()
			open_map()]])))
	s.add_child(reset)
	_map_path = FxViews.MapPath.new()
	_map_path.size = Vector2(1600, 900)
	_map_path.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(_map_path)
	_map_nodes = Control.new()
	_map_nodes.size = Vector2(1600, 900)
	_map_nodes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(_map_nodes)


func open_map() -> void:
	if battle:
		battle.clear_timer()
	show_screen("map")
	var xp := SaveData.total_xp()
	_map_xp.text = str(xp)
	_map_rank.text = SaveData.rank_for(xp)
	for c in _map_nodes.get_children():
		c.queue_free()
	var pts: Array = []
	for i in levels.size():
		pts.append(MAP_POS[i] if i < MAP_POS.size() else Vector2(200 + (i % 5) * 300, 300 + (i / 5) * 220))
	_map_path.points = pts
	_map_path.queue_redraw()
	for i in levels.size():
		var L: Dictionary = levels[i]
		var m: Dictionary = GHData.monsters.get(L.monster, {})
		var locked := i + 1 > SaveData.unlocked
		var best := SaveData.best_for(int(L.id))
		var current := i + 1 == SaveData.unlocked and best.is_empty()
		var border := UIKit.LINE
		if L.get("boss", false):
			border = UIKit.RED_DEEP
		if current:
			border = UIKit.GOLD
		var card := Panel.new()
		card.size = Vector2(250, 110)
		card.position = pts[i] - card.size / 2
		card.add_theme_stylebox_override("panel", UIKit.box(UIKit.PANEL_HI, border, 8, 2 if current else 1, 12))
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not locked else Control.CURSOR_FORBIDDEN
		card.modulate = Color(1, 1, 1, 0.45) if locked else Color.WHITE
		_map_nodes.add_child(card)
		var art := ArtView.new()
		art.bob = false
		art.position = Vector2(4, 13)
		art.size = Vector2(84, 84)
		art.set_texture(UIKit.monster_texture(m.get("art", "rootbound")))
		card.add_child(art)
		UIKit.sub(card, ("Boss" if L.get("boss", false) else "Level %d" % int(L.id)) + " · " + str(m.get("name", "")), Vector2(92, 10), 150, 9)
		var t := UIKit.label(card, L.title, 13, UIKit.GOLD, UIKit.serif, Vector2(92, 25), 152)
		t.clip_text = true
		var obj := UIKit.label(card, L.objective, 11, Color(UIKit.TEXT, 0.8), UIKit.sans, Vector2(92, 46))
		obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		obj.custom_minimum_size = Vector2(150, 0)
		obj.size = Vector2(150, 36)
		obj.max_lines_visible = 2
		obj.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var stars := RichTextLabel.new()
		stars.bbcode_enabled = true
		stars.fit_content = true
		stars.position = Vector2(92, 84)
		stars.size = Vector2(150, 20)
		stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stars.add_theme_font_size_override("normal_font_size", 14)
		var st := ""
		for k in 3:
			st += "[color=%s]★[/color] " % ("#e6c35a" if not best.is_empty() and k < int(best.stars) else "#5a6b66")
		if not best.is_empty():
			st += "[font_size=11][color=#8fa29b]%d XP[/color][/font_size]" % int(best.xp)
		stars.text = st
		card.add_child(stars)
		if locked:
			UIKit.label(card, "🔒", 14, UIKit.TEXT, null, Vector2(222, 6))
		var idx := i
		card.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				if idx + 1 > SaveData.unlocked:
					toast("Defeat the previous monster first", "bad")
				else:
					start_level(idx))
		var home: Vector2 = card.position
		card.mouse_entered.connect(func(): if not locked: card.position = home - Vector2(0, 3))
		card.mouse_exited.connect(func(): card.position = home)


# ═════════════════════ battle layout ═════════════════════
func _build_battle(s: Control) -> void:
	# graph
	var pg := UIKit.panel(s, Rect2(45, 48, 503, 325))
	UIKit.label(pg, "Build your definition", 19, UIKit.GOLD, UIKit.serif, Vector2(18, 12))
	graph_sub = UIKit.sub(pg, "", Vector2(18, 38), 470, 10)
	graph = GraphView.new()
	graph.position = Vector2(10, 58)
	graph.size = Vector2(483, 235)
	graph.place_requested.connect(func():
		if battle.selected != null:
			battle.place()
		else:
			toast("Select a card from your hand first"))
	pg.add_child(graph)
	var line := ColorRect.new()
	line.color = UIKit.LINE_SOFT
	line.position = Vector2(18, 297)
	line.size = Vector2(467, 1)
	pg.add_child(line)
	graph_foot = UIKit.rich(pg, Vector2(18, 301), Vector2(467, 20), 11)

	# preview
	var pp := UIKit.panel(s, Rect2(565, 48, 530, 602), Color("b9c3c6"), Color("5e7470"))
	pp.clip_contents = true
	preview = PreviewView.new()
	preview.position = Vector2(1, 1)
	preview.size = Vector2(528, 600)
	pp.add_child(preview)
	view_btn = OptionButton.new()
	for v in ["Perspective", "Top", "Front"]:
		view_btn.add_item(v)
	view_btn.position = Vector2(8, 8)
	var vsb := UIKit.box(Color("8fb0dc"), Color("5d7fae"), 2, 1)
	vsb.content_margin_left = 10
	vsb.content_margin_right = 10
	for st in ["normal", "hover", "pressed", "focus"]:
		view_btn.add_theme_stylebox_override(st, vsb)
	view_btn.add_theme_color_override("font_color", Color("10264a"))
	view_btn.add_theme_color_override("font_hover_color", Color("10264a"))
	view_btn.add_theme_font_size_override("font_size", 13)
	view_btn.item_selected.connect(func(i): preview.set_view(["perspective", "top", "front"][i]))
	pp.add_child(view_btn)
	var params_panel := PanelContainer.new()
	params_panel.position = Vector2(326, 8)
	params_panel.custom_minimum_size = Vector2(196, 0)
	var psb := UIKit.box(Color(0.94, 0.953, 0.957, 0.82), Color(0.31, 0.37, 0.39, 0.35), 4, 1)
	psb.content_margin_left = 9
	psb.content_margin_right = 9
	psb.content_margin_top = 6
	psb.content_margin_bottom = 6
	params_panel.add_theme_stylebox_override("panel", psb)
	pp.add_child(params_panel)
	params_box = VBoxContainer.new()
	params_box.add_theme_constant_override("separation", 0)
	params_panel.add_child(params_box)
	preview_foot = UIKit.label(pp, "", 13, Color("56676b"), UIKit.sans, Vector2(18, 566), 300)
	timer_pill = FxViews.TimerPill.new()
	timer_pill.position = Vector2(140, 8)
	timer_pill.size = Vector2(170, 30)
	timer_pill.visible = false
	pp.add_child(timer_pill)

	# health
	health_panel = UIKit.panel(s, Rect2(1112, 48, 440, 152))
	UIKit.label(health_panel, "Your health", 19, UIKit.GOLD, UIKit.serif, Vector2(18, 12))
	hp_text = UIKit.label(health_panel, "4 / 4", 18, UIKit.GOLD, UIKit.serif, Vector2(330, 12))
	hp_text.size.x = 92
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hearts = FxViews.Hearts.new()
	hearts.position = Vector2(0, 34)
	hearts.size = Vector2(440, 92)
	hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_panel.add_child(hearts)
	level_chip = UIKit.sub(health_panel, "", Vector2(18, 128), 300, 11)
	xp_text = UIKit.label(health_panel, "XP 0", 12, UIKit.MUTED, UIKit.sans_bold, Vector2(320, 127))
	xp_text.size.x = 102
	xp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	effects_box = HBoxContainer.new()
	effects_box.position = Vector2(1112, 210)
	effects_box.size = Vector2(440, 32)
	effects_box.add_theme_constant_override("separation", 6)
	s.add_child(effects_box)

	# monster
	mon_panel = UIKit.panel(s, Rect2(1112, 250, 440, 418), Color("1f3632"))
	mon_panel.clip_contents = true
	var glow := TextureRect.new()
	var gg := Gradient.new()
	gg.set_color(0, Color("24403b"))
	gg.set_color(1, Color(0.1, 0.17, 0.16, 0))
	var ggt := GradientTexture2D.new()
	ggt.gradient = gg
	ggt.fill = GradientTexture2D.FILL_RADIAL
	ggt.fill_from = Vector2(0.5, 0.7)
	ggt.fill_to = Vector2(1.0, 1.2)
	glow.texture = ggt
	glow.size = Vector2(440, 418)
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mon_panel.add_child(glow)
	mon_name = UIKit.label(mon_panel, "", 25, UIKit.GOLD, UIKit.serif, Vector2(18, 12))
	mon_name.size = Vector2(250, 60)
	mon_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mon_sub = UIKit.sub(mon_panel, "", Vector2(18, 72), 260, 10)
	mon_intent_box = PanelContainer.new()
	var isb := UIKit.box(Color(0.157, 0.063, 0.078, 0.7), Color("8c4a4f"), 2, 1)
	isb.content_margin_left = 10
	isb.content_margin_right = 10
	isb.content_margin_top = 6
	isb.content_margin_bottom = 6
	mon_intent_box.add_theme_stylebox_override("panel", isb)
	mon_intent_box.position = Vector2(260, 14)
	mon_panel.add_child(mon_intent_box)
	mon_intent = UIKit.label(mon_intent_box, "", 10, Color("f1d0c4"), UIKit.sans_xbold)
	mon_hp_text = UIKit.label(mon_panel, "", 11, UIKit.TEXT, UIKit.sans_bold, Vector2(18, 86))
	mon_hp_text.size.x = 404
	mon_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var bar := Panel.new()
	bar.position = Vector2(18, 104)
	bar.size = Vector2(404, 11)
	bar.add_theme_stylebox_override("panel", UIKit.box(Color("2c2524"), Color("d9c9a0"), 6, 2))
	bar.clip_contents = true
	mon_panel.add_child(bar)
	mon_hp_fill = ColorRect.new()
	mon_hp_fill.color = Color("c45b5e")
	mon_hp_fill.size = Vector2(404, 11)
	bar.add_child(mon_hp_fill)
	mon_art = ArtView.new()
	mon_art.position = Vector2(30, 122)
	mon_art.size = Vector2(380, 290)
	mon_panel.add_child(mon_art)

	# featured card, feedback, lifesavers
	featured = Control.new()
	featured.position = Vector2(50, 392)
	featured.size = Vector2(214, 246)
	s.add_child(featured)
	fb_panel = UIKit.panel(s, Rect2(278, 392, 270, 182))
	fb_panel.clip_contents = true
	fb_head = UIKit.sub(fb_panel, "", Vector2(14, 10), 180, 10)
	fb_count = UIKit.sub(fb_panel, "", Vector2(196, 10), 60, 10)
	fb_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fb_title = UIKit.label(fb_panel, "", 16, UIKit.GOLD, UIKit.serif, Vector2(14, 26), 242)
	fb_body = UIKit.rich(fb_panel, Vector2(14, 50), Vector2(242, 90), 12)
	fb_meta = UIKit.rich(fb_panel, Vector2(14, 140), Vector2(242, 40), 10, UIKit.MUTED)
	var lsrow := HBoxContainer.new()
	lsrow.position = Vector2(278, 582)
	lsrow.size = Vector2(270, 54)
	lsrow.add_theme_constant_override("separation", 6)
	s.add_child(lsrow)
	for k in Battle.LS_ORDER:
		var b := Button.new()
		b.custom_minimum_size = Vector2(40, 54)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nsb := UIKit.box(Color("263d3a"), Color("6f8a83"), 6, 1)
		var hsb := UIKit.box(Color("2f4b47"), Color("6f8a83"), 6, 1)
		b.add_theme_stylebox_override("normal", nsb)
		b.add_theme_stylebox_override("hover", hsb)
		b.add_theme_stylebox_override("pressed", nsb)
		b.add_theme_stylebox_override("disabled", nsb)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.tooltip_text = "%s\n%s" % Battle.LS_INFO[k]
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var icon := TextureRect.new()
		icon.texture = UIKit.svg_texture("res://art/ls_%s.svg" % k, 2.0)
		icon.size = Vector2(24, 24)
		icon.position = Vector2(8, 15)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)
		if k == "fifty":
			icon.visible = false
			var t50 := UIKit.label(b, "50/50", 11, UIKit.GOLD, UIKit.sans_xbold, Vector2(4, 19))
			t50.size.x = 32
			t50.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var badge := Label.new()
		badge.add_theme_font_override("font", UIKit.sans_xbold)
		badge.add_theme_font_size_override("font_size", 10)
		badge.add_theme_color_override("font_color", Color("1a2120"))
		var bsb := UIKit.box(UIKit.STAR, Color("1a2120"), 9, 1)
		bsb.content_margin_left = 4
		bsb.content_margin_right = 4
		badge.add_theme_stylebox_override("normal", bsb)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.position = Vector2(26, -6)
		badge.custom_minimum_size = Vector2(17, 17)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(badge)
		var key: String = k
		b.pressed.connect(func(): battle.use_lifesaver(key))
		lsrow.add_child(b)
		ls_buttons[k] = {"button": b, "badge": badge, "icon": icon}

	# hero, hand, side buttons
	hero = ArtView.new()
	hero.bob = false
	hero.position = Vector2(30, 646)
	hero.size = Vector2(290, 250)
	hero.set_texture(UIKit.hero_texture())
	s.add_child(hero)
	UIKit.label(s, "Your hand", 19, UIKit.GOLD, UIKit.serif, Vector2(376, 638))
	hand_sub = UIKit.sub(s, "", Vector2(510, 646), 400, 10)
	hand_box = Control.new()
	hand_box.position = Vector2(330, 662)
	hand_box.size = Vector2(940, 240)
	hand_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(hand_box)
	var side := VBoxContainer.new()
	side.position = Vector2(1300, 736)
	side.size = Vector2(235, 140)
	side.add_theme_constant_override("separation", 12)
	s.add_child(side)
	var moves := UIKit.button("Moves", "primary")
	moves.custom_minimum_size = Vector2(235, 54)
	moves.add_theme_font_size_override("font_size", 24)
	moves.pressed.connect(moves_modal)
	side.add_child(moves)
	var helpb := UIKit.button("Help", "warm")
	helpb.custom_minimum_size = Vector2(235, 54)
	helpb.add_theme_font_size_override("font_size", 24)
	helpb.pressed.connect(help_modal)
	side.add_child(helpb)
	var mapb := UIKit.button("← Map", "ghost", "small")
	mapb.size_flags_horizontal = Control.SIZE_SHRINK_END
	mapb.pressed.connect(func():
		if battle and not battle.over and battle.di > 0:
			modal(func(b):
				_m_h2(b, "Leave the battle?")
				_m_p(b, "Your progress in this level will be lost.")
				_m_actions(b, [["Stay", "", close_modal], ["Leave", "warm", func():
					close_modal()
					open_map()]]))
		else:
			open_map())
	side.add_child(mapb)
	flash = FxViews.Flash.new()
	flash.size = Vector2(1600, 900)
	s.add_child(flash)


func _build_overlays() -> void:
	toast_box = VBoxContainer.new()
	toast_box.position = Vector2(400, 380)
	toast_box.size = Vector2(800, 10)
	toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	toast_box.add_theme_constant_override("separation", 8)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.z_index = 70
	add_child(toast_box)
	modal_layer = Control.new()
	modal_layer.size = Vector2(1600, 900)
	modal_layer.visible = false
	modal_layer.z_index = 80
	add_child(modal_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.04, 0.72)
	dim.size = Vector2(1600, 900)
	dim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: close_modal())
	modal_layer.add_child(dim)
	modal_panel = PanelContainer.new()
	var msb := UIKit.box(Color("1d2d2b"), UIKit.LINE, 8, 1, 30)
	msb.content_margin_left = 34
	msb.content_margin_right = 34
	msb.content_margin_top = 28
	msb.content_margin_bottom = 28
	modal_panel.add_theme_stylebox_override("panel", msb)
	modal_panel.custom_minimum_size = Vector2(720, 0)
	modal_layer.add_child(modal_panel)
	modal_scroll = ScrollContainer.new()
	modal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal_panel.add_child(modal_scroll)
	modal_box = VBoxContainer.new()
	modal_box.add_theme_constant_override("separation", 8)
	modal_box.custom_minimum_size.x = 652
	modal_scroll.add_child(modal_box)


# ═════════════════════ battle flow ═════════════════════
func start_level(i: int) -> void:
	if battle:
		battle.clear_timer()
	battle = Battle.new(levels[i], i, levels.size())
	battle.changed.connect(render_all)
	battle.fx.connect(_on_fx)
	graph.battle = battle
	_hand_ids = []
	_hp_shown = -1.0
	show_screen("battle")
	preview.set_view("perspective")
	view_btn.select(0)
	preview.zoom = 1.0
	mon_art.set_texture(UIKit.monster_texture(battle.monster().get("art", "rootbound")))
	_render_params()
	render_all()
	update_preview()
	briefing()


func update_preview(fresh := "") -> void:
	var done := battle.done
	var ctx := {"params": battle.params,
		"placed": func(n): return n.given or done.has(n.id),
		"wire_active": func(w): return w.quiz == null or done.has(w.quiz)}
	preview.set_scene(GHEngine.scene(battle.L, GHEngine.evaluate(battle.L, ctx), ctx), fresh)


func _on_fx(kind: String, data: Dictionary) -> void:
	var delay: float = data.get("delay", 0.0)
	if delay > 0:
		var d2 := data.duplicate()
		d2.erase("delay")
		get_tree().create_timer(delay).timeout.connect(func(): _on_fx(kind, d2))
		return
	match kind:
		"toast":
			toast(data.msg, data.get("cls", ""))
		"float":
			var pos := Vector2(1332, 500)
			match data.target:
				"health": pos = Vector2(1420, 150)
				"hearts": pos = Vector2(1312, 118)
			float_text(pos, data.text, data.get("cls", ""))
		"anim":
			match data.target:
				"monster": mon_art.play(data.name)
				"hero": hero.play(data.name)
				"flash": flash.play()
				"intent":
					var tw := create_tween()
					tw.tween_property(mon_intent_box, "modulate", Color(1.6, 1.6, 1.6), 0.15)
					tw.tween_property(mon_intent_box, "modulate", Color.WHITE, 0.3)
					tw.set_loops(2)
		"preview":
			update_preview(data.fresh)
		"victory":
			mon_art.kill()
			get_tree().create_timer(1.1).timeout.connect(victory_modal)
		"defeat":
			get_tree().create_timer(0.65).timeout.connect(defeat_modal)
		"revived":
			close_modal()
		"dealt":
			_hand_ids = []


func render_all() -> void:
	if battle == null:
		return
	var d = battle.cur()
	graph_sub.text = str(battle.L.objective).to_upper()
	if d == null:
		graph_foot.text = "[color=#e8dcb0][b]DEFINITION COMPLETE[/b][/color] • Drag the sliders in the preview to explore your result." if battle.won else ""
	elif d.kind == "quiz":
		graph_foot.text = "[color=#e8dcb0][b]WIRE CHECK[/b][/color] • " + str(d.quiz.prompt)
	else:
		var n := 0
		for i in battle.L.steps.size():
			if battle.L.steps[i].key == d.step.key:
				n = i + 1
		graph_foot.text = "[color=#e8dcb0][b]SELECTED SLOT %s[/b][/color] • Place a card here to extend the definition." % UIKit.pad2(n)
	graph.queue_redraw()
	preview.blurred = battle.effects.blur > 0
	_render_hand()
	_render_featured()
	_render_feedback()
	_render_health()
	_render_effects()
	_render_monster()
	_render_lifesavers()
	_render_timer()
	hand_sub.text = ("Definition complete" if battle.won else "") if d == null else ("Wire check: choose a port" if d.kind == "quiz" else "Choose a component").to_upper()


func _render_params() -> void:
	for c in params_box.get_children():
		c.queue_free()
	UIKit.label(params_box, "SLIDERS", 9, Color("4a5a5e"), UIKit.sans_bold)
	for p in battle.L.params:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(178, 21)
		row.add_theme_constant_override("separation", 6)
		params_box.add_child(row)
		var name := UIKit.label(row, str(p.label), 11, Color("263235"), UIKit.sans_bold)
		name.custom_minimum_size = Vector2(62, 0)
		name.clip_text = true
		var sl := HSlider.new()
		sl.min_value = float(p.min)
		sl.max_value = float(p.max)
		sl.step = float(p.step)
		sl.value = float(battle.params[p.key])
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sl.custom_minimum_size = Vector2(70, 14)
		row.add_child(sl)
		var val := UIKit.label(row, UIKit.fmt(sl.value), 11, Color("263235"), UIKit.sans_bold)
		val.custom_minimum_size = Vector2(30, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var key: String = p.key
		sl.value_changed.connect(func(v):
			battle.params[key] = v
			val.text = UIKit.fmt(v)
			update_preview()
			graph.queue_redraw())
	preview_foot.text = "World XY • %s preview" % battle.L.title


func _render_hand() -> void:
	var ids: Array = battle.hand
	if ids != _hand_ids:
		for c in _cards:
			c.queue_free()
		_cards = []
		var dealing := battle.deal_anim
		for i in ids.size():
			var cv := CardView.new().setup(ids[i], battle)
			cv.clicked.connect(func(id):
				if battle.selected == id:
					battle.place()
				else:
					battle.select(id))
			cv.set_meta("hover_cb", func(_c): _layout_hand(false))
			hand_box.add_child(cv)
			_cards.append(cv)
		_hand_ids = ids.duplicate()
		_layout_hand(true, dealing)
		battle.deal_anim = false
	else:
		_layout_hand(false)
	for c in _cards:
		c.is_selected = c.card_id == battle.selected
		c.queue_redraw()


func _layout_hand(fresh: bool, dealing := false) -> void:
	var n := _cards.size()
	if n == 0:
		return
	var cw := 196.0
	var avail := 940.0
	var step := minf(186.0, (avail - cw) / (n - 1)) if n > 1 else 0.0
	var left0 := (avail - (cw + step * (n - 1))) / 2.0
	var mid := (n - 1) / 2.0
	for i in n:
		var c: CardView = _cards[i]
		var off := i - mid
		var rot := off * (3.4 if n > 4 else 4.6)
		var y := off * off * (3.5 if n > 4 else 6.0) + 6.0
		var sel: bool = c.card_id == battle.selected
		var lift := 38.0 if sel else (22.0 if c.hovered else 0.0)
		var r2 := rot * (0.5 if c.hovered and not sel else 1.0)
		var target := Vector2(left0 + i * step, y - lift)
		c.z_index = 31 if sel else (30 if c.hovered else 10 + i)
		if fresh:
			if dealing:
				c.position = target + Vector2(400, 260)
				c.rotation_degrees = 20
				c.modulate.a = 0.0
				var tw := c.create_tween()
				tw.tween_interval(i * 0.06)
				tw.set_parallel(true)
				tw.tween_property(c, "position", target, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				tw.tween_property(c, "rotation_degrees", r2, 0.45)
				tw.tween_property(c, "modulate:a", 1.0, 0.3)
			else:
				c.position = target
				c.rotation_degrees = r2
		else:
			var tw2 := c.create_tween().set_parallel(true)
			tw2.tween_property(c, "position", target, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw2.tween_property(c, "rotation_degrees", r2, 0.25)


func _render_featured() -> void:
	for c in featured.get_children():
		c.queue_free()
	var d = battle.cur()
	if d == null or battle.selected == null:
		var box := FxViews.DashedBox.new()
		box.size = Vector2(210, 204)
		featured.add_child(box)
		var rt := UIKit.rich(box, Vector2(16, 0), Vector2(178, 204), 12, UIKit.MUTED)
		rt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var head: String
		var body: String
		if d == null:
			head = "Victory!" if battle.won else "Defeated"
			body = "Your definition is complete. Drag the sliders in the preview to see it respond." if battle.won else "Retry from the menu."
		else:
			head = "Wire check" if d.kind == "quiz" else "Your move"
			body = str(d.quiz.prompt) if d.kind == "quiz" else "Choose a card from your hand to inspect it, then place it in the glowing node."
			if battle.L.guidance == "guided" and d.kind == "comp":
				body += "\n\n[color=#a8c690][i]Needs %s.[/i][/color]" % d.step.need
		rt.text = "[center][font_size=15][color=#e8dcb0]%s[/color][/font_size]\n%s[/center]" % [head, body]
		if d == null and battle.won and battle.idx + 1 < levels.size():
			var nb := UIKit.button("Next level →", "", "small")
			nb.position = Vector2(48, 160)
			nb.pressed.connect(func(): start_level(battle.idx + 1))
			box.add_child(nb)
		return
	var cv := CardView.new().setup(str(battle.selected), battle, true)
	cv.position = Vector2(2, 2)
	cv.clicked.connect(func(_id): battle.place())
	featured.add_child(cv)
	var pb := UIKit.button("Connect wire ▸" if d.kind == "quiz" else "Place in node ▸", "primary", "mid")
	pb.position = Vector2(2, 214)
	pb.custom_minimum_size = Vector2(210, 30)
	pb.pressed.connect(func(): battle.place())
	featured.add_child(pb)


func _render_feedback() -> void:
	var f: Dictionary = battle.fb
	var border := UIKit.LINE
	var tcol := UIKit.GOLD
	match f.get("cls", ""):
		"ok":
			border = UIKit.SAGE_DEEP
			tcol = Color("b9e0a5")
		"bad":
			border = Color("a14a52")
			tcol = Color("f0a6a6")
		"hint":
			border = Color("c9b26a")
			tcol = Color("f0dc96")
	fb_panel.add_theme_stylebox_override("panel", UIKit.box(UIKit.PANEL_HI, border, 6, 1, 14))
	fb_head.text = str(f.get("head", "Field notes")).to_upper()
	fb_count.text = "%d/%d" % [battle.di, battle.decisions.size()]
	fb_title.text = f.get("title", "")
	fb_title.add_theme_color_override("font_color", tcol)
	fb_body.text = str(f.get("body", ""))
	var body_h := fb_body.get_content_height()
	fb_meta.position.y = 50 + minf(body_h, 120) + 6
	fb_meta.text = str(f.get("meta", "")).replace("[b]", "[color=#a8c690][b]").replace("[/b]", "[/b][/color]")
	var tw := create_tween()
	fb_panel.modulate.a = 0.4
	tw.tween_property(fb_panel, "modulate:a", 1.0, 0.3)


func _render_health() -> void:
	hp_text.text = "%d / %d" % [battle.health, battle.max_health]
	hearts.set_state(battle.health, battle.max_health, battle.shield)
	xp_text.text = "XP %d" % battle.xp
	level_chip.text = ("Boss level" if battle.L.get("boss", false) else "Level %d · %s" % [int(battle.L.id), battle.L.title]).to_upper()


func _chip(text: String, good := false, none := false) -> void:
	var p := PanelContainer.new()
	var sb := UIKit.box(Color("20363c") if good else (Color(0, 0, 0, 0) if none else Color("3a2328")), Color("8fd0e6") if good else (UIKit.LINE_SOFT if none else UIKit.RED), 14, 1)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	UIKit.label(p, text.to_upper(), 11, Color("cdeef7") if good else (UIKit.MUTED if none else Color("f1c8c8")), UIKit.sans_bold)
	effects_box.add_child(p)


func _render_effects() -> void:
	for c in effects_box.get_children():
		c.queue_free()
	var e := battle.effects
	var any := false
	if e.blur > 0:
		_chip("Blurred · %d" % e.blur)
		any = true
	if e.icon > 0:
		_chip("Icon curse · %d" % e.icon)
		any = true
	if e.locked != null:
		_chip("Locked node · %d" % e.locked.turns)
		any = true
	if battle.timer != null:
		var m := battle.monster()
		_chip("Frenzy" if m.has("frenzy") and battle.timer.total == float(m.frenzy) else "Time pressure")
		any = true
	if battle.shield:
		_chip("Shielded", true)
		any = true
	if battle.snap != null and int(battle.ls.get("second", 0)) > 0 and not battle.won:
		_chip("Second chance ready", true)
		any = true
	if not any:
		_chip("No active penalties", false, true)


func _render_monster() -> void:
	var m := battle.monster()
	mon_name.text = m.get("name", "")
	mon_name.add_theme_font_size_override("font_size", 20 if str(mon_name.text).length() > 15 else 25)
	mon_sub.text = ("%s · %s" % [m.get("place", ""), "Boss" if battle.L.get("boss", false) else "Encounter " + UIKit.pad2(battle.L.id)]).to_upper()
	mon_intent.text = "DEFEATED" if battle.won else ("⚔ INTENT: " + Battle.INTENT_TXT.get(battle.intent, battle.intent)).to_upper()
	mon_intent_box.reset_size()
	mon_intent_box.position.x = 422 - mon_intent_box.size.x
	mon_hp_text.text = "%d / %d" % [battle.hp, battle.hp_max]


func _render_lifesavers() -> void:
	for k in ls_buttons:
		var e: Dictionary = ls_buttons[k]
		var b: Button = e.button
		var can := battle.can_use(k)
		b.disabled = not can
		b.modulate = Color(1, 1, 1, 1) if can else Color(0.7, 0.7, 0.7, 0.5)
		e.badge.text = str(int(battle.ls.get(k, 0)))
		var ready: bool = k == "second" and can
		var active: bool = k == "shield" and battle.shield
		var sb := UIKit.box(Color("263d3a"), UIKit.STAR if ready else (Color("8fd0e6") if active else Color("6f8a83")), 6, 2 if (ready or active) else 1)
		if ready:
			sb.shadow_color = Color(0.9, 0.76, 0.35, 0.6)
			sb.shadow_size = 8
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("disabled", sb)
		var tip: String = "%s\n%s" % Battle.LS_INFO[k]
		if int(battle.ls.get(k, 0)) <= 0:
			tip += "\nNone left this level."
		b.tooltip_text = tip


func _render_timer() -> void:
	if battle == null or battle.timer == null:
		timer_pill.visible = false
		return
	timer_pill.visible = true
	timer_pill.left = battle.timer.left
	timer_pill.total = battle.timer.total
	timer_pill.position.x = 140 + (sin(Time.get_ticks_msec() / 40.0) * 3.0 if battle.timer.left < 5 else 0.0)
	timer_pill.queue_redraw()


# ═════════════════════ toasts, floats ═════════════════════
func toast(msg: String, cls := "") -> void:
	var p := PanelContainer.new()
	var border := UIKit.GOLD_DIM
	var col := UIKit.GOLD
	if cls == "bad":
		border = UIKit.RED
		col = Color("f6c0c0")
	elif cls == "good":
		border = UIKit.SAGE
		col = Color("d5efc4")
	var sb := UIKit.box(Color(0.06, 0.1, 0.094, 0.94), border, 4, 1, 12)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.label(p, msg, 18, col, UIKit.serif)
	toast_box.add_child(p)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.tween_interval(1.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.45)
	tw.tween_callback(p.queue_free)


func float_text(pos: Vector2, text: String, cls := "") -> void:
	var col := Color("ffe2a8")
	if cls == "bad":
		col = Color("ff9f9f")
	elif cls == "good":
		col = Color("b9f0c4")
	var l := UIKit.label(self, text, 30, col, UIKit.serif, pos - Vector2(20, 10))
	l.add_theme_color_override("font_outline_color", Color("4a1018"))
	l.add_theme_constant_override("outline_size", 6)
	l.z_index = 20
	l.modulate.a = 0.0
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "modulate:a", 1.0, 0.2)
	tw.tween_property(l, "position:y", l.position.y - 70, 1.1).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(l, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(l.queue_free)


# ═════════════════════ modal ═════════════════════
func modal(builder: Callable, on_close = null) -> void:
	for c in modal_box.get_children():
		c.queue_free()
	builder.call(modal_box)
	modal_on_close = on_close
	modal_layer.visible = true
	modal_panel.modulate.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	modal_scroll.scroll_vertical = 0
	modal_scroll.custom_minimum_size = Vector2(652, minf(modal_box.get_combined_minimum_size().y, 760))
	modal_panel.reset_size()
	modal_panel.position = (Vector2(1600, 900) - modal_panel.size) / 2.0
	var tw := create_tween()
	tw.tween_property(modal_panel, "modulate:a", 1.0, 0.2)


func close_modal() -> void:
	if not modal_layer.visible:
		return
	modal_layer.visible = false
	var f = modal_on_close
	modal_on_close = null
	if f != null:
		f.call()


func _m_sub(b: Control, text: String) -> void:
	UIKit.sub(b, text, Vector2.ZERO, 0, 11)


func _m_h2(b: Control, text: String) -> void:
	UIKit.label(b, text, 32, UIKit.GOLD, UIKit.serif)


func _m_h4(b: Control, text: String) -> void:
	var l := UIKit.label(b, text, 16, UIKit.GOLD, UIKit.serif)
	l.custom_minimum_size.y = 30
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM


func _m_p(b: Control, bbcode: String, size := 15, width := 652.0) -> RichTextLabel:
	var r := UIKit.rich(b, Vector2.ZERO, Vector2(width, 10), size)
	r.fit_content = true
	r.custom_minimum_size.x = width
	r.text = bbcode
	return r


func _m_table(b: Control, rows: Array, first_width := 150.0) -> void:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 6)
	b.add_child(g)
	for r in rows:
		var k := UIKit.label(g, str(r[0]), 14, UIKit.GOLD, UIKit.sans_bold)
		k.custom_minimum_size.x = first_width
		var v := _m_p(g, str(r[1]), 14, 652.0 - first_width - 16)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _m_actions(b: Control, acts: Array) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 12
	b.add_child(spacer)
	b.add_child(row)
	for a in acts:
		var btn := UIKit.button(a[0], a[1], "mid")
		btn.pressed.connect(a[2])
		row.add_child(btn)


func briefing() -> void:
	var L := battle.L
	var m := battle.monster()
	var mode: String = {"guided": "Guided: descriptions shown, and the open node tells you what it needs.",
		"standard": "Standard: descriptions shown, no slot hints.",
		"independent": "Independent: card descriptions hidden. Read the icons and ports."}.get(L.guidance, "")
	var quizzes: int = battle.decisions.size() - L.steps.size()
	modal(func(b):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 22)
		b.add_child(row)
		var art := ArtView.new()
		art.custom_minimum_size = Vector2(200, 200)
		art.set_texture(UIKit.monster_texture(m.get("art", "rootbound")))
		row.add_child(art)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		row.add_child(col)
		_m_sub(col, ("Boss level" if L.get("boss", false) else "Level %d" % int(L.id)) + " · " + str(m.get("place", "")))
		_m_h2(col, L.title)
		_m_p(col, "[b]%s[/b] blocks the path. %s" % [m.get("name", ""), m.get("trait", "")], 15, 430)
		var kv := [["Challenge", L.objective], ["You'll learn", L.get("learn", "")], ["Mode", mode],
			["Decisions", "%d (%d components%s)" % [battle.decisions.size(), L.steps.size(), (" + %d wire checks" % quizzes) if quizzes > 0 else ""]]]
		for e in kv:
			var r2 := HBoxContainer.new()
			r2.add_theme_constant_override("separation", 12)
			col.add_child(r2)
			var k := UIKit.sub(r2, e[0], Vector2.ZERO, 0, 11)
			k.custom_minimum_size.x = 110
			_m_p(r2, str(e[1]), 14, 308)
		_m_actions(b, [["Back", "ghost", func():
			close_modal()
			open_map()], ["Fight!", "primary", close_modal]]),
		func():
			var mm := battle.monster()
			if mm.has("frenzy") and not battle.over and battle.timer == null:
				battle.start_timer(float(mm.frenzy)))


func victory_modal() -> void:
	if battle == null or not battle.won:
		return
	var L := battle.L
	var m := battle.monster()
	var sc := battle.score
	modal(func(b):
		_m_sub(b, str(m.get("place", "")) + " · " + ("Boss defeated" if L.get("boss", false) else "Encounter " + UIKit.pad2(L.id)))
		_m_h2(b, "%s is defeated!" % m.get("name", ""))
		var stars := ""
		for i in 3:
			stars += "[color=%s]★[/color] " % ("#e6c35a" if i < int(sc.stars) else "#45524e")
		_m_p(b, "[font_size=46]%s[/font_size]" % stars)
		_m_p(b, "You built a working definition: [b]%s[/b]" % L.objective)
		_m_table(b, [["Correct decisions", str(sc.xp)],
			["Efficiency (%d / %d picks)" % [battle.decisions.size(), battle.attempts], str(sc.eff)],
			["Health remaining (%d × 50)" % battle.health, str(sc.hp_bonus)],
			["Perfect run" + ("" if sc.perfect else " (no mistakes, no lifesavers)"), str(sc.perf_bonus)],
			["Total XP", "[font_size=19][color=#e8dcb0][b]%d[/b][/color][/font_size]" % int(sc.total)]], 330)
		var acts := [["Explore result", "ghost", close_modal], ["Map", "", func():
			close_modal()
			open_map()]]
		if battle.idx + 1 < levels.size():
			acts.append(["Next level →", "primary", func():
				close_modal()
				start_level(battle.idx + 1)])
		else:
			acts.append(["Finish", "primary", credits])
		_m_actions(b, acts))


func defeat_modal() -> void:
	if battle == null or battle.won or not battle.over:
		return
	var m := battle.monster()
	modal(func(b):
		_m_sub(b, str(m.get("place", "")))
		_m_h2(b, "%s wins this round" % m.get("name", ""))
		_m_p(b, "Your health ran out with [b]%d of %d[/b] decisions complete. Every mistake taught you something: check [b]Moves[/b] for the explanations, then try again." % [battle.di, battle.decisions.size()])
		var acts := []
		if battle.snap != null and int(battle.ls.get("second", 0)) > 0:
			acts.append(["Use Second Chance", "warm", func(): battle.use_lifesaver("second")])
		acts.append(["Map", "", func():
			close_modal()
			open_map()])
		acts.append(["Retry", "primary", func():
			close_modal()
			start_level(battle.idx)])
		_m_actions(b, acts))
	render_all()


func credits() -> void:
	modal(func(b):
		_m_h2(b, "Script Master")
		_m_p(b, "You defeated the Spaghetti Wyrm and built a complete parametric workflow: polygon, series, graph mapping, scale, rotate, move and loft, all driven by a handful of sliders.")
		_m_p(b, "That chain is real Grasshopper. Open Rhino, place the same components, wire them the same way, and you'll get the same tower.")
		_m_p(b, "[color=#8fa29b]Replay levels for three stars and a higher rank, or try a perfect run without lifesavers.[/color]")
		_m_actions(b, [["Back to the map", "primary", func():
			close_modal()
			open_map()]]))


func help_modal() -> void:
	modal(func(b):
		_m_h2(b, "How to play")
		_m_p(b, "Each level is a Grasshopper challenge guarded by a monster. Build the definition before it defeats you.")
		_m_h4(b, "Each turn")
		_m_p(b, "1. Pick a [b]component card[/b] from your hand: it appears in the featured slot.\n2. Click [b]Place[/b], the glowing node, or the card again to commit.\n3. [b]Wire checks[/b] ask which input or output a wire should connect to: the cards become ports.\n4. Read the [b]field notes[/b]: every choice explains why it works (or doesn't), what it expects and what it outputs. Watch the preview update.", 14)
		_m_h4(b, "Monster attacks")
		_m_p(b, "[color=#8fa29b]A wrong pick costs a heart and triggers the monster's telegraphed [b]intent[/b] (shown on its panel). Penalties wear off as you place correct components.[/color]", 14)
		_m_table(b, [["Heavy Strike", "Lose 2 hearts instead of 1."], ["Blurred Vision", "Component names and the preview blur for 2 placements."],
			["Icon Curse", "Card names and descriptions vanish: only icons and ports remain."], ["Scramble", "Your hand is shuffled."],
			["Locked Component", "A placed node hides its label for 3 placements."], ["Time Pressure", "15 seconds to decide, or take a hit."]])
		_m_h4(b, "Lifesavers")
		var rows := []
		for k in Battle.LS_ORDER:
			rows.append(Battle.LS_INFO[k])
		rows.append(["Streak bonus", "Every 3 correct picks in a row may award an extra lifesaver."])
		_m_table(b, rows)
		_m_h4(b, "Scoring")
		_m_p(b, "+100 XP per component (+60 per wire check), +40 for a clean first try, plus efficiency, health and a 500 XP bonus for a perfect run (no mistakes, no lifesavers).", 14)
		_m_h4(b, "Shortcuts")
		_m_p(b, "[color=#8fa29b]Keys 1–6 select a card · Enter places it · H uses a hint · drag the preview to orbit, scroll to zoom, double-click to reset.[/color]", 14)
		_m_actions(b, [["Got it", "primary", close_modal]]))


func moves_modal() -> void:
	if battle == null:
		return
	modal(func(b):
		_m_sub(b, battle.L.title)
		_m_h2(b, "Moves & field notes")
		_m_p(b, "[color=#8fa29b]%d / %d decisions · %d mistakes · %d lifesavers used[/color]" % [battle.di, battle.decisions.size(), battle.mistakes, battle.aids], 14)
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(652, mini(480, 40 + battle.journal.size() * 70))
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		b.add_child(scroll)
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 8)
		scroll.add_child(list)
		if battle.journal.is_empty():
			_m_p(list, "[color=#8fa29b]No moves yet. Every decision you make is logged here with its explanation.[/color]", 14, 630)
		for e in battle.journal:
			var p := PanelContainer.new()
			var bc := UIKit.SAGE_DEEP
			if e.cls == "bad":
				bc = Color("a14a52")
			elif e.cls == "aid":
				bc = Color("c9b26a")
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0, 0, 0, 0.18)
			sb.border_color = bc
			sb.border_width_left = 3
			sb.content_margin_left = 12
			sb.content_margin_right = 12
			sb.content_margin_top = 6
			sb.content_margin_bottom = 6
			p.add_theme_stylebox_override("panel", sb)
			list.add_child(p)
			_m_p(p, "[font_size=15][color=#e8dcb0]%s[/color][/font_size]\n%s" % [e.title, e.text], 13, 600)
		_m_actions(b, [["Back to battle", "primary", close_modal]]))


# ═════════════════════ keyboard ═════════════════════
func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	if e.keycode == KEY_ESCAPE and modal_layer.visible:
		close_modal()
		return
	if modal_layer.visible or battle == null or not screens.battle.visible:
		return
	if e.keycode >= KEY_1 and e.keycode <= KEY_9:
		var i: int = e.keycode - KEY_1
		if i < battle.hand.size():
			battle.select(battle.hand[i])
	elif (e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER) and battle.selected != null:
		battle.place()
	elif e.keycode == KEY_H:
		battle.use_lifesaver("hint")
