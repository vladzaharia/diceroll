shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Rounded HP bar drawn on one quad: frame, dark well, trailing "ghost" damage, fill with a
// glossy top, optional phase ticks (bosses) and a blue frame when the unit has block.

uniform vec2 size = vec2(1.4, 0.2);
uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform float ghost : hint_range(0.0, 1.0) = 1.0;
uniform vec4 fill_color : source_color = vec4(0.9, 0.2, 0.2, 1.0);
uniform vec4 ghost_color : source_color = vec4(1.0, 0.9, 0.75, 1.0);
uniform vec4 well_color : source_color = vec4(0.1, 0.06, 0.08, 1.0);
uniform vec4 frame_color : source_color = vec4(0.1, 0.06, 0.08, 1.0);
uniform vec4 shield_color : source_color = vec4(0.45, 0.78, 1.0, 1.0);
uniform float shielded = 0.0;
uniform float segments = 1.0;
uniform float border = 0.035;
uniform float opacity = 1.0;
// 1 = the pack bar look (Bars/Regular red): a flat fill with a flat lighter top band, no gloss
uniform float flat_band = 0.0;

float rbox(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = (UV - 0.5) * size;
	float r = size.y * 0.5;
	float d = rbox(p, size * 0.5, r);
	float aa = fwidth(d) * 0.8;
	float outer = smoothstep(aa, -aa, d);
	float din = rbox(p, size * 0.5 - vec2(border), r - border);
	float inner = smoothstep(aa, -aa, din);
	float x = (p.x + size.x * 0.5 - border) / (size.x - 2.0 * border);
	vec3 frame = mix(frame_color.rgb, shield_color.rgb, shielded);
	vec3 col = well_color.rgb;
	float gy = (p.y + size.y * 0.5) / size.y;   // 0 bottom .. 1 top
	if (x < ghost) col = ghost_color.rgb * 0.9;
	if (x < fill) {
		vec3 gloss = fill_color.rgb * mix(0.72, 1.15, smoothstep(0.1, 0.9, gy));
		gloss += vec3(0.25) * smoothstep(0.62, 0.8, gy) * smoothstep(0.95, 0.8, gy);
		float band = smoothstep(0.6, 0.64, gy);
		vec3 flat_col = mix(fill_color.rgb * 0.86, mix(fill_color.rgb, vec3(1.0), 0.28), band);
		col = mix(gloss, flat_col, flat_band);
	}
	if (segments > 1.0) {
		float s = fract(x * segments);
		float tick = smoothstep(0.012 * segments, 0.0, min(s, 1.0 - s));
		col = mix(col, frame_color.rgb, tick * step(0.02, x) * step(x, 0.98));
	}
	col = mix(frame, col, inner);
	ALBEDO = col;
	ALPHA = outer * opacity;
}
