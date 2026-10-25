class_name Ambient
extends Node2D
## Screen-space ambient particles that follow the camera (snow, embers, spores, fireflies, dust).

var parts: CPUParticles2D
var kind := ""


func _ready() -> void:
	z_index = 20
	parts = CPUParticles2D.new()
	parts.amount = 60
	parts.lifetime = 6.0
	parts.preprocess = 4.0
	parts.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	parts.emission_rect_extents = Vector2(340, 200)
	parts.texture = Art.fx("soft")
	parts.local_coords = false
	parts.emitting = false
	add_child(parts)


func set_kind(k: String) -> void:
	if k == kind:
		return
	kind = k
	parts.emitting = k != ""
	if k == "":
		return
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.add_point(0.2, Color(1, 1, 1, 1))
	g.add_point(0.8, Color(1, 1, 1, 1))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	parts.color_ramp = g
	parts.direction = Vector2(0, 1)
	parts.spread = 25.0
	parts.gravity = Vector2.ZERO
	parts.initial_velocity_min = 5.0
	parts.initial_velocity_max = 15.0
	parts.scale_amount_min = 0.06
	parts.scale_amount_max = 0.12
	parts.amount = 60
	match k:
		"snow":
			parts.color = Color(1, 1, 1, 0.9)
			parts.direction = Vector2(-0.3, 1)
			parts.initial_velocity_min = 18.0
			parts.initial_velocity_max = 30.0
			parts.amount = 120
		"embers":
			parts.color = Color(1.0, 0.55, 0.2, 0.9)
			parts.direction = Vector2(0.2, -1)
			parts.initial_velocity_min = 10.0
			parts.initial_velocity_max = 25.0
			parts.scale_amount_max = 0.09
		"spores":
			parts.color = Color(0.85, 0.6, 1.0, 0.75)
			parts.direction = Vector2(0, -1)
			parts.spread = 180.0
		"swamp":
			parts.color = Color(0.6, 0.9, 0.4, 0.6)
			parts.direction = Vector2(0, -1)
			parts.spread = 180.0
		"fireflies":
			parts.color = Color(1.0, 0.95, 0.45, 0.95)
			parts.spread = 180.0
			parts.amount = 40
			parts.scale_amount_min = 0.1
			parts.scale_amount_max = 0.16
		"dust":
			parts.color = Color(1.0, 0.9, 0.7, 0.45)
			parts.direction = Vector2(1, 0.1)
			parts.initial_velocity_min = 12.0
			parts.initial_velocity_max = 28.0
		"leaves":
			parts.texture = Art.fx("leaf")
			parts.color = Color(1, 1, 1, 0.9)
			parts.direction = Vector2(0.4, 1)
			parts.initial_velocity_min = 10.0
			parts.initial_velocity_max = 22.0
			parts.scale_amount_min = 0.5
			parts.scale_amount_max = 0.8
			parts.amount = 18
			parts.angular_velocity_min = -90.0
			parts.angular_velocity_max = 90.0
			return
		"motes":
			parts.color = Color(1.0, 0.95, 0.85, 0.35)
			parts.spread = 180.0
	parts.texture = Art.fx("soft")
	parts.angular_velocity_min = 0.0
	parts.angular_velocity_max = 0.0


func _process(_d: float) -> void:
	var lv = Game.level_node
	if lv and lv.camera:
		global_position = lv.camera.get_screen_center_position()
