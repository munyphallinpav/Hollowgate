extends Node
## Bonds, parties, duels and spectated test runs.  godot --path . -- --autotest --socialtest [--shots=DIR]

var fails: Array = []
var passes := 0
var shots_dir := ""
var step := 0


func ok(cond: bool, what: String) -> void:
	if cond:
		passes += 1
		print("[soc] pass  ", what)
	else:
		fails.append(what)
		print("[soc] FAIL  ", what)


func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func shot(name: String) -> void:
	if shots_dir == "":
		return
	for i in 3:
		await get_tree().process_frame
	step += 1
	DirAccess.make_dir_recursive_absolute(shots_dir)
	get_viewport().get_texture().get_image().save_png("%s/soc_%02d_%s.png" % [shots_dir, step, name])


func _make_npc(lv: int, cls: String = "") -> Dictionary:
	var n := {}
	for k in 60:
		n = NpcWorld.add_npc(lv, false)
		if cls == "" or n["class"] == cls or k == 59:
			break  # (keeps the last one if the class never comes up)
		Game.world["npcs"].erase(n)
	n["state"] = "town"
	n["state_t"] = 9999.0
	n["visited"] = true
	return n


## Puts an adventurer (as a real character) right next to the hero.
func _bring(n: Dictionary, off: Vector2) -> Adventurer:
	var lvn = Game.level_node
	var p = Game.player_node
	n["pos"] = [p.global_position.x + off.x, p.global_position.y + off.y]
	var a = NpcWorld.actor_of(n)
	if a == null:
		a = lvn.spawn_adventurer(n, p.global_position + off)
	else:
		a.global_position = lvn.snap_walkable(p.global_position + off)
	return a


func _level_hero(to: int) -> void:
	while int(Game.player["level"]) < to:
		Game.add_xp(GameData.xp_to_next(int(Game.player["level"])))


func _bag_index(uid: int) -> int:
	var inv: Array = Game.player["inv"]
	for i in inv.size():
		if inv[i] is Dictionary and not inv[i].is_empty() and int(inv[i].get("uid", -1)) == uid:
			return i
	return -1


func run_all() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
	var M = Game.main
	M.go_title(false)
	await _wait(0.3)
	M.start_new_game("Social", "warrior", 3)
	await _wait(1.2)
	_level_hero(15)
	Game.allocate_stat("str", int(Game.player["stat_points"]) / 2)
	Game.allocate_stat("vit", int(Game.player["stat_points"]))
	Game.add_gold(20000)
	var lvn = Game.level_node
	var p: Player = Game.player_node
	p.global_position = lvn.town_spawn()
	# keep the town quiet: only our own test adventurers
	lvn._adv_t = 1e9
	lvn._challenge_t = 1e9
	for n in NpcWorld.npcs().duplicate():
		if n.get("physical", false):
			lvn._despawn_adventurer(n)
	Game.world["npcs"] = []
	await _wait(0.3)
	var part := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--part="):
			part = a.substr(7)
	if part == "" or part == "bond":
		await _bond_tests()
	if part == "" or part == "party":
		await _party_tests()
	if part == "" or part == "duel":
		await _duel_tests()
	if part == "" or part == "npcparty":
		await _npc_party_tests()
	if part == "" or part == "run":
		await _test_run_tests()
	if part == "" or part == "runend":
		await _test_run_endings()
	_finish()


