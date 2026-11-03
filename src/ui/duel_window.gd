class_name DuelWindow
extends GameWindow
## Setting up a duel with an adventurer: both sides put up stakes of similar value (gold and/or items),
## or nothing for a friendly bout. The adventurer decides whether the bet is worth it.
## When the adventurer challenged you, its stake is fixed and you have to match it.

var n: Dictionary
var actor: Adventurer
var challenged := false
var their: Dictionary = {"gold": 0, "items": []}
var gold_spin: SpinBox
var item_checks: Dictionary = {}  # bag index -> CheckBox
var mine_lbl: Label
var theirs_box: VBoxContainer
var match_lbl: RichTextLabel
var answer_lbl: RichTextLabel
var go_btn: Button


func _init(npc: Dictionary, a: Adventurer, challenge: Dictionary = {}) -> void:
	n = npc
	actor = a
	challenged = not challenge.is_empty()
	if challenged:
		their = {"gold": int(challenge.get("gold", 0)), "items": []}
	super._init("Duel — %s" % n["name"], Vector2(860, 560), "duel")
	var cls: Dictionary = GameData.CLASSES[n["class"]]
	var head := UI.rich("", 15)
	var ch := Duel.npc_win_chance(n)
	head.text = "[color=#%s][b]%s[/b][/color]  Lv %d %s  •  duels won %d / lost %d  •  [color=#9c97b8]rates their own chances at[/color] [b]%d%%[/b]\n" % [
		cls["color"].lightened(0.3).to_html(false), n["name"], int(n["level"]), cls["name"], int(n.get("duels_won", 0)), int(n.get("duels_lost", 0)), int(ch * 100.0)]
	head.text += "[color=#9c97b8]Winner takes the whole pot and earns XP (more for beating a stronger opponent, half for a friendly bout). Both stakes must be worth about the same (within %d%%). No potions; the first to drop to 1 HP loses — nobody dies. Leaving the ring for 3 seconds forfeits; after %d s it is a draw.[/color]" % [
		int(Duel.MATCH_TOLERANCE * 100.0), int(Duel.TIME_LIMIT)]
	body.add_child(head)
	if challenged:
		var c := UI.rich("[color=#fee761]%s challenged you%s![/color]" % [n["name"], (" and puts up %d gold" % int(their["gold"])) if int(their["gold"]) > 0 else " to a friendly bout"], 16)
		body.add_child(c)
	var cols := UI.hbox(18)
	body.add_child(cols)
	# ---- your stake
	var left := UI.vbox(6)
	left.custom_minimum_size.x = 420
	cols.add_child(left)
	left.add_child(UI.label("Your stake", 16, Color("ffe9a8")))
	var gh := UI.hbox(8)
	left.add_child(gh)
	gh.add_child(UI.icon(Art.icon("gold"), 18))
	gold_spin = SpinBox.new()
	gold_spin.min_value = 0
	gold_spin.max_value = maxi(0, int(Game.player["gold"]))
	gold_spin.step = 10
	gold_spin.custom_minimum_size.x = 140
	gold_spin.value = mini(int(their["gold"]), int(Game.player["gold"])) if challenged else 0
	gold_spin.value_changed.connect(func(_v): _refresh())
	gh.add_child(gold_spin)
	gh.add_child(UI.label("of %d gold" % int(Game.player["gold"]), 13, UI.DIM))
	left.add_child(UI.label("Items (up to %d): gear and materials" % Duel.MAX_STAKE_ITEMS, 13, UI.DIM))
	var il := UI.vbox(2)
	var inv: Array = Game.player["inv"]
	for i in inv.size():
		var it = inv[i]
		if not (it is Dictionary) or it.is_empty():
			continue
		var t := GameData.item_template(it.get("id", ""))
		if not (Items.is_gear(it) or t.get("type", "") == "material"):
			continue
		var row := UI.hbox(6)
		var cb := CheckBox.new()
		cb.text = "%s  (%d g)" % [Items.name_of(it), Items.sell_price(it) * int(it.get("qty", 1))]
		cb.add_theme_color_override("font_color", Items.color_of(it) if Items.is_gear(it) else UI.TEXT)
		cb.toggled.connect(func(_on): _refresh())
		row.add_child(cb)
		item_checks[i] = cb
		il.add_child(row)
	if item_checks.is_empty():
		il.add_child(UI.label("Nothing suitable in your bag.", 13, UI.DIM))
	left.add_child(UI.scroll(il, Vector2(410, 230)))
	mine_lbl = UI.label("", 15, Color("fee761"))
	left.add_child(mine_lbl)
	# ---- their stake
	var right := UI.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(UI.label("%s's stake" % n["name"], 16, Color("ffe9a8")))
	theirs_box = UI.vbox(3)
	right.add_child(theirs_box)
	match_lbl = UI.rich("", 15)
	match_lbl.custom_minimum_size = Vector2(360, 50)
	right.add_child(match_lbl)
	answer_lbl = UI.rich("", 14)
	answer_lbl.custom_minimum_size = Vector2(360, 60)
	right.add_child(answer_lbl)
	# ---- buttons
	var h := UI.hbox(10)
	h.alignment = BoxContainer.ALIGNMENT_END
	body.add_child(h)
	h.add_child(UI.button("Decline" if challenged else "Cancel", func():
		if challenged:
			n.erase("challenge")
			Game.toast("%s: \"Another time, then.\"" % n["name"], Color("c8c0e0"))
		close(), 120))
	if not challenged:
		h.add_child(UI.button("Friendly duel (no stakes)", _friendly, 220))
	go_btn = UI.button("Accept challenge" if challenged else "Propose duel", _go, 180)
	h.add_child(go_btn)
	_refresh()


