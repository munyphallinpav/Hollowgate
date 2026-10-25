class_name DungeonEditor
extends GameWindow
## Custom dungeon editor.
## Quick Setup: pick options and generate.  Room Builder: drag & drop rooms, doors, start/boss,
## monsters, traps, spawners, treasure (random in room or pinned to a tile) and paint walls/cliffs/water/lava.
## Free to edit; Test Run lets you try it; Create Crystal gives an item that raises it in the world.

const BIOME_COL := {"lava": Color("8a3a2a"), "forest": Color("3a6a3a"), "mushroom": Color("5a4a78"), "grass": Color("5a8a3a"),
	"beach": Color("b8a070"), "cave": Color("4a4a5a")}
const TERRAIN_COL := {"wall": Color("8b8b9b"), "cliff": Color("0c0a14"), "water": Color("3a8ad8"), "lava": Color("f77622")}

var design: Dictionary = {}
var design_idx := -1
var opts: Dictionary = {}
var mode := "quick"
var selected_room := Vector2i(-1, -1)
var grid_tool := "select"
var paint_tool := "wall"
var paint_style := ""
var status_lbl: RichTextLabel
var top_box: HBoxContainer
var top_box2: HBoxContainer
var page: Control
var design_opt: OptionButton
var grid_canvas: Control
var room_canvas: Control
var room_props: VBoxContainer
var room_list: VBoxContainer


