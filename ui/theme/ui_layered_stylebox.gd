class_name UiLayeredStyleBox
extends StyleBox
## Draws several style boxes on top of each other in one StyleBox (bottom first): RhosGFX
## panels are a Container (fill) under a Frame (hollow border), and bars are a container
## under a fill. Content margins are this box's own; each layer keeps its own 9-slice and
## expand margins (negative expand = inset). Built by UiSkin from a ui_pack.json "layers" list.

@export var layers: Array[StyleBox] = []


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	for l in layers:
		if l != null:
			l.draw(to_canvas_item, rect)


func _get_draw_rect(rect: Rect2) -> Rect2:
	var r := rect
	for l in layers:
		if l is StyleBoxTexture:
			var t := l as StyleBoxTexture
			r = r.merge(rect.grow_individual(t.expand_margin_left, t.expand_margin_top,
				t.expand_margin_right, t.expand_margin_bottom))
	return r
