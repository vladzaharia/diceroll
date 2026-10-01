class_name MissingAssetsScreen
extends Control
## "Required game assets are missing" screen (see AssetCheck). Built only from engine built-ins
## plus our own tracked logo (res://assets/icon/logo_doubles.png, with a drawn die as fallback):
## no project theme, fonts or third-party textures, since those are exactly what may be missing.
## Layout: a DICE|ROLL lockup (logo + wordmark, scaled down on narrow screens) above a card with
## the explanation, a "Read the build guide" button (README) and Quit. Respects safe areas.
## Hosts the hidden DevGesture (bottom-right corner, 5 taps): the Developer menu uses UiTheme,
## which falls back to the engine font when the third-party fonts are missing.
##
## UI reskin (docs/design/2026-09-30-ui-reskin.md 4.5): this screen is EXEMPT from the RhosGFX
## pack because it shows exactly when packs are missing. It never touches the icon registry,
## the skin manifest or the imported pack folders: the buttons are engine Buttons whose drawn face copies the pack's yellow
## (primary) and blue (secondary) 3D button colours, the card echoes the Nailed wood frame,
## and its icons are tracked files in game/boot/icons/ (hand-drawn book / door / warning, plus
## two CC0 key glyphs from the RhosGFX keyboard pack, which may be redistributed).
## Keys: Enter = Read the build guide, Esc = Quit; on desktop the key shows as a faded keycap
## inside the button's top-right corner only while the mouse hovers it (no permanent badges).

const LOGO_PATH := "res://assets/icon/logo_doubles.png"

const BG_CENTER := Color("#272c6b")
const BG_MID := Color("#14173a")
const BG_EDGE := Color("#07081a")
const CARD := Color(0.075, 0.082, 0.19, 0.97)
## Nailed-frame wood (the pack's darkbrown frame) around the card.
const WOOD := Color("#5a3a22")
const WOOD_DARK := Color("#3a2414")
## Pack 3D button colours (button-square-3d-2.5-<family>-regular_*.svg): face, hover face,
## lip, outline.
const PACK_YELLOW := [Color("#fdaf18"), Color("#fec92b"), Color("#fc9504"), Color("#f15a24")]
const PACK_BLUE := [Color("#37b9ff"), Color("#96dbff"), Color("#1778ff"), Color("#0049c7")]
const LABEL_INK := Color("#1a2530")
## Tracked icons (loaded straight from the files, never through the icon registry).
const ICON_DIR := "res://game/boot/icons/"
## Touch-target floor for the two buttons.
const BUTTON_H := 88.0
## Hover keycap height and opacity (spec 6).
const KEYCAP_H := 24.0
const KEYCAP_ALPHA := 0.6
const INK := Color("#0b0c1a")
const GOLD := Color("#f6c453")
const GOLD_HI := Color("#ffd97a")
const GOLD_LO := Color("#d9a332")
const RED := Color("#ec5a4f")
const CREAM := Color("#fbf3df")
const TEXT := Color(0.8, 0.82, 0.92)
const MUTED := Color(0.55, 0.58, 0.72)

## Lockup / card design sizes (logical px) at scale 1.
const LOGO := 156.0
const WORDMARK := 84
const CARD_W := 640.0
const GUTTER := 24.0

var _margin: MarginContainer
var _lockup_row: HBoxContainer
var _logo: Control
var _dice: Label
var _roll: Label
var _card: PanelContainer
var _buttons: BoxContainer
var readme_button: Button
var quit_button: Button


func _init() -> void:
	name = "MissingAssets"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	_layout()
	# Gentle entrance: the content fades in over the (already visible) background.
	_margin.modulate.a = 0.0
	var t := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(_margin, "modulate:a", 1.0, 0.35)


# --- build -------------------------------------------------------------------------------------

func _build() -> void:
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([BG_CENTER, BG_MID, BG_EDGE])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.36)
	tex.fill_to = Vector2(1.15, 1.05)
	tex.width = 256
	tex.height = 256
	bg.texture = tex
	add_child(bg)

	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	var center := CenterContainer.new()
	_margin.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 48)
	center.add_child(col)

	col.add_child(_lockup())
	col.add_child(_card_panel())
	# hidden Developer menu (build info / diagnostics work without the third-party assets)
	add_child(DevGesture.new())


