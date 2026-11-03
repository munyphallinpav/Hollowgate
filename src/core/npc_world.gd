class_name NpcWorld
extends RefCounted
## NPC adventurers and the guild Dungeon Hall.
##
## Every NPC is a persistent character record shaped exactly like the hero's data (class, level,
## stat allocation, skills, hotbar, equipment, bag, gold, guild points, quests), so the same
## StatCalc formulas and the same Player/SkillExec code can drive them.
##
## Off-screen they are simulated once per second: they shop and train in town, travel to a hunting
## ground that suits their level, fight (outcomes use the real damage formulas), loot, drink potions,
## retreat or die, take quests from the guild board and play dungeons listed in the guild.
## When the hero is close, the Overworld spawns them as real Adventurer actors that fight with
## their real skills; the simulation then only keeps their schedule.

const MAX_NPCS := 50
const LISTING_CAPS := [3, 4, 5, 6, 7, 8, 10]  # by guild rank F..S
const MAX_GOLD_SHARE := 30
const MAX_ITEM_SHARE := 25
const MAX_NPC_LISTINGS := 40
const T := 16

const NAMES := ["Aldric", "Brynn", "Cedric", "Daria", "Elowen", "Fenwick", "Gwen", "Halvard", "Isolde", "Jorah", "Kael", "Liora",
	"Magnus", "Nyra", "Orrin", "Perrin", "Quinn", "Rowan", "Sable", "Torin", "Ulric", "Vesper", "Wren", "Xander", "Yara", "Zephyr",
	"Ansel", "Briar", "Corin", "Dagny", "Eira", "Faelan", "Garrick", "Hollis", "Ivo", "Juno", "Kestrel", "Lyra", "Mira", "Niall",
	"Odessa", "Pax", "Rhea", "Soren", "Talia", "Ulla", "Vale", "Willa", "Ysolde", "Zara", "Ash", "Bram", "Cora", "Dax", "Esme",
	"Finn", "Greta", "Hugo", "Ilsa", "Jasper", "Kira", "Leif", "Maren", "Nils", "Olwen", "Piers", "Ronan", "Selka", "Tamsin",
	"Uma", "Viggo", "Wilda", "Yorick", "Zinnia", "Arlo", "Bianca", "Caspian", "Delphine", "Emrys", "Freya"]
const BUILDS := {
	"warrior": {"str": 0.45, "vit": 0.35, "dex": 0.1, "luk": 0.1},
	"ranger": {"dex": 0.45, "str": 0.25, "vit": 0.2, "luk": 0.1},
	"assassin": {"luk": 0.4, "str": 0.25, "dex": 0.15, "vit": 0.2},
	"mage": {"int": 0.5, "mnd": 0.2, "vit": 0.2, "dex": 0.1},
	"priest": {"mnd": 0.45, "int": 0.25, "vit": 0.25, "dex": 0.05},
}
const ARMOR := {"warrior": "heavy", "ranger": "leather", "assassin": "leather", "mage": "robe", "priest": "robe"}
const ARMOR_PREF := {
	"warrior": {"heavy": 1.0, "light": 0.8, "leather": 0.45, "robe": 0.15},
	"ranger": {"leather": 1.0, "light": 0.85, "heavy": 0.4, "robe": 0.3},
	"assassin": {"leather": 1.0, "light": 0.8, "heavy": 0.35, "robe": 0.3},
	"mage": {"robe": 1.0, "light": 0.4, "leather": 0.4, "heavy": 0.15},
	"priest": {"robe": 1.0, "light": 0.5, "leather": 0.4, "heavy": 0.2},
}
const ACC_SLOTS := [["necklace", "necklace", 5], ["ring1", "ring", 10], ["bracelet1", "bracelet", 15], ["ring2", "ring", 25], ["bracelet2", "bracelet", 35]]
const DUNGEON_ADJ := ["Ember", "Sunken", "Whispering", "Hollow", "Verdant", "Crimson", "Frozen", "Shrouded", "Gilded", "Forgotten",
	"Mossy", "Ashen", "Coral", "Thorned", "Moonlit", "Howling", "Silent", "Molten"]
const DUNGEON_NOUN := ["Vault", "Catacombs", "Grotto", "Labyrinth", "Den", "Halls", "Burrow", "Sanctum", "Crypt", "Hive", "Warren",
	"Depths", "Keep", "Maze"]

## Gates: [inner point, outer point] in tiles.
const GATES := [[Vector2(256, 234), Vector2(256, 226)], [Vector2(256, 277), Vector2(256, 285)],
	[Vector2(234, 256), Vector2(226, 256)], [Vector2(277, 256), Vector2(285, 256)]]

static var actors: Dictionary = {}  # npc id -> Adventurer node (only while physically present)
static var _acc := 0.0
static var _grow_acc := 0.0
static var _board_acc := 0.0
static var _news_t := 0.0
static var _gen: WorldGen = null
static var _gen_seed := -1
static var _rng := RandomNumberGenerator.new()


# =================================================================== setup
static func world() -> Dictionary:
	return Game.world


static func npcs() -> Array:
	return Game.world.get("npcs", [])


static func gen() -> WorldGen:
	var s := int(Game.world.get("seed", 1))
	if _gen == null or _gen_seed != s:
		_gen = WorldGen.new(s)
		_gen_seed = s
	return _gen


## Adds missing keys (new game or an older save) and creates the starting adventurers (2-5).
static func ensure_world() -> void:
	_rng.randomize()
	var w: Dictionary = Game.world
	for k in ["npcs", "guild_listings", "guild_log"]:
		if not w.has(k):
			w[k] = []
	if not w.has("npc_next_id"):
		w["npc_next_id"] = 1
	if not w.has("listing_next_id"):
		w["listing_next_id"] = 1
	if not w.has("guild_payout"):
		w["guild_payout"] = {"gold": 0, "items": []}
	if not w.has("npc_start"):
		w["npc_start"] = _rng.randi_range(2, 5)
	if not Game.player.has("guild_played"):
		Game.player["guild_played"] = {}
	actors.clear()
	for n in w["npcs"]:
		n["physical"] = false
		n.erase("challenge")
		if n["state"] == "duel":  # saved mid-duel: the duel is off
			n["state"] = n.get("state_before_duel", "town")
			if n["state"] == "duel":
				n["state"] = "town"
		n.erase("state_before_duel")
	if not w.get("npc_init", false):
		w["npc_init"] = true
		var plv := int(Game.player.get("level", 1))
		for i in int(w["npc_start"]):
			add_npc(clampi(plv + _rng.randi_range(0, 2), 1, 100), false)


static func target_count() -> int:
	return mini(MAX_NPCS, int(Game.world.get("npc_start", 3)) + int(Game.player.get("level", 1)) / 2)


static func find(id: int) -> Dictionary:
	for n in npcs():
		if int(n["id"]) == id:
			return n
	return {}


# =================================================================== creation & growth
static func _unique_name() -> String:
	var used := {}
	for n in npcs():
		used[n["name"]] = true
	var pool := []
	for nm in NAMES:
		if not used.has(nm):
			pool.append(nm)
	if pool.is_empty():
		return "%s %s" % [NAMES[_rng.randi() % NAMES.size()], ["II", "III", "the Younger", "of the Dunes"][_rng.randi() % 4]]
	return pool[_rng.randi() % pool.size()]


static func _pick_class() -> String:
	var count := {"warrior": 0, "ranger": 0, "assassin": 0, "mage": 0, "priest": 0}
	for n in npcs():
		count[n["class"]] = int(count[n["class"]]) + 1
	var best := []
	var lo := 999
	for c in count:
		if int(count[c]) < lo:
			lo = int(count[c])
	for c in count:
		if int(count[c]) <= lo + 1:
			best.append(c)
	return best[_rng.randi() % best.size()]


