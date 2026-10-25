class_name Monster
extends Actor
## Data-driven monster AI. Archetypes: hopper, melee, pack, pouncer, brute, caster, blinker, flyer, dragon, critter, mimic.

var mtype := "slime"
var data: Dictionary = {}
var ai := "melee"
var attacks: Array = []
var atk_cds: Dictionary = {}
var target: Actor = null
var state := "idle"
var state_t := 0.0
var cur_attack := ""
var attack_dir := Vector2.RIGHT
var attack_pos := Vector2.ZERO
var home := Vector2.ZERO
var aggro_range := 150.0
var leash := 420.0
var room_id := -1
var wander_t := 0.0
var wander_dir := Vector2.ZERO
var rebirth_used := false
var xp_value := 10.0
var gold_value := 2.0
var enraged := false
var telegraph: Node = null
var speed := 50.0
var dmg_kind := "phys"
var summoner: Monster = null
var summons: Array = []
var hit_done: Dictionary = {}
var lunge_vel := Vector2.ZERO
var leap_from := Vector2.ZERO
var leap_to := Vector2.ZERO
var leap_t := 0.0
var leap_dur := 0.5
var strafe_sign := 1.0
var dormant := false
var flee_t := 0.0
var drain_t := 0.0
var drain_beam: FxNode = null
var breath_t := 0.0
var stuck_t := 0.0
var _last_pos := Vector2.ZERO
var side_t := 0.0
var side_dir := Vector2.ZERO
var scale_mult := 1.0
var tint := Color.WHITE
var no_loot := false
var spawned_by: Node = null
var hurt_alert := 0.0
var hpbar: Node2D
var name_tag: Node2D


class HpBar extends Node2D:
	var m

	func _draw() -> void:
		if m == null or m.dead or m.hp >= m.max_hp or m.tier == "boss":
			return
		var w := clampf(m.radius * 2.6, 16.0, 40.0)
		var r := clampf(m.hp / m.max_hp, 0.0, 1.0)
		draw_rect(Rect2(-w / 2.0 - 1, -1, w + 2, 4), Color(0.05, 0.03, 0.08, 0.85))
		var col := Color("e43b44") if m.tier == "normal" else (Color("ffb347") if m.tier == "mini" else Color("8fd3ff"))
		draw_rect(Rect2(-w / 2.0, 0, w * r, 2), col)


static func create(type: String, lvl: int, tr: String = "normal", opts: Dictionary = {}) -> Monster:
	var m := Monster.new()
	m.setup(type, lvl, tr, opts)
	return m


func setup(type: String, lvl: int, tr: String, opts: Dictionary) -> void:
	mtype = type
	data = GameData.MONSTERS[type]
	level = clampi(lvl, 1, 120)
	tier = tr
	ai = data["ai"]
	attacks = data["attacks"].duplicate()
	element = opts.get("element", data["el"])
	undead = data.get("undead", false)
	display_name = data["name"]
	radius = float(data.get("radius", 7))
	hover = float(data.get("flying", 0))
	if type == "skeleton" and opts.get("ranged", randf() < 0.35):
		attacks = data["variant_ranged"].duplicate()
		ai = "caster"
		display_name = "Skeleton Archer"
	var hp_m := float(data["hp"])
	var atk_m := float(data["atk"])
	var xp_m := float(data["xp"])
	var gold_m := float(data.get("gold", 1.0))
	scale_mult = 1.0
	match tier:
		"elite":
			hp_m *= 2.5
			atk_m *= 1.2
			xp_m *= 4.0
			gold_m *= 3.0
			scale_mult = 1.15
			display_name = "Elite " + display_name
		"mini":
			hp_m *= 6.0
			atk_m *= 1.35
			xp_m *= 10.0
			gold_m *= 8.0
			scale_mult = 1.35
			display_name = "Chieftain " + display_name if type in ["goblin", "ogre", "lizard"] else "Alpha " + display_name
			aggro_range = 190.0
		"boss":
			hp_m *= 16.0 / sqrt(maxf(0.5, float(data["hp"])))
			atk_m *= 1.6
			xp_m *= 40.0
			gold_m *= 30.0
			scale_mult = 1.8 if radius < 16 else 1.3
			display_name = opts.get("boss_name", "Lord of " + data["name"] + "s")
			aggro_range = 260.0
			knock_resist = 0.9
	if tier == "mini":
		knock_resist = 0.6
	if float(data["hp"]) >= 2.5:
		knock_resist = maxf(knock_resist, 0.5)
	max_hp = GameData.mon_hp(level) * hp_m
	hp = max_hp
	var atk := GameData.mon_atk(level) * atk_m
	base_stats = {"patk": atk, "matk": atk, "pdef": GameData.mon_def(level) * float(data["def"]),
		"mdef": GameData.mon_def(level) * float(data["mdef"]), "crit": 5.0, "crit_dmg": 150.0, "level": level}
	xp_value = GameData.mon_xp(level) * xp_m
	gold_value = (2.0 + level * 1.2) * gold_m
	speed = float(data["spd"]) * (0.9 if tier == "boss" else 1.0)
	if ai in ["caster", "blinker"]:
		dmg_kind = "magic"
	tint = opts.get("tint", Color.WHITE)
	dormant = ai == "mimic" and not opts.get("awake", false)
	radius *= scale_mult


