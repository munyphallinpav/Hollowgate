class_name Player
extends Actor
## The player character: input, aiming, basic attacks per weapon type, dash with i-frames,
## skill casting, consumable hotkeys, passive procs, hunger.

const DASH_TIME := 0.18
const DASH_BASE_DIST := 72.0
const DASH_BASE_CD := 0.9

var cls := "warrior"
var aim := Vector2.RIGHT
var move_dir := Vector2.ZERO
var dir_name := "down"
var attack_cd := 0.0
var attack_held := false
var dash_cd := 0.0
var dash_t := 0.0
var dash_vec := Vector2.ZERO
var lock_t := 0.0
var anim_lock_t := 0.0
var anim_override := ""
var skill_cds: Dictionary = {}
var gcd := 0.0
var speed_mult_override := 1.0
var speed_override_t := 0.0
var wind_walker_t := 0.0
var spree_stacks := 0
var spree_t := 0.0
var enchant: Dictionary = {}
var teleport_t := -1.0
var death_t := 0.0
var hunger_tick := 0.0
var weapon_pivot: Node2D
var weapon_sprite: Sprite2D
var swing_t := 0.0
var swing_from := 0.0
var swing_to := 0.0
var swing_dur := 0.12
var light: PointLight2D
var interact_target: Node = null
var passive_ready: Dictionary = {"last_stand": 0.0, "revive": 0.0}
var in_air_skill := false
var invisible_t := 0.0
var spin_t := 0.0
var dash_step_cb: Callable
var dash_hop := 0.0
var dash_total := 0.0
var leap_from := Vector2.ZERO
var leap_to := Vector2.ZERO
var leap_t := -1.0
var leap_dur := 0.5
var leap_h := 40.0
var leap_cb: Callable
var shield_burst: Callable
var bot_aim := Vector2.INF  # used by the automated playtest bot instead of the mouse


func _ready() -> void:
	team = "player"
	add_to_group("team_player")
	add_to_group("player")
	radius = 6.0
	body_height = 22.0
	collision_layer = 4
	collision_mask = 1 | 2
	cls = Game.player["class"]
	display_name = Game.player["name"]
	build_body("char_" + cls, 1.0)
	weapon_pivot = Node2D.new()
	weapon_pivot.position = Vector2(0, -12)
	visual.add_child(weapon_pivot)
	weapon_sprite = Sprite2D.new()
	weapon_pivot.add_child(weapon_sprite)
	light = PointLight2D.new()
	light.texture = Art.fx("light")
	light.texture_scale = 3.5
	light.energy = 0.0
	light.color = Color(1.0, 0.85, 0.6)
	light.position = Vector2(0, -10)
	add_child(light)
	Game.player_node = self
	on_equipment_changed()
	Game.recalc()
	max_hp = Game.stats["max_hp"]
	max_mp = Game.stats["max_mp"]
	hp = float(Game.player.get("hp", max_hp))
	mp = float(Game.player.get("mp", max_mp))
	if hp <= 0.0:
		hp = max_hp
	if mp < 0.0:
		mp = max_mp
	hp = minf(hp, max_hp)
	mp = minf(mp, max_mp)
	play_anim("idle_down")


func get_stats() -> Dictionary:
	return Game.stats


func mouse_pos() -> Vector2:
	return bot_aim if bot_aim != Vector2.INF else get_global_mouse_position()


func buff_mod_list() -> Array:
	var out := []
	for b in buffs.values():
		out.append(b["mods"])
	if spree_stacks > 0:
		var v := float(Game.stats.get("spree", 0.0)) * spree_stacks
		out.append({"aspd_pct": v, "move_pct": v})
	return out


func _on_buffs_changed() -> void:
	Game.recalc()
	_refresh_max()


func _refresh_max() -> void:
	var r_hp := hp / maxf(1.0, max_hp)
	max_hp = Game.stats["max_hp"]
	max_mp = Game.stats["max_mp"]
	hp = minf(hp, max_hp)
	mp = minf(mp, max_mp)


