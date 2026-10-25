class_name FxNode
extends Node2D
## Procedurally drawn effect (slashes, rings, telegraphs, beams, pillars, swirls...).

var kind := "ring"
var dur := 0.3
var t := 0.0
var color := Color.WHITE
var radius := 20.0
var radius2 := 0.0
var arc := 120.0
var dir := Vector2.RIGHT
var width := 3.0
var length := 100.0
var follow: Node2D = null
var follow_offset := Vector2.ZERO
var loop := false
var fill := true
var seed_v := 0.0


func _ready() -> void:
	seed_v = randf() * 100.0


func _process(delta: float) -> void:
	t += delta
	if follow:
		if not is_instance_valid(follow):
			queue_free()
			return
		global_position = follow.global_position + follow_offset
	if t >= dur and not loop:
		queue_free()
		return
	queue_redraw()


func _p() -> float:
	return clampf(t / maxf(dur, 0.001), 0.0, 1.0)


func _draw() -> void:
	var p := _p()
	match kind:
		"slash":
			_draw_slash(p)
		"ring":
			var r := lerpf(radius2, radius, ease(p, 0.4))
			var c := color
			c.a *= 1.0 - p
			draw_arc(Vector2.ZERO, r, 0, TAU, 48, c, width * (1.0 - p * 0.5), false)
			if fill:
				var c2 := color
				c2.a *= 0.25 * (1.0 - p)
				draw_circle(Vector2.ZERO, r, c2)
		"ellipse_ring":
			var r2 := lerpf(radius2, radius, ease(p, 0.4))
			var c3 := color
			c3.a *= 1.0 - p
			_draw_ellipse_outline(r2, r2 * 0.55, c3, width)
		"disc":
			var c4 := color
			c4.a *= (1.0 - p) * (1.0 - p)
			draw_circle(Vector2.ZERO, radius * (0.7 + 0.3 * p), c4)
		"telegraph":
			# ground warning: outline + filling inner disc (ellipse for perspective)
			var c5 := color
			c5.a = 0.25 + 0.2 * sin(t * 18.0)
			_draw_ellipse_fill(radius, radius * 0.62, Color(color.r, color.g, color.b, 0.12))
			_draw_ellipse_fill(radius * p, radius * 0.62 * p, Color(color.r, color.g, color.b, 0.28))
			_draw_ellipse_outline(radius, radius * 0.62, Color(color.r, color.g, color.b, 0.85), 1.5)
		"line_tele":
			var c6 := color
			c6.a = 0.15 + 0.25 * p
			var n := dir.orthogonal() * width * 0.5
			draw_colored_polygon(PackedVector2Array([n, dir * length + n, dir * length - n, -n]), c6)
			draw_line(n, dir * length + n, Color(color.r, color.g, color.b, 0.8), 1.0)
			draw_line(-n, dir * length - n, Color(color.r, color.g, color.b, 0.8), 1.0)
		"beam":
			var a := 1.0 - p
			var w := width * (1.0 - p * 0.6)
			draw_line(Vector2.ZERO, dir * length, Color(color.r, color.g, color.b, 0.35 * a), w * 2.2)
			draw_line(Vector2.ZERO, dir * length, Color(color.r, color.g, color.b, 0.9 * a), w)
			draw_line(Vector2.ZERO, dir * length, Color(1, 1, 1, a), maxf(1.0, w * 0.35))
		"pillar":
			var a2 := 1.0 - p
			var w2 := width * (1.0 + 0.4 * sin(t * 30.0)) * (1.0 - p * 0.5)
			draw_rect(Rect2(-w2 * 1.6, -length, w2 * 3.2, length), Color(color.r, color.g, color.b, 0.25 * a2))
			draw_rect(Rect2(-w2 * 0.5, -length, w2, length), Color(color.r, color.g, color.b, 0.85 * a2))
			draw_rect(Rect2(-w2 * 0.2, -length, w2 * 0.4, length), Color(1, 1, 1, a2))
			_draw_ellipse_fill(w2 * 3.0, w2 * 1.2, Color(color.r, color.g, color.b, 0.5 * a2))
		"bubble":
			var pulse := 1.0 + 0.06 * sin(t * 6.0)
			draw_arc(Vector2(0, -radius * 0.6), radius * pulse, 0, TAU, 40, color, 1.5, false)
			draw_circle(Vector2(0, -radius * 0.6), radius * pulse, Color(color.r, color.g, color.b, color.a * 0.25))
			draw_arc(Vector2(-radius * 0.35, -radius * 1.0), radius * 0.25, PI, PI * 1.5, 8, Color(1, 1, 1, 0.8), 1.5)
		"aura":
			var a3 := 0.5 + 0.3 * sin(t * 5.0)
			_draw_ellipse_outline(radius + 2.0 * sin(t * 4.0), radius * 0.5, Color(color.r, color.g, color.b, a3), 1.5)
		"swirl", "tornado":
			_draw_tornado(p)
		"vortex":
			_draw_vortex(p)
		"sanctuary":
			_draw_sanctuary(p)
		"rain":
			_draw_rain(p)
		"cone":
			var a4 := (1.0 - p) * 0.5
			var pts := PackedVector2Array([Vector2.ZERO])
			var half := deg_to_rad(arc) * 0.5
			for i in 13:
				var ang := dir.angle() - half + half * 2.0 * i / 12.0
				pts.append(Vector2.from_angle(ang) * length)
			draw_colored_polygon(pts, Color(color.r, color.g, color.b, a4))
		"cross_flash":
			var a5 := 1.0 - p
			var l := radius * (0.6 + p)
			draw_line(Vector2(-l, 0), Vector2(l, 0), Color(color.r, color.g, color.b, a5), 2.0)
			draw_line(Vector2(0, -l), Vector2(0, l), Color(color.r, color.g, color.b, a5), 2.0)


