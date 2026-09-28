class_name Ribbon
extends Control
## Gold title banner with folded tails, used as modal headers.
##
##   var r := Ribbon.make("LEVEL UP!")

var text := "":
	set(v):
		text = v
		update_minimum_size()
		queue_redraw()
var font_size := 38
var color: Color = UiPalette.GOLD
const TAIL := 34.0


static func make(p_text: String, size := 38, p_color: Color = UiPalette.GOLD) -> Ribbon:
	var r := Ribbon.new()
	r.text = p_text
	r.font_size = size
	r.color = p_color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return r


func _get_minimum_size() -> Vector2:
	var w := UiTheme.display_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return Vector2(w + 80 + TAIL * 2.0, font_size * 1.75)


func _draw() -> void:
	var h := size.y
	var body_h := h * 0.82
	var top := (h - body_h) * 0.5 - h * 0.06
	var x0 := TAIL
	var x1 := size.x - TAIL
	var dark := color.darkened(0.5)
	# tails (behind, lower)
	var ty := top + h * 0.2
	var th := body_h
	for side in [-1, 1]:
		var ax: float = x0 + 18.0 if side < 0 else x1 - 18.0
		var ex: float = 0.0 if side < 0 else size.x
		var pts := PackedVector2Array([
			Vector2(ax, ty), Vector2(ex, ty), Vector2(ex + side * -14.0, ty + th * 0.5), Vector2(ex, ty + th), Vector2(ax, ty + th)])
		_poly_outline(pts, dark)
		# fold shadow
		draw_colored_polygon(PackedVector2Array([Vector2(ax, ty + th), Vector2(ax + side * -18.0 * -1.0, ty + th), Vector2(ax, ty + th - h * 0.2)]), color.darkened(0.7))
	# body
	var body := PackedVector2Array([Vector2(x0, top), Vector2(x1, top), Vector2(x1, top + body_h), Vector2(x0, top + body_h)])
	_poly_outline(body, color)
	draw_rect(Rect2(x0 + 2, top + body_h * 0.55, x1 - x0 - 4, body_h * 0.45 - 2), color.darkened(0.18))
	draw_rect(Rect2(x0 + 4, top + 5, x1 - x0 - 8, body_h * 0.2), Color(1, 1, 1, 0.3))
	draw_line(Vector2(x0 + 10, top + body_h - 8), Vector2(x1 - 10, top + body_h - 8), Color(0, 0, 0, 0.15), 2.0)
	# text
	var f := UiTheme.display_font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := Vector2((size.x - w) * 0.5, top + body_h * 0.5 + font_size * 0.36)
	draw_string(f, pos + Vector2(0, 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color.darkened(0.6), 0.9))
	draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, UiPalette.OUTLINE)
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UiPalette.TEXT)


func _poly_outline(pts: PackedVector2Array, fill: Color) -> void:
	draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, UiPalette.OUTLINE, 3.0, true)
