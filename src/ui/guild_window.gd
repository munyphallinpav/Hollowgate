class_name GuildWindow
extends GameWindow
## Adventurer Guild: quest board, turn-ins and guild rank.

var board_box: VBoxContainer
var mine_box: VBoxContainer
var rank_lbl: RichTextLabel


func _init() -> void:
	super._init("Adventurer Guild", Vector2(1120, 620), "guild")
	rank_lbl = UI.rich("", 15)
	body.add_child(rank_lbl)
	var h := UI.hbox(16)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(h)
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
	board_box = UI.vbox(6)
	left.add_child(UI.scroll(board_box, Vector2(530, 470)))
	var right := UI.vbox(6)
	h.add_child(right)
	right.add_child(UI.label("Your Quests", 18, Color("ffe9a8")))
	mine_box = UI.vbox(6)
	right.add_child(UI.scroll(mine_box, Vector2(530, 470)))


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
	rank_lbl.text = "Guild Rank [color=#fee761][b]%s[/b][/color] — %d points%s.  Active quest slots: %d / %d.  [color=#9c97b8]New quests are posted every day. Higher ranks allow more active quests.[/color]" % [rank, gp, nxt, Game.player["quests"].size(), Game.max_active_quests()]
	for c in board_box.get_children():
		c.queue_free()
	for i in Game.world["board"].size():
		board_box.add_child(QuestsPage.quest_card(Game.world["board"][i], i, true))
	if Game.world["board"].is_empty():
		board_box.add_child(UI.label("The board is empty. Come back tomorrow!", 14, UI.DIM))
	for c in mine_box.get_children():
		c.queue_free()
	for i in Game.player["quests"].size():
		mine_box.add_child(QuestsPage.quest_card(Game.player["quests"][i], i, false))
	if Game.player["quests"].is_empty():
		mine_box.add_child(UI.label("No active quests.", 14, UI.DIM))
