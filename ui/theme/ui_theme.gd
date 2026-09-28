class_name UiTheme
extends RefCounted
## Fonts, Theme resource, StyleBox factories and small builders shared by every screen.
##
##   root.theme = UiTheme.get_theme()
##   var l := UiTheme.label("GOLD", 28, UiPalette.GOLD, true, 6)
##   panel.add_theme_stylebox_override("panel", UiTheme.panel_box("card"))

const DISPLAY_PATH := "res://assets/fonts/LilitaOne-Regular.ttf"
const BODY_PATH := "res://assets/fonts/Fredoka-Variable.ttf"

## Safe padding from screen edges (logical px), raised by the device safe area when larger.
const EDGE := 24.0
## Portion of the screen height reserved for the dice tray (owned by game/dice).
const TRAY_FRACTION := 0.24
## Max width of modal panels.
const MODAL_MAX_W := 680.0
## Minimum touch target on phones.
const TOUCH := 88.0

static var _theme: Theme
static var _display: Font
static var _body: Dictionary = {}
static var _label_settings: Dictionary = {}


static func display_font() -> Font:
	if _display == null:
		var f := FontFile.new()
		f.load_dynamic_font(DISPLAY_PATH)
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.hinting = TextServer.HINTING_LIGHT
		f.generate_mipmaps = true
		_display = f
	return _display


## Fredoka at a variable weight (300..700).
static func body_font(weight: int = 500) -> Font:
	if not _body.has(weight):
		var base: Font = load(BODY_PATH)
		var v := FontVariation.new()
		v.base_font = base
		var ts := TextServerManager.get_primary_interface()
		v.variation_opentype = {ts.name_to_tag("wght"): weight}
		_body[weight] = v
	return _body[weight]


# ---------------------------------------------------------------- style boxes

