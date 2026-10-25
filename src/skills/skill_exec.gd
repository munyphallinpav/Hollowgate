class_name SkillExec
extends RefCounted
## Executes active skills for the player. Each "kind" is a reusable behaviour configured by skill data.

static var _pm := 1.0  # power multiplier (spell echo casts at 50%)


static func cast(p: Player, sid: String, lv: int, target: Vector2, echo: bool = false) -> bool:
	var s: Dictionary = GameData.SKILLS[sid]
	var level = p.level_node()
	if level == null:
		return false
	_pm = 0.5 if echo else 1.0
	var aim := (target - p.global_position).normalized()
	if aim == Vector2.ZERO:
		aim = p.aim
	var el: String = s.get("el", "none")
	var col := GameData.element_color(el)
	var kind: String = s.get("kind", "")
	var magicish: bool = s.get("dmg", "phys") in ["magic", "hybrid"] or kind in ["buff", "heal", "zone", "summon", "regen"]
	p.set_action_anim("cast" if magicish else "attack", 0.3)
	if not echo:
		_cast_flourish(p, level, col, el)
	var ok := true
	match kind:
		"slash":
			_slash(p, level, sid, lv, aim, col, el)
		"dash_strike":
			_dash_strike(p, level, sid, lv, aim, col, el)
		"buff":
			_buff(p, level, sid, lv, col, el)
		"spin":
			_spin(p, level, sid, lv, col, el)
		"line_eruption":
			_line_eruption(p, level, sid, lv, aim, col, el)
		"enchant":
			p.enchant = {"el": GameData.SKILLS[sid]["p"]["element"], "bonus": GameData.sp(sid, "bonus", lv), "t": GameData.sp(sid, "dur", lv)}
			VFX.particles(level, p.global_position + Vector2(0, -12), col, 24, 60.0, 0.7, Vector2(0, -60), "soft", 0.4)
			VFX.ground_ring(level, p.global_position, 30.0, col, 0.5)
			Sfx.play("fire")
		"leap":
			_leap(p, level, sid, lv, target, col, el)
		"shield":
			_shield(p, level, sid, lv, col, el)
		"sky_drop":
			_sky_drop(p, level, sid, lv, target, col, el)
		"projectile":
			_projectile(p, level, sid, lv, aim, col, el)
		"lob":
			_lob(p, level, sid, lv, target, col, el)
		"rain":
			_rain(p, level, sid, lv, target, col, el)
		"place_trap":
			_place_trap(p, level, sid, lv, target)
		"backstep":
			_backstep(p, level, sid, lv, aim, col, el)
		"summon":
			_summon(p, level, sid, lv)
		"beam":
			_beam(p, level, sid, lv, aim, col, el)
		"teleport_strike":
			ok = _teleport_strike(p, level, sid, lv, target, col, el)
		"flurry":
			_flurry(p, level, sid, lv, aim, col, el)
		"smoke":
			_smoke(p, level, sid, lv)
		"multi_blink":
			ok = _multi_blink(p, level, sid, lv, col, el)
		"blink":
			_blink(p, level, sid, lv, target, col, el)
		"nova":
			_nova(p, level, sid, lv, col, el)
		"zone":
			_zone(p, level, sid, lv, target, aim, col, el)
		"channel_beam":
			_channel_beam(p, level, sid, lv, col, el)
		"quake":
			_quake(p, level, sid, lv, col, el)
		"heal":
			_heal(p, level, sid, lv)
		"debuff_area":
			_debuff_area(p, level, sid, lv, target, col, el)
		"drain_beam":
			_drain_beam(p, level, sid, lv, col, el)
		"regen":
			var pct := GameData.sp(sid, "pct", lv)
			var dur := GameData.sp(sid, "dur", lv)
			p.add_buff("second_wind", dur, {"hp_regen": p.max_hp * pct / 100.0 / dur}, col, s["name"])
			VFX.attach_aura(p, Color("7be05a"), 14.0, dur)
			VFX.particles(level, p.global_position + Vector2(0, -10), Color("7be05a"), 20, 50.0, 0.8, Vector2(0, -40), "spark", 0.5)
			Sfx.play("heal")
		_:
			ok = false
	if ok and not echo and s.get("dmg", "none") != "none" and kind not in ["summon", "buff", "enchant", "shield", "smoke", "regen", "heal"]:
		var ech := float(Game.stats.get("echo", 0.0))
		if ech > 0.0 and randf() * 100.0 < ech:
			var tw := level.create_tween()
			tw.tween_interval(0.35)
			tw.tween_callback(func():
				if is_instance_valid(p) and not p.dead:
					level.float_text(p.global_position + Vector2(0, -36), "Echo!", Color("c79bff"), 0.9)
					cast(p, sid, lv, p.mouse_pos(), true))
	_pm = 1.0
	return ok


# ------------------------------------------------------------------ helpers
static func power(sid: String, lv: int) -> float:
	return GameData.skill_power(sid, lv) * _pm


static func status_of(sid: String, lv: int) -> Dictionary:
	var st: Dictionary = GameData.SKILLS[sid].get("status", {})
	if st.is_empty():
		return {}
	var out := st.duplicate()
	out["dur"] = float(st.get("dur", 2.0)) + float(st.get("dur_lv", 0.0)) * (lv - 1)
	if st.has("power"):
		out["power"] = float(st["power"]) + float(st.get("power_lv", 0.0)) * (lv - 1)
	return out


