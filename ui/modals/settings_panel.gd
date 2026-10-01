class_name SettingsPanel
extends UiModal
## Settings: Master / Music / SFX volume (via the Audio autoload, which persists them) and
## game speed 1× / 2× / 4× (persisted in user://settings.cfg [game] speed).
## UI size 90 / 100 / 115 / 130 % (accessibility; [display] ui_size) scales the whole 2D UI
## via the window's content_scale_factor; every layout (HUD column, tray, camera framing)
## adapts to the resulting logical canvas.
## Desktop builds add the Controls list (every shortcut with its keycaps, spec 6) and all
## builds end with the credits. One exit: the header close button / Esc / backdrop (no DONE).
## Emits speed_changed(speed) and closed / dismissed (from UiModal).

signal speed_changed(speed: float)
signal auto_settings_pressed

const CFG := "user://settings.cfg"
const SPEEDS := [1.0, 2.0, 4.0]
const UI_SIZES := [0.9, 1.0, 1.15, 1.3]
## Keycap height in Settings -> Controls (34 in the spec; 40 stays legible on the 0.75 phone frame).
const CONTROLS_KEY_PX := 40.0
const CREDITS := "Interface art and icons by RhosGFX (Cartoony UI Pack, Vector Icon Pack Pro, Vector Keyboard Controls). 3D models by KayKit. Sounds by Kenney."

var _sliders: Dictionary = {}
var _values: Dictionary = {}
var _speed_btns: Array[Button] = []
var _size_btns: Array[Button] = []
var _update_btn: ToggleSwitch
var _controls: Control


static func game_speed() -> float:
	var cfg := ConfigFile.new()
	if cfg.load(CFG) != OK:
		return 1.0
	return float(cfg.get_value("game", "speed", 1.0))


static func set_game_speed(v: float) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG)
	cfg.set_value("game", "speed", v)
	cfg.save(CFG)


static func ui_size() -> float:
	# screenshot runs are deterministic: saved value ignored, `--ui-size=F` overrides
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--ui-size="):
			return clampf(float(a.substr(10)), 0.5, 2.0)
	for a in args:
		if a.begins_with("--scenario="):
			return 1.0
	var cfg := ConfigFile.new()
	if cfg.load(CFG) != OK:
		return 1.0
	return clampf(float(cfg.get_value("display", "ui_size", 1.0)), 0.5, 2.0)


static func set_ui_size(v: float) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG)
	cfg.set_value("display", "ui_size", v)
	cfg.save(CFG)


## Applies the saved UI size to `win` on top of its base content scale (the first call
## remembers the base, so OS / harness scaling is kept), times the landscape phone boost
## (UiTheme.landscape_ui_boost: 1.4 on a phone held sideways, else 1). Re-applied on every
## window resize / rotation (track_window).
static func apply_ui_size(win: Window, v: float = -1.0) -> void:
	if win == null:
		return
	if not win.has_meta("ui_base_scale"):
		win.set_meta("ui_base_scale", win.content_scale_factor)
	var k := ui_size() if v <= 0.0 else v
	win.content_scale_factor = float(win.get_meta("ui_base_scale")) * effective_ui_scale(k, Vector2(win.size))
	track_window(win)


## The UI scale actually used: the player's UI size times the landscape phone boost.
static func effective_ui_scale(user_size: float, window_size: Vector2) -> float:
	return user_size * UiTheme.landscape_ui_boost(window_size)


## Keeps `win`'s UI scale right through rotations and resizes (connected once per window).
static func track_window(win: Window) -> void:
	if win == null or win.has_meta("ui_size_tracked"):
		return
	win.set_meta("ui_size_tracked", true)
	win.size_changed.connect(func() -> void: apply_ui_size(win))


