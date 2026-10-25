class_name Combat
extends RefCounted
## Damage formulas shared by every attack in the game.


static func attack_value(st: Dictionary, dmg_type: String) -> float:
	match dmg_type:
		"magic":
			return float(st.get("matk", 0.0))
		"hybrid":
			return maxf(float(st.get("patk", 0.0)), float(st.get("matk", 0.0)))
	return float(st.get("patk", 0.0))


## Deal damage from attacker (may be null for traps -> use opts.raw) to target.
## Returns damage actually dealt.
static func hit(attacker: Actor, target: Actor, power_pct: float, dmg_type: String, element: String, opts: Dictionary = {}) -> int:
	if target == null or not is_instance_valid(target) or target.dead:
		return 0
	if target.is_invulnerable() and not opts.get("ignore_invuln", false):
		return 0
	if not is_instance_valid(attacker):
		attacker = null
	var ast: Dictionary = attacker.get_stats() if attacker else opts.get("ast", {})
	var raw: float
	if opts.has("raw"):
		raw = float(opts["raw"]) * power_pct / 100.0
	else:
		raw = attack_value(ast, dmg_type) * power_pct / 100.0
	if attacker and is_instance_valid(attacker):
		raw *= attacker.damage_out_mult()
		if attacker.has_status("curse"):
			raw *= 0.8
	var is_magic := dmg_type == "magic" or (dmg_type == "hybrid" and float(ast.get("matk", 0)) > float(ast.get("patk", 0)))
	var def: float = target.get_stat("mdef" if is_magic else "pdef")
	if target.has_status("shred"):
		def *= 0.8
	var dmg := raw * raw / maxf(1.0, raw + def) if raw > 0.0 else 0.0
	# elements
	if target.is_player_team():
		if element in GameData.WorldData.ELEMENTS:
			dmg *= 1.0 - float(target.get_stats().get("res_" + element, 0.0)) / 100.0
	else:
		dmg *= GameData.element_mult(element, target.element)
	if element in GameData.WorldData.ELEMENTS:
		dmg *= 1.0 + float(ast.get("dmg_" + element, 0.0)) / 100.0
	if target.has_status("judged"):
		dmg *= 1.15
	if float(ast.get("opportunist", 0.0)) > 0.0 and target.has_any_debuff():
		dmg *= 1.0 + float(ast["opportunist"]) / 100.0
	if float(ast.get("range_bonus", 0.0)) > 0.0 and float(opts.get("dist", 0.0)) > 80.0:
		dmg *= 1.0 + float(ast["range_bonus"]) / 100.0
	if target.undead:
		dmg *= 1.0 + (float(ast.get("undead_dmg", 0.0)) + float(opts.get("undead_bonus", 0.0))) / 100.0
	if opts.has("mult"):
		dmg *= float(opts["mult"])
	# critical
	var crit := false
	if not opts.get("no_crit", false) and not ast.is_empty():
		var cc := float(ast.get("crit", 0.0)) + float(opts.get("crit_bonus", 0.0))
		if is_magic:
			cc += float(ast.get("crit_mag", 0.0))
		if randf() * 100.0 < cc:
			crit = true
			dmg *= float(ast.get("crit_dmg", 150.0)) / 100.0
	dmg *= randf_range(0.92, 1.08)
	var final := maxi(1, int(round(dmg)))
	# execute
	if opts.has("execute") and not target.is_boss() and target.hp - final <= target.max_hp * float(opts["execute"]) / 100.0:
		final = maxi(final, int(ceil(target.hp)))
	var info := {"crit": crit, "el": element, "src": attacker, "type": dmg_type, "skill": opts.get("skill", false),
		"knock": float(opts.get("knock", 0.0)), "knock_dir": opts.get("knock_dir", Vector2.ZERO), "basic": opts.get("basic", false),
		"no_flash": opts.get("no_flash", false)}
	var dealt := target.take_damage(final, info)
	if dealt <= 0:
		return 0
	# on-hit effects for the attacker
	if attacker and is_instance_valid(attacker):
		attacker.on_dealt_damage(target, dealt, info)
	# statuses
	var st: Dictionary = opts.get("status", {})
	if not st.is_empty() and not target.dead:
		var ch := float(st.get("chance", 100.0))
		if randf() * 100.0 < ch:
			var dur := float(st.get("dur", 2.0))
			if not ast.is_empty():
				dur *= 1.0 + float(ast.get("debuff_pct", 0.0)) / 200.0
			var pw := float(st.get("power", 0.0))
			if st["id"] in ["burn", "poison"]:
				pw = maxf(pw, 20.0) / 100.0 * float(dealt)
				if st["id"] == "burn":
					pw *= 1.0 + float(ast.get("burn_pct", 0.0)) / 100.0
			target.apply_status(st["id"], dur, pw, attacker)
	return dealt


## Rough damage a monster attack does (for traps/skills using raw attack numbers)
static func monster_raw_atk(level: int, mult: float = 1.0) -> float:
	return GameData.mon_atk(level) * mult
