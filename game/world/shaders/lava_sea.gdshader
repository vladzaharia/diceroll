shader_type spatial;
render_mode cull_disabled, shadows_disabled;
// The molten sea under the Magma island: dark cooled crust plates drifting on a glowing flow,
// bright seams between the plates, hotter where plates thin out. World space.

uniform vec4 crust_color : source_color = vec4(0.07, 0.04, 0.05, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.32, 0.05, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.8, 0.38, 1.0);
uniform vec4 warm_crust : source_color = vec4(0.3, 0.07, 0.04, 1.0);
uniform float scale = 0.3;
uniform float speed = 0.04;
uniform float energy = 1.6;
uniform float seam = 0.06;
uniform vec2 flow = vec2(0.6, 1.0);
// share of the surface that runs hot (0 = all crusted over, 1 = seams glow everywhere)
uniform float hot_share = 0.5;
// glow of the plate interiors near their seams (0 = black plates)
uniform float plate_heat = 0.35;
// seam glow where the surface has crusted over (fraction of a hot seam)
uniform float crust_seam = 0.35;
// distance falloff from the island (world xz origin): full heat inside fade_near, down to
// far_glow by fade_far; beyond, the surface sinks into a dark haze (fog) and loses contrast.
uniform float fade_near = 1000.0;
uniform float fade_far = 2000.0;
uniform float far_glow = 1.0;
uniform vec4 haze_color : source_color = vec4(0.07, 0.025, 0.05, 1.0);
uniform float haze_near = 1000.0;
uniform float haze_far = 2000.0;
uniform float haze_max = 0.0;

varying vec3 world_pos;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash2(i).x;
	float b = hash2(i + vec2(1.0, 0.0)).x;
	float c = hash2(i + vec2(0.0, 1.0)).x;
	float d = hash2(i + vec2(1.0, 1.0)).x;
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// x: F2 - F1 (edge distance), y: F1, z: cell hash
vec3 plates(vec2 p, float t) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	float h = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = hash2(n + g);
			vec2 o = 0.5 + 0.38 * sin(t * 0.6 + 6.2831 * r);
			float d = length(g + o - f);
			if (d < f1) {
				f2 = f1;
				f1 = d;
				h = r.x;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return vec3(f2 - f1, f1, h);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME * speed;
	vec2 p = world_pos.xz * scale + flow * t;
	vec2 warp = vec2(noise(p * 1.7 + t), noise(p * 1.7 - t + 3.0)) - 0.5;
	vec3 pl = plates(p + warp * 0.35, TIME * speed * 6.0);
	// seams narrow and widen along their length (plates grinding)
	float w = seam * (0.5 + noise(p * 3.0 + t * 2.0));
	float edge = 1.0 - smoothstep(0.0, w, pl.x);
	float halo = 1.0 - smoothstep(0.0, w * 4.0, pl.x);
	// some plates are thin and glow through
	float thin = smoothstep(0.72, 1.0, pl.z) * (0.35 + 0.35 * noise(p * 5.0 + t * 3.0));
	// large regions crust over (dim seams), others run hot
	float lo = mix(0.75, 0.0, hot_share);
	float region = smoothstep(lo, lo + 0.5, noise(p * 0.35 + t * 0.5 + 7.0));
	float glow = clamp((edge * (crust_seam + (1.0 - crust_seam) * region)) + halo * 0.18 * region + thin * 0.5 * region, 0.0, 1.0);
	float beat = 0.85 + 0.15 * sin(TIME * 1.1 + pl.z * 12.0);
	vec3 hot = mix(hot_color.rgb, core_color.rgb, edge * edge);
	// plates cool toward their middle: dull red near the seams, near-black in the centre,
	// with fine crackle on top
	float cool = smoothstep(0.05, 0.45, pl.x);
	vec3 crust = mix(warm_crust.rgb, crust_color.rgb, cool) * (0.75 + 0.5 * noise(p * 11.0));
	float dist = length(world_pos.xz);
	float heat_k = mix(1.0, far_glow, smoothstep(fade_near, fade_far, dist));
	float haze = haze_max * smoothstep(haze_near, haze_far, dist);
	ALBEDO = mix(mix(crust, hot * 0.4, glow), haze_color.rgb, haze);
	ROUGHNESS = mix(0.95, 0.5, glow);
	vec3 em = hot * glow * energy * beat + vec3(0.5, 0.08, 0.02) * (1.0 - cool) * plate_heat * region;
	EMISSION = mix(em * heat_k, haze_color.rgb * 0.6, haze);
}
