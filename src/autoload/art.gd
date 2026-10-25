extends Node
## Loads generated sprite sheets (see tools/art) and serves textures / SpriteFrames.

var manifest: Dictionary = {}
var _frames_cache: Dictionary = {}
var _tex_cache: Dictionary = {}
var _icon_cache: Dictionary = {}
var tile_image: Image
var tile_index: Dictionary = {}
var tile_priority: Dictionary = {}
var _tile_img_cache: Dictionary = {}


func _ready() -> void:
	manifest = preload("res://assets/data/art_manifest.gd").DATA
	var t: Dictionary = manifest.get("tiles", {})
	if not t.is_empty():
		var tex: Texture2D = load(t["path"])
		tile_image = tex.get_image()
		if tile_image.is_compressed():
			tile_image.decompress()
		tile_image.convert(Image.FORMAT_RGBA8)
		tile_index = t["index"]
		tile_priority = t["priority"]


func tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]


## SpriteFrames for "char_<name>" or "mon_<name>"
func frames(key: String) -> SpriteFrames:
	if _frames_cache.has(key):
		return _frames_cache[key]
	var m: Dictionary = manifest.get(key, {})
	var sf := SpriteFrames.new()
	if m.is_empty():
		push_warning("Missing sprite sheet " + key)
		_frames_cache[key] = sf
		return sf
	var sheet := tex(m["path"])
	var fw: int = m["frame_w"]
	var fh: int = m["frame_h"]
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for anim in m["anims"]:
		var a: Dictionary = m["anims"][anim]
		sf.add_animation(anim)
		sf.set_animation_speed(anim, a["fps"])
		sf.set_animation_loop(anim, a["loop"])
		for i in int(a["count"]):
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(i * fw, int(a["row"]) * fh, fw, fh)
			sf.add_frame(anim, at)
	_frames_cache[key] = sf
	return sf


func frame_size(key: String) -> Vector2i:
	var m: Dictionary = manifest.get(key, {})
	if m.is_empty():
		return Vector2i(32, 32)
	return Vector2i(m["frame_w"], m["frame_h"])


func obj(name: String) -> Texture2D:
	var m: Dictionary = manifest.get("objects", {}).get(name, {})
	if m.is_empty():
		return null
	return tex(m["path"])


func weapon(name: String) -> Texture2D:
	var m: Dictionary = manifest.get("weapons", {}).get(name, {})
	if m.is_empty():
		return null
	return tex(m["path"])


func fx(name: String) -> Texture2D:
	var m: Dictionary = manifest.get("fx", {}).get(name, {})
	if m.is_empty():
		return null
	return tex(m["path"])


func _atlas_icon(group: String, name: String) -> Texture2D:
	var key := group + ":" + name
	if _icon_cache.has(key):
		return _icon_cache[key]
	var g: Dictionary = manifest.get(group, {})
	if g.is_empty() or not g["index"].has(name):
		return null
	var at := AtlasTexture.new()
	at.atlas = tex(g["path"])
	var s: int = g["size"]
	var c: Array = g["index"][name]
	at.region = Rect2(int(c[0]) * s, int(c[1]) * s, s, s)
	_icon_cache[key] = at
	return at


func icon(name: String) -> Texture2D:
	var t := _atlas_icon("item_icons", name)
	if t == null:
		t = _atlas_icon("item_icons", "quest")
	return t


func glyph(name: String) -> Texture2D:
	var t := _atlas_icon("glyphs", name)
	if t == null:
		t = _atlas_icon("glyphs", "star")
	return t


## Returns a 16x16 Image for a named tile ("grass_2", "wall_stone_top"...)
func tile(name: String) -> Image:
	if _tile_img_cache.has(name):
		return _tile_img_cache[name]
	if not tile_index.has(name):
		return null
	var c: Array = tile_index[name]
	var img := tile_image.get_region(Rect2i(int(c[0]) * 16, int(c[1]) * 16, 16, 16))
	_tile_img_cache[name] = img
	return img


func has_tile(name: String) -> bool:
	return tile_index.has(name)