func _my_stake() -> Dictionary:
	var st := {"gold": int(gold_spin.value), "items": []}
	var inv: Array = Game.player["inv"]
	for i in item_checks:
		if item_checks[i].button_pressed and i < inv.size():
			st["items"].append(inv[i])
	return st


func _refresh() -> void:
	var mine := _my_stake()
	var n_items: int = mine["items"].size()
	for i in item_checks:
		item_checks[i].disabled = not item_checks[i].button_pressed and n_items >= Duel.MAX_STAKE_ITEMS
	var mv := Duel.stake_value(mine)
	mine_lbl.text = "Your stake is worth %d gold" % mv
	if not challenged:
		their = Duel.npc_offer(n, mv) if mv > 0 else {"gold": 0, "items": []}
	for c in theirs_box.get_children():
		c.queue_free()
	if int(their["gold"]) > 0:
		var gh := UI.hbox(6)
		gh.add_child(UI.icon(Art.icon("gold"), 18))
		gh.add_child(UI.label("%d gold" % int(their["gold"]), 15, Color("fee761")))
		theirs_box.add_child(gh)
	for it in their["items"]:
		theirs_box.add_child(UI.label("%s  (%d g)" % [Items.name_of(it), Items.sell_price(it) * int(it.get("qty", 1))], 14,
			Items.color_of(it) if Items.is_gear(it) else UI.TEXT))
	if int(their["gold"]) <= 0 and their["items"].is_empty():
		theirs_box.add_child(UI.label("Nothing (friendly bout)" if mv <= 0 else "—", 14, UI.DIM))
	var tv := Duel.stake_value(their)
	var ok := Duel.values_match(mv, tv)
	if mv <= 0 and tv <= 0:
		match_lbl.text = "[color=#9c97b8]No stakes: a friendly duel (half XP).[/color]"
	elif ok:
		match_lbl.text = "[color=#7be05a]Stakes match[/color] — %d vs %d gold worth. Pot: %d gold worth." % [mv, tv, mv + tv]
	elif not challenged and tv < mv:
		match_lbl.text = "[color=#ff9a6a]%s can't match that[/color] (best offer %d vs your %d). Bet less." % [n["name"], tv, mv]
	else:
		match_lbl.text = "[color=#ff9a6a]Stakes don't match[/color] — %d vs %d. They must be within %d%% of each other." % [mv, tv, int(Duel.MATCH_TOLERANCE * 100.0)]
	go_btn.disabled = not ok or (challenged and tv > 0 and mv <= 0)


func _can_start() -> String:
	if Duel.active:
		return "A duel is already going on."
	if actor == null or not is_instance_valid(actor) or actor.dead:
		return "%s is no longer here." % n["name"]
	var p = Game.player_node
	if p == null or not is_instance_valid(p) or p.dead:
		return "You can't duel right now."
	if actor.global_position.distance_to(p.global_position) > 260.0:
		return "%s is too far away." % n["name"]
	return ""


func _friendly() -> void:
	var why := _can_start()
	if why != "":
		answer_lbl.text = "[color=#ff6a6a]%s[/color]" % why
		return
	var acc := Duel.npc_accepts(n, 0)
	answer_lbl.text = acc[1]
	if acc[0]:
		_start({"gold": 0, "items": []}, {"gold": 0, "items": []})


func _go() -> void:
	var why := _can_start()
	if why != "":
		answer_lbl.text = "[color=#ff6a6a]%s[/color]" % why
		return
	var mine := _my_stake()
	var mv := Duel.stake_value(mine)
	if not Duel.values_match(mv, Duel.stake_value(their)):
		return
	if not challenged:
		var acc := Duel.npc_accepts(n, mv)
		answer_lbl.text = acc[1]
		if not acc[0]:
			Sfx.play("error")
			return
	n.erase("challenge")
	_start(mine, their)


func _start(mine: Dictionary, theirs: Dictionary) -> void:
	var p = Game.player_node
	var a := actor
	close()
	if not Duel.start(p, a, mine, theirs):
		Game.toast("The duel could not start.", UI.BAD)
