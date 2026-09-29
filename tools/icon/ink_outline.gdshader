shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, fog_disabled;

// Inverted-hull ink outline (sticker look) for icon objects: reads at 29 px.
// Width is in world units, scaled by view distance so it stays even across the frame.

uniform vec3 color : source_color = vec3(0.043, 0.047, 0.1);
uniform float width = 0.03;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = color;
}
