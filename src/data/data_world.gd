extends RefCounted
## Classes, elements, statuses, monsters, biomes, dungeon content.

const CLASSES := {
	"warrior": {"name": "Warrior", "role": "Physical / Melee", "weapon": "sword", "start_armor": "heavy",
		"base": {"str": 16, "vit": 14, "int": 4, "mnd": 6, "dex": 8, "luk": 6}, "hp_bonus": 20,
		"color": Color("e43b44"), "desc": "A sword-and-shield frontliner with the highest base Strength. Excels at melee and can take a beating."},
	"ranger": {"name": "Ranger", "role": "Physical / Ranged", "weapon": "bow", "start_armor": "leather",
		"base": {"str": 9, "vit": 8, "int": 5, "mnd": 6, "dex": 16, "luk": 10}, "hp_bonus": 0,
		"color": Color("63c74d"), "desc": "A bow master with the highest base Dexterity. Kites enemies and fires volleys from range."},
	"assassin": {"name": "Assassin", "role": "Physical / Melee", "weapon": "dagger", "start_armor": "leather",
		"base": {"str": 10, "vit": 7, "int": 5, "mnd": 5, "dex": 11, "luk": 16}, "hp_bonus": 10,
		"color": Color("9b5de5"), "desc": "A dagger specialist with the highest base Luck. Deadly critical hits, blinks and shadows."},
	"mage": {"name": "Mage", "role": "Magic / Damage", "weapon": "wand", "start_armor": "robe",
		"base": {"str": 4, "vit": 6, "int": 16, "mnd": 10, "dex": 9, "luk": 9}, "hp_bonus": 0,
		"color": Color("3fa9f5"), "desc": "Master of the elements with the highest base Intelligence. Devastating area spells."},
	"priest": {"name": "Priest", "role": "Magic / Support", "weapon": "grimoire", "start_armor": "robe",
		"base": {"str": 5, "vit": 9, "int": 10, "mnd": 16, "dex": 7, "luk": 7}, "hp_bonus": 10,
		"color": Color("fee761"), "desc": "A holy support with the highest base Mind. Heals, buffs allies, curses foes and smites the undead."},
}

const MAIN_STATS := ["str", "vit", "int", "mnd", "dex", "luk"]
const STAT_NAMES := {"str": "STR", "vit": "VIT", "int": "INT", "mnd": "MND", "dex": "DEX", "luk": "LUK"}
const STAT_DESC := {
	"str": "Strength: Physical Attack and Max HP",
	"vit": "Vitality: Max HP and Physical Defense",
	"int": "Intelligence: Magic Attack and Max MP",
	"mnd": "Mind: Max MP and Magic Defense",
	"dex": "Dexterity: Attack and Casting Speed",
	"luk": "Luck: Critical Rate, Critical Damage and Drop Rate",
}

const ELEMENTS := ["light", "dark", "fire", "water", "earth", "wind"]
const ELEMENT_COLORS := {
	"light": Color("ffe98a"), "dark": Color("a66bff"), "fire": Color("ff6a2a"), "water": Color("4fb4ff"),
	"earth": Color("d39a52"), "wind": Color("6ee7a8"), "none": Color("e8ecf2"),
}
## attacker element -> defender element it is strong against
const ELEMENT_STRONG := {"water": "fire", "fire": "earth", "earth": "wind", "wind": "water", "light": "dark", "dark": "light"}
const ELEMENT_STATUS := {"fire": "burn", "water": "chill", "earth": "stun", "wind": "shred", "light": "judged", "dark": "curse"}

