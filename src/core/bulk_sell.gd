class_name BulkSell
extends RefCounted
## Selling many bag items at once by filter: item type, rarity, item level and gold value per item, with
## safety rules (locked items, enchanted gear, upgrades over what you wear, quest materials, a reserve of each
## potion/material stack) and an optional gold target ("sell the cheapest matches until I get N gold").
## Equipped items are never in the bag, so they are never sold. Locked items are never sold.
##
## The filter is a plain Dictionary saved with the character (Game.player["sell_filter"]).

const TYPES := ["weapon", "armor", "accessory", "material", "consumable"]
const TYPE_NAMES := {"weapon": "Weapons", "armor": "Armor", "accessory": "Accessories", "material": "Materials", "consumable": "Potions & food"}


static func default_filter() -> Dictionary:
	return {
		"types": {"weapon": true, "armor": true, "accessory": true, "material": false, "consumable": false},
		"rarities": [true, true, false, false, false, false],
		"lv_min": 1, "lv_max": 100,  # gear item level
		"price_min": 0, "price_max": 0,  # gold per item; 0 = no upper limit
		"keep_enchanted": true, "keep_upgrades": true, "keep_quest": true, "keep_uniques": true,
		"keep_stack": 0,  # keep at least this many of each potion / food / material
		"gold_goal": 0,  # 0 = sell every match; otherwise the cheapest matches until this much gold
	}


## The character's saved filter, completed with defaults for anything missing.
static func saved_filter() -> Dictionary:
	var f := default_filter()
	var s = Game.player.get("sell_filter", {})
	if s is Dictionary:
		for k in s:
			if f.has(k):
				f[k] = s[k]
	if not (f["rarities"] is Array) or f["rarities"].size() != GameData.ItemData.RARITIES.size():
		f["rarities"] = default_filter()["rarities"]
	return f


static func save_filter(f: Dictionary) -> void:
	Game.player["sell_filter"] = f.duplicate(true)


## Which filter type an item belongs to ("" = never bulk-sold: tomes, scrolls, dungeon crystals...).
static func type_of(it: Dictionary) -> String:
	if Items.is_gear(it):
		var c := Items.category(it)
		if c in ["weapon", "armor"]:
			return c
		return "accessory"
	match Items.filter_group(it):
		"material":
			return "material"
		"consumable":
			return "consumable"
	return ""


## The bag items that would make it into the hero's gear: for each slot type, the best pieces that beat what is
## worn (an empty slot counts as weakest), at most one per slot — so with an empty ring slot only the best ring
## is kept, not every ring.
static func upgrade_uids() -> Dictionary:
	var by_cat := {}
	for it in Game.player["inv"]:
		if it is Dictionary and Items.is_gear(it):
			var c := Items.category(it)
			if not by_cat.has(c):
				by_cat[c] = []
			by_cat[c].append(it)
	var out := {}
	for cat in by_cat:
		var slots := [cat] if cat in ["weapon", "armor", "necklace"] else [cat + "1", cat + "2"]
		var worn := []
		for sl in slots:
			var w: Dictionary = Game.player["equip"].get(sl, {})
			worn.append(NpcWorld.gear_score(Game.player, w) if not w.is_empty() else -1.0)
		var cands: Array = by_cat[cat]
		cands.sort_custom(func(a, b): return NpcWorld.gear_score(Game.player, a) > NpcWorld.gear_score(Game.player, b))
		for it in cands:
			var sc := NpcWorld.gear_score(Game.player, it)
			var wi := 0
			for k in worn.size():
				if worn[k] < worn[wi]:
					wi = k
			if worn[wi] < 0.0 or sc > worn[wi] * 1.001:
				out[int(it.get("uid", -1))] = true
				worn[wi] = sc  # it would be worn instead
			else:
				break
	return out


static func is_upgrade(it: Dictionary) -> bool:
	return upgrade_uids().has(int(it.get("uid", -1)))


static func _quest_needs(id: String) -> int:
	var need := 0
	for q in Game.player.get("quests", []):
		if q.get("type", "") == "gather" and q.get("target", "") == id:
			need += int(q.get("need", 0))
	return need


## Why an item is kept ("" = it matches the filter and would be sold). `upgrades` = upgrade_uids(), if already known.
static func reason_kept(it: Dictionary, f: Dictionary, upgrades = null) -> String:
	if it.is_empty():
		return "empty"
	if it.get("locked", false):
		return "locked"
	var t := type_of(it)
	if t == "":
		return "special item"
	if not f["types"].get(t, false):
		return "type"
	var price := Items.sell_price(it)
	if price < int(f["price_min"]):
		return "value"
	if int(f["price_max"]) > 0 and price > int(f["price_max"]):
		return "value"
	if Items.is_gear(it):
		var r := int(it.get("rarity", 0))
		if r < 0 or r >= f["rarities"].size() or not f["rarities"][r]:
			return "rarity"
		var il := int(it.get("ilvl", 1))
		if il < int(f["lv_min"]) or il > int(f["lv_max"]):
			return "level"
		if f["keep_uniques"] and it.has("unique"):
			return "boss unique"
		if f["keep_enchanted"] and int(it.get("enchant", 0)) > 0:
			return "enchanted"
		if f["keep_upgrades"]:
			var up: Dictionary = upgrades if upgrades is Dictionary else upgrade_uids()
			if up.has(int(it.get("uid", -1))):
				return "upgrade"
	return ""


