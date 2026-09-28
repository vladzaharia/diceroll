shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled;
// Crescent sword swipe that sweeps across the quad as `progress` goes 0 -> 1.

uniform vec4 color : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform float progress = 0.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);            // -pi..pi
	float band = smoothstep(0.16, 0.0, abs(r - 0.72)) ;
	float head = mix(-2.6, 2.6, progress);
	float tail = head - 2.2;
	float along = smoothstep(tail, head, a) * step(a, head);
	float taper = smoothstep(0.1, 0.0, abs(r - 0.72) - 0.04 * along);
	float v = band * along * taper * (1.0 - progress * 0.6);
	ALBEDO = color.rgb * v * 2.2;
	ALPHA = clamp(v, 0.0, 1.0);
}
