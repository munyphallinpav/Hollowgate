class_name Actor
extends CharacterBody2D
## Base class for every living thing: player, monsters, allies, guards.
## Handles HP, statuses, buffs, shields, knockback and the 2.5D height (z) + shadow.

signal died(actor: Actor)

const FLASH_SHADER := preload("res://src/vfx/flash.gdshader")
const DEBUFFS := ["burn", "chill", "freeze", "stun", "shred", "judged", "curse", "poison", "root", "blind"]

var team := "enemy"
var display_name := ""
var hp := 100.0
var max_hp := 100.0
var mp := 0.0
var max_mp := 0.0
var base_stats: Dictionary = {}
var element := "none"
var undead := false
var radius := 7.0
var body_height := 22.0
var z := 0.0
var vz := 0.0
var gravity := 600.0
var hover := 0.0
var facing := Vector2.RIGHT
var dead := false
var statuses: Dictionary = {}
var buffs: Dictionary = {}
var shield := 0.0
var shield_t := 0.0
var invuln_t := 0.0
var knock := Vector2.ZERO
var flash_t := 0.0
var level := 1
var tier := "normal"
var knock_resist := 0.0
var visual: Node2D
var sprite: AnimatedSprite2D
var shadow: Sprite2D
var shield_fx: Node2D
var _mat: ShaderMaterial
var _status_tick := 0.0
var _status_fx_t := 0.0
var _base_modulate := Color.WHITE


func _init() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0


func build_body(frames_key: String, shadow_scale: float = 1.0) -> void:
	shadow = Sprite2D.new()
	shadow.texture = Art.fx("shadow")
	shadow.scale = Vector2(shadow_scale, shadow_scale)
	shadow.z_index = -1
	shadow.position = Vector2(0, 0)
	add_child(shadow)
	visual = Node2D.new()
	add_child(visual)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Art.frames(frames_key)
	var fs := Art.frame_size(frames_key)
	sprite.centered = true
	sprite.offset = Vector2(0, -fs.y / 2.0 + 2.0)
	_mat = ShaderMaterial.new()
	_mat.shader = FLASH_SHADER
	sprite.material = _mat
	visual.add_child(sprite)
	var col := CollisionShape2D.new()
	var shp := CircleShape2D.new()
	shp.radius = maxf(3.0, radius * 0.6)
	col.shape = shp
	add_child(col)


func play_anim(n: String) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(n) and sprite.animation != n:
		sprite.play(n)


# ------------------------------------------------------------------ stats
func get_stats() -> Dictionary:
	return base_stats


func get_stat(k: String) -> float:
	var v := float(get_stats().get(k, 0.0))
	if is_player_team() and self is Player:
		return v
	var pct := 0.0
	var flat := 0.0
	for b in buffs.values():
		pct += float(b["mods"].get(k + "_pct", 0.0))
		flat += float(b["mods"].get(k, 0.0))
	return maxf(0.0, (v + flat) * (1.0 + pct / 100.0))


func damage_out_mult() -> float:
	var m := 1.0
	for b in buffs.values():
		m *= 1.0 + float(b["mods"].get("atk_mult", 0.0)) / 100.0
		m *= 1.0 + float(b["mods"].get("patk_pct", 0.0)) / 100.0 if not (self is Player) else 1.0
	return m


func is_player_team() -> bool:
	return team == "player"


func is_boss() -> bool:
	return tier == "boss"


func is_invulnerable() -> bool:
	return invuln_t > 0.0


func level_node() -> Node:
	return Game.level_node


# ------------------------------------------------------------------ statuses
func has_status(id: String) -> bool:
	return statuses.has(id)


func has_any_debuff() -> bool:
	for s in statuses:
		if s in DEBUFFS:
			return true
	return false


func apply_status(id: String, dur: float, power: float = 0.0, src: Actor = null) -> void:
	if dead:
		return
	if buffs.has("immune") and id in DEBUFFS:
		return
	if is_boss() and id in ["stun", "freeze", "root"]:
		dur *= 0.35
	elif tier == "mini" and id in ["stun", "freeze", "root"]:
		dur *= 0.6
	if self is Player:
		dur *= 1.0 - minf(80.0, float(get_stats().get("status_resist", 0.0))) / 100.0
	if dur <= 0.05:
		return
	var cur: Dictionary = statuses.get(id, {})
	if cur.is_empty() or float(cur["t"]) < dur or power > float(cur.get("p", 0.0)):
		statuses[id] = {"t": maxf(dur, float(cur.get("t", 0.0))), "p": maxf(power, float(cur.get("p", 0.0))), "src": src}
	if id == "chill" and src and is_instance_valid(src):
		statuses[id]["slow"] = 35.0 + float(src.get_stats().get("slow_pct", 0.0))
	if id in ["stun", "freeze"]:
		on_disabled()
	if Settings.damage_numbers and id in ["stun", "freeze", "root", "poison", "burn"] and level_node():
		level_node().float_text(global_position + Vector2(0, -body_height - 8), GameData.WorldData.STATUS[id]["name"], GameData.WorldData.STATUS[id]["color"], 0.8)


