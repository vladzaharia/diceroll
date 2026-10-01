class_name GameButton
extends BaseButton
## Chunky button: RhosGFX 3D Square art per kind (ink labels), 3D Round art for icon-only
## buttons, press squash + bounce, click sfx, and the desktop hover keycap. Falls back to the
## pre-reskin drawn look (face, lip, gloss) when the pack isn't imported.
##
##   var b := GameButton.make("ROLL", "dice", GameButton.Kind.PRIMARY, 44)
##   b.pressed.connect(...)
##   b.set_enabled(false)
##   b.sub_text = "2 left"
##   b.shortcut_hint = "key_space"      # faded keycap in the top-right corner while hovered
##
## Sizing (spec 2.1 / 3): the art is 1.25 px per unit at 80 px and taller, 1.0 at 72 px and
## shorter (`_sm` pieces). `min_height` is the drawn height; a control drawn under 88 px keeps
## an 88 px hit rect (the Control grows, the art is drawn centred inside it).

enum Kind { PRIMARY, SECONDARY, DANGER, SUCCESS, ROUND, GHOST }

## Lip of the pre-reskin drawn look (fallback only).
const DEPTH := 8.0
## Drawn heights at or under this use the 1.0-scale `_sm` art.
const SMALL_H := 72.0
## Round art: the face is a circle 54 units wide on 64 tall (10-unit lip).
const ROUND_W := 55.0 / 64.0
const ROUND_FACE := 54.0 / 64.0
## Hover keycap: fade in / out, opacity, inset from the face edge.
const KEYCAP_ALPHA := 0.6
const KEYCAP_IN := 0.12
const KEYCAP_OUT := 0.08
## Smallest hover keycap height in real screen pixels.
const KEYCAP_MIN_SCREEN := 22.0

var kind: Kind = Kind.PRIMARY:
	set(v):
		kind = v
		_refresh_if_ready()
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
var icon_tint: Variant = null:
	set(v):
		icon_tint = v
		_apply_icon()
## Toggle buttons draw as PRIMARY while pressed (GHOST art / SECONDARY look when off).
var toggle_primary := false
var sfx_id := "click"
## Icon-only buttons: pack family of the round face ("red" close, "grey" utility, "yellow"
## hero, "blue", "green", "purple"); "" = from the kind (close icon -> red).
var round_family := "":
	set(v):
		round_family = v
		_refresh_if_ready()
## Input glyph id of this button's keyboard shortcut ("key_space", "key_r", "key_esc", ...).
## Text buttons show it as a faded keycap inside the top-right corner while the mouse hovers
## (keyboard / mouse mode only); round buttons add it to their tooltip instead ("Pause (ESC)").
var shortcut_hint := "":
	set(v):
		shortcut_hint = v
		if _keycap and is_instance_valid(_keycap):
			_keycap.queue_free()
			_keycap = null

var _content: HBoxContainer
## The icon sits in a holder sized to its visible glyph (the SVGs carry transparent margins),
## so [glyph + gap + label] centres as one unit and icon-only buttons centre the glyph exactly.
var _icon_box: Control
var _icon: TextureRect
## True only while the finger / mouse is actually down (a toggled-on button doesn't sink).
var _held := false
var _label: Label
var _sub: Label
var _hover := false
var _tween: Tween
var _keycap: KeyGlyph
var _keycap_tween: Tween


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
	_content = UiTheme.hbox(10)
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_icon_box = Control.new()
	_icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_content.add_child(_icon_box)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_box.add_child(_icon)
	_content.sort_children.connect(_align_icon)
	var col := UiTheme.vbox(-4)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(col)
	_label = UiTheme.label(text, font_size, _text_color(), true, 0, not skinned())
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
		_show_keycap(true)
		_refresh())
	mouse_exited.connect(func() -> void:
		_hover = false
		_show_keycap(false)
		_refresh())
	focus_entered.connect(_refresh)
	focus_exited.connect(_refresh)
	resized.connect(_layout)
	if is_inside_tree():
		InputMode.instance(get_tree())
	_refresh()
	_layout()


func set_enabled(on: bool) -> void:
	disabled = not on
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if on else Control.CURSOR_ARROW
	_refresh()


# ---------------------------------------------------------------- art selection

## True when the RhosGFX art for this button is imported (else the drawn fallback).
func skinned() -> bool:
	return UiSkin.has(piece())


## Icon-only (no label) buttons use the round art.
func is_round() -> bool:
	return kind == Kind.ROUND or (text == "" and sub_text == "" and icon_name != "")


