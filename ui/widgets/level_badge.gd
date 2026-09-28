class_name LevelBadge
extends Control
## Round level medallion with an XP progress ring.

var level := 1
var xp_frac := 0.0
var _shown := 0.0
var _tween: Tween


static func make(px := 92.0) -> LevelBadge:
	var b := LevelBadge.new()
	b.custom_minimum_size = Vector2(px, px)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func set_level(p_level: int, frac: float, animate := false) -> void:
	var leveled := p_level > level
	level = p_level
	xp_frac = clampf(frac, 0.0, 1.0)
	if _tween and _tween.is_valid():
		_tween.kill()
	if not animate or not is_inside_tree():
		_shown = xp_frac
		queue_redraw()
		return
	_tween = create_tween()
	if leveled:
		_tween.tween_method(_set_shown, _shown, 1.0, 0.3)
		_tween.tween_callback(func() -> void:
			_shown = 0.0
			UiTheme.pop(self, 1.25, 0.4))
	_tween.tween_method(_set_shown, 0.0 if leveled else _shown, xp_frac, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_shown(x: float) -> void:
	_shown = x
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var r := s * 0.5
	draw_circle(c + Vector2(0, 4), r, Color(0, 0, 0, 0.35))
	draw_circle(c, r, UiPalette.OUTLINE)
	draw_circle(c, r - 3, Color(0.04, 0.04, 0.1, 0.95))
	var ring_r := r - 9.0
	var ring_w := 9.0
	draw_arc(c, ring_r, 0, TAU, 48, Color(UiPalette.XP_DARK, 0.7), ring_w, true)
	if _shown > 0.001:
		draw_arc(c, ring_r, -PI * 0.5, -PI * 0.5 + TAU * _shown, 48, UiPalette.XP, ring_w, true)
	var inner := r - 16.0
	draw_circle(c, inner, UiPalette.GOLD_DEEP)
	draw_circle(c, inner - 3, UiPalette.NAVY_2)
	draw_circle(c - Vector2(0, inner * 0.3), inner * 0.7, Color(1, 1, 1, 0.05))
	var f := UiTheme.display_font()
	var small := int(s * 0.17)
	var big := int(s * 0.36)
	var t1 := "LV"
	var w1 := f.get_string_size(t1, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
	draw_string(f, Vector2(c.x - w1 * 0.5, c.y - inner * 0.28), t1, HORIZONTAL_ALIGNMENT_LEFT, -1, small, UiPalette.GOLD)
	var t2 := str(level)
	var w2 := f.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
	var p2 := Vector2(c.x - w2 * 0.5, c.y + inner * 0.62)
	draw_string_outline(f, p2, t2, HORIZONTAL_ALIGNMENT_LEFT, -1, big, 6, UiPalette.OUTLINE)
	draw_string(f, p2, t2, HORIZONTAL_ALIGNMENT_LEFT, -1, big, UiPalette.TEXT)
