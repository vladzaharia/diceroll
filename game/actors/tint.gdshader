shader_type spatial;
// Character tint: blends the KayKit atlas colour toward `tint` while keeping the
// atlas' light/dark gradient, so a bone-white skeleton still reads as shaded.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// Glowing cracks (magma creatures): alpha > 0 enables. Object-space cells, so the cracks
// ride with the body.
uniform vec4 crack_color : source_color = vec4(0.0);
uniform float crack_scale = 7.0;
uniform float crack_energy = 2.5;
uniform float crack_sparsity = 0.45;

varying vec3 obj_pos;

vec3 hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}

// x: F2 - F1 (distance to a cell edge), y: hash of the nearest cell
vec2 crack_edge(vec3 p) {
	vec3 n = floor(p);
	vec3 f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	float h = 0.0;
	for (int k = -1; k <= 1; k++)
	for (int j = -1; j <= 1; j++)
	for (int i = -1; i <= 1; i++) {
		vec3 g = vec3(float(i), float(j), float(k));
		vec3 r = hash3(n + g);
		float d = length(g + r - f);
		if (d < f1) { f2 = f1; f1 = d; h = r.z; } else if (d < f2) { f2 = d; }
	}
	return vec2(f2 - f1, h);
}

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb * albedo_color.rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 t = tint.rgb * mix(0.22, 1.1, smoothstep(0.02, 0.6, l));
	ALBEDO = mix(c, t, strength);
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = emission.rgb;
	if (crack_color.a > 0.0) {
		vec2 ce = crack_edge(obj_pos * crack_scale);
		// thin seams, and only around some plates: reads as a few deliberate cracks
		float c = (1.0 - smoothstep(0.0, 0.05, ce.x)) * step(crack_sparsity, ce.y);
		float beat = 0.8 + 0.2 * sin(TIME * 2.0 + obj_pos.y * 6.0);
		ALBEDO = mix(ALBEDO, crack_color.rgb * 0.5, c);
		EMISSION += crack_color.rgb * c * crack_energy * beat * crack_color.a;
	}
}
