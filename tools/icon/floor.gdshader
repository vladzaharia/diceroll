shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// App-icon ground: a large lit plane with a radial colour falloff (inner -> outer) in world XZ,
// so objects cast real contact shadows on it while the "backdrop" stays a clean gradient.

uniform vec3 inner : source_color = vec3(0.2, 0.22, 0.5);
uniform vec3 outer : source_color = vec3(0.05, 0.05, 0.12);
uniform vec2 center = vec2(0.0, 0.0);
uniform float radius = 6.0;
uniform float falloff = 1.4;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float r = length(wpos.xz - center) / radius;
	ALBEDO = mix(inner, outer, pow(clamp(r, 0.0, 1.0), falloff));
	ROUGHNESS = 1.0;
}
