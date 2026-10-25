class_name QuestsPage
extends VBoxContainer
## Active quest log.

var list: VBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	add_child(UI.label("Active Quests", 18, Color("ffe9a8")))
	add_child(UI.rich("[color=#9c97b8]Accept quests at the Adventurer Guild in town and return there to claim rewards.[/color]", 13))
	list = UI.vbox(8)
	var sc := UI.scroll(list, Vector2(900, 470))
	add_child(sc)
	Game.quests_changed.connect(refresh)
	Game.inventory_changed.connect(refresh)
	refresh()


func refresh() -> void:
	if not is_inside_tree() or Game.player.is_empty():
		return
	for c in list.get_children():
		c.queue_free()
	if Game.player["quests"].is_empty():
		list.add_child(UI.label("No active quests.", 15, UI.DIM))
		return
	for i in Game.player["quests"].size():
		list.add_child(quest_card(Game.player["quests"][i], i, false))


static func quest_card(q: Dictionary, i: int, board: bool) -> PanelContainer:
	var p := PanelContainer.new()
	var done := not board and Quests.is_complete(q)
	p.add_theme_stylebox_override("panel", UI.sbox(Color("201f36"), UI.GOOD if done else Color("4a4568"), 1, 4, 10))
	var h := UI.hbox(12)
	p.add_child(h)
	var icon := "quest"
	match q["type"]:
		"hunt":
			icon = "sword"
		"gather":
			icon = GameData.item_template(q["target"]).get("icon", "quest")
		"dungeon":
			icon = "dungeon_crystal"
		"elite":
			icon = "mat_monster_core"
	h.add_child(UI.icon(Art.icon(icon), 36))
	var v := UI.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UI.label(q["title"], 16, Color("ffe9a8")))
	v.add_child(UI.label(q["desc"], 13, UI.TEXT))
	var rw := "Reward: [color=#fee761]%d gold[/color], [color=#8fe8ff]%d XP[/color], %d guild pts" % [int(q["gold"]), int(q["xp"]), int(q["gp"])]
	if q.has("item_rarity"):
		rw += ", [color=#%s]%s+ gear[/color]" % [GameData.rarity_color(int(q["item_rarity"])).to_html(false), GameData.rarity(int(q["item_rarity"]))["name"]]
	v.add_child(UI.rich(rw, 13))
	if not board:
		v.add_child(UI.label("Progress: " + Quests.progress_text(q) + ("  — Ready to turn in!" if done else ""), 13, UI.GOOD if done else UI.DIM))
		if Game.main and Game.main.is_service_open("guild"):
			var tb := UI.button("Turn In", func(): Game.turn_in_quest(i))
			tb.disabled = not done
			h.add_child(tb)
		h.add_child(UI.button("Abandon", func():
			Dialogs.confirm(Game.main.menu_layer, "Abandon quest", "Abandon '%s'?" % q["title"], func(): Game.abandon_quest(i), "Abandon")))
	else:
		h.add_child(UI.button("Accept", func(): Game.accept_quest(i)))
	return p