static func box(bg: Color, radius: int = 20, border: int = 0, border_color := Color.TRANSPARENT,
		shadow: int = 0, shadow_color := Color(0, 0, 0, 0.45), shadow_offset := Vector2(0, 6)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.corner_detail = 10
	s.anti_aliasing = true
	s.anti_aliasing_size = 1.2
	if border > 0:
		s.set_border_width_all(border)
		s.border_color = border_color
	if shadow > 0:
		s.shadow_size = shadow
		s.shadow_color = shadow_color
		s.shadow_offset = shadow_offset
	return s


static func pad(s: StyleBox, h: float, v: float = -1.0) -> StyleBox:
	s.content_margin_left = h
	s.content_margin_right = h
	s.content_margin_top = h if v < 0.0 else v
	s.content_margin_bottom = h if v < 0.0 else v
	return s


## Named panel styles: main (modal), card, card_hi (selected), inset, hud, pill, tooltip.
static func panel_box(kind: String = "main") -> StyleBoxFlat:
	var s: StyleBoxFlat
	match kind:
		"main":
			s = box(UiPalette.PANEL, 34, 3, UiPalette.GOLD_LINE, 28, Color(0, 0, 0, 0.55), Vector2(0, 10))
			pad(s, 32, 28)
		"card":
			s = box(UiPalette.NAVY_2, 24, 2, Color(1, 1, 1, 0.08), 10, Color(0, 0, 0, 0.35), Vector2(0, 5))
			pad(s, 20, 18)
		"card_hi":
			s = box(UiPalette.NAVY_3, 24, 4, UiPalette.GOLD_BRIGHT, 16, Color(0.95, 0.7, 0.2, 0.35), Vector2(0, 0))
			pad(s, 18, 16)
		"inset":
			s = box(Color(0.03, 0.03, 0.09, 0.55), 18, 0)
			pad(s, 16, 12)
		"hud":
			s = box(UiPalette.PANEL_SOFT, 26, 2, UiPalette.GOLD_FAINT, 14, Color(0, 0, 0, 0.35), Vector2(0, 4))
			pad(s, 14, 10)
		"pill":
			s = box(Color(0.05, 0.05, 0.13, 0.82), 40, 2, UiPalette.GOLD_FAINT, 8, Color(0, 0, 0, 0.3), Vector2(0, 3))
			pad(s, 18, 8)
		"tooltip":
			s = box(UiPalette.INK, 14, 2, UiPalette.GOLD_LINE)
			pad(s, 14, 10)
		_:
			s = box(UiPalette.PANEL, 24)
	return s


# ---------------------------------------------------------------- labels

static func label_settings(size: int, color: Color = UiPalette.TEXT, display := true, outline := 0,
		outline_color: Color = UiPalette.OUTLINE, shadow := false, weight := 600) -> LabelSettings:
	var key := "%d|%s|%s|%d|%s|%s|%d" % [size, color.to_html(), display, outline, outline_color.to_html(), shadow, weight]
	if _label_settings.has(key):
		return _label_settings[key]
	var ls := LabelSettings.new()
	ls.font = display_font() if display else body_font(weight)
	ls.font_size = size
	ls.font_color = color
	if outline > 0:
		ls.outline_size = outline
		ls.outline_color = outline_color
	if shadow:
		ls.shadow_size = 2
		ls.shadow_color = Color(0, 0, 0, 0.55)
		ls.shadow_offset = Vector2(0, maxf(2.0, size * 0.08))
	_label_settings[key] = ls
	return ls


static func label(text: String, size: int = 26, color: Color = UiPalette.TEXT, display := true, outline := 0,
		shadow := false, weight := 600) -> Label:
	var l := Label.new()
	l.text = text
	l.label_settings = label_settings(size, color, display, outline, UiPalette.OUTLINE, shadow, weight)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## Wrapped body copy.
static func para(text: String, size: int = 24, color: Color = UiPalette.TEXT_DIM, weight := 500) -> Label:
	var l := label(text, size, color, false, 0, false, weight)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 40
	return l


# ---------------------------------------------------------------- layout helpers

static func vbox(sep: int = 12) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func hbox(sep: int = 12) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func spacer(h: float = 0.0, expand := false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(h, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func panel(kind: String = "main") -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_box(kind))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p


static func margin(node: Control, l: float, t: float, r: float, b: float) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", int(l))
	m.add_theme_constant_override("margin_top", int(t))
	m.add_theme_constant_override("margin_right", int(r))
	m.add_theme_constant_override("margin_bottom", int(b))
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if node:
		m.add_child(node)
	return m


static func full_rect(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0
	return c


## True when the canvas is taller than wide (phone portrait).
static func is_portrait(size: Vector2) -> bool:
	return size.y >= size.x * 0.9


class Margins:
	extends RefCounted
	var left := EDGE
	var top := EDGE
	var right := EDGE
	var bottom := EDGE


## Safe margins (logical px) for a node's viewport: device safe area on phones, EDGE minimum.
static func safe_margins(node: Node) -> Margins:
	var m := Margins.new()
	if node == null or not node.is_inside_tree():
		return m
	if not (OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android")):
		return m
	var vp := node.get_viewport()
	var logical: Vector2 = vp.get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0:
		return m
	var k := logical.x / win.x
	var screen := Vector2(DisplayServer.screen_get_size())
	m.left = maxf(EDGE, safe.position.x * k)
	m.top = maxf(EDGE, safe.position.y * k)
	m.right = maxf(EDGE, (screen.x - safe.end.x) * k)
	m.bottom = maxf(EDGE, (screen.y - safe.end.y) * k)
	return m


## Height of the dice-tray band at the bottom of the screen.
static func tray_height(view: Vector2) -> float:
	return round(view.y * TRAY_FRACTION)


## Width of the dice tray (portrait: nearly full width; landscape: capped and centred).
static func tray_width(view: Vector2) -> float:
	return view.x - 24.0 if view.y > view.x else minf(view.x - 48.0, 920.0)


## Landscape only: the free band to the right of the dice tray, where the bottom HUD
## (ROLL / GO / Reroll / Attack) lives so the world keeps the height above the tray.
## Empty Rect2 in portrait or when the band is too narrow.
static func side_slot(view: Vector2) -> Rect2:
	if view.y > view.x:
		return Rect2()
	var th := tray_height(view)
	var x0 := (view.x + tray_width(view)) * 0.5 + 20.0
	var r := Rect2(x0, view.y - th - 40.0, view.x - x0 - 28.0, th + 20.0)
	return r if r.size.x >= 420.0 else Rect2()


## Vertical gradient texture (top -> bottom colours, optional middle stop).
## Built synchronously from an Image (GradientTexture2D updates deferred and can draw blank).
static func vgradient(top: Color, bottom: Color, mid: Variant = null) -> Texture2D:
	var h := 128
	var img := Image.create(1, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var t := float(y) / float(h - 1)
		var c: Color
		if mid is Color:
			c = top.lerp(mid, t * 2.0) if t < 0.5 else (mid as Color).lerp(bottom, (t - 0.5) * 2.0)
		else:
			c = top.lerp(bottom, t)
		img.set_pixel(0, y, c)
	return ImageTexture.create_from_image(img)


## Removes and frees every child of `node`.
static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


# ---------------------------------------------------------------- tweens

## Quick pop-in used by counters, badges and banners.
static func pop(node: CanvasItem, amount := 1.18, time := 0.22) -> void:
	if node == null or not node.is_inside_tree():
		return
	if node is Control:
		(node as Control).pivot_offset = (node as Control).size * 0.5
	var t := node.create_tween()
	t.tween_property(node, "scale", Vector2.ONE * amount, time * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", Vector2.ONE, time * 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func sfx(id: String) -> void:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null:
		return
	var a := loop.root.get_node_or_null("Audio")
	if a != null and a.has_method("play_sfx"):
		a.play_sfx(id)


# ---------------------------------------------------------------- theme resource

static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = body_font(500)
	t.default_font_size = 26

	t.set_color("font_color", "Label", UiPalette.TEXT)

	# Plain Buttons (GameButton is preferred, but never show Godot grey).
	var bn := box(UiPalette.SECONDARY, 20, 2, UiPalette.GOLD_FAINT)
	pad(bn, 20, 12)
	var bh := box(UiPalette.NAVY_3, 20, 2, UiPalette.GOLD_LINE)
	pad(bh, 20, 12)
	var bp := box(UiPalette.SECONDARY_DARK, 20, 2, UiPalette.GOLD)
	pad(bp, 20, 12)
	var bd := box(UiPalette.DISABLED_DARK, 20, 0)
	pad(bd, 20, 12)
	for st in [["normal", bn], ["hover", bh], ["pressed", bp], ["disabled", bd], ["focus", StyleBoxEmpty.new()]]:
		t.set_stylebox(st[0], "Button", st[1])
	t.set_font("font", "Button", display_font())
	t.set_font_size("font_size", "Button", 28)
	t.set_color("font_color", "Button", UiPalette.TEXT)
	t.set_color("font_hover_color", "Button", UiPalette.GOLD_BRIGHT)
	t.set_color("font_pressed_color", "Button", UiPalette.GOLD)
	t.set_color("font_disabled_color", "Button", UiPalette.TEXT_MUTED)

	t.set_stylebox("panel", "PanelContainer", panel_box("main"))
	t.set_stylebox("panel", "Panel", panel_box("main"))

	# Sliders
	var track := box(Color(0.02, 0.02, 0.07, 0.8), 12, 2, Color(1, 1, 1, 0.06))
	track.content_margin_top = 10
	track.content_margin_bottom = 10
	var fill := box(UiPalette.GOLD, 12)
	fill.content_margin_top = 10
	fill.content_margin_bottom = 10
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var knob := _knob_texture(44, false)
	t.set_icon("grabber", "HSlider", knob)
	t.set_icon("grabber_highlight", "HSlider", _knob_texture(44, true))
	t.set_icon("grabber_disabled", "HSlider", knob)
	t.set_icon("tick", "HSlider", ImageTexture.new())
	t.set_constant("center_grabber", "HSlider", 1)

	# Scroll bars
	var sb := box(Color(1, 1, 1, 0.04), 6)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	var grab := box(UiPalette.GOLD_FAINT, 6)
	var grab_h := box(UiPalette.GOLD_LINE, 6)
	for kind in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", kind, sb)
		t.set_stylebox("grabber", kind, grab)
		t.set_stylebox("grabber_highlight", kind, grab_h)
		t.set_stylebox("grabber_pressed", kind, grab_h)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())

	t.set_stylebox("panel", "TooltipPanel", panel_box("tooltip"))
	t.set_color("font_color", "TooltipLabel", UiPalette.TEXT)
	t.set_font("font", "TooltipLabel", body_font(500))
	t.set_font_size("font_size", "TooltipLabel", 22)
	_theme = t
	return t


## Gold slider knob with a dark rim, drawn into an image.
static func _knob_texture(px: int, hot: bool) -> Texture2D:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var c := Vector2(px, px) * 0.5
	var r_out := px * 0.5 - 1.0
	var face := UiPalette.GOLD_BRIGHT if hot else UiPalette.GOLD
	for y in px:
		for x in px:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var col := Color(0, 0, 0, 0)
			if d <= r_out:
				col = UiPalette.OUTLINE
				if d <= r_out - 3.0:
					var k := clampf((y - c.y) / r_out * 0.5 + 0.5, 0.0, 1.0)
					col = face.lerp(UiPalette.GOLD_DEEP, k * 0.7)
				if d <= r_out * 0.32:
					col = UiPalette.GOLD_DARK
				col.a = clampf(r_out - d + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
