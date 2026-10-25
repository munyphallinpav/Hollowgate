class_name HUD
extends CanvasLayer
## In-game heads-up display.

var root: Control
var name_lbl: Label
var hp_bar: ProgressBar
var hp_lbl: Label
var mp_bar: ProgressBar
var mp_lbl: Label
var xp_bar: ProgressBar
var sat_bar: ProgressBar
var gold_lbl: Label
var points_box: HBoxContainer
var buff_box: HBoxContainer
var skill_slots: Array = []
var item_slots: Array = []
var dash_bar: ProgressBar
var minimap: TextureRect
var mm_img: Image
var mm_tex: ImageTexture
var mm_marks: Control
var clock_lbl: Label
var loc_lbl: Label
var quest_box: VBoxContainer
var toast_box: VBoxContainer
var boss_panel: PanelContainer
var boss_bar: ProgressBar
var boss_lbl: Label
var prompt_lbl: Label
var tp_bar: ProgressBar
var vignette: ColorRect
var save_lbl: Label
var death_panel: Control
var hotbar_panel: PanelContainer
var mm_panel: PanelContainer
var _mm_t := 0.0
var _q_dirty := true
var _vig := 0.0
const MM_TILES := 72


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.theme()
	add_child(root)
	_build_vignette()
	_build_status()
	_build_hotbar()
	_build_minimap()
	_build_quests()
	_build_toasts()
	_build_boss()
	_build_prompts()
	Game.notify.connect(toast)
	Game.saved.connect(_on_saved)
	Game.quests_changed.connect(func(): _q_dirty = true)
	Game.inventory_changed.connect(func(): _q_dirty = true)


func _anchor(c: Control, preset: int, offset: Vector2) -> void:
	c.set_anchors_preset(preset)
	c.position = offset


# ---------------------------------------------------------------- builders
func _build_vignette() -> void:
	vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform float amount = 0.0;\nuniform vec4 tint : source_color = vec4(0.8,0.05,0.05,1.0);\nvoid fragment(){ float d = distance(UV, vec2(0.5)); COLOR = vec4(tint.rgb, smoothstep(0.35, 0.8, d) * amount); }"
	var m := ShaderMaterial.new()
	m.shader = sh
	vignette.material = m
	root.add_child(vignette)


