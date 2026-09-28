shader_type canvas_item;
// Full-screen swirling iris dissolve for biome changes. progress 0 = clear, 1 = covered.
// Covering closes from the screen edges toward `center` along a noisy, glowing edge;
// uncovering (progress 1 -> 0) opens outward from `center`.

uniform float progress = 0.0;
uniform vec4 color : source_color = vec4(0.08, 0.06, 0.16, 1.0);
uniform vec4 edge : source_color = vec4(1.0, 0.7, 0.35, 1.0);
uniform vec2 center = vec2(0.5, 0.45);
uniform float aspect = 0.5625;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 d = UV - center;
	d.x *= aspect;
	float r = length(d);
	float ang = atan(d.y, d.x);
	// swirl: noise sampled in a rotating polar frame
	float sw = ang + r * 3.2 - TIME * 0.5;
	float n = fbm(vec2(cos(sw), sin(sw)) * 2.2 + r * 4.0 + TIME * 0.15);
	float reach = (1.0 - progress) * 1.35 - 0.1;
	float v = r + (n - 0.5) * 0.42 - reach;
	float aa = fwidth(v) * 1.5 + 0.004;
	float cov = smoothstep(-aa, aa, v);
	float live = step(0.002, progress) * step(progress, 0.998);
	float glow = exp(-abs(v) * 24.0) * live;
	float bands = 0.5 + 0.5 * sin(sw * 5.0 + n * 6.0 - TIME * 2.0);
	vec3 inner = color.rgb * (0.75 + 0.35 * bands) + edge.rgb * 0.08 * n;
	inner = mix(inner, color.rgb * 0.45, smoothstep(0.2, 1.1, r));
	vec3 col = mix(edge.rgb * 1.6, inner, clamp(cov, 0.0, 1.0));
	col += edge.rgb * glow * 1.4;
	COLOR = vec4(col, clamp(max(cov, glow * 0.95), 0.0, 1.0));
}
