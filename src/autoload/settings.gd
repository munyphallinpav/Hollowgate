extends Node
## Settings + rebindable hotkeys + display (window mode, window size, monitor, scaling, vsync, frame cap).
## Persisted in user://settings.cfg
##
## Any resolution and aspect ratio works: the game is laid out for a 1280x720 view and scales to fill the window,
## and on wider or taller screens the view simply grows (you see more of the world, the HUD sticks to the edges).

signal changed
signal display_changed  # window mode / size / scaling changed (the settings page refreshes itself)

const PATH := "user://settings.cfg"

## action -> [label, [default bindings]]  binding = [type, code]
const ACTIONS := {
	"move_up": ["Move Up", [["key", KEY_W], ["key", KEY_UP]]],
	"move_down": ["Move Down", [["key", KEY_S], ["key", KEY_DOWN]]],
	"move_left": ["Move Left", [["key", KEY_A], ["key", KEY_LEFT]]],
	"move_right": ["Move Right", [["key", KEY_D], ["key", KEY_RIGHT]]],
	"attack": ["Attack", [["mouse", MOUSE_BUTTON_LEFT]]],
	"dash": ["Dash", [["key", KEY_SPACE], ["key", KEY_SHIFT]]],
	"interact": ["Interact", [["key", KEY_E], ["key", KEY_F]]],
	"skill_1": ["Skill Slot 1", [["key", KEY_1]]],
	"skill_2": ["Skill Slot 2", [["key", KEY_2]]],
	"skill_3": ["Skill Slot 3", [["key", KEY_3]]],
	"skill_4": ["Skill Slot 4", [["key", KEY_4], ["mouse", MOUSE_BUTTON_RIGHT]]],
	"item_1": ["Consumable Slot 1", [["key", KEY_Z]]],
	"item_2": ["Consumable Slot 2", [["key", KEY_X]]],
	"item_3": ["Consumable Slot 3", [["key", KEY_C]]],
	"item_4": ["Consumable Slot 4", [["key", KEY_V]]],
	"teleport_town": ["Teleport to Town", [["key", KEY_T]]],
	"open_inventory": ["Inventory", [["key", KEY_I], ["key", KEY_TAB]]],
	"open_character": ["Character", [["key", KEY_P]]],
	"open_skills": ["Skills", [["key", KEY_K]]],
	"open_quests": ["Quests", [["key", KEY_J]]],
	"open_map": ["World Map", [["key", KEY_M]]],
	"open_editor": ["Dungeon Editor", [["key", KEY_B]]],
	"menu": ["Menu / Close", [["key", KEY_ESCAPE]]],
	"toggle_fullscreen": ["Toggle Fullscreen", [["key", KEY_F11]]],
}

const BASE_SIZE := Vector2i(1280, 720)  # the layout size the game is designed for
const MIN_WINDOW := Vector2i(800, 450)
const WINDOW_MODES := ["windowed", "fullscreen", "exclusive"]
const WINDOW_MODE_NAMES := ["Windowed", "Fullscreen (borderless)", "Exclusive fullscreen"]
const SCALINGS := ["fit", "integer"]
const SCALING_NAMES := ["Fit to window (smooth)", "Pixel-perfect (whole-number steps)"]
const FPS_CAPS := [0, 30, 60, 75, 120, 144, 165, 240]
## Common window sizes (16:9, 16:10, 4:3, 5:4, 21:9); only those that fit the monitor are offered.
const RESOLUTIONS := [
	Vector2i(1024, 576), Vector2i(1024, 768), Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1280, 800),
	Vector2i(1280, 1024), Vector2i(1366, 768), Vector2i(1440, 900), Vector2i(1600, 900), Vector2i(1680, 1050),
	Vector2i(1920, 1080), Vector2i(1920, 1200), Vector2i(2560, 1080), Vector2i(2560, 1440), Vector2i(2560, 1600),
	Vector2i(3200, 1800), Vector2i(3440, 1440), Vector2i(3840, 2160),
]

var binds: Dictionary = {}
var master_volume := 0.8
var sfx_volume := 0.8
var music_volume := 0.5
var window_mode := "windowed"  # windowed / fullscreen (borderless) / exclusive
var window_size := Vector2i.ZERO  # windowed size; ZERO = automatic (largest 16:9 size that fits the monitor)
var monitor := -1  # -1 = the one the window is on
var scaling := "fit"
var crisp_pixels := true  # world pixels always cover a whole number of screen pixels
var vsync := true
var max_fps := 0
var last_fullscreen := "fullscreen"
var damage_numbers := true
var screen_shake := true
var camera_zoom := 3.0
var show_minimap := true


