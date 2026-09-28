shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Vertical light pillar fading out toward the top (level up, target markers).

uniform vec4 color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float alpha = 1.0;
uniform float scroll = 0.6;

void fragment() {
	float h = UV.y;               // 0 top .. 1 bottom on CylinderMesh
	float fade = smoothstep(0.0, 0.85, h);
	float f = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.5);
	float streak = 0.75 + 0.25 * sin(UV.x * 40.0 + TIME * 2.0) * sin(h * 12.0 - TIME * scroll * 10.0);
	float v = fade * (0.35 + f) * streak;
	ALBEDO = color.rgb * v * alpha * 1.4;
	ALPHA = clamp(v * alpha, 0.0, 1.0);
}
