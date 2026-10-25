class_name TileRenderer
extends RefCounted
## Builds ground textures from terrain grids, with soft fringe transitions between terrains,
## 2.5D wall faces, pits and decoration overlays.

const T := 16
const DIRS := {"n": Vector2i(0, -1), "s": Vector2i(0, 1), "w": Vector2i(-1, 0), "e": Vector2i(1, 0),
	"nw": Vector2i(-1, -1), "ne": Vector2i(1, -1), "sw": Vector2i(-1, 1), "se": Vector2i(1, 1)}


static func vhash(x: int, y: int, s: int = 0) -> int:
	var h := (x * 374761393 + y * 668265263 + s * 2147483647) & 0x7fffffff
	h = (h ^ (h >> 13)) * 1274126177
	return (h ^ (h >> 16)) & 0x7fffffff


## terrain_at: Callable(x, y) -> String (terrain name or "wall", "pit", "void")
## deco_at: Callable(x, y) -> String ("" for none)
static func render(x0: int, y0: int, w: int, h: int, terrain_at: Callable, deco_at: Callable = Callable(), wall_style: String = "stone") -> Image:
	var img := Image.create_empty(w * T, h * T, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.03, 0.02, 0.05))
	var pri: Dictionary = Art.tile_priority
	# cache terrain incl. 1-tile border
	var cache := {}
	for yy in range(y0 - 1, y0 + h + 1):
		for xx in range(x0 - 1, x0 + w + 1):
			cache[Vector2i(xx, yy)] = terrain_at.call(xx, yy)
	var src := Rect2i(0, 0, T, T)
	for yy in range(y0, y0 + h):
		for xx in range(x0, x0 + w):
			var ter: String = cache[Vector2i(xx, yy)]
			var dst := Vector2i((xx - x0) * T, (yy - y0) * T)
			if ter == "void":
				continue
			if ter.begins_with("wall"):
				var style := wall_style
				if ter.length() > 5 and ter[4] == ":":
					style = ter.substr(5)
				var below: String = cache.get(Vector2i(xx, yy + 1), "wall")
				var face := not below.begins_with("wall") and below != "void"
				var ti := Art.tile("wall_%s_%s" % [style, "front" if face else "top"])
				if ti:
					img.blit_rect(ti, src, dst)
				if not face:
					# outline wall tops where they meet open ground so walls read clearly
					var edge_dark := Color(0.06, 0.05, 0.09)
					var nb_n: String = cache.get(Vector2i(xx, yy - 1), "wall")
					var nb_w: String = cache.get(Vector2i(xx - 1, yy), "wall")
					var nb_e: String = cache.get(Vector2i(xx + 1, yy), "wall")
					if not nb_n.begins_with("wall") and nb_n != "void":
						img.fill_rect(Rect2i(dst.x, dst.y, T, 2), edge_dark)
					if not nb_w.begins_with("wall") and nb_w != "void":
						img.fill_rect(Rect2i(dst.x, dst.y, 2, T), edge_dark)
					if not nb_e.begins_with("wall") and nb_e != "void":
						img.fill_rect(Rect2i(dst.x + T - 2, dst.y, 2, T), edge_dark)
				continue
			if ter == "pit":
				var above: String = cache.get(Vector2i(xx, yy - 1), "pit")
				var ti2 := Art.tile("pit_edge" if above != "pit" and not above.begins_with("wall") and above != "void" else "pit")
				img.blit_rect(ti2, src, dst)
				continue
			var v := vhash(xx, yy) % 4
			var base := Art.tile("%s_%d" % [ter, v])
			if base == null:
				base = Art.tile("grass_0")
			img.blit_rect(base, src, dst)
			# fringes from higher-priority neighbours
			var my_p: int = pri.get(ter, 0)
			if ter.begins_with("df_"):
				continue
			var applied := {}
			for dname in ["n", "s", "w", "e"]:
				var nb: String = cache.get(Vector2i(xx, yy) + DIRS[dname], ter)
				if nb == ter or nb.begins_with("wall") or nb in ["pit", "void"] or nb.begins_with("df_"):
					continue
				if int(pri.get(nb, 0)) > my_p:
					var fr := Art.tile("fr_%s_%s" % [nb, dname])
					if fr:
						img.blend_rect(fr, src, dst)
						applied[nb + dname] = true
			for dname in ["nw", "ne", "sw", "se"]:
				var nb2: String = cache.get(Vector2i(xx, yy) + DIRS[dname], ter)
				if nb2 == ter or nb2.begins_with("wall") or nb2 in ["pit", "void"] or nb2.begins_with("df_"):
					continue
				if int(pri.get(nb2, 0)) > my_p:
					var a: String = dname.substr(0, 1)
					var b: String = dname.substr(1, 1)
					if applied.has(nb2 + a) or applied.has(nb2 + b):
						continue
					var fr2 := Art.tile("fr_%s_%s" % [nb2, dname])
					if fr2:
						img.blend_rect(fr2, src, dst)
			if deco_at.is_valid():
				var dc: String = deco_at.call(xx, yy)
				if dc != "":
					var di := Art.tile("deco_" + dc)
					if di:
						img.blend_rect(di, src, dst)
	return img


## Merge runs of blocked tiles into rectangles and add them as collision shapes to `body`.
static func add_collision(body: StaticBody2D, x0: int, y0: int, w: int, h: int, blocked: Callable, origin: Vector2 = Vector2.ZERO) -> void:
	for yy in range(y0, y0 + h):
		var run_start := -1
		for xx in range(x0, x0 + w + 1):
			var b: bool = xx < x0 + w and blocked.call(xx, yy)
			if b and run_start < 0:
				run_start = xx
			elif not b and run_start >= 0:
				var cs := CollisionShape2D.new()
				var rs := RectangleShape2D.new()
				rs.size = Vector2((xx - run_start) * T, T)
				cs.shape = rs
				cs.position = origin + Vector2((run_start + (xx - run_start) * 0.5) * T, (yy + 0.5) * T)
				body.add_child(cs)
				run_start = -1