func on_equipment_changed() -> void:
	var w := StatCalc.weapon_type(Game.player)
	if w == "":
		weapon_sprite.texture = null
	else:
		weapon_sprite.texture = Art.weapon(w)
		var tw := weapon_sprite.texture.get_width()
		weapon_sprite.offset = Vector2(tw * 0.5 - 3.0, 0)
		if w == "bow":
			weapon_sprite.offset = Vector2(4, 0)
		elif w == "grimoire":
			weapon_sprite.offset = Vector2(8, -2)
	_refresh_max()


func on_level_up() -> void:
	_refresh_max()
	hp = max_hp
	mp = max_mp
	var lv = level_node()
	if lv:
		VFX.pillar(lv, global_position, 8.0, 90.0, Color("fee761"), 0.8)
		VFX.ground_ring(lv, global_position, 40.0, Color("fee761"), 0.6, 2.0)
		VFX.particles(lv, global_position + Vector2(0, -10), Color("fee761"), 30, 90.0, 1.0, Vector2(0, -30), "spark", 0.7)
		lv.float_text(global_position + Vector2(0, -40), "LEVEL UP!", Color("fee761"), 1.6)


# ===================================================================== input
func _unhandled_input(event: InputEvent) -> void:
	if dead:
		return
	if event.is_action_pressed("attack"):
		attack_held = true


func _physics_process(delta: float) -> void:
	if dead:
		death_t += delta
		_update_visual(delta)
		if death_t > 2.2 and death_t - delta <= 2.2:
			var lv = level_node()
			if lv:
				lv.on_player_died()
		return
	_update_statuses(delta)
	if dead:
		return
	_update_buffs(delta)
	_update_z(delta)
	_timers(delta)
	_regen(delta)
	aim = (mouse_pos() - (global_position + Vector2(0, -10))).normalized()
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT
	if not Input.is_action_pressed("attack"):
		attack_held = false
	move_dir = Vector2.ZERO
	if lock_t <= 0.0 and can_move():
		move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if teleport_t >= 0.0:
		_teleport_channel(delta)
	if leap_t >= 0.0:
		_leap_step(delta)
	elif dash_t > 0.0:
		_dash_step(delta)
	else:
		var spd := float(Game.stats.get("move", 85.0)) * (speed_mult_override if speed_override_t > 0.0 else 1.0)
		if lock_t > 0.0:
			spd = 0.0
		move_with(move_dir * spd, delta)
		if can_act() and lock_t <= 0.0 and not in_air_skill:
			_handle_actions()
	_update_interact()
	_update_anim()
	_update_weapon(delta)
	_update_visual(delta)
	if invisible_t > 0.0:
		sprite.modulate.a = 0.35
	light.energy = lerpf(light.energy, level_node().player_light_energy() if level_node() else 0.0, delta * 2.0)


func _timers(delta: float) -> void:
	for k in skill_cds.keys():
		skill_cds[k] = float(skill_cds[k]) - delta
		if skill_cds[k] <= 0.0:
			skill_cds.erase(k)
	attack_cd -= delta
	dash_cd -= delta
	gcd -= delta
	lock_t -= delta
	anim_lock_t -= delta
	wind_walker_t -= delta
	invisible_t -= delta
	if speed_override_t > 0.0:
		speed_override_t -= delta
	if spree_t > 0.0:
		spree_t -= delta
		if spree_t <= 0.0:
			spree_stacks = 0
			Game.recalc()
	if not enchant.is_empty():
		enchant["t"] = float(enchant["t"]) - delta
		if float(enchant["t"]) <= 0.0:
			enchant = {}
			weapon_sprite.modulate = Color.WHITE


func _handle_actions() -> void:
	if Input.is_action_just_pressed("dash"):
		try_dash()
		return
	for i in 4:
		if Input.is_action_just_pressed("skill_%d" % (i + 1)):
			var sid: String = Game.player["hot_skills"][i]
			if sid != "":
				try_cast(sid)
		if Input.is_action_just_pressed("item_%d" % (i + 1)):
			Game.use_hot_item(i)
	if Input.is_action_just_pressed("interact") and interact_target and is_instance_valid(interact_target):
		interact_target.interact(self)
		return
	if Input.is_action_just_pressed("teleport_town"):
		start_town_teleport()
	if attack_held and attack_cd <= 0.0:
		basic_attack()


