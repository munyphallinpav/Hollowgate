class_name SellFilterDialog
extends ColorRect
## "Sell by filter" (opened from any shop): pick item types, rarities, item level and gold value per item,
## see exactly what would be sold and for how much, click items to keep them this time, then sell in one go.
## The filter is remembered per character.

var f: Dictionary
var exclude: Dictionary = {}  # uid -> true: kept this time
var preview_grid: GridContainer
var summary_lbl: RichTextLabel
var sell_btn: Button
var _plan: Dictionary = {}
var _building := false
var _widgets: Dictionary = {}


func _init() -> void:
	f = BulkSell.saved_filter()
	color = Color(0, 0, 0, 0.55)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UI.theme()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1000, 0)
	center.add_child(panel)
	var v := UI.vbox(8)
	panel.add_child(v)
	var top := UI.hbox(8)
	v.add_child(top)
	var t := UI.label("Sell by filter", 20, Color("ffe9a8"))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(UI.button("X", close, 36))
	var cols := UI.hbox(18)
	v.add_child(cols)
	cols.add_child(_filters())
	cols.add_child(_preview_side())
	var h := UI.hbox(10)
	h.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(h)
	h.add_child(UI.button("Reset filters", func():
		f = BulkSell.default_filter()
		exclude.clear()
		_sync_widgets()
		_changed(), 150))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	h.add_child(UI.button("Cancel", close, 110))
	sell_btn = UI.button("Sell", _sell_pressed, 280)
	h.add_child(sell_btn)
	Game.inventory_changed.connect(_refresh_preview)
	_refresh_preview()


func close() -> void:
	if Game.main:
		Game.main.tooltip.hide_tip()
	queue_free()


# ------------------------------------------------------------------ filters
func _section(text: String) -> Label:
	return UI.label(text, 15, Color("ffe9a8"))


