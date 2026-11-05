extends Node
## Tutorial + feature unlocks by level.
##   godot --path . -- --autotest --progtest [--shots=DIR]

var fails: Array = []
var passes := 0
var shots_dir := ""
var step := 0


func ok(cond: bool, what: String) -> void:
	if cond:
		passes += 1
		print("[prog] pass  ", what)
	else:
		fails.append(what)
		print("[prog] FAIL  ", what)


func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func shot(name: String) -> void:
	if shots_dir == "":
		return
	for i in 3:
		await get_tree().process_frame
	step += 1
	DirAccess.make_dir_recursive_absolute(shots_dir)
	get_viewport().get_texture().get_image().save_png("%s/prog_%02d_%s.png" % [shots_dir, step, name])


func _step_id() -> String:
	return String(Progression.current_step().get("id", ""))


## Polls the tutorial until it leaves `id` (or gives up).
func _until_past(id: String, t: float = 2.0) -> bool:
	var left := t
	while left > 0.0:
		if _step_id() != id:
			return true
		await _wait(0.1)
		left -= 0.1
	return _step_id() != id


func run_all() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
	DebugMode.unlock_all = false
	Progression.tutorial_off = false
	var M = Game.main
	M.go_title(false)
	await _wait(0.3)
	M.start_new_game("Newbie", "warrior", 3)
	await _wait(1.0)
	var lvn = Game.level_node
	var p: Player = Game.player_node
	# ---------------------------------------------------------------- locks at level 1
	ok(int(Game.player["level"]) == 1, "a new character starts at level 1")
	ok(not Progression.is_unlocked("blacksmith") and not Progression.is_unlocked("duels") and not Progression.is_unlocked("architect"), "advanced features start locked")
	M.open_service("blacksmith")
	await _wait(0.2)
	ok(M.window == null, "the Blacksmith refuses a level-1 character")
	M.open_service("architect")
	await _wait(0.2)
	ok(M.window == null, "so does the Dungeon Architect")
	M.open_service("gear")
	await _wait(0.2)
	ok(M.window is ShopWindow, "the Gear Shop is open from the start")
	M.close_all()
	M.open_service("guild")
	await _wait(0.3)
	ok(M.window is GuildWindow and M.window.tabs.is_tab_disabled(1), "the guild's Dungeon Hall tab is locked")
	M.close_all()
	# ---------------------------------------------------------------- the tutorial
	ok(Progression.tutorial_active() and _step_id() == "move", "the tutorial starts with moving")
	await _wait(0.4)
	ok(M.hud.tut_panel.visible and M.hud.tut_title.text.begins_with("Tutorial 1/"), "the HUD shows the current step (%s)" % M.hud.tut_title.text)
	await shot("tutorial_move")
	var g0 := int(Game.player["gold"])
	p.global_position += Vector2(120, 0)
	ok(await _until_past("move"), "walking completes step 1")
	ok(int(Game.player["gold"]) > g0, "and pays a small reward")
	ok(_step_id() == "skill", "next: learn a skill")
	var sk := ""
	for id in GameData.SKILLS:
		if Game.can_learn(id) and GameData.SKILLS[id].get("type", "") == "active":
			sk = id
			break
	if sk != "":
		Game.learn_skill(sk)
		Game.set_hot_skill(0, sk)
	ok(await _until_past("skill"), "equipping a skill completes step 2 (%s)" % sk)
	Game.refresh_board(true)
	Game.accept_quest(0)
	ok(await _until_past("quest"), "accepting a quest completes step 3")
	var ow: Overworld = lvn
	p.global_position = Vector2(256 * 16 + 8, 300 * 16 + 8)
	ok(await _until_past("gate"), "leaving town completes step 4")
	for i in 3:
		Game.on_monster_killed("slime", "normal")
		await _wait(0.1)
	ok(await _until_past("kill"), "three kills complete step 5")
	M.open_menu("inventory")
	ok(await _until_past("bag"), "opening the bag completes step 6")
	M.close_all()
	p.global_position = ow.town_spawn()
	ok(await _until_past("home"), "back in town completes step 7")
	M.open_service("gear")
	await _wait(0.3)
	var w: ShopWindow = M.window
	var idx := -1
	for i in Game.player["inv"].size():
		var it = Game.player["inv"][i]
		if it is Dictionary and not it.is_empty():
			idx = i
			break
	w._do_sell(idx, 1)
	await _wait(0.5)
	ok(not Progression.tutorial_active() and bool(Progression.state()["tut_done"]), "selling finishes the tutorial")
	ok(not M.hud.tut_panel.visible, "and the tracker disappears")
	M.close_all()
	# restarting does not pay again
	var paid: int = Progression.state().get("paid", []).size()
	var g1 := int(Game.player["gold"])
	Progression.restart_tutorial()
	p.global_position += Vector2(-120, 0)
	await _until_past("move")
	ok(int(Game.player["gold"]) == g1 and Progression.state()["paid"].size() == paid, "a restarted tutorial pays nothing twice")
	Progression.skip_tutorial()
	ok(not Progression.tutorial_active(), "the tutorial can be skipped")
	# ---------------------------------------------------------------- unlocks while levelling
	var announced := []
	while int(Game.player["level"]) < 10:
		Game.add_xp(GameData.xp_to_next(int(Game.player["level"])))
	ok(Progression.is_unlocked("blacksmith") and Progression.is_unlocked("dungeons") and Progression.is_unlocked("party") and Progression.is_unlocked("duels"), "level 10: blacksmith, dungeons, parties and duels are open")
	ok(not Progression.is_unlocked("artifact_shop") and not Progression.is_unlocked("architect"), "but not the artifact shop or the architect yet")
	for f in Progression.FEATURES:
		if int(f["level"]) <= 10:
			announced.append(f["id"])
	var seen: Array = Progression.state()["seen"]
	var all_seen := true
	for id in announced:
		if not id in seen:
			all_seen = false
	ok(all_seen, "each unlock was announced once")
	await _wait(0.3)
	ok(M.hud.unlock_panel.visible, "the unlock card shows on screen (%s)" % M.hud.unlock_title.text)
	await shot("unlock_card")
	M.open_service("blacksmith")
	await _wait(0.3)
	ok(M.window is BlacksmithWindow, "the Blacksmith opens at level 3+")
	ok(not M.window.tabbar.is_tab_disabled(1) and M.window.tabbar.is_tab_disabled(2), "enchanting is open at 8, rerolling still locked until 14")
	M.close_all()
	# ---------------------------------------------------------------- the Progression list
	M.open_menu("quests")
	await _wait(0.4)
	var page = M.window.find_children("*", "QuestsPage", true, false)[0]
	ok(page.prog_box.get_child_count() >= Progression.FEATURES.size(), "the Quests page lists every unlock")
	await shot("progression_page")
	M.close_all()
	# ---------------------------------------------------------------- saves
	Game.save_game(false)
	M.load_slot(3)
	await _wait(0.8)
	ok(bool(Progression.state()["tut_done"]) and Progression.state()["seen"].size() == announced.size(), "progression is saved with the character")
	Game.player.erase("progression")
	Progression.init_loaded_game()
	ok(not Progression.tutorial_active() and Progression.state()["seen"].size() == announced.size(), "older saves skip the tutorial and aren't spammed with unlocks")
	# ---------------------------------------------------------------- debug override
	DebugMode.unlock_all = true
	ok(Progression.is_unlocked("architect"), "the debug panel can unlock everything")
	DebugMode.unlock_all = false
	_end()


func _end() -> void:
	print("[prog] ==== %d passed, %d failed" % [passes, fails.size()])
	for x in fails:
		print("[prog] FAILED: ", x)
	get_tree().quit()
