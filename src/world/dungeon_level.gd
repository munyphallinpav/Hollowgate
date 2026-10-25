class_name DungeonLevel
extends Level
## A hidden (or custom) dungeon instance built from a design: rooms on a grid, corridors,
## custom terrain, traps, spawners, treasure, mini bosses and a final boss.

const T := 16
const BOSS_TITLES := {
	"slime": "Gelatinous King", "wolf": "Fenrir the Alpha", "tiger": "Sabreclaw", "bear": "Ursa Ironhide", "goblin": "Goblin Warlord Grizzik",
	"ogre": "Gorrak the Crusher", "skeleton": "The Bone Lord", "zombie": "Rotting Abomination", "treant": "Elder Rootwarden",
	"dryad": "Thornmother", "lizard": "Scaled Chieftain Ssark", "mermaid": "Siren Queen Maris", "vampire": "Count Velkhar",
	"wyvern": "Stormwing Wyvern", "dragon": "Ignatius the Red Tyrant", "phoenix": "Eternal Phoenix Solara", "bear_": "",
}

var dungeon: Dictionary = {}
var design: Dictionary = {}
var test_run := false
var W := 0
var H := 0
var grid: Array = []
var astar := AStarGrid2D.new()
var room_rects: Dictionary = {}
var cleared := false
var boss_cell := Vector2i(-1, -1)
var start_cell := Vector2i.ZERO
var _paths: Dictionary = {}
var _active_t := 0.0
var map_image: Image
var visited_rooms: Dictionary = {}
var floor_name := "df_cave"
var liquid_default := "water"


func setup(d: Dictionary, test: bool) -> void:
	dungeon = d
	test_run = test
	if d.get("custom", false) or d.has("design"):
		design = d["design"].duplicate(true)
	else:
		design = DungeonGen.random_design(int(d["rank"]), d["biome"], int(d["seed"]))


func _ready() -> void:
	super._ready()
	_build_layout()
	_render()
	_populate()
	var bd: Dictionary = GameData.DUNGEON_BIOMES[design.get("biome", "cave")]
	canvas_mod.color = bd["ambient"]
	var amb := Ambient.new()
	add_child(amb)
	amb.set_kind({"lava": "embers", "mushroom": "spores", "forest": "leaves", "beach": "motes", "grass": "motes"}.get(design.get("biome", "cave"), "motes"))
	spawn_player(room_center_px(start_cell) + Vector2(0, 26))
	visited_rooms[start_cell] = true
	Game.toast("Entered %s  [Rank %d]%s" % [design.get("name", "Dungeon"), int(design.get("rank", 1)), "  (TEST RUN)" if test_run else ""], Color("c79bff"))


func _process(delta: float) -> void:
	super._process(delta)
	if not test_run:
		time_tick(delta)
	_active_t -= delta
	if _active_t <= 0.0:
		_active_t = 0.4
		_update_activation()


# ===================================================================== layout
func cell_origin(c: Vector2i) -> Vector2i:
	var cs: Vector2i = GameData.WorldData.CELL_SIZE
	return Vector2i(c.x * cs.x, c.y * cs.y)


func room_rect(c: Vector2i) -> Rect2i:
	var cs: Vector2i = GameData.WorldData.CELL_SIZE
	var dims := DungeonGen.room_dims(design["rooms"][c])
	var o := cell_origin(c)
	return Rect2i(o.x + (cs.x - dims.x) / 2, o.y + (cs.y - dims.y) / 2, dims.x, dims.y)


func _idx(x: int, y: int) -> int:
	return y * W + x