# ===================================================================== regen / hunger
func _regen(delta: float) -> void:
	var sat: float = Game.player.get("satiety", 100.0)
	var hunger_rate := 100.0 / 1200.0 * (1.0 - minf(80.0, float(Game.stats.get("hunger_pct", 0.0))) / 100.0)
	if level_node() and level_node().is_town():
		hunger_rate *= 0.3
	sat = maxf(0.0, sat - hunger_rate * delta)
	Game.player["satiety"] = sat
	var regen_mult := 1.0 if sat > 20.0 else (0.4 if sat > 0.0 else 0.0)
	hp = minf(max_hp, hp + float(Game.stats.get("hp_regen", 0.0)) * regen_mult * delta)
	mp = minf(max_mp, mp + float(Game.stats.get("mp_regen", 0.0)) * delta)
	if sat <= 0.0:
		hunger_tick += delta
		if hunger_tick >= 2.0:
			hunger_tick = 0.0
			if hp > 1.0:
				hp = maxf(1.0, hp - max_hp * 0.01)
				if level_node():
					level_node().float_text(global_position + Vector2(0, -30), "Starving", Color("ffb070"), 0.8)


# ===================================================================== movement
func try_dash() -> void:
	if dash_cd > 0.0 or not can_move():
		return
	var d := move_dir if move_dir != Vector2.ZERO else aim
	dash_vec = d.normalized()
	var dist := DASH_BASE_DIST * (1.0 + float(Game.stats.get("dash_dist_pct", 0.0)) / 100.0)
	dash_t = DASH_TIME
	dash_total = DASH_TIME
	dash_step_cb = Callable()
	dash_hop = 0.0
	dash_vec *= dist / DASH_TIME
	dash_cd = DASH_BASE_CD * (1.0 - float(Game.stats.get("dash_cd_pct", 0.0)) / 100.0)
	invuln_t = maxf(invuln_t, DASH_TIME + 0.08)
	if float(Game.stats.get("wind_walker", 0.0)) > 0.0:
		wind_walker_t = 2.0
	teleport_t = -1.0
	Sfx.play("dash")
	VFX.particles(level_node(), global_position, Color(0.85, 0.9, 1.0, 0.7), 8, 40.0, 0.35, Vector2.ZERO, "smoke", 0.5)


func _dash_step(delta: float) -> void:
	dash_t -= delta
	velocity = dash_vec
	move_and_slide()
	VFX.afterimage(self, Color(0.55, 0.8, 1.0, 0.55), 0.25)
	if dash_hop > 0.0 and dash_total > 0.0:
		z = sin(clampf(1.0 - dash_t / dash_total, 0.0, 1.0) * PI) * dash_hop
	if dash_step_cb.is_valid():
		dash_step_cb.call(global_position)
	if dash_t <= 0.0:
		velocity = Vector2.ZERO
		dash_step_cb = Callable()
		dash_hop = 0.0
		z = 0.0


## Skill-driven dash (Shield Bash, Flame Dance, Evasive Shot). step(pos) is called every frame.
func start_skill_dash(dir: Vector2, dist: float, dur: float, step: Callable = Callable(), hop: float = 0.0) -> void:
	dash_vec = dir.normalized() * dist / dur
	dash_t = dur
	dash_total = dur
	dash_step_cb = step
	dash_hop = hop
	invuln_t = maxf(invuln_t, dur + 0.05)
	teleport_t = -1.0


## Leap through the air (z arc) and land on `to`, then call `on_land`.
func start_leap(to: Vector2, dur: float, height: float, on_land: Callable) -> void:
	leap_from = global_position
	leap_to = to
	leap_t = 0.0
	leap_dur = dur
	leap_h = height
	leap_cb = on_land
	in_air_skill = true
	invuln_t = maxf(invuln_t, dur + 0.05)
	teleport_t = -1.0