## Creates a new adventurer of the given level, fully trained and equipped for it.
static func add_npc(level: int, announce: bool = true) -> Dictionary:
	if npcs().size() >= MAX_NPCS:
		return {}
	var cls := _pick_class()
	var id := int(Game.world["npc_next_id"])
	Game.world["npc_next_id"] = id + 1
	var spot := town_spot(_rng.randi())
	var n := {
		"id": id, "name": _unique_name(), "class": cls, "level": 1, "xp": 0, "gold": 0,
		"alloc": {"str": 0, "vit": 0, "int": 0, "mnd": 0, "dex": 0, "luk": 0}, "stat_points": 0, "skill_points": 1,
		"skills": {}, "tomes": [], "hot_skills": ["", "", "", ""], "hot_items": ["", "", "", ""],
		"equip": {"weapon": {}, "armor": {}, "necklace": {}, "ring1": {}, "ring2": {}, "bracelet1": {}, "bracelet2": {}},
		"inv": [], "bag_size": 24, "hp_frac": 1.0, "mp_frac": 1.0, "satiety": 100.0,
		"guild_points": 0, "quests": [], "kills": 0, "dungeons_cleared": 0, "deaths": 0, "quests_done": 0,
		"state": "town", "state_t": _rng.randf_range(8.0, 30.0), "pos": [spot.x, spot.y], "dest": [spot.x, spot.y],
		"hunt_lv": 1, "kill_t": 4.0, "visited": true, "run": {}, "played": {}, "joined_day": int(Game.world.get("day", 1)),
		"bravery": snappedf(_rng.randf(), 0.01), "physical": false, "kill_streak": 0, "hue": snappedf(_rng.randf_range(0.12, 0.88), 0.01),
		"talent": _rng.randi_range(-6, 5),
	}
	n["equip"]["weapon"] = Items.gen_gear(GameData.CLASSES[cls]["weapon"], 1, 0, _rng)
	n["equip"]["armor"] = Items.gen_gear(ARMOR[cls], 1, 0, _rng)
	for i in level - 1:
		_level_up(n, false)
	n["gold"] = 120 + level * 70
	if level > 3:
		# Late joiners arrive with a history: some guild standing and a kill record.
		n["guild_points"] = int(level * level * 0.5 * _rng.randf_range(0.6, 1.3))
		n["kills"] = int(level * _rng.randf_range(10.0, 22.0))
		n["quests_done"] = int(n["guild_points"]) / 22
		n["dungeons_cleared"] = int(level / 6.0 * _rng.randf_range(0.5, 1.5))
		n["deaths"] = int(level / 10.0 * _rng.randf_range(0.2, 1.4))
	_kit_out(n, level)
	_spend_points(n)
	_restock_potions(n, true)
	Game.world["npcs"].append(n)
	if announce:
		news("A new adventurer joined the guild: %s the %s (Lv %d)." % [n["name"], GameData.CLASSES[cls]["name"], int(n["level"])], Color("8fe8ff"), true)
	return n


## Gear appropriate for the level (used when an NPC joins).
static func _kit_out(n: Dictionary, level: int) -> void:
	var cls: String = n["class"]
	var rar := 0 if level < 8 else (1 if level < 25 else (2 if level < 55 else 3))
	var il := maxi(1, level - _rng.randi_range(0, 3))
	n["equip"]["weapon"] = Items.gen_gear(GameData.CLASSES[cls]["weapon"], il, clampi(rar + _rng.randi_range(-1, 0), 0, 5), _rng)
	n["equip"]["armor"] = Items.gen_gear(ARMOR[cls], il, clampi(rar + _rng.randi_range(-1, 0), 0, 5), _rng)
	for a in ACC_SLOTS:
		if level >= int(a[2]):
			n["equip"][a[0]] = Items.gen_gear(a[1], il, clampi(rar - 1, 0, 5), _rng)


static func _grow() -> void:
	var want := target_count()
	if npcs().size() < want:
		var plv := int(Game.player.get("level", 1))
		add_npc(clampi(plv + _rng.randi_range(-5, 3), 1, 100), true)


# =================================================================== progression
## Each adventurer has a personal talent: the level it settles at relative to the hero (-6..+5).
## NPCs progress with the hero's level: they catch up quickly when far behind their target and
## slow to a crawl once they are a few levels past it, so the crowd stays spread around the hero.
static func talent_of(n: Dictionary) -> int:
	if n.has("talent"):
		return int(n["talent"])
	return (int(n["id"]) * 37) % 12 - 6


static func target_level(n: Dictionary) -> int:
	return clampi(int(Game.player.get("level", 1)) + talent_of(n), 3, 100)


static func xp_catchup(n: Dictionary) -> float:
	var diff := target_level(n) - int(n["level"])
	if diff > 12:
		return 3.0
	if diff > 6:
		return 2.0
	if diff > 2:
		return 1.4
	if diff >= -1:
		return 1.0
	if diff >= -2:
		return 0.3
	if diff >= -4:
		return 0.06
	return 0.0


## `party`: XP shared in a party always counts at least half (party members level along with you).
static func gain_xp(n: Dictionary, amount: float, party: bool = false) -> void:
	if int(n["level"]) >= GameData.MAX_LEVEL:
		return
	var mult := xp_catchup(n)
	if party:
		mult = maxf(mult, 0.5)
	n["xp"] = int(n["xp"]) + int(amount * mult)
	var ups := 0
	while int(n["level"]) < GameData.MAX_LEVEL and int(n["xp"]) >= GameData.xp_to_next(int(n["level"])):
		n["xp"] = int(n["xp"]) - GameData.xp_to_next(int(n["level"]))
		_level_up(n, true)
		ups += 1
	if ups > 0:
		n["hp_frac"] = 1.0
		n["mp_frac"] = 1.0
		var a = actor_of(n)
		if a:
			a.on_npc_level_up()
		var lv := int(n["level"])
		if lv % 10 == 0:
			news("%s the %s reached level %d!" % [n["name"], GameData.CLASSES[n["class"]]["name"], lv], Color("fee761"), false)


static func _level_up(n: Dictionary, spend: bool) -> void:
	n["level"] = int(n["level"]) + 1
	n["stat_points"] = int(n["stat_points"]) + GameData.STAT_POINTS_PER_LEVEL
	n["skill_points"] = int(n["skill_points"]) + GameData.SKILL_POINTS_PER_LEVEL
	if spend:
		_spend_points(n)


static func _spend_points(n: Dictionary) -> void:
	# stats: follow the class build
	var sp := int(n["stat_points"])
	if sp > 0:
		var b: Dictionary = BUILDS[n["class"]]
		var given := 0
		var primary := ""
		for k in b:
			if primary == "":
				primary = k
			var amt := int(floor(sp * float(b[k])))
			n["alloc"][k] = int(n["alloc"][k]) + amt
			given += amt
		n["alloc"][primary] = int(n["alloc"][primary]) + (sp - given)
		n["stat_points"] = 0
	# skills: first every new active, then passives, then ranks of the equipped actives
	var guard := 0
	while int(n["skill_points"]) > 0 and guard < 600:
		guard += 1
		var best := ""
		var bs := -1.0
		for id in GameData.skills_for(n["class"]) + GameData.skills_for("common"):
			if not _can_learn(n, id):
				continue
			var s: Dictionary = GameData.SKILLS[id]
			var r := int(n["skills"].get(id, 0))
			var score := 0.0
			if s["type"] == "active":
				score = (100.0 - float(s["row"]) * 3.0) if r == 0 else ((55.0 if id in n["hot_skills"] else 12.0) - r * 1.5)
				if s.get("dmg", "none") == "none" and r > 0:
					score -= 15.0
			else:
				score = (85.0 - float(s["row"]) * 3.0) if r == 0 else (42.0 - r * 1.2)
				if s.has("cond") and not (GameData.CLASSES[n["class"]]["weapon"] in s["cond"] or (s["cond"].has("wand") and n["class"] in ["mage", "priest"])):
					score -= 60.0
			score += _rng.randf() * 4.0
			if score > bs:
				bs = score
				best = id
		if best == "":
			break
		n["skills"][best] = int(n["skills"].get(best, 0)) + 1
		n["skill_points"] = int(n["skill_points"]) - 1
		_pick_hot(n)


static func _can_learn(n: Dictionary, id: String) -> bool:
	var s: Dictionary = GameData.SKILLS[id]
	if s["cls"] != "common" and s["cls"] != n["class"]:
		return false
	if s.has("tome") and not (id in n.get("tomes", [])):
		return false
	if int(n["skills"].get(id, 0)) >= int(s["max"]):
		return false
	if int(n["level"]) < GameData.skill_req_level(id):
		return false
	for r in s.get("req", {}):
		if int(n["skills"].get(r, 0)) < int(s["req"][r]):
			return false
	return true


## The four actives on the NPC's hotbar: mostly damage, one support skill.
static func _pick_hot(n: Dictionary) -> void:
	var acts := []
	for id in n["skills"]:
		var s: Dictionary = GameData.SKILLS.get(id, {})
		if s.get("type", "") == "active" and int(n["skills"][id]) > 0:
			var dmg: bool = s.get("dmg", "none") != "none"
			acts.append([id, (100.0 if dmg else 60.0) + int(n["skills"][id]) * 2.0 + float(s.get("row", 0)) * 6.0, dmg])
	acts.sort_custom(func(a, b): return a[1] > b[1])
	var hot := []
	var support := 0
	for a in acts:
		if hot.size() >= 4:
			break
		if not a[2]:
			if support >= 1:
				continue
			support += 1
		hot.append(a[0])
	while hot.size() < 4:
		hot.append("")
	n["hot_skills"] = hot