static func opts(sid: String, lv: int, extra: Dictionary = {}) -> Dictionary:
	var o := {"status": status_of(sid, lv), "skill": true}
	o.merge(extra, true)
	return o


static func dmg_type(sid: String) -> String:
	return GameData.SKILLS[sid].get("dmg", "phys")


static func hit_area(p: Player, level, center: Vector2, r: float, sid: String, lv: int, el: String, extra: Dictionary = {}, mult: float = 1.0) -> int:
	var n := 0
	for a in level.actors_in_radius(center, r, "enemy"):
		var o := opts(sid, lv, extra)
		if not o.has("knock_dir"):
			o["knock_dir"] = (a.global_position - center).normalized()
		Combat.hit(p, a, power(sid, lv) * mult, dmg_type(sid), el, o)
		n += 1
	level.hit_props(center, r, p)
	return n


static func _clamp_target(p: Player, target: Vector2, rng: float) -> Vector2:
	var d := target - p.global_position
	if d.length() > rng:
		d = d.normalized() * rng
	return p.global_position + d


static func _cast_flourish(p: Player, level, col: Color, el: String) -> void:
	VFX.particles(level, p.global_position + Vector2(0, -14), col, 8, 40.0, 0.4, Vector2(0, -50), "spark", 0.4)
	VFX.ground_ring(level, p.global_position, 16.0, col, 0.3, 1.5)


# ------------------------------------------------------------------ kinds
static func _slash(p: Player, level, sid: String, lv: int, aim: Vector2, col: Color, el: String) -> void:
	var r := GameData.sp(sid, "radius", lv, 30.0)
	var arc := GameData.sp(sid, "arc", lv, 120.0)
	p._swing(arc, 0.16)
	p.lock(0.18)
	var origin := p.global_position + Vector2(0, -10)
	VFX.slash(level, origin, aim, r, arc, col, 0.26, 6.0)
	VFX.slash(level, origin, aim, r * 0.75, arc * 0.9, Color(1, 1, 1, 0.8), 0.18, 3.0)
	var extra := {"knock": GameData.sp(sid, "knock", lv, 80.0)}
	var pp: Dictionary = GameData.SKILLS[sid]["p"]
	if pp.has("execute"):
		extra["execute"] = GameData.sp(sid, "execute", lv)
	if pp.has("crit_bonus"):
		extra["crit_bonus"] = float(pp["crit_bonus"])
	var hit := false
	for a in level.actors_in_arc(p.global_position, aim, r + 4.0, arc, "enemy"):
		var o := opts(sid, lv, extra)
		o["knock_dir"] = (a.global_position - p.global_position).normalized()
		Combat.hit(p, a, power(sid, lv), dmg_type(sid), el, o)
		VFX.hit_spark(level, a.body_center(), col, true)
		hit = true
	level.hit_props(p.global_position + aim * r * 0.6, r * 0.7, p)
	if pp.get("shockwave", false):
		Projectile.spawn(level, p.global_position + aim * 10.0, aim, {"attacker": p, "team": "player", "speed": 260.0, "range": 130.0,
			"power": power(sid, lv) * 0.5, "dmg": dmg_type(sid), "el": el, "tex": "crescent", "scale": 2.0, "pierce": 99,
			"opts": opts(sid, lv), "color": col, "height": 4.0, "trail": true})
		VFX.particles(level, p.global_position + aim * 20.0, Color("9a7050"), 10, 70.0, 0.4, Vector2(0, 120), "px", 0.5, 60.0)
	if hit:
		level.shake(3.0, 0.15)
		level.hitstop(0.04)
	Sfx.play("crit" if hit else "swing")


static func _dash_strike(p: Player, level, sid: String, lv: int, aim: Vector2, col: Color, el: String) -> void:
	var dist := GameData.sp(sid, "dist", lv, 80.0)
	var width := GameData.sp(sid, "width", lv, 20.0)
	var hits := {}
	var fire_trail: bool = GameData.SKILLS[sid]["p"].get("fire_trail", false)
	var o := opts(sid, lv, {"knock": 150.0, "knock_dir": aim})
	var pw := power(sid, lv)
	var dt := dmg_type(sid)
	var step := func(pos: Vector2):
		for a in level.actors_in_radius(pos, width, "enemy"):
			if hits.has(a.get_instance_id()):
				continue
			hits[a.get_instance_id()] = true
			Combat.hit(p, a, pw, dt, el, o)
			VFX.hit_spark(level, a.body_center(), col, true)
			level.hitstop(0.03)
		if fire_trail and Engine.get_physics_frames() % 3 == 0:
			var z := SkillZone.new()
			z.caster = p
			z.sid = sid
			z.power = pw * 0.12
			z.dmg_type = dt
			z.element = "fire"
			z.radius = 14.0
			z.dur = 2.5
			z.tick = 0.5
			z.position = pos
			level.add_fx(z, "under")
			VFX.particles(level, pos, Color("ff8a3a"), 4, 20.0, 0.6, Vector2(0, -40), "soft", 0.35)
			VFX.zone(level, pos, "disc", 12.0, Color(1, 0.5, 0.2, 0.25), 2.5)
	p.start_skill_dash(aim, dist, 0.2, step)
	Sfx.play("dash")
	if sid == "shield_bash":
		VFX.particles(level, p.global_position + Vector2(0, -10), Color("fff6c8"), 12, 50.0, 0.4, Vector2.ZERO, "spark", 0.5)