func _leap_step(delta: float) -> void:
	leap_t += delta
	var p := clampf(leap_t / leap_dur, 0.0, 1.0)
	var np := leap_from.lerp(leap_to, p)
	velocity = (np - global_position) / maxf(delta, 0.001)
	move_and_slide()
	z = sin(p * PI) * leap_h
	if p >= 1.0:
		leap_t = -1.0
		z = 0.0
		in_air_skill = false
		velocity = Vector2.ZERO
		if leap_cb.is_valid():
			leap_cb.call()


func on_shield_end(broken: bool) -> void:
	super.on_shield_end(broken)
	if shield_burst.is_valid():
		var cb := shield_burst
		shield_burst = Callable()
		cb.call()


func lock(dur: float) -> void:
	lock_t = maxf(lock_t, dur)


func slow_for(mult: float, dur: float) -> void:
	speed_mult_override = mult
	speed_override_t = dur


# ===================================================================== animation
func _dir_from(v: Vector2) -> String:
	if absf(v.x) >= absf(v.y) * 0.85:
		return "side"
	return "up" if v.y < 0.0 else "down"


func _update_anim() -> void:
	var v := move_dir
	var looking := aim if (attack_held or anim_lock_t > 0.0 or move_dir == Vector2.ZERO) else move_dir
	dir_name = _dir_from(looking)
	if dir_name == "side":
		sprite.flip_h = looking.x < 0.0
	else:
		sprite.flip_h = false
	var base := "idle"
	if dash_t > 0.0:
		base = "dash"
	elif anim_lock_t > 0.0 and anim_override != "":
		base = anim_override
	elif v != Vector2.ZERO and lock_t <= 0.0:
		base = "walk"
	play_anim(base + "_" + dir_name)
	if base == "walk":
		sprite.speed_scale = clampf(float(Game.stats.get("move", 85.0)) / 85.0, 0.6, 2.0)
	elif sprite.speed_scale != 0.0:
		sprite.speed_scale = 1.0


func set_action_anim(kind: String, dur: float) -> void:
	anim_override = kind
	anim_lock_t = dur
	sprite.stop()
	sprite.play(kind + "_" + _dir_from(aim))


func _update_weapon(delta: float) -> void:
	var w := StatCalc.weapon_type(Game.player)
	weapon_pivot.z_index = -1 if dir_name == "up" else 1
	var ang := aim.angle()
	if spin_t > 0.0:
		spin_t -= delta
		ang = Time.get_ticks_msec() * 0.03
	elif swing_t > 0.0:
		swing_t -= delta
		var p := 1.0 - clampf(swing_t / swing_dur, 0.0, 1.0)
		ang = lerp_angle(swing_from, swing_to, ease(p, 0.4))
	elif w in ["sword", "hammer", "dagger"] and not attack_held:
		# rest pose: weapon held low in the facing direction
		var fx := -1.0 if sprite.flip_h else 1.0
		if dir_name == "side":
			ang = deg_to_rad(60.0) if fx > 0 else deg_to_rad(120.0)
		else:
			ang = deg_to_rad(70.0) if dir_name == "down" else deg_to_rad(-110.0)
	weapon_pivot.rotation = ang
	weapon_sprite.flip_v = absf(wrapf(ang, -PI, PI)) > PI * 0.5
	if w == "grimoire":
		weapon_pivot.rotation = 0.0
		weapon_sprite.flip_v = false
		weapon_sprite.position = Vector2(-8 if sprite.flip_h else 0, sin(Time.get_ticks_msec() * 0.004) * 1.5 - 2)
	else:
		weapon_sprite.position = Vector2.ZERO
	if not enchant.is_empty():
		weapon_sprite.modulate = GameData.element_color(enchant["el"]).lightened(0.3)


# ===================================================================== combat
func is_specialized() -> bool:
	return Game.is_specialized_weapon()


