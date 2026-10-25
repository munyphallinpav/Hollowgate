class_name SkillZone
extends Node2D
## Persistent area effect (tornado, black hole, sanctuary, rain, burning ground).

var caster: Actor
var sid := ""
var lvl := 1
var power := 50.0
var dmg_type := "magic"
var element := "none"
var radius := 50.0
var dur := 3.0
var tick := 0.25
var pull := 0.0
var move_vel := Vector2.ZERO
var heal_pct := 0.0
var cleanse := false
var finale := 0.0
var status: Dictionary = {}
var t := 0.0
var _tick_t := 0.0
var fx: FxNode
var ast: Dictionary = {}


func _ready() -> void:
	if is_instance_valid(caster):
		ast = caster.get_stats().duplicate()


func _physics_process(delta: float) -> void:
	t += delta
	var lv = Game.level_node
	if lv == null:
		queue_free()
		return
	if move_vel != Vector2.ZERO:
		var np := global_position + move_vel * delta
		if not lv.ray_blocked(global_position, np):
			global_position = np
		if fx:
			fx.global_position = global_position
	# pull enemies toward the centre
	if pull > 0.0:
		for a in lv.actors_in_radius(global_position, radius * 1.3, "enemy"):
			if a.is_boss():
				continue
			var d: Vector2 = global_position - a.global_position
			if d.length() > 4.0:
				a.knock += d.normalized() * pull * delta * 6.0
	_tick_t -= delta
	if _tick_t <= 0.0:
		_tick_t = tick
		_do_tick(lv)
	if t >= dur:
		if finale > 0.0:
			VFX.explosion(lv, global_position, radius, GameData.element_color(element), "dark" if element == "dark" else "explode")
			for a in lv.actors_in_radius(global_position, radius, "enemy"):
				Combat.hit(caster if is_instance_valid(caster) else null, a, finale, dmg_type, element, {"ast": ast, "knock": 160.0, "knock_dir": (a.global_position - global_position).normalized()})
		queue_free()


func _do_tick(lv) -> void:
	if power > 0.0:
		for a in lv.actors_in_radius(global_position, radius, "enemy"):
			Combat.hit(caster if is_instance_valid(caster) else null, a, power, dmg_type, element, {"ast": ast, "status": status, "no_flash": true, "skill": true})
	if heal_pct > 0.0:
		var hp_mult := 1.0 + float(ast.get("heal_pct", 0.0)) / 100.0
		for a in lv.actors_in_radius(global_position, radius, "player"):
			a.heal(a.max_hp * heal_pct / 100.0 * hp_mult)
			if cleanse:
				a.clear_debuffs()
		if lv.player and lv.player.global_position.distance_to(global_position) < radius:
			VFX.particles(lv, lv.player.global_position + Vector2(0, -10), Color("7be05a"), 3, 20.0, 0.6, Vector2(0, -30), "spark", 0.4)
