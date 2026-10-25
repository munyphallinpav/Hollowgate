class_name HotSlot
extends Control
## Hotbar slot for skills (kind "skill") or consumables (kind "item"). Accepts drag & drop.

var kind := "skill"
var idx := 0
var font: Font
var _hover := false


func _init(k: String = "skill", i: int = 0, sz: int = 50) -> void:
	kind = k
	idx = i
	custom_minimum_size = Vector2(sz, sz)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func():
		_hover = true
		_tip())
	mouse_exited.connect(func():
		_hover = false
		if Game.main:
			Game.main.tooltip.hide_tip())


func _ready() -> void:
	font = get_theme_default_font()


func _process(_d: float) -> void:
	queue_redraw()


func _id() -> String:
	if Game.player.is_empty():
		return ""
	return Game.player["hot_skills"][idx] if kind == "skill" else Game.player["hot_items"][idx]


func _action() -> String:
	return ("skill_%d" if kind == "skill" else "item_%d") % (idx + 1)


func _draw() -> void:
	var sz := size
	var id := _id()
	var border := Color("5a547e")
	var bg := Color(0.06, 0.055, 0.1, 0.9)
	var el := "none"
	if id != "" and kind == "skill" and GameData.SKILLS.has(id):
		el = GameData.SKILLS[id].get("el", "none")
		border = GameData.element_color(el)
		bg = border.darkened(0.75)
	if _hover:
		border = Color("fee761")
	draw_rect(Rect2(Vector2.ZERO, sz), bg)
	draw_rect(Rect2(Vector2.ONE, sz - Vector2(2, 2)), border, false, 2.0)
	if id != "":
		var tex: Texture2D
		var mod := Color.WHITE
		if kind == "skill":
			tex = Art.glyph(GameData.SKILLS[id].get("glyph", "star"))
			mod = GameData.element_color(el).lightened(0.55)
		else:
			tex = Art.icon(GameData.item_template(id).get("icon", "quest"))
		var pad := 7.0
		var ok := true
		if kind == "skill" and is_instance_valid(Game.player_node):
			ok = Game.player_node.mp >= GameData.skill_mp(id, maxi(1, Game.skill_level(id)))
		if kind == "item" and Game.count_item(id) <= 0:
			ok = false
		if not ok:
			mod = mod.darkened(0.5)
		draw_texture_rect(tex, Rect2(Vector2(pad, pad), sz - Vector2(pad, pad) * 2.0), false, mod)
		# cooldown
		var r := 0.0
		if kind == "skill" and is_instance_valid(Game.player_node):
			r = Game.player_node.skill_cd_ratio(id)
		if r > 0.0:
			var c := sz * 0.5
			var pts := PackedVector2Array([c])
			var steps := 24
			for i in steps + 1:
				var a := -PI / 2.0 + TAU * r * float(i) / steps
				pts.append(c + Vector2(cos(a), sin(a)) * sz.x)
			draw_colored_polygon(pts, Color(0, 0, 0, 0.6))
			var left: float = Game.player_node.skill_cds.get(id, 0.0)
			_text(Vector2(0, sz.y * 0.5 + 6), "%.1f" % left if left < 10.0 else str(int(left)), Color.WHITE, 15, sz.x, HORIZONTAL_ALIGNMENT_CENTER)
		if kind == "item":
			_text(Vector2(0, sz.y - 4), str(Game.count_item(id)), Color.WHITE, 13, sz.x - 4, HORIZONTAL_ALIGNMENT_RIGHT)
		elif kind == "skill":
			_text(Vector2(0, sz.y - 4), "Lv%d" % Game.skill_level(id), Color("c8c0e0"), 11, sz.x - 4, HORIZONTAL_ALIGNMENT_RIGHT)
	_text(Vector2(4, 14), Settings.action_text(_action()), Color("ffe9a8"), 12, sz.x, HORIZONTAL_ALIGNMENT_LEFT)


func _text(pos: Vector2, t: String, col: Color, fs: int, w: float, align: int) -> void:
	if font == null:
		return
	draw_string_outline(font, pos, t, align, w, fs, 4, Color(0, 0, 0, 0.9))
	draw_string(font, pos, t, align, w, fs, col)


func _tip() -> void:
	var id := _id()
	if Game.main == null:
		return
	if id == "":
		Game.main.tooltip.show_text("[color=#9c97b8]Empty %s slot. Drag a %s here.[/color]" % ["skill" if kind == "skill" else "consumable",
			"skill from the Skills window" if kind == "skill" else "potion or food from your Inventory"])
		return
	if kind == "skill":
		var lv := maxi(1, Game.skill_level(id))
		Game.main.tooltip.show_text("[b]%s[/b]  Lv %d\n%s" % [GameData.SKILLS[id]["name"], lv, GameData.skill_description(id, lv)], 320)
	else:
		Game.main.tooltip.show_text(Items.tooltip({"id": id, "qty": Game.count_item(id)}))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if kind == "skill":
				Game.set_hot_skill(idx, "")
			else:
				Game.set_hot_item(idx, "")
		elif event.button_index == MOUSE_BUTTON_LEFT and event.double_click and kind == "item":
			Game.use_hot_item(idx)


func _get_drag_data(_p: Vector2):
	var id := _id()
	if id == "":
		return null
	var prev := Control.new()
	var ic := UI.icon(Art.glyph(GameData.SKILLS[id]["glyph"]) if kind == "skill" else Art.icon(GameData.item_template(id).get("icon", "quest")), 36)
	ic.position = Vector2(-18, -18)
	prev.add_child(ic)
	set_drag_preview(prev)
	if kind == "skill":
		return {"type": "skill", "id": id, "from_hot": idx}
	return {"type": "hot_item", "id": id, "from_hot": idx}


func _can_drop_data(_p: Vector2, data) -> bool:
	if not (data is Dictionary):
		return false
	if kind == "skill":
		return data.get("type", "") == "skill" and Game.skill_level(data["id"]) > 0 and GameData.SKILLS[data["id"]]["type"] == "active"
	if data.get("type", "") == "hot_item":
		return true
	if data.get("type", "") == "item":
		var it: Dictionary = data["item"]
		return not Items.is_gear(it) and GameData.item_template(it.get("id", "")).get("type", "") == "consumable"
	return false


func _drop_data(_p: Vector2, data) -> void:
	if kind == "skill":
		var prev_here := _id()
		Game.set_hot_skill(idx, data["id"])
		if data.has("from_hot") and prev_here != "" and int(data["from_hot"]) != idx:
			Game.set_hot_skill(int(data["from_hot"]), prev_here)
	else:
		var id: String = data["id"] if data.get("type", "") == "hot_item" else data["item"]["id"]
		var prev2 := _id()
		Game.set_hot_item(idx, id)
		if data.get("type", "") == "hot_item" and prev2 != "" and int(data["from_hot"]) != idx:
			Game.set_hot_item(int(data["from_hot"]), prev2)
	Sfx.play("click")
