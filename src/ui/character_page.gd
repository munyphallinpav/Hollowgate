class_name CharacterPage
extends HBoxContainer
## Main stat allocation + full derived stat sheet + resistances.

var header: RichTextLabel
var points_lbl: Label
var stat_rows: Dictionary = {}
var derived: RichTextLabel
var res: RichTextLabel
var misc: RichTextLabel


func _ready() -> void:
	add_theme_constant_override("separation", 18)
	var left := UI.vbox(8)
	left.custom_minimum_size.x = 400
	add_child(left)
	header = UI.rich("", 16)
	left.add_child(header)
	points_lbl = UI.label("", 17, Color("fee761"))
	left.add_child(points_lbl)
	left.add_child(UI.sep())
	for st in GameData.WorldData.MAIN_STATS:
		var row := UI.hbox(6)
		var name := UI.label(GameData.WorldData.STAT_NAMES[st], 17, Color("ffe9a8"))
		name.custom_minimum_size.x = 52
		name.mouse_filter = Control.MOUSE_FILTER_STOP
		var tip: String = GameData.WorldData.STAT_DESC[st]
		name.mouse_entered.connect(func(): Game.main.tooltip.show_text(tip, 260))
		name.mouse_exited.connect(func(): Game.main.tooltip.hide_tip())
		row.add_child(name)
		var val := UI.label("", 16)
		val.custom_minimum_size.x = 90
		row.add_child(val)
		var info := UI.label("", 12, UI.DIM)
		info.custom_minimum_size.x = 120
		row.add_child(info)
		for n in [1, 5, 10]:
			var nn: int = n
			var s2: String = st
			row.add_child(UI.button("+%d" % nn, func(): Game.allocate_stat(s2, nn)))
		left.add_child(row)
		stat_rows[st] = {"val": val, "info": info}
	left.add_child(UI.sep())
	left.add_child(UI.rich("[color=#9c97b8]You gain 10 stat points and 5 skill points every level (max level 100). Each level up also fully restores HP and MP. A Scroll of Rebirth (Magic Shop) refunds all stat points.[/color]", 13))
	var mid := UI.vbox(6)
	mid.custom_minimum_size.x = 300
	add_child(mid)
	mid.add_child(UI.label("Attributes", 18, Color("ffe9a8")))
	derived = UI.rich("", 14)
	mid.add_child(derived)
	var right := UI.vbox(6)
	right.custom_minimum_size.x = 300
	add_child(right)
	right.add_child(UI.label("Elements", 18, Color("ffe9a8")))
	res = UI.rich("", 14)
	right.add_child(res)
	right.add_child(UI.sep())
	misc = UI.rich("", 14)
	right.add_child(misc)
	Game.player_changed.connect(refresh)
	Game.stats_changed.connect(refresh)
	Game.xp_changed.connect(refresh)
	refresh()


func refresh() -> void:
	if Game.player.is_empty() or not is_inside_tree():
		return
	var p := Game.player
	var cls: Dictionary = GameData.CLASSES[p["class"]]
	var lv := int(p["level"])
	header.text = "[b][color=#%s]%s[/color][/b]  the %s   [color=#ffe9a8]Level %d[/color]\n[color=#9c97b8]%s[/color]\nXP: %d / %d" % [
		cls["color"].to_html(false), p["name"], cls["name"], lv, cls["role"], int(p["xp"]), GameData.xp_to_next(lv)]
	points_lbl.text = "Stat points available: %d" % int(p["stat_points"])
	var st := Game.stats
	for s in stat_rows:
		var base := int(cls["base"][s])
		var al := int(p["alloc"][s])
		var total := int(st.get(s, 0))
		stat_rows[s]["val"].text = str(total)
		stat_rows[s]["info"].text = "base %d  +%d  (+%d)" % [base, al, total - base - al]
	var lines := []
	for r in StatCalc.sheet_rows():
		var v = st.get(r[1], 0)
		var txt: String = r[2] % (int(v) if r[2] == "%d" or r[2] == "%d%%" else v)
		lines.append("[color=#c8c0e0]%s:[/color]  [color=#ffffff]%s[/color]" % [r[0], txt])
	var spec := "Yes (+15% dmg, +10% speed)" if Game.is_specialized_weapon() else "No — equip a %s" % cls["weapon"].capitalize()
	lines.append("[color=#c8c0e0]Class Weapon[/color]  %s" % spec)
	derived.text = "\n".join(lines)
	var rl := []
	for el in GameData.WorldData.ELEMENTS:
		var c: Color = GameData.element_color(el)
		rl.append("[color=#%s]%s[/color]   Res %d%%   Dmg +%d%%" % [c.to_html(false), el.capitalize(), int(st.get("res_" + el, 0)), int(st.get("dmg_" + el, 0))])
	rl.append("")
	rl.append("[color=#9c97b8]Water > Fire > Earth > Wind > Water.  Light and Dark are strong against each other.[/color]")
	res.text = "\n".join(rl)
	var kills := 0
	for k in p["kills"]:
		kills += int(p["kills"][k])
	misc.text = "Guild Rank: [color=#fee761]%s[/color] (%d pts)\nMonsters slain: %d\nBosses slain: %d\nDungeons cleared: %d\nPlay time: %s" % [
		GameData.guild_rank(int(p["guild_points"])), int(p["guild_points"]), kills, int(p["bosses_killed"]), int(p["dungeons_cleared"]), UI.fmt_time(Game.playtime)]
