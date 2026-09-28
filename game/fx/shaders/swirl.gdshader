shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Spiral vortex disc (portal tiles, teleports).

uniform vec4 color_a : source_color = vec4(0.55, 0.3, 1.0, 1.0);
uniform vec4 color_b : source_color = vec4(0.3, 0.95, 1.0, 1.0);
uniform float alpha = 1.0;
uniform float speed = 1.6;
uniform float arms = 3.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float spiral = sin(a * arms + log(r + 0.02) * 7.0 + TIME * speed * 3.0);
	float s = smoothstep(0.0, 0.9, spiral);
	float edge = smoothstep(1.0, 0.75, r);
	float core = smoothstep(0.45, 0.0, r);
	vec3 col = mix(color_a.rgb, color_b.rgb, s * (1.0 - r));
	float v = (0.35 + 0.65 * s) * edge + core * 0.9;
	ALBEDO = (col * v + vec3(1.0) * core * 0.6) * 1.5 * alpha;
	ALPHA = clamp(v * alpha, 0.0, 1.0);
}
