class_name ShopWindow
extends GameWindow
## Buy/sell window used by the Gear, Potion, Food, Magic and Artifact shops.

var role := "gear"
var stock_grid: GridContainer
var inv_grid: GridContainer
var gold_lbl: Label
var info_lbl: RichTextLabel

const TITLES := {"gear": "Gear Shop — Bram's Arms & Armor", "potion": "Potion Shop — Myra's Remedies", "food": "Food Shop — Tobbin's Kitchen",
	"magic": "Magic Shop — Orren's Spellbooks", "artifact": "Artifact Shop — Lys' Curiosities"}
const BLURB := {
	"gear": "Weapons and armor restocked every day. Sell me anything you find out there!",
	"potion": "Healing, mana and battle draughts. Stronger brews unlock as you level.",
	"food": "A full belly keeps you alive out there. Food grants Satiety and lasting buffs.",
	"magic": "Spellbooks teach Tome skills to any class. I also sell enchanting supplies and rebirth scrolls.",
	"artifact": "Rare treasures, only one of each. New wares arrive every other day.",
}


func _init(r: String) -> void:
	role = r
	super._init(TITLES.get(r, "Shop"), Vector2(1120, 620), "shop_" + r)
	info_lbl = UI.rich("[color=#9c97b8]%s[/color]" % BLURB.get(r, ""), 14)
	body.add_child(info_lbl)
	if r == "food":
		var cook := UI.hbox(8)
		body.add_child(cook)
		cook.add_child(UI.label("Cooking service:", 14, Color("ffe9a8")))
		cook.add_child(UI.button("Grill all Raw Meat (5g each)", func(): _cook({"food_raw_meat": 1}, "food_grilled_meat", 5)))
		cook.add_child(UI.button("Fish Stew (Fish + Herb, 10g)", func(): _cook({"food_fish": 1, "herb": 1}, "food_fish_stew", 10)))
		cook.add_child(UI.button("Hearty Stew (2 Raw Meat + Herb, 15g)", func(): _cook({"food_raw_meat": 2, "herb": 1}, "food_hearty_stew", 15)))
	var h := UI.hbox(18)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(h)
	var left := UI.vbox(6)
	h.add_child(left)
	var lt := UI.hbox(8)
	left.add_child(lt)
	lt.add_child(UI.label("For sale", 18, Color("ffe9a8")))
	if role == "gear":
		lt.add_child(UI.button("Restock (%dg)" % _restock_cost(), func():
			var c := _restock_cost()
			if int(Game.player["gold"]) < c:
				Game.toast("Not enough gold.", UI.BAD)
				return
			Game.add_gold(-c)
			Game.refresh_shops(true)
			refresh()))
	left.add_child(UI.label("Click to buy. Shift+click to buy several.", 12, UI.DIM))
	stock_grid = GridContainer.new()
	stock_grid.columns = 7
	stock_grid.add_theme_constant_override("h_separation", 8)
	stock_grid.add_theme_constant_override("v_separation", 18)
	left.add_child(UI.scroll(stock_grid, Vector2(470, 440)))
	var right := UI.vbox(6)
	h.add_child(right)
	var rt := UI.hbox(8)
	right.add_child(rt)
	rt.add_child(UI.label("Your bag", 18, Color("ffe9a8")))
	rt.add_child(UI.icon(Art.icon("gold"), 18))
	gold_lbl = UI.label("", 16, Color("fee761"))
	rt.add_child(gold_lbl)
	rt.add_child(UI.button("Sell all Common gear", _sell_junk))
	right.add_child(UI.label("Click an item to sell it. Equipped items are not shown.", 12, UI.DIM))
	inv_grid = GridContainer.new()
	inv_grid.columns = 10
	inv_grid.add_theme_constant_override("h_separation", 4)
	inv_grid.add_theme_constant_override("v_separation", 4)
	right.add_child(UI.scroll(inv_grid, Vector2(520, 440)))


