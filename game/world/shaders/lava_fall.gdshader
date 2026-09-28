shader_type spatial;
render_mode cull_disabled, shadows_disabled;
// A falling sheet of lava (UV space: v runs down). Bright streaks race down over a darker
// crust, the edges fray and cool.

uniform vec4 crust_color : source_color = vec4(0.12, 0.04, 0.03, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.36, 0.06, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.82, 0.4, 1.0);
uniform float energy = 2.0;
uniform float speed = 0.9;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;
	float streak = noise(vec2(uv.x * 9.0, uv.y * 1.6 - t)) * 0.6 + noise(vec2(uv.x * 23.0, uv.y * 3.0 - t * 1.7)) * 0.4;
	float edge = smoothstep(0.0, 0.25, uv.x) * smoothstep(1.0, 0.75, uv.x);
	float fray = noise(vec2(uv.y * 6.0 - t, 3.0)) * 0.2;
	float glow = smoothstep(0.35, 0.8, streak) * smoothstep(0.0, 0.2 + fray, min(uv.x, 1.0 - uv.x) * 2.0);
	vec3 hot = mix(hot_color.rgb, core_color.rgb, smoothstep(0.6, 0.95, streak));
	ALBEDO = mix(crust_color.rgb, hot * 0.4, glow);
	ROUGHNESS = 0.6;
	EMISSION = hot * (glow * energy + 0.25 * edge);
	ALPHA = clamp(edge * 1.4 + glow, 0.0, 1.0);
}
