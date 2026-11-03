extends Node
## Balance probe: how a fully built character (points spent on its class build, gear of its level,
## exactly what an NPC adventurer or a sensible player has) fares against monsters of its level.
## godot --path . -- --autotest --balance


func run_all() -> void:
	var M = Game.main
	M.start_new_game("Probe", "warrior", 3)
	await get_tree().create_timer(0.6).timeout
	Game.world["npcs"] = []
	print("[bal] lvl class   HP    pdef  mdef  atk  | monster hit %%HP (normal / elite / mini / boss)  | hits to kill (normal / elite / mini / boss) | ttk normal s")
	for lv in [5, 15, 30, 50, 70, 90]:
		for cls in ["warrior", "ranger", "mage"]:
			var n := {}
			for k in 40:
				n = NpcWorld.add_npc(lv, false)
				if n["class"] == cls:
					break
				Game.world["npcs"].erase(n)
			var st := NpcWorld.stats_of(n)
			var magic: bool = cls == "mage"
			var atk := float(st["matk"] if magic else st["patk"])
			var row := "[bal] %3d %-8s %5d %5d %5d %5d |" % [lv, cls, int(st["max_hp"]), int(st["pdef"]), int(st["mdef"]), int(atk)]
			var hits := ""
			var ttk := 0.0
			for tier in ["normal", "elite", "mini", "boss"]:
				var m := Monster.create("ogre" if tier == "boss" else "goblin", lv, tier)
				var raw := float(m.base_stats["patk"]) * 1.0
				var taken := raw * raw / maxf(1.0, raw + float(st["pdef"]))
				row += " %5.1f" % (100.0 * taken / float(st["max_hp"]))
				var mdef := float(m.base_stats["mdef"] if magic else m.base_stats["pdef"])
				var per := atk * 0.6 * 1.15
				per = per * per / maxf(1.0, per + mdef) * (1.0 + float(st["crit"]) / 100.0 * 0.5)
				hits += " %6.1f" % (m.max_hp / maxf(1.0, per))
				if tier == "normal":
					ttk = m.max_hp / maxf(1.0, per) * 0.6 / float(st["aspd"])
				m.free()
			print(row + "  |" + hits + "  | %.1f" % ttk)
			Game.world["npcs"].erase(n)
	get_tree().quit()