static func _buff(p: Player, level, sid: String, lv: int, col: Color, el: String) -> void:
	var s: Dictionary = GameData.SKILLS[sid]
	var pp: Dictionary = s["p"]
	var dur := GameData.sp(sid, "dur", lv)
	var mods := GameData.skill_mods(sid, lv)
	p.add_buff(sid, dur, mods, col, s["name"])
	VFX.attach_aura(p, col, 14.0, dur)
	if pp.has("shield_pct"):
		p.add_shield(p.max_hp * GameData.sp(sid, "shield_pct", lv) / 100.0, dur)
	if pp.get("party", false):
		for a in level.get_team_actors("player"):
			if a != p and a is Ally:
				a.add_buff(sid, dur, mods, col, s["name"])
	if pp.has("nova_radius"):
		var r := float(pp["nova_radius"])
		VFX.ring(level, p.global_position + Vector2(0, -6), r, col, 0.4, 3.0, 6.0)
		VFX.particles(level, p.global_position, col, 24, r * 3.0, 0.5, Vector2(0, -40), "soft", 0.4)
		hit_area(p, level, p.global_position, r, sid, lv, el, {"knock": 100.0})
		level.shake(3.0, 0.2)
		Sfx.play("roar", 0.05, 0.7)
	VFX.pillar(level, p.global_position, 6.0, 60.0, col, 0.5)
	VFX.particles(level, p.global_position + Vector2(0, -10), col, 20, 50.0, 0.8, Vector2(0, -50), "spark", 0.5)
	if el == "dark":
		VFX.disc(level, p.global_position + Vector2(0, -10), 26.0, Color(0.3, 0.0, 0.4, 0.6), 0.5)
		Sfx.play("dark")
	else:
		Sfx.play("buff")


static func _spin(p: Player, level, sid: String, lv: int, col: Color, el: String) -> void:
	var dur := GameData.sp(sid, "dur", lv)
	var tick := GameData.sp(sid, "tick", lv)
	var r := GameData.sp(sid, "radius", lv)
	p.slow_for(GameData.sp(sid, "move_mult", lv), dur)
	p.spin_t = dur
	var n := int(dur / tick)
	var tw = level.create_tween()
	for i in n:
		tw.tween_callback(func():
			if not is_instance_valid(p) or p.dead:
				return
			VFX.slash(level, p.global_position + Vector2(0, -10), Vector2.from_angle(i * 2.4), r, 300.0, col, 0.22, 4.0)
			VFX.particles(level, p.global_position, col, 4, 60.0, 0.3, Vector2.ZERO, "px", 0.4)
			hit_area(p, level, p.global_position, r, sid, lv, el, {"knock": 60.0, "no_flash": false})
			Sfx.play("swing", 0.15, 0.6))
		tw.tween_interval(tick)


static func _line_eruption(p: Player, level, sid: String, lv: int, aim: Vector2, col: Color, el: String) -> void:
	var count := int(GameData.sp(sid, "count", lv))
	var spacing := GameData.sp(sid, "spacing", lv)
	var delay := GameData.sp(sid, "delay", lv)
	var r := GameData.sp(sid, "radius", lv)
	var hits := {}
	var start := p.global_position
	p.lock(0.2)
	level.shake(2.0, 0.15)
	var tw = level.create_tween()
	for i in count:
		tw.tween_interval(delay)
		var pos := start + aim * spacing * (i + 1)
		tw.tween_callback(func():
			if level.ray_blocked(start, pos):
				return
			VFX.spike(level, pos, "spike_rock", 1.2 + 0.05 * i, 0.7)
			VFX.spike(level, pos + aim.orthogonal() * 7.0, "spike_rock", 0.8, 0.6)
			VFX.spike(level, pos - aim.orthogonal() * 7.0, "spike_rock", 0.9, 0.6)
			VFX.ground_ring(level, pos, r, col, 0.3, 1.5)
			Sfx.play("earth", 0.1, 0.5)
			for a in level.actors_in_radius(pos, r, "enemy"):
				if hits.has(a.get_instance_id()):
					continue
				hits[a.get_instance_id()] = true
				Combat.hit(p, a, power(sid, lv), dmg_type(sid), el, opts(sid, lv, {"knock": 60.0, "knock_dir": Vector2.UP}))
				a.vz = 120.0 if not a.is_boss() else 0.0
			level.hit_props(pos, r, p))


static func _leap(p: Player, level, sid: String, lv: int, target: Vector2, col: Color, el: String) -> void:
	var to := _clamp_target(p, target, GameData.sp(sid, "range", lv))
	var r := GameData.sp(sid, "radius", lv)
	var tm := GameData.sp(sid, "time", lv, 0.5)
	VFX.telegraph(level, to, r, col, tm)
	var land := func():
		VFX.element_burst(level, p.global_position, el, r)
		for k in 6:
			VFX.spike(level, p.global_position + Vector2.from_angle(k * TAU / 6.0) * r * 0.6, "spike_rock", 1.0, 0.5)
		hit_area(p, level, p.global_position, r, sid, lv, el, {"knock": 180.0})
		level.shake(6.0, 0.3)
		level.hitstop(0.06)
	p.start_leap(to, tm, GameData.sp(sid, "height", lv, 40.0), land)
	Sfx.play("dash")


