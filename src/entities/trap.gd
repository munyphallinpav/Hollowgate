class_name Trap
extends Node2D
## Dungeon traps: spike, arrow, poison_gas, boulder, teleport, pitfall, bomb.

var type := "spike"
var room_id := -1
var rank := 1
var dir := Vector2.RIGHT
var t := 0.0
var phase := 0
var sprite: Sprite2D
var raw := 20.0
var hit_once := false
var cd := 0.0
var vel := Vector2.ZERO
var used := false
var gas_t := 0.0
var _frame := 0
var _anim_t := 0.0
var test_mode := false


func _ready() -> void:
	add_to_group("traps")
	raw = GameData.mon_atk(rank)
	sprite = Sprite2D.new()
	add_child(sprite)
	t = randf() * 2.0
	match type:
		"spike":
			sprite.texture = Art.obj("dg_spike0")
			z_index = -1
		"arrow":
			sprite.texture = Art.obj("dg_arrow_trap")
			sprite.offset = Vector2(0, -6)
			sprite.flip_h = dir.x < 0.0
			if absf(dir.y) > absf(dir.x):
				sprite.rotation = PI / 2.0 if dir.y > 0 else -PI / 2.0
		"poison_gas":
			sprite.texture = Art.obj("dg_gas_vent")
			z_index = -1
		"boulder":
			sprite.texture = Art.obj("dg_boulder0")
			sprite.offset = Vector2(0, -11)
			var sh := Sprite2D.new()
			sh.texture = Art.fx("shadow")
			sh.scale = Vector2(1.3, 1.3)
			sh.show_behind_parent = true
			add_child(sh)
			vel = Vector2.from_angle(randf() * TAU) * 85.0
		"teleport":
			sprite.texture = Art.obj("dg_tele_rune0")
			z_index = -1
			var l := PointLight2D.new()
			l.texture = Art.fx("light")
			l.color = Color("b088ff")
			l.energy = 0.6
			l.texture_scale = 0.8
			add_child(l)
		"pitfall":
			sprite.texture = Art.obj("dg_plate")
			sprite.modulate = Color(1, 1, 1, 0.55)
			z_index = -1
		"bomb":
			sprite.texture = Art.obj("dg_plate")
			sprite.modulate = Color(1, 0.85, 0.85, 0.7)
			z_index = -1


func _player():
	var lv = Game.level_node
	if lv == null:
		return null
	var p = lv.player
	if p == null or not is_instance_valid(p) or p.dead:
		return null
	if room_id >= 0 and lv.has_method("room_of") and lv.room_of(p.global_position) != room_id:
		return null
	return p


func _physics_process(delta: float) -> void:
	var p = _player()
	if type == "boulder":
		_boulder(delta, p)
		return
	if p == null:
		return
	t += delta
	cd -= delta
	var lv = Game.level_node
	var d: float = p.global_position.distance_to(global_position)
	match type:
		"spike":
			var cycle := fmod(t, 2.8)
			var st := 0 if cycle < 1.6 else (1 if cycle < 2.1 else 2)
			if st != phase:
				phase = st
				sprite.texture = Art.obj("dg_spike%d" % st)
				if st == 2:
					hit_once = false
					Sfx.play("trap", 0.1, 0.4)
			if phase == 2 and not hit_once and d < 9.0 and p.z < 4.0:
				hit_once = true
				_hurt(p, 100.0, "none", {"knock": 60.0})
		"arrow":
			if cd <= 0.0:
				cd = 2.2
				sprite.modulate = Color(1.5, 0.6, 0.6)
				var tw := create_tween()
				tw.tween_interval(0.35)
				tw.tween_callback(func():
					sprite.modulate = Color.WHITE
					Projectile.spawn(lv, global_position + dir * 8.0, dir, {"team": "enemy", "speed": 230.0, "range": 340.0, "power": 90.0,
						"dmg": "phys", "el": "none", "tex": "arrow", "height": 6.0, "opts": {"raw": raw, "ast": {"crit": 0.0}, "knock": 60.0}})
					Sfx.play("shoot", 0.1, 0.4))
		"poison_gas":
			if cd <= 0.0 and gas_t <= 0.0:
				cd = 4.0
				gas_t = 2.5
			if gas_t > 0.0:
				gas_t -= delta
				if Engine.get_physics_frames() % 6 == 0:
					VFX.particles(lv, global_position + Vector2(randf_range(-8, 8), -4), Color(0.5, 0.85, 0.35, 0.55), 3, 30.0, 1.2, Vector2(0, -8), "gas", 1.2)
				if d < 26.0 and Engine.get_physics_frames() % 30 == 0:
					p.apply_status("poison", 3.0, raw * 0.12)
		"teleport":
			_anim_t += delta
			if _anim_t > 0.4:
				_anim_t = 0.0
				_frame = 1 - _frame
				sprite.texture = Art.obj("dg_tele_rune%d" % _frame)
			if d < 7.0 and cd <= 0.0:
				cd = 3.0
				VFX.particles(lv, p.global_position + Vector2(0, -10), Color("b088ff"), 24, 70.0, 0.6, Vector2(0, -30), "spark", 0.6)
				Sfx.play("portal")
				lv.float_text(p.global_position + Vector2(0, -30), "Teleported!", Color("c79bff"), 1.0)
				lv.teleport_random_room()
		"pitfall":
			if not used and d < 7.0 and p.z <= 0.0 and p.dash_t <= 0.0:
				used = true
				sprite.texture = Art.obj("dg_pit_open")
				sprite.modulate = Color.WHITE
				Sfx.play("trap")
				lv.player_fall(global_position, room_id)
		"bomb":
			if d < 8.0 and cd <= 0.0:
				cd = 6.0
				Sfx.play("trap")
				lv.float_text(global_position + Vector2(0, -20), "Click!", Color("ff9a7a"), 0.8)
				for i in 3:
					var target: Vector2 = p.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(14, 30))
					_drop_bomb(lv, target, 0.7 + i * 0.25)


