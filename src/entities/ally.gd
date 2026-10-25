class_name Ally
extends Actor
## Player summons: hawk (dive attacks), shadow clone (melee), guardian angel (heals + holy bolts).

var kind := "hawk"
var owner_player: Player
var life := 15.0
var power := 60.0
var atk_cd := 0.0
var heal_cd := 2.0
var target: Actor
var dive := 0.0
var orbit_a := 0.0


static func create(k: String, p: Player, pw: float, dur: float) -> Ally:
	var a := Ally.new()
	a.kind = k
	a.owner_player = p
	a.power = pw
	a.life = dur
	return a


func _ready() -> void:
	team = "player"
	add_to_group("team_player")
	add_to_group("allies")
	collision_layer = 0
	collision_mask = 1
	radius = 6.0
	max_hp = owner_player.max_hp * 0.4
	hp = max_hp
	orbit_a = randf() * TAU
	match kind:
		"hawk":
			hover = 18.0
			body_height = 10.0
			build_body("mon_hawk", 0.6)
		"angel":
			hover = 10.0
			body_height = 24.0
			build_body("mon_angel", 0.8)
			_base_modulate = Color(1, 1, 1, 0.92)
		_:
			body_height = 22.0
			build_body("char_" + owner_player.cls, 1.0)
			_base_modulate = Color(0.45, 0.3, 0.75, 0.75)
	play_anim("idle" if kind != "clone" else "idle_down")
	var lv = level_node()
	if lv:
		VFX.particles(lv, global_position + Vector2(0, -10), Color("c8b8ff") if kind == "clone" else Color("fff6c8"), 20, 60.0, 0.6, Vector2(0, -20), "spark", 0.6)


func get_stats() -> Dictionary:
	return Game.stats


func _physics_process(delta: float) -> void:
	if dead:
		_update_visual(delta)
		return
	life -= delta
	if life <= 0.0 or not is_instance_valid(owner_player) or owner_player.dead:
		_vanish()
		return
	_update_statuses(delta)
	_update_buffs(delta)
	atk_cd -= delta
	heal_cd -= delta
	var lv = level_node()
	if target == null or not is_instance_valid(target) or target.dead or target.global_position.distance_to(owner_player.global_position) > 220.0:
		target = _nearest_enemy(170.0)
	match kind:
		"hawk":
			_hawk(delta)
		"angel":
			_angel(delta)
		_:
			_clone(delta)
	_update_visual(delta)


func _nearest_enemy(r: float) -> Actor:
	var best: Actor = null
	var bd := r
	for e in level_node().get_team_actors("enemy"):
		if e.dead:
			continue
		if e is Monster and e.data.get("passive", false):
			continue
		var d = e.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = e
	return best


func _follow_owner(delta: float, dist: float, spd: float) -> void:
	orbit_a += delta * 1.2
	var want := owner_player.global_position + Vector2(cos(orbit_a), sin(orbit_a) * 0.6) * dist
	var d := want - global_position
	velocity = d.normalized() * minf(spd, d.length() * 4.0) if d.length() > 2.0 else Vector2.ZERO
	move_and_slide()
	set_facing_x(velocity.x)


func _hawk(delta: float) -> void:
	if target:
		var d := target.global_position - global_position
		hover = lerpf(hover, 4.0 if d.length() < 40.0 else 18.0, delta * 5.0)
		velocity = d.normalized() * 160.0
		move_and_slide()
		set_facing_x(d.x)
		if d.length() < 12.0 and atk_cd <= 0.0:
			atk_cd = 0.8
			Combat.hit(self, target, power, "phys", "wind", {"knock": 40.0})
			VFX.hit_spark(level_node(), target.body_center(), Color("6ee7a8"))
			Sfx.play("hit", 0.15, 0.5)
			velocity = -d.normalized() * 100.0
	else:
		hover = lerpf(hover, 22.0, delta * 3.0)
		_follow_owner(delta, 26.0, 140.0)
	play_anim("move")


func _angel(delta: float) -> void:
	_follow_owner(delta, 22.0, 120.0)
	play_anim("idle")
	var lv = level_node()
	if heal_cd <= 0.0:
		heal_cd = 2.0
		owner_player.heal(owner_player.max_hp * 0.03 * (1.0 + float(Game.stats.get("heal_pct", 0.0)) / 100.0))
		VFX.beam(lv, body_center(), owner_player.body_center(), 2.0, Color("fff6c8"), 0.3)
		VFX.particles(lv, owner_player.body_center(), Color("fff6c8"), 8, 30.0, 0.6, Vector2(0, -30), "spark", 0.5)
	if target and atk_cd <= 0.0:
		atk_cd = 1.0
		var dir := (target.global_position - global_position).normalized()
		Projectile.spawn(lv, global_position, dir, {"attacker": self, "team": "player", "speed": 300.0, "range": 220.0,
			"power": power, "dmg": "magic", "el": "light", "tex": "holy_orb", "height": hover + 14.0, "trail": true, "opts": {"undead_bonus": 50.0}})
		play_anim("attack")


func _clone(delta: float) -> void:
	var anim := "idle_side"
	if target:
		var d := target.global_position - global_position
		if d.length() > 22.0:
			velocity = d.normalized() * 95.0
			move_and_slide()
			anim = "walk_side"
		elif atk_cd <= 0.0:
			atk_cd = 0.55
			var lv = level_node()
			VFX.slash(lv, global_position + Vector2(0, -10), d.normalized(), 26.0, 120.0, Color("c8b8ff"), 0.18, 3.0)
			for e in lv.actors_in_arc(global_position, d.normalized(), 28.0, 120.0, "enemy"):
				Combat.hit(self, e, power, "phys", "dark", {"knock": 50.0})
			anim = "attack_side"
		set_facing_x(d.x)
	else:
		_follow_owner(delta, 24.0, 100.0)
		anim = "walk_side" if velocity.length() > 5.0 else "idle_side"
	play_anim(anim)


func _vanish() -> void:
	dead = true
	var lv = level_node()
	if lv:
		VFX.particles(lv, global_position + Vector2(0, -10 - hover), Color("c8b8ff"), 14, 50.0, 0.5, Vector2(0, -30), "soft", 0.4)
	queue_free()


func die(_killer = null) -> void:
	_vanish()
