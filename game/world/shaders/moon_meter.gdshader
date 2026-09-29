shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// The Moon King's moon meter (boss HUD): a moon disc lit from the right by `fill` (0 new .. 1
// full, like a waxing phase), inside a dark rim with `pips` tide pips round its lower edge, `lit`
// of them filled. `blood` turns the moon red (phase 2), `pulse` flashes it (a change).

uniform float fill = 0.0;
uniform int pips = 4;
uniform int lit = 0;
uniform float blood = 0.0;
uniform float pulse = 0.0;
uniform float opacity = 1.0;
uniform vec4 rim_color : source_color = vec4(0.1, 0.06, 0.08, 1.0);
uniform vec4 bg_color : source_color = vec4(0.05, 0.06, 0.16, 1.0);

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	p.y = -p.y;
	float r = length(p);
	float aa = fwidth(r) * 1.2;
	float disc = smoothstep(1.0, 1.0 - aa, r);
	float rim = smoothstep(0.86 + aa, 0.86, r);
	vec3 moon_lit = mix(vec3(0.93, 0.95, 1.0), vec3(1.0, 0.36, 0.3), blood);
	vec3 moon_dark = mix(vec3(0.3, 0.34, 0.56), vec3(0.36, 0.12, 0.16), blood);
	vec3 bg = bg_color.rgb * mix(0.7, 1.2, smoothstep(-0.8, 0.8, p.y));
	vec3 col = mix(rim_color.rgb, bg, rim);
	// the moon: waxing from the right (terminator = an ellipse whose half-width follows cos(pi f))
	float mr = 0.6;
	vec2 m = p - vec2(0.0, 0.1);
	float md = length(m);
	float in_moon = smoothstep(mr + aa, mr, md);
	float yy = clamp(m.y / mr, -1.0, 1.0);
	float term = mr * cos(3.14159 * clamp(fill, 0.0, 1.0)) * sqrt(max(1.0 - yy * yy, 0.0));
	float lit_side = smoothstep(term - aa, term + aa, m.x);
	vec3 moon = mix(moon_dark, moon_lit, lit_side);
	// soft craters
	float cr = smoothstep(0.1, 0.07, length(m - vec2(0.18, 0.2))) + smoothstep(0.08, 0.05, length(m - vec2(-0.1, -0.22)));
	moon *= 1.0 - 0.14 * cr;
	col = mix(col, moon, in_moon * rim);
	// a thin silver limb so the unlit moon still reads against the badge
	col = mix(col, mix(vec3(0.72, 0.8, 1.0), vec3(1.0, 0.5, 0.42), blood), smoothstep(aa * 1.5, 0.0, abs(md - mr)) * rim * 0.8);
	// tide pips along the lower rim
	for (int i = 0; i < 8; i++) {
		if (i >= pips) break;
		float t = (float(i) + 0.5) / float(pips);
		float a = radians(-150.0 + 120.0 * t);
		vec2 c = vec2(cos(a), sin(a)) * 0.74;
		float pd = length(p - c);
		float o = smoothstep(0.13 + aa, 0.13, pd);
		float f = smoothstep(0.09 + aa, 0.09, pd);
		col = mix(col, rim_color.rgb, o);
		col = mix(col, i < lit ? mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.4, 0.3), blood) : vec3(0.22, 0.24, 0.36), f);
	}
	col += vec3(0.6, 0.7, 1.0) * pulse * in_moon;
	ALBEDO = col;
	ALPHA = disc * opacity;
}