func _ready() -> void:
	team = "enemy"
	add_to_group("team_enemy")
	add_to_group("monsters")
	collision_layer = 8
	collision_mask = 1 | 2 | 8 if hover <= 0.0 else 1
	if data.get("passive", false):
		collision_mask = 1 | 2
	body_height = Art.frame_size("mon_" + mtype).y * 0.75 * scale_mult
	build_body("mon_" + mtype, maxf(1.0, radius / 7.0))
	visual.scale = Vector2(scale_mult, scale_mult)
	_base_modulate = tint
	home = global_position
	_last_pos = global_position
	strafe_sign = 1.0 if randf() < 0.5 else -1.0
	if tier in ["elite", "mini"]:
		_mat.set_shader_parameter("outline", 1.0)
		_mat.set_shader_parameter("outline_color", Color("ffd24a") if tier == "mini" else Color("8fd3ff"))
	elif tier == "boss":
		_mat.set_shader_parameter("outline", 1.0)
		_mat.set_shader_parameter("outline_color", Color("ff4a4a"))
	if dormant:
		play_anim("idle")
		sprite.stop()
		sprite.frame = 0
	else:
		play_anim("idle")
	for a in attacks:
		atk_cds[a] = randf_range(0.3, 1.2)
	hpbar = HpBar.new()
	hpbar.m = self
	hpbar.z_index = 30
	add_child(hpbar)
	if tier in ["elite", "mini"]:
		name_tag = WorldText.make("%s  Lv%d" % [display_name, level], 4.5, Color("ffd24a") if tier == "mini" else Color("8fd3ff"))
		add_child(name_tag)


# ===================================================================== main loop
func _physics_process(delta: float) -> void:
	if dead:
		_update_visual(delta)
		return
	_update_statuses(delta)
	if dead:
		return
	_update_buffs(delta)
	_update_z(delta)
	for k in atk_cds.keys():
		atk_cds[k] = float(atk_cds[k]) - delta
	hurt_alert -= delta
	state_t -= delta
	if dormant:
		_dormant(delta)
		_update_visual(delta)
		return
	if not can_act():
		_cancel_attack()
		move_with(Vector2.ZERO, delta)
		_update_visual(delta)
		return
	match state:
		"windup":
			_windup(delta)
		"lunge":
			_lunge(delta)
		"leap":
			_leap(delta)
		"breath":
			_breath(delta)
		"drain":
			_drain(delta)
		"recover":
			move_with(Vector2.ZERO, delta)
			if state_t <= 0.0:
				state = "idle"
		_:
			_think(delta)
	_update_visual(delta)
	if hpbar:
		hpbar.position = Vector2(0, -body_height - 8 - z - hover)
		if Engine.get_physics_frames() % 10 == 0:
			hpbar.queue_redraw()
	if name_tag:
		name_tag.position = Vector2(0, -body_height - 15 - z - hover)
	if tier == "boss" and not enraged and hp < max_hp * 0.5:
		_enrage()


