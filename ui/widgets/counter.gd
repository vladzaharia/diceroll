class_name Counter
extends PanelContainer
## Icon + number pill that ticks up/down when the value changes (gold, treasury, block...).
##
##   var gold := Counter.make("coin", 120)
##   gold.set_value(145, true)

var value: int = 0
var prefix := ""
var _shown: float = 0.0
var _label: Label
var _icon: TextureRect
var _tween: Tween
var _size: int = 30
var _color: Color = UiPalette.TEXT


static func make(icon: String, p_value := 0, font := 30, color: Color = UiPalette.TEXT, style := "pill") -> Counter:
	var c := Counter.new()
	c._size = font
	c._color = color
	c.value = p_value
	c._shown = p_value
	c.add_theme_stylebox_override("panel", UiTheme.panel_box(style))
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UiTheme.hbox(8)
	c.add_child(row)
	c._icon = Icons.rect(icon, int(font * 1.25))
	row.add_child(c._icon)
	c._label = UiTheme.label(str(p_value), font, color, true, 6)
	row.add_child(c._label)
	return c


func set_value(v: int, animate := false) -> void:
	var old := value
	value = v
	if _tween and _tween.is_valid():
		_tween.kill()
	if not animate or not is_inside_tree() or old == v:
		_shown = v
		_label.text = prefix + str(v)
		return
	var dur := clampf(absf(v - old) * 0.03, 0.25, 0.9)
	_tween = create_tween()
	_tween.tween_method(_tick, float(old), float(v), dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var flash := UiPalette.GOLD_BRIGHT if v > old else UiPalette.HP_BRIGHT
	_label.label_settings = UiTheme.label_settings(_size, flash, true, 6)
	_tween.tween_callback(func() -> void: _label.label_settings = UiTheme.label_settings(_size, _color, true, 6))
	UiTheme.pop(_icon, 1.3, 0.3)


func _tick(x: float) -> void:
	_shown = x
	_label.text = prefix + str(int(round(x)))
