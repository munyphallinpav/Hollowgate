class_name VFX
extends RefCounted
## Factory for visual effects. All effects are added to the current Level's fx layers.

const FxScript := preload("res://src/vfx/fx_node.gd")


static func _fx(level: Node, kind: String, pos: Vector2, dur: float, color: Color, layer: String = "over") -> FxNode:
	var f := FxNode.new()
	f.kind = kind
	f.dur = dur
	f.color = color
	f.position = pos
	if level:
		level.add_fx(f, layer)
	return f


static func slash(level: Node, pos: Vector2, dir: Vector2, radius: float, arc_deg: float, color: Color, dur: float = 0.2, width: float = 4.0) -> FxNode:
	var f := _fx(level, "slash", pos, dur, color)
	f.dir = dir.normalized()
	f.radius = radius
	f.arc = arc_deg
	f.width = width
	return f


static func ring(level: Node, pos: Vector2, radius: float, color: Color, dur: float = 0.35, width: float = 2.0, start_r: float = 2.0, filled: bool = true) -> FxNode:
	var f := _fx(level, "ellipse_ring" if not filled else "ring", pos, dur, color)
	f.radius = radius
	f.radius2 = start_r
	f.width = width
	f.fill = filled
	return f


static func ground_ring(level: Node, pos: Vector2, radius: float, color: Color, dur: float = 0.4, width: float = 2.0) -> FxNode:
	var f := _fx(level, "ellipse_ring", pos, dur, color, "under")
	f.radius = radius
	f.radius2 = radius * 0.2
	f.width = width
	return f


static func disc(level: Node, pos: Vector2, radius: float, color: Color, dur: float = 0.25) -> FxNode:
	var f := _fx(level, "disc", pos, dur, color)
	f.radius = radius
	return f


static func telegraph(level: Node, pos: Vector2, radius: float, color: Color, dur: float) -> FxNode:
	var f := _fx(level, "telegraph", pos, dur, color, "under")
	f.radius = radius
	return f


static func line_telegraph(level: Node, pos: Vector2, dir: Vector2, length: float, width: float, color: Color, dur: float) -> FxNode:
	var f := _fx(level, "line_tele", pos, dur, color, "under")
	f.dir = dir.normalized()
	f.length = length
	f.width = width
	return f


static func beam(level: Node, from: Vector2, to: Vector2, width: float, color: Color, dur: float = 0.3) -> FxNode:
	var f := _fx(level, "beam", from, dur, color)
	var d := to - from
	f.dir = d.normalized()
	f.length = d.length()
	f.width = width
	return f


static func pillar(level: Node, pos: Vector2, width: float, height: float, color: Color, dur: float = 0.5) -> FxNode:
	var f := _fx(level, "pillar", pos, dur, color)
	f.width = width
	f.length = height
	return f


static func cone(level: Node, pos: Vector2, dir: Vector2, length: float, arc_deg: float, color: Color, dur: float) -> FxNode:
	var f := _fx(level, "cone", pos, dur, color, "under")
	f.dir = dir.normalized()
	f.length = length
	f.arc = arc_deg
	return f


static func zone(level: Node, pos: Vector2, kind: String, radius: float, color: Color, dur: float) -> FxNode:
	var layer := "under" if kind in ["sanctuary", "vortex"] else "over"
	var f := _fx(level, kind, pos, dur, color, layer)
	f.radius = radius
	return f


static func cross_flash(level: Node, pos: Vector2, radius: float, color: Color, dur: float = 0.25) -> FxNode:
	var f := _fx(level, "cross_flash", pos, dur, color)
	f.radius = radius
	return f


static func attach_bubble(actor: Node2D, color: Color, radius: float) -> FxNode:
	var f := FxNode.new()
	f.kind = "bubble"
	f.loop = true
	f.dur = 999.0
	f.color = color
	f.radius = radius
	actor.add_child(f)
	f.z_index = 2
	return f


static func attach_aura(actor: Node2D, color: Color, radius: float, dur: float) -> FxNode:
	var f := FxNode.new()
	f.kind = "aura"
	f.dur = dur
	f.color = color
	f.radius = radius
	actor.add_child(f)
	f.z_index = -1
	return f


static func particles(level: Node, pos: Vector2, color: Color, count: int = 12, speed: float = 60.0, life: float = 0.5,
		gravity: Vector2 = Vector2.ZERO, tex: String = "px", scale: float = 0.5, spread: float = 180.0, dir: Vector2 = Vector2.UP) -> void:
	if level == null:
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.emitting = false
	p.amount = maxi(1, count)
	p.lifetime = life
	p.explosiveness = 0.95
	p.texture = Art.fx(tex)
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = gravity
	p.scale_amount_min = scale * 0.6
	p.scale_amount_max = scale
	p.color = color
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	p.damping_min = speed * 0.5
	p.damping_max = speed * 1.2
	level.add_fx(p, "over")
	p.emitting = true
	var tm := level.get_tree().create_timer(life + 0.2, false)
	tm.timeout.connect(p.queue_free)


static func explosion(level: Node, pos: Vector2, radius: float, color: Color, sound: String = "explode") -> void:
	disc(level, pos + Vector2(0, -4), radius * 0.9, Color(1, 1, 0.9, 0.9), 0.18)
	disc(level, pos + Vector2(0, -4), radius, Color(color.r, color.g, color.b, 0.7), 0.35)
	ground_ring(level, pos, radius * 1.15, color, 0.45, 2.0)
	particles(level, pos + Vector2(0, -4), color, int(10 + radius * 0.4), radius * 3.2, 0.5, Vector2(0, 30), "soft", 0.45)
	particles(level, pos + Vector2(0, -4), Color(1, 1, 1), 8, radius * 4.0, 0.3, Vector2.ZERO, "spark", 0.8)
	particles(level, pos, Color(0.4, 0.4, 0.45, 0.6), 6, radius, 0.9, Vector2(0, -20), "smoke", 1.0)
	if level:
		level.shake(minf(6.0, radius * 0.08), 0.25)
	if sound != "":
		Sfx.play(sound)


