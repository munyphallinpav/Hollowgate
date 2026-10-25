class_name DungeonGen
extends RefCounted
## Dungeon *designs* are plain dictionaries shared by random hidden dungeons and the custom editor:
## { name, rank, biome, wall, grid: Vector2i, rooms: {Vector2i: room}, start: Vector2i, boss_room: Vector2i, boss }
## room = { size, biome, doors{n,s,e,w}, monsters[], traps[], spawners[], treasures[], tiles{Vector2i: kind}, miniboss }

const DIRS := {"n": Vector2i(0, -1), "s": Vector2i(0, 1), "e": Vector2i(1, 0), "w": Vector2i(-1, 0)}
const OPP := {"n": "s", "s": "n", "e": "w", "w": "e"}


static func default_options(rank: int = 1, biome: String = "cave") -> Dictionary:
	return {"name": "Custom Dungeon", "rank": rank, "biome": biome, "grid_w": 4, "grid_h": 4, "room_count": 8,
		"room_size": "random", "monsters": GameData.DUNGEON_BIOMES[biome]["monsters"].duplicate(), "monster_density": 1.0,
		"traps": ["spike", "arrow", "poison_gas", "boulder", "teleport", "pitfall", "bomb", "mimic"], "trap_density": 1.0,
		"spawner_density": 1.0, "treasures": 3, "boss": "random", "miniboss_count": 1, "miniboss": "random",
		"terrain": 1.0, "seed": randi() % 999999}


static func empty_room(size: String = "medium") -> Dictionary:
	return {"size": size, "biome": "", "doors": {"n": false, "s": false, "e": false, "w": false}, "monsters": [], "traps": [],
		"spawners": [], "treasures": [], "tiles": {}, "tile_styles": {}, "miniboss": ""}


static func room_dims(room: Dictionary) -> Vector2i:
	return GameData.WorldData.ROOM_SIZES.get(room.get("size", "medium"), Vector2i(15, 11))


static func allowed_monsters(biome: String, rank: int, pool: Array = []) -> Array:
	var src: Array = pool if not pool.is_empty() else GameData.DUNGEON_BIOMES[biome]["monsters"]
	var out := []
	for m in src:
		if m == "mimic" or not GameData.MONSTERS.has(m):
			continue
		if int(GameData.MONSTERS[m]["min_lv"]) <= rank + 8:
			out.append(m)
	if out.is_empty():
		var lowest := ""
		var lv := 999
		for m in src:
			if GameData.MONSTERS.has(m) and m != "mimic" and int(GameData.MONSTERS[m]["min_lv"]) < lv:
				lv = int(GameData.MONSTERS[m]["min_lv"])
				lowest = m
		out = [lowest if lowest != "" else "slime"]
	return out


static func pick_boss(biome: String, rank: int, rng: RandomNumberGenerator) -> String:
	var opts := []
	for b in GameData.DUNGEON_BIOMES[biome]["bosses"]:
		if int(GameData.MONSTERS[b]["min_lv"]) <= rank + 15:
			opts.append(b)
	if opts.is_empty():
		opts = [GameData.DUNGEON_BIOMES[biome]["bosses"][-1]]
		var best := 999
		for b in GameData.DUNGEON_BIOMES[biome]["bosses"]:
			if int(GameData.MONSTERS[b]["min_lv"]) < best:
				best = int(GameData.MONSTERS[b]["min_lv"])
				opts = [b]
	return opts[rng.randi_range(0, opts.size() - 1)]


## Random hidden dungeon by rank
static func random_design(rank: int, biome: String, seed_v: int) -> Dictionary:
	var o := default_options(rank, biome)
	o["seed"] = seed_v
	var g := clampi(3 + rank / 28, 3, 6)
	o["grid_w"] = g
	o["grid_h"] = g
	o["room_count"] = clampi(int(g * g * 0.62), 4, 24)
	o["monster_density"] = 1.0 + rank / 100.0
	o["trap_density"] = 0.6 + rank / 60.0
	o["treasures"] = 2 + rank / 25
	o["miniboss_count"] = 1 + rank / 34
	o["spawner_density"] = 0.5 + rank / 70.0
	var d := generate(o)
	d["name"] = "%s Dungeon" % GameData.DUNGEON_BIOMES[biome]["name"]
	return d