var _size_save_t := -1.0
var _cmdline_window := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # F11 works in menus too
	for a in ACTIONS:
		binds[a] = ACTIONS[a][1].duplicate(true)
	load_settings()
	# a size / mode given on the command line (--resolution, --fullscreen, ...) wins over the saved one
	var args := OS.get_cmdline_args()
	for a in ["--resolution", "--fullscreen", "-f", "--maximized", "-m", "--windowed", "-w"]:
		if a in args:
			_cmdline_window = true
	apply()
	if _display_ok():
		get_window().size_changed.connect(_on_window_resized)
		apply_display(true)


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	master_volume = cf.get_value("audio", "master", master_volume)
	sfx_volume = cf.get_value("audio", "sfx", sfx_volume)
	music_volume = cf.get_value("audio", "music", music_volume)
	if cf.get_value("video", "fullscreen", false):  # older settings files
		window_mode = "fullscreen"
	window_mode = str(cf.get_value("video", "window_mode", window_mode))
	if not window_mode in WINDOW_MODES:
		window_mode = "windowed"
	var ws = cf.get_value("video", "window_size", window_size)
	window_size = ws if ws is Vector2i else Vector2i.ZERO
	monitor = int(cf.get_value("video", "monitor", monitor))
	scaling = str(cf.get_value("video", "scaling", scaling))
	if not scaling in SCALINGS:
		scaling = "fit"
	crisp_pixels = bool(cf.get_value("video", "crisp_pixels", crisp_pixels))
	vsync = bool(cf.get_value("video", "vsync", vsync))
	max_fps = int(cf.get_value("video", "max_fps", max_fps))
	last_fullscreen = str(cf.get_value("video", "last_fullscreen", last_fullscreen))
	camera_zoom = cf.get_value("video", "zoom", camera_zoom)
	damage_numbers = cf.get_value("game", "damage_numbers", damage_numbers)
	screen_shake = cf.get_value("game", "screen_shake", screen_shake)
	show_minimap = cf.get_value("game", "minimap", show_minimap)
	for a in ACTIONS:
		var v = cf.get_value("binds", a, null)
		if v is Array:
			binds[a] = v


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "master", master_volume)
	cf.set_value("audio", "sfx", sfx_volume)
	cf.set_value("audio", "music", music_volume)
	cf.set_value("video", "window_mode", window_mode)
	cf.set_value("video", "window_size", window_size)
	cf.set_value("video", "monitor", monitor)
	cf.set_value("video", "scaling", scaling)
	cf.set_value("video", "crisp_pixels", crisp_pixels)
	cf.set_value("video", "vsync", vsync)
	cf.set_value("video", "max_fps", max_fps)
	cf.set_value("video", "last_fullscreen", last_fullscreen)
	cf.set_value("video", "zoom", camera_zoom)
	cf.set_value("game", "damage_numbers", damage_numbers)
	cf.set_value("game", "screen_shake", screen_shake)
	cf.set_value("game", "minimap", show_minimap)
	for a in binds:
		cf.set_value("binds", a, binds[a])
	cf.save(PATH)


func apply() -> void:
	for a in ACTIONS:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.2)
		InputMap.action_erase_events(a)
		for b in binds[a]:
			var ev := make_event(b)
			if ev:
				InputMap.action_add_event(a, ev)
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(max(master_volume, 0.0001)))
	changed.emit()


# =================================================================== display
func _display_ok() -> bool:
	return not Engine.is_editor_hint() and DisplayServer.get_name() != "headless"


func screen_index() -> int:
	if monitor >= 0 and monitor < DisplayServer.get_screen_count():
		return monitor
	return get_window().current_screen if _display_ok() else 0


func screen_size() -> Vector2i:
	return DisplayServer.screen_get_size(screen_index()) if _display_ok() else BASE_SIZE


func usable_size() -> Vector2i:
	if not _display_ok():
		return BASE_SIZE
	var u := DisplayServer.screen_get_usable_rect(screen_index()).size
	return u if u.x > 0 and u.y > 0 else screen_size()


