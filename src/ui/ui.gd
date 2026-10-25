class_name UI
extends RefCounted
## Theme + small factory helpers for building the interface in code.

const BG := Color("161526")
const BG2 := Color("201f36")
const BG3 := Color("2c2a48")
const GOLD := Color("d9b46a")
const TEXT := Color("efe6d2")
const DIM := Color("9c97b8")
const GOOD := Color("7be05a")
const BAD := Color("ff6a6a")

static var _theme: Theme


static func sbox(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, radius: int = 3, margin: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin * 0.7
	s.content_margin_bottom = margin * 0.7
	s.anti_aliasing = false
	return s


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 15
	var panel := sbox(Color(BG, 0.97), GOLD.darkened(0.25), 2, 4, 10)
	panel.shadow_color = Color(0, 0, 0, 0.45)
	panel.shadow_size = 6
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("normal", "Button", sbox(BG3, Color("5a547e"), 1, 3, 8))
	t.set_stylebox("hover", "Button", sbox(Color("3d3a62"), GOLD.darkened(0.1), 1, 3, 8))
	t.set_stylebox("pressed", "Button", sbox(Color("514c80"), GOLD, 1, 3, 8))
	t.set_stylebox("disabled", "Button", sbox(Color("1e1d30"), Color("38354f"), 1, 3, 8))
	t.set_stylebox("focus", "Button", sbox(Color(0, 0, 0, 0), GOLD.darkened(0.3), 1, 3, 8))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color("fff4d8"))
	t.set_color("font_disabled_color", "Button", Color("6a6588"))
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("normal", "LineEdit", sbox(Color("0f0e1c"), Color("5a547e"), 1, 3, 6))
	t.set_stylebox("focus", "LineEdit", sbox(Color("0f0e1c"), GOLD, 1, 3, 6))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("panel", "TabContainer", sbox(Color(BG2, 0.6), Color(0, 0, 0, 0), 0, 3, 8))
	t.set_stylebox("tab_selected", "TabContainer", sbox(Color("3d3a62"), GOLD, 1, 3, 10))
	t.set_stylebox("tab_unselected", "TabContainer", sbox(BG3, Color("4a4568"), 1, 3, 10))
	t.set_stylebox("tab_hovered", "TabContainer", sbox(Color("35325a"), Color("6a6390"), 1, 3, 10))
	t.set_color("font_selected_color", "TabContainer", Color("ffe9a8"))
	t.set_color("font_unselected_color", "TabContainer", DIM)
	t.set_stylebox("tab_selected", "TabBar", sbox(Color("3d3a62"), GOLD, 1, 3, 10))
	t.set_stylebox("tab_unselected", "TabBar", sbox(BG3, Color("4a4568"), 1, 3, 10))
	t.set_stylebox("tab_hovered", "TabBar", sbox(Color("35325a"), Color("6a6390"), 1, 3, 10))
	t.set_color("font_selected_color", "TabBar", Color("ffe9a8"))
	t.set_color("font_unselected_color", "TabBar", DIM)
	t.set_stylebox("background", "ProgressBar", sbox(Color("0d0c18"), Color("3a3656"), 1, 2, 0))
	t.set_stylebox("fill", "ProgressBar", sbox(Color("e43b44"), Color(0, 0, 0, 0), 0, 2, 0))
	t.set_stylebox("panel", "PopupMenu", sbox(BG, GOLD.darkened(0.3), 1, 3, 6))
	t.set_stylebox("hover", "PopupMenu", sbox(Color("3d3a62"), Color(0, 0, 0, 0), 0, 2, 4))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_stylebox("panel", "TooltipPanel", sbox(BG, GOLD, 1, 3, 8))
	t.set_stylebox("grabber_area", "HSlider", sbox(GOLD.darkened(0.2), Color(0, 0, 0, 0), 0, 2, 0))
	t.set_stylebox("slider", "HSlider", sbox(Color("0d0c18"), Color("3a3656"), 1, 2, 2))
	t.set_stylebox("scroll", "VScrollBar", sbox(Color("0d0c18"), Color(0, 0, 0, 0), 0, 2, 0))
	t.set_stylebox("grabber", "VScrollBar", sbox(Color("4a4568"), Color(0, 0, 0, 0), 0, 2, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", sbox(Color("6a6390"), Color(0, 0, 0, 0), 0, 2, 0))
	t.set_stylebox("normal", "OptionButton", sbox(BG3, Color("5a547e"), 1, 3, 8))
	t.set_stylebox("hover", "OptionButton", sbox(Color("3d3a62"), GOLD.darkened(0.1), 1, 3, 8))
	t.set_stylebox("pressed", "OptionButton", sbox(Color("514c80"), GOLD, 1, 3, 8))
	t.set_color("font_color", "OptionButton", TEXT)
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		t.set_stylebox(st, "CheckBox", StyleBoxEmpty.new())
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", Color("fff4d8"))
	t.set_color("font_pressed_color", "CheckBox", Color("ffe9a8"))
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_stylebox("normal", "SpinBox", sbox(Color("0f0e1c"), Color("5a547e"), 1, 3, 4))
	_theme = t
	return t


static func label(text: String, size: int = 15, color: Color = TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l


static func outlined(l: Label, w: int = 4) -> Label:
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.07))
	l.add_theme_constant_override("outline_size", w)
	return l


static func rich(bb: String = "", size: int = 14) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = bb
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size + 1)
	return r


