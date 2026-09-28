shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// A soft, slowly drifting sea of clouds far below the floating island.

uniform vec4 deep_color : source_color = vec4(0.16, 0.1, 0.18, 1.0);
uniform vec4 light_color : source_color = vec4(0.45, 0.32, 0.38, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.7, 0.45, 1.0);
uniform float scale = 0.11;
uniform float speed = 0.012;
uniform float shadow_radius = 13.0;

varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * scale;
	float t = TIME * speed;
	float n = fbm(p + vec2(t, t * 0.6));
	float n2 = fbm(p * 2.2 - vec2(t * 1.4, 0.0));
	float c = smoothstep(0.38, 0.72, n * 0.75 + n2 * 0.25);
	float edge = smoothstep(0.5, 0.62, n) - smoothstep(0.62, 0.8, n);
	vec3 col = mix(deep_color.rgb, light_color.rgb, c);
	col += rim_color.rgb * edge * 0.12;
	float d = length(world_pos.xz);
	col *= mix(0.7, 1.0, smoothstep(shadow_radius * 0.4, shadow_radius * 1.4, d));
	ALBEDO = col;
}