const STATUS := {
	"burn": {"name": "Burn", "color": Color("ff6a2a"), "debuff": true},
	"chill": {"name": "Chill", "color": Color("8fd3ff"), "debuff": true},
	"freeze": {"name": "Freeze", "color": Color("bfe8ff"), "debuff": true},
	"stun": {"name": "Stun", "color": Color("fee761"), "debuff": true},
	"shred": {"name": "Shred", "color": Color("6ee7a8"), "debuff": true},
	"judged": {"name": "Judged", "color": Color("fff6c8"), "debuff": true},
	"curse": {"name": "Curse", "color": Color("a66bff"), "debuff": true},
	"poison": {"name": "Poison", "color": Color("7bd36a"), "debuff": true},
	"root": {"name": "Root", "color": Color("63c74d"), "debuff": true},
	"blind": {"name": "Blind", "color": Color("5a5a66"), "debuff": true},
}

## ---------------------------------------------------------------- monsters
## hp/atk/def/mdef are multipliers on the level curve. spd in px/s.
const MONSTERS := {
	"slime": {"name": "Slime", "hp": 0.7, "atk": 0.7, "def": 0.5, "mdef": 0.4, "spd": 42, "el": "water", "ai": "hopper",
		"attacks": ["hop"], "xp": 0.8, "radius": 6, "drops": [["slime_gel", 0.6, 1, 2], ["herb", 0.1, 1, 1]], "min_lv": 1, "weight": 10},
	"wolf": {"name": "Wolf", "hp": 0.9, "atk": 1.0, "def": 0.7, "mdef": 0.6, "spd": 88, "el": "wind", "ai": "pack",
		"attacks": ["lunge", "bite"], "xp": 1.0, "radius": 7, "drops": [["wolf_pelt", 0.45, 1, 1], ["food_raw_meat", 0.35, 1, 1]], "min_lv": 3, "weight": 8},
	"goblin": {"name": "Goblin", "hp": 0.85, "atk": 0.95, "def": 0.8, "mdef": 0.6, "spd": 62, "el": "earth", "ai": "melee",
		"attacks": ["throw", "strike"], "xp": 1.0, "radius": 6, "drops": [["goblin_ear", 0.4, 1, 1], ["cloth", 0.25, 1, 2]], "min_lv": 2, "weight": 8, "gold": 2.0},
	"bear": {"name": "Bear", "hp": 1.8, "atk": 1.4, "def": 1.2, "mdef": 0.7, "spd": 52, "el": "earth", "ai": "melee",
		"attacks": ["maul", "swipe"], "xp": 1.6, "radius": 11, "drops": [["bear_claw", 0.4, 1, 1], ["food_raw_meat", 0.6, 1, 2], ["leather", 0.4, 1, 2]], "min_lv": 8, "weight": 5},
	"skeleton": {"name": "Skeleton", "hp": 0.9, "atk": 1.1, "def": 1.0, "mdef": 0.6, "spd": 55, "el": "dark", "ai": "melee", "undead": true,
		"attacks": ["strike"], "variant_ranged": ["shoot_bone"], "xp": 1.1, "radius": 6, "drops": [["bone", 0.5, 1, 2]], "min_lv": 8, "weight": 7},
	"zombie": {"name": "Zombie", "hp": 1.4, "atk": 1.0, "def": 0.6, "mdef": 0.5, "spd": 32, "el": "dark", "ai": "melee", "undead": true,
		"attacks": ["grab"], "xp": 1.1, "radius": 7, "drops": [["rotten_flesh", 0.5, 1, 2], ["cloth", 0.2, 1, 1]], "min_lv": 6, "weight": 7},
	"lizard": {"name": "Lizardman", "hp": 1.1, "atk": 1.2, "def": 1.0, "mdef": 0.8, "spd": 66, "el": "water", "ai": "melee",
		"attacks": ["spit", "thrust"], "xp": 1.3, "radius": 7, "drops": [["lizard_scale", 0.4, 1, 1], ["food_fish", 0.2, 1, 1]], "min_lv": 14, "weight": 6},
	"tiger": {"name": "Tiger", "hp": 1.2, "atk": 1.5, "def": 0.9, "mdef": 0.7, "spd": 96, "el": "fire", "ai": "pouncer",
		"attacks": ["pounce", "claw"], "xp": 1.5, "radius": 9, "drops": [["tiger_fang", 0.4, 1, 1], ["leather", 0.3, 1, 2], ["food_raw_meat", 0.4, 1, 1]], "min_lv": 18, "weight": 5},
	"mermaid": {"name": "Mermaid", "hp": 1.0, "atk": 1.1, "def": 0.8, "mdef": 1.4, "spd": 50, "el": "water", "ai": "caster",
		"attacks": ["bubble", "trident"], "xp": 1.4, "radius": 7, "drops": [["mermaid_pearl", 0.25, 1, 1], ["food_fish", 0.5, 1, 2]], "min_lv": 16, "weight": 5},
	"ogre": {"name": "Ogre", "hp": 2.6, "atk": 1.8, "def": 1.4, "mdef": 0.8, "spd": 44, "el": "earth", "ai": "brute",
		"attacks": ["club_slam", "smash"], "xp": 2.2, "radius": 13, "drops": [["ogre_hide", 0.4, 1, 2], ["monster_core", 0.03, 1, 1]], "min_lv": 22, "weight": 4},
	"treant": {"name": "Treant", "hp": 3.0, "atk": 1.5, "def": 1.8, "mdef": 0.8, "spd": 30, "el": "earth", "ai": "brute",
		"attacks": ["roots", "branch"], "xp": 2.4, "radius": 13, "drops": [["ancient_bark", 0.4, 1, 1], ["hardwood", 0.6, 1, 3]], "min_lv": 25, "weight": 3},
	"dryad": {"name": "Dryad", "hp": 1.0, "atk": 1.3, "def": 0.8, "mdef": 1.5, "spd": 56, "el": "wind", "ai": "caster",
		"attacks": ["nature_heal", "leaf_spread"], "xp": 1.6, "radius": 7, "drops": [["dryad_petal", 0.35, 1, 1], ["herb", 0.5, 1, 2]], "min_lv": 25, "weight": 4},
	"vampire": {"name": "Vampire", "hp": 1.5, "atk": 1.6, "def": 1.1, "mdef": 1.4, "spd": 76, "el": "dark", "ai": "blinker", "undead": true,
		"attacks": ["summon_bats", "drain", "blink", "strike"], "xp": 2.2, "radius": 7, "drops": [["vampire_fang", 0.35, 1, 1]], "min_lv": 35, "weight": 3},
	"wyvern": {"name": "Wyvern", "hp": 1.8, "atk": 1.7, "def": 1.3, "mdef": 1.0, "spd": 82, "el": "wind", "ai": "flyer", "flying": 22,
		"attacks": ["poison_breath", "swoop"], "xp": 2.5, "radius": 12, "drops": [["wyvern_wing", 0.3, 1, 1], ["leather", 0.4, 1, 2]], "min_lv": 40, "weight": 3},
	"dragon": {"name": "Dragon", "hp": 6.0, "atk": 2.5, "def": 2.0, "mdef": 1.8, "spd": 56, "el": "fire", "ai": "dragon",
		"attacks": ["meteor_rain", "fire_breath", "tail_sweep", "claw"], "xp": 8.0, "radius": 22, "drops": [["dragon_scale", 0.6, 1, 2], ["monster_core", 0.3, 1, 1]], "min_lv": 60, "weight": 1},
	"phoenix": {"name": "Phoenix", "hp": 3.5, "atk": 2.2, "def": 1.2, "mdef": 2.2, "spd": 86, "el": "fire", "ai": "flyer", "flying": 26, "rebirth": true,
		"attacks": ["fire_nova", "fireball", "swoop"], "xp": 6.0, "radius": 14, "drops": [["phoenix_feather", 0.5, 1, 1], ["monster_core", 0.2, 1, 1]], "min_lv": 70, "weight": 1},
	"mimic": {"name": "Mimic", "hp": 1.6, "atk": 1.6, "def": 1.4, "mdef": 1.0, "spd": 70, "el": "dark", "ai": "mimic",
		"attacks": ["chomp", "hop"], "xp": 3.0, "radius": 8, "drops": [["arcane_dust", 0.6, 1, 3], ["enchant_stone", 0.4, 1, 1]], "min_lv": 1, "weight": 0, "gold": 8.0, "gear": 1.0},
	"rabbit": {"name": "Rabbit", "hp": 0.3, "atk": 0.0, "def": 0.2, "mdef": 0.2, "spd": 80, "el": "earth", "ai": "critter",
		"attacks": [], "xp": 0.3, "radius": 5, "drops": [["food_raw_meat", 0.5, 1, 1], ["leather", 0.2, 1, 1]], "min_lv": 1, "weight": 4, "passive": true},
	"deer": {"name": "Deer", "hp": 0.6, "atk": 0.0, "def": 0.3, "mdef": 0.3, "spd": 100, "el": "earth", "ai": "critter",
		"attacks": [], "xp": 0.5, "radius": 8, "drops": [["food_raw_meat", 0.8, 1, 2], ["leather", 0.6, 1, 2]], "min_lv": 1, "weight": 3, "passive": true},
	"bat": {"name": "Bat", "hp": 0.3, "atk": 0.6, "def": 0.3, "mdef": 0.3, "spd": 110, "el": "dark", "ai": "flyer", "flying": 14,
		"attacks": ["bite"], "xp": 0.2, "radius": 5, "drops": [], "min_lv": 1, "weight": 0},
}

