class_name DieFace
extends Control
## A 2D die face: rounded body, drawn pips 1-6, crisp numerals 7-9, an empty inset with a
## faint cross for a blank 0 (or ★ for Wild), rune tint, gold rim for edited faces, the
## die kind's corner mark, plus selected / marked / locked / dimmed states. Used in modals
## and previews.
##
##   var f := DieFace.make(4, "frost", true)   # value, rune, edited
##   f.kind = "giant"
##   f.selected = true

@export_range(0, 9) var value: int = 6:
	set(v):
		value = v
		queue_redraw()
@export var rune: String = "":
	set(v):
		rune = v
		queue_redraw()
@export var edited := false:
	set(v):
		edited = v
		queue_redraw()
@export var star := false:
	set(v):
		star = v
		queue_redraw()
@export var selected := false:
	set(v):
		selected = v
		queue_redraw()
@export var locked := false:
	set(v):
		locked = v
		queue_redraw()
@export var dimmed := false:
	set(v):
		dimmed = v
		queue_redraw()
## Die kind (DiceKinds id): a small coloured corner mark (none for standard).
var kind := "standard":
	set(v):
		kind = v
		queue_redraw()
## Text label drawn instead of pips (e.g. "?" for an unknown face).
var glyph := ""

const PIPS := {
	1: [Vector2(0.5, 0.5)],
	2: [Vector2(0.27, 0.27), Vector2(0.73, 0.73)],
	3: [Vector2(0.27, 0.27), Vector2(0.5, 0.5), Vector2(0.73, 0.73)],
	4: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
	5: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.5, 0.5), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
	6: [Vector2(0.27, 0.25), Vector2(0.73, 0.25), Vector2(0.27, 0.5), Vector2(0.73, 0.5), Vector2(0.27, 0.75), Vector2(0.73, 0.75)],
}


static func make(p_value: int, p_rune := "", p_edited := false, px := 64.0) -> DieFace:
	var f := DieFace.new()
	f.value = p_value
	f.rune = p_rune
	f.edited = p_edited
	f.custom_minimum_size = Vector2(px, px)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return f


static func body_color(p_rune: String) -> Color:
	if p_rune == "" or p_rune == "wild":
		return UiPalette.DIE_BODY
	return UiPalette.DIE_BODY.lerp(UiPalette.rune_color(p_rune), 0.62)


## The kind's corner mark (same shapes as the 3D die shader) centred at `c`, radius `r`.
func _draw_kind_mark(c: Vector2, r: float, col: Color, dim: bool) -> void:
	draw_kind_mark(self, UiPalette.kind_mark(kind), c, r, col.darkened(0.3) if dim else col)


## Draws kind mark `mark` (UiPalette.KIND ids) on any CanvasItem.
static func draw_kind_mark(ci: CanvasItem, mark: int, c: Vector2, r: float, col: Color) -> void:
	var w := maxf(1.5, r * 0.5)
	match mark:
		1, 2:
			var sgn := -1.0 if mark == 2 else 1.0
			var pts := PackedVector2Array([c + Vector2(-r, -r * 0.45 * sgn), c + Vector2(0, r * 0.5 * sgn), c + Vector2(r, -r * 0.45 * sgn)])
			ci.draw_polyline(pts, col, w, true)
		3:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), col)
		4:
			ci.draw_arc(c, r * 0.7, 0.0, TAU, 16, col, w * 0.8, true)
		5:
			ci.draw_rect(Rect2(c - Vector2(r * 0.8, r * 0.55), Vector2(r * 1.6, r * 1.25)), col)
		6:
			ci.draw_line(c + Vector2(-r * 0.4, -r), c + Vector2(-r * 0.4, r), col, w * 0.9, true)
			ci.draw_line(c + Vector2(r * 0.4, -r), c + Vector2(r * 0.4, r), col, w * 0.9, true)
		7:
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI * 0.5 + i * PI / 5.0
				var rr := r * (1.1 if i % 2 == 0 else 0.45)
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			ci.draw_colored_polygon(pts, col)
		8:
			var b := r
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-b, b * 0.6), c + Vector2(-b, -b * 0.7), c + Vector2(-b * 0.45, 0),
				c + Vector2(0, -b), c + Vector2(b * 0.45, 0), c + Vector2(b, -b * 0.7), c + Vector2(b, b * 0.6)]), col)