func _cancel_attack() -> void:
	if state in ["windup", "breath", "drain"]:
		state = "recover"
		state_t = 0.3
		if telegraph and is_instance_valid(telegraph):
			telegraph.queue_free()
		telegraph = null
		if drain_beam and is_instance_valid(drain_beam):
			drain_beam.queue_free()


func _enrage() -> void:
	enraged = true
	speed *= 1.25
	base_stats["patk"] = float(base_stats["patk"]) * 1.15
	base_stats["matk"] = float(base_stats["matk"]) * 1.15
	var lv = level_node()
	if lv:
		lv.float_text(global_position + Vector2(0, -body_height - 10), "ENRAGED!", Color("ff4a4a"), 1.6)
		VFX.ring(lv, global_position, 70.0, Color("ff4a4a"), 0.6, 3.0)
		lv.shake(5.0, 0.4)
	Sfx.play("roar")
	_base_modulate = tint * Color(1.25, 0.85, 0.85)


# ===================================================================== targeting / movement
func _find_target() -> Actor:
	var lv = level_node()
	if lv == null:
		return null
	var best: Actor = null
	var bd := aggro_range * (1.5 if hurt_alert > 0.0 else 1.0)
	for a in lv.get_team_actors("player"):
		if a.dead:
			continue
		if a is Player and a.invisible_t > 0.0:
			continue
		var d = a.global_position.distance_to(global_position)
		if d < bd and lv.can_aggro(self, a):
			bd = d
			best = a
	return best


func _think(delta: float) -> void:
	if ai == "critter":
		_critter(delta)
		return
	if target == null or not is_instance_valid(target) or target.dead or (target is Player and target.invisible_t > 0.0):
		target = _find_target()
	elif global_position.distance_to(target.global_position) > aggro_range * 2.2 or not level_node().can_aggro(self, target):
		target = null
	if target == null:
		_wander(delta)
		return
	var to := target.global_position - global_position
	var dist := to.length()
	set_facing_x(to.x)
	# pick an attack
	for a in attacks:
		if float(atk_cds.get(a, 0.0)) > 0.0:
			continue
		var ad: Dictionary = GameData.ATTACKS[a]
		if dist <= float(ad["range"]) and dist >= float(ad.get("min", 0.0)):
			if ad["type"] == "heal" and not _has_hurt_ally(float(ad["range"])):
				continue
			if ad["type"] == "summon" and summons.size() >= 4:
				continue
			if ad["type"] in HEAVY_ATTACKS and _committed_on(target) >= 2:
				continue  # attack token: packs take turns instead of all lunging at once
			_start_attack(a)
			return
	_chase(delta, to, dist)


## Gap-closing attacks that are dangerous when a whole pack commits at the same moment.
const HEAVY_ATTACKS := ["lunge", "pounce", "swoop", "hop", "slam"]


## How many other monsters are currently winding up / performing a heavy attack on `t`.
func _committed_on(t: Actor) -> int:
	var n := 0
	var lv = level_node()
	if lv == null:
		return 0
	for o in lv.get_team_actors("enemy"):
		if o == self or not (o is Monster) or o.target != t:
			continue
		if o.state in ["windup", "lunge", "leap"] and GameData.ATTACKS.get(o.cur_attack, {}).get("type", "") in HEAVY_ATTACKS:
			n += 1
	return n


