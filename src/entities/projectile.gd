class_name Projectile
extends Node2D
## Moving projectile (arrows, bolts, fireballs, knives...). Collides with walls and actors of the other team.

var attacker: Actor
var team := "player"
var vel := Vector2.ZERO
var speed := 300.0
var max_dist := 260.0
var traveled := 0.0
var power := 100.0
var dmg_type := "phys"
var element := "none"
var opts: Dictionary = {}
var pierce := 0
var explode := 0.0
var homing := 0.0
var hit_radius := 5.0
var color := Color.WHITE
var trail := false
var height := 10.0
var on_impact: Callable
var hits: Dictionary = {}
var sprite: Sprite2D
var _trail_t := 0.0
var _home_target: Actor
var ast: Dictionary = {}
var lob_time := 0.0
var lob_height := 40.0
var _lob_t := 0.0
var _lob_from := Vector2.ZERO
var _lob_to := Vector2.ZERO
var spin := 0.0
var start_pos := Vector2.ZERO


static func spawn(level: Node, from: Vector2, dir: Vector2, p: Dictionary) -> Projectile:
	var pr := Projectile.new()
	pr.position = from
	pr.start_pos = from
	pr.attacker = p.get("attacker")
	pr.team = p.get("team", "player")
	pr.speed = p.get("speed", 300.0)
	pr.vel = dir.normalized() * pr.speed
	pr.max_dist = p.get("range", 260.0)
	pr.power = p.get("power", 100.0)
	pr.dmg_type = p.get("dmg", "phys")
	pr.element = p.get("el", "none")
	pr.opts = p.get("opts", {})
	pr.pierce = p.get("pierce", 0)
	pr.explode = p.get("explode", 0.0)
	pr.homing = p.get("homing", 0.0)
	pr.color = p.get("color", GameData.element_color(pr.element))
	pr.trail = p.get("trail", false)
	pr.hit_radius = p.get("hit_radius", 5.0)
	pr.height = p.get("height", 10.0)
	pr.spin = p.get("spin", 0.0)
	if p.has("on_impact"):
		pr.on_impact = p["on_impact"]
	if is_instance_valid(pr.attacker):
		pr.ast = pr.attacker.get_stats().duplicate()
		pr.opts["ast"] = pr.ast
	pr.sprite = Sprite2D.new()
	pr.sprite.texture = Art.fx(p.get("tex", "bolt"))
	var sc: float = p.get("scale", 1.0)
	pr.sprite.scale = Vector2(sc, sc)
	pr.sprite.position = Vector2(0, -pr.height)
	if p.get("tint", true) and p.get("tex", "bolt") in ["bolt", "crescent", "spark", "soft"]:
		pr.sprite.modulate = pr.color.lightened(0.2)
	pr.add_child(pr.sprite)
	# glow
	if p.get("glow", p.get("tex", "bolt") in ["bolt", "fireball", "holy_orb", "dark_orb", "crescent", "ice"]):
		var gl := Sprite2D.new()
		gl.texture = Art.fx("soft")
		gl.modulate = Color(pr.color.r, pr.color.g, pr.color.b, 0.45)
		gl.scale = Vector2(0.7, 0.7) * sc
		gl.position = Vector2(0, -pr.height)
		gl.show_behind_parent = true
		pr.add_child(gl)
	var sh := Sprite2D.new()
	sh.texture = Art.fx("shadow")
	sh.scale = Vector2(0.35, 0.35) * sc
	sh.modulate.a = 0.6
	sh.show_behind_parent = true
	pr.add_child(sh)
	if p.get("lob", 0.0) > 0.0:
		pr.lob_time = p["lob"]
		pr.lob_height = p.get("lob_height", 40.0)
		pr._lob_from = from
		pr._lob_to = p.get("target", from + dir * 100.0)
	level.add_fx(pr, "projectiles")
	pr.sprite.rotation = dir.angle() if pr.spin == 0.0 else 0.0
	return pr


func _physics_process(delta: float) -> void:
	if lob_time > 0.0:
		_lob(delta)
		return
	if homing > 0.0:
		if _home_target == null or not is_instance_valid(_home_target) or _home_target.dead:
			_home_target = _find_target(180.0)
		if _home_target:
			var want := (_home_target.global_position - global_position).normalized() * speed
			vel = vel.lerp(want, clampf(homing * delta, 0.0, 1.0)).normalized() * speed
	var step := vel * delta
	var lv = Game.level_node
	if lv == null:
		queue_free()
		return
	# wall collision
	if lv.ray_blocked(global_position, global_position + step):
		_impact(global_position)
		return
	position += step
	traveled += step.length()
	if spin != 0.0:
		sprite.rotation += spin * delta
	else:
		sprite.rotation = vel.angle()
	# actors
	for a in lv.get_team_actors("enemy" if team == "player" else "player"):
		if a.dead or hits.has(a.get_instance_id()):
			continue
		if a.global_position.distance_to(global_position) <= hit_radius + a.radius:
			hits[a.get_instance_id()] = true
			if explode > 0.0:
				_impact(global_position)
				return
			_damage(a)
			if pierce <= 0:
				_impact(global_position, false)
				return
			pierce -= 1
	if trail:
		_trail_t -= delta
		if _trail_t <= 0.0:
			_trail_t = 0.03
			VFX.particles(lv, global_position + Vector2(0, -height), color, 2, 15.0, 0.3, Vector2.ZERO, "soft", 0.25)
	if traveled >= max_dist:
		_impact(global_position, explode > 0.0)


func _lob(delta: float) -> void:
	_lob_t += delta
	var p := clampf(_lob_t / lob_time, 0.0, 1.0)
	position = _lob_from.lerp(_lob_to, p)
	sprite.position.y = -height - sin(p * PI) * lob_height
	sprite.rotation += 8.0 * delta
	if p >= 1.0:
		_impact(global_position, true)


func _find_target(rng: float) -> Actor:
	var lv = Game.level_node
	var best: Actor = null
	var bd := rng
	for a in lv.get_team_actors("enemy" if team == "player" else "player"):
		if a.dead or hits.has(a.get_instance_id()):
			continue
		var d = a.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = a
	return best


func _damage(a: Actor) -> void:
	var o := opts.duplicate()
	o["dist"] = start_pos.distance_to(a.global_position)
	if not o.has("knock_dir"):
		o["knock_dir"] = vel.normalized()
	Combat.hit(attacker if is_instance_valid(attacker) else null, a, power, dmg_type, element, o)
	VFX.hit_spark(Game.level_node, a.body_center(), color)


func _impact(at: Vector2, do_explode: bool = true) -> void:
	var lv = Game.level_node
	if do_explode and explode > 0.0 and lv:
		VFX.element_burst(lv, at, element if element != "none" else "fire", explode)
		for a in lv.get_team_actors("enemy" if team == "player" else "player"):
			if a.dead:
				continue
			if a.global_position.distance_to(at) <= explode + a.radius:
				var o := opts.duplicate()
				o["knock_dir"] = (a.global_position - at).normalized()
				o["knock"] = float(o.get("knock", 80.0))
				Combat.hit(attacker if is_instance_valid(attacker) else null, a, power, dmg_type, element, o)
	elif lv:
		VFX.particles(lv, at + Vector2(0, -height), color, 5, 50.0, 0.25, Vector2.ZERO, "px", 0.4)
	if on_impact.is_valid():
		on_impact.call(at)
	queue_free()
