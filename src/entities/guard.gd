class_name Guard
extends Actor
## Town gate guard: very strong, protects the town from any monster that comes close.

var post := Vector2.ZERO
var atk_cd := 0.0
var target: Actor
var sight := 120.0


func _ready() -> void:
	team = "player"
	add_to_group("team_player")
	add_to_group("guards")
	collision_layer = 0
	collision_mask = 1
	radius = 7.0
	body_height = 24.0
	display_name = "Town Guard"
	level = 120
	max_hp = 999999.0
	hp = max_hp
	base_stats = {"patk": GameData.mon_atk(120) * 4.0, "matk": 100.0, "pdef": 99999.0, "mdef": 99999.0, "crit": 20.0, "crit_dmg": 200.0, "level": 120}
	build_body("char_guard", 1.0)
	weapon()
	post = global_position
	play_anim("idle_down")
	var lbl := WorldText.make("Guard", 5.0, Color("8fd3ff"))
	lbl.position = Vector2(0, -38)
	add_child(lbl)


func weapon() -> void:
	var w := Sprite2D.new()
	w.texture = Art.weapon("spear")
	w.rotation = -PI / 2.0
	w.position = Vector2(6, -14)
	visual.add_child(w)


func _physics_process(delta: float) -> void:
	_update_buffs(delta)
	atk_cd -= delta
	hp = max_hp
	if target == null or not is_instance_valid(target) or target.dead or target.global_position.distance_to(post) > sight * 1.5:
		target = null
		var lv = level_node()
		if lv and Engine.get_physics_frames() % 10 == 0:
			for e in lv.get_team_actors("enemy"):
				if not e.dead and e.global_position.distance_to(post) < sight:
					target = e
					break
	if target:
		var d := target.global_position - global_position
		set_facing_x(d.x)
		if d.length() > 30.0:
			velocity = d.normalized() * 110.0
			move_and_slide()
			play_anim("walk_side")
		else:
			play_anim("attack_side")
			if atk_cd <= 0.0:
				atk_cd = 0.6
				var lv2 = level_node()
				VFX.beam(lv2, global_position + Vector2(0, -12), target.body_center(), 3.0, Color("c8e6ff"), 0.15)
				Combat.hit(self, target, 100.0, "phys", "light", {"knock": 200.0})
				Sfx.play("hit", 0.1, 0.6)
	else:
		var back := post - global_position
		if back.length() > 3.0:
			velocity = back.normalized() * 70.0
			move_and_slide()
			play_anim("walk_side")
			set_facing_x(back.x)
		else:
			play_anim("idle_down")
	_update_visual(delta)


func take_damage(_amount: int, _info: Dictionary = {}) -> int:
	flash_t = 0.1
	return 0
