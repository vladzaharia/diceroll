shader_type spatial;
// Re-colours a KayKit atlas-textured prop toward `tint`, keeping the swatch's
// vertical light/dark gradient so the result still reads as the KayKit style.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, hint_default_white;
uniform vec4 tint : source_color = vec4(1.0);
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.85;

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 t = tint.rgb * mix(0.6, 1.12, smoothstep(0.05, 0.8, l));
	ALBEDO = mix(c, t, strength);
	ROUGHNESS = roughness;
	EMISSION = emission.rgb;
}
