class_name UiFitStyleBox
extends StyleBox
## Wraps a 9-slice art box (StyleBoxTexture / UiLayeredStyleBox) whose borders are fixed at
## the art's manifest scale, and shrinks the whole drawing uniformly when the draw rect is
## smaller than those borders (a 40 px chip from 64 px pill art, a 64 px round button from
## the 88 px art, a nearly-empty bar fill). Bigger rects draw the inner box unchanged, so
## the 1-unit stretch band grows as usual. Built by UiSkin for pieces with "fit": true.

@export var inner: StyleBox
## Smallest rect (logical px) the inner box draws without its borders overlapping.
@export var min_rect := Vector2.ZERO


## Uniform shrink factor for a draw rect of `size` (1 = draw as is).
func fit_scale(size: Vector2) -> float:
	var k := 1.0
	if min_rect.x > 0.0 and size.x > 0.0:
		k = minf(k, size.x / min_rect.x)
	if min_rect.y > 0.0 and size.y > 0.0:
		k = minf(k, size.y / min_rect.y)
	return clampf(k, 0.05, 1.0)


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if inner == null:
		return
	var k := fit_scale(rect.size)
	if k >= 0.999:
		inner.draw(to_canvas_item, rect)
		return
	RenderingServer.canvas_item_add_set_transform(to_canvas_item, Transform2D(0.0, Vector2(k, k), 0.0, rect.position))
	inner.draw(to_canvas_item, Rect2(Vector2.ZERO, rect.size / k))
	RenderingServer.canvas_item_add_set_transform(to_canvas_item, Transform2D.IDENTITY)


func _get_draw_rect(rect: Rect2) -> Rect2:
	# the inner art may reach past the rect by its expand margins (scaled with it)
	if inner is StyleBoxTexture:
		var t := inner as StyleBoxTexture
		var k := fit_scale(rect.size)
		return rect.grow_individual(t.expand_margin_left * k, t.expand_margin_top * k,
			t.expand_margin_right * k, t.expand_margin_bottom * k)
	return rect
