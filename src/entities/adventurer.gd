class_name Adventurer
extends Player
## An NPC adventurer in the world. It is the same character code as the hero — same class sprites,
## stats, gear, skill tree and skill animations — but an AI brain replaces mouse and keyboard.
##
## The brain follows the NPC's schedule from NpcWorld (town / travel / hunt / return) and in combat:
## picks targets, keeps its preferred range (melee closes in, casters and archers kite), casts its
## equipped skills when they fit the situation, dodges telegraphed attacks with its dash, drinks
## potions and flees when it is in trouble.

const SKILL_RANGE := {
	"slash": 46.0, "flurry": 40.0, "spin": 44.0, "nova": 60.0, "quake": 90.0, "dash_strike": 90.0, "line_eruption": 130.0,
	"leap": 120.0, "projectile": 220.0, "beam": 220.0, "channel_beam": 200.0, "lob": 165.0, "drain_beam": 150.0,
	"sky_drop": 170.0, "rain": 170.0, "zone": 160.0, "debuff_area": 160.0, "place_trap": 110.0, "teleport_strike": 145.0,
	"multi_blink": 180.0,
}
const SUPPORT := ["buff", "enchant", "shield", "summon", "regen", "heal", "smoke", "blink", "backstep"]

var foe: Actor = null
var aim_point := Vector2.ZERO
var want_skill := ""
var want_dash := false
var think_t := 0.0
var potion_cd := 0.0
var wander_to := Vector2.INF
var idle_t := 0.0
var stuck_t := 0.0
var side_t := 0.0
var side_dir := Vector2.ZERO
var _last_pos := Vector2.ZERO
var _sync_t := 0.0
var _goal := Vector2.INF
var name_tag: Node2D
var interact_radius := 26.0
var ranged := false
var atk_range := 30.0
var _dodge_seen: Dictionary = {}
## "routine" (own schedule), "follow" (party member: follows `leader` and fights beside it),
## "run" (leads a dungeon run room by room, e.g. a spectated test run) or "duel" (fights `foe`).
var mode := "routine"
var leader: Player = null
var _tp_cd := 0.0
var _prog_d := INF  # closest distance to the current goal recently reached
var _prog_t := 0.0
var _prog_goal := Vector2.INF


## Chance to dash out of a telegraphed attack: 25-55% by personality, +15% at level 100,
## +10% for the nimble classes.
func reflex() -> float:
	var base := 0.25 + float((int(npc.get("id", 0)) * 53) % 31) / 100.0
	base += 0.15 * float(npc.get("level", 1)) / 100.0
	if cls in ["ranger", "assassin"]:
		base += 0.1
	return clampf(base, 0.2, 0.8)


func _ready() -> void:
	super._ready()
	_mat.set_shader_parameter("hue_shift", NpcWorld.hue_of(npc))
	add_to_group("interactable")
	ranged = cls in ["ranger", "mage", "priest"]
	_refresh_range()
	_make_tag()
	_last_pos = global_position
	aim_point = global_position + Vector2(20, 0)


func _make_tag() -> void:
	if name_tag and is_instance_valid(name_tag):
		name_tag.queue_free()
	# party members' names show in the party colour
	var col: Color = Color("7be0ff") if Social.in_party(npc) else GameData.CLASSES[cls]["color"].lightened(0.25)
	name_tag = WorldText.make("%s  Lv%d" % [display_name, int(npc["level"])], 4.5, col)
	name_tag.position = Vector2(0, -36)
	add_child(name_tag)


func _refresh_range() -> void:
	var w := StatCalc.weapon_type(npc)
	var atk: Dictionary = GameData.ItemData.GEAR.get(w, {}).get("attack", {"style": "melee", "radius": 22})
	if atk.get("style", "melee") == "proj":
		atk_range = float(atk.get("range", 220)) * 0.8
		ranged = true
	else:
		atk_range = float(atk.get("radius", 24)) + 2.0