func damage_out_mult() -> float:
	var m := 1.0
	if is_specialized():
		m *= 1.15
	if hp < max_hp * 0.35 and float(Game.stats.get("low_hp_atk", 0.0)) > 0.0:
		m *= 1.0 + float(Game.stats["low_hp_atk"]) / 100.0
	if wind_walker_t > 0.0 and float(Game.stats.get("wind_walker", 0.0)) > 0.0:
		m *= 1.0 + float(Game.stats["wind_walker"]) / 100.0
	return m


func attack_speed() -> float:
	var s := float(Game.stats.get("aspd", 1.0))
	if is_specialized():
		s *= 1.10
	return s


func basic_attack() -> void:
	var w := StatCalc.weapon_type(Game.player)
	var g: Dictionary = GameData.ItemData.GEAR.get(w, {})
	var atk: Dictionary = g.get("attack", {"style": "melee", "radius": 22, "arc": 100, "cd": 0.5, "mult": 0.6, "knock": 40})
	var aspd := attack_speed()
	attack_cd = float(atk["cd"]) / aspd
	var dmg_type := "magic" if g.get("atk", "patk") == "matk" else "phys"
	var el := "none"
	var power := float(atk["mult"]) * 100.0
	if not enchant.is_empty():
		el = enchant["el"]
		power *= 1.0 + float(enchant["bonus"]) / 100.0
	var opts := {"basic": true, "knock": float(atk.get("knock", 50)) * (1.0 + float(Game.stats.get("knock_pct", 0.0)) / 100.0)}
	if float(Game.stats.get("poison_hit", 0.0)) > 0.0:
		opts["status"] = {"id": "poison", "chance": Game.stats["poison_hit"], "dur": 4.0, "power": 25.0}
	if el != "none" and not opts.has("status"):
		opts["status"] = {"id": GameData.WorldData.ELEMENT_STATUS[el], "chance": 15.0, "dur": 2.5}
	var lv = level_node()
	var origin := global_position + Vector2(0, -10)
	wind_walker_t = 0.0 if wind_walker_t > 0.0 and wind_walker_t < 1.95 else wind_walker_t
	match atk["style"]:
		"melee", "thrust":
			var r := float(atk["radius"])
			var arc := float(atk["arc"])
			set_action_anim("attack", minf(0.3, attack_cd))
			_swing(arc, minf(0.14, attack_cd * 0.8))
			var col := Color(1, 1, 1, 0.9) if el == "none" else GameData.element_color(el)
			if atk["style"] == "thrust":
				VFX.beam(lv, origin + aim * 6.0, origin + aim * (r + 4.0), 3.0, col, 0.14)
			else:
				VFX.slash(lv, origin, aim, r, arc, col, 0.2, 3.5 if w != "hammer" else 5.0)
			if w == "hammer":
				lv.shake(1.5, 0.1)
			var hit_any := false
			for a in lv.actors_in_arc(global_position, aim, r + 4.0, arc, "enemy"):
				Combat.hit(self, a, power, dmg_type, el, opts.merged({"knock_dir": (a.global_position - global_position).normalized()}))
				VFX.hit_spark(lv, a.body_center(), col)
				hit_any = true
			lv.hit_props(global_position + aim * r * 0.7, r * 0.7, self)
			Sfx.play("hit" if hit_any else "swing")
			if hit_any and w == "hammer":
				lv.shake(2.5, 0.12)
			if not enchant.is_empty() and enchant["el"] == "fire":
				VFX.particles(lv, origin + aim * r * 0.6, Color("ff8a3a"), 8, 60.0, 0.4, Vector2(0, -40), "soft", 0.3)
		"proj":
			set_action_anim("attack" if w in ["bow", "gun"] else "cast", minf(0.3, attack_cd))
			var tex: String = atk.get("proj", "bolt")
			var dirs := [aim]
			if float(Game.stats.get("split", 0.0)) > 0.0 and randf() * 100.0 < float(Game.stats["split"]):
				dirs.append(aim.rotated(0.18))
				dirs.append(aim.rotated(-0.18))
			for d in dirs:
				Projectile.spawn(lv, global_position + d * 8.0, d, {"attacker": self, "team": "player", "speed": atk["speed"],
					"range": atk["range"], "power": power, "dmg": dmg_type, "el": el, "opts": opts, "tex": tex,
					"pierce": atk.get("pierce", 0), "homing": atk.get("homing", 0.0), "color": GameData.element_color(el) if el != "none" else (Color("c8e6ff") if dmg_type == "magic" else Color.WHITE),
					"height": 12.0, "trail": dmg_type == "magic"})
			Sfx.play("gun" if w == "gun" else ("shoot" if w == "bow" else "magic"), 0.1, 0.6)
			if w == "gun":
				VFX.particles(lv, origin + aim * 14.0, Color("fee761"), 5, 70.0, 0.15, Vector2.ZERO, "px", 0.4, 30.0, aim)
				knock -= aim * 30.0


