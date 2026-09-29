shader_type spatial;
// KayKit atlas prop drawn through a MultiMesh: optional re-tint toward `tint` (keeping the
// swatch's light/dark gradient, like atlas_tint) and a per-instance colour multiply
// (MultiMesh use_colors) for subtle variation between copies.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, hint_default_white;
uniform vec4 tint : source_color = vec4(1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.85;

varying vec3 inst;

void vertex() {
	inst = COLOR.rgb;
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 t = tint.rgb * mix(0.6, 1.12, smoothstep(0.05, 0.8, l));
	ALBEDO = mix(c, t, strength) * inst;
	ROUGHNESS = roughness;
	EMISSION = emission.rgb;
}