func mouse_pos() -> Vector2:
	return aim_point


func interact(_p) -> void:
	Sfx.play("click")
	if Game.main:
		Game.main.open_npc_profile(int(npc["id"]))


func on_npc_level_up() -> void:
	recalc_stats()
	_refresh_max()
	hp = max_hp
	mp = max_mp
	_make_tag()
	var lv = level_node()
	if lv:
		VFX.pillar(lv, global_position, 6.0, 70.0, Color("fee761"), 0.7)
		lv.float_text(global_position + Vector2(0, -44), "Level up!", Color("fee761"), 1.0)


func on_npc_gear_changed() -> void:
	recalc_stats()
	on_equipment_changed()
	_refresh_range()


func heal(amount: float, _show: bool = true) -> void:
	super.heal(amount, false)


func _show_damage(final: int, info: Dictionary) -> void:
	if not Settings.damage_numbers or not level_node():
		return
	level_node().damage_number(global_position + Vector2(randf_range(-5, 5), -body_height - z), final, Color(1.0, 0.6, 0.45, 0.85), false, 0.7)


func _on_death_finished() -> void:
	if Game.test_run:
		return  # test runs change nothing (the record is restored afterwards)
	NpcWorld.on_actor_died(npc)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)


func basic_attack() -> void:
	Sfx.volume_scale = 0.3
	super.basic_attack()
	Sfx.volume_scale = 1.0


func try_cast(sid: String) -> bool:
	Sfx.volume_scale = 0.35
	var ok := super.try_cast(sid)
	Sfx.volume_scale = 1.0
	return ok


func try_dash() -> void:
	Sfx.volume_scale = 0.3
	super.try_dash()
	Sfx.volume_scale = 1.0


# ===================================================================== brain
func _control(delta: float) -> void:
	_sync_t -= delta
	if _sync_t <= 0.0:
		_sync_t = 0.25
		if level_node() is Overworld:
			npc["pos"] = [global_position.x, global_position.y]
		npc["hp_frac"] = hp / maxf(1.0, max_hp)
		npc["mp_frac"] = mp / maxf(1.0, max_mp)
	potion_cd -= delta
	think_t -= delta
	if think_t <= 0.0:
		think_t = 0.12 + randf() * 0.06
		_think()
	_tp_cd -= delta
	move_dir = Vector2.ZERO
	if lock_t <= 0.0 and can_move() and _goal != Vector2.INF:
		var to := _goal - global_position
		if to.length() > 6.0:
			var lv = level_node()
			# dungeons: walk around walls along the room/corridor grid
			move_dir = lv.path_dir(self, _goal) if lv is DungeonLevel else to.normalized()
	_unstick(delta)
	aim = (aim_point - (global_position + Vector2(0, -10))).normalized()
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT


func _unstick(delta: float) -> void:
	_check_progress(delta)
	side_t -= delta
	if move_dir == Vector2.ZERO:
		stuck_t = 0.0
		_last_pos = global_position
		return
	if global_position.distance_to(_last_pos) < 0.25 * float(st.get("move", 85.0)) * delta:
		stuck_t += delta
		if stuck_t > 0.4 and side_t <= 0.0:
			side_t = 0.6
			side_dir = move_dir.orthogonal() * (1.0 if randf() < 0.5 else -1.0)
		if stuck_t > 5.0:
			# hopelessly blocked: hop a little toward the goal if there is floor there
			var hop := global_position + move_dir * 28.0
			var lv = level_node()
			if lv and lv.is_walkable(hop):
				global_position = hop
			stuck_t = 0.0
	else:
		stuck_t = maxf(0.0, stuck_t - delta)
	_last_pos = global_position
	if side_t > 0.0:
		move_dir = (move_dir * 0.3 + side_dir).normalized()


