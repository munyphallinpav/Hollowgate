class_name GuildWindow
extends GameWindow
## Adventurer Guild: quest board, the Dungeon Hall (list your dungeon crystals for other adventurers,
## play theirs) and the roster of NPC adventurers.

var rank_lbl: RichTextLabel
var tabs: TabBar
var page: VBoxContainer
var tab := 0
var _popup: PopupMenu
var _crystal_idx: Array = []


func _init(start_tab: int = 0) -> void:
	super._init("Adventurer Guild", Vector2(1160, 640), "guild")
	tab = start_tab
	rank_lbl = UI.rich("", 15)
	body.add_child(rank_lbl)
	tabs = TabBar.new()
	tabs.add_tab("Quest Board")
	tabs.add_tab("Dungeon Hall")
	tabs.add_tab("Adventurers")
	if not Progression.is_unlocked("dungeon_hall"):
		tabs.set_tab_title(1, "Dungeon Hall (Lv %d)" % Progression.unlock_level("dungeon_hall"))
		tabs.set_tab_disabled(1, true)
		if tab == 1:
			tab = 0
	tabs.focus_mode = Control.FOCUS_NONE
	tabs.clip_tabs = false
	tabs.current_tab = tab
	tabs.tab_changed.connect(func(i):
		tab = i
		refresh())
	body.add_child(tabs)
	page = UI.vbox(8)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(page)
	_popup = PopupMenu.new()
	_popup.id_pressed.connect(_on_pick_crystal)
	add_child(_popup)


func _ready() -> void:
	Game.refresh_board()
	Game.quests_changed.connect(refresh)
	Game.inventory_changed.connect(refresh)
	refresh()


func _refresh_cost() -> int:
	return 30 + int(Game.player["level"]) * 10


func refresh() -> void:
	if not is_inside_tree():
		return
	var gp := int(Game.player["guild_points"])
	var rank := GameData.guild_rank(gp)
	var nxt := ""
	for r in GameData.WorldData.GUILD_RANKS:
		if int(r[1]) > gp:
			nxt = "  (next rank %s at %d pts)" % [r[0], int(r[1])]
			break
	rank_lbl.text = "Guild Rank [color=#fee761][b]%s[/b][/color] — %d points%s.   Quest slots %d / %d.   Dungeon Hall slots %d / %d." % [
		rank, gp, nxt, Game.player["quests"].size(), Game.max_active_quests(), NpcWorld.hero_listings().size(), NpcWorld.hero_listing_cap()]
	tabs.set_tab_title(2, "Adventurers (%d)" % NpcWorld.npcs().size())
	if tabs.current_tab != tab:
		tabs.current_tab = tab
	for c in page.get_children():
		c.queue_free()
	match tab:
		0:
			_quest_page()
		1:
			_hall_page()
		2:
			_roster_page()


# ------------------------------------------------------------------ quests
func _quest_page() -> void:
	var h := UI.hbox(16)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(h)
	var left := UI.vbox(6)
	h.add_child(left)
	var lt := UI.hbox(8)
	left.add_child(lt)
	lt.add_child(UI.label("Quest Board", 18, Color("ffe9a8")))
	lt.add_child(UI.button("New quests (%dg)" % _refresh_cost(), func():
		var c := _refresh_cost()
		if int(Game.player["gold"]) < c:
			Game.toast("Not enough gold.", UI.BAD)
			return
		Game.add_gold(-c)
		Game.refresh_board(true)))
	var board_box := UI.vbox(6)
	left.add_child(UI.scroll(board_box, Vector2(540, 440)))
	for i in Game.world["board"].size():
		board_box.add_child(QuestsPage.quest_card(Game.world["board"][i], i, true))
	if Game.world["board"].is_empty():
		board_box.add_child(UI.label("The board is empty — other adventurers took everything. New quests are posted over time.", 14, UI.DIM))
	left.add_child(UI.label("Other adventurers take quests from this board too. New ones are posted every few minutes.", 12, UI.DIM))
	var right := UI.vbox(6)
	h.add_child(right)
	right.add_child(UI.label("Your Quests", 18, Color("ffe9a8")))
	var mine_box := UI.vbox(6)
	right.add_child(UI.scroll(mine_box, Vector2(540, 460)))
	for i in Game.player["quests"].size():
		mine_box.add_child(QuestsPage.quest_card(Game.player["quests"][i], i, false))
	if Game.player["quests"].is_empty():
		mine_box.add_child(UI.label("No active quests.", 14, UI.DIM))


