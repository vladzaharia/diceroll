shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

// Soft glowing ring on the felt under a die (mark / combo highlight).
uniform vec3 color : source_color = vec3(1.0, 0.78, 0.35);
uniform float strength = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = max(abs(p.x), abs(p.y));
	float r = length(p);
	float sq = mix(d, r, 0.55);
	float ring = exp(-pow((sq - 0.62) / 0.07, 2.0));
	float halo = (1.0 - smoothstep(0.2, 1.0, sq)) * 0.35;
	ALBEDO = color * strength * (ring * 1.4 + halo);
}
