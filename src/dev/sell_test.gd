extends Node
## Selling by filter (rarity, item level, gold value, type) + item locking.
##   godot --path . -- --autotest --selltest [--shots=DIR]

var fails: Array = []
var passes := 0
var shots_dir := ""
var step := 0


func ok(cond: bool, what: String) -> void:
	if cond:
		passes += 1
		print("[sell] pass  ", what)
	else:
		fails.append(what)
		print("[sell] FAIL  ", what)


func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func shot(name: String) -> void:
	if shots_dir == "":
		return
	for i in 3:
		await get_tree().process_frame
	step += 1
	DirAccess.make_dir_recursive_absolute(shots_dir)
	get_viewport().get_texture().get_image().save_png("%s/sell_%02d_%s.png" % [shots_dir, step, name])


func _bag() -> Array:
	var out := []
	for it in Game.player["inv"]:
		if it is Dictionary and not it.is_empty():
			out.append(it)
	return out


func _uids(lines: Array) -> Dictionary:
	var d := {}
	for ln in lines:
		d[int(ln[1]["uid"])] = int(ln[2])
	return d


## Puts an item in the bag and returns the bag's own copy (the bag stores a copy).
func _give(it: Dictionary) -> Dictionary:
	var uid := int(it["uid"])
	Game.give_item(it)
	for b in Game.player["inv"]:
		if b is Dictionary and int(b.get("uid", -1)) == uid:
			return b
	return it


