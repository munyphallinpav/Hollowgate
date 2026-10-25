extends RefCounted
## Item database: rarities, gear bases, affixes, consumables, materials, specials,
## unique boss drops and blacksmith recipes.

const RARITIES := [
	{"name": "Common", "color": Color("d8dee9"), "mult": 1.0, "affixes": 0, "price": 1.0},
	{"name": "Uncommon", "color": Color("63c74d"), "mult": 1.12, "affixes": 1, "price": 2.0},
	{"name": "Rare", "color": Color("3fa9f5"), "mult": 1.26, "affixes": 2, "price": 4.0},
	{"name": "Epic", "color": Color("b06cf0"), "mult": 1.45, "affixes": 3, "price": 8.0},
	{"name": "Legendary", "color": Color("ff9a2e"), "mult": 1.7, "affixes": 4, "price": 16.0},
	{"name": "Mythical", "color": Color("ff4f7b"), "mult": 2.0, "affixes": 5, "price": 32.0},
]
const RARITY_WEIGHTS := [600.0, 250.0, 100.0, 40.0, 9.0, 1.0]

const EQUIP_SLOTS := ["weapon", "armor", "necklace", "ring1", "ring2", "bracelet1", "bracelet2"]
const SLOT_NAMES := {"weapon": "Weapon", "armor": "Armor", "necklace": "Necklace", "ring1": "Ring", "ring2": "Ring",
	"bracelet1": "Bracelet", "bracelet2": "Bracelet"}

## Gear bases. cat: weapon|armor|necklace|ring|bracelet
const GEAR := {
	"sword": {"cat": "weapon", "name": "Sword", "icon": "sword", "atk": "patk", "atk_mult": 1.0, "implicit": {"pdef": 0.2},
		"attack": {"style": "melee", "radius": 30, "arc": 120, "cd": 0.45, "mult": 1.0, "knock": 90}},
	"spear": {"cat": "weapon", "name": "Spear", "icon": "spear", "atk": "patk", "atk_mult": 1.1, "implicit": {"crit": 3.0},
		"attack": {"style": "thrust", "radius": 46, "arc": 30, "cd": 0.55, "mult": 1.1, "knock": 70}},
	"hammer": {"cat": "weapon", "name": "Hammer", "icon": "hammer", "atk": "patk", "atk_mult": 1.45, "implicit": {"knock_pct": 30.0},
		"attack": {"style": "melee", "radius": 34, "arc": 160, "cd": 0.85, "mult": 1.6, "knock": 190}},
	"dagger": {"cat": "weapon", "name": "Dagger", "icon": "dagger", "atk": "patk", "atk_mult": 0.75, "implicit": {"crit": 8.0},
		"attack": {"style": "melee", "radius": 24, "arc": 90, "cd": 0.28, "mult": 0.65, "knock": 40}},
	"wand": {"cat": "weapon", "name": "Wand", "icon": "wand", "atk": "matk", "atk_mult": 1.0, "implicit": {"mp_regen": 1.0},
		"attack": {"style": "proj", "proj": "bolt", "speed": 280, "range": 240, "cd": 0.55, "mult": 1.0, "knock": 40}},
	"grimoire": {"cat": "weapon", "name": "Grimoire", "icon": "grimoire", "atk": "matk", "atk_mult": 1.2, "implicit": {"mp_pct": 5.0},
		"attack": {"style": "proj", "proj": "holy_orb", "speed": 220, "range": 230, "cd": 0.7, "mult": 1.25, "pierce": 1, "homing": 2.0, "knock": 40}},
	"bow": {"cat": "weapon", "name": "Bow", "icon": "bow", "atk": "patk", "atk_mult": 1.0, "implicit": {"crit": 2.0},
		"attack": {"style": "proj", "proj": "arrow", "speed": 360, "range": 280, "cd": 0.6, "mult": 1.0, "knock": 50}},
	"gun": {"cat": "weapon", "name": "Gun", "icon": "gun", "atk": "patk", "atk_mult": 0.95, "implicit": {"crit_dmg": 10.0},
		"attack": {"style": "proj", "proj": "bullet", "speed": 540, "range": 260, "cd": 0.42, "mult": 0.85, "knock": 60}},
	"heavy": {"cat": "armor", "name": "Heavy Armor", "icon": "armor_heavy", "def_mult": 1.0, "mdef_mult": 0.3, "implicit": {"hp_pct": 6.0, "move_pct": -8.0}},
	"light": {"cat": "armor", "name": "Light Armor", "icon": "armor_light", "def_mult": 0.75, "mdef_mult": 0.5, "implicit": {"hp_pct": 3.0}},
	"leather": {"cat": "armor", "name": "Leather Armor", "icon": "armor_leather", "def_mult": 0.5, "mdef_mult": 0.35, "implicit": {"dodge": 3.0, "aspd_pct": 5.0}},
	"robe": {"cat": "armor", "name": "Robe", "icon": "armor_robe", "def_mult": 0.25, "mdef_mult": 1.0, "implicit": {"mp_pct": 8.0}},
	"necklace": {"cat": "necklace", "name": "Necklace", "icon": "necklace", "implicit": {"res_all": 2.0}},
	"ring": {"cat": "ring", "name": "Ring", "icon": "ring", "implicit": {}},
	"bracelet": {"cat": "bracelet", "name": "Bracelet", "icon": "bracelet", "implicit": {}},
}
const WEAPON_TYPES := ["sword", "spear", "hammer", "dagger", "wand", "grimoire", "bow", "gun"]
const ARMOR_TYPES := ["heavy", "light", "leather", "robe"]
const ACCESSORY_TYPES := ["necklace", "ring", "bracelet"]