# =================================================================== bond
func _bond_tests() -> void:
	var M = Game.main
	var n := _make_npc(14, "warrior")
	var a := _bring(n, Vector2(30, 0))
	await _wait(0.4)
	var wb: String = GameData.CLASSES[n["class"]]["weapon"]
	var good := Items.gen_gear(wb, 16, 3)
	var weak := Items.gen_gear(wb, 1, 0)
	var high := Items.gen_gear(wb, 30, 3)
	var c1 := Social.gift_check(n, good)
	var c2 := Social.gift_check(n, weak)
	var c3 := Social.gift_check(n, high)
	ok(c1["ok"] and int(c1["bond"]) >= 4 and int(c1["bond"]) <= 20, "a better weapon it can wield is a welcome gift (bond +%d)" % int(c1["bond"]))
	ok(not c2["ok"], "a weaker weapon is refused (%s)" % c2["why"])
	ok(not c3["ok"], "gear too high-level to use is refused (%s)" % c3["why"])
	ok(Social.gift_check(n, Items.stack("pot_hp_s", 5))["ok"], "potions are always useful")
	ok(not Social.gift_check(n, Items.stack("wood", 3))["ok"] or n["quests"].any(func(q): return q["target"] == "wood"), "materials only count when a quest needs them")
	Game.give_item(good)
	var idx := _bag_index(int(good["uid"]))
	var before := Social.bond(n)
	var msg := Social.give_item(n, idx)
	ok(Social.bond(n) > before and _bag_index(int(good["uid"])) == -1, "giving the weapon raises the bond (%s)" % msg)
	ok(int(n["equip"]["weapon"].get("uid", -1)) == int(good["uid"]), "the adventurer equips the gift right away")
	await _wait(0.2)
	ok(a.st["patk"] > 0 and NpcWorld.gear_score(n, n["equip"]["weapon"]) >= NpcWorld.gear_score(n, weak), "and is stronger for it")
	# daily cap
	for i in 12:
		var pt := Items.stack("pot_hp_m", 10)
		Game.give_item(pt)
		var j := _bag_index(int(pt["uid"]))
		if j < 0:
			for k in Game.player["inv"].size():
				var it = Game.player["inv"][k]
				if it is Dictionary and it.get("id", "") == "pot_hp_m":
					j = k
			if j < 0:
				continue
		Social.give_item(n, j)
	ok(Social.bond_left_today(n) == 0 and Social.bond(n) == Social.BOND_PER_DAY, "bond gains stop at %d per day (bond %d)" % [Social.BOND_PER_DAY, Social.bond(n)])
	var pt2 := Items.stack("pot_hp_s", 3)
	Game.give_item(pt2)
	var m2 := Social.give_item(n, _bag_index(int(pt2["uid"])) if _bag_index(int(pt2["uid"])) >= 0 else 0)
	ok(m2.contains("enough"), "further gifts that day are politely declined (%s)" % m2)
	var g0 := int(Game.player["gold"])
	ok(Social.give_gold(n, 5000).contains("enough"), "gold can't buy past the daily limit either")
	ok(int(Game.player["gold"]) == g0, "and no gold is taken")
	# next day
	Game.world["day"] = int(Game.world["day"]) + 1
	ok(Social.bond_left_today(n) == Social.BOND_PER_DAY, "a new day resets the daily bond limit")
	var per := Social.gold_per_bond(n)
	var b0 := Social.bond(n)
	var r := Social.give_gold(n, per * 10 + per / 2)
	ok(Social.bond(n) == b0 + 10 and int(Game.player["gold"]) == g0 - per * 10, "gold converts to bond (%d gold = 1 bond, only whole points taken): %s" % [per, r])
	var r2 := Social.give_gold(n, per * 100)
	ok(Social.bond(n) == b0 + Social.BOND_PER_DAY and int(Game.player["gold"]) == g0 - per * Social.BOND_PER_DAY, "a big purse only buys what is left of today's limit")
	ok(Social.bond_level(n) == 2 and Social.bond_name(n) == "Friend", "bond level %d: %s" % [Social.bond_level(n), Social.bond_name(n)])
	# profile UI
	M.open_npc_profile(int(n["id"]))
	await _wait(0.4)
	ok(M.window is NpcProfileWindow, "the profile shows the bond, gift, party and duel actions")
	await shot("profile_social")
	M.window._give_item_dialog()
	await _wait(0.3)
	await shot("gift_picker")
	M.close_all()
	await _wait(0.2)
	n["state_t"] = 9999.0


