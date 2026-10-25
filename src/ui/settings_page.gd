class_name SettingsPage
extends HBoxContainer
## Hotkey rebinding (skills, consumables, everything) + audio / video / gameplay options.

var bind_list: VBoxContainer
var capture_action := ""
var capture_idx := 0
var capture_lbl: Label


func _ready() -> void:
	add_theme_constant_override("separation", 20)
	var left := UI.vbox(6)
	left.custom_minimum_size.x = 560
	add_child(left)
	left.add_child(UI.label("Hotkeys", 18, Color("ffe9a8")))
	capture_lbl = UI.label("Click a key box, then press the new key or mouse button (Esc to cancel).", 13, UI.DIM)
	left.add_child(capture_lbl)
	bind_list = UI.vbox(4)
	left.add_child(UI.scroll(bind_list, Vector2(560, 430)))
	left.add_child(UI.button("Reset all hotkeys to default", func():
		Settings.reset_binds()
		_build_binds()))
	var right := UI.vbox(10)
	right.custom_minimum_size.x = 360
	add_child(right)
	right.add_child(UI.label("Audio", 18, Color("ffe9a8")))
	right.add_child(_slider("Master volume", Settings.master_volume, func(v):
		Settings.master_volume = v
		Settings.apply()
		Settings.save_settings()))
	right.add_child(_slider("Sound effects", Settings.sfx_volume, func(v):
		Settings.sfx_volume = v
		Settings.save_settings()))
	right.add_child(_slider("Music", Settings.music_volume, func(v):
		Settings.music_volume = v
		Settings.save_settings()))
	right.add_child(UI.sep())
	right.add_child(UI.label("Video & Gameplay", 18, Color("ffe9a8")))
	right.add_child(_check("Fullscreen", Settings.fullscreen, func(on):
		Settings.fullscreen = on
		Settings.apply()
		Settings.save_settings()))
	right.add_child(_check("Damage numbers", Settings.damage_numbers, func(on):
		Settings.damage_numbers = on
		Settings.save_settings()))
	right.add_child(_check("Screen shake", Settings.screen_shake, func(on):
		Settings.screen_shake = on
		Settings.save_settings()))
	right.add_child(_check("Show minimap", Settings.show_minimap, func(on):
		Settings.show_minimap = on
		Settings.save_settings()))
	var zs := _slider("Camera zoom (mouse wheel in game)", (Settings.camera_zoom - 2.0) / 2.5, func(v):
		Settings.camera_zoom = 2.0 + v * 2.5
		Settings.save_settings())
	right.add_child(zs)
	_build_binds()


func _slider(label: String, value: float, cb: Callable) -> Control:
	var v := UI.vbox(2)
	v.add_child(UI.label(label, 14))
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.01
	s.value = value
	s.custom_minimum_size.x = 320
	s.value_changed.connect(cb)
	v.add_child(s)
	return v


func _check(label: String, on: bool, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = label
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(cb)
	return c


func _build_binds() -> void:
	for c in bind_list.get_children():
		c.queue_free()
	for a in Settings.ACTIONS:
		var row := UI.hbox(8)
		var l := UI.label(Settings.ACTIONS[a][0], 14)
		l.custom_minimum_size.x = 220
		row.add_child(l)
		for idx in 2:
			var bl: Array = Settings.binds.get(a, [])
			var txt := Settings.binding_text(bl[idx]) if idx < bl.size() else "-"
			if capture_action == a and capture_idx == idx:
				txt = "Press a key..."
			var aa: String = a
			var ii: int = idx
			var b := UI.button(txt, func(): _start_capture(aa, ii), 150)
			row.add_child(b)
		bind_list.add_child(row)


func _start_capture(a: String, idx: int) -> void:
	capture_action = a
	capture_idx = idx
	capture_lbl.text = "Press a new key / mouse button for '%s'..." % Settings.ACTIONS[a][0]
	_build_binds()


func _input(event: InputEvent) -> void:
	if capture_action == "" or not is_visible_in_tree():
		return
	var b := []
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE and capture_action != "menu":
			capture_action = ""
			capture_lbl.text = "Cancelled."
			_build_binds()
			get_viewport().set_input_as_handled()
			return
		b = Settings.binding_from_event(event)
	elif event is InputEventMouseButton and event.pressed and event.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		b = Settings.binding_from_event(event)
	if b.is_empty():
		return
	get_viewport().set_input_as_handled()
	Settings.set_binding(capture_action, capture_idx, b)
	capture_lbl.text = "Bound %s to %s." % [Settings.ACTIONS[capture_action][0], Settings.binding_text(b)]
	capture_action = ""
	_build_binds()