func clear_debuffs() -> void:
	for s in statuses.keys():
		if s in DEBUFFS:
			statuses.erase(s)


func on_disabled() -> void:
	pass


func can_move() -> bool:
	return not (statuses.has("stun") or statuses.has("freeze") or statuses.has("root"))


func can_act() -> bool:
	return not (statuses.has("stun") or statuses.has("freeze"))


func move_mult() -> float:
	if not can_move():
		return 0.0
	var m := 1.0
	if statuses.has("chill"):
		m *= 1.0 - minf(80.0, float(statuses["chill"].get("slow", 35.0))) / 100.0
	if not (self is Player):
		var pct := 0.0
		for b in buffs.values():
			pct += float(b["mods"].get("move_pct", 0.0))
		m *= maxf(0.2, 1.0 + pct / 100.0)
	return m


func _update_statuses(delta: float) -> void:
	_status_tick += delta
	var tick := _status_tick >= 0.5
	if tick:
		_status_tick = 0.0
	for id in statuses.keys():
		var s: Dictionary = statuses[id]
		s["t"] = float(s["t"]) - delta
		if tick and id in ["burn", "poison"] and float(s.get("p", 0.0)) > 0.0:
			var d := maxi(1, int(float(s["p"]) * 0.5))
			take_damage(d, {"el": "fire" if id == "burn" else "earth", "dot": true, "src": s.get("src")})
			if dead:
				return
		if float(s["t"]) <= 0.0:
			statuses.erase(id)
	_status_fx_t -= delta
	if _status_fx_t <= 0.0 and not statuses.is_empty() and level_node():
		_status_fx_t = 0.25
		var lv = level_node()
		var p := global_position + Vector2(randf_range(-radius, radius), -randf_range(4, body_height))
		if statuses.has("burn"):
			VFX.particles(lv, p, Color("ff8a3a"), 3, 20.0, 0.5, Vector2(0, -40), "soft", 0.25)
		if statuses.has("poison"):
			VFX.particles(lv, p, Color("8ad36a"), 2, 12.0, 0.6, Vector2(0, -25), "soft", 0.2)
		if statuses.has("stun"):
			VFX.particles(lv, global_position + Vector2(0, -body_height - 6 - z - hover), Color("fee761"), 2, 25.0, 0.4, Vector2.ZERO, "spark", 0.6)
		if statuses.has("chill") or statuses.has("freeze"):
			VFX.particles(lv, p, Color("bfe8ff"), 2, 10.0, 0.5, Vector2(0, 10), "spark", 0.4)
		if statuses.has("curse"):
			VFX.particles(lv, p, Color("a66bff"), 2, 10.0, 0.6, Vector2(0, -20), "soft", 0.2)


# ------------------------------------------------------------------ buffs
func add_buff(id: String, dur: float, mods: Dictionary, color: Color = Color.WHITE, bname: String = "") -> void:
	buffs[id] = {"t": dur, "max": dur, "mods": mods, "color": color, "name": bname if bname != "" else id.capitalize()}
	_on_buffs_changed()


func remove_buff(id: String) -> void:
	if buffs.erase(id):
		_on_buffs_changed()


func _on_buffs_changed() -> void:
	pass


func _update_buffs(delta: float) -> void:
	var changed := false
	for id in buffs.keys():
		buffs[id]["t"] = float(buffs[id]["t"]) - delta
		if float(buffs[id]["t"]) <= 0.0:
			buffs.erase(id)
			changed = true
	if changed:
		_on_buffs_changed()
	if shield_t > 0.0:
		shield_t -= delta
		if shield_t <= 0.0 and shield > 0.0:
			on_shield_end(false)
			shield = 0.0
	if invuln_t > 0.0:
		invuln_t -= delta


func add_shield(amount: float, dur: float) -> void:
	shield = maxf(shield, amount)
	shield_t = dur
	if shield_fx == null:
		shield_fx = VFX.attach_bubble(self, Color(0.55, 0.85, 1.0, 0.55), radius + 8.0)


func on_shield_end(broken: bool) -> void:
	if shield_fx and is_instance_valid(shield_fx):
		shield_fx.queue_free()
	shield_fx = null