const TIER_PREFIX := ["Rusty", "Iron", "Steel", "Silver", "Mithril", "Runic", "Adamant", "Dragonbone", "Celestial"]
const ROBE_PREFIX := ["Tattered", "Linen", "Woven", "Silk", "Moonweave", "Runic", "Starweave", "Archmage", "Celestial"]
const LEATHER_PREFIX := ["Worn", "Hide", "Studded", "Hardened", "Shadow", "Runic", "Drakeskin", "Wyrmhide", "Celestial"]
const ACC_PREFIX := ["Copper", "Iron", "Silver", "Gold", "Mithril", "Runic", "Adamant", "Dragon", "Celestial"]

const AFFIX_SUFFIX := {"str": "of Might", "vit": "of Vigor", "int": "of Intellect", "mnd": "of the Mind", "dex": "of Finesse",
	"luk": "of Fortune", "hp": "of Life", "mp": "of Mana", "patk_pct": "of Fury", "matk_pct": "of Sorcery",
	"crit": "of Precision", "crit_dmg": "of Ruin", "aspd_pct": "of Haste", "move_pct": "of the Wind",
	"lifesteal": "of the Leech", "cdr": "of Alacrity", "dodge": "of Evasion", "drop_pct": "of Plunder"}

## stat, min, max, per_ilvl (value = (min..max) + per_ilvl*ilvl)
const AFFIXES := [
	["str", 1.0, 3.0, 0.45], ["vit", 1.0, 3.0, 0.45], ["int", 1.0, 3.0, 0.45], ["mnd", 1.0, 3.0, 0.45],
	["dex", 1.0, 3.0, 0.45], ["luk", 1.0, 3.0, 0.45], ["hp", 10.0, 25.0, 6.0], ["mp", 5.0, 12.0, 3.0],
	["patk", 2.0, 5.0, 1.0], ["matk", 2.0, 5.0, 1.0], ["pdef", 2.0, 5.0, 0.9], ["mdef", 2.0, 5.0, 0.9],
	["hp_pct", 3.0, 8.0, 0.0], ["mp_pct", 3.0, 8.0, 0.0], ["patk_pct", 3.0, 9.0, 0.0], ["matk_pct", 3.0, 9.0, 0.0],
	["pdef_pct", 4.0, 10.0, 0.0], ["mdef_pct", 4.0, 10.0, 0.0], ["crit", 1.0, 5.0, 0.0], ["crit_dmg", 5.0, 20.0, 0.0],
	["aspd_pct", 3.0, 9.0, 0.0], ["move_pct", 2.0, 7.0, 0.0], ["drop_pct", 5.0, 15.0, 0.0], ["gold_pct", 5.0, 20.0, 0.0],
	["res_fire", 4.0, 12.0, 0.0], ["res_water", 4.0, 12.0, 0.0], ["res_earth", 4.0, 12.0, 0.0], ["res_wind", 4.0, 12.0, 0.0],
	["res_light", 4.0, 12.0, 0.0], ["res_dark", 4.0, 12.0, 0.0], ["dmg_fire", 4.0, 12.0, 0.0], ["dmg_water", 4.0, 12.0, 0.0],
	["dmg_earth", 4.0, 12.0, 0.0], ["dmg_wind", 4.0, 12.0, 0.0], ["dmg_light", 4.0, 12.0, 0.0], ["dmg_dark", 4.0, 12.0, 0.0],
	["lifesteal", 0.5, 2.5, 0.0], ["hp_regen", 1.0, 3.0, 0.25], ["mp_regen", 0.5, 1.5, 0.1], ["cdr", 2.0, 6.0, 0.0],
	["dodge", 1.0, 4.0, 0.0],
]

