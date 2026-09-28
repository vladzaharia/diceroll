class_name StatBar
extends Control
## Rounded progress bar with a glossy fill, a delayed "ghost" fill that drains after damage
## (or leads on heals), optional centred "value / max" text and an optional overlay badge.
##
##   var hp := StatBar.make(UiPalette.HP, 44)
##   hp.set_values(42, 64)             # snap
##   hp.set_values(30, 64, true)       # animate: fill snaps, ghost drains

var fill_color: Color = UiPalette.HP
var ghost_color: Color = Color("ffd7a0")
var track_color: Color = Color(0.02, 0.02, 0.07, 0.85)
var show_text := true
var text_size := 26
var text_format := "%d / %d"
var value: float = 1.0
var max_value: float = 1.0
## Fraction drawn for the trailing ghost segment.
var ghost: float = 1.0
## Fraction drawn for the main fill (animated towards value/max).
var shown: float = 1.0
var _tween: Tween
var _text_value: int = 0


static func make(color: Color, height := 36.0, text := true) -> StatBar:
	var b := StatBar.new()
	b.fill_color = color
	b.custom_minimum_size = Vector2(120, height)
	b.show_text = text
	b.text_size = int(height * 0.62)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func set_values(v: float, m: float, animate := false) -> void:
	var old := shown
	value = v
	max_value = maxf(1.0, m)
	var f := clampf(v / max_value, 0.0, 1.0)
	if _tween and _tween.is_valid():
		_tween.kill()
	if not animate or not is_inside_tree():
		shown = f
		ghost = f
		_text_value = int(v)
		queue_redraw()
		return
	_tween = create_tween().set_parallel(true)
	if f < old:
		# damage: fill snaps down quickly, ghost lingers then drains
		shown = old
		ghost = old
		_tween.tween_method(_set_shown, old, f, 0.12)
		_tween.tween_method(_set_ghost, old, f, 0.5).set_delay(0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	else:
		# heal/fill: ghost leads, fill catches up
		ghost = f
		_tween.tween_method(_set_shown, old, f, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_text, float(_text_value), v, 0.4)
	UiTheme.pop(self, 1.05, 0.25)


func _set_shown(x: float) -> void:
	shown = x
	queue_redraw()


func _set_ghost(x: float) -> void:
	ghost = x
	queue_redraw()


func _set_text(x: float) -> void:
	_text_value = int(round(x))
	queue_redraw()


func _draw() -> void:
	var h := size.y
	var r := int(h * 0.5)
	var full := Rect2(Vector2.ZERO, size)
	draw_style_box(UiTheme.box(UiPalette.OUTLINE, r + 2), full.grow(2))
	draw_style_box(UiTheme.box(track_color, r), full)
	var inner := full.grow(-3)
	var ir := int(inner.size.y * 0.5)
	var gw := inner.size.x * ghost
	var fw := inner.size.x * shown
	if gw > 1.0 and gw > fw:
		draw_style_box(UiTheme.box(ghost_color, ir), Rect2(inner.position, Vector2(maxf(gw, inner.size.y), inner.size.y)))
	if fw > 0.5:
		var fr := Rect2(inner.position, Vector2(maxf(fw, inner.size.y), inner.size.y))
		draw_style_box(UiTheme.box(fill_color.darkened(0.25), ir), fr)
		draw_style_box(UiTheme.box(fill_color, ir), Rect2(fr.position, Vector2(fr.size.x, fr.size.y * 0.82)))
		var gloss := UiTheme.box(Color(1, 1, 1, 0.28), ir)
		draw_style_box(gloss, Rect2(fr.position + Vector2(ir * 0.6, fr.size.y * 0.12), Vector2(maxf(0.0, fr.size.x - ir * 1.2), fr.size.y * 0.26)))
	if show_text:
		var f := UiTheme.display_font()
		var t := text_format % [_text_value, int(max_value)] if text_format.count("%d") == 2 else text_format % _text_value
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
		var pos := Vector2((size.x - w) * 0.5, size.y * 0.5 + text_size * 0.36)
		draw_string_outline(f, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, 7, UiPalette.OUTLINE)
		draw_string(f, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, UiPalette.TEXT)
