extends Node
## Resolutions, aspect ratios and fullscreen.
##   godot --path . --resolution 1920x1080 -- --autotest --restest [--pixelperfect] [--modes] [--shots=DIR]
## Checks that the HUD and every window fit inside the view at the current window size, that crisp pixels
## land on whole screen pixels, and (with --modes) switches window modes and sizes at runtime.

var fails: Array = []
var passes := 0
var shots_dir := ""
var tag := ""


func ok(cond: bool, what: String) -> void:
	if cond:
		passes += 1
		print("[res] pass  ", what)
	else:
		fails.append(what)
		print("[res] FAIL  ", what)


func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func shot(name: String) -> void:
	if shots_dir == "":
		return
	for i in 3:
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(shots_dir)
	get_viewport().get_texture().get_image().save_png("%s/res_%s_%s.png" % [shots_dir, tag, name])


## Waits until a window switch sequence started by Settings has finished (it waits for the OS between steps).
func _applied() -> void:
	for i in 300:
		if not Settings._applying:
			break
		await get_tree().process_frame


func _view() -> Rect2:
	return get_viewport().get_visible_rect()


## True if the control's on-screen rectangle lies inside the view.
func _inside(c: Control, margin: float = 0.0) -> bool:
	if c == null or not is_instance_valid(c) or not c.is_visible_in_tree():
		return true
	var r := c.get_global_rect()
	var v := _view().grow(margin)
	return v.encloses(r)


func _window_fits(what: String) -> void:
	var M = Game.main
	var w = M.window
	if w == null:
		for c in M.menu_layer.get_children():
			if c is GameWindow:
				w = c
	if w == null or not is_instance_valid(w):
		ok(false, "%s window is open" % what)
		return
	await _wait(0.25)
	ok(_inside(w.panel, 1.0), "%s window fits the view (%s in %s)" % [what, str(w.panel.get_global_rect()), str(_view().size)])


func run_all() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
	var win := get_window()
	if "--pixelperfect" in args:
		Settings.scaling = "integer"
		Settings._update_scaling()
	tag = "%dx%d%s" % [win.size.x, win.size.y, "_int" if "--pixelperfect" in args else ""]
	await _wait(0.3)
	print("[res] info: %s" % Settings.display_info())
	var vs := _view().size
	ok(vs.x >= Settings.BASE_SIZE.x - 1 and vs.y >= Settings.BASE_SIZE.y - 1 or (Settings.scaling == "integer"),
		"the game view is never smaller than the 1280x720 layout (%dx%d)" % [int(vs.x), int(vs.y)])
	var M = Game.main
	# ---- title screen
	M.go_title(false)
	await _wait(0.4)
	await shot("title")
	M.title.show_settings()
	await _wait(0.3)
	await shot("title_settings")
	M.title.show_main()
	await _wait(0.2)
	# ---- in game
	M.start_new_game("Res", "ranger", 3)
	await _wait(1.6)
	var hud = M.hud
	await _wait(0.3)
	ok(_inside(hud.status_panel), "status panel on screen")
	ok(_inside(hud.hotbar_panel), "hotbar on screen (%s)" % str(hud.hotbar_panel.get_global_rect()))
	ok(_inside(hud.mm_panel), "minimap on screen (%s)" % str(hud.mm_panel.get_global_rect()))
	ok(absf(hud.hotbar_panel.get_global_rect().get_center().x - _view().get_center().x) < 2.0, "hotbar centred")
	var mm_r: Rect2 = hud.mm_panel.get_global_rect()
	ok(absf(mm_r.end.x - _view().end.x) < 16.0, "minimap hugs the right edge")
	if Settings.crisp_pixels:
		var z: float = Game.level_node.camera.zoom.x
		var px := z * Settings.view_scale()
		ok(absf(px - round(px)) < 0.01, "crisp pixels: one art pixel = %.2f screen pixels" % px)
	await shot("hud_town")
	# ---- windows
	M.open_menu("inventory")
	await _window_fits("inventory")
	await shot("inventory")
	M.window.show_tab("settings")
	await _wait(0.3)
	await _window_fits("settings")
	await shot("settings_display")
	M.window.show_tab("map")
	await _wait(0.3)
	await _window_fits("map")
	M.close_all()
	M.open_service("guild")
	await _window_fits("guild")
	M.close_all()
	M.open_service("architect")
	await _window_fits("dungeon editor")
	await shot("editor")
	M.close_all()
	M.open_service("blacksmith")
	await _window_fits("blacksmith")
	M.close_all()
	var ns := NpcWorld.npcs()
	if not ns.is_empty():
		M.open_npc_profile(int(ns[0]["id"]))
		await _window_fits("adventurer profile")
		await shot("profile")
		M.close_all()
	await _wait(0.3)
	# ---- a dungeon
	M.enter_dungeon({"id": -3, "rank": 3, "biome": "lava", "seed": 33}, false)
	await _wait(1.8)
	ok(Game.level_node is DungeonLevel, "dungeon loads")
	await shot("dungeon")
	if "--modes" in args:
		await _modes()
	_finish()


