class_name SettingsPage
extends VBoxContainer
## Settings in three sections: Display (window mode, window size, monitor, scaling, vsync, frame cap),
## Audio & Gameplay, and Hotkeys (rebind everything).

var section := "display"
var tab_row: HBoxContainer
var holder: Control
var bind_list: VBoxContainer
var capture_action := ""
var capture_idx := 0
var capture_lbl: Label
var info_lbl: Label
var size_opt: OptionButton
var _info_t := 0.0
static var last_section := "display"


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	section = last_section
	tab_row = UI.hbox(6)
	add_child(tab_row)
	holder = MarginContainer.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(holder)
	_show(section)
	Settings.display_changed.connect(_on_settings_changed)


func _show(sec: String) -> void:
	section = sec
	last_section = sec
	capture_action = ""
	for c in tab_row.get_children():
		c.queue_free()
	for pair in [["display", "Display"], ["audio", "Audio & Gameplay"], ["keys", "Hotkeys"]]:
		var key: String = pair[0]
		var b := UI.button(pair[1], func(): _show(key), 170)
		b.focus_mode = Control.FOCUS_NONE
		if key == sec:
			b.add_theme_stylebox_override("normal", UI.sbox(Color("3d3a62"), UI.GOLD, 1, 3, 8))
			b.add_theme_color_override("font_color", Color("ffe9a8"))
		tab_row.add_child(b)
	for c in holder.get_children():
		c.queue_free()
	info_lbl = null
	size_opt = null
	match sec:
		"display":
			holder.add_child(_display_page())
		"audio":
			holder.add_child(_audio_page())
		_:
			holder.add_child(_keys_page())


func _process(delta: float) -> void:
	_info_t -= delta
	if _info_t <= 0.0 and info_lbl and is_instance_valid(info_lbl):
		_info_t = 0.5
		info_lbl.text = Settings.display_info()


func _on_settings_changed() -> void:
	# F11 / Alt+Enter while this page is open: show the new state
	if section == "display" and is_inside_tree():
		_show.call_deferred("display")


# ------------------------------------------------------------------ display
func _display_page() -> Control:
	var cols := UI.hbox(30)
	var left := UI.vbox(10)
	left.custom_minimum_size.x = 460
	cols.add_child(left)
	left.add_child(UI.label("Display", 18, Color("ffe9a8")))
	# window mode
	var mode := _option(Settings.WINDOW_MODE_NAMES, Settings.WINDOW_MODES.find(Settings.window_mode), func(i: int):
		Settings.set_window_mode(Settings.WINDOW_MODES[i]))
	left.add_child(_row("Display mode", mode))
	# window size
	var opts := Settings.resolution_options()
	var names := ["Automatic (%d × %d)" % [Settings.windowed_size().x, Settings.windowed_size().y]]
	var sel := 0
	for r in opts:
		var tag := ""
		var ratio := _ratio(r)
		if ratio != "":
			tag = "  (%s)" % ratio
		names.append("%d × %d%s" % [r.x, r.y, tag])
		if Settings.window_size == r:
			sel = names.size() - 1
	if Settings.window_size != Vector2i.ZERO and sel == 0:
		names.append("%d × %d  (custom)" % [Settings.window_size.x, Settings.window_size.y])
		sel = names.size() - 1
	size_opt = _option(names, sel, func(i: int):
		if i == 0:
			Settings.window_size = Vector2i.ZERO
		elif i - 1 < opts.size():
			Settings.window_size = opts[i - 1]
		Settings.apply_display()
		Settings.save_settings())
	size_opt.disabled = Settings.window_mode != "windowed" or not Settings.can_change_window()
	mode.disabled = not Settings.can_change_window()
	left.add_child(_row("Window size", size_opt))
	if Settings.embedded_in_editor():
		var note := UI.label("The game is running inside the Godot editor's Game tab, so the editor controls the window size and fullscreen. Run the exported game, or turn off \"Embed Game\" in the Game tab, to use these options.", 12, Color("ffb347"))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size.x = 450
		left.add_child(note)
	elif Settings.window_mode != "windowed":
		left.add_child(UI.label("Fullscreen always uses the monitor's own resolution.", 12, UI.DIM))
	# monitor
	var n_scr := DisplayServer.get_screen_count() if Settings._display_ok() else 1
	if n_scr > 1:
		var mnames := ["Current monitor"]
		for i in n_scr:
			var ss := DisplayServer.screen_get_size(i)
			mnames.append("Monitor %d (%d × %d)" % [i + 1, ss.x, ss.y])
		var mon := _option(mnames, Settings.monitor + 1, func(i: int):
			Settings.monitor = i - 1
			Settings.apply_display()
			Settings.save_settings())
		mon.disabled = not Settings.can_change_window()
		left.add_child(_row("Monitor", mon))
	# scaling
	var sc := _option(Settings.SCALING_NAMES, Settings.SCALINGS.find(Settings.scaling), func(i: int):
		Settings.scaling = Settings.SCALINGS[i]
		Settings.apply_display()
		Settings.save_settings())
	left.add_child(_row("Scaling", sc))
	left.add_child(_check("Crisp pixel art (world pixels snap to whole screen pixels)", Settings.crisp_pixels, func(on):
		Settings.crisp_pixels = on
		Settings.save_settings()))
	left.add_child(_check("VSync (no tearing)", Settings.vsync, func(on):
		Settings.vsync = on
		Settings.apply_display()
		Settings.save_settings()))
	var fps_names := []
	for f in Settings.FPS_CAPS:
		fps_names.append("Unlimited" if f == 0 else "%d FPS" % f)
	var fps := _option(fps_names, maxi(0, Settings.FPS_CAPS.find(Settings.max_fps)), func(i: int):
		Settings.max_fps = Settings.FPS_CAPS[i]
		Settings.apply_display()
		Settings.save_settings())
	left.add_child(_row("Frame rate limit", fps))
	# help
	var right := UI.vbox(10)
	right.custom_minimum_size.x = 420
	cols.add_child(right)
	right.add_child(UI.label("Your screen", 18, Color("ffe9a8")))
	info_lbl = UI.label(Settings.display_info(), 13, Color("8fe8ff"))
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_lbl.custom_minimum_size.x = 400
	right.add_child(info_lbl)
	var help := UI.rich("[color=#9c97b8]Any resolution and aspect ratio works — 16:9, 16:10, 4:3, ultrawide 21:9 or a window dragged to any size. The game is laid out for a 1280 × 720 view and scales up to fill the screen; on wider or taller screens you simply see more of the world and the HUD stays at the edges.\n\n[b]Fit to window[/b] uses every pixel of the screen. [b]Pixel-perfect[/b] scales only in whole steps (×1, ×2, ×3) for perfectly even pixels; on screens between steps it uses the lower step and shows a bigger view instead (more of the world, smaller text) — for example ×1 on a 1920 × 1080 screen, ×2 on 2560 × 1440, ×3 on 4K.\n\n[b]%s[/b] or [b]Alt+Enter[/b] switches between window and fullscreen at any time. Your window size is remembered when you resize the window yourself.[/color]" % Settings.action_text("toggle_fullscreen"), 13)
	help.custom_minimum_size.x = 400
	right.add_child(help)
	return cols


