extends Node
## Kill tagging + NPC manners + live fight screenshots.  godot --path . -- --autotest --tagtest [--shots=DIR]

var fails: Array = []
var passes := 0
var shots_dir := ""
var step := 0


func ok(cond: bool, what: String) -> void:
	if cond:
		passes += 1
		print("[tag] pass  ", what)
	else:
		fails.append(what)
		print("[tag] FAIL  ", what)


func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func shot(name: String) -> void:
	if shots_dir == "":
		return
	for i in 3:
		await get_tree().process_frame
	step += 1
	DirAccess.make_dir_recursive_absolute(shots_dir)
	get_viewport().get_texture().get_image().save_png("%s/tag_%02d_%s.png" % [shots_dir, step, name])


func _make_npc(cls: String, lv: int, pos: Vector2) -> Dictionary:
	var n := {}
	for k in 60:
		n = NpcWorld.add_npc(lv, false)
		if n["class"] == cls or k == 59:
			break
		Game.world["npcs"].erase(n)
	n["state"] = "hunt"
	n["state_t"] = 999.0
	n["hunt_lv"] = lv
	n["pos"] = [pos.x, pos.y]
	n["dest"] = [pos.x, pos.y]
	return n


## A spot with open, walkable ground all around (the world is random per run: avoid water and trees).
func _open_spot(lvn, from: Vector2) -> Vector2:
	for ring in 30:
		for k in 8:
			var c := from + Vector2.from_angle(k * TAU / 8.0) * ring * 48.0
			var clear := true
			for r in [0.0, 40.0, 80.0, 130.0, 180.0]:
				for j in 10:
					if not lvn.is_walkable(c + Vector2.from_angle(j * TAU / 10.0) * r):
						clear = false
						break
				if not clear:
					break
			if clear:
				return c
	return from


