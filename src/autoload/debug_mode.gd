extends Node
## Debug mode: an info overlay (F3) and a cheat panel (F4) for testing.
##
## Only available in debug builds (running from the Godot editor, or an export made with "Export With Debug"),
## or when the game is started with the user argument  --debug-mode  (godot --path . -- --debug-mode).
## Release exports never see it. The cheat flags are never saved.

const OVERLAY_KEY := KEY_F3
const PANEL_KEY := KEY_F4
const SPEEDS := [0.25, 0.5, 1.0, 2.0, 4.0]
const TIERS := ["normal", "elite", "mini", "boss"]

var enabled := false
## Cheats (read by Player / Combat / Level)
var god := false          # the hero takes no damage
var one_hit := false      # the hero's hits kill anything
var free_skills := false  # no MP cost, no cooldowns for the hero
var no_hunger := false    # satiety stays full
var noclip := false       # walk through walls, water and cliffs
var fast_move := false    # hero moves 2.5x faster
var game_speed := 1.0     # Engine.time_scale outside of hitstop
var unlock_all := false   # every progression-locked feature is available (Progression.is_unlocked)

var overlay_layer: CanvasLayer
var overlay: Label
var _overlay_t := 0.0
## World position of the mouse when the panel was opened (spawns / teleports go there).
var last_mouse_world := Vector2.INF


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	enabled = OS.is_debug_build() or "--debug-mode" in args
	if "--autotest" in args and not ("--debug-mode" in args or "--debugtest" in args):
		enabled = false  # automated tests run the real game rules
	if not enabled:
		set_process(false)
		set_process_input(false)
		return
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 95
	overlay_layer.visible = false
	add_child(overlay_layer)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UI.sbox(Color(0.03, 0.02, 0.08, 0.72), Color(1, 1, 1, 0.12), 1, 3, 6))
	panel.position = Vector2(8, 8)
	overlay_layer.add_child(panel)
	overlay = Label.new()
	overlay.add_theme_font_size_override("font_size", 13)
	overlay.add_theme_color_override("font_color", Color("c8ffb0"))
	overlay.add_theme_color_override("font_outline_color", Color.BLACK)
	overlay.add_theme_constant_override("outline_size", 3)
	panel.add_child(overlay)


func any_cheat() -> bool:
	return god or one_hit or free_skills or no_hunger or noclip or fast_move or unlock_all or game_speed != 1.0


# ------------------------------------------------------------------ input
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		OVERLAY_KEY:
			overlay_layer.visible = not overlay_layer.visible
			_overlay_t = 0.0
			get_viewport().set_input_as_handled()
		PANEL_KEY:
			toggle_panel()
			get_viewport().set_input_as_handled()


func toggle_panel() -> void:
	var m = Game.main
	if m == null or not Game.in_game:
		return
	if m.window is DebugWindow and is_instance_valid(m.window):
		m.close_all()
		return
	var p := hero()
	last_mouse_world = p.get_global_mouse_position() if p else Vector2.INF
	m._open(DebugWindow.new())


# ------------------------------------------------------------------ helpers
func hero() -> Player:
	var p = Game.player_node
	return p if p is Player and is_instance_valid(p) else null


func level() -> Level:
	var m = Game.main
	if m == null or not is_instance_valid(m.level):
		return null
	return m.level


func set_game_speed(s: float) -> void:
	game_speed = s
	Engine.time_scale = s


# ------------------------------------------------------------------ per frame
func _process(delta: float) -> void:
	var p := hero()
	if p and not p.ghost:
		p.collision_mask = 0 if noclip else (1 | 2)
		if no_hunger:
			Game.player["satiety"] = 100.0
	if overlay_layer.visible:
		_overlay_t -= delta / maxf(0.01, Engine.time_scale)
		if _overlay_t <= 0.0:
			_overlay_t = 0.2
			overlay.text = _overlay_text()