## Attack definitions used by monster AI.
## type: melee|lunge|hop|pounce|slam|target_aoe|proj|spread|nova|heal|blink|summon|drain|swoop|breath|meteor
const ATTACKS := {
	"bite": {"type": "melee", "range": 18, "radius": 20, "arc": 90, "wind": 0.25, "power": 1.0, "cd": 1.2},
	"strike": {"type": "melee", "range": 20, "radius": 22, "arc": 100, "wind": 0.35, "power": 1.0, "cd": 1.3},
	"claw": {"type": "melee", "range": 22, "radius": 26, "arc": 110, "wind": 0.3, "power": 1.1, "cd": 1.1},
	"chomp": {"type": "melee", "range": 18, "radius": 22, "arc": 80, "wind": 0.3, "power": 1.5, "cd": 1.4},
	"grab": {"type": "melee", "range": 18, "radius": 20, "arc": 90, "wind": 0.5, "power": 1.0, "cd": 1.6, "status": "poison"},
	"thrust": {"type": "melee", "range": 26, "radius": 32, "arc": 40, "wind": 0.4, "power": 1.2, "cd": 1.5},
	"trident": {"type": "melee", "range": 24, "radius": 30, "arc": 50, "wind": 0.4, "power": 1.1, "cd": 1.6},
	"swipe": {"type": "melee", "range": 24, "radius": 30, "arc": 140, "wind": 0.45, "power": 1.3, "cd": 2.0},
	"branch": {"type": "melee", "range": 30, "radius": 38, "arc": 140, "wind": 0.6, "power": 1.3, "cd": 2.2},
	"maul": {"type": "slam", "range": 26, "radius": 34, "wind": 0.8, "power": 1.7, "cd": 5.0},
	"lunge": {"type": "lunge", "range": 80, "min": 30, "dist": 70, "wind": 0.45, "power": 1.2, "cd": 4.0},
	"hop": {"type": "hop", "range": 46, "radius": 14, "wind": 0.3, "power": 1.0, "cd": 1.6},
	"pounce": {"type": "pounce", "range": 120, "min": 40, "radius": 24, "wind": 0.6, "power": 1.6, "cd": 5.0},
	"club_slam": {"type": "slam", "range": 30, "radius": 46, "wind": 0.9, "power": 1.8, "cd": 4.5},
	"smash": {"type": "melee", "range": 28, "radius": 34, "arc": 120, "wind": 0.55, "power": 1.4, "cd": 2.0},
	"tail_sweep": {"type": "slam", "range": 40, "radius": 58, "wind": 0.8, "power": 1.5, "cd": 6.0},
	"roots": {"type": "target_aoe", "range": 150, "radius": 26, "wind": 0.9, "power": 1.5, "cd": 4.0, "fx": "rock", "status": "root"},
	"throw": {"type": "proj", "range": 130, "min": 50, "proj": "knife", "speed": 200, "wind": 0.45, "power": 0.9, "cd": 3.5},
	"shoot_bone": {"type": "proj", "range": 160, "proj": "bone", "speed": 210, "wind": 0.4, "power": 0.95, "cd": 2.0},
	"spit": {"type": "proj", "range": 130, "min": 40, "proj": "bolt", "speed": 220, "wind": 0.4, "power": 0.9, "cd": 3.0, "color": "4fb4ff"},
	"bubble": {"type": "proj", "range": 160, "proj": "bubble", "speed": 130, "wind": 0.5, "power": 1.0, "cd": 2.2, "status": "chill"},
	"fireball": {"type": "proj", "range": 180, "proj": "fireball", "speed": 200, "wind": 0.5, "power": 1.1, "cd": 2.5, "explode": 26},
	"leaf_spread": {"type": "spread", "range": 150, "proj": "leaf", "speed": 190, "count": 3, "spread": 40, "wind": 0.5, "power": 0.8, "cd": 2.4},
	"poison_breath": {"type": "breath", "range": 90, "arc": 50, "dur": 1.2, "wind": 0.5, "power": 0.3, "cd": 6.0, "fx": "poison", "status": "poison"},
	"fire_breath": {"type": "breath", "range": 110, "arc": 55, "dur": 1.4, "wind": 0.7, "power": 0.4, "cd": 6.0, "fx": "fire", "status": "burn"},
	"fire_nova": {"type": "nova", "range": 120, "proj": "fireball", "speed": 150, "count": 12, "wind": 0.7, "power": 0.9, "cd": 7.0},
	"meteor_rain": {"type": "meteor", "range": 200, "count": 5, "radius": 30, "wind": 1.0, "power": 1.6, "cd": 11.0},
	"nature_heal": {"type": "heal", "range": 130, "pct": 15, "wind": 0.6, "cd": 7.0},
	"blink": {"type": "blink", "range": 220, "min": 60, "wind": 0.2, "cd": 6.0},
	"summon_bats": {"type": "summon", "range": 200, "monster": "bat", "count": 3, "wind": 0.6, "cd": 14.0},
	"drain": {"type": "drain", "range": 90, "dur": 1.5, "wind": 0.3, "power": 0.35, "cd": 7.0},
	"swoop": {"type": "swoop", "range": 170, "min": 40, "wind": 0.5, "power": 1.4, "cd": 4.5},
}

