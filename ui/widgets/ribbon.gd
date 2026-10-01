class_name Ribbon
extends Control
## Title plaque used as modal (and minigame) headers: the RhosGFX 3D Square face in a pack
## family (yellow by default; red GAME OVER / abandon, purple LEVEL UP, green VICTORY) with
## the title in ink Lilita, 72 px tall on phones and 84 px on desktop canvases. Long titles
## shrink to 30 px, then end in an ellipsis within `max_width`. Without the pack it draws the
## pre-reskin gold ribbon with folded tails.
##
##   var r := Ribbon.make("LEVEL UP!", 38, UiPalette.XP)   # colour -> nearest pack family
##   r.family = "green"                                     # or pick the family directly
##   r.max_width = 420.0

const TAIL := 34.0
## Plaque heights (logical px): phone canvas / desktop canvas (>= 1000 both ways).
const PLAQUE_H := 72.0
const PLAQUE_H_LG := 84.0
## Horizontal padding each side of the title on the plaque.
const PAD_X := 48.0
const MIN_FONT := 30

var text := "":
	set(v):
		text = v
		update_minimum_size()
		queue_redraw()
var font_size := 38:
	set(v):
		font_size = v
		update_minimum_size()
		queue_redraw()
var color: Color = UiPalette.GOLD:
	set(v):
		color = v
		queue_redraw()
## Pack family of the plaque ("" = nearest to `color`).
var family := "":
	set(v):
		family = v
		queue_redraw()
## Widest the plaque may be (0 = no limit); the title shrinks, then truncates.
var max_width := 0.0:
	set(v):
		max_width = v
		update_minimum_size()
		queue_redraw()
## Desktop-size plaque (84 px) instead of the phone one (72 px).
var large := false:
	set(v):
		large = v
		update_minimum_size()
		queue_redraw()


static func make(p_text: String, size := 38, p_color: Color = UiPalette.GOLD) -> Ribbon:
	var r := Ribbon.new()
	r.text = p_text
	r.font_size = size
	r.color = p_color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return r


func skinned() -> bool:
	return UiSkin.has("plaque_" + plaque_family())


func plaque_family() -> String:
	return family if family != "" else UiTheme.family_of(color)


func plaque_height() -> float:
	return PLAQUE_H_LG if large else PLAQUE_H


## Title font size after fitting `max_width` (never below MIN_FONT; below that it truncates).
func fitted_font() -> int:
	var fs := clampi(font_size, MIN_FONT, 46) if skinned() else font_size
	if max_width <= 0.0 or text == "":
		return fs
	var avail := max_width - PAD_X * 2.0
	var w := UiTheme.display_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if w > avail and w > 0.0:
		fs = maxi(MIN_FONT, int(floor(fs * avail / w)))
	return fs


## The title as drawn (ellipsis when even MIN_FONT doesn't fit `max_width`).
func shown_text() -> String:
	if max_width <= 0.0:
		return text
	var fs := fitted_font()
	var f := UiTheme.display_font()
	var avail := max_width - PAD_X * 2.0
	if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= avail:
		return text
	var t := text
	while t.length() > 1 and f.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > avail:
		t = t.left(t.length() - 1)
	return t.strip_edges() + "…"


func _get_minimum_size() -> Vector2:
	if not skinned():
		var w0 := UiTheme.display_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		return Vector2(w0 + 80 + TAIL * 2.0, font_size * 1.75)
	var fs := fitted_font()
	var w := UiTheme.display_font().get_string_size(shown_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + PAD_X * 2.0
	if max_width > 0.0:
		w = minf(w, max_width)
	return Vector2(w, plaque_height())


func _draw() -> void:
	if not skinned():
		_draw_ribbon()
		return
	var fam := plaque_family()
	var sb := UiTheme.plaque_box(color if fam == "white" else fam)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var f := UiTheme.display_font()
	var fs := fitted_font()
	var t := shown_text()
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	# centre on the face (the bottom 19 of 64 units are the lip + outline)
	var face_mid := size.y * (4.0 + 46.0 * 0.5) / 64.0
	var base := face_mid + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
	var ink := UiPalette.INK_LABEL if fam != "grey" else UiPalette.TEXT
	draw_string(f, Vector2((size.x - w) * 0.5, base), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)


func _draw_ribbon() -> void:
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