# =================================================================== party
func _party_tests() -> void:
	var M = Game.main
	var lvn = Game.level_node
	var p: Player = Game.player_node
	var hl := int(Game.player["level"])
	var peer := _make_npc(hl)
	var strong := _make_npc(hl + 8)
	var c_peer := float(Social.invite_chance(peer)[0])
	var c_strong := float(Social.invite_chance(strong)[0])
	ok(c_strong < c_peer, "a stronger adventurer is less likely to accept (%.0f%% vs %.0f%%)" % [c_strong * 100.0, c_peer * 100.0])
	strong["bond"] = 60
	var c_bond := float(Social.invite_chance(strong)[0])
	ok(c_bond > c_strong + 0.3, "bond raises the chance a lot (%.0f%% with bond level 3)" % (c_bond * 100.0))
	strong["bond"] = 0
	strong["invite_cd"] = -1e9
	# a refusal puts a short cooldown on asking again
	var refused := false
	for i in 40:
		strong.erase("invite_cd")
		var r := Social.invite(strong)
		if not r[0]:
			refused = true
			ok(float(Social.invite_chance(strong)[0]) == 0.0 and String(Social.invite_chance(strong)[1]).contains("moment ago"), "after a refusal you have to wait before asking again")
			break
		Social.leave_party(strong)
	ok(refused, "a much stronger stranger turns you down sometimes")
	strong.erase("invite_cd")
	strong["state"] = "town"
	# join
	var a1 := _bring(peer, Vector2(-30, 10))
	peer["bond"] = 100
	var joined := false
	for i in 10:
		peer.erase("invite_cd")
		var r2 := Social.invite(peer)
		if r2[0]:
			joined = true
			break
	ok(joined and Social.in_party(peer) and peer["state"] == "party", "a sworn ally joins your party")
	await _wait(0.5)
	a1 = NpcWorld.actor_of(peer)
	ok(a1 != null and a1.mode == "follow" and a1.leader == p, "the member follows you")
	ok(Social.party_stay(peer) > 1e10, "sworn allies stay for good")
	# follows the hero around
	var spot: Vector2 = lvn.snap_walkable(p.global_position + Vector2(160, 40))
	p.global_position = spot
	await _wait(3.0)
	ok(a1.global_position.distance_to(p.global_position) < 90.0, "walks after you (%.0f px away)" % a1.global_position.distance_to(p.global_position))
	await shot("party_follow")
	# far away: catches up by teleport
	var far: Vector2 = lvn.snap_walkable(lvn.town_spawn() + Vector2(0, -600))
	p.global_position = far
	await _wait(2.5)
	ok(a1.global_position.distance_to(p.global_position) < 140.0, "teleports back to you when left far behind (%.0f px)" % a1.global_position.distance_to(p.global_position))
	p.global_position = lvn.town_spawn()
	await _wait(1.5)
	# second member, then the party is full
	var third := _make_npc(hl - 2)
	third["bond"] = 100
	var a2 := _bring(third, Vector2(30, 10))
	for i in 10:
		third.erase("invite_cd")
		if Social.invite(third)[0]:
			break
	ok(Social.party_size() == 3, "party of 3 (you + 2)")
	var fourth := _make_npc(hl)
	var cf := Social.invite_chance(fourth)
	ok(float(cf[0]) == 0.0 and String(cf[1]).contains("full"), "the party is limited to %d (%s)" % [Social.PARTY_MAX, cf[1]])
	# shared XP
	var hx := int(Game.player["xp"])
	var x1 := float(peer["xp"])
	var x2 := float(third["xp"])
	var lv1 := int(peer["level"])
	var share := Social.share_xp(900.0)
	ok(share > 300.0 and share < 900.0, "a kill's XP is shared: you get %.0f of 900 (the total grows with the party)" % share)
	ok(float(peer["xp"]) > x1 or int(peer["level"]) > lv1, "party members earn their share too")
	# a kill by a party member counts for the party
	await _wait(0.5)
	var m: Monster = lvn.spawn_monster("slime", p.global_position + Vector2(0, 80), hl)
	await _wait(0.05)
	hx = int(Game.player["xp"])
	var hlv := int(Game.player["level"])
	x2 = float(third["xp"])
	var lv2 := int(third["level"])
	lvn.on_monster_died(m, NpcWorld.actor_of(third))
	m.queue_free()
	ok(int(Game.player["xp"]) > hx or int(Game.player["level"]) > hlv, "you get XP when a party member lands the kill")
	ok(float(third["xp"]) > x2 or int(third["level"]) > lv2, "and so does the member")
	# fighting together builds bond (its own daily limit, separate from gifts)
	third["bond"] = 40
	third.erase("team_bond_today")
	third["team_bond_acc"] = 0.0
	Social.on_party_kill("elite", 1.0)
	ok(Social.bond(third) == 41, "an elite killed together: bond +1 (%d)" % Social.bond(third))
	for i in 10:
		Social.on_party_kill("normal", 1.0)
	ok(Social.bond(third) == 42, "ten ordinary kills together: bond +1 more (%d)" % Social.bond(third))
	var gift_left := Social.bond_left_today(third)
	for i in 20:
		Social.on_party_kill("boss", 1.0)
	ok(Social.bond(third) == 40 + Social.TEAM_BOND_PER_DAY and Social.team_bond_left_today(third) == 0, "teamwork bond is capped at %d a day (%d)" % [Social.TEAM_BOND_PER_DAY, Social.bond(third)])
	ok(Social.bond_left_today(third) == gift_left, "and doesn't use up the gift limit")
	var away := _make_npc(hl)
	away["bond"] = 10
	Social.join_party(away)  # a member whose actor isn't here (away) gains nothing
	if NpcWorld.actor_of(away) != null:
		lvn.despawn_adventurer(away)
	Social.on_party_kill("boss", 1.0)
	ok(Social.bond(away) == 10, "members who aren't with you don't gain bond")
	Social.leave_party(away, "")
	third.erase("team_bond_today")
	third["bond"] = 100
	await _wait(0.3)
	await shot("party_hud")
	# into a dungeon together
	M.enter_dungeon({"id": -7, "rank": 6, "biome": "cave", "seed": 77}, false)
	await _wait(1.8)
	var dl = Game.level_node
	ok(dl is DungeonLevel, "entered a dungeon")
	var b1 = NpcWorld.actor_of(peer)
	var b2 = NpcWorld.actor_of(third)
	ok(b1 != null and b2 != null and dl.is_ancestor_of(b1) and dl.is_ancestor_of(b2), "the party comes along into the same dungeon")
	if b1:
		ok(b1.global_position.distance_to(dl.player.global_position) < 120.0, "right beside you")
	peer["bond"] = 50
	peer.erase("team_bond_today")
	var gains := Social.on_dungeon_cleared(6)
	ok(Social.bond(peer) == 50 + Social.TEAM_DUNGEON_BOND and gains.size() >= 1, "clearing a dungeon together: bond +%d (%d)" % [Social.TEAM_DUNGEON_BOND, Social.bond(peer)])
	peer["bond"] = 100
	await _wait(1.0)
	await shot("party_dungeon")
	M.leave_dungeon("exit", false)
	await _wait(2.0)
	lvn = Game.level_node
	p = Game.player_node
	lvn._adv_t = 1e9
	lvn._challenge_t = 1e9
	ok(lvn is Overworld and NpcWorld.actor_of(peer) != null and NpcWorld.actor_of(peer).mode == "follow", "and back out with you")
	# parting ways
	Social.leave_party(third, "")
	await _wait(0.3)
	var a3 = NpcWorld.actor_of(third)
	ok(not Social.in_party(third) and third["state"] == "town" and (a3 == null or a3.mode == "routine"), "a member who leaves goes back to its own life")
	ok(Social.party_size() == 2, "party of 2 left")


