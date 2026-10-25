extends Node
## Global read-only game data + balancing formulas.

const SkillData = preload("res://src/data/data_skills.gd")
const ItemData = preload("res://src/data/data_items.gd")
const WorldData = preload("res://src/data/data_world.gd")

const MAX_LEVEL := 100
const STAT_POINTS_PER_LEVEL := 10
const SKILL_POINTS_PER_LEVEL := 5
const COMMON_TIER_LEVELS := [1, 15, 30, 1]

var SKILLS: Dictionary = SkillData.SKILLS
var CLASSES: Dictionary = WorldData.CLASSES
var MONSTERS: Dictionary = WorldData.MONSTERS
var ATTACKS: Dictionary = WorldData.ATTACKS
var BIOMES: Dictionary = WorldData.BIOMES
var DUNGEON_BIOMES: Dictionary = WorldData.DUNGEON_BIOMES

## Human readable labels for stat keys (label, is_percent)
const STAT_LABELS := {
	"str": ["STR", false], "vit": ["VIT", false], "int": ["INT", false], "mnd": ["MND", false], "dex": ["DEX", false], "luk": ["LUK", false],
	"str_pct": ["STR", true], "vit_pct": ["VIT", true], "int_pct": ["INT", true], "mnd_pct": ["MND", true], "dex_pct": ["DEX", true], "luk_pct": ["LUK", true],
	"all_stats_pct": ["All Main Stats", true],
	"hp": ["Max HP", false], "hp_pct": ["Max HP", true], "mp": ["Max MP", false], "mp_pct": ["Max MP", true],
	"patk": ["Phys Atk", false], "patk_pct": ["Phys Atk", true], "matk": ["Magic Atk", false], "matk_pct": ["Magic Atk", true],
	"pdef": ["Phys Def", false], "pdef_pct": ["Phys Def", true], "mdef": ["Magic Def", false], "mdef_pct": ["Magic Def", true],
	"move_pct": ["Move Speed", true], "aspd_pct": ["Atk/Cast Speed", true], "crit": ["Crit Rate", true], "crit_dmg": ["Crit Damage", true],
	"crit_mag": ["Magic Crit Rate", true], "drop_pct": ["Drop Rate", true], "gold_pct": ["Gold Find", true],
	"res_all": ["All Resistances", true], "res_light": ["Light Res", true], "res_dark": ["Dark Res", true], "res_fire": ["Fire Res", true],
	"res_water": ["Water Res", true], "res_earth": ["Earth Res", true], "res_wind": ["Wind Res", true],
	"dmg_all_el": ["Elemental Damage", true], "dmg_light": ["Light Damage", true], "dmg_dark": ["Dark Damage", true],
	"dmg_fire": ["Fire Damage", true], "dmg_water": ["Water Damage", true], "dmg_earth": ["Earth Damage", true], "dmg_wind": ["Wind Damage", true],
	"hp_regen": ["HP Regen/s", false], "hp_regen_pct": ["HP Regen (% Max)/s", true], "mp_regen": ["MP Regen/s", false], "mp_regen_pct": ["MP Regen (% Max)/s", true],
	"dodge": ["Dodge Chance", true], "block": ["Block Chance", true], "lifesteal": ["Lifesteal", true], "cdr": ["Cooldown Reduction", true],
	"heal_pct": ["Healing Power", true], "dash_cd_pct": ["Dash Cooldown Reduction", true], "dash_dist_pct": ["Dash Distance", true],
	"status_resist": ["Status Resistance", true], "counter": ["Counter Chance", true], "kill_heal": ["Heal on Kill (% Max HP)", true],
	"low_hp_atk": ["Attack at Low HP", true], "low_hp_def": ["Defense at Low HP", true], "knock_pct": ["Knockback", true],
	"last_stand": ["Last Stand", false], "revive": ["Resurrection", false], "range_bonus": ["Long Range Damage", true], "split": ["Split Shot Chance", true],
	"wind_walker": ["Post-Dash Damage", true], "opportunist": ["Damage vs Afflicted", true], "poison_hit": ["Poison on Hit", true],
	"spree": ["Spree Bonus per Stack", true], "crit_heal": ["Heal on Crit", true], "mana_shield": ["Damage Taken from MP", true],
	"burn_pct": ["Burn Damage", true], "slow_pct": ["Chill Strength", true], "echo": ["Spell Echo Chance", true], "debuff_pct": ["Debuff Power", true],
	"martyr": ["Martyr Heal Chance", true], "undead_dmg": ["Damage vs Undead", true], "hunger_pct": ["Slower Hunger", true],
	"food_dur_pct": ["Food Duration", true], "gather_pct": ["Bonus Harvest Chance", true],
}