static func _shield(p: Player, level, sid: String, lv: int, col: Color, el: String) -> void:
	var amt := p.max_hp * GameData.sp(sid, "pct", lv) / 100.0
	p.add_shield(amt, GameData.sp(sid, "dur", lv))
	var br := GameData.sp(sid, "burst_radius", lv, 60.0)
	p.shield_burst = func():
		VFX.element_burst(level, p.global_position, "water", br)
		VFX.ring(level, p.global_position + Vector2(0, -8), br, col, 0.4, 3.0, 8.0)
		hit_area(p, level, p.global_position, br, sid, lv, el, {"knock": 160.0})
	VFX.particles(level, p.global_position + Vector2(0, -10), col, 20, 50.0, 0.6, Vector2(0, -20), "soft", 0.4)
	Sfx.play("ice")


static func _sky_drop(p: Player, level, sid: String, lv: int, target: Vector2, col: Color, el: String) -> void:
	var pos := _clamp_target(p, target, GameData.sp(sid, "range", lv, 170.0))
	var r := GameData.sp(sid, "radius", lv)
	var delay := GameData.sp(sid, "delay", lv, 0.6)
	var fxname: String = GameData.SKILLS[sid]["p"].get("fx", "meteor")
	VFX.telegraph(level, pos, r, col, delay)
	var pw := power(sid, lv)
	var burn: float = GameData.SKILLS[sid]["p"].get("burn_ground", 0.0)
	var impact := func():
		VFX.element_burst(level, pos, el, r)
		VFX.explosion(level, pos, r * 0.8, col, "")
		for a in level.actors_in_radius(pos, r, "enemy"):
			var o := opts(sid, lv, {"knock": 170.0, "knock_dir": (a.global_position - pos).normalized()})
			Combat.hit(p, a, pw, dmg_type(sid), el, o)
		level.hit_props(pos, r, p)
		level.shake(7.0, 0.35)
		level.hitstop(0.05)
		if burn > 0.0:
			var z := SkillZone.new()
			z.caster = p
			z.power = pw * 0.08
			z.dmg_type = dmg_type(sid)
			z.element = "fire"
			z.radius = r * 0.8
			z.dur = burn
			z.tick = 0.5
			z.position = pos
			level.add_fx(z, "under")
			VFX.zone(level, pos, "disc", r * 0.7, Color(1, 0.4, 0.1, 0.3), burn)
			for k in 6:
				VFX.particles(level, pos + Vector2.from_angle(k) * r * 0.4, Color("ff8a3a"), 6, 20.0, 1.0, Vector2(0, -40), "soft", 0.4)
	match fxname:
		"pillar":
			var tw = level.create_tween()
			tw.tween_interval(delay)
			tw.tween_callback(func():
				VFX.pillar(level, pos, r * 0.35, 220.0, col, 0.6)
				impact.call())
		"holy_sword":
			VFX.sky_object(level, Art.fx("holy_sword"), pos, delay, 200.0, 2.0, impact)
		_:
			VFX.sky_object(level, Art.fx("meteor"), pos, delay, 200.0, 1.6, impact, 0.4)
	Sfx.play("light" if el == "light" else "fire", 0.05, 0.7)


static func _projectile(p: Player, level, sid: String, lv: int, aim: Vector2, col: Color, el: String) -> void:
	var pp: Dictionary = GameData.SKILLS[sid]["p"]
	var count := int(GameData.sp(sid, "count", lv, 1.0))
	if pp.has("count_per5"):
		count += int(pp["count_per5"]) * (lv / 5)
	var spread := deg_to_rad(float(pp.get("spread", 0.0)))
	var tex: String = pp.get("proj", "bolt")
	var extra_opts := {"knock": float(pp.get("knock", 50.0))}
	if pp.has("undead_bonus"):
		extra_opts["undead_bonus"] = float(pp["undead_bonus"])
	var on_imp := Callable()
	if pp.get("fx_burst", "") == "vines":
		on_imp = func(at: Vector2):
			for k in 8:
				VFX.spike(level, at + Vector2.from_angle(k * TAU / 8.0) * 18.0, "spike_rock", 0.7, 2.0)
			VFX.particles(level, at, Color("63c74d"), 16, 50.0, 0.8, Vector2(0, -10), "px", 0.5)
	for i in count:
		var d := aim
		if count > 1:
			if spread >= TAU - 0.01:
				d = aim.rotated(TAU * i / count)
			else:
				d = aim.rotated(-spread * 0.5 + spread * i / (count - 1))
		Projectile.spawn(level, p.global_position + d * 8.0, d, {"attacker": p, "team": "player", "speed": float(pp.get("speed", 300.0)),
			"range": float(pp.get("range", 260.0)), "power": power(sid, lv), "dmg": dmg_type(sid), "el": el,
			"opts": opts(sid, lv, extra_opts), "tex": tex, "pierce": int(pp.get("pierce", 0)), "explode": float(pp.get("explode", 0.0)),
			"homing": float(pp.get("homing", 0.0)), "scale": float(pp.get("scale", 1.0)), "color": col, "trail": true,
			"height": 12.0, "on_impact": on_imp, "spin": 14.0 if tex in ["knife"] and spread >= TAU - 0.01 else 0.0})
	VFX.particles(level, p.global_position + aim * 10.0 + Vector2(0, -12), col, 8, 60.0, 0.3, Vector2.ZERO, "spark", 0.4, 40.0, aim)
	Sfx.play("magic" if dmg_type(sid) != "phys" else "shoot")


