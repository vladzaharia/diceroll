shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Round intent badge with a crisp SDF icon.
// kind: 0 attack (sword) 1 block (shield) 2 buff (up arrow) 3 curse (padlock) 4 summon (skull) 5 unknown (dot)

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
