class_name Portal
extends Node2D
## Dungeon entrance (overworld), dungeon exit, or town waypoint stone.

var kind := "entrance"  # entrance | exit | waypoint
var dungeon: Dictionary = {}
var interact_radius := 30.0
var sprite: Sprite2D
var label: Node2D
var t := 0.0
var frame := 0
var light: PointLight2D


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("portals")
	sprite = Sprite2D.new()
	add_child(sprite)
	match kind:
		"entrance":
			sprite.texture = Art.obj("dg_entrance0")
			sprite.offset = Vector2(0, -18)
			var r := int(dungeon.get("rank", 1))
			var title := "%s Dungeon  [Rank %d]" % [GameData.DUNGEON_BIOMES.get(dungeon.get("biome", "cave"), {}).get("name", "?"), r]
			if dungeon.get("custom", false):
				title = "%s  [Rank %d]" % [dungeon.get("name", "Custom Dungeon"), r]
			label = WorldText.make(title, 5.5, rank_color(r))
			label.position = Vector2(0, -46)
			add_child(label)
			var body := StaticBody2D.new()
			body.collision_layer = 1
			for x in [-14.0, 14.0]:
				var c := CollisionShape2D.new()
				var s := RectangleShape2D.new()
				s.size = Vector2(8, 4)
				c.shape = s
				c.position = Vector2(x, -2)
				body.add_child(c)
			add_child(body)
		"exit":
			sprite.texture = Art.obj("dg_portal0")
			sprite.offset = Vector2(0, -16)
			label = WorldText.make("Exit Portal", 5.0, Color("8fe8ff"))
			label.position = Vector2(0, -36)
			add_child(label)
		"waypoint":
			sprite.texture = Art.obj("prop_waypoint")
			sprite.offset = Vector2(0, -16)
			label = WorldText.make("Waypoint (return to the wild)", 5.0, Color("8fe8ff"))
			label.position = Vector2(0, -40)
			add_child(label)
	light = PointLight2D.new()
	light.texture = Art.fx("light")
	light.color = Color("b088ff") if kind == "entrance" else Color("6fe0ff")
	light.energy = 0.9
	light.texture_scale = 1.6
	light.position = Vector2(0, -16)
	add_child(light)


static func rank_color(r: int) -> Color:
	if r >= 80:
		return Color("ff4f7b")
	if r >= 60:
		return Color("ff9a2e")
	if r >= 40:
		return Color("b06cf0")
	if r >= 20:
		return Color("3fa9f5")
	return Color("7be05a")


func _process(delta: float) -> void:
	t += delta
	if kind in ["entrance", "exit"] and t > 0.12:
		t = 0.0
		frame = (frame + 1) % 4
		sprite.texture = Art.obj(("dg_entrance%d" if kind == "entrance" else "dg_portal%d") % frame)
	if light:
		var dk := 0.5
		if Game.level_node:
			dk = clampf(Game.level_node.player_light_energy() * 1.4, 0.15, 1.0)
		light.energy = dk * (0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.004))
	if kind == "entrance" and label and dungeon.has("expires") and not dungeon.get("custom", false):
		var left := float(dungeon["expires"]) - float(Game.world.get("total", 0.0))
		if Engine.get_process_frames() % 30 == 0:
			var r := int(dungeon.get("rank", 1))
			WorldText.set_text(label, "%s Dungeon  [Rank %d]  %d:%02d" % [GameData.DUNGEON_BIOMES.get(dungeon.get("biome", "cave"), {}).get("name", "?"), r, int(left) / 60, int(left) % 60])


func interact(_p) -> void:
	var lv = Game.level_node
	if lv == null:
		return
	match kind:
		"entrance":
			Sfx.play("portal")
			lv.enter_dungeon(dungeon)
		"exit":
			Sfx.play("portal")
			lv.exit_dungeon()
		"waypoint":
			lv.use_waypoint()
