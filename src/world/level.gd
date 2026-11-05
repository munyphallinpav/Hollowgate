class_name Level
extends Node2D
## Shared base for the overworld and dungeons: layers, camera, spatial queries,
## damage numbers, loot drops and monster death handling.

var player: Player
var ground: Node2D
var entities: Node2D
var fx_under: Node2D
var fx_over: Node2D
var fx_proj: Node2D
var fx_text: Node2D
var camera: Camera2D
var canvas_mod: CanvasModulate
var shake_amt := 0.0
var shake_t := 0.0
var boss: Monster = null
var _team_cache: Dictionary = {}
var _team_frame := -1
var _hitstop := false
## Spectator camera (test runs watched instead of played): follows `spec_target`, or flies freely.
var spectate := false
var spec_target: Actor = null
var spec_free := false
var spec_pos := Vector2.ZERO


func _init() -> void:
	ground = Node2D.new()
	ground.name = "Ground"
	ground.z_index = -20
	add_child(ground)
	fx_under = Node2D.new()
	fx_under.name = "FxUnder"
	fx_under.z_index = -5
	add_child(fx_under)
	entities = Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	add_child(entities)
	fx_proj = Node2D.new()
	fx_proj.name = "Projectiles"
	fx_proj.z_index = 8
	add_child(fx_proj)
	fx_over = Node2D.new()
	fx_over.name = "FxOver"
	fx_over.z_index = 10
	add_child(fx_over)
	fx_text = Node2D.new()
	fx_text.name = "FxText"
	fx_text.z_index = 50
	add_child(fx_text)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	add_child(camera)
	canvas_mod = CanvasModulate.new()
	add_child(canvas_mod)


func _ready() -> void:
	Game.level_node = self
	camera.zoom = Vector2.ONE * Settings.world_zoom(Settings.camera_zoom)
	camera.make_current()
	call_deferred("sync_party", true)


func _exit_tree() -> void:
	if Duel.active:
		Duel.cancel("left the area")
	# adventurers present here go back to the simulation (position, HP and MP are kept)
	for n in NpcWorld.npcs():
		var a = NpcWorld.actor_of(n)
		if a != null and is_ancestor_of(a):
			despawn_adventurer(n)


func spawn_player(pos: Vector2) -> void:
	if player == null or not is_instance_valid(player):
		player = Player.new()
		player.position = pos
		entities.add_child(player)
	else:
		player.global_position = pos
	camera.global_position = pos
	camera.reset_smoothing()


func _process(delta: float) -> void:
	Duel.update(delta)
	if spectate:
		_spectate_camera(delta)
	elif player and is_instance_valid(player):
		var target := player.global_position + Vector2(0, -10)
		var mouse_off := (get_global_mouse_position() - player.global_position).limit_length(60.0) * 0.12
		camera.global_position = target + mouse_off
	if shake_t > 0.0:
		shake_t -= delta
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt if Settings.screen_shake else Vector2.ZERO
	else:
		camera.offset = Vector2.ZERO
	var z := Settings.world_zoom(Settings.camera_zoom)
	camera.zoom = camera.zoom.lerp(Vector2(z, z), clampf(delta * 8.0, 0.0, 1.0))
	if absf(camera.zoom.x - z) < 0.002:
		camera.zoom = Vector2(z, z)  # land exactly on the crisp zoom