# ------------------------------------------------------------------ dungeon hall
func _hall_page() -> void:
	var h := UI.hbox(16)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(h)
	# ---- your listings
	var left := UI.vbox(6)
	left.custom_minimum_size.x = 556
	h.add_child(left)
	var lt := UI.hbox(8)
	left.add_child(lt)
	var mine := NpcWorld.hero_listings()
	lt.add_child(UI.label("Your dungeons  %d / %d" % [mine.size(), NpcWorld.hero_listing_cap()], 18, Color("ffe9a8")))
	_crystal_idx = []
	var inv: Array = Game.player["inv"]
	for i in inv.size():
		if inv[i] is Dictionary and inv[i].get("id", "") == "dungeon_crystal" and not inv[i].get("design", {}).is_empty():
			_crystal_idx.append(i)
	var lb := UI.button("List a Dungeon Crystal", _list_pressed)
	lb.disabled = _crystal_idx.is_empty() or mine.size() >= NpcWorld.hero_listing_cap()
	lt.add_child(lb)
	var pay: Dictionary = Game.world["guild_payout"]
	var pr := UI.hbox(8)
	left.add_child(pr)
	var prl := UI.rich("Your shares waiting: [color=#fee761]%d gold[/color], [color=#c79bff]%d item(s)[/color]" % [int(pay["gold"]), pay["items"].size()], 14)
	prl.custom_minimum_size.x = 420
	prl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pr.add_child(prl)
	var cb := UI.button("Collect", func():
		var got := NpcWorld.collect_payout()
		Game.toast("Collected %d gold and %d item(s) from the Dungeon Hall." % [got[0], got[1]], UI.GOOD)
		Sfx.play("coin")
		refresh())
	cb.disabled = int(pay["gold"]) <= 0 and pay["items"].is_empty()
	pr.add_child(cb)
	var box := UI.vbox(6)
	left.add_child(UI.scroll(box, Vector2(556, 300)))
	for l in mine:
		box.add_child(_own_card(l))
	if mine.is_empty():
		var hint := "List a Dungeon Crystal here and adventurers of a matching rank will run it.\nYou receive the share of their gold and loot that you set (gold up to %d%%, items up to %d%%). Higher shares attract fewer adventurers.\nHow you built it matters: more chests and mini bosses mean bigger hauls, but a dungeon too deadly for its rank defeats its runners and loses visitors." % [NpcWorld.MAX_GOLD_SHARE, NpcWorld.MAX_ITEM_SHARE]
		if _crystal_idx.is_empty():
			hint += "\n\n[color=#ffd27a]You have no Dungeon Crystal. Design a dungeon with the Dungeon Architect (%s) and press 'Create Dungeon Crystal'.[/color]" % Settings.action_text("open_editor")
		box.add_child(UI.rich("[color=#9c97b8]%s[/color]" % hint, 13))
	# ---- other adventurers' listings
	var right := UI.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	right.add_child(UI.label("Dungeons by other adventurers", 18, Color("ffe9a8")))
	right.add_child(UI.label("Run one per day each. The owner takes their share of the gold and items you find inside.", 12, UI.DIM))
	var box2 := UI.vbox(6)
	right.add_child(UI.scroll(box2, Vector2(540, 330)))
	var others := NpcWorld.listings().filter(func(l): return int(l["owner"]) != -1)
	others.sort_custom(func(a, b): return int(a["rank"]) < int(b["rank"]))
	for l in others:
		box2.add_child(_other_card(l))
	if others.is_empty():
		box2.add_child(UI.label("No adventurer has listed a dungeon yet (they start at level 8).", 14, UI.DIM))
	# ---- log
	page.add_child(UI.label("Hall activity", 15, Color("ffe9a8")))
	var lg: Array = Game.world.get("guild_log", [])
	var txt := ""
	for i in range(lg.size() - 1, maxi(-1, lg.size() - 6), -1):
		txt += lg[i] + "\n"
	page.add_child(UI.rich("[color=#c8c0e0]%s[/color]" % (txt if txt != "" else "Nothing yet."), 12))


