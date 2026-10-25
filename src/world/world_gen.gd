class_name WorldGen
extends RefCounted
## Deterministic overworld generation: biomes, terrain, resources, roads and the walled town.

const SIZE := 512
const CHUNK := 32
const CENTER := Vector2i(256, 256)
const TOWN_HALF := 26
const TOWN_MIN := Vector2i(230, 230)
const TOWN_MAX := Vector2i(281, 281)
const GATE_LO := 254
const GATE_HI := 257
const BLOCKED := ["water", "deep_water", "lava", "swamp_water"]

const MAP_COLORS := {
	"grass": Color("5aa04a"), "forest": Color("3f7f3c"), "sand": Color("e4c98a"), "desert": Color("d9a75a"),
	"snow": Color("e6eef6"), "swamp": Color("5b7a45"), "mushroom": Color("6e5a8a"), "ash": Color("4a4048"),
	"lava": Color("f77622"), "water": Color("3a8ad8"), "deep_water": Color("2560b0"), "dirt": Color("9a7050"),
	"cobble": Color("8f8f9c"), "plaza": Color("b8b0a0"), "wall": Color("5e5e70"), "swamp_water": Color("4f6b4a"),
}
const BIOME_DUNGEON := {"volcanic": "lava", "forest": "forest", "mushroom": "mushroom", "grass": "grass", "beach": "beach",
	"swamp": "mushroom", "snow": "cave", "desert": "cave"}

var seed_v := 1
var n_elev := FastNoiseLite.new()
var n_moist := FastNoiseLite.new()
var n_temp := FastNoiseLite.new()
var n_detail := FastNoiseLite.new()
var n_mush := FastNoiseLite.new()


func _init(s: int) -> void:
	seed_v = s
	for pair in [[n_elev, 0, 0.013], [n_moist, 1, 0.009], [n_temp, 2, 0.006], [n_detail, 3, 0.09], [n_mush, 4, 0.018]]:
		var n: FastNoiseLite = pair[0]
		n.seed = s + int(pair[1]) * 1013
		n.frequency = pair[2]
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = 3 if pair[1] != 3 else 1


func dist(tx: int, ty: int) -> float:
	return Vector2(tx - CENTER.x, ty - CENTER.y).length()


## Monster / dungeon level by distance from town. A gentle curve near the walls (Lv 1-5 within
## ~30 tiles of the gates, ~Lv 10 at 50 tiles) that steepens towards the edge of the world (Lv 100 at ~240 tiles).
func level_at(tx: int, ty: int) -> int:
	var f := clampf((dist(tx, ty) - 26.0) / 214.0, 0.0, 1.0)
	return clampi(int(1.0 + 99.0 * pow(f, 1.6)), 1, 100)


func in_town(tx: int, ty: int, margin: int = 0) -> bool:
	return tx >= TOWN_MIN.x - margin and tx <= TOWN_MAX.x + margin and ty >= TOWN_MIN.y - margin and ty <= TOWN_MAX.y + margin


func is_road(tx: int, ty: int) -> bool:
	var d := dist(tx, ty)
	if d > 95.0 or in_town(tx, ty):
		return false
	var wx := 256 + int(sin(ty * 0.05) * 3.0)
	var wy := 256 + int(sin(tx * 0.05 + 1.0) * 3.0)
	return (absi(tx - wx) <= 1 and (ty < TOWN_MIN.y or ty > TOWN_MAX.y)) or (absi(ty - wy) <= 1 and (tx < TOWN_MIN.x or tx > TOWN_MAX.x))


func biome_at(tx: int, ty: int) -> String:
	var d := dist(tx, ty)
	if d < 44.0:
		return "grass"
	var e := n_elev.get_noise_2d(tx, ty)
	var m := n_moist.get_noise_2d(tx, ty)
	var t := n_temp.get_noise_2d(tx, ty) + (d - 120.0) / 600.0
	var mu := n_mush.get_noise_2d(tx, ty)
	if d > 236.0:
		return "beach"
	if e > -0.36 and e < -0.26:
		if t < 0.3:
			return "beach"
	if d > 140.0 and t > 0.22:
		return "volcanic"
	if t > 0.28 and m < 0.05:
		return "desert"
	if t < -0.3:
		return "snow"
	if m > 0.3 and d > 70.0:
		return "swamp"
	if mu > 0.42 and d > 75.0:
		return "mushroom"
	if m > 0.02:
		return "forest"
	return "grass"


