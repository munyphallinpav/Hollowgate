extends Node
## NPC adventurer + guild Dungeon Hall tests.  godot --path . -- --autotest --npctest [--shots=DIR]

var fails: Array = []
var passes := 0
var shots_dir := ""
var step := 0


func ok(cond: bool, what: String) -> void:
	if cond:
		passes += 1
		print("[npc] pass  ", what)
	else:
		fails.append(what)
		print("[npc] FAIL  ", what)


func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func shot(name: String) -> void:
	if shots_dir == "":
		return
	for i in 3:
		await get_tree().process_frame
	step += 1
	DirAccess.make_dir_recursive_absolute(shots_dir)
	get_viewport().get_texture().get_image().save_png("%s/npc_%02d_%s.png" % [shots_dir, step, name])


## Average script + physics time per frame (ms) over a stretch of real frames.
func _frame_cost(secs: float) -> float:
	var total := 0.0
	var phys := 0.0
	var frames := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0:
		await get_tree().process_frame
		total += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		frames += 1
	var u0 := Time.get_ticks_usec()
	NpcWorld.tick(1.0)
	var tick_ms := (Time.get_ticks_usec() - u0) / 1000.0
	print("[npc] info: %d frames in %.1fs  process %.2f ms  physics %.2f ms  sim tick(50 npcs) %.2f ms  objects %d" % [frames, secs,
		total / maxf(1.0, frames), phys / maxf(1.0, frames), tick_ms, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	return phys / maxf(1.0, frames)


func _perf_only() -> void:
	print("[npc] perf: town, start")
	await _frame_cost(3.0)
	Game.player["level"] = 60
	for i in 40:
		NpcWorld.add_npc(55 + i % 10, false)
	var p := Game.player_node
	var lvn = Game.level_node
	var spot := Vector2(256 * 16 + 8, 330 * 16)
	p.global_position = spot
	lvn._update_chunks(true)
	await _wait(1.0)
	print("[npc] perf: wild, %d npcs, none live" % NpcWorld.npcs().size())
	await _frame_cost(3.0)
	var crowd := 0
	for n in NpcWorld.npcs():
		if crowd >= 12:
			break
		var off := Vector2.from_angle(crowd * 0.52) * (120.0 + 25.0 * (crowd % 4))
		n["state"] = "hunt"
		n["state_t"] = 999.0
		n["hunt_lv"] = 20
		n["pos"] = [spot.x + off.x, spot.y + off.y]
		n["dest"] = n["pos"].duplicate()
		crowd += 1
	lvn._adv_t = 0.0
	await _wait(0.6)
	print("[npc] perf: wild, %d live, idle" % get_tree().get_nodes_in_group("adventurers").size())
	await _frame_cost(3.0)
	for i in 14:
		lvn.spawn_monster(["wolf", "goblin", "slime", "skeleton", "bear"][i % 5], spot + Vector2.from_angle(i * 0.45) * 200.0, 20)
	await _wait(0.3)
	print("[npc] perf: wild, %d live, fighting" % get_tree().get_nodes_in_group("adventurers").size())
	await _frame_cost(4.0)
	await shot("perf_crowd")
	get_tree().quit()


## Sends a live adventurer from several town spots out through each gate and back.
func _gate_only() -> void:
	var n: Dictionary = NpcWorld.npcs()[0]
	var hero := Game.player_node
	var spots := NpcWorld.town_spots()
	var bad := 0
	for gi in 4:
		var g: Array = NpcWorld.GATES[gi]
		var outward: Vector2 = (g[1] - g[0]).normalized()
		var dest: Vector2 = g[1] * NpcWorld.T + outward * 300.0
		for si in [0, 3, 6, 9, -1, -2]:
			# -1 / -2: on the road's centre line, right behind the lamp posts at the south / north gates
			var sp: Vector2 = spots[si % spots.size()] if si >= 0 else (Vector2(4104, 4300) if si == -1 else Vector2(4104, 3900))
			hero.global_position = sp + Vector2(0, 30)
			n["state"] = "travel"
			n["pos"] = [sp.x, sp.y]
			n["dest"] = [dest.x, dest.y]
			n["state_t"] = 999.0
			var a = NpcWorld.actor_of(n)
			if a:
				a.global_position = sp
			Game.level_node._update_adventurers()
			await _wait(0.3)
			var out := false
			var trail := []
			for t in 120:
				await _wait(0.25)
				a = NpcWorld.actor_of(n)
				if a:
					hero.global_position = a.global_position + Vector2(0, 40)
					if t % 8 == 0:
						trail.append("(%d,%d)" % [int(a.global_position.x), int(a.global_position.y)])
				if not NpcWorld.in_town_px(Vector2(n["pos"][0], n["pos"][1])):
					out = true
					break
			if not out:
				bad += 1
			print("[npc] gate %d from spot %d: %s  %s" % [gi, si, "OUT" if out else "STUCK", " ".join(trail) if not out else ""])
	print("[npc] gate test: %d stuck" % bad)
	get_tree().quit()


func run_all() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
	var M = Game.main
	M.go_title(false)
	await _wait(0.3)
	M.start_new_game("Npc", "mage", 3)
	await _wait(1.5)
	if "--npcperf" in OS.get_cmdline_user_args():
		await _perf_only()
		return
	if "--gatetest" in OS.get_cmdline_user_args():
		await _gate_only()
		return
	var ns := NpcWorld.npcs()
	ok(ns.size() >= 2 and ns.size() <= 5, "game starts with 2-5 adventurers (%d)" % ns.size())
	var classes := {}
	for n in ns:
		classes[n["class"]] = true
		ok(n["state"] == "town", "%s starts in town" % n["name"])
		ok(not n["equip"]["weapon"].is_empty() and n["equip"]["weapon"]["base"] == GameData.CLASSES[n["class"]]["weapon"], "%s carries its class weapon" % n["name"])
		ok(NpcWorld.count(n, "pot_hp_s") > 0, "%s has potions in its bag" % n["name"])
		ok(n["hot_skills"][0] != "", "%s has a skill equipped (%s)" % [n["name"], n["hot_skills"][0]])
	await _wait(1.0)
	var live := get_tree().get_nodes_in_group("adventurers").size()
	ok(live >= 1, "adventurers walk around town as real characters (%d visible)" % live)
	await _wait(2.0)
	await shot("town_adventurers")
	# ---- interact -> profile
	var adv = null
	for a in get_tree().get_nodes_in_group("adventurers"):
		adv = a
		break
	if adv:
		Game.player_node.global_position = adv.global_position + Vector2(0, 10)
		await _wait(0.3)
		adv.interact(Game.player_node)
		await _wait(0.4)
		ok(M.window is NpcProfileWindow, "talking to an adventurer opens its profile")
		await shot("npc_profile")
		M.close_all()
		await _wait(0.2)
	# ---- live actors leave town through a gate and come back
	var walker: Dictionary = ns[0]
	var wa = NpcWorld.actor_of(walker)
	if wa:
		walker["state"] = "town"
		walker["visited"] = true
		walker["state_t"] = 0.0
		var left_live := false
		for t in 300:  # it may first finish its town business (stroll, guild) before heading out
			await _wait(0.2)
			var wp := Vector2(walker["pos"][0], walker["pos"][1])
			if not NpcWorld.in_town_px(wp):
				left_live = NpcWorld.actor_of(walker) != null or left_live
				break
		print("[npc] info: walker state=%s pos=%s live=%s" % [walker["state"], str(walker["pos"]), str(NpcWorld.actor_of(walker) != null)])
		ok(not NpcWorld.in_town_px(Vector2(walker["pos"][0], walker["pos"][1])), "a live adventurer walks out of town through a gate to go hunting")
		ok(left_live, "it was a real character while passing the gate")
		# now meet it outside and send it home
		var hero := Game.player_node
		hero.global_position = Vector2(walker["pos"][0], walker["pos"][1]) + Vector2(0, 30)
		Game.level_node._update_chunks(true)
		await _wait(1.0)
		NpcWorld._go_home(walker)
		var back := false
		for t in 250:
			await _wait(0.2)
			var a2 = NpcWorld.actor_of(walker)
			if a2:
				hero.global_position = a2.global_position + Vector2(0, 40)  # follow it
			if walker["state"] == "town" or NpcWorld.in_town_px(Vector2(walker["pos"][0], walker["pos"][1])):
				back = true
				break
		print("[npc] info: walker back state=%s pos=%s" % [walker["state"], str(walker["pos"])])
		ok(back, "a live adventurer walks back into town through a gate")
		hero.global_position = Game.level_node.town_spawn()
		Game.level_node._update_chunks(true)
		await _wait(0.5)
	# ---- fast-forward the simulation: ~2 hours of play
	var lv0 := {}
	for n in ns:
		lv0[n["id"]] = int(n["level"])
	Game.add_xp(4000)  # hero a few levels up so NPCs have someone to keep up with
	# the simulation is fast-forwarded without frames: hand every live actor back to the simulation first
	var lvn0 = Game.level_node
	for n in ns:
		if n.get("physical", false):
			lvn0._despawn_adventurer(n)
	lvn0._adv_t = 1e9
	var states := {}
	for sec in 7200:
		for n in NpcWorld.npcs().duplicate():
			NpcWorld._tick_npc(n, 1.0)
			states[n["state"]] = int(states.get(n["state"], 0)) + 1
		if sec % 60 == 0:
			Game.world["total"] = float(Game.world["total"]) + 60.0
		if sec % 1200 == 0 and sec > 0:
			Game.world["day"] = int(Game.world["day"]) + 1
			Game.refresh_board(true)
		if sec % 120 == 0:
			NpcWorld._top_up_board()
	lvn0._adv_t = 0.0
	print("[npc] info: states over 2h ", states)
	var kills := 0
	var quests := 0
	var lvl_up := 0
	var deaths := 0
	for n in ns:
		kills += int(n["kills"])
		quests += int(n.get("quests_done", 0)) + n["quests"].size()
		deaths += int(n["deaths"])
		if int(n["level"]) > int(lv0[n["id"]]):
			lvl_up += 1
		print("[npc] info: %s Lv%d->%d %s gold=%d kills=%d deaths=%d dungeons=%d quests_done=%d gear=%s/%s hot=%s" % [n["name"], int(lv0[n["id"]]), int(n["level"]), n["class"],
			int(n["gold"]), int(n["kills"]), int(n["deaths"]), int(n["dungeons_cleared"]), int(n.get("quests_done", 0)),
			Items.name_of(n["equip"]["weapon"]), Items.name_of(n["equip"]["armor"]), str(n["hot_skills"])])
	ok(kills > 50, "adventurers hunt monsters on their own (%d kills)" % kills)
	ok(lvl_up == ns.size(), "every adventurer levelled up (%d/%d)" % [lvl_up, ns.size()])
	ok(states.has("travel") and states.has("hunt") and states.has("return") and states.has("town"), "adventurers travel, hunt, return and rest")
	ok(quests > 0, "adventurers take guild quests (%d)" % quests)
	var spent := false
	for n in ns:
		if int(n["stat_points"]) == 0 and int(n["skill_points"]) == 0 and n["skills"].size() >= 4:
			spent = true
	ok(spent, "adventurers spend stat and skill points")
	var upgraded := false
	for n in ns:
		if int(n["equip"]["weapon"].get("ilvl", 1)) > 3:
			upgraded = true
	ok(upgraded, "adventurers upgrade their gear")
	# ---- growth with hero level, cap 50
	var before: int = NpcWorld.npcs().size()
	Game.add_xp(9999999)
	for i in 80:
		NpcWorld._grow()
	ok(NpcWorld.npcs().size() == NpcWorld.MAX_NPCS, "adventurer count grows with hero level up to the 50 cap (%d -> %d)" % [before, NpcWorld.npcs().size()])
	var hi := 0
	for n in NpcWorld.npcs():
		hi = maxi(hi, int(n["level"]))
	ok(hi >= 80, "new adventurers join near the hero's level (highest Lv %d)" % hi)
	NpcWorld.add_npc(10)
	ok(NpcWorld.npcs().size() == NpcWorld.MAX_NPCS, "never more than 50 adventurers")
	# ---- physical fight in the wild
	var hunter: Dictionary = {}
	for n in NpcWorld.npcs():
		if n["class"] in ["warrior", "mage"] and int(n["level"]) >= 60:
			hunter = n
			break
	var p := Game.player_node
	var lvn = Game.level_node
	var spot := Vector2(256 * 16 + 8, 330 * 16)
	p.global_position = spot
	lvn._update_chunks(true)
	await _wait(0.3)
	for n in NpcWorld.npcs():
		if n != hunter and n.get("physical", false):
			lvn._despawn_adventurer(n)
	hunter["state"] = "hunt"
	hunter["state_t"] = 999.0
	hunter["dest"] = [spot.x + 60, spot.y]
	hunter["pos"] = [spot.x + 60, spot.y]
	hunter["hunt_lv"] = 20
	lvn._update_adventurers()
	await _wait(0.3)
	var a = NpcWorld.actor_of(hunter)
	ok(a != null, "an adventurer near the hero becomes a real character")
	if a:
		var k0 := int(hunter["kills"])
		var mp0: float = a.mp
		for i in 5:
			var m = lvn.spawn_monster(["wolf", "goblin", "slime", "skeleton", "bear"][i], a.global_position + Vector2.from_angle(i * 1.2) * 70.0, 20)
		var casts := 0
		var gone := false
		for t in 60:
			await _wait(0.2)
			if not is_instance_valid(a):
				gone = true
				print("[npc] info: the hunter's actor went away: state=%s deaths=%d hp=%.2f" % [hunter["state"], int(hunter["deaths"]), float(hunter["hp_frac"])])
				break
			if not a.skill_cds.is_empty():
				casts += 1
			p.global_position = a.global_position + Vector2(0, 60)  # stay close (a far-off adventurer goes back to the simulation)
		await shot("adventurer_fight")
		ok(int(hunter["kills"]) > k0, "the adventurer kills monsters with its own attacks (%d kills)" % (int(hunter["kills"]) - k0))
		ok(casts > 0, "the adventurer uses its skills in combat")
		ok(not gone and not a.dead, "a strong adventurer survives a fight with weaker monsters")
	# ---- performance with a crowd of live adventurers
	var base := await _frame_cost(3.0)
	var crowd := 0
	for n in NpcWorld.npcs():
		if crowd >= 12:
			break
		if n.get("physical", false) or n["state"] == "dead":
			continue
		var off := Vector2.from_angle(crowd * 0.52) * (120.0 + 25.0 * (crowd % 4))
		n["state"] = "hunt"
		n["state_t"] = 999.0
		n["hunt_lv"] = 20
		n["pos"] = [spot.x + off.x, spot.y + off.y]
		n["dest"] = n["pos"].duplicate()
		crowd += 1
	lvn._adv_t = 0.0
	lvn._update_adventurers()
	for i in 10:
		lvn.spawn_monster(["wolf", "goblin", "slime", "skeleton", "bear"][i % 5], spot + Vector2.from_angle(i * 0.63) * 200.0, 20)
	await _wait(0.5)
	var live_n := get_tree().get_nodes_in_group("adventurers").size()
	var busy := await _frame_cost(4.0)
	print("[npc] info: frame cost without crowd %.2f ms, with %d live adventurers %.2f ms (script+physics)" % [base, live_n, busy])
	var lv_levels := []
	for adv_node in get_tree().get_nodes_in_group("adventurers"):
		lv_levels.append(int(adv_node.npc["level"]))
	print("[npc] info: crowd scene: monsters=%d allies=%d fx_over=%d fx_under=%d projectiles=%d entities=%d levels=%s" % [
		get_tree().get_nodes_in_group("monsters").size(), get_tree().get_nodes_in_group("allies").size(),
		lvn.fx_over.get_child_count(), lvn.fx_under.get_child_count(), lvn.fx_proj.get_child_count(), lvn.entities.get_child_count(), str(lv_levels)])
	ok(live_n >= 10, "a crowd of adventurers can be live at once (%d)" % live_n)
	ok(busy < 14.0, "a crowd of live adventurers stays cheap (%.2f ms per frame)" % busy)
	await shot("adventurer_crowd")
	for n in NpcWorld.npcs():
		if n.get("physical", false) and n != hunter:
			lvn._despawn_adventurer(n)
			if n["state"] != "dead":
				var ts := NpcWorld.town_spot(int(n["id"]))
				n["state"] = "town"
				n["state_t"] = 20.0
				n["pos"] = [ts.x, ts.y]
				n["dest"] = [ts.x, ts.y]
	# hero does not get XP for NPC kills
	# ---- Dungeon Hall
	Game.player["guild_points"] = 0
	ok(NpcWorld.hero_listing_cap() == 3, "Dungeon Hall starts with 3 listing slots")
	Game.player["guild_points"] = 99999
	ok(NpcWorld.hero_listing_cap() == 10, "Dungeon Hall grows to 10 slots at guild rank S")
	Game.player["guild_points"] = 0
	var made := 0
	var test_rank := int(NpcWorld.npcs()[10]["level"])
	for i in 4:
		var d := DungeonGen.generate(DungeonGen.default_options(test_rank, "cave"))
		d["name"] = "Test Vault %d" % i
		var it := Items.stack("dungeon_crystal", 1)
		it["design"] = d
		Game.add_item(it)
	var errs := []
	for i in 4:
		var idx := -1
		for k in Game.player["inv"].size():
			var it2 = Game.player["inv"][k]
			if it2 is Dictionary and it2.get("id", "") == "dungeon_crystal":
				idx = k
				break
		var e := NpcWorld.list_crystal(idx, 20, 25)
		if e == "":
			made += 1
		else:
			errs.append(e)
	ok(made == 3 and errs.size() == 1, "only 3 crystals can be listed at rank F (%d listed, refused: %s)" % [made, str(errs)])
	var mine := NpcWorld.hero_listings()
	NpcWorld.set_shares(int(mine[0]["id"]), 80, 90)
	ok(int(mine[0]["gold_pct"]) == NpcWorld.MAX_GOLD_SHARE and int(mine[0]["item_pct"]) == NpcWorld.MAX_ITEM_SHARE, "shares are capped (gold %d%%, items %d%%)" % [int(mine[0]["gold_pct"]), int(mine[0]["item_pct"])])
	# NPCs of a matching rank run the hero's dungeons
	var pay0 := int(Game.world["guild_payout"]["gold"])
	var runs := 0
	for n in NpcWorld.npcs():
		if absi(int(n["level"]) - test_rank) <= 4 and n["state"] != "dead":
			var l := NpcWorld._pick_listing(n)
			if not l.is_empty():
				NpcWorld._start_listing_run(n, l)
				n["state_t"] = 0.0
				NpcWorld._tick_npc(n, 1.0)
				runs += 1
	var plays := 0
	for l in mine:
		plays += int(l["plays"])
	print("[npc] info: runs=%d plays on hero dungeons=%d payout gold=%d items=%d" % [runs, plays, int(Game.world["guild_payout"]["gold"]), Game.world["guild_payout"]["items"].size()])
	ok(plays > 0, "adventurers of a matching rank run your listed dungeons (%d runs)" % plays)
	ok(int(Game.world["guild_payout"]["gold"]) > pay0, "you receive your gold share (%d)" % int(Game.world["guild_payout"]["gold"]))
	var g0 := int(Game.player["gold"])
	var got := NpcWorld.collect_payout()
	ok(int(Game.player["gold"]) == g0 + int(got[0]) and int(Game.world["guild_payout"]["gold"]) == 0, "collect your shares at the guild (+%d gold, %d items)" % [got[0], got[1]])
	# NPCs list their own dungeons
	for n in NpcWorld.npcs():
		n["gold"] = int(n["gold"]) + 5000
		for i in 3:
			NpcWorld._make_listing(n)
	var npc_l := NpcWorld.listings().filter(func(l): return int(l["owner"]) != -1)
	ok(npc_l.size() > 0 and npc_l.size() <= NpcWorld.MAX_NPC_LISTINGS, "adventurers list their own dungeons (%d)" % npc_l.size())
	# NPCs play each other's dungeons and pay the owner
	var other: Dictionary = npc_l[0]
	var owner := NpcWorld.find(int(other["owner"]))
	var og := int(owner["gold"])
	var challenger: Dictionary = {}
	for n in NpcWorld.npcs():
		if int(n["id"]) != int(owner["id"]) and absi(int(n["level"]) - int(other["rank"])) < 5 and n["state"] != "dead":
			challenger = n
			break
	if not challenger.is_empty():
		challenger["played"] = {}
		NpcWorld._start_listing_run(challenger, other)
		challenger["state_t"] = 0.0
		NpcWorld._tick_npc(challenger, 1.0)
		ok(int(other["plays"]) >= 1, "an adventurer ran another adventurer's dungeon")
		ok(int(owner["gold"]) >= og, "the owning adventurer got its share (%d -> %d)" % [og, int(owner["gold"])])
	# the hero plays an NPC dungeon and pays the owner's share
	M.open_service("guild")
	await _wait(0.3)
	M.window.tab = 1
	M.window.refresh()
	await _wait(0.3)
	await shot("dungeon_hall")
	M.window.tab = 2
	M.window.refresh()
	await _wait(0.3)
	await shot("roster")
	M.close_all()
	await _wait(0.2)
	var target: Dictionary = npc_l[npc_l.size() - 1]
	var towner := NpcWorld.find(int(target["owner"]))
	var eg0 := int(target["earned_gold"])
	var paid := 0
	ok(NpcWorld.hero_enter(target), "the hero can enter an adventurer's dungeon from the Dungeon Hall")
	await _wait(1.8)
	ok(Game.level_node is DungeonLevel and not Game.guild_run.is_empty(), "inside the listed dungeon with the owner's share active")
	ok(NpcWorld.hero_can_play(target) != "", "the same dungeon can only be played once a day")
	var dl = Game.level_node
	if dl is DungeonLevel:
		var hero := Game.player_node
		var gold_before := int(Game.player["gold"])
		dl.drop_gold(1000, hero.global_position + Vector2(0, 12))
		await _wait(0.8)
		for pk in get_tree().get_nodes_in_group("pickups"):
			if pk.gold == 1000:
				hero.global_position = pk.global_position  # the coins scatter when they drop; walk onto them
		await _wait(0.8)
		print("[npc] debug: pickups=%d gold=%d run=%s" % [get_tree().get_nodes_in_group("pickups").size(), int(Game.player["gold"]), str(Game.guild_run)])
		var gained := int(Game.player["gold"]) - gold_before
		var expect := 1000 - mini(int(round(1000 * float(target["gold_pct"]) / 100.0)), NpcWorld.royalty_cap(int(target["rank"])))
		ok(gained == expect, "picking up 1000 gold keeps %d after the %d%% share (kept %d)" % [expect, int(target["gold_pct"]), gained])
		for k in 3:  # a Phoenix boss revives once
			if is_instance_valid(dl.boss) and not dl.boss.dead:
				dl.boss.invuln_t = 0.0
				dl.boss.take_damage(int(dl.boss.hp) + 10, {"src": hero})
			await _wait(0.6)
		ok(dl.cleared, "the boss of the listed dungeon is defeated")
		paid = int(Game.guild_run.get("paid_gold", 0))
		dl.exit_dungeon()
		await _wait(1.8)
	ok(Game.guild_run.is_empty() and int(target["plays"]) >= 1 and int(target["clears"]) >= 1, "leaving pays the owner and records the clear")
	# (the owner keeps living meanwhile and may spend gold, so check the ledger rather than its purse)
	ok(paid > 0 and int(target["earned_gold"]) == eg0 + paid and not towner.is_empty(),
		"the dungeon owner received the hero's gold share (%d gold, ledger %d -> %d)" % [paid, eg0, int(target["earned_gold"])])
	# ---- save / load keeps everything
	var nn: int = NpcWorld.npcs().size()
	var nl: int = NpcWorld.listings().size()
	var some_lv := int(NpcWorld.npcs()[0]["level"])
	Game.save_game(false)
	M.load_slot(3)
	# checked right away: the world keeps living after loading (newcomers, listings, level-ups)
	ok(NpcWorld.npcs().size() == nn and NpcWorld.listings().size() == nl and int(NpcWorld.npcs()[0]["level"]) == some_lv, "save/load keeps adventurers and the Dungeon Hall")
	await _wait(1.0)
	var phys_ok := true
	for n in NpcWorld.npcs():
		if n.get("physical", false) and NpcWorld.actor_of(n) == null:
			phys_ok = false
	ok(phys_ok, "after loading no adventurer is stuck in the 'physical' state")
	print("[npc] ==== %d passed, %d failed" % [passes, fails.size()])
	for f in fails:
		print("[npc] FAILED: ", f)
	get_tree().quit()