func _chase(delta: float, to: Vector2, dist: float) -> void:
	var dir := to / maxf(dist, 0.01)
	var want := dist
	match ai:
		"caster", "blinker":
			want = 110.0
		"pack":
			want = 55.0
		"pouncer":
			want = 85.0
		"flyer":
			want = 70.0
		"dragon":
			want = 60.0
		_:
			want = 14.0 + radius
	var mv := Vector2.ZERO
	if dist > want + 6.0:
		mv = level_node().path_dir(self, target.global_position)
	elif dist < want - 25.0 and ai in ["caster", "blinker", "pouncer", "flyer"]:
		mv = -dir
	if ai in ["pack", "flyer", "caster"] and dist < want + 30.0:
		mv += dir.orthogonal() * strafe_sign * 0.8
		if randf() < 0.005:
			strafe_sign *= -1.0
	if ai == "hopper":
		# move in little bursts
		var cycle := fmod(Time.get_ticks_msec() / 1000.0 + float(get_instance_id() % 100) * 0.1, 1.0)
		mv *= 1.6 if cycle < 0.45 else 0.0
		if cycle < 0.45 and z <= 0.0 and mv != Vector2.ZERO:
			vz = 90.0
	_avoid_stuck(delta, mv)
	if side_t > 0.0:
		mv = side_dir
	move_with(mv.normalized() * speed if mv != Vector2.ZERO else Vector2.ZERO, delta)
	play_anim("move" if mv != Vector2.ZERO else "idle")
	_separate(delta)


func _avoid_stuck(delta: float, mv: Vector2) -> void:
	side_t -= delta
	if mv == Vector2.ZERO:
		stuck_t = 0.0
		return
	if global_position.distance_to(_last_pos) < speed * delta * 0.25:
		stuck_t += delta
		if stuck_t > 0.35:
			stuck_t = 0.0
			side_t = 0.5
			side_dir = mv.orthogonal().normalized() * (1.0 if randf() < 0.5 else -1.0)
	else:
		stuck_t = 0.0
	_last_pos = global_position


func _separate(delta: float) -> void:
	# light separation so packs don't stack perfectly
	var lv = level_node()
	if lv == null or Engine.get_physics_frames() % 4 != get_instance_id() % 4:
		return
	for o in lv.get_team_actors("enemy"):
		if o == self or o.dead:
			continue
		var d := global_position.distance_to(o.global_position)
		if d < radius + o.radius and d > 0.01:
			knock += (global_position - o.global_position).normalized() * 30.0


func _wander(delta: float) -> void:
	wander_t -= delta
	if global_position.distance_to(home) > leash:
		wander_dir = (home - global_position).normalized()
		wander_t = 1.0
	elif wander_t <= 0.0:
		wander_t = randf_range(1.0, 3.0)
		wander_dir = Vector2.ZERO if randf() < 0.45 else Vector2.from_angle(randf() * TAU)
		if room_id >= 0 and level_node().has_method("room_center"):
			var rc: Vector2 = level_node().room_center(room_id)
			if global_position.distance_to(rc) > 60.0:
				wander_dir = (rc - global_position).normalized()
	_avoid_stuck(delta, wander_dir)
	var mv := side_dir if side_t > 0.0 else wander_dir
	move_with(mv * speed * 0.4, delta)
	if mv.x != 0.0:
		set_facing_x(mv.x)
	play_anim("move" if mv != Vector2.ZERO else "idle")


func _critter(delta: float) -> void:
	flee_t -= delta
	var lv = level_node()
	var pl: Actor = lv.player if lv else null
	if pl and is_instance_valid(pl) and not pl.dead and pl.global_position.distance_to(global_position) < 70.0:
		flee_t = 1.5
	if flee_t > 0.0 and pl and is_instance_valid(pl):
		var away := (global_position - pl.global_position).normalized()
		_avoid_stuck(delta, away)
		var mv := side_dir if side_t > 0.0 else away
		move_with(mv * speed, delta)
		set_facing_x(mv.x)
		play_anim("move")
	else:
		_wander(delta)


func _has_hurt_ally(rng: float) -> bool:
	for o in level_node().get_team_actors("enemy"):
		if not o.dead and o.hp < o.max_hp * 0.8 and o.global_position.distance_to(global_position) < rng:
			return true
	return false


func _dormant(delta: float) -> void:
	var lv = level_node()
	if lv and lv.player and is_instance_valid(lv.player) and lv.player.global_position.distance_to(global_position) < 22.0:
		wake()
	move_with(Vector2.ZERO, delta)


func wake() -> void:
	if not dormant:
		return
	dormant = false
	sprite.play("attack")
	Sfx.play("roar", 0.1, 0.6)
	var lv = level_node()
	if lv:
		lv.float_text(global_position + Vector2(0, -26), "It's a Mimic!", Color("ff6a6a"), 1.2)
	hurt_alert = 3.0


