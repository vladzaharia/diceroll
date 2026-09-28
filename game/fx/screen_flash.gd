class_name ScreenFlash
extends CanvasLayer
## Full-screen additive-looking colour flash (combo hook). One per tree, created lazily:
##   ScreenFlash.get_for(node).flash(Color(1, 0.9, 0.4, 0.6))

var _rect: ColorRect
var _tween: Tween


static func get_for(any: Node) -> ScreenFlash:
	var root := any.get_tree().root
	var existing := root.get_node_or_null("ScreenFlash") as ScreenFlash
	if existing:
		return existing
	var f := ScreenFlash.new()
	f.name = "ScreenFlash"
	root.add_child(f)
	return f


func _init() -> void:
	layer = 90
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.color = Color(1, 1, 1, 0)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_rect.material = m
	add_child(_rect)


func flash(color: Color, duration := 0.35) -> void:
	if _tween:
		_tween.kill()
	_rect.color = color
	_tween = create_tween()
	_tween.tween_property(_rect, "color:a", 0.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
