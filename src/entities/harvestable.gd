class_name Harvestable
extends StaticBody2D
## Trees, rocks, ores and bushes: hit them to gather materials. Regrow after a while.

const KINDS := {
	"tree": {"hits": 4, "drops": [["wood", 2, 3, 1.0], ["food_apple", 1, 1, 0.12]], "sound": "chop", "chip": Color("8a5a3a")},
	"big_tree": {"hits": 6, "drops": [["wood", 2, 4, 1.0], ["hardwood", 1, 2, 0.8]], "sound": "chop", "chip": Color("5a3a2e")},
	"pine": {"hits": 5, "drops": [["wood", 2, 3, 1.0], ["hardwood", 1, 1, 0.5]], "sound": "chop", "chip": Color("5a3a2e")},
	"palm": {"hits": 4, "drops": [["wood", 1, 3, 1.0], ["food_apple", 1, 2, 0.3]], "sound": "chop", "chip": Color("b86f50")},
	"mushroom": {"hits": 3, "drops": [["herb", 1, 3, 1.0], ["crystal_shard", 1, 1, 0.08]], "sound": "chop", "chip": Color("9b5de5")},
	"dead": {"hits": 3, "drops": [["wood", 1, 2, 1.0], ["bone", 1, 1, 0.1]], "sound": "chop", "chip": Color("5a4a42")},
	"cactus": {"hits": 3, "drops": [["herb", 1, 2, 0.8], ["food_berries", 1, 2, 0.4]], "sound": "chop", "chip": Color("3e8948")},
	"crystal": {"hits": 5, "drops": [["crystal_shard", 1, 3, 1.0]], "sound": "mine", "chip": Color("2ce8f5")},
	"bush": {"hits": 2, "drops": [["herb", 1, 1, 0.5], ["cloth", 1, 1, 0.1]], "sound": "chop", "chip": Color("3e8948")},
	"berry_bush": {"hits": 2, "drops": [["food_berries", 2, 3, 1.0]], "sound": "chop", "chip": Color("e43b44")},
	"rock": {"hits": 4, "drops": [["stone", 2, 3, 1.0]], "sound": "mine", "chip": Color("8b9bb4")},
	"ore_copper": {"hits": 5, "drops": [["ore_copper", 2, 3, 1.0], ["stone", 1, 1, 0.6]], "sound": "mine", "chip": Color("d77643")},
	"ore_iron": {"hits": 5, "drops": [["ore_iron", 2, 3, 1.0], ["stone", 1, 1, 0.6]], "sound": "mine", "chip": Color("c0cbdc")},
	"ore_silver": {"hits": 6, "drops": [["ore_silver", 2, 3, 1.0], ["stone", 1, 1, 0.6]], "sound": "mine", "chip": Color("e4e8ef")},
	"ore_gold": {"hits": 6, "drops": [["ore_gold", 1, 3, 1.0], ["stone", 1, 1, 0.6]], "sound": "mine", "chip": Color("feae34")},
	"ore_mithril": {"hits": 7, "drops": [["ore_mithril", 1, 2, 1.0], ["crystal_shard", 1, 1, 0.2]], "sound": "mine", "chip": Color("2ce8f5")},
	"ore_adamantite": {"hits": 8, "drops": [["ore_adamantite", 1, 2, 1.0], ["crystal_shard", 1, 1, 0.3]], "sound": "mine", "chip": Color("b55088")},
	"ore_crystal": {"hits": 6, "drops": [["crystal_shard", 2, 3, 1.0]], "sound": "mine", "chip": Color("9b5de5")},
}

const SPRITE_KIND := {
	"tree_oak": "tree", "tree_big_oak": "big_tree", "tree_pine": "pine", "tree_snow_pine": "pine", "tree_palm": "palm",
	"tree_mushroom_tree": "mushroom", "tree_dead_tree": "dead", "tree_swamp_tree": "dead", "tree_cactus": "cactus",
	"tree_crystal_tree": "crystal", "bush": "bush", "bush_berry": "berry_bush", "rock_small": "rock", "rock_big": "rock",
	"rock_dark": "rock", "ore_copper": "ore_copper", "ore_iron": "ore_iron", "ore_silver": "ore_silver", "ore_gold": "ore_gold",
	"ore_mithril": "ore_mithril", "ore_adamantite": "ore_adamantite", "ore_crystal": "ore_crystal",
}

var key := ""
var obj_name := "tree_oak"
var kind := "tree"
var hits_left := 4
var sprite: Sprite2D
var _shake := 0.0
var _fade_check := 0.0
var tall := false
var regrow := 420.0


static func create(obj: String, k: String) -> Harvestable:
	var h := Harvestable.new()
	h.obj_name = obj
	h.key = k
	h.kind = SPRITE_KIND.get(obj, "rock")
	return h


func _ready() -> void:
	add_to_group("props")
	add_to_group("harvestable")
	collision_layer = 1
	collision_mask = 0
	hits_left = KINDS[kind]["hits"]
	sprite = Sprite2D.new()
	sprite.texture = Art.obj(obj_name)
	if sprite.texture:
		var h := sprite.texture.get_height()
		sprite.offset = Vector2(0, -h / 2.0 + 2.0)
		tall = h > 30
	add_child(sprite)
	var col := CollisionShape2D.new()
	var shp := CircleShape2D.new()
	shp.radius = 4.0 if obj_name.begins_with("tree") else (5.0 if obj_name != "bush" and obj_name != "bush_berry" else 4.0)
	if obj_name in ["rock_big", "tree_big_oak"]:
		shp.radius = 7.0
	col.shape = shp
	add_child(col)


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake -= delta
		sprite.position.x = sin(_shake * 60.0) * 1.5 if _shake > 0.0 else 0.0
	if tall:
		_fade_check -= delta
		if _fade_check <= 0.0:
			_fade_check = 0.15
			var p = Game.player_node
			var a := 1.0
			if p and is_instance_valid(p):
				var d: Vector2 = p.global_position - global_position
				if d.y < -2.0 and d.y > -float(sprite.texture.get_height()) and absf(d.x) < sprite.texture.get_width() * 0.45:
					a = 0.45
			sprite.modulate.a = lerpf(sprite.modulate.a, a, 0.6)


func hit_by(_attacker) -> void:
	hits_left -= 1
	_shake = 0.2
	var lv = Game.level_node
	var k: Dictionary = KINDS[kind]
	Sfx.play(k["sound"], 0.15, 0.6)
	if lv:
		VFX.particles(lv, global_position + Vector2(0, -8), k["chip"], 6, 50.0, 0.4, Vector2(0, 150), "px", 0.45, 80.0)
	if hits_left <= 0:
		_break()


func _break() -> void:
	var lv = Game.level_node
	var k: Dictionary = KINDS[kind]
	var bonus := float(Game.stats.get("gather_pct", 0.0)) / 100.0
	for d in k["drops"]:
		if randf() > float(d[3]):
			continue
		var n := randi_range(int(d[1]), int(d[2]))
		if randf() < bonus:
			n += 1
		if n > 0 and lv:
			lv.drop_item(Items.stack(d[0], n), global_position)
	if lv:
		VFX.particles(lv, global_position + Vector2(0, -10), k["chip"], 16, 70.0, 0.6, Vector2(0, 160), "px", 0.6)
		VFX.particles(lv, global_position, Color(0.8, 0.8, 0.8, 0.5), 6, 30.0, 0.6, Vector2(0, -20), "smoke", 0.7)
	if key != "":
		Game.world["harvested"][key] = float(Game.world["total"]) + regrow
	queue_free()
