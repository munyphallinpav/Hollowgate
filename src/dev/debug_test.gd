extends Node
## Debug mode (F3 overlay / F4 cheat panel) checks.  godot --path . -- --autotest --debugtest

var fails: Array = []
var passes := 0


func ok(cond: bool, what: String) -> void:
	if cond:
		passes += 1
		print("[debug] pass  ", what)
	else:
		fails.append(what)
		print("[debug] FAIL  ", what)


func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	await get_tree().process_frame


func run_all() -> void:
	var M = Game.main
	M.start_new_game("Debugger", "mage", 3)
	await _wait(0.8)
	var D = DebugMode
	ok(D.enabled, "debug mode is enabled for this run")
	var p: Player = Game.player_node
	var lvn = Game.level_node

	# overlay
	await _key(KEY_F3)
	await _wait(0.3)
	ok(D.overlay_layer.visible and D.overlay.text.contains("FPS") and D.overlay.text.contains("biome"), "F3 shows the overlay with FPS and location")
	await _key(KEY_F3)
	ok(not D.overlay_layer.visible, "F3 hides it again")

	# panel
	await _key(KEY_F4)
	ok(M.window is DebugWindow and get_tree().paused, "F4 opens the cheat panel and pauses")
	await _key(KEY_F4)
	ok(M.window == null and not get_tree().paused, "F4 closes it")

	# levels / gold
	D.add_levels(10)
	ok(int(Game.player["level"]) == 11, "+10 levels -> level 11 (got %d)" % int(Game.player["level"]))
	D.add_levels(GameData.MAX_LEVEL)
	ok(int(Game.player["level"]) == GameData.MAX_LEVEL, "max level")

	# god mode
	p.invuln_t = 0.0
	D.god = true
	var hp0 := p.hp
	p.take_damage(999999, {})
	ok(not p.dead and p.hp == hp0, "god mode: no damage taken")
	D.god = false

	# one-hit kills
	var spot := p.global_position + Vector2(40, 0)
	D.last_mouse_world = spot
	D.spawn_monster("slime", 100, "boss", 1)
	await _wait(0.1)
	var mons := get_tree().get_nodes_in_group("monsters").filter(func(m): return is_instance_valid(m) and not m.dead and m.global_position.distance_to(spot) < 5.0)
	ok(mons.size() == 1, "spawn monster at mouse")
	if mons.size() == 1:
		D.one_hit = true
		Combat.hit(p, mons[0], 1.0, "magic", "none", {})
		ok(mons[0].dead or mons[0].hp <= 0.0, "one-hit kill on a Lv 100 boss slime")
		D.one_hit = false

	# free skills
	D.free_skills = true
	var sid := ""
	for id in GameData.SKILLS:
		if GameData.SKILLS[id].get("cls", "") == "mage" and GameData.SKILLS[id].get("type", "") == "active":
			sid = id
			break
	if sid != "":
		Game.player["skills"][sid] = 1
		p.mp = 0.0
		p.gcd = 0.0
		var cast := p.try_cast(sid)
		ok(not cast or not p.skill_cds.has(sid), "free skills: cast %s with 0 MP and no cooldown (cast=%s)" % [sid, cast])
	D.free_skills = false

	# hunger / restore
	Game.player["satiety"] = 5.0
	D.no_hunger = true
	await _wait(0.1)
	ok(float(Game.player["satiety"]) == 100.0, "no hunger keeps satiety full")
	D.no_hunger = false

	# noclip
	D.noclip = true
	await _wait(0.1)
	ok(p.collision_mask == 0, "noclip clears the collision mask")
	D.noclip = false
	await _wait(0.1)
	ok(p.collision_mask == (1 | 2), "noclip off restores it")

	# items
	var free0 := Game.free_slots()
	D.give_gear(50, 5, 2)
	ok(Game.free_slots() == free0 - 2, "two Mythical gear pieces added")

	# world
	D.reveal_map()
	ok(Game.world["explored"].size() == (WorldGen.SIZE / WorldGen.CHUNK) * (WorldGen.SIZE / WorldGen.CHUNK), "map fully revealed")
	D.set_hour(22.0)
	ok(Game.is_night(), "set time to night")
	var nd := int(Game.world["dungeons"].size())
	ok(D.spawn_dungeon() and Game.world["dungeons"].size() == nd + 1, "spawn hidden dungeon")
	D.kill_monsters()
	await _wait(0.1)
	ok(get_tree().get_nodes_in_group("monsters").filter(func(m): return is_instance_valid(m) and not m.dead).is_empty(), "kill all monsters")
	D.set_game_speed(2.0)
	lvn.hitstop(0.05)
	await _wait(0.3)
	ok(is_equal_approx(Engine.time_scale, 2.0), "game speed survives hitstop")
	D.set_game_speed(1.0)

	print("[debug] ==== %d passed, %d failed" % [passes, fails.size()])
	for f in fails:
		print("[debug] FAILED: ", f)
	get_tree().quit()
