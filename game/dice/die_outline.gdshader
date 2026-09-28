shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, blend_add, shadows_disabled;

// Inverted-hull glow shell for marked dice (used as the die material's next_pass).
uniform vec3 color : source_color = vec3(1.0, 0.78, 0.35);
uniform float strength = 0.0;
uniform float width = 0.04;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	float f = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.5);
	ALBEDO = color * strength * (0.2 + 1.1 * f * f);
}
