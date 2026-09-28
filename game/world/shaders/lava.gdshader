shader_type spatial;
render_mode cull_disabled, shadows_disabled;
// Slow-flowing molten lava: a dark cooling crust broken by bright glowing veins that drift
// and pulse. World-space, so any plane (the sea under the Magma island, pools, lava tiles)
// flows continuously. Emission drives the glow.

uniform vec4 crust_color : source_color = vec4(0.13, 0.04, 0.035, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.36, 0.05, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.86, 0.42, 1.0);
uniform float scale = 0.35;
uniform float speed = 0.05;
uniform float crust = 0.5;
uniform float energy = 3.0;
uniform float pulse = 0.25;
uniform vec2 flow = vec2(1.0, 0.35);

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
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.07 + vec2(3.1, 1.7);
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
	vec2 warp = vec2(fbm(p + flow * t), fbm(p * 1.3 - flow.yx * t + 4.0));
	float n = fbm(p + warp * 1.6 + flow * t * 0.5);
	// veins: thin bright lines where the warped field crosses 0.5
	float vein = 1.0 - smoothstep(0.0, 0.08, abs(n - 0.5));
	float heat = smoothstep(crust, crust - 0.3, n);
	float glow = clamp(heat * 0.85 + vein * 0.9, 0.0, 1.0);
	float beat = 1.0 + pulse * sin(TIME * 1.6 + n * 9.0);
	vec3 hot = mix(hot_color.rgb, core_color.rgb, smoothstep(0.55, 1.0, glow));
	vec3 col = mix(crust_color.rgb, hot, glow);
	ALBEDO = col * 0.35;
	ROUGHNESS = mix(0.95, 0.4, glow);
	EMISSION = hot * glow * energy * beat;
}
