class_name StatCalc
extends RefCounted
## Computes final player stats from class base + allocation + gear + passives + buffs.

const PCT_CAPS := {"crit": 85.0, "dodge": 60.0, "block": 75.0, "cdr": 40.0, "status_resist": 80.0, "mana_shield": 30.0,
	"echo": 30.0, "lifesteal": 25.0, "counter": 40.0}


static func add_mods(into: Dictionary, mods: Dictionary, mult: float = 1.0) -> void:
	for k in mods:
		into[k] = float(into.get(k, 0.0)) + float(mods[k]) * mult


## Modifiers granted by one gear item (base stats incl. enchant, implicit, affixes).
static func gear_mods(it: Dictionary) -> Dictionary:
	var out := {}
	var ench_mult := 1.0 + 0.07 * float(it.get("enchant", 0))
	var base: Dictionary = it.get("stats", {})
	for k in base:
		out[k] = float(out.get(k, 0.0)) + float(base[k]) * ench_mult
	add_mods(out, it.get("implicit", {}))
	for a in it.get("affixes", []):
		out[a[0]] = float(out.get(a[0], 0.0)) + float(a[1])
	return out


static func weapon_type(p: Dictionary) -> String:
	var w = p.get("equip", {}).get("weapon")
	if w is Dictionary:
		return w.get("base", "")
	return ""