# ---------------------------------------------------------------- formulas
func xp_to_next(level: int) -> int:
	return int(40.0 + 25.0 * pow(float(level), 1.5))


func mon_hp(level: int) -> float:
	var l := float(level)
	return 30.0 + 22.0 * l + 0.18 * l * l


func mon_atk(level: int) -> float:
	return 8.0 + 9.0 * float(level)


func mon_def(level: int) -> float:
	return 3.0 + 4.0 * float(level)


func mon_xp(level: int) -> float:
	return 8.0 + 4.0 * float(level)


func element_mult(atk_el: String, def_el: String) -> float:
	if atk_el == "none" or atk_el == "" or def_el == "" or def_el == "none":
		return 1.0
	if WorldData.ELEMENT_STRONG.get(atk_el, "") == def_el:
		return 1.5
	if WorldData.ELEMENT_STRONG.get(def_el, "") == atk_el and atk_el != "light" and atk_el != "dark":
		return 0.75
	if atk_el == def_el:
		return 0.6
	return 1.0


func element_color(el: String) -> Color:
	return WorldData.ELEMENT_COLORS.get(el, Color.WHITE)


# ---------------------------------------------------------------- skills
func skill(id: String) -> Dictionary:
	return SKILLS.get(id, {})


func skills_for(cls: String) -> Array:
	var out := []
	for id in SKILLS:
		if SKILLS[id]["cls"] == cls:
			out.append(id)
	return out


func skill_req_level(id: String) -> int:
	var s: Dictionary = SKILLS[id]
	if s.has("req_lv"):
		return s["req_lv"]
	if s["cls"] == "common":
		return COMMON_TIER_LEVELS[s["row"]]
	return SkillData.TIER_LEVELS[s["row"]]


func skill_mp(id: String, lv: int) -> float:
	var s: Dictionary = SKILLS[id]
	return float(s.get("mp", 0)) + float(s.get("mp_lv", 0)) * float(max(lv - 1, 0))


func skill_cd(id: String, lv: int) -> float:
	var s: Dictionary = SKILLS[id]
	return max(0.5, float(s.get("cd", 1.0)) + float(s.get("cd_lv", 0.0)) * float(max(lv - 1, 0)))


func skill_power(id: String, lv: int) -> float:
	var s: Dictionary = SKILLS[id]
	return float(s.get("pow", 0)) + float(s.get("pow_lv", 0)) * float(max(lv - 1, 0))


## Generic "base + per-level" param lookup inside a skill's p dictionary.
func sp(id: String, key: String, lv: int, default = 0.0) -> float:
	var p: Dictionary = SKILLS[id].get("p", {})
	var base := float(p.get(key, default))
	return base + float(p.get(key + "_lv", 0.0)) * float(max(lv - 1, 0))


func skill_mods(id: String, lv: int) -> Dictionary:
	var s: Dictionary = SKILLS[id]
	var out := {}
	if s["type"] == "passive":
		for k in s.get("mods", {}):
			out[k] = float(s["mods"][k]) * lv
	else:
		var p: Dictionary = s.get("p", {})
		var mods: Dictionary = p.get("mods", {})
		var mods_lv: Dictionary = p.get("mods_lv", {})
		for k in mods:
			out[k] = float(mods[k]) + float(mods_lv.get(k, 0.0)) * float(max(lv - 1, 0))
	return out