func on_hurt(_amount: int, info: Dictionary) -> void:
	hurt_alert = 3.0
	if hpbar:
		hpbar.queue_redraw()
	if dormant:
		wake()
	if ai == "critter":
		flee_t = 2.0
	if target == null and info.get("src") and is_instance_valid(info["src"]) and info["src"] is Actor and info["src"].team == "player":
		target = info["src"]
	if state == "idle" and not dead and sprite.animation != "attack":
		sprite.play("hurt")


# ===================================================================== attacks
func _attack_def() -> Dictionary:
	return GameData.ATTACKS.get(cur_attack, {})


func _start_attack(a: String) -> void:
	cur_attack = a
	var ad: Dictionary = GameData.ATTACKS[a]
	state = "windup"
	var wind := float(ad.get("wind", 0.4)) * (0.7 if enraged else 1.0)
	state_t = wind
	attack_dir = (target.global_position - global_position).normalized()
	attack_pos = target.global_position
	hit_done.clear()
	play_anim("attack")
	sprite.pause()
	sprite.frame = 0
	var lv = level_node()
	var warn := Color(1.0, 0.25, 0.2)
	match ad["type"]:
		"melee":
			var tf := VFX.cone(lv, global_position, attack_dir, float(ad["radius"]) + 4.0, float(ad["arc"]), warn, wind)
			tf.color.a = 0.6
			telegraph = tf
		"slam":
			telegraph = VFX.telegraph(lv, global_position, float(ad["radius"]), warn, wind)
		"pounce", "hop":
			attack_pos = target.global_position + target.velocity * 0.15
			if ad["type"] == "pounce":
				telegraph = VFX.telegraph(lv, attack_pos, float(ad["radius"]), warn, wind)
		"target_aoe":
			telegraph = VFX.telegraph(lv, attack_pos, float(ad["radius"]), warn, wind)
		"lunge", "swoop":
			telegraph = VFX.line_telegraph(lv, global_position, attack_dir, float(ad.get("dist", ad["range"])), radius * 2.0, warn, wind)
		"breath":
			telegraph = VFX.cone(lv, global_position, attack_dir, float(ad["range"]), float(ad["arc"]), warn, wind)
		"meteor":
			Sfx.play("roar", 0.1, 0.7)
	if ad["type"] in ["heal", "summon", "blink", "nova", "meteor", "drain"]:
		VFX.particles(lv, global_position + Vector2(0, -body_height * 0.6), GameData.element_color(element), 10, 30.0, wind, Vector2(0, -30), "spark", 0.5)


func _windup(delta: float) -> void:
	move_with(Vector2.ZERO, delta)
	if target and is_instance_valid(target):
		var ad := _attack_def()
		if ad["type"] in ["proj", "spread", "drain"]:
			attack_dir = (target.global_position - global_position).normalized()
	if state_t <= 0.0:
		telegraph = null
		sprite.play("attack")
		_execute()


func _blind_miss() -> bool:
	if has_status("blind") and randf() < 0.5:
		level_node().float_text(global_position + Vector2(0, -body_height - 6), "Miss", Color("aab4c8"), 0.8)
		return true
	return false


