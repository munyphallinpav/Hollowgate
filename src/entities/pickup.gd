class_name Pickup
extends Node2D
## Loot lying on the ground (item or gold). Walk near to collect.

var item: Dictionary = {}
var gold := 0
var t := 0.0
var vel := Vector2.ZERO
var vz := 0.0
var z := 0.0
var sprite: Sprite2D
var beam: Sprite2D
var life := 300.0
var _msg_cd := 0.0
var magnet := false


static func create_item(it: Dictionary) -> Pickup:
	var p := Pickup.new()
	p.item = it
	return p


static func create_gold(n: int) -> Pickup:
	var p := Pickup.new()
	p.gold = n
	return p


func _ready() -> void:
	add_to_group("pickups")
	var sh := Sprite2D.new()
	sh.texture = Art.fx("shadow")
	sh.scale = Vector2(0.6, 0.6)
	add_child(sh)
	if gold > 0:
		sprite = Sprite2D.new()
		sprite.texture = Art.icon("gold")
		sprite.scale = Vector2(0.75, 0.75)
	else:
		var r := int(item.get("rarity", -1)) if Items.is_gear(item) else -1
		if r >= 2 or item.get("unique", "") != "":
			beam = Sprite2D.new()
			beam.texture = Art.fx("soft")
			beam.scale = Vector2(0.35, 2.4)
			beam.position = Vector2(0, -20)
			beam.modulate = Color(Items.color_of(item), 0.55)
			add_child(beam)
		sprite = Sprite2D.new()
		sprite.texture = Items.icon_of(item)
		var gl := Sprite2D.new()
		gl.texture = Art.fx("soft")
		gl.modulate = Color(Items.color_of(item), 0.5)
		gl.scale = Vector2(0.7, 0.7)
		gl.position = Vector2(0, -8)
		add_child(gl)
	sprite.position = Vector2(0, -8)
	add_child(sprite)
	vel = Vector2.from_angle(randf() * TAU) * randf_range(20.0, 50.0)
	vz = randf_range(70.0, 110.0)
	z = 2.0


func _process(delta: float) -> void:
	t += delta
	life -= delta
	_msg_cd -= delta
	if life <= 0.0:
		queue_free()
		return
	if z > 0.0 or vz > 0.0:
		vz -= 320.0 * delta
		z += vz * delta
		position += vel * delta
		if z <= 0.0:
			z = 0.0
			vz = 0.0
			vel = Vector2.ZERO
	sprite.position.y = -8.0 - z - (sin(t * 4.0) * 1.5 if z <= 0.0 else 0.0)
	if beam:
		beam.modulate.a = 0.35 + 0.2 * sin(t * 3.0)
	if t < 0.5:
		return
	var p = Game.player_node
	if p == null or not is_instance_valid(p) or p.dead:
		return
	var d: float = p.global_position.distance_to(global_position)
	if d < 34.0 or magnet:
		if gold > 0 or _can_take():
			global_position = global_position.move_toward(p.global_position, (160.0 + (34.0 - d) * 6.0) * delta)
			if d < 8.0:
				_collect(p)
		elif _msg_cd <= 0.0 and d < 16.0:
			_msg_cd = 3.0
			Game.toast("Bag is full!", Color("ff7a7a"))


func _can_take() -> bool:
	if Game.free_slots() > 0:
		return true
	if Items.max_stack(item) > 1:
		for s in Game.inv():
			if s is Dictionary and not s.is_empty() and Items.can_stack(s, item) and int(s["qty"]) < Items.max_stack(s):
				return true
	return false


func _collect(p) -> void:
	var lv = Game.level_node
	if gold > 0:
		Game.add_gold(gold)
		if lv:
			lv.float_text(global_position + Vector2(0, -16), "+%d g" % gold, Color("fee761"), 0.8)
		Sfx.play("coin", 0.1, 0.6)
		queue_free()
		return
	var name := Items.name_of(item)
	var qty := int(item.get("qty", 1))
	if Game.add_item(item):
		if lv:
			lv.float_text(global_position + Vector2(0, -16), name + ("" if qty <= 1 else " x%d" % qty), Items.color_of(item), 0.9)
		Game.toast("Picked up %s%s" % [name, "" if qty <= 1 else " x%d" % qty], Items.color_of(item))
		Sfx.play("pickup", 0.1, 0.5)
		queue_free()