func _draw_slash(p: float) -> void:
	# crescent sweeping from one side of the arc to the other
	var half := deg_to_rad(arc) * 0.5
	var base := dir.angle()
	var sweep := ease(minf(1.0, p * 1.8), 0.5)
	var a0 := base - half
	var a1 := base - half + half * 2.0 * sweep
	var fade := 1.0 - maxf(0.0, (p - 0.45) / 0.55)
	var steps := 18
	for k in 3:
		var r := radius - k * width * 0.7
		var pts := PackedVector2Array()
		for i in steps + 1:
			var ang := lerpf(a0 + (a1 - a0) * 0.25 * k, a1, float(i) / steps)
			pts.append(Vector2.from_angle(ang) * r)
		var c := color.lightened(0.35 * (2 - k) / 2.0)
		c.a *= fade * (1.0 - k * 0.25)
		if pts.size() > 1:
			draw_polyline(pts, c, maxf(1.0, width * (1.0 - k * 0.3)))
	# bright edge
	var tip := Vector2.from_angle(a1) * radius
	draw_circle(tip, width * 0.6 * fade, Color(1, 1, 1, fade))


func _draw_ellipse_outline(rx: float, ry: float, c: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 41:
		var a := TAU * i / 40.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, c, w)


func _draw_ellipse_fill(rx: float, ry: float, c: Color) -> void:
	if rx < 0.5:
		return
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, c)