## Consumables. use: heal_pct, mp_pct, satiety, buff{id,mods,dur}, cure
const CONSUMABLES := {
	"pot_hp_s": {"name": "Small Health Potion", "icon": "pot_hp_s", "kind": "potion", "price": 20, "heal_pct": 25, "heal_flat": 30, "desc": "Restores 25% HP +30."},
	"pot_hp_m": {"name": "Health Potion", "icon": "pot_hp_m", "kind": "potion", "price": 80, "heal_pct": 45, "heal_flat": 80, "lv": 15, "desc": "Restores 45% HP +80."},
	"pot_hp_l": {"name": "Greater Health Potion", "icon": "pot_hp_l", "kind": "potion", "price": 250, "heal_pct": 70, "heal_flat": 200, "lv": 35, "desc": "Restores 70% HP +200."},
	"pot_mp_s": {"name": "Small Mana Potion", "icon": "pot_mp_s", "kind": "potion", "price": 20, "mp_pct": 25, "mp_flat": 20, "desc": "Restores 25% MP +20."},
	"pot_mp_m": {"name": "Mana Potion", "icon": "pot_mp_m", "kind": "potion", "price": 80, "mp_pct": 45, "mp_flat": 50, "lv": 15, "desc": "Restores 45% MP +50."},
	"pot_mp_l": {"name": "Greater Mana Potion", "icon": "pot_mp_l", "kind": "potion", "price": 250, "mp_pct": 70, "mp_flat": 120, "lv": 35, "desc": "Restores 70% MP +120."},
	"pot_elixir": {"name": "Elixir", "icon": "pot_elixir", "kind": "potion", "price": 1200, "heal_pct": 100, "mp_pct": 100, "lv": 25, "desc": "Fully restores HP and MP."},
	"pot_antidote": {"name": "Antidote", "icon": "pot_antidote", "kind": "potion", "price": 40, "cure": true, "desc": "Cures poison, burn, chill, curse and grants 10s immunity."},
	"pot_str": {"name": "Potion of Might", "icon": "pot_str", "kind": "potion", "price": 300, "lv": 10, "buff": {"id": "pot_might", "mods": {"patk_pct": 20}, "dur": 120}, "desc": "+20% Phys Atk for 120s."},
	"pot_int": {"name": "Potion of Sorcery", "icon": "pot_int", "kind": "potion", "price": 300, "lv": 10, "buff": {"id": "pot_sorcery", "mods": {"matk_pct": 20}, "dur": 120}, "desc": "+20% Magic Atk for 120s."},
	"pot_def": {"name": "Ironskin Draught", "icon": "pot_def", "kind": "potion", "price": 300, "lv": 10, "buff": {"id": "pot_iron", "mods": {"pdef_pct": 25, "mdef_pct": 25}, "dur": 120}, "desc": "+25% Phys & Magic Def for 120s."},
	"pot_spd": {"name": "Swiftness Tonic", "icon": "pot_spd", "kind": "potion", "price": 300, "lv": 10, "buff": {"id": "pot_swift", "mods": {"move_pct": 20, "aspd_pct": 10}, "dur": 120}, "desc": "+20% Move Speed, +10% Attack Speed for 120s."},
	"food_apple": {"name": "Apple", "icon": "food_apple", "kind": "food", "price": 8, "satiety": 15, "heal_pct": 5, "desc": "Crunchy. +15 Satiety, heals 5% HP."},
	"food_berries": {"name": "Wild Berries", "icon": "food_berries", "kind": "food", "price": 5, "satiety": 10, "mp_pct": 5, "desc": "Foraged from bushes. +10 Satiety, 5% MP."},
	"food_bread": {"name": "Bread", "icon": "food_bread", "kind": "food", "price": 15, "satiety": 30, "buff": {"id": "food", "mods": {"hp_regen": 2}, "dur": 120}, "desc": "+30 Satiety. +2 HP regen/s for 120s."},
	"food_raw_meat": {"name": "Raw Meat", "icon": "food_raw_meat", "kind": "food", "price": 6, "satiety": 12, "poison_chance": 30, "desc": "+12 Satiety. Risky to eat raw..."},
	"food_fish": {"name": "Fresh Fish", "icon": "food_fish", "kind": "food", "price": 10, "satiety": 15, "mp_pct": 8, "desc": "+15 Satiety, 8% MP."},
	"food_grilled_meat": {"name": "Grilled Meat", "icon": "food_grilled_meat", "kind": "food", "price": 45, "satiety": 40, "buff": {"id": "food", "mods": {"patk_pct": 8}, "dur": 300}, "desc": "+40 Satiety. +8% Phys Atk for 300s."},
	"food_fish_stew": {"name": "Fish Stew", "icon": "food_fish_stew", "kind": "food", "price": 60, "satiety": 50, "buff": {"id": "food", "mods": {"mp_regen_pct": 0.5, "matk_pct": 8}, "dur": 300}, "desc": "+50 Satiety. MP regen and +8% Magic Atk for 300s."},
	"food_hearty_stew": {"name": "Hearty Stew", "icon": "food_hearty_stew", "kind": "food", "price": 80, "satiety": 60, "buff": {"id": "food", "mods": {"hp_regen_pct": 0.5, "pdef_pct": 10}, "dur": 300}, "desc": "+60 Satiety. HP regen and +10% Phys Def for 300s."},
	"food_honey_cake": {"name": "Honey Cake", "icon": "food_honey_cake", "kind": "food", "price": 70, "satiety": 35, "buff": {"id": "food", "mods": {"move_pct": 10, "aspd_pct": 5}, "dur": 300}, "desc": "+35 Satiety. +10% Move, +5% Attack Speed for 300s."},
	"food_feast": {"name": "Hero's Feast", "icon": "food_feast", "kind": "food", "price": 400, "satiety": 100, "lv": 20, "buff": {"id": "food", "mods": {"all_stats_pct": 10, "hp_regen_pct": 0.3}, "dur": 600}, "desc": "Full belly. +10% all main stats for 600s."},
}