static func button(text: String, cb: Callable = Callable(), min_w: int = 0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if min_w > 0:
		b.custom_minimum_size.x = min_w
	if cb.is_valid():
		b.pressed.connect(cb)
	b.pressed.connect(func(): Sfx.play("click", 0.05, 0.6))
	return b


static func hbox(sep: int = 6) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep: int = 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func icon(tex: Texture2D, size: int = 32) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func bar(color: Color, w: int = 200, h: int = 14) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_stylebox_override("fill", sbox(color, Color(0, 0, 0, 0), 0, 2, 0))
	b.add_theme_stylebox_override("background", sbox(Color("0d0c18"), Color("3a3656"), 1, 2, 0))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func spacer(w: int = 0, h: int = 0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func expand(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func sep() -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_stylebox_override("separator", sbox(Color(GOLD, 0.25), Color(0, 0, 0, 0), 0, 0, 0))
	s.custom_minimum_size.y = 6
	return s


static func scroll(child: Control, min_size: Vector2 = Vector2.ZERO) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.custom_minimum_size = min_size
	s.add_child(child)
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


static func element_panel(el: String, size: int = 40) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(size, size)
	var c := GameData.element_color(el) if el != "none" else Color("8b9bb4")
	p.add_theme_stylebox_override("panel", sbox(c.darkened(0.55), c, 2, 4, 0))
	return p


## Skill icon: element-coloured frame with the white glyph tinted toward the element colour.
static func skill_icon(sid: String, size: int = 40) -> Panel:
	var s: Dictionary = GameData.SKILLS[sid]
	var el: String = s.get("el", "none")
	var p := element_panel(el, size)
	if s["type"] == "passive":
		p.add_theme_stylebox_override("panel", sbox(Color("23223a"), (GameData.element_color(el) if el != "none" else Color("b8b0a0")).darkened(0.1), 2, size / 2, 0))
	var ic := icon(Art.glyph(s.get("glyph", "star")), size - 8)
	ic.position = Vector2(4, 4)
	ic.size = Vector2(size - 8, size - 8)
	ic.modulate = (GameData.element_color(el) if el != "none" else Color.WHITE).lightened(0.55)
	p.add_child(ic)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p


static func fmt_time(sec: float) -> String:
	var s := int(sec)
	if s >= 3600:
		return "%dh %02dm" % [s / 3600, (s % 3600) / 60]
	return "%d:%02d" % [s / 60, s % 60]
