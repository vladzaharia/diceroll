class_name ScrollFade
extends TextureRect
## Bottom fade over a scroll area that can scroll further (plan c 3.3): a navy -> transparent
## gradient along the bottom edge of the visible scroll rect, shown only while more content
## sits below the fold, so a cut-off list reads as "scroll for more" on phones (where the
## scrollbar is hidden). It is a sibling overlay (never part of the scroll content) that
## follows the scroll rect every frame, so it tracks modal open tweens and the _fit scale.
##
##   ScrollFade.attach(self, _scroll, UiPalette.NAVY_2, _frame)   # in a UiModal subclass's _build()

## Fade height in logical px (at the frame's scale 1).
const HEIGHT := 40.0

var scroll: ScrollContainer
## Follows this node's alpha (a modal's frame during its open / close tweens).
var alpha_src: CanvasItem


static func attach(host: Control, p_scroll: ScrollContainer, color: Color = UiPalette.NAVY_2,
		p_alpha_src: CanvasItem = null) -> ScrollFade:
	var f := ScrollFade.new()
	f.alpha_src = p_alpha_src
	f.name = "ScrollFade"
	f.scroll = p_scroll
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	f.stretch_mode = TextureRect.STRETCH_SCALE
	f.texture = UiTheme.vgradient(Color(color, 0.0), Color(color, 0.95))
	f.z_index = 1
	f.visible = false
	host.add_child(f)
	return f


## True when content continues below the visible part.
func has_more() -> bool:
	if scroll == null or not is_instance_valid(scroll) or not scroll.is_visible_in_tree():
		return false
	var bar := scroll.get_v_scroll_bar()
	return bar != null and bar.max_value - bar.page > 1.0 and scroll.scroll_vertical < bar.max_value - bar.page - 2.0


func _process(_dt: float) -> void:
	var on := has_more()
	visible = on
	if not on:
		return
	var host := get_parent() as Control
	if host == null:
		return
	var inv := host.get_global_transform().affine_inverse()
	var r := scroll.get_global_rect()
	var p0 := inv * r.position
	var p1 := inv * r.end
	var k := scroll.get_global_transform().get_scale().y / maxf(host.get_global_transform().get_scale().y, 0.001)
	var h := minf(HEIGHT * k, (p1.y - p0.y) * 0.4)
	position = Vector2(p0.x, p1.y - h)
	size = Vector2(p1.x - p0.x, h)
	modulate.a = alpha_src.modulate.a if alpha_src != null and is_instance_valid(alpha_src) else 1.0
