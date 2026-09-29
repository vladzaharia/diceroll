shader_type spatial;
// Calm world-space ground for the BlockBits biomes' flat paving (Glade meadow, Frostpeak
// snowfield): soft low-frequency patches between two colours, a fine speckle (clover, pebbles,
// snow grain), optional glints, and earthy sides with a lip of the top colour. Plain boxes use
// it, so the floor reads as one surface instead of a grid of cubes.

uniform vec4 top_a : source_color = vec4(0.36, 0.62, 0.24, 1.0);
uniform vec4 top_b : source_color = vec4(0.58, 0.74, 0.3, 1.0);
uniform vec4 speck_color : source_color = vec4(0.24, 0.46, 0.16, 1.0);
uniform vec4 side_color : source_color = vec4(0.5, 0.36, 0.24, 1.0);
uniform float patch_scale = 0.11;
uniform float speck_scale = 3.2;
uniform float speck_amount = 0.35;
uniform float glint = 0.0;
uniform float lip = 0.22;
uniform float roughness = 0.9;

varying vec3 world_pos;
varying vec3 world_nrm;

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
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float up = step(0.5, world_nrm.y);
	vec2 p = world_pos.xz;
	float pt = smoothstep(0.3, 0.7, fbm(p * patch_scale));
	vec3 top = mix(top_a.rgb, top_b.rgb, pt);
	float sp = noise(p * speck_scale) * noise(p * speck_scale * 2.3 + 5.0);
	top = mix(top, speck_color.rgb, smoothstep(0.25, 0.45, sp) * speck_amount);
	top *= 0.95 + 0.1 * noise(p * 14.0);
	// sides: earth below a lip of the top colour (with a wavy edge)
	float wave = 0.06 * sin(world_pos.x * 5.0 + world_pos.z * 4.0);
	float on_lip = step(-lip + wave, world_pos.y);
	vec3 side = side_color.rgb * (0.85 + 0.3 * noise(vec2(world_pos.x + world_pos.z, world_pos.y) * 4.0));
	side = mix(side, top_a.rgb * 0.9, on_lip);
	ALBEDO = mix(side, top, up);
	ROUGHNESS = roughness;
	float g = step(0.985, hash(floor(p * 9.0))) * glint * up;
	EMISSION = vec3(g) * (0.6 + 0.4 * sin(TIME * 3.0 + hash(floor(p * 9.0)) * 30.0));
}
