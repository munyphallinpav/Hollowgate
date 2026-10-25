class_name Tooltip
extends CanvasLayer
## Rich tooltip that follows the mouse.

var panel: PanelContainer
var text: RichTextLabel
var _visible := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = PanelContainer.new()
	panel.theme = UI.theme()
	panel.add_theme_stylebox_override("panel", UI.sbox(Color(0.07, 0.065, 0.12, 0.97), UI.GOLD.darkened(0.2), 1, 3, 9))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text = UI.rich("", 14)
	text.custom_minimum_size = Vector2(260, 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(text)
	add_child(panel)
	panel.visible = false


func show_text(bb: String, width: int = 280) -> void:
	text.custom_minimum_size.x = width
	text.text = bb
	panel.reset_size()
	panel.visible = true
	_visible = true
	_place()


func hide_tip() -> void:
	panel.visible = false
	_visible = false


func _process(_d: float) -> void:
	if _visible:
		_place()


func _place() -> void:
	var vp := panel.get_viewport_rect().size
	var m := panel.get_viewport().get_mouse_position()
	var s := panel.size
	var p := m + Vector2(18, 14)
	if p.x + s.x > vp.x - 4:
		p.x = m.x - s.x - 12
	if p.y + s.y > vp.y - 4:
		p.y = vp.y - s.y - 4
	panel.position = p.max(Vector2(4, 4))
