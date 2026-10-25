class_name Quests
extends RefCounted
## Adventurer Guild quest generation and helpers.

const GATHER_BY_LEVEL := [
	[1, ["wood", "stone", "slime_gel", "herb", "ore_copper"]],
	[8, ["wolf_pelt", "goblin_ear", "ore_iron", "leather", "bone"]],
	[18, ["bear_claw", "rotten_flesh", "ore_silver", "hardwood", "lizard_scale"]],
	[30, ["tiger_fang", "ogre_hide", "ore_gold", "mermaid_pearl", "dryad_petal"]],
	[45, ["ancient_bark", "vampire_fang", "ore_mithril", "crystal_shard"]],
	[65, ["wyvern_wing", "ore_adamantite", "monster_core"]],
	[80, ["dragon_scale", "phoenix_feather"]],
]


static func hunt_targets(level: int) -> Array:
	var out := []
	for m in GameData.MONSTERS:
		var d: Dictionary = GameData.MONSTERS[m]
		if d.get("weight", 0) <= 0 or d.get("passive", false):
			continue
		if int(d["min_lv"]) <= level + 3 and int(d["min_lv"]) >= level - 40:
			out.append(m)
	if out.is_empty():
		out = ["slime", "wolf", "goblin"]
	return out


static func generate(level: int, rank_pts: int, rng: RandomNumberGenerator) -> Dictionary:
	var rank_mult := 1.0 + rank_pts / 3000.0
	var roll := rng.randf()
	var q := {"id": rng.randi(), "have": 0}
	var gold_base := 30.0 + level * 18.0
	var xp_base := float(GameData.xp_to_next(level)) * 0.3
	if roll < 0.45:
		var targets := hunt_targets(level)
		var m: String = targets[rng.randi_range(0, targets.size() - 1)]
		var n := rng.randi_range(5, 12) if GameData.MONSTERS[m]["hp"] < 2.0 else rng.randi_range(3, 6)
		q.merge({"type": "hunt", "target": m, "need": n, "title": "Hunt: %s" % GameData.MONSTERS[m]["name"],
			"desc": "Defeat %d %s." % [n, GameData.MONSTERS[m]["name"]], "gold": int(gold_base * n * 0.25 * rank_mult),
			"xp": int(xp_base * (0.6 + n * 0.08)), "gp": 10 + n})
	elif roll < 0.75:
		var pool: Array = GATHER_BY_LEVEL[0][1]
		for g in GATHER_BY_LEVEL:
			if level >= int(g[0]):
				pool = g[1]
		var mat: String = pool[rng.randi_range(0, pool.size() - 1)]
		var n2 := rng.randi_range(4, 10)
		var mname: String = GameData.item_template(mat).get("name", mat)
		q.merge({"type": "gather", "target": mat, "need": n2, "title": "Gather: %s" % mname,
			"desc": "Bring %d %s to the guild." % [n2, mname], "gold": int(gold_base * 0.6 * rank_mult + float(GameData.item_template(mat).get("price", 2)) * n2 * 3.0),
			"xp": int(xp_base * 0.7), "gp": 12})
	elif roll < 0.9:
		var rank: int = max(1, level - rng.randi_range(0, 8))
		q.merge({"type": "dungeon", "target": "", "need": 1, "min_rank": rank, "title": "Clear a Rank %d+ Dungeon" % rank,
			"desc": "Find a hidden dungeon of rank %d or higher and defeat its boss." % rank,
			"gold": int(gold_base * 3.0 * rank_mult), "xp": int(xp_base * 2.2), "gp": 40, "item_rarity": 2})
	else:
		var n3 := rng.randi_range(1, 3)
		q.merge({"type": "elite", "target": "", "need": n3, "title": "Elite Hunt",
			"desc": "Defeat %d elite, mini boss or boss monsters." % n3, "gold": int(gold_base * 1.6 * n3 * rank_mult),
			"xp": int(xp_base * 1.2 * n3), "gp": 25 * n3, "item_rarity": 1})
	return q


static func progress_text(q: Dictionary) -> String:
	var have: int = q.get("have", 0)
	if q["type"] == "gather":
		have = Game.count_item(q["target"])
	return "%d / %d" % [mini(have, int(q["need"])), int(q["need"])]


static func is_complete(q: Dictionary) -> bool:
	if q["type"] == "gather":
		return Game.count_item(q["target"]) >= int(q["need"])
	return int(q.get("have", 0)) >= int(q["need"])