## Materials: name, icon, value (sell), tier
const MATERIALS := {
	"wood": ["Wood", "mat_wood", 2], "hardwood": ["Hardwood", "mat_hardwood", 6], "stone": ["Stone", "mat_stone", 1],
	"ore_copper": ["Copper Ore", "mat_ore_copper", 4], "ore_iron": ["Iron Ore", "mat_ore_iron", 8],
	"ore_silver": ["Silver Ore", "mat_ore_silver", 15], "ore_gold": ["Gold Ore", "mat_ore_gold", 25],
	"ore_mithril": ["Mithril Ore", "mat_ore_mithril", 45], "ore_adamantite": ["Adamantite Ore", "mat_ore_adamantite", 80],
	"crystal_shard": ["Crystal Shard", "mat_crystal_shard", 30], "enchant_stone": ["Enchant Stone", "mat_enchant_stone", 50],
	"arcane_dust": ["Arcane Dust", "mat_arcane_dust", 20], "monster_core": ["Monster Core", "mat_monster_core", 120],
	"leather": ["Leather", "mat_leather", 6], "cloth": ["Cloth", "mat_cloth", 5], "herb": ["Herb", "mat_herb", 3],
	"feather": ["Feather", "mat_feather", 3], "slime_gel": ["Slime Gel", "mat_slime_gel", 2], "wolf_pelt": ["Wolf Pelt", "mat_wolf_pelt", 5],
	"tiger_fang": ["Tiger Fang", "mat_tiger_fang", 14], "bear_claw": ["Bear Claw", "mat_bear_claw", 12],
	"goblin_ear": ["Goblin Ear", "mat_goblin_ear", 4], "ogre_hide": ["Ogre Hide", "mat_ogre_hide", 20],
	"bone": ["Bone", "mat_bone", 6], "rotten_flesh": ["Rotten Flesh", "mat_rotten_flesh", 3],
	"ancient_bark": ["Ancient Bark", "mat_ancient_bark", 25], "dryad_petal": ["Dryad Petal", "mat_dryad_petal", 25],
	"lizard_scale": ["Lizard Scale", "mat_lizard_scale", 18], "mermaid_pearl": ["Mermaid Pearl", "mat_mermaid_pearl", 35],
	"vampire_fang": ["Vampire Fang", "mat_vampire_fang", 40], "wyvern_wing": ["Wyvern Wing", "mat_wyvern_wing", 60],
	"dragon_scale": ["Dragon Scale", "mat_dragon_scale", 150], "phoenix_feather": ["Phoenix Feather", "mat_phoenix_feather", 200],
}

