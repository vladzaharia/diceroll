class_name GameButton
extends BaseButton
## Chunky mobile button with a 3D "depth" lip, gloss, press sink + bounce, hover glow and
## click sfx. Draws itself (no Godot grey anywhere).
##
##   var b := GameButton.make("ROLL", "dice", GameButton.Kind.PRIMARY, 44)
##   b.pressed.connect(...)
##   b.set_enabled(false)
##   b.sub_text = "2 left"

enum Kind { PRIMARY, SECONDARY, DANGER, SUCCESS, ROUND, GHOST }

const DEPTH := 8.0

var kind: Kind = Kind.PRIMARY
var font_size: int = 34
var min_height: float = UiTheme.TOUCH
var pad_x: float = 28.0
var text: String = "":
	set(v):
		text = v
		if _label:
			_label.text = v
			_label.visible = v != ""
			update_minimum_size()
var sub_text: String = "":
	set(v):
		sub_text = v
		if _sub:
			_sub.text = v
			_sub.visible = v != ""
			update_minimum_size()
var icon_name: String = "":
	set(v):
		icon_name = v
		_apply_icon()
var icon_px: int = 0
var icon_tint: Variant = null
## Toggle buttons draw as PRIMARY while pressed.
var toggle_primary := false
var sfx_id := "click"

var _content: HBoxContainer
var _icon: TextureRect
var _label: Label
var _sub: Label
var _hover := false
var _tween: Tween


static func make(p_text: String, p_icon := "", p_kind := Kind.PRIMARY, p_font := 34) -> GameButton:
	var b := GameButton.new()
	b.kind = p_kind
	b.font_size = p_font
	b.text = p_text
	b.icon_name = p_icon
	if p_kind == Kind.ROUND:
		b.pad_x = 0.0
	return b


static func round_icon(p_icon: String, px := 88.0) -> GameButton:
	var b := make("", p_icon, Kind.ROUND)
	b.min_height = px
	b.icon_px = int(px * 0.46)
	return b


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_content = UiTheme.hbox(12)
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_content)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_icon)
	var col := UiTheme.vbox(-4)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(col)
	_label = UiTheme.label(text, font_size, _text_color(), true, 0, true)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.visible = text != ""
	col.add_child(_label)
	_sub = UiTheme.label(sub_text, maxi(18, int(font_size * 0.52)), _text_color(), false, 0, false, 600)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.visible = sub_text != ""
	col.add_child(_sub)
	_apply_icon()
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	pressed.connect(func() -> void: UiTheme.sfx(sfx_id))
	toggled.connect(func(_on: bool) -> void: _refresh())
	mouse_entered.connect(func() -> void:
		_hover = true
		_refresh())
	mouse_exited.connect(func() -> void:
		_hover = false
		_refresh())
	resized.connect(_layout)
	_refresh()
	_layout()


func set_enabled(on: bool) -> void:
	disabled = not on
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if on else Control.CURSOR_ARROW
	_refresh()


func _apply_icon() -> void:
	if _icon == null:
		return
	if icon_name == "":
		_icon.visible = false
		update_minimum_size()
		return
	var px := icon_px if icon_px > 0 else int(font_size * 1.15)
	var tint: Variant = icon_tint
	if tint == null and kind in [Kind.ROUND, Kind.SECONDARY, Kind.GHOST]:
		tint = null
	_icon.texture = UiIcons.tex(icon_name, px * 2, tint)
	_icon.custom_minimum_size = Vector2(px, px)
	_icon.visible = true
	update_minimum_size()


func _get_minimum_size() -> Vector2:
	if _content == null:
		return Vector2(min_height, min_height)
	var c := _content.get_combined_minimum_size()
	var w := c.x + pad_x * 2.0
	var h := maxf(min_height, c.y + 22.0 + DEPTH)
	if kind == Kind.ROUND:
		return Vector2(h, h)
	return Vector2(maxf(w, h), h)


func _layout() -> void:
	pivot_offset = size * 0.5
	_place_content()


func _place_content() -> void:
	if _content == null:
		return
	var sink := _sink()
	_content.position = Vector2(0, sink)
	_content.size = Vector2(size.x, size.y - DEPTH)


