extends Node
## Functional QA suite: drives real game code paths (key events, windows, shops, blacksmith,
## quests, dungeons, editor drag & drop, save/load) and reports PASS/FAIL lines.
## Run with:  godot --path . -- --autotest --qa [--shots=DIR]

var fails: Array = []
var passes := 0
var shots_dir := ""
var step := 0


func run_all() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
	var M = Game.main
	M.go_title(false)
	await _wait(0.3)
	await t_new_game(M)
	await t_leveling()
	await t_stats()
	await t_skills()
	await t_inventory()
	await t_keys(M)
	await t_rebind(M)
	await t_shops(M)
	await t_blacksmith(M)
	await t_quests(M)
	await t_teleport_death(M)
	await t_dungeon(M)
	await t_editor(M)
	await t_save_load(M)
	print("[qa] ==== %d passed, %d failed" % [passes, fails.size()])
	for f in fails:
		print("[qa] FAILED: ", f)
	get_tree().quit()


# ------------------------------------------------------------------ helpers
func ok(cond: bool, what: String) -> void:
	if cond:
		passes += 1
		print("[qa] pass  ", what)
	else:
		fails.append(what)
		print("[qa] FAIL  ", what)


func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _frames(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	if shots_dir == "":
		return
	await _frames(3)
	step += 1
	get_viewport().get_texture().get_image().save_png("%s/qa_%02d_%s.png" % [shots_dir, step, name])


func key(code: int, hold: float = 0.05) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	await _wait(hold)
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(2)


func pnode() -> Player:
	return Game.player_node


func give(id: String, n: int) -> void:
	Game.add_item(Items.stack(id, n))


func inv_index_of(pred: Callable) -> int:
	var a: Array = Game.player["inv"]
	for i in a.size():
		if a[i] is Dictionary and not a[i].is_empty() and pred.call(a[i]):
			return i
	return -1


func clear_bag() -> void:
	var a: Array = Game.player["inv"]
	for i in a.size():
		a[i] = null
	Game.inventory_changed.emit()


# ------------------------------------------------------------------ tests
func t_new_game(M) -> void:
	for cls in ["warrior", "ranger", "assassin", "mage", "priest"]:
		M.start_new_game("QA", cls, 3)
		await _wait(0.6)
		var c: Dictionary = GameData.CLASSES[cls]
		var w: Dictionary = Game.player["equip"]["weapon"]
		ok(w.get("base", "") == c["weapon"], "%s starts with class weapon %s (got %s)" % [cls, c["weapon"], w.get("base", "")])
		ok(Game.is_specialized_weapon(), "%s weapon counts as specialized" % cls)
		ok(pnode() != null and pnode().hp > 0 and pnode().hp == pnode().max_hp, "%s spawns at full HP" % cls)
		var t: Vector2i = Game.level_node.tile_of(pnode().global_position)
		ok(Game.level_node.gen.in_town(t.x, t.y), "%s spawns inside town" % cls)
	# the class with highest base stat matches spec
	var hi := {"warrior": "str", "ranger": "dex", "assassin": "luk", "mage": "int", "priest": "mnd"}
	for cls in hi:
		var b: Dictionary = GameData.CLASSES[cls]["base"]
		var best := ""
		var bv := -1
		for s in b:
			if int(b[s]) > bv:
				bv = int(b[s])
				best = s
		ok(best == hi[cls], "%s has highest base %s (got %s)" % [cls, hi[cls], best])
	M.start_new_game("QA", "warrior", 3)
	await _wait(0.6)
	# level curve near town is gentle
	var g: WorldGen = Game.level_node.gen
	ok(g.level_at(256, 256 + 26 + 10) <= 3, "monsters 10 tiles outside the wall are Lv<=3 (got %d)" % g.level_at(256, 292))
	ok(g.level_at(256, 256 + 26 + 25) <= 7, "monsters 25 tiles outside the wall are Lv<=7 (got %d)" % g.level_at(256, 307))
	ok(g.level_at(256, 256 + 240) >= 95, "edge of the world is Lv95+ (got %d)" % g.level_at(256, 496))


func t_leveling() -> void:
	var p := pnode()
	p.hp = 1.0
	p.mp = 0.0
	var sp0 := int(Game.player["stat_points"])
	var kp0 := int(Game.player["skill_points"])
	Game.add_xp(GameData.xp_to_next(1))
	await _frames(2)
	ok(int(Game.player["level"]) == 2, "level up 1 -> 2")
	ok(int(Game.player["stat_points"]) == sp0 + 10, "level up gives +10 stat points")
	ok(int(Game.player["skill_points"]) == kp0 + 5, "level up gives +5 skill points")
	ok(absf(p.hp - p.max_hp) < 1.0 and absf(p.mp - p.max_mp) < 1.0, "level up restores full HP and MP (hp %.0f/%.0f mp %.0f/%.0f)" % [p.hp, p.max_hp, p.mp, p.max_mp])
	Game.add_xp(99999999)
	ok(int(Game.player["level"]) == 100, "level is capped at 100 (got %d)" % int(Game.player["level"]))
	ok(int(Game.player["stat_points"]) == sp0 + 990 and int(Game.player["skill_points"]) == kp0 + 495, "99 level-ups grant 990 stat / 495 skill points")
	Game.add_xp(5000)
	ok(int(Game.player["level"]) == 100 and int(Game.player["xp"]) == 0, "no XP gained past level 100")


func t_stats() -> void:
	var pairs := {"str": ["patk", "max_hp"], "vit": ["max_hp", "pdef"], "int": ["matk", "max_mp"], "mnd": ["max_mp", "mdef"],
		"dex": ["aspd"], "luk": ["crit", "crit_dmg", "drop"]}
	for st in pairs:
		var before := Game.stats.duplicate()
		Game.allocate_stat(st, 50)
		for k in pairs[st]:
			ok(float(Game.stats[k]) > float(before[k]), "+50 %s raises %s (%.2f -> %.2f)" % [st.to_upper(), k, float(before[k]), float(Game.stats[k])])
	for k in ["max_hp", "max_mp", "patk", "matk", "pdef", "mdef", "move", "aspd", "crit", "crit_dmg"]:
		ok(Game.stats.has(k), "stat sheet has %s" % k)
	for el in ["light", "dark", "fire", "water", "earth", "wind"]:
		ok(Game.stats.has("res_" + el), "stat sheet has %s resistance" % el)


func t_skills() -> void:
	var cls: String = Game.player["class"]
	var ids := GameData.skills_for(cls)
	var act := 0
	var pas := 0
	var els := {}
	for id in ids:
		if GameData.SKILLS[id]["type"] == "active":
			act += 1
			els[GameData.SKILLS[id]["el"]] = true
		else:
			pas += 1
	ok(act == 10 and pas == 10, "%s tree has 10 active + 10 passive (got %d/%d)" % [cls, act, pas])
	for c in ["warrior", "ranger", "assassin", "mage", "priest"]:
		var a := 0
		var pp := 0
		for id in GameData.skills_for(c):
			if GameData.SKILLS[id]["type"] == "active":
				a += 1
			else:
				pp += 1
		ok(a == 10 and pp == 10, "%s: 10 actives + 10 passives" % c)
	var all_els := {}
	for id in GameData.SKILLS:
		all_els[GameData.SKILLS[id]["el"]] = true
	for el in ["light", "dark", "fire", "water", "earth", "wind"]:
		ok(all_els.has(el), "some skill uses element %s" % el)
	# prerequisites are enforced
	var gated := ""
	for id in ids:
		if not GameData.SKILLS[id]["req"].is_empty():
			gated = id
			break
	ok(Game.skill_unlock_reason(gated) != "", "skill %s is locked until its prerequisite is learned" % gated)
	Game.player["skill_points"] = 999
	for i in 5:
		for id in ids:
			Game.learn_skill(id, 5)
	ok(Game.skill_level(gated) > 0, "skill %s learnable after prerequisites" % gated)
	# only 4 actives on the bar, passives rejected
	var actives := []
	for id in ids:
		if GameData.SKILLS[id]["type"] == "active" and Game.skill_level(id) > 0:
			actives.append(id)
	for i in 4:
		Game.set_hot_skill(i, actives[i])
	Game.set_hot_skill(0, actives[4])
	ok(Game.player["hot_skills"].size() == 4 and Game.player["hot_skills"][0] == actives[4], "hotbar holds exactly 4 skills")
	var passive := ""
	for id in ids:
		if GameData.SKILLS[id]["type"] == "passive":
			passive = id
			break
	Game.set_hot_skill(1, passive)
	ok(Game.player["hot_skills"][1] != passive, "passive skills cannot be put on the hotbar")
	# casting every learned active works
	var p := pnode()
	var n_ok := 0
	for id in actives:
		p.skill_cds.clear()
		p.gcd = 0.0
		p.mp = p.max_mp
		p.hp = p.max_hp
		p.bot_aim = p.global_position + Vector2(60, 0)
		if p.try_cast(id):
			n_ok += 1
		await _wait(0.2)
	ok(n_ok == actives.size(), "all %d learned class actives can be cast (%d ok)" % [actives.size(), n_ok])
	await _wait(1.0)
	# dash makes you immune
	p.invuln_t = 0.0
	p.dash_cd = 0.0
	p.try_dash()
	var hp0 := p.hp
	var dealt := p.take_damage(500, {})
	ok(dealt == 0 and p.hp == hp0, "dash grants immunity to attacks")
	await _wait(0.6)


func t_inventory() -> void:
	clear_bag()
	give("pot_hp_s", 30)
	give("pot_hp_s", 80)
	ok(Game.count_item("pot_hp_s") == 110, "stacking potions (110 total)")
	var i := inv_index_of(func(it): return it.get("id", "") == "pot_hp_s")
	ok(Game.split_slot(i, 10), "split a stack")
	var stacks := 0
	for it in Game.player["inv"]:
		if it is Dictionary and it.get("id", "") == "pot_hp_s":
			stacks += 1
	ok(stacks >= 2 and Game.count_item("pot_hp_s") == 110, "split keeps total and makes a new stack")
	Game.stack_all()
	give("ore_iron", 5)
	for k in 4:
		Game.add_item(Items.random_gear(20, k))
	Game.add_item(Items.gen_gear("ring", 10, 2))
	Game.add_item(Items.gen_gear("robe", 10, 1))
	for mode in ["type", "rarity", "name", "value"]:
		Game.sort_inventory(mode)
		var first = Game.player["inv"][0]
		ok(first is Dictionary and not first.is_empty(), "sort by %s puts items first" % mode)
	Game.sort_inventory("type")
	ok(Items.is_gear(Game.player["inv"][0]), "sort by type puts gear first")
	var j := inv_index_of(func(it): return it.get("id", "") == "ore_iron")
	Game.remove_at(j, 2)
	ok(Game.count_item("ore_iron") == 3, "discard 2 of a stack")
	j = inv_index_of(func(it): return it.get("id", "") == "ore_iron")
	Game.remove_at(j)
	ok(Game.count_item("ore_iron") == 0, "discard whole stack")
	# equip / unequip a ring into the second ring slot
	var r := inv_index_of(func(it): return Items.is_gear(it) and Items.category(it) == "ring")
	ok(Game.equip_from_inv(r, "ring2") and not Game.player["equip"]["ring2"].is_empty(), "equip ring into ring slot 2")
	ok(Game.unequip("ring2"), "unequip ring")
	# consumables heal
	var p := pnode()
	p.hp = 10.0
	Game._item_cd = 0.0
	var pi := inv_index_of(func(it): return it.get("id", "") == "pot_hp_s")
	Game.use_item(pi)
	ok(p.hp > 10.0, "HP potion heals (%.0f)" % p.hp)
	# bag expansion
	var bs := int(Game.player["bag_size"])
	Game.add_gold(100000)
	ok(Game.expand_bag() and int(Game.player["bag_size"]) == bs + Game.BAG_STEP and Game.player["inv"].size() == bs + Game.BAG_STEP, "bag can be expanded with gold")
	# inventory UI filter hides non-matching items
	Game.main.open_menu("inventory")
	await _wait(0.3)
	var page = _find(Game.main.window, InventoryPage)
	ok(page != null, "inventory page opens")
	if page:
		page.filter = "consumable"
		page.refresh()
		var vis := 0
		var bad := 0
		for s in page.inv_slots:
			if s.visible:
				vis += 1
				if s.item.is_empty() or Items.filter_group(s.item) != "consumable":
					bad += 1
		ok(vis > 0 and bad == 0, "consumable filter shows only consumables (%d shown)" % vis)
		page.filter = "accessory"
		page.refresh()
		bad = 0
		vis = 0
		for s in page.inv_slots:
			if s.visible:
				vis += 1
				if not (Items.is_gear(s.item) and Items.category(s.item) in ["ring", "necklace", "bracelet"]):
					bad += 1
		ok(vis > 0 and bad == 0, "accessory filter shows only accessories (%d shown)" % vis)
		page.filter = "all"
		page.refresh()
		await shot("inventory")
	Game.main.close_all()
	await _wait(0.2)


func _find(n: Node, cls) -> Node:
	if n == null:
		return null
	if is_instance_of(n, cls):
		return n
	for c in n.get_children():
		var r = _find(c, cls)
		if r:
			return r
	return null


func t_keys(M) -> void:
	await key(KEY_I)
	await _wait(0.2)
	ok(M.window is GameMenu and M.window.current == "inventory", "I opens inventory")
	await key(KEY_K)
	await _wait(0.2)
	ok(M.window is GameMenu and M.window.current == "skills", "K switches to skills")
	await key(KEY_ESCAPE)
	await _wait(0.2)
	ok(M.window == null, "Esc closes the menu")
	ok(not get_tree().paused, "game unpaused after closing menu")
	await key(KEY_M)
	await _wait(0.2)
	ok(M.window is GameMenu and M.window.current == "map", "M opens map")
	await shot("map")
	await key(KEY_M)
	await _wait(0.2)
	ok(M.window == null, "M again closes map")
	await key(KEY_ESCAPE)
	await _wait(0.2)
	ok(M.window is GameMenu and M.window.current == "system", "Esc in game opens the game menu")
	await key(KEY_ESCAPE)
	await _wait(0.2)
	# skill hotkey 1
	var p := pnode()
	var sid: String = Game.player["hot_skills"][0]
	p.skill_cds.clear()
	p.gcd = 0.0
	p.mp = p.max_mp
	p.bot_aim = p.global_position + Vector2(50, 0)
	await key(KEY_1)
	await _wait(0.1)
	ok(p.skill_cds.has(sid), "key 1 casts skill in slot 1 (%s)" % sid)
	# consumable hotkey Z
	Game.player["hot_items"][0] = "pot_hp_s"
	p.hp = p.max_hp * 0.3
	Game._item_cd = 0.0
	var hp0 := p.hp
	await key(KEY_Z)
	ok(p.hp > hp0, "key Z uses the potion in consumable slot 1")
	# dash key
	p.dash_cd = 0.0
	await key(KEY_SPACE)
	ok(p.dash_cd > 0.0, "Space dashes")
	await _wait(0.5)


func t_rebind(M) -> void:
	var p := pnode()
	Settings.set_binding("skill_2", 0, ["key", KEY_Q])
	var sid: String = Game.player["hot_skills"][1]
	p.skill_cds.clear()
	p.gcd = 0.0
	p.mp = p.max_mp
	await key(KEY_Q)
	await _wait(0.1)
	ok(p.skill_cds.has(sid), "rebound skill slot 2 to Q and Q casts it")
	p.skill_cds.clear()
	p.gcd = 0.0
	await key(KEY_2)
	ok(not p.skill_cds.has(sid), "old key 2 no longer casts slot 2")
	Settings.set_binding("item_2", 0, ["key", KEY_G])
	ok(Settings.action_text("item_2") == "G", "consumable hotkey rebinds (shows %s)" % Settings.action_text("item_2"))
	Settings.set_binding("item_1", 0, ["key", KEY_G])
	ok(Settings.action_text("item_2") == "-" or Settings.binds["item_2"].is_empty() or Settings.action_text("item_2") != "G", "binding a key elsewhere removes the conflict")
	Settings.reset_binds()
	ok(Settings.action_text("skill_2") == "2", "reset hotkeys to default")
	M.open_menu("settings")
	await _wait(0.3)
	await shot("settings")
	M.close_all()
	await _wait(0.2)


func t_shops(M) -> void:
	clear_bag()
	Game.player["gold"] = 5000
	M.open_service("potion")
	await _wait(0.3)
	var w = M.window
	ok(w is ShopWindow, "potion shop opens")
	var stock: Array = w._stock()
	var idx := -1
	for i in stock.size():
		if stock[i]["id"] == "pot_hp_s":
			idx = i
	var g0 := int(Game.player["gold"])
	w._buy(idx, false)
	ok(Game.count_item("pot_hp_s") == 1 and int(Game.player["gold"]) < g0, "buy a potion")
	# full bag: partial stack purchase must only charge for what fits
	for k in Game.player["inv"].size():
		if Game.player["inv"][k] == null:
			Game.player["inv"][k] = Items.gen_gear("sword", 1, 0)
	var gi := inv_index_of(func(it): return it.get("id", "") == "pot_hp_s")
	Game.player["inv"][gi]["qty"] = 95
	var g1 := int(Game.player["gold"])
	w._do_buy(stock[idx], 10, 10, idx)
	ok(Game.count_item("pot_hp_s") == 99 and int(Game.player["gold"]) == g1 - 40, "full bag: bought 4 and paid for 4 (have %d, paid %d)" % [Game.count_item("pot_hp_s"), g1 - int(Game.player["gold"])])
	# sell
	var si := inv_index_of(func(it): return Items.is_gear(it))
	var g2 := int(Game.player["gold"])
	w._sell(si)
	ok(int(Game.player["gold"]) > g2 and Game.player["inv"][si] == null, "sell gear")
	M.close_all()
	clear_bag()
	for shop in ["gear", "food", "magic", "artifact"]:
		M.open_service(shop)
		await _wait(0.25)
		ok(M.window is ShopWindow and M.window._stock().size() > 0, "%s shop has stock" % shop)
		M.close_all()
	# magic shop: a spellbook teaches a tome skill
	M.open_service("magic")
	await _wait(0.2)
	var mw = M.window
	var ms: Array = mw._stock()
	for i in ms.size():
		if ms[i]["id"] == "book_fire":
			mw._buy(i, false)
	M.close_all()
	var bi := inv_index_of(func(it): return it.get("id", "") == "book_fire")
	ok(bi >= 0, "bought Fire spellbook")
	Game.use_item(bi)
	ok("tome_flame_orb" in Game.player["tomes"], "reading the spellbook unlocks the Flame Orb tome skill")
	# artifact shop sells rare+ gear
	var art_ok := true
	for it in Game.shops["artifact"]:
		if int(it.get("rarity", 0)) < 3:
			art_ok = false
	ok(art_ok, "artifact shop only sells Epic+ items")
	await _wait(0.1)


func t_blacksmith(M) -> void:
	clear_bag()
	Game.player["gold"] = 100000
	M.open_service("blacksmith")
	await _wait(0.3)
	var w = M.window
	ok(w is BlacksmithWindow, "blacksmith opens")
	w.craft_type = "bow"
	w.craft_tier = 0
	var r: Dictionary = w._recipe("bow", 0)
	for id in r["need"]:
		give(id, int(r["need"][id]))
	w._craft(r)
	await _wait(0.2)
	var bi := inv_index_of(func(it): return Items.is_gear(it) and it["base"] == "bow")
	ok(bi >= 0 and int(Game.player["inv"][bi]["rarity"]) >= 1, "craft a bow (rarity >= Uncommon)")
	for c in Game.main.menu_layer.get_children():
		if not (c is GameWindow):
			c.queue_free()
	await _frames(2)
	var it: Dictionary = Game.player["inv"][bi]
	give("enchant_stone", 50)
	w.mode = "enchant"
	w.sel_ref = {"where": "inv", "index": bi, "item": it}
	for k in 3:
		w._enchant()
	ok(int(it.get("enchant", 0)) == 3, "enchant +3 (100%% success tiers), got +%d" % int(it.get("enchant", 0)))
	var before: Array = it["affixes"].duplicate(true)
	give("arcane_dust", 50)
	w.mode = "reroll"
	var changed := false
	for k in 5:
		w._reroll()
		if it["affixes"] != before:
			changed = true
	ok(changed, "reroll changes affixes")
	w.mode = "salvage"
	w.sel_ref = {"where": "inv", "index": bi, "item": it}
	var dust0 := Game.count_item("arcane_dust")
	w._salvage()
	ok(Game.player["inv"][bi] == null and Game.count_item("arcane_dust") > dust0, "salvage gives arcane dust")
	await shot("blacksmith")
	M.close_all()
	await _wait(0.2)


func t_quests(M) -> void:
	Game.player["quests"] = []
	Game.refresh_board(true)
	var hunt := -1
	for i in Game.world["board"].size():
		if Game.world["board"][i]["type"] == "hunt":
			hunt = i
			break
	ok(hunt >= 0, "guild board has a hunt quest")
	if hunt < 0:
		return
	ok(Game.accept_quest(hunt), "accept a quest")
	var q: Dictionary = Game.player["quests"][0]
	for k in int(q["need"]):
		Game.on_monster_killed(q["target"], "normal")
	ok(Quests.is_complete(q), "killing %d %s completes the hunt quest" % [int(q["need"]), q["target"]])
	var g0 := int(Game.player["gold"])
	var gp0 := int(Game.player["guild_points"])
	ok(Game.turn_in_quest(0) and int(Game.player["gold"]) > g0 and int(Game.player["guild_points"]) > gp0, "turn in quest for gold + guild points")
	M.open_service("guild")
	await _wait(0.3)
	await shot("guild")
	M.close_all()
	await _wait(0.2)


func t_teleport_death(M) -> void:
	var lv = Game.level_node
	var p := pnode()
	p.global_position = Vector2(256 * 16 + 8, 300 * 16)
	lv._update_chunks(true)
	await _wait(0.3)
	p.start_town_teleport()
	await _wait(1.9)
	var t: Vector2i = lv.tile_of(p.global_position)
	ok(lv.gen.in_town(t.x, t.y), "T channel teleports back to town")
	p.global_position = Vector2(256 * 16 + 8, 300 * 16)
	await _wait(0.2)
	var g0 := int(Game.player["gold"])
	p.invuln_t = 0.0
	# disable Last Stand / Resurrection passives for this check
	p.passive_ready["last_stand"] = 1e12
	p.passive_ready["revive"] = 1e12
	for k in ["block", "dodge", "mana_shield"]:
		Game.stats[k] = 0.0
	p.shield = 0.0
	p.take_damage(int(p.hp) + 10, {})
	ok(p.dead, "player can die")
	await _wait(3.0)
	t = lv.tile_of(p.global_position)
	ok(not p.dead and lv.gen.in_town(t.x, t.y), "after death you wake up in town")
	ok(int(Game.player["gold"]) < g0 or g0 == 0, "death costs some gold")
	# monsters near town are low level, guards protect the gates
	var guards := get_tree().get_nodes_in_group("team_player").filter(func(a): return a is Guard)
	ok(guards.size() >= 4, "town gates have guards (%d)" % guards.size())


func t_dungeon(M) -> void:
	var lv = Game.level_node
	var ds: Array = Game.world["dungeons"]
	ok(ds.size() > 0, "hidden dungeons exist in the world (%d)" % ds.size())
	var ranks := {}
	for d in ds:
		ranks[int(d["rank"])] = true
		ok(int(d["rank"]) >= 1 and int(d["rank"]) <= 100, "dungeon %d rank %d in 1..100" % [d["id"], int(d["rank"])])
		ok(float(d["expires"]) > float(Game.world["total"]), "dungeon %d has a limited lifetime" % d["id"])
	# expiry removes a dungeon
	var victim: Dictionary = ds[ds.size() - 1]
	victim["expires"] = float(Game.world["total"]) - 1.0
	lv._ensure_dungeons()
	var still := false
	for d in Game.world["dungeons"]:
		if d["id"] == victim["id"]:
			still = true
	ok(not still, "expired dungeon disappears from the world")
	# enter & clear one
	var d: Dictionary = Game.world["dungeons"][0]
	var did: int = d["id"]
	var n_before: int = Game.world["dungeons"].size()
	var cleared0 := int(Game.player["dungeons_cleared"])
	lv.enter_dungeon(d)
	await _wait(1.5)
	var dl = Game.level_node
	ok(dl is DungeonLevel, "entered a dungeon")
	if not (dl is DungeonLevel):
		return
	ok(dl.design["rooms"].size() >= 3, "dungeon has several rooms (%d)" % dl.design["rooms"].size())
	var minis := 0
	for m in get_tree().get_nodes_in_group("monsters"):
		if m.tier == "mini":
			minis += 1
	ok(minis >= 1, "dungeon has mini bosses (%d)" % minis)
	ok(dl.boss != null and is_instance_valid(dl.boss), "dungeon has a main boss")
	var start: Vector2i = dl.start_cell
	var far := DungeonGen.bfs(dl.design["rooms"], start)
	var maxd := 0
	for c in far:
		maxd = maxi(maxd, int(far[c]))
	ok(int(far.get(dl.boss_cell, -1)) == maxd, "boss room is the farthest room from the start")
	var traps := get_tree().get_nodes_in_group("traps").size()
	var chests := get_tree().get_nodes_in_group("interactable").filter(func(n): return n is Chest).size()
	ok(chests > 0, "dungeon has treasure chests (%d)" % chests)
	print("[qa] info: traps=%d chests=%d minis=%d" % [traps, chests, minis])
	var p := pnode()
	p.global_position = dl.room_center_px(dl.boss_cell) + Vector2(0, 60)
	p.invuln_t = 5.0
	await _wait(1.0)
	await shot("boss_room")
	dl.boss.take_damage(int(dl.boss.hp) + 10, {"src": p})
	await _wait(1.5)
	var boss_chest = null
	for c in get_tree().get_nodes_in_group("interactable"):
		if c is Chest and c.unique_monster != "":
			boss_chest = c
	ok(boss_chest != null, "boss drops a treasure chest")
	var uniq_before := inv_index_of(func(it): return Items.is_gear(it) and it.get("unique", "") != "")
	if boss_chest:
		p.global_position = boss_chest.global_position + Vector2(0, 12)
		await _wait(0.2)
		boss_chest.interact(p)
		await _wait(2.5)
	var uniq := inv_index_of(func(it): return Items.is_gear(it) and it.get("unique", "") != "")
	ok(uniq >= 0 and uniq_before < 0, "boss treasure gives a unique item (%s)" % (Items.name_of(Game.player["inv"][uniq]) if uniq >= 0 else "none"))
	ok(int(Game.player["dungeons_cleared"]) == cleared0 + 1, "dungeon clear is counted")
	dl.exit_dungeon()
	await _wait(1.6)
	ok(Game.level_node is Overworld, "exit portal returns to the overworld")
	var exists := false
	for x in Game.world["dungeons"]:
		if x["id"] == did:
			exists = true
	ok(not exists, "cleared dungeon disappears (only clearable once)")


func t_editor(M) -> void:
	Game.designs = []
	M.open_service("architect")
	await _wait(0.4)
	var ed = M.window
	ok(ed is DungeonEditor, "dungeon editor opens")
	if not (ed is DungeonEditor):
		return
	# quick setup
	ed.opts["grid_w"] = 3
	ed.opts["grid_h"] = 3
	ed.opts["room_count"] = 6
	ed.opts["traps"] = ["spike", "bomb"]
	ed.opts["monsters"] = ["wolf"]
	ed.opts["miniboss_count"] = 1
	ed.opts["treasures"] = 2
	ed._generate()
	ok(ed.design["rooms"].size() == 6, "quick setup generates 6 rooms (got %d)" % ed.design["rooms"].size())
	var only_wolves := true
	var trap_ok := true
	for c in ed.design["rooms"]:
		for m in ed.design["rooms"][c].get("monsters", []):
			if m["type"] != "wolf":
				only_wolves = false
		for t in ed.design["rooms"][c].get("traps", []):
			if not t["type"] in ["spike", "bomb"]:
				trap_ok = false
	ok(only_wolves, "monster selection is respected")
	ok(trap_ok, "trap selection is respected")
	ok(ed._validate(false), "generated design is valid")
	# builder: manual design
	ed.mode = "builder"
	ed._build_page()
	await _wait(0.3)
	for c in ed.design["rooms"].keys():
		ed.remove_room(c)
	ok(ed.design["rooms"].is_empty(), "remove all rooms")
	ed.add_room(Vector2i(0, 0))
	ed.add_room(Vector2i(1, 0))
	ed.add_room(Vector2i(1, 1))
	ok(ed.design["rooms"][Vector2i(0, 0)]["doors"]["e"] and ed.design["rooms"][Vector2i(1, 0)]["doors"]["w"], "new room auto-connects to its neighbour")
	ed.add_room(Vector2i(2, 2))
	ok(not ed._validate(false), "an unreachable room makes the design invalid")
	ed.add_room(Vector2i(2, 1))
	var doors := func(c: Vector2i, dn: String) -> bool:
		return ed.design["rooms"][c]["doors"].get(dn, false)
	if not doors.call(Vector2i(2, 1), "s"):
		ed.toggle_door(Vector2i(2, 1), "s")
	if not doors.call(Vector2i(1, 1), "e"):
		ed.toggle_door(Vector2i(1, 1), "e")
	ok(doors.call(Vector2i(2, 2), "n") and doors.call(Vector2i(2, 1), "w"), "door toggles connect rooms up/down/left/right")
	ed.design["start"] = Vector2i(0, 0)
	ed.design["boss_room"] = Vector2i(2, 2)
	ok(ed._validate(false), "connected design with start + boss is valid: %s" % ed.status_lbl.text)
	# drag & drop through the canvases
	ed.select_room(Vector2i(1, 0))
	await _frames(2)
	var gc = ed.grid_canvas
	gc._fit()
	var drop_pos := Vector2(1 * gc.CW + gc.CW / 2.0, 0 * gc.CH + gc.CH / 2.0)
	var data := {"type": "palette", "cat": "monster", "id": "goblin"}
	ok(gc._can_drop_data(drop_pos, data), "grid accepts a dropped monster")
	gc._drop_data(drop_pos, data)
	gc._drop_data(drop_pos, data)
	var rm: Dictionary = ed.design["rooms"][Vector2i(1, 0)]
	var gob: Array = rm["monsters"].filter(func(e): return e["type"] == "goblin")
	ok(gob.size() == 1 and int(gob[0]["count"]) == 2 and not gob[0].has("pos"), "two goblins dropped on a room -> random spots (count 2)")
	var rc = ed.room_canvas
	var o: Vector2 = rc.offset()
	var tile_pos: Vector2 = o + Vector2(4.5, 3.5) * rc.TS
	var tdata := {"type": "palette", "cat": "trap", "id": "pitfall"}
	ok(rc._can_drop_data(tile_pos, tdata), "room view accepts a dropped trap")
	rc._drop_data(tile_pos, tdata)
	var pinned: Array = rm["traps"].filter(func(e): return e["type"] == "pitfall" and e.get("pos") == Vector2i(4, 3))
	ok(pinned.size() == 1, "trap dropped on a tile is pinned at (4,3)")
	rc._drop_data(o + Vector2(6.5, 2.5) * rc.TS, {"type": "palette", "cat": "treasure", "id": "gold_chest"})
	ok(rm["treasures"].filter(func(e): return e.get("pos") == Vector2i(6, 2)).size() == 1, "treasure pinned on a tile")
	gc._drop_data(drop_pos, {"type": "palette", "cat": "treasure", "id": "chest"})
	ok(rm["treasures"].filter(func(e): return not e.has("pos")).size() == 1, "treasure dropped on a room goes to a random spot")
	# paint terrain with wall styles
	ed.paint_tool = "wall"
	ed.paint_style = "crystal"
	rc._paint(o + Vector2(2.5, 2.5) * rc.TS, false)
	ed.paint_tool = "lava"
	rc._paint(o + Vector2(8.5, 5.5) * rc.TS, false)
	ed.paint_tool = "water"
	rc._paint(o + Vector2(9.5, 5.5) * rc.TS, false)
	ed.paint_tool = "cliff"
	rc._paint(o + Vector2(10.5, 5.5) * rc.TS, false)
	ok(rm["tiles"].get(Vector2i(2, 2)) == "wall" and rm["tile_styles"].get(Vector2i(2, 2)) == "crystal", "paint a crystal-style wall")
	ok(rm["tiles"].get(Vector2i(8, 5)) == "lava" and rm["tiles"].get(Vector2i(9, 5)) == "water" and rm["tiles"].get(Vector2i(10, 5)) == "cliff", "paint lava, water and cliff")
	rc._last_paint = Vector2i(-99, -99)
	rc._paint(o + Vector2(10.5, 5.5) * rc.TS, true)
	ok(not rm["tiles"].has(Vector2i(10, 5)), "right-click erases terrain")
	ed.design["rooms"][Vector2i(1, 1)]["miniboss"] = "ogre"
	ed.refresh_builder()
	await _wait(0.2)
	await shot("editor_builder")
	# test run: nothing gained/lost, returns to the editor
	var gold0 := int(Game.player["gold"])
	var xp0 := int(Game.player["xp"])
	var inv0: int = Game.player["inv"].filter(func(x): return x is Dictionary and not x.is_empty()).size()
	ed._test_run()
	await _wait(1.6)
	ok(Game.level_node is DungeonLevel and Game.test_run, "test run enters the custom dungeon")
	var tl = Game.level_node
	var pinned_traps := 0
	for tr in get_tree().get_nodes_in_group("traps"):
		if tr.type == "pitfall":
			pinned_traps += 1
	ok(pinned_traps == 1, "pinned pitfall exists in the test run")
	Game.add_gold(5000)
	if tl is DungeonLevel:
		tl.exit_dungeon()
	await _wait(2.4)
	ok(not Game.test_run and Game.level_node is Overworld, "test run ends back in the overworld")
	ok(int(Game.player["gold"]) == gold0 and int(Game.player["xp"]) == xp0, "test run changes nothing (gold %d->%d)" % [gold0, int(Game.player["gold"])])
	ok(M.window is DungeonEditor, "editor reopens after the test run")
	# crystal costs gold, placing it raises the dungeon
	ed = M.window
	var cost: int = ed.crystal_cost()
	Game.player["gold"] = cost - 1
	ed._make_crystal()
	ok(inv_index_of(func(it): return it.get("id", "") == "dungeon_crystal") < 0, "cannot afford the crystal -> none created")
	Game.player["gold"] = cost + 10
	ed._make_crystal()
	var ci := inv_index_of(func(it): return it.get("id", "") == "dungeon_crystal")
	ok(ci >= 0 and int(Game.player["gold"]) == 10, "Dungeon Crystal created for %d gold" % cost)
	M.close_all()
	await _wait(0.2)
	var p := pnode()
	var placed := false
	for attempt in 12:
		p.global_position = Vector2(256 * 16 + 8 + (attempt % 4 - 2) * 160, (205 - attempt * 3) * 16)
		p.bot_aim = p.global_position + Vector2(0, -40)
		Game.level_node._update_chunks(true)
		await _wait(0.2)
		Game.use_item(ci)
		await _wait(0.2)
		if Game.world["dungeons"].filter(func(x): return x.get("custom", false)).size() == 1:
			placed = true
			break
	var custom: Array = Game.world["dungeons"].filter(func(x): return x.get("custom", false))
	ok(placed and custom.size() == 1 and inv_index_of(func(it): return it.get("id", "") == "dungeon_crystal") < 0, "using the crystal in the wild places the custom dungeon (crystal consumed)")
	await shot("crystal_placed")


func t_save_load(M) -> void:
	var lv := int(Game.player["level"])
	var gold := int(Game.player["gold"])
	var nd: int = Game.world["dungeons"].size()
	var ndes: int = Game.designs.size()
	var got := [false]
	var cb := func(auto: bool): got[0] = auto
	Game.saved.connect(cb)
	Game._autosave_t = Game.AUTOSAVE_INTERVAL - 0.5
	await _wait(1.0)
	ok(got[0], "autosave fires after 60 seconds of play")
	Game.saved.disconnect(cb)
	Game.player["gold"] = 1
	M.load_slot(3)
	await _wait(1.0)
	ok(int(Game.player["level"]) == lv and int(Game.player["gold"]) == gold, "load restores level and gold")
	ok(Game.world["dungeons"].size() == nd, "load restores dungeons")
	ok(Game.designs.size() == ndes, "load restores dungeon designs")
	M.go_title(true)
	await _wait(0.4)
	ok(not Game.in_game and M.title != null, "return to title (autosaves)")
