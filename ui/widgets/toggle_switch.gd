class_name ToggleSwitch
extends CheckButton
## ON / OFF switch (spec 2.9): the pack's round toggle track (green on, grey off) with the
## round handle sliding left / right (0.12 s), 88x48 px drawn, 88 px tall hit row. Replaces
## the settings ON/OFF GameButtons and the auto-settings _SwitchRow track. Without the pack it
## draws a flat pill + knob.
##
##   var sw := ToggleSwitch.make(true)
##   sw.toggled.connect(func(on: bool) -> void: ...)

const TRACK := Vector2(88, 48)
const SLIDE := 0.12

var _knob := 1.0
var _tween: Tween


static func make(on := false, label := "") -> ToggleSwitch:
	var s := ToggleSwitch.new()
	s.set_pressed_no_signal(on)
	s._knob = 1.0 if on else 0.0
	s.text = label
	return s


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	flat = true
	custom_minimum_size = Vector2(TRACK.x, UiTheme.TOUCH)
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	for ic in ["checked", "unchecked", "checked_disabled", "unchecked_disabled"]:
		add_theme_icon_override(ic, ImageTexture.new())
	toggled.connect(_on_toggled)


func _ready() -> void:
	_knob = 1.0 if button_pressed else 0.0


func _on_toggled(on: bool) -> void:
	UiTheme.sfx("click")
	if _tween and _tween.is_valid():
		_tween.kill()
	if not is_inside_tree():
		_knob = 1.0 if on else 0.0
		queue_redraw()
		return
	_tween = create_tween()
	_tween.tween_method(func(x: float) -> void:
		_knob = x
		queue_redraw(), _knob, 1.0 if on else 0.0, SLIDE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Knob position 0 (off, left) .. 1 (on, right); tests read it.
func knob() -> float:
	return _knob


## The drawn track rect (right-aligned in the control, vertically centred).
func track_rect() -> Rect2:
	var h := minf(TRACK.y, size.y)
	return Rect2(size.x - TRACK.x, (size.y - h) * 0.5, TRACK.x, h)


func _draw() -> void:
	var tr := track_rect()
	var on := button_pressed
	var state := "disabled" if disabled else ("checked" if on else "unchecked")
	var knob_w := tr.size.y * 24.0 / 24.0
	var travel := tr.size.x - knob_w
	if UiSkin.has("toggle_track", state):
		draw_style_box(UiSkin.stylebox("toggle_track", state), tr)
		var kt := UiSkin.texture("toggle_knob", "normal", tr.size.y * 28.0 / 24.0)
		if kt != null:
			var ks := kt.get_size()
			var kx := tr.position.x + travel * _knob
			draw_texture_rect(kt, Rect2(kx + (knob_w - ks.x) * 0.5, tr.position.y + (tr.size.y - ks.y) * 0.5 - 2.0, ks.x, ks.y), false,
				Color(1, 1, 1, 0.6) if disabled else Color.WHITE)
		return
	var col := UiPalette.HEAL if on else UiPalette.DISABLED
	draw_style_box(UiTheme.box(col, int(tr.size.y * 0.5), 3, UiPalette.OUTLINE), tr)
	var c := Vector2(tr.position.x + tr.size.y * 0.5 + travel * _knob, tr.get_center().y)
	draw_circle(c, tr.size.y * 0.5 - 5.0, UiPalette.TEXT)