## True while the game runs inside the Godot editor's Game tab (Godot 4.4+ embeds it by default when you press
## F5). The editor owns the window then: resizing it or going fullscreen from the game would leave the picture and
## the mouse out of step, so window size / mode / monitor are left alone in that case.
func embedded_in_editor() -> bool:
	if Engine.has_method("is_embedded_in_editor") and bool(Engine.call("is_embedded_in_editor")):
		return true
	return "--embedded" in OS.get_cmdline_args() or "--fake-embedded" in OS.get_cmdline_user_args()  # (the latter: tests)


## Whether this session may change the window (not headless, not embedded in the editor).
func can_change_window() -> bool:
	return _display_ok() and not embedded_in_editor()


var _deco := Vector2i(16, 39)  # window frame + title bar, measured while windowed (a typical guess until then)


func _measure_deco() -> void:
	if not _display_ok() or get_window().mode != Window.MODE_WINDOWED:
		return
	var d := DisplayServer.window_get_size_with_decorations() - DisplayServer.window_get_size()
	if d.x >= 0 and d.y >= 0 and d.x < 200 and d.y < 200:
		_deco = d


## The largest window (inside area) that fits on the monitor together with its frame and title bar.
func max_window_size() -> Vector2i:
	var u := usable_size()
	return Vector2i(maxi(MIN_WINDOW.x, u.x - _deco.x), maxi(MIN_WINDOW.y, u.y - _deco.y))


## Window sizes that fit on the monitor (frame and title bar included).
func resolution_options() -> Array:
	var m := max_window_size()
	var out := []
	for r in RESOLUTIONS:
		if r.x <= m.x and r.y <= m.y:
			out.append(r)
	if out.is_empty():
		out.append(Vector2i(mini(m.x, BASE_SIZE.x), mini(m.y, BASE_SIZE.y)))
	return out


## The windowed size to use: the chosen one (kept on screen), or the largest 16:9 size that fits nicely.
func windowed_size() -> Vector2i:
	var m := max_window_size()
	if window_size != Vector2i.ZERO:
		return Vector2i(clampi(window_size.x, MIN_WINDOW.x, m.x), clampi(window_size.y, MIN_WINDOW.y, m.y))
	var u := usable_size()
	var best := Vector2i(1024, 576)
	for r in RESOLUTIONS:
		if r.x * 9 == r.y * 16 and r.x <= mini(m.x, int(u.x * 0.9)) and r.y <= mini(m.y, int(u.y * 0.9)) and r.x > best.x:
			best = r
	return best


## Where to put a window of inside size `sz` so the whole window (frame included) is centred on the monitor.
func _centered_position(scr: int, sz: Vector2i) -> Vector2i:
	var ur := DisplayServer.screen_get_usable_rect(scr)
	var outer := sz + _deco
	var side := _deco.x / 2
	var top := maxi(0, _deco.y - side)  # title bar
	var p := ur.position + (ur.size - outer) / 2 + Vector2i(side, top)
	return Vector2i(maxi(p.x, ur.position.x + side), maxi(p.y, ur.position.y + top))


var _apply_gen := 0
var _applying := false


## Applies window mode, size, monitor, scaling, vsync and the frame cap.
## Window changes run as a short sequence that waits for the operating system to finish each step (leaving
## fullscreen can take a moment, and is animated on some systems) before the next one, and the scaling is set
## from the size the window really ended up with — so the picture and the mouse always stay in step, however
## quickly you switch. A newer request cancels an older one that is still running.
func apply_display(startup: bool = false) -> void:
	if not _display_ok():
		return
	var win := get_window()
	win.min_size = MIN_WINDOW
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = max_fps
	_measure_deco()
	if not can_change_window() or (startup and (_cmdline_window or "--autotest" in OS.get_cmdline_user_args())):
		_update_scaling()  # the editor / command line / test owns the window: only the scaling is ours
		return
	_apply_gen += 1
	_apply_window(_apply_gen)