func _overlay_text() -> String:
	var L: PackedStringArray = []
	L.append("DEBUG  (F3 overlay, F4 cheats)")
	L.append("FPS %d   frame %.1f ms   physics %.1f ms" % [Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	L.append("Nodes %d   objects %d   draw calls %d   mem %.0f MB" % [Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	L.append("Time scale %.2f   %s" % [Engine.time_scale, "PAUSED" if get_tree().paused else ""])
	if not Game.in_game:
		return "\n".join(L)
	var lv := level()
	var p := hero()
	L.append("%s   Lv %d (%d / %d XP)   gold %d" % [Game.clock_text(), int(Game.player["level"]), int(Game.player["xp"]),
		GameData.xp_to_next(int(Game.player["level"])), int(Game.player["gold"])])
	if p:
		var pos := p.global_position
		L.append("Pos (%.0f, %.0f)   HP %.0f/%.0f   MP %.0f/%.0f   satiety %.0f" % [pos.x, pos.y, p.hp, p.max_hp, p.mp, p.max_mp,
			float(Game.player.get("satiety", 0.0))])
		if lv is Overworld:
			var ow: Overworld = lv
			var t := ow.tile_of(pos)
			L.append("Tile %d,%d   chunk %d,%d   biome %s   area Lv %d   %s   chunks loaded %d" % [t.x, t.y,
				floori(t.x / float(WorldGen.CHUNK)), floori(t.y / float(WorldGen.CHUNK)), ow.gen.biome_at(t.x, t.y),
				ow.gen.level_at(t.x, t.y), "town" if ow.is_town() else "wild", ow.chunks.size()])
		elif lv is DungeonLevel:
			var dl: DungeonLevel = lv
			L.append("Dungeon rank %d   room %d   rooms visited %d / %d   %s" % [int(dl.dungeon.get("rank", 0)), dl.room_of(pos),
				dl.visited_rooms.size(), dl.design.get("rooms", []).size(), "TEST RUN" if dl.test_run else ""])
	var mons := 0
	for m in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(m) and not m.dead:
			mons += 1
	L.append("Monsters %d   adventurers here %d / %d   world dungeons %d" % [mons, NpcWorld.actors.size(),
		NpcWorld.npcs().size(), Game.world.get("dungeons", []).size()])
	var on: PackedStringArray = []
	for f in ["god", "one_hit", "free_skills", "no_hunger", "noclip", "fast_move", "unlock_all"]:
		if get(f):
			on.append(f)
	if game_speed != 1.0:
		on.append("speed x%s" % game_speed)
	if not on.is_empty():
		L.append("Cheats: " + ", ".join(on))
	return "\n".join(L)


# ------------------------------------------------------------------ actions
func full_restore() -> void:
	var p := hero()
	if p:
		p.hp = p.max_hp
		p.mp = p.max_mp
		p.clear_debuffs()
		p.skill_cds.clear()
	Game.player["satiety"] = 100.0


func add_levels(n: int) -> void:
	var lv := int(Game.player["level"])
	var target := clampi(lv + n, 1, GameData.MAX_LEVEL)
	var need := 0
	for l in range(lv, target):
		need += GameData.xp_to_next(l)
	if need > 0:
		Game.add_xp(maxi(0, need - int(Game.player["xp"])))


func kill_monsters(radius: float = -1.0) -> int:
	var p := hero()
	var n := 0
	for m in get_tree().get_nodes_in_group("monsters"):
		if not is_instance_valid(m) or m.dead:
			continue
		if radius > 0.0 and p and m.global_position.distance_to(p.global_position) > radius:
			continue
		m.hp = 0.0
		m.die(p)
		n += 1
	return n


func spawn_monster(type: String, lvl: int, tier: String, count: int) -> void:
	var lv := level()
	var p := hero()
	if lv == null or p == null:
		return
	var at := last_mouse_world if last_mouse_world != Vector2.INF else p.global_position + p.aim * 60.0
	var opts := {}
	if lv is DungeonLevel:
		opts["room"] = (lv as DungeonLevel).room_of(at)
	for i in count:
		var pos := at + Vector2(randf_range(-16, 16), randf_range(-16, 16)) * (0.0 if count == 1 else 1.0)
		lv.spawn_monster(type, pos, lvl, tier, opts)


func give_gear(ilvl: int, rarity: int, count: int) -> void:
	for i in count:
		Game.give_item(Items.random_gear(ilvl, rarity))


func give_consumables() -> void:
	for id in GameData.ItemData.CONSUMABLES:
		Game.give_item(Items.stack(id, 10))


func teleport(to: Vector2) -> void:
	var lv := level()
	var p := hero()
	if lv == null or p == null or to == Vector2.INF:
		return
	if lv is Overworld:
		(lv as Overworld)._teleport_player(to)
	else:
		p.global_position = to
		lv.camera.global_position = to
		lv.camera.reset_smoothing()


func reveal_map() -> void:
	var n := WorldGen.SIZE / WorldGen.CHUNK
	for cy in n:
		for cx in n:
			Game.world["explored"]["%d,%d" % [cx, cy]] = true


func skip_hours(h: float) -> void:
	Game.advance_time(Game.DAY_LEN * h / 24.0)


func set_hour(h: float) -> void:
	var now := Game.day_fraction() * 24.0
	var diff := fposmod(h - now, 24.0)
	skip_hours(diff)


func spawn_dungeon() -> bool:
	var lv := level()
	if not (lv is Overworld):
		return false
	var ow: Overworld = lv
	if not ow._spawn_random_dungeon():
		return false
	ow._update_portals()
	return true