## Walking somewhere (not chasing a foe) without getting any closer for a few seconds means something small
## blocks the way head-on (a lamp post right on the route, a crowd at a gate): step around it.
func _check_progress(delta: float) -> void:
	if move_dir == Vector2.ZERO or _goal == Vector2.INF or foe != null:
		_prog_t = 0.0
		_prog_d = INF
		return
	if _prog_goal == Vector2.INF or _goal.distance_to(_prog_goal) > 24.0:
		_prog_goal = _goal
		_prog_d = INF
		_prog_t = 0.0
	var d := global_position.distance_to(_goal)
	if d < _prog_d - 6.0:
		_prog_d = d
		_prog_t = 0.0
		return
	_prog_t += delta
	if _prog_t < 2.0:
		return
	_prog_t = 0.0
	_prog_d = INF
	var lv = level_node()
	if lv == null:
		return
	var side := move_dir.orthogonal() * (1.0 if int(npc.get("id", 0)) % 2 == 0 else -1.0)
	for off in [(move_dir + side).normalized() * 22.0, (move_dir - side).normalized() * 22.0, side * 20.0, -side * 20.0, move_dir * 26.0]:
		if lv.is_walkable(global_position + off) and lv.is_walkable(global_position + off * 0.5):
			global_position += off
			return


func _foe_valid(f) -> bool:
	if f == null or not is_instance_valid(f) or f.dead or f.global_position.distance_to(global_position) >= 320.0:
		return false
	return not _claimed_by_other(f)


## Good manners: a monster someone else is already fighting (tagged by the hero or another
## adventurer, or chasing the hero) is left to them — unless it is attacking us.
func _claimed_by_other(e) -> bool:
	if not (e is Monster) or e.target == self:
		return false
	var o = e.tag_owner()
	if o != null and o != self and not Social.same_party(o, self):
		return true
	return e.target != null and is_instance_valid(e.target) and e.target is Player and e.target != self \
		and not Social.same_party(e.target, self)


func _nearest_foe(r: float) -> Actor:
	var lv = level_node()
	if lv == null:
		return null
	var best: Actor = null
	var bd := r
	for e in lv.get_team_actors(foe_team()):
		if e.dead or not (e is Monster) or e.dormant:
			continue
		if _claimed_by_other(e):
			continue
		var d: float = e.global_position.distance_to(global_position)
		var threat: bool = e.target == self
		if e.data.get("passive", false) and not threat:
			d += 120.0  # critters only when nothing better is around
		if threat:
			d *= 0.5
		if d < bd:
			bd = d
			best = e
	return best


func _drink_if_needed(hpf: float) -> void:
	if mode == "duel":
		return  # no potions in a duel
	if hpf < 0.4 and potion_cd <= 0.0:
		var pt := NpcWorld.drink(npc)
		if not pt.is_empty():
			potion_cd = 2.5
			Sfx.volume_scale = 0.3
			consume(pt, "pot_hp")
			Sfx.volume_scale = 1.0
	if mp < max_mp * 0.2 and potion_cd <= 0.0 and ranged:
		var pm := NpcWorld.drink(npc, true)
		if not pm.is_empty():
			potion_cd = 2.5
			consume(pm, "pot_mp")


