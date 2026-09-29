shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Round intent badge with a crisp SDF icon.
// kind: 0 attack (sword) 1 block (shield) 2 buff (up arrow) 3 curse (padlock) 4 summon (skull)
// 5 unknown (dot) 6 aim (crosshair: the archer takes aim, no attack this turn) 7 chaos (spiral)
// 8 heal (plus) 9 drain (fang over a heart) 10 burn (flame) 11 chill (sword + snowflake)
// 12 scorch (flame on a die) 13 armor (plated shield) 14 thorns (bramble ring) 15 ward (dome)
// 16 pierce (cracked shield) 17 bury (a die sinking into sand) 18 moonfall (a crescent falling
// with streaks)

uniform int kind = 0;
uniform vec4 bg_color : source_color = vec4(0.85, 0.2, 0.2, 1.0);
uniform vec4 icon_color : source_color = vec4(1.0, 0.97, 0.9, 1.0);
uniform vec4 rim_color : source_color = vec4(0.1, 0.06, 0.08, 1.0);
uniform float opacity = 1.0;

float box(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}
float circle(vec2 p, float r) { return length(p) - r; }
vec2 rot(vec2 p, float a) { float c = cos(a), s = sin(a); return vec2(c * p.x - s * p.y, s * p.x + c * p.y); }
float tri_up(vec2 p, float w, float h) {
	// isosceles triangle with base at y=0 and apex at y=h
	p.x = abs(p.x);
	vec2 a = vec2(w, 0.0), b = vec2(0.0, h);
	vec2 e = b - a;
	vec2 n = normalize(vec2(e.y, -e.x));
	return max(dot(p - a, n), -p.y);
}

float dot2(vec2 v) { return dot(v, v); }
float heart(vec2 p) {
	p.x = abs(p.x);
	if (p.y + p.x > 1.0) return sqrt(dot2(p - vec2(0.25, 0.75))) - sqrt(2.0) / 4.0;
	return sqrt(min(dot2(p - vec2(0.0, 1.0)), dot2(p - 0.5 * max(p.x + p.y, 0.0)))) * sign(p.x - p.y);
}
float flame(vec2 p) {
	float body = circle(p - vec2(0.0, -0.14), 0.26);
	float tip = tri_up(p - vec2(0.0, -0.14), 0.25, 0.62);
	float f = min(body, tip);
	float inner = min(circle(p - vec2(0.0, -0.2), 0.11), tri_up(p - vec2(0.0, -0.2), 0.1, 0.3));
	return max(f, -inner);
}
float snowflake(vec2 p, float r, float w) {
	float d = 8.0;
	for (int i = 0; i < 3; i++) {
		vec2 q = rot(p, float(i) * 1.0471976);
		d = min(d, box(q, vec2(w, r)));
		vec2 b = vec2(abs(q.x), abs(q.y)) - vec2(0.0, r * 0.62);
		d = min(d, box(rot(b, 0.785398), vec2(w * 0.9, r * 0.28)));
	}
	return d;
}
float sword(vec2 p) {
	vec2 q = rot(p, -0.785398);
	float blade = box(q - vec2(0.0, 0.1), vec2(0.07, 0.3));
	float tip = tri_up(q - vec2(0.0, 0.4), 0.07, 0.14);
	float guard = box(q - vec2(0.0, -0.22), vec2(0.2, 0.045));
	float grip = box(q - vec2(0.0, -0.34), vec2(0.04, 0.1));
	float pommel = circle(q - vec2(0.0, -0.46), 0.06);
	return min(min(min(blade, tip), min(guard, grip)), pommel);
}
float shield(vec2 p) {
	float top = box(p - vec2(0.0, 0.16), vec2(0.3, 0.16));
	float bot = max(max(circle(p - vec2(-0.3, 0.1), 0.6), circle(p - vec2(0.3, 0.1), 0.6)), p.y - 0.1);
	return min(top, bot);
}

