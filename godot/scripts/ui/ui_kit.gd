## Colors, fonts, style boxes, widgets and textures shared by every screen.
## Colors come from web/css/style.css so both versions look alike.
class_name UIKit
extends RefCounted

const BG := Color("13201f")
const PANEL := Color("1c2c2a")
const PANEL_HI := Color("223532")
const LINE := Color("3d5450")
const LINE_SOFT := Color("2c3f3c")
const GOLD := Color("e8dcb0")
const GOLD_DIM := Color("b8ad86")
const SAGE := Color("a8c690")
const SAGE_DEEP := Color("6f9a7e")
const TEXT := Color("dfe6dc")
const MUTED := Color("8fa29b")
const RED := Color("c4555e")
const RED_DEEP := Color("8f2f3a")
const PARCH := Color("ece3c9")
const PARCH_2 := Color("e0d5b4")
const INK := Color("2a2a24")
const STAR := Color("e6c35a")

static var serif: Font
static var sans: Font
static var sans_bold: Font
static var sans_xbold: Font
static var _tex := {}


static func init() -> void:
	if serif != null:
		return
	serif = _font("res://fonts/Cinzel.ttf", 700)
	sans = _font("res://fonts/Barlow-Medium.ttf")
	sans_bold = _font("res://fonts/Barlow-Bold.ttf")
	sans_xbold = _font("res://fonts/Barlow-ExtraBold.ttf")


static func _font(path: String, weight := 0) -> Font:
	var f = load(path)
	if f == null:
		return ThemeDB.fallback_font
	if weight > 0:
		var v := FontVariation.new()
		v.base_font = f
		v.variation_opentype = {"wght": weight}
		return v
	return f


## The game-wide theme: default font, colors, tooltip look.
static func make_theme() -> Theme:
	init()
	var t := Theme.new()
	t.default_font = sans
	t.default_font_size = 14
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("bold_font", "RichTextLabel", sans_xbold)
	t.set_font("normal_font", "RichTextLabel", sans)
	t.set_font("italics_font", "RichTextLabel", sans)
	var tip := box(Color("0f1918"), LINE, 4)
	tip.content_margin_left = 10
	tip.content_margin_right = 10
	tip.content_margin_top = 8
	tip.content_margin_bottom = 8
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 13)
	return t


static func box(bg: Color, border := LINE, radius := 6, bw := 1, shadow := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	if shadow > 0:
		s.shadow_color = Color(0, 0, 0, 0.35)
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, shadow * 0.4)
	return s


## A panel like .panel in the web CSS, placed absolutely.
static func panel(parent: Control, rect: Rect2, bg := PANEL_HI, border := LINE) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	var sb := box(bg, border, 6, 1, 14)
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	return p


static func label(parent: Node, text: String, font_size := 14, color := TEXT, font: Font = null, pos := Vector2.ZERO, width := 0.0) -> Label:
	init()
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", font if font else sans)
	l.position = pos
	if width > 0:
		l.size.x = width
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent:
		parent.add_child(l)
	return l


## Small uppercase caption like the web .sub class.
static func sub(parent: Node, text: String, pos := Vector2.ZERO, width := 0.0, size := 10) -> Label:
	var l := label(parent, text.to_upper(), size, MUTED, sans_bold, pos, width)
	return l


static func rich(parent: Node, pos: Vector2, size: Vector2, font_size := 13, color := TEXT) -> RichTextLabel:
	init()
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.position = pos
	r.size = size
	r.scroll_active = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", font_size)
	r.add_theme_font_size_override("bold_font_size", font_size)
	r.add_theme_color_override("default_color", color)
	r.add_theme_font_override("normal_font", sans)
	r.add_theme_font_override("bold_font", sans_xbold)
	if parent:
		parent.add_child(r)
	return r


## Buttons like the web .btn variants: "" (teal), "primary", "warm", "ghost"; size "big" | "small" | "mid".
static func button(text: String, kind := "", size := "big") -> Button:
	init()
	var b := Button.new()
	b.text = text.to_upper() if size == "small" else text
	var top := Color("36535a")
	var border := Color("8ea7a2")
	var fg := GOLD
	if kind == "warm":
		top = Color("5b4a38")
		border = Color("b39a7a")
	elif kind == "ghost":
		top = Color(0, 0, 0, 0)
		border = LINE
		fg = MUTED
	var normal := box(top, border, 3, 1, 0 if kind == "ghost" else 6)
	normal.content_margin_left = 22 if size != "small" else 12
	normal.content_margin_right = normal.content_margin_left
	normal.content_margin_top = 8 if size != "small" else 5
	normal.content_margin_bottom = normal.content_margin_top
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = top.lightened(0.15) if kind != "ghost" else Color(1, 1, 1, 0.05)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = top.darkened(0.15) if kind != "ghost" else Color(1, 1, 1, 0.08)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", normal)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg.lightened(0.15))
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_focus_color", fg)
	var fs := 22
	match size:
		"small": fs = 12
		"mid": fs = 16
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_font_override("font", sans_bold if size == "small" else serif)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


# ───── textures ─────
static func svg_texture(path: String, scale := 1.0, fill := "") -> Texture2D:
	var key := "%s@%s%s" % [path, scale, fill]
	if _tex.has(key):
		return _tex[key]
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var svg := f.get_as_text()
	if fill != "":
		svg = svg.replace("<svg ", '<svg fill="%s" ' % fill)
	var img := Image.new()
	if img.load_svg_from_string(svg, scale) != OK:
		return null
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t


static func png_texture(path: String) -> Texture2D:
	if _tex.has(path):
		return _tex[path]
	if not FileAccess.file_exists(path):
		return null
	var img := Image.new()
	if img.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return null
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[path] = t
	return t


## Painted PNG art when the team has made it (art/monster_<key>.png), else the web SVG.
static func monster_texture(art: String) -> Texture2D:
	var png := png_texture("res://art/monster_%s.png" % art)
	return png if png else svg_texture("res://art/monster_%s.svg" % art, 2.0)


static func hero_texture() -> Texture2D:
	var png := png_texture("res://art/hero.png")
	return png if png else svg_texture("res://art/hero.svg", 2.0)


## Component icon (24x24 line glyph from data.js) rasterised at px pixels.
static func comp_icon(id: String, px: int, color := "#2f6d52") -> Texture2D:
	var key := "icon:%s:%d:%s" % [id, px, color]
	if _tex.has(key):
		return _tex[key]
	var inner: String = GHData.icons.get(id, "")
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="%s" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">%s</svg>' % [color, inner.replace("currentColor", color)]
	var img := Image.new()
	if img.load_svg_from_string(svg, px / 24.0) != OK:
		return null
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t


## Two-decimal number formatting, as in the web G.fmt.
static func fmt(v) -> String:
	return Geo.fmt(v)


static func pad2(n) -> String:
	return "%02d" % int(n)