func _ratio(r: Vector2i) -> String:
	for pr in [[16, 9, "16:9"], [16, 10, "16:10"], [4, 3, "4:3"], [5, 4, "5:4"], [64, 27, "21:9"], [43, 18, "21:9"]]:
		if r.x * int(pr[1]) == r.y * int(pr[0]):
			return pr[2]
	return ""


func _row(label: String, ctrl: Control) -> Control:
	var h := UI.hbox(10)
	var l := UI.label(label, 14)
	l.custom_minimum_size.x = 150
	h.add_child(l)
	h.add_child(ctrl)
	return h


func _option(items: Array, selected: int, cb: Callable) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.custom_minimum_size.x = 290
	for it in items:
		o.add_item(str(it))
	o.selected = clampi(selected, 0, items.size() - 1)
	o.item_selected.connect(cb)
	return o


# ------------------------------------------------------------------ audio & gameplay
func _audio_page() -> Control:
	var cols := UI.hbox(40)
	var left := UI.vbox(10)
	left.custom_minimum_size.x = 380
	cols.add_child(left)
	left.add_child(UI.label("Audio", 18, Color("ffe9a8")))
	left.add_child(_slider("Master volume", Settings.master_volume, func(v):
		Settings.master_volume = v
		Settings.apply()
		Settings.save_settings()))
	left.add_child(_slider("Sound effects", Settings.sfx_volume, func(v):
		Settings.sfx_volume = v
		Settings.save_settings()))
	left.add_child(_slider("Music", Settings.music_volume, func(v):
		Settings.music_volume = v
		Settings.save_settings()))
	var right := UI.vbox(10)
	right.custom_minimum_size.x = 380
	cols.add_child(right)
	right.add_child(UI.label("Gameplay", 18, Color("ffe9a8")))
	right.add_child(_check("Damage numbers", Settings.damage_numbers, func(on):
		Settings.damage_numbers = on
		Settings.save_settings()))
	right.add_child(_check("Screen shake", Settings.screen_shake, func(on):
		Settings.screen_shake = on
		Settings.save_settings()))
	right.add_child(_check("Show minimap", Settings.show_minimap, func(on):
		Settings.show_minimap = on
		Settings.save_settings()))
	right.add_child(_slider("Camera zoom (mouse wheel in game)", (Settings.camera_zoom - 2.0) / 2.5, func(v):
		Settings.camera_zoom = 2.0 + v * 2.5
		Settings.save_settings()))
	return cols


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


# ------------------------------------------------------------------ hotkeys
func _keys_page() -> Control:
	var v := UI.vbox(6)
	capture_lbl = UI.label("Click a key box, then press the new key or mouse button (Esc to cancel).", 13, UI.DIM)
	v.add_child(capture_lbl)
	bind_list = UI.vbox(4)
	var sc := UI.scroll(bind_list, Vector2(620, 400))
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	v.add_child(UI.button("Reset all hotkeys to default", func():
		Settings.reset_binds()
		_build_binds()))
	_build_binds()
	return v


func _build_binds() -> void:
	if bind_list == null or not is_instance_valid(bind_list):
		return
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