func run_all() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
	var M = Game.main
	M.go_title(false)
	await _wait(0.3)
	M.start_new_game("Seller", "warrior", 3)
	await _wait(1.2)
	while int(Game.player["level"]) < 20:
		Game.add_xp(GameData.xp_to_next(int(Game.player["level"])))
	# empty bag, a worn weapon to compare upgrades against
	for i in Game.player["inv"].size():
		Game.player["inv"][i] = null
	Game.player["bag_size"] = maxi(int(Game.player.get("bag_size", 30)), 60)
	while Game.player["inv"].size() < 60:
		Game.player["inv"].append(null)
	var wb: String = GameData.CLASSES["warrior"]["weapon"]
	# wearing rare level-15 gear in every slot, so plain low items are no upgrade
	Game.player["equip"]["weapon"] = Items.gen_gear(wb, 15, 2)
	Game.player["equip"]["armor"] = Items.gen_gear("heavy", 15, 2)
	Game.player["equip"]["necklace"] = Items.gen_gear("necklace", 15, 2)
	for sl in ["ring1", "ring2"]:
		Game.player["equip"][sl] = Items.gen_gear("ring", 15, 2)
	for sl in ["bracelet1", "bracelet2"]:
		Game.player["equip"][sl] = Items.gen_gear("bracelet", 15, 2)
	Game._after_equip_change()
	var c5 := _give(Items.gen_gear("heavy", 5, 0))          # common, low level
	var c12 := _give(Items.gen_gear("ring", 12, 0))         # common accessory
	var u8 := _give(Items.gen_gear("bracelet", 8, 1))       # uncommon
	var u18 := _give(Items.gen_gear(wb, 3, 1))              # uncommon weapon, weaker than worn
	var r10 := _give(Items.gen_gear("light", 10, 2))        # rare
	var e25 := _give(Items.gen_gear("necklace", 25, 3))     # epic
	var l30 := _give(Items.gen_gear("heavy", 30, 4))        # legendary
	var ench := _give(Items.gen_gear("leather", 6, 0))      # common but enchanted
	ench["enchant"] = 3
	var upg := _give(Items.gen_gear(wb, 60, 0))             # common, but beats the worn weapon by far
	var uniq := _give(Items.unique_for("ogre", 14))
	var locked := _give(Items.gen_gear("heavy", 4, 0))      # common, locked
	locked["locked"] = true
	var wood := _give(Items.stack("wood", 30))
	var pots := _give(Items.stack("pot_hp_s", 12))
	var tome := _give(Items.stack("book_fire", 1))
	Game.player["quests"].append({"id": 1, "have": 0, "type": "gather", "target": "wood", "need": 10, "title": "Gather: Wood",
		"desc": "Bring 10 Wood.", "gold": 50, "xp": 10, "gp": 5})
	Game.inventory_changed.emit()
	print("[sell] info: worn %s (score %.0f) vs upgrade %s (score %.0f)" % [Items.name_of(Game.player["equip"]["weapon"]),
		NpcWorld.gear_score(Game.player, Game.player["equip"]["weapon"]), Items.name_of(upg), NpcWorld.gear_score(Game.player, upg)])
	# ---- the default filter: plain common & uncommon gear
	var f := BulkSell.default_filter()
	var p := BulkSell.plan(f)
	var got := _uids(p["lines"])
	for it in [c5, c12, u8, u18]:
		ok(got.has(int(it["uid"])), "default filter sells %s" % Items.name_of(it))
	ok(not got.has(int(r10["uid"])) and not got.has(int(e25["uid"])) and not got.has(int(l30["uid"])), "default filter keeps Rare and better")
	ok(not got.has(int(ench["uid"])), "enchanted gear is kept")
	ok(not got.has(int(upg["uid"])) and BulkSell.reason_kept(upg, f) == "upgrade", "gear better than what you wear is kept")
	ok(not got.has(int(uniq["uid"])), "boss uniques are kept")
	var f_all := BulkSell.default_filter()
	f_all["rarities"] = [true, true, true, true, true, true]
	ok(BulkSell.reason_kept(e25, f_all) == "upgrade" and BulkSell.reason_kept(l30, f_all) == "upgrade",
		"the Epic necklace and Legendary armor beat what you wear: kept as upgrades")
	# an empty slot keeps only the best candidate, not every item of that kind
	var worn_ring: Dictionary = Game.player["equip"]["ring1"]
	Game.player["equip"]["ring1"] = {}
	var ring2 := _give(Items.gen_gear("ring", 2, 0))
	var up := BulkSell.upgrade_uids()
	ok(up.has(int(c12["uid"])) and not up.has(int(ring2["uid"])), "an empty ring slot keeps the best ring only")
	Game.player["equip"]["ring1"] = worn_ring
	Game.player["inv"][Game.player["inv"].find(ring2)] = null
	ok(not got.has(int(locked["uid"])) and BulkSell.reason_kept(locked, f) == "locked", "locked items are never sold")
	ok(not got.has(int(wood["uid"])) and not got.has(int(pots["uid"])), "materials and potions are off by default")
	ok(BulkSell.reason_kept(tome, f) == "special item", "tomes are never sold by filter")
	var expect := 0
	for it in [c5, c12, u8, u18]:
		expect += Items.sell_price(it)
	ok(int(p["gold"]) == expect and int(p["count"]) == 4, "the preview total is the sum of the sell prices (%d gold)" % expect)
	# ---- rarity
	var fr := BulkSell.default_filter()
	fr["keep_upgrades"] = false
	fr["rarities"] = [false, false, true, true, false, false]
	got = _uids(BulkSell.plan(fr)["lines"])
	ok(got.size() == 2 and got.has(int(r10["uid"])) and got.has(int(e25["uid"])), "rarity filter: only Rare and Epic (%d)" % got.size())
	# ---- item level
	var fl := BulkSell.default_filter()
	fl["keep_upgrades"] = false
	fl["rarities"] = [true, true, true, true, true, true]
	fl["lv_min"] = 8
	fl["lv_max"] = 12
	got = _uids(BulkSell.plan(fl)["lines"])
	ok(got.has(int(c12["uid"])) and got.has(int(u8["uid"])) and got.has(int(r10["uid"])) and not got.has(int(c5["uid"])) and not got.has(int(e25["uid"])),
		"item level 8-12 only (%d items)" % got.size())
	# ---- gold value per item
	var fp := BulkSell.default_filter()
	fp["keep_upgrades"] = false
	fp["rarities"] = [true, true, true, true, true, true]
	fp["price_min"] = Items.sell_price(r10)
	got = _uids(BulkSell.plan(fp)["lines"])
	var all_rich := true
	for uid in got:
		for it in _bag():
			if int(it["uid"]) == uid and Items.sell_price(it) < Items.sell_price(r10):
				all_rich = false
	ok(all_rich and got.has(int(r10["uid"])) and got.has(int(l30["uid"])), "value filter: only items worth %d gold or more" % Items.sell_price(r10))
	fp["price_min"] = 0
	fp["price_max"] = Items.sell_price(c12)
	got = _uids(BulkSell.plan(fp)["lines"])
	ok(got.has(int(c12["uid"])) and not got.has(int(l30["uid"])), "value filter: only items worth at most %d gold" % Items.sell_price(c12))
	# ---- materials and potions: quest needs and a reserve stay in the bag
	var fm := BulkSell.default_filter()
	fm["types"] = {"weapon": false, "armor": false, "accessory": false, "material": true, "consumable": true}
	fm["keep_stack"] = 5
	got = _uids(BulkSell.plan(fm)["lines"])
	ok(int(got.get(int(wood["uid"]), 0)) == 30 - 10 - 5, "materials: keeps what the quest needs + 5 (sells %d of 30 wood)" % int(got.get(int(wood["uid"]), 0)))
	ok(int(got.get(int(pots["uid"]), 0)) == 12 - 5, "potions: keeps 5 of the stack (sells %d of 12)" % int(got.get(int(pots["uid"]), 0)))
	fm["keep_quest"] = false
	fm["keep_stack"] = 0
	got = _uids(BulkSell.plan(fm)["lines"])
	ok(int(got.get(int(wood["uid"]), 0)) == 30, "without the quest rule the whole stack goes")
	# ---- a gold target: the cheapest matches until the goal is met
	var fg := BulkSell.default_filter()
	fg["keep_upgrades"] = false
	fg["rarities"] = [true, true, true, true, true, true]
	fg["types"]["material"] = true
	fg["keep_quest"] = false
	fg["gold_goal"] = 40
	var pg := BulkSell.plan(fg)
	var most := 0
	for ln in pg["lines"]:
		most = maxi(most, Items.sell_price(ln[1]))
	ok(int(pg["gold"]) >= 40 and int(pg["gold"]) - most < 40, "gold target 40: sells just enough, cheapest first (%d gold from %d items)" % [int(pg["gold"]), int(pg["count"])])
	var cheapest_first := true
	for i in range(1, pg["lines"].size()):
		if Items.sell_price(pg["lines"][i][1]) < Items.sell_price(pg["lines"][i - 1][1]):
			cheapest_first = false
	ok(cheapest_first, "  in order of value")
	# ---- excluding items by hand
	var ex := {int(c5["uid"]): true}
	got = _uids(BulkSell.plan(f, ex)["lines"])
	ok(not got.has(int(c5["uid"])) and got.has(int(c12["uid"])), "an item clicked to keep is left out")
	# ---- selling
	var g0 := int(Game.player["gold"])
	var res := BulkSell.sell(f, ex)
	ok(int(Game.player["gold"]) == g0 + int(res[1]) and int(res[1]) == expect - Items.sell_price(c5) and int(res[0]) == 3, "selling pays the previewed gold (%d)" % int(res[1]))
	var left := {}
	for it in _bag():
		left[int(it["uid"])] = true
	ok(not left.has(int(c12["uid"])) and not left.has(int(u8["uid"])) and left.has(int(c5["uid"])) and left.has(int(locked["uid"])) and left.has(int(upg["uid"])), "the right items left the bag")
	ok(not Game.player["equip"]["weapon"].is_empty(), "equipped gear is untouched")
	# ---- the window
	M.open_service("gear")
	await _wait(0.4)
	ok(M.window is ShopWindow, "gear shop open")
	var d: SellFilterDialog = M.window.open_sell_filter()
	await _wait(0.4)
	ok(is_instance_valid(d) and d.is_inside_tree(), "Sell by filter opens from the shop")
	d.f = BulkSell.default_filter()
	d.f["rarities"] = [true, true, true, false, false, false]
	d._sync_widgets()
	d._changed()
	await _wait(0.2)
	var dp := BulkSell.plan(d.f, d.exclude)
	ok(d.sell_btn.text == "Sell %d items for %d gold" % [int(dp["count"]), int(dp["gold"])] or (int(dp["count"]) == 1 and d.sell_btn.text.begins_with("Sell 1 item")),
		"the button shows what will be sold (%s)" % d.sell_btn.text)
	ok(d.preview_grid.get_child_count() == dp["lines"].size(), "the preview shows each item (%d)" % d.preview_grid.get_child_count())
	await shot("filter_dialog")
	# click the first preview slot to keep it
	if d.preview_grid.get_child_count() == 0:
		ok(false, "the preview has items to click")
		_end()
		return
	var first: ItemSlot = d.preview_grid.get_child(0)
	var first_uid := int(first.item["uid"])
	first.slot_clicked.emit(first, MOUSE_BUTTON_LEFT, false, false)
	await _wait(0.2)
	ok(d.exclude.has(first_uid), "clicking a previewed item keeps it")
	# preset buttons
	ok(int(Game.player.get("sell_filter", {}).get("rarities", []).count(true)) == 3, "the filter is remembered for this character")
	var g1 := int(Game.player["gold"])
	var want := BulkSell.plan(d.f, d.exclude)
	d._sell_pressed()
	await _wait(0.3)
	# a confirmation may appear for valuable batches
	for c in (d.get_children() if is_instance_valid(d) else []):
		if c is ColorRect:
			for b in c.find_children("*", "Button", true, false):
				if b.text == "Sell":
					b.pressed.emit()
	await _wait(0.4)
	ok(int(Game.player["gold"]) == g1 + int(want["gold"]), "selling from the window pays %d gold" % int(want["gold"]))
	ok(not is_instance_valid(d) or not d.is_inside_tree(), "and closes the window")
	var still := false
	for it in _bag():
		if int(it["uid"]) == first_uid:
			still = true
	ok(still, "the item clicked to keep is still in the bag")
	await shot("after_sell")
	# ---- locking from the bag
	M.close_all()
	M.open_menu("inventory")
	await _wait(0.4)
	var page = M.window.find_children("*", "InventoryPage", true, false)[0]
	var idx := -1
	for i in Game.player["inv"].size():
		var it = Game.player["inv"][i]
		if it is Dictionary and not it.is_empty() and int(it.get("uid", -1)) == int(upg["uid"]):
			idx = i
	page._open_popup(idx)
	await _wait(0.2)
	var lock_i: int = page.popup.get_item_index(20)
	ok(lock_i >= 0 and page.popup.get_item_text(lock_i).begins_with("Lock"), "the bag's item menu offers Lock")
	page.popup.hide()
	page._on_popup(20)
	await _wait(0.2)
	ok(upg.get("locked", false), "the item is locked")
	var slot_shown := false
	for s in page.find_children("*", "ItemSlot", true, false):
		if s.source == "inv" and int(s.item.get("uid", -1)) == int(upg["uid"]) and s.lock_mark.visible:
			slot_shown = true
	ok(slot_shown, "a padlock shows on its slot")
	ok(Items.tooltip(upg).contains("Locked"), "and in its tooltip")
	page._open_popup(idx)
	await _wait(0.1)
	ok(page.popup.is_item_disabled(page.popup.get_item_index(2)), "a locked item can't be discarded")
	page.popup.hide()
	await shot("locked_item")
	page._on_popup(20)
	ok(not upg.get("locked", false), "and unlocked again")
	M.close_all()
	# ---- saved with the character
	var saved_f: Dictionary = Game.player["sell_filter"].duplicate(true)
	locked["locked"] = true
	Game.save_game(false)
	M.load_slot(3)
	await _wait(0.8)
	ok(BulkSell.saved_filter()["rarities"] == saved_f["rarities"], "the filter is saved with the game")
	var lock_kept := false
	for it in _bag():
		if int(it.get("uid", -1)) == int(locked["uid"]) and it.get("locked", false):
			lock_kept = true
	ok(lock_kept, "locks are saved with the game")
	await _buyback_tests()
	_end()