func _lockup() -> Control:
	var row := HBoxContainer.new()
	_lockup_row = row
	row.name = "Lockup"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	var tex: Texture2D = load(LOGO_PATH) if ResourceLoader.exists(LOGO_PATH) else null
	if tex:
		var logo := TextureRect.new()
		logo.texture = tex
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_logo = logo
	else:
		_logo = Control.new()  # fallback emblem: a gold die, drawn
		_logo.draw.connect(_draw_die.bind(_logo))
	_logo.name = "Logo"
	_logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_logo)

	var word := HBoxContainer.new()
	word.add_theme_constant_override("separation", 0)
	word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dice = _word_label("DICE", GOLD)
	_roll = _word_label("ROLL", RED)
	word.add_child(_dice)
	word.add_child(_roll)
	row.add_child(word)
	return row


func _word_label(text: String, color: Color) -> Label:
	var heavy := FontVariation.new()
	heavy.base_font = ThemeDB.fallback_font
	heavy.variation_embolden = 1.1
	heavy.spacing_glyph = 2
	var ls := LabelSettings.new()
	ls.font = heavy
	ls.font_color = color
	ls.outline_size = 14
	ls.outline_color = INK
	ls.shadow_size = 0
	ls.shadow_color = Color(0, 0, 0, 0.45)
	ls.shadow_offset = Vector2(0, 6)
	var l := Label.new()
	l.text = text
	l.label_settings = ls
	return l


func _card_panel() -> Control:
	_card = PanelContainer.new()
	_card.name = "Card"
	_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(7)
	sb.border_width_bottom = 10
	sb.border_color = WOOD
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 36
	sb.shadow_offset = Vector2(0, 14)
	sb.content_margin_left = 44
	sb.content_margin_right = 44
	sb.content_margin_top = 40
	sb.content_margin_bottom = 40
	_card.add_theme_stylebox_override("panel", sb)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	_card.add_child(box)

	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 10)
	var warn := _icon_rect("warning", 30.0)
	if warn:
		brow.add_child(warn)
	var eyebrow := _text("SETUP NEEDED", 17, GOLD, 1)
	eyebrow.label_settings.font = _font(1.0, 4)
	eyebrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	eyebrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eyebrow.autowrap_mode = TextServer.AUTOWRAP_OFF
	brow.add_child(eyebrow)
	box.add_child(brow)
	box.add_child(_gap(12))
	box.add_child(_text("Required game assets are missing", 32, CREAM, 0.6))
	box.add_child(_gap(20))
	box.add_child(_body())
	box.add_child(_gap(32))

	var buttons := BoxContainer.new()
	buttons.name = "Buttons"
	buttons.add_theme_constant_override("separation", 16)
	_buttons = buttons
	var guide := _button("Read the build guide", true, "book", "key_enter")
	guide.name = "Readme"
	guide.tooltip_text = AssetCheck.README_URL
	guide.pressed.connect(func() -> void: OS.shell_open(AssetCheck.README_URL))
	buttons.add_child(guide)
	var quit := _button("Quit", false, "door", "key_esc")
	quit.name = "Quit"
	quit.size_flags_stretch_ratio = 0.55
	quit.pressed.connect(func() -> void: get_tree().quit())
	buttons.add_child(quit)
	readme_button = guide
	quit_button = quit
	box.add_child(buttons)
	box.add_child(_gap(18))

	var link := LinkButton.new()
	link.name = "ReadmeLink"
	link.text = AssetCheck.README_URL.trim_prefix("https://")
	link.uri = AssetCheck.README_URL
	link.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# a full 80 px tap row (44 pt on a phone), the text centred in it
	link.custom_minimum_size.y = 80
	link.add_theme_font_override("font", _font(0.0))
	link.add_theme_font_size_override("font_size", 17)
	link.add_theme_color_override("font_color", MUTED)
	link.add_theme_color_override("font_hover_color", GOLD_HI)
	link.add_theme_color_override("font_pressed_color", GOLD)
	link.add_theme_color_override("font_focus_color", GOLD_HI)
	box.add_child(link)
	return _card