static func element_burst(level: Node, pos: Vector2, el: String, radius: float) -> void:
	var c := GameData.element_color(el)
	match el:
		"fire":
			explosion(level, pos, radius, c, "fire")
		"water":
			ground_ring(level, pos, radius, c, 0.45, 2.0)
			particles(level, pos + Vector2(0, -6), Color("bfe8ff"), 18, radius * 3.0, 0.6, Vector2(0, 120), "px", 0.5, 120.0)
			Sfx.play("ice")
		"earth":
			ground_ring(level, pos, radius, c, 0.4, 3.0)
			particles(level, pos, Color("9a7050"), 14, radius * 2.5, 0.6, Vector2(0, 180), "px", 0.6, 70.0)
			if level:
				level.shake(3.0, 0.2)
			Sfx.play("earth")
		"wind":
			ring(level, pos + Vector2(0, -6), radius, c, 0.35, 2.0, 4.0, false)
			particles(level, pos + Vector2(0, -6), c, 12, radius * 3.5, 0.4, Vector2.ZERO, "px", 0.4)
			Sfx.play("wind")
		"light":
			pillar(level, pos, 4.0, 60.0, c, 0.35)
			ring(level, pos, radius, c, 0.35, 2.0)
			particles(level, pos + Vector2(0, -10), Color(1, 1, 0.85), 14, radius * 2.0, 0.6, Vector2(0, -40), "spark", 0.6)
			Sfx.play("light")
		"dark":
			disc(level, pos + Vector2(0, -4), radius * 0.9, Color(0.15, 0.0, 0.25, 0.7), 0.4)
			ring(level, pos, radius, c, 0.4, 2.0)
			particles(level, pos + Vector2(0, -6), c, 14, radius * 2.0, 0.6, Vector2(0, -30), "soft", 0.3)
			Sfx.play("dark")
		_:
			ring(level, pos, radius, c, 0.3, 2.0)
			particles(level, pos, c, 10, radius * 2.0, 0.4)


static func hit_spark(level: Node, pos: Vector2, color: Color, crit: bool = false) -> void:
	particles(level, pos, color, 6 if not crit else 12, 90.0 if not crit else 140.0, 0.25, Vector2.ZERO, "px", 0.45)
	if crit:
		cross_flash(level, pos, 10.0, Color(1, 1, 0.8), 0.2)


static func afterimage(actor: Actor, color: Color = Color(0.6, 0.8, 1.0, 0.6), life: float = 0.3) -> void:
	if actor.sprite == null or actor.sprite.sprite_frames == null:
		return
	var lv = actor.level_node()
	if lv == null:
		return
	var tex := actor.sprite.sprite_frames.get_frame_texture(actor.sprite.animation, actor.sprite.frame)
	var s := Sprite2D.new()
	s.texture = tex
	s.flip_h = actor.sprite.flip_h
	s.offset = actor.sprite.offset
	s.global_position = actor.global_position + Vector2(0, -actor.z - actor.hover)
	s.modulate = color
	lv.add_fx(s, "under_entities")
	var tw := s.create_tween()
	tw.tween_property(s, "modulate:a", 0.0, life)
	tw.tween_callback(s.queue_free)


## Rock / ice spike that erupts from the ground (y-sorted with actors)
static func spike(level: Node, pos: Vector2, tex: String = "spike_rock", scale: float = 1.0, life: float = 0.6) -> void:
	if level == null:
		return
	var s := Sprite2D.new()
	s.texture = Art.fx(tex)
	s.offset = Vector2(0, -s.texture.get_height() * 0.5)
	s.position = pos
	s.scale = Vector2(scale, 0.1)
	level.add_entity(s)
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector2(scale, scale * 1.15), 0.08)
	tw.tween_property(s, "scale", Vector2(scale, scale), 0.06)
	tw.tween_interval(life * 0.5)
	tw.tween_property(s, "scale", Vector2(scale, 0.0), life * 0.3)
	tw.tween_callback(s.queue_free)
	particles(level, pos, Color("8a6a50"), 5, 50.0, 0.35, Vector2(0, 120), "px", 0.4, 60.0)


## A sprite that falls from the sky onto `pos` after `delay` and then calls `on_hit`.
static func sky_object(level: Node, tex: Texture2D, pos: Vector2, delay: float, height: float, scale: float, on_hit: Callable, rot: float = 0.0) -> void:
	if level == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.scale = Vector2(scale, scale)
	s.rotation = rot
	s.position = pos + Vector2(0, -height)
	s.z_index = 5
	level.add_fx(s, "over")
	var sh := Sprite2D.new()
	sh.texture = Art.fx("shadow")
	sh.position = pos
	sh.scale = Vector2(0.4, 0.4)
	level.add_fx(sh, "under")
	var tw := s.create_tween()
	tw.tween_property(s, "position", pos + Vector2(0, -6), delay).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func():
		if is_instance_valid(sh):
			sh.queue_free()
		on_hit.call()
		s.queue_free())
	var tw2 := sh.create_tween()
	tw2.tween_property(sh, "scale", Vector2(scale * 1.6, scale * 1.6), delay)