## ---------------------------------------------------------------- overworld biomes
const BIOMES := {
	"grass": {"name": "Meadow", "ground": "grass", "alt": "dirt", "trees": {"tree_oak": 6, "bush": 3, "bush_berry": 1, "tree_big_oak": 1},
		"tree_density": 0.035, "deco": ["flower0", "flower1", "flower2", "tuft0", "tuft1"], "monsters": ["slime", "wolf", "goblin", "tiger", "ogre", "rabbit", "deer"],
		"slime": Color("7be05a")},
	"forest": {"name": "Deep Forest", "ground": "forest", "alt": "grass", "trees": {"tree_oak": 4, "tree_big_oak": 4, "tree_pine": 2, "bush": 2, "bush_berry": 1},
		"tree_density": 0.09, "deco": ["tuft0", "tuft1", "shroom0", "flower3"], "monsters": ["wolf", "bear", "goblin", "treant", "dryad", "tiger", "deer", "slime"],
		"slime": Color("4fbf6a")},
	"beach": {"name": "Coast", "ground": "sand", "alt": "sand", "trees": {"tree_palm": 5, "rock_small": 1},
		"tree_density": 0.02, "deco": ["shell", "pebble"], "monsters": ["slime", "lizard", "mermaid"], "slime": Color("4fb4ff")},
	"swamp": {"name": "Murk Swamp", "ground": "swamp", "alt": "swamp_water", "trees": {"tree_swamp_tree": 5, "bush": 2},
		"tree_density": 0.04, "deco": ["tuft0", "shroom1", "bone"], "monsters": ["zombie", "slime", "lizard", "skeleton", "vampire"],
		"slime": Color("8a6bd0")},
	"mushroom": {"name": "Mushroom Grove", "ground": "mushroom", "alt": "mushroom", "trees": {"tree_mushroom_tree": 6, "tree_crystal_tree": 1},
		"tree_density": 0.05, "deco": ["shroom0", "shroom1", "pebble"], "monsters": ["slime", "dryad", "treant", "vampire", "zombie"],
		"slime": Color("d06bd0")},
	"snow": {"name": "Frostlands", "ground": "snow", "alt": "snow", "trees": {"tree_snow_pine": 6, "rock_small": 1},
		"tree_density": 0.04, "deco": ["snowdrift", "pebble"], "monsters": ["wolf", "bear", "ogre", "skeleton", "wyvern", "deer"],
		"slime": Color("bfe8ff")},
	"desert": {"name": "Sunscorch Desert", "ground": "desert", "alt": "sand", "trees": {"tree_cactus": 4, "tree_dead_tree": 1, "rock_small": 2},
		"tree_density": 0.015, "deco": ["bone", "pebble"], "monsters": ["skeleton", "lizard", "goblin", "ogre", "wyvern", "phoenix"],
		"slime": Color("f0c060")},
	"volcanic": {"name": "Ashen Wastes", "ground": "ash", "alt": "lava", "trees": {"tree_dead_tree": 4, "rock_dark": 3},
		"tree_density": 0.025, "deco": ["ember", "rubble", "bone"], "monsters": ["slime", "ogre", "wyvern", "dragon", "phoenix", "skeleton"],
		"slime": Color("ff6a2a")},
}

