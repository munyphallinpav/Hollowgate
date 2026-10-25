class_name Spawner
extends Actor
## Monster spawning devices: nest, totem (empowers room), grave (undead), circle (one-time ambush).

var kind := "nest"
var room_id := -1
var monsters: Array = ["slime"]
var interval := 6.0
var max_alive := 3
var alive: Array = []
var t := 0.0
var triggered := false
var sprite2: Sprite2D
var tint := Color.WHITE
var dungeon_rank := 1


func _ready() -> void:
	team = "enemy"
	level = dungeon_rank
	if kind != "circle":
		add_to_group("team_enemy")
		add_to_group("spawners")
	collision_layer = 1 if kind != "circle" else 0
	collision_mask = 0
	radius = 10.0
	body_height = 20.0
	display_name = GameData.WorldData.SPAWNERS[kind]["name"]
	max_hp = GameData.mon_hp(level) * (4.0 if kind == "nest" else 5.0)
	hp = max_hp
	base_stats = {"patk": 0.0, "matk": 0.0, "pdef": GameData.mon_def(level), "mdef": GameData.mon_def(level), "crit": 0.0, "crit_dmg": 100.0, "level": level}
	knock_resist = 1.0
	match kind:
		"nest":
			interval = 6.0
			max_alive = 3
		"totem":
			interval = 8.0
			max_alive = 2
		"grave":
			interval = 7.0
			max_alive = 3
			monsters = ["skeleton", "zombie"]
	visual = Node2D.new()
	add_child(visual)
	sprite2 = Sprite2D.new()
	sprite2.texture = Art.obj({"nest": "dg_nest", "totem": "dg_totem", "grave": "dg_grave", "circle": "dg_circle0"}[kind])
	if kind != "circle":
		sprite2.offset = Vector2(0, -sprite2.texture.get_height() / 2.0 + 3.0)
	else:
		z_index = -1
	_mat = ShaderMaterial.new()
	_mat.shader = FLASH_SHADER
	sprite2.material = _mat
	visual.add_child(sprite2)
	if kind != "circle":
		var col := CollisionShape2D.new()
		var shp := CircleShape2D.new()
		shp.radius = 7.0
		col.shape = shp
		add_child(col)
		var l := PointLight2D.new()
		l.texture = Art.fx("light")
		l.color = Color("ff4a4a") if kind == "totem" else Color("b088ff")
		l.energy = 0.5
		l.texture_scale = 1.0
		add_child(l)
	t = interval * 0.5


func _physics_process(delta: float) -> void:
	if dead:
		return
	_update_statuses(delta)
	_update_visual(delta)
	var lv = Game.level_node
	if lv == null or lv.player == null or not is_instance_valid(lv.player):
		return
	var p = lv.player
	var in_room: bool = room_id < 0 or lv.room_of(p.global_position) == room_id
	if kind == "circle":
		if not triggered and in_room and p.global_position.distance_to(global_position) < 70.0:
			triggered = true
			_ambush(lv)
		return
	if not in_room:
		return
	for m in alive.duplicate():
		if not is_instance_valid(m) or m.dead:
			alive.erase(m)
	t -= delta
	if t <= 0.0 and alive.size() < max_alive:
		t = interval
		_spawn_one(lv, global_position + Vector2.from_angle(randf() * TAU) * 16.0)
	if kind == "totem" and Engine.get_physics_frames() % 60 == 0:
		for m in lv.get_team_actors("enemy"):
			if m is Monster and not m.dead and m.room_id == room_id:
				m.add_buff("totem", 2.5, {"atk_mult": 20.0, "move_pct": 10.0}, Color("ff4a4a"), "Empowered")
		VFX.ground_ring(lv, global_position, 50.0, Color(1, 0.3, 0.3, 0.6), 0.8)


func _spawn_one(lv, pos: Vector2) -> void:
	var mt: String = monsters[randi() % monsters.size()]
	var m = lv.spawn_monster(mt, pos, dungeon_rank, "normal", {"room": room_id})
	if m:
		m.no_loot = randf() < 0.5
		m.hurt_alert = 3.0
		alive.append(m)
		VFX.particles(lv, pos + Vector2(0, -8), Color("b088ff"), 14, 50.0, 0.5, Vector2(0, -30), "spark", 0.5)
		VFX.ground_ring(lv, pos, 14.0, Color("b088ff"), 0.4)


func _ambush(lv) -> void:
	sprite2.texture = Art.obj("dg_circle1")
	lv.float_text(global_position + Vector2(0, -24), "Ambush!", Color("ff6a6a"), 1.4)
	Sfx.play("roar", 0.1, 0.8)
	VFX.ring(lv, global_position, 60.0, Color("ff4a4a"), 0.6, 3.0)
	for i in 4:
		var pos := global_position + Vector2.from_angle(TAU * i / 4.0) * 24.0
		var tw := create_tween()
		tw.tween_interval(0.15 * i)
		tw.tween_callback(func(): _spawn_one(lv, pos))
	var tw2 := create_tween()
	tw2.tween_interval(2.0)
	tw2.tween_property(self, "modulate:a", 0.0, 1.0)
	tw2.tween_callback(queue_free)


func die(killer = null) -> void:
	if dead:
		return
	super.die(killer)
	var lv = Game.level_node
	if lv:
		VFX.explosion(lv, global_position, 26.0, Color("b088ff"), "explode")
		lv.drop_gold(int(GameData.mon_xp(level) * 2.0), global_position)
		if randf() < 0.5:
			lv.drop_item(Items.stack("arcane_dust", randi_range(1, 3)), global_position)
		Game.add_xp(GameData.mon_xp(level) * 3.0)
	queue_free()
