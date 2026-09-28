shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
// Fresnel bubble with a hex-ish lattice, used for block flashes.

uniform vec4 color : source_color = vec4(0.35, 0.7, 1.0, 1.0);
uniform float alpha = 1.0;

void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	vec2 uv = UV * vec2(18.0, 9.0);
	vec2 g = abs(fract(uv + vec2(0.5 * floor(uv.y), 0.0)) - 0.5);
	float lattice = smoothstep(0.42, 0.5, max(g.x, g.y));
	float v = f * 1.4 + lattice * 0.35 * (0.3 + f) + 0.06;
	ALBEDO = color.rgb * v * alpha * 1.6;
	ALPHA = clamp(v * alpha, 0.0, 1.0);
}