static func _lob(p: Player, level, sid: String, lv: int, target: Vector2, col: Color, el: String) -> void:
	var pp: Dictionary = GameData.SKILLS[sid]["p"]
	var to := _clamp_target(p, target, float(pp.get("range", 160.0)))
	var r := float(pp.get("radius", 36.0))
	VFX.telegraph(level, to, r, col, float(pp.get("time", 0.6)))
	Projectile.spawn(level, p.global_position, (to - p.global_position).normalized(), {"attacker": p, "team": "player",
		"power": power(sid, lv), "dmg": dmg_type(sid), "el": el, "opts": opts(sid, lv, {"knock": 150.0}), "tex": pp.get("proj", "rock"),
		"explode": r, "scale": float(pp.get("scale", 1.0)), "lob": float(pp.get("time", 0.6)), "lob_height": float(pp.get("height", 50.0)),
		"target": to, "color": col})
	Sfx.play("earth", 0.1, 0.6)


static func _rain(p: Player, level, sid: String, lv: int, target: Vector2, col: Color, el: String) -> void:
	var center := _clamp_target(p, target, GameData.sp(sid, "range", lv, 180.0))
	var r := GameData.sp(sid, "radius", lv)
	var dur := GameData.sp(sid, "dur", lv)
	var rate := GameData.sp(sid, "rate", lv, 10.0)
	VFX.telegraph(level, center, r, col, 0.4)
	var n := int(dur * rate)
	var tw = level.create_tween()
	tw.tween_interval(0.3)
	for i in n:
		tw.tween_callback(func():
			var off := Vector2.from_angle(randf() * TAU) * sqrt(randf()) * r
			var pos := center + Vector2(off.x, off.y * 0.7)
			VFX.beam(level, pos + Vector2(-14, -90), pos, 1.5, col.lightened(0.3), 0.12)
			VFX.particles(level, pos, col, 3, 30.0, 0.3, Vector2(0, -20), "soft", 0.3)
			for a in level.actors_in_radius(pos, 12.0, "enemy"):
				Combat.hit(p, a, power(sid, lv), dmg_type(sid), el, opts(sid, lv, {"no_flash": true})))
		tw.tween_interval(1.0 / rate)
	Sfx.play("shoot")


static func _place_trap(p: Player, level, sid: String, lv: int, target: Vector2) -> void:
	var traps = level.get_tree().get_nodes_in_group("player_traps")
	var mx := int(GameData.sp(sid, "max", lv, 3.0))
	if traps.size() >= mx:
		traps[0].queue_free()
	var t := PlayerTrap.new()
	t.caster = p
	t.power = power(sid, lv)
	t.radius = GameData.sp(sid, "radius", lv)
	t.life = GameData.sp(sid, "life", lv)
	t.status = status_of(sid, lv)
	t.position = _clamp_target(p, target, 110.0)
	level.add_fx(t, "under")
	VFX.ground_ring(level, t.position, 16.0, Color("8fd3ff"), 0.4)
	Sfx.play("trap")


static func _backstep(p: Player, level, sid: String, lv: int, aim: Vector2, col: Color, el: String) -> void:
	p.start_skill_dash(-aim, GameData.sp(sid, "dist", lv), 0.22, Callable(), 14.0)
	var n := int(GameData.sp(sid, "count", lv))
	var spr := deg_to_rad(GameData.sp(sid, "spread", lv))
	for i in n:
		var d := aim.rotated(-spr * 0.5 + spr * i / maxf(1.0, n - 1))
		Projectile.spawn(level, p.global_position + d * 8.0, d, {"attacker": p, "team": "player", "speed": 380.0, "range": 240.0,
			"power": power(sid, lv), "dmg": dmg_type(sid), "el": el, "opts": opts(sid, lv, {"knock": 70.0}), "tex": "arrow", "color": col,
			"trail": true, "height": 14.0})
	Sfx.play("shoot")


static func _summon(p: Player, level, sid: String, lv: int) -> void:
	var pp: Dictionary = GameData.SKILLS[sid]["p"]
	var count := int(pp.get("count", 1))
	if lv >= int(pp.get("count_at", 99)):
		count += 1
	var kind: String = pp.get("ally", "hawk")
	# dismiss previous summons of the same kind
	for a in level.get_tree().get_nodes_in_group("allies"):
		if a.kind == kind:
			a._vanish()
	for i in count:
		var al := Ally.create(kind, p, power(sid, lv), GameData.sp(sid, "dur", lv))
		al.position = p.global_position + Vector2.from_angle(randf() * TAU) * 16.0
		level.add_entity(al)
	Sfx.play("light" if kind == "angel" else ("dark" if kind == "clone" else "wind"))


static func _beam(p: Player, level, sid: String, lv: int, aim: Vector2, col: Color, el: String) -> void:
	var length := GameData.sp(sid, "length", lv)
	var width := GameData.sp(sid, "width", lv)
	var delay := GameData.sp(sid, "delay", lv, 0.25)
	var start := p.global_position
	VFX.line_telegraph(level, start, aim, length, width, col, delay)
	p.lock(delay + 0.1)
	var tw = level.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func():
		var from := start + Vector2(0, -12)
		VFX.beam(level, from, from + aim * length, width, col, 0.45)
		VFX.particles(level, from, col, 20, 120.0, 0.4, Vector2.ZERO, "spark", 0.6, 30.0, aim)
		for a in level.actors_in_line(start, aim, length, width * 0.5, "enemy"):
			Combat.hit(p, a, power(sid, lv), dmg_type(sid), el, opts(sid, lv, {"knock": 120.0, "knock_dir": aim}))
			VFX.hit_spark(level, a.body_center(), col, true)
		level.shake(4.0, 0.2)
		Sfx.play("light"))