func _hurt(p, power: float, el: String, extra: Dictionary = {}) -> void:
	if test_mode and p.hp < p.max_hp * 0.1:
		return
	var o := {"raw": raw, "ast": {"crit": 0.0}}
	o.merge(extra)
	Combat.hit(null, p, power, "phys", el, o)


func _drop_bomb(lv, target: Vector2, delay: float) -> void:
	VFX.telegraph(lv, target, 26.0, Color(1, 0.3, 0.2), delay + 0.3)
	var cb := func():
		var b := Sprite2D.new()
		b.texture = Art.obj("dg_bomb0")
		b.position = target
		b.offset = Vector2(0, -6)
		lv.add_entity(b)
		var tw := b.create_tween()
		tw.tween_property(b, "modulate", Color(2, 0.6, 0.6), 0.15)
		tw.tween_property(b, "modulate", Color.WHITE, 0.15)
		tw.tween_callback(func():
			VFX.explosion(lv, target, 26.0, Color("ff8a3a"))
			var pl = lv.player
			if pl and is_instance_valid(pl) and not pl.dead and pl.global_position.distance_to(target) < 26.0 + pl.radius:
				_hurt(pl, 160.0, "fire", {"knock": 180.0, "knock_dir": (pl.global_position - target).normalized()})
			for m in lv.actors_in_radius(target, 26.0, "enemy"):
				Combat.hit(null, m, 160.0, "phys", "fire", {"raw": raw, "ast": {"crit": 0.0}, "knock": 120.0})
			b.queue_free())
	VFX.sky_object(lv, Art.obj("dg_bomb0"), target, delay, 140.0, 1.0, cb)


func _boulder(delta: float, p) -> void:
	var lv = Game.level_node
	if lv == null:
		return
	if room_id >= 0 and lv.has_method("room_of") and lv.player and is_instance_valid(lv.player) and lv.room_of(lv.player.global_position) != room_id:
		return
	_anim_t += delta * vel.length() / 40.0
	sprite.texture = Art.obj("dg_boulder%d" % (int(_anim_t * 4.0) % 4))
	var np := global_position + vel * delta
	if lv.ray_blocked(global_position, global_position + vel.normalized() * 11.0, true):
		# bounce: try reflecting on each axis
		if lv.ray_blocked(global_position, global_position + Vector2(signf(vel.x) * 11.0, 0), true):
			vel.x = -vel.x
		if lv.ray_blocked(global_position, global_position + Vector2(0, signf(vel.y) * 11.0), true):
			vel.y = -vel.y
		vel = vel.rotated(randf_range(-0.3, 0.3))
		lv.shake(1.0, 0.08)
		Sfx.play("earth", 0.1, 0.3)
	else:
		global_position = np
	cd -= delta
	if p and cd <= 0.0 and p.global_position.distance_to(global_position) < 12.0 + p.radius and p.z < 8.0:
		cd = 0.8
		_hurt(p, 140.0, "earth", {"knock": 220.0, "knock_dir": vel.normalized()})
	for m in lv.actors_in_radius(global_position, 12.0, "enemy"):
		if m is Monster and m.hover <= 0.0 and Engine.get_physics_frames() % 20 == 0:
			m.knock += vel.normalized() * 120.0
