shader_type spatial;
// Camp island top: soft grass patches with a fine speckle, and a trampled dirt clearing around
// the campfire (an ellipse with a ragged, soft edge). Island sides keep their vertex colours.

uniform vec4 grass_a : source_color = vec4(0.2, 0.34, 0.2, 1.0);
uniform vec4 grass_b : source_color = vec4(0.26, 0.42, 0.22, 1.0);
uniform vec4 speck_color : source_color = vec4(0.14, 0.26, 0.16, 1.0);
uniform vec4 dirt_a : source_color = vec4(0.4, 0.29, 0.2, 1.0);
uniform vec4 dirt_b : source_color = vec4(0.48, 0.36, 0.25, 1.0);
uniform vec2 clear_center = vec2(0.0, 1.0);
uniform vec2 clear_radius = vec2(5.6, 4.4);
uniform float edge = 0.18;
uniform float island_half = 15.8;

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
	// clip to the island's squircle outline
	vec2 q = abs(world_pos.xz) / island_half;
	if (pow(pow(q.x, 8.0) + pow(q.y, 8.0), 0.125) > 1.0) {
		discard;
	}
	vec2 p = world_pos.xz;
	float pt = smoothstep(0.3, 0.7, fbm(p * 0.13));
	vec3 grass = mix(grass_a.rgb, grass_b.rgb, pt);
	float sp = noise(p * 3.1) * noise(p * 7.3 + 5.0);
	grass = mix(grass, speck_color.rgb, smoothstep(0.22, 0.45, sp) * 0.6);
	vec2 d = (p - clear_center) / clear_radius;
	float r = length(d) + (fbm(p * 1.4) - 0.5) * 0.22;
	float dm = 1.0 - smoothstep(1.0 - edge, 1.0 + edge, r);
	vec3 dirt = mix(dirt_a.rgb, dirt_b.rgb, fbm(p * 0.9 + 3.0));
	dirt = mix(dirt, dirt * 0.8, smoothstep(0.3, 0.6, noise(p * 5.0)) * 0.5);
	vec3 top = mix(grass, dirt, dm);
	ALBEDO = mix(COLOR.rgb, top, up);
	ROUGHNESS = 0.95;
}
