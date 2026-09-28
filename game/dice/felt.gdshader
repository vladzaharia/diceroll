shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx;

// Tray felt: fibrous noise, soft sheen at grazing angles, radial falloff.
uniform vec3 felt : source_color = vec3(0.08, 0.16, 0.17);
uniform vec3 sheen : source_color = vec3(0.25, 0.4, 0.42);
uniform sampler2D noise_a : filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_b : filter_linear_mipmap, repeat_enable;
uniform vec2 center = vec2(0.0, 0.0);
uniform float falloff = 7.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 w = wpos.xz;
	float n1 = texture(noise_a, w * 0.09).r;
	float n2 = texture(noise_b, w * vec2(1.3, 1.1)).r;
	float fib = texture(noise_b, w * vec2(4.0, 3.7) + n1).r;
	vec3 c = felt * (0.8 + 0.35 * n1) * (0.9 + 0.18 * n2) * (0.94 + 0.12 * fib);
	float r = length((w - center) / vec2(1.0, 0.8)) / falloff;
	c *= mix(1.08, 0.72, smoothstep(0.2, 1.1, r));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	ALBEDO = c;
	EMISSION = sheen * fres * 0.08;
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;
	vec2 g = vec2(dFdx(fib), dFdy(fib));
	NORMAL = normalize(NORMAL + vec3(g.x, g.y, 0.0) * 1.5);
}