func _unhandled_input(event: InputEvent) -> void:
	var zmin := 1.0 if spectate else 2.0  # spectators can pull back for an overview
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			Settings.camera_zoom = clampf(Settings.camera_zoom + 0.25, zmin, 4.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			Settings.camera_zoom = clampf(Settings.camera_zoom - 0.25, zmin, 4.5)
	if spectate and (event is InputEventKey or event is InputEventAction) and event.is_pressed() and not event.is_echo():
		for i in 3:
			if event.is_action_pressed("skill_%d" % (i + 1)):
				var rs := spectate_targets()
				if i < rs.size():
					spec_target = rs[i]
					spec_free = false
				get_viewport().set_input_as_handled()
		if event.is_action_pressed("dash"):
			spec_free = not spec_free
			spec_pos = camera.global_position
			get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ spectating
func spectating() -> bool:
	return spectate


## Starts watching instead of playing: the hero turns into an invisible, untouchable ghost.
func start_spectating() -> void:
	spectate = true
	if player and is_instance_valid(player):
		player.set_ghost(true)
	var rs := spectate_targets()
	spec_target = rs[0] if not rs.is_empty() else null
	spec_pos = camera.global_position


## The hero-side actors that can be watched (living ones first).
func spectate_targets() -> Array:
	var out := []
	for a in focus_actors():
		if a != player:
			out.append(a)
	return out


func _spectate_camera(delta: float) -> void:
	if spec_free:
		var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		spec_pos += v * 260.0 * delta / maxf(0.5, camera.zoom.x / 3.0)
		camera.global_position = spec_pos
		return
	if spec_target == null or not is_instance_valid(spec_target) or spec_target.dead:
		var rs := spectate_targets()
		if not rs.is_empty():
			spec_target = rs[0]
	if spec_target and is_instance_valid(spec_target):
		camera.global_position = spec_target.global_position + Vector2(0, -10)
		spec_pos = camera.global_position


## Where the action is: what the camera looks at (the hero, or the watched actor).
func view_center() -> Vector2:
	if spectate:
		return camera.global_position
	if player and is_instance_valid(player):
		return player.global_position
	return camera.global_position


## Actors that keep the level "awake" around them: the hero (unless a ghost) and party members /
## test-run runners present in this level.
func focus_actors() -> Array:
	var out := []
	if player and is_instance_valid(player) and not player.ghost and not player.dead:
		out.append(player)
	for id in NpcWorld.actors:
		var a = NpcWorld.actors[id]
		if a != null and is_instance_valid(a) and not a.dead and a.mode in ["follow", "run"] and is_ancestor_of(a):
			out.append(a)
	return out


# ------------------------------------------------------------------ adventurer actors / the party
func spawn_adventurer(n: Dictionary, pos: Vector2) -> Adventurer:
	var old = NpcWorld.actor_of(n)
	if old != null:
		return old
	var a := Adventurer.new()
	a.npc = n
	a.position = snap_walkable(pos)
	n["physical"] = true
	NpcWorld.actors[int(n["id"])] = a
	add_entity(a)
	return a


func despawn_adventurer(n: Dictionary) -> void:
	var a = NpcWorld.actor_of(n)
	NpcWorld.actors.erase(int(n["id"]))
	n["physical"] = false
	if a:
		if self is Overworld:
			n["pos"] = [a.global_position.x, a.global_position.y]
		if not a.dead:
			n["hp_frac"] = clampf(a.hp / maxf(1.0, a.max_hp), 0.05, 1.0)
			n["mp_frac"] = clampf(a.mp / maxf(1.0, a.max_mp), 0.0, 1.0)
		a.queue_free()


func snap_walkable(p: Vector2) -> Vector2:
	if is_walkable(p):
		return p
	for ring in range(1, 10):
		for k in 12:
			var q := p + Vector2.from_angle(k * TAU / 12.0) * ring * 14.0
			if is_walkable(q):
				return q
	return p


## Keeps the hero's party members present next to the hero in this level (they travel with you,
## into dungeons and test runs). Adventurers that left the party go back to their own life.
func sync_party(_joined: bool = true) -> void:
	if player == null or not is_instance_valid(player) or Game.player.is_empty() or spectate:
		return
	var i := 0
	for n in Social.party_members():
		i += 1
		if n["state"] == "dead":
			continue
		if Game.test_run and self is DungeonLevel and not int(n["id"]) in self.runner_ids:
			continue  # left out of this test run
		var a = NpcWorld.actor_of(n)
		if a == null:
			var off := Vector2(-22.0 if i == 1 else 22.0, 14.0)
			a = spawn_adventurer(n, player.global_position + off)
		if not Game.test_run or a.mode != "run":
			if a.mode != "follow":
				a.call_deferred("_make_tag")
			a.mode = "follow"
			a.leader = player
	for id in NpcWorld.actors.keys():
		var a2 = NpcWorld.actors[id]
		if a2 == null or not is_instance_valid(a2) or Social.in_party(a2.npc) or a2.mode != "follow" or a2.leader != player:
			continue
		if Game.test_run:
			continue
		a2.mode = "routine"
		a2.leader = null
		a2._make_tag()
		if not (self is Overworld):
			# outside the overworld the ex-member makes its own way back to town
			var spot := NpcWorld.town_spot(int(id) * 7 + 1)
			a2.npc["pos"] = [spot.x, spot.y]
			despawn_adventurer(a2.npc)


# ------------------------------------------------------------------ layers
func add_fx(node: Node, layer: String = "over") -> void:
	match layer:
		"under", "under_entities":
			fx_under.add_child(node)
		"projectiles":
			fx_proj.add_child(node)
		"text":
			fx_text.add_child(node)
		_:
			fx_over.add_child(node)


func add_entity(node: Node) -> void:
	entities.add_child(node)


# ------------------------------------------------------------------ queries
## Living actors of a team. Cached per main-loop iteration (process frame): nodes freed with
## queue_free() are only deleted at the end of an iteration, so the cache never holds freed objects.
## Entries are still re-validated because actors can be freed immediately (free()) by other code.
func get_team_actors(team: String) -> Array:
	var f := Engine.get_process_frames()
	if f != _team_frame:
		_team_frame = f
		_team_cache.clear()
	if not _team_cache.has(team):
		var arr := []
		for n in get_tree().get_nodes_in_group("team_" + team):
			if is_instance_valid(n) and not n.dead and n.is_inside_tree():
				arr.append(n)
		_team_cache[team] = arr
	else:
		var arr2: Array = _team_cache[team]
		for i in range(arr2.size() - 1, -1, -1):
			if not is_instance_valid(arr2[i]):
				arr2.remove_at(i)
	return _team_cache[team]


func actors_in_radius(pos: Vector2, r: float, team: String) -> Array:
	var out := []
	for a in get_team_actors(team):
		if not a.dead and a.global_position.distance_to(pos) <= r + a.radius:
			out.append(a)
	return out


func actors_in_arc(pos: Vector2, dir: Vector2, r: float, arc_deg: float, team: String) -> Array:
	var out := []
	var half := deg_to_rad(arc_deg) * 0.5
	for a in get_team_actors(team):
		if a.dead:
			continue
		var d: Vector2 = a.global_position - pos
		var dist := d.length()
		if dist > r + a.radius:
			continue
		if dist < a.radius + 4.0 or absf(dir.angle_to(d)) <= half + atan2(a.radius, maxf(dist, 1.0)):
			out.append(a)
	return out


func actors_in_line(start: Vector2, dir: Vector2, length: float, half_w: float, team: String) -> Array:
	var out := []
	var d := dir.normalized()
	for a in get_team_actors(team):
		if a.dead:
			continue
		var rel: Vector2 = a.global_position - start
		var along := rel.dot(d)
		if along < -a.radius or along > length + a.radius:
			continue
		var perp := absf(rel.cross(d))
		if perp <= half_w + a.radius:
			out.append(a)
	return out


func nearest_actor(pos: Vector2, r: float, team: String) -> Actor:
	var best: Actor = null
	var bd := r
	for a in get_team_actors(team):
		var d: float = a.global_position.distance_to(pos)
		if not a.dead and d < bd:
			bd = d
			best = a
	return best


func hit_props(pos: Vector2, r: float, attacker) -> void:
	for h in get_tree().get_nodes_in_group("harvestable"):
		if is_instance_valid(h) and h.global_position.distance_to(pos) <= r + 6.0:
			h.hit_by(attacker)


func ray_blocked(from: Vector2, to: Vector2, low: bool = false) -> bool:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(from, to, 1 | (2 if low else 0))
	q.collide_with_areas = false
	return not space.intersect_ray(q).is_empty()


func is_walkable(pos: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var q := PhysicsPointQueryParameters2D.new()
	q.position = pos
	q.collision_mask = 1 | 2
	return space.intersect_point(q, 1).is_empty()


func path_dir(m: Actor, to: Vector2) -> Vector2:
	return (to - m.global_position).normalized()


func can_aggro(_m: Actor, _t: Actor) -> bool:
	return true


func is_town() -> bool:
	return false


func player_light_energy() -> float:
	return 0.0


# ------------------------------------------------------------------ feedback
func damage_number(pos: Vector2, value: int, color: Color, crit: bool, scale: float = 1.0) -> void:
	var txt := str(value) + ("!" if crit else "")
	var size := (7.0 if not crit else 9.0) * scale
	var n := WorldText.make(txt, size, color, 2)
	n.position = pos
	add_fx(n, "text")
	var tw := n.create_tween()
	var rise := Vector2(randf_range(-8, 8), -18.0 - (6.0 if crit else 0.0))
	if crit:
		n.scale *= 1.6
		tw.tween_property(n, "scale", Vector2.ONE / WorldText.OVERSAMPLE, 0.12)
	tw.tween_property(n, "position", pos + rise, 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(n, "modulate:a", 0.0, 0.35).set_delay(0.35)
	tw.tween_callback(n.queue_free)


func float_text(pos: Vector2, text: String, color: Color, scale: float = 1.0) -> void:
	var n := WorldText.make(text, 6.0 * scale, color, 2)
	n.position = pos
	add_fx(n, "text")
	var tw := n.create_tween()
	tw.tween_property(n, "position", pos + Vector2(0, -16), 0.9).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "modulate:a", 0.0, 0.4).set_delay(0.6)
	tw.tween_callback(n.queue_free)


## Camera shake. With `at`, the shake fades with distance from the hero (far-away explosions barely move the camera).
func shake(amount: float, dur: float, at: Vector2 = Vector2.INF) -> void:
	if at != Vector2.INF and player and is_instance_valid(player):
		amount *= clampf(1.0 - (player.global_position.distance_to(at) - 120.0) / 280.0, 0.0, 1.0)
		if amount <= 0.2:
			return
	if amount >= shake_amt or shake_t <= 0.0:
		shake_amt = amount
	shake_t = maxf(shake_t, dur)


func hitstop(t: float) -> void:
	if _hitstop or get_tree().paused:
		return
	_hitstop = true
	Engine.time_scale = 0.08 * DebugMode.game_speed
	var tm := get_tree().create_timer(t, true, false, true)
	tm.timeout.connect(func():
		Engine.time_scale = DebugMode.game_speed
		_hitstop = false)


func hurt_flash() -> void:
	if Game.main and Game.main.hud:
		Game.main.hud.hurt_flash()


# ------------------------------------------------------------------ loot
func drop_item(it: Dictionary, pos: Vector2) -> void:
	var p := Pickup.create_item(it)
	p.position = pos + Vector2(randf_range(-4, 4), randf_range(-2, 2))
	add_entity(p)


func drop_gold(n: int, pos: Vector2) -> void:
	if n <= 0:
		return
	var p := Pickup.create_gold(n)
	p.position = pos
	add_entity(p)


func spawn_monster(type: String, pos: Vector2, lvl: int, tier: String = "normal", opts: Dictionary = {}) -> Monster:
	var m := Monster.create(type, lvl, tier, opts)
	m.position = pos
	m.room_id = int(opts.get("room", -1))
	add_entity(m)
	return m


func on_monster_died(m: Monster, killer) -> void:
	if m == boss:
		boss = null
	# The monster's tag owner (first hero/NPC to hit it) gets the rewards; otherwise whoever killed it.
	# Kills owned by NPC adventurers (or their summons) reward that adventurer, not the hero.
	var credit = m.tag_owner()
	if credit == null:
		credit = Monster.hero_behind(killer)
	if credit == null:
		credit = killer if killer != null and is_instance_valid(killer) else null
	# A kill by one of the hero's party members counts for the whole party: XP is shared and the loot
	# drops for the hero like any of the hero's kills.
	if credit is Adventurer and not Social.in_party(credit.npc):
		if m.summoner == null and not (m.no_loot and m.tier == "normal") and not Game.test_run:
			NpcWorld.on_actor_kill(credit.npc, m)
		credit.on_kill(m)
		return
	if credit is Adventurer:
		credit.on_kill(m)
		if m.summoner == null:
			NpcWorld.quest_kill(credit.npc, m.mtype, m.tier)
	if m.summoner != null or m.no_loot and m.tier == "normal":
		if m.summoner == null:
			Game.add_xp(Social.share_xp(m.xp_value * 0.5))
		return
	var lv_diff := int(Game.player["level"]) - m.level
	var xp_mult := 1.0
	if lv_diff >= 10:
		xp_mult = maxf(0.1, 1.0 - (lv_diff - 9) * 0.08)
	elif lv_diff < 0:
		xp_mult = minf(1.6, 1.0 - lv_diff * 0.04)
	var my_xp := Social.share_xp(m.xp_value * xp_mult)
	Game.add_xp(my_xp)
	Social.on_party_kill(m.tier, xp_mult)  # fighting side by side builds bond
	if int(Game.player["level"]) < GameData.MAX_LEVEL:
		var party_txt := " (party)" if Social.party_size() > 1 else ""
		float_text(m.global_position + Vector2(0, -m.body_height - 14), "+%d XP%s" % [int(my_xp), party_txt], Color("8fe8ff"), 0.8)
	Game.on_monster_killed(m.mtype, m.tier)
	if player and is_instance_valid(player) and not (credit is Adventurer):
		player.on_kill(m)
	var drop := float(Game.stats.get("drop", 100.0)) / 100.0
	var gold_f := float(Game.stats.get("gold_find", 100.0)) / 100.0
	if m.data.get("passive", false):
		gold_f *= 0.2
	var g := int(m.gold_value * gold_f * randf_range(0.6, 1.4))
	if g > 0:
		drop_gold(g, m.global_position)
	for d in m.data.get("drops", []):
		if randf() < float(d[1]) * drop * (1.5 if m.tier != "normal" else 1.0):
			drop_item(Items.stack(d[0], randi_range(int(d[2]), int(d[3]))), m.global_position)
	var gear_chance := 0.05
	var min_r := 0
	match m.tier:
		"elite":
			gear_chance = 0.4
			min_r = 1
		"mini":
			gear_chance = 1.0
			min_r = 2
		"boss":
			gear_chance = 1.0
			min_r = 3
	gear_chance *= float(m.data.get("gear", 1.0))
	if m.data.get("passive", false):
		gear_chance = 0.0
	if randf() < gear_chance * drop:
		var n := 2 if m.tier == "boss" else 1
		for i in n:
			drop_item(Items.random_gear(m.level, Items.roll_rarity(drop * (2.0 if m.tier != "normal" else 1.0), min_r)), m.global_position)
	if randf() < 0.05 * drop:
		drop_item(Items.stack("pot_hp_s" if m.level < 20 else ("pot_hp_m" if m.level < 45 else "pot_hp_l"), 1), m.global_position)
	if randf() < (0.02 if m.tier == "normal" else 0.4) * drop:
		drop_item(Items.stack("enchant_stone", 1), m.global_position)
	if randf() < (0.05 if m.tier == "normal" else 0.6) * drop:
		drop_item(Items.stack("arcane_dust", randi_range(1, 2)), m.global_position)
	if m.tier in ["mini", "boss"]:
		drop_item(Items.stack("monster_core", 1), m.global_position)


# ------------------------------------------------------------------ hooks for subclasses
func on_player_died() -> void:
	pass


func teleport_to_town() -> void:
	pass


func save_position() -> Array:
	return []


func enter_dungeon(_d: Dictionary) -> void:
	pass


func exit_dungeon() -> void:
	pass


func use_waypoint() -> void:
	pass


func teleport_random_room(_who = null) -> void:
	pass


func player_fall(_pos: Vector2, _room: int, _who = null) -> void:
	pass


func room_of(_pos: Vector2) -> int:
	return -1


func time_tick(delta: float) -> void:
	Game.advance_time(delta)
