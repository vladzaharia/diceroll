class_name DieFace
extends Control
## A 2D die face: rounded body, drawn pips (or ★ for Wild), rune tint, gold rim for edited
## faces, plus selected / marked / locked / dimmed states. Used in modals and previews.
##
##   var f := DieFace.make(4, "frost", true)   # value, rune, edited
##   f.selected = true

@export_range(0, 6) var value: int = 6:
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
	if glyph != "":
		var f := UiTheme.display_font()
		var fs := int(s * 0.55)
		var w := f.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(top.get_center().x - w * 0.5, top.get_center().y + fs * 0.36), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, pip_col)
	elif star:
		var tex := UiIcons.tex("star", int(s * 1.4), UiPalette.GOLD_BRIGHT)
		var ts := s * 0.64
		draw_texture_rect(tex, Rect2(top.get_center() - Vector2(ts, ts) * 0.5, Vector2(ts, ts)), false)
	elif PIPS.has(value):
		var pr := s * (0.085 if value <= 5 else 0.075)
		var inner := Rect2(top.position + Vector2(s * 0.04, s * 0.02), top.size - Vector2(s * 0.08, s * 0.02))
		for p in PIPS[value]:
			var c: Vector2 = inner.position + inner.size * (p as Vector2)
			draw_circle(c + Vector2(0, pr * 0.18), pr, Color(0, 0, 0, 0.18))
			draw_circle(c, pr, pip_col)
	if locked:
		draw_style_box(UiTheme.box(Color(0.1, 0.02, 0.18, 0.55), r), rect)
		var lt := UiIcons.tex("curse", int(s * 1.2))
		var ls := s * 0.52
		draw_texture_rect(lt, Rect2(rect.get_center() - Vector2(ls, ls) * 0.5, Vector2(ls, ls)), false)