## ---------------------------------------------------------------- dungeon biomes
const DUNGEON_BIOMES := {
	"lava": {"name": "Lava", "floor": "df_lava", "wall": "obsidian", "liquid": "lava", "deco": ["ember", "rubble", "bone"],
		"props": ["dg_pillar", "dg_torch0", "dg_bones"], "monsters": ["slime", "ogre", "lizard", "wyvern", "skeleton", "dragon", "phoenix"],
		"bosses": ["dragon", "phoenix", "ogre", "wyvern"], "slime": Color("ff6a2a"), "ambient": Color(0.58, 0.42, 0.4), "light": Color("ff8a4a")},
	"forest": {"name": "Forest", "floor": "df_forest", "wall": "hedge", "liquid": "water", "deco": ["tuft0", "tuft1", "flower3"],
		"props": ["dg_shrooms", "tree_oak", "bush"], "monsters": ["wolf", "bear", "goblin", "treant", "dryad", "tiger", "slime"],
		"bosses": ["treant", "bear", "tiger", "dryad", "wolf"], "slime": Color("4fbf6a"), "ambient": Color(0.5, 0.6, 0.5), "light": Color("c8ffb0")},
	"mushroom": {"name": "Mushroom", "floor": "df_mushroom", "wall": "mushroom", "liquid": "swamp_water", "deco": ["shroom0", "shroom1"],
		"props": ["dg_shrooms", "tree_mushroom_tree", "dg_crystals"], "monsters": ["slime", "dryad", "zombie", "vampire", "treant", "mimic"],
		"bosses": ["vampire", "treant", "dryad", "slime"], "slime": Color("d06bd0"), "ambient": Color(0.45, 0.38, 0.62), "light": Color("e0a8ff")},
	"grass": {"name": "Grass Plain", "floor": "df_grass", "wall": "stone", "liquid": "water", "deco": ["flower0", "flower2", "tuft0"],
		"props": ["dg_pillar", "bush", "tree_oak"], "monsters": ["slime", "wolf", "goblin", "ogre", "tiger", "bear"],
		"bosses": ["ogre", "goblin", "wolf", "tiger", "slime"], "slime": Color("7be05a"), "ambient": Color(0.72, 0.72, 0.66), "light": Color("fff2c8")},
	"beach": {"name": "Beach", "floor": "df_beach", "wall": "coral", "liquid": "water", "deco": ["shell", "pebble"],
		"props": ["dg_coral", "tree_palm", "dg_bones"], "monsters": ["slime", "lizard", "mermaid", "skeleton", "wyvern"],
		"bosses": ["mermaid", "lizard", "wyvern", "slime"], "slime": Color("4fb4ff"), "ambient": Color(0.66, 0.7, 0.78), "light": Color("c8f0ff")},
	"cave": {"name": "Cave", "floor": "df_cave", "wall": "cave", "liquid": "water", "deco": ["pebble", "rubble", "bone"],
		"props": ["dg_crystals", "dg_pillar", "dg_torch0", "dg_bones"], "monsters": ["skeleton", "zombie", "goblin", "bear", "vampire", "ogre", "mimic"],
		"bosses": ["vampire", "skeleton", "ogre", "bear", "zombie", "dragon"], "slime": Color("8b9bb4"), "ambient": Color(0.4, 0.4, 0.5), "light": Color("ffd08a")},
}
const WALL_STYLES := ["stone", "brick", "wood", "crystal", "obsidian", "hedge", "coral", "mushroom", "cave"]
const ROOM_SIZES := {"small": Vector2i(11, 9), "medium": Vector2i(15, 11), "large": Vector2i(19, 13)}
const CELL_SIZE := Vector2i(21, 15)

