class_name AutoButton
extends Control
## The HUD "AUTO" toggle: a pill with a looping-arrow icon and the word AUTO. Off it is a
## quiet dark pill with a teal rim; on it lights up teal, the icon spins and a soft glow
## breathes around it. Tap toggles (toggled_by_user); a long press (0.45 s) or a right click
## opens the AUTO settings (settings_requested) without toggling.

signal toggled_by_user(on: bool)
signal settings_requested

const ACCENT := Color("46d9c4")
const ACCENT_DEEP := Color("128a7c")
const LONG_PRESS := 0.45
const H := 64.0

var active := false
var _icon: TextureRect
var _label: Label
var _t := 0.0
var _down_at := -1.0
var _down := false
var _long_fired := false
var _hover := false
var _spin := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_NONE
	tooltip_text = "AUTO plays for you. Long-press for AUTO settings."
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.size = Vector2(38, 38)
	_icon.pivot_offset = Vector2(19, 19)
	add_child(_icon)
	_label = UiTheme.label("AUTO", 28, UiPalette.TEXT, true, 6)
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
	_apply()


func _get_minimum_size() -> Vector2:
	return Vector2(150, H)


func set_active(on: bool, animate := true) -> void:
	if on == active:
		return
	active = on
	_apply()
	if animate and is_inside_tree():
		UiTheme.pop(self, 1.12 if on else 0.94, 0.26)


func _apply() -> void:
	_icon.texture = UiIcons.tex("auto", 76, UiPalette.TEXT_DARK if active else ACCENT)
	_label.label_settings = UiTheme.label_settings(28, UiPalette.TEXT_DARK if active else UiPalette.TEXT, true,
		0 if active else 6)
	if not active:
		_spin = 0.0
		_icon.rotation = 0.0
	_place()
	queue_redraw()


func _place() -> void:
	pivot_offset = size * 0.5
	var sink := 3.0 if _down else 0.0
	var lw := _label.get_minimum_size().x
	# centre the visible glyph + label as one group (the icon has transparent margins)
	var g := GameButton._glyph_rect(_icon.texture)
	var gw := 38.0 * g.size.x
	var total := gw + 10.0 + lw
	var x := (size.x - total) * 0.5
	_icon.position = Vector2(x - 38.0 * g.position.x, (size.y - 38.0) * 0.5 + sink - 1.0)
	_label.position = Vector2(x + gw + 10.0, (size.y - _label.get_minimum_size().y) * 0.5 + sink)
	_label.size = _label.get_minimum_size()


func _process(dt: float) -> void:
	if _down and not _long_fired and _down_at >= 0.0 and _t - _down_at >= LONG_PRESS:
		_long_fired = true
		_down = false
		_place()
		UiTheme.sfx("open")
		settings_requested.emit()
	_t += dt
	if active:
		_spin += dt * 2.4
		_icon.rotation = _spin
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null:
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		accept_event()
		settings_requested.emit()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if mb.pressed:
		_down = true
		_long_fired = false
		_down_at = _t
		_place()
		queue_redraw()
	else:
		var was := _down
		_down = false
		_down_at = -1.0
		_place()
		queue_redraw()
		if was and not _long_fired and Rect2(Vector2.ZERO, size).has_point(mb.position):
			UiTheme.sfx("click")
			set_active(not active)
			toggled_by_user.emit(active)


func _draw() -> void:
	var r := size.y * 0.5
	var full := Rect2(Vector2.ZERO, size)
	var sink := 3.0 if _down else 0.0
	if active:
		# breathing glow: three soft rings
		var k := 0.5 + 0.5 * sin(_t * 3.2)
		for i in 3:
			var g := 4.0 + i * 5.0 + k * 3.0
			var sb := UiTheme.box(Color(ACCENT, (0.20 - i * 0.055) * (0.6 + 0.4 * k)), int(r + g))
			draw_style_box(sb, full.grow(g))
	# outline + lip
	draw_style_box(UiTheme.box(UiPalette.OUTLINE, int(r + 2)), full.grow(2))
	var lip := ACCENT_DEEP if active else Color(0.02, 0.02, 0.06, 0.85)
	draw_style_box(UiTheme.box(lip, int(r)), full)
	var face_rect := Rect2(0, sink, size.x, size.y - 5.0)
	var face := ACCENT if active else Color(0.06, 0.07, 0.16, 0.86)
	if _hover:
		face = face.lightened(0.08)
	draw_style_box(UiTheme.box(face, int(r)), face_rect)
	var gloss := UiTheme.box(Color(1, 1, 1, 0.16 if active else 0.05), int(r))
	draw_style_box(gloss, Rect2(face_rect.position + Vector2(6, 3), Vector2(face_rect.size.x - 12, face_rect.size.y * 0.44)))
	var rim := UiTheme.box(Color.TRANSPARENT, int(r), 2, Color(Color.WHITE, 0.5) if active else Color(ACCENT, 0.75))
	rim.draw_center = false
	draw_style_box(rim, face_rect)
	if active:
		# a bright spark orbiting the rim
		var per := 2.0 * (size.x - size.y) + TAU * r
		var d := fmod(_t * 160.0, per)
		draw_circle(_rim_point(d, face_rect, r), 3.2, Color(1, 1, 1, 0.9))
		draw_circle(_rim_point(d - 9.0, face_rect, r), 2.4, Color(1, 1, 1, 0.45))


## Point at arc length `d` along the pill outline (clockwise from the top-left straight).
func _rim_point(d: float, rect: Rect2, r: float) -> Vector2:
	var straight := rect.size.x - 2.0 * r
	var per := 2.0 * straight + TAU * r
	d = fposmod(d, per)
	var top := rect.position.y + 1.0
	var bot := rect.end.y - 1.0
	var cy := (top + bot) * 0.5
	var rr := (bot - top) * 0.5
	var lx := rect.position.x + r
	var rx := lx + straight
	if d < straight:
		return Vector2(lx + d, top)
	d -= straight
	if d < PI * r:
		var a := -PI * 0.5 + d / r
		return Vector2(rx + cos(a) * rr, cy + sin(a) * rr)
	d -= PI * r
	if d < straight:
		return Vector2(rx - d, bot)
	d -= straight
	var a2 := PI * 0.5 + d / r
	return Vector2(lx + cos(a2) * rr, cy + sin(a2) * rr)
