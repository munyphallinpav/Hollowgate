extends Node
## Root controller: title screen, level switching (overworld <-> dungeons), menus, pausing, transitions.

var world_root: Node2D
var hud: HUD
var menu_layer: CanvasLayer
var tooltip: Tooltip
var title: TitleScreen
var fade_layer: CanvasLayer
var fade: ColorRect
var level: Level
var window: GameWindow
var pending_spawn := Vector2.INF
var test_snapshot: Dictionary = {}
var test_return_pos := Vector2.INF
var _busy := false


func _ready() -> void:
	Game.main = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	RenderingServer.set_default_clear_color(Color("0b0a12"))
	world_root = Node2D.new()
	world_root.name = "World"
	world_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world_root)
	hud = HUD.new()
	hud.visible = false
	add_child(hud)
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 20
	menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(menu_layer)
	tooltip = Tooltip.new()
	add_child(tooltip)
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 90
	add_child(fade_layer)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade)
	Sfx.play_music(true)
	var args := OS.get_cmdline_user_args()
	if "--autotest" in args:
		var at = load("res://src/dev/autotest.gd").new()
		add_child(at)
		return
	go_title(false)


# ===================================================================== flow
func go_title(save: bool) -> void:
	if save and Game.in_game and not Game.test_run:
		Game.save_game(true)
	close_all()
	_free_level()
	Game.in_game = false
	Game.test_run = false
	hud.visible = false
	get_tree().paused = false
	if title == null or not is_instance_valid(title):
		title = TitleScreen.new()
		add_child(title)
	else:
		title.show_main()


func start_new_game(pname: String, cls: String, slot: int) -> void:
	Game.designs = []
	Game.new_game(pname, cls, slot)
	_start_world()
	Game.save_game(true)
	Game.toast("Welcome to Hollowgate, %s! Visit the Adventurer Guild for quests, then head out through any gate." % pname, Color("ffe9a8"))
	Game.toast("Tip: you have 1 skill point — press %s to open your skills." % Settings.action_text("open_skills"), Color("c8c0e0"))


func load_slot(s: int) -> void:
	close_all()
	if Game.load_game(s):
		_start_world()
		Game.toast("Welcome back, %s." % Game.player["name"], Color("ffe9a8"))
	else:
		Game.toast("Could not load slot %d." % s, Color("ff7a7a"))


func _start_world() -> void:
	if title and is_instance_valid(title):
		title.queue_free()
		title = null
	Game.in_game = true
	hud.visible = true
	get_tree().paused = false
	_load_level(Overworld.new())


func _free_level() -> void:
	if level and is_instance_valid(level):
		world_root.remove_child(level)
		level.queue_free()
	level = null
	Game.level_node = null
	Game.player_node = null
	Engine.time_scale = 1.0


func _load_level(lv: Level) -> void:
	_free_level()
	level = lv
	world_root.add_child(lv)


func _transition(cb: Callable) -> void:
	if _busy:
		return
	_busy = true
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.25)
	tw.tween_callback(func():
		cb.call()
		_busy = false)
	tw.tween_interval(0.1)
	tw.tween_property(fade, "color:a", 0.0, 0.35)


func enter_dungeon(d: Dictionary, test: bool) -> void:
	_transition(func():
		var dl := DungeonLevel.new()
		dl.setup(d, test)
		_load_level(dl))


func leave_dungeon(reason: String, cleared: bool) -> void:
	if Game.test_run:
		end_test_run(reason)
		return
	_transition(func():
		match reason:
			"town":
				pending_spawn = Vector2(256 * 16 + 8, 262 * 16 + 8)
			"dead":
				pending_spawn = Vector2(256 * 16 + 8, 262 * 16 + 8)
				var lost := int(int(Game.player["gold"]) * 0.1)
				Game.add_gold(-lost)
				Game.player["hp"] = -1.0
				Game.player["mp"] = -1.0
				Game.toast("You were defeated in the dungeon... (-%d gold)" % lost, Color("ff7a7a"))
			_:
				var pos: Array = Game.player.get("pos", [])
				if pos.size() == 2:
					pending_spawn = Vector2(pos[0], pos[1])
		if cleared:
			Game.toast("The dungeon crumbles away behind you.", Color("c79bff"))
		_load_level(Overworld.new()))


func start_test_run(design: Dictionary) -> void:
	close_all()
	test_snapshot = Game.snapshot()
	if level and level.player:
		test_return_pos = level.player.global_position
	Game.save_game(true)
	Game.test_run = true
	enter_dungeon({"id": -1, "rank": int(design.get("rank", 1)), "biome": design.get("biome", "cave"), "custom": true, "design": design, "seed": 1}, true)


func end_test_run(reason: String = "exit") -> void:
	_transition(func():
		Game.test_run = false
		Game.restore(test_snapshot)
		pending_spawn = test_return_pos
		_load_level(Overworld.new())
		Game.toast("Test run finished (%s). Nothing was gained or lost." % ("defeated" if reason == "dead" else "left"), Color("c79bff"))
		var tw := create_tween()
		tw.tween_interval(0.5)
		tw.tween_callback(func(): open_service("architect")))


# ===================================================================== windows
func _open(w: GameWindow) -> void:
	close_all()
	window = w
	w.closed.connect(func():
		if window == w:
			window = null
			get_tree().paused = false)
	menu_layer.add_child(w)
	get_tree().paused = true
	Sfx.play("click")


func open_menu(tab: String) -> void:
	if not Game.in_game:
		return
	if window is GameMenu and is_instance_valid(window):
		if window.current == tab:
			close_all()
		else:
			window.show_tab(tab)
		return
	_open(GameMenu.new(tab))


func open_service(role: String, _npc = null) -> void:
	if not Game.in_game:
		return
	match role:
		"guild":
			_open(GuildWindow.new())
		"blacksmith":
			_open(BlacksmithWindow.new())
		"architect":
			_open(DungeonEditor.new())
		_:
			Game.refresh_shops()
			_open(ShopWindow.new(role))


func is_service_open(role: String) -> bool:
	return window != null and is_instance_valid(window) and window.key in [role, "shop_" + role]


func close_all() -> void:
	for c in menu_layer.get_children():
		if c is GameWindow:
			c.closed.emit()
		c.queue_free()
	window = null
	tooltip.hide_tip()
	if Game.in_game:
		get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not Game.in_game or _busy:
		return
	if not (event is InputEventKey or event is InputEventMouseButton) or not event.is_pressed():
		return
	if event.is_action_pressed("menu"):
		if menu_layer.get_child_count() > 0:
			# close topmost dialog first, then the window
			var top := menu_layer.get_child(menu_layer.get_child_count() - 1)
			if top is GameWindow:
				close_all()
			else:
				top.queue_free()
		else:
			open_menu("system")
		get_viewport().set_input_as_handled()
		return
	var map := {"open_inventory": "inventory", "open_character": "character", "open_skills": "skills", "open_quests": "quests", "open_map": "map"}
	for a in map:
		if event.is_action_pressed(a):
			if window != null and not (window is GameMenu):
				return
			open_menu(map[a])
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("open_editor"):
		if window is DungeonEditor:
			close_all()
		else:
			open_service("architect")
		get_viewport().set_input_as_handled()
