class_name BlacksmithWindow
extends GameWindow
## Craft gear from materials, enchant (+1..+15), reroll affixes, salvage gear.

var tabbar: TabBar
var holder: HBoxContainer
var mode := "craft"
var sel_ref: Dictionary = {}
var craft_type := "sword"
var craft_tier := 0
var detail: RichTextLabel
var action_box: HBoxContainer


func _init() -> void:
	super._init("Blacksmith — Durn's Forge", Vector2(1100, 620), "blacksmith")
	tabbar = TabBar.new()
	for t in ["Craft", "Enchant", "Reroll", "Salvage"]:
		tabbar.add_tab(t)
	tabbar.focus_mode = Control.FOCUS_NONE
	tabbar.clip_tabs = false
	tabbar.tab_changed.connect(func(i):
		mode = ["craft", "enchant", "reroll", "salvage"][i]
		sel_ref = {}
		refresh())
	body.add_child(tabbar)
	holder = UI.hbox(16)
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(holder)


func _ready() -> void:
	Game.inventory_changed.connect(refresh)
	refresh()


func refresh() -> void:
	if not is_inside_tree():
		return
	for c in holder.get_children():
		c.queue_free()
	if mode == "craft":
		_build_craft()
	else:
		_build_gear_mode()


# ------------------------------------------------------------------ craft
func _recipe(base: String, t: int) -> Dictionary:
	var tier: Dictionary = GameData.ItemData.CRAFT_TIERS[t]
	var ore: String = tier["ore"]
	var part: String = tier["part"]
	var cat: String = GameData.ItemData.GEAR[base]["cat"]
	var need := {}
	match cat:
		"weapon":
			need[ore] = 4 + 2 * t
			need["wood" if t < 2 else "hardwood"] = 3
			need[part] = 2
		"armor":
			match base:
				"leather":
					need["leather"] = 5 + 2 * t
					need[ore] = 2
				"robe":
					need["cloth"] = 5 + 2 * t
					need["crystal_shard"] = 1 + t / 2
				_:
					need[ore] = 5 + 2 * t
					need["leather"] = 3
			need[part] = 2
		_:
			need[ore] = 3 + t
			need["crystal_shard"] = 1 + t
			need[part] = 1
	return {"need": need, "gold": int(tier["gold"]), "ilvl": int(tier["ilvl"])}


func _build_craft() -> void:
	var left := UI.vbox(8)
	left.custom_minimum_size.x = 420
	holder.add_child(left)
	left.add_child(UI.label("1. Choose an item", 16, Color("ffe9a8")))
	var g := GridContainer.new()
	g.columns = 5
	for b in GameData.ItemData.GEAR:
		var bb: String = b
		var btn := UI.button(GameData.ItemData.GEAR[b]["name"], func():
			craft_type = bb
			refresh())
		btn.toggle_mode = true
		btn.button_pressed = b == craft_type
		btn.icon = Art.icon(GameData.ItemData.GEAR[b]["icon"])
		btn.add_theme_font_size_override("font_size", 12)
		g.add_child(btn)
	left.add_child(g)
	left.add_child(UI.label("2. Choose a material tier", 16, Color("ffe9a8")))
	var tg := GridContainer.new()
	tg.columns = 2
	for t in GameData.ItemData.CRAFT_TIERS.size():
		var tt: int = t
		var tier: Dictionary = GameData.ItemData.CRAFT_TIERS[t]
		var btn2 := UI.button("%s  (iLvl %d)" % [GameData.item_template(tier["ore"]).get("name", tier["ore"]), int(tier["ilvl"])], func():
			craft_tier = tt
			refresh())
		btn2.toggle_mode = true
		btn2.button_pressed = t == craft_tier
		btn2.icon = Art.icon(GameData.item_template(tier["ore"]).get("icon", "quest"))
		tg.add_child(btn2)
	left.add_child(tg)
	left.add_child(UI.sep())
	left.add_child(UI.label("Refine materials", 16, Color("ffe9a8")))
	var rf := UI.hbox(8)
	rf.add_child(UI.button("Enchant Stone (2 Crystal, 3 Iron, 120g)", func(): _refine({"crystal_shard": 2, "ore_iron": 3}, 120, "enchant_stone", 1)))
	rf.add_child(UI.button("5 Arcane Dust (1 Monster Core)", func(): _refine({"monster_core": 1}, 0, "arcane_dust", 5)))
	left.add_child(rf)
	var right := UI.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_child(right)
	var r := _recipe(craft_type, craft_tier)
	var txt := "[b][font_size=18]%s[/font_size][/b]\nItem level %d — rarity is rolled (at least Uncommon).\n\n[color=#ffe9a8]Required materials:[/color]\n" % [Items.base_name(craft_type, r["ilvl"]), r["ilvl"]]
	var ok := true
	for id in r["need"]:
		var have := Game.count_item(id)
		var need := int(r["need"][id])
		if have < need:
			ok = false
		txt += "[color=#%s]%s  %d / %d[/color]\n" % ["7be05a" if have >= need else "ff6a6a", GameData.item_template(id).get("name", id), have, need]
	var gold_ok := int(Game.player["gold"]) >= int(r["gold"])
	txt += "[color=#%s]Gold  %d / %d[/color]\n" % ["7be05a" if gold_ok else "ff6a6a", int(Game.player["gold"]), int(r["gold"])]
	txt += "\n[color=#9c97b8]Ores come from rocks in the wild (deeper = better ores). Monster parts drop from monsters. Leather from animals, cloth from goblins and zombies.[/color]"
	var d := UI.rich(txt, 14)
	right.add_child(d)
	var cb := UI.button("Craft!", func(): _craft(r), 200)
	cb.disabled = not (ok and gold_ok)
	right.add_child(cb)