float icon(vec2 p) {
	if (kind == 0) {
		vec2 q = rot(p, -0.785398);
		float blade = box(q - vec2(0.0, 0.1), vec2(0.07, 0.3));
		float tip = tri_up(q - vec2(0.0, 0.4), 0.07, 0.14);
		float guard = box(q - vec2(0.0, -0.22), vec2(0.2, 0.045));
		float grip = box(q - vec2(0.0, -0.34), vec2(0.04, 0.1));
		float pommel = circle(q - vec2(0.0, -0.46), 0.06);
		return min(min(min(blade, tip), min(guard, grip)), pommel);
	} else if (kind == 1) {
		float top = box(p - vec2(0.0, 0.16), vec2(0.3, 0.16));
		float bot = max(max(circle(p - vec2(-0.3, 0.1), 0.6), circle(p - vec2(0.3, 0.1), 0.6)), p.y - 0.1);
		float s = min(top, bot);
		float cut = abs(box(p - vec2(0.0, 0.08), vec2(0.17, 0.2)) + 0.0) - 0.035;
		return max(s, -max(cut, p.y - 0.36));
	} else if (kind == 2) {
		float head = tri_up(p - vec2(0.0, 0.02), 0.3, 0.36);
		float stem = box(p - vec2(0.0, -0.16), vec2(0.1, 0.2));
		return min(head, stem);
	} else if (kind == 3) {
		float body = box(p - vec2(0.0, -0.12), vec2(0.28, 0.22)) - 0.04;
		float shackle = abs(circle(p - vec2(0.0, 0.14), 0.18)) - 0.055;
		shackle = max(shackle, -(p.y - 0.1));
		float hole = circle(p - vec2(0.0, -0.1), 0.06);
		return max(min(body, shackle), -hole);
	} else if (kind == 4) {
		float skull = circle(p - vec2(0.0, 0.08), 0.3);
		float jaw = box(p - vec2(0.0, -0.2), vec2(0.17, 0.12)) - 0.03;
		float s = min(skull, jaw);
		float eyes = min(circle(p - vec2(-0.12, 0.06), 0.09), circle(p - vec2(0.12, 0.06), 0.09));
		float nose = tri_up(p - vec2(0.0, -0.1), 0.05, 0.08);
		float teeth = box(p - vec2(0.0, -0.26), vec2(0.012, 0.07));
		return max(max(s, -eyes), -min(nose, teeth));
	} else if (kind == 6) {
		float ring = abs(circle(p, 0.3)) - 0.055;
		float ticks = min(min(box(p - vec2(0.0, 0.42), vec2(0.045, 0.12)), box(p + vec2(0.0, 0.42), vec2(0.045, 0.12))),
			min(box(p - vec2(0.42, 0.0), vec2(0.12, 0.045)), box(p + vec2(0.42, 0.0), vec2(0.12, 0.045))));
		float dot_c = circle(p, 0.08);
		return min(min(ring, ticks), dot_c);
	} else if (kind == 7) {
		float r = length(p);
		float a = atan(p.y, p.x);
		float spiral = abs(fract((r * 3.2 - a / 6.2831853) + 0.5) - 0.5) / 3.2 - 0.05;
		return max(spiral, r - 0.46);
	} else if (kind == 8) {
		return min(box(p, vec2(0.12, 0.4)), box(p, vec2(0.4, 0.12))) - 0.02;
	} else if (kind == 9) {
		float h = heart((p - vec2(0.0, -0.44)) * vec2(1.55, 1.55)) / 1.55;
		float fang = tri_up(rot(p - vec2(0.0, 0.46), 3.14159), 0.13, 0.3);
		float drop = circle(p - vec2(0.0, 0.1), 0.06);
		return min(min(max(h, -circle(p - vec2(0.0, 0.1), 0.1)), fang), drop);
	} else if (kind == 10) {
		return flame(p * 0.95) / 0.95;
	} else if (kind == 11) {
		float s = sword((p - vec2(-0.1, 0.08)) * 1.15) / 1.15;
		float f = snowflake(p - vec2(0.24, -0.26), 0.2, 0.035);
		float halo = circle(p - vec2(0.24, -0.26), 0.25);
		return min(max(s, -halo), f);
	} else if (kind == 12) {
		float die_o = abs(box(p - vec2(0.0, -0.12), vec2(0.3, 0.3)) - 0.06) - 0.05;
		float pip = circle(p - vec2(0.0, -0.12), 0.07);
		float f = flame((p - vec2(0.0, 0.3)) * 2.1) / 2.1;
		return min(min(max(die_o, -circle(p - vec2(0.0, 0.3), 0.2)), pip), f);
	} else if (kind == 13) {
		float s = shield(p);
		float bands = abs(fract((p.y + 0.02) * 3.4) - 0.5) / 3.4 - 0.03;
		return max(s, -max(bands, -(s + 0.08)));
	} else if (kind == 14) {
		float ring = abs(circle(p, 0.28)) - 0.06;
		float spikes = 8.0;
		for (int i = 0; i < 8; i++) {
			vec2 q = rot(p, float(i) * 0.785398 + 0.39);
			spikes = min(spikes, tri_up(q - vec2(0.0, 0.3), 0.08, 0.2));
		}
		return min(ring, spikes);
	} else if (kind == 15) {
		float dome = max(abs(circle(p - vec2(0.0, -0.22), 0.44)) - 0.06, -(p.y + 0.22));
		float base = box(p - vec2(0.0, -0.26), vec2(0.5, 0.05));
		float spark = snowflake(p - vec2(0.0, 0.0), 0.12, 0.03);
		return min(min(dome, base), spark);
	} else if (kind == 16) {
		float s = shield(p);
		vec2 q = p - vec2(0.02, 0.05);
		float crack = abs(q.x + 0.14 * sin(q.y * 9.0)) - 0.045;
		crack = max(crack, abs(q.y) - 0.42);
		return max(s, -crack);
	} else if (kind == 17) {
		// a tilted die half under a sand wave
		vec2 q = rot(p - vec2(0.0, 0.12), 0.22);
		float die_b = box(q, vec2(0.27, 0.27)) - 0.06;
		float pips = min(min(circle(q - vec2(-0.13, 0.13), 0.055), circle(q, 0.055)), circle(q - vec2(0.13, -0.13), 0.055));
		float d = max(die_b, -pips);
		float wave = p.y - (-0.08 + 0.06 * sin(p.x * 7.0));
		d = max(d, -wave);
		float sand = max(abs(p.y + 0.3 - 0.05 * sin(p.x * 7.0)) - 0.09, abs(p.x) - 0.5);
		return min(d, sand);
	} else if (kind == 18) {
		// crescent (a disc minus an offset disc) diving down-left, with three streaks
		vec2 q = p - vec2(-0.08, -0.1);
		float cres = max(circle(q, 0.3), -circle(q - vec2(0.14, 0.1), 0.25));
		float streaks = 8.0;
		for (int i = 0; i < 3; i++) {
			vec2 o = vec2(0.18 + 0.12 * float(i), 0.26 + 0.1 * float(i) - 0.12 * float(i == 2));
			vec2 r = rot(p - o, 0.8);
			streaks = min(streaks, box(r, vec2(0.035, 0.12 - 0.02 * float(i))));
		}
		return min(cres, streaks);
	}
	return circle(p, 0.18);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	p.y = -p.y;
	float r = length(p);
	float aa = fwidth(r) * 1.2;
	float disc = smoothstep(1.0, 1.0 - aa, r);
	float rim = smoothstep(0.84 + aa, 0.84, r);
	vec3 bg = bg_color.rgb * mix(0.75, 1.2, smoothstep(-0.8, 0.8, p.y));
	vec3 col = mix(rim_color.rgb, bg, rim);
	float d = icon(p * 1.25);
	float ia = fwidth(d);
	float ic = smoothstep(ia, -ia, d);
	float sh = smoothstep(ia, -ia, icon(p * 1.25 + vec2(-0.05, 0.06)));
	col = mix(col, rim_color.rgb, sh * 0.6 * rim);
	col = mix(col, icon_color.rgb, ic * rim);
	ALBEDO = col;
	ALPHA = disc * opacity;
}