## ui_pack.json piece for the current kind / toggle state / size.
func piece() -> String:
	if is_round():
		return "round_" + _round_fam()
	var k := _effective_kind()
	var n: String = {Kind.PRIMARY: "primary", Kind.DANGER: "danger", Kind.SUCCESS: "success", Kind.GHOST: "ghost"}.get(k, "secondary")
	if toggle_mode and toggle_primary and not button_pressed:
		n = "ghost"
	return "button_%s%s" % [n, "_sm" if min_height <= SMALL_H else ""]


func _round_fam() -> String:
	if round_family != "":
		return round_family
	if icon_name == "close":
		return "red"
	match kind:
		Kind.PRIMARY:
			return "yellow"
		Kind.DANGER:
			return "red"
		Kind.SUCCESS:
			return "green"
	return "grey"


## Art state: disabled / pressed / hover (desktop) / focus (keyboard, desktop) / normal.
func art_state() -> String:
	if disabled:
		return "disabled"
	if _is_down():
		return "pressed"
	if _hover and InputMode.is_kbm():
		return "hover"
	if has_focus() and InputMode.is_kbm():
		return "focus"
	return "normal"


## Face family is light enough for ink labels (every pack face but ghost / grey).
func _ink_face() -> bool:
	if is_round():
		return _round_fam() != "grey"
	return not piece().begins_with("button_ghost")


func _refresh_if_ready() -> void:
	if _content:
		_apply_icon()
		_refresh()


# ---------------------------------------------------------------- icon

func _apply_icon() -> void:
	if _icon == null:
		return
	if icon_name == "":
		_icon_box.visible = false
		update_minimum_size()
		return
	var px := icon_px if icon_px > 0 else int(font_size * 1.15)
	var tint: Variant = icon_tint
	var o := {}
	if skinned():
		if tint == null and not _ink_face():
			tint = UiPalette.TEXT
		if disabled:
			o["saturation"] = 0.0
	if tint != null:
		o["tint"] = tint
	_icon.texture = Icons.texture(icon_name, px, o if not o.is_empty() else null)
	_icon.size = Vector2(px, px)
	var g := _glyph_rect_of(icon_name, tint)
	_icon_box.custom_minimum_size = Vector2(maxf(px * g.size.x, 1.0), px)
	_icon_box.visible = true
	update_minimum_size()
	_align_icon()


static var _glyph_cache: Dictionary = {}


## The visible (non-transparent) part of an icon, as fractions of its square, measured once
## on a fixed raster.
static func _glyph_rect_of(id: String, tint: Variant = null) -> Rect2:
	var key := "%s|%s" % [id, str(tint)]
	if not _glyph_cache.has(key):
		_glyph_cache[key] = _glyph_rect(Icons.tex(id, 128, tint))
	return _glyph_cache[key]


## The visible (non-transparent) part of a raster texture, as fractions of its size.
static func _glyph_rect(t: Texture2D) -> Rect2:
	if t == null:
		return Rect2(0, 0, 1, 1)
	var id := t.get_instance_id()
	if _glyph_cache.has(id):
		return _glyph_cache[id]
	var img := t.get_image()
	var r := Rect2(0, 0, 1, 1)
	if img != null and not img.is_empty():
		if img.is_compressed():
			img.decompress()
		var u := img.get_used_rect()
		if u.size.x > 0 and u.size.y > 0:
			var sz := Vector2(img.get_width(), img.get_height())
			r = Rect2(Vector2(u.position) / sz, Vector2(u.size) / sz)
	_glyph_cache[id] = r
	return r


## Places the glyph inside its holder: left edge flush (the holder is glyph-wide) and
## vertically centred on the label's cap height (or on the button face when icon-only).
func _align_icon() -> void:
	if _icon == null or not _icon_box.visible:
		return
	var px := _icon.size.x
	var g := _glyph_rect_of(icon_name, icon_tint)
	_icon.position.x = -g.position.x * px
	var glyph_mid := (g.position.y + g.size.y * 0.5) * px
	var target := _icon_box.size.y * 0.5
	if _label and _label.visible and _label.label_settings:
		var ls := _label.label_settings
		var asc := ls.font.get_ascent(ls.font_size)
		var cap := ls.font_size * 0.7
		# label line box top in holder coordinates
		var col := _label.get_parent() as Control
		var top := col.position.y + _label.position.y - _icon_box.position.y
		var lh := _label.size.y
		var line_h := asc + ls.font.get_descent(ls.font_size)
		top += (lh - line_h) * 0.5
		target = top + asc - cap * 0.5
	_icon.position.y = target - glyph_mid


