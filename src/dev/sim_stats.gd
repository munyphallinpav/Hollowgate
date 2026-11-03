extends Node
## Balance probe for the NPC simulation (not a pass/fail test).
## godot --path . -- --autotest --simstat
## For several hero levels: 12 adventurers live one simulated hour off-screen; prints their levels,
## defeats, gold, kills, dungeon runs and quests, plus what the hero's listed dungeons earned.


func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func run_all() -> void:
	var M = Game.main
	M.start_new_game("Sim", "warrior", 3)
	await _wait(0.8)
	var lvn = Game.level_node
	lvn._adv_t = 1e9
	for n in NpcWorld.npcs():
		if n.get("physical", false):
			lvn._despawn_adventurer(n)
	for hero_lv in [5, 20, 45, 80]:
		Game.player["level"] = hero_lv
		Game.player["xp"] = 0
		Game.world["npcs"] = []
		Game.world["guild_listings"] = []
		Game.world["guild_payout"] = {"gold": 0, "items": []}
		for i in 12:
			NpcWorld.add_npc(clampi(hero_lv + (i % 7) - 3, 1, 100), false)
		# the hero lists two dungeons of their level: one plain, one packed with monsters and chests
		for k in 2:
			var o := DungeonGen.default_options(hero_lv, "cave")
			o["seed"] = 100 + k
			if k == 1:
				o["monster_density"] = 2.5
				o["treasures"] = 9
				o["miniboss_count"] = 4
			var d := DungeonGen.generate(o)
			d["name"] = "Probe %d" % k
			var it := Items.stack("dungeon_crystal", 1)
			it["design"] = d
			Game.add_item(it)
			for i in Game.player["inv"].size():
				var s = Game.player["inv"][i]
				if s is Dictionary and s.get("id", "") == "dungeon_crystal":
					print("[sim]   list: ", NpcWorld.list_crystal(i, 15, 10))
					break
		var base := {}
		for n in NpcWorld.npcs():
			base[n["id"]] = {"level": int(n["level"]), "gold": int(n["gold"]), "kills": int(n["kills"]), "deaths": int(n["deaths"]),
				"clears": int(n["dungeons_cleared"]), "quests": int(n.get("quests_done", 0))}
		var states := {}
		var causes := {}
		for sec in 3600:
			for n in NpcWorld.npcs().duplicate():
				var before: String = n["state"]
				NpcWorld._tick_npc(n, 1.0)
				if n["state"] == "dead" and before != "dead":
					causes[before] = int(causes.get(before, 0)) + 1
				states[n["state"]] = int(states.get(n["state"], 0)) + 1
			if sec % 60 == 0:
				Game.world["total"] = float(Game.world["total"]) + 60.0
			if sec % 1200 == 0 and sec > 0:
				Game.world["day"] = int(Game.world["day"]) + 1
				Game.refresh_board(true)
			if sec % 120 == 0:
				NpcWorld._top_up_board()
		var deaths := 0
		var kills := 0
		var gold := 0
		var runs := 0
		var quests := 0
		var lvls := []
		var dl := []
		for n in NpcWorld.npcs():
			var b: Dictionary = base.get(n["id"], {"level": 1, "gold": 0, "kills": 0, "deaths": 0, "clears": 0, "quests": 0})
			deaths += int(n["deaths"]) - int(b["deaths"])
			kills += int(n["kills"]) - int(b["kills"])
			gold += int(n["gold"]) - int(b["gold"])
			runs += int(n["dungeons_cleared"]) - int(b["clears"])
			quests += int(n.get("quests_done", 0)) - int(b["quests"])
			lvls.append(int(n["level"]))
			dl.append("%d>%d(t%+d)" % [int(b["level"]), int(n["level"]), NpcWorld.talent_of(n)])
		lvls.sort()
		var cnt := NpcWorld.npcs().size()
		print("[sim] hero Lv%d  npcs=%d  levels %s  (min %d max %d)" % [hero_lv, cnt, " ".join(PackedStringArray(dl)), lvls[0], lvls[-1]])
		print("[sim]   per NPC-hour: defeats %.2f  kills %.0f  gold %+.0f  clears %.2f  quests %.2f   states %s" % [
			float(deaths) / cnt, float(kills) / cnt, float(gold) / cnt, float(runs) / cnt, float(quests) / cnt, str(states)])
		print("[sim]   defeats by activity: ", causes)
		print("[sim]   sim fights %d  avg HP lost per fight %.1f%%  worst %.0f%%" % [NpcWorld.dbg_fights, 100.0 * NpcWorld.dbg_dmg / maxf(1.0, NpcWorld.dbg_fights), 100.0 * NpcWorld.dbg_max])
		NpcWorld.dbg_fights = 0
		NpcWorld.dbg_dmg = 0.0
		NpcWorld.dbg_max = 0.0
		for l in NpcWorld.hero_listings():
			var pr := NpcWorld.listing_profile(l)
			print("[sim]   listing %s rank %d (danger %.2f %s, loot %.2f %s, gold %.2f): played %d cleared %d failed %d earned %d gold %d items" % [l["name"], int(l["rank"]),
				float(pr["danger"]), NpcWorld.danger_word(pr["danger"]), float(pr["loot"]), NpcWorld.loot_word(pr["loot"]), float(pr["gold"]),
				int(l["plays"]), int(l["clears"]), int(l["fails"]), int(l["earned_gold"]), int(l["earned_items"])])
	get_tree().quit()