func _draw() -> void:

	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) * 0.5
	var rect := Rect2(o, Vector2(s, s))
	var r := int(s * 0.2)
	var body := body_color(rune)
	if dimmed:
		body = body.darkened(0.45)
	# selection glow
	if selected:
		var glow := UiTheme.box(Color(0, 0, 0, 0), r + 6, 0, Color.TRANSPARENT, int(s * 0.18), Color(1.0, 0.8, 0.3, 0.75), Vector2.ZERO)
		draw_style_box(glow, rect)
	# outline
	draw_style_box(UiTheme.box(UiPalette.OUTLINE, r + 2), rect.grow(maxf(2.0, s * 0.03)))
	# side/bottom shade to fake a bevel
	draw_style_box(UiTheme.box(body.darkened(0.28), r), rect)
	var top := Rect2(rect.position, rect.size - Vector2(0, s * 0.07))
	draw_style_box(UiTheme.box(body, r), top)
	# top gloss
	var gl := UiTheme.box(Color(1, 1, 1, 0.22), r)
	draw_style_box(gl, Rect2(top.position + Vector2(s * 0.08, s * 0.05), Vector2(s * 0.84, s * 0.3)))
	# wild: rainbow rim
	if rune == "wild" and s >= 56.0:
		var n := 24
		for i in n:
			var a0 := TAU * i / n
			var c := Color.from_hsv(float(i) / n, 0.65, 1.0)
			draw_arc(rect.get_center(), s * 0.47, a0, a0 + TAU / n + 0.02, 4, c, maxf(2.0, s * 0.05), true)
	# edited: gold rim
	if edited:
		var rim := UiTheme.box(Color.TRANSPARENT, r, maxi(2, int(s * 0.07)), UiPalette.GOLD_BRIGHT)
		rim.draw_center = false
		draw_style_box(rim, top.grow(-1))
	var pip_col := UiPalette.DIE_PIP if body.get_luminance() > 0.45 else Color("fff6e6")
	if dimmed:
		pip_col.a = 0.6
	if glyph != "" or (value >= 7 and not star):
		var txt := glyph if glyph != "" else str(value)
		var f := UiTheme.display_font()
		var fs := int(s * (0.55 if glyph != "" else 0.68))
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := Vector2(top.get_center().x - w * 0.5, top.get_center().y + fs * 0.36)
		draw_string(f, at + Vector2(0, fs * 0.05), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.18))
		draw_string(f, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, pip_col)
	elif value <= 0 and not star:
		# blank face: an empty inset with a faint cross
		var ins := Rect2(top.get_center() - Vector2(s, s) * 0.24, Vector2(s, s) * 0.48)
		var ib := UiTheme.box(Color(0, 0, 0, 0.07), int(s * 0.1), maxi(1, int(s * 0.035)), Color(pip_col, 0.38))
		draw_style_box(ib, ins)
		var cc := top.get_center()
		var k := s * 0.09
		var lw := maxf(1.0, s * 0.035)
		draw_line(cc - Vector2(k, k), cc + Vector2(k, k), Color(pip_col, 0.32), lw, true)
		draw_line(cc + Vector2(-k, k), cc + Vector2(k, -k), Color(pip_col, 0.32), lw, true)
	elif star:
		var tex := Icons.tex("die_wild_face" if Icons.is_mapped("die_wild_face") else "star", int(s * 1.4), UiPalette.GOLD_BRIGHT)
		var ts := s * 0.64
		draw_texture_rect(tex, Rect2(top.get_center() - Vector2(ts, ts) * 0.5, Vector2(ts, ts)), false)
	elif PIPS.has(value):
		var pr := s * (0.085 if value <= 5 else 0.075)
		var inner := Rect2(top.position + Vector2(s * 0.04, s * 0.02), top.size - Vector2(s * 0.08, s * 0.02))
		for p in PIPS[value]:
			var c: Vector2 = inner.position + inner.size * (p as Vector2)
			draw_circle(c + Vector2(0, pr * 0.18), pr, Color(0, 0, 0, 0.18))
			draw_circle(c, pr, pip_col)
	if kind != "standard" and UiPalette.kind_mark(kind) > 0 and s >= 26.0:
		_draw_kind_mark(top.position + Vector2(s * 0.14, s * 0.14), s * 0.085, UiPalette.kind_color(kind), dimmed)
	if locked:
		draw_style_box(UiTheme.box(Color(0.1, 0.02, 0.18, 0.55), r), rect)
		var lt := Icons.tex("die_locked" if Icons.is_mapped("die_locked") else "curse", int(s * 1.2))
		var ls := s * 0.52
		draw_texture_rect(lt, Rect2(rect.get_center() - Vector2(ls, ls) * 0.5, Vector2(ls, ls)), false)