func _think() -> void:
	var state: String = npc.get("state", "town")
	var lv = level_node()
	if lv == null:
		return
	var in_town := NpcWorld.in_town_px(global_position) if lv is Overworld else false
	attack_held = false
	want_skill = ""
	var hpf := hp / maxf(1.0, max_hp)
	_drink_if_needed(hpf)
	match mode:
		"duel":
			_think_duel(hpf)
			return
		"follow":
			_think_follow(hpf)
			return
		"run":
			_think_run(hpf)
			return
	# who to fight
	if not _foe_valid(foe):
		foe = null
	if foe == null and not in_town:
		var r := 240.0 if state == "hunt" else (110.0 if state == "travel" else 70.0)
		foe = _nearest_foe(r)
	if foe:
		_fight(hpf)
		return
	# a pending duel challenge: walk up to the hero and wait for an answer
	if _challenge_pending():
		var hero = Game.player_node
		if global_position.distance_to(hero.global_position) > 44.0:
			_goal = hero.global_position + (global_position - hero.global_position).normalized() * 36.0
		else:
			_goal = Vector2.INF
		aim_point = hero.global_position
		return
	# no fight: follow the schedule
	match state:
		"travel", "return":
			var dest := Vector2(npc["dest"][0], npc["dest"][1])
			if global_position.distance_to(dest) < 22.0:
				NpcWorld.arrive(npc)
				_goal = Vector2.INF
			else:
				_goal = NpcWorld.route_point(global_position, dest)
		"hunt":
			var c := Vector2(npc["dest"][0], npc["dest"][1])
			_wander_around(c, 140.0)
		"town":
			_town_stroll()
		_:
			_goal = NpcWorld.guild_door()
	if _goal != Vector2.INF:
		aim_point = global_position + (_goal - global_position).normalized() * 30.0


var _mark: Node2D = null


func _challenge_pending() -> bool:
	var c: Dictionary = npc.get("challenge", {})
	var on := not c.is_empty()
	if on and (float(Game.world.get("total", 0.0)) > float(c.get("until", 0.0)) or Duel.active or npc["state"] != "town"):
		npc.erase("challenge")
		on = false
	var hero = Game.player_node
	if on and (hero == null or not is_instance_valid(hero) or hero.dead):
		on = false
	if on and (_mark == null or not is_instance_valid(_mark)):
		_mark = WorldText.make("!", 9.0, Color("fee761"))
		_mark.position = Vector2(0, -46)
		add_child(_mark)
	elif not on and _mark != null and is_instance_valid(_mark):
		_mark.queue_free()
		_mark = null
	return on


# ------------------------------------------------------------------ party member
## Party members stay close to their leader, fight what threatens the group and teleport back to the
## leader if they get separated (e.g. after the leader teleports or enters a dungeon).
func _think_follow(hpf: float) -> void:
	if leader == null or not is_instance_valid(leader) or leader.dead:
		_goal = Vector2.INF
		if leader != null and is_instance_valid(leader) and leader.dead:
			return  # wait by the fallen leader
		mode = "routine"
		return
	var dl := global_position.distance_to(leader.global_position)
	if dl > 420.0 and _tp_cd <= 0.0 and not in_air_skill:
		_tp_cd = 2.0
		var lv = level_node()
		var spot: Vector2 = lv.snap_walkable(leader.global_position + _formation_offset() * 1.3)
		VFX.particles(lv, global_position + Vector2(0, -10), Color("8fd3ff"), 14, 50.0, 0.5, Vector2(0, -40), "spark", 0.5)
		global_position = spot
		VFX.pillar(lv, spot, 5.0, 60.0, Color("8fd3ff"), 0.4)
		foe = null
		return
	if Duel.is_duelist(leader):
		# the leader is duelling: stand outside the ring and watch
		foe = null
		var out := Duel.center + (global_position - Duel.center).normalized() * (Duel.RING + 26.0)
		_goal = out if global_position.distance_to(Duel.center) < Duel.RING + 14.0 else Vector2.INF
		aim_point = leader.global_position
		return
	if foe != null and (not _foe_valid(foe) or foe.global_position.distance_to(leader.global_position) > 260.0):
		foe = null
	if foe == null:
		foe = _group_foe(leader.global_position, 190.0)
	if foe != null and dl < 300.0:
		_fight(hpf)
		return
	var want := leader.global_position + _formation_offset()
	_goal = want if global_position.distance_to(want) > 22.0 else Vector2.INF
	aim_point = leader.global_position + leader.aim * 60.0 if _goal == Vector2.INF else global_position + (want - global_position).normalized() * 30.0