func _own_card(l: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.sbox(Color("201f36"), Color("6a4fa0"), 1, 4, 8))
	var v := UI.vbox(4)
	p.add_child(v)
	var r1 := UI.hbox(8)
	v.add_child(r1)
	r1.add_child(UI.icon(Art.icon("dungeon_crystal"), 28))
	var nm := UI.rich("[b]%s[/b]  [color=#%s]Rank %d[/color]  %s" % [l["name"], Portal.rank_color(int(l["rank"])).to_html(false), int(l["rank"]),
		GameData.DUNGEON_BIOMES.get(l["biome"], {"name": l["biome"]})["name"]], 15)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_child(nm)
	var lid: int = l["id"]
	r1.add_child(UI.button("Withdraw", func():
		if NpcWorld.withdraw(lid):
			Game.toast("'%s' was returned to your bag as a Dungeon Crystal." % l["name"], UI.GOOD)
		refresh()))
	var r2 := UI.hbox(8)
	v.add_child(r2)
	r2.add_child(_share_slider("Gold share", l, "gold_pct", NpcWorld.MAX_GOLD_SHARE))
	r2.add_child(_share_slider("Item share", l, "item_pct", NpcWorld.MAX_ITEM_SHARE))
	var rating := UI.rich(rating_text(l) + "   [color=#9c97b8]Clear rate %s[/color]" % (("%d%%" % int(100.0 * int(l["clears"]) / int(l["plays"]))) if int(l["plays"]) > 0 else "—"), 12)
	rating.tooltip_text = "Compared with a standard dungeon of the same rank.\nDanger (monsters, mini bosses, traps and spawners per room, plus length) decides how many runners clear it — and how many get defeated.\nLoot (chests, mini bosses, monsters) decides how much gold and how many items they bring out, and so your share.\nAdventurers prefer dungeons they can clear that pay well; a bad clear record keeps them away."
	rating.mouse_filter = Control.MOUSE_FILTER_STOP
	v.add_child(rating)
	v.add_child(UI.label("Played %d  •  Cleared %d  •  Failed %d  •  You earned %d gold and %d item(s)" % [int(l["plays"]), int(l["clears"]),
		int(l["fails"]), int(l["earned_gold"]), int(l["earned_items"])], 12, UI.DIM))
	return p


## "Danger: Hard ×1.4  •  Loot: Rich ×1.7" with colours.
static func rating_text(l: Dictionary) -> String:
	var pr := NpcWorld.listing_profile(l)
	var d := float(pr["danger"])
	var lo := float(pr["loot"])
	var dcol := "7be05a" if d < 0.75 else ("c8c0e0" if d < 1.2 else ("ffb347" if d < 1.6 else "ff6a6a"))
	var lcol := "9c97b8" if lo < 0.7 else ("c8c0e0" if lo < 1.3 else ("fee761" if lo < 2.0 else "ffd27a"))
	return "Danger: [color=#%s]%s ×%.1f[/color]   Loot: [color=#%s]%s ×%.1f[/color]" % [dcol, NpcWorld.danger_word(d), d, lcol, NpcWorld.loot_word(lo), lo]


func _share_slider(label: String, l: Dictionary, key: String, mx: int) -> Control:
	var h := UI.hbox(4)
	h.add_child(UI.label(label, 13, UI.DIM))
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = mx
	s.step = 1
	s.value = int(l[key])
	s.custom_minimum_size.x = 130
	s.focus_mode = Control.FOCUS_NONE
	var vl := UI.label("%d%%" % int(l[key]), 13, Color("fee761"))
	s.value_changed.connect(func(v):
		l[key] = clampi(int(v), 0, mx)
		vl.text = "%d%%" % int(v))
	h.add_child(s)
	h.add_child(vl)
	return h


func _other_card(l: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.sbox(Color("201f36"), Color("4a4568"), 1, 4, 8))
	var h := UI.hbox(10)
	p.add_child(h)
	h.add_child(UI.icon(Art.icon("dungeon_crystal"), 28))
	var v := UI.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UI.rich("[b]%s[/b]  [color=#%s]Rank %d[/color]  %s" % [l["name"], Portal.rank_color(int(l["rank"])).to_html(false), int(l["rank"]),
		GameData.DUNGEON_BIOMES.get(l["biome"], {"name": l["biome"]})["name"]], 14))
	var o := NpcWorld.find(int(l["owner"]))
	var who: String = l["owner_name"] if o.is_empty() else "%s (Lv %d %s)" % [o["name"], int(o["level"]), GameData.CLASSES[o["class"]]["name"]]
	v.add_child(UI.label("By %s  •  owner's share: %d%% gold, %d%% items  •  cleared %d / %d" % [who, int(l["gold_pct"]), int(l["item_pct"]),
		int(l["clears"]), int(l["plays"])], 12, UI.DIM))
	if l.has("design"):
		v.add_child(UI.rich(rating_text(l), 12))  # standard random dungeons are always Normal/Normal
	var why := NpcWorld.hero_can_play(l)
	var b := UI.button("Played today" if why != "" else "Enter", func(): NpcWorld.hero_enter(l))
	b.disabled = why != ""
	b.tooltip_text = why
	h.add_child(b)
	return p