static func _teleport_strike(p: Player, level, sid: String, lv: int, target: Vector2, col: Color, el: String) -> bool:
	var rng := GameData.sp(sid, "range", lv)
	var best: Actor = null
	var bd := 1e9
	for a in level.actors_in_radius(p.global_position, rng, "enemy"):
		var d = a.global_position.distance_to(target)
		if d < bd:
			bd = d
			best = a
	VFX.particles(level, p.global_position + Vector2(0, -10), Color("a66bff"), 16, 60.0, 0.5, Vector2.ZERO, "soft", 0.4)
	VFX.afterimage(p, Color(0.5, 0.3, 0.8, 0.7), 0.4)
	if best == null:
		var to := _clamp_target(p, target, rng * 0.6)
		if level.is_walkable(to):
			p.global_position = to
		return true
	var dir := (best.global_position - p.global_position).normalized()
	var dest := best.global_position + dir * (best.radius + 10.0)
	if not level.is_walkable(dest):
		dest = best.global_position - dir * (best.radius + 10.0)
	p.global_position = dest
	p.aim = -dir
	p.invuln_t = maxf(p.invuln_t, 0.3)
	VFX.particles(level, p.global_position + Vector2(0, -10), Color("a66bff"), 16, 60.0, 0.5, Vector2.ZERO, "soft", 0.4)
	VFX.slash(level, p.global_position + Vector2(0, -10), -dir, 26.0, 140.0, col, 0.22, 5.0)
	Combat.hit(p, best, power(sid, lv), dmg_type(sid), el, opts(sid, lv, {"knock": 80.0, "knock_dir": -dir, "crit_bonus": 20.0}))
	VFX.hit_spark(level, best.body_center(), col, true)
	level.hitstop(0.05)
	Sfx.play("dark")
	return true


static func _flurry(p: Player, level, sid: String, lv: int, aim: Vector2, col: Color, el: String) -> void:
	var pp: Dictionary = GameData.SKILLS[sid]["p"]
	var hits_n := int(pp.get("hits", 6)) + int(pp.get("hits_per5", 0)) * (lv / 5)
	var interval := float(pp.get("interval", 0.06))
	var r := float(pp.get("radius", 30.0))
	var arc := float(pp.get("arc", 80.0))
	p.lock(hits_n * interval + 0.05)
	var tw = level.create_tween()
	for i in hits_n:
		tw.tween_callback(func():
			if not is_instance_valid(p) or p.dead:
				return
			var a2 := p.aim.rotated(randf_range(-0.4, 0.4))
			VFX.slash(level, p.global_position + Vector2(0, -10), a2, r * randf_range(0.7, 1.0), 50.0, col if i % 2 else Color.WHITE, 0.12, 2.5)
			p._swing(70.0, interval)
			for a in level.actors_in_arc(p.global_position, p.aim, r + 4.0, arc, "enemy"):
				Combat.hit(p, a, power(sid, lv), dmg_type(sid), el, opts(sid, lv, {"knock": 25.0, "no_flash": i % 2 == 1}))
			Sfx.play("swing", 0.2, 0.5))
		tw.tween_interval(interval)


static func _smoke(p: Player, level, sid: String, lv: int) -> void:
	var r := GameData.sp(sid, "radius", lv)
	var dur := GameData.sp(sid, "dur", lv)
	p.invisible_t = GameData.sp(sid, "stealth", lv)
	for i in 6:
		VFX.particles(level, p.global_position + Vector2.from_angle(i) * r * 0.4, Color(0.55, 0.55, 0.6, 0.8), 12, r * 0.8, dur * 0.6, Vector2(0, -6), "smoke", 2.2)
	VFX.zone(level, p.global_position, "disc", r, Color(0.4, 0.4, 0.45, 0.35), dur)
	for a in level.actors_in_radius(p.global_position, r, "enemy"):
		a.apply_status("blind", float(status_of(sid, lv).get("dur", 3.0)), 0.0, p)
		if a is Monster:
			a.target = null
	Sfx.play("wind")


static func _multi_blink(p: Player, level, sid: String, lv: int, col: Color, el: String) -> bool:
	var pp: Dictionary = GameData.SKILLS[sid]["p"]
	var n := int(pp.get("targets", 5)) + int(pp.get("targets_per4", 0)) * (lv / 4)
	var rng := float(pp.get("range", 200.0))
	var interval := float(pp.get("interval", 0.12))
	var cands: Array = level.actors_in_radius(p.global_position, rng, "enemy")
	if cands.is_empty():
		return false
	cands.sort_custom(func(a, b): return a.global_position.distance_to(p.global_position) < b.global_position.distance_to(p.global_position))
	var seq := []
	for i in n:
		seq.append(cands[i % cands.size()])
	p.invuln_t = maxf(p.invuln_t, seq.size() * interval + 0.3)
	p.lock(seq.size() * interval + 0.1)
	var tw = level.create_tween()
	for t in seq:
		tw.tween_callback(func():
			if not is_instance_valid(t) or t.dead or not is_instance_valid(p):
				return
			VFX.afterimage(p, Color(1, 0.9, 0.7, 0.6), 0.4)
			var off = Vector2.from_angle(randf() * TAU) * (t.radius + 10.0)
			if level.is_walkable(t.global_position + off):
				p.global_position = t.global_position + off
			var d: Vector2 = (t.global_position - p.global_position).normalized()
			VFX.slash(level, p.global_position + Vector2(0, -10), d, 26.0, 160.0, col, 0.2, 4.0)
			VFX.particles(level, t.body_center(), Color("ffd6e8"), 10, 60.0, 0.6, Vector2(0, 30), "soft", 0.35)
			Combat.hit(p, t, power(sid, lv), dmg_type(sid), el, opts(sid, lv, {"knock": 40.0}))
			Sfx.play("crit", 0.2, 0.6))
		tw.tween_interval(interval)
	return true


