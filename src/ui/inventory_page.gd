class_name InventoryPage
extends HBoxContainer
## Equipment paper doll + bag grid with sort / filter / stack / split / discard / drag & drop.

var equip_slots: Dictionary = {}
var inv_slots: Array = []
var grid: GridContainer
var filter := "all"
var filter_btns: Dictionary = {}
var sort_opt: OptionButton
var bag_lbl: Label
var gold_lbl: Label
var expand_btn: Button
var summary: RichTextLabel
var popup: PopupMenu
var _popup_index := -1
var preview: TextureRect
var _pv_t := 0.0
var _pv_f := 0


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	_build_equipment()
	_build_bag()
	popup = PopupMenu.new()
	popup.id_pressed.connect(_on_popup)
	add_child(popup)
	Game.inventory_changed.connect(refresh)
	Game.stats_changed.connect(_refresh_summary)
	refresh()


func _build_equipment() -> void:
	var left := UI.vbox(8)
	left.custom_minimum_size.x = 300
	add_child(left)
	left.add_child(UI.label("Equipment", 18, Color("ffe9a8")))
	var doll := Control.new()
	doll.custom_minimum_size = Vector2(300, 250)
	left.add_child(doll)
	var bg := Panel.new()
	bg.position = Vector2(95, 20)
	bg.size = Vector2(110, 150)
	bg.add_theme_stylebox_override("panel", UI.sbox(Color("100f1c"), Color("3a3656"), 1, 6, 0))
	doll.add_child(bg)
	preview = UI.icon(null, 128)
	preview.position = Vector2(86, 30)
	preview.size = Vector2(128, 128)
	doll.add_child(preview)
	var layout := {"necklace": Vector2(20, 10), "weapon": Vector2(20, 70), "ring1": Vector2(20, 130),
		"armor": Vector2(232, 10), "bracelet1": Vector2(232, 70), "bracelet2": Vector2(232, 130), "ring2": Vector2(126, 186)}
	for k in layout:
		var s := ItemSlot.new(48)
		s.source = "equip"
		s.key = k
		s.position = layout[k]
		var ph = {"weapon": "sword", "armor": "armor_light", "necklace": "necklace", "ring1": "ring", "ring2": "ring",
			"bracelet1": "bracelet", "bracelet2": "bracelet"}[k]
		s.placeholder = Art.icon(ph)
		s.compare_equipped = false
		s.accepts = func(_sl, data): return data.get("type", "") == "item" and data.get("source", "") == "inv" and Game.slot_accepts(k, data["item"])
		s.slot_dropped.connect(func(sl, data): Game.equip_from_inv(int(data["index"]), sl.key))
		s.slot_clicked.connect(_on_equip_click)
		doll.add_child(s)
		var l := UI.label(GameData.ItemData.SLOT_NAMES[k], 11, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		l.position = layout[k] + Vector2(-16, 48)
		l.size = Vector2(80, 14)
		doll.add_child(l)
		equip_slots[k] = s
	summary = UI.rich("", 14)
	summary.custom_minimum_size = Vector2(300, 0)
	left.add_child(summary)
	left.add_child(UI.rich("[color=#9c97b8]Double-click: use / equip\nRight-click: item menu\nShift + click: split a stack\nDrag: move, equip, or put potions & food on the hotbar[/color]", 12))


func _build_bag() -> void:
	var right := UI.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(right)
	var top := UI.hbox(6)
	right.add_child(top)
	top.add_child(UI.label("Bag", 18, Color("ffe9a8")))
	top.add_child(UI.spacer(8))
	for f in [["all", "All"], ["gear", "Gear"], ["weapon", "Weapons"], ["armor", "Armor"], ["accessory", "Accessories"],
			["consumable", "Consumables"], ["material", "Materials"], ["special", "Special"]]:
		var key: String = f[0]
		var b := UI.button(f[1], func():
			filter = key
			refresh())
		b.toggle_mode = true
		b.add_theme_font_size_override("font_size", 13)
		filter_btns[key] = b
		top.add_child(b)
	var row2 := UI.hbox(6)
	right.add_child(row2)
	row2.add_child(UI.label("Sort:", 14, UI.DIM))
	sort_opt = OptionButton.new()
	for s in ["Type", "Rarity", "Name", "Value"]:
		sort_opt.add_item(s)
	sort_opt.focus_mode = Control.FOCUS_NONE
	row2.add_child(sort_opt)
	row2.add_child(UI.button("Sort", func(): Game.sort_inventory(["type", "rarity", "name", "value"][sort_opt.selected])))
	row2.add_child(UI.button("Stack All", func(): Game.stack_all()))
	expand_btn = UI.button("Expand Bag", func(): _expand())
	row2.add_child(expand_btn)
	grid = GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	var sc := UI.scroll(grid, Vector2(500, 430))
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(sc)
	var foot := UI.hbox(10)
	right.add_child(foot)
	foot.add_child(UI.icon(Art.icon("gold"), 18))
	gold_lbl = UI.label("", 15, Color("fee761"))
	foot.add_child(gold_lbl)
	foot.add_child(UI.spacer(20))
	bag_lbl = UI.label("", 14, UI.DIM)
	foot.add_child(bag_lbl)


func _expand() -> void:
	var cost := Game.bag_expand_cost()
	Dialogs.confirm(Game.main.menu_layer, "Expand Bag", "Add %d slots to your bag for [color=#fee761]%d gold[/color]?" % [Game.BAG_STEP, cost], func(): Game.expand_bag())


func _ensure_slots() -> void:
	var n := int(Game.player["bag_size"])
	while inv_slots.size() < n:
		var s := ItemSlot.new(46)
		s.source = "inv"
		s.index = inv_slots.size()
		s.accepts = func(_sl, data): return data.get("type", "") == "item" and data.get("source", "") in ["inv", "equip"]
		s.slot_dropped.connect(_on_inv_drop)
		s.slot_clicked.connect(_on_inv_click)
		inv_slots.append(s)
		grid.add_child(s)


func refresh() -> void:
	if Game.player.is_empty() or not is_inside_tree():
		return
	_ensure_slots()
	var inv_a: Array = Game.player["inv"]
	var used := 0
	var shown := 0
	for i in inv_slots.size():
		var it = inv_a[i] if i < inv_a.size() else null
		var s: ItemSlot = inv_slots[i]
		var d = it is Dictionary and not it.is_empty()
		if d:
			used += 1
		# filtering hides everything that does not match (and empty slots) — slots keep their real bag index
		var vis: bool = filter == "all" or (d and matches_filter(it))
		s.visible = vis and i < int(Game.player["bag_size"])
		if vis and d:
			shown += 1
		s.dim = false
		s.set_item(it if d else {})
	for k in equip_slots:
		equip_slots[k].set_item(Game.player["equip"][k])
	for f in filter_btns:
		filter_btns[f].button_pressed = f == filter
	bag_lbl.text = "Bag: %d / %d slots" % [used, int(Game.player["bag_size"])]
	if filter != "all":
		bag_lbl.text += "   •   showing %d %s" % [shown, filter_btns[filter].text.to_lower()]
	gold_lbl.text = str(int(Game.player["gold"]))
	if int(Game.player["bag_size"]) >= Game.MAX_BAG:
		expand_btn.text = "Bag at max size"
		expand_btn.disabled = true
	else:
		expand_btn.text = "Expand Bag (+%d) — %dg" % [Game.BAG_STEP, Game.bag_expand_cost()]
		expand_btn.disabled = false
	_refresh_summary()


func matches_filter(it: Dictionary) -> bool:
	match filter:
		"all":
			return true
		"weapon":
			return Items.is_gear(it) and Items.category(it) == "weapon"
		"armor":
			return Items.is_gear(it) and Items.category(it) == "armor"
		"accessory":
			return Items.is_gear(it) and Items.category(it) in ["necklace", "ring", "bracelet"]
	return Items.filter_group(it) == filter


func _refresh_summary() -> void:
	if Game.stats.is_empty() or summary == null:
		return
	var st := Game.stats
	summary.text = "[color=#ffe9a8]HP[/color] %d   [color=#8fb8ff]MP[/color] %d\n[color=#ffb08a]Phys Atk[/color] %d   [color=#c79bff]Magic Atk[/color] %d\n[color=#c0cbdc]Phys Def[/color] %d   [color=#c0cbdc]Magic Def[/color] %d\n[color=#fee761]Crit[/color] %.1f%%  x%d%%   [color=#8fe8ff]Speed[/color] x%.2f" % [
		int(st["max_hp"]), int(st["max_mp"]), int(st["patk"]), int(st["matk"]), int(st["pdef"]), int(st["mdef"]), st["crit"], int(st["crit_dmg"]), st["aspd"]]


func _process(delta: float) -> void:
	_pv_t += delta
	if _pv_t > 0.18 and not Game.player.is_empty():
		_pv_t = 0.0
		_pv_f = (_pv_f + 1) % 4
		var sf := Art.frames("char_" + Game.player["class"])
		if sf.has_animation("idle_down"):
			preview.texture = sf.get_frame_texture("idle_down", _pv_f)


func _on_inv_drop(slot: ItemSlot, data: Dictionary) -> void:
	if data["source"] == "inv":
		Game.move_slot(int(data["index"]), slot.index)
	elif data["source"] == "equip":
		var target = Game.player["inv"][slot.index]
		if target is Dictionary and not target.is_empty():
			if Items.is_gear(target) and Game.slot_accepts(data["key"], target):
				Game.equip_from_inv(slot.index, data["key"])
			return
		Game.unequip(data["key"], slot.index)
	Sfx.play("click")


func _on_inv_click(slot: ItemSlot, button: int, shift: bool, double: bool) -> void:
	if slot.item.is_empty():
		return
	if button == MOUSE_BUTTON_LEFT and double:
		Game.use_item(slot.index)
		Game.main.tooltip.hide_tip()
	elif button == MOUSE_BUTTON_LEFT and shift:
		_split(slot.index)
	elif button == MOUSE_BUTTON_RIGHT:
		_open_popup(slot.index)


func _on_equip_click(slot: ItemSlot, button: int, _shift: bool, double: bool) -> void:
	if slot.item.is_empty():
		return
	if double or button == MOUSE_BUTTON_RIGHT:
		Game.unequip(slot.key)
		Game.main.tooltip.hide_tip()


func _split(index: int) -> void:
	var it = Game.player["inv"][index]
	if not (it is Dictionary) or Items.is_gear(it) or int(it.get("qty", 1)) < 2:
		return
	var q := int(it["qty"])
	Dialogs.quantity(Game.main.menu_layer, "Split %s" % Items.name_of(it), q - 1, q / 2, func(n): Game.split_slot(index, n))


func _open_popup(index: int) -> void:
	var it: Dictionary = Game.player["inv"][index]
	_popup_index = index
	popup.clear()
	if Items.is_gear(it):
		popup.add_item("Equip", 0)
	else:
		var t := GameData.item_template(it["id"])
		if t.get("type", "") in ["consumable", "special"]:
			popup.add_item("Use", 0)
		if t.get("type", "") == "consumable":
			for i in 4:
				popup.add_item("Assign to hotkey %s" % Settings.action_text("item_%d" % (i + 1)), 10 + i)
		if int(it.get("qty", 1)) > 1:
			popup.add_item("Split stack...", 1)
	popup.add_separator()
	popup.add_item("Discard...", 2)
	popup.reset_size()
	popup.popup(Rect2i(Vector2i(get_viewport().get_mouse_position()), Vector2i(1, 1)))


func _on_popup(id: int) -> void:
	var idx := _popup_index
	var it = Game.player["inv"][idx]
	if not (it is Dictionary) or it.is_empty():
		return
	match id:
		0:
			Game.use_item(idx)
		1:
			_split(idx)
		2:
			var q := int(it.get("qty", 1))
			if q > 1:
				Dialogs.quantity(Game.main.menu_layer, "Discard how many %s?" % Items.name_of(it), q, q, func(n):
					Game.remove_at(idx, n)
					Game.toast("Discarded %s x%d" % [Items.name_of(it), n], UI.DIM))
			else:
				Dialogs.confirm(Game.main.menu_layer, "Discard", "Throw away [color=#%s]%s[/color]? This cannot be undone." % [Items.color_of(it).to_html(false), Items.name_of(it)], func():
					Game.remove_at(idx)
					Game.toast("Discarded %s" % Items.name_of(it), UI.DIM), "Discard")
		10, 11, 12, 13:
			Game.set_hot_item(id - 10, it["id"])
			Game.toast("%s assigned to hotkey %s" % [Items.name_of(it), Settings.action_text("item_%d" % (id - 9))], UI.GOOD)