static func compute(p: Dictionary, buff_mods: Array = []) -> Dictionary:
	var GD = GameData
	var cls: Dictionary = GD.CLASSES.get(p.get("class", "warrior"), GD.CLASSES["warrior"])
	var level: int = p.get("level", 1)
	var m := {}
	# gear
	for slot in p.get("equip", {}):
		var it = p["equip"][slot]
		if it is Dictionary and not it.is_empty():
			add_mods(m, gear_mods(it))
	# passives
	var wt := weapon_type(p)
	var skills: Dictionary = p.get("skills", {})
	for id in skills:
		var lv: int = skills[id]
		if lv <= 0 or not GD.SKILLS.has(id):
			continue
		var s: Dictionary = GD.SKILLS[id]
		if s["type"] != "passive":
			continue
		if s.has("cond") and not (wt in s["cond"]):
			continue
		add_mods(m, s.get("mods", {}), lv)
	for bm in buff_mods:
		add_mods(m, bm)
	var out := {}
	# main stats
	var all_pct := float(m.get("all_stats_pct", 0.0))
	for st in ["str", "vit", "int", "mnd", "dex", "luk"]:
		var v := float(cls["base"][st]) + float(p.get("alloc", {}).get(st, 0)) + float(m.get(st, 0.0))
		v *= 1.0 + (float(m.get(st + "_pct", 0.0)) + all_pct) / 100.0
		out[st] = v
	var STR: float = out["str"]
	var VIT: float = out["vit"]
	var INT: float = out["int"]
	var MND: float = out["mnd"]
	var DEX: float = out["dex"]
	var LUK: float = out["luk"]
	out["max_hp"] = (70.0 + STR * 2.0 + VIT * 8.0 + level * 8.0 + float(m.get("hp", 0.0))) * (1.0 + (float(m.get("hp_pct", 0.0)) + float(cls.get("hp_bonus", 0))) / 100.0)
	out["max_mp"] = (30.0 + INT * 3.0 + MND * 5.0 + level * 6.0 + float(m.get("mp", 0.0))) * (1.0 + float(m.get("mp_pct", 0.0)) / 100.0)
	out["patk"] = (5.0 + STR * 2.0 + DEX * 0.3 + float(m.get("patk", 0.0))) * (1.0 + float(m.get("patk_pct", 0.0)) / 100.0)
	out["matk"] = (5.0 + INT * 2.0 + MND * 0.3 + float(m.get("matk", 0.0))) * (1.0 + float(m.get("matk_pct", 0.0)) / 100.0)
	out["pdef"] = maxf(0.0, (VIT * 1.5 + STR * 0.2 + float(m.get("pdef", 0.0))) * (1.0 + float(m.get("pdef_pct", 0.0)) / 100.0))
	out["mdef"] = maxf(0.0, (MND * 1.5 + INT * 0.2 + float(m.get("mdef", 0.0))) * (1.0 + float(m.get("mdef_pct", 0.0)) / 100.0))
	out["move"] = clampf(85.0 * (1.0 + float(m.get("move_pct", 0.0)) / 100.0), 35.0, 190.0)
	out["aspd"] = clampf((1.0 + DEX * 0.003) * (1.0 + float(m.get("aspd_pct", 0.0)) / 100.0), 0.4, 3.0)
	out["crit"] = clampf(5.0 + LUK * 0.15 + float(m.get("crit", 0.0)), 0.0, PCT_CAPS["crit"])
	out["crit_mag"] = float(m.get("crit_mag", 0.0))
	out["crit_dmg"] = 150.0 + LUK * 0.4 + float(m.get("crit_dmg", 0.0))
	out["drop"] = 100.0 + LUK * 0.2 + float(m.get("drop_pct", 0.0))
	out["gold_find"] = 100.0 + float(m.get("gold_pct", 0.0))
	for el in ["light", "dark", "fire", "water", "earth", "wind"]:
		out["res_" + el] = clampf(float(m.get("res_all", 0.0)) + float(m.get("res_" + el, 0.0)), -50.0, 75.0)
		out["dmg_" + el] = float(m.get("dmg_all_el", 0.0)) + float(m.get("dmg_" + el, 0.0))
	out["hp_regen"] = 0.3 + VIT * 0.04 + float(m.get("hp_regen", 0.0)) + float(m.get("hp_regen_pct", 0.0)) / 100.0 * float(out["max_hp"])
	out["mp_regen"] = float(out["max_mp"]) * 0.012 + MND * 0.04 + float(m.get("mp_regen", 0.0)) + float(m.get("mp_regen_pct", 0.0)) / 100.0 * float(out["max_mp"])
	for k in ["dodge", "block", "lifesteal", "cdr", "status_resist", "mana_shield", "echo", "counter"]:
		out[k] = clampf(float(m.get(k, 0.0)), 0.0, PCT_CAPS.get(k, 100.0))
	for k in ["heal_pct", "dash_cd_pct", "dash_dist_pct", "kill_heal", "low_hp_atk", "low_hp_def", "knock_pct", "range_bonus",
			"split", "wind_walker", "opportunist", "poison_hit", "spree", "crit_heal", "burn_pct", "slow_pct", "debuff_pct",
			"martyr", "undead_dmg", "hunger_pct", "food_dur_pct", "gather_pct", "last_stand", "revive"]:
		out[k] = float(m.get(k, 0.0))
	out["dash_cd_pct"] = minf(out["dash_cd_pct"], 60.0)
	out["level"] = level
	out["el"] = "none"
	out["weapon"] = wt
	return out


## Short list of stats shown on the character sheet: [label, key, format]
static func sheet_rows() -> Array:
	return [
		["Max HP", "max_hp", "%d"], ["Max MP", "max_mp", "%d"], ["Phys Atk", "patk", "%d"], ["Magic Atk", "matk", "%d"],
		["Phys Def", "pdef", "%d"], ["Magic Def", "mdef", "%d"], ["Move Speed", "move", "%d"], ["Atk/Cast Speed", "aspd", "x%.2f"],
		["Crit Rate", "crit", "%.1f%%"], ["Crit Damage", "crit_dmg", "%d%%"], ["Drop Rate", "drop", "%d%%"], ["HP Regen", "hp_regen", "%.1f/s"],
		["MP Regen", "mp_regen", "%.1f/s"], ["Dodge", "dodge", "%.1f%%"], ["Block", "block", "%.1f%%"], ["Lifesteal", "lifesteal", "%.1f%%"],
		["Cooldown Red.", "cdr", "%.1f%%"],
	]
