class_name QuestsPage
extends VBoxContainer
## Active quest log, plus Progression: the tutorial and which features unlock at which level.

var list: VBoxContainer
var prog_box: VBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var cols := UI.hbox(16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(cols)
	var left := UI.vbox(8)
	cols.add_child(left)
	left.add_child(UI.label("Active Quests", 18, Color("ffe9a8")))
	left.add_child(UI.rich("[color=#9c97b8]Accept quests at the Adventurer Guild in town and return there to claim rewards.[/color]", 13))
	list = UI.vbox(8)
	left.add_child(UI.scroll(list, Vector2(700, 470)))
	var right := UI.vbox(6)
	cols.add_child(right)
	right.add_child(UI.label("Progression", 18, Color("ffe9a8")))
	prog_box = UI.vbox(4)
	right.add_child(UI.scroll(prog_box, Vector2(400, 500)))
	Game.quests_changed.connect(refresh)
	Game.inventory_changed.connect(refresh)
	refresh()


func _build_progression() -> void:
	for c in prog_box.get_children():
		c.queue_free()
	var plv := int(Game.player["level"])
	# tutorial
	var st := Progression.state()
	if Progression.tutorial_active():
		var s := Progression.current_step()
		prog_box.add_child(UI.rich("[color=#7be0ff][b]Tutorial[/b][/color] — step %d of %d: [b]%s[/b]
%s" % [
			int(st["tut_step"]) + 1, Progression.STEPS.size(), s["title"], Progression.step_text(s)], 13))
		prog_box.add_child(UI.button("Skip tutorial", func():
			Progression.skip_tutorial()
			refresh(), 160))
	else:
		prog_box.add_child(UI.rich("[color=#7be0ff][b]Tutorial[/b][/color] [color=#9c97b8]— finished or skipped.[/color]", 13))
		prog_box.add_child(UI.button("Restart tutorial", func():
			Progression.restart_tutorial()
			refresh(), 160))
	prog_box.add_child(UI.sep())
	# feature unlocks
	prog_box.add_child(UI.rich("[color=#9c97b8]New features open up as you level. Available from the start: combat, bag, skills, quests, map, the Quest Board, Gear / Potion / Food shops, teleport to town.[/color]", 12))
	var nx := Progression.next_unlock()
	if not nx.is_empty():
		var lv0 := plv
		var need := 0
		for l in range(lv0, int(nx["level"])):
			need += GameData.xp_to_next(l)
		need -= int(Game.player["xp"])
		prog_box.add_child(UI.rich("Next: [color=#fee761][b]%s[/b][/color] at level %d [color=#9c97b8](%d XP to go)[/color]" % [nx["name"], int(nx["level"]), maxi(0, need)], 14))
	else:
		prog_box.add_child(UI.rich("[color=#7be05a]Every feature is unlocked.[/color]", 14))
	for f in Progression.FEATURES:
		var open := Progression.is_unlocked(f["id"])
		var col := "7be05a" if open else "9c97b8"
		var mark := "Lv %d  OPEN" % int(f["level"]) if open else "Lv %d" % int(f["level"])
		prog_box.add_child(UI.rich("[color=#%s][b]%s  %s[/b][/color]
[color=#%s]%s[/color]" % [col, mark, f["name"],
			"c8c0e0" if open else "6f6a8c", Progression.description(f)], 12))


func refresh() -> void:
	if not is_inside_tree() or Game.player.is_empty():
		return
	_build_progression()
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