func _execute() -> void:
	var ad := _attack_def()
	atk_cds[cur_attack] = float(ad["cd"]) * (0.7 if enraged else 1.0) * randf_range(0.9, 1.2)
	var lv = level_node()
	var power := float(ad.get("power", 1.0)) * 100.0
	var el := element if ad["type"] in ["proj", "spread", "nova", "breath", "meteor", "target_aoe", "drain"] else "none"
	var st := {}
	if ad.has("status"):
		st = {"id": ad["status"], "chance": 60.0, "dur": 3.0, "power": 25.0}
	_finish_recover(0.35)
	match ad["type"]:
		"melee":
			if _blind_miss():
				return
			var col := Color(1, 0.9, 0.85, 0.85)
			VFX.slash(lv, global_position + Vector2(0, -body_height * 0.4), attack_dir, float(ad["radius"]), float(ad["arc"]), col, 0.18, 3.0 * scale_mult)
			Sfx.play("swing", 0.1, 0.7)
			for a in lv.actors_in_arc(global_position, attack_dir, float(ad["radius"]) + 2.0, float(ad["arc"]), "player"):
				Combat.hit(self, a, power, dmg_kind if dmg_kind == "magic" and false else "phys", el, {"knock": 90.0, "status": st})
		"slam":
			VFX.element_burst(lv, global_position, "earth", float(ad["radius"]))
			lv.shake(4.0, 0.25)
			for a in lv.actors_in_radius(global_position, float(ad["radius"]), "player"):
				Combat.hit(self, a, power, "phys", el, {"knock": 160.0, "status": {"id": "stun", "chance": 25.0, "dur": 0.6}})
		"lunge":
			if _blind_miss():
				return
			state = "lunge"
			state_t = 0.28
			lunge_vel = attack_dir * float(ad.get("dist", 70.0)) / 0.28
			invuln_t = 0.0
		"swoop":
			state = "lunge"
			state_t = 0.4
			var d := (attack_pos - global_position)
			lunge_vel = d.normalized() * (d.length() + 50.0) / 0.4
		"hop", "pounce":
			state = "leap"
			leap_from = global_position
			leap_to = attack_pos
			var dd := leap_to - leap_from
			if dd.length() > float(ad["range"]):
				leap_to = leap_from + dd.normalized() * float(ad["range"])
			leap_dur = 0.45 if ad["type"] == "hop" else 0.55
			leap_t = 0.0
			Sfx.play("dash", 0.1, 0.5)
		"target_aoe":
			var fx: String = ad.get("fx", "rock")
			for k in 5:
				VFX.spike(lv, attack_pos + Vector2.from_angle(k * TAU / 5.0) * float(ad["radius"]) * 0.55, "spike_rock", 1.1)
			VFX.spike(lv, attack_pos, "spike_rock", 1.4)
			VFX.element_burst(lv, attack_pos, element, float(ad["radius"]))
			for a in lv.actors_in_radius(attack_pos, float(ad["radius"]), "player"):
				Combat.hit(self, a, power, dmg_kind, el, {"knock": 60.0, "status": {"id": ad.get("status", "root"), "chance": 70.0, "dur": 1.2}})
		"proj":
			if _blind_miss():
				return
			_fire(attack_dir, ad, power, el, st)
		"spread":
			var n := int(ad.get("count", 3))
			var spr := deg_to_rad(float(ad.get("spread", 40)))
			for i in n:
				var ang := -spr * 0.5 + spr * i / maxf(1.0, n - 1)
				_fire(attack_dir.rotated(ang), ad, power, el, st)
		"nova":
			var n2 := int(ad.get("count", 12))
			for i in n2:
				_fire(Vector2.from_angle(TAU * i / n2), ad, power, el, st)
			VFX.ring(lv, global_position, 30.0, GameData.element_color(element), 0.3)
		"heal":
			for o in lv.get_team_actors("enemy"):
				if not o.dead and o.global_position.distance_to(global_position) < float(ad["range"]):
					o.heal(o.max_hp * float(ad["pct"]) / 100.0)
					VFX.particles(lv, o.global_position + Vector2(0, -10), Color("7be05a"), 10, 30.0, 0.7, Vector2(0, -40), "spark", 0.5)
			VFX.ground_ring(lv, global_position, float(ad["range"]) * 0.6, Color("7be05a"), 0.6)
			Sfx.play("heal", 0.1, 0.6)
		"blink":
			if target and is_instance_valid(target):
				VFX.particles(lv, global_position + Vector2(0, -12), Color("a66bff"), 16, 60.0, 0.5, Vector2.ZERO, "soft", 0.4)
				var behind := target.global_position + Vector2.from_angle(randf() * TAU) * 40.0
				if lv.is_walkable(behind):
					global_position = behind
				VFX.particles(lv, global_position + Vector2(0, -12), Color("a66bff"), 16, 60.0, 0.5, Vector2.ZERO, "soft", 0.4)
				Sfx.play("dark", 0.1, 0.6)
		"summon":
			for i in int(ad.get("count", 3)):
				var pos := global_position + Vector2.from_angle(randf() * TAU) * 20.0
				var m = lv.spawn_monster(ad["monster"], pos, maxi(1, level - 2), "normal", {"summoned": true})
				if m:
					m.summoner = self
					m.no_loot = true
					summons.append(m)
					m.died.connect(func(x): summons.erase(x))
			VFX.ring(lv, global_position, 40.0, Color("a66bff"), 0.5)
			Sfx.play("dark", 0.1, 0.7)
		"drain":
			if target and is_instance_valid(target):
				state = "drain"
				drain_t = float(ad.get("dur", 1.5))
				state_t = drain_t
		"breath":
			state = "breath"
			breath_t = 0.0
			state_t = float(ad.get("dur", 1.2))
			Sfx.play("fire" if element == "fire" else "wind", 0.1, 0.8)
		"meteor":
			for i in int(ad.get("count", 5)):
				var p := attack_pos + Vector2(randf_range(-60, 60), randf_range(-40, 40))
				if i == 0 and target and is_instance_valid(target):
					p = target.global_position
				var delay := 0.9 + i * 0.18
				VFX.telegraph(lv, p, float(ad["radius"]), Color(1, 0.4, 0.2), delay)
				var cb := func():
					VFX.explosion(lv, p, float(ad["radius"]), Color("ff6a2a"))
					for a in lv.actors_in_radius(p, float(ad["radius"]), "player"):
						Combat.hit(self if is_instance_valid(self) else null, a, power, "magic", "fire", {"knock": 100.0, "ast": base_stats, "status": {"id": "burn", "chance": 60.0, "dur": 3.0, "power": 25.0}})
				VFX.sky_object(lv, Art.fx("meteor"), p, delay, 160.0, 0.9, cb, 0.6)