func _swing(arc: float, dur: float) -> void:
	var base := aim.angle()
	var half := deg_to_rad(arc) * 0.5
	var flip := 1.0 if aim.x >= 0.0 else -1.0
	swing_from = base - half * flip
	swing_to = base + half * flip
	swing_dur = maxf(0.05, dur)
	swing_t = swing_dur


func try_cast(sid: String) -> bool:
	var lvl := Game.skill_level(sid)
	if lvl <= 0:
		return false
	if gcd > 0.0 or skill_cds.has(sid):
		return false
	var s: Dictionary = GameData.SKILLS[sid]
	var cost := GameData.skill_mp(sid, lvl)
	if mp < cost:
		Sfx.play("error")
		level_node().float_text(global_position + Vector2(0, -34), "Not enough MP", Color("8fb8ff"), 0.8)
		return false
	var hp_cost := float(s.get("hp_cost", 0)) / 100.0 * max_hp
	if hp_cost > 0.0 and hp <= hp_cost + 1.0:
		return false
	var target := mouse_pos()
	if not SkillExec.cast(self, sid, lvl, target):
		# targeted skills (Shadow Step, Lotus Storm...) refuse without a target and cost nothing
		Sfx.play("error")
		if level_node():
			level_node().float_text(global_position + Vector2(0, -34), "No target in range", Color("aab4c8"), 0.8)
		return false
	mp -= cost
	hp -= hp_cost
	var cd := GameData.skill_cd(sid, lvl) * (1.0 - float(Game.stats.get("cdr", 0.0)) / 100.0)
	skill_cds[sid] = cd
	gcd = 0.25 / attack_speed()
	attack_cd = maxf(attack_cd, 0.15)
	return true


func skill_cd_ratio(sid: String) -> float:
	if not skill_cds.has(sid):
		return 0.0
	var lvl := maxi(1, Game.skill_level(sid))
	var total := GameData.skill_cd(sid, lvl) * (1.0 - float(Game.stats.get("cdr", 0.0)) / 100.0)
	return clampf(float(skill_cds[sid]) / maxf(0.01, total), 0.0, 1.0)


func on_dealt_damage(target: Actor, amount: int, info: Dictionary) -> void:
	var ls := float(Game.stats.get("lifesteal", 0.0))
	if info.get("crit", false):
		ls += float(Game.stats.get("crit_heal", 0.0))
	if ls > 0.0:
		heal(amount * ls / 100.0, false)


func on_kill(target: Actor) -> void:
	var kh := float(Game.stats.get("kill_heal", 0.0))
	if kh > 0.0:
		heal(max_hp * kh / 100.0)
	if float(Game.stats.get("spree", 0.0)) > 0.0:
		spree_stacks = mini(5, spree_stacks + 1)
		spree_t = 4.0
		Game.recalc()