# ------------------------------------------------------------------ inner widgets
class PaletteItem extends PanelContainer:
	var cat := ""
	var id := ""
	var ed

	func _init(c: String, i: String, editor, tex: Texture2D, label: String) -> void:
		cat = c
		id = i
		ed = editor
		custom_minimum_size = Vector2(92, 58)
		add_theme_stylebox_override("panel", UI.sbox(Color("201f36"), Color("4a4568"), 1, 3, 3))
		var v := UI.vbox(0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(v)
		var ic := UI.icon(tex, 34)
		v.add_child(ic)
		var l := UI.label(label, 10, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		l.clip_text = true
		l.custom_minimum_size.x = 78
		v.add_child(l)
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = ""
		mouse_entered.connect(func(): Game.main.tooltip.show_text("[b]%s[/b]\n%s\n[color=#9c97b8]Drag onto a room (random spot) or onto a tile in the room view (pinned). Click to add to the selected room.[/color]" % [label, ed.palette_desc(cat, id)], 260))
		mouse_exited.connect(func(): Game.main.tooltip.hide_tip())

	func _get_drag_data(_p):
		var pv := Control.new()
		var ic := UI.icon(get_child(0).get_child(0).texture, 34)
		ic.position = Vector2(-17, -17)
		pv.add_child(ic)
		set_drag_preview(pv)
		Game.main.tooltip.hide_tip()
		return {"type": "palette", "cat": cat, "id": id}

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and not e.double_click:
			pass
		if e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			ed.add_to_room(ed.selected_room, cat, id, null)


class GridCanvas extends Control:
	var ed
	var CW := 46.0
	var CH := 34.0
	var hover := Vector2i(-1, -1)
	const AREA := Vector2(388, 292)

	func _init(editor) -> void:
		ed = editor
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = AREA
		mouse_exited.connect(func():
			hover = Vector2i(-1, -1)
			queue_redraw())

	## Cell size adapts to the grid so small grids get big, easy-to-click cells.
	func _fit() -> void:
		var g: Vector2i = ed.design.get("grid", Vector2i(4, 4))
		CW = floorf(minf(minf(AREA.x / g.x, AREA.y * 1.4 / g.y), 96.0))
		CH = floorf(CW / 1.4)

	func cell_at(p: Vector2) -> Vector2i:
		_fit()
		return Vector2i(int(floor(p.x / CW)), int(floor(p.y / CH)))

	func _draw() -> void:
		var d: Dictionary = ed.design
		if d.is_empty():
			return
		_fit()
		var g: Vector2i = d["grid"]
		var font := get_theme_default_font()
		draw_rect(Rect2(Vector2.ZERO, AREA), Color("0b0a14"))
		for y in g.y:
			for x in g.x:
				var r := Rect2(x * CW + 2, y * CH + 2, CW - 4, CH - 4)
				draw_rect(r, Color("12111f"))
				draw_rect(r, Color("2c2a48") if Vector2i(x, y) != hover else Color("6a6494"), false, 1.0)
				if Vector2i(x, y) == hover and not d["rooms"].has(hover) and ed.grid_tool == "room":
					draw_string(font, r.position + Vector2(0, r.size.y / 2.0 + 6), "+", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, Color("7be05a"))
		for c in d["rooms"]:
			var room: Dictionary = d["rooms"][c]
			var b: String = room.get("biome", "")
			if b == "":
				b = d.get("biome", "cave")
			var sc = {"small": 0.62, "medium": 0.8, "large": 0.96}.get(room.get("size", "medium"), 0.8)
			var center := Vector2(c.x * CW + CW / 2.0, c.y * CH + CH / 2.0)
			var rs = Vector2(CW - 8, CH - 8) * sc
			var r2 := Rect2(center - rs / 2.0, rs)
			draw_rect(r2, ed.BIOME_COL.get(b, Color.GRAY))
			var bc := Color("fee761") if c == ed.selected_room else Color(0, 0, 0, 0.6)
			draw_rect(r2, bc, false, 2.0 if c == ed.selected_room else 1.0)
			for dn in ["e", "s"]:
				if room["doors"].get(dn, false):
					var nb: Vector2i = c + DungeonGen.DIRS[dn]
					if d["rooms"].has(nb):
						var a := center
						var bpt := Vector2(nb.x * CW + CW / 2.0, nb.y * CH + CH / 2.0)
						draw_line(a + (bpt - a) * 0.3, a + (bpt - a) * 0.7, Color("e8d8a8"), 5.0)
			var tag := ""
			if c == d.get("start", Vector2i(-9, -9)):
				tag = "START"
			elif c == d.get("boss_room", Vector2i(-9, -9)):
				tag = "BOSS"
			var fs := int(clampf(CW / 5.0, 10.0, 15.0))
			if tag != "":
				draw_string_outline(font, center + Vector2(-CW / 2.0, 2), tag, HORIZONTAL_ALIGNMENT_CENTER, CW, fs, 4, Color.BLACK)
				draw_string(font, center + Vector2(-CW / 2.0, 2), tag, HORIZONTAL_ALIGNMENT_CENTER, CW, fs, Color("7be05a") if tag == "START" else Color("ff6a6a"))
			var cnt := 0
			for m in room.get("monsters", []):
				cnt += int(m.get("count", 1))
			var info := "%dm %dt" % [cnt, room.get("traps", []).size()]
			if room.get("treasures", []).size() > 0:
				info += " %dc" % room["treasures"].size()
			if room.get("miniboss", "") != "":
				info += " M"
			var ip := Vector2(r2.position.x - 4.0, r2.end.y - 3.0)
			draw_string_outline(font, ip, info, HORIZONTAL_ALIGNMENT_CENTER, r2.size.x + 8.0, fs - 2, 3, Color(0, 0, 0, 0.8))
			draw_string(font, ip, info, HORIZONTAL_ALIGNMENT_CENTER, r2.size.x + 8.0, fs - 2, Color(1, 1, 1, 0.85))

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseMotion:
			var hc := cell_at(e.position)
			if hc != hover:
				hover = hc
				queue_redraw()
			return
		if not (e is InputEventMouseButton and e.pressed):
			return
		if e.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			return
		var d: Dictionary = ed.design
		var g: Vector2i = d["grid"]
		var c := cell_at(e.position)
		if c.x < 0 or c.y < 0 or c.x >= g.x or c.y >= g.y:
			return
		if e.button_index == MOUSE_BUTTON_RIGHT:
			if d["rooms"].has(c):
				ed.remove_room(c)
			return
		match ed.grid_tool:
			"room":
				if d["rooms"].has(c):
					ed.remove_room(c)
				else:
					ed.add_room(c)
			"door":
				var local = e.position - Vector2(c.x * CW, c.y * CH)
				var dn := ""
				var fx = local.x / CW
				var fy = local.y / CH
				var dl := minf(minf(fx, 1.0 - fx), minf(fy, 1.0 - fy))
				if dl == fx:
					dn = "w"
				elif dl == 1.0 - fx:
					dn = "e"
				elif dl == fy:
					dn = "n"
				else:
					dn = "s"
				ed.toggle_door(c, dn)
			"start":
				if d["rooms"].has(c):
					d["start"] = c
			"boss":
				if d["rooms"].has(c):
					d["boss_room"] = c
			_:
				pass
		if d["rooms"].has(c):
			ed.select_room(c)
		ed.refresh_builder()

	func _can_drop_data(p, data) -> bool:
		return data is Dictionary and data.get("type", "") == "palette" and ed.design["rooms"].has(cell_at(p))

	func _drop_data(p, data) -> void:
		var c := cell_at(p)
		ed.select_room(c)
		ed.add_to_room(c, data["cat"], data["id"], null)


class RoomCanvas extends Control:
	var ed
	var TS := 18.0
	var painting := false
	var hover := Vector2i(-1, -1)
	const AREA := Vector2(446, 304)
	var _tex: Dictionary = {}

	func _init(editor) -> void:
		ed = editor
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = AREA
		mouse_exited.connect(func():
			hover = Vector2i(-1, -1)
			queue_redraw())

	func dims() -> Vector2i:
		if not ed.design["rooms"].has(ed.selected_room):
			return Vector2i.ZERO
		return DungeonGen.room_dims(ed.design["rooms"][ed.selected_room])

	## Tile size adapts to the room size (small rooms get bigger tiles).
	func _fit() -> void:
		var d := dims()
		if d == Vector2i.ZERO:
			return
		TS = floorf(minf(minf((AREA.x - 8.0) / d.x, (AREA.y - 8.0) / d.y), 36.0))

	func offset() -> Vector2:
		_fit()
		var d := dims()
		return ((AREA - Vector2(d.x, d.y) * TS) * 0.5).floor()

	func tile_at(p: Vector2) -> Vector2i:
		var o := offset()
		return Vector2i(int(floor((p.x - o.x) / TS)), int(floor((p.y - o.y) / TS)))

	## Real 16x16 tile art (floors per biome, each wall style, water, lava, pits) for the room preview.
	func _tile_tex(name: String) -> Texture2D:
		if not _tex.has(name):
			var img: Image = Art.tile(name)
			_tex[name] = ImageTexture.create_from_image(img) if img else null
		return _tex[name]

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, AREA), Color("0b0a14"))
		var d := dims()
		if d == Vector2i.ZERO:
			draw_string(get_theme_default_font(), Vector2(20, 40), "Select a room in the grid", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI.DIM)
			return
		var room: Dictionary = ed.design["rooms"][ed.selected_room]
		var b: String = room.get("biome", "")
		if b == "":
			b = ed.design.get("biome", "cave")
		var floor_n: String = GameData.DUNGEON_BIOMES.get(b, GameData.DUNGEON_BIOMES["cave"])["floor"]
		var liquid: String = GameData.DUNGEON_BIOMES.get(ed.design.get("biome", "cave"), GameData.DUNGEON_BIOMES["cave"])["liquid"]
		var def_style: String = ed.design.get("wall", "stone")
		var styles: Dictionary = room.get("tile_styles", {})
		var fc: Color = ed.BIOME_COL.get(b, Color.GRAY)
		var o := offset()
		for y in d.y:
			for x in d.x:
				var r := Rect2(o + Vector2(x, y) * TS, Vector2(TS, TS))
				var p := Vector2i(x, y)
				var t: String = room["tiles"].get(p, "")
				var tn := "%s_%d" % [floor_n, TileRenderer.vhash(x, y, 3) % 4]
				match t:
					"wall":
						var below: String = room["tiles"].get(p + Vector2i(0, 1), "")
						tn = "wall_%s_%s" % [styles.get(p, def_style), "top" if below == "wall" else "front"]
					"water":
						tn = "swamp_water_0" if liquid == "swamp_water" else "water_0"
					"lava":
						tn = "lava_0"
					"cliff":
						tn = "pit_edge" if room["tiles"].get(p - Vector2i(0, 1), "") != "cliff" else "pit"
				var tx := _tile_tex(tn)
				if tx:
					draw_texture_rect(tx, r, false)
				else:
					draw_rect(r, ed.TERRAIN_COL.get(t, fc))
		var c := Vector2(d.x, d.y) * 0.5
		for dn in room["doors"]:
			if not room["doors"][dn]:
				continue
			var dv: Vector2i = DungeonGen.DIRS[dn]
			var pos := o + (c + Vector2(dv) * (Vector2(d.x, d.y) * 0.5)) * TS
			draw_rect(Rect2(pos - Vector2(TS * 1.5, TS * 1.5) * 0.5 - Vector2(dv) * 4.0, Vector2(TS * 1.5, TS * 1.5)), Color("e8d8a8"), false, 3.0)
		# grid lines
		for x in d.x + 1:
			draw_line(o + Vector2(x * TS, 0), o + Vector2(x * TS, d.y * TS), Color(0, 0, 0, 0.25), 1.0)
		for y in d.y + 1:
			draw_line(o + Vector2(0, y * TS), o + Vector2(d.x * TS, y * TS), Color(0, 0, 0, 0.25), 1.0)
		# pinned entities (icon keeps its aspect ratio, with a soft marker underneath)
		for cat in ["monsters", "traps", "spawners", "treasures"]:
			for ent in room.get(cat, []):
				if ent.get("pos") == null or not ent.has("pos"):
					continue
				var pp: Vector2i = ent["pos"]
				var tex: Texture2D = ed.palette_tex(cat, ent["type"])
				var cell := Rect2(o + Vector2(pp) * TS, Vector2(TS, TS))
				var mk: Color = {"monsters": Color(1, 0.35, 0.3, 0.35), "traps": Color(1, 0.8, 0.2, 0.35), "spawners": Color(0.7, 0.4, 1, 0.35),
					"treasures": Color(1, 0.9, 0.4, 0.35)}[cat]
				draw_circle(cell.get_center() + Vector2(0, TS * 0.25), TS * 0.42, mk)
				if tex:
					var ts := tex.get_size()
					var sc := minf((TS + 4.0) / ts.x, (TS + 4.0) / ts.y)
					var sz := ts * sc
					draw_texture_rect(tex, Rect2(cell.get_center() + Vector2(-sz.x / 2.0, TS / 2.0 - sz.y), sz), false)
		# hover cursor
		if hover.x >= 0 and hover.y >= 0 and hover.x < d.x and hover.y < d.y:
			draw_rect(Rect2(o + Vector2(hover) * TS, Vector2(TS, TS)), Color(1, 1, 1, 0.9), false, 2.0)
		if room.get("miniboss", "") != "":
			var f := get_theme_default_font()
			var mt: String = "Mini boss: " + GameData.MONSTERS[room["miniboss"]]["name"]
			draw_string_outline(f, Vector2(6, AREA.y - 6), mt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color.BLACK)
			draw_string(f, Vector2(6, AREA.y - 6), mt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("fee761"))

	var _last_paint := Vector2i(-99, -99)

	func _paint(p: Vector2, erase: bool) -> void:
		var t := tile_at(p)
		var d := dims()
		if t.x < 0 or t.y < 0 or t.x >= d.x or t.y >= d.y:
			return
		if t == _last_paint:
			return
		_last_paint = t
		var room: Dictionary = ed.design["rooms"][ed.selected_room]
		if erase or ed.paint_tool == "floor":
			room["tiles"].erase(t)
			room.get("tile_styles", {}).erase(t)
			# also unpin entities on that tile when erasing with right click
			if erase:
				for cat in ["monsters", "traps", "spawners", "treasures"]:
					var lst: Array = room.get(cat, [])
					for i in range(lst.size() - 1, -1, -1):
						if lst[i].get("pos") != null and lst[i].has("pos") and lst[i]["pos"] == t:
							lst.remove_at(i)
		else:
			room["tiles"][t] = ed.paint_tool
			if ed.paint_tool == "wall" and ed.paint_style != "":
				if not room.has("tile_styles"):
					room["tile_styles"] = {}
				room["tile_styles"][t] = ed.paint_style
			else:
				room.get("tile_styles", {}).erase(t)
		queue_redraw()
		ed.refresh_room_list()

	func _gui_input(e: InputEvent) -> void:
		if ed.design.is_empty() or not ed.design["rooms"].has(ed.selected_room):
			return
		if e is InputEventMouseButton:
			if e.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
				return
			if e.pressed:
				painting = true
				_last_paint = Vector2i(-99, -99)
				_paint(e.position, e.button_index == MOUSE_BUTTON_RIGHT)
			else:
				painting = false
		elif e is InputEventMouseMotion:
			var ht := tile_at(e.position)
			if ht != hover:
				hover = ht
				queue_redraw()
			if painting:
				_paint(e.position, (e.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0)

	func _can_drop_data(p, data) -> bool:
		if not (data is Dictionary and data.get("type", "") == "palette"):
			return false
		var t := tile_at(p)
		var d := dims()
		return t.x >= 0 and t.y >= 0 and t.x < d.x and t.y < d.y

	func _drop_data(p, data) -> void:
		ed.add_to_room(ed.selected_room, data["cat"], data["id"], tile_at(p))


# ------------------------------------------------------------------ setup
var mode_tabs: TabBar
var crystal_btn: Button


## Designing and test runs are free; imprinting a design into a Dungeon Crystal costs gold
## (it creates a real dungeon with real rewards in the world).
func crystal_cost() -> int:
	return 100 + int(design.get("rank", 1)) * 25


func _init() -> void:
	super._init("Dungeon Architect", Vector2(1200, 660), "editor")
	top_box = UI.hbox(6)
	body.add_child(top_box)
	var row2 := UI.hbox(8)
	body.add_child(row2)
	mode_tabs = TabBar.new()
	mode_tabs.add_tab("Quick Setup (options)")
	mode_tabs.add_tab("Room Builder (drag & drop)")
	mode_tabs.focus_mode = Control.FOCUS_NONE
	mode_tabs.clip_tabs = false
	mode_tabs.tab_changed.connect(func(i):
		var m := "quick" if i == 0 else "builder"
		if m != mode:
			mode = m
			_build_page())
	row2.add_child(mode_tabs)
	row2.add_child(UI.expand(Control.new()))
	top_box2 = UI.hbox(8)
	row2.add_child(top_box2)
	page = MarginContainer.new()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(page)
	status_lbl = UI.rich("", 14)
	body.add_child(status_lbl)


func _ready() -> void:
	if Game.designs.is_empty():
		_new_design()
	else:
		_load_design(0)
	_build_top()
	_build_page()


func _new_design() -> void:
	var rank := clampi(int(Game.player["level"]), 1, 100)
	opts = DungeonGen.default_options(rank, "cave")
	opts["name"] = "My Dungeon %d" % (Game.designs.size() + 1)
	design = DungeonGen.generate(opts)
	design["name"] = opts["name"]
	design["opts"] = opts.duplicate(true)
	Game.designs.append(design)
	design_idx = Game.designs.size() - 1
	selected_room = design["start"]


func _load_design(i: int) -> void:
	design_idx = i
	design = Game.designs[i]
	opts = design.get("opts", DungeonGen.default_options(int(design.get("rank", 1)), design.get("biome", "cave"))).duplicate(true)
	selected_room = design.get("start", Vector2i(-1, -1))


func _build_top() -> void:
	for c in top_box.get_children():
		c.queue_free()
	for c in top_box2.get_children():
		c.queue_free()
	design_opt = OptionButton.new()
	design_opt.focus_mode = Control.FOCUS_NONE
	for i in Game.designs.size():
		design_opt.add_item(str(Game.designs[i].get("name", "Design")))
	design_opt.selected = design_idx
	design_opt.item_selected.connect(func(i):
		_load_design(i)
		_build_top()
		_build_page())
	top_box.add_child(UI.label("Design:", 14, UI.DIM))
	top_box.add_child(design_opt)
	top_box.add_child(UI.button("New", func():
		_new_design()
		_build_top()
		_build_page()))
	top_box.add_child(UI.button("Copy", func():
		var cp := design.duplicate(true)
		cp["name"] = str(design.get("name", "Design")) + " copy"
		Game.designs.append(cp)
		_load_design(Game.designs.size() - 1)
		_build_top()
		_build_page()))
	top_box.add_child(UI.button("Rename", func():
		Dialogs.text_input(Game.main.menu_layer, "Dungeon name", str(design.get("name", "")), func(t):
			if t != "":
				design["name"] = t
				_build_top())))
	top_box.add_child(UI.button("Delete", func():
		Dialogs.confirm(Game.main.menu_layer, "Delete design", "Delete '%s'?" % design.get("name", ""), func():
			Game.designs.remove_at(design_idx)
			if Game.designs.is_empty():
				_new_design()
			else:
				_load_design(0)
			_build_top()
			_build_page(), "Delete")))
	top_box.add_child(UI.spacer(10))
	top_box.add_child(UI.label("Rank", 14, UI.DIM))
	var rk := SpinBox.new()
	rk.min_value = 1
	rk.max_value = 100
	rk.value = int(design.get("rank", 1))
	rk.value_changed.connect(func(v):
		design["rank"] = int(v)
		opts["rank"] = int(v)
		if crystal_btn and is_instance_valid(crystal_btn):
			crystal_btn.text = "Create Dungeon Crystal (%dg)" % crystal_cost()
		_validate(false))
	top_box.add_child(rk)
	top_box.add_child(UI.label("Biome", 14, UI.DIM))
	var bo := OptionButton.new()
	bo.focus_mode = Control.FOCUS_NONE
	var bkeys := GameData.DUNGEON_BIOMES.keys()
	for b in bkeys:
		bo.add_item(GameData.DUNGEON_BIOMES[b]["name"])
	bo.selected = bkeys.find(design.get("biome", "cave"))
	var wo := OptionButton.new()
	bo.item_selected.connect(func(i):
		design["biome"] = bkeys[i]
		design["wall"] = GameData.DUNGEON_BIOMES[bkeys[i]]["wall"]
		wo.selected = GameData.WorldData.WALL_STYLES.find(design["wall"])
		opts["biome"] = bkeys[i]
		_refresh_all()
		_validate(false))
	top_box.add_child(bo)
	top_box.add_child(UI.label("Walls", 14, UI.DIM))
	wo.focus_mode = Control.FOCUS_NONE
	for w in GameData.WorldData.WALL_STYLES:
		wo.add_item(w.capitalize())
	wo.selected = GameData.WorldData.WALL_STYLES.find(design.get("wall", "stone"))
	wo.item_selected.connect(func(i):
		design["wall"] = GameData.WorldData.WALL_STYLES[i]
		_refresh_all())
	top_box.add_child(wo)
	top_box2.add_child(UI.button("Validate", func(): _validate(true)))
	top_box2.add_child(UI.button("Test Run (free)", _test_run))
	crystal_btn = UI.button("Create Dungeon Crystal (%dg)" % crystal_cost(), _make_crystal)
	top_box2.add_child(crystal_btn)


func _refresh_all() -> void:
	if mode == "builder":
		refresh_builder()


func _build_page() -> void:
	if mode_tabs and mode_tabs.current_tab != (0 if mode == "quick" else 1):
		mode_tabs.current_tab = 0 if mode == "quick" else 1
	for c in page.get_children():
		c.queue_free()
	if mode == "quick":
		page.add_child(_quick_page())
	else:
		page.add_child(_builder_page())
	_validate(false)


# ------------------------------------------------------------------ quick setup
func _spin(label: String, key: String, mn: int, mx: int, parent: Container) -> void:
	var h := UI.hbox(6)
	var l := UI.label(label, 14)
	l.custom_minimum_size.x = 150
	h.add_child(l)
	var s := SpinBox.new()
	s.min_value = mn
	s.max_value = mx
	s.value = int(opts.get(key, mn))
	s.value_changed.connect(func(v): opts[key] = int(v))
	h.add_child(s)
	parent.add_child(h)


func _slide(label: String, key: String, mx: float, parent: Container) -> void:
	var h := UI.hbox(6)
	var l := UI.label(label, 14)
	l.custom_minimum_size.x = 150
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = mx
	s.step = 0.1
	s.value = float(opts.get(key, 1.0))
	s.custom_minimum_size.x = 180
	var vl := UI.label("%.1f" % s.value, 13, UI.DIM)
	s.value_changed.connect(func(v):
		opts[key] = v
		vl.text = "%.1f" % v)
	h.add_child(s)
	h.add_child(vl)
	parent.add_child(h)


func _quick_page() -> Control:
	var h := UI.hbox(20)
	var c1 := UI.vbox(6)
	h.add_child(c1)
	c1.add_child(UI.label("Layout", 16, Color("ffe9a8")))
	_spin("Grid width", "grid_w", 2, 8, c1)
	_spin("Grid height", "grid_h", 2, 8, c1)
	_spin("Room count", "room_count", 2, 64, c1)
	var hs := UI.hbox(6)
	var lbs := UI.label("Room size", 14)
	lbs.custom_minimum_size.x = 150
	hs.add_child(lbs)
	var so := OptionButton.new()
	so.focus_mode = Control.FOCUS_NONE
	var sizes := ["random", "small", "medium", "large"]
	for s in sizes:
		so.add_item(s.capitalize())
	so.selected = sizes.find(opts.get("room_size", "random"))
	so.item_selected.connect(func(i): opts["room_size"] = sizes[i])
	hs.add_child(so)
	c1.add_child(hs)
	_slide("Terrain features", "terrain", 2.0, c1)
	c1.add_child(UI.sep())
	c1.add_child(UI.label("Bosses & Loot", 16, Color("ffe9a8")))
	var hb := UI.hbox(6)
	var lb := UI.label("Main boss", 14)
	lb.custom_minimum_size.x = 150
	hb.add_child(lb)
	var bo := OptionButton.new()
	bo.focus_mode = Control.FOCUS_NONE
	var mlist := ["random"]
	for m in GameData.MONSTERS:
		if GameData.MONSTERS[m].get("weight", 0) > 0 and not GameData.MONSTERS[m].get("passive", false):
			mlist.append(m)
	for m in mlist:
		bo.add_item("Random (fits biome)" if m == "random" else GameData.MONSTERS[m]["name"])
	bo.selected = maxi(0, mlist.find(opts.get("boss", "random")))
	bo.item_selected.connect(func(i): opts["boss"] = mlist[i])
	hb.add_child(bo)
	c1.add_child(hb)
	_spin("Mini bosses", "miniboss_count", 0, 10, c1)
	var hm := UI.hbox(6)
	var lm := UI.label("Mini boss type", 14)
	lm.custom_minimum_size.x = 150
	hm.add_child(lm)
	var mo := OptionButton.new()
	mo.focus_mode = Control.FOCUS_NONE
	for m in mlist:
		mo.add_item("Random" if m == "random" else GameData.MONSTERS[m]["name"])
	mo.selected = maxi(0, mlist.find(opts.get("miniboss", "random")))
	mo.item_selected.connect(func(i): opts["miniboss"] = mlist[i])
	hm.add_child(mo)
	c1.add_child(hm)
	_spin("Treasure chests", "treasures", 0, 30, c1)
	_spin("Seed", "seed", 0, 999999, c1)
	var c2 := UI.vbox(6)
	h.add_child(c2)
	c2.add_child(UI.label("Monsters that can appear", 16, Color("ffe9a8")))
	var mg := GridContainer.new()
	mg.columns = 3
	c2.add_child(mg)
	for m in mlist:
		if m == "random":
			continue
		var cb := CheckBox.new()
		cb.text = GameData.MONSTERS[m]["name"]
		cb.focus_mode = Control.FOCUS_NONE
		cb.button_pressed = m in opts.get("monsters", [])
		var mm: String = m
		cb.toggled.connect(func(on):
			var arr: Array = opts.get("monsters", [])
			if on and not mm in arr:
				arr.append(mm)
			elif not on:
				arr.erase(mm)
			opts["monsters"] = arr)
		mg.add_child(cb)
	_slide("Monster density", "monster_density", 3.0, c2)
	_slide("Spawner devices", "spawner_density", 3.0, c2)
	var c3 := UI.vbox(6)
	h.add_child(c3)
	c3.add_child(UI.label("Traps", 16, Color("ffe9a8")))
	for t in GameData.WorldData.TRAPS:
		var cb2 := CheckBox.new()
		cb2.text = GameData.WorldData.TRAPS[t]["name"]
		cb2.focus_mode = Control.FOCUS_NONE
		cb2.button_pressed = t in opts.get("traps", [])
		var tt: String = t
		cb2.toggled.connect(func(on):
			var arr: Array = opts.get("traps", [])
			if on and not tt in arr:
				arr.append(tt)
			elif not on:
				arr.erase(tt)
			opts["traps"] = arr)
		c3.add_child(cb2)
	_slide("Trap density", "trap_density", 3.0, c3)
	c3.add_child(UI.sep())
	var gen_b := UI.button("Generate Dungeon", _generate, 240)
	gen_b.add_theme_font_size_override("font_size", 18)
	c3.add_child(gen_b)
	c3.add_child(UI.button("Randomize seed + Generate", func():
		opts["seed"] = randi() % 999999
		_generate(), 240))
	c3.add_child(UI.rich("[color=#9c97b8]Generating replaces the current layout. Switch to Room Builder to fine-tune rooms, doors and contents by hand.[/color]", 12))
	return h


func _generate() -> void:
	opts["rank"] = int(design.get("rank", 1))
	opts["biome"] = design.get("biome", "cave")
	opts["grid_w"] = clampi(int(opts["grid_w"]), 2, 8)
	opts["grid_h"] = clampi(int(opts["grid_h"]), 2, 8)
	opts["room_count"] = clampi(int(opts["room_count"]), 2, int(opts["grid_w"]) * int(opts["grid_h"]))
	if opts.get("monsters", []).is_empty():
		opts["monsters"] = GameData.DUNGEON_BIOMES[opts["biome"]]["monsters"].duplicate()
	var nd := DungeonGen.generate(opts)
	nd["name"] = design.get("name", "Dungeon")
	nd["wall"] = design.get("wall", nd["wall"])
	nd["opts"] = opts.duplicate(true)
	Game.designs[design_idx] = nd
	design = nd
	selected_room = design["start"]
	Game.toast("Dungeon generated: %d rooms." % design["rooms"].size(), UI.GOOD)
	_validate(false)


# ------------------------------------------------------------------ room builder
func _builder_page() -> Control:
	var h := UI.hbox(12)
	# ---- column 1: room grid + contents of the selected room
	var c1 := UI.vbox(6)
	c1.custom_minimum_size.x = 388
	h.add_child(c1)
	var tools := UI.hbox(4)
	c1.add_child(tools)
	var tool_tips := {"select": "Click a room to select it.", "room": "Click an empty cell to add a room, click a room to remove it.",
		"door": "Click near the edge of a room to open/close the door to its neighbour (up, down, left or right).",
		"start": "Click a room to make it the start (entrance) room.", "boss": "Click a room to make it the main boss room."}
	for t in [["select", "Select"], ["room", "+/- Room"], ["door", "Doors"], ["start", "Set Start"], ["boss", "Set Boss"]]:
		var tt: String = t[0]
		var b := UI.button(t[1], func():
			grid_tool = tt
			_build_page())
		b.toggle_mode = true
		b.button_pressed = grid_tool == tt
		b.tooltip_text = tool_tips[tt]
		b.add_theme_font_size_override("font_size", 13)
		tools.add_child(b)
	var gs := UI.hbox(6)
	c1.add_child(gs)
	gs.add_child(UI.label("Grid size", 13, UI.DIM))
	for axis in [0, 1]:
		var s := SpinBox.new()
		s.min_value = 2
		s.max_value = 8
		s.value = design["grid"].x if axis == 0 else design["grid"].y
		var ax: int = axis
		s.value_changed.connect(func(v): _resize_grid(ax, int(v)))
		gs.add_child(s)
		if axis == 0:
			gs.add_child(UI.label("x", 13, UI.DIM))
	gs.add_child(UI.spacer(8))
	gs.add_child(UI.label(tool_tips[grid_tool] if grid_tool != "select" else "Right-click removes a room.", 11, UI.DIM))
	grid_canvas = GridCanvas.new(self)
	c1.add_child(grid_canvas)
	c1.add_child(UI.label("Contents of the selected room", 13, Color("ffe9a8")))
	room_list = UI.vbox(2)
	var rl_scroll := UI.scroll(room_list, Vector2(388, 96))
	rl_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c1.add_child(rl_scroll)
	# ---- column 2: tile painter / pin view of the selected room
	var c2 := UI.vbox(6)
	h.add_child(c2)
	var paint := UI.hbox(4)
	c2.add_child(paint)
	paint.add_child(UI.label("Paint:", 13, UI.DIM))
	for t in [["floor", "Floor"], ["wall", "Wall"], ["cliff", "Cliff"], ["water", "Water"], ["lava", "Lava"]]:
		var tt2: String = t[0]
		var b2 := UI.button(t[1], func():
			paint_tool = tt2
			_build_page())
		b2.toggle_mode = true
		b2.button_pressed = paint_tool == tt2
		b2.add_theme_font_size_override("font_size", 13)
		paint.add_child(b2)
	var wst := OptionButton.new()
	wst.focus_mode = Control.FOCUS_NONE
	wst.add_item("Wall style: dungeon default")
	for w in GameData.WorldData.WALL_STYLES:
		wst.add_item("Wall style: " + w.capitalize())
	wst.selected = 0 if paint_style == "" else GameData.WorldData.WALL_STYLES.find(paint_style) + 1
	wst.item_selected.connect(func(i):
		paint_style = "" if i == 0 else GameData.WorldData.WALL_STYLES[i - 1]
		if paint_tool != "wall":
			paint_tool = "wall"
			_build_page())
	paint.add_child(wst)
	room_canvas = RoomCanvas.new(self)
	c2.add_child(room_canvas)
	room_props = UI.vbox(4)
	c2.add_child(room_props)
	c2.add_child(UI.rich("[color=#9c97b8]Left-drag paints, right-drag erases (and unpins). Drop a palette item on a [b]tile[/b] to pin it there, or on a [b]room in the grid[/b] (or click it) to place it at a random spot.[/color]", 12))
	# ---- column 3: palette
	var c3 := UI.vbox(4)
	h.add_child(c3)
	c3.add_child(UI.label("Palette  (drag & drop)", 15, Color("ffe9a8")))
	var pal := UI.vbox(4)
	var pal_scroll := UI.scroll(pal, Vector2(212, 440))
	pal_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c3.add_child(pal_scroll)
	for sec in [["Monsters", "monster"], ["Traps", "trap"], ["Spawning devices", "spawner"], ["Treasure", "treasure"]]:
		pal.add_child(UI.label(sec[0], 13, UI.DIM))
		var g := GridContainer.new()
		g.columns = 2
		pal.add_child(g)
		for id in palette_ids(sec[1]):
			g.add_child(PaletteItem.new(sec[1], id, self, palette_tex(sec[1] + "s", id), palette_name(sec[1], id)))
	refresh_builder()
	return h


func palette_ids(cat: String) -> Array:
	match cat:
		"monster":
			var a := []
			for m in GameData.MONSTERS:
				if GameData.MONSTERS[m].get("weight", 0) > 0 and not GameData.MONSTERS[m].get("passive", false):
					a.append(m)
			return a
		"trap":
			return GameData.WorldData.TRAPS.keys()
		"spawner":
			return GameData.WorldData.SPAWNERS.keys()
		"treasure":
			return GameData.WorldData.TREASURES.keys()
	return []


func palette_name(cat: String, id: String) -> String:
	match cat:
		"monster":
			return GameData.MONSTERS[id]["name"]
		"trap":
			return GameData.WorldData.TRAPS[id]["name"]
		"spawner":
			return GameData.WorldData.SPAWNERS[id]["name"]
		"treasure":
			return GameData.WorldData.TREASURES[id]["name"]
	return id


func palette_desc(cat: String, id: String) -> String:
	match cat:
		"monster":
			var m: Dictionary = GameData.MONSTERS[id]
			return "%s monster, %s element. Appears from level %d." % [m["ai"].capitalize(), m["el"].capitalize(), int(m["min_lv"])]
		"trap":
			return GameData.WorldData.TRAPS[id]["desc"]
		"spawner":
			return GameData.WorldData.SPAWNERS[id]["desc"]
	return "Holds gold, gear and materials scaled to the dungeon rank."


func palette_tex(cat: String, id: String) -> Texture2D:
	match cat:
		"monster", "monsters":
			var sf := Art.frames("mon_" + id)
			if sf.has_animation("idle"):
				return sf.get_frame_texture("idle", 0)
		"trap", "traps":
			return Art.obj(GameData.WorldData.TRAPS[id]["icon"])
		"spawner", "spawners":
			return Art.obj(GameData.WorldData.SPAWNERS[id]["icon"])
		"treasure", "treasures":
			return Art.obj(GameData.WorldData.TREASURES[id]["icon"])
	return null


func select_room(c: Vector2i) -> void:
	selected_room = c
	refresh_builder()


func refresh_builder() -> void:
	if grid_canvas == null or not is_instance_valid(grid_canvas):
		return
	grid_canvas.queue_redraw()
	room_canvas.queue_redraw()
	for ch in room_props.get_children():
		ch.queue_free()
	if design["rooms"].has(selected_room):
		var room: Dictionary = design["rooms"][selected_room]
		var h := UI.hbox(6)
		room_props.add_child(h)
		h.add_child(UI.label("Room %s" % str(selected_room), 13, Color("ffe9a8")))
		var so := OptionButton.new()
		so.focus_mode = Control.FOCUS_NONE
		var sizes := ["small", "medium", "large"]
		for s in sizes:
			so.add_item(s.capitalize())
		so.selected = sizes.find(room.get("size", "medium"))
		so.item_selected.connect(func(i):
			room["size"] = sizes[i]
			_clip_room(room)
			refresh_builder())
		h.add_child(so)
		var bo := OptionButton.new()
		bo.focus_mode = Control.FOCUS_NONE
		var bkeys := [""] + GameData.DUNGEON_BIOMES.keys()
		for b in bkeys:
			bo.add_item("Biome: dungeon default" if b == "" else "Biome: " + GameData.DUNGEON_BIOMES[b]["name"])
		bo.selected = maxi(0, bkeys.find(room.get("biome", "")))
		bo.item_selected.connect(func(i):
			room["biome"] = bkeys[i]
			refresh_builder())
		h.add_child(bo)
		var h2 := UI.hbox(6)
		room_props.add_child(h2)
		var mo := OptionButton.new()
		mo.focus_mode = Control.FOCUS_NONE
		var ml := [""] + palette_ids("monster")
		for m in ml:
			mo.add_item("Mini boss: none" if m == "" else "Mini boss: " + GameData.MONSTERS[m]["name"])
		mo.selected = maxi(0, ml.find(room.get("miniboss", "")))
		mo.item_selected.connect(func(i):
			room["miniboss"] = ml[i]
			refresh_builder())
		h2.add_child(mo)
		h2.add_child(UI.button("Clear room", func():
			for k in ["monsters", "traps", "spawners", "treasures"]:
				room[k] = []
			room["tiles"] = {}
			room["tile_styles"] = {}
			room["miniboss"] = ""
			refresh_builder()))
	refresh_room_list()
	_validate(false)


func refresh_room_list() -> void:
	if room_list == null or not is_instance_valid(room_list):
		return
	for ch in room_list.get_children():
		ch.queue_free()
	if not design["rooms"].has(selected_room):
		return
	var room: Dictionary = design["rooms"][selected_room]
	for cat in ["monsters", "traps", "spawners", "treasures"]:
		var lst: Array = room.get(cat, [])
		for i in lst.size():
			var ent: Dictionary = lst[i]
			var h := UI.hbox(4)
			h.add_child(UI.icon(palette_tex(cat, ent["type"]), 20))
			var pinned: bool = ent.has("pos") and ent.get("pos") != null
			var nm := palette_name(cat.trim_suffix("s"), ent["type"])
			var txt := "%s%s  %s" % [nm, (" x%d" % int(ent.get("count", 1))) if cat == "monsters" and not pinned else "", "(pinned %s)" % str(ent["pos"]) if pinned else "(random spot)"]
			var l := UI.label(txt, 12)
			l.custom_minimum_size.x = 260
			h.add_child(l)
			var cc: String = cat
			var ii: int = i
			if cat == "monsters" and not pinned:
				h.add_child(UI.button("-", func():
					var e2: Dictionary = room[cc][ii]
					e2["count"] = int(e2.get("count", 1)) - 1
					if int(e2["count"]) <= 0:
						room[cc].remove_at(ii)
					refresh_builder()))
				h.add_child(UI.button("+", func():
					room[cc][ii]["count"] = int(room[cc][ii].get("count", 1)) + 1
					refresh_builder()))
			if pinned:
				var ub := UI.button("Unpin", func():
					room[cc][ii].erase("pos")
					if cc == "monsters":
						room[cc][ii]["count"] = 1
					refresh_builder())
				ub.tooltip_text = "Place this at a random spot in the room instead"
				h.add_child(ub)
			h.add_child(UI.button("x", func():
				room[cc].remove_at(ii)
				refresh_builder()))
			room_list.add_child(h)
	if room_list.get_child_count() == 0:
		room_list.add_child(UI.label("Empty — drag monsters, traps, spawners or treasure from the palette.", 12, UI.DIM))


func add_to_room(c: Vector2i, cat: String, id: String, pos) -> void:
	if not design["rooms"].has(c):
		Game.toast("Select a room first.", UI.BAD)
		return
	var room: Dictionary = design["rooms"][c]
	var key: String = cat + "s"
	if not room.has(key):
		room[key] = []
	if pos != null:
		# remove whatever was pinned on that tile and clear terrain there
		for k in ["monsters", "traps", "spawners", "treasures"]:
			var lst: Array = room.get(k, [])
			for i in range(lst.size() - 1, -1, -1):
				if lst[i].has("pos") and lst[i].get("pos") != null and lst[i]["pos"] == pos:
					lst.remove_at(i)
		room["tiles"].erase(pos)
		room[key].append({"type": id, "pos": pos})
	else:
		var merged := false
		if cat == "monster":
			for ent in room[key]:
				if ent["type"] == id and not (ent.has("pos") and ent.get("pos") != null):
					ent["count"] = int(ent.get("count", 1)) + 1
					merged = true
					break
		if not merged:
			room[key].append({"type": id, "count": 1} if cat == "monster" else {"type": id})
	Sfx.play("click")
	refresh_builder()


func add_room(c: Vector2i) -> void:
	design["rooms"][c] = DungeonGen.empty_room("medium")
	# auto-connect to one existing neighbour so it is reachable
	for dn in DungeonGen.DIRS:
		var nb: Vector2i = c + DungeonGen.DIRS[dn]
		if design["rooms"].has(nb):
			toggle_door(c, dn)
			break
	if not design["rooms"].has(design.get("start", Vector2i(-9, -9))):
		design["start"] = c
	selected_room = c


func remove_room(c: Vector2i) -> void:
	design["rooms"].erase(c)
	for dn in DungeonGen.DIRS:
		var nb: Vector2i = c + DungeonGen.DIRS[dn]
		if design["rooms"].has(nb):
			design["rooms"][nb]["doors"][DungeonGen.OPP[dn]] = false
	if selected_room == c:
		selected_room = Vector2i(-1, -1)
	refresh_builder()


func toggle_door(c: Vector2i, dn: String) -> void:
	var nb: Vector2i = c + DungeonGen.DIRS[dn]
	if not design["rooms"].has(c) or not design["rooms"].has(nb):
		return
	var on: bool = not design["rooms"][c]["doors"].get(dn, false)
	design["rooms"][c]["doors"][dn] = on
	design["rooms"][nb]["doors"][DungeonGen.OPP[dn]] = on


func _clip_room(room: Dictionary) -> void:
	var d := DungeonGen.room_dims(room)
	for k in room["tiles"].keys():
		if k.x >= d.x or k.y >= d.y:
			room["tiles"].erase(k)
	for cat in ["monsters", "traps", "spawners", "treasures"]:
		for ent in room.get(cat, []):
			if ent.has("pos") and ent.get("pos") != null and (ent["pos"].x >= d.x or ent["pos"].y >= d.y):
				ent.erase("pos")


func _resize_grid(axis: int, v: int) -> void:
	var g: Vector2i = design["grid"]
	if axis == 0:
		g.x = v
	else:
		g.y = v
	design["grid"] = g
	for c in design["rooms"].keys():
		if c.x >= g.x or c.y >= g.y:
			remove_room(c)
	refresh_builder()


# ------------------------------------------------------------------ actions
func _validate(show_ok: bool) -> bool:
	if design.get("boss", "") == "" or not GameData.MONSTERS.has(design.get("boss", "")):
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		design["boss"] = DungeonGen.pick_boss(design.get("biome", "cave"), int(design.get("rank", 1)), rng)
	var err := DungeonGen.validate(design)
	var boss_name: String = GameData.MONSTERS.get(design.get("boss", ""), {}).get("name", "?")
	if err != "":
		status_lbl.text = "[color=#ff8a8a]Problem: %s[/color]" % err
		return false
	var mons := 0
	var traps := 0
	for c in design["rooms"]:
		for m in design["rooms"][c].get("monsters", []):
			mons += int(m.get("count", 1))
		traps += design["rooms"][c].get("traps", []).size()
	status_lbl.text = "[color=#7be05a]%s[/color]  %d rooms • %d monsters • %d traps • Boss: %s • Rank %d %s" % [
		"Valid!" if show_ok else "OK", design["rooms"].size(), mons, traps, boss_name, int(design.get("rank", 1)), GameData.DUNGEON_BIOMES[design.get("biome", "cave")]["name"]]
	return true


func _test_run() -> void:
	if not _validate(true):
		return
	Game.main.start_test_run(design.duplicate(true))


func _make_crystal() -> void:
	if not _validate(true):
		return
	var cost := crystal_cost()
	if int(Game.player["gold"]) < cost:
		Game.toast("Creating this Dungeon Crystal costs %d gold." % cost, UI.BAD)
		Sfx.play("error")
		return
	if Game.free_slots() <= 0:
		Game.toast("Your bag is full.", UI.BAD)
		return
	var it := Items.stack("dungeon_crystal", 1)
	it["design"] = design.duplicate(true)
	it["design"].erase("opts")
	if Game.add_item(it):
		Game.add_gold(-cost)
		Game.toast("Created a Dungeon Crystal for '%s' (-%dg). Use it out in the wild to raise the dungeon!" % [design.get("name", ""), cost], Color("c79bff"))
		Sfx.play("magic")
	else:
		Game.toast("Your bag is full.", UI.BAD)
