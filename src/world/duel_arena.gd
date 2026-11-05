extends Node2D
## The Duelling Grounds: a pocket dimension where duels are fought. A round stone platform floating in a
## starry void, built far outside the world map for the length of one duel (see Duel.start / Duel._leave_arena).
## An invisible barrier just past the ring keeps both duellists on the platform.

const VOID_HALF := 1000.0
const GOLD := Color(1.0, 0.82, 0.35)
const STONE := Color("4b4458")
const STONE_DARK := Color("3a3346")
const STONE_EDGE := Color("2a2434")
const UNDERSIDE := Color("1a1424")

var ring := 130.0    # the gold duelling line
var radius := 138.0  # the barrier (edge of the walkable platform)
var t := 0.0
var _stars: Array = []   # [pos, size, phase]
var _nebula: Array = []  # [pos, radius, color]
var _debris: Array = []  # [pos, size, phase]
var light: PointLight2D


static func create(level: Node, center: Vector2, ring_r: float, wall_r: float) -> Node2D:
	var a = (load("res://src/world/duel_arena.gd") as GDScript).new()
	a.position = center
	a.ring = ring_r
	a.radius = wall_r
	a.z_index = -19  # above the (absent) world ground, below every actor and effect
	a.name = "DuelArena"
	level.add_child(a)
	return a


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for i in 260:
		_stars.append([Vector2(rng.randf_range(-VOID_HALF, VOID_HALF), rng.randf_range(-VOID_HALF, VOID_HALF)),
			rng.randf_range(0.4, 1.5), rng.randf() * TAU])
	for i in 7:
		var hue := rng.randf_range(0.68, 0.86)
		_nebula.append([Vector2(rng.randf_range(-500, 500), rng.randf_range(-400, 400)), rng.randf_range(140, 320),
			Color.from_hsv(hue, 0.6, 0.55, 0.07)])
	for i in 14:
		var ang := rng.randf() * TAU
		_debris.append([Vector2.from_angle(ang) * rng.randf_range(radius + 40.0, radius + 150.0), rng.randf_range(3.0, 9.0), rng.randf() * TAU])
	_build_barrier()
	light = PointLight2D.new()
	light.texture = Art.fx("light")
	light.color = Color(1.0, 0.88, 0.62)
	if light.texture:
		light.texture_scale = radius * 3.0 / maxf(1.0, light.texture.get_width())
	light.energy = 0.0
	add_child(light)


func _build_barrier() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	var cs := CollisionShape2D.new()
	var sh := ConcavePolygonShape2D.new()
	var segs := PackedVector2Array()
	var n := 48
	for k in n:
		segs.append(Vector2.from_angle(k * TAU / n) * radius)
		segs.append(Vector2.from_angle((k + 1) * TAU / n) * radius)
	sh.segments = segs
	cs.shape = sh
	body.add_child(cs)
	add_child(body)


func _process(delta: float) -> void:
	t += delta
	var lv = Game.level_node
	if light and lv and lv.has_method("player_light_energy"):
		light.energy = 0.15 + 1.1 * float(lv.player_light_energy())
	queue_redraw()


func _draw() -> void:
	# the void
	draw_rect(Rect2(-VOID_HALF, -VOID_HALF, VOID_HALF * 2.0, VOID_HALF * 2.0), Color(0.03, 0.02, 0.06))
	for nb in _nebula:
		draw_circle(nb[0], nb[1], nb[2])
		draw_circle(nb[0], nb[1] * 0.6, nb[2])
	for s in _stars:
		var a: float = 0.35 + 0.45 * (0.5 + 0.5 * sin(t * 1.6 + float(s[2])))
		draw_circle(s[0], s[1], Color(0.85, 0.85, 1.0, a))
	# drifting rocks around the platform
	for d in _debris:
		var p: Vector2 = d[0] + Vector2(0, sin(t * 0.9 + d[2]) * 4.0)
		draw_circle(p + Vector2(0, d[1] * 0.6), d[1], UNDERSIDE)
		draw_circle(p, d[1], STONE_DARK)
	# the floating platform: underside (depth), rim, floor
	draw_circle(Vector2(0, 18), radius + 10.0, UNDERSIDE)
	draw_circle(Vector2(0, 9), radius + 10.0, STONE_EDGE)
	draw_circle(Vector2.ZERO, radius + 10.0, STONE_DARK)
	draw_circle(Vector2.ZERO, radius + 2.0, STONE)
	# flagstones: concentric bands and radial joints
	for r in [ring * 0.3, ring * 0.62, ring]:
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 72, STONE_DARK, 1.0)
	for k in 16:
		var dir := Vector2.from_angle(k * TAU / 16.0 + (TAU / 32.0 if k % 2 == 0 else 0.0))
		draw_line(dir * ring * 0.3, dir * ring * 0.62, STONE_DARK, 1.0)
	for k in 24:
		var dir2 := Vector2.from_angle(k * TAU / 24.0)
		draw_line(dir2 * ring * 0.62, dir2 * (radius + 2.0), STONE_DARK, 1.0)
	# centre sigil: a slowly turning star in a circle
	var sig := Color(GOLD.r, GOLD.g, GOLD.b, 0.35 + 0.15 * sin(t * 2.0))
	draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 40, sig, 1.5)
	var pts := PackedVector2Array()
	for k in 6:
		pts.append(Vector2.from_angle(t * 0.25 + k * TAU / 5.0 * 2.0) * 22.0)
	draw_polyline(pts, sig, 1.0)
	# starting marks
	for sx in [-50.0, 50.0]:
		draw_arc(Vector2(sx, 0), 7.0, 0.0, TAU, 16, Color(GOLD.r, GOLD.g, GOLD.b, 0.4), 1.0)
	# the duelling line
	var c := Color(GOLD.r, GOLD.g, GOLD.b, 0.6 + 0.25 * sin(t * 3.0))
	draw_arc(Vector2.ZERO, ring, 0.0, TAU, 96, c, 2.0)
	# braziers on the rim
	for k in 8:
		var bp := Vector2.from_angle(k * TAU / 8.0 + TAU / 16.0) * (radius + 5.0)
		draw_circle(bp, 4.0, STONE_EDGE)
		var fl := 2.4 + 0.8 * sin(t * 9.0 + k * 1.7)
		draw_circle(bp + Vector2(0, -2), fl, Color(1.0, 0.6, 0.2, 0.9))
		draw_circle(bp + Vector2(0, -2.5), fl * 0.5, Color(1.0, 0.95, 0.6))
	# the barrier: a faint shimmer at the platform's edge
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, Color(0.65, 0.55, 1.0, 0.2 + 0.12 * sin(t * 2.2)), 1.5)