# ===================================================================== damage taken
func take_damage(amount: int, info: Dictionary = {}) -> int:
	if dead:
		return 0
	if invuln_t > 0.0 and not info.get("dot", false):
		return 0
	var lv = level_node()
	var dmg := float(amount)
	if not info.get("dot", false):
		if randf() * 100.0 < float(Game.stats.get("dodge", 0.0)):
			if lv:
				lv.float_text(global_position + Vector2(0, -30), "Dodge", Color("c8e6ff"), 0.9)
			VFX.afterimage(self, Color(1, 1, 1, 0.5), 0.2)
			return 0
		if randf() * 100.0 < float(Game.stats.get("block", 0.0)):
			dmg *= 0.3
			if lv:
				lv.float_text(global_position + Vector2(0, -30), "Block", Color("c0cbdc"), 0.9)
				VFX.cross_flash(lv, global_position + aim * 8.0 + Vector2(0, -12), 8.0, Color(1, 1, 1), 0.2)
			Sfx.play("block")
		if hp < max_hp * 0.35 and float(Game.stats.get("low_hp_def", 0.0)) > 0.0:
			dmg *= 1.0 / (1.0 + float(Game.stats["low_hp_def"]) / 100.0)
	var ms := float(Game.stats.get("mana_shield", 0.0))
	if ms > 0.0 and mp > 0.0:
		var take := minf(mp, dmg * ms / 100.0)
		mp -= take
		dmg -= take
	var lethal := hp - dmg <= 0.0
	var now := Time.get_ticks_msec() / 1000.0
	if lethal and float(Game.stats.get("last_stand", 0.0)) > 0.0 and now >= float(passive_ready["last_stand"]):
		var lvl_ls := float(Game.stats["last_stand"])
		passive_ready["last_stand"] = now + maxf(60.0, 180.0 - 5.0 * lvl_ls)
		dmg = maxf(0.0, hp - 1.0)
		invuln_t = 2.0
		if lv:
			lv.float_text(global_position + Vector2(0, -36), "LAST STAND!", Color("ffd27a"), 1.4)
			VFX.ground_ring(lv, global_position, 40.0, Color("ffd27a"), 0.6, 3.0)
			VFX.particles(lv, global_position + Vector2(0, -10), Color("ffd27a"), 24, 90.0, 0.8, Vector2(0, -20), "spark", 0.6)
		Sfx.play("buff")
	var dealt := super.take_damage(int(dmg), info)
	if dead:
		return dealt
	if dealt > 0 and not info.get("dot", false):
		Sfx.play("hurt", 0.1, 0.8)
		if lv:
			lv.shake(2.0, 0.12)
			lv.hurt_flash()
		teleport_t = -1.0
		if randf() * 100.0 < float(Game.stats.get("martyr", 0.0)):
			heal(max_hp * 0.05)
			if lv:
				VFX.particles(lv, global_position + Vector2(0, -12), Color("7be05a"), 10, 40.0, 0.6, Vector2(0, -30), "spark", 0.5)
		if randf() * 100.0 < float(Game.stats.get("counter", 0.0)):
			_counter_attack()
	return dealt


func _counter_attack() -> void:
	var lv = level_node()
	if lv == null:
		return
	VFX.ring(lv, global_position + Vector2(0, -6), 40.0, Color("ffd27a"), 0.3, 3.0, 6.0)
	lv.float_text(global_position + Vector2(0, -36), "Counter!", Color("ffd27a"), 0.9)
	for a in lv.actors_in_radius(global_position, 40.0, "enemy"):
		Combat.hit(self, a, 150.0, "phys", "none", {"knock": 120.0})


func die(killer = null) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if float(Game.stats.get("revive", 0.0)) > 0.0 and now >= float(passive_ready["revive"]):
		passive_ready["revive"] = now + maxf(90.0, 300.0 - 8.0 * float(Game.stats["revive"]))
		hp = max_hp * 0.5
		invuln_t = 3.0
		clear_debuffs()
		var lv = level_node()
		if lv:
			lv.float_text(global_position + Vector2(0, -40), "RESURRECTION", Color("fff6c8"), 1.6)
			VFX.pillar(lv, global_position, 10.0, 120.0, Color("fff6c8"), 1.0)
			VFX.particles(lv, global_position + Vector2(0, -10), Color("fff6c8"), 30, 80.0, 1.0, Vector2(0, -40), "spark", 0.7)
		Sfx.play("heal")
		return
	super.die(killer)
	death_t = 0.0
	play_anim("death_" + dir_name)
	weapon_pivot.visible = false
	teleport_t = -1.0
	Sfx.play("death")


