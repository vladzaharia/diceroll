shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// The world HUD's one badge (intent, trait, affix, scare, brave, board affix chips): a round
// disc with a pack icon (Icons.tex fixed raster, never a DPITexture) on top.
//   style 1 (C, badges of 40 px or more on screen): the full-colour Outline glyph on a dark navy
//     disc with an accent-coloured rim (the rim carries the intent / trait colour, so the glyph
//     keeps its own colours and never clashes with the disc).
//   style 0 (B, 28 px or less): the glyph as a white silhouette (its dark outline kept as ink)
//     on an accent-coloured disc, which stays legible when the art's detail would blur.
// `style` may be fractional (the HUD crossfades between the two as the badge's size changes).
// billboard = 1 faces the camera (board chips; the unit HUD turns itself).

uniform sampler2D icon : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 bg_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 rim_color : source_color = vec4(0.1, 0.06, 0.08, 1.0);
uniform vec4 disc_color : source_color = vec4(0.07, 0.08, 0.17, 1.0);
uniform float style = 1.0;
uniform float glyph_scale = 0.66;
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
	float c = clamp(style, 0.0, 1.0);
	// C: a thicker accent rim (about 4 px on a 64 px badge) inside a thin ink edge
	float edge_in = mix(0.9, 0.8, c);
	float outer = 1.0 - smoothstep(1.0 - aa, 1.0, r);
	float ink_edge = smoothstep(0.93 - aa, 0.93, r);
	float disc = 1.0 - smoothstep(edge_in - aa, edge_in, r);
	float shade = 0.5 - p.y * 0.5;
	vec3 bg_b = mix(bg_color.rgb * 0.72, bg_color.rgb * 1.08, shade);
	vec3 bg_c = mix(disc_color.rgb * 0.8, disc_color.rgb * 1.25, shade);
	vec3 bg = mix(bg_b, bg_c, c);
	vec2 uv = (UV - 0.5) / glyph_scale + 0.5;
	vec4 ic = texture(icon, uv);
	float inside = step(abs(uv.x - 0.5), 0.5) * step(abs(uv.y - 0.5), 0.5);
	ic.a *= inside;
	// B: coloured art -> white, its dark outline -> ink
	float lum = dot(ic.rgb, vec3(0.299, 0.587, 0.114));
	vec3 flat_w = mix(rim_color.rgb, vec3(1.0, 0.98, 0.93), smoothstep(0.16, 0.3, lum));
	vec3 glyph = mix(flat_w, ic.rgb, c);
	vec3 col = mix(bg, glyph, ic.a * disc);
	// ring between the disc and the ink edge: the accent (C) or the ink rim (B)
	vec3 ring = mix(rim_color.rgb, bg_color.rgb * 1.1, c);
	col = mix(col, ring, (1.0 - disc) * outer);
	col = mix(col, rim_color.rgb, ink_edge * outer);
	col += bg_color.rgb * glow * (1.0 - r * 0.5);
	ALBEDO = col;
	ALPHA = outer * opacity;
}