## Window modes and sizes switched at runtime.
func _modes() -> void:
	var win := get_window()
	var scr := DisplayServer.screen_get_size(win.current_screen)
	print("[res] info: screen %s" % str(scr))
	Settings.set_window_mode("fullscreen")
	await _applied()
	await _wait(0.8)
	ok(win.mode == Window.MODE_FULLSCREEN, "fullscreen (borderless) mode")
	if win.size == scr:
		ok(true, "fullscreen fills the monitor")
	else:
		print("[res] info: the window manager resizes a fullscreen window; this X server has none (%s vs %s)" % [str(win.size), str(scr)])
	await shot("fullscreen")
	Settings.toggle_fullscreen()
	await _applied()
	await _wait(0.8)
	ok(win.mode == Window.MODE_WINDOWED and Settings.window_mode == "windowed", "F11 / Alt+Enter goes back to a window")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ENTER
	ev.keycode = KEY_ENTER
	ev.alt_pressed = true
	ev.pressed = true
	Input.parse_input_event(ev)
	await _wait(0.8)
	ok(Settings.window_mode == "fullscreen", "Alt+Enter toggles fullscreen")
	var f11 := InputEventKey.new()
	f11.physical_keycode = KEY_F11
	f11.keycode = KEY_F11
	f11.pressed = true
	Input.parse_input_event(f11)
	await _wait(0.8)
	ok(Settings.window_mode == "windowed", "F11 toggles it back")
	Settings.set_window_mode("exclusive")
	await _applied()
	await _wait(0.8)
	ok(win.mode == Window.MODE_EXCLUSIVE_FULLSCREEN, "exclusive fullscreen mode")
	Settings.set_window_mode("windowed")
	await _applied()
	await _wait(0.8)
	for r in [Vector2i(1600, 900), Vector2i(1024, 768), Vector2i(1920, 1080)]:
		if not r in Settings.resolution_options():
			continue
		Settings.window_size = r
		Settings.apply_display()
		await _applied()
		await _wait(0.6)
		ok(win.size == r, "window size %dx%d (%s)" % [r.x, r.y, str(win.size)])
		var vs := _view().size
		ok(vs.x >= 1279.0 and vs.y >= 719.0, "  view %dx%d still holds the full layout" % [int(vs.x), int(vs.y)])
		Game.main.open_menu("inventory")
		await _window_fits("  inventory at %dx%d" % [r.x, r.y])
		Game.main.close_all()
	# pixel-perfect: whole-number steps when the window is big enough, smooth fallback when it is not
	Settings.scaling = "integer"
	Settings.window_size = Vector2i(1920, 1080) if Vector2i(1920, 1080) in Settings.resolution_options() else Vector2i(1280, 720)
	Settings.apply_display()
	await _applied()
	await _wait(0.6)
	var s1 := Settings.view_scale()
	var xf := get_viewport().get_final_transform()
	ok(Settings.integer_scaling_active() and absf(s1 - round(s1)) < 0.01, "pixel-perfect scaling at %s: whole-number scale (×%.2f)" % [str(win.size), s1])
	ok(xf.origin.length() < 1.0 and absf(_view().size.x * s1 - win.size.x) < s1 + 0.5, "  fills the whole window (no black bars, view %s)" % str(_view().size))
	Game.main.open_menu("inventory")
	await _window_fits("  inventory with pixel-perfect scaling")
	await shot("pixel_perfect")
	Game.main.close_all()
	Settings.window_size = Vector2i(1024, 768)
	Settings.apply_display()
	await _applied()
	await _wait(0.6)
	ok(not Settings.integer_scaling_active() and _view().size.x >= 1279.0, "  a window smaller than the layout falls back to smooth scaling so everything fits")
	# a window dragged to an odd size is remembered
	Settings.scaling = "fit"
	Settings.window_size = Vector2i.ZERO
	Settings.apply_display()
	await _applied()
	await _wait(0.5)
	win.size = Vector2i(1500, 777)
	await _wait(1.2)
	ok(Settings.window_size == Vector2i(1500, 777), "a size you drag the window to is remembered (%s)" % str(Settings.window_size))
	var cf := ConfigFile.new()
	cf.load(Settings.PATH)
	ok(cf.get_value("video", "window_size", Vector2i.ZERO) == Vector2i(1500, 777), "  and saved")
	await _wait(0.3)
	await shot("odd_size")
	# leave the settings as a player would find them
	Settings.window_size = Vector2i.ZERO
	Settings.window_mode = "windowed"
	Settings.scaling = "fit"
	Settings.save_settings()


func _finish() -> void:
	print("[res] ==== %d passed, %d failed  (%s)" % [passes, fails.size(), tag])
	for f in fails:
		print("[res] FAILED: ", f)
	get_tree().quit()