func revive_at(pos: Vector2, hp_frac: float = 1.0) -> void:
	dead = false
	global_position = pos
	collision_layer = 4
	collision_mask = 1 | 2
	hp = max_hp * hp_frac
	mp = max_mp * hp_frac
	invuln_t = 2.0
	weapon_pivot.visible = true
	statuses.clear()
	knock = Vector2.ZERO
	z = 0.0
	play_anim("idle_down")


# ===================================================================== consumables
func consume(t: Dictionary, id: String) -> void:
	var lv = level_node()
	var kind: String = t.get("kind", "potion")
	if t.has("heal_pct") or t.has("heal_flat"):
		heal(max_hp * float(t.get("heal_pct", 0)) / 100.0 + float(t.get("heal_flat", 0)))
	if t.has("mp_pct") or t.has("mp_flat"):
		var before := mp
		mp = minf(max_mp, mp + max_mp * float(t.get("mp_pct", 0)) / 100.0 + float(t.get("mp_flat", 0)))
		if lv and mp > before:
			lv.float_text(global_position + Vector2(4, -30), "+%d MP" % int(mp - before), Color("6fb8ff"), 0.9)
	if t.has("satiety"):
		Game.player["satiety"] = minf(100.0, float(Game.player["satiety"]) + float(t["satiety"]))
	if t.get("cure", false):
		clear_debuffs()
		add_buff("immune", 10.0, {}, Color("7be05a"), "Immune")
	if t.has("buff"):
		var b: Dictionary = t["buff"]
		var dur := float(b["dur"])
		if kind == "food":
			dur *= 1.0 + float(Game.stats.get("food_dur_pct", 0.0)) / 100.0
		add_buff(b["id"], dur, b["mods"], Color("ffd27a"), t["name"])
	if float(t.get("poison_chance", 0)) > 0.0 and randf() * 100.0 < float(t["poison_chance"]):
		apply_status("poison", 5.0, max_hp * 0.02)
	if lv:
		var c := Color("ff6a6a") if t.has("heal_pct") else (Color("6fb8ff") if t.has("mp_pct") else Color("ffd27a"))
		VFX.particles(lv, global_position + Vector2(0, -12), c, 10, 40.0, 0.6, Vector2(0, -40), "spark", 0.5)
	Sfx.play("eat" if kind == "food" else "heal")


# ===================================================================== interaction / teleport
func _update_interact() -> void:
	var best: Node = null
	var bd := 30.0
	for n in get_tree().get_nodes_in_group("interactable"):
		if not is_instance_valid(n) or not n.has_method("interact"):
			continue
		var d: float = n.global_position.distance_to(global_position)
		var r: float = n.get("interact_radius") if n.get("interact_radius") != null else 30.0
		if d < r and d < bd + r:
			bd = d
			best = n
	interact_target = best


func start_town_teleport() -> void:
	var lv = level_node()
	if lv == null:
		return
	if lv.is_town():
		Game.toast("You are already in town.", Color("aab4c8"))
		return
	teleport_t = 0.0
	Game.toast("Teleporting to town... (moving or getting hit cancels)", Color("8fd3ff"))
	Sfx.play("portal")


func _teleport_channel(delta: float) -> void:
	if move_dir != Vector2.ZERO:
		teleport_t = -1.0
		Game.toast("Teleport cancelled", Color("ff9a7a"))
		return
	teleport_t += delta
	if int(teleport_t * 10.0) % 2 == 0:
		VFX.particles(level_node(), global_position + Vector2(randf_range(-8, 8), 0), Color("8fd3ff"), 2, 20.0, 0.6, Vector2(0, -60), "spark", 0.5)
	if teleport_t >= 1.5:
		teleport_t = -1.0
		level_node().teleport_to_town()


func teleport_progress() -> float:
	return clampf(teleport_t / 1.5, 0.0, 1.0) if teleport_t >= 0.0 else -1.0