func _fire(dir: Vector2, ad: Dictionary, power: float, el: String, st: Dictionary) -> void:
	var col := GameData.element_color(el) if el != "none" else Color.WHITE
	if ad.has("color"):
		col = Color(ad["color"])
	Projectile.spawn(level_node(), global_position + dir * radius, dir, {"attacker": self, "team": "enemy", "speed": ad.get("speed", 200.0),
		"range": float(ad["range"]) + 60.0, "power": power, "dmg": dmg_kind, "el": el, "opts": {"knock": 50.0, "status": st},
		"tex": ad.get("proj", "bolt"), "color": col, "explode": float(ad.get("explode", 0.0)), "height": body_height * 0.5 + hover,
		"spin": 12.0 if ad.get("proj", "") in ["bone", "knife"] else 0.0})
	Sfx.play("shoot", 0.1, 0.5)


func _finish_recover(t: float) -> void:
	state = "recover"
	state_t = t


func _lunge(delta: float) -> void:
	velocity = lunge_vel
	move_and_slide()
	if hover > 0.0:
		VFX.afterimage(self, Color(1, 0.6, 0.5, 0.4), 0.2)
	var lv = level_node()
	var ad := _attack_def()
	for a in lv.actors_in_radius(global_position, radius + 8.0, "player"):
		if hit_done.has(a.get_instance_id()):
			continue
		hit_done[a.get_instance_id()] = true
		Combat.hit(self, a, float(ad.get("power", 1.0)) * 100.0, "phys", "none", {"knock": 140.0, "knock_dir": lunge_vel.normalized()})
	if state_t <= 0.0:
		_finish_recover(0.4)


func _leap(delta: float) -> void:
	leap_t += delta
	var p := clampf(leap_t / leap_dur, 0.0, 1.0)
	var np := leap_from.lerp(leap_to, p)
	velocity = (np - global_position) / maxf(delta, 0.001)
	move_and_slide()
	z = sin(p * PI) * (34.0 if cur_attack == "pounce" else 18.0)
	if p >= 1.0:
		z = 0.0
		var ad := _attack_def()
		var lv = level_node()
		var r := float(ad.get("radius", 16.0))
		VFX.ground_ring(lv, global_position, r, Color(1, 0.9, 0.8), 0.3, 2.0)
		VFX.particles(lv, global_position, Color("9a7050"), 8, 50.0, 0.4, Vector2(0, 80), "px", 0.4, 70.0)
		if cur_attack == "pounce":
			lv.shake(3.0, 0.15)
		for a in lv.actors_in_radius(global_position, r, "player"):
			Combat.hit(self, a, float(ad.get("power", 1.0)) * 100.0, "phys", "none", {"knock": 120.0})
		_finish_recover(0.45)