## Special usable items
const SPECIALS := {
	"book_fire": {"name": "Tome: Flame Orb", "icon": "book_fire", "price": 3000, "lv": 10, "teach": "tome_flame_orb", "desc": "Read to learn the Flame Orb skill (Common tree)."},
	"book_water": {"name": "Tome: Aqua Spear", "icon": "book_water", "price": 3000, "lv": 10, "teach": "tome_aqua_spear", "desc": "Read to learn the Aqua Spear skill (Common tree)."},
	"book_earth": {"name": "Tome: Boulder Toss", "icon": "book_earth", "price": 6000, "lv": 20, "teach": "tome_rock_throw", "desc": "Read to learn the Boulder Toss skill (Common tree)."},
	"book_wind": {"name": "Tome: Gale Slash", "icon": "book_wind", "price": 6000, "lv": 20, "teach": "tome_gale_slash", "desc": "Read to learn the Gale Slash skill (Common tree)."},
	"book_light": {"name": "Tome: Radiant Burst", "icon": "book_light", "price": 12000, "lv": 30, "teach": "tome_radiant_burst", "desc": "Read to learn the Radiant Burst skill (Common tree)."},
	"book_dark": {"name": "Tome: Shadow Bolt", "icon": "book_dark", "price": 12000, "lv": 30, "teach": "tome_shadow_bolt", "desc": "Read to learn the Shadow Bolt skill (Common tree)."},
	"book_forget": {"name": "Tome of Forgetting", "icon": "book_neutral", "price": 5000, "respec": "skills", "desc": "Refunds all skill points."},
	"scroll_rebirth": {"name": "Scroll of Rebirth", "icon": "scroll", "price": 5000, "respec": "stats", "desc": "Refunds all allocated stat points."},
	"dungeon_crystal": {"name": "Dungeon Crystal", "icon": "dungeon_crystal", "price": 0, "desc": "Holds a custom dungeon. Use it in the wild to raise the dungeon at your feet."},
}

