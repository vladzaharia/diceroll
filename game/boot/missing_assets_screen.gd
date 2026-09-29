class_name MissingAssetsScreen
extends Control
## "Required game assets are missing" screen (see AssetCheck). Built only from engine built-ins
## plus our own tracked logo (res://assets/icon/logo_doubles.png, with a drawn die as fallback):
## no project theme, fonts or third-party textures, since those are exactly what may be missing.
## Layout: a DICE|ROLL lockup (logo + wordmark, scaled down on narrow screens) above a card with
## the explanation, a "Read the build guide" button (README) and Quit. Respects safe areas.
## Hosts the hidden DevGesture (bottom-right corner, 5 taps): the Developer menu uses UiTheme,
## which falls back to the engine font when the third-party fonts are missing.

const LOGO_PATH := "res://assets/icon/logo_doubles.png"

const BG_CENTER := Color("#272c6b")
const BG_MID := Color("#14173a")
const BG_EDGE := Color("#07081a")
const CARD := Color(0.075, 0.082, 0.19, 0.96)
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
	sb.set_corner_radius_all(28)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.08)
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

	var eyebrow := _text("SETUP NEEDED", 17, GOLD, 1)
	eyebrow.label_settings.font = _font(1.0, 4)
	box.add_child(eyebrow)
	box.add_child(_gap(12))
	box.add_child(_text("Required game assets are missing", 32, CREAM, 0.6))
	box.add_child(_gap(20))
	box.add_child(_body())
	box.add_child(_gap(32))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	var guide := _button("Read the build guide", true)
	guide.name = "Readme"
	guide.tooltip_text = AssetCheck.README_URL
	guide.pressed.connect(func() -> void: OS.shell_open(AssetCheck.README_URL))
	buttons.add_child(guide)
	var quit := _button("Quit", false)
	quit.name = "Quit"
	quit.size_flags_stretch_ratio = 0.55
	quit.pressed.connect(func() -> void: get_tree().quit())
	buttons.add_child(quit)
	box.add_child(buttons)
	box.add_child(_gap(18))

	var link := LinkButton.new()
	link.name = "ReadmeLink"
	link.text = AssetCheck.README_URL.trim_prefix("https://")
	link.uri = AssetCheck.README_URL
	link.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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
		+ "(KayKit FREE + EXTRA, Kenney, Mixkit, Google Fonts) that aren't included in the repository.\n"
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


func _button(text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 64)
	b.add_theme_font_override("font", _font(0.7))
	b.add_theme_font_size_override("font_size", 22)
	var base := GOLD if primary else Color(1, 1, 1, 0.06)
	var hover := GOLD_HI if primary else Color(1, 1, 1, 0.12)
	var down := GOLD_LO if primary else Color(1, 1, 1, 0.03)
	var fg := INK if primary else CREAM
	for st: String in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": base, "hover": hover, "pressed": down, "disabled": base}[st]
		sb.set_corner_radius_all(16)
		# Same border geometry on both kinds so their labels share a baseline.
		sb.set_border_width_all(2)
		sb.border_width_bottom = 2 if st == "pressed" else 5
		if primary:
			sb.border_color = GOLD_LO.darkened(0.3) if st != "pressed" else down
		else:
			sb.border_color = Color(1, 1, 1, 0.16 if st != "hover" else 0.28)
		sb.content_margin_left = 20
		sb.content_margin_right = 20
		b.add_theme_stylebox_override(st, sb)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_corner_radius_all(20)
	focus.set_border_width_all(3)
	focus.border_color = CREAM
	focus.set_expand_margin_all(5)
	b.add_theme_stylebox_override("focus", focus)
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color"]:
		b.add_theme_color_override(c, fg)
	return b


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
