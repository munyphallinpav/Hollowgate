class_name NpcProfileWindow
extends GameWindow
## Character sheet of an NPC adventurer: class, level, stats, equipment, bag, skills, quests, dungeon
## listings and current activity — plus your bond with it, gifts, party invitations and duels.

var n: Dictionary
var portrait: TextureRect
var _pv_t := 0.0
var _pv_f := 0


func _init(npc: Dictionary) -> void:
	n = npc
	super._init("Adventurer — %s" % npc["name"], Vector2(1080, 700), "npc_profile")
	var cls: Dictionary = GameData.CLASSES[n["class"]]
	var st := NpcWorld.stats_of(n)
	var top := UI.hbox(16)
	body.add_child(top)
	# ---- left: portrait + identity + record
	var left := UI.vbox(6)
	left.custom_minimum_size.x = 300
	top.add_child(left)
	var ph := UI.hbox(10)
	left.add_child(ph)
	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(96, 112)
	frame.add_theme_stylebox_override("panel", UI.sbox(Color("100f1c"), Color("3a3656"), 1, 6, 0))
	ph.add_child(frame)
	portrait = UI.icon(null, 96)
	portrait.material = NpcWorld.hue_material(n)
	portrait.position = Vector2(0, 8)
	portrait.size = Vector2(96, 96)
	frame.add_child(portrait)
	var idv := UI.vbox(2)
	ph.add_child(idv)
	idv.add_child(UI.label(n["name"], 22, cls["color"].lightened(0.2)))
	idv.add_child(UI.label("Level %d %s" % [int(n["level"]), cls["name"]], 16))
	idv.add_child(UI.label(cls["role"], 13, UI.DIM))
	idv.add_child(UI.label("Guild rank %s" % GameData.guild_rank(int(n["guild_points"])), 14, Color("fee761")))
	idv.add_child(UI.label("%d gold" % int(n["gold"]), 14, Color("fee761")))
	left.add_child(UI.rich("[color=#8fe8ff]%s[/color]" % NpcWorld.activity(n), 14))
	left.add_child(UI.rich("XP %d / %d\nMonsters slain: %d   Defeats: %d\nDungeons cleared: %d   Quests done: %d\nJoined on day %d" % [
		int(n["xp"]), GameData.xp_to_next(int(n["level"])), int(n["kills"]), int(n["deaths"]), int(n["dungeons_cleared"]),
		int(n.get("quests_done", 0)), int(n.get("joined_day", 1))], 13))
	left.add_child(UI.sep())
	left.add_child(UI.label("Stats", 15, Color("ffe9a8")))
	left.add_child(UI.rich("[color=#ffe9a8]HP[/color] %d   [color=#8fb8ff]MP[/color] %d\n[color=#ffb08a]Phys Atk[/color] %d   [color=#c79bff]Magic Atk[/color] %d\n[color=#c0cbdc]Phys Def[/color] %d   [color=#c0cbdc]Magic Def[/color] %d\n[color=#fee761]Crit[/color] %.1f%%  x%d%%   [color=#8fe8ff]Atk speed[/color] x%.2f\nSTR %d  VIT %d  INT %d  MND %d  DEX %d  LUK %d" % [
		int(st["max_hp"]), int(st["max_mp"]), int(st["patk"]), int(st["matk"]), int(st["pdef"]), int(st["mdef"]), st["crit"], int(st["crit_dmg"]), st["aspd"],
		int(st["str"]), int(st["vit"]), int(st["int"]), int(st["mnd"]), int(st["dex"]), int(st["luk"])], 13))
	# ---- middle: equipment + bag
	var mid := UI.vbox(6)
	mid.custom_minimum_size.x = 390
	top.add_child(mid)
	mid.add_child(UI.label("Equipment", 15, Color("ffe9a8")))
	var eg := GridContainer.new()
	eg.columns = 7
	mid.add_child(eg)
	for k in GameData.ItemData.EQUIP_SLOTS:
		var s := ItemSlot.new(48)
		s.source = "view"
		s.draggable = false
		s.compare_equipped = false
		s.key = k
		s.set_item(n["equip"].get(k, {}))
		eg.add_child(s)
	mid.add_child(UI.label("Bag (%d / %d)" % [n["inv"].size(), int(n["bag_size"])], 15, Color("ffe9a8")))
	var bg := GridContainer.new()
	bg.columns = 8
	bg.add_theme_constant_override("h_separation", 3)
	bg.add_theme_constant_override("v_separation", 3)
	for it in n["inv"]:
		var s2 := ItemSlot.new(44)
		s2.source = "view"
		s2.draggable = false
		s2.compare_equipped = false
		s2.set_item(it)
		bg.add_child(s2)
	mid.add_child(UI.scroll(bg, Vector2(380, 200)))
	mid.add_child(UI.label("Quests", 15, Color("ffe9a8")))
	var qt := ""
	for q in n["quests"]:
		qt += "• %s  %s\n" % [q["title"], "(done)" if Quests.is_complete_for(q, n) else "%d / %d" % [mini(int(q.get("have", 0)) if q["type"] != "gather" else NpcWorld.count(n, q["target"]), int(q["need"])), int(q["need"])]]
	mid.add_child(UI.rich(qt if qt != "" else "[color=#9c97b8]No quests right now.[/color]", 13))
	# ---- right: skills + dungeons
	var right := UI.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(right)
	right.add_child(UI.label("Skill hotbar", 15, Color("ffe9a8")))
	var hb := UI.hbox(6)
	right.add_child(hb)
	for sid in n["hot_skills"]:
		if sid == "":
			var e := Panel.new()
			e.custom_minimum_size = Vector2(40, 40)
			e.add_theme_stylebox_override("panel", UI.sbox(Color("12111f"), Color("4a4568"), 1, 4, 0))
			hb.add_child(e)
		else:
			var ic := UI.skill_icon(sid, 40)
			ic.tooltip_text = "%s  Lv %d" % [GameData.SKILLS[sid]["name"], int(n["skills"].get(sid, 0))]
			hb.add_child(ic)
	right.add_child(UI.label("Learned skills", 15, Color("ffe9a8")))
	var sl := UI.vbox(2)
	var ids: Array = n["skills"].keys()
	ids.sort_custom(func(a, b): return int(n["skills"][a]) > int(n["skills"][b]))
	for sid in ids:
		var s: Dictionary = GameData.SKILLS.get(sid, {})
		if s.is_empty():
			continue
		var row := UI.hbox(6)
		row.add_child(UI.skill_icon(sid, 22))
		row.add_child(UI.label("%s  Lv %d  (%s)" % [s["name"], int(n["skills"][sid]), s["type"]], 12))
		sl.add_child(row)
	right.add_child(UI.scroll(sl, Vector2(300, 250)))
	right.add_child(UI.label("Dungeons listed in the guild", 15, Color("ffe9a8")))
	var dt := ""
	for l in NpcWorld.listings():
		if int(l["owner"]) == int(n["id"]):
			dt += "• %s (rank %d) — played %d, cleared %d\n" % [l["name"], int(l["rank"]), int(l["plays"]), int(l["clears"])]
	right.add_child(UI.rich(dt if dt != "" else "[color=#9c97b8]None yet.[/color]", 13))
	body.add_child(UI.sep())
	_build_social()


