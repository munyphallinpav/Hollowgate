class_name MapPage
extends HBoxContainer
## World map: explored areas, town, player and every hidden dungeon (visible even when unexplored).

var map_rect: TextureRect
var overlay: Control
var side: VBoxContainer
var scale_f := 1.0
var map_px := 540.0
var _hover_d: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(map_px, map_px)
	add_child(holder)
	map_rect = TextureRect.new()
	map_rect.size = Vector2(map_px, map_px)
	map_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	holder.add_child(map_rect)
	overlay = Control.new()
	overlay.size = Vector2(map_px, map_px)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.draw.connect(_draw_overlay)
	overlay.gui_input.connect(_overlay_input)
	overlay.mouse_exited.connect(func(): Game.main.tooltip.hide_tip())
	holder.add_child(overlay)
	side = UI.vbox(6)
	side.custom_minimum_size.x = 430
	add_child(UI.scroll(side, Vector2(430, 540)))
	refresh()


func refresh() -> void:
	var lv = Game.level_node
	for c in side.get_children():
		c.queue_free()
	if lv is Overworld:
		_build_world(lv)
	elif lv is DungeonLevel:
		_build_dungeon(lv)


func _build_world(lv: Overworld) -> void:
	var n := WorldGen.SIZE / WorldGen.CHUNK
	var img := Image.create_empty(WorldGen.SIZE, WorldGen.SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color("1a1826"))
	var explored: Dictionary = Game.world["explored"]
	var budget := 40
	for cy in n:
		for cx in n:
			var key := "%d,%d" % [cx, cy]
			if not explored.has(key):
				continue
			var c := Vector2i(cx, cy)
			if not lv.map_images.has(c):
				if budget <= 0:
					continue
				budget -= 1
			var im: Image = lv.get_map_image(c)
			img.blit_rect(im, Rect2i(0, 0, WorldGen.CHUNK, WorldGen.CHUNK), c * WorldGen.CHUNK)
	map_rect.texture = ImageTexture.create_from_image(img)
	scale_f = map_px / float(WorldGen.SIZE)
	side.add_child(UI.label("World Map", 18, Color("ffe9a8")))
	side.add_child(UI.rich("[color=#9c97b8]Explored lands are revealed as you travel. Hidden dungeons are always marked — their colour shows the rank. Hover a marker for details.[/color]", 13))
	side.add_child(UI.rich("Rank colours:  [color=#7be05a]1-19[/color]  [color=#3fa9f5]20-39[/color]  [color=#b06cf0]40-59[/color]  [color=#ff9a2e]60-79[/color]  [color=#ff4f7b]80-100[/color]", 13))
	side.add_child(UI.sep())
	var pt := lv.tile_of(lv.player.global_position)
	var ds: Array = Game.world["dungeons"].duplicate()
	ds.sort_custom(func(a, b): return Vector2(a["tile"][0], a["tile"][1]).distance_to(Vector2(pt)) < Vector2(b["tile"][0], b["tile"][1]).distance_to(Vector2(pt)))
	for d in ds:
		var dt := Vector2(d["tile"][0], d["tile"][1])
		var dist := int(dt.distance_to(Vector2(pt)))
		var dirv := dt - Vector2(pt)
		var compass := _compass(dirv)
		var left := float(d["expires"]) - float(Game.world["total"])
		var name: String = d.get("name", "") if d.get("custom", false) else "%s Dungeon" % GameData.DUNGEON_BIOMES[d["biome"]]["name"]
		var timer := "permanent" if d.get("custom", false) else UI.fmt_time(left) + " left"
		side.add_child(UI.rich("[color=#%s]Rank %d[/color]  %s  [color=#9c97b8]%d tiles %s • %s[/color]" % [Portal.rank_color(int(d["rank"])).to_html(false), int(d["rank"]), name, dist, compass, timer], 13))


func _compass(v: Vector2) -> String:
	if v.length() < 1.0:
		return "here"
	var a := fposmod(rad_to_deg(v.angle()) + 90.0, 360.0)
	var dirs := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	return dirs[int(round(a / 45.0)) % 8]