## Outfit hue shift of an adventurer (clothes recoloured so same-class NPCs look different).
static func hue_of(n: Dictionary) -> float:
	if n.has("hue"):
		return float(n["hue"])
	return 0.12 + float((int(n["id"]) * 7919) % 760) / 1000.0


## A material for portraits/icons that applies the same outfit colours as the actor.
static func hue_material(n: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = Actor.FLASH_SHADER
	m.set_shader_parameter("hue_shift", hue_of(n))
	return m


static func stats_of(n: Dictionary) -> Dictionary:
	return StatCalc.compute(n, [])


# =================================================================== bag
static func bag_free(n: Dictionary) -> int:
	return int(n["bag_size"]) - n["inv"].size()


static func add_item(n: Dictionary, it: Dictionary) -> bool:
	if Items.max_stack(it) > 1:
		for s in n["inv"]:
			if Items.can_stack(s, it):
				s["qty"] = int(s["qty"]) + int(it.get("qty", 1))
				return true
	if n["inv"].size() >= int(n["bag_size"]):
		return false
	n["inv"].append(it.duplicate(true))
	return true


static func count(n: Dictionary, id: String) -> int:
	var c := 0
	for s in n["inv"]:
		if s.get("id", "") == id and not Items.is_gear(s):
			c += int(s.get("qty", 1))
	return c


static func remove(n: Dictionary, id: String, qty: int) -> void:
	for i in range(n["inv"].size() - 1, -1, -1):
		var s: Dictionary = n["inv"][i]
		if s.get("id", "") != id or Items.is_gear(s):
			continue
		var take := mini(qty, int(s.get("qty", 1)))
		s["qty"] = int(s.get("qty", 1)) - take
		qty -= take
		if int(s["qty"]) <= 0:
			n["inv"].remove_at(i)
		if qty <= 0:
			return


static func _potion_ids(n: Dictionary) -> Array:
	var lv := int(n["level"])
	return ["pot_hp_l" if lv >= 35 else ("pot_hp_m" if lv >= 15 else "pot_hp_s"), "pot_mp_l" if lv >= 35 else ("pot_mp_m" if lv >= 15 else "pot_mp_s")]


## Drinks the best HP (or MP) potion in the bag. Returns the potion template or {}.
static func drink(n: Dictionary, mp: bool = false) -> Dictionary:
	var order := ["pot_mp_l", "pot_mp_m", "pot_mp_s"] if mp else ["pot_hp_l", "pot_hp_m", "pot_hp_s", "pot_elixir"]
	for id in order:
		if count(n, id) > 0:
			remove(n, id, 1)
			return GameData.item_template(id)
	return {}


static func gear_score(n: Dictionary, it: Dictionary) -> float:
	if it.is_empty():
		return 0.0
	var v := Items.gear_value(it)
	var cat := Items.category(it)
	if cat == "weapon":
		var w: String = it["base"]
		var cw: String = GameData.CLASSES[n["class"]]["weapon"]
		var magic: bool = n["class"] in ["mage", "priest"]
		if w == cw or (magic and w in ["wand", "grimoire"]):
			v *= 1.0
		elif GameData.ItemData.GEAR[w].get("atk", "patk") == ("matk" if magic else "patk"):
			v *= 0.22  # usable, but they lose their class-weapon bonus and weapon passives
		else:
			v *= 0.05
	elif cat == "armor":
		v *= float(ARMOR_PREF[n["class"]].get(it["base"], 0.3))
	return v


## Equips anything in the bag that beats what is worn.
static func _auto_equip(n: Dictionary) -> bool:
	var changed := false
	for i in range(n["inv"].size() - 1, -1, -1):
		var it: Dictionary = n["inv"][i]
		if not Items.is_gear(it) or int(it.get("ilvl", 1)) > int(n["level"]) + 5:
			continue
		var cat := Items.category(it)
		var slots := [cat] if cat in ["weapon", "armor", "necklace"] else [cat + "1", cat + "2"]
		var worst := ""
		var ws := INF
		for sl in slots:
			var sc := gear_score(n, n["equip"][sl])
			if sc < ws:
				ws = sc
				worst = sl
		if gear_score(n, it) > ws * 1.05:
			var old: Dictionary = n["equip"][worst]
			n["equip"][worst] = it
			n["inv"].remove_at(i)
			if not old.is_empty():
				n["inv"].append(old)
			changed = true
	if changed:
		var a = actor_of(n)
		if a:
			a.on_npc_gear_changed()
	return changed


# =================================================================== geography
static func town_spot(seed_v: int) -> Vector2:
	var spots := town_spots()
	return spots[absi(seed_v) % spots.size()]


static func town_spots() -> Array:
	var out := []
	for b in Overworld.BUILDINGS:
		if b[4] != "":
			out.append(Vector2(int(b[1]) * T + 8, (int(b[2]) + 1) * T + 34))
	for p in [Vector2(250, 258), Vector2(262, 254), Vector2(256, 264), Vector2(246, 252), Vector2(266, 260), Vector2(256, 248)]:
		out.append(p * T)
	return out


static func guild_door() -> Vector2:
	return Vector2(242 * T + 8, 244 * T + 34)


static func in_town_px(p: Vector2) -> bool:
	return gen().in_town(int(floor(p.x / T)), int(floor(p.y / T)))


## Next point to walk to on the way from `from` to `to`, going through a gate when crossing the wall.
static func route_point(from: Vector2, to: Vector2) -> Vector2:
	var fin := in_town_px(from)
	var tin := in_town_px(to)
	if fin == tin:
		return to
	var outside := to if fin else from
	var best: Array = GATES[0]
	var bd := INF
	for g in GATES:
		var d: float = (g[1] * T).distance_to(outside)
		if d < bd:
			bd = d
			best = g
	var inner: Vector2 = best[0] * T + Vector2(8, 8)
	var outer: Vector2 = best[1] * T + Vector2(8, 8)
	# inside the gate corridor (on the line between the inner and outer gate points) just keep going;
	# anywhere else first walk to the near end of the corridor
	var axis := (outer - inner).normalized()
	var rel := from - inner
	var along := rel.dot(axis)
	var in_corridor := absf(rel.cross(axis)) < 14.0 and along > -14.0 and along < inner.distance_to(outer) + 14.0
	if fin:
		return outer if in_corridor else inner
	return inner if in_corridor else outer


static func level_for_hunt(n: Dictionary) -> int:
	var lv := int(n["level"])
	var b := float(n.get("bravery", 0.5))
	var off := int(round(lerpf(-2.0, 2.5, b)))
	# chase quest targets if the monster lives a bit further out
	for q in n["quests"]:
		if q["type"] == "hunt" and GameData.MONSTERS.has(q["target"]):
			var ml := int(GameData.MONSTERS[q["target"]]["min_lv"])
			if ml > lv + off and ml <= lv + 3:
				return ml
	return clampi(lv + off, 1, 100)


## A walkable point in the wild whose monster level is about `lv`.
static func hunt_point(lv: int) -> Vector2:
	var g := gen()
	var f := pow(clampf(float(lv - 1) / 99.0, 0.0, 1.0), 1.0 / 1.6)
	var dist := 26.0 + f * 214.0 + 3.0
	for attempt in 24:
		var ang := _rng.randf() * TAU
		var dd := dist + _rng.randf_range(-4.0, 6.0)
		var tx := int(256 + cos(ang) * dd)
		var ty := int(256 + sin(ang) * dd)
		if tx < 4 or ty < 4 or tx > 507 or ty > 507:
			continue
		if g.in_town(tx, ty, 4) or g.is_blocked(g.terrain_at(tx, ty)):
			continue
		return Vector2(tx * T + 8, ty * T + 8)
	return Vector2(256 * T, (256 + int(dist)) * T)


# =================================================================== ticking
static func tick(delta: float) -> void:
	if not Game.world.has("npcs"):
		return
	_acc += delta
	_news_t -= delta
	if _acc < 1.0:
		return
	var dt := _acc
	_acc = 0.0
	for n in npcs().duplicate():
		_tick_npc(n, dt)
	Social.tick()
	_grow_acc += dt
	if _grow_acc >= 30.0:
		_grow_acc = 0.0
		_grow()
	_board_acc += dt
	if _board_acc >= 120.0:
		_board_acc = 0.0
		_top_up_board()


static func _tick_npc(n: Dictionary, dt: float) -> void:
	n["state_t"] = float(n["state_t"]) - dt
	var phys: bool = n.get("physical", false)
	match n["state"]:
		"town":
			if not n.get("visited", false):
				_town_visit(n)
			if float(n["state_t"]) <= 0.0:
				_choose_activity(n)
		"travel":
			if not phys and _move(n, dt):
				arrive(n)
		"hunt":
			if not phys:
				_sim_hunt(n, dt)
			_check_return(n)
		"return":
			if not phys and _move(n, dt):
				arrive(n)
		"dungeon":
			if float(n["state_t"]) <= 0.0:
				_finish_listing_run(n)
		"dead":
			if float(n["state_t"]) <= 0.0:
				var spot := town_spot(_rng.randi())
				n["pos"] = [spot.x, spot.y]
				n["hp_frac"] = 0.5
				_enter_town(n)
		"party":
			_party_upkeep(n)
		"follow":
			_tick_follower(n, dt, phys)
		"duel":
			if not Duel.active or Duel.npc != n:
				n["state"] = n.get("state_before_duel", "town")
				if n["state"] == "duel":
					_enter_town(n)


## A member of the hero's party: while you are in town with it, it rests, hands in quests and restocks.
static func _party_upkeep(n: Dictionary) -> void:
	if not Social.in_party(n):
		_enter_town(n)
		return
	var a = actor_of(n)
	var now := float(Game.world.get("total", 0.0))
	if a and Game.level_node is Overworld and in_town_px(a.global_position) and now >= float(n.get("upkeep_t", 0.0)):
		n["upkeep_t"] = now + 120.0
		var keep_state: String = n["state"]
		_town_visit(n)
		n["state"] = keep_state
		a.hp = maxf(a.hp, a.max_hp * 0.8)


## A member of an adventurer party: goes wherever its leader goes. The party breaks up when the leader
## is back in town (or falls).
static func _tick_follower(n: Dictionary, dt: float, phys: bool) -> void:
	var lead := Social.npc_party_leader(n)
	if lead.is_empty() or lead == n or not int(n["id"]) in lead.get("sim_party", []) or lead["state"] in ["town", "dead"]:
		n.erase("sim_party")
		_enter_town(n)
		return
	if not phys:
		var off := Vector2.from_angle(float(int(n["id"]) % 7)) * 18.0
		n["pos"] = [float(lead["pos"][0]) + off.x, float(lead["pos"][1]) + off.y]
		var st := stats_of(n)
		n["hp_frac"] = minf(1.0, float(n["hp_frac"]) + float(st["hp_regen"]) * dt / maxf(1.0, float(st["max_hp"])))


## Simulated walking. Returns true on arrival.
static func _move(n: Dictionary, dt: float) -> bool:
	var pos := Vector2(n["pos"][0], n["pos"][1])
	var dest := Vector2(n["dest"][0], n["dest"][1])
	var spd := 82.0 * (1.0 + 0.002 * int(n["level"]))
	var budget := spd * dt
	for i in 3:
		var wp := route_point(pos, dest)
		var d := pos.distance_to(wp)
		if d <= budget:
			pos = wp
			budget -= d
			if wp == dest:
				n["pos"] = [pos.x, pos.y]
				return true
		else:
			pos += (wp - pos).normalized() * budget
			break
	n["pos"] = [pos.x, pos.y]
	return false


## Called when a walk ends (simulated, or by the physical actor).
static func arrive(n: Dictionary) -> void:
	match n["state"]:
		"travel":
			n["state"] = "hunt"
			n["state_t"] = _rng.randf_range(150.0, 320.0)
			n["kill_t"] = _rng.randf_range(2.0, 6.0)
		"return":
			_enter_town(n)


static func _enter_town(n: Dictionary) -> void:
	n["state"] = "town"
	n["state_t"] = _rng.randf_range(20.0, 50.0)
	n["visited"] = false
	if Social.is_npc_leader(n):
		Social.disband_npc_party(n)


static func _choose_activity(n: Dictionary) -> void:
	if not Social.in_npc_party(n) and _rng.randf() < 0.22:
		Social.try_form_npc_party(n, _rng)
	var want_dungeon := false
	for q in n["quests"]:
		if q["type"] == "dungeon" and not Quests.is_complete(q):
			want_dungeon = true
	if int(n["level"]) >= 5 and _rng.randf() < (0.65 if want_dungeon else 0.28):
		var l := _pick_listing(n)
		if not l.is_empty():
			_start_listing_run(n, l)
			return
	n["hunt_lv"] = level_for_hunt(n)
	var p := hunt_point(int(n["hunt_lv"]))
	n["dest"] = [p.x, p.y]
	n["state"] = "travel"
	n["state_t"] = 600.0


static func _go_home(n: Dictionary) -> void:
	var spot := town_spot(_rng.randi())
	n["dest"] = [spot.x, spot.y]
	n["state"] = "return"
	n["state_t"] = 600.0


static func _check_return(n: Dictionary) -> void:
	if n["state"] != "hunt":
		return
	var hp := _hp_frac(n)
	var potions := count(n, "pot_hp_s") + count(n, "pot_hp_m") + count(n, "pot_hp_l")
	var quests_done: bool = not n["quests"].is_empty()
	for q in n["quests"]:
		if not Quests.is_complete(q):
			quests_done = false
	if float(n["state_t"]) <= 0.0 or bag_free(n) <= 1 or (hp < 0.35 and potions == 0) or quests_done:
		_go_home(n)


static func _hp_frac(n: Dictionary) -> float:
	var a = actor_of(n)
	if a:
		return a.hp / maxf(1.0, a.max_hp)
	return float(n["hp_frac"])


# =================================================================== simulated hunting
static func _pick_monster(n: Dictionary, lv: int) -> String:
	var p := Vector2(n["pos"][0], n["pos"][1])
	var g := gen()
	var biome := g.biome_at(int(p.x / T), int(p.y / T))
	var pool := []
	for m in GameData.BIOMES[biome]["monsters"]:
		var md: Dictionary = GameData.MONSTERS[m]
		if int(md["min_lv"]) <= lv + 2 and not md.get("passive", false):
			pool.append(m)
	if pool.is_empty():
		return "slime"
	return pool[_rng.randi() % pool.size()]


## Estimated fight against one monster using the real damage formula. Returns [time_to_kill, damage_taken].
static func fight_estimate(n: Dictionary, st: Dictionary, mtype: String, lv: int) -> Array:
	var md: Dictionary = GameData.MONSTERS[mtype]
	var magic: bool = n["class"] in ["mage", "priest"]
	var atk := float(st["matk"] if magic else st["patk"])
	var mdef := GameData.mon_def(lv) * float(md["mdef"] if magic else md["def"])
	var per_hit := atk * atk / maxf(1.0, atk + mdef)
	per_hit *= 1.0 + float(st["crit"]) / 100.0 * (float(st["crit_dmg"]) / 100.0 - 1.0)
	per_hit *= 1.15 * 1.4  # class weapon + skills
	var hits := float(st["aspd"]) / 0.6
	var ttk := clampf(GameData.mon_hp(lv) * float(md["hp"]) / maxf(1.0, per_hit * hits), 0.6, 90.0)
	var raw := GameData.mon_atk(lv) * float(md["atk"])
	var taken := raw * raw / maxf(1.0, raw + float(st["pdef"]))
	var ranged: bool = n["class"] in ["ranger", "mage", "priest"]
	var dps := taken * 0.85 * (0.65 if ranged else 1.0) * (1.0 - float(st.get("dodge", 0.0)) / 100.0) * (1.0 - float(st.get("block", 0.0)) / 140.0)
	return [ttk, maxf(0.0, dps * ttk - float(st["hp_regen"]) * ttk)]


static var dbg_fights := 0
static var dbg_dmg := 0.0
static var dbg_max := 0.0


static func _sim_hunt(n: Dictionary, dt: float) -> void:
	var st := stats_of(n)
	n["hp_frac"] = minf(1.0, float(n["hp_frac"]) + float(st["hp_regen"]) * dt / maxf(1.0, float(st["max_hp"])))
	n["kill_t"] = float(n["kill_t"]) - dt
	if float(n["kill_t"]) > 0.0:
		return
	var lv := clampi(int(n["hunt_lv"]) + _rng.randi_range(-2, 2), 1, 100)
	var mt := _pick_monster(n, lv)
	var est := fight_estimate(n, st, mt, lv)
	var group := Social.npc_party_members(n).size() if Social.is_npc_leader(n) else 1
	if group > 1:
		est = [float(est[0]) / (1.0 + 0.8 * (group - 1)), float(est[1]) / (1.0 + 0.9 * (group - 1))]
	var tier := "elite" if _rng.randf() < 0.04 else "normal"
	var risk := 2.5 if tier == "elite" else 1.0
	# Real fights are messier than one-on-one duels: monsters arrive in packs, approach while you are
	# busy and chain attacks. Braver adventurers pull more at once — faster loot, more danger.
	var pack := tier == "normal" and _rng.randf() < 0.08 + 0.12 * float(n.get("bravery", 0.5))
	if pack:
		risk = 2.4
	n["kill_t"] = float(est[0]) * (2.5 if tier == "elite" else (1.8 if pack else 1.0)) + _rng.randf_range(3.0, 7.0)
	# A plain fight never costs more than a third of the bar, so a healthy adventurer only falls to a
	# pack or an elite caught at the wrong moment (they drink at 40% and go home when out of potions).
	var cap := 0.33 if risk <= 1.0 else (0.6 if pack else 0.8)
	var loss := minf(float(est[1]) * 1.6 * risk * _rng.randf_range(0.5, 1.6) / maxf(1.0, float(st["max_hp"])), cap)
	dbg_fights += 1
	dbg_dmg += loss
	dbg_max = maxf(dbg_max, loss)
	n["hp_frac"] = float(n["hp_frac"]) - loss
	if float(n["hp_frac"]) < 0.4:
		var pt := drink(n)
		if not pt.is_empty():
			n["hp_frac"] = minf(1.0, float(n["hp_frac"]) + float(pt.get("heal_pct", 0)) / 100.0 + float(pt.get("heal_flat", 0)) / maxf(1.0, float(st["max_hp"])))
	if float(n["hp_frac"]) <= 0.0:
		_die(n)
		return
	for k in (2 if pack else 1):
		_reward_kill(n, mt, lv, tier, GameData.mon_xp(lv) * float(GameData.MONSTERS[mt]["xp"]) * (4.0 if tier == "elite" else 1.0),
			(2.0 + lv * 1.2) * float(GameData.MONSTERS[mt].get("gold", 1.0)) * (3.0 if tier == "elite" else 1.0), st)


## Rewards for a kill (simulated, or a real monster killed by the physical actor).
static func _reward_kill(n: Dictionary, mt: String, lv: int, tier: String, xp: float, gold_v: float, st: Dictionary) -> void:
	var diff := int(n["level"]) - lv
	var mult := 1.0
	if diff >= 10:
		mult = maxf(0.1, 1.0 - (diff - 9) * 0.08)
	elif diff < 0:
		mult = minf(1.6, 1.0 - diff * 0.04)
	var drop := float(st.get("drop", 100.0)) / 100.0
	n["gold"] = int(n["gold"]) + int(gold_v * _rng.randf_range(0.6, 1.4) * float(st.get("gold_find", 100.0)) / 100.0)
	n["kills"] = int(n["kills"]) + 1
	var md: Dictionary = GameData.MONSTERS[mt]
	for d in md.get("drops", []):
		if _rng.randf() < float(d[1]) * drop * (1.5 if tier != "normal" else 1.0):
			add_item(n, Items.stack(d[0], _rng.randi_range(int(d[2]), int(d[3]))))
	var gear_ch := (0.4 if tier == "elite" else 0.05) * float(md.get("gear", 1.0)) * drop
	if _rng.randf() < gear_ch:
		add_item(n, Items.random_gear(lv, Items.roll_rarity(drop * (2.0 if tier != "normal" else 1.0), 1 if tier != "normal" else 0, 0.0, _rng), 1.0, _rng))
		_auto_equip(n)
	quest_kill(n, mt, tier, false)
	if Social.in_npc_party(n):
		Social.share_npc_xp(n, xp * mult)
	else:
		gain_xp(n, xp * mult)


## Counts a kill for the adventurer's guild quests (and its kill tally).
static func quest_kill(n: Dictionary, mt: String, tier: String, tally: bool = true) -> void:
	if Game.test_run:
		return
	if tally:
		n["kills"] = int(n["kills"]) + 1
	for q in n["quests"]:
		if q["type"] == "hunt" and q["target"] == mt:
			q["have"] = int(q["have"]) + 1
		elif q["type"] == "elite" and tier != "normal":
			q["have"] = int(q["have"]) + 1


## A real monster killed by the physical Adventurer actor.
static func on_actor_kill(n: Dictionary, m: Monster) -> void:
	var a = actor_of(n)
	var st: Dictionary = a.st if a else stats_of(n)
	_reward_kill(n, m.mtype, m.level, m.tier, m.xp_value, m.gold_value, st)
	if m.tier in ["mini", "boss"]:
		add_item(n, Items.stack("monster_core", 1))


static func _die(n: Dictionary) -> void:
	if Social.is_npc_leader(n):
		Social.disband_npc_party(n)
	elif Social.in_npc_party(n):
		for m in Social.npc_party_members(n):
			if m != n:
				m["sim_party"].erase(int(n["id"]))
		n.erase("sim_party")
	n["deaths"] = int(n["deaths"]) + 1
	var lost := int(int(n["gold"]) * 0.1)
	n["gold"] = int(n["gold"]) - lost
	n["state"] = "dead"
	n["state_t"] = 25.0
	n["hp_frac"] = 0.0
	n["kill_streak"] = 0


## The physical actor died.
static func on_actor_died(n: Dictionary) -> void:
	_die(n)


# =================================================================== town life
static func _town_visit(n: Dictionary) -> void:
	n["visited"] = true
	n["hp_frac"] = 1.0
	n["mp_frac"] = 1.0
	# quests
	for i in range(n["quests"].size() - 1, -1, -1):
		var q: Dictionary = n["quests"][i]
		if Quests.is_complete_for(q, n):
			if q["type"] == "gather":
				remove(n, q["target"], int(q["need"]))
			n["gold"] = int(n["gold"]) + int(q["gold"])
			n["guild_points"] = int(n["guild_points"]) + int(q["gp"])
			n["quests_done"] = int(n.get("quests_done", 0)) + 1
			if q.has("item_rarity"):
				add_item(n, Items.random_gear(int(n["level"]), Items.roll_rarity(1.5, int(q["item_rarity"]), 0.0, _rng), 1.0, _rng))
			n["quests"].remove_at(i)
			gain_xp(n, float(q["xp"]))
	_auto_equip(n)
	_sell_loot(n)
	_buy_upgrades(n)
	_restock_potions(n, false)
	_enchant_gear(n)
	_spend_points(n)
	if _rng.randf() < 0.14:
		_make_listing(n)
	_take_quests(n)
	if _rng.randf() < 0.05 and not n.get("physical", false):
		for m in npcs():
			if m != n and m["state"] == "town" and not m.get("physical", false) and not Social.in_party(m) and absi(int(m["level"]) - int(n["level"])) <= 8:
				Duel.sim_duel(n, m, _rng)
				break


static func _sell_loot(n: Dictionary) -> void:
	var keep := {}
	for q in n["quests"]:
		if q["type"] == "gather":
			keep[q["target"]] = true
	for i in range(n["inv"].size() - 1, -1, -1):
		var it: Dictionary = n["inv"][i]
		if Items.is_gear(it):
			n["gold"] = int(n["gold"]) + Items.sell_price(it)
			n["inv"].remove_at(i)
			continue
		var t := GameData.item_template(it.get("id", ""))
		if t.get("type", "") == "material" and not keep.has(it["id"]):
			n["gold"] = int(n["gold"]) + Items.sell_price(it) * int(it.get("qty", 1))
			n["inv"].remove_at(i)


static func _buy_upgrades(n: Dictionary) -> void:
	var lv := int(n["level"])
	var slots := [["weapon", GameData.CLASSES[n["class"]]["weapon"]], ["armor", ARMOR[n["class"]]]]
	for a in ACC_SLOTS:
		if lv >= int(a[2]):
			slots.append([a[0], a[1]])
	slots.shuffle()
	# wealthier adventurers shop for better rarities
	var gold := int(n["gold"])
	var want_r := 0 if lv < 8 else (1 if gold < 4000 else (2 if gold < 20000 else 3))
	for s in slots:
		var cur: Dictionary = n["equip"][s[0]]
		var cur_ok: bool = not cur.is_empty() and int(cur.get("ilvl", 1)) >= lv - 5 and int(cur.get("rarity", 0)) >= want_r
		if cur_ok and gear_score(n, cur) >= gear_score(n, Items.gen_gear(s[1], lv, want_r, _rng)) * 0.9:
			continue
		var rar := want_r if _rng.randf() < 0.7 else maxi(0, want_r - 1)
		var it := Items.gen_gear(s[1], lv, rar, _rng)
		var price := Items.buy_price(it)
		if int(n["gold"]) < price + 150:
			continue
		if gear_score(n, it) > gear_score(n, cur):
			n["gold"] = int(n["gold"]) - price
			n["equip"][s[0]] = it
			if not cur.is_empty():
				n["gold"] = int(n["gold"]) + Items.sell_price(cur)
	var a2 = actor_of(n)
	if a2:
		a2.on_npc_gear_changed()


## Surplus gold goes to the Blacksmith: weapon first, then armour, then jewellery, at the same rates
## and costs as for the hero (Enchant Stones bought at the Magic Shop). Careful adventurers stop at +7,
## where failures start to drop the item a level; rich and brave ones push further.
static func _enchant_gear(n: Dictionary) -> void:
	var reserve := 600 + int(n["level"]) * 60
	var limit := 7 if float(n.get("bravery", 0.5)) < 0.6 else 10
	var changed := false
	for attempt in 3:
		var best := ""
		for sl in ["weapon", "armor", "necklace", "ring1", "ring2", "bracelet1", "bracelet2"]:
			var it: Dictionary = n["equip"][sl]
			if it.is_empty() or int(it.get("enchant", 0)) >= limit:
				continue
			if best == "" or int(it.get("enchant", 0)) < int(n["equip"][best].get("enchant", 0)) - (1 if best == "weapon" else 0):
				best = sl
		if best == "":
			break
		var item: Dictionary = n["equip"][best]
		var cost := Items.enchant_cost(item)
		var price := int(cost["gold"]) + int(cost["stones"]) * 400
		if int(n["gold"]) - price < reserve:
			break
		n["gold"] = int(n["gold"]) - price
		var e := int(item.get("enchant", 0))
		if _rng.randi() % 100 < Items.enchant_rate(item):
			item["enchant"] = e + 1
			changed = true
			if e + 1 >= 7:
				log_event("%s enchanted their %s." % [n["name"], Items.name_of(item)])
		elif e >= 7:
			item["enchant"] = e - 1
			changed = true
	if changed:
		var a = actor_of(n)
		if a:
			a.on_npc_gear_changed()


static func _restock_potions(n: Dictionary, free: bool) -> void:
	var ids := _potion_ids(n)
	var magic: bool = n["class"] in ["mage", "priest"]
	var want := {ids[0]: 6, ids[1]: 5 if magic else 2}
	for id in want:
		var have := count(n, id)
		var need: int = int(want[id]) - have
		if need <= 0:
			continue
		var price := int(GameData.item_template(id).get("price", 20))
		if not free:
			need = mini(need, int(n["gold"]) / maxi(1, price))
			n["gold"] = int(n["gold"]) - need * price
		if need > 0:
			add_item(n, Items.stack(id, need))


static func _take_quests(n: Dictionary) -> void:
	var board: Array = Game.world.get("board", [])
	if n["quests"].size() >= 2 or board.is_empty() or _rng.randf() > 0.45:
		return
	for i in board.size():
		var q: Dictionary = board[i]
		var ok := false
		match q["type"]:
			"hunt":
				ok = GameData.MONSTERS.has(q["target"]) and int(GameData.MONSTERS[q["target"]]["min_lv"]) <= int(n["level"]) + 3
			"dungeon":
				ok = int(q.get("min_rank", 1)) <= int(n["level"]) + 2
			"elite":
				ok = int(n["level"]) >= 4
			"gather":
				ok = true
		if ok:
			board.remove_at(i)
			n["quests"].append(q)
			Game.quests_changed.emit()
			log_event("%s took the quest \"%s\"." % [n["name"], q["title"]])
			return


static func _top_up_board() -> void:
	var board: Array = Game.world.get("board", [])
	if board.size() >= 6 or Game.player.is_empty():
		return
	board.append(Quests.generate(int(Game.player["level"]), int(Game.player["guild_points"]), _rng))
	Game.quests_changed.emit()


# =================================================================== guild Dungeon Hall
static func listings() -> Array:
	return Game.world.get("guild_listings", [])


static func hero_listing_cap() -> int:
	var r := ["F", "E", "D", "C", "B", "A", "S"].find(GameData.guild_rank(int(Game.player.get("guild_points", 0))))
	return LISTING_CAPS[clampi(r, 0, LISTING_CAPS.size() - 1)]


static func hero_listings() -> Array:
	return listings().filter(func(l): return int(l["owner"]) == -1)


static func listing(id: int) -> Dictionary:
	for l in listings():
		if int(l["id"]) == id:
			return l
	return {}


## Lists a Dungeon Crystal from the hero's bag. Returns "" on success or the reason.
static func list_crystal(inv_index: int, gold_pct: int = 10, item_pct: int = 10) -> String:
	if hero_listings().size() >= hero_listing_cap():
		return "All %d listing slots are used. Raise your guild rank for more (up to 10)." % hero_listing_cap()
	var it = Game.player["inv"][inv_index]
	if not (it is Dictionary) or it.get("id", "") != "dungeon_crystal" or it.get("design", {}).is_empty():
		return "That is not a Dungeon Crystal."
	var d: Dictionary = it["design"]
	var id := int(Game.world["listing_next_id"])
	Game.world["listing_next_id"] = id + 1
	Game.world["guild_listings"].append({"id": id, "owner": -1, "owner_name": Game.player["name"], "name": d.get("name", "Dungeon"),
		"rank": int(d.get("rank", 1)), "biome": d.get("biome", "cave"), "design": d.duplicate(true),
		"gold_pct": clampi(gold_pct, 0, MAX_GOLD_SHARE), "item_pct": clampi(item_pct, 0, MAX_ITEM_SHARE),
		"plays": 0, "clears": 0, "fails": 0, "earned_gold": 0, "earned_items": 0, "day": int(Game.world["day"])})
	Game.remove_at(inv_index)
	log_event("%s listed the dungeon \"%s\" (rank %d)." % [Game.player["name"], d.get("name", "Dungeon"), int(d.get("rank", 1))])
	return ""


static func withdraw(id: int) -> bool:
	var l := listing(id)
	if l.is_empty() or int(l["owner"]) != -1:
		return false
	var it := Items.stack("dungeon_crystal", 1)
	it["design"] = l["design"].duplicate(true)
	if not Game.add_item(it):
		Game.toast("Your bag is full.", Color("ff7a7a"))
		return false
	Game.world["guild_listings"].erase(l)
	return true


static func set_shares(id: int, gold_pct: int, item_pct: int) -> void:
	var l := listing(id)
	if l.is_empty():
		return
	l["gold_pct"] = clampi(gold_pct, 0, MAX_GOLD_SHARE)
	l["item_pct"] = clampi(item_pct, 0, MAX_ITEM_SHARE)


## Royalty gold is capped per run so a share can never take more than a reasonable amount.
static func royalty_cap(rank: int) -> int:
	return 60 + rank * 30


# ------------------------------------------------------------------ dungeon profiles
## What a design contains, scored for danger (what kills runners) and loot (what they bring home).
static func design_scores(d: Dictionary) -> Dictionary:
	var rooms: Dictionary = d.get("rooms", {})
	var mons := 0
	var minis := 0
	var traps := 0
	var spawners := 0
	var chest := 0.0
	for c in rooms:
		var r: Dictionary = rooms[c]
		for m in r.get("monsters", []):
			mons += int(m.get("count", 1))
		if str(r.get("miniboss", "")) != "":
			minis += 1
		traps += r.get("traps", []).size()
		spawners += r.get("spawners", []).size()
		for t in r.get("treasures", []):
			chest += 1.0 + float(GameData.WorldData.TREASURES.get(t.get("type", "chest"), {"tier": 0}).get("tier", 0))
	return {"rooms": rooms.size(), "mons": mons, "minis": minis, "traps": traps, "spawners": spawners, "chest": chest,
		"danger": mons + minis * 6.0 + traps * 1.5 + spawners * 3.0 + rooms.size() * 0.5,
		"loot": chest * 3.0 + minis * 3.0 + mons * 0.5, "gold": mons + minis * 4.0}


static var _baseline_cache: Dictionary = {}


## Average scores of standard random dungeons of that rank (what NPCs list and what hidden dungeons are).
static func baseline_scores(rank: int) -> Dictionary:
	var b := clampi(rank / 5 * 5, 1, 100)
	if _baseline_cache.has(b):
		return _baseline_cache[b]
	var acc := {}
	for s in 4:
		var sc := design_scores(DungeonGen.random_design(b, "cave", 7001 + s))
		for k in sc:
			acc[k] = float(acc.get(k, 0.0)) + float(sc[k]) / 4.0
	_baseline_cache[b] = acc
	return acc


## Danger / loot / gold multipliers of a listing relative to a standard dungeon of its rank (1.0 = standard).
static func listing_profile(l: Dictionary) -> Dictionary:
	if l.has("prof"):
		return l["prof"]
	var base := baseline_scores(int(l.get("rank", 1)))
	var p := {"danger": 1.0, "loot": 1.0, "gold": 1.0, "rooms": int(round(float(base.get("rooms", 8.0))))}
	if l.has("design") and not l["design"].is_empty():
		var s := design_scores(l["design"])
		# Danger is judged per room (how hard each fight is), with the dungeon's length counting for a
		# quarter. Loot and gold blend the whole haul with how packed each room is.
		var rs := maxf(1.0, float(s["rooms"]) - 1.0)
		var rb := maxf(1.0, float(base["rooms"]) - 1.0)
		var length := float(s["rooms"]) / maxf(1.0, float(base["rooms"]))
		var dens := (float(s["danger"]) / rs) / maxf(0.1, float(base["danger"]) / rb)
		var ratio := func(key: String) -> float:
			var tot := float(s[key]) / maxf(1.0, float(base[key]))
			var per := (float(s[key]) / rs) / maxf(0.1, float(base[key]) / rb)
			return 0.5 * tot + 0.5 * per
		p = {"danger": snappedf(clampf(dens * (0.75 + 0.25 * length), 0.3, 3.0), 0.01),
			"loot": snappedf(clampf(ratio.call("loot"), 0.2, 3.0), 0.01),
			"gold": snappedf(clampf(ratio.call("gold"), 0.3, 3.0), 0.01), "rooms": int(s["rooms"])}
	l["prof"] = p
	return p


static func danger_word(x: float) -> String:
	return "Easy" if x < 0.75 else ("Normal" if x < 1.2 else ("Hard" if x < 1.6 else "Deadly"))


static func loot_word(x: float) -> String:
	return "Poor" if x < 0.7 else ("Normal" if x < 1.3 else ("Rich" if x < 2.0 else "Lavish"))


## Chance that this adventurer clears the listing (level + gear against rank, adjusted by the design's danger).
static func clear_chance(n: Dictionary, l: Dictionary) -> float:
	var rank := int(l["rank"])
	var gear := 0.0
	for k in n["equip"]:
		var it: Dictionary = n["equip"][k]
		if not it.is_empty():
			gear += float(it.get("ilvl", 1)) * (1.0 + 0.12 * float(it.get("rarity", 0)))
	var eff := float(n["level"]) * 0.7 + gear / 7.0 * 0.3
	var danger := float(listing_profile(l)["danger"])
	return clampf(0.55 + (eff / maxf(1.0, rank) - 1.0) * 1.3 - (danger - 1.0) * 0.35, 0.05, 0.96)


static func collect_payout() -> Array:
	var p: Dictionary = Game.world["guild_payout"]
	var got := [int(p["gold"]), 0]
	if int(p["gold"]) > 0:
		Game.add_gold(int(p["gold"]))
		p["gold"] = 0
	var left := []
	for it in p["items"]:
		if Game.add_item(it):
			got[1] += 1
		else:
			left.append(it)
	p["items"] = left
	return got


static func _make_listing(n: Dictionary) -> void:
	if int(n["level"]) < 8:
		return
	var lv := int(n["level"])
	var mine := []
	var oldest: Dictionary = {}
	var all_npc := 0
	var busy := int(Game.guild_run.get("listing", -2))
	for l in listings():
		if int(l["owner"]) != -1:
			all_npc += 1
			if int(l["id"]) == busy:
				continue  # never pull a dungeon out from under the hero
			if int(l["owner"]) == int(n["id"]):
				mine.append(l)
			if oldest.is_empty() or int(l["day"]) < int(oldest["day"]):
				oldest = l
	# An adventurer who has outgrown one of their dungeons takes it down to make room for a new one.
	var stale: Dictionary = {}
	for l in mine:
		if int(l["rank"]) < lv - 12 and (stale.is_empty() or int(l["rank"]) < int(stale["rank"])):
			stale = l
	if mine.size() >= npc_listing_cap(n) and stale.is_empty():
		return
	# When the hall is full, only a dungeon that has been up for 2+ days makes way for a new one.
	if stale.is_empty() and all_npc >= MAX_NPC_LISTINGS and (oldest.is_empty() or int(Game.world["day"]) - int(oldest["day"]) < 2):
		return
	var rank := clampi(lv + _rng.randi_range(-3, 3), 1, 100)
	var cost := 100 + rank * 25
	if int(n["gold"]) < cost + 200:
		return
	n["gold"] = int(n["gold"]) - cost
	if not stale.is_empty():
		_retire_listing(stale)
	elif all_npc >= MAX_NPC_LISTINGS and not oldest.is_empty():
		_retire_listing(oldest)
	var biomes := GameData.DUNGEON_BIOMES.keys()
	var id := int(Game.world["listing_next_id"])
	Game.world["listing_next_id"] = id + 1
	var nm := "%s's %s %s" % [n["name"], DUNGEON_ADJ[_rng.randi() % DUNGEON_ADJ.size()], DUNGEON_NOUN[_rng.randi() % DUNGEON_NOUN.size()]]
	Game.world["guild_listings"].append({"id": id, "owner": int(n["id"]), "owner_name": n["name"], "name": nm, "rank": rank,
		"biome": biomes[_rng.randi() % biomes.size()], "seed": _rng.randi() % 9999999, "gold_pct": _rng.randi_range(5, 20),
		"item_pct": _rng.randi_range(0, 15), "plays": 0, "clears": 0, "fails": 0, "earned_gold": 0, "earned_items": 0,
		"day": int(Game.world["day"])})
	log_event("%s listed the dungeon \"%s\" (rank %d)." % [n["name"], nm, rank])


static func _retire_listing(l: Dictionary) -> void:
	Game.world["guild_listings"].erase(l)
	var pl := int(l.get("plays", 0))
	log_event("%s took down the dungeon \"%s\" (played %d time%s)." % [l.get("owner_name", "?"), l.get("name", "?"), pl, "" if pl == 1 else "s"])


## Same 3..10 slot rule as the hero, by the adventurer's own guild rank.
static func npc_listing_cap(n: Dictionary) -> int:
	var r := ["F", "E", "D", "C", "B", "A", "S"].find(GameData.guild_rank(int(n.get("guild_points", 0))))
	return LISTING_CAPS[clampi(r, 0, LISTING_CAPS.size() - 1)]


## Picks a listed dungeon that suits the NPC's rank; lower shares attract more adventurers.
static func _pick_listing(n: Dictionary) -> Dictionary:
	var lv := int(n["level"])
	var day := int(Game.world["day"])
	var cands := []
	var weights := []
	for l in listings():
		if int(l["owner"]) == int(n["id"]) or int(n["played"].get(str(l["id"]), -1)) == day:
			continue
		var r := int(l["rank"])
		if r > lv + 4 or r < lv - 12:
			continue
		var w := (1.0 - float(l["gold_pct"]) / 45.0) * (1.0 - float(l["item_pct"]) / 40.0) * (1.0 - absf(r - lv) / 20.0)
		# Adventurers like dungeons they can clear and that pay well, and they talk: a dungeon with a
		# bad clear record loses visitors, a rich one gains them. Brave ones mind the danger less.
		var prof := listing_profile(l)
		var ch := clear_chance(n, l)
		w *= pow(ch, 1.6 - float(n.get("bravery", 0.5)) * 0.8) * (0.55 + 0.45 * float(prof["loot"]))
		w *= 0.5 + (float(l["clears"]) + 1.0) / (float(l["plays"]) + 2.0)
		if int(l["owner"]) == -1:
			w *= 1.3  # the hero's dungeons are popular
		cands.append(l)
		weights.append(maxf(0.05, w))
	if cands.is_empty():
		return {}
	var total := 0.0
	for w in weights:
		total += w
	var roll := _rng.randf() * total
	for i in cands.size():
		roll -= weights[i]
		if roll <= 0.0:
			return cands[i]
	return cands[0]


static func _start_listing_run(n: Dictionary, l: Dictionary) -> void:
	n["run"] = {"listing": int(l["id"])}
	n["played"][str(l["id"])] = int(Game.world["day"])
	n["state"] = "dungeon"
	n["state_t"] = 30.0 + float(l["rank"]) * 0.6 + float(listing_profile(l)["rooms"]) * 6.0 + _rng.randf_range(0.0, 40.0)
	var door := guild_door()
	n["pos"] = [door.x, door.y]


static func _finish_listing_run(n: Dictionary) -> void:
	var l := listing(int(n["run"].get("listing", -1)))
	n["run"] = {}
	if l.is_empty():
		_enter_town(n)
		return
	var rank := int(l["rank"])
	var prof := listing_profile(l)
	var chance := clear_chance(n, l)
	var mates := []
	if Social.is_npc_leader(n):
		for m in Social.npc_party_members(n):
			if m != n and m["state"] == "follow":
				mates.append(m)
				chance = maxf(chance, clear_chance(m, l))
		chance = minf(0.97, chance + 0.12 * mates.size())  # more hands, better odds
	l["plays"] = int(l["plays"]) + 1
	var success := _rng.randf() < chance
	for m in mates:
		if success:
			m["dungeons_cleared"] = int(m["dungeons_cleared"]) + 1
			for q in m["quests"]:
				if q["type"] == "dungeon" and rank >= int(q.get("min_rank", 1)):
					q["have"] = int(q["have"]) + 1
			gain_xp(m, GameData.xp_to_next(int(m["level"])) * 0.2 + rank * 10.0)
			if _rng.randf() < 0.6 * float(prof["loot"]):
				add_item(m, Items.random_gear(rank, Items.roll_rarity(1.4, 1, 0.0, _rng), 1.0, _rng))
				_auto_equip(m)
		else:
			gain_xp(m, rank * 5.0)
			if _rng.randf() < clampf(0.25 * float(prof["danger"]), 0.08, 0.6):
				m.erase("sim_party")
				_die(m)
	# More monsters and mini bosses mean more gold dropped; more and better chests mean more items.
	var gold := int((40.0 + rank * 24.0) * (0.4 + 0.6 * float(prof["gold"])) * _rng.randf_range(0.8, 1.3) * (1.0 if success else 0.35))
	var items := []
	if success:
		l["clears"] = int(l["clears"]) + 1
		n["dungeons_cleared"] = int(n["dungeons_cleared"]) + 1
		var n_items := clampi(int(round(_rng.randf_range(1.0, 3.0) * float(prof["loot"]))), 1, 6)
		for i in n_items:
			items.append(Items.random_gear(rank, Items.roll_rarity(1.6, 1, 0.0, _rng), 1.0, _rng))
		if _rng.randf() < 0.25:
			var bt := DungeonGen.pick_boss(l["biome"], rank, _rng)
			items.append(Items.unique_for(bt, rank))
		for q in n["quests"]:
			if q["type"] == "dungeon" and rank >= int(q.get("min_rank", 1)):
				q["have"] = int(q["have"]) + 1
		gain_xp(n, GameData.xp_to_next(int(n["level"])) * 0.25 + rank * 12.0)
	else:
		l["fails"] = int(l["fails"]) + 1
		gain_xp(n, rank * 6.0)
		if _rng.randf() < 0.3 * float(prof["loot"]):
			items.append(Items.random_gear(rank, Items.roll_rarity(1.2, 0, 0.0, _rng), 1.0, _rng))  # grabbed a chest before retreating
		if _rng.randf() < clampf(0.35 * float(prof["danger"]), 0.12, 0.75):
			_die(n)
	# shares for the owner
	var share := mini(int(gold * float(l["gold_pct"]) / 100.0), royalty_cap(rank))
	var owner_items := []
	var kept := []
	for it in items:
		if _rng.randf() * 100.0 < float(l["item_pct"]):
			owner_items.append(it)
		else:
			kept.append(it)
	n["gold"] = int(n["gold"]) + gold - share
	for it in kept:
		add_item(n, it)
	_auto_equip(n)
	pay_owner(l, share, owner_items, n["name"], success)
	if n["state"] != "dead":
		var door := guild_door()
		n["pos"] = [door.x, door.y]
		n["hp_frac"] = 1.0 if success else 0.4
		_enter_town(n)


## Gives a run's share to the listing's owner (the hero's pending payout, or an NPC).
static func pay_owner(l: Dictionary, gold: int, items: Array, who: String, cleared: bool) -> void:
	l["earned_gold"] = int(l["earned_gold"]) + gold
	l["earned_items"] = int(l["earned_items"]) + items.size()
	if int(l["owner"]) == -1:
		var p: Dictionary = Game.world["guild_payout"]
		p["gold"] = int(p["gold"]) + gold
		for it in items:
			p["items"].append(it)
		var txt := "%s %s your dungeon \"%s\" — your share: %d gold%s." % [who, "cleared" if cleared else "failed", l["name"], gold,
			(" + %s" % Items.name_of(items[0]) + (" and %d more" % (items.size() - 1) if items.size() > 1 else "")) if not items.is_empty() else ""]
		news(txt, Color("c79bff"), gold > 0 or not items.is_empty())
	else:
		var o := find(int(l["owner"]))
		if not o.is_empty():
			o["gold"] = int(o["gold"]) + gold
			for it in items:
				add_item(o, it)
		log_event("%s %s \"%s\" (%s earned %d gold)." % [who, "cleared" if cleared else "failed", l["name"], l["owner_name"], gold])


# ------------------------------------------------------------------ the hero playing an NPC's dungeon
static func hero_can_play(l: Dictionary) -> String:
	if int(l["owner"]) == -1:
		return "This is your own dungeon (use Test Run in the Dungeon Architect)."
	if int(Game.player["guild_played"].get(str(l["id"]), -1)) == int(Game.world["day"]):
		return "You already played this dungeon today."
	return ""


static func hero_enter(l: Dictionary) -> bool:
	if hero_can_play(l) != "":
		return false
	Game.player["guild_played"][str(l["id"])] = int(Game.world["day"])
	var design := DungeonGen.random_design(int(l["rank"]), l["biome"], int(l["seed"]))
	design["name"] = l["name"]
	Game.guild_run = {"listing": int(l["id"]), "paid_gold": 0, "paid_items": [], "earned": 0}
	var door := guild_door()
	Game.player["pos"] = [door.x, door.y]
	Game.main.close_all()
	Game.main.enter_dungeon({"id": -1000 - int(l["id"]), "rank": int(l["rank"]), "biome": l["biome"], "custom": true, "design": design,
		"seed": int(l["seed"]), "listing_id": int(l["id"])}, false)
	return true


## Gold picked up while running an NPC's dungeon: returns how much the hero keeps.
static func tribute_gold(amount: int) -> int:
	var r: Dictionary = Game.guild_run
	if r.is_empty():
		return amount
	var l := listing(int(r["listing"]))
	if l.is_empty():
		return amount
	var cut := int(round(amount * float(l["gold_pct"]) / 100.0))
	cut = mini(cut, royalty_cap(int(l["rank"])) - int(r["paid_gold"]))
	cut = maxi(0, cut)
	r["paid_gold"] = int(r["paid_gold"]) + cut
	r["earned"] = int(r["earned"]) + amount
	return amount - cut


## Item picked up while running an NPC's dungeon: true if it goes to the owner instead.
static func tribute_item(it: Dictionary) -> bool:
	var r: Dictionary = Game.guild_run
	if r.is_empty():
		return false
	var l := listing(int(r["listing"]))
	if l.is_empty() or _rng.randf() * 100.0 >= float(l["item_pct"]):
		return false
	r["paid_items"].append(it.duplicate(true))
	return true


static func finish_hero_run(cleared: bool) -> void:
	var r: Dictionary = Game.guild_run
	if r.is_empty():
		return
	Game.guild_run = {}
	var l := listing(int(r["listing"]))
	if l.is_empty():
		# The owner took the dungeon down meanwhile: nobody to pay, so the hero keeps everything.
		Game.add_gold(int(r["paid_gold"]))
		for it in r["paid_items"]:
			Game.give_item(it)
		return
	l["plays"] = int(l["plays"]) + 1
	if cleared:
		l["clears"] = int(l["clears"]) + 1
	else:
		l["fails"] = int(l["fails"]) + 1
	pay_owner(l, int(r["paid_gold"]), r["paid_items"], Game.player["name"], cleared)
	Game.toast("You paid %s their share: %d gold%s." % [l["owner_name"], int(r["paid_gold"]),
		(" and %d item(s)" % r["paid_items"].size()) if not r["paid_items"].is_empty() else ""], Color("c79bff"))


# =================================================================== physical actors
static func actor_of(n: Dictionary):
	if n.is_empty():
		return null
	var a = actors.get(int(n["id"]))
	if a != null and is_instance_valid(a):
		return a
	return null


static func activity(n: Dictionary) -> String:
	match n["state"]:
		"town":
			return "In town"
		"travel":
			return "Heading out to hunt (Lv %d area)" % int(n["hunt_lv"])
		"hunt":
			var p := Vector2(n["pos"][0], n["pos"][1])
			var b := gen().biome_at(int(p.x / T), int(p.y / T))
			return "Hunting in %s (Lv %d)" % [GameData.BIOMES[b].get("name", b.capitalize()), int(n["hunt_lv"])]
		"return":
			return "Returning to town"
		"dungeon":
			var l := listing(int(n["run"].get("listing", -1)))
			return "Exploring \"%s\"" % l.get("name", "a dungeon")
		"dead":
			return "Recovering (defeated)"
		"party":
			return "In your party"
		"duel":
			return "Duelling"
		"follow":
			var lead := Social.npc_party_leader(n)
			if lead.is_empty():
				return "Adventuring with a party"
			return "With %s's party — %s" % [lead["name"], activity(lead).to_lower()] if lead["state"] != "follow" else "With %s's party" % lead["name"]
	return n["state"]


# =================================================================== news
static func log_event(text: String) -> void:
	var lg: Array = Game.world.get("guild_log", [])
	lg.append("Day %d — %s" % [int(Game.world.get("day", 1)), text])
	while lg.size() > 40:
		lg.pop_front()


## Logs an event and shows a toast (NPC chatter is throttled; events about the hero always show).
static func news(text: String, col: Color, important: bool) -> void:
	log_event(text)
	if important or _news_t <= 0.0:
		_news_t = 25.0
		Game.toast(text, col)