# ------------------------------------------------------------------ damage
func take_damage(amount: int, info: Dictionary = {}) -> int:
	if dead:
		return 0
	if invuln_t > 0.0 and not info.get("dot", false):
		return 0
	var dmg := float(amount)
	if shield > 0.0:
		var absorbed := minf(shield, dmg)
		shield -= absorbed
		dmg -= absorbed
		if shield <= 0.0:
			on_shield_end(true)
		if dmg <= 0.0:
			if level_node():
				level_node().float_text(global_position + Vector2(0, -body_height - 4), "Absorbed", Color("8fd3ff"), 0.7)
			return 0
	var final := int(dmg)
	hp -= final
	_show_damage(final, info)
	if not info.get("dot", false) and not info.get("no_flash", false):
		flash_t = 0.09
	var kn := float(info.get("knock", 0.0)) * (1.0 - knock_resist)
	if kn > 0.0:
		var dir: Vector2 = info.get("knock_dir", Vector2.ZERO)
		if dir == Vector2.ZERO and info.get("src") and is_instance_valid(info["src"]):
			dir = (global_position - info["src"].global_position).normalized()
		knock += dir * kn
	on_hurt(final, info)
	if hp <= 0.0:
		hp = 0.0
		die(info.get("src"))
	return final


func _show_damage(final: int, info: Dictionary) -> void:
	if not Settings.damage_numbers or not level_node():
		return
	var col: Color
	if is_player_team():
		col = Color("ff5a5a")
	else:
		col = GameData.element_color(info.get("el", "none")) if info.get("el", "none") != "none" else Color.WHITE
		if info.get("dot", false):
			col = col.darkened(0.15)
	var scale := 1.0 if not info.get("crit", false) else 1.45
	if info.get("dot", false):
		scale = 0.75
	level_node().damage_number(global_position + Vector2(randf_range(-5, 5), -body_height - z - hover), final, col, info.get("crit", false), scale)


func heal(amount: float, show: bool = true) -> void:
	if dead or amount <= 0.0:
		return
	var before := hp
	hp = minf(max_hp, hp + amount)
	var got := int(hp - before)
	if show and got > 0 and Settings.damage_numbers and level_node():
		level_node().float_text(global_position + Vector2(randf_range(-4, 4), -body_height - 6), "+%d" % got, Color("7be05a"), 1.0)


func on_hurt(_amount: int, _info: Dictionary) -> void:
	pass


func on_dealt_damage(_target: Actor, _amount: int, _info: Dictionary) -> void:
	pass


func die(_killer = null) -> void:
	if dead:
		return
	dead = true
	statuses.clear()
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	play_anim("death")
	died.emit(self)


# ------------------------------------------------------------------ physics helpers
func move_with(vel: Vector2, delta: float) -> void:
	velocity = vel * move_mult() + knock
	move_and_slide()
	knock = knock.move_toward(Vector2.ZERO, 900.0 * delta)
	if knock.length() < 4.0:
		knock = Vector2.ZERO


func _update_z(delta: float) -> void:
	if z > 0.0 or vz != 0.0:
		vz -= gravity * delta
		z += vz * delta
		if z <= 0.0:
			z = 0.0
			vz = 0.0
			on_land()


func on_land() -> void:
	pass


func _update_visual(delta: float) -> void:
	if visual:
		visual.position.y = -z - hover
	if shadow:
		var s := clampf(1.0 - (z + hover) / 120.0, 0.45, 1.0)
		shadow.scale = Vector2(s, s) * maxf(1.0, radius / 7.0)
		shadow.modulate.a = s
	if flash_t > 0.0:
		flash_t -= delta
	if _mat:
		_mat.set_shader_parameter("flash", 0.65 if flash_t > 0.0 else 0.0)
	if sprite:
		var tint := _base_modulate
		if statuses.has("freeze"):
			tint = tint * Color(0.6, 0.85, 1.3)
		elif statuses.has("chill"):
			tint = tint * Color(0.75, 0.9, 1.15)
		elif statuses.has("poison"):
			tint = tint * Color(0.75, 1.1, 0.7)
		elif statuses.has("curse"):
			tint = tint * Color(0.85, 0.7, 1.1)
		sprite.modulate = tint
		if statuses.has("freeze") or statuses.has("stun"):
			sprite.speed_scale = 0.0
		elif sprite.speed_scale == 0.0:
			sprite.speed_scale = 1.0


func body_center() -> Vector2:
	return global_position + Vector2(0, -body_height * 0.5 - z - hover)


func set_facing_x(dx: float) -> void:
	if sprite and absf(dx) > 0.01:
		sprite.flip_h = dx < 0.0
