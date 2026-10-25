class_name SkillsPage
extends HBoxContainer
## Class + Common skill trees with prerequisites, details, learning and hotbar assignment (drag & drop).

const NODE := 52
const DX := 112
const DY := 88

var tabs: TabBar
var canvas: Control
var detail: RichTextLabel
var learn_box: HBoxContainer
var assign_box: HBoxContainer
var points_lbl: Label
var tree_cls := ""
var selected := ""
var nodes: Dictionary = {}
var hot: Array = []


class SkillNode extends Control:
	var sid := ""
	var page
	var icon_panel: Panel
	var lv_lbl: Label
	var lock: ColorRect

	func _init(id: String, pg) -> void:
		sid = id
		page = pg
		custom_minimum_size = Vector2(52, 52)
		size = Vector2(52, 52)
		mouse_filter = Control.MOUSE_FILTER_STOP
		icon_panel = UI.skill_icon(id, 52)
		icon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon_panel)
		lock = ColorRect.new()
		lock.color = Color(0, 0, 0, 0.55)
		lock.size = Vector2(52, 52)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lock)
		lv_lbl = UI.outlined(UI.label("", 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
		lv_lbl.position = Vector2(-14, 52)
		lv_lbl.size = Vector2(80, 16)
		add_child(lv_lbl)
		mouse_entered.connect(func():
			var lv := maxi(1, Game.skill_level(sid))
			Game.main.tooltip.show_text("[b]%s[/b]\n%s" % [GameData.SKILLS[sid]["name"], GameData.skill_description(sid, lv)], 320))
		mouse_exited.connect(func(): Game.main.tooltip.hide_tip())

	func refresh() -> void:
		var lv := Game.skill_level(sid)
		var mx := int(GameData.SKILLS[sid]["max"])
		lv_lbl.text = "%d/%d" % [lv, mx]
		var reason := Game.skill_unlock_reason(sid)
		lock.visible = lv == 0 and reason != ""
		lv_lbl.add_theme_color_override("font_color", Color("fee761") if lv >= mx else (Color.WHITE if lv > 0 else UI.DIM))
		modulate = Color(1, 1, 1) if lv > 0 or reason == "" else Color(0.75, 0.75, 0.8)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			page.select(sid)
			if e.double_click:
				Game.learn_skill(sid, 1)
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
			page.select(sid)
			Game.learn_skill(sid, 1)

	func _get_drag_data(_p):
		if GameData.SKILLS[sid]["type"] != "active" or Game.skill_level(sid) <= 0:
			return null
		var pv := Control.new()
		var ic := UI.skill_icon(sid, 40)
		ic.position = Vector2(-20, -20)
		pv.add_child(ic)
		set_drag_preview(pv)
		Game.main.tooltip.hide_tip()
		return {"type": "skill", "id": sid}

	func _draw() -> void:
		if page.selected == sid:
			draw_rect(Rect2(Vector2(-4, -4), size + Vector2(8, 8)), Color("fee761"), false, 2.0)


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	var left := UI.vbox(6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(left)
	var top := UI.hbox(10)
	left.add_child(top)
	tabs = TabBar.new()
	tabs.add_tab(GameData.CLASSES[Game.player["class"]]["name"] + " Tree")
	tabs.add_tab("Common Tree")
	tabs.focus_mode = Control.FOCUS_NONE
	tabs.clip_tabs = false
	tabs.custom_minimum_size.x = 300
	tabs.tab_changed.connect(func(i): _build_tree("common" if i == 1 else Game.player["class"]))
	top.add_child(tabs)
	points_lbl = UI.label("", 16, Color("fee761"))
	top.add_child(points_lbl)
	canvas = Control.new()
	canvas.custom_minimum_size = Vector2(700, 470)
	canvas.draw.connect(_draw_links)
	left.add_child(canvas)
	var hb := UI.hbox(8)
	left.add_child(hb)
	hb.add_child(UI.label("Active skill slots (max 4) — drag skills here:", 14, UI.DIM))
	for i in 4:
		var s := HotSlot.new("skill", i, 50)
		hot.append(s)
		hb.add_child(s)
	var right := UI.vbox(8)
	right.custom_minimum_size.x = 380
	add_child(right)
	detail = UI.rich("", 14)
	detail.custom_minimum_size = Vector2(380, 330)
	detail.fit_content = false
	detail.scroll_active = true
	right.add_child(detail)
	learn_box = UI.hbox(6)
	right.add_child(learn_box)
	assign_box = UI.hbox(6)
	right.add_child(assign_box)
	right.add_child(UI.rich("[color=#9c97b8]Right-click or double-click a skill to put a point in it. Each tier unlocks at a character level and needs points in the skill above it. Only 4 active skills can be equipped. Tome skills are learned from spellbooks sold at the Magic Shop.[/color]", 12))
	Game.skills_changed.connect(refresh)
	Game.player_changed.connect(refresh)
	_build_tree(Game.player["class"])


func _build_tree(cls: String) -> void:
	tree_cls = cls
	for c in canvas.get_children():
		c.queue_free()
	nodes.clear()
	var ids := GameData.skills_for(cls)
	var tiers: Array = GameData.SkillData.TIER_LEVELS if cls != "common" else GameData.COMMON_TIER_LEVELS
	var max_col := 0
	for id in ids:
		max_col = maxi(max_col, int(GameData.SKILLS[id]["col"]))
	var x0 := 80
	for r in tiers.size():
		var any := false
		for id in ids:
			if int(GameData.SKILLS[id]["row"]) == r:
				any = true
		if not any:
			continue
		var tl := UI.label("Lv %d" % tiers[r] if not (cls == "common" and r == 3) else "Tomes", 13, UI.DIM)
		if cls == "common" and r == 3:
			tl.text = "Tomes"
		tl.position = Vector2(4, 20 + r * DY + 14)
		canvas.add_child(tl)
	for id in ids:
		var s: Dictionary = GameData.SKILLS[id]
		var n := SkillNode.new(id, self)
		var dx := DX if max_col < 4 else 98
		n.position = Vector2(x0 + int(s["col"]) * dx, 20 + int(s["row"]) * DY)
		canvas.add_child(n)
		nodes[id] = n
		n.refresh()
	if cls == "common":
		var l := UI.label("Square = Active   Round = Passive", 12, UI.DIM)
		l.position = Vector2(500, 0)
		canvas.add_child(l)
	if selected == "" or not nodes.has(selected):
		selected = ids[0]
	canvas.queue_redraw()
	refresh()


func _draw_links() -> void:
	for id in nodes:
		var s: Dictionary = GameData.SKILLS[id]
		for r in s.get("req", {}):
			if not nodes.has(r):
				continue
			var a: Vector2 = nodes[r].position + Vector2(NODE / 2.0, NODE + 14)
			var b: Vector2 = nodes[id].position + Vector2(NODE / 2.0, -2)
			var met := Game.skill_level(r) >= int(s["req"][r])
			var col := Color("fee761") if met else Color("4a4568")
			var mid := (a.y + b.y) * 0.5
			canvas.draw_polyline(PackedVector2Array([a, Vector2(a.x, mid), Vector2(b.x, mid), b]), col, 2.0)
			canvas.draw_string(get_theme_default_font(), Vector2((a.x + b.x) * 0.5 + 4, mid - 3), "%d" % int(s["req"][r]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)


func select(id: String) -> void:
	selected = id
	for n in nodes.values():
		n.queue_redraw()
	refresh()


func refresh() -> void:
	if Game.player.is_empty() or not is_inside_tree():
		return
	points_lbl.text = "Skill points: %d" % int(Game.player["skill_points"])
	for n in nodes.values():
		n.refresh()
	canvas.queue_redraw()
	if selected == "" or not GameData.SKILLS.has(selected):
		return
	var s: Dictionary = GameData.SKILLS[selected]
	var lv := Game.skill_level(selected)
	var mx := int(s["max"])
	var el: String = s.get("el", "none")
	var txt := "[b][font_size=20]%s[/font_size][/b]\n" % s["name"]
	txt += "[color=#%s]%s[/color] • %s • Level %d / %d\n\n" % [GameData.element_color(el).to_html(false), el.capitalize() if el != "none" else "Neutral", s["type"].capitalize(), lv, mx]
	if lv > 0:
		txt += "[color=#ffe9a8]Current (Lv %d):[/color]\n%s\n\n" % [lv, GameData.skill_description(selected, lv)]
	if lv < mx:
		txt += "[color=#8fe8ff]%s (Lv %d):[/color]\n%s\n" % ["Next" if lv > 0 else "At level 1", lv + 1, GameData.skill_description(selected, lv + 1)]
	var reason := Game.skill_unlock_reason(selected)
	if reason != "":
		txt += "\n[color=#ff8a8a]Locked: %s[/color]" % reason
	detail.text = txt
	for c in learn_box.get_children():
		c.queue_free()
	for c in assign_box.get_children():
		c.queue_free()
	var can := Game.can_learn(selected)
	var b1 := UI.button("Learn +1", func(): Game.learn_skill(selected, 1))
	b1.disabled = not can
	learn_box.add_child(b1)
	var b5 := UI.button("+5", func(): Game.learn_skill(selected, 5))
	b5.disabled = not can
	learn_box.add_child(b5)
	var bm := UI.button("Max", func(): Game.learn_skill(selected, mx))
	bm.disabled = not can
	learn_box.add_child(bm)
	if s["type"] == "active" and lv > 0:
		assign_box.add_child(UI.label("Equip to:", 14, UI.DIM))
		for i in 4:
			var ii: int = i
			assign_box.add_child(UI.button(Settings.action_text("skill_%d" % (i + 1)), func(): Game.set_hot_skill(ii, selected)))
