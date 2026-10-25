class_name Items
extends RefCounted
## Item creation, naming, pricing and tooltips. Items are plain Dictionaries so they save as JSON.

const ID := preload("res://src/data/data_items.gd")


static func uid() -> int:
	Game.next_uid += 1
	return Game.next_uid


static func stack(id: String, qty: int = 1) -> Dictionary:
	return {"uid": uid(), "id": id, "qty": qty}


static func is_gear(it) -> bool:
	return it is Dictionary and it.get("id", "") == "gear"


static func category(it: Dictionary) -> String:
	if is_gear(it):
		return ID.GEAR[it["base"]]["cat"]
	var t := GameData.item_template(it.get("id", ""))
	return t.get("type", "material")


static func filter_group(it: Dictionary) -> String:
	if is_gear(it):
		return "gear"
	var t := GameData.item_template(it.get("id", ""))
	match t.get("type", ""):
		"consumable":
			return "consumable"
		"special":
			return "special"
	return "material"


static func max_stack(it: Dictionary) -> int:
	if is_gear(it):
		return 1
	if it.has("design"):
		return 1
	return int(GameData.item_template(it.get("id", "")).get("stack", 1))


static func can_stack(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	return a.get("id") == b.get("id") and max_stack(a) > 1 and not is_gear(a) and not a.has("design") and not b.has("design")


static func name_of(it: Dictionary) -> String:
	if it.is_empty():
		return ""
	if is_gear(it):
		var n: String = it.get("name", "Gear")
		if int(it.get("enchant", 0)) > 0:
			n = "+%d %s" % [it["enchant"], n]
		return n
	if it.has("design"):
		return "Dungeon Crystal: " + str(it["design"].get("name", "Custom"))
	return GameData.item_template(it["id"]).get("name", it["id"])


static func color_of(it: Dictionary) -> Color:
	if is_gear(it):
		return GameData.rarity_color(int(it.get("rarity", 0)))
	if it.get("id", "") == "dungeon_crystal":
		return Color("c79bff")
	var t := GameData.item_template(it.get("id", ""))
	if t.get("type", "") == "special":
		return Color("ffd27a")
	return Color("e8ecf2")


static func icon_of(it: Dictionary) -> Texture2D:
	if it.is_empty():
		return null
	if is_gear(it):
		return Art.icon(ID.GEAR[it["base"]]["icon"])
	return Art.icon(GameData.item_template(it["id"]).get("icon", "quest"))


## Price the shop charges (buy)
static func buy_price(it: Dictionary) -> int:
	if is_gear(it):
		return int(gear_value(it) * (2.5 if it.get("artifact", false) else 1.0))
	return int(GameData.item_template(it["id"]).get("price", 1))


## Gold received when selling one unit
static func sell_price(it: Dictionary) -> int:
	if is_gear(it):
		return max(1, int(gear_value(it) * 0.25))
	var t := GameData.item_template(it["id"])
	if t.get("type", "") == "material":
		return int(t.get("price", 1))
	return max(1, int(float(t.get("price", 1)) * 0.3))


static func gear_value(it: Dictionary) -> float:
	var r := GameData.rarity(int(it.get("rarity", 0)))
	return (12.0 + pow(float(it.get("ilvl", 1)), 1.3) * 5.0) * float(r["price"]) * (1.0 + 0.15 * float(it.get("enchant", 0)))


# ------------------------------------------------------------------ generation
static func tier_of(ilvl: int) -> int:
	return clampi(ilvl / 12, 0, 8)


static func base_name(base: String, ilvl: int) -> String:
	var g: Dictionary = ID.GEAR[base]
	var t := tier_of(ilvl)
	var prefix: String = ID.TIER_PREFIX[t]
	if base == "robe":
		prefix = ID.ROBE_PREFIX[t]
	elif base == "leather":
		prefix = ID.LEATHER_PREFIX[t]
	elif g["cat"] in ["necklace", "ring", "bracelet"]:
		prefix = ID.ACC_PREFIX[t]
	elif base in ["wand", "grimoire"]:
		prefix = ["Apprentice", "Oak", "Ashwood", "Silver", "Moonsilver", "Runic", "Starforged", "Archon", "Celestial"][t]
	elif base == "bow":
		prefix = ["Short", "Hunter's", "Recurve", "Silver", "Elven", "Runic", "Storm", "Dragonbone", "Celestial"][t]
	return "%s %s" % [prefix, g["name"]]


static func gen_gear(base: String, ilvl: int, rarity: int, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	ilvl = clampi(ilvl, 1, 100)
	rarity = clampi(rarity, 0, 5)
	var g: Dictionary = ID.GEAR[base]
	var rm: float = ID.RARITIES[rarity]["mult"]
	var st := {}
	var fl := float(ilvl)
	match g["cat"]:
		"weapon":
			st[g["atk"]] = roundf((8.0 + fl * 3.2) * float(g["atk_mult"]) * rm)
		"armor":
			st["pdef"] = roundf((6.0 + fl * 2.6) * float(g["def_mult"]) * rm)
			st["mdef"] = roundf((6.0 + fl * 2.6) * float(g["mdef_mult"]) * rm)
		"necklace":
			st["hp"] = roundf((20.0 + fl * 8.0) * rm)
		"ring":
			st["patk"] = roundf((2.0 + fl * 1.0) * rm)
			st["matk"] = roundf((2.0 + fl * 1.0) * rm)
		"bracelet":
			st["pdef"] = roundf((2.0 + fl * 0.8) * rm)
			st["crit"] = snappedf(1.0 + fl * 0.03 * rm, 0.1)
	var it := {"uid": uid(), "id": "gear", "base": base, "ilvl": ilvl, "rarity": rarity, "enchant": 0,
		"stats": st, "implicit": g.get("implicit", {}).duplicate(), "affixes": [], "name": base_name(base, ilvl)}
	roll_affixes(it, rng)
	return it


static func roll_affixes(it: Dictionary, rng: RandomNumberGenerator) -> void:
	var count: int = ID.RARITIES[int(it["rarity"])]["affixes"]
	var pool := range(ID.AFFIXES.size())
	var chosen := []
	var used := {}
	var ilvl := float(it["ilvl"])
	var tries := 0
	while chosen.size() < count and tries < 100:
		tries += 1
		var a: Array = ID.AFFIXES[pool[rng.randi_range(0, pool.size() - 1)]]
		if used.has(a[0]):
			continue
		used[a[0]] = true
		var v: float = lerpf(a[1], a[2], rng.randf()) + float(a[3]) * ilvl
		v *= 1.0 + 0.08 * float(it["rarity"])
		v = roundf(v) if float(a[3]) > 0.0 or a[0] in ["str", "vit", "int", "mnd", "dex", "luk"] else snappedf(v, 0.1)
		chosen.append([a[0], v])
	it["affixes"] = chosen
	# flavour suffix from the strongest affix
	var nm: String = base_name(it["base"], int(it["ilvl"]))
	if it.get("unique", "") != "":
		return
	for a in chosen:
		if ID.AFFIX_SUFFIX.has(a[0]):
			nm += " " + ID.AFFIX_SUFFIX[a[0]]
			break
	it["name"] = nm


static func roll_rarity(drop_mult: float = 1.0, min_r: int = 0, bonus: float = 0.0, rng: RandomNumberGenerator = null) -> int:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var weights: Array = ID.RARITY_WEIGHTS.duplicate()
	var total := 0.0
	for r in range(6):
		if r < min_r:
			weights[r] = 0.0
		elif r > 0:
			weights[r] = float(weights[r]) * pow(drop_mult * (1.0 + bonus), float(r) * 0.7)
		total += float(weights[r])
	var roll := rng.randf() * total
	for r in range(6):
		roll -= float(weights[r])
		if roll <= 0.0:
			return r
	return min_r


static func random_base(rng: RandomNumberGenerator, cats: Array = []) -> String:
	var all: Array = []
	for b in ID.GEAR:
		if cats.is_empty() or ID.GEAR[b]["cat"] in cats:
			all.append(b)
	# weapons and armor a bit more common than accessories
	return all[rng.randi_range(0, all.size() - 1)]


static func random_gear(ilvl: int, rarity: int = -1, drop_mult: float = 1.0, rng: RandomNumberGenerator = null, cats: Array = []) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	if rarity < 0:
		rarity = roll_rarity(drop_mult, 0, 0.0, rng)
	return gen_gear(random_base(rng, cats), ilvl, rarity, rng)


static func unique_for(monster: String, ilvl: int) -> Dictionary:
	var u: Dictionary = ID.UNIQUES.get(monster, ID.UNIQUES["slime"])
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var it := gen_gear(u["base"], ilvl, int(u["rarity"]), rng)
	it["unique"] = monster
	it["name"] = u["name"]
	var aff := []
	for k in u["mods"]:
		var v := float(u["mods"][k])
		if k in ["str", "vit", "int", "mnd", "dex", "luk", "hp"]:
			v = roundf(v * (1.0 + ilvl / 40.0))
		aff.append([k, v])
	it["affixes"] = aff
	return it


# ------------------------------------------------------------------ blacksmith
static func enchant_cost(it: Dictionary) -> Dictionary:
	var e: int = it.get("enchant", 0)
	return {"stones": 1 + e / 3, "gold": int(80.0 * (e + 1) * (1.0 + float(it.get("ilvl", 1)) / 20.0))}


static func enchant_rate(it: Dictionary) -> int:
	var e: int = it.get("enchant", 0)
	if e >= ID.MAX_ENCHANT:
		return 0
	return ID.ENCHANT_RATES[e]


static func reroll_cost(it: Dictionary) -> Dictionary:
	var r: int = it.get("rarity", 0)
	return {"dust": r + 1, "gold": int(150.0 * (r + 1) * (1.0 + float(it.get("ilvl", 1)) / 25.0))}


static func salvage_result(it: Dictionary) -> Dictionary:
	var r: int = it.get("rarity", 0)
	var out := {"arcane_dust": 1 + r * 2}
	if r >= 3:
		out["enchant_stone"] = r - 2
	return out


# ------------------------------------------------------------------ text
static func stat_line(k: String, v: float) -> String:
	return GameData.format_mod(k, v)


static func tooltip(it: Dictionary, compare: Dictionary = {}) -> String:
	if it.is_empty():
		return ""
	var lines: PackedStringArray = []
	var col := color_of(it).to_html(false)
	lines.append("[b][color=#%s]%s[/color][/b]" % [col, name_of(it)])
	if is_gear(it):
		var g: Dictionary = ID.GEAR[it["base"]]
		var r := GameData.rarity(int(it["rarity"]))
		lines.append("[color=#%s]%s %s[/color]   [color=#99a]iLvl %d[/color]" % [col, r["name"], g["name"], it["ilvl"]])
		if it.get("unique", "") != "":
			lines.append("[color=#ffb347]Unique — dropped by %s bosses[/color]" % GameData.MONSTERS.get(it["unique"], {}).get("name", "?"))
		var ench_mult := 1.0 + 0.07 * float(it.get("enchant", 0))
		var cmp_mods := {}
		if not compare.is_empty():
			cmp_mods = StatCalc.gear_mods(compare)
		var my_mods := StatCalc.gear_mods(it)
		for k in it["stats"]:
			var v := float(it["stats"][k]) * ench_mult
			var line := "[color=#ffffff]%s[/color]" % stat_line(k, v)
			if not compare.is_empty():
				var d := v - float(cmp_mods.get(k, 0.0))
				if absf(d) >= 0.5:
					line += "  [color=#%s](%s%d)[/color]" % ["7be05a" if d > 0 else "ff6a6a", "+" if d > 0 else "", int(d)]
			lines.append(line)
		for k in it.get("implicit", {}):
			lines.append("[color=#aab4c8]%s[/color]" % stat_line(k, it["implicit"][k]))
		if not it.get("affixes", []).is_empty():
			for a in it["affixes"]:
				lines.append("[color=#8fc8ff]%s[/color]" % stat_line(a[0], a[1]))
		if int(it.get("enchant", 0)) > 0:
			lines.append("[color=#c79bff]Enchanted +%d (+%d%% base stats)[/color]" % [it["enchant"], int(it["enchant"]) * 7])
		if g["cat"] == "weapon":
			var cls_w: String = GameData.CLASSES.get(Game.player.get("class", ""), {}).get("weapon", "")
			var spec = it["base"] == cls_w or (cls_w in ["wand", "grimoire"] and it["base"] in ["wand", "grimoire"])
			if spec:
				lines.append("[color=#ffd27a]Class specialty: +15% damage, +10% speed[/color]")
		if not compare.is_empty() and compare != it:
			lines.append("[color=#778]— compared to equipped %s —[/color]" % name_of(compare))
			var diff_keys := {}
			for k in my_mods:
				diff_keys[k] = true
			for k in cmp_mods:
				diff_keys[k] = true
			var shown := 0
			for k in diff_keys:
				if k in it["stats"]:
					continue
				var d2 := float(my_mods.get(k, 0.0)) - float(cmp_mods.get(k, 0.0))
				if absf(d2) > 0.05 and shown < 6:
					shown += 1
					lines.append("[color=#%s]%s[/color]" % ["7be05a" if d2 > 0 else "ff6a6a", stat_line(k, d2)])
		lines.append("[color=#e8c860]Sell: %d g[/color]" % sell_price(it))
	else:
		var t := GameData.item_template(it["id"])
		var tname = {"consumable": "Consumable", "material": "Material / Loot", "special": "Special"}.get(t.get("type", ""), "Item")
		if t.get("kind", "") == "food":
			tname = "Consumable — Food"
		elif t.get("kind", "") == "potion":
			tname = "Consumable — Potion"
		lines.append("[color=#99a]%s[/color]" % tname)
		lines.append(t.get("desc", ""))
		if it.has("design"):
			var d: Dictionary = it["design"]
			lines.append("[color=#c79bff]Rank %d • %s • %d rooms[/color]" % [int(d.get("rank", 1)), GameData.DUNGEON_BIOMES.get(d.get("biome", "cave"), {}).get("name", "?"), d.get("rooms", {}).size()])
		if int(t.get("lv", 0)) > 0:
			lines.append("[color=#aab]Requires level %d[/color]" % int(t["lv"]))
		if int(it.get("qty", 1)) > 1:
			lines.append("[color=#99a]Quantity: %d[/color]" % int(it["qty"]))
		lines.append("[color=#e8c860]Sell: %d g[/color]" % sell_price(it))
	return "\n".join(lines)
