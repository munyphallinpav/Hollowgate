class_name WorldText
extends RefCounted
## Crisp text in the zoomed pixel-art world: render at 3x size and scale the node down.

const OVERSAMPLE := 3.0


## Returns a Node2D (centered horizontally on its origin) holding the label.
static func make(text: String, size_px: float, color: Color, outline: int = 2) -> Node2D:
	var holder := Node2D.new()
	holder.z_index = 40
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", int(size_px * OVERSAMPLE))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08))
	l.add_theme_constant_override("outline_size", int(outline * OVERSAMPLE))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var w := maxf(60.0, text.length() * size_px * 0.75) * OVERSAMPLE
	l.size = Vector2(w, size_px * 1.6 * OVERSAMPLE)
	l.position = Vector2(-w * 0.5, -size_px * 0.8 * OVERSAMPLE)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(l)
	holder.scale = Vector2.ONE / OVERSAMPLE
	holder.set_meta("label", l)
	return holder


static func set_text(holder: Node2D, text: String) -> void:
	var l: Label = holder.get_meta("label")
	l.text = text