func _breath(delta: float) -> void:
	move_with(Vector2.ZERO, delta)
	if target and is_instance_valid(target):
		var want := (target.global_position - global_position).normalized()
		attack_dir = attack_dir.slerp(want, delta * 1.5)
	breath_t -= delta
	var ad := _attack_def()
	var lv = level_node()
	var col := Color("ff7a2a") if ad.get("fx", "") == "fire" else Color("8ad36a")
	var mouth := global_position + Vector2(0, -body_height * 0.6) + attack_dir * radius
	VFX.particles(lv, mouth, col, 5, float(ad["range"]) * 2.6, 0.4, Vector2.ZERO, "soft", 0.6, float(ad["arc"]) * 0.4, attack_dir)
	if breath_t <= 0.0:
		breath_t = 0.25
		for a in lv.actors_in_arc(global_position, attack_dir, float(ad["range"]), float(ad["arc"]), "player"):
			Combat.hit(self, a, float(ad.get("power", 0.3)) * 100.0, "magic", element, {"knock": 20.0, "no_flash": false,
				"status": {"id": ad.get("status", "burn"), "chance": 35.0, "dur": 3.0, "power": 20.0}})
	if state_t <= 0.0:
		_finish_recover(0.5)


func _drain(delta: float) -> void:
	move_with(Vector2.ZERO, delta)
	var lv = level_node()
	if target == null or not is_instance_valid(target) or target.dead or target.global_position.distance_to(global_position) > 140.0:
		if drain_beam and is_instance_valid(drain_beam):
			drain_beam.queue_free()
		_finish_recover(0.3)
		return
	breath_t -= delta
	if breath_t <= 0.0:
		breath_t = 0.3
		var ad := _attack_def()
		var dealt := Combat.hit(self, target, float(ad.get("power", 0.35)) * 100.0, "magic", "dark", {"no_flash": true})
		heal(dealt * 1.5, true)
		VFX.beam(lv, target.body_center(), body_center(), 3.0, Color("e43b44"), 0.3)
		VFX.particles(lv, target.body_center(), Color("e43b44"), 4, 30.0, 0.3, Vector2.ZERO, "soft", 0.3)
	if state_t <= 0.0:
		_finish_recover(0.4)


# ===================================================================== death
func die(killer = null) -> void:
	if dead:
		return
	if data.get("rebirth", false) and not rebirth_used:
		rebirth_used = true
		hp = max_hp * 0.5
		invuln_t = 1.5
		var lv = level_node()
		if lv:
			lv.float_text(global_position + Vector2(0, -body_height - 10), "REBIRTH!", Color("ff9a2a"), 1.6)
			VFX.explosion(lv, global_position, 60.0, Color("ff9a2a"), "fire")
			VFX.pillar(lv, global_position, 10.0, 100.0, Color("ffd27a"), 1.0)
			for a in lv.actors_in_radius(global_position, 60.0, "player"):
				Combat.hit(self, a, 150.0, "magic", "fire", {"knock": 160.0})
		return
	if telegraph and is_instance_valid(telegraph):
		telegraph.queue_free()
	if drain_beam and is_instance_valid(drain_beam):
		drain_beam.queue_free()
	super.die(killer)
	z = 0.0
	hover = 0.0
	if hpbar:
		hpbar.queue_free()
		hpbar = null
	if name_tag:
		name_tag.queue_free()
		name_tag = null
	var lvn = level_node()
	if lvn:
		lvn.on_monster_died(self, killer)
	for s in summons.duplicate():
		if is_instance_valid(s) and not s.dead:
			s.die(null)
	var tw := create_tween()
	tw.tween_interval(0.7)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)
