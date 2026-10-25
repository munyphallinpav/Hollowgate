extends Node
## Settings + rebindable hotkeys. Persisted in user://settings.cfg

signal changed

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
}

var binds: Dictionary = {}
var master_volume := 0.8
var sfx_volume := 0.8
var music_volume := 0.5
var fullscreen := false
var damage_numbers := true
var screen_shake := true
var camera_zoom := 3.0
var show_minimap := true


func _ready() -> void:
	for a in ACTIONS:
		binds[a] = ACTIONS[a][1].duplicate(true)
	load_settings()
	apply()


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	master_volume = cf.get_value("audio", "master", master_volume)
	sfx_volume = cf.get_value("audio", "sfx", sfx_volume)
	music_volume = cf.get_value("audio", "music", music_volume)
	fullscreen = cf.get_value("video", "fullscreen", fullscreen)
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
	cf.set_value("video", "fullscreen", fullscreen)
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
	if not Engine.is_editor_hint() and DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and (fullscreen or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN):
			DisplayServer.window_set_mode(want)
	changed.emit()


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