func _check(text: String, on: bool, col: Color, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_color_override("font_color", col)
	c.add_theme_color_override("font_pressed_color", col)
	c.add_theme_color_override("font_hover_color", col.lightened(0.2))
	c.toggled.connect(func(v: bool):
		if not _building:
			cb.call(v)
			_changed())
	return c


func _spin(value: int, lo: int, hi: int, step: int, cb: Callable, w: int = 96) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size.x = w
	s.value_changed.connect(func(x: float):
		if not _building:
			cb.call(int(x))
			_changed())
	return s


func _filters() -> Control:
	var left := UI.vbox(6)
	left.custom_minimum_size.x = 450
	# types
	left.add_child(_section("Item types"))
	var tg := GridContainer.new()
	tg.columns = 3
	left.add_child(tg)
	for ty in BulkSell.TYPES:
		var key: String = ty
		var c := _check(BulkSell.TYPE_NAMES[ty], bool(f["types"].get(ty, false)), UI.TEXT, func(on: bool): f["types"][key] = on)
		_widgets["type_" + ty] = c
		tg.add_child(c)
	# rarity
	var rh := UI.hbox(6)
	left.add_child(rh)
	rh.add_child(_section("Rarity (gear)"))
	for pr in [["Common only", 0], ["Up to Uncommon", 1], ["Up to Rare", 2], ["All", 5]]:
		var upto: int = pr[1]
		var b := UI.button(pr[0], func():
			for i in f["rarities"].size():
				f["rarities"][i] = i <= upto
			_sync_widgets()
			_changed())
		b.add_theme_font_size_override("font_size", 12)
		rh.add_child(b)
	var rg := GridContainer.new()
	rg.columns = 3
	left.add_child(rg)
	for i in GameData.ItemData.RARITIES.size():
		var ri: int = i
		var r: Dictionary = GameData.ItemData.RARITIES[i]
		var c2 := _check(r["name"], bool(f["rarities"][i]), r["color"], func(on: bool): f["rarities"][ri] = on)
		_widgets["rar_%d" % i] = c2
		rg.add_child(c2)
	# level
	left.add_child(_section("Item level (gear)"))
	var lh := UI.hbox(6)
	left.add_child(lh)
	lh.add_child(UI.label("from", 13, UI.DIM))
	var lmin := _spin(int(f["lv_min"]), 1, 100, 1, func(x: int): f["lv_min"] = x)
	_widgets["lv_min"] = lmin
	lh.add_child(lmin)
	lh.add_child(UI.label("to", 13, UI.DIM))
	var lmax := _spin(int(f["lv_max"]), 1, 100, 1, func(x: int): f["lv_max"] = x)
	_widgets["lv_max"] = lmax
	lh.add_child(lmax)
	var below := UI.button("Below my level", func():
		f["lv_min"] = 1
		f["lv_max"] = maxi(1, int(Game.player["level"]) - 1)
		_sync_widgets()
		_changed())
	below.add_theme_font_size_override("font_size", 12)
	lh.add_child(below)
	# value
	left.add_child(_section("Gold value per item"))
	var gh := UI.hbox(6)
	left.add_child(gh)
	gh.add_child(UI.label("from", 13, UI.DIM))
	var pmin := _spin(int(f["price_min"]), 0, 999999, 10, func(x: int): f["price_min"] = x, 110)
	_widgets["price_min"] = pmin
	gh.add_child(pmin)
	gh.add_child(UI.label("to", 13, UI.DIM))
	var pmax := _spin(int(f["price_max"]), 0, 999999, 10, func(x: int): f["price_max"] = x, 110)
	_widgets["price_max"] = pmax
	gh.add_child(pmax)
	gh.add_child(UI.label("gold  (0 = no limit)", 12, UI.DIM))
	# keep rules
	left.add_child(_section("Always keep"))
	var kg := GridContainer.new()
	kg.columns = 2
	left.add_child(kg)
	for pr2 in [["keep_upgrades", "Gear better than what I wear"], ["keep_enchanted", "Enchanted gear (+1 and up)"],
			["keep_uniques", "Boss unique items"], ["keep_quest", "Materials my quests need"]]:
		var k: String = pr2[0]
		var c3 := _check(pr2[1], bool(f[k]), UI.TEXT, func(on: bool): f[k] = on)
		_widgets[k] = c3
		kg.add_child(c3)
	var sh := UI.hbox(6)
	left.add_child(sh)
	sh.add_child(UI.label("At least", 13))
	var ks := _spin(int(f["keep_stack"]), 0, 999, 1, func(x: int): f["keep_stack"] = x, 80)
	_widgets["keep_stack"] = ks
	sh.add_child(ks)
	sh.add_child(UI.label("of each potion, food and material", 13))
	# gold goal
	left.add_child(_section("How much to sell"))
	var oh := UI.hbox(6)
	left.add_child(oh)
	oh.add_child(UI.label("Only raise", 13))
	var goal := _spin(int(f["gold_goal"]), 0, 9999999, 100, func(x: int): f["gold_goal"] = x, 120)
	_widgets["gold_goal"] = goal
	oh.add_child(goal)
	oh.add_child(UI.label("gold (cheapest first; 0 = sell everything that matches)", 12, UI.DIM))
	left.add_child(UI.rich("[color=#9c97b8]Locked items (padlock — right-click an item in your bag to lock it) and equipped gear are never sold. Tomes, scrolls and dungeon crystals are never sold by filter.[/color]", 12))
	return left


## Puts the filter's values back into the controls (after a preset or a reset).
func _sync_widgets() -> void:
	_building = true
	for ty in BulkSell.TYPES:
		_widgets["type_" + ty].button_pressed = bool(f["types"].get(ty, false))
	for i in GameData.ItemData.RARITIES.size():
		_widgets["rar_%d" % i].button_pressed = bool(f["rarities"][i])
	for k in ["lv_min", "lv_max", "price_min", "price_max", "keep_stack", "gold_goal"]:
		_widgets[k].value = int(f[k])
	for k in ["keep_upgrades", "keep_enchanted", "keep_uniques", "keep_quest"]:
		_widgets[k].button_pressed = bool(f[k])
	_building = false


func _changed() -> void:
	if int(f["lv_min"]) > int(f["lv_max"]):
		f["lv_max"] = f["lv_min"]
		_sync_widgets()
	BulkSell.save_filter(f)
	_refresh_preview()


# ------------------------------------------------------------------ preview
func _preview_side() -> Control:
	var right := UI.vbox(6)
	right.custom_minimum_size.x = 500
	summary_lbl = UI.rich("", 15)
	summary_lbl.custom_minimum_size = Vector2(500, 44)
	right.add_child(summary_lbl)
	preview_grid = GridContainer.new()
	preview_grid.columns = 9
	preview_grid.add_theme_constant_override("h_separation", 5)
	preview_grid.add_theme_constant_override("v_separation", 18)
	right.add_child(UI.scroll(preview_grid, Vector2(500, 390)))
	right.add_child(UI.label("Click an item to keep it this time (click again to sell it after all).", 12, UI.DIM))
	return right


func _refresh_preview() -> void:
	if not is_inside_tree() and preview_grid == null:
		return
	_plan = BulkSell.plan(f, exclude)
	for c in preview_grid.get_children():
		c.queue_free()
	# what will be sold, then what the player chose to keep
	var shown := {}
	for ln in _plan["lines"]:
		var it: Dictionary = ln[1]
		shown[int(it.get("uid", -1))] = true
		preview_grid.add_child(_slot(it, int(ln[2]), int(ln[3]), false))
	for i in Game.player["inv"].size():
		var it2 = Game.player["inv"][i]
		if it2 is Dictionary and not it2.is_empty() and exclude.has(int(it2.get("uid", -1))) and not shown.has(int(it2.get("uid", -1))):
			preview_grid.add_child(_slot(it2, int(it2.get("qty", 1)), 0, true))
	var n: int = _plan["count"]
	var g: int = _plan["gold"]
	if n == 0:
		summary_lbl.text = "[color=#9c97b8]Nothing in your bag matches these filters.[/color]"
	else:
		var goal_txt := ""
		if int(f["gold_goal"]) > 0:
			goal_txt = "  [color=#9c97b8](target %d gold%s)[/color]" % [int(f["gold_goal"]), "" if g >= int(f["gold_goal"]) else " — not enough matching items"]
		summary_lbl.text = "Will sell [b]%d[/b] item%s for [color=#fee761][b]%d gold[/b][/color]%s" % [n, "" if n == 1 else "s", g, goal_txt]
	var notes := []
	var kt := BulkSell.kept_text(_plan.get("kept", {}))
	if kt != "":
		notes.append("Your rules keep: " + kt)
	if not exclude.is_empty():
		notes.append("%d kept by you this time" % exclude.size())
	if not notes.is_empty():
		summary_lbl.text += "\n[color=#9c97b8]%s[/color]" % "  •  ".join(notes)
	sell_btn.text = "Sell %d item%s for %d gold" % [n, "" if n == 1 else "s", g] if n > 0 else "Nothing to sell"
	sell_btn.disabled = n == 0


func _slot(it: Dictionary, qty: int, gold: int, kept: bool) -> ItemSlot:
	var s := ItemSlot.new(46)
	s.source = "view"
	s.draggable = false
	var shown_it := it
	if qty != int(it.get("qty", 1)):
		shown_it = it.duplicate()
		shown_it["qty"] = qty  # e.g. only part of a stack is sold
	s.dim = kept
	s.set_item(shown_it, gold if not kept else -1)
	if kept:
		s.price_label.text = "kept"
		s.price_label.add_theme_color_override("font_color", UI.DIM)
	var uid := int(it.get("uid", -1))
	s.slot_clicked.connect(func(_sl, btn, _shift, _dbl):
		if btn != MOUSE_BUTTON_LEFT:
			return
		if exclude.has(uid):
			exclude.erase(uid)
		else:
			exclude[uid] = true
		Sfx.play("click")
		_refresh_preview.call_deferred())
	return s


func _sell_pressed() -> void:
	var p := BulkSell.plan(f, exclude)
	if int(p["count"]) <= 0:
		return
	var go := func():
		var res := BulkSell.sell(f, exclude)
		exclude.clear()
		if int(res[0]) > 0:
			Game.toast("Sold %d item%s for %d gold." % [int(res[0]), "" if int(res[0]) == 1 else "s", int(res[1])], UI.GOOD)
			Sfx.play("coin")
		close()
	if int(p["best_rarity"]) >= 3 or int(p["count"]) >= 20 or int(p["gold"]) >= 5000:
		var best := ""
		if int(p["best_rarity"]) >= 3:
			var r: Dictionary = GameData.ItemData.RARITIES[int(p["best_rarity"])]
			best = "\nIncludes [color=#%s]%s[/color] gear." % [r["color"].to_html(false), r["name"]]
		Dialogs.confirm(self, "Sell by filter", "Sell %d items for %d gold?%s\nThis cannot be undone." % [int(p["count"]), int(p["gold"]), best], go, "Sell")
	else:
		go.call()
