extends Node
## Automated smoke test / screenshot tour. Run with:  godot --path . -- --autotest [--shots=DIR] [--class=warrior] [--quick]
## Not used during normal play.

var shots_dir := ""
var quick := false
var only_class := ""
var step := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
		if a == "--quick":
			quick = true
		if a.begins_with("--class="):
			only_class = a.substr(8)
	_run()


func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _frames(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	if shots_dir == "":
		return
	await _frames(3)
	var img := get_viewport().get_texture().get_image()
	step += 1
	img.save_png("%s/%02d_%s.png" % [shots_dir, step, name])
	print("[autotest] shot ", name)


func log_(s: String) -> void:
	print("[autotest] ", s)


func _bot_seconds() -> float:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bot="):
			return float(a.substr(6))
	return 0.0


func _set_move(d: Vector2) -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	if d.x < -0.1:
		Input.action_press("move_left", -d.x)
	if d.x > 0.1:
		Input.action_press("move_right", d.x)
	if d.y < -0.1:
		Input.action_press("move_up", -d.y)
	if d.y > 0.1:
		Input.action_press("move_down", d.y)


var _trail: Array = []


func _bot(M, cls: String, seconds: float) -> void:
	M.start_new_game("Bot", cls, 3)
	await _wait(1.0)
	var main_stat: String = {"warrior": "str", "ranger": "dex", "assassin": "luk", "mage": "int", "priest": "mnd"}[cls]
	var p = Game.player_node
	var lv = Game.level_node
	p.global_position = Vector2(256 * 16 + 8, 292 * 16)
	lv._update_chunks(true)
	var t := 0.0
	var deaths := 0
	var was_dead := false
	var wander := Vector2.DOWN
	var kills0 := 0
	var log_t := 0.0
	var ranged: bool = cls in ["ranger", "mage", "priest"]
	while t < seconds:
		await _wait(0.1)
		t += 0.1
		log_t += 0.1
		p = Game.player_node
		lv = Game.level_node
		if p == null or lv == null:
			continue
		# spend points
		if int(Game.player["stat_points"]) > 0:
			var sp := int(Game.player["stat_points"])
			Game.allocate_stat(main_stat, sp * 6 / 10)
			Game.allocate_stat("vit", int(Game.player["stat_points"]) * 3 / 4)
			Game.allocate_stat("dex", int(Game.player["stat_points"]))
		while int(Game.player["skill_points"]) > 0:
			var learned := false
			for id in GameData.skills_for(cls):
				if Game.can_learn(id):
					Game.learn_skill(id, 1)
					learned = true
					break
			if not learned:
				break
		if p.dead:
			if not was_dead:
				deaths += 1
				log_("DEATH #%d at t=%.1f — last moments:" % [deaths, t])
				for line in _trail:
					log_("     " + line)
			was_dead = true
			_set_move(Vector2.ZERO)
			continue
		was_dead = false
		# rolling record of the last 3 s (who is near, their state) to explain deaths
		var near := []
		for m in lv.actors_in_radius(p.global_position, 90.0, "enemy"):
			near.append("%s(L%d %s %s %d)" % [m.display_name, m.level, m.state, m.cur_attack, int(m.global_position.distance_to(p.global_position))])
		_trail.append("t=%.1f hp=%d near=%s" % [t, int(p.hp), ", ".join(PackedStringArray(near))])
		if _trail.size() > 30:
			_trail.pop_front()
		if p.hp < p.max_hp * 0.4:
			Game.use_hot_item(0)
		if p.mp < p.max_mp * 0.2:
			Game.use_hot_item(1)
		if float(Game.player["satiety"]) < 30.0:
			Game.use_hot_item(2)
		var e = lv.nearest_actor(p.global_position, 220.0, "enemy")
		if e and e is Monster and e.data.get("passive", false) and randf() < 0.5:
			e = e
		if e:
			p.bot_aim = e.global_position
			var d: Vector2 = e.global_position - p.global_position
			var mv := Vector2.ZERO
			if ranged:
				if d.length() > 150.0:
					mv = d.normalized()
				elif d.length() < 70.0:
					mv = -d.normalized()
			elif d.length() > 20.0:
				mv = d.normalized()
			_set_move(mv)
			p.attack_held = true
			for i in 4:
				var sid: String = Game.player["hot_skills"][i]
				if sid != "" and not p.skill_cds.has(sid) and randf() < 0.3:
					p.try_cast(sid)
		else:
			p.attack_held = false
			var td: float = p.global_position.distance_to(Vector2(256 * 16, 256 * 16)) / 16.0
			if td > 75.0:
				wander = (Vector2(256 * 16, 256 * 16) - p.global_position).normalized()
			elif td < 36.0:
				wander = (p.global_position - Vector2(256 * 16, 256 * 16)).normalized()
			elif randf() < 0.02:
				wander = wander.rotated(randf_range(-1.2, 1.2))
			_set_move(wander)
			p.bot_aim = p.global_position + wander * 50.0
		if log_t >= 15.0:
			log_t = 0.0
			var kills := 0
			for k in Game.player["kills"]:
				kills += int(Game.player["kills"][k])
			var tt: Vector2i = lv.tile_of(p.global_position) if lv is Overworld else Vector2i.ZERO
			log_("t=%ds lv=%d xp=%d/%d kills=%d (+%d) gold=%d hp=%d/%d deaths=%d bag=%d area_lv=%d monsters=%d fps=%d" % [
				int(t), int(Game.player["level"]), int(Game.player["xp"]), GameData.xp_to_next(int(Game.player["level"])), kills, kills - kills0,
				int(Game.player["gold"]), int(p.hp), int(p.max_hp), deaths, Game.player["bag_size"] - Game.free_slots(),
				lv.gen.level_at(tt.x, tt.y) if lv is Overworld else 0, get_tree().get_nodes_in_group("monsters").size(), Engine.get_frames_per_second()])
			kills0 = kills
			var ne = lv.nearest_actor(p.global_position, 9999.0, "enemy")
			log_("   pos=%s move=%s vel=%s air=%s leap=%.2f dash=%.2f lock=%.2f tele=%.2f canmove=%s canact=%s st=%s nearest=%s" % [
				str(Vector2i(p.global_position)), str(p.move_dir), str(Vector2i(p.velocity)), str(p.in_air_skill), p.leap_t, p.dash_t, p.lock_t,
				p.teleport_t, str(p.can_move()), str(p.can_act()), str(p.statuses.keys()),
				("%s@%d" % [ne.display_name, int(ne.global_position.distance_to(p.global_position))]) if ne else "none"])
	_set_move(Vector2.ZERO)
	await shot("bot_" + cls)
	log_("BOT DONE %s: level %d, deaths %d" % [cls, int(Game.player["level"]), deaths])


func _check_scripts(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			var s = load(dir.path_join(f))
			if s == null or not (s is GDScript) or not s.can_instantiate():
				out.append(dir.path_join(f))
	for sub in d.get_directories():
		_check_scripts(dir.path_join(sub), out)


func _run() -> void:
	var M = Game.main
	if "--qa" in OS.get_cmdline_user_args():
		var qa = load("res://src/dev/qa.gd").new()
		add_child(qa)
		await qa.run_all()
		return
	if "--check" in OS.get_cmdline_user_args():
		var bad := []
		_check_scripts("res://src", bad)
		log_("CHECK %s %s" % ["OK" if bad.is_empty() else "FAILED", str(bad)])
		get_tree().quit()
		return
	var bs := _bot_seconds()
	if bs > 0.0:
		M.go_title(false)
		await _wait(0.3)
		await _bot(M, only_class if only_class != "" else "warrior", bs)
		get_tree().quit()
		return
	M.go_title(false)
	await _wait(0.6)
	await shot("title")
	if M.title:
		M.title.show_new()
		await _wait(0.4)
		await shot("class_select")
	var classes := ["warrior", "ranger", "assassin", "mage", "priest"]
	if only_class != "":
		classes = [only_class]
	var first := true
	for cls in classes:
		log_("=== class " + cls)
		M.start_new_game("Test" + cls.capitalize(), cls, 3)
		await _wait(1.2)
		if first:
			await shot("town_start")
			await _input_test(M)
			await _menus(M)
			await _services(M)
		await _power_up()
		await _wild(M, cls, first)
		if first:
			await _dungeon(M)
			await _trap_test(M)
			await _editor(M)
			await _save_load(M)
		first = false
		if quick:
			break
	log_("ALL DONE")
	get_tree().quit()


func _press(action: String, t: float) -> void:
	Input.action_press(action)
	await _wait(t)
	Input.action_release(action)
	await _frames(2)


func _input_test(M) -> void:
	var p = Game.player_node
	var start: Vector2 = p.global_position
	await _press("move_right", 0.6)
	log_("move_right moved %.1f px" % (p.global_position.x - start.x))
	var before: Vector2 = p.global_position
	Input.action_press("move_left")
	await _frames(2)
	await _press("dash", 0.05)
	await _wait(0.3)
	Input.action_release("move_left")
	log_("dash moved %.1f px" % (before.x - p.global_position.x))
	# mouse attack through the real input pipeline
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(700, 360)
	Input.parse_input_event(ev)
	await _wait(0.5)
	var ev2 := ev.duplicate()
	ev2.pressed = false
	Input.parse_input_event(ev2)
	log_("attack held -> cd %.2f" % p.attack_cd)
	# hotkey item
	var hp_before: float = p.hp
	p.hp = p.max_hp * 0.5
	await _press("item_1", 0.05)
	log_("potion hotkey: hp %.0f -> %.0f" % [p.max_hp * 0.5, p.hp])
	p.hp = p.max_hp
	# walk to the guild master and press interact
	var npc = null
	for n in get_tree().get_nodes_in_group("npcs"):
		if n.role == "guild":
			npc = n
	p.global_position = npc.global_position + Vector2(0, 14)
	await _wait(0.2)
	await _press("interact", 0.05)
	await _wait(0.3)
	log_("interact opened window: %s" % str(M.window != null and M.window.key == "guild"))
	M.close_all()
	await _press("open_inventory", 0.05)
	log_("I opened inventory: %s" % str(M.window is GameMenu))
	await _press("menu", 0.05)
	log_("Esc closed: %s" % str(M.window == null))
	# chunk timing
	var lv = Game.level_node
	var t0 := Time.get_ticks_usec()
	lv._load_chunk(Vector2i(3, 3))
	log_("chunk load time: %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	# death and respawn in town
	p.global_position = Vector2(256 * 16 + 8, 220 * 16)
	await _wait(0.2)
	p.invuln_t = 0.0
	p.take_damage(int(p.hp) + 50, {})
	await _wait(3.0)
	var t: Vector2i = lv.tile_of(p.global_position)
	log_("after death: dead=%s in_town=%s hp=%.0f" % [str(p.dead), str(lv.gen.in_town(t.x, t.y)), p.hp])
	# hunger
	Game.player["satiety"] = 5.0
	Game.use_hot_item(2)
	log_("satiety after bread: %.1f" % float(Game.player["satiety"]))


func _menus(M) -> void:
	for t in ["inventory", "character", "skills", "quests", "map", "settings", "system"]:
		M.open_menu(t)
		await _wait(0.35)
		await shot("menu_" + t)
	M.close_all()
	await _wait(0.2)


func _services(M) -> void:
	for r in ["guild", "gear", "potion", "food", "magic", "artifact", "blacksmith", "architect"]:
		M.open_service(r)
		await _wait(0.35)
		await shot("service_" + r)
		if r == "guild":
			Game.accept_quest(0)
			Game.accept_quest(0)
		M.close_all()
		await _wait(0.15)


func _power_up() -> void:
	Game.add_xp(500000)
	var p := Game.player
	for st in ["str", "vit", "int", "mnd", "dex", "luk"]:
		Game.allocate_stat(st, int(p["stat_points"]) / 6)
	p["skill_points"] = 999
	for id in GameData.skills_for(p["class"]):
		Game.learn_skill(id, 8)
	for id in ["second_wind", "battle_focus", "rune_blast"]:
		Game.learn_skill(id, 3)
	p["tomes"] = ["tome_flame_orb", "tome_aqua_spear", "tome_rock_throw", "tome_gale_slash", "tome_radiant_burst", "tome_shadow_bolt"]
	for id in p["tomes"]:
		Game.learn_skill(id, 3)
	Game.add_gold(100000)
	for i in 6:
		Game.add_item(Items.random_gear(int(p["level"]), 3 + i % 3))
	Game.add_item(Items.stack("enchant_stone", 20))
	Game.add_item(Items.stack("arcane_dust", 20))
	Game.recalc()
	await _wait(0.2)


func _wild(M, cls: String, take_shots: bool) -> void:
	var lv = Game.level_node
	var p = Game.player_node
	# go a little way out of town
	var spot := Vector2(256 * 16 + 8, 200 * 16)
	for k in 30:
		var cand := Vector2(256 * 16 + randf_range(-600, 600), 190 * 16 + randf_range(-500, 300))
		if lv.is_walkable(cand):
			spot = cand
			break
	p.global_position = spot
	lv._update_chunks(true)
	await _wait(0.5)
	# spawn a crowd to fight
	var types := ["slime", "wolf", "goblin", "skeleton", "zombie", "bear", "lizard", "tiger", "mermaid", "ogre", "treant", "dryad", "vampire", "wyvern", "dragon", "phoenix"]
	for i in types.size():
		var mp: Vector2 = p.global_position + Vector2.from_angle(i * TAU / types.size()) * randf_range(60, 110)
		var m = lv.spawn_monster(types[i], mp, 20, "elite" if i % 5 == 0 else "normal")
		m.target = p
	await _wait(1.0)
	if take_shots:
		await shot("wild_monsters")
	# cast every skill the class has
	var all_ids := GameData.skills_for(cls) + GameData.skills_for("common")
	var n := 0
	for id in all_ids:
		if GameData.SKILLS[id]["type"] != "active" or Game.skill_level(id) <= 0:
			continue
		var tgt = lv.nearest_actor(p.global_position, 300.0, "enemy")
		var aimp: Vector2 = tgt.global_position if tgt else p.global_position + Vector2(80, 0)
		p.mp = p.max_mp
		p.skill_cds.clear()
		p.gcd = 0.0
		var ok = SkillExec.cast(p, id, Game.skill_level(id), aimp)
		log_("cast %s -> %s" % [id, str(ok)])
		await _wait(0.45)
		n += 1
		if take_shots and n % 4 == 1:
			await shot("skill_" + id)
		p.hp = p.max_hp
	# basic attacks
	for i in 12:
		p.attack_cd = 0.0
		p.basic_attack()
		await _wait(0.12)
	await _wait(1.5)
	if take_shots:
		await shot("after_fight")
	p.hp = p.max_hp
	# monsters attack the player for a bit (AI test)
	p.invuln_t = 0.0
	await _wait(2.5)
	p.hp = p.max_hp
	# night test
	if take_shots:
		Game.world["time"] = Game.DAY_LEN * 0.92
		await _wait(0.6)
		await shot("night")
		Game.world["time"] = Game.DAY_LEN * 0.4


func _dungeon(M) -> void:
	var lv = Game.level_node
	var ds: Array = Game.world["dungeons"]
	log_("dungeons in world: %d" % ds.size())
	if ds.is_empty():
		return
	var d: Dictionary = ds[0]
	for x in ds:
		if int(x["rank"]) > int(d["rank"]):
			d = x
	lv.enter_dungeon(d)
	await _wait(1.8)
	var dl = Game.level_node
	log_("in dungeon: %s rooms=%d" % [str(dl is DungeonLevel), dl.design["rooms"].size()])
	await shot("dungeon_start")
	var p = Game.player_node
	# walk into a neighbouring room
	for c in dl.design["rooms"]:
		if c != dl.start_cell and c != dl.boss_cell:
			p.global_position = dl.room_center_px(c) + Vector2(0, 20)
			break
	await _wait(1.5)
	await shot("dungeon_room")
	p.hp = p.max_hp
	p.global_position = dl.room_center_px(dl.boss_cell) + Vector2(0, 60)
	p.invuln_t = 5.0
	await _wait(2.0)
	await shot("boss_room")
	if dl.boss and is_instance_valid(dl.boss):
		dl.boss.take_damage(int(dl.boss.hp) + 10, {"src": p})
	await _wait(1.6)
	for ch in get_tree().get_nodes_in_group("interactable"):
		if ch is Chest and not ch.opened:
			ch.interact(p)
	await _wait(1.5)
	await shot("boss_loot")
	dl.exit_dungeon()
	await _wait(1.5)
	log_("back in overworld: %s" % str(Game.level_node is Overworld))


func _trap_test(M) -> void:
	var d := {"name": "Trap Hall", "rank": 10, "biome": "cave", "wall": "cave", "grid": Vector2i(3, 1), "rooms": {},
		"start": Vector2i(0, 0), "boss_room": Vector2i(2, 0), "boss": "ogre", "seed": 5}
	for x in 3:
		d["rooms"][Vector2i(x, 0)] = DungeonGen.empty_room("large" if x == 1 else "medium")
	d["rooms"][Vector2i(0, 0)]["doors"]["e"] = true
	d["rooms"][Vector2i(1, 0)]["doors"]["w"] = true
	d["rooms"][Vector2i(1, 0)]["doors"]["e"] = true
	d["rooms"][Vector2i(2, 0)]["doors"]["w"] = true
	var r: Dictionary = d["rooms"][Vector2i(1, 0)]
	r["traps"] = [{"type": "spike", "pos": Vector2i(3, 3)}, {"type": "arrow", "pos": Vector2i(1, 6)}, {"type": "poison_gas", "pos": Vector2i(6, 3)},
		{"type": "boulder", "pos": Vector2i(9, 6)}, {"type": "teleport", "pos": Vector2i(12, 3)}, {"type": "pitfall", "pos": Vector2i(3, 9)},
		{"type": "bomb", "pos": Vector2i(6, 9)}, {"type": "mimic", "pos": Vector2i(12, 9)}]
	r["spawners"] = [{"type": "nest", "pos": Vector2i(15, 3)}, {"type": "totem", "pos": Vector2i(15, 9)}, {"type": "circle", "pos": Vector2i(9, 2)}, {"type": "grave", "pos": Vector2i(9, 10)}]
	r["treasures"] = [{"type": "gold_chest", "pos": Vector2i(17, 6)}]
	r["tiles"] = {Vector2i(5, 6): "water", Vector2i(6, 6): "water", Vector2i(13, 6): "lava", Vector2i(14, 6): "lava", Vector2i(10, 8): "cliff", Vector2i(11, 8): "cliff", Vector2i(7, 1): "wall", Vector2i(8, 1): "wall"}
	r["tile_styles"] = {Vector2i(7, 1): "crystal"}
	log_("trap design valid: '%s'" % DungeonGen.validate(d))
	M.enter_dungeon({"id": -5, "rank": 10, "biome": "cave", "custom": true, "design": d, "seed": 1}, false)
	await _wait(1.5)
	var dl = Game.level_node
	var p = Game.player_node
	p.global_position = dl.room_center_px(Vector2i(1, 0)) + Vector2(0, 40)
	p.invuln_t = 0.0
	await _wait(2.5)
	await shot("trap_room")
	var rr: Rect2i = dl.room_rects[Vector2i(1, 0)]
	var at := func(lp: Vector2i) -> Vector2:
		return dl.tile_px(Vector2i(rr.position.x + lp.x, rr.position.y + lp.y))
	for test in [["spike", Vector2i(3, 3)], ["gas", Vector2i(6, 3)], ["bomb", Vector2i(6, 9)]]:
		p.hp = p.max_hp
		p.invuln_t = 0.0
		p.global_position = at.call(test[1])
		await _wait(3.2)
		log_("trap %s: hp %.0f / %.0f" % [test[0], p.hp, p.max_hp])
	await shot("trap_bombs")
	p.global_position = at.call(Vector2i(3, 9))
	await _wait(1.5)
	log_("pitfall: player now at room %d, hp %.0f" % [dl.room_of(p.global_position), p.hp])
	p.global_position = at.call(Vector2i(12, 3))
	await _wait(0.6)
	log_("teleport rune: player now in room %d" % dl.room_of(p.global_position))
	p.global_position = at.call(Vector2i(12, 8))
	await _wait(1.0)
	var mims := 0
	for m in get_tree().get_nodes_in_group("monsters"):
		if m.mtype == "mimic" and not m.dormant:
			mims += 1
	log_("mimic awake: %d" % mims)
	p.hp = p.max_hp
	dl.exit_dungeon()
	await _wait(1.5)


func _editor(M) -> void:
	M.open_service("architect")
	await _wait(0.4)
	var ed = M.window
	ed._generate()
	await _wait(0.3)
	await shot("editor_quick")
	ed.mode = "builder"
	ed._build_page()
	await _wait(0.4)
	ed.add_to_room(ed.selected_room, "trap", "spike", Vector2i(3, 3))
	ed.add_to_room(ed.selected_room, "monster", "wolf", null)
	ed.room_canvas.queue_redraw()
	await _wait(0.3)
	await shot("editor_builder")
	ed._make_crystal()
	ed._test_run()
	await _wait(2.0)
	await shot("test_run")
	Game.level_node.exit_dungeon()
	await _wait(2.0)
	M.close_all()
	# place crystal dungeon
	for i in Game.player["inv"].size():
		var it = Game.player["inv"][i]
		if it is Dictionary and it.get("id", "") == "dungeon_crystal":
			Game.player_node.global_position = Vector2(256 * 16 + 8, 210 * 16)
			Game.use_item(i)
			break
	await _wait(1.0)
	await shot("crystal_placed")


func _save_load(M) -> void:
	log_("save: %s" % str(Game.save_game(false)))
	var lvl := int(Game.player["level"])
	M.load_slot(3)
	await _wait(1.2)
	log_("loaded level %d (was %d)" % [int(Game.player["level"]), lvl])
	await shot("after_load")
