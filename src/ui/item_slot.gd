class_name ItemSlot
extends Panel
## Inventory/equipment/hotbar/shop slot with drag & drop, tooltip and click handling.

signal slot_clicked(slot: ItemSlot, button: int, shift: bool, double: bool)
signal slot_dropped(slot: ItemSlot, data: Dictionary)

var source := "inv"
var index := -1
var key := ""
var item: Dictionary = {}
var draggable := true
var accepts: Callable
var placeholder: Texture2D
var price := -1
var compare_equipped := true
var icon_rect: TextureRect
var qty_label: Label
var corner_label: Label
var price_label: Label
var _size := 44
var dim := false
var highlight := false


func _init(sz: int = 44) -> void:
	_size = sz
	custom_minimum_size = Vector2(sz, sz)
	mouse_filter = Control.MOUSE_FILTER_STOP
	icon_rect = UI.icon(null, sz - 8)
	icon_rect.position = Vector2(4, 4)
	icon_rect.size = Vector2(sz - 8, sz - 8)
	add_child(icon_rect)
	qty_label = UI.outlined(UI.label("", 12, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT), 4)
	qty_label.position = Vector2(0, sz - 18)
	qty_label.size = Vector2(sz - 3, 16)
	add_child(qty_label)
	corner_label = UI.outlined(UI.label("", 11, Color("ffe9a8")), 4)
	corner_label.position = Vector2(3, 1)
	add_child(corner_label)
	price_label = UI.outlined(UI.label("", 11, Color("fee761"), HORIZONTAL_ALIGNMENT_CENTER), 4)
	price_label.position = Vector2(-10, sz - 2)
	price_label.size = Vector2(sz + 20, 14)
	add_child(price_label)
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)
	_refresh_style()


func set_item(it, pr: int = -1) -> void:
	item = it if it is Dictionary else {}
	price = pr
	if item.is_empty():
		icon_rect.texture = placeholder
		icon_rect.modulate = Color(1, 1, 1, 0.25)
		qty_label.text = ""
		corner_label.text = ""
	else:
		icon_rect.texture = Items.icon_of(item)
		icon_rect.modulate = Color(1, 1, 1, 0.4) if dim else Color.WHITE
		var q := int(item.get("qty", 1))
		qty_label.text = str(q) if q > 1 else ""
		corner_label.text = "+%d" % int(item["enchant"]) if Items.is_gear(item) and int(item.get("enchant", 0)) > 0 else ""
	price_label.text = "%dg" % price if price >= 0 and not item.is_empty() else ""
	_refresh_style()


func _refresh_style() -> void:
	var border := Color("4a4568")
	var bg := Color("12111f")
	if not item.is_empty():
		border = Items.color_of(item).darkened(0.15)
		if Items.is_gear(item) and int(item.get("rarity", 0)) >= 1:
			bg = Items.color_of(item).darkened(0.82)
	if highlight:
		border = Color("fee761")
	add_theme_stylebox_override("panel", UI.sbox(bg, border, 2, 4, 0))


func _on_enter() -> void:
	if item.is_empty():
		if key != "" and source == "equip" and Game.main:
			Game.main.tooltip.show_text("[color=#9c97b8]%s (empty)[/color]" % GameData.ItemData.SLOT_NAMES.get(key, key))
		return
	var cmp := {}
	if compare_equipped and Items.is_gear(item) and source != "equip":
		var sl := Game.slot_for(item)
		if sl != "":
			cmp = Game.player["equip"].get(sl, {})
	var txt := Items.tooltip(item, cmp)
	if price >= 0:
		txt += "\n[color=#fee761]Price: %d g[/color]" % price
	if Game.main:
		Game.main.tooltip.show_text(txt)
	highlight = true
	_refresh_style()


func _on_exit() -> void:
	if Game.main:
		Game.main.tooltip.hide_tip()
	highlight = false
	_refresh_style()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		slot_clicked.emit(self, event.button_index, event.shift_pressed, event.double_click)


func _get_drag_data(_pos: Vector2):
	if item.is_empty() or not draggable:
		return null
	var prev := UI.icon(Items.icon_of(item), 40)
	prev.modulate.a = 0.85
	var c := Control.new()
	c.add_child(prev)
	prev.position = Vector2(-20, -20)
	set_drag_preview(c)
	if Game.main:
		Game.main.tooltip.hide_tip()
	return {"type": "item", "source": source, "index": index, "key": key, "item": item}


func _can_drop_data(_pos: Vector2, data) -> bool:
	return data is Dictionary and accepts.is_valid() and accepts.call(self, data)


func _drop_data(_pos: Vector2, data) -> void:
	slot_dropped.emit(self, data)
