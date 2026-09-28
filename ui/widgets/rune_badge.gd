class_name RuneBadge
extends Control
## Round "gem socket" badge for a rune: dark disk, rune-coloured ring, glyph in rune colour.
## Wild gets a rainbow ring. Empty rune id draws a faint empty socket.

var rune: String = "":
	set(v):
		rune = v
		queue_redraw()


static func make(p_rune: String, px := 56.0) -> RuneBadge:
	var b := RuneBadge.new()
	b.rune = p_rune
	b.custom_minimum_size = Vector2(px, px)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var r := s * 0.5
	draw_circle(c + Vector2(0, s * 0.05), r, Color(0, 0, 0, 0.35))
	draw_circle(c, r, UiPalette.OUTLINE)
	if rune == "":
		draw_circle(c, r - 3.0, UiPalette.NAVY_2)
		draw_arc(c, r * 0.62, 0, TAU, 32, Color(1, 1, 1, 0.12), 2.0, true)
		return
	var col := UiPalette.rune_color(rune)
	# ring
	if rune == "wild":
		var n := 30
		for i in n:
			var a0 := TAU * i / n
			draw_arc(c, r - s * 0.07, a0, a0 + TAU / n + 0.03, 4, Color.from_hsv(float(i) / n, 0.7, 1.0), s * 0.12, true)
	else:
		draw_circle(c, r - 2.0, col.darkened(0.1))
		draw_arc(c, r - s * 0.1, PI * 1.1, PI * 1.9, 16, Color(1, 1, 1, 0.35), s * 0.04, true)
	# inner disk
	var inner := r - s * 0.13
	draw_circle(c, inner, col.darkened(0.72))
	draw_circle(c - Vector2(0, inner * 0.25), inner * 0.8, Color(col.darkened(0.55), 0.6))
	var glyph_col := col.lightened(0.12) if rune != "wild" else Color.WHITE
	var tex := UiIcons.tex("rune_" + rune, int(s * 1.6), glyph_col)
	var gs := inner * 1.42
	draw_texture_rect(tex, Rect2(c - Vector2(gs, gs) * 0.5, Vector2(gs, gs)), false)