func _build() -> void:
	ScrollFade.attach(self, _scroll, UiPalette.NAVY_2, _frame)
	set_title("SETTINGS", PLAQUE_DEFAULT)
	max_width = 600.0
	# one exit (spec 3.2): the header close button, Esc and the backdrop; settings apply live,
	# so there is no DONE
	dismissible = true
	for row in [["Master", "speaker"], ["Music", "music"], ["SFX", "sfx"]]:
		body.add_child(_volume_row(row[0], row[1]))
	body.add_child(UiModal.section_gap())
	body.add_child(_row_head("speed", "Game speed"))
	var speeds: Array[String] = []
	for sp in SPEEDS:
		speeds.append("%d×" % int(sp))
	var seg_speed := Segmented.make(speeds, func(i: int) -> void: _set_speed(SPEEDS[i]))
	_speed_btns = seg_speed.buttons
	body.add_child(seg_speed)
	body.add_child(_row_head("ui_size", "UI size"))
	var sizes: Array[String] = []
	for z in UI_SIZES:
		sizes.append("%d%%" % int(round(z * 100.0)))
	var seg_size := Segmented.make(sizes, func(i: int) -> void: _set_ui_size(UI_SIZES[i]))
	_size_btns = seg_size.buttons
	body.add_child(seg_size)
	body.add_child(_update_row())
	var auto := GameButton.make("AUTO SETTINGS", "auto", GameButton.Kind.SECONDARY, 26)
	auto.min_height = 80
	auto.pad_x = 24
	auto.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	auto.pressed.connect(func() -> void: auto_settings_pressed.emit())
	body.add_child(auto)
	# Controls (desktop only, spec 6): every shortcut with its keycaps, from the action table
	# (ControlsList: slice e's widget; shown in keyboard / mouse mode, hidden on touch)
	if InputMode.platform_default_kbm():
		_controls = UiTheme.vbox(8)
		_controls.name = "Controls"
		_controls.add_child(UiModal.section_label("Controls"))
		_controls.add_child(ControlsList.make(CONTROLS_KEY_PX))
		body.add_child(_controls)
	# credits
	var credits := UiTheme.vbox(4)
	credits.add_child(UiModal.section_label("Credits"))
	var cl := UiTheme.para(CREDITS, 19, UiPalette.TEXT_MUTED, 500)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.add_child(cl)
	body.add_child(credits)
	refresh()


## Icon (a Flat White action glyph, drawn in TEXT on the navy panel) + a row label.
func _row_head(icon: String, text: String) -> HBoxContainer:
	var r := UiTheme.hbox(12)
	r.add_child(Icons.rect(icon if Icons.exists(icon) else "plus", 36, UiPalette.TEXT))
	var l := UiTheme.label(text, 28, UiPalette.TEXT, true, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(l)
	return r


## Scrolls the panel so the Controls list is in view (F1, pause CONTROLS).
func scroll_to_controls() -> void:
	if _controls == null:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_controls):
		_scroll.scroll_vertical = int(_controls.position.y + _inner.position.y)


func _volume_row(bus: String, icon: String) -> Control:
	var col := UiTheme.vbox(6)
	var head := _row_head(icon, bus if bus != "SFX" else "Sound effects")
	col.add_child(head)
	var v := UiTheme.label("100%", 26, UiPalette.GOLD_BRIGHT, true, 0)
	head.add_child(v)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.custom_minimum_size = Vector2(200, 56)
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(func(x: float) -> void:
		v.text = "%d%%" % int(round(x * 100))
		var a := _audio()
		if a:
			a.set_volume(bus, x))
	s.drag_ended.connect(func(_c: bool) -> void: UiTheme.sfx("click"))
	# inset so the round grabber isn't clipped at 0 / 100 %
	var sm := UiTheme.margin(s, 22, 0, 22, 0)
	col.add_child(sm)
	_sliders[bus] = s
	_values[bus] = v
	return col


