shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, depth_draw_never;
// A stylised moon disc with a soft halo (Moonlit Woods: the sky moon, the moon rune chest's glyph,
// the moon pool). `fill` is the lit fraction (0 new, 0.5 half, 1 full), lit side on the right
// (waxing); `blood` turns it red (the Moon King's phase 2). `billboard` faces the camera.

uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform vec4 lit_color : source_color = vec4(0.93, 0.96, 1.0, 1.0);
uniform vec4 dark_color : source_color = vec4(0.12, 0.15, 0.3, 1.0);
uniform vec4 glow_color : source_color = vec4(0.55, 0.7, 1.0, 1.0);
uniform vec4 blood_color : source_color = vec4(1.0, 0.24, 0.16, 1.0);
uniform float glow = 0.55;
uniform float energy = 1.5;
uniform float disc = 0.6;
uniform float blood : hint_range(0.0, 1.0) = 0.0;
uniform float dark_alpha = 0.85;
uniform float opacity = 1.0;
uniform bool billboard = false;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
			INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
			MODEL_MATRIX[3]);
	}
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	p.y = -p.y;
	vec2 q = p / disc;
	float r = length(q);
	float aa = fwidth(r) * 1.5;
	float inside = smoothstep(1.0, 1.0 - aa, r);
	// terminator: an ellipse sweeping from the left limb (new) to the right limb (full)
	float yy = clamp(q.y, -1.0, 1.0);
	float xt = (1.0 - 2.0 * fill) * sqrt(max(1.0 - yy * yy, 0.0));
	float lit = smoothstep(xt - 0.06, xt + 0.06, q.x) * step(0.005, fill);
	if (fill > 0.995) lit = 1.0;
	// soft maria and a few craters
	float m = noise(q * 2.2 + vec2(3.1, 1.7)) * 0.6 + noise(q * 5.0) * 0.4;
	float crater = 0.0;
	for (int i = 0; i < 5; i++) {
		vec2 c = vec2(hash(vec2(float(i), 1.3)), hash(vec2(float(i), 7.9))) * 1.2 - 0.6;
		float cr = 0.08 + 0.1 * hash(vec2(float(i), 3.3));
		crater += smoothstep(cr, cr * 0.6, length(q - c)) * 0.35;
	}
	vec3 lc = mix(lit_color.rgb, blood_color.rgb, blood);
	vec3 face = lc * (1.0 - 0.18 * smoothstep(0.45, 0.7, m) - crater * 0.5);
	face *= 0.92 + 0.08 * (1.0 - r * r);
	vec3 dc = mix(dark_color.rgb, blood_color.rgb * 0.25, blood);
	vec3 col = mix(dc, face * energy, lit);
	float a_disc = inside * mix(dark_alpha, 1.0, lit);
	// halo: stronger the fuller the moon
	vec3 gc = mix(glow_color.rgb, blood_color.rgb, blood);
	float halo = exp(-max(r - 1.0, 0.0) * 3.2) * (1.0 - inside) * glow * (0.35 + 0.65 * fill);
	halo *= smoothstep(1.0, 0.82, length(p));
	ALBEDO = mix(gc * halo * 1.4, col, inside);
	ALPHA = clamp(a_disc + halo, 0.0, 1.0) * opacity;
}
