shader_type sky;
// Stylised gradient sky: zenith/horizon/ground bands, a soft sun glow and optional stars.

uniform vec3 top_color : source_color = vec3(0.12, 0.14, 0.3);
uniform vec3 horizon_color : source_color = vec3(0.9, 0.6, 0.45);
uniform vec3 bottom_color : source_color = vec3(0.1, 0.08, 0.12);
uniform vec3 glow_color : source_color = vec3(1.0, 0.7, 0.4);
uniform vec3 glow_dir = vec3(0.0, 0.15, -1.0);
uniform float glow_power = 8.0;
uniform float glow_strength = 0.6;
uniform float horizon_blend = 0.45;
uniform float stars = 0.0;
uniform float energy = 1.0;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float y = d.y;
	vec3 col = mix(horizon_color, top_color, smoothstep(-0.02, horizon_blend, y));
	col = mix(col, bottom_color, smoothstep(0.0, -0.35, y));
	float g = max(dot(d, normalize(glow_dir)), 0.0);
	col += glow_color * pow(g, glow_power) * glow_strength;
	col += glow_color * pow(g, glow_power * 8.0) * glow_strength * 0.8;
	if (stars > 0.0 && y > 0.0) {
		vec3 cell = floor(d * 160.0);
		float h = hash(cell);
		float s = smoothstep(0.985, 1.0, h) * smoothstep(0.02, 0.35, y);
		float tw = 0.6 + 0.4 * sin(TIME * (1.0 + h * 3.0) + h * 40.0);
		col += vec3(0.9, 0.95, 1.0) * s * stars * tw;
	}
	COLOR = col * energy;
}