func skill_description(id: String, lv: int) -> String:
	var s: Dictionary = SKILLS[id]
	var lines: PackedStringArray = []
	lines.append(s.get("desc", ""))
	var show_lv: int = max(lv, 1)
	if s["type"] == "active":
		var el: String = s.get("el", "none")
		var dmg: String = s.get("dmg", "none")
		if dmg != "none" and skill_power(id, show_lv) > 0:
			var label = {"phys": "Physical", "magic": "Magic", "hybrid": "Higher of Phys/Magic"}[dmg]
			lines.append("[color=#%s]%s[/color] damage: %d%% of %s Atk" % [element_color(el).to_html(false), el.capitalize(), int(skill_power(id, show_lv)), label])
		var mods := skill_mods(id, show_lv)
		for k in mods:
			lines.append("  " + format_mod(k, mods[k]))
		var st: Dictionary = s.get("status", {})
		if not st.is_empty():
			var dur := float(st.get("dur", 0)) + float(st.get("dur_lv", 0)) * (show_lv - 1)
			lines.append("%d%% chance to inflict %s (%.1fs)" % [int(st.get("chance", 100)), WorldData.STATUS[st["id"]]["name"], dur])
		var p: Dictionary = s.get("p", {})
		if p.has("dur") and s.get("kind", "") in ["buff", "enchant", "summon", "zone", "smoke", "shield", "spin", "regen", "quake", "rain"]:
			lines.append("Duration: %.1fs" % sp(id, "dur", show_lv))
		if s.get("hp_cost", 0) > 0:
			lines.append("Costs %d%% HP" % s["hp_cost"])
		lines.append("MP: %d   Cooldown: %.1fs" % [int(skill_mp(id, show_lv)), skill_cd(id, show_lv)])
	else:
		var mods2 := skill_mods(id, show_lv)
		for k in mods2:
			lines.append(format_mod(k, mods2[k]))
		if s.has("cond"):
			lines.append("[color=#aab]Requires: %s[/color]" % ", ".join(PackedStringArray(s["cond"])).capitalize())
	return "\n".join(lines)


func format_mod(key: String, value: float) -> String:
	var info: Array = STAT_LABELS.get(key, [key.capitalize(), false])
	if key == "last_stand" or key == "revive":
		return info[0]
	var sign := "+" if value >= 0 else ""
	if info[1]:
		var v := snappedf(value, 0.01)
		return "%s%s%s %s" % [sign, _num(v), "%", info[0]]
	return "%s%s %s" % [sign, _num(snappedf(value, 0.1)), info[0]]


func _num(v: float) -> String:
	if absf(v - roundf(v)) < 0.001:
		return str(int(roundf(v)))
	return str(snappedf(v, 0.01))


# ---------------------------------------------------------------- items
## Returns template info for any non-gear item id.
func item_template(id: String) -> Dictionary:
	if ItemData.CONSUMABLES.has(id):
		var c: Dictionary = ItemData.CONSUMABLES[id].duplicate()
		c["type"] = "consumable"
		c["stack"] = 99
		return c
	if ItemData.MATERIALS.has(id):
		var m: Array = ItemData.MATERIALS[id]
		return {"type": "material", "name": m[0], "icon": m[1], "price": m[2], "stack": 999, "desc": "Crafting material."}
	if ItemData.SPECIALS.has(id):
		var s: Dictionary = ItemData.SPECIALS[id].duplicate()
		s["type"] = "special"
		s["stack"] = 1 if id == "dungeon_crystal" else 20
		return s
	return {}


func is_stackable_id(id: String) -> bool:
	var t := item_template(id)
	return not t.is_empty() and int(t.get("stack", 1)) > 1


func rarity(r: int) -> Dictionary:
	return ItemData.RARITIES[clampi(r, 0, 5)]


func rarity_color(r: int) -> Color:
	return ItemData.RARITIES[clampi(r, 0, 5)]["color"]


func guild_rank(points: int) -> String:
	var rank := "F"
	for r in WorldData.GUILD_RANKS:
		if points >= r[1]:
			rank = r[0]
	return rank
