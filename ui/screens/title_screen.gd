class_name TitleScreen
extends Control
## Title: animated DICEROLL logo, New Run, Continue (enabled when user://save.json exists),
## Settings. Emits new_run_pressed, continue_pressed, settings_pressed.

signal new_run_pressed
signal continue_pressed
signal settings_pressed

const SAVE_PATH := "user://save.json"

var logo: Logo
var new_btn: GameButton
var continue_btn: GameButton
var settings_btn: GameButton
var _col: VBoxContainer
var _logo_box: Control
var _tag: Label
var _dice: Array[DieFace] = []
var _footer: Label
var _t := 0.0


func _init() -> void:
	theme = UiTheme.get_theme()
	UiTheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# vignette
	var vg := _Vignette.new()
	add_child(UiTheme.full_rect(vg))
	_logo_box = Control.new()
	_logo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_logo_box)
	for v in [5, 3]:
		var d := DieFace.make(v, "", false, 96)
		_dice.append(d)
		_logo_box.add_child(d)
	_dice[1].rune = "ember"
	logo = Logo.new()
	_logo_box.add_child(logo)
	_tag = UiTheme.label("A  DICE  ROGUELITE", 28, UiPalette.TEXT, true, 6, true)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_logo_box.add_child(_tag)

	_col = UiTheme.vbox(18)
	add_child(_col)
	new_btn = GameButton.make("NEW RUN", "dice", GameButton.Kind.PRIMARY, 46)
	new_btn.min_height = 116
	new_btn.pressed.connect(func() -> void: new_run_pressed.emit())
	_col.add_child(new_btn)
	continue_btn = GameButton.make("CONTINUE", "arrow_right", GameButton.Kind.SECONDARY, 36)
	continue_btn.icon_tint = UiPalette.GOLD
	continue_btn.min_height = 100
	continue_btn.pressed.connect(func() -> void: continue_pressed.emit())
	_col.add_child(continue_btn)
	settings_btn = GameButton.make("SETTINGS", "gear", GameButton.Kind.GHOST, 32)
	settings_btn.icon_tint = UiPalette.GOLD
	settings_btn.pressed.connect(func() -> void: settings_pressed.emit())
	_col.add_child(settings_btn)
	_footer = UiTheme.label("v0.1  ·  Fredoka & Lilita One (OFL)  ·  KayKit & Kenney (CC0)", 18, UiPalette.TEXT_MUTED, false, 0, false, 500)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_footer)
	resized.connect(_layout)


func _ready() -> void:
	refresh()
	_layout()
	# entrance
	_logo_box.modulate.a = 0.0
	_col.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(_logo_box, "modulate:a", 1.0, 0.4)
	t.tween_property(_col, "modulate:a", 1.0, 0.4).set_delay(0.2)


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func refresh(_flow: GameFlow = null) -> void:
	continue_btn.set_enabled(has_save())
	continue_btn.sub_text = "" if has_save() else "no saved run"


func _layout() -> void:
	if size.x <= 0.0:
		return
	var portrait := UiTheme.is_portrait(size)
	var safe := UiTheme.safe_margins(self)
	logo.font_size = int(clampf(size.x / 6.2, 96.0, 150.0)) if portrait else 150
	logo.reset_size()
	var ls := logo.get_combined_minimum_size()
	var box_w := maxf(ls.x, 400.0)
	var box_h := ls.y + 150.0
	_logo_box.size = Vector2(box_w, box_h)
	_logo_box.position = Vector2((size.x - box_w) * 0.5, size.y * (0.2 if portrait else 0.14))
	logo.position = Vector2(0, 70)
	logo.size = Vector2(box_w, ls.y)
	_tag.position = Vector2(0, 70 + ls.y + 4)
	_tag.size = Vector2(box_w, 40)
	var w := minf(460.0, size.x - safe.left - safe.right)
	_col.reset_size()
	var ch := _col.get_combined_minimum_size().y
	_col.size = Vector2(w, ch)
	_col.position = Vector2((size.x - w) * 0.5, size.y * (0.56 if portrait else 0.52))
	_footer.size = Vector2(size.x, 30)
	_footer.position = Vector2(0, size.y - safe.bottom - 30)


func _process(delta: float) -> void:
	_t += delta
	if _dice.size() < 2 or logo == null:
		return
	var w := _logo_box.size.x
	_dice[0].position = Vector2(w * 0.5 - 150 + sin(_t * 1.3) * 6.0, 4 + sin(_t * 1.7) * 8.0)
	_dice[0].size = Vector2(96, 96)
	_dice[0].pivot_offset = Vector2(48, 48)
	_dice[0].rotation = deg_to_rad(-14.0 + sin(_t * 1.1) * 5.0)
	_dice[1].position = Vector2(w * 0.5 + 54 + sin(_t * 1.1 + 1.0) * 6.0, -6 + sin(_t * 1.5 + 2.0) * 8.0)
	_dice[1].size = Vector2(96, 96)
	_dice[1].pivot_offset = Vector2(48, 48)
	_dice[1].rotation = deg_to_rad(12.0 + sin(_t * 1.3 + 1.0) * 5.0)
	logo.position.y = 70 + sin(_t * 1.2) * 3.0


class _Vignette:
	extends Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	var _tex: Texture2D

	func _draw() -> void:
		# soft darkening at top and bottom for text contrast (texture kept alive: RIDs of a
		# temporary texture would be freed before the frame renders)
		if _tex == null:
			var ink := Color(0.02, 0.02, 0.07)
			_tex = UiTheme.vgradient(Color(ink, 0.7), Color(ink, 0.75), Color(ink, 0.12))
		draw_texture_rect(_tex, Rect2(Vector2.ZERO, size), false)