# =================================================================== duels
func _duel_tests() -> void:
	var M = Game.main
	var lvn = Game.level_node
	var p: Player = Game.player_node
	ok(Duel.values_match(100, 110) and not Duel.values_match(100, 130) and Duel.values_match(0, 0), "stakes must be within 15% of each other")
	var foe := _make_npc(int(Game.player["level"]) - 3)
	foe["gold"] = 3000
	var fo := Duel.npc_offer(foe, 400)
	ok(Duel.values_match(400, Duel.stake_value(fo)), "an adventurer can counter a 400-gold bet (%d)" % Duel.stake_value(fo))
	var poor := _make_npc(5)
	poor["gold"] = 20
	poor["inv"] = []
	ok(not Duel.values_match(5000, Duel.stake_value(Duel.npc_offer(poor, 5000))), "a poor adventurer can't match a rich bet")
	var spot: Vector2 = lvn.snap_walkable(lvn.town_spawn() + Vector2(-90, 60))
	p.global_position = spot
	var fa := _bring(foe, Vector2(70, 0))
	await _wait(0.4)
	# the duel window
	M.open_duel(foe, fa)
	await _wait(0.3)
	ok(M.window is DuelWindow, "the duel window opens")
	M.window.gold_spin.value = 300
	M.window._refresh()
	await _wait(0.1)
	ok(not M.window.go_btn.disabled, "a matched bet can be proposed")
	await shot("duel_window")
	M.close_all()
	await _wait(0.2)
	# a real fight
	var g0 := int(Game.player["gold"])
	var fg0 := int(foe["gold"])
	p.hp = p.max_hp
	ok(Duel.start(p, fa, {"gold": 300, "items": []}, {"gold": 300, "items": []}), "duel starts")
	ok(int(Game.player["gold"]) == g0 - 300 and int(foe["gold"]) == fg0 - 300, "both stakes go into the pot")
	ok(p.team == "duel_a" and fa.team == "duel_b" and fa.foe_team() == "duel_a", "the duellists fight each other")
	ok(foe["state"] == "duel" and NpcWorld.activity(foe) == "Duelling", "shown as duelling")
	for i in 400:
		if Duel.phase != "countdown":
			break
		await get_tree().process_frame
	ok(Duel.phase == "fight", "after the countdown: FIGHT")
	for mem in Social.party_members():
		var ma = NpcWorld.actor_of(mem)
		if ma and Duel.active:
			ok(ma.global_position.distance_to(Duel.center) > Duel.RING, "your party member steps out of the ring to watch (%.0f px from the centre)" % ma.global_position.distance_to(Duel.center))
	# no potions in a duel
	Game.give_item(Items.stack("pot_hp_s", 2))
	var pi := -1
	for i in Game.player["inv"].size():
		var it = Game.player["inv"][i]
		if it is Dictionary and it.get("id", "") == "pot_hp_s":
			pi = i
	ok(pi >= 0 and not Game.use_item(pi), "no potions allowed")
	# let them fight for a while (the hero stands still, the adventurer attacks)
	var hp0 := p.hp
	for t in 25:
		await _wait(0.2)
		if p.hp < hp0 or not Duel.active:
			break
	ok(p.hp < hp0 or not Duel.active, "the adventurer really fights you (%d -> %d HP)" % [int(hp0), int(p.hp)])
	await shot("duel_fight")
	# finish it: the adventurer drops to 1 HP
	var xp0 := int(Game.player["xp"])
	var lv0 := int(Game.player["level"])
	var fhp := 0
	for i in 60:
		if not Duel.active:
			break
		fa.invuln_t = 0.0
		fa.take_damage(int(fa.max_hp), {})
		await get_tree().process_frame
	ok(not Duel.active and Duel.last_result == "won", "KO at 1 HP: you win (%s)" % Duel.last_result)
	ok(not fa.dead and fa.hp >= 1.0, "nobody dies in a duel")
	ok(int(Game.player["gold"]) == g0 + 300, "winner takes all (+300 gold)")
	ok(int(Game.player["xp"]) > xp0 or int(Game.player["level"]) > lv0, "winning earns XP")
	ok(p.team == "player" and fa.team == "player" and fa.mode == "routine" and foe["state"] != "duel", "everyone is back to normal")
	await _wait(1.2)
	# losing
	g0 = int(Game.player["gold"])
	fg0 = int(foe["gold"])
	fa.hp = fa.max_hp
	Duel.start(p, fa, {"gold": 200, "items": []}, {"gold": 200, "items": []})
	await _wait(3.3)
	for i in 60:
		if not Duel.active:
			break
		p.invuln_t = 0.0
		p.take_damage(int(p.max_hp), {})
		await get_tree().process_frame
	ok(Duel.last_result == "lost" and not p.dead and int(foe["gold"]) == fg0 + 200 and int(Game.player["gold"]) == g0 - 200, "lose and the adventurer takes the pot (you live)")
	await _wait(1.2)
	# forfeit by leaving the ring
	p.hp = p.max_hp
	Duel.start(p, fa, {}, {})
	await _wait(3.3)
	var away: Vector2 = Duel.center + Vector2(0, Duel.RING * 2.0)
	for i in 30:
		p.global_position = away
		await _wait(0.15)
		if not Duel.active:
			break
	ok(Duel.last_result == "lost", "leaving the ring forfeits")
	await _wait(1.2)
	# staking an item
	var gear := Items.gen_gear(GameData.CLASSES["warrior"]["weapon"], 12, 2)
	Game.give_item(gear)
	var gi := _bag_index(int(gear["uid"]))
	var their := Duel.npc_offer(foe, Items.sell_price(gear))
	ok(Duel.values_match(Items.sell_price(gear), Duel.stake_value(their)), "items can be bet too")
	Duel.start(p, fa, {"gold": 0, "items": [Game.player["inv"][gi]]}, their)
	ok(_bag_index(int(gear["uid"])) == -1, "the staked item goes into the pot")
	Duel.cancel("test")
	ok(_bag_index(int(gear["uid"])) >= 0, "a called-off duel returns the stakes")
	await _wait(1.2)
	var g1 := int(Game.player["gold"])
	Duel.start(p, fa, {"gold": 100, "items": []}, Duel.npc_offer(foe, 100))
	Game.save_game(false)
	ok(not Duel.active and int(Game.player["gold"]) == g1, "saving / quitting mid-duel calls it off and returns the stakes first")
	await _wait(1.2)
	# the adventurer challenges you
	foe["bravery"] = 1.0
	for i in 15:
		NpcWorld._level_up(foe, true)
	NpcWorld._kit_out(foe, int(foe["level"]))
	fa.on_npc_gear_changed()
	fa.on_npc_level_up()
	fa.global_position = p.global_position + Vector2(60, 0)
	foe.erase("challenged_day")
	Game.player["duel_ask_t"] = 0.0
	var asked := false
	for i in 30:
		Game.player["duel_ask_t"] = 0.0
		foe.erase("challenged_day")
		lvn._npc_challenge()
		if foe.has("challenge"):
			asked = true
			break
	ok(asked, "a confident adventurer in town challenges you (%d%% win chance)" % int(Duel.npc_win_chance(foe) * 100.0))
	await _wait(1.5)
	ok(fa._mark != null and fa.global_position.distance_to(p.global_position) < 80.0, "it walks up with a ! over its head")
	await shot("npc_challenge")
	M.open_duel(foe, fa, foe.get("challenge", {}))
	await _wait(0.3)
	ok(M.window is DuelWindow and M.window.challenged, "answering shows its fixed stake to match")
	M.close_all()
	foe.erase("challenge")
	# adventurers duel each other in town
	var x := _make_npc(10)
	var y := _make_npc(11)
	x["gold"] = 1000
	y["gold"] = 1000
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	Duel.sim_duel(x, y, rng)
	ok(int(x["gold"]) + int(y["gold"]) == 2000 and int(x.get("duels_won", 0)) + int(y.get("duels_won", 0)) == 1, "adventurers duel each other for gold (winner takes the bet)")
	Game.world["npcs"].erase(poor)