func _ready() -> void:
	Game.inventory_changed.connect(refresh)
	Game.gold_changed.connect(refresh)
	refresh()


func _restock_cost() -> int:
	return 50 + int(Game.player["level"]) * 20


func _stock() -> Array:
	match role:
		"gear":
			return Game.shops["gear"]
		"artifact":
			return Game.shops["artifact"]
		"potion":
			var a := []
			for id in GameData.ItemData.CONSUMABLES:
				if GameData.ItemData.CONSUMABLES[id]["kind"] == "potion":
					a.append({"id": id, "qty": 1})
			return a
		"food":
			var f := []
			for id in ["food_apple", "food_bread", "food_grilled_meat", "food_fish_stew", "food_hearty_stew", "food_honey_cake", "food_feast"]:
				f.append({"id": id, "qty": 1})
			return f
		"magic":
			var m := []
			for id in ["book_fire", "book_water", "book_earth", "book_wind", "book_light", "book_dark", "book_forget", "scroll_rebirth"]:
				m.append({"id": id, "qty": 1})
			for id in ["enchant_stone", "arcane_dust", "crystal_shard"]:
				m.append({"id": id, "qty": 1, "_price": {"enchant_stone": 400, "arcane_dust": 150, "crystal_shard": 250}[id]})
			return m
	return []


func _price(it: Dictionary) -> int:
	if it.has("_price"):
		return int(it["_price"])
	return Items.buy_price(it)


func refresh() -> void:
	if not is_inside_tree():
		return
	gold_lbl.text = str(int(Game.player["gold"]))
	for c in stock_grid.get_children():
		c.queue_free()
	var stock := _stock()
	for i in stock.size():
		var it: Dictionary = stock[i]
		var s := ItemSlot.new(52)
		s.source = "shop"
		s.index = i
		s.draggable = false
		var price := _price(it)
		var lvreq := int(GameData.item_template(it.get("id", "")).get("lv", 0)) if not Items.is_gear(it) else 0
		s.dim = lvreq > int(Game.player["level"])
		s.set_item(it, price)
		s.slot_clicked.connect(func(sl, btn, shift, _dbl):
			if btn == MOUSE_BUTTON_LEFT:
				_buy(sl.index, shift))
		stock_grid.add_child(s)
	if stock.is_empty():
		stock_grid.add_child(UI.label("Sold out! Come back tomorrow.", 14, UI.DIM))
	for c in inv_grid.get_children():
		c.queue_free()
	var inv_a: Array = Game.player["inv"]
	for i in inv_a.size():
		var it2 = inv_a[i]
		if not (it2 is Dictionary) or it2.is_empty():
			continue
		var s2 := ItemSlot.new(46)
		s2.source = "inv"
		s2.index = i
		s2.draggable = false
		s2.set_item(it2, Items.sell_price(it2))
		s2.slot_clicked.connect(func(sl, btn, _shift, _dbl):
			if btn == MOUSE_BUTTON_LEFT or btn == MOUSE_BUTTON_RIGHT:
				_sell(sl.index))
		inv_grid.add_child(s2)


func _buy(i: int, many: bool) -> void:
	var stock := _stock()
	if i >= stock.size():
		return
	var it: Dictionary = stock[i]
	var price := _price(it)
	if not Items.is_gear(it):
		var lvreq := int(GameData.item_template(it["id"]).get("lv", 0))
		if lvreq > int(Game.player["level"]):
			Game.toast("Requires level %d." % lvreq, UI.BAD)
			return
	if many and not Items.is_gear(it):
		var mx := int(Game.player["gold"]) / maxi(1, price)
		if mx <= 0:
			Game.toast("Not enough gold.", UI.BAD)
			return
		Dialogs.quantity(Game.main.menu_layer, "Buy how many %s?" % Items.name_of(it), mini(mx, 99), mini(5, mx), func(n): _do_buy(it, price, n, i))
		return
	_do_buy(it, price, 1, i)


