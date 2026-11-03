extends Node
## Mouse / display alignment while switching resolutions, window modes and scaling around.
##   godot --path . --resolution 1600x900 -- --autotest --aligntest [--shots=DIR]
## After every switch it checks that the picture covers the window exactly, that the real mouse pointer lands
## on the control drawn under it (pointer warped through the OS), and that a click there presses that control.

var fails: Array = []
var passes := 0
var shots_dir := ""
var step := 0


func ok(cond: bool, what: String) -> void:
	if cond:
		passes += 1
		print("[align] pass  ", what)
	else:
		fails.append(what)
		print("[align] FAIL  ", what)


func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	if shots_dir == "":
		return
	await _frames(3)
	step += 1
	DirAccess.make_dir_recursive_absolute(shots_dir)
	get_viewport().get_texture().get_image().save_png("%s/align_%02d_%s.png" % [shots_dir, step, name])


## The window-pixel position of a point given in view (canvas) coordinates.
func _to_window(p: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * p


## Checks that display and input agree, using `target` (a visible Button) as the thing to point at.
func _check(label: String, target: Control) -> void:
	for i in 300:  # let a running window switch finish first
		if not Settings._applying:
			break
		await get_tree().process_frame
	await _wait(0.4)
	var win := get_window()
	var vp := get_viewport()
	var ds := DisplayServer.window_get_size()
	ok(ds == win.size, "%s: window size agrees with the OS (%s / %s)" % [label, str(win.size), str(ds)])
	var xf := vp.get_final_transform()
	var vis := vp.get_visible_rect().size
	var covered := vis * xf.get_scale() + xf.origin * 2.0
	ok(absf(covered.x - win.size.x) <= xf.get_scale().x + 1.0 and absf(covered.y - win.size.y) <= xf.get_scale().y + 1.0,
		"%s: the picture fills the window exactly (%s drawn for a %s window)" % [label, str(covered), str(win.size)])
	var img_size := vp.get_texture().get_image().get_size()
	ok(img_size == win.size, "%s: rendered at window resolution (%s)" % [label, str(img_size)])
	if target == null or not is_instance_valid(target) or not target.is_visible_in_tree():
		ok(false, "%s: target control visible" % label)
		return
	var c := target.get_global_rect().get_center()
	var wp := _to_window(c)
	# 1) the real pointer, moved by the OS
	DisplayServer.warp_mouse(Vector2i(wp.round()))
	await _frames(4)
	var mp := vp.get_mouse_position()
	ok(mp.distance_to(c) < 2.5, "%s: OS pointer at window %s maps to view %s (expected %s)" % [label, str(wp.round()), str(mp.round()), str(c.round())])
	var hov := vp.gui_get_hovered_control()
	ok(hov == target or (hov != null and target.is_ancestor_of(hov)), "%s: the control under the pointer is the one drawn there (%s)" % [label, str(hov)])
	# 2) a click at that window position
	var pressed := [false]
	var cb := func(): pressed[0] = true
	if target is BaseButton:
		target.pressed.connect(cb, CONNECT_ONE_SHOT)
		for down in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = down
			ev.position = wp
			ev.global_position = wp
			Input.parse_input_event(ev)
			await _frames(2)
		ok(pressed[0], "%s: clicking it presses it" % label)
		if is_instance_valid(target) and target.pressed.is_connected(cb):
			target.pressed.disconnect(cb)


## Inside the editor's Game tab the window belongs to the editor: nothing may resize it.
func _embedded() -> void:
	var M = Game.main
	M.start_new_game("Align", "mage", 3)
	await _wait(1.5)
	var win := get_window()
	var size0 := win.size
	ok(Settings.embedded_in_editor() and not Settings.can_change_window(), "detects running inside the editor")
	await _open_display_settings()
	var sp := _settings_page()
	var disabled := 0
	for o in sp.find_children("*", "OptionButton", true, false):
		if o.disabled:
			disabled += 1
	ok(disabled >= 2, "display mode and window size are greyed out (%d)" % disabled)
	await _choose("Window size", "1024 × 768")
	await _wait(0.6)
	ok(win.size == size0, "choosing a window size leaves the editor's window alone")
	Settings.toggle_fullscreen()
	await _wait(0.6)
	ok(win.mode == Window.MODE_WINDOWED and win.size == size0, "F11 / Alt+Enter don't fight the editor either")
	await _check("embedded", _menu_target())
	Settings.window_size = Vector2i.ZERO
	Settings.window_mode = "windowed"
	Settings.save_settings()
	print("[align] ==== %d passed, %d failed" % [passes, fails.size()])
	for f in fails:
		print("[align] FAILED: ", f)
	get_tree().quit()


## Right-click menus must open right at the pointer, at any scale.
func _popup_check(label: String) -> void:
	var M = Game.main
	Game.give_item(Items.stack("pot_hp_s", 2))
	M.open_menu("inventory")
	await _wait(0.4)
	var page = null
	for c in M.window.find_children("*", "InventoryPage", true, false):
		page = c
	if page == null:
		ok(false, "%s: inventory page" % label)
		return
	var slot: Control = null
	for c in page.find_children("*", "ItemSlot", true, false):
		if c.source == "inv" and c.item is Dictionary and not c.item.is_empty():
			slot = c
			break
	if slot == null:
		ok(false, "%s: an item slot" % label)
		return
	var target := slot.get_global_rect().get_center()
	var wp := _to_window(target)
	DisplayServer.warp_mouse(Vector2i(wp.round()))
	await _frames(4)
	page._open_popup(int(slot.index))
	await _frames(3)
	var pm: PopupMenu = page.popup
	# where the menu's top-left corner is drawn, in window pixels
	var drawn: Vector2 = Vector2(pm.position - get_window().position)  # native window: screen pixels
	if pm.is_embedded():
		drawn = _to_window(Vector2(pm.position))
	print("[align] info: %s popup.position=%s embedded=%s mouse(window)=%s mouse(view)=%s" % [label, str(pm.position), str(pm.is_embedded()), str(wp.round()), str(get_viewport().get_mouse_position().round())])
	ok(drawn.distance_to(wp) < 12.0, "%s: the menu opens at the pointer (corner drawn at %s, pointer at %s)" % [label, str(drawn.round()), str(wp.round())])
	await shot("context_menu")
	pm.hide()
	M.close_all()
	await _wait(0.2)


func _menu_target() -> Control:
	var w = Game.main.window
	if w is GameWindow:
		# the window's close button "X"
		for c in w.panel.find_children("*", "Button", true, false):
			if c.text == "X":
				return c
	return null


func _settings_page() -> SettingsPage:
	var w = Game.main.window
	if w is GameMenu:
		for c in w.find_children("*", "SettingsPage", true, false):
			return c
	return null


func _open_display_settings() -> void:
	var M = Game.main
	if not (M.window is GameMenu):
		M.open_menu("settings")
		await _wait(0.3)
	M.window.show_tab("settings")
	await _wait(0.2)
	var sp := _settings_page()
	if sp and sp.section != "display":
		sp._show("display")
	await _wait(0.2)


## Picks an entry of one of the Display page's option buttons, exactly as a click in the list would.
func _choose(row_label: String, item_text: String) -> bool:
	await _open_display_settings()
	var sp := _settings_page()
	if sp == null:
		return false
	for row in sp.find_children("*", "HBoxContainer", true, false):
		var l = row.get_child(0) if row.get_child_count() > 0 else null
		if l is Label and l.text == row_label and row.get_child_count() > 1 and row.get_child(1) is OptionButton:
			var o: OptionButton = row.get_child(1)
			for i in o.item_count:
				if o.get_item_text(i).begins_with(item_text):
					o.select(i)
					o.item_selected.emit(i)
					return true
	print("[align] info: no '%s' entry starting with '%s'" % [row_label, item_text])
	return false


func run_all() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
	if "--fake-embedded" in OS.get_cmdline_user_args():
		await _embedded()
		return
	var M = Game.main
	M.start_new_game("Align", "mage", 3)
	await _wait(1.5)
	Settings.window_mode = "windowed"
	Settings.scaling = "fit"
	Settings.window_size = Vector2i.ZERO
	print("[align] info: %s" % Settings.display_info())
	await _open_display_settings()
	await _check("start", _menu_target())
	var seq := [
		["Window size", "1600 × 900"], ["Window size", "1024 × 768"], ["Window size", "1920 × 1080"],
		["Window size", "1280 × 720"], ["Window size", "2560 × 1080"], ["Window size", "Automatic"],
		["Display mode", "Fullscreen"], ["Display mode", "Windowed"], ["Display mode", "Exclusive"],
		["Display mode", "Windowed"], ["Window size", "1366 × 768"],
		["Scaling", "Pixel-perfect"], ["Window size", "1920 × 1080"], ["Window size", "2560 × 1440"],
		["Window size", "1024 × 768"], ["Display mode", "Fullscreen"], ["Display mode", "Windowed"],
		["Scaling", "Fit"], ["Window size", "1600 × 900"],
	]
	for s in seq:
		var okc := await _choose(s[0], s[1])
		if not okc:
			continue
		await _wait(0.3)
		await _open_display_settings()
		await _check("%s → %s" % [s[0], s[1]], _menu_target())
	await shot("after_switching")
	await _popup_check("context menu at %s" % str(get_window().size))
	get_viewport().gui_embed_subwindows = false  # pop-ups as separate OS windows (some platforms / settings)
	await _popup_check("native pop-up menu at %s" % str(get_window().size))
	get_viewport().gui_embed_subwindows = true
	# a window dragged to an odd size by the player
	Game.main.close_all()
	get_window().size = Vector2i(1333, 777)
	await _wait(0.5)
	M.open_menu("inventory")
	await _check("dragged to 1333×777", _menu_target())
	# the HUD and the world after all that: the hotbar slot and the aim point
	M.close_all()
	await _wait(0.4)
	var hs: Control = M.hud.skill_slots[0]
	var wp := _to_window(hs.get_global_rect().get_center())
	DisplayServer.warp_mouse(Vector2i(wp.round()))
	await _frames(4)
	ok(get_viewport().gui_get_hovered_control() == hs or hs.is_ancestor_of(get_viewport().gui_get_hovered_control()), "HUD: the pointer is over the hotbar slot drawn there")
	# world: the camera leans toward the mouse, so let it settle, then check the spot under the pointer
	var p = Game.player_node
	var aim_win := _to_window(get_viewport().get_canvas_transform() * (p.global_position + Vector2(80, -40)))
	for i in 3:
		DisplayServer.warp_mouse(Vector2i(aim_win.round()))
		await _wait(0.6)
	var under: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * (get_viewport().get_final_transform().affine_inverse() * aim_win.round())
	ok(p.get_global_mouse_position().distance_to(under) < 1.5, "world: the aim point is the spot drawn under the pointer (%s vs %s)" % [str(p.get_global_mouse_position().round()), str(under.round())])
	await shot("end")
	Settings.window_mode = "windowed"
	Settings.window_size = Vector2i.ZERO
	Settings.scaling = "fit"
	Settings.save_settings()
	print("[align] ==== %d passed, %d failed" % [passes, fails.size()])
	for f in fails:
		print("[align] FAILED: ", f)
	get_tree().quit()
