shader_type canvas_item;
// Hit flash + status tint for actors.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline : hint_range(0.0, 1.0) = 0.0;
uniform vec4 outline_color : source_color = vec4(1.0, 0.8, 0.2, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (outline > 0.0 && c.a < 0.1) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		float a = texture(TEXTURE, UV + vec2(px.x, 0.0)).a + texture(TEXTURE, UV - vec2(px.x, 0.0)).a
			+ texture(TEXTURE, UV + vec2(0.0, px.y)).a + texture(TEXTURE, UV - vec2(0.0, px.y)).a;
		if (a > 0.1) {
			c = vec4(outline_color.rgb, outline_color.a * outline);
		}
	}
	c *= COLOR;
	c.rgb = mix(c.rgb, flash_color.rgb, flash * step(0.01, c.a));
	COLOR = c;
}