func _refine(need: Dictionary, gold: int, out: String, n: int) -> void:
	for id in need:
		if Game.count_item(id) < int(need[id]):
			Game.toast("Missing %s." % GameData.item_template(id)["name"], UI.BAD)
			return
	if int(Game.player["gold"]) < gold:
		Game.toast("Not enough gold.", UI.BAD)
		return
	for id in need:
		Game.remove_item(id, int(need[id]))
	Game.add_gold(-gold)
	Game.give_item(Items.stack(out, n))
	Game.toast("Refined %s x%d" % [GameData.item_template(out)["name"], n], UI.GOOD)
	Sfx.play("equip")


func _craft(r: Dictionary) -> void:
	for id in r["need"]:
		if Game.count_item(id) < int(r["need"][id]):
			return
	if int(Game.player["gold"]) < int(r["gold"]) or Game.free_slots() <= 0:
		Game.toast("Not enough gold or bag space.", UI.BAD)
		return
	for id in r["need"]:
		Game.remove_item(id, int(r["need"][id]))
	Game.add_gold(-int(r["gold"]))
	var drop := float(Game.stats.get("drop", 100.0)) / 100.0
	var it := Items.gen_gear(craft_type, int(r["ilvl"]), Items.roll_rarity(drop * 2.0, 1, 0.3))
	Game.add_item(it)
	Sfx.play("chest")
	Game.toast("Crafted %s!" % Items.name_of(it), Items.color_of(it))
	Dialogs.message(Game.main.menu_layer, "Crafted!", Items.tooltip(it))


# ------------------------------------------------------------------ enchant / reroll / salvage
func _gear_refs() -> Array:
	var out := []
	for k in GameData.ItemData.EQUIP_SLOTS:
		var it: Dictionary = Game.player["equip"][k]
		if not it.is_empty():
			out.append({"where": "equip", "key": k, "item": it})
	var inv_a: Array = Game.player["inv"]
	for i in inv_a.size():
		var it2 = inv_a[i]
		if it2 is Dictionary and Items.is_gear(it2):
			out.append({"where": "inv", "index": i, "item": it2})
	return out