func _sink() -> float:
	return DEPTH - 2.0 if _is_down() else 0.0


func _is_down() -> bool:
	return get_draw_mode() == DRAW_PRESSED or get_draw_mode() == DRAW_HOVER_PRESSED


func _on_down() -> void:
	_refresh()
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2(0.96, 0.94), 0.06).set_trans(Tween.TRANS_QUAD)


func _on_up() -> void:
	_refresh()
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2(1.04, 1.05), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh() -> void:
	if _label:
		var tc := _text_color()
		_label.label_settings = UiTheme.label_settings(font_size, tc, true, 0, UiPalette.OUTLINE, not disabled)
		_sub.label_settings = UiTheme.label_settings(maxi(18, int(font_size * 0.52)), Color(tc, 0.85), false, 0, UiPalette.OUTLINE, false, 600)
		_icon.modulate = Color(1, 1, 1, 0.45) if disabled else Color.WHITE
	_place_content()
	queue_redraw()


func _effective_kind() -> Kind:
	if toggle_mode and toggle_primary:
		return Kind.PRIMARY if button_pressed else Kind.SECONDARY
	return kind


func _colors() -> Array[Color]:
	# [face, lip (depth), rim]
	if disabled:
		return [UiPalette.DISABLED, UiPalette.DISABLED_DARK, Color(1, 1, 1, 0.06)]
	match _effective_kind():
		Kind.PRIMARY:
			return [UiPalette.PRIMARY, UiPalette.PRIMARY_DARK, Color("ffe08a")]
		Kind.DANGER:
			return [UiPalette.DANGER, UiPalette.DANGER_DARK, Color("ff9a9a")]
		Kind.SUCCESS:
			return [Color("4cc26a"), Color("1f7a3c"), Color("a8f0b0")]
		Kind.GHOST:
			return [Color(0.06, 0.06, 0.15, 0.7), Color(0.02, 0.02, 0.06, 0.8), UiPalette.GOLD_FAINT]
		_:
			return [UiPalette.SECONDARY, UiPalette.SECONDARY_DARK, UiPalette.GOLD_LINE]


func _text_color() -> Color:
	if disabled:
		return UiPalette.TEXT_MUTED
	match _effective_kind():
		Kind.PRIMARY:
			return UiPalette.TEXT_DARK
		_:
			return UiPalette.TEXT


func _draw() -> void:
	var cols := _colors()
	var face: Color = cols[0]
	var lip: Color = cols[1]
	var rim: Color = cols[2]
	if _hover and not disabled:
		face = face.lightened(0.08)
	var r := int(minf(size.y * 0.5, 26.0)) if kind != Kind.ROUND else int(size.y * 0.5)
	var sink := _sink()
	var full := Rect2(Vector2.ZERO, size)
	# soft drop shadow
	if not disabled:
		var sh := UiTheme.box(Color(0, 0, 0, 0), r, 0, Color.TRANSPARENT, 12, Color(0, 0, 0, 0.4), Vector2(0, 6 - sink * 0.6))
		sh.bg_color = Color(0, 0, 0, 0.0)
		draw_style_box(sh, full.grow(-2))
	# outline + lip
	draw_style_box(UiTheme.box(UiPalette.OUTLINE, r + 2), full.grow(2))
	draw_style_box(UiTheme.box(lip, r), full)
	# face
	var face_rect := Rect2(0, sink, size.x, size.y - DEPTH)
	var fb := UiTheme.box(face, r)
	draw_style_box(fb, face_rect)
	# gloss (upper half)
	var gloss := UiTheme.box(Color(1, 1, 1, 0.0 if disabled else (0.13 if kind != Kind.GHOST else 0.05)), r)
	gloss.corner_radius_bottom_left = int(r * 0.6)
	gloss.corner_radius_bottom_right = int(r * 0.6)
	draw_style_box(gloss, Rect2(face_rect.position + Vector2(5, 4), Vector2(face_rect.size.x - 10, face_rect.size.y * 0.45)))
	# rim light
	var rb := UiTheme.box(Color.TRANSPARENT, r, 2, Color(rim, 0.55))
	rb.draw_center = false
	draw_style_box(rb, face_rect)