# =================================================================== adventurer parties
func _npc_party_tests() -> void:
	var lead := _make_npc(12)
	var m1 := _make_npc(11)
	var m2 := _make_npc(13)
	for n in [lead, m1, m2]:
		n["physical"] = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var formed := false
	for i in 30:
		if Social.try_form_npc_party(lead, rng):
			formed = true
			break
	ok(formed and Social.is_npc_leader(lead), "adventurers team up among themselves (%d members)" % Social.npc_party_members(lead).size())
	var mates := Social.npc_party_members(lead)
	var mate: Dictionary = mates[1] if mates.size() > 1 else {}
	if not mate.is_empty():
		ok(mate["state"] == "follow" and NpcWorld.activity(mate).begins_with("With %s's party" % lead["name"]), "members travel with the leader (%s)" % NpcWorld.activity(mate))
		var x0 := float(mate["xp"])
		var l0 := int(mate["level"])
		Social.share_npc_xp(lead, 500.0)
		ok(float(mate["xp"]) > x0 or int(mate["level"]) > l0, "kills by the party share XP")
		ok(Social.same_party(null, null) == false, "same_party is safe with nothing")
		lead["pos"] = [5000.0, 5000.0]
		lead["state"] = "travel"
		NpcWorld._tick_npc(mate, 1.0)
		ok(Vector2(mate["pos"][0], mate["pos"][1]).distance_to(Vector2(5000, 5000)) < 40.0, "a member moves with its leader")
		NpcWorld._enter_town(lead)
		ok(not Social.in_npc_party(lead) and not Social.in_npc_party(mate) and mate["state"] == "town", "the party breaks up back in town")
	var c0 := Social.invite_chance(lead)
	ok(float(c0[0]) > 0.0, "a free adventurer can be invited again")