func town_terrain(tx: int, ty: int) -> String:
	var on_edge := tx == TOWN_MIN.x or tx == TOWN_MAX.x or ty == TOWN_MIN.y or ty == TOWN_MAX.y
	if on_edge:
		var gate := (tx >= GATE_LO and tx <= GATE_HI) or (ty >= GATE_LO and ty <= GATE_HI)
		return "cobble" if gate else "wall"
	if Vector2(tx - 255.5, ty - 255.5).length() < 7.0:
		return "plaza"
	if (tx >= GATE_LO and tx <= GATE_HI) or (ty >= GATE_LO and ty <= GATE_HI):
		return "cobble"
	if (ty == 244 or ty == 268) and tx > 233 and tx < 278:
		return "cobble"
	return "grass"


func terrain_at(tx: int, ty: int, biome: String = "") -> String:
	if tx < 0 or ty < 0 or tx >= SIZE or ty >= SIZE:
		return "deep_water"
	if in_town(tx, ty):
		return town_terrain(tx, ty)
	var d := dist(tx, ty)
	if d > 244.0:
		return "deep_water" if d > 249.0 else ("water" if d > 247.0 else "sand")
	if is_road(tx, ty):
		return "dirt"
	var e := n_elev.get_noise_2d(tx, ty)
	if d < 40.0:
		e = maxf(e, -0.2)
	var b := biome if biome != "" else biome_at(tx, ty)
	var det := n_detail.get_noise_2d(tx, ty)
	if e < -0.46:
		return "deep_water" if b != "volcanic" else "lava"
	if e < -0.36:
		return "water" if b != "volcanic" else "lava"
	match b:
		"grass":
			return "dirt" if det > 0.55 else "grass"
		"forest":
			return "grass" if det > 0.6 else "forest"
		"beach":
			return "sand"
		"swamp":
			return "swamp_water" if det > 0.5 else "swamp"
		"mushroom":
			return "mushroom"
		"snow":
			return "snow"
		"desert":
			return "sand" if det > 0.6 else "desert"
		"volcanic":
			return "lava" if det > 0.62 else "ash"
	return "grass"


func is_blocked(ter: String) -> bool:
	return ter in BLOCKED or ter == "wall"


func object_at(tx: int, ty: int, ter: String, biome: String = "") -> String:
	if in_town(tx, ty, 3) or is_blocked(ter) or ter in ["dirt", "cobble", "plaza"]:
		return ""
	var d := dist(tx, ty)
	if d > 242.0:
		return ""
	var h := TileRenderer.vhash(tx, ty, seed_v)
	var r := float(h % 10000) / 10000.0
	var b := biome if biome != "" else biome_at(tx, ty)
	var bd: Dictionary = GameData.BIOMES[b]
	var dens := float(bd["tree_density"]) * (0.35 if d < 40.0 else 1.0)
	if r < dens:
		var total := 0.0
		for k in bd["trees"]:
			total += float(bd["trees"][k])
		var pick := float(TileRenderer.vhash(tx, ty, seed_v + 7) % 1000) / 1000.0 * total
		for k in bd["trees"]:
			pick -= float(bd["trees"][k])
			if pick <= 0.0:
				return k
		return ""
	if r < dens + 0.006:
		var h2 := TileRenderer.vhash(tx, ty, seed_v + 11) % 100
		if h2 < 45:
			return "rock_small" if h2 < 30 else "rock_big"
		if b == "mushroom" and h2 < 75:
			return "ore_crystal"
		var lv := level_at(tx, ty)
		if lv < 12:
			return "ore_copper"
		if lv < 28:
			return "ore_iron" if h2 < 85 else "ore_copper"
		if lv < 45:
			return "ore_silver" if h2 < 85 else "ore_iron"
		if lv < 62:
			return "ore_gold" if h2 < 85 else "ore_silver"
		if lv < 80:
			return "ore_mithril" if h2 < 85 else "ore_gold"
		return "ore_adamantite" if h2 < 85 else "ore_mithril"
	return ""


func deco_at(tx: int, ty: int, ter: String, biome: String = "") -> String:
	if is_blocked(ter) or ter in ["cobble", "plaza", "dirt"]:
		return ""
	var h := TileRenderer.vhash(tx, ty, seed_v + 3) % 100
	if h >= 9:
		return ""
	var b := biome if biome != "" else (biome_at(tx, ty) if not in_town(tx, ty) else "grass")
	var decos: Array = GameData.BIOMES[b]["deco"]
	return decos[h % decos.size()]