static func _blink(p: Player, level, sid: String, lv: int, target: Vector2, col: Color, el: String) -> void:
	var start := p.global_position
	var dest := _clamp_target(p, target, GameData.sp(sid, "range", lv))
	var dir := (dest - start).normalized()
	var tries := 0
	while not level.is_walkable(dest) and tries < 12:
		dest -= dir * 8.0
		tries += 1
	VFX.afterimage(p, Color(0.6, 1.0, 0.85, 0.7), 0.4)
	var r := GameData.sp(sid, "radius", lv)
	VFX.element_burst(level, start, "wind", r)
	hit_area(p, level, start, r, sid, lv, el, {"knock": 120.0})
	p.global_position = dest
	p.invuln_t = maxf(p.invuln_t, 0.2)
	VFX.particles(level, dest + Vector2(0, -10), col, 16, 60.0, 0.4, Vector2.ZERO, "spark", 0.5)
	VFX.beam(level, start + Vector2(0, -10), dest + Vector2(0, -10), 2.0, col, 0.25)


static func _nova(p: Player, level, sid: String, lv: int, col: Color, el: String) -> void:
	var r := GameData.sp(sid, "radius", lv)
	VFX.ring(level, p.global_position + Vector2(0, -6), r, col, 0.45, 3.0, 6.0)
	VFX.ground_ring(level, p.global_position, r, col, 0.5, 2.0)
	VFX.element_burst(level, p.global_position, el, r * 0.6)
	if el == "water":
		for k in 10:
			VFX.spike(level, p.global_position + Vector2.from_angle(k * TAU / 10.0) * r * 0.7, "ice_spike", 0.9, 0.9)
	hit_area(p, level, p.global_position, r, sid, lv, el, {"knock": 130.0})
	var sh := float(GameData.SKILLS[sid]["p"].get("self_heal", 0.0))
	if sh > 0.0:
		p.heal(p.max_hp * sh / 100.0)
	level.shake(3.0, 0.2)


static func _zone(p: Player, level, sid: String, lv: int, target: Vector2, aim: Vector2, col: Color, el: String) -> void:
	var pp: Dictionary = GameData.SKILLS[sid]["p"]
	var z := SkillZone.new()
	z.caster = p
	z.sid = sid
	z.lvl = lv
	z.power = power(sid, lv)
	z.dmg_type = dmg_type(sid)
	z.element = el
	z.radius = float(pp.get("radius", 50.0))
	z.dur = float(pp.get("dur", 3.0))
	z.tick = float(pp.get("tick", 0.25))
	z.pull = float(pp.get("pull", 0.0))
	z.heal_pct = GameData.sp(sid, "heal_pct", lv) if pp.has("heal_pct") else 0.0
	z.cleanse = pp.get("cleanse", false)
	z.status = status_of(sid, lv)
	if pp.has("finale"):
		z.finale = GameData.sp(sid, "finale", lv) * _pm
	var pos := p.global_position
	if pp.has("moving"):
		z.move_vel = aim * float(pp["moving"])
		pos = p.global_position + aim * 16.0
	elif pp.has("range"):
		pos = _clamp_target(p, target, float(pp["range"]))
	z.position = pos
	level.add_fx(z, "under")
	var fxk: String = pp.get("fx", "swirl")
	var f := VFX.zone(level, pos, fxk, z.radius, col, z.dur)
	z.fx = f
	Sfx.play({"tornado": "wind", "vortex": "dark", "sanctuary": "light", "rain": "ice"}.get(fxk, "magic"))


static func _channel_beam(p: Player, level, sid: String, lv: int, col: Color, el: String) -> void:
	var dur := GameData.sp(sid, "dur", lv)
	var tick := GameData.sp(sid, "tick", lv)
	var length := GameData.sp(sid, "length", lv)
	var width := GameData.sp(sid, "width", lv)
	p.slow_for(0.25, dur)
	var n := int(dur / tick)
	var tw = level.create_tween()
	var hue := [0.0]
	for i in n:
		tw.tween_callback(func():
			if not is_instance_valid(p) or p.dead:
				return
			var from := p.global_position + Vector2(0, -12)
			var dir := p.aim
			hue[0] = fmod(hue[0] + 0.07, 1.0)
			var c := Color.from_hsv(hue[0], 0.35, 1.0)
			VFX.beam(level, from, from + dir * length, width, c, tick * 1.6)
			VFX.particles(level, from + dir * length, c, 3, 50.0, 0.2, Vector2.ZERO, "spark", 0.4)
			for a in level.actors_in_line(p.global_position, dir, length, width * 0.5 + 2.0, "enemy"):
				Combat.hit(p, a, power(sid, lv), dmg_type(sid), el, opts(sid, lv, {"no_flash": true}))
			if i % 3 == 0:
				Sfx.play("light", 0.1, 0.3))
		tw.tween_interval(tick)