# =================================================================== test runs
func _test_run_tests() -> void:
	var M = Game.main
	var hl := int(Game.player["level"])
	var r1 := _make_npc(hl + 4, "warrior")
	var r2 := _make_npc(hl + 4, "priest")
	for n in [r1, r2]:
		NpcWorld._restock_potions(n, true)
	var snap1: Dictionary = r1.duplicate(true)
	var snap2: Dictionary = r2.duplicate(true)
	var hero_xp := int(Game.player["xp"])
	var hero_gold := int(Game.player["gold"])
	var design := DungeonGen.random_design(maxi(1, hl - 4), "cave", 4242)
	design["name"] = "Spectator Trial"
	Game.designs.append(design)
	M.open_service("architect")
	await _wait(0.4)
	if M.window is DungeonEditor:
		M.window.design = design.duplicate(true)
		M.window._test_run_dialog()
		await _wait(0.3)
		await shot("test_run_picker")
	M.close_all()
	await _wait(0.2)
	M.start_test_run(design.duplicate(true), {"hero": false, "npcs": [int(r1["id"]), int(r2["id"])]})
	await _wait(2.0)
	var dl = Game.level_node
	ok(dl is DungeonLevel and dl.test_run and dl.spectate, "watching a test run instead of playing it")
	var p: Player = Game.player_node
	ok(p.ghost and not p.visible and not p.is_in_group("team_player"), "you are an invisible ghost: monsters ignore you")
	if dl.runners.size() != 2:
		print("[soc] info: runner_ids=%s runners=%s r1=%d r2=%d found=%s/%s" % [str(dl.runner_ids), str(dl.runners), int(r1["id"]), int(r2["id"]),
			str(not NpcWorld.find(int(r1["id"])).is_empty()), str(not NpcWorld.find(int(r2["id"])).is_empty())])
	ok(dl.runners.size() == 2, "two adventurers run the dungeon")
	var lead_ok := false
	for a in dl.runners:
		if a.mode == "run":
			lead_ok = true
	ok(lead_ok, "one leads the way, the other follows it")
	ok(dl.spec_target != null and dl.camera.global_position.distance_to(dl.spec_target.global_position) < 40.0, "the camera follows a runner")
	await shot("spectate_start")
	Engine.time_scale = 4.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 30000 and dl.visited_rooms.size() < 3 and not dl.run_over:
		await _wait(0.5)
	Engine.time_scale = 1.0
	print("[soc] info: rooms %d/%d kills %d time %.0fs over=%s cleared=%s" % [dl.visited_rooms.size(), dl.design["rooms"].size(), dl.run_kills, dl.run_time, str(dl.run_over), str(dl.cleared)])
	ok(dl.visited_rooms.size() >= 2, "the runners make their way through the rooms (%d explored)" % dl.visited_rooms.size())
	ok(dl.run_kills >= 1, "and fight the monsters (%d down)" % dl.run_kills)
	await shot("spectate_fight")
	# switch who to watch, then the free camera
	var other = dl.runners[1] if dl.spec_target == dl.runners[0] else dl.runners[0]
	var ev := InputEventAction.new()
	ev.action = "skill_2" if other == dl.runners[1] else "skill_1"
	ev.pressed = true
	dl._unhandled_input(ev)
	await _wait(0.2)
	ok(dl.spec_target == other or other.dead, "number keys switch the runner you watch")
	var ev2 := InputEventAction.new()
	ev2.action = "dash"
	ev2.pressed = true
	dl._unhandled_input(ev2)
	ok(dl.spec_free, "space switches to a free camera")
	var c0: Vector2 = dl.camera.global_position
	Input.action_press("move_right")
	await _wait(0.5)
	Input.action_release("move_right")
	ok(dl.camera.global_position.x > c0.x + 30.0, "WASD flies the free camera")
	ev2.pressed = true
	dl._unhandled_input(ev2)
	await shot("spectate_banner")
	# end it from the menu
	M.end_test_run("exit")
	await _wait(2.5)
	ok(Game.level_node is Overworld and not Game.test_run, "back in town after the test run")
	ok(M.last_test_summary.contains("Rooms explored"), "with a report of the run")
	await shot("test_run_report")
	M.close_all()
	var same := true
	for k in ["xp", "level", "gold", "kills"]:
		if str(r1[k]) != str(snap1[k]) or str(r2[k]) != str(snap2[k]):
			same = false
			print("[soc] info: changed %s: %s/%s vs %s/%s" % [k, str(r1[k]), str(r2[k]), str(snap1[k]), str(snap2[k])])
	ok(same and r1["inv"].size() == snap1["inv"].size() and NpcWorld.count(r1, "pot_hp_s") == NpcWorld.count(snap1, "pot_hp_s"), "the runners come back exactly as they went in")
	ok(not r1.get("physical", false) or NpcWorld.actor_of(r1) != null, "and return to the simulation")
	ok(int(Game.player["xp"]) == hero_xp and int(Game.player["gold"]) == hero_gold, "nothing gained or lost for you")
	# playing it yourself with your party
	await _wait(0.5)
	var mem := Social.party_members()
	M.start_test_run(design.duplicate(true), {"hero": true, "npcs": Social.party_ids().duplicate()})
	await _wait(2.0)
	dl = Game.level_node
	ok(dl is DungeonLevel and not dl.spectate and not Game.player_node.ghost, "or play the test run yourself")
	var with_me := not mem.is_empty()
	for n in mem:
		var a = NpcWorld.actor_of(n)
		if a == null or not dl.is_ancestor_of(a) or a.leader != Game.player_node:
			with_me = false
	if not mem.is_empty():
		ok(with_me, "with your party at your side")
	await shot("test_run_party")
	M.end_test_run("exit")
	await _wait(2.5)
	ok(Game.level_node is Overworld and Social.party_size() == 1 + mem.size(), "the party is still yours afterwards")