func _build_gear_mode() -> void:
	var left := UI.vbox(4)
	left.custom_minimum_size.x = 420
	holder.add_child(left)
	left.add_child(UI.label("Select gear", 16, Color("ffe9a8")))
	var list := UI.vbox(3)
	left.add_child(UI.scroll(list, Vector2(420, 470)))
	for ref in _gear_refs():
		if mode == "salvage" and ref["where"] == "equip":
			continue
		var it: Dictionary = ref["item"]
		var b := UI.button("%s%s" % [Items.name_of(it), "  (equipped)" if ref["where"] == "equip" else ""], func():
			sel_ref = ref
			refresh())
		b.icon = Items.icon_of(it)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_color_override("font_color", Items.color_of(it))
		b.toggle_mode = true
		b.button_pressed = not sel_ref.is_empty() and sel_ref["item"] == it
		list.add_child(b)
	var right := UI.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_child(right)
	if sel_ref.is_empty():
		right.add_child(UI.label("Choose a piece of gear on the left.", 15, UI.DIM))
		right.add_child(UI.rich(_mode_help(), 14))
		return
	var it2: Dictionary = sel_ref["item"]
	right.add_child(UI.rich(Items.tooltip(it2), 14))
	right.add_child(UI.sep())
	match mode:
		"enchant":
			var e := int(it2.get("enchant", 0))
			if e >= GameData.ItemData.MAX_ENCHANT:
				right.add_child(UI.label("This item is at the maximum enchant level (+15).", 15, Color("fee761")))
				return
			var cost := Items.enchant_cost(it2)
			var rate := Items.enchant_rate(it2)
			right.add_child(UI.rich("Enchant [b]+%d → +%d[/b]  (base stats +7%% per level)\nSuccess chance: [color=#%s]%d%%[/color]\nCost: %d Enchant Stone (have %d), %d gold%s" % [
				e, e + 1, "7be05a" if rate >= 70 else ("fee761" if rate >= 40 else "ff6a6a"), rate, int(cost["stones"]), Game.count_item("enchant_stone"), int(cost["gold"]),
				"\n[color=#ff8a8a]Failing at +7 or higher drops the item by 1 level.[/color]" if e >= 7 else ""], 15))
			var b := UI.button("Enchant", _enchant, 200)
			b.disabled = Game.count_item("enchant_stone") < int(cost["stones"]) or int(Game.player["gold"]) < int(cost["gold"])
			right.add_child(b)
		"reroll":
			if int(it2.get("rarity", 0)) == 0:
				right.add_child(UI.label("Common items have no affixes to reroll.", 15, UI.DIM))
				return
			if it2.get("unique", "") != "":
				right.add_child(UI.label("Unique items have fixed powers and cannot be rerolled.", 15, UI.DIM))
				return
			var c2 := Items.reroll_cost(it2)
			right.add_child(UI.rich("Reroll all %d bonus affixes.\nCost: %d Arcane Dust (have %d), %d gold" % [it2["affixes"].size(), int(c2["dust"]), Game.count_item("arcane_dust"), int(c2["gold"])], 15))
			var b2 := UI.button("Reroll", _reroll, 200)
			b2.disabled = Game.count_item("arcane_dust") < int(c2["dust"]) or int(Game.player["gold"]) < int(c2["gold"])
			right.add_child(b2)
		"salvage":
			var res := Items.salvage_result(it2)
			var t := "Break this item down into:\n"
			for k in res:
				t += "  %s x%d\n" % [GameData.item_template(k)["name"], int(res[k])]
			right.add_child(UI.rich(t, 15))
			right.add_child(UI.button("Salvage", _salvage, 200))


func _mode_help() -> String:
	match mode:
		"enchant":
			return "[color=#9c97b8]Enchanting raises the base stats of weapons, armor and accessories (+1 up to +15). Higher levels are riskier. Enchant Stones drop from monsters and chests, or can be refined here.[/color]"
		"reroll":
			return "[color=#9c97b8]Rerolling re-randomizes every bonus affix on an Uncommon or better item. Costs Arcane Dust and gold.[/color]"
	return "[color=#9c97b8]Salvage unwanted gear into Arcane Dust (and Enchant Stones for Epic or better).[/color]"


func _enchant() -> void:
	var it: Dictionary = sel_ref["item"]
	var cost := Items.enchant_cost(it)
	if not Game.remove_item("enchant_stone", int(cost["stones"])):
		return
	Game.add_gold(-int(cost["gold"]))
	var e := int(it.get("enchant", 0))
	if randi() % 100 < Items.enchant_rate(it):
		it["enchant"] = e + 1
		Game.toast("Enchant success! %s" % Items.name_of(it), Color("c79bff"))
		Sfx.play("levelup")
	else:
		if e >= 7:
			it["enchant"] = e - 1
			Game.toast("Enchant failed... the item dropped to +%d." % (e - 1), UI.BAD)
		else:
			Game.toast("Enchant failed. Materials were consumed.", UI.BAD)
		Sfx.play("error")
	Game._after_equip_change()


func _reroll() -> void:
	var it: Dictionary = sel_ref["item"]
	var c := Items.reroll_cost(it)
	if not Game.remove_item("arcane_dust", int(c["dust"])):
		return
	Game.add_gold(-int(c["gold"]))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	Items.roll_affixes(it, rng)
	Game.toast("Affixes rerolled!", Color("8fe8ff"))
	Sfx.play("magic")
	Game._after_equip_change()


func _salvage() -> void:
	if sel_ref.get("where", "") != "inv":
		return
	var it: Dictionary = sel_ref["item"]
	var res := Items.salvage_result(it)
	Game.remove_at(int(sel_ref["index"]))
	for k in res:
		Game.give_item(Items.stack(k, int(res[k])))
	sel_ref = {}
	Game.toast("Salvaged %s." % Items.name_of(it), UI.DIM)
	Sfx.play("mine")
	refresh()
