class_name Overworld
extends Level
## The procedurally generated wild world with the walled town at its centre.

const T := 16
const LOAD_RADIUS := 1
const KEEP_RADIUS := 3
const MAX_DUNGEONS := 14

var gen: WorldGen
var chunks: Dictionary = {}
var map_images: Dictionary = {}
var _pending: Array = []
var spawn_t := 0.0
var dungeon_t := 0.0
var portal_nodes: Dictionary = {}
var lamps: Array = []
var _was_night := false
var ambient: Ambient

const BUILDINGS := [
	# sprite, tile x (bottom centre), tile y (bottom row), npc sprite, role, npc name
	["bld_guild", 242, 243, "char_guildmaster", "guild", "Guild Master Hollis"],
	["bld_architect", 249, 243, "char_architect", "architect", "Architect Vera"],
	["bld_gear", 263, 243, "char_merchant", "gear", "Gear Merchant Bram"],
	["bld_blacksmith", 269, 243, "char_smith", "blacksmith", "Blacksmith Durn"],
	["bld_artifact", 275, 243, "char_collector", "artifact", "Collector Lys"],
	["bld_potion", 237, 267, "char_alchemist", "potion", "Alchemist Myra"],
	["bld_food", 243, 267, "char_cook", "food", "Cook Tobbin"],
	["bld_magic", 249, 267, "char_sage", "magic", "Sage Orren"],
	["bld_house", 264, 267, "", "", ""],
	["bld_house2", 271, 267, "", "", ""],
	["bld_house2", 238, 279, "", "", ""],
	["bld_house", 274, 279, "", "", ""],
]


func _ready() -> void:
	super._ready()
	gen = WorldGen.new(int(Game.world["seed"]))
	_build_town()
	var pos := town_spawn()
	var saved: Array = Game.player.get("pos", [])
	if saved.size() == 2:
		pos = Vector2(saved[0], saved[1])
	if Game.main and Game.main.pending_spawn != Vector2.INF:
		pos = Game.main.pending_spawn
		Game.main.pending_spawn = Vector2.INF
	spawn_player(pos)
	_update_chunks(true)
	_ensure_dungeons()
	_update_portals()
	_update_daylight(true)
	ambient = Ambient.new()
	add_child(ambient)
	Game.refresh_shops()
	Game.refresh_board()


func town_spawn() -> Vector2:
	return Vector2(256 * T + 8, 262 * T + 8)


func tile_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / T)), int(floor(p.y / T)))


func is_town() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var t := tile_of(player.global_position)
	return gen.in_town(t.x, t.y)


func _process(delta: float) -> void:
	super._process(delta)
	time_tick(delta)
	_update_daylight()
	if Engine.get_process_frames() % 8 == 0:
		_update_chunks(false)
	if not _pending.is_empty():
		_load_chunk(_pending.pop_front())
	spawn_t -= delta
	if spawn_t <= 0.0:
		spawn_t = 1.0
		_spawn_tick()
		_update_ambient()
	dungeon_t -= delta
	if dungeon_t <= 0.0:
		dungeon_t = 1.5
		_ensure_dungeons()
		_update_portals()


# ===================================================================== chunks
func _update_chunks(force: bool) -> void:
	if player == null:
		return
	var pc := Vector2i(int(floor(player.global_position.x / (WorldGen.CHUNK * T))), int(floor(player.global_position.y / (WorldGen.CHUNK * T))))
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var c := pc + Vector2i(dx, dy)
			if c.x < 0 or c.y < 0 or c.x >= WorldGen.SIZE / WorldGen.CHUNK or c.y >= WorldGen.SIZE / WorldGen.CHUNK:
				continue
			if chunks.has(c) or c in _pending:
				continue
			if force or (absi(dx) <= LOAD_RADIUS and absi(dy) <= LOAD_RADIUS):
				_load_chunk(c)
			else:
				_pending.append(c)
	for c in chunks.keys():
		if absi(c.x - pc.x) > KEEP_RADIUS or absi(c.y - pc.y) > KEEP_RADIUS:
			_unload_chunk(c)