func _draw_tornado(p: float) -> void:
	var fade := minf(1.0, (1.0 - p) * 4.0) * minf(1.0, t * 6.0)
	_draw_ellipse_fill(radius, radius * 0.4, Color(color.r, color.g, color.b, 0.18 * fade))
	for i in 7:
		var y := -i * radius * 0.32
		var w := radius * (0.35 + i * 0.14)
		var ph := t * 10.0 + i * 0.9 + seed_v
		var pts := PackedVector2Array()
		for k in 13:
			var a := ph + k * 0.5
			pts.append(Vector2(cos(a) * w, y + sin(a) * w * 0.25))
		draw_polyline(pts, Color(color.r, color.g, color.b, (0.35 + 0.08 * i) * fade), 1.5)
	for k in 5:
		var a2 := t * 7.0 + k * 1.3 + seed_v
		var hh := fmod(t * 50.0 + k * 13.0, radius * 2.2)
		draw_circle(Vector2(cos(a2) * radius * 0.8, -hh), 1.2, Color(1, 1, 1, 0.7 * fade))


func _draw_vortex(p: float) -> void:
	var fade := minf(1.0, (1.0 - p) * 5.0) * minf(1.0, t * 4.0)
	_draw_ellipse_fill(radius, radius * 0.6, Color(0.05, 0.0, 0.12, 0.45 * fade))
	for arm in 4:
		var pts := PackedVector2Array()
		for k in 24:
			var tt := k / 23.0
			var a := -t * 6.0 + arm * TAU / 4.0 + tt * 4.0
			var r := radius * (1.0 - tt)
			pts.append(Vector2(cos(a) * r, sin(a) * r * 0.6))
		draw_polyline(pts, Color(color.r, color.g, color.b, 0.75 * fade), 2.0)
	draw_circle(Vector2.ZERO, 5.0 + sin(t * 12.0), Color(0, 0, 0, fade))
	draw_arc(Vector2.ZERO, 6.0, 0, TAU, 16, Color(color.r, color.g, color.b, fade), 1.5)


func _draw_sanctuary(p: float) -> void:
	var fade := minf(1.0, (1.0 - p) * 5.0) * minf(1.0, t * 4.0)
	_draw_ellipse_fill(radius, radius * 0.6, Color(color.r, color.g, color.b, 0.16 * fade))
	_draw_ellipse_outline(radius, radius * 0.6, Color(color.r, color.g, color.b, 0.8 * fade), 1.5)
	_draw_ellipse_outline(radius * 0.7, radius * 0.42, Color(color.r, color.g, color.b, 0.5 * fade), 1.0)
	for i in 8:
		var a := t * 0.8 + i * TAU / 8.0
		var pt := Vector2(cos(a) * radius * 0.85, sin(a) * radius * 0.51)
		draw_rect(Rect2(pt - Vector2(1, 3), Vector2(2, 6)), Color(1, 1, 1, 0.8 * fade))
		draw_rect(Rect2(pt - Vector2(3, 1), Vector2(6, 2)), Color(1, 1, 1, 0.8 * fade))
	for k in 6:
		var hh := fmod(t * 30.0 + k * 11.0, 40.0)
		var x := sin(seed_v + k * 2.1) * radius * 0.7
		draw_rect(Rect2(Vector2(x, -hh), Vector2(1, 3)), Color(color.r, color.g, color.b, (1.0 - hh / 40.0) * fade))


func _draw_rain(p: float) -> void:
	var fade := minf(1.0, (1.0 - p) * 5.0) * minf(1.0, t * 4.0)
	_draw_ellipse_fill(radius, radius * 0.6, Color(color.r, color.g, color.b, 0.15 * fade))
	for k in 26:
		var x := sin(seed_v + k * 7.3) * radius * 0.95
		var yb := cos(seed_v * 0.7 + k * 3.1) * radius * 0.55
		var fall := fmod(t * 220.0 + k * 37.0, 90.0)
		var top := Vector2(x, yb - 90.0 + fall)
		draw_line(top, top + Vector2(-1, 6), Color(color.r, color.g, color.b, 0.75 * fade), 1.0)
		if fall > 84.0:
			_draw_ellipse_outline_at(Vector2(x, yb), 3.0, Color(color.r, color.g, color.b, 0.6 * fade))


func _draw_ellipse_outline_at(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var a := TAU * i / 8.0
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * 0.5))
	draw_polyline(pts, col, 1.0)
