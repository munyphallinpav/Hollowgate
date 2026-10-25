class_name NPC
extends StaticBody2D
## Town NPC (shopkeepers, guild master, architect). Interact to open their service window.

var role := "gear"
var npc_name := "Merchant"
var sprite_key := "char_merchant"
var interact_radius := 30.0
var sprite: AnimatedSprite2D
var label: Node2D
var bubble_t := 0.0
var lines: Array = []


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("npcs")
	collision_layer = 1
	var sh := Sprite2D.new()
	sh.texture = Art.fx("shadow")
	add_child(sh)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Art.frames(sprite_key)
	sprite.offset = Vector2(0, -14)
	sprite.play("idle_down")
	add_child(sprite)
	var col := CollisionShape2D.new()
	var shp := CircleShape2D.new()
	shp.radius = 5.0
	col.shape = shp
	add_child(col)
	label = WorldText.make(npc_name, 6.0, Color("ffe9a8"))
	label.position = Vector2(0, -40)
	add_child(label)


func _process(delta: float) -> void:
	var p = Game.player_node
	if p and is_instance_valid(p):
		var d: Vector2 = p.global_position - global_position
		if d.length() < 60.0:
			if absf(d.x) > absf(d.y):
				sprite.play("idle_side")
				sprite.flip_h = d.x < 0
			else:
				sprite.play("idle_down" if d.y > 0 else "idle_up")
				sprite.flip_h = false
		else:
			sprite.play("idle_down")


func interact(_p) -> void:
	Sfx.play("click")
	if Game.main:
		Game.main.open_service(role, self)