func get_t(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= W or y >= H:
		return "void"
	return grid[_idx(x, y)]


func set_t(x: int, y: int, v: String) -> void:
	if x < 0 or y < 0 or x >= W or y >= H:
		return
	grid[_idx(x, y)] = v


func _room_floor(c: Vector2i) -> String:
	var b: String = design["rooms"][c].get("biome", "")
	if b == "" or not GameData.DUNGEON_BIOMES.has(b):
		return floor_name
	return GameData.DUNGEON_BIOMES[b]["floor"]


func _build_layout() -> void:
	var cs: Vector2i = GameData.WorldData.CELL_SIZE
	var g: Vector2i = design["grid"]
	W = g.x * cs.x
	H = g.y * cs.y
	grid.resize(W * H)
	grid.fill("void")
	var biome: String = design.get("biome", "cave")
	floor_name = GameData.DUNGEON_BIOMES[biome]["floor"]
	liquid_default = GameData.DUNGEON_BIOMES[biome]["liquid"]
	start_cell = design["start"]
	boss_cell = design["boss_room"]
	for c in design["rooms"]:
		var r := room_rect(c)
		room_rects[c] = r
		var fl := _room_floor(c)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				set_t(x, y, fl)
	# corridors
	for c in design["rooms"]:
		var room: Dictionary = design["rooms"][c]
		for dn in ["e", "s"]:
			if not room["doors"].get(dn, false):
				continue
			var nb: Vector2i = c + DungeonGen.DIRS[dn]
			if not design["rooms"].has(nb):
				continue
			var a: Rect2i = room_rects[c]
			var b: Rect2i = room_rects[nb]
			if dn == "e":
				var cy := cell_origin(c).y + cs.y / 2
				for x in range(a.end.x, b.position.x):
					for y in range(cy - 1, cy + 2):
						set_t(x, y, floor_name)
			else:
				var cx := cell_origin(c).x + cs.x / 2
				for y in range(a.end.y, b.position.y):
					for x in range(cx - 1, cx + 2):
						set_t(x, y, floor_name)
	# custom terrain painted in the editor
	for c in design["rooms"]:
		var room2: Dictionary = design["rooms"][c]
		var r2: Rect2i = room_rects[c]
		var styles: Dictionary = room2.get("tile_styles", {})
		for p in room2.get("tiles", {}):
			var kind: String = room2["tiles"][p]
			var gx: int = r2.position.x + p.x
			var gy: int = r2.position.y + p.y
			if gx < r2.position.x or gy < r2.position.y or gx >= r2.end.x or gy >= r2.end.y:
				continue
			match kind:
				"wall":
					var st: String = styles.get(p, "")
					set_t(gx, gy, "wall" if st == "" else "wall:" + st)
				"cliff":
					set_t(gx, gy, "pit")
				"water":
					set_t(gx, gy, liquid_default if liquid_default != "lava" else "water")
				"lava":
					set_t(gx, gy, "lava")
				"floor":
					set_t(gx, gy, _room_floor(c))
	# walls around everything walkable
	var walls := []
	for y in H:
		for x in W:
			if get_t(x, y) != "void":
				continue
			var near := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var n := get_t(x + dx, y + dy)
					if n != "void" and not n.begins_with("wall"):
						near = true
			if near:
				walls.append(Vector2i(x, y))
	for w in walls:
		set_t(w.x, w.y, "wall")
	# pathfinding grid
	astar.region = Rect2i(0, 0, W, H)
	astar.cell_size = Vector2(T, T)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in H:
		for x in W:
			if _blocked_t(get_t(x, y)):
				astar.set_point_solid(Vector2i(x, y), true)


func _blocked_t(t: String) -> bool:
	return t == "void" or t.begins_with("wall") or t in ["pit", "water", "lava", "swamp_water", "deep_water"]


func _render() -> void:
	var biome: String = design.get("biome", "cave")
	var decos: Array = GameData.DUNGEON_BIOMES[biome]["deco"]
	var terrain_f := func(x: int, y: int) -> String:
		return get_t(x, y)
	var deco_f := func(x: int, y: int) -> String:
		var t := get_t(x, y)
		if not t.begins_with("df_"):
			return ""
		var h := TileRenderer.vhash(x, y, 77) % 100
		return decos[h % decos.size()] if h < 7 else ""
	var wall_style: String = design.get("wall", GameData.DUNGEON_BIOMES[biome]["wall"])
	# render in 64x64 tile blocks to keep textures small
	var B := 64
	for by in range(0, H, B):
		for bx in range(0, W, B):
			var img := TileRenderer.render(bx, by, mini(B, W - bx), mini(B, H - by), terrain_f, deco_f, wall_style)
			var spr := Sprite2D.new()
			spr.texture = ImageTexture.create_from_image(img)
			spr.centered = false
			spr.position = Vector2(bx * T, by * T)
			ground.add_child(spr)
	var wb := StaticBody2D.new()
	wb.collision_layer = 1
	TileRenderer.add_collision(wb, 0, 0, W, H, func(x, y): return get_t(x, y).begins_with("wall") or get_t(x, y) == "void")
	add_child(wb)
	var lb := StaticBody2D.new()
	lb.collision_layer = 2
	TileRenderer.add_collision(lb, 0, 0, W, H, func(x, y): return get_t(x, y) in ["pit", "water", "lava", "swamp_water"])
	add_child(lb)
	# minimap image
	map_image = Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var t := get_t(x, y)
			var c := Color(0, 0, 0, 0)
			if t.begins_with("wall"):
				c = Color("6e6e80")
			elif t == "pit":
				c = Color("0c0a14")
			elif t == "lava":
				c = Color("f77622")
			elif t in ["water", "swamp_water"]:
				c = Color("3a8ad8")
			elif t != "void":
				c = Color("b8b0a0").darkened(0.2)
			map_image.set_pixel(x, y, c)
	# lava glow
	for y in range(0, H, 3):
		for x in range(0, W, 3):
			if get_t(x, y) == "lava" and TileRenderer.vhash(x, y, 5) % 3 == 0:
				var l := PointLight2D.new()
				l.texture = Art.fx("light")
				l.color = Color("ff7a2a")
				l.energy = 0.45
				l.texture_scale = 1.2
				l.position = Vector2(x * T + 8, y * T + 8)
				add_child(l)


# ===================================================================== population
func _floor_tiles(c: Vector2i, margin: int = 1) -> Array:
	var r: Rect2i = room_rects[c]
	var out := []
	for y in range(r.position.y + margin, r.end.y - margin):
		for x in range(r.position.x + margin, r.end.x - margin):
			if get_t(x, y).begins_with("df_"):
				out.append(Vector2i(x, y))
	return out


func _pick_spot(c: Vector2i, used: Dictionary, rng: RandomNumberGenerator, margin: int = 1) -> Vector2i:
	var tiles := _floor_tiles(c, margin)
	if tiles.is_empty():
		tiles = _floor_tiles(c, 0)
	for i in 30:
		var t: Vector2i = tiles[rng.randi_range(0, tiles.size() - 1)]
		if not used.has(t):
			used[t] = true
			return t
	return tiles[0] if not tiles.is_empty() else room_rects[c].get_center()


func _local_to_global(c: Vector2i, p) -> Vector2i:
	var r: Rect2i = room_rects[c]
	return Vector2i(r.position.x + int(p.x), r.position.y + int(p.y))


func tile_px(t: Vector2i) -> Vector2:
	return Vector2(t.x * T + 8, t.y * T + 10)


func room_id_of(c: Vector2i) -> int:
	return c.y * int(design["grid"].x) + c.x


func _populate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(design.get("seed", 1)) + 99
	var rank := int(design.get("rank", 1))
	var biome: String = design.get("biome", "cave")
	var bd: Dictionary = GameData.DUNGEON_BIOMES[biome]
	# exit portal at the start
	var exitp := Portal.new()
	exitp.kind = "exit"
	exitp.position = room_center_px(start_cell) + Vector2(0, -6)
	add_entity(exitp)
	for c in design["rooms"]:
		var room: Dictionary = design["rooms"][c]
		var used := {}
		var rid := room_id_of(c)
		var rb: String = room.get("biome", "")
		if rb == "" or not GameData.DUNGEON_BIOMES.has(rb):
			rb = biome
		var tint: Color = GameData.DUNGEON_BIOMES[rb]["slime"]
		used[room_rects[c].get_center()] = true
		# torches + decoration
		_torches(c)
		if rng.randf() < 0.7:
			var props: Array = GameData.DUNGEON_BIOMES[rb]["props"]
			for i in rng.randi_range(1, 2):
				var spot := _pick_spot(c, used, rng, 1)
				var r: Rect2i = room_rects[c]
				if absi(spot.x - r.get_center().x) <= 1 or absi(spot.y - r.get_center().y) <= 1:
					continue
				_prop(props[rng.randi_range(0, props.size() - 1)], tile_px(spot))
		if c == start_cell:
			continue
		# monsters
		for m in room.get("monsters", []):
			var mt: String = m.get("type", "slime")
			if not GameData.MONSTERS.has(mt):
				continue
			var n := int(m.get("count", 1))
			for i in n:
				var spot2: Vector2i = _local_to_global(c, m["pos"]) if m.get("pos") != null and m.has("pos") else _pick_spot(c, used, rng, 2)
				_spawn_room_monster(mt, tile_px(spot2), rank, "normal", rid, tint, rb)
		if room.get("miniboss", "") != "" and GameData.MONSTERS.has(room["miniboss"]):
			var spot3 := _pick_spot(c, used, rng, 2)
			_spawn_room_monster(room["miniboss"], tile_px(spot3), rank + 2, "mini", rid, tint, rb)
		# traps
		for tr in room.get("traps", []):
			var tt: String = tr.get("type", "spike")
			var pos_t: Vector2i = _local_to_global(c, tr["pos"]) if tr.get("pos") != null and tr.has("pos") else _pick_spot(c, used, rng, 1)
			if tt == "mimic":
				var mm := spawn_monster("mimic", tile_px(pos_t), rank + 1, "normal", {"room": rid})
				continue
			_spawn_trap(tt, pos_t, c, rid, rank, rng)
		for sp in room.get("spawners", []):
			var st: String = sp.get("type", "nest")
			var pos_s: Vector2i = _local_to_global(c, sp["pos"]) if sp.get("pos") != null and sp.has("pos") else _pick_spot(c, used, rng, 2)
			var s := Spawner.new()
			s.kind = st
			s.room_id = rid
			s.dungeon_rank = rank
			s.monsters = DungeonGen.allowed_monsters(rb, rank) if st != "grave" else ["skeleton", "zombie"]
			s.position = tile_px(pos_s)
			add_entity(s)
		for ch in room.get("treasures", []):
			var ct: String = ch.get("type", "chest")
			var pos_c: Vector2i = _local_to_global(c, ch["pos"]) if ch.get("pos") != null and ch.has("pos") else _pick_spot(c, used, rng, 1)
			var chest := Chest.new()
			chest.tier = GameData.WorldData.TREASURES.get(ct, {"tier": 0})["tier"]
			chest.ilvl = rank
			chest.position = tile_px(pos_c)
			add_entity(chest)
	# boss
	var bt: String = design.get("boss", "ogre")
	if not GameData.MONSTERS.has(bt):
		bt = "ogre"
	var bpos := room_center_px(boss_cell) + Vector2(0, -20)
	var bb: String = design["rooms"][boss_cell].get("biome", "")
	var btint: Color = GameData.DUNGEON_BIOMES[bb if GameData.DUNGEON_BIOMES.has(bb) else biome]["slime"]
	boss = _spawn_room_monster(bt, bpos, rank + 3, "boss", room_id_of(boss_cell), btint, biome)
	boss.display_name = design.get("boss_name", BOSS_TITLES.get(bt, "Dungeon Lord"))
	boss.died.connect(_on_boss_died)


func _spawn_room_monster(mt: String, pos: Vector2, rank: int, tier: String, rid: int, tint: Color, biome: String) -> Monster:
	var opts := {"room": rid}
	if mt == "slime":
		opts["tint"] = tint
		opts["element"] = {"lava": "fire", "beach": "water", "mushroom": "dark", "cave": "dark", "forest": "earth", "grass": "earth"}.get(biome, "water")
	var m := spawn_monster(mt, pos, rank, tier, opts)
	m.home = pos
	m.leash = 260.0
	return m


func _spawn_trap(tt: String, t: Vector2i, c: Vector2i, rid: int, rank: int, rng: RandomNumberGenerator) -> void:
	var tr := Trap.new()
	tr.type = tt
	tr.room_id = rid
	tr.rank = rank
	tr.test_mode = test_run
	var pos := tile_px(t)
	if tt == "arrow":
		# mount on the nearest wall facing inwards
		var r: Rect2i = room_rects[c]
		var dl := t.x - r.position.x
		var dr := r.end.x - 1 - t.x
		var du := t.y - r.position.y
		var dd := r.end.y - 1 - t.y
		var m := mini(mini(dl, dr), mini(du, dd))
		if m == dl:
			t.x = r.position.x
			tr.dir = Vector2.RIGHT
		elif m == dr:
			t.x = r.end.x - 1
			tr.dir = Vector2.LEFT
		elif m == du:
			t.y = r.position.y
			tr.dir = Vector2.DOWN
		else:
			t.y = r.end.y - 1
			tr.dir = Vector2.UP
		pos = tile_px(t)
	tr.position = pos
	if tt in ["boulder", "arrow"]:
		add_entity(tr)
	else:
		add_fx(tr, "under")


func _torches(c: Vector2i) -> void:
	var r: Rect2i = room_rects[c]
	var bd: Dictionary = GameData.DUNGEON_BIOMES[design.get("biome", "cave")]
	for x in [r.position.x + 1, r.end.x - 2]:
		var y := r.position.y - 1
		if get_t(x, y).begins_with("wall"):
			var s := Sprite2D.new()
			s.texture = Art.obj("dg_torch0")
			s.position = Vector2(x * T + 8, y * T + 8)
			s.z_index = 1
			add_fx(s, "under")
			var l := PointLight2D.new()
			l.texture = Art.fx("light")
			l.color = bd["light"]
			l.energy = 0.55
			l.texture_scale = 2.4
			l.position = s.position + Vector2(0, 6)
			add_child(l)
			var tw := l.create_tween().set_loops()
			tw.tween_property(l, "energy", 0.42, 0.3 + randf() * 0.2)
			tw.tween_property(l, "energy", 0.6, 0.3 + randf() * 0.2)


func _prop(name: String, pos: Vector2) -> void:
	var tex := Art.obj(name)
	if tex == null:
		return
	var s := StaticBody2D.new()
	s.collision_layer = 1
	s.position = pos
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.offset = Vector2(0, -tex.get_height() / 2.0 + 2)
	s.add_child(spr)
	var cs := CollisionShape2D.new()
	var shp := CircleShape2D.new()
	shp.radius = 5.0
	cs.shape = shp
	s.add_child(cs)
	add_entity(s)


# ===================================================================== rooms / queries
func room_center_px(c: Vector2i) -> Vector2:
	var r: Rect2i = room_rects.get(c, Rect2i(0, 0, 1, 1))
	return Vector2((r.position.x + r.size.x * 0.5) * T, (r.position.y + r.size.y * 0.5) * T)


func cell_of(pos: Vector2) -> Vector2i:
	var cs: Vector2i = GameData.WorldData.CELL_SIZE
	return Vector2i(int(floor(pos.x / T / cs.x)), int(floor(pos.y / T / cs.y)))


func room_of(pos: Vector2) -> int:
	var c := cell_of(pos)
	if design["rooms"].has(c):
		return room_id_of(c)
	return -1


func room_center(rid: int) -> Vector2:
	var gw := int(design["grid"].x)
	return room_center_px(Vector2i(rid % gw, rid / gw))


func can_aggro(m: Actor, t: Actor) -> bool:
	if not (m is Monster) or m.room_id < 0:
		return true
	return room_of(t.global_position) == m.room_id or m.global_position.distance_to(t.global_position) < 90.0


func path_dir(m: Actor, to: Vector2) -> Vector2:
	if m.hover > 0.0 or not ray_blocked(m.global_position, to, true):
		return (to - m.global_position).normalized()
	var id := m.get_instance_id()
	var now := Time.get_ticks_msec() / 1000.0
	var p: Dictionary = _paths.get(id, {})
	if p.is_empty() or now - float(p["t"]) > 0.5:
		var from_t := Vector2i(int(m.global_position.x / T), int(m.global_position.y / T))
		var to_t := Vector2i(int(to.x / T), int(to.y / T))
		var pts := PackedVector2Array()
		if astar.is_in_boundsv(from_t) and astar.is_in_boundsv(to_t) and not astar.is_point_solid(to_t):
			pts = astar.get_point_path(from_t, to_t, true)
		p = {"t": now, "pts": pts, "i": 1}
		_paths[id] = p
	var pts2: PackedVector2Array = p["pts"]
	var i: int = p["i"]
	while i < pts2.size() and m.global_position.distance_to(pts2[i] + Vector2(8, 8)) < 6.0:
		i += 1
	p["i"] = i
	if i < pts2.size():
		return (pts2[i] + Vector2(8, 8) - m.global_position).normalized()
	return (to - m.global_position).normalized()


func _update_activation() -> void:
	if player == null or not is_instance_valid(player):
		return
	var pc := cell_of(player.global_position)
	if design["rooms"].has(pc) and not visited_rooms.has(pc):
		visited_rooms[pc] = true
		if pc == boss_cell and is_instance_valid(boss) and not boss.dead:
			Game.toast("%s awaits!" % boss.display_name, Color("ff6a6a"))
			Sfx.play("roar")
			shake(4.0, 0.5)
	for m in get_tree().get_nodes_in_group("monsters"):
		if not is_instance_valid(m) or m.dead:
			continue
		var mc := cell_of(m.global_position)
		var near := absi(mc.x - pc.x) + absi(mc.y - pc.y) <= 1
		m.set_physics_process(near)
		m.visible = near or absi(mc.x - pc.x) + absi(mc.y - pc.y) <= 2


func player_light_energy() -> float:
	return 0.55


func boss_visible() -> bool:
	return boss != null and is_instance_valid(boss) and not boss.dead and player and cell_of(player.global_position) == boss_cell


# ===================================================================== events
func _on_boss_died(_m) -> void:
	cleared = true
	var c := room_center_px(boss_cell)
	var chest := Chest.new()
	chest.tier = 2
	chest.ilvl = int(design.get("rank", 1))
	chest.unique_monster = design.get("boss", "ogre")
	chest.position = c + Vector2(0, 8)
	add_entity(chest)
	var ex := Portal.new()
	ex.kind = "exit"
	ex.position = c + Vector2(40, 12)
	add_entity(ex)
	VFX.pillar(self, chest.position, 10.0, 160.0, Color("fee761"), 1.2)
	VFX.particles(self, chest.position, Color("fee761"), 40, 120.0, 1.2, Vector2(0, -30), "spark", 0.7)
	Game.toast("DUNGEON CLEARED! The boss's treasure has appeared.", Color("fee761"))
	Sfx.play("levelup")
	if not test_run:
		Game.on_dungeon_cleared(int(design.get("rank", 1)))
		for d in Game.world["dungeons"]:
			if d.get("id", -1) == dungeon.get("id", -2):
				d["cleared"] = true
		Game.add_xp(GameData.xp_to_next(int(Game.player["level"])) * 0.25)


func save_position() -> Array:
	return Game.player.get("pos", [])


func exit_dungeon() -> void:
	if Game.main:
		Game.main.leave_dungeon("exit", cleared)


func teleport_to_town() -> void:
	if Game.main:
		Game.main.leave_dungeon("town", cleared)


func on_player_died() -> void:
	if Game.main:
		Game.main.leave_dungeon("dead", cleared)


func teleport_random_room() -> void:
	var cur := cell_of(player.global_position)
	var opts := []
	for c in design["rooms"]:
		if c != cur:
			opts.append(c)
	if opts.is_empty():
		return
	var c2: Vector2i = opts[randi() % opts.size()]
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var spot := _pick_spot(c2, {}, rng, 2)
	player.global_position = tile_px(spot)
	camera.global_position = player.global_position
	camera.reset_smoothing()
	VFX.particles(self, player.global_position + Vector2(0, -10), Color("b088ff"), 24, 70.0, 0.6, Vector2(0, -30), "spark", 0.6)


func player_fall(pos: Vector2, rid: int) -> void:
	if player == null:
		return
	player.lock(1.0)
	player.invuln_t = maxf(player.invuln_t, 1.2)
	player.global_position = pos
	var tw := player.create_tween()
	tw.tween_property(player.visual, "scale", Vector2(0.1, 0.1), 0.5)
	tw.parallel().tween_property(player.visual, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func():
		var gw := int(design["grid"].x)
		var c := Vector2i(rid % gw, rid / gw) if rid >= 0 else cell_of(pos)
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var spot := _pick_spot(c, {}, rng, 2) if design["rooms"].has(c) else Vector2i(pos / T)
		player.global_position = tile_px(spot)
		player.visual.scale = Vector2.ONE
		player.visual.modulate.a = 1.0
		var dmg := int(player.max_hp * 0.1)
		if not test_run or player.hp > dmg + 1:
			player.hp = maxf(1.0, player.hp - dmg)
			float_text(player.global_position + Vector2(0, -30), "-%d (fell!)" % dmg, Color("ff6a6a"), 1.0)
		shake(3.0, 0.2))