func _apply_window(gen: int) -> void:
	_applying = true
	var win := get_window()
	var scr := screen_index()
	if window_mode == "windowed":
		if win.mode != Window.MODE_WINDOWED:
			win.mode = Window.MODE_WINDOWED
			await _settle(gen)
			if gen != _apply_gen:
				return
			_measure_deco()
		if win.current_screen != scr:
			win.current_screen = scr
			await _settle(gen)
			if gen != _apply_gen:
				return
		var sz := windowed_size()
		if win.size != sz:
			win.size = sz
		win.position = _centered_position(scr, sz)
		await _settle(gen)
	else:
		if win.current_screen != scr:
			if win.mode != Window.MODE_WINDOWED:
				win.mode = Window.MODE_WINDOWED
				await _settle(gen)
				if gen != _apply_gen:
					return
			win.current_screen = scr
			await _settle(gen)
			if gen != _apply_gen:
				return
		var want := Window.MODE_FULLSCREEN if window_mode == "fullscreen" else Window.MODE_EXCLUSIVE_FULLSCREEN
		if win.mode != want:
			if win.mode == Window.MODE_WINDOWED:
				_measure_deco()
			win.mode = want
			await _settle(gen)
	if gen != _apply_gen:
		return
	_update_scaling()
	_applying = false
	display_changed.emit()


## Waits until the window size reported by the OS has stopped changing for a few frames (max ~1.5 s).
func _settle(gen: int) -> void:
	var last := Vector2i(-1, -1)
	var stable := 0
	for i in 90:
		await get_tree().process_frame
		if gen != _apply_gen:
			return
		var sz := DisplayServer.window_get_size()
		if sz == last:
			stable += 1
			if stable >= 3:
				break
		else:
			stable = 0
			last = sz
	_sync_window_size()
	_update_scaling()


## If the OS gave the window another size than was asked for (a tiling window manager, a size the system would
## not allow, the editor's Game tab), adopt the real size so the picture and the mouse line up with what is shown.
func _sync_window_size() -> void:
	var win := get_window()
	if win.mode != Window.MODE_WINDOWED:
		return
	var real := DisplayServer.window_get_size()
	if real.x > 0 and real.y > 0 and real != win.size:
		win.size = real


## "fit": the 1280x720 layout is scaled by whatever fills the window (the view grows on other aspect ratios).
## "integer": the largest whole-number scale (x1, x2, x3...) that still holds the layout, and the view grows to
## fill the whole window at that scale — no black bars (Godot's own integer stretch would letterbox instead).
## A window smaller than the layout always uses "fit", so everything stays on screen.
## The size used is the one the OS reports, so the picture always matches the real window.
func _update_scaling() -> void:
	if not _display_ok():
		return
	var win := get_window()
	var ws := DisplayServer.window_get_size() if not embedded_in_editor() else win.size
	if ws.x <= 0 or ws.y <= 0:
		ws = win.size
	var base := BASE_SIZE
	if scaling == "integer" and ws.x >= BASE_SIZE.x and ws.y >= BASE_SIZE.y:
		var k := maxi(1, mini(ws.x / BASE_SIZE.x, ws.y / BASE_SIZE.y))
		base = Vector2i(ws.x / k, ws.y / k)
	if win.content_scale_mode != Window.CONTENT_SCALE_MODE_CANVAS_ITEMS:
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if win.content_scale_aspect != Window.CONTENT_SCALE_ASPECT_EXPAND:
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	if win.content_scale_stretch != Window.CONTENT_SCALE_STRETCH_FRACTIONAL:
		win.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	if win.content_scale_size != base:
		win.content_scale_size = base


## True when pixel-perfect scaling is in effect right now.
func integer_scaling_active() -> bool:
	return _display_ok() and get_window().content_scale_size != BASE_SIZE


func _on_window_resized() -> void:
	_update_scaling()
	if _applying or not can_change_window():
		return  # our own switch in progress (or the editor resizing its Game tab): nothing to remember
	var win := get_window()
	if win.mode == Window.MODE_WINDOWED and window_mode == "windowed":
		window_size = win.size  # remember a size the player dragged the window to
		_size_save_t = 0.8
		_measure_deco()


var _sync_t := 0.0


func _process(delta: float) -> void:
	if _size_save_t > 0.0:
		_size_save_t -= delta
		if _size_save_t <= 0.0:
			save_settings()
	# safety net: if the OS changed the window without telling us (or we missed it), keep the picture in step
	_sync_t -= delta
	if _sync_t <= 0.0:
		_sync_t = 0.5
		if not _applying and _display_ok():
			_sync_window_size()
		_update_scaling()
		if not _applying and can_change_window():
			var win := get_window()
			var actual := win.mode
			if window_mode == "windowed" and actual in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]:
				window_mode = "fullscreen" if actual == Window.MODE_FULLSCREEN else "exclusive"  # changed by the OS
				display_changed.emit()
			elif window_mode != "windowed" and actual in [Window.MODE_WINDOWED, Window.MODE_MAXIMIZED]:
				window_mode = "windowed"  # e.g. the player left fullscreen with the system's own controls
				display_changed.emit()


