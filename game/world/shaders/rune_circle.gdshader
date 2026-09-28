shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Procedural glowing magic circle: two rings, tick marks and a rotating rune band.

uniform vec4 color : source_color = vec4(0.6, 0.35, 1.0, 1.0);
uniform float intensity = 1.4;
uniform float speed = 0.15;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x) + TIME * speed;
	float w = fwidth(r) * 1.5;
	float ring1 = smoothstep(w, 0.0, abs(r - 0.94) - 0.012);
	float ring2 = smoothstep(w, 0.0, abs(r - 0.72) - 0.008);
	float band = step(0.74, r) * step(r, 0.92);
	float ticks = smoothstep(0.55, 0.9, sin(a * 24.0)) * band * 0.55;
	float runes = step(0.5, fract(a * 3.8197)) * smoothstep(0.02, 0.0, abs(r - 0.83) - 0.03) * 0.45;
	float inner = smoothstep(0.72, 0.0, r) * 0.12;
	float star = 0.0;
	for (int i = 0; i < 3; i++) {
		float ang = float(i) * 2.0944 - TIME * speed * 0.6;
		vec2 dir = vec2(cos(ang), sin(ang));
		float d = abs(dot(p, vec2(-dir.y, dir.x)));
		star += smoothstep(w * 1.2, 0.0, d - 0.006) * step(r, 0.72);
	}
	float glow = smoothstep(1.0, 0.6, r) * 0.08;
	float v = ring1 + ring2 * 0.8 + ticks + runes + inner + star * 0.5 + glow;
	v *= smoothstep(1.0, 0.97, r);
	float pulse = 0.85 + 0.15 * sin(TIME * 2.0);
	ALBEDO = color.rgb * v * intensity * pulse;
	ALPHA = clamp(v, 0.0, 1.0);
}