func _body() -> RichTextLabel:
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Menlo", "SF Mono", "Consolas", "DejaVu Sans Mono", "monospace"])
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_font_override("normal_font", ThemeDB.fallback_font)
	r.add_theme_font_override("mono_font", mono)
	r.add_theme_font_size_override("normal_font_size", 21)
	r.add_theme_font_size_override("mono_font_size", 19)
	r.add_theme_color_override("default_color", TEXT)
	r.add_theme_constant_override("line_separation", 6)
	r.add_theme_constant_override("paragraph_separation", 14)
	var cmd := func(c: String) -> String:
		return "[color=#%s][code]$ [/code][/color][color=#%s][code]%s[/code][/color]" % [
			MUTED.to_html(false), GOLD_HI.to_html(false), c]
	r.text = ("Diceroll's 3D models, sound effects, music and fonts come from third-party packs "
		+ "(KayKit FREE + EXTRA, Kenney, OpenGameArt, Google Fonts) that aren't included in the repository.\n"
		+ "Download the packs, then run:\n%s\n%s\nThe build guide has every step."
		) % [cmd.call("tools/import_assets.sh"), cmd.call("godot --headless --import")]
	return r


# --- small builders ----------------------------------------------------------------------------

func _font(embolden: float, spacing := 0) -> Font:
	var f := FontVariation.new()
	f.base_font = ThemeDB.fallback_font
	f.variation_embolden = embolden
	f.spacing_glyph = spacing
	return f


func _text(s: String, size: int, color: Color, embolden: float) -> Label:
	var ls := LabelSettings.new()
	ls.font = _font(embolden)
	ls.font_size = size
	ls.font_color = color
	ls.line_spacing = 2
	var l := Label.new()
	l.text = s
	l.label_settings = ls
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _button(text: String, primary: bool, icon := "", key := "") -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, BUTTON_H)
	b.add_theme_font_override("font", _font(0.9))
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_constant_override("h_separation", 10)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var tex := _icon_texture(icon, 40.0)
	if tex:
		b.icon = tex
		b.expand_icon = false
	# the face is drawn by a child behind the label (pack colours); the label sits on the face
	for st: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		var sb := StyleBoxEmpty.new()
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.content_margin_top = 8 if st != "pressed" else 14
		sb.content_margin_bottom = 20 if st != "pressed" else 14
		b.add_theme_stylebox_override(st, sb)
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color"]:
		b.add_theme_color_override(c, LABEL_INK)
	var face := _Face.new()
	face.colors = PACK_YELLOW if primary else PACK_BLUE
	face.button = b
	face.show_behind_parent = true
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(face)
	if key != "":
		var cap := _Keycap.new()
		cap.button = b
		cap.texture = _icon_texture(key, KEYCAP_H, Color("#dfe6ea"))
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.visible = false
		cap.name = "Keycap"
		b.add_child(cap)
		b.mouse_entered.connect(cap.set_hover.bind(true))
		b.mouse_exited.connect(cap.set_hover.bind(false))
	return b


## A tracked boot icon as a texture `px` tall (null when missing: the button still works).
## Raw SVG through FileAccess when the source is there (crisp at any size), else the imported
## texture (exported builds ship imported resources only).
func _icon_texture(id: String, px: float, tint: Variant = null) -> Texture2D:
	if id == "":
		return null
	var path := ICON_DIR + id + ".svg"
	if FileAccess.file_exists(path):
		var src := FileAccess.get_file_as_string(path)
		if tint is Color:
			src = src.replace("#fff;", "#%s;" % (tint as Color).to_html(false)).replace("#fff\"", "#%s\"" % (tint as Color).to_html(false))
		var m := RegEx.create_from_string("viewBox=\"[\\d.]+ [\\d.]+ ([\\d.]+) ([\\d.]+)\"").search(src)
		var vh := float(m.get_string(2)) if m else 48.0
		var img := Image.new()
		var ds := DisplayServer.screen_get_scale() if DisplayServer.get_name() != "headless" else 1.0
		if img.load_svg_from_string(src, px / vh * maxf(2.0, ds)) == OK:
			var t := ImageTexture.create_from_image(img)
			t.set_size_override(Vector2i(roundi(px * img.get_width() / float(img.get_height())), roundi(px)))
			return t
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _icon_rect(id: String, px: float) -> TextureRect:
	var t := _icon_texture(id, px)
	if t == null:
		return null
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Enter = Read the build guide, Esc = Quit (InputMap actions when registered, else the keys).
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if _is(event, "menu_confirm", [KEY_ENTER, KEY_KP_ENTER]):
		get_viewport().set_input_as_handled()
		readme_button.pressed.emit()
	elif _is(event, "menu_back", [KEY_ESCAPE]):
		get_viewport().set_input_as_handled()
		quit_button.pressed.emit()


static func _is(event: InputEvent, action: String, keys: Array) -> bool:
	if InputMap.has_action(action):
		return event.is_action_pressed(action, false, true)
	return (event as InputEventKey).keycode in keys