## Boss-unique drops (one per monster type)
const UNIQUES := {
	"slime": {"name": "Crown of the Gel King", "base": "necklace", "rarity": 4, "mods": {"hp_pct": 12, "hp_regen_pct": 0.4, "res_water": 15}},
	"wolf": {"name": "Fang of the Alpha", "base": "dagger", "rarity": 4, "mods": {"crit": 10, "move_pct": 8, "dmg_wind": 15}},
	"tiger": {"name": "Tigerclaw Bracer", "base": "bracelet", "rarity": 4, "mods": {"patk_pct": 12, "aspd_pct": 10, "crit_dmg": 20}},
	"bear": {"name": "Ursine Warplate", "base": "heavy", "rarity": 4, "mods": {"hp_pct": 15, "pdef_pct": 15, "vit": 20}},
	"goblin": {"name": "Goblin King's Blunderbuss", "base": "gun", "rarity": 4, "mods": {"gold_pct": 30, "crit_dmg": 30, "luk": 20}},
	"ogre": {"name": "Ogre Warlord's Crusher", "base": "hammer", "rarity": 4, "mods": {"patk_pct": 20, "str": 25, "knock_pct": 50}},
	"skeleton": {"name": "Bone Lord's Longbow", "base": "bow", "rarity": 4, "mods": {"dmg_dark": 20, "crit": 8, "dex": 20}},
	"zombie": {"name": "Ring of Pestilence", "base": "ring", "rarity": 4, "mods": {"poison_hit": 15, "res_dark": 15, "hp": 300}},
	"treant": {"name": "Heartwood Wand", "base": "wand", "rarity": 4, "mods": {"matk_pct": 15, "hp_regen_pct": 0.5, "dmg_earth": 20}},
	"dryad": {"name": "Grimoire of Blossoms", "base": "grimoire", "rarity": 4, "mods": {"heal_pct": 25, "dmg_earth": 15, "mnd": 25}},
	"lizard": {"name": "Scaled Lance", "base": "spear", "rarity": 4, "mods": {"dmg_water": 20, "aspd_pct": 10, "crit": 6}},
	"mermaid": {"name": "Tidecaller Pendant", "base": "necklace", "rarity": 4, "mods": {"mp_pct": 20, "dmg_water": 20, "int": 20}},
	"vampire": {"name": "Crimson Nightcloak", "base": "leather", "rarity": 4, "mods": {"lifesteal": 4, "dodge": 6, "dmg_dark": 15}},
	"wyvern": {"name": "Skyscale Bracers", "base": "bracelet", "rarity": 4, "mods": {"move_pct": 12, "dmg_wind": 20, "dodge": 4}},
	"dragon": {"name": "Dragonfang Greatsword", "base": "sword", "rarity": 5, "mods": {"patk_pct": 25, "dmg_fire": 25, "crit_dmg": 30, "res_fire": 20}},
	"phoenix": {"name": "Robe of the Undying Flame", "base": "robe", "rarity": 5, "mods": {"matk_pct": 22, "dmg_fire": 25, "hp_regen_pct": 0.8, "res_fire": 30}},
}

## Crafting tiers at the Blacksmith
const CRAFT_TIERS := [
	{"ore": "ore_copper", "ilvl": 5, "gold": 60, "part": "slime_gel"},
	{"ore": "ore_iron", "ilvl": 18, "gold": 300, "part": "wolf_pelt"},
	{"ore": "ore_silver", "ilvl": 32, "gold": 900, "part": "bone"},
	{"ore": "ore_gold", "ilvl": 48, "gold": 2400, "part": "lizard_scale"},
	{"ore": "ore_mithril", "ilvl": 66, "gold": 6000, "part": "vampire_fang"},
	{"ore": "ore_adamantite", "ilvl": 85, "gold": 14000, "part": "wyvern_wing"},
	{"ore": "dragon_scale", "ilvl": 100, "gold": 30000, "part": "phoenix_feather"},
]

const ENCHANT_RATES := [100, 100, 100, 90, 80, 70, 60, 50, 42, 35, 30, 25, 20, 15, 10]
const MAX_ENCHANT := 15