const TRAPS := {
	"spike": {"name": "Spike Floor", "icon": "dg_spike2", "desc": "Spikes periodically erupt from the floor."},
	"arrow": {"name": "Arrow Turret", "icon": "dg_arrow_trap", "desc": "Fires arrows at regular intervals."},
	"poison_gas": {"name": "Poison Gas Vent", "icon": "dg_gas_vent", "desc": "Vents a cloud of toxic gas."},
	"boulder": {"name": "Bouncing Boulder", "icon": "dg_boulder0", "desc": "A boulder that ricochets around the room."},
	"teleport": {"name": "Teleport Rune", "icon": "dg_tele_rune0", "desc": "Teleports whoever steps on it to another room."},
	"mimic": {"name": "Mimic", "icon": "dg_chest0_closed", "desc": "Looks like a treasure chest... it is not."},
	"pitfall": {"name": "Pitfall", "icon": "dg_plate", "desc": "A hidden pit that collapses underfoot."},
	"bomb": {"name": "Falling Bombs", "icon": "dg_bomb0", "desc": "Bombs fall from the ceiling when triggered."},
}
const SPAWNERS := {
	"nest": {"name": "Monster Nest", "icon": "dg_nest", "desc": "Spawns monsters until destroyed."},
	"totem": {"name": "Cursed Totem", "icon": "dg_totem", "desc": "Spawns monsters and empowers the room."},
	"circle": {"name": "Summoning Circle", "icon": "dg_circle0", "desc": "Summons a wave of monsters when you approach."},
	"grave": {"name": "Restless Grave", "icon": "dg_grave", "desc": "Raises undead periodically."},
}
const TREASURES := {
	"chest": {"name": "Treasure Chest", "icon": "dg_chest0_closed", "tier": 0},
	"silver_chest": {"name": "Silver Chest", "icon": "dg_chest1_closed", "tier": 1},
	"gold_chest": {"name": "Golden Chest", "icon": "dg_chest2_closed", "tier": 2},
}
const TERRAIN_PAINT := ["wall", "cliff", "water", "lava", "floor"]

const GUILD_RANKS := [["F", 0], ["E", 100], ["D", 300], ["C", 700], ["B", 1500], ["A", 3000], ["S", 6000]]
