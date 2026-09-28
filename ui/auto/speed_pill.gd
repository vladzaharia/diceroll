class_name SpeedPill
extends Control
## Compact HUD speed control: a dark pill showing the chevrons icon and "1×" / "2×" / "4×".
## Each tap steps to the next speed (1 -> 2 -> 4 -> 1) and emits speed_picked(speed).
## Persisting is the caller's job (SettingsPanel.set_game_speed).

signal speed_picked(speed: float)

const SPEEDS := [1.0, 2.0, 4.0]
const H := 64.0

var speed := 1.0
var _icon: TextureRect
var _label: Label
var _down := false
var _hover := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Game speed"
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.size = Vector2(28, 28)
	add_child(_icon)
	_label = UiTheme.label("1×", 28, UiPalette.GOLD_BRIGHT, true, 6)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		_down = false
		queue_redraw())
	resized.connect(_place)
	set_speed(1.0, false)


func _get_minimum_size() -> Vector2:
	return Vector2(108, H)


static func next_speed(s: float) -> float:
	for v: float in SPEEDS:
		if v > s + 0.01:
			return v
	return SPEEDS[0]


func set_speed(s: float, animate := true) -> void:
	var changed := not is_equal_approx(s, speed)
	speed = s
	_label.text = "%d×" % int(round(s)) if is_equal_approx(s, round(s)) else "%.1f×" % s
	var hot := s >= 3.9
	_label.label_settings = UiTheme.label_settings(28, UiPalette.HP_BRIGHT.lerp(UiPalette.GOLD_BRIGHT, 0.35) if hot else UiPalette.GOLD_BRIGHT, true, 6)
	_icon.texture = UiIcons.tex("speed", 56, UiPalette.GOLD if not hot else Color("ff9a5a"))
	_place()
	queue_redraw()
	if animate and changed and is_inside_tree():
		UiTheme.pop(self, 1.1, 0.22)


func _place() -> void:
	pivot_offset = size * 0.5
	var sink := 3.0 if _down else 0.0
	var lw := _label.get_minimum_size().x
	var total := 28.0 + 6.0 + lw
	var x := (size.x - total) * 0.5
	_icon.position = Vector2(x, (size.y - 28.0) * 0.5 + sink - 3.0)
	_label.size = _label.get_minimum_size()
	_label.position = Vector2(x + 34.0, (size.y - _label.size.y) * 0.5 + sink - 2.0)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if mb.pressed:
		_down = true
	else:
		var was := _down
		_down = false
		if was and Rect2(Vector2.ZERO, size).has_point(mb.position):
			UiTheme.sfx("click")
			var s := next_speed(speed)
			set_speed(s)
			speed_picked.emit(s)
	_place()
	queue_redraw()


func _draw() -> void:
	var r := size.y * 0.5
	var full := Rect2(Vector2.ZERO, size)
	var sink := 3.0 if _down else 0.0
	draw_style_box(UiTheme.box(UiPalette.OUTLINE, int(r + 2)), full.grow(2))
	draw_style_box(UiTheme.box(Color(0.02, 0.02, 0.06, 0.85), int(r)), full)
	var face_rect := Rect2(0, sink, size.x, size.y - 5.0)
	var face := Color(0.06, 0.07, 0.16, 0.86)
	if _hover:
		face = face.lightened(0.08)
	draw_style_box(UiTheme.box(face, int(r)), face_rect)
	draw_style_box(UiTheme.box(Color(1, 1, 1, 0.05), int(r)), Rect2(face_rect.position + Vector2(6, 3), Vector2(face_rect.size.x - 12, face_rect.size.y * 0.44)))
	var rim := UiTheme.box(Color.TRANSPARENT, int(r), 2, UiPalette.GOLD_FAINT.lerp(UiPalette.GOLD_LINE, 0.4))
	rim.draw_center = false
	draw_style_box(rim, face_rect)
	# three step dots under the label: which of 1× / 2× / 4× is on
	var cx := size.x * 0.5
	var y := face_rect.end.y - 9.0
	for i in SPEEDS.size():
		var on: bool = speed >= float(SPEEDS[i]) - 0.01
		var p := Vector2(cx + (i - 1) * 11.0, y)
		draw_circle(p, 2.6, UiPalette.GOLD_BRIGHT if on else Color(1, 1, 1, 0.18))
