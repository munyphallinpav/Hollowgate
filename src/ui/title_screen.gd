class_name TitleScreen
extends CanvasLayer
## Title screen: continue / new game (class select) / load / settings / quit.

var root: Control
var content: Control
var bg_time := 0.0
var sel_class := "warrior"
var name_edit: LineEdit
var sel_slot := 1
var preview_rects: Array = []
var _anim_t := 0.0
var _frame := 0
var class_info: RichTextLabel
var bg: Control


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.theme()
	add_child(root)
	bg = Control.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.draw.connect(_draw_bg)
	root.add_child(bg)
	content = Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(content)
	show_main()


func _process(delta: float) -> void:
	bg_time += delta
	bg.queue_redraw()
	_anim_t += delta
	if _anim_t > 0.16:
		_anim_t = 0.0
		_frame = (_frame + 1) % 6
		for pr in preview_rects:
			if is_instance_valid(pr):
				var sf := Art.frames("char_" + str(pr.get_meta("cls")))
				var anim := "walk_down" if pr.get_meta("cls") == sel_class else "idle_down"
				pr.texture = sf.get_frame_texture(anim, _frame % sf.get_frame_count(anim))


func _draw_bg() -> void:
	var s := bg.size
	var top := Color("0e0b1e")
	var bot := Color("2a1d3e")
	for i in 24:
		var y0 := s.y * i / 24.0
		bg.draw_rect(Rect2(0, y0, s.x, s.y / 24.0 + 1), top.lerp(bot, i / 23.0))
	# stars
	for i in 70:
		var x := fmod(i * 137.5, s.x)
		var y := fmod(i * 71.3, s.y * 0.6)
		var a := 0.4 + 0.4 * sin(bg_time * 2.0 + i)
		bg.draw_rect(Rect2(x, y, 2, 2), Color(1, 1, 1, a))
	# moon
	bg.draw_circle(Vector2(s.x * 0.82, s.y * 0.18), 40, Color("f4ecd0"))
	bg.draw_circle(Vector2(s.x * 0.82 + 14, s.y * 0.18 - 8), 34, Color("15112a").lerp(top, 0.2))
	# mountains silhouette
	var pts := PackedVector2Array([Vector2(0, s.y)])
	for i in 13:
		var x2 := s.x * i / 12.0
		pts.append(Vector2(x2, s.y * 0.62 - (sin(i * 1.7) * 0.5 + 0.5) * 120.0 - (i % 3) * 30.0))
	pts.append(Vector2(s.x, s.y))
	bg.draw_colored_polygon(pts, Color("1a1430"))
	# town wall + towers
	var wy := s.y * 0.78
	bg.draw_rect(Rect2(0, wy, s.x, s.y - wy), Color("120e22"))
	for i in 9:
		var tx := s.x * (0.06 + i * 0.11)
		bg.draw_rect(Rect2(tx - 22, wy - 70, 44, 70), Color("120e22"))
		for k in 3:
			bg.draw_rect(Rect2(tx - 22 + k * 16, wy - 82, 10, 12), Color("120e22"))
		var glow := 0.6 + 0.4 * sin(bg_time * 3.0 + i)
		bg.draw_rect(Rect2(tx - 4, wy - 50, 8, 12), Color(1.0, 0.75, 0.35, glow))
	# fireflies
	for i in 18:
		var fx := fmod(i * 97.0 + bg_time * (10 + i), s.x)
		var fy := s.y * 0.7 + sin(bg_time + i) * 40.0
		bg.draw_circle(Vector2(fx, fy), 2.0, Color(1, 0.9, 0.5, 0.5 + 0.5 * sin(bg_time * 4.0 + i)))


func _clear() -> void:
	for c in content.get_children():
		c.queue_free()
	preview_rects.clear()


