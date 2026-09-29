shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Procedural die surface: resin body, engraved pips (numerals for 7-9, an empty inset for
// a blank 0 face), gold rim on edited faces, rune tint + emissive bevel rim, Wild star
// faces, a small per-kind corner mark, mark/lock/highlight/dim states.
// Face slot comes from CUSTOM0.w and the face's right axis from CUSTOM0.xyz (see DieMesh).

uniform vec3 body_color : source_color = vec3(0.95, 0.92, 0.84);
uniform vec3 edge_color : source_color = vec3(0.86, 0.78, 0.66);
uniform vec3 pip_color : source_color = vec3(0.07, 0.06, 0.06);
uniform vec3 rim_color : source_color = vec3(1.0, 0.8, 0.4);
uniform float rim_strength = 0.0;
uniform float metallic = 0.0;
uniform float roughness = 0.3;
uniform float clearcoat = 0.6;
uniform float face_vals[6];
uniform float face_edit[6];
uniform float wild = 0.0;
uniform vec3 gold : source_color = vec3(1.0, 0.76, 0.33);
uniform float bevel = 0.26;
uniform vec3 glow_color : source_color = vec3(1.0, 0.78, 0.35);
uniform float glow = 0.0;
uniform vec3 hl_color : source_color = vec3(1.0, 0.85, 0.4);
uniform float hl = 0.0;
uniform vec3 lock_tint : source_color = vec3(0.42, 0.22, 0.62);
uniform float locked = 0.0;
uniform float time_offset = 0.0;
// Kind corner mark: 0 none, 1 low (down chevron), 2 high (up chevron), 3 even (diamond),
// 4 odd (ring), 5 loaded (weight), 6 twin (double bar), 7 gambler (spark), 8 giant (crown),
// 9 bone (a bone), 10 pretend (a three-toed dino print).
uniform int kind_mark = 0;
uniform vec3 kind_color : source_color = vec3(1.0, 0.75, 0.3);
// Die tag mark on the other two corners: 0 none, 1 seed (a sprouting leaf).
uniform int tag_mark = 0;
uniform vec3 tag_color : source_color = vec3(0.35, 0.9, 0.45);
// The Pretend face (value 10): a bold star, never a number.
uniform vec3 star_color : source_color = vec3(1.0, 0.8, 0.22);
// 0..1: darken (dice not moving this turn).
uniform float dim = 0.0;

varying float v_slot;
varying vec3 v_u;
varying vec3 v_v;

const float PIP_S = 0.46;

void vertex() {
	v_slot = CUSTOM0.w;
	vec3 u = CUSTOM0.xyz;
	vec3 v = cross(u, NORMAL);
	v_u = (MODELVIEW_MATRIX * vec4(u, 0.0)).xyz;
	v_v = (MODELVIEW_MATRIX * vec4(v, 0.0)).xyz;
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

// Nearest pip for value n: xy = offset from its centre, z = distance.
vec3 nearest_pip(vec2 p, int n) {
	float s = PIP_S;
	vec2 best = vec2(1e3);
	vec2 c[7];
	int cnt = 0;
	if (n == 1 || n == 3 || n == 5) { c[cnt] = vec2(0.0); cnt++; }
	if (n >= 2) { c[cnt] = vec2(s, -s); cnt++; c[cnt] = vec2(-s, s); cnt++; }
	if (n >= 4) { c[cnt] = vec2(-s, -s); cnt++; c[cnt] = vec2(s, s); cnt++; }
	if (n == 6) { c[cnt] = vec2(-s, 0.0); cnt++; c[cnt] = vec2(s, 0.0); cnt++; }
	for (int i = 0; i < 7; i++) {
		if (i >= cnt) break;
		vec2 o = p - c[i];
		if (dot(o, o) < dot(best, best)) best = o;
	}
	return vec3(best, length(best));
}

// Small pips in a row (Wild faces show the value under the star).
vec3 nearest_row_pip(vec2 p, int n) {
	float sp = 0.19;
	float x0 = -0.5 * sp * float(n - 1);
	vec2 best = vec2(1e3);
	for (int i = 0; i < 6; i++) {
		if (i >= n) break;
		vec2 o = p - vec2(x0 + sp * float(i), 0.5);
		if (dot(o, o) < dot(best, best)) best = o;
	}
	return vec3(best, length(best));
}

float sd_star5(vec2 p, float r, float rf) {
	const vec2 k1 = vec2(0.809016994375, -0.587785252292);
	const vec2 k2 = vec2(-k1.x, k1.y);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float sd_seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// Chunky rounded numeral 7, 8 or 9 (y up, glyph ~1.0 tall). Returns a signed distance.
float sd_numeral(vec2 q, int n) {
	float w = 0.105;
	if (n == 7) {
		float a = sd_seg(q, vec2(-0.3, 0.44), vec2(0.3, 0.44));
		float b = sd_seg(q, vec2(0.3, 0.44), vec2(-0.06, -0.46));
		return min(a, b) - w;
	}
	if (n == 8) {
		float t = abs(length((q - vec2(0.0, 0.25)) * vec2(1.08, 1.0)) - 0.19);
		float b = abs(length((q - vec2(0.0, -0.2)) * vec2(0.96, 1.0)) - 0.25);
		return min(t, b) - w * 0.92;
	}
	// 9: a loop with a tail
	float ring = abs(length((q - vec2(0.0, 0.17)) * vec2(0.96, 1.0)) - 0.24);
	float tail = sd_seg(q, vec2(0.235, 0.14), vec2(0.07, -0.46));
	return min(ring, tail) - w;
}

// Small kind mark centred at the origin (y up), radius ~1.
float sd_kind(vec2 q, int k) {
	if (k == 1 || k == 2) {
		vec2 r = (k == 1) ? vec2(q.x, -q.y) : q;
		return min(sd_seg(r, vec2(-0.75, -0.35), vec2(0.0, 0.4)), sd_seg(r, vec2(0.0, 0.4), vec2(0.75, -0.35))) - 0.28;
	}
	if (k == 3) return (abs(q.x) + abs(q.y)) * 0.7071 - 0.62;
	if (k == 4) return abs(length(q) - 0.62) - 0.26;
	if (k == 5) return sd_round_box(q - vec2(0.0, -0.12), vec2(0.72, 0.56), 0.3);
	if (k == 6) return min(sd_seg(q, vec2(-0.38, -0.7), vec2(-0.38, 0.7)), sd_seg(q, vec2(0.38, -0.7), vec2(0.38, 0.7))) - 0.24;
	if (k == 7) return sd_star5(vec2(q.x, q.y), 0.95, 0.42);
	if (k == 9) {
		float shaft = sd_seg(q, vec2(-0.5, -0.5), vec2(0.5, 0.5)) - 0.2;
		float k1 = min(length(q - vec2(-0.72, -0.42)), length(q - vec2(-0.42, -0.72))) - 0.26;
		float k2 = min(length(q - vec2(0.72, 0.42)), length(q - vec2(0.42, 0.72))) - 0.26;
		return min(shaft, min(k1, k2));
	}
	if (k == 10) {
		float pad = length((q - vec2(0.0, -0.35)) * vec2(1.0, 1.25)) - 0.42;
		float t1 = sd_seg(q, vec2(-0.2, -0.05), vec2(-0.7, 0.65)) - 0.16;
		float t2 = sd_seg(q, vec2(0.0, 0.0), vec2(0.0, 0.85)) - 0.16;
		float t3 = sd_seg(q, vec2(0.2, -0.05), vec2(0.7, 0.65)) - 0.16;
		return min(pad, min(t1, min(t2, t3)));
	}
	// 8 giant: crown
	float base = sd_round_box(q - vec2(0.0, -0.45), vec2(0.8, 0.22), 0.08);
	float spikes = min(min(sd_seg(q, vec2(-0.65, -0.3), vec2(-0.8, 0.65)), sd_seg(q, vec2(0.0, -0.3), vec2(0.0, 0.8))),
		sd_seg(q, vec2(0.65, -0.3), vec2(0.8, 0.65))) - 0.22;
	return min(base, spikes);
}

void fragment() {
	int slot = clamp(int(v_slot + 0.5), 0, 5);
	int val = int(face_vals[slot] + 0.5);
	float edited = face_edit[slot];
	vec2 p = UV * 2.0 - 1.0;          // face coords, -1..1 (flat area is |p| < 1 - bevel)
	float f = 1.0 - bevel;
	float boxd = max(abs(p.x), abs(p.y));
	float bev = smoothstep(f - 0.02, 1.0, boxd);   // 0 on the flat face, 1 at the edge
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);

	vec3 body = body_color;
	if (wild > 0.5) {
		float hue = fract(0.55 * p.x + 0.35 * p.y + 0.6 * fres + 0.13 * v_slot);
		body = mix(body_color, hsv2rgb(vec3(hue, 0.35, 1.0)), 0.28 + 0.3 * fres);
	}
	vec3 albedo = mix(body, edge_color, bev * 0.8);
	float rough = roughness;
	float metal = metallic;
	vec3 emission = vec3(0.0);
	vec3 bump = vec3(0.0);      // (du, dv) tilt in face space

	// --- pips / star ---------------------------------------------------------
	float pip_mask = 0.0;
	vec2 pip_off = vec2(0.0);
	float pip_r = 0.0;
	vec3 pip_col = pip_color;
	if (wild > 0.5) {
		vec2 sp = p - vec2(0.0, -0.1);
		float ds = sd_star5(vec2(sp.x, -sp.y), 0.47, 0.46);
		float aa = fwidth(ds) * 0.9;
		float star = 1.0 - smoothstep(-aa, aa, ds);
		float outline = 1.0 - smoothstep(-aa, aa, ds - 0.045);
		float hue = fract(atan(sp.y, sp.x) / 6.2831 + 0.1 * TIME + time_offset);
		vec3 rainbow = hsv2rgb(vec3(hue, 0.75, 1.0));
		vec3 star_col = mix(gold, rainbow, 0.55 + 0.25 * (-ds / 0.3));
		albedo = mix(albedo, pip_color, outline);
		albedo = mix(albedo, star_col, star);
		emission += star_col * star * 0.35;
		rough = mix(rough, 0.25, star);
		vec3 rp = nearest_row_pip(p, clamp(val, 1, 6));
		pip_r = 0.06;
		pip_off = rp.xy;
		float pa = fwidth(rp.z) * 0.9;
		pip_mask = 1.0 - smoothstep(pip_r - pa, pip_r + pa, rp.z);
	} else if (val == 10) {
		// the Pretend face: a big glossy gold star with a dark outline (never a numeral)
		vec2 sp = p - vec2(0.0, -0.06);
		float ds = sd_star5(vec2(sp.x, -sp.y), 0.6, 0.47);
		float aa = fwidth(ds) * 0.9;
		float star = 1.0 - smoothstep(-aa, aa, ds);
		float outline = 1.0 - smoothstep(-aa, aa, ds - 0.07);
		float inner = clamp(-ds / 0.22, 0.0, 1.0);
		vec3 sc = mix(star_color * 0.78, star_color * 1.12, inner);
		albedo = mix(albedo, pip_color, outline);
		albedo = mix(albedo, sc, star);
		emission += star_color * star * (0.28 + 0.12 * sin(TIME * 3.0 + time_offset * 6.28));
		rough = mix(rough, 0.22, star);
		metal = mix(metal, 0.35, star);
	} else if (val >= 7) {
		// numeral, engraved like a pip (y up in glyph space)
		vec2 q = vec2(p.x, -p.y) * 1.02;
		float d = sd_numeral(q, clamp(val, 7, 9));
		float aa = fwidth(d) * 0.9;
		pip_mask = 1.0 - smoothstep(-aa, aa, d);
		pip_r = 0.1;
		float dx = sd_numeral(q + vec2(0.012, 0.0), clamp(val, 7, 9)) - d;
		float dy = sd_numeral(q + vec2(0.0, 0.012), clamp(val, 7, 9)) - d;
		pip_off = -normalize(vec2(dx, -dy) + 1e-5) * clamp(1.0 + d / 0.1, 0.0, 1.0) * pip_r;
	} else if (val <= 0) {
		// blank face: an empty engraved inset with a faint cross
		float rd = sd_round_box(p, vec2(0.46), 0.16);
		float aa = fwidth(rd) * 0.9;
		float line = 1.0 - smoothstep(0.03 - aa, 0.03 + aa, abs(rd));
		float cross_d = min(sd_seg(p, vec2(-0.2, -0.2), vec2(0.2, 0.2)), sd_seg(p, vec2(-0.2, 0.2), vec2(0.2, -0.2))) - 0.04;
		float ca = fwidth(cross_d) * 0.9;
		float cr = 1.0 - smoothstep(-ca, ca, cross_d);
		float inset = 1.0 - smoothstep(-aa, aa, rd);
		albedo = mix(albedo, albedo * 0.86, inset);
		pip_mask = max(line * 0.8, cr * 0.45);
		pip_r = 0.03;
	} else {
		vec3 np = nearest_pip(p, clamp(val, 1, 6));
		pip_r = (val == 1) ? 0.2 : 0.145;
		pip_off = np.xy;
		float pa = fwidth(np.z) * 0.9;
		pip_mask = 1.0 - smoothstep(pip_r - pa, pip_r + pa, np.z);
	}
	// --- kind mark: two opposite corners (symmetric under the resting half-turn) ------
	if (kind_mark > 0 && wild < 0.5) {
		float km = 0.0;
		for (int c = 0; c < 2; c++) {
			vec2 at = (c == 0) ? vec2(-0.63, -0.63) : vec2(0.63, 0.63);
			vec2 q = (p - at) / 0.1;
			q.y = -q.y;
			float d = sd_kind(q, kind_mark) * 0.1;
			float ka = fwidth(d) * 0.9;
			km = max(km, 1.0 - smoothstep(-ka, ka, d));
		}
		albedo = mix(albedo, kind_color, km * 0.95);
		emission += kind_color * km * 0.12;
		rough = mix(rough, 0.3, km);
	}
	// --- tag mark (seed leaf) on the other diagonal -----------------------------------
	if (tag_mark > 0 && wild < 0.5) {
		float tm = 0.0;
		for (int c = 0; c < 2; c++) {
			vec2 at = (c == 0) ? vec2(-0.63, 0.63) : vec2(0.63, -0.63);
			vec2 q = (p - at) / 0.12;
			q.y = -q.y;
			// a leaf: two arcs meeting at the tips, tilted 45 degrees
			vec2 r = vec2(q.x + q.y, q.y - q.x) * 0.7071;
			float d = max(length(r - vec2(0.0, -0.55)) - 0.95, length(r - vec2(0.0, 0.55)) - 0.95) * 0.12;
			float ka = fwidth(d) * 0.9;
			tm = max(tm, 1.0 - smoothstep(-ka, ka, d));
		}
		albedo = mix(albedo, tag_color, tm * 0.95);
		emission += tag_color * tm * 0.25;
		rough = mix(rough, 0.35, tm);
	}
	// Engraved dimple: the inside of the pip tilts toward its centre.
	float inside = clamp(1.0 - length(pip_off) / max(pip_r, 1e-3), 0.0, 1.0);
	vec2 tilt = -pip_off / max(pip_r, 1e-3) * 0.85 * pip_mask;
	bump.xy += tilt;
	vec3 pip_shade = pip_col * (0.75 + 0.5 * inside);
	albedo = mix(albedo, pip_shade, pip_mask);
	rough = mix(rough, 0.6, pip_mask);
	metal = mix(metal, 0.0, pip_mask);

	// --- gold rim on edited faces ----------------------------------------------
	if (edited > 0.5) {
		float rd = sd_round_box(p, vec2(f - 0.075), 0.12);
		float aa = fwidth(rd) * 0.9;
		float line = 1.0 - smoothstep(0.022 - aa, 0.022 + aa, abs(rd));
		float halo = 1.0 - smoothstep(0.0, 0.06, abs(rd));
		albedo = mix(albedo, albedo * 0.7, halo * 0.5 * (1.0 - line));
		albedo = mix(albedo, gold, line);
		metal = mix(metal, 0.95, line);
		rough = mix(rough, 0.22, line);
		emission += gold * line * 0.25;
		bump.xy += normalize(p + 1e-4) * sign(rd) * line * 0.25;
	}

	// --- rune rim (emissive bevel) ----------------------------------------------
	if (rim_strength > 0.0) {
		vec3 rc = rim_color;
		if (wild > 0.5) {
			rc = hsv2rgb(vec3(fract(0.3 * (p.x + p.y) + 0.12 * v_slot + 0.15 * TIME), 0.8, 1.0));
		}
		float band = smoothstep(f + 0.05, 1.0, boxd);
		float ld = 1.0 - boxd;
		float la = fwidth(boxd) * 0.9;
		float line = 1.0 - smoothstep(0.045 - la, 0.045 + la, ld);
		emission += rc * band * rim_strength * 0.35;
		emission += rc * 1.1 * line * rim_strength;
		albedo = mix(albedo, rc, band * 0.3 + line * 0.5);
	}

	// --- lock / mark / highlight ------------------------------------------------
	albedo = mix(albedo, albedo * lock_tint * 1.6, locked * 0.55);
	emission += lock_tint * locked * (0.08 + 0.35 * fres);
	float not_pip = 1.0 - pip_mask;
	emission += glow_color * glow * (0.06 + 0.9 * fres) * not_pip;
	emission += hl_color * hl * (0.05 + 0.8 * fres) * not_pip;
	albedo = mix(albedo, vec3(dot(albedo, vec3(0.3, 0.59, 0.11))), dim * 0.5) * (1.0 - dim * 0.6);
	emission *= 1.0 - dim * 0.8;

	// Normal perturbation in view space using the face axes.
	vec3 tu = normalize(v_u);
	vec3 tv = normalize(v_v);
	NORMAL = normalize(NORMAL + (tu * bump.x + tv * bump.y) * (1.0 - bev));

	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = mix(0.55, 0.15, pip_mask);
	CLEARCOAT = clearcoat * (1.0 - pip_mask);
	CLEARCOAT_ROUGHNESS = 0.12;
	BACKLIGHT = body_color * 0.18;
	EMISSION = emission;
}