## Auto-update switch ([update] auto, owned by the Updater autoload) + a small manual CHECK.
func _update_row() -> Control:
	var r := _row_head("download", "Auto-update")
	_update_btn = ToggleSwitch.make(true)
	_update_btn.tooltip_text = "Check for updates on launch"
	_update_btn.toggled.connect(func(on: bool) -> void: _updater().call("set_auto_enabled", on))
	r.add_child(_update_btn)
	var chk := GameButton.make("CHECK", "", GameButton.Kind.SECONDARY, 24)
	chk.min_height = 80
	chk.pad_x = 16
	chk.pressed.connect(func() -> void: _updater().call("check_now", true))
	r.add_child(chk)
	var up := _updater()
	r.visible = up != null and bool(up.call("can_check"))
	return r


func _updater() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Updater") if tree != null and tree.root != null else null


func refresh(_flow: GameFlow = null) -> void:
	var a := _audio()
	for bus in _sliders:
		var vol: float = a.get_volume(bus) if a else 1.0
		(_sliders[bus] as HSlider).set_value_no_signal(vol)
		(_values[bus] as Label).text = "%d%%" % int(round(vol * 100))
	var sp := game_speed()
	for i in _speed_btns.size():
		_speed_btns[i].set_pressed_no_signal(is_equal_approx(sp, SPEEDS[i]))
	if _update_btn:
		var on: bool = _update_btn.get_parent().visible and bool(_updater().call("is_auto_enabled"))
		_update_btn.set_pressed_no_signal(on)
		_update_btn.set("_knob", 1.0 if on else 0.0)
		_update_btn.queue_redraw()
	if _controls != null:
		_controls.visible = InputMode.is_kbm()
	var us := ui_size()
	for i in _size_btns.size():
		_size_btns[i].set_pressed_no_signal(is_equal_approx(us, UI_SIZES[i]))


func _set_speed(s: float) -> void:
	set_game_speed(s)
	refresh()
	speed_changed.emit(s)


func _set_ui_size(z: float) -> void:
	set_ui_size(z)
	apply_ui_size(get_window(), z)
	refresh()


func _audio() -> Node:
	return get_tree().root.get_node_or_null("Audio") if is_inside_tree() else null


func _ready() -> void:
	super._ready()
	apply_ui_size(get_window())
	refresh()


## Segmented control (spec 2.3): a grey-darker track holding pill segments; the selected one
## is the yellow pill with an ink label. Each segment is an 88 px tall hit row.
class Segmented:
	extends PanelContainer
	var buttons: Array[Button] = []

	static func make(labels: Array[String], on_pick: Callable, font := 26) -> Segmented:
		var sg := Segmented.new()
		sg.add_theme_stylebox_override("panel", UiTheme.tab_track_box())
		var row := UiTheme.hbox(6)
		sg.add_child(row)
		var group := ButtonGroup.new()
		for i in labels.size():
			var b := Button.new()
			b.text = labels[i]
			b.toggle_mode = true
			b.button_group = group
			b.focus_mode = Control.FOCUS_NONE
			b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size = Vector2(0, 80)
			b.add_theme_font_override("font", UiTheme.display_font())
			b.add_theme_font_size_override("font_size", font)
			# 12 px side padding (the pill's 18 made a 4-way row wider than a phone at 125%)
			for st in ["normal", "hover", "disabled"]:
				b.add_theme_stylebox_override(st, _slim(UiTheme.tab_box(false, st)))
			for st in ["pressed", "hover_pressed"]:
				b.add_theme_stylebox_override(st, _slim(UiTheme.tab_box(true)))
			b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			b.add_theme_color_override("font_color", UiPalette.TEXT_DIM)
			b.add_theme_color_override("font_hover_color", UiPalette.TEXT)
			b.add_theme_color_override("font_pressed_color", UiPalette.INK_LABEL)
			b.add_theme_color_override("font_hover_pressed_color", UiPalette.INK_LABEL)
			b.pressed.connect(func() -> void:
				UiTheme.sfx("click")
				on_pick.call(i))
			row.add_child(b)
			sg.buttons.append(b)
		return sg

	static func _slim(sb: StyleBox) -> StyleBox:
		var d := sb.duplicate() as StyleBox
		d.content_margin_left = 12
		d.content_margin_right = 12
		return d
