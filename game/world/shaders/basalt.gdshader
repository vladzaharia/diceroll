shader_type spatial;
// Calm volcanic basalt for the Magma Depths terrain: large, low-contrast slabs with thin dark
// seams, lighter ash on top faces, and a few thin glowing cracks (sparse, deliberate). World
// space, so neighbouring blocks read as one continuous floor instead of a checkerboard.

uniform vec4 top_color : source_color = vec4(0.35, 0.31, 0.32, 1.0);
uniform vec4 side_color : source_color = vec4(0.085, 0.08, 0.1, 1.0);
uniform vec4 seam_color : source_color = vec4(0.08, 0.065, 0.075, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.42, 0.1, 1.0);
uniform float slab = 0.55;          // slab cells per world unit
uniform float crack_density = 0.035; // fraction of slabs with a glowing crack edge
uniform float crack_energy = 2.2;
uniform float variation = 0.18;
uniform float heat_low = 1.0;       // side faces glow toward the bottom (lava below)

varying vec3 world_pos;
varying vec3 world_nrm;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// x: F1, y: F2 - F1 (edge distance), z: cell hash
vec3 voronoi(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	vec2 id = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash2(n + g) * 0.8 + 0.1;
			float d = length(g + o - f);
			if (d < f1) {
				f2 = f1;
				f1 = d;
				id = n + g;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return vec3(f1, f2 - f1, hash2(id).x);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float up = smoothstep(0.5, 0.9, world_nrm.y);
	vec2 uv = mix(vec2(world_pos.x + world_pos.z, world_pos.y * 1.3), world_pos.xz, up) * slab;
	// wobble the slab edges so seams are irregular, not straight polygon lines
	vec2 wob = vec2(voronoi(uv * 2.3 + 5.0).x, voronoi(uv * 2.3 - 3.0).x) - 0.5;
	vec3 v = voronoi(uv + wob * 0.28);
	vec3 base = mix(side_color.rgb, top_color.rgb, up);
	base *= 1.0 + (v.z - 0.5) * variation * 2.0;
	// fine grain so slabs are not flat plastic
	vec3 g = voronoi(uv * 6.0);
	base *= 0.94 + g.x * 0.1;
	float seam = 1.0 - smoothstep(0.02, 0.07, v.y);
	vec3 col = mix(base, seam_color.rgb, seam * 0.85);
	// sparse glowing cracks along some slab edges
	float cracked = step(1.0 - crack_density, v.z);
	float crack = cracked * (1.0 - smoothstep(0.0, 0.03, v.y)) * smoothstep(0.35, 0.6, g.x + 0.3);
	float beat = 0.8 + 0.2 * sin(TIME * 1.3 + v.z * 20.0);
	// side faces pick up the lava glow near their bottom edge
	float low = (1.0 - up) * heat_low * smoothstep(-0.4, -2.6, world_pos.y);
	ALBEDO = col;
	ROUGHNESS = mix(0.92, 0.6, seam);
	SPECULAR = 0.3;
	EMISSION = glow_color.rgb * (crack * crack_energy * beat + low * 0.35);
}