## Build a full design from editor "simple mode" options
static func generate(o: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(o.get("seed", randi()))
	var rank := clampi(int(o.get("rank", 1)), 1, 100)
	var biome: String = o.get("biome", "cave")
	var gw := clampi(int(o.get("grid_w", 4)), 2, 8)
	var gh := clampi(int(o.get("grid_h", 4)), 2, 8)
	var want := clampi(int(o.get("room_count", 8)), 2, gw * gh)
	var rooms := {}
	var start := Vector2i(rng.randi_range(0, gw - 1), gh - 1)
	rooms[start] = empty_room("medium")
	var keys := [start]
	var guard := 0
	while keys.size() < want and guard < 2000:
		guard += 1
		var from: Vector2i = keys[rng.randi_range(0, keys.size() - 1)]
		var dn: String = DIRS.keys()[rng.randi_range(0, 3)]
		var to: Vector2i = from + DIRS[dn]
		if to.x < 0 or to.y < 0 or to.x >= gw or to.y >= gh or rooms.has(to):
			continue
		var sz: String = o.get("room_size", "random")
		if sz == "random":
			sz = ["small", "medium", "medium", "large"][rng.randi_range(0, 3)]
		rooms[to] = empty_room(sz)
		rooms[from]["doors"][dn] = true
		rooms[to]["doors"][OPP[dn]] = true
		keys.append(to)
	# a few loops so it is a maze, not a tree
	for k in keys:
		for dn in ["e", "s"]:
			var nb: Vector2i = k + DIRS[dn]
			if rooms.has(nb) and not rooms[k]["doors"][dn] and rng.randf() < 0.18:
				rooms[k]["doors"][dn] = true
				rooms[nb]["doors"][OPP[dn]] = true
	var dist := bfs(rooms, start)
	var boss_room := start
	var far := -1
	for k in dist:
		if dist[k] > far:
			far = dist[k]
			boss_room = k
	rooms[boss_room]["size"] = "large"
	var d := {"name": o.get("name", "Dungeon"), "rank": rank, "biome": biome, "wall": GameData.DUNGEON_BIOMES[biome]["wall"],
		"grid": Vector2i(gw, gh), "rooms": rooms, "start": start, "boss_room": boss_room, "boss": "", "seed": int(o.get("seed", 0))}
	var boss: String = o.get("boss", "random")
	d["boss"] = pick_boss(biome, rank, rng) if boss == "random" else boss
	populate(d, o, rng)
	return d


static func bfs(rooms: Dictionary, start: Vector2i) -> Dictionary:
	var dist := {start: 0}
	var q := [start]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for dn in DIRS:
			if rooms[c]["doors"].get(dn, false):
				var nb: Vector2i = c + DIRS[dn]
				if rooms.has(nb) and not dist.has(nb):
					dist[nb] = dist[c] + 1
					q.append(nb)
	return dist


static func populate(d: Dictionary, o: Dictionary, rng: RandomNumberGenerator) -> void:
	var rank: int = d["rank"]
	var mons := allowed_monsters(d["biome"], rank, o.get("monsters", []))
	var traps: Array = o.get("traps", [])
	var mdens := float(o.get("monster_density", 1.0))
	var tdens := float(o.get("trap_density", 1.0))
	var sdens := float(o.get("spawner_density", 1.0))
	var terrain := float(o.get("terrain", 1.0))
	var candidates := []
	for k in d["rooms"]:
		if k != d["start"] and k != d["boss_room"]:
			candidates.append(k)
	for k in d["rooms"]:
		var r: Dictionary = d["rooms"][k]
		if k == d["start"]:
			continue
		var dims := room_dims(r)
		var size_bonus = {"small": 0, "medium": 1, "large": 2}.get(r["size"], 1)
		if k == d["boss_room"]:
			r["monsters"] = [{"type": mons[rng.randi_range(0, mons.size() - 1)], "count": 1 + rank / 40}]
			_terrain(r, dims, rng, terrain * 0.5, d["biome"])
			continue
		var groups := maxi(1, int(round((1 + size_bonus + rank / 40.0) * mdens * rng.randf_range(0.6, 1.2))))
		for i in groups:
			var mt: String = mons[rng.randi_range(0, mons.size() - 1)]
			var cnt := rng.randi_range(1, 3) if float(GameData.MONSTERS[mt]["hp"]) < 2.0 else 1
			r["monsters"].append({"type": mt, "count": cnt})
		if not traps.is_empty() and rng.randf() < 0.55 * tdens:
			var nt := rng.randi_range(1, 1 + int(tdens + rank / 50.0))
			for i in nt:
				r["traps"].append({"type": traps[rng.randi_range(0, traps.size() - 1)]})
		if rng.randf() < 0.22 * sdens:
			var sk: Array = GameData.WorldData.SPAWNERS.keys()
			r["spawners"].append({"type": sk[rng.randi_range(0, sk.size() - 1)]})
		_terrain(r, dims, rng, terrain, d["biome"])
	# treasures: prefer dead ends
	var nt2 := int(o.get("treasures", 3))
	candidates.sort_custom(func(a, b):
		var da := 0
		var db := 0
		for dn in d["rooms"][a]["doors"]:
			da += 1 if d["rooms"][a]["doors"][dn] else 0
		for dn in d["rooms"][b]["doors"]:
			db += 1 if d["rooms"][b]["doors"][dn] else 0
		return da < db)
	for i in nt2:
		if candidates.is_empty():
			break
		var k2: Vector2i = candidates[i % candidates.size()]
		var tier := 0 if rng.randf() < 0.6 else (1 if rng.randf() < 0.8 else 2)
		d["rooms"][k2]["treasures"].append({"type": ["chest", "silver_chest", "gold_chest"][tier]})
	# mini bosses
	var nm := int(o.get("miniboss_count", 1))
	var shuffled := candidates.duplicate()
	shuffled.shuffle()
	for i in mini(nm, shuffled.size()):
		var mb: String = o.get("miniboss", "random")
		if mb == "random":
			mb = mons[rng.randi_range(0, mons.size() - 1)]
		d["rooms"][shuffled[i]]["miniboss"] = mb


## Random interior features (pillars, pools, pits) keeping the central cross clear.
static func _terrain(r: Dictionary, dims: Vector2i, rng: RandomNumberGenerator, amount: float, biome: String) -> void:
	if amount <= 0.0:
		return
	var cx := dims.x / 2
	var cy := dims.y / 2
	var liquid: String = "lava" if biome == "lava" else "water"
	var pattern := rng.randi_range(0, 5)
	if rng.randf() > 0.75 * amount:
		return
	match pattern:
		0, 1:
			# pillars
			for p in [Vector2i(cx - 3, cy - 2), Vector2i(cx + 3, cy - 2), Vector2i(cx - 3, cy + 2), Vector2i(cx + 3, cy + 2)]:
				if p.x > 0 and p.y > 0 and p.x < dims.x - 1 and p.y < dims.y - 1:
					r["tiles"][p] = "wall"
		2:
			# pool in a corner
			var corner := Vector2i(rng.randi_range(1, 2), rng.randi_range(1, 2))
			if rng.randf() < 0.5:
				corner.x = dims.x - 4
			for yy in range(corner.y, corner.y + 2):
				for xx in range(corner.x, corner.x + 3):
					if absi(xx - cx) > 1 and absi(yy - cy) > 1:
						r["tiles"][Vector2i(xx, yy)] = liquid
		3:
			# pit pair
			for side in [-1, 1]:
				var px = cx + side * (dims.x / 4 + 1)
				for yy in range(cy - 2, cy):
					if absi(px - cx) > 1:
						r["tiles"][Vector2i(px, yy)] = "cliff"
						r["tiles"][Vector2i(px + side, yy)] = "cliff"
		4:
			# low walls
			for xx in range(2, cx - 1):
				r["tiles"][Vector2i(xx, 2)] = "wall"
			for xx in range(cx + 2, dims.x - 2):
				r["tiles"][Vector2i(xx, dims.y - 3)] = "wall"
		5:
			# liquid moat corners
			for p in [Vector2i(1, 1), Vector2i(dims.x - 2, 1), Vector2i(1, dims.y - 2), Vector2i(dims.x - 2, dims.y - 2)]:
				r["tiles"][p] = liquid


static func validate(d: Dictionary) -> String:
	if d.get("rooms", {}).is_empty():
		return "The dungeon has no rooms."
	if not d["rooms"].has(d.get("start", Vector2i(-1, -1))):
		return "Pick a start room."
	if not d["rooms"].has(d.get("boss_room", Vector2i(-1, -1))):
		return "Pick a boss room."
	if d["start"] == d["boss_room"]:
		return "Start and boss room must be different."
	var dist := bfs(d["rooms"], d["start"])
	for k in d["rooms"]:
		if not dist.has(k):
			return "Room %s is not connected to the start room." % str(k)
	return ""
