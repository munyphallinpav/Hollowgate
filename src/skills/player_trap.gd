class_name PlayerTrap
extends Node2D
## Ranger's frost trap: arms after a moment, explodes when an enemy walks over it.

var caster: Actor
var power := 150.0
var radius := 40.0
var life := 20.0
var status: Dictionary = {}
var armed := 0.4
var ast: Dictionary = {}
var _blink := 0.0


func _ready() -> void:
	add_to_group("player_traps")
	if is_instance_valid(caster):
		ast = caster.get_stats().duplicate()
	var s := Sprite2D.new()
	s.texture = Art.obj("dg_spike1")
	s.modulate = Color(0.6, 0.9, 1.0)
	add_child(s)
	z_index = -1


func _process(delta: float) -> void:
	life -= delta
	armed -= delta
	_blink += delta
	modulate.a = 0.6 + 0.4 * sin(_blink * 6.0)
	if life <= 0.0:
		queue_free()
		return
	if armed > 0.0:
		return
	var lv = Game.level_node
	if lv == null:
		return
	for a in lv.actors_in_radius(global_position, 12.0, "enemy"):
		trigger()
		return


func trigger() -> void:
	var lv = Game.level_node
	VFX.element_burst(lv, global_position, "water", radius)
	for k in 6:
		VFX.spike(lv, global_position + Vector2.from_angle(k * TAU / 6.0) * radius * 0.5, "ice_spike", 1.0, 0.8)
	for a in lv.actors_in_radius(global_position, radius, "enemy"):
		Combat.hit(caster if is_instance_valid(caster) else null, a, power, "phys", "water", {"ast": ast, "status": status, "skill": true})
	queue_free()
