class_name SystemPage
extends VBoxContainer
## Save / load / title / quit.

var slots_box: VBoxContainer
var info: Label


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	add_child(UI.label("Game", 18, Color("ffe9a8")))
	info = UI.label("The game auto-saves every minute, when you return to the title screen and when you quit.", 14, UI.DIM)
	add_child(info)
	var h := UI.hbox(10)
	add_child(h)
	h.add_child(UI.button("Resume", func(): Game.main.close_all(), 160))
	var sb := UI.button("Save Now", func():
		if Game.save_game(false):
			info.text = "Saved to slot %d." % Game.slot
			_refresh(), 160)
	sb.disabled = Game.test_run
	h.add_child(sb)
	h.add_child(UI.button("Return to Title", func():
		Dialogs.confirm(Game.main.menu_layer, "Return to title", "Your progress will be saved. Return to the title screen?", func(): Game.main.go_title(true)), 180))
	h.add_child(UI.button("Quit Game", func():
		Dialogs.confirm(Game.main.menu_layer, "Quit", "Save and quit the game?", func():
			if not Game.test_run:
				Game.save_game(true)
			get_tree().quit(), "Quit"), 160))
	add_child(UI.sep())
	add_child(UI.label("Load a save slot", 16, Color("ffe9a8")))
	slots_box = UI.vbox(6)
	add_child(slots_box)
	add_child(UI.sep())
	add_child(UI.label("How to play", 16, Color("ffe9a8")))
	var keys := "Move [b]%s%s%s%s[/b] • Attack [b]%s[/b] (hold) • Dash [b]%s[/b] (immune while dashing) • Skills [b]%s %s %s %s[/b] • Consumables [b]%s %s %s %s[/b]\nInteract [b]%s[/b] • Teleport to town [b]%s[/b] • Inventory [b]%s[/b] • Character [b]%s[/b] • Skills [b]%s[/b] • Quests [b]%s[/b] • Map [b]%s[/b] • Dungeon editor [b]%s[/b]" % [
		Settings.action_text("move_up"), Settings.action_text("move_left"), Settings.action_text("move_down"), Settings.action_text("move_right"),
		Settings.action_text("attack"), Settings.action_text("dash"), Settings.action_text("skill_1"), Settings.action_text("skill_2"),
		Settings.action_text("skill_3"), Settings.action_text("skill_4"), Settings.action_text("item_1"), Settings.action_text("item_2"),
		Settings.action_text("item_3"), Settings.action_text("item_4"), Settings.action_text("interact"), Settings.action_text("teleport_town"),
		Settings.action_text("open_inventory"), Settings.action_text("open_character"), Settings.action_text("open_skills"),
		Settings.action_text("open_quests"), Settings.action_text("open_map"), Settings.action_text("open_editor")]
	add_child(UI.rich(keys, 14))
	add_child(UI.rich("[color=#9c97b8]Monster level rises the farther you travel from Hollowgate. Hidden dungeons (marked on the map) hold mini bosses, a boss and its unique treasure — they vanish after a while or once cleared. Keep your belly full: below 20 Satiety you regenerate slowly. Harvest trees, rocks and ores for crafting at the Blacksmith. Mouse wheel zooms the camera.[/color]", 13))
	_refresh()


func _refresh() -> void:
	for c in slots_box.get_children():
		c.queue_free()
	for s in range(1, Game.SAVE_SLOTS + 1):
		var inf := Game.slot_info(s)
		var row := UI.hbox(10)
		var txt := "Slot %d: (empty)" % s
		if not inf.is_empty():
			txt = "Slot %d: %s — %s Lv %d — Day %d — %s%s" % [s, inf["name"], GameData.CLASSES.get(inf["class"], {"name": "?"})["name"], int(inf["level"]), int(inf["day"]), inf["date"], "  (current)" if s == Game.slot else ""]
		var l := UI.label(txt, 14)
		l.custom_minimum_size.x = 640
		row.add_child(l)
		if not inf.is_empty():
			var ss: int = s
			row.add_child(UI.button("Load", func():
				Dialogs.confirm(Game.main.menu_layer, "Load game", "Load slot %d? Unsaved progress in the current game will be lost." % ss, func(): Game.main.load_slot(ss))))
		slots_box.add_child(row)