## The pack 3D button look in plain draw calls: outline, lip, face (hover = lighter face;
## pressed = the face sinks onto the lip).
class _Face:
	extends Control
	var colors: Array = []
	var button: Button

	func _ready() -> void:
		for sig in ["mouse_entered", "mouse_exited", "button_down", "button_up"]:
			button.connect(sig, queue_redraw)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var k := size.y / 64.0
		var down := button.is_pressed() or button.button_pressed
		var hover := button.is_hovered() and InputMode.is_kbm()
		var o := 4.0 * k
		var lip := (10.0 if not down else 4.0) * k
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(int(9.0 * k))
		sb.bg_color = colors[3]
		draw_style_box(sb, r)
		sb.set_corner_radius_all(int(5.0 * k))
		sb.bg_color = colors[2]
		var inner := r.grow(-o)
		draw_style_box(sb, inner)
		sb.bg_color = colors[1] if hover and not down else colors[0]
		var top := inner.position.y + (6.0 * k if down else 0.0)
		draw_style_box(sb, Rect2(inner.position.x, top, inner.size.x, inner.end.y - lip - top))


## The desktop hover keycap: a faded key glyph inside the top-right of the face, only while
## the mouse hovers the button in keyboard / mouse mode.
class _Keycap:
	extends TextureRect
	var button: Button

	func set_hover(on: bool) -> void:
		visible = on and texture != null and InputMode.is_kbm()
		if not visible:
			return
		var ts := texture.get_size()
		var h := KEYCAP_H
		var w := h * ts.x / maxf(ts.y, 1.0)
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		size = Vector2(w, h)
		position = Vector2(button.size.x - w - 12.0, 9.0)
		modulate.a = KEYCAP_ALPHA


## Fallback emblem when the logo texture can't load: a gold die showing three.
func _draw_die(c: Control) -> void:
	var s := minf(c.size.x, c.size.y)
	var r := Rect2((c.size - Vector2(s, s)) / 2, Vector2(s, s)).grow(-s * 0.08)
	var sb := StyleBoxFlat.new()
	sb.bg_color = GOLD
	sb.set_corner_radius_all(int(s * 0.2))
	sb.set_border_width_all(maxi(2, int(s * 0.045)))
	sb.border_color = INK
	sb.border_width_bottom = maxi(4, int(s * 0.09))
	c.draw_style_box(sb, r)
	for i in 3:
		var p := r.position + r.size * Vector2(0.28 + 0.22 * i, 0.26 + 0.22 * i)
		c.draw_circle(p, s * 0.075, INK)


# --- layout ------------------------------------------------------------------------------------

func _layout() -> void:
	if not is_inside_tree():
		return
	var view := get_viewport().get_visible_rect().size
	var m := UiTheme.safe_margins(self)
	_margin.add_theme_constant_override("margin_left", int(maxf(m.left, GUTTER)))
	_margin.add_theme_constant_override("margin_right", int(maxf(m.right, GUTTER)))
	_margin.add_theme_constant_override("margin_top", int(maxf(m.top, GUTTER)))
	_margin.add_theme_constant_override("margin_bottom", int(maxf(m.bottom, GUTTER)))
	var avail := view.x - maxf(m.left, GUTTER) - maxf(m.right, GUTTER)
	# The lockup scales down as a unit on narrow screens (never stacks): measure it at full
	# size, then shrink logo + wordmark together to fit.
	var k := clampf(avail / _lockup_width(), 0.4, 1.0)
	_size_lockup(k)
	_card.custom_minimum_size.x = minf(CARD_W, avail)
	# the two 88 px buttons stack on narrow cards so neither label is squeezed
	_buttons.vertical = _card.custom_minimum_size.x < 520.0
	_logo.queue_redraw()


## Lockup width at full size (labels only update their minimum size a frame later, so measure).
func _lockup_width() -> float:
	var w := LOGO + 18.0
	for l: Label in [_dice, _roll]:
		w += l.label_settings.font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, WORDMARK).x + 14.0
	return w


func _size_lockup(k: float) -> void:
	_logo.custom_minimum_size = Vector2.ONE * roundf(LOGO * k)
	_lockup_row.add_theme_constant_override("separation", int(18 * k))
	for l: Label in [_dice, _roll]:
		l.label_settings.font_size = int(WORDMARK * k)
		l.label_settings.outline_size = int(14 * k)