## A spot beside/behind the leader; each member has its own side.
func _formation_offset() -> Vector2:
	var back := -leader.aim if leader.aim != Vector2.ZERO else Vector2.DOWN
	var idx := 1
	if Social.in_party(npc):
		idx = Social.party_ids().find(int(npc["id"])) + 1
	elif Social.in_npc_party(npc):
		idx = npc["sim_party"].find(int(npc["id"]))
	var side := 0.75 if idx % 2 == 1 else -0.75
	return back.rotated(side) * 30.0


## Monsters threatening the group (attacking us, the leader or a party mate) come first, then any free
## monster near `around`.
func _group_foe(around: Vector2, r: float) -> Actor:
	var lv = level_node()
	var best: Actor = null
	var bd := INF
	for e in lv.get_team_actors(foe_team()):
		if e.dead or not (e is Monster) or e.dormant:
			continue
		var threat: bool = e.target == self or (e.target != null and is_instance_valid(e.target) and Social.same_party(e.target, self))
		var d: float = e.global_position.distance_to(global_position)
		if not threat:
			if e.global_position.distance_to(around) > r or _claimed_by_other(e) or e.data.get("passive", false):
				continue
			d += 60.0
		if d < bd:
			bd = d
			best = e
	return best


# ------------------------------------------------------------------ dungeon run (spectated test runs)
## Leads the group room by room along the shortest route to the boss, clearing each room on the way.
func _think_run(hpf: float) -> void:
	var lv = level_node()
	if not (lv is DungeonLevel):
		mode = "routine"
		return
	if foe != null and not _foe_valid(foe):
		foe = null
	var cur: Vector2i = lv.cell_of(global_position)
	if foe == null:
		foe = _room_foe(lv, cur)
	if foe != null:
		_fight(hpf)
		return
	var nxt: Vector2i = lv.next_cell_toward(cur, lv.boss_cell)
	if cur == lv.boss_cell or nxt == Vector2i(-99, -99):
		_wander_around(lv.room_center_px(cur), 40.0)
		return
	_goal = lv.room_center_px(nxt)
	aim_point = global_position + (_goal - global_position).normalized() * 30.0


## Awake monsters in the given room, or anything attacking the group.
func _room_foe(lv, cell: Vector2i) -> Actor:
	var rid: int = lv.room_id_of(cell) if lv.design["rooms"].has(cell) else -999
	var best: Actor = null
	var bd := INF
	for e in lv.get_team_actors(foe_team()):
		if e.dead or not (e is Monster) or e.dormant:
			continue
		var threat: bool = e.target == self or (e.target != null and is_instance_valid(e.target) and Social.same_party(e.target, self))
		if not threat and e.room_id != rid:
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = e
	return best


# ------------------------------------------------------------------ duel
func _think_duel(hpf: float) -> void:
	if foe == null or not is_instance_valid(foe):
		_goal = Vector2.INF
		return
	aim_point = foe.body_center()
	if Duel.phase != "fight":
		_goal = Vector2.INF
		return
	_fight(hpf)


func _wander_around(center: Vector2, radius: float) -> void:
	if global_position.distance_to(center) > radius * 1.6:
		_goal = NpcWorld.route_point(global_position, center)
		return
	idle_t -= 0.15
	if wander_to == Vector2.INF or global_position.distance_to(wander_to) < 10.0:
		if idle_t > 0.0:
			_goal = Vector2.INF
			return
		idle_t = randf_range(0.5, 2.5)
		wander_to = center + Vector2.from_angle(randf() * TAU) * randf_range(20.0, radius)
	_goal = wander_to


func _town_stroll() -> void:
	idle_t -= 0.15
	if wander_to == Vector2.INF or global_position.distance_to(wander_to) < 12.0:
		if idle_t > 0.0:
			_goal = Vector2.INF
			return
		idle_t = randf_range(2.0, 7.0)
		var spots := NpcWorld.town_spots()
		wander_to = spots[randi() % spots.size()] + Vector2(randf_range(-14, 14), randf_range(-6, 10))
	_goal = NpcWorld.route_point(global_position, wander_to)