func _load_chunk(c: Vector2i) -> void:
	if chunks.has(c):
		return
	var x0 := c.x * WorldGen.CHUNK
	var y0 := c.y * WorldGen.CHUNK
	var n := WorldGen.CHUNK
	var ters := {}
	var biomes := {}
	for yy in range(y0 - 1, y0 + n + 1):
		for xx in range(x0 - 1, x0 + n + 1):
			var bi := "grass" if gen.in_town(xx, yy) else gen.biome_at(xx, yy)
			biomes[Vector2i(xx, yy)] = bi
			ters[Vector2i(xx, yy)] = gen.terrain_at(xx, yy, bi)
	var terrain_f := func(x: int, y: int) -> String:
		return ters.get(Vector2i(x, y), "grass")
	var deco_f := func(x: int, y: int) -> String:
		return gen.deco_at(x, y, ters.get(Vector2i(x, y), "grass"), biomes.get(Vector2i(x, y), ""))
	var img := TileRenderer.render(x0, y0, n, n, terrain_f, deco_f, "town")
	var spr := Sprite2D.new()
	spr.texture = ImageTexture.create_from_image(img)
	spr.centered = false
	spr.position = Vector2(x0 * T, y0 * T)
	ground.add_child(spr)
	var body := StaticBody2D.new()
	body.collision_layer = 2
	TileRenderer.add_collision(body, x0, y0, n, n, func(x, y): return ters[Vector2i(x, y)] in WorldGen.BLOCKED)
	add_child(body)
	var wall_body := StaticBody2D.new()
	wall_body.collision_layer = 1
	TileRenderer.add_collision(wall_body, x0, y0, n, n, func(x, y): return ters[Vector2i(x, y)] == "wall")
	add_child(wall_body)
	var holder := Node2D.new()
	holder.y_sort_enabled = true
	entities.add_child(holder)
	var total := float(Game.world["total"])
	var harvested: Dictionary = Game.world["harvested"]
	var near_dungeons := []
	for d in Game.world["dungeons"]:
		near_dungeons.append(Vector2i(d["tile"][0], d["tile"][1]))
	for yy in range(y0, y0 + n):
		for xx in range(x0, x0 + n):
			var ter: String = ters[Vector2i(xx, yy)]
			var obj := gen.object_at(xx, yy, ter, biomes[Vector2i(xx, yy)])
			if obj == "":
				continue
			var key := "%d,%d" % [xx, yy]
			if harvested.has(key):
				if float(harvested[key]) > total:
					continue
				harvested.erase(key)
			var skip := false
			for dt in near_dungeons:
				if absi(dt.x - xx) <= 2 and absi(dt.y - yy) <= 2:
					skip = true
					break
			if skip:
				continue
			var h := Harvestable.create(obj, key)
			h.position = Vector2(xx * T + 8, yy * T + 12)
			holder.add_child(h)
	chunks[c] = {"sprite": spr, "body": body, "wall": wall_body, "holder": holder}
	# explored map
	var key2 := "%d,%d" % [c.x, c.y]
	Game.world["explored"][key2] = true
	if not map_images.has(c):
		map_images[c] = _map_image(x0, y0, n, ters, holder)


func _map_image(x0: int, y0: int, n: int, ters: Dictionary, holder: Node2D) -> Image:
	var im := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	for yy in n:
		for xx in n:
			im.set_pixel(xx, yy, WorldGen.MAP_COLORS.get(ters[Vector2i(x0 + xx, y0 + yy)], Color.MAGENTA))
	for h in holder.get_children():
		var t := tile_of(h.position)
		var lx := t.x - x0
		var ly := t.y - y0
		if lx >= 0 and ly >= 0 and lx < n and ly < n:
			im.set_pixel(lx, ly, im.get_pixel(lx, ly).darkened(0.35))
	return im


## Map pixels for a chunk (generated on demand for explored chunks that are not loaded).
func get_map_image(c: Vector2i) -> Image:
	if map_images.has(c):
		return map_images[c]
	var x0 := c.x * WorldGen.CHUNK
	var y0 := c.y * WorldGen.CHUNK
	var n := WorldGen.CHUNK
	var im := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	for yy in n:
		for xx in n:
			var ter := gen.terrain_at(x0 + xx, y0 + yy)
			var col: Color = WorldGen.MAP_COLORS.get(ter, Color.MAGENTA)
			if gen.object_at(x0 + xx, y0 + yy, ter) != "":
				col = col.darkened(0.35)
			im.set_pixel(xx, yy, col)
	map_images[c] = im
	return im