func run_all() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
	var M = Game.main
	M.start_new_game("Tagger", "warrior", 3)
	await _wait(0.8)
	Game.add_xp(60000)
	var lvn = Game.level_node
	lvn._adv_t = 1e9
	for n in NpcWorld.npcs():
		if n.get("physical", false):
			lvn._despawn_adventurer(n)
	Game.world["npcs"] = []
	var p := Game.player_node
	var spot := Vector2(256 * 16 + 8, 315 * 16)
	p.global_position = spot
	p.invuln_t = 9999.0
	lvn._update_chunks(true)
	await _wait(0.3)
	spot = _open_spot(lvn, spot + Vector2(60, 0)) - Vector2(60, 0)
	p.global_position = spot
	lvn._update_chunks(true)
	await _wait(0.3)
	var hl := int(Game.player["level"])
	# keep the wild quiet: no world spawns during the checks, and no strays
	lvn.spawn_t = 1e9
	for m in get_tree().get_nodes_in_group("monsters"):
		m.queue_free()
	await _wait(0.1)
	print("[tag] hero level ", hl, " area level ", lvn.gen.level_at(256, 315))
	# ---- an adventurer next to the hero
	var n := _make_npc("mage", hl, spot + Vector2(90, 0))
	lvn._spawn_adventurer(n)
	await _wait(0.2)
	var a = NpcWorld.actor_of(n)
	ok(a != null, "adventurer spawned as a real character")
	if a == null:
		_finish()
		return
	a.invuln_t = 9999.0
	# A) hero tags, NPC lands the killing blow -> hero's kill
	var w: Monster = lvn.spawn_monster("wolf", spot + Vector2(0, 160), 10)
	await _wait(0.1)
	var xp0 := int(Game.player["xp"])
	var lvl0 := int(Game.player["level"])
	var k0 := int(n["kills"])
	Combat.hit(p, w, 10.0, "phys", "none", {})
	ok(w.tag_owner() == p, "the hero's first hit tags the monster")
	Combat.hit(a, w, 99999.0, "magic", "none", {})
	await _wait(0.1)
	ok(w.dead, "the adventurer finished it off")
	ok(int(Game.player["xp"]) > xp0 or int(Game.player["level"]) > lvl0, "the hero still gets the XP for a monster they tagged")
	ok(int(n["kills"]) == k0, "the adventurer gets nothing for the hero's tagged monster")
	# B) NPC tags, hero lands the killing blow -> NPC's kill
	var g: Monster = lvn.spawn_monster("goblin", spot + Vector2(0, 170), 10)
	await _wait(0.1)
	xp0 = int(Game.player["xp"])
	lvl0 = int(Game.player["level"])
	Combat.hit(a, g, 5.0, "magic", "none", {})
	ok(g.tag_owner() == a, "the adventurer's first hit tags the monster")
	Combat.hit(p, g, 99999.0, "phys", "none", {})
	await _wait(0.1)
	ok(g.dead and int(n["kills"]) == k0 + 1, "the kill belongs to the adventurer who tagged it")
	ok(int(Game.player["xp"]) == xp0 and int(Game.player["level"]) == lvl0, "the hero gets no XP for a monster an adventurer tagged")
	# C) manners: the adventurer leaves the hero's monster alone and picks another one
	a.global_position = spot + Vector2(110, 0)
	var mine: Monster = lvn.spawn_monster("bear", spot + Vector2(-60, 0), hl)
	var free: Monster = lvn.spawn_monster("slime", spot + Vector2(170, 60), hl)
	await _wait(0.05)
	Combat.hit(p, mine, 5.0, "phys", "none", {})
	mine.target = p
	var hp_mine: float = mine.hp
	var went_for_mine := false
	var went_for_free := false
	for t in 25:
		await _wait(0.1)
		if a.foe == mine:
			went_for_mine = true
		if is_instance_valid(free) and a.foe == free:
			went_for_free = true
	ok(not went_for_mine, "the adventurer never targets a monster the hero is fighting")
	ok(went_for_free, "it picks an untagged monster instead")
	ok(mine.tag_owner() == p, "the hero keeps the tag on their monster")
	for m in [mine, free]:
		if is_instance_valid(m) and not m.dead:
			m.queue_free()
	await _wait(0.3)
	# ---- an even fight, photographed mid-battle: the hero stands back so the monsters pick the adventurers
	a.invuln_t = 0.0
	var fspot := spot + Vector2(130, 0)
	a.global_position = fspot + Vector2(-10, -30)
	p.global_position = spot + Vector2(-40, 0)
	var w2 := _make_npc("warrior", hl, fspot + Vector2(10, 30))
	lvn._spawn_adventurer(w2)
	await _wait(0.1)
	var b = NpcWorld.actor_of(w2)
	var al := clampi(hl + 4, 1, 100)
	var kk0 := int(n["kills"]) + int(w2["kills"])
	var foes := []
	for i in 5:
		var tier := "mini" if i == 4 else ("elite" if i % 2 == 0 else "normal")
		var m: Monster = lvn.spawn_monster(["wolf", "goblin", "skeleton", "bear", "ogre"][i], fspot + Vector2.from_angle(i * 1.26 + 0.3) * 55.0, al, tier)
		m.target = a if i % 2 == 0 else b
		foes.append(m)
	# direct check: can a monster's hit damage an adventurer at all?
	var hp_b0: float = b.hp
	var dealt := Combat.hit(foes[4], b, 100.0, "phys", "none", {})
	print("[tag] info: direct mini-boss hit on the warrior dealt %d (hp %d -> %d, invuln %.2f)" % [dealt, int(hp_b0), int(b.hp), b.invuln_t])
	var dashes := 0
	var taken := 0.0
	var casts := 0
	var last_a: float = a.hp
	var last_b: float = b.hp
	var t0 := Time.get_ticks_msec()
	var shots_done := 0
	while Time.get_ticks_msec() - t0 < 5000:
		await get_tree().process_frame
		if a.hp < last_a:
			taken += last_a - a.hp
		if b.hp < last_b:
			taken += last_b - b.hp
		last_a = a.hp
		last_b = b.hp
		if a.dash_t > 0.0 or b.dash_t > 0.0:
			dashes += 1
		if not a.skill_cds.is_empty() or not b.skill_cds.is_empty():
			casts += 1
		var el := Time.get_ticks_msec() - t0
		if shots_done < 3 and el > [800, 1700, 2900][shots_done]:
			await shot(["even_fight_early", "even_fight_mid", "even_fight_late"][shots_done])
			shots_done += 1
	ok(casts > 0, "both adventurers use their skills")
	ok(int(n["kills"]) + int(w2["kills"]) > kk0, "the adventurers kill tougher monsters (%d kills)" % (int(n["kills"]) + int(w2["kills"]) - kk0))
	print("[tag] info: the pack (2 elites + mini boss, +4 levels) dealt %d damage in 5 s; %d frames spent dashing" % [int(taken), dashes])
	# a boss six levels above them lasts long enough to hit back
	var boss: Monster = lvn.spawn_monster("bear", fspot + Vector2(0, -40), hl + 6, "boss")
	boss.target = b
	last_a = a.hp
	last_b = b.hp
	var boss_dmg := 0.0
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 10000 and is_instance_valid(boss) and not boss.dead:
		await get_tree().process_frame
		if a.hp < last_a:
			boss_dmg += last_a - a.hp
		if b.hp < last_b:
			boss_dmg += last_b - b.hp
		last_a = a.hp
		last_b = b.hp
		if Time.get_ticks_msec() - t1 > 2200 and shots_done == 3:
			await shot("adventurers_vs_boss")
			shots_done += 1
	print("[tag] info: the boss dealt %d damage" % int(boss_dmg))
	ok(taken + boss_dmg > 0.0, "tough monsters land hits on the adventurers (%d damage over the two fights)" % int(taken + boss_dmg))
	if is_instance_valid(boss) and not boss.dead:
		boss.queue_free()
	print("[tag] info: mage hp %d/%d  warrior hp %d/%d  " % [int(a.hp), int(a.max_hp), int(b.hp) if b else 0, int(b.max_hp) if b else 0])
	for m in foes:
		if is_instance_valid(m) and not m.dead:
			m.queue_free()
	# ---- an NPC-claimed monster's health bar is grey for the hero
	p.global_position = spot
	var c: Monster = lvn.spawn_monster("ogre", spot + Vector2(-60, -40), hl)
	await _wait(0.05)
	Combat.hit(a, c, 20.0, "magic", "none", {})
	c.target = a
	c.set_physics_process(false)
	await _wait(0.2)
	await shot("npc_tagged_bar")
	_finish()


func _finish() -> void:
	print("[tag] ==== %d passed, %d failed" % [passes, fails.size()])
	for f in fails:
		print("[tag] FAILED: ", f)
	get_tree().quit()
