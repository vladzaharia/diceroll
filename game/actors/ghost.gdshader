shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, shadows_disabled;
// Translucent spirit (Hollow Wisp): the KayKit atlas shading tinted toward `tint`, see-through
// in the middle with a bright fresnel rim and a soft inner glow. Same uniforms as tint.gdshader
// so Character.set_tint drives it.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform vec4 tint : source_color = vec4(0.5, 1.0, 0.9, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.9;
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float alpha = 0.42;
uniform float rim = 2.2;

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb * albedo_color.rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 t = tint.rgb * mix(0.4, 1.1, smoothstep(0.02, 0.6, l));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float wave = 0.85 + 0.15 * sin(TIME * 3.0 + UV.y * 20.0);
	ALBEDO = mix(c, t, strength);
	ROUGHNESS = 0.4;
	EMISSION = emission.rgb + tint.rgb * (0.25 + fres * rim) * wave;
	ALPHA = clamp(alpha + fres * 0.55, 0.0, 1.0);
}