func _list_pressed() -> void:
	if _crystal_idx.size() == 1:
		_list(_crystal_idx[0])
		return
	_popup.clear()
	for k in _crystal_idx.size():
		var it: Dictionary = Game.player["inv"][_crystal_idx[k]]
		_popup.add_item("%s (rank %d)" % [it["design"].get("name", "Dungeon"), int(it["design"].get("rank", 1))], k)
	_popup.reset_size()
	UI.popup_at_mouse(_popup, self)


func _on_pick_crystal(k: int) -> void:
	if k >= 0 and k < _crystal_idx.size():
		_list(_crystal_idx[k])


func _list(idx: int) -> void:
	var err := NpcWorld.list_crystal(idx)
	if err != "":
		Game.toast(err, UI.BAD)
		Sfx.play("error")
	else:
		Game.toast("Dungeon listed! Adventurers of a matching rank will start running it.", UI.GOOD)
		Sfx.play("magic")
	refresh()


# ------------------------------------------------------------------ roster
func _roster_page() -> void:
	var all: Array = NpcWorld.npcs().duplicate()
	all.sort_custom(func(a, b): return int(a["level"]) > int(b["level"]))
	page.add_child(UI.label("%d adventurers call Hollowgate home (more arrive as you level up, up to %d). They hunt, quest, run dungeons, team up and duel on their own. Talk to one in person to give gifts (bond), invite it to your party (max %d) or challenge it to a duel." % [
		all.size(), NpcWorld.MAX_NPCS, Social.PARTY_MAX], 13, UI.DIM))
	# your party first, then by level
	all.sort_custom(func(a, b):
		var pa := Social.in_party(a)
		var pb := Social.in_party(b)
		if pa != pb:
			return pa
		return int(a["level"]) > int(b["level"]))
	var box := UI.vbox(4)
	var sc := UI.scroll(box, Vector2(1120, 470))
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(sc)
	for n in all:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UI.sbox(Color("1a1930"), Color("3a3656"), 1, 3, 4))
		var h := UI.hbox(10)
		p.add_child(h)
		var sf := Art.frames("char_" + n["class"])
		var por := UI.icon(sf.get_frame_texture("idle_down", 0) if sf.has_animation("idle_down") else null, 34)
		por.material = NpcWorld.hue_material(n)
		h.add_child(por)
		var nm := UI.label(n["name"], 15, GameData.CLASSES[n["class"]]["color"].lightened(0.25))
		nm.custom_minimum_size.x = 110
		h.add_child(nm)
		var lvl := UI.label("Lv %d %s" % [int(n["level"]), GameData.CLASSES[n["class"]]["name"]], 14)
		lvl.custom_minimum_size.x = 130
		h.add_child(lvl)
		var rk := UI.label("Rank %s" % GameData.guild_rank(int(n["guild_points"])), 13, Color("fee761"))
		rk.custom_minimum_size.x = 64
		h.add_child(rk)
		var gd := UI.label("%d g" % int(n["gold"]), 13, Color("fee761"))
		gd.custom_minimum_size.x = 80
		h.add_child(gd)
		var act := UI.label(NpcWorld.activity(n), 13, Color("7be0ff") if Social.in_party(n) else Color("8fe8ff"))
		act.custom_minimum_size.x = 300
		act.clip_text = true
		h.add_child(act)
		var bond := UI.label(Social.bond_name(n) if Social.bond(n) > 0 else "", 12, Color("ff9ad5"))
		bond.custom_minimum_size.x = 90
		bond.tooltip_text = "Bond %d / %d" % [Social.bond(n), Social.BOND_MAX]
		bond.mouse_filter = Control.MOUSE_FILTER_PASS
		h.add_child(bond)
		var rec := UI.label("%d kills • %d defeats • %d dungeons" % [int(n["kills"]), int(n["deaths"]), int(n["dungeons_cleared"])], 12, UI.DIM)
		rec.custom_minimum_size.x = 190
		rec.clip_text = true
		h.add_child(rec)
		var nid: int = n["id"]
		h.add_child(UI.button("Profile", func(): Game.main.open_npc_profile(nid)))
		box.add_child(p)
