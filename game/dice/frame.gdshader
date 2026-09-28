shader_type canvas_item;

// 2D frame around the 3D tray: walnut rim with gold inlay, inner shadow over the felt,
// transparent outside the rounded rectangle.
uniform vec2 size = vec2(720.0, 320.0);
uniform float radius = 26.0;
uniform float frame = 13.0;
uniform vec3 wood_dark : source_color = vec3(0.13, 0.075, 0.045);
uniform vec3 wood_light : source_color = vec3(0.33, 0.19, 0.1);
uniform vec3 gold : source_color = vec3(0.96, 0.76, 0.4);
uniform float shadow_px = 30.0;
uniform float shadow_alpha = 0.6;

float sd_rrect(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	vec2 p = UV * size - size * 0.5;
	float d = sd_rrect(p, size * 0.5, radius);
	float di = sd_rrect(p, size * 0.5 - frame, max(radius - frame, 3.0));
	float outer = 1.0 - smoothstep(-1.0, 0.0, d);
	float inner = 1.0 - smoothstep(-0.5, 0.5, di);

	// Wood grain: streaks running along the longer side of the frame.
	bool vertical_side = abs(p.x) > size.x * 0.5 - frame - 2.0 && abs(p.y) < size.y * 0.5 - radius;
	vec2 gp = vertical_side ? p.yx : p;
	float wob = vnoise(gp * vec2(0.012, 0.25)) * 5.0 + vnoise(gp * vec2(0.05, 0.6));
	float grain = 0.5 + 0.5 * sin(gp.y * 0.9 + wob * 2.4);
	grain = mix(grain, vnoise(gp * vec2(0.02, 1.4)), 0.35);
	vec3 wood = mix(wood_dark, wood_light, grain * 0.75);
	// Rounded bevel: light from above, darker toward the inner edge.
	float across = clamp(-d / frame, 0.0, 1.0);
	wood *= 0.75 + 0.55 * sin(across * 3.14159) * (p.y < 0.0 ? 1.1 : 0.85);
	float top_light = 1.0 - smoothstep(0.0, 2.5, abs(d + 1.2));
	wood += vec3(0.35, 0.25, 0.15) * top_light * 0.35;
	// Gold inlay lines.
	float l1 = 1.0 - smoothstep(0.55, 1.35, abs(di - 1.8));
	float l2 = 1.0 - smoothstep(0.4, 1.1, abs(d + 4.0));
	vec3 g = gold * (0.85 + 0.3 * vnoise(p * 0.3));
	vec3 fc = mix(wood, g, max(l1, l2 * 0.55));

	float fa = (1.0 - inner) * outer;
	float sh = pow(1.0 - clamp(-di / shadow_px, 0.0, 1.0), 2.2) * shadow_alpha * inner;
	float a = fa + sh * (1.0 - fa);
	vec3 rgb = (fc * fa) / max(a, 1e-4);
	COLOR = vec4(rgb, a);
}
