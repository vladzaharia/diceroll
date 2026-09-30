shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// A pack plaque (a 3D-lipped button / container SVG, rasterised once by UiSvg.raster) on one
// camera-facing quad of any aspect: 9-slice UV math, so the corners and the lip keep their
// shape at every width (board landing badges: "5", "5 9", "12").

uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic;
// quad size in world units, the art's size in SVG units and its slices [l, t, r, b] (units)
uniform vec2 quad_size = vec2(0.62, 0.62);
uniform vec2 art_size = vec2(160.0, 64.0);
uniform vec4 slices = vec4(9.0, 9.0, 9.0, 19.0);
// world units per SVG unit (the art's on-screen scale)
uniform float unit = 0.0097;
uniform float opacity = 1.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
}

float slice_axis(float p, float size, float lo, float hi, float art) {
	// p in world units from the low edge; returns the SVG coordinate
	float lo_w = lo * unit;
	float hi_w = hi * unit;
	if (p < lo_w) return p / unit;
	if (p > size - hi_w) return art - (size - p) / unit;
	float mid = max(size - lo_w - hi_w, 1e-4);
	return lo + (p - lo_w) / mid * (art - lo - hi);
}

void fragment() {
	vec2 p = UV * quad_size;
	float u = slice_axis(p.x, quad_size.x, slices.x, slices.z, art_size.x);
	float v = slice_axis(p.y, quad_size.y, slices.y, slices.w, art_size.y);
	vec4 c = texture(tex, vec2(u, v) / art_size);
	ALBEDO = c.rgb;
	ALPHA = c.a * opacity;
}