func _build_status() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.sbox(Color(0.06, 0.055, 0.1, 0.78), UI.GOLD.darkened(0.45), 1, 4, 8))
	panel.position = Vector2(10, 10)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var v := UI.vbox(3)
	panel.add_child(v)
	name_lbl = UI.outlined(UI.label("", 16, Color("ffe9a8")))
	v.add_child(name_lbl)
	var hp_row := Control.new()
	hp_row.custom_minimum_size = Vector2(250, 18)
	hp_bar = UI.bar(Color("d8343e"), 250, 18)
	hp_row.add_child(hp_bar)
	hp_lbl = UI.outlined(UI.label("", 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	hp_lbl.size = Vector2(250, 18)
	hp_row.add_child(hp_lbl)
	v.add_child(hp_row)
	var mp_row := Control.new()
	mp_row.custom_minimum_size = Vector2(250, 14)
	mp_bar = UI.bar(Color("3a7ad8"), 250, 14)
	mp_row.add_child(mp_bar)
	mp_lbl = UI.outlined(UI.label("", 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	mp_lbl.size = Vector2(250, 14)
	mp_row.add_child(mp_lbl)
	v.add_child(mp_row)
	xp_bar = UI.bar(Color("e8c84a"), 250, 6)
	v.add_child(xp_bar)
	var h := UI.hbox(6)
	v.add_child(h)
	h.add_child(UI.icon(Art.icon("food_grilled_meat"), 16))
	sat_bar = UI.bar(Color("e48a3a"), 100, 8)
	sat_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sat_bar)
	h.add_child(UI.spacer(10))
	h.add_child(UI.icon(Art.icon("gold"), 16))
	gold_lbl = UI.outlined(UI.label("0", 14, Color("fee761")))
	h.add_child(gold_lbl)
	points_box = UI.hbox(6)
	v.add_child(points_box)
	buff_box = UI.hbox(4)
	buff_box.position = Vector2(12, 0)
	v.add_child(buff_box)


func _build_hotbar() -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.sbox(Color(0.06, 0.055, 0.1, 0.72), UI.GOLD.darkened(0.5), 1, 4, 6))
	hotbar_panel = bar
	root.add_child(bar)
	var h := UI.hbox(6)
	bar.add_child(h)
	for i in 4:
		var s := HotSlot.new("skill", i, 54)
		skill_slots.append(s)
		h.add_child(s)
	var dv := UI.vbox(2)
	dv.alignment = BoxContainer.ALIGNMENT_CENTER
	var dl := UI.outlined(UI.label("DASH", 10, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	dv.add_child(dl)
	dash_bar = UI.bar(Color("8fd3ff"), 34, 6)
	dv.add_child(dash_bar)
	h.add_child(dv)
	for i in 4:
		var s2 := HotSlot.new("item", i, 46)
		s2.size_flags_vertical = Control.SIZE_SHRINK_END
		item_slots.append(s2)
		h.add_child(s2)


func _build_minimap() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.sbox(Color(0.06, 0.055, 0.1, 0.8), UI.GOLD.darkened(0.4), 1, 4, 5))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mm_panel = panel
	root.add_child(panel)
	var v := UI.vbox(3)
	panel.add_child(v)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(176, 176)
	holder.clip_contents = true
	v.add_child(holder)
	minimap = TextureRect.new()
	minimap.size = Vector2(176, 176)
	minimap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	minimap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(minimap)
	mm_marks = Control.new()
	mm_marks.size = Vector2(176, 176)
	mm_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mm_marks.draw.connect(_draw_marks)
	holder.add_child(mm_marks)
	mm_img = Image.create_empty(MM_TILES, MM_TILES, false, Image.FORMAT_RGBA8)
	mm_tex = ImageTexture.create_from_image(mm_img)
	minimap.texture = mm_tex
	clock_lbl = UI.outlined(UI.label("", 13, Color("ffe9a8"), HORIZONTAL_ALIGNMENT_CENTER))
	clock_lbl.custom_minimum_size.x = 176
	v.add_child(clock_lbl)
	loc_lbl = UI.outlined(UI.label("", 12, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	loc_lbl.custom_minimum_size.x = 176
	loc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(loc_lbl)
	save_lbl = UI.outlined(UI.label("", 12, UI.GOOD, HORIZONTAL_ALIGNMENT_CENTER))
	save_lbl.custom_minimum_size.x = 176
	v.add_child(save_lbl)


func _build_quests() -> void:
	quest_box = UI.vbox(2)
	quest_box.custom_minimum_size = Vector2(250, 0)
	quest_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(quest_box)


func _build_toasts() -> void:
	toast_box = UI.vbox(2)
	toast_box.custom_minimum_size = Vector2(460, 230)
	toast_box.alignment = BoxContainer.ALIGNMENT_END
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)


func _build_boss() -> void:
	boss_panel = PanelContainer.new()
	boss_panel.add_theme_stylebox_override("panel", UI.sbox(Color(0.06, 0.03, 0.05, 0.8), Color("a22633"), 1, 4, 6))
	boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(boss_panel)
	var v := UI.vbox(2)
	boss_panel.add_child(v)
	boss_lbl = UI.outlined(UI.label("", 16, Color("ff9a8a"), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(boss_lbl)
	boss_bar = UI.bar(Color("c02a38"), 500, 16)
	v.add_child(boss_bar)
	boss_panel.visible = false


func _build_prompts() -> void:
	prompt_lbl = UI.outlined(UI.label("", 16, Color("ffe9a8"), HORIZONTAL_ALIGNMENT_CENTER), 5)
	prompt_lbl.size = Vector2(500, 24)
	root.add_child(prompt_lbl)
	tp_bar = UI.bar(Color("8fd3ff"), 200, 10)
	tp_bar.visible = false
	root.add_child(tp_bar)
	death_panel = CenterContainer.new()
	death_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dl := UI.outlined(UI.label("You have fallen...", 40, Color("ff6a6a"), HORIZONTAL_ALIGNMENT_CENTER), 8)
	death_panel.add_child(dl)
	death_panel.visible = false
	root.add_child(death_panel)


# ---------------------------------------------------------------- update
func _layout() -> void:
	var vp := root.size
	if hotbar_panel:
		hotbar_panel.position = Vector2(round((vp.x - hotbar_panel.size.x) * 0.5), vp.y - hotbar_panel.size.y - 10)
	if mm_panel:
		mm_panel.visible = Settings.show_minimap
		mm_panel.position = Vector2(vp.x - mm_panel.size.x - 10, 10)
		quest_box.position = Vector2(vp.x - 262, (mm_panel.position.y + mm_panel.size.y + 10) if mm_panel.visible else 10.0)
	toast_box.position = Vector2(12, vp.y - toast_box.size.y - (hotbar_panel.size.y + 24 if hotbar_panel and hotbar_panel.position.x < 480 else 12))
	boss_panel.position = Vector2(round((vp.x - boss_panel.size.x) * 0.5), 12)
	prompt_lbl.position = Vector2(round((vp.x - prompt_lbl.size.x) * 0.5), (hotbar_panel.position.y if hotbar_panel else vp.y) - 36)
	tp_bar.position = Vector2(round((vp.x - tp_bar.size.x) * 0.5), vp.y * 0.5 + 60)


func _process(delta: float) -> void:
	if Game.player.is_empty():
		return
	_layout()
	var p = Game.player_node
	var st := Game.stats
	name_lbl.text = "%s  •  %s  Lv %d" % [Game.player["name"], GameData.CLASSES[Game.player["class"]]["name"], int(Game.player["level"])]
	if p and is_instance_valid(p):
		hp_bar.max_value = p.max_hp
		hp_bar.value = p.hp
		hp_lbl.text = "%d / %d" % [int(p.hp), int(p.max_hp)] + ("  (+%d)" % int(p.shield) if p.shield > 0 else "")
		mp_bar.max_value = p.max_mp
		mp_bar.value = p.mp
		mp_lbl.text = "%d / %d" % [int(p.mp), int(p.max_mp)]
		dash_bar.max_value = 1.0
		dash_bar.value = 1.0 - clampf(p.dash_cd / Player.DASH_BASE_CD, 0.0, 1.0)
		var tp: float = p.teleport_progress()
		tp_bar.visible = tp >= 0.0
		tp_bar.value = tp * 100.0
		if p.interact_target and is_instance_valid(p.interact_target):
			prompt_lbl.text = "[%s] %s" % [Settings.action_text("interact"), _interact_name(p.interact_target)]
		else:
			prompt_lbl.text = ""
		death_panel.visible = p.dead
		_update_buffs(p)
		if p.hp < p.max_hp * 0.25 and not p.dead:
			_vig = maxf(_vig, 0.25 + 0.15 * sin(Time.get_ticks_msec() * 0.006))
	var lv := int(Game.player["level"])
	xp_bar.max_value = GameData.xp_to_next(lv)
	xp_bar.value = int(Game.player["xp"])
	sat_bar.max_value = 100.0
	sat_bar.value = float(Game.player["satiety"])
	gold_lbl.text = str(int(Game.player["gold"]))
	_update_points()
	_vig = maxf(0.0, _vig - delta * 1.8)
	(vignette.material as ShaderMaterial).set_shader_parameter("amount", _vig)
	clock_lbl.text = Game.clock_text()
	var lvn = Game.level_node
	if lvn:
		loc_lbl.text = _location_text(lvn)
		var show_boss := false
		if lvn is DungeonLevel and lvn.boss_visible():
			show_boss = true
		elif lvn.boss and is_instance_valid(lvn.boss) and not lvn.boss.dead and lvn.boss.target != null:
			show_boss = true
		boss_panel.visible = show_boss
		if show_boss:
			var b: Monster = lvn.boss
			boss_lbl.text = "%s  (Lv %d)%s" % [b.display_name, b.level, "  — ENRAGED" if b.enraged else ""]
			boss_bar.max_value = b.max_hp
			boss_bar.value = b.hp
	_mm_t -= delta
	if _mm_t <= 0.0:
		_mm_t = 0.35
		_update_minimap()
	mm_marks.queue_redraw()
	if _q_dirty:
		_q_dirty = false
		_update_quests()


func _interact_name(t: Node) -> String:
	if t is NPC:
		return "Talk to " + t.npc_name
	if t is Chest:
		return "Open chest"
	if t is Portal:
		match t.kind:
			"entrance":
				return "Enter dungeon (Rank %d)" % int(t.dungeon.get("rank", 1))
			"exit":
				return "Leave dungeon"
			"waypoint":
				return "Use waypoint"
	return "Interact"


func _location_text(lvn) -> String:
	if lvn is DungeonLevel:
		return "%s  •  Rank %d" % [lvn.design.get("name", "Dungeon"), int(lvn.design.get("rank", 1))]
	if lvn is Overworld and lvn.player:
		var t: Vector2i = lvn.tile_of(lvn.player.global_position)
		if lvn.gen.in_town(t.x, t.y):
			return "Hollowgate (Safe Town)"
		var b: String = lvn.gen.biome_at(t.x, t.y)
		return "%s  •  Monster Lv ~%d" % [GameData.BIOMES[b]["name"], lvn.gen.level_at(t.x, t.y)]
	return ""


func _update_points() -> void:
	var sp := int(Game.player["stat_points"])
	var kp := int(Game.player["skill_points"])
	var want := "%d|%d" % [sp, kp]
	if points_box.get_meta("k", "") == want:
		return
	points_box.set_meta("k", want)
	for c in points_box.get_children():
		c.queue_free()
	if sp > 0:
		var b := UI.button("+%d Stat pts (%s)" % [sp, Settings.action_text("open_character")], func(): Game.main.open_menu("character"))
		b.add_theme_font_size_override("font_size", 12)
		points_box.add_child(b)
	if kp > 0:
		var b2 := UI.button("+%d Skill pts (%s)" % [kp, Settings.action_text("open_skills")], func(): Game.main.open_menu("skills"))
		b2.add_theme_font_size_override("font_size", 12)
		points_box.add_child(b2)


func _update_buffs(p) -> void:
	var key := ""
	for id in p.buffs:
		key += id + str(int(p.buffs[id]["t"])) + ","
	for id in p.statuses:
		key += "s" + id + str(int(p.statuses[id]["t"])) + ","
	if buff_box.get_meta("k", "") == key:
		return
	buff_box.set_meta("k", key)
	for c in buff_box.get_children():
		c.queue_free()
	for id in p.buffs:
		var b: Dictionary = p.buffs[id]
		buff_box.add_child(_buff_chip(b["name"], b["color"], float(b["t"]), true, b["mods"]))
	for id in p.statuses:
		var s: Dictionary = p.statuses[id]
		buff_box.add_child(_buff_chip(GameData.WorldData.STATUS[id]["name"], GameData.WorldData.STATUS[id]["color"], float(s["t"]), false, {}))


func _buff_chip(nm: String, col: Color, t: float, good: bool, mods: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.sbox(col.darkened(0.7), col if good else Color("ff6a6a"), 1, 3, 3))
	var l := UI.outlined(UI.label("%s %ds" % [nm.left(10), int(t)], 11, col.lightened(0.3)))
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var lines := []
	for k in mods:
		lines.append(GameData.format_mod(k, mods[k]))
	var tip := "[b]%s[/b]\n%s" % [nm, "\n".join(lines)]
	p.mouse_entered.connect(func(): Game.main.tooltip.show_text(tip, 200))
	p.mouse_exited.connect(func(): Game.main.tooltip.hide_tip())
	return p


func _update_quests() -> void:
	for c in quest_box.get_children():
		c.queue_free()
	if Game.player.is_empty() or Game.player["quests"].is_empty():
		return
	quest_box.add_child(UI.outlined(UI.label("Quests (%s)" % Settings.action_text("open_quests"), 14, Color("ffe9a8"))))
	for q in Game.player["quests"]:
		var done := Quests.is_complete(q)
		var l := UI.outlined(UI.label("%s %s  %s" % ["(done)" if done else "-", q["title"], Quests.progress_text(q)], 13, UI.GOOD if done else UI.TEXT))
		quest_box.add_child(l)


# ---------------------------------------------------------------- minimap
func _update_minimap() -> void:
	var lvn = Game.level_node
	if lvn == null or lvn.player == null or not is_instance_valid(lvn.player):
		return
	mm_img.fill(Color(0.03, 0.03, 0.06, 1))
	var pt := Vector2i(int(lvn.player.global_position.x / 16.0), int(lvn.player.global_position.y / 16.0))
	var o := pt - Vector2i(MM_TILES / 2, MM_TILES / 2)
	if lvn is Overworld:
		var cs := WorldGen.CHUNK
		var c0 := Vector2i(int(floor(float(o.x) / cs)), int(floor(float(o.y) / cs)))
		for cy in range(c0.y, c0.y + MM_TILES / cs + 2):
			for cx in range(c0.x, c0.x + MM_TILES / cs + 2):
				var c := Vector2i(cx, cy)
				if not lvn.map_images.has(c):
					continue
				var im: Image = lvn.map_images[c]
				var dst := Vector2i(cx * cs - o.x, cy * cs - o.y)
				var src := Rect2i(0, 0, cs, cs)
				mm_img.blit_rect(im, src, dst)
	elif lvn is DungeonLevel:
		var dim := Rect2i(o, Vector2i(MM_TILES, MM_TILES)).intersection(Rect2i(0, 0, lvn.W, lvn.H))
		if dim.size.x > 0 and dim.size.y > 0:
			mm_img.blit_rect(lvn.map_image, dim, dim.position - o)
			# hide unvisited rooms
			var cs2: Vector2i = GameData.WorldData.CELL_SIZE
			for y in MM_TILES:
				for x in MM_TILES:
					var tx := o.x + x
					var ty := o.y + y
					if tx < 0 or ty < 0 or tx >= lvn.W or ty >= lvn.H:
						continue
					var cell := Vector2i(tx / cs2.x, ty / cs2.y)
					if not lvn.visited_rooms.has(cell):
						mm_img.set_pixel(x, y, Color(0.03, 0.03, 0.06, 1))
	mm_tex.update(mm_img)
	mm_marks.set_meta("o", o)


func _draw_marks() -> void:
	var lvn = Game.level_node
	if lvn == null or not mm_marks.has_meta("o"):
		return
	var o: Vector2i = mm_marks.get_meta("o")
	var scale := 176.0 / MM_TILES
	var font := mm_marks.get_theme_default_font()
	if lvn is Overworld:
		for d in Game.world["dungeons"]:
			var tp := (Vector2(d["tile"][0], d["tile"][1]) - Vector2(o)) * scale
			if Rect2(Vector2.ZERO, Vector2(176, 176)).has_point(tp):
				mm_marks.draw_circle(tp, 4.0, Portal.rank_color(int(d["rank"])))
				mm_marks.draw_arc(tp, 4.5, 0, TAU, 12, Color.BLACK, 1.0)
		for m in lvn.get_tree().get_nodes_in_group("monsters"):
			if is_instance_valid(m) and not m.dead:
				var mp: Vector2 = (m.global_position / 16.0 - Vector2(o)) * scale
				if Rect2(Vector2.ZERO, Vector2(176, 176)).has_point(mp):
					mm_marks.draw_circle(mp, 1.6, Color("ff5a5a") if not m.data.get("passive", false) else Color("f0e0c0"))
		var town := (Vector2(256, 256) - Vector2(o)) * scale
		if Rect2(Vector2.ZERO, Vector2(176, 176)).has_point(town):
			mm_marks.draw_rect(Rect2(town - Vector2(4, 4), Vector2(8, 8)), Color("fee761"), false, 2.0)
	elif lvn is DungeonLevel:
		for m in lvn.get_tree().get_nodes_in_group("monsters"):
			if is_instance_valid(m) and not m.dead and m.visible:
				var mp2: Vector2 = (m.global_position / 16.0 - Vector2(o)) * scale
				if Rect2(Vector2.ZERO, Vector2(176, 176)).has_point(mp2):
					mm_marks.draw_circle(mp2, 1.8 if m.tier == "normal" else 3.0, Color("ff5a5a") if m.tier != "boss" else Color("ff2a2a"))
	var pc := Vector2(88, 88)
	var p = lvn.player
	if p and is_instance_valid(p):
		var a: float = p.aim.angle()
		var tri := PackedVector2Array([pc + Vector2.from_angle(a) * 6.0, pc + Vector2.from_angle(a + 2.5) * 4.0, pc + Vector2.from_angle(a - 2.5) * 4.0])
		mm_marks.draw_colored_polygon(tri, Color("7be0ff"))
	mm_marks.draw_rect(Rect2(Vector2.ZERO, Vector2(176, 176)), Color(0, 0, 0, 0.6), false, 2.0)


# ---------------------------------------------------------------- feedback
func toast(text: String, color: Color = Color.WHITE) -> void:
	var l := UI.outlined(UI.label(text, 14, color), 4)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 460
	toast_box.add_child(l)
	while toast_box.get_child_count() > 7:
		toast_box.get_child(0).queue_free()
		toast_box.remove_child(toast_box.get_child(0))
	var tw := l.create_tween()
	tw.tween_interval(4.5)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)


func hurt_flash() -> void:
	_vig = 0.6


func _on_saved(auto: bool) -> void:
	save_lbl.text = "Auto-saved" if auto else "Game saved"
	save_lbl.modulate.a = 1.0
	var tw := save_lbl.create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(save_lbl, "modulate:a", 0.0, 1.0)
