shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, fog_disabled;

// App-icon backdrop: a camera-facing quad with a radial glow (inner -> mid -> outer),
// a soft floor band and a vignette. Drawn first (render_priority -100), behind everything.

uniform vec3 inner : source_color = vec3(1.0, 0.8, 0.4);
uniform vec3 mid : source_color = vec3(0.3, 0.2, 0.4);
uniform vec3 outer : source_color = vec3(0.05, 0.05, 0.12);
uniform vec2 center = vec2(0.5, 0.45);
uniform float radius = 0.62;
uniform float mid_at = 0.35;
uniform float vignette = 0.35;
// Rays: count, strength (0 = none).
uniform float rays = 0.0;
uniform float ray_strength = 0.0;

void fragment() {
	vec2 p = UV - center;
	float r = length(p) / radius;
	vec3 c = mix(inner, mid, smoothstep(0.0, mid_at, r));
	c = mix(c, outer, smoothstep(mid_at, 1.0, r));
	if (ray_strength > 0.0) {
		float a = atan(p.y, p.x);
		float s = pow(0.5 + 0.5 * cos(a * rays), 6.0);
		c += inner * s * ray_strength * (1.0 - smoothstep(0.1, 1.1, r)) * smoothstep(0.05, 0.3, r);
	}
	vec2 q = UV - 0.5;
	c *= 1.0 - vignette * smoothstep(0.35, 0.75, length(q) * 1.1);
	ALBEDO = c;
}