# ---------------------------------------------------------------- layout

## Drawn height (min_height, or taller when the content needs it).
func visual_height() -> float:
	if _content == null:
		return min_height
	if not skinned():
		return maxf(min_height, _content.get_combined_minimum_size().y + 22.0 + DEPTH)
	var sb := UiSkin.stylebox(piece(), "normal")
	var c := _content.get_combined_minimum_size()
	if is_round():
		return maxf(min_height, c.y / ROUND_FACE)
	return maxf(min_height, c.y + sb.content_margin_top + sb.content_margin_bottom)


func _get_minimum_size() -> Vector2:
	if _content == null:
		return Vector2(min_height, min_height)
	var c := _content.get_combined_minimum_size()
	var h := visual_height()
	if skinned():
		var hit := maxf(h, UiTheme.TOUCH)
		if is_round():
			return Vector2(hit, hit)
		return Vector2(maxf(c.x + pad_x * 2.0, maxf(h, UiTheme.TOUCH)), hit)
	var w := c.x + pad_x * 2.0
	if kind == Kind.ROUND:
		return Vector2(h, h)
	return Vector2(maxf(w, h), h)


## Where the art is drawn: the full rect, or centred inside the 88 px hit rect when the
## button is drawn smaller; round art is a circle-faced box (55 x 64 units) in the middle.
func box_rect() -> Rect2:
	var h := minf(size.y, visual_height()) if skinned() else size.y
	if is_round() and skinned():
		var w := minf(size.x, h * ROUND_W)
		return Rect2((size.x - w) * 0.5, (size.y - h) * 0.5, w, h)
	return Rect2(0.0, (size.y - h) * 0.5, size.x, h)


func _layout() -> void:
	pivot_offset = size * 0.5
	_place_content()


func _place_content() -> void:
	if _content == null:
		return
	if not skinned():
		_content.position = Vector2(0, _sink())
		_content.size = Vector2(size.x, size.y - DEPTH)
		return
	var b := box_rect()
	if is_round():
		# the glyph centres on the face (27/64 of the height), which sinks when pressed
		var sink := b.size.y * 6.0 / 64.0 if art_state() == "pressed" else 0.0
		_content.position = Vector2(0, b.position.y + sink)
		_content.size = Vector2(size.x, b.size.y * ROUND_FACE)
		return
	var sb := UiSkin.stylebox(piece(), art_state())
	_content.position = Vector2(0, b.position.y + sb.content_margin_top)
	_content.size = Vector2(size.x, maxf(0.0, b.size.y - sb.content_margin_top - sb.content_margin_bottom))


func _sink() -> float:
	return DEPTH - 2.0 if _is_down() else 0.0


func _is_down() -> bool:
	# not get_draw_mode(): a toggled-on button reports PRESSED but must not sink
	return _held and (get_draw_mode() == DRAW_PRESSED or get_draw_mode() == DRAW_HOVER_PRESSED or is_hovered())


func _on_down() -> void:
	_held = true
	_refresh()
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2(0.96, 0.94), 0.06).set_trans(Tween.TRANS_QUAD)


func _on_up() -> void:
	_held = false
	_refresh()
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2(1.04, 1.05), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh() -> void:
	if _label:
		var tc := _text_color()
		var skin := skinned()
		_label.label_settings = UiTheme.label_settings(font_size, tc, true, 0, UiPalette.OUTLINE, not disabled and not skin)
		_sub.label_settings = UiTheme.label_settings(maxi(18, int(font_size * 0.52)), Color(tc, 0.85), false, 0, UiPalette.OUTLINE, false, 600)
		if skin:
			_icon.modulate = Color(1, 1, 1, 0.8) if disabled else Color.WHITE
		else:
			_icon.modulate = Color(1, 1, 1, 0.45) if disabled else Color.WHITE
	_place_content()
	_align_icon.call_deferred()
	update_minimum_size()
	queue_redraw()


func _effective_kind() -> Kind:
	if toggle_mode and toggle_primary:
		return Kind.PRIMARY if button_pressed else Kind.SECONDARY
	return kind