func _bag_has(uid: int) -> bool:
	for it in _bag():
		if int(it.get("uid", -1)) == uid:
			return true
	return false


# ---- buying back recently sold items
func _buyback_tests() -> void:
	var M = Game.main
	Game.player["buyback"] = []
	Game.add_gold(100000)
	M.open_service("gear")
	await _wait(0.4)
	var w: ShopWindow = M.window
	var gear := _give(Items.gen_gear(GameData.CLASSES["warrior"]["weapon"], 20, 1))
	var uid := int(gear["uid"])
	var price := Items.sell_price(gear)
	var idx := -1
	for i in Game.player["inv"].size():
		var it = Game.player["inv"][i]
		if it is Dictionary and int(it.get("uid", -1)) == uid:
			idx = i
	var g0 := int(Game.player["gold"])
	w._do_sell(idx, 1)
	ok(not _bag_has(uid) and int(Game.player["gold"]) == g0 + price, "sold the gear (+%d)" % price)
	var bb := Game.buyback_list()
	ok(bb.size() == 1 and int(bb[0]["item"]["uid"]) == uid and int(bb[0]["each"]) == price, "the sale is listed for buyback")
	w.buyback_mode = true
	w.refresh()
	await _wait(0.2)
	ok(w.stock_grid.get_child_count() == 1 and w.tab_btn.text == "Back to shop", "the Buy back tab lists it")
	await shot("buyback")
	w._buy_back(0)
	await _wait(0.2)
	ok(_bag_has(uid) and int(Game.player["gold"]) == g0 and Game.buyback_list().is_empty(), "bought back for what it sold for")
	# stacks: selling the same potion twice makes one entry; partial buyback when gold is short
	Game.give_item(Items.stack("pot_hp_s", 6))
	var each := Items.sell_price(Items.stack("pot_hp_s", 1))
	for k in 2:
		for i in Game.player["inv"].size():
			var it = Game.player["inv"][i]
			if it is Dictionary and it.get("id", "") == "pot_hp_s":
				w._do_sell(i, 3)
				break
	bb = Game.buyback_list()
	ok(bb.size() == 1 and int(bb[0]["item"]["qty"]) == 6, "repeated sales of one stack merge (%s)" % str(bb.map(func(e): return e["item"].get("qty", 1))))
	Game.player["gold"] = each * 2
	var got := Game.buy_back(0)
	ok(got == 2 and int(Game.buyback_list()[0]["item"]["qty"]) == 4 and int(Game.player["gold"]) == 0, "short on gold: buys back what you can afford")
	# the list keeps only the latest sales
	Game.player["buyback"] = []
	for k in Game.BUYBACK_MAX + 3:
		Game.record_sale(Items.gen_gear(GameData.CLASSES["warrior"]["weapon"], 5, 0), 10)
	ok(Game.buyback_list().size() == Game.BUYBACK_MAX, "only the last %d sales are kept" % Game.BUYBACK_MAX)
	M.close_all()


func _end() -> void:
	print("[sell] ==== %d passed, %d failed" % [passes, fails.size()])
	for x in fails:
		print("[sell] FAILED: ", x)
	get_tree().quit()
