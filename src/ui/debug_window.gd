class_name DebugWindow
extends GameWindow
## Cheat panel for debug mode (F4). See DebugMode (src/autoload/debug_mode.gd).

var info: Label
var mon_opt: OptionButton
var mon_lv: SpinBox
var mon_tier: OptionButton
var mon_n: SpinBox
var gear_lv: SpinBox
var gear_rar: OptionButton
var gear_n: SpinBox
var _types: Array = []


func _init() -> void:
	super._init("Debug", Vector2(980, 560), "debug")
	var cols := UI.hbox(18)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	var c1 := _col(cols, "Cheats")
	_check(c1, "God mode (no damage)", "god")
	_check(c1, "One-hit kills", "one_hit")
	_check(c1, "Free skills (no MP / cooldowns)", "free_skills")
	_check(c1, "No hunger", "no_hunger")
	_check(c1, "Noclip (walk through walls)", "noclip")
	_check(c1, "Fast movement (x2.5)", "fast_move")
	_check(c1, "Unlock all features (ignore level gates)", "unlock_all")
	c1.add_child(UI.label("Game speed", 14, UI.DIM))
	var sp := UI.hbox(4)
	c1.add_child(sp)
	for s in DebugMode.SPEEDS:
		var b := UI.button("x%s" % s, func(): DebugMode.set_game_speed(s); _say("Game speed x%s (applies when you close this panel)" % s))
		sp.add_child(b)

	var c2 := _col(cols, "Character")
	var r := UI.hbox(4)
	c2.add_child(r)
	r.add_child(UI.button("+1 Lv", func(): DebugMode.add_levels(1); _say("Level %d" % int(Game.player["level"]))))
	r.add_child(UI.button("+10 Lv", func(): DebugMode.add_levels(10); _say("Level %d" % int(Game.player["level"]))))
	r.add_child(UI.button("Max Lv", func(): DebugMode.add_levels(GameData.MAX_LEVEL); _say("Level %d" % int(Game.player["level"]))))
	r = UI.hbox(4)
	c2.add_child(r)
	r.add_child(UI.button("+1k gold", func(): Game.add_gold(1000); _say("Gold %d" % int(Game.player["gold"]))))
	r.add_child(UI.button("+100k gold", func(): Game.add_gold(100000); _say("Gold %d" % int(Game.player["gold"]))))
	r = UI.hbox(4)
	c2.add_child(r)
	r.add_child(UI.button("+50 stat pts", func(): _points("stat_points", 50)))
	r.add_child(UI.button("+25 skill pts", func(): _points("skill_points", 25)))
	c2.add_child(UI.button("Full restore (HP, MP, food, cooldowns)", func(): DebugMode.full_restore(); _say("Restored")))
	c2.add_child(UI.button("+500 guild points", func():
		Game.player["guild_points"] = int(Game.player.get("guild_points", 0)) + 500
		Game.quests_changed.emit()
		_say("Guild points %d" % int(Game.player["guild_points"]))))
	c2.add_child(UI.sep())
	c2.add_child(UI.label("Items", 16, Color("ffe9a8")))
	r = UI.hbox(4)
	c2.add_child(r)
	r.add_child(UI.label("Item Lv", 13, UI.DIM))
	gear_lv = _spin(1, 100, int(Game.player["level"]))
	r.add_child(gear_lv)
	r.add_child(UI.label("x", 13, UI.DIM))
	gear_n = _spin(1, 20, 1)
	r.add_child(gear_n)
	gear_rar = OptionButton.new()
	gear_rar.focus_mode = Control.FOCUS_NONE
	gear_rar.add_item("Random rarity")
	for rd in GameData.ItemData.RARITIES:
		gear_rar.add_item(rd["name"])
	c2.add_child(gear_rar)
	c2.add_child(UI.button("Give random gear", func():
		DebugMode.give_gear(int(gear_lv.value), gear_rar.selected - 1, int(gear_n.value))
		_say("Gear added to the bag")))
	c2.add_child(UI.button("Give 10 of every consumable", func(): DebugMode.give_consumables(); _say("Consumables added")))

	var c3 := _col(cols, "Monsters")
	mon_opt = OptionButton.new()
	mon_opt.focus_mode = Control.FOCUS_NONE
	_types = GameData.MONSTERS.keys()
	_types.sort()
	for t in _types:
		mon_opt.add_item(String(GameData.MONSTERS[t].get("name", t)))
	c3.add_child(mon_opt)
	r = UI.hbox(4)
	c3.add_child(r)
	r.add_child(UI.label("Lv", 13, UI.DIM))
	mon_lv = _spin(1, 100, int(Game.player["level"]))
	r.add_child(mon_lv)
	r.add_child(UI.label("x", 13, UI.DIM))
	mon_n = _spin(1, 30, 1)
	r.add_child(mon_n)
	mon_tier = OptionButton.new()
	mon_tier.focus_mode = Control.FOCUS_NONE
	for t in DebugMode.TIERS:
		mon_tier.add_item(t.capitalize())
	c3.add_child(mon_tier)
	c3.add_child(UI.button("Spawn at mouse", func():
		if _types.is_empty():
			return
		DebugMode.spawn_monster(_types[mon_opt.selected], int(mon_lv.value), DebugMode.TIERS[mon_tier.selected], int(mon_n.value))
		_say("Spawned %d" % int(mon_n.value))))
	c3.add_child(UI.button("Kill monsters nearby", func(): _say("Killed %d" % DebugMode.kill_monsters(400.0))))
	c3.add_child(UI.button("Kill ALL monsters", func(): _say("Killed %d" % DebugMode.kill_monsters())))

	var c4 := _col(cols, "World")
	c4.add_child(UI.button("Teleport to mouse", func(): DebugMode.teleport(DebugMode.last_mouse_world); Game.main.close_all()))
	var tb := UI.button("Teleport to town", func():
		Game.main.close_all()
		if DebugMode.level():
			DebugMode.level().teleport_to_town())
	c4.add_child(tb)
	c4.add_child(UI.button("Reveal world map", func(): DebugMode.reveal_map(); _say("Map revealed")))
	c4.add_child(UI.button("Spawn hidden dungeon", func():
		_say("Hidden dungeon placed (see map)" if DebugMode.spawn_dungeon() else "Only in the overworld / no free spot")))
	c4.add_child(UI.button("Add NPC adventurer", func():
		var n := NpcWorld.add_npc(int(Game.player["level"]))
		_say("Added %s" % n["name"] if not n.is_empty() else "Adventurer cap reached")))
	c4.add_child(UI.label("Time", 14, UI.DIM))
	r = UI.hbox(4)
	c4.add_child(r)
	r.add_child(UI.button("Dawn", func(): DebugMode.set_hour(6.0); _say(Game.clock_text())))
	r.add_child(UI.button("Noon", func(): DebugMode.set_hour(12.0); _say(Game.clock_text())))
	r.add_child(UI.button("Night", func(): DebugMode.set_hour(22.0); _say(Game.clock_text())))
	r.add_child(UI.button("+1 h", func(): DebugMode.skip_hours(1.0); _say(Game.clock_text())))
	var sv := UI.button("Save now", func(): _say("Saved to slot %d" % Game.slot if Game.save_game(false) else "Save failed"))
	sv.disabled = Game.test_run
	c4.add_child(sv)

	body.add_child(UI.sep())
	info = UI.label("F3 toggles the info overlay. Cheats are not saved. \"At mouse\" uses the cursor position from when this panel was opened.", 13, UI.DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(info)


func _col(parent: Control, title: String) -> VBoxContainer:
	var v := UI.vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.label(title, 16, Color("ffe9a8")))
	parent.add_child(v)
	return v


func _check(parent: Control, text: String, flag: String) -> void:
	var cb := CheckBox.new()
	cb.text = text
	cb.focus_mode = Control.FOCUS_NONE
	cb.button_pressed = bool(DebugMode.get(flag))
	cb.toggled.connect(func(on: bool):
		DebugMode.set(flag, on)
		_say("%s %s" % [text, "ON" if on else "off"]))
	parent.add_child(cb)


func _spin(lo: int, hi: int, v: int) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.value = clampi(v, lo, hi)
	s.custom_minimum_size.x = 80
	return s


func _points(key: String, n: int) -> void:
	Game.player[key] = int(Game.player.get(key, 0)) + n
	Game.stats_changed.emit()
	Game.skills_changed.emit()
	_say("%s: %d" % [key.replace("_", " ").capitalize(), int(Game.player[key])])


func _say(t: String) -> void:
	if info:
		info.text = t