func _title(parent: Control) -> void:
	var t := UI.outlined(UI.label("HOLLOWGATE", 72, Color("ffd27a"), HORIZONTAL_ALIGNMENT_CENTER), 12)
	t.set_anchors_preset(Control.PRESET_CENTER_TOP)
	t.position = Vector2(-400, 50)
	t.size = Vector2(800, 90)
	parent.add_child(t)
	var st := UI.outlined(UI.label("A pixel action RPG of hidden dungeons", 20, Color("c8b8ff"), HORIZONTAL_ALIGNMENT_CENTER), 6)
	st.set_anchors_preset(Control.PRESET_CENTER_TOP)
	st.position = Vector2(-400, 140)
	st.size = Vector2(800, 30)
	parent.add_child(st)


func show_main() -> void:
	_clear()
	_title(content)
	var box := UI.vbox(10)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-140, -40)
	box.custom_minimum_size = Vector2(280, 0)
	content.add_child(box)
	var latest := _latest_slot()
	if latest > 0:
		var inf := Game.slot_info(latest)
		var b := UI.button("Continue  (%s Lv %d)" % [inf.get("name", "?"), int(inf.get("level", 1))], func(): Game.main.load_slot(latest), 280)
		b.add_theme_font_size_override("font_size", 18)
		box.add_child(b)
	for e in [["New Game", show_new], ["Load Game", show_load], ["Settings", show_settings], ["Quit", func(): get_tree().quit()]]:
		var b2 := UI.button(e[0], e[1], 280)
		b2.add_theme_font_size_override("font_size", 18)
		box.add_child(b2)
	var hint := UI.outlined(UI.label("WASD move • Mouse aim & attack • Space dash • 1-4 skills • Z X C V items • E interact • T teleport to town • I/P/K/J/M/B menus • Esc menu", 13, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-560, -40)
	hint.size = Vector2(1120, 20)
	content.add_child(hint)


func _latest_slot() -> int:
	var best := 0
	var best_date := ""
	for s in range(1, Game.SAVE_SLOTS + 1):
		var inf := Game.slot_info(s)
		if not inf.is_empty() and str(inf["date"]) >= best_date:
			best_date = str(inf["date"])
			best = s
	return best


func show_new() -> void:
	_clear()
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-560, -300)
	panel.custom_minimum_size = Vector2(1120, 600)
	content.add_child(panel)
	var v := UI.vbox(10)
	panel.add_child(v)
	v.add_child(UI.label("Choose your class", 26, Color("ffe9a8")))
	var row := UI.hbox(12)
	v.add_child(row)
	for c in GameData.CLASSES:
		var cd: Dictionary = GameData.CLASSES[c]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(208, 250)
		var sel = c == sel_class
		card.add_theme_stylebox_override("panel", UI.sbox(Color("201f36") if not sel else Color("2c2a52"), cd["color"] if sel else Color("4a4568"), 3 if sel else 1, 6, 8))
		var cv := UI.vbox(4)
		card.add_child(cv)
		var pr := UI.icon(null, 128)
		pr.set_meta("cls", c)
		preview_rects.append(pr)
		cv.add_child(pr)
		cv.add_child(UI.label(cd["name"], 20, cd["color"], HORIZONTAL_ALIGNMENT_CENTER))
		cv.add_child(UI.label(cd["role"], 13, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
		cv.add_child(UI.label("Weapon: " + cd["weapon"].capitalize(), 13, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		var cc: String = c
		var btn := UI.button("Select" if not sel else "Selected", func():
			sel_class = cc
			show_new())
		cv.add_child(btn)
		card.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed:
				sel_class = cc
				show_new())
		row.add_child(card)
	var cd2: Dictionary = GameData.CLASSES[sel_class]
	var stats_txt := ""
	for st in GameData.WorldData.MAIN_STATS:
		var val := int(cd2["base"][st])
		stats_txt += "[color=#ffe9a8]%s[/color] %d  %s   " % [GameData.WorldData.STAT_NAMES[st], val, "|".repeat(val / 2)]
		if st == "int":
			stats_txt += "\n"
	var skills_txt := []
	for id in GameData.skills_for(sel_class):
		if GameData.SKILLS[id]["type"] == "active":
			skills_txt.append(GameData.SKILLS[id]["name"])
	class_info = UI.rich("[b]%s[/b] — %s\n%s\n[color=#9c97b8]Active skills: %s[/color]" % [cd2["name"], cd2["desc"], stats_txt, ", ".join(skills_txt)], 14)
	v.add_child(class_info)
	var h := UI.hbox(10)
	v.add_child(h)
	h.add_child(UI.label("Name:", 16))
	name_edit = LineEdit.new()
	name_edit.text = ["Aria", "Bran", "Kael", "Lyra", "Rowan", "Sera", "Torin"][randi() % 7]
	name_edit.max_length = 16
	name_edit.custom_minimum_size.x = 200
	h.add_child(name_edit)
	h.add_child(UI.spacer(20))
	h.add_child(UI.label("Save slot:", 16))
	for s in range(1, Game.SAVE_SLOTS + 1):
		var inf := Game.slot_info(s)
		var ss: int = s
		var b := UI.button("%d%s" % [s, "" if inf.is_empty() else " (used)"], func():
			sel_slot = ss
			show_new())
		b.toggle_mode = true
		b.button_pressed = s == sel_slot
		h.add_child(b)
	var h2 := UI.hbox(10)
	h2.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(h2)
	h2.add_child(UI.button("Back", show_main, 120))
	var start := UI.button("Begin Adventure", func():
		var nm := name_edit.text.strip_edges()
		if nm == "":
			nm = "Hero"
		if not Game.slot_info(sel_slot).is_empty():
			Dialogs.confirm(content, "Overwrite save", "Slot %d already has a save. Overwrite it?" % sel_slot, func(): Game.main.start_new_game(nm, sel_class, sel_slot), "Overwrite")
		else:
			Game.main.start_new_game(nm, sel_class, sel_slot), 220)
	start.add_theme_font_size_override("font_size", 18)
	h2.add_child(start)


func show_load() -> void:
	_clear()
	_title(content)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-420, -110)
	panel.custom_minimum_size = Vector2(840, 300)
	content.add_child(panel)
	var v := UI.vbox(10)
	panel.add_child(v)
	v.add_child(UI.label("Load Game", 22, Color("ffe9a8")))
	for s in range(1, Game.SAVE_SLOTS + 1):
		var inf := Game.slot_info(s)
		var row := UI.hbox(10)
		var txt := "Slot %d — empty" % s
		if not inf.is_empty():
			txt = "Slot %d — %s, %s Lv %d — Day %d — played %s — %s" % [s, inf["name"], GameData.CLASSES.get(inf["class"], {"name": "?"})["name"], int(inf["level"]), int(inf["day"]), UI.fmt_time(float(inf["playtime"])), inf["date"]]
		var l := UI.label(txt, 15)
		l.custom_minimum_size.x = 600
		row.add_child(l)
		if not inf.is_empty():
			var ss: int = s
			row.add_child(UI.button("Load", func(): Game.main.load_slot(ss)))
			row.add_child(UI.button("Delete", func():
				Dialogs.confirm(content, "Delete save", "Permanently delete slot %d?" % ss, func():
					Game.delete_slot(ss)
					show_load(), "Delete")))
		v.add_child(row)
	v.add_child(UI.button("Back", show_main, 120))


func show_settings() -> void:
	_clear()
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-520, -290)
	panel.custom_minimum_size = Vector2(1040, 580)
	content.add_child(panel)
	var v := UI.vbox(8)
	panel.add_child(v)
	v.add_child(UI.label("Settings", 22, Color("ffe9a8")))
	v.add_child(SettingsPage.new())
	v.add_child(UI.button("Back", show_main, 120))
