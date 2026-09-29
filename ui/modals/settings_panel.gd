class_name SettingsPanel
extends UiModal
## Settings: Master / Music / SFX volume (via the Audio autoload, which persists them) and
## game speed 1× / 2× / 4× (persisted in user://settings.cfg [game] speed).
## UI size 90 / 100 / 115 / 130 % (accessibility; [display] ui_size) scales the whole 2D UI
## via the window's content_scale_factor; every layout (HUD column, tray, camera framing)
## adapts to the resulting logical canvas.
## Emits speed_changed(speed) and closed (from UiModal) when DONE is pressed.

signal speed_changed(speed: float)
signal done_pressed
signal auto_settings_pressed

const CFG := "user://settings.cfg"
const SPEEDS := [1.0, 2.0, 4.0]
const UI_SIZES := [0.9, 1.0, 1.15, 1.3]

var _sliders: Dictionary = {}
var _values: Dictionary = {}
var _speed_btns: Array[GameButton] = []
var _size_btns: Array[GameButton] = []


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
## remembers the base, so OS / harness scaling is kept).
static func apply_ui_size(win: Window, v: float = -1.0) -> void:
	if win == null:
		return
	if not win.has_meta("ui_base_scale"):
		win.set_meta("ui_base_scale", win.content_scale_factor)
	var k := ui_size() if v <= 0.0 else v
	win.content_scale_factor = float(win.get_meta("ui_base_scale")) * k


func _build() -> void:
	set_title("SETTINGS")
	max_width = 600.0
	for row in [["Master", "speaker"], ["Music", "music"], ["SFX", "bolt"]]:
		body.add_child(_volume_row(row[0], row[1]))
	body.add_child(UiTheme.spacer(4))
	var sp := UiTheme.hbox(14)
	body.add_child(sp)
	sp.add_child(UiIcons.rect("speed", 40, UiPalette.GOLD))
	var sl := UiTheme.label("Game speed", 30, UiPalette.TEXT, true, 0)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.add_child(sl)
	for s in SPEEDS:
		var b := GameButton.make("%d×" % int(s), "", GameButton.Kind.SECONDARY, 30)
		b.toggle_mode = true
		b.toggle_primary = true
		b.min_height = 84
		b.pad_x = 20
		b.pressed.connect(_set_speed.bind(s))
		sp.add_child(b)
		_speed_btns.append(b)
	# UI size (one compact row, like game speed)
	var zr := UiTheme.hbox(10)
	body.add_child(zr)
	zr.add_child(UiIcons.rect("plus", 40, UiPalette.GOLD))
	var zl := UiTheme.label("UI size", 30, UiPalette.TEXT, true, 0)
	zl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zr.add_child(zl)
	for z in UI_SIZES:
		var b := GameButton.make("%d%%" % int(round(z * 100.0)), "", GameButton.Kind.SECONDARY, 24)
		b.toggle_mode = true
		b.toggle_primary = true
		b.min_height = 72
		b.pad_x = 10
		b.pressed.connect(_set_ui_size.bind(z))
		zr.add_child(b)
		_size_btns.append(b)
	var auto := GameButton.make("AUTO SETTINGS", "auto", GameButton.Kind.SECONDARY, 28)
	auto.icon_tint = AutoButton.ACCENT
	auto.min_height = 84
	auto.pressed.connect(func() -> void: auto_settings_pressed.emit())
	body.add_child(auto)
	body.add_child(UiTheme.spacer(6))
	var done := GameButton.make("DONE", "check", GameButton.Kind.PRIMARY, 36)
	done.icon_tint = UiPalette.TEXT_DARK
	done.pressed.connect(func() -> void:
		done_pressed.emit()
		close())
	body.add_child(done)
	refresh()


func _volume_row(bus: String, icon: String) -> Control:
	var col := UiTheme.vbox(6)
	var head := UiTheme.hbox(12)
	col.add_child(head)
	head.add_child(UiIcons.rect(icon, 34, UiPalette.GOLD))
	var l := UiTheme.label(bus if bus != "SFX" else "Sound effects", 28, UiPalette.TEXT, true, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
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
	col.add_child(s)
	_sliders[bus] = s
	_values[bus] = v
	return col


func refresh(_flow: GameFlow = null) -> void:
	var a := _audio()
	for bus in _sliders:
		var vol: float = a.get_volume(bus) if a else 1.0
		(_sliders[bus] as HSlider).set_value_no_signal(vol)
		(_values[bus] as Label).text = "%d%%" % int(round(vol * 100))
	var sp := game_speed()
	for i in _speed_btns.size():
		_speed_btns[i].set_pressed_no_signal(is_equal_approx(sp, SPEEDS[i]))
		_speed_btns[i].call("_refresh")
	var us := ui_size()
	for i in _size_btns.size():
		_size_btns[i].set_pressed_no_signal(is_equal_approx(us, UI_SIZES[i]))
		_size_btns[i].call("_refresh")


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