# ------------------------------------------------------------------ bond / party / duel
## The adventurer's actor if it is close enough to talk to (party members are always reachable).
func _actor_near() -> Adventurer:
	var a = NpcWorld.actor_of(n)
	var p = Game.player_node
	if a == null or p == null or not is_instance_valid(p) or a.dead:
		return null
	if Social.in_party(n) or a.global_position.distance_to(p.global_position) <= 200.0:
		return a
	return null


func _build_social() -> void:
	var row := UI.hbox(16)
	body.add_child(row)
	# bond
	var bv := UI.vbox(3)
	bv.custom_minimum_size.x = 330
	row.add_child(bv)
	var bl := Social.bond_level(n)
	bv.add_child(UI.rich("[color=#ff9ad5]Bond:[/color] [b]%s[/b]  [color=#9c97b8](level %d/5)[/color]  %d / %d" % [Social.bond_name(n), bl, Social.bond(n), Social.BOND_MAX], 14))
	var bar := UI.bar(Color("e85aa8"), 320, 10)
	bar.max_value = Social.BOND_MAX
	bar.value = Social.bond(n)
	bv.add_child(bar)
	var left_today := Social.bond_left_today(n)
	bv.add_child(UI.rich("[color=#9c97b8]Today: +%d more bond possible (max %d/day). Gifts that count: gear they can wear that beats theirs, potions, food, materials their quests need — or gold (%d gold = 1 bond).[/color]" % [
		left_today, Social.BOND_PER_DAY, Social.gold_per_bond(n)], 12))
	bv.add_child(UI.rich("[color=#9c97b8]Fighting together in your party: +%d more today (max %d/day) — kills (elites and bosses count most) and dungeons cleared together.[/color]" % [
		Social.team_bond_left_today(n), Social.TEAM_BOND_PER_DAY], 12))
	# party + duel info
	var pv := UI.vbox(3)
	pv.custom_minimum_size.x = 360
	row.add_child(pv)
	if Social.in_party(n):
		var until := float(n.get("party_until", 1e12)) - float(Game.world.get("total", 0.0))
		pv.add_child(UI.rich("[color=#7be0ff]In your party[/color] — %s. Shares XP from every kill, follows you into dungeons." % ("stays for good (sworn ally)" if until > 1e10 else "stays about %d more min" % maxi(1, int(until / 60.0))), 14))
	else:
		var ch := Social.invite_chance(n)
		if float(ch[0]) > 0.0:
			var diff := int(n["level"]) - int(Game.player["level"])
			pv.add_child(UI.rich("Chance to accept a party invite: [b]%d%%[/b]  [color=#9c97b8](%s, bond %+d%%)[/color]" % [
				int(float(ch[0]) * 100.0), ("%d levels above you" % diff) if diff > 0 else "not stronger than you", 12 * bl], 14))
		else:
			pv.add_child(UI.rich("[color=#9c97b8]%s[/color]" % ch[1], 14))
	pv.add_child(UI.rich("Duels: won %d / lost %d   [color=#9c97b8](you: %d / %d)[/color]" % [int(n.get("duels_won", 0)), int(n.get("duels_lost", 0)),
		int(Game.player.get("duels_won", 0)), int(Game.player.get("duels_lost", 0))], 13))
	if n.has("challenge"):
		pv.add_child(UI.rich("[color=#fee761]%s has challenged you to a duel%s![/color]" % [n["name"], (" for %d gold" % int(n["challenge"].get("gold", 0))) if int(n["challenge"].get("gold", 0)) > 0 else ""], 14))
	# actions
	var av := UI.vbox(4)
	av.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(av)
	var near := _actor_near()
	var h1 := UI.hbox(6)
	av.add_child(h1)
	var h2 := UI.hbox(6)
	av.add_child(h2)
	var gi := UI.button("Give item…", _give_item_dialog, 150)
	var gg := UI.button("Give gold…", _give_gold_dialog, 150)
	h1.add_child(gi)
	h1.add_child(gg)
	var inv_btn: Button
	if Social.in_party(n):
		inv_btn = UI.button("Part ways", func():
			Social.leave_party(n, "%s leaves your party." % n["name"])
			_reopen(), 150)
	else:
		inv_btn = UI.button("Invite to party", func():
			var r := Social.invite(n)
			Game.toast(r[1], UI.GOOD if r[0] else Color("ffb38a"))
			Sfx.play("levelup" if r[0] else "error")
			_reopen(), 150)
	var du := UI.button("Answer challenge…" if n.has("challenge") else "Challenge to duel…", func():
		var a := _actor_near()
		if a == null:
			return
		var ch2: Dictionary = n.get("challenge", {})
		close()
		Game.main.open_duel(n, a, ch2), 190)
	h2.add_child(inv_btn)
	h2.add_child(du)
	var hint := ""
	var busy: bool = n["state"] in ["dead", "dungeon"]
	if near == null:
		hint = "Talk to %s in person to give gifts, invite or duel (%s)." % [n["name"], NpcWorld.activity(n).to_lower()]
		gi.disabled = true
		gg.disabled = true
		inv_btn.disabled = not Social.in_party(n)
		du.disabled = true
	if busy:
		du.disabled = true
	if Game.test_run or not (Game.level_node is Overworld) or Duel.active:
		du.disabled = true
		if hint == "":
			hint = "Duels are fought out in the world (not in dungeons or test runs)."
	if not Social.in_party(n) and float(Social.invite_chance(n)[0]) <= 0.0:
		inv_btn.disabled = true
	# features that open up with character level (Progression)
	var locked: Array = []
	if not Progression.is_unlocked("bonds"):
		gi.disabled = true
		gg.disabled = true
		locked.append("bonds")
	if not Progression.is_unlocked("party") and not Social.in_party(n):
		inv_btn.disabled = true
		locked.append("party")
	if not Progression.is_unlocked("duels"):
		du.disabled = true
		locked.append("duels")
	if not locked.is_empty():
		var parts: PackedStringArray = []
		for id in locked:
			parts.append("%s at Lv %d" % [Progression.feature(id)["name"], Progression.unlock_level(id)])
		hint = ("%s
" % hint if hint != "" else "") + "Unlocks: " + ", ".join(parts) + "."
	if hint != "":
		av.add_child(UI.label(hint, 12, UI.DIM))


func _reopen() -> void:
	var id := int(n["id"])
	close()
	if Game.main:
		Game.main.open_npc_profile(id)


func _give_item_dialog() -> void:
	var m := Dialogs._modal(self, "Give %s an item" % n["name"], 600)
	var b: VBoxContainer = m["body"]
	b.add_child(UI.rich("[color=#9c97b8]Bond today: +%d more possible. Only things %s can use make them stronger — and raise your bond.[/color]" % [Social.bond_left_today(n), n["name"]], 13))
	var list := UI.vbox(3)
	var inv: Array = Game.player["inv"]
	var any := false
	for i in inv.size():
		var it = inv[i]
		if not (it is Dictionary) or it.is_empty():
			continue
		var chk := Social.gift_check(n, it)
		var row := UI.hbox(8)
		var slot := ItemSlot.new(36)
		slot.source = "view"
		slot.draggable = false
		slot.set_item(it)
		row.add_child(slot)
		var nm := UI.label(Items.name_of(it), 14, Items.color_of(it))
		nm.custom_minimum_size.x = 210
		row.add_child(nm)
		var capped := Social.bond_left_today(n) <= 0 and Social.bond(n) < Social.BOND_MAX
		var res_txt: String = (("Bond +%d" % int(chk["bond"])) + ("  (daily limit reached — tomorrow)" if capped else "")) if chk["ok"] else chk["why"]
		var res := UI.label(res_txt, 12, UI.GOOD if chk["ok"] and not capped else UI.DIM)
		res.custom_minimum_size.x = 250
		res.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(res)
		var idx: int = i
		var give := UI.button("Give", func():
			var msg := Social.give_item(n, idx)
			m["root"].queue_free()
			if msg != "":
				Game.toast(msg, Color("ff9ad5"))
			_reopen(), 70)
		give.disabled = not chk["ok"] or (Social.bond_left_today(n) <= 0 and Social.bond(n) < Social.BOND_MAX)
		row.add_child(give)
		if chk["ok"]:
			list.add_child(row)
			list.move_child(row, 0)
		else:
			list.add_child(row)
		any = true
	if not any:
		list.add_child(UI.label("Your bag is empty.", 14, UI.DIM))
	b.add_child(UI.scroll(list, Vector2(580, 340)))
	var h := UI.hbox(10)
	h.alignment = BoxContainer.ALIGNMENT_END
	b.add_child(h)
	h.add_child(UI.button("Close", func(): m["root"].queue_free(), 100))


func _give_gold_dialog() -> void:
	var per := Social.gold_per_bond(n)
	var room := mini(Social.bond_left_today(n), Social.BOND_MAX - Social.bond(n))
	var can := mini(room, int(Game.player["gold"]) / per)
	if can <= 0:
		Game.toast(Social.give_gold(n, per) if room <= 0 else "You need at least %d gold." % per, Color("ffb38a"))
		return
	Dialogs.quantity(self, "Give gold — %d gold per bond point (up to +%d today)" % [per, room], can, can, func(pts: int):
		Game.toast(Social.give_gold(n, pts * per), Color("ff9ad5"))
		_reopen())


func _process(delta: float) -> void:
	_pv_t += delta
	if _pv_t > 0.18:
		_pv_t = 0.0
		_pv_f = (_pv_f + 1) % 4
		var sf := Art.frames("char_" + n["class"])
		if sf.has_animation("idle_down"):
			portrait.texture = sf.get_frame_texture("idle_down", _pv_f % sf.get_frame_count("idle_down"))
