extends Node
## Global game state: player data, inventory, skills, quests, world state, save/load and autosave.

signal player_changed
signal inventory_changed
signal stats_changed
signal skills_changed
signal hotbar_changed
signal quests_changed
signal gold_changed
signal xp_changed
signal leveled_up(level: int)
signal notify(text: String, color: Color)
signal saved(auto: bool)

const ID := preload("res://src/data/data_items.gd")
const SAVE_DIR := "user://saves/"
const SAVE_SLOTS := 3
const DAY_LEN := 1200.0
const AUTOSAVE_INTERVAL := 60.0
const BASE_BAG := 30
const MAX_BAG := 120
const BAG_STEP := 10

var slot := 1
var player: Dictionary = {}
var world: Dictionary = {}
var shops: Dictionary = {}
var designs: Array = []
var next_uid := 1000
var in_game := false
var test_run := false
var playtime := 0.0
var stats: Dictionary = {}
var main: Node = null
var level_node: Node = null
var player_node: Node = null
var _autosave_t := 0.0
var _item_cd := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	get_tree().auto_accept_quit = false
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if _item_cd > 0.0:
		_item_cd -= delta
	if not in_game or test_run:
		return
	playtime += delta
	_autosave_t += delta
	if _autosave_t >= AUTOSAVE_INTERVAL:
		_autosave_t = 0.0
		save_game(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if in_game and not test_run:
			save_game(true)
		get_tree().quit()


func toast(text: String, color: Color = Color.WHITE) -> void:
	notify.emit(text, color)


# =================================================================== new game
func new_game(pname: String, cls: String, save_slot: int) -> void:
	slot = save_slot
	next_uid = 1000
	playtime = 0.0
	test_run = false
	var c: Dictionary = GameData.CLASSES[cls]
	var inv := []
	inv.resize(BASE_BAG)
	player = {
		"name": pname, "class": cls, "level": 1, "xp": 0, "gold": 250,
		"alloc": {"str": 0, "vit": 0, "int": 0, "mnd": 0, "dex": 0, "luk": 0},
		"stat_points": 0, "skill_points": 1, "skills": {}, "tomes": [],
		"equip": {"weapon": {}, "armor": {}, "necklace": {}, "ring1": {}, "ring2": {}, "bracelet1": {}, "bracelet2": {}},
		"inv": inv, "bag_size": BASE_BAG,
		"hot_skills": ["", "", "", ""], "hot_items": ["pot_hp_s", "pot_mp_s", "food_bread", ""],
		"hp": -1.0, "mp": -1.0, "satiety": 100.0, "pos": [], "last_field": [],
		"guild_points": 0, "quests": [], "kills": {}, "dungeons_cleared": 0, "bosses_killed": 0,
		"last_stand_ready": 0.0, "revive_ready": 0.0,
	}
	var r := RandomNumberGenerator.new()
	r.randomize()
	player["equip"]["weapon"] = Items.gen_gear(c["weapon"], 1, 0, r)
	player["equip"]["armor"] = Items.gen_gear(c["start_armor"], 1, 0, r)
	add_item(Items.stack("pot_hp_s", 8))
	add_item(Items.stack("pot_mp_s", 5))
	add_item(Items.stack("food_bread", 5))
	add_item(Items.stack("food_apple", 3))
	world = {"seed": r.randi() % 999999, "time": DAY_LEN * 0.3, "day": 1, "total": 0.0, "harvested": {},
		"explored": {}, "dungeons": [], "next_dungeon": 1, "board": [], "board_day": 0, "visited": {}}
	shops = {"gear": [], "artifact": [], "day": 0}
	if designs.is_empty():
		designs = []
	recalc()
	player["hp"] = stats["max_hp"]
	player["mp"] = stats["max_mp"]


# =================================================================== stats
func recalc() -> void:
	var bm: Array = []
	if is_instance_valid(player_node) and player_node.has_method("buff_mod_list"):
		bm = player_node.buff_mod_list()
	stats = StatCalc.compute(player, bm)
	stats_changed.emit()


func is_specialized_weapon() -> bool:
	var w: String = StatCalc.weapon_type(player)
	var cw: String = GameData.CLASSES[player["class"]]["weapon"]
	if w == cw:
		return true
	return cw in ["wand", "grimoire"] and w in ["wand", "grimoire"]


func add_xp(amount: float) -> void:
	if player.is_empty() or test_run:
		return
	var lv: int = player["level"]
	if lv >= GameData.MAX_LEVEL:
		return
	player["xp"] = int(player["xp"]) + int(amount)
	var leveled := false
	while int(player["level"]) < GameData.MAX_LEVEL and int(player["xp"]) >= GameData.xp_to_next(int(player["level"])):
		player["xp"] = int(player["xp"]) - GameData.xp_to_next(int(player["level"]))
		player["level"] = int(player["level"]) + 1
		player["stat_points"] = int(player["stat_points"]) + GameData.STAT_POINTS_PER_LEVEL
		player["skill_points"] = int(player["skill_points"]) + GameData.SKILL_POINTS_PER_LEVEL
		leveled = true
	if int(player["level"]) >= GameData.MAX_LEVEL:
		player["xp"] = 0
	if leveled:
		recalc()
		player["hp"] = stats["max_hp"]
		player["mp"] = stats["max_mp"]
		if is_instance_valid(player_node):
			player_node.on_level_up()
		leveled_up.emit(int(player["level"]))
		toast("Level Up! You are now level %d" % int(player["level"]), Color("fee761"))
		Sfx.play("levelup")
	xp_changed.emit()


func add_gold(n: int) -> void:
	player["gold"] = max(0, int(player["gold"]) + n)
	gold_changed.emit()


func allocate_stat(st: String, n: int = 1) -> void:
	n = mini(n, int(player["stat_points"]))
	if n <= 0:
		return
	player["alloc"][st] = int(player["alloc"][st]) + n
	player["stat_points"] = int(player["stat_points"]) - n
	recalc()
	player_changed.emit()


# =================================================================== inventory
func inv() -> Array:
	return player["inv"]


func _slot_empty(v) -> bool:
	return v == null or (v is Dictionary and v.is_empty())


func free_slots() -> int:
	var n := 0
	for v in player["inv"]:
		if _slot_empty(v):
			n += 1
	return n


## Adds an item (stack-aware). Returns true if fully added; leftover qty stays in `it`.
func add_item(it: Dictionary, notify_pickup: bool = false) -> bool:
	var inv_a: Array = player["inv"]
	var ms := Items.max_stack(it)
	if ms > 1:
		for i in inv_a.size():
			var s = inv_a[i]
			if not _slot_empty(s) and Items.can_stack(s, it) and int(s["qty"]) < ms:
				var room := ms - int(s["qty"])
				var mv := mini(room, int(it["qty"]))
				s["qty"] = int(s["qty"]) + mv
				it["qty"] = int(it["qty"]) - mv
				if int(it["qty"]) <= 0:
					break
	if not it.has("qty") or int(it.get("qty", 1)) > 0:
		for i in inv_a.size():
			if _slot_empty(inv_a[i]):
				var put := it.duplicate(true)
				if ms > 1 and int(put["qty"]) > ms:
					put["qty"] = ms
					it["qty"] = int(it["qty"]) - ms
					put["uid"] = Items.uid()
					inv_a[i] = put
					continue
				inv_a[i] = put
				it["qty"] = 0
				break
	inventory_changed.emit()
	var done := int(it.get("qty", 0)) <= 0
	if not done and notify_pickup:
		toast("Bag is full!", Color("ff7a7a"))
	return done


## Adds an item; whatever does not fit in the bag is dropped at the player's feet instead of being lost.
func give_item(it: Dictionary) -> void:
	if add_item(it):
		return
	if is_instance_valid(level_node) and is_instance_valid(player_node):
		level_node.drop_item(it, player_node.global_position)
		toast("Bag full — %s was placed at your feet." % Items.name_of(it), Color("ff7a7a"))


func count_item(id: String) -> int:
	var n := 0
	for s in player["inv"]:
		if not _slot_empty(s) and s.get("id", "") == id and not Items.is_gear(s):
			n += int(s.get("qty", 1))
	return n


func remove_item(id: String, qty: int) -> bool:
	if count_item(id) < qty:
		return false
	var inv_a: Array = player["inv"]
	for i in range(inv_a.size() - 1, -1, -1):
		var s = inv_a[i]
		if _slot_empty(s) or s.get("id", "") != id or Items.is_gear(s):
			continue
		var take := mini(qty, int(s["qty"]))
		s["qty"] = int(s["qty"]) - take
		qty -= take
		if int(s["qty"]) <= 0:
			inv_a[i] = null
		if qty <= 0:
			break
	inventory_changed.emit()
	return true


func remove_at(index: int, qty: int = -1) -> Dictionary:
	var inv_a: Array = player["inv"]
	var s = inv_a[index]
	if _slot_empty(s):
		return {}
	if qty < 0 or Items.is_gear(s) or qty >= int(s.get("qty", 1)):
		inv_a[index] = null
		inventory_changed.emit()
		return s
	var part: Dictionary = s.duplicate(true)
	part["qty"] = qty
	part["uid"] = Items.uid()
	s["qty"] = int(s["qty"]) - qty
	inventory_changed.emit()
	return part


func move_slot(from: int, to: int) -> void:
	var inv_a: Array = player["inv"]
	if from == to or from < 0 or to < 0 or from >= inv_a.size() or to >= inv_a.size():
		return
	var a = inv_a[from]
	var b = inv_a[to]
	if not _slot_empty(a) and not _slot_empty(b) and Items.can_stack(a, b):
		var ms := Items.max_stack(b)
		var mv := mini(ms - int(b["qty"]), int(a["qty"]))
		b["qty"] = int(b["qty"]) + mv
		a["qty"] = int(a["qty"]) - mv
		if int(a["qty"]) <= 0:
			inv_a[from] = null
	else:
		inv_a[from] = b
		inv_a[to] = a
	inventory_changed.emit()


func split_slot(index: int, qty: int) -> bool:
	var inv_a: Array = player["inv"]
	var s = inv_a[index]
	if _slot_empty(s) or Items.is_gear(s) or qty <= 0 or qty >= int(s["qty"]):
		return false
	for i in inv_a.size():
		if _slot_empty(inv_a[i]):
			var part: Dictionary = s.duplicate(true)
			part["qty"] = qty
			part["uid"] = Items.uid()
			s["qty"] = int(s["qty"]) - qty
			inv_a[i] = part
			inventory_changed.emit()
			return true
	toast("No free slot to split into", Color("ff7a7a"))
	return false


func stack_all() -> void:
	var inv_a: Array = player["inv"]
	for i in inv_a.size():
		if _slot_empty(inv_a[i]):
			continue
		for j in range(i + 1, inv_a.size()):
			if _slot_empty(inv_a[j]) or _slot_empty(inv_a[i]):
				continue
			if Items.can_stack(inv_a[i], inv_a[j]):
				var ms := Items.max_stack(inv_a[i])
				var mv := mini(ms - int(inv_a[i]["qty"]), int(inv_a[j]["qty"]))
				inv_a[i]["qty"] = int(inv_a[i]["qty"]) + mv
				inv_a[j]["qty"] = int(inv_a[j]["qty"]) - mv
				if int(inv_a[j]["qty"]) <= 0:
					inv_a[j] = null
	inventory_changed.emit()


const SORT_ORDER := {"gear": 0, "consumable": 1, "special": 2, "material": 3}


func sort_inventory(mode: String = "type") -> void:
	stack_all()
	var inv_a: Array = player["inv"]
	var items := []
	for s in inv_a:
		if not _slot_empty(s):
			items.append(s)
	match mode:
		"rarity":
			items.sort_custom(func(a, b):
				var ra := int(a.get("rarity", -1)) if Items.is_gear(a) else -1
				var rb := int(b.get("rarity", -1)) if Items.is_gear(b) else -1
				if ra != rb:
					return ra > rb
				return Items.name_of(a) < Items.name_of(b))
		"name":
			items.sort_custom(func(a, b): return Items.name_of(a) < Items.name_of(b))
		"value":
			items.sort_custom(func(a, b): return Items.sell_price(a) * int(a.get("qty", 1)) > Items.sell_price(b) * int(b.get("qty", 1)))
		_:
			items.sort_custom(func(a, b):
				var ga: int = SORT_ORDER.get(Items.filter_group(a), 9)
				var gb: int = SORT_ORDER.get(Items.filter_group(b), 9)
				if ga != gb:
					return ga < gb
				if Items.is_gear(a) and Items.is_gear(b):
					if a["base"] != b["base"]:
						return str(a["base"]) < str(b["base"])
					return int(a["rarity"]) > int(b["rarity"])
				return Items.name_of(a) < Items.name_of(b))
	for i in inv_a.size():
		inv_a[i] = items[i] if i < items.size() else null
	inventory_changed.emit()


func bag_expand_cost() -> int:
	var steps := (int(player["bag_size"]) - BASE_BAG) / BAG_STEP
	return int(500 * pow(2.0, steps))


func expand_bag() -> bool:
	if int(player["bag_size"]) >= MAX_BAG:
		toast("Your bag is already at maximum size.", Color("ff7a7a"))
		return false
	var cost := bag_expand_cost()
	if int(player["gold"]) < cost:
		toast("Not enough gold (%d needed)" % cost, Color("ff7a7a"))
		return false
	add_gold(-cost)
	player["bag_size"] = int(player["bag_size"]) + BAG_STEP
	player["inv"].resize(int(player["bag_size"]))
	inventory_changed.emit()
	toast("Bag expanded to %d slots" % int(player["bag_size"]), Color("7be05a"))
	Sfx.play("coin")
	return true


# =================================================================== equipment
func slot_for(it: Dictionary) -> String:
	var cat := Items.category(it)
	match cat:
		"weapon":
			return "weapon"
		"armor":
			return "armor"
		"necklace":
			return "necklace"
		"ring":
			if player["equip"]["ring1"].is_empty():
				return "ring1"
			if player["equip"]["ring2"].is_empty():
				return "ring2"
			return "ring1"
		"bracelet":
			if player["equip"]["bracelet1"].is_empty():
				return "bracelet1"
			if player["equip"]["bracelet2"].is_empty():
				return "bracelet2"
			return "bracelet1"
	return ""


func slot_accepts(slot_name: String, it: Dictionary) -> bool:
	if not Items.is_gear(it):
		return false
	var cat := Items.category(it)
	return slot_name == cat or slot_name.begins_with(cat) and (cat == "ring" or cat == "bracelet")


func equip_from_inv(index: int, target_slot: String = "") -> bool:
	var inv_a: Array = player["inv"]
	var it = inv_a[index]
	if _slot_empty(it) or not Items.is_gear(it):
		return false
	var sl := target_slot if target_slot != "" else slot_for(it)
	if sl == "" or not slot_accepts(sl, it):
		return false
	var old: Dictionary = player["equip"][sl]
	player["equip"][sl] = it
	inv_a[index] = null if old.is_empty() else old
	Sfx.play("equip")
	_after_equip_change()
	return true


func unequip(sl: String, to_index: int = -1) -> bool:
	var it: Dictionary = player["equip"].get(sl, {})
	if it.is_empty():
		return false
	var inv_a: Array = player["inv"]
	if to_index >= 0 and to_index < inv_a.size() and _slot_empty(inv_a[to_index]):
		inv_a[to_index] = it
	else:
		var placed := false
		for i in inv_a.size():
			if _slot_empty(inv_a[i]):
				inv_a[i] = it
				placed = true
				break
		if not placed:
			toast("Bag is full!", Color("ff7a7a"))
			return false
	player["equip"][sl] = {}
	_after_equip_change()
	return true


func _after_equip_change() -> void:
	var old_max: float = stats.get("max_hp", 1.0)
	recalc()
	if is_instance_valid(player_node):
		player_node.on_equipment_changed()
	inventory_changed.emit()
	player_changed.emit()


# =================================================================== using items
func use_item(index: int) -> bool:
	var inv_a: Array = player["inv"]
	var it = inv_a[index]
	if _slot_empty(it):
		return false
	if Items.is_gear(it):
		return equip_from_inv(index)
	var t := GameData.item_template(it["id"])
	var req_lv := int(t.get("lv", 0))
	if req_lv > int(player["level"]) and t.get("type", "") != "material":
		toast("Requires level %d" % req_lv, Color("ff7a7a"))
		return false
	match t.get("type", ""):
		"consumable":
			if _item_cd > 0.0:
				return false
			if not is_instance_valid(player_node) or player_node.dead:
				return false
			player_node.consume(t, it["id"])
			_item_cd = 0.6
			remove_at(index, 1)
			hotbar_changed.emit()
			return true
		"special":
			return _use_special(index, it, t)
		"material":
			toast("Materials are used for crafting and quests.", Color("aab4c8"))
	return false


func _use_special(index: int, it: Dictionary, t: Dictionary) -> bool:
	if t.has("teach"):
		var sid: String = t["teach"]
		if sid in player["tomes"]:
			toast("You already know %s" % GameData.SKILLS[sid]["name"], Color("ff7a7a"))
			return false
		player["tomes"].append(sid)
		remove_at(index, 1)
		toast("Learned tome skill: %s! Level it in the Common skill tree." % GameData.SKILLS[sid]["name"], Color("c79bff"))
		Sfx.play("levelup")
		skills_changed.emit()
		return true
	if t.get("respec", "") == "skills":
		var refund := 0
		for s in player["skills"]:
			refund += int(player["skills"][s])
		player["skills"] = {}
		player["skill_points"] = int(player["skill_points"]) + refund
		player["hot_skills"] = ["", "", "", ""]
		remove_at(index, 1)
		recalc()
		toast("Skills reset. %d points refunded." % refund, Color("c79bff"))
		skills_changed.emit()
		hotbar_changed.emit()
		return true
	if t.get("respec", "") == "stats":
		var refund2 := 0
		for s in player["alloc"]:
			refund2 += int(player["alloc"][s])
			player["alloc"][s] = 0
		player["stat_points"] = int(player["stat_points"]) + refund2
		remove_at(index, 1)
		recalc()
		toast("Stats reset. %d points refunded." % refund2, Color("c79bff"))
		player_changed.emit()
		return true
	if it.get("id", "") == "dungeon_crystal":
		if is_instance_valid(level_node) and level_node.has_method("place_custom_dungeon"):
			if level_node.place_custom_dungeon(it.get("design", {})):
				remove_at(index, 1)
				return true
		else:
			toast("Use the crystal out in the wild.", Color("ff7a7a"))
	return false


func use_hot_item(i: int) -> void:
	var id: String = player["hot_items"][i]
	if id == "":
		return
	var inv_a: Array = player["inv"]
	for idx in inv_a.size():
		var s = inv_a[idx]
		if not _slot_empty(s) and s.get("id", "") == id:
			use_item(idx)
			return
	toast("No %s left" % GameData.item_template(id).get("name", id), Color("ff7a7a"))


func set_hot_item(i: int, id: String) -> void:
	for k in 4:
		if player["hot_items"][k] == id:
			player["hot_items"][k] = ""
	player["hot_items"][i] = id
	hotbar_changed.emit()


# =================================================================== skills
func skill_level(id: String) -> int:
	return int(player["skills"].get(id, 0))


func skill_unlock_reason(id: String) -> String:
	var s: Dictionary = GameData.SKILLS[id]
	if s["cls"] != "common" and s["cls"] != player["class"]:
		return "Other class"
	if s.has("tome") and not (id in player["tomes"]):
		return "Read the %s spellbook (Magic Shop)" % GameData.item_template(s["tome"]).get("name", "")
	var rl := GameData.skill_req_level(id)
	if int(player["level"]) < rl:
		return "Requires character level %d" % rl
	for r in s.get("req", {}):
		if skill_level(r) < int(s["req"][r]):
			return "Requires %s Lv %d" % [GameData.SKILLS[r]["name"], int(s["req"][r])]
	return ""


func can_learn(id: String) -> bool:
	if int(player["skill_points"]) <= 0:
		return false
	if skill_level(id) >= int(GameData.SKILLS[id]["max"]):
		return false
	return skill_unlock_reason(id) == ""


func learn_skill(id: String, times: int = 1) -> int:
	var n := 0
	for i in times:
		if not can_learn(id):
			break
		player["skills"][id] = skill_level(id) + 1
		player["skill_points"] = int(player["skill_points"]) - 1
		n += 1
	if n > 0:
		if GameData.SKILLS[id]["type"] == "active" and skill_level(id) == n and not (id in player["hot_skills"]):
			for k in 4:
				if player["hot_skills"][k] == "":
					player["hot_skills"][k] = id
					hotbar_changed.emit()
					break
		recalc()
		skills_changed.emit()
		player_changed.emit()
		Sfx.play("click")
	return n


func set_hot_skill(i: int, id: String) -> void:
	if id != "" and (skill_level(id) <= 0 or GameData.SKILLS[id]["type"] != "active"):
		return
	for k in 4:
		if player["hot_skills"][k] == id:
			player["hot_skills"][k] = ""
	player["hot_skills"][i] = id
	hotbar_changed.emit()


# =================================================================== quests
func on_monster_killed(mtype: String, tier: String) -> void:
	if test_run:
		return
	player["kills"][mtype] = int(player["kills"].get(mtype, 0)) + 1
	var changed := false
	for q in player["quests"]:
		if q["type"] == "hunt" and q["target"] == mtype:
			q["have"] = int(q["have"]) + 1
			changed = true
		elif q["type"] == "elite" and tier in ["elite", "mini", "boss"]:
			q["have"] = int(q["have"]) + 1
			changed = true
	if tier == "boss":
		player["bosses_killed"] = int(player["bosses_killed"]) + 1
	if changed:
		quests_changed.emit()


func on_dungeon_cleared(rank: int) -> void:
	if test_run:
		return
	player["dungeons_cleared"] = int(player["dungeons_cleared"]) + 1
	for q in player["quests"]:
		if q["type"] == "dungeon" and rank >= int(q.get("min_rank", 1)):
			q["have"] = int(q["have"]) + 1
	quests_changed.emit()


func refresh_board(force: bool = false) -> void:
	if not force and int(world.get("board_day", -1)) == int(world["day"]) and not world["board"].is_empty():
		return
	world["board"] = []
	for i in 6:
		world["board"].append(Quests.generate(int(player["level"]), int(player["guild_points"]), rng))
	world["board_day"] = world["day"]
	quests_changed.emit()


func max_active_quests() -> int:
	return 3 + ["F", "E", "D", "C", "B", "A", "S"].find(GameData.guild_rank(int(player["guild_points"]))) / 2


func accept_quest(i: int) -> bool:
	if player["quests"].size() >= max_active_quests():
		toast("Too many active quests (max %d)" % max_active_quests(), Color("ff7a7a"))
		return false
	var q: Dictionary = world["board"][i]
	world["board"].remove_at(i)
	player["quests"].append(q)
	quests_changed.emit()
	Sfx.play("click")
	return true


func abandon_quest(i: int) -> void:
	player["quests"].remove_at(i)
	quests_changed.emit()


func turn_in_quest(i: int) -> bool:
	var q: Dictionary = player["quests"][i]
	if not Quests.is_complete(q):
		return false
	if q["type"] == "gather":
		remove_item(q["target"], int(q["need"]))
	add_gold(int(q["gold"]))
	add_xp(float(q["xp"]))
	player["guild_points"] = int(player["guild_points"]) + int(q["gp"])
	if q.has("item_rarity"):
		var it := Items.random_gear(int(player["level"]), Items.roll_rarity(1.5, int(q["item_rarity"])), 1.0, rng)
		if not add_item(it):
			toast("Bag full — reward item dropped at your feet", Color("ff7a7a"))
			if is_instance_valid(level_node):
				level_node.drop_item(it, player_node.global_position)
	player["quests"].remove_at(i)
	toast("Quest complete! +%d gold" % int(q["gold"]), Color("7be05a"))
	Sfx.play("coin")
	quests_changed.emit()
	return true


# =================================================================== shops
func refresh_shops(force: bool = false) -> void:
	if not force and int(shops.get("day", -1)) == int(world["day"]) and not shops["gear"].is_empty():
		return
	var lv := int(player["level"])
	var r := RandomNumberGenerator.new()
	r.randomize()
	shops["gear"] = []
	for i in 14:
		var il := clampi(lv + r.randi_range(-4, 2), 1, 100)
		shops["gear"].append(Items.random_gear(il, Items.roll_rarity(1.0, 0, 0.0, r) if r.randf() < 0.85 else 0, 1.0, r).duplicate())
		if int(shops["gear"][-1]["rarity"]) > 2:
			shops["gear"][-1] = Items.gen_gear(shops["gear"][-1]["base"], il, 2, r)
	if int(world["day"]) % 2 == 1 or shops["artifact"].is_empty() or force:
		shops["artifact"] = []
		for i in 5:
			var rar := 3 if r.randf() < 0.65 else (4 if r.randf() < 0.85 else 5)
			var it := Items.random_gear(clampi(lv + r.randi_range(0, 5), 1, 100), rar, 1.0, r)
			it["artifact"] = true
			shops["artifact"].append(it)
	shops["day"] = world["day"]


# =================================================================== time
func advance_time(delta: float) -> void:
	world["time"] = float(world["time"]) + delta
	world["total"] = float(world["total"]) + delta
	if float(world["time"]) >= DAY_LEN:
		world["time"] = float(world["time"]) - DAY_LEN
		world["day"] = int(world["day"]) + 1
		toast("Day %d begins" % int(world["day"]), Color("fee761"))


func day_fraction() -> float:
	return float(world.get("time", 0.0)) / DAY_LEN


func is_night() -> bool:
	var f := day_fraction()
	return f > 0.78 or f < 0.2


func clock_text() -> String:
	var mins := int(day_fraction() * 24.0 * 60.0)
	return "Day %d  %02d:%02d" % [int(world.get("day", 1)), mins / 60, mins % 60]


# =================================================================== save / load
func save_path(s: int) -> String:
	return SAVE_DIR + "slot_%d.save" % s


func _sync_live_state() -> void:
	if is_instance_valid(player_node):
		player["hp"] = player_node.hp
		player["mp"] = player_node.mp
	if is_instance_valid(level_node) and level_node.has_method("save_position"):
		player["pos"] = level_node.save_position()


func save_game(auto: bool = false) -> bool:
	if player.is_empty() or test_run:
		return false
	_sync_live_state()
	var data := {"version": 1, "slot": slot, "date": Time.get_datetime_string_from_system(false, true), "playtime": playtime,
		"next_uid": next_uid, "player": player, "world": world, "shops": shops, "designs": designs}
	var f := FileAccess.open(save_path(slot), FileAccess.WRITE)
	if f == null:
		push_error("Could not save: %s" % FileAccess.get_open_error())
		return false
	f.store_string(var_to_str(data))
	f.close()
	saved.emit(auto)
	return true


func slot_info(s: int) -> Dictionary:
	if not FileAccess.file_exists(save_path(s)):
		return {}
	var f := FileAccess.open(save_path(s), FileAccess.READ)
	if f == null:
		return {}
	var d = str_to_var(f.get_as_text())
	if not (d is Dictionary):
		return {}
	var p: Dictionary = d.get("player", {})
	return {"name": p.get("name", "?"), "class": p.get("class", "?"), "level": p.get("level", 1), "date": d.get("date", ""),
		"playtime": d.get("playtime", 0.0), "day": d.get("world", {}).get("day", 1)}


func load_game(s: int) -> bool:
	if not FileAccess.file_exists(save_path(s)):
		return false
	var f := FileAccess.open(save_path(s), FileAccess.READ)
	var d = str_to_var(f.get_as_text())
	if not (d is Dictionary) or not d.has("player"):
		return false
	slot = s
	test_run = false
	player = d["player"]
	world = d["world"]
	shops = d.get("shops", {"gear": [], "artifact": [], "day": 0})
	designs = d.get("designs", [])
	next_uid = int(d.get("next_uid", 1000))
	playtime = float(d.get("playtime", 0.0))
	# forward-compatible defaults
	for k in ["tomes", "quests"]:
		if not player.has(k):
			player[k] = []
	for k in ["kills", "skills"]:
		if not player.has(k):
			player[k] = {}
	if not world.has("visited"):
		world["visited"] = {}
	player["inv"].resize(int(player["bag_size"]))
	recalc()
	return true


func delete_slot(s: int) -> void:
	if FileAccess.file_exists(save_path(s)):
		DirAccess.remove_absolute(save_path(s))


## Snapshot used for dungeon test runs (restored afterwards so nothing is gained or lost)
func snapshot() -> Dictionary:
	_sync_live_state()
	return {"player": player.duplicate(true), "next_uid": next_uid}


func restore(snap: Dictionary) -> void:
	player = snap["player"]
	next_uid = snap["next_uid"]
	recalc()
	player_changed.emit()
	inventory_changed.emit()