func _colors() -> Array[Color]:
	# pre-reskin fallback look: [face, lip (depth), rim]
	if disabled:
		return [UiPalette.DISABLED, UiPalette.DISABLED_DARK, Color(1, 1, 1, 0.06)]
	match _effective_kind():
		Kind.PRIMARY:
			return [Color("ffab32"), UiPalette.PRIMARY_DARK, Color("ffe08a")]
		Kind.DANGER:
			return [Color("e8484f"), UiPalette.DANGER_DARK, Color("ff9a9a")]
		Kind.SUCCESS:
			return [Color("4cc26a"), Color("1f7a3c"), Color("a8f0b0")]
		Kind.GHOST:
			return [Color(0.06, 0.06, 0.15, 0.7), Color(0.02, 0.02, 0.06, 0.8), UiPalette.GOLD_FAINT]
		_:
			return [UiPalette.SECONDARY, UiPalette.SECONDARY_DARK, UiPalette.GOLD_LINE]


func _text_color() -> Color:
	if skinned():
		if disabled:
			return UiPalette.INK_LABEL
		return UiPalette.INK_LABEL if _ink_face() else UiPalette.TEXT
	if disabled:
		return UiPalette.TEXT_MUTED
	match _effective_kind():
		Kind.PRIMARY:
			return UiPalette.TEXT_DARK
		_:
			return UiPalette.TEXT


# ---------------------------------------------------------------- hover keycap / tooltip

## Round buttons carry their shortcut in the tooltip ("Pause (ESC)").
func _get_tooltip(_at: Vector2) -> String:
	if shortcut_hint != "" and is_round() and tooltip_text != "":
		return "%s (%s)" % [tooltip_text, KeyGlyph.label_of(shortcut_hint)]
	return tooltip_text


## Whether the hover keycap may show now: a text button with a shortcut, hovered, in
## keyboard / mouse mode (never after touch input, never on mobile).
func keycap_allowed() -> bool:
	return shortcut_hint != "" and not is_round() and not disabled and InputMode.is_kbm()


## Keycap rect inside the face's top-right corner, inset 6 px from the face edge
## (26 px tall on buttons of 80 px and up, 22 px on smaller ones).
func keycap_rect(glyph_w_over_h: float = 1.0) -> Rect2:
	var b := box_rect()
	var kh := 26.0 if b.size.y >= 80.0 else 22.0
	# never under KEYCAP_MIN_SCREEN real pixels (a 1366x768 window draws the canvas at ~0.6x:
	# a 26 px cap was ~15 px and its "ENTER" unreadable); capped to fit the face
	var k := get_viewport().get_final_transform().get_scale().y if is_inside_tree() else 1.0
	if k > 0.0:
		kh = clampf(KEYCAP_MIN_SCREEN / k, kh, maxf(kh, b.size.y * 0.42))
	var edge := 6.0 + (4.0 * (1.25 if b.size.y >= 80.0 else 1.0))
	var kw := kh * glyph_w_over_h
	return Rect2(b.end.x - edge - kw, b.position.y + edge, kw, kh)


func _show_keycap(on: bool) -> void:
	if on and not keycap_allowed():
		on = false
	if not on and _keycap == null:
		return
	if _keycap == null:
		_keycap = KeyGlyph.make(shortcut_hint, 26.0)
		_keycap.set_meta(UiAudit.SKIP, true)
		add_child(_keycap)
	var r := keycap_rect(_keycap.size.x / maxf(_keycap.size.y, 1.0))
	_keycap.set_glyph(shortcut_hint, r.size.y)
	_keycap.position = r.position
	if on and _label and _label.visible:
		# never over the label: hide instead
		var lr := Rect2(_label.global_position - global_position, _label.size)
		if lr.size.x > 4.0 and lr.size.y > 4.0 and lr.grow(-2.0).intersects(Rect2(r.position, _keycap.size)):
			on = false
	if _keycap_tween and _keycap_tween.is_valid():
		_keycap_tween.kill()
	if not is_inside_tree():
		_keycap.visible = on
		_keycap.modulate.a = KEYCAP_ALPHA if on else 0.0
		return
	if on:
		_keycap.visible = true
		_keycap_tween = create_tween()
		_keycap_tween.tween_property(_keycap, "modulate:a", KEYCAP_ALPHA, KEYCAP_IN)
	else:
		_keycap_tween = create_tween()
		_keycap_tween.tween_property(_keycap, "modulate:a", 0.0, KEYCAP_OUT)
		_keycap_tween.tween_callback(func() -> void:
			if _keycap:
				_keycap.visible = false)


## True while the hover keycap is showing (tests).
func keycap_visible() -> bool:
	return _keycap != null and _keycap.visible and _keycap.modulate.a > 0.0


# ---------------------------------------------------------------- draw

func _draw() -> void:
	if skinned():
		draw_style_box(UiSkin.stylebox(piece(), art_state()), box_rect())
		return
	_draw_fallback()


func _draw_fallback() -> void:
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