func set_window_mode(m: String) -> void:
	window_mode = m if m in WINDOW_MODES else "windowed"
	if window_mode != "windowed":
		last_fullscreen = window_mode
	apply_display()
	save_settings()
	display_changed.emit()


func toggle_fullscreen() -> void:
	if not can_change_window():
		if embedded_in_editor() and Game:
			Game.toast("Running inside the Godot editor: fullscreen and window size are controlled by the editor. Run the exported game (or turn off \"Embed Game\" in the editor's Game tab) to use them.", Color("ffb347"))
		return
	set_window_mode(last_fullscreen if window_mode == "windowed" else "windowed")


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var alt_enter: bool = event.alt_pressed and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]
	if alt_enter or event.is_action_pressed("toggle_fullscreen"):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


## How many screen pixels one view pixel takes (e.g. 1.5 for a 1920x1080 window).
func view_scale() -> float:
	if not _display_ok():
		return 1.0
	var vis := get_viewport().get_visible_rect().size
	return float(get_window().size.y) / maxf(1.0, vis.y)


## The camera zoom to use for a wanted zoom: with crisp pixels on, adjusted a little so that one art pixel
## covers a whole number of screen pixels (no uneven, shimmering pixels at in-between scales).
func world_zoom(z: float) -> float:
	if not crisp_pixels:
		return z
	var s := view_scale()
	if s <= 0.0:
		return z
	return maxf(1.0, round(z * s)) / s


func display_info() -> String:
	if not _display_ok():
		return "No display."
	var win := get_window()
	var vis := get_viewport().get_visible_rect().size
	return "Monitor %d: %d × %d  •  Window: %d × %d  •  Game view: %d × %d (scale ×%.2f)" % [screen_index() + 1,
		screen_size().x, screen_size().y, win.size.x, win.size.y, int(vis.x), int(vis.y), view_scale()]


func make_event(b: Array) -> InputEvent:
	if b.size() < 2:
		return null
	if b[0] == "key":
		var k := InputEventKey.new()
		k.physical_keycode = int(b[1])
		return k
	if b[0] == "mouse":
		var m := InputEventMouseButton.new()
		m.button_index = int(b[1])
		return m
	return null


func binding_from_event(ev: InputEvent) -> Array:
	if ev is InputEventKey:
		var code: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		return ["key", code]
	if ev is InputEventMouseButton:
		return ["mouse", ev.button_index]
	return []


func binding_text(b: Array) -> String:
	if b.size() < 2:
		return "-"
	if b[0] == "key":
		return OS.get_keycode_string(int(b[1]))
	var names := {MOUSE_BUTTON_LEFT: "Mouse L", MOUSE_BUTTON_RIGHT: "Mouse R", MOUSE_BUTTON_MIDDLE: "Mouse M",
		MOUSE_BUTTON_XBUTTON1: "Mouse 4", MOUSE_BUTTON_XBUTTON2: "Mouse 5"}
	return names.get(int(b[1]), "Mouse %d" % int(b[1]))


func action_text(action: String) -> String:
	var bl: Array = binds.get(action, [])
	if bl.is_empty():
		return "-"
	return binding_text(bl[0])


func set_binding(action: String, idx: int, b: Array) -> void:
	# remove the same binding from any other action so keys never conflict
	for a in binds:
		var lst: Array = binds[a]
		for i in range(lst.size() - 1, -1, -1):
			if lst[i] == b and not (a == action and i == idx):
				lst.remove_at(i)
	var cur: Array = binds[action]
	while cur.size() <= idx:
		cur.append([])
	cur[idx] = b
	var clean := []
	for x in cur:
		if x is Array and x.size() == 2:
			clean.append(x)
	binds[action] = clean
	apply()
	save_settings()


func reset_binds() -> void:
	for a in ACTIONS:
		binds[a] = ACTIONS[a][1].duplicate(true)
	apply()
	save_settings()
