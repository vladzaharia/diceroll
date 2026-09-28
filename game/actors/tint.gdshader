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

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb * albedo_color.rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 t = tint.rgb * mix(0.22, 1.1, smoothstep(0.02, 0.6, l));
	ALBEDO = mix(c, t, strength);
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = emission.rgb;
}
