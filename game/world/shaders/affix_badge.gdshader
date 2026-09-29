shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Affix badge (enemy HUD, board preview chips): a round coloured disc with a dark rim and the
// affix's UiIcons glyph on top. billboard = 1 faces the camera (board chips; the HUD already does).

uniform sampler2D icon : source_color, filter_linear_mipmap;
uniform vec4 bg_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 rim_color : source_color = vec4(0.1, 0.06, 0.08, 1.0);
uniform float opacity = 1.0;
uniform float glow = 0.0;
uniform float billboard = 0.0;
// billboard only: a screen-aligned offset (local units) so chips in a row stay side by side
uniform vec2 offset = vec2(0.0);

void vertex() {
	if (billboard > 0.5) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
			INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
		VERTEX.xy += offset;
	}
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float aa = fwidth(r) * 1.2;
	float disc = 1.0 - smoothstep(0.9 - aa, 0.9, r);
	float outer = 1.0 - smoothstep(1.0 - aa, 1.0, r);
	float rim = outer - disc;
	vec3 bg = mix(bg_color.rgb * 0.72, bg_color.rgb * 1.08, 0.5 - p.y * 0.5);
	vec4 ic = texture(icon, (UV - 0.5) / 0.7 + 0.5);
	float inside = step(abs((UV.x - 0.5) / 0.7), 0.5) * step(abs((UV.y - 0.5) / 0.7), 0.5);
	ic.a *= inside;
	vec3 col = mix(bg, ic.rgb, ic.a * disc);
	col = mix(col, rim_color.rgb, rim);
	col += bg_color.rgb * glow * (1.0 - r * 0.5);
	float halo = glow * (1.0 - smoothstep(0.9, 1.0, r)) ;
	ALBEDO = col;
	ALPHA = max(outer, halo * 0.0) * opacity;
}