func _unload_chunk(c: Vector2i) -> void:
	var ch: Dictionary = chunks[c]
	for k in ["sprite", "body", "wall", "holder"]:
		if is_instance_valid(ch[k]):
			ch[k].queue_free()
	chunks.erase(c)


# ===================================================================== town
func _build_town() -> void:
	var pz := Vector2(256 * T + 8, 255 * T + 8)
	_prop("prop_fountain", pz, Vector2(40, 12))
	for b in BUILDINGS:
		var tex := Art.obj(b[0])
		var bottom := Vector2(int(b[1]) * T + 8, (int(b[2]) + 1) * T)
		var s := StaticBody2D.new()
		s.position = bottom
		s.collision_layer = 1
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.offset = Vector2(0, -tex.get_height() / 2.0)
		s.add_child(spr)
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = Vector2(tex.get_width() - 8, 26)
		cs.shape = rs
		cs.position = Vector2(0, -13)
		s.add_child(cs)
		add_entity(s)
		if b[4] != "":
			var npc := NPC.new()
			npc.role = b[4]
			npc.npc_name = b[5]
			npc.sprite_key = b[3]
			npc.position = bottom + Vector2(0, 14)
			add_entity(npc)
			var lamp_l := _light(bottom + Vector2(-tex.get_width() * 0.3, -20), Color(1, 0.8, 0.5), 0.9)
			lamps.append(lamp_l)
	# waypoint
	var wp := Portal.new()
	wp.kind = "waypoint"
	wp.position = Vector2(262 * T + 8, 259 * T + 8)
	add_entity(wp)
	# market stalls and props
	var props := [["prop_stall0", 236, 250], ["prop_stall1", 243, 250], ["prop_stall2", 270, 250], ["prop_stall0", 277, 250],
		["prop_barrel", 246, 260], ["prop_crate", 247, 261], ["prop_barrel", 266, 252], ["prop_crate", 278, 262],
		["prop_anvil", 272, 246], ["prop_banner", 252, 247], ["prop_banner", 260, 247], ["prop_crate", 234, 270],
		["prop_barrel", 260, 271], ["prop_banner", 252, 264], ["prop_banner", 260, 264]]
	for p in props:
		_prop(p[0], Vector2(int(p[1]) * T + 8, (int(p[2]) + 1) * T), Vector2(16, 8))
	for lp in [[252, 249], [260, 249], [252, 262], [260, 262], [240, 256], [272, 256], [256, 236], [256, 276]]:
		_prop("prop_lamp", Vector2(int(lp[0]) * T + 8, (int(lp[1]) + 1) * T), Vector2(4, 4))
		lamps.append(_light(Vector2(int(lp[0]) * T + 8, int(lp[1]) * T - 10), Color(1, 0.85, 0.55), 1.0))
	# wall towers
	var towers := [[230, 230], [281, 230], [230, 281], [281, 281], [253, 230], [258, 230], [253, 281], [258, 281],
		[230, 253], [230, 258], [281, 253], [281, 258]]
	for tw in towers:
		_prop("prop_tower", Vector2(int(tw[0]) * T + 8, (int(tw[1]) + 1) * T + 4), Vector2(24, 12))
	# trees inside town corners
	for tr in [[234, 234], [278, 234], [235, 276], [277, 275], [246, 233], [266, 233]]:
		_prop("tree_oak", Vector2(int(tr[0]) * T + 8, (int(tr[1]) + 1) * T), Vector2(6, 6))
	# guards outside every gate
	var guard_pos := [[253, 228], [258, 228], [253, 283], [258, 283], [228, 253], [228, 258], [283, 253], [283, 258]]
	for gp in guard_pos:
		var g := Guard.new()
		g.position = Vector2(int(gp[0]) * T + 8, int(gp[1]) * T + 8)
		add_entity(g)


func _prop(name: String, bottom: Vector2, col_size: Vector2) -> StaticBody2D:
	var tex := Art.obj(name)
	var s := StaticBody2D.new()
	s.position = bottom
	s.collision_layer = 1
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.offset = Vector2(0, -tex.get_height() / 2.0 + 1)
	s.add_child(spr)
	if col_size != Vector2.ZERO:
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = col_size
		cs.shape = rs
		cs.position = Vector2(0, -col_size.y / 2.0)
		s.add_child(cs)
	add_entity(s)
	return s