func _build_dungeon(lv: DungeonLevel) -> void:
	var img: Image = lv.map_image.duplicate()
	var cs: Vector2i = GameData.WorldData.CELL_SIZE
	for y in lv.H:
		for x in lv.W:
			if not lv.visited_rooms.has(Vector2i(x / cs.x, y / cs.y)):
				img.set_pixel(x, y, Color("1a1826"))
	map_rect.texture = ImageTexture.create_from_image(img)
	scale_f = map_px / float(maxi(lv.W, lv.H))
	map_rect.size = Vector2(lv.W, lv.H) * scale_f
	overlay.size = map_rect.size
	side.add_child(UI.label(lv.design.get("name", "Dungeon"), 18, Color("ffe9a8")))
	side.add_child(UI.label("Rank %d • %s" % [int(lv.design.get("rank", 1)), GameData.DUNGEON_BIOMES[lv.design.get("biome", "cave")]["name"]], 14, UI.DIM))
	side.add_child(UI.label("Rooms explored: %d / %d" % [lv.visited_rooms.size(), lv.design["rooms"].size()], 14))
	side.add_child(UI.rich("[color=#9c97b8]The boss waits in the room farthest from the entrance. Clear the boss to claim its unique treasure. The exit portal is in the starting room.[/color]", 13))


func _draw_overlay() -> void:
	var lv = Game.level_node
	if lv == null or lv.player == null:
		return
	var font := get_theme_default_font()
	if lv is Overworld:
		var town := Vector2(256, 256) * scale_f
		overlay.draw_rect(Rect2(town - Vector2(6, 6), Vector2(12, 12)), Color("fee761"), false, 2.0)
		overlay.draw_string(font, town + Vector2(9, 4), "Hollowgate", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("fee761"))
		for d in Game.world["dungeons"]:
			var p := Vector2(d["tile"][0], d["tile"][1]) * scale_f
			var col := Portal.rank_color(int(d["rank"]))
			var pts := PackedVector2Array([p + Vector2(0, -6), p + Vector2(5, 0), p + Vector2(0, 6), p + Vector2(-5, 0)])
			overlay.draw_colored_polygon(pts, col)
			overlay.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color.BLACK, 1.0)
			if d.get("custom", false):
				overlay.draw_arc(p, 8.0, 0, TAU, 16, Color("c79bff"), 1.5)
		var lf: Array = Game.player.get("last_field", [])
		if lf.size() == 2:
			var wp := Vector2(lf[0], lf[1]) / 16.0 * scale_f
			overlay.draw_circle(wp, 3.0, Color("8fe8ff"))
		var pp: Vector2 = lv.player.global_position / 16.0 * scale_f
		var a: float = lv.player.aim.angle()
		overlay.draw_colored_polygon(PackedVector2Array([pp + Vector2.from_angle(a) * 8.0, pp + Vector2.from_angle(a + 2.5) * 5.0, pp + Vector2.from_angle(a - 2.5) * 5.0]), Color("7be0ff"))
		overlay.draw_arc(pp, 9.0, 0, TAU, 16, Color(1, 1, 1, 0.6), 1.0)
	elif lv is DungeonLevel:
		var pp2: Vector2 = lv.player.global_position / 16.0 * scale_f
		overlay.draw_circle(pp2, 4.0, Color("7be0ff"))
		var sc = lv.room_center_px(lv.start_cell) / 16.0 * scale_f
		overlay.draw_string(font, sc, "Exit", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color("8fe8ff"))
		if lv.visited_rooms.has(lv.boss_cell):
			var bc = lv.room_center_px(lv.boss_cell) / 16.0 * scale_f
			overlay.draw_string(font, bc, "BOSS", HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color("ff6a6a"))


func _overlay_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Game.level_node is Overworld:
		var mp: Vector2 = e.position
		var best: Dictionary = {}
		for d in Game.world["dungeons"]:
			var p := Vector2(d["tile"][0], d["tile"][1]) * scale_f
			if p.distance_to(mp) < 8.0:
				best = d
		if not best.is_empty():
			var left := float(best["expires"]) - float(Game.world["total"])
			var nm: String = best.get("name", "Custom Dungeon") if best.get("custom", false) else "%s Dungeon" % GameData.DUNGEON_BIOMES[best["biome"]]["name"]
			Game.main.tooltip.show_text("[b]%s[/b]\nRank [color=#%s]%d[/color]\n%s" % [nm, Portal.rank_color(int(best["rank"])).to_html(false), int(best["rank"]),
				"Permanent (custom)" if best.get("custom", false) else "Disappears in " + UI.fmt_time(left)], 220)
		else:
			Game.main.tooltip.hide_tip()