## What selling with this filter would do: {"lines": [[bag index, item, qty to sell, gold]], "count", "gold", "best_rarity"}.
## `exclude` holds item uids the player clicked to keep this time.
static func plan(f: Dictionary, exclude: Dictionary = {}) -> Dictionary:
	var inv: Array = Game.player["inv"]
	var lines := []
	var keep_stack := maxi(0, int(f["keep_stack"]))
	var reserved := {}  # item id -> how many are still to be kept back (quest needs + reserve)
	var ups := upgrade_uids() if f["keep_upgrades"] else {}
	var kept := {}  # matched the filter but kept by a safety rule: reason -> count
	for i in inv.size():
		var it = inv[i]
		if not (it is Dictionary) or it.is_empty() or exclude.has(int(it.get("uid", -1))):
			continue
		var why := reason_kept(it, f, ups)
		if why != "":
			if why in ["locked", "upgrade", "enchanted", "boss unique"]:
				kept[why] = int(kept.get(why, 0)) + 1
			continue
		var qty := int(it.get("qty", 1))
		if not Items.is_gear(it):
			var id: String = it.get("id", "")
			if not reserved.has(id):
				reserved[id] = keep_stack + (_quest_needs(id) if f["keep_quest"] else 0)
			var hold := mini(qty, int(reserved[id]))
			reserved[id] = int(reserved[id]) - hold
			qty -= hold
			if hold > 0:
				kept["reserve"] = int(kept.get("reserve", 0)) + hold
		if qty <= 0:
			continue
		lines.append([i, it, qty, Items.sell_price(it) * qty])
	var goal := int(f["gold_goal"])
	if goal > 0:
		# cheapest single items first, until the goal is met
		lines.sort_custom(func(a, b): return Items.sell_price(a[1]) < Items.sell_price(b[1]))
		var picked := []
		var got := 0
		for ln in lines:
			if got >= goal:
				break
			var each := Items.sell_price(ln[1])
			var n: int = ln[2]
			if not Items.is_gear(ln[1]):
				n = mini(n, int(ceil(float(goal - got) / maxf(1.0, each))))
			picked.append([ln[0], ln[1], n, each * n])
			got += each * n
		lines = picked
	var total := 0
	var count := 0
	var best := -1
	for ln in lines:
		total += int(ln[3])
		count += int(ln[2])
		if Items.is_gear(ln[1]):
			best = maxi(best, int(ln[1].get("rarity", 0)))
	return {"lines": lines, "count": count, "gold": total, "best_rarity": best, "kept": kept}


## "2 upgrades, 1 locked, 5 in reserve" — what the safety rules held back.
static func kept_text(kept: Dictionary) -> String:
	var parts := []
	for pr in [["upgrade", "upgrade", "upgrades"], ["locked", "locked", "locked"], ["enchanted", "enchanted", "enchanted"],
			["boss unique", "boss unique", "boss uniques"], ["reserve", "kept in reserve / for quests", "kept in reserve / for quests"]]:
		var n := int(kept.get(pr[0], 0))
		if n > 0:
			parts.append("%d %s" % [n, pr[1] if n == 1 else pr[2]])
	return ", ".join(parts)


## Sells what plan() returns. Returns [items sold, gold earned].
static func sell(f: Dictionary, exclude: Dictionary = {}) -> Array:
	var p := plan(f, exclude)
	var gold := 0
	var count := 0
	var inv: Array = Game.player["inv"]
	for ln in p["lines"]:
		var idx: int = ln[0]
		var it = inv[idx]
		if not (it is Dictionary) or it.get("uid", -1) != ln[1].get("uid", -2):
			continue  # the bag changed meanwhile
		var each := Items.sell_price(it)
		var n := mini(int(ln[2]), int(it.get("qty", 1)))
		var sold: Dictionary = it
		if Items.is_gear(it) or n >= int(it.get("qty", 1)):
			inv[idx] = null
		else:
			sold = it.duplicate(true)
			sold["qty"] = n
			it["qty"] = int(it["qty"]) - n
		Game.record_sale(sold, each)
		gold += each * n
		count += n
	if count > 0:
		Game.inventory_changed.emit()  # once, not per item
	if gold > 0:
		Game.add_gold(gold)
	return [count, gold]
