shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Procedural die surface: resin body, engraved pips, gold rim on edited faces,
// rune tint + emissive bevel rim, Wild star faces, mark/lock/highlight states.
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
	} else {
		vec3 np = nearest_pip(p, clamp(val, 1, 6));
		pip_r = (val == 1) ? 0.2 : 0.145;
		pip_off = np.xy;
		float pa = fwidth(np.z) * 0.9;
		pip_mask = 1.0 - smoothstep(pip_r - pa, pip_r + pa, np.z);
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
		emission += rc * band * rim_strength;
		albedo = mix(albedo, rc, band * 0.35);
	}

	// --- lock / mark / highlight ------------------------------------------------
	albedo = mix(albedo, albedo * lock_tint * 1.6, locked * 0.55);
	emission += lock_tint * locked * (0.08 + 0.35 * fres);
	float not_pip = 1.0 - pip_mask;
	emission += glow_color * glow * (0.06 + 0.9 * fres) * not_pip;
	emission += hl_color * hl * (0.05 + 0.8 * fres) * not_pip;

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
