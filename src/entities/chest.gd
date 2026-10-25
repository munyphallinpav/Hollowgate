class_name Chest
extends StaticBody2D
## Treasure chest. Tier 0 wood, 1 silver, 2 gold. Boss treasure also holds the boss's unique item.

var tier := 0
var ilvl := 1
var opened := false
var unique_monster := ""
var interact_radius := 26.0
var sprite: Sprite2D
var glow: Sprite2D
var on_opened: Callable
var t := 0.0


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("props")
	collision_layer = 1
	sprite = Sprite2D.new()
	sprite.texture = Art.obj("dg_chest%d_closed" % tier)
	sprite.offset = Vector2(0, -8)
	sprite.scale = Vector2.ONE * (1.0 + 0.25 * tier)
	add_child(sprite)
	glow = Sprite2D.new()
	glow.texture = Art.fx("soft")
	glow.modulate = [Color(1, 0.85, 0.5, 0.35), Color(0.8, 0.9, 1.0, 0.4), Color(1, 0.8, 0.2, 0.5)][tier]
	glow.scale = Vector2(1.2, 0.8) * (1.0 + tier * 0.3)
	glow.position = Vector2(0, -6)
	glow.show_behind_parent = true
	add_child(glow)
	var col := CollisionShape2D.new()
	var shp := RectangleShape2D.new()
	shp.size = Vector2(14, 6) * sprite.scale
	col.shape = shp
	add_child(col)


func _process(delta: float) -> void:
	t += delta
	if not opened:
		glow.modulate.a = 0.25 + 0.15 * sin(t * 3.0)


func interact(_p) -> void:
	if opened:
		return
	opened = true
	remove_from_group("interactable")
	sprite.texture = Art.obj("dg_chest%d_open" % tier)
	glow.modulate.a = 0.15
	Sfx.play("chest")
	var lv = Game.level_node
	if lv == null:
		return
	VFX.particles(lv, global_position + Vector2(0, -10), Color("fee761"), 20 + tier * 10, 70.0, 0.8, Vector2(0, -30), "spark", 0.6)
	VFX.pillar(lv, global_position, 5.0 + tier * 2.0, 50.0, Color("fee761"), 0.6)
	var drop_mult := float(Game.stats.get("drop", 100.0)) / 100.0
	lv.drop_gold(int((10.0 + ilvl * 6.0) * (1.0 + tier * 1.5) * randf_range(0.7, 1.3)), global_position)
	var n_items = [1, 2, 3][tier] + (1 if randf() < 0.3 * drop_mult else 0)
	for i in n_items:
		var it := Items.random_gear(ilvl, Items.roll_rarity(drop_mult * (1.5 + tier), mini(tier, 2), tier * 0.25))
		lv.drop_item(it, global_position)
	if randf() < 0.5 + tier * 0.2:
		lv.drop_item(Items.stack(["pot_hp_s", "pot_hp_m", "pot_mp_m", "pot_hp_l"][mini(3, ilvl / 25 + tier)], randi_range(1, 3)), global_position)
	if randf() < 0.3 + tier * 0.25:
		lv.drop_item(Items.stack("enchant_stone", 1 + tier), global_position)
	if randf() < 0.4:
		lv.drop_item(Items.stack("arcane_dust", randi_range(1, 2 + tier)), global_position)
	if unique_monster != "":
		var u := Items.unique_for(unique_monster, ilvl)
		lv.drop_item(u, global_position)
		lv.drop_item(Items.stack("monster_core", 1), global_position)
		Game.toast("Unique treasure: %s!" % u["name"], Items.color_of(u))
	if on_opened.is_valid():
		on_opened.call()
