shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
// Warded affix: a fresnel shell (clear centre, glowing edge) with slow shimmer bands.

uniform vec4 color : source_color = vec4(0.7, 0.45, 1.0, 1.0);
uniform float strength = 0.85;

void fragment() {
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.4);
	float band = 0.75 + 0.25 * sin(TIME * 2.2 + VERTEX.y * 9.0);
	ALBEDO = color.rgb * (fr * strength * band + 0.03);
}