## Spectated runs end by themselves: when the boss falls, or when every runner is down.
func _test_run_endings() -> void:
	var M = Game.main
	var hl := int(Game.player["level"])
	for k in 2:
		var win := k == 0
		var lv := hl + 10 if win else 2
		var rs := [_make_npc(lv, "warrior"), _make_npc(lv, "priest" if win else "mage")]
		var ids := []
		for n in rs:
			ids.append(int(n["id"]))
			n["physical"] = false
		var design := DungeonGen.random_design(maxi(1, hl - 8) if win else hl + 12, "cave", 99 + k)
		design["name"] = "Ending Trial %d" % k
		M.start_test_run(design, {"hero": false, "npcs": ids})
		await _wait(2.0)
		Engine.time_scale = 6.0
		var t0 := Time.get_ticks_msec()
		var dl = Game.level_node
		var lvl_info := ""
		while Time.get_ticks_msec() - t0 < 90000 and not (Game.level_node is Overworld):
			if Game.level_node is DungeonLevel:
				dl = Game.level_node
				lvl_info = "rooms %d/%d kills %d time %.0fs" % [dl.visited_rooms.size(), dl.design["rooms"].size(), dl.run_kills, dl.run_time]
			await _wait(0.5)
		Engine.time_scale = 1.0
		await _wait(1.5)
		print("[soc] info: ending %d: %s | %s" % [k, lvl_info, M.last_test_summary.replace("\n", " / ")])
		if win:
			ok(Game.level_node is Overworld and M.last_test_summary.contains("Cleared"), "strong runners clear it and the run ends by itself with the report")
		else:
			ok(Game.level_node is Overworld and M.last_test_summary.contains("Not cleared") and M.last_test_summary.contains("down in "), "a party that falls ends the run too (who fell where is in the report)")
		M.close_all()
		await _wait(0.5)
		for n in rs:
			ok(n["state"] == "town" and float(n["hp_frac"]) > 0.0, "%s is back in town unharmed" % n["name"])


func _finish() -> void:
	Engine.time_scale = 1.0
	print("[soc] ==== %d passed, %d failed" % [passes, fails.size()])
	for f in fails:
		print("[soc] FAILED: ", f)
	get_tree().quit()
