class_name Logo
extends Control
## "DICEROLL" wordmark: deep drop shadow, thick ink outline, bronze inner rim and a vertical
## gold gradient fill (shader), with a tumbling die dotting the middle.

const FILL_SHADER := """
shader_type canvas_item;
uniform vec4 top_col : source_color = vec4(1.0, 0.93, 0.62, 1.0);
uniform vec4 mid_col : source_color = vec4(1.0, 0.76, 0.28, 1.0);
uniform vec4 bot_col : source_color = vec4(0.93, 0.45, 0.12, 1.0);
uniform float y0 = -80.0;
uniform float y1 = 0.0;
varying float ly;
void vertex() { ly = VERTEX.y; }
void fragment() {
	float t = clamp((ly - y0) / (y1 - y0), 0.0, 1.0);
	vec3 c = t < 0.5 ? mix(top_col.rgb, mid_col.rgb, t * 2.0) : mix(mid_col.rgb, bot_col.rgb, (t - 0.5) * 2.0);
	// thin highlight band near the top
	c += vec3(0.25) * smoothstep(0.18, 0.1, abs(t - 0.2)) * 0.6;
	COLOR = vec4(c, COLOR.a);
}
"""

var text := "DICEROLL"
var font_size := 132
var _fill: _Layer
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill = _Layer.new()
	_fill.logo = self
	_fill.fill = true
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = FILL_SHADER
	mat.shader = sh
	_fill.material = mat
	add_child(_fill)
	resized.connect(func() -> void:
		_fill.size = size
		queue_redraw())


func _get_minimum_size() -> Vector2:
	var w := UiTheme.display_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return Vector2(w + 40, font_size * 1.25)


func baseline() -> Vector2:
	var w := UiTheme.display_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return Vector2((size.x - w) * 0.5, size.y * 0.5 + font_size * 0.36)


func _process(delta: float) -> void:
	_t += delta
	var m := _fill.material as ShaderMaterial
	var b := baseline()
	m.set_shader_parameter("y0", b.y - font_size * 0.78)
	m.set_shader_parameter("y1", b.y + font_size * 0.04)


func _draw() -> void:
	var f := UiTheme.display_font()
	var b := baseline()
	# long drop shadow
	for k in range(10, 0, -2):
		draw_string_outline(f, b + Vector2(0, k), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 26, Color(0.02, 0.01, 0.05, 0.25))
	draw_string_outline(f, b + Vector2(0, 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 26, Color(0.02, 0.01, 0.05, 0.8))
	draw_string_outline(f, b, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 26, UiPalette.OUTLINE)
	draw_string_outline(f, b, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 12, Color("7a3a10"))


class _Layer:
	extends Control
	var logo: Logo
	var fill := true

	func _draw() -> void:
		var f := UiTheme.display_font()
		draw_string(f, logo.baseline(), logo.text, HORIZONTAL_ALIGNMENT_LEFT, -1, logo.font_size, Color.WHITE)