static func _quake(p: Player, level, sid: String, lv: int, col: Color, el: String) -> void:
	var dur := GameData.sp(sid, "dur", lv)
	var count := int(GameData.sp(sid, "count", lv))
	var r := GameData.sp(sid, "radius", lv)
	var area := GameData.sp(sid, "area", lv)
	p.lock(0.3)
	var tw = level.create_tween()
	for i in count:
		tw.tween_interval(dur / count)
		tw.tween_callback(func():
			if not is_instance_valid(p):
				return
			var pos := p.global_position + Vector2.from_angle(randf() * TAU) * randf_range(20.0, area)
			var near = level.nearest_actor(p.global_position, area, "enemy")
			if near and randf() < 0.5:
				pos = near.global_position
			VFX.telegraph(level, pos, r, col, 0.25)
			var tw2 = level.create_tween()
			tw2.tween_interval(0.25)
			tw2.tween_callback(func():
				VFX.element_burst(level, pos, "earth", r)
				for k in 4:
					VFX.spike(level, pos + Vector2.from_angle(k * TAU / 4.0 + 0.4) * r * 0.5, "spike_rock", 1.2, 0.6)
				VFX.spike(level, pos, "spike_rock", 1.6, 0.7)
				hit_area(p, level, pos, r, sid, lv, el, {"knock": 90.0})))
	level.shake(2.0, dur)


static func _heal(p: Player, level, sid: String, lv: int) -> void:
	var pct := GameData.sp(sid, "pct", lv)
	var amt := (p.max_hp * pct / 100.0 + float(Game.stats.get("matk", 0.0)) * power(sid, lv) / 100.0) * (1.0 + float(Game.stats.get("heal_pct", 0.0)) / 100.0)
	var r := GameData.sp(sid, "radius", lv, 80.0)
	for a in level.actors_in_radius(p.global_position, r, "player"):
		a.heal(amt if a == p else amt * 0.6)
		VFX.pillar(level, a.global_position, 6.0, 70.0, Color("7be05a"), 0.6)
		VFX.particles(level, a.global_position + Vector2(0, -10), Color("b8ffb0"), 18, 40.0, 0.9, Vector2(0, -40), "spark", 0.6)
	VFX.ground_ring(level, p.global_position, r * 0.5, Color("7be05a"), 0.5)
	Sfx.play("heal")


static func _debuff_area(p: Player, level, sid: String, lv: int, target: Vector2, col: Color, el: String) -> void:
	var pos := _clamp_target(p, target, GameData.sp(sid, "range", lv, 160.0))
	var r := GameData.sp(sid, "radius", lv)
	var dur := GameData.sp(sid, "dur", lv) * (1.0 + float(Game.stats.get("debuff_pct", 0.0)) / 100.0)
	var mods := GameData.skill_mods(sid, lv)
	var hex := 1.0 + float(Game.stats.get("debuff_pct", 0.0)) / 100.0
	for k in mods:
		mods[k] = float(mods[k]) * hex
	VFX.zone(level, pos, "vortex", r, col, 0.8)
	VFX.particles(level, pos, col, 26, 40.0, 1.2, Vector2(0, -30), "soft", 0.5)
	for a in level.actors_in_radius(pos, r, "enemy"):
		a.add_buff("curse_area", dur, mods, col, "Cursed")
		a.apply_status("curse", dur, 0.0, p)
		Combat.hit(p, a, power(sid, lv), dmg_type(sid), el, {"skill": true})
	Sfx.play("dark")


static func _drain_beam(p: Player, level, sid: String, lv: int, col: Color, el: String) -> void:
	var dur := GameData.sp(sid, "dur", lv)
	var tick := GameData.sp(sid, "tick", lv)
	var rng := GameData.sp(sid, "range", lv)
	var heal_pct := GameData.sp(sid, "heal", lv)
	var maxt := int(GameData.sp(sid, "targets", lv, 3.0))
	p.slow_for(0.4, dur)
	var tw = level.create_tween()
	for i in int(dur / tick):
		tw.tween_callback(func():
			if not is_instance_valid(p) or p.dead:
				return
			var cands: Array = level.actors_in_radius(p.global_position, rng, "enemy")
			cands.sort_custom(func(a, b): return a.global_position.distance_to(p.global_position) < b.global_position.distance_to(p.global_position))
			for k in mini(maxt, cands.size()):
				var t: Actor = cands[k]
				var dealt := Combat.hit(p, t, power(sid, lv), dmg_type(sid), el, {"no_flash": true, "skill": true})
				p.heal(dealt * heal_pct / 100.0 * (1.0 + float(Game.stats.get("heal_pct", 0.0)) / 100.0), false)
				VFX.beam(level, t.body_center(), p.body_center(), 2.5, Color("c0304a"), tick * 1.5)
				VFX.particles(level, t.body_center(), Color("e43b44"), 3, 30.0, 0.3, Vector2.ZERO, "soft", 0.3)
			if i % 3 == 0:
				Sfx.play("dark", 0.1, 0.3))
		tw.tween_interval(tick)
