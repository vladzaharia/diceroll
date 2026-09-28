shader_type spatial;
// A BlockBits cube whose bright texels glow and pulse (the lava block): the atlas colour
// stays the albedo, and its warm, bright parts become emission.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, hint_default_white;
uniform vec4 glow_color : source_color = vec4(1.0, 0.45, 0.1, 1.0);
uniform float energy = 2.4;
uniform float pulse = 0.3;
uniform float speed = 1.4;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float warm = clamp((c.r - c.b) * 1.6, 0.0, 1.0);
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	float mask = warm * smoothstep(0.25, 0.75, l);
	float beat = 1.0 + pulse * sin(TIME * speed + (world_pos.x + world_pos.z) * 0.9);
	ALBEDO = c * mix(1.0, 0.6, mask);
	ROUGHNESS = mix(0.9, 0.45, mask);
	EMISSION = mix(glow_color.rgb, c, 0.35) * mask * energy * beat;
}