func _light(pos: Vector2, col: Color, scale: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = Art.fx("light")
	l.color = col
	l.texture_scale = scale * 2.5
	l.energy = 0.0
	l.position = pos
	add_child(l)
	return l


# ===================================================================== day / night
func _update_daylight(instant: bool = false) -> void:
	var f := Game.day_fraction()
	var keys := [[0.0, Color(0.30, 0.33, 0.55)], [0.18, Color(0.36, 0.38, 0.6)], [0.25, Color(0.85, 0.7, 0.72)], [0.32, Color(1, 1, 1)],
		[0.7, Color(1, 1, 1)], [0.78, Color(1.0, 0.75, 0.6)], [0.86, Color(0.36, 0.38, 0.6)], [1.0, Color(0.30, 0.33, 0.55)]]
	var col := Color.WHITE
	for i in keys.size() - 1:
		if f >= keys[i][0] and f <= keys[i + 1][0]:
			col = keys[i][1].lerp(keys[i + 1][1], (f - keys[i][0]) / (keys[i + 1][0] - keys[i][0]))
			break
	canvas_mod.color = col
	var night := 1.0 - clampf((col.r + col.g + col.b) / 3.0, 0.0, 1.0)
	for l in lamps:
		l.energy = clampf(night * 2.2, 0.0, 1.2)
	var is_night := Game.is_night()
	if is_night != _was_night and not instant:
		Game.toast("Night falls... undead roam the land." if is_night else "The sun rises.", Color("c8b8ff") if is_night else Color("fee761"))
	_was_night = is_night


func _update_ambient() -> void:
	if ambient == null or player == null:
		return
	var t := tile_of(player.global_position)
	if gen.in_town(t.x, t.y, 2):
		ambient.set_kind("fireflies" if Game.is_night() else "")
		return
	var night := Game.is_night()
	var k := ""
	match gen.biome_at(t.x, t.y):
		"snow":
			k = "snow"
		"volcanic":
			k = "embers"
		"mushroom":
			k = "spores"
		"swamp":
			k = "swamp"
		"desert":
			k = "dust"
		"forest":
			k = "fireflies" if night else "leaves"
		"grass":
			k = "fireflies" if night else ""
	ambient.set_kind(k)


func player_light_energy() -> float:
	var c := canvas_mod.color
	return clampf((1.0 - (c.r + c.g + c.b) / 3.0) * 1.8, 0.0, 1.0)


# ===================================================================== spawning
func _spawn_tick() -> void:
	if player == null or player.dead:
		return
	var pp := player.global_position
	var count := 0
	for m in get_tree().get_nodes_in_group("monsters"):
		if not is_instance_valid(m) or m.dead:
			continue
		var d: float = m.global_position.distance_to(pp)
		if d > 560.0 and (m.target == null):
			m.queue_free()
			continue
		if m.summoner == null:
			count += 1
	var cap := 12 + (4 if Game.is_night() else 0)
	if count >= cap:
		return
	for attempt in 6:
		var ang := randf() * TAU
		var dist := randf_range(230.0, 340.0)
		var pos := pp + Vector2.from_angle(ang) * dist
		var t := tile_of(pos)
		if gen.in_town(t.x, t.y, 6):
			continue
		var ter := gen.terrain_at(t.x, t.y)
		if gen.is_blocked(ter):
			continue
		if not is_walkable(pos):
			continue
		_spawn_group(pos, t)
		return


func _spawn_group(pos: Vector2, t: Vector2i) -> void:
	var biome := gen.biome_at(t.x, t.y)
	var lvl := clampi(gen.level_at(t.x, t.y) + randi_range(-2, 2), 1, 100)
	var pool := []
	var weights := []
	for m in GameData.BIOMES[biome]["monsters"]:
		var md: Dictionary = GameData.MONSTERS[m]
		if int(md["min_lv"]) <= lvl + 2:
			pool.append(m)
			weights.append(float(md["weight"]))
	if Game.is_night():
		for m in ["zombie", "skeleton"]:
			if int(GameData.MONSTERS[m]["min_lv"]) <= lvl + 6:
				pool.append(m)
				weights.append(6.0)
		if lvl >= 30:
			pool.append("vampire")
			weights.append(3.0)
	if pool.is_empty():
		pool = ["slime"]
		weights = [1.0]
	var total := 0.0
	for w in weights:
		total += w
	var r := randf() * total
	var mt: String = pool[0]
	for i in pool.size():
		r -= weights[i]
		if r <= 0.0:
			mt = pool[i]
			break
	var n := 1
	if mt in ["wolf", "slime", "goblin"]:
		n = randi_range(2, 4) if lvl >= 8 else randi_range(1, 3)
	elif mt in ["zombie", "skeleton", "rabbit"]:
		n = randi_range(1, 3) if lvl >= 8 else randi_range(1, 2)
	var opts := {}
	if mt == "slime":
		var el = {"volcanic": "fire", "beach": "water", "snow": "water", "swamp": "dark", "mushroom": "dark", "desert": "earth"}.get(biome, "earth")
		opts = {"tint": GameData.BIOMES[biome]["slime"], "element": el}
	for i in n:
		var tier := "elite" if randf() < 0.04 and not GameData.MONSTERS[mt].get("passive", false) else "normal"
		var p := pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		if is_walkable(p):
			spawn_monster(mt, p, lvl, tier, opts)


func can_aggro(m: Actor, t: Actor) -> bool:
	# monsters never chase into town
	var tt := tile_of(t.global_position)
	return not gen.in_town(tt.x, tt.y, 1) or t is Guard


# ===================================================================== dungeons on the map
func _ensure_dungeons() -> void:
	var ds: Array = Game.world["dungeons"]
	var total := float(Game.world["total"])
	for d in ds.duplicate():
		if d.get("cleared", false) or (not d.get("custom", false) and float(d["expires"]) <= total):
			ds.erase(d)
			if portal_nodes.has(d["id"]):
				var pn = portal_nodes[d["id"]]
				if is_instance_valid(pn):
					VFX.particles(self, pn.global_position, Color("b088ff"), 24, 60.0, 0.8, Vector2(0, -40), "spark", 0.6)
					pn.queue_free()
				portal_nodes.erase(d["id"])
	var non_custom := 0
	for d in ds:
		if not d.get("custom", false):
			non_custom += 1
	var spawned := 0
	var cap := 4 if total > 10.0 else MAX_DUNGEONS
	while non_custom < MAX_DUNGEONS and spawned < cap:
		if _spawn_random_dungeon():
			non_custom += 1
			spawned += 1
			if total > 5.0 and spawned == 1:
				Game.toast("A hidden dungeon has appeared somewhere! (check the map)", Color("c79bff"))
		else:
			break


func _spawn_random_dungeon() -> bool:
	for attempt in 40:
		var ang := randf() * TAU
		var dist := randf_range(34.0, 232.0)
		var t := WorldGen.CENTER + Vector2i(int(cos(ang) * dist), int(sin(ang) * dist))
		var ter := gen.terrain_at(t.x, t.y)
		if gen.is_blocked(ter) or gen.in_town(t.x, t.y, 6) or gen.is_road(t.x, t.y):
			continue
		var ok := true
		for dx in range(-2, 3):
			for dy in range(-1, 3):
				if gen.is_blocked(gen.terrain_at(t.x + dx, t.y + dy)):
					ok = false
		for d in Game.world["dungeons"]:
			if Vector2(d["tile"][0], d["tile"][1]).distance_to(Vector2(t)) < 24.0:
				ok = false
		if not ok:
			continue
		var biome := gen.biome_at(t.x, t.y)
		var dbiome: String = WorldGen.BIOME_DUNGEON.get(biome, "cave")
		if randf() < 0.3:
			var keys := GameData.DUNGEON_BIOMES.keys()
			dbiome = keys[randi() % keys.size()]
		var rank := clampi(gen.level_at(t.x, t.y) + randi_range(-3, 6), 1, 100)
		var id := int(Game.world["next_dungeon"])
		Game.world["next_dungeon"] = id + 1
		Game.world["dungeons"].append({"id": id, "tile": [t.x, t.y], "rank": rank, "biome": dbiome, "seed": randi(),
			"expires": float(Game.world["total"]) + randf_range(900.0, 2400.0), "custom": false, "cleared": false})
		return true
	return false


func _update_portals() -> void:
	if player == null:
		return
	var pp := player.global_position
	var alive_ids := {}
	for d in Game.world["dungeons"]:
		alive_ids[d["id"]] = true
		var wp := Vector2(int(d["tile"][0]) * T + 8, int(d["tile"][1]) * T + 8)
		var dist := wp.distance_to(pp)
		if dist < 700.0 and not portal_nodes.has(d["id"]):
			var p := Portal.new()
			p.kind = "entrance"
			p.dungeon = d
			p.position = wp
			add_entity(p)
			portal_nodes[d["id"]] = p
			# clear harvestables around entrance
			for h in get_tree().get_nodes_in_group("harvestable"):
				if h.global_position.distance_to(wp) < 30.0:
					h.queue_free()
		elif dist > 900.0 and portal_nodes.has(d["id"]):
			if is_instance_valid(portal_nodes[d["id"]]):
				portal_nodes[d["id"]].queue_free()
			portal_nodes.erase(d["id"])
	for id in portal_nodes.keys():
		if not alive_ids.has(id):
			if is_instance_valid(portal_nodes[id]):
				portal_nodes[id].queue_free()
			portal_nodes.erase(id)


func place_custom_dungeon(design: Dictionary) -> bool:
	if is_town():
		Game.toast("You can't raise a dungeon inside town.", Color("ff7a7a"))
		return false
	if design.is_empty():
		return false
	var pos := player.global_position + player.aim * 36.0
	var t := tile_of(pos)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if gen.is_blocked(gen.terrain_at(t.x + dx, t.y + dy)):
				Game.toast("Not enough open ground here.", Color("ff7a7a"))
				return false
	var id := int(Game.world["next_dungeon"])
	Game.world["next_dungeon"] = id + 1
	var d := {"id": id, "tile": [t.x, t.y], "rank": int(design.get("rank", 1)), "biome": design.get("biome", "cave"), "seed": randi(),
		"expires": 1e12, "custom": true, "design": design.duplicate(true), "name": design.get("name", "Custom Dungeon"), "cleared": false}
	Game.world["dungeons"].append(d)
	for h in get_tree().get_nodes_in_group("harvestable"):
		if h.global_position.distance_to(Vector2(t) * T) < 36.0:
			h.queue_free()
	VFX.explosion(self, Vector2(t) * T + Vector2(8, 8), 40.0, Color("b088ff"), "portal")
	VFX.pillar(self, Vector2(t) * T + Vector2(8, 8), 10.0, 140.0, Color("c79bff"), 1.0)
	_update_portals()
	Game.toast("The dungeon '%s' rises from the ground!" % d["name"], Color("c79bff"))
	return true


# ===================================================================== travel
func save_position() -> Array:
	if player and is_instance_valid(player):
		return [player.global_position.x, player.global_position.y]
	return []


func teleport_to_town() -> void:
	if not is_town():
		Game.player["last_field"] = [player.global_position.x, player.global_position.y]
	_teleport_player(town_spawn())
	Game.toast("Welcome back to Hollowgate.", Color("8fd3ff"))


func use_waypoint() -> void:
	var lf: Array = Game.player.get("last_field", [])
	if lf.size() != 2:
		Game.toast("The waypoint has no destination yet. Teleport to town from the wild first.", Color("aab4c8"))
		return
	_teleport_player(Vector2(lf[0], lf[1]))


func _teleport_player(to: Vector2) -> void:
	VFX.particles(self, player.global_position + Vector2(0, -10), Color("8fd3ff"), 30, 70.0, 0.6, Vector2(0, -60), "spark", 0.6)
	VFX.pillar(self, player.global_position, 6.0, 80.0, Color("8fd3ff"), 0.5)
	for m in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(m) and m.target == player:
			m.target = null
	player.global_position = to
	camera.global_position = to
	camera.reset_smoothing()
	_update_chunks(true)
	_update_portals()
	VFX.pillar(self, to, 6.0, 80.0, Color("8fd3ff"), 0.6)
	VFX.particles(self, to + Vector2(0, -10), Color("8fd3ff"), 30, 70.0, 0.6, Vector2(0, -60), "spark", 0.6)
	Sfx.play("portal")


func on_player_died() -> void:
	var lost := int(int(Game.player["gold"]) * 0.1)
	Game.add_gold(-lost)
	Game.toast("You were defeated... You wake up in town. (-%d gold)" % lost, Color("ff7a7a"))
	player.revive_at(town_spawn(), 1.0)
	camera.global_position = player.global_position
	camera.reset_smoothing()
	_update_chunks(true)
	Game.player["satiety"] = maxf(float(Game.player["satiety"]), 50.0)


func enter_dungeon(d: Dictionary) -> void:
	if Game.main:
		Game.player["pos"] = [d["tile"][0] * T + 8, d["tile"][1] * T + 34]
		Game.main.enter_dungeon(d, false)