func _fight(hpf: float) -> void:
	var to: Vector2 = foe.global_position - global_position
	var d := to.length()
	var dir := to / maxf(d, 0.01)
	aim_point = foe.body_center()
	var fleeing := mode != "duel" and hpf < 0.22 and NpcWorld.count(npc, "pot_hp_s") + NpcWorld.count(npc, "pot_hp_m") + NpcWorld.count(npc, "pot_hp_l") == 0
	# dodge a telegraphed attack aimed at us: one reaction roll per wind-up, like a person (reflexes
	# differ per adventurer and improve with experience) — not a perfect machine.
	for k in _dodge_seen.keys():
		var mm = instance_from_id(k)
		if mm == null or not is_instance_valid(mm) or mm.state != "windup":
			_dodge_seen.erase(k)
	for m in level_node().actors_in_radius(global_position, 110.0, foe_team()):
		if not (m is Monster) or m.target != self or m.state != "windup" or _dodge_seen.has(m.get_instance_id()):
			continue
		_dodge_seen[m.get_instance_id()] = true
		if dash_cd <= 0.0 and randf() < reflex():
			var md: Vector2 = (global_position - m.global_position).normalized()
			_goal = global_position + md.orthogonal() * (1.0 if randf() < 0.5 else -1.0) * 60.0 + md * 30.0
			want_dash = true
			break
	if want_dash:
		return
	if fleeing:
		_goal = global_position - dir * 80.0
		if dash_cd <= 0.0 and d < 60.0:
			want_dash = true
		return
	# positioning
	if ranged:
		var lo := 70.0
		var hi := minf(atk_range, 170.0)
		if d > hi:
			_goal = foe.global_position - dir * (hi - 20.0)
		elif d < lo:
			_goal = global_position - dir * 50.0 + dir.orthogonal() * 20.0
		else:
			_goal = global_position + dir.orthogonal() * (14.0 if int(npc["id"]) % 2 == 0 else -14.0)
		attack_held = d <= atk_range
	else:
		if d > atk_range - 4.0:
			_goal = foe.global_position
		else:
			_goal = Vector2.INF
		attack_held = d <= atk_range + 4.0
	want_skill = _choose_skill(d, hpf)
	if mode == "duel" and _goal != Vector2.INF and _goal.distance_to(Duel.center) > Duel.RING - 12.0:
		_goal = Duel.center + (_goal - Duel.center).limit_length(Duel.RING - 12.0)


func _choose_skill(d: float, hpf: float) -> String:
	if gcd > 0.0 or randf() < 0.25:
		return ""
	for sid in npc.get("hot_skills", []):
		if sid == "" or skill_cds.has(sid) or skill_lv(sid) <= 0:
			continue
		var s: Dictionary = GameData.SKILLS[sid]
		if mp < GameData.skill_mp(sid, skill_lv(sid)):
			continue
		var kind: String = s.get("kind", "")
		if kind in SUPPORT:
			match kind:
				"heal", "regen":
					if hpf < 0.55:
						return sid
				"smoke", "blink", "backstep":
					if hpf < 0.4 or (ranged and d < 45.0):
						return sid
				_:
					if d < 150.0 and not buffs.has(sid) and randf() < 0.4:
						return sid
			continue
		if d <= float(SKILL_RANGE.get(kind, 120.0)):
			return sid
	return ""


func _handle_actions() -> void:
	if want_dash:
		want_dash = false
		if _goal != Vector2.INF:
			move_dir = (_goal - global_position).normalized()
		try_dash()
		return
	if want_skill != "":
		var sid := want_skill
		want_skill = ""
		if try_cast(sid):
			return
	if attack_held and attack_cd <= 0.0:
		basic_attack()