func _do_buy(it: Dictionary, price: int, n: int, i: int) -> void:
	var total := price * n
	if int(Game.player["gold"]) < total:
		Game.toast("Not enough gold.", UI.BAD)
		Sfx.play("error")
		return
	var new_it: Dictionary
	if Items.is_gear(it):
		new_it = it.duplicate(true)
		new_it.erase("artifact")
		new_it["uid"] = Items.uid()
	else:
		new_it = Items.stack(it["id"], n)
	if Items.is_gear(it) and Game.free_slots() <= 0:
		Game.toast("Your bag is full.", UI.BAD)
		Sfx.play("error")
		return
	if not Game.add_item(new_it):
		# partially added stack: only pay for what actually fit in the bag
		var added := n - int(new_it.get("qty", 0))
		if added <= 0:
			Game.toast("Your bag is full.", UI.BAD)
			Sfx.play("error")
			return
		n = added
		total = price * n
		Game.toast("Your bag is full — bought only %d." % n, UI.BAD)
	Game.add_gold(-total)
	if role in ["gear", "artifact"]:
		_stock().remove_at(i)
	Game.toast("Bought %s%s for %d gold." % [Items.name_of(it), "" if n <= 1 else " x%d" % n, total], UI.GOOD)
	Sfx.play("coin")
	refresh()


func _sell(index: int) -> void:
	var it = Game.player["inv"][index]
	if not (it is Dictionary) or it.is_empty():
		return
	var q := int(it.get("qty", 1))
	var price := Items.sell_price(it)
	if q > 1:
		Dialogs.quantity(Game.main.menu_layer, "Sell how many %s? (%dg each)" % [Items.name_of(it), price], q, q, func(n): _do_sell(index, n))
	elif Items.is_gear(it) and int(it.get("rarity", 0)) >= 3:
		Dialogs.confirm(Game.main.menu_layer, "Sell", "Sell [color=#%s]%s[/color] for %d gold?" % [Items.color_of(it).to_html(false), Items.name_of(it), price], func(): _do_sell(index, 1), "Sell")
	else:
		_do_sell(index, 1)


func _do_sell(index: int, n: int) -> void:
	var it = Game.player["inv"][index]
	if not (it is Dictionary):
		return
	var price := Items.sell_price(it)
	var part := Game.remove_at(index, n)
	if part.is_empty():
		return
	Game.add_gold(price * n)
	Sfx.play("coin")


func _cook(need: Dictionary, out: String, fee: int) -> void:
	var n := 999
	for id in need:
		n = mini(n, Game.count_item(id) / int(need[id]))
	n = mini(n, int(Game.player["gold"]) / maxi(1, fee))
	if n <= 0:
		Game.toast("You need the ingredients and %dg per dish." % fee, UI.BAD)
		Sfx.play("error")
		return
	for id in need:
		Game.remove_item(id, int(need[id]) * n)
	Game.add_gold(-fee * n)
	var it := Items.stack(out, n)
	if not Game.add_item(it):
		Game.toast("Bag full — the rest was placed at your feet.", UI.BAD)
		if is_instance_valid(Game.level_node) and is_instance_valid(Game.player_node):
			Game.level_node.drop_item(it, Game.player_node.global_position)
	Game.toast("Cooked %s x%d" % [GameData.item_template(out)["name"], n], UI.GOOD)
	Sfx.play("eat")
	refresh()


func _sell_junk() -> void:
	var total := 0
	var inv_a: Array = Game.player["inv"]
	for i in inv_a.size():
		var it = inv_a[i]
		if it is Dictionary and Items.is_gear(it) and int(it.get("rarity", 0)) == 0 and int(it.get("enchant", 0)) == 0:
			total += Items.sell_price(it)
			inv_a[i] = null
	if total > 0:
		Game.add_gold(total)
		Game.inventory_changed.emit()
		Game.toast("Sold common gear for %d gold." % total, UI.GOOD)
		Sfx.play("coin")
