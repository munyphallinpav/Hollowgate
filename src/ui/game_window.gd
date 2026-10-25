class_name GameWindow
extends Control
## Centered modal window frame with a title bar and close button.

signal closed

var panel: PanelContainer
var body: VBoxContainer
var title_lbl: Label
var key := ""


func _init(title: String, size_px: Vector2, k: String = "") -> void:
	key = k
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UI.theme()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = size_px
	center.add_child(panel)
	var v := UI.vbox(8)
	panel.add_child(v)
	var top := UI.hbox(8)
	v.add_child(top)
	title_lbl = UI.outlined(UI.label(title, 22, Color("ffe9a8")), 4)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_lbl)
	var hint := UI.label("Esc to close", 12, UI.DIM)
	top.add_child(hint)
	top.add_child(UI.button("X", func(): close(), 36))
	body = UI.vbox(8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)


func close() -> void:
	if Game.main:
		Game.main.tooltip.hide_tip()
	closed.emit()
	queue_free()
