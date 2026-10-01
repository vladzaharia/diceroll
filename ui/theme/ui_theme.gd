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
		# Source checkouts without the third-party fonts (missing-assets boot screen + dev
		# menu): fall back to the engine font instead of drawing nothing.
		if not FileAccess.file_exists(DISPLAY_PATH) and not ResourceLoader.exists(DISPLAY_PATH):
			_display = ThemeDB.fallback_font
			return _display
		var f: FontFile
		if ResourceLoader.exists(DISPLAY_PATH):
			# Exported builds only contain the imported font (.fontdata), not the raw .ttf.
			f = (load(DISPLAY_PATH) as FontFile).duplicate()
		else:
			f = FontFile.new()
			f.load_dynamic_font(DISPLAY_PATH)
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.hinting = TextServer.HINTING_LIGHT
		f.generate_mipmaps = true
		_display = f
	return _display


## Fredoka at a variable weight (300..700).
static func body_font(weight: int = 500) -> Font:
	if not _body.has(weight):
		var base: Font = load(BODY_PATH) if ResourceLoader.exists(BODY_PATH) else ThemeDB.fallback_font
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


## The pre-reskin flat look of a named panel (main, card, card_hi, inset, hud, pill, tooltip):
## the fallback when the RhosGFX pack is absent (UiSkin "panel:<kind>" fallbacks) and the
## base the accent recolours. Always a fresh StyleBoxFlat.
static func flat_box(kind: String = "main") -> StyleBoxFlat:
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


# ---------------------------------------------------------------- RhosGFX factories
#
# Shared StyleBox factories for the UI reskin (docs/design/2026-09-30-ui-reskin.md section 2).
# Each returns the pack art (UiSkin, ui/theme/ui_pack.json) when it was imported and the
# pre-reskin flat look otherwise, as a fresh StyleBox that is safe to edit (content margins,
# UiTheme.pad). Never cast the result to StyleBoxFlat: pass an `accent` instead.

## Pack family per panel kind / piece suffix; used by chip_box / plaque / round buttons.
const FAMILIES := ["yellow", "blue", "red", "green", "forestgreen", "purple", "pink", "grey", "white"]

## Named panel styles: main (modal), card, card_hi (selected), inset, hud, pill, tooltip.
## `accent` (Color) = a coloured rim: card -> Thin white rim x accent, tooltip -> callout rim,
## pill -> a dark accent-tinted pill, main / hud / inset -> ignored with the pack (flat
## fallback: border colour). Replaces mutating the returned box (R10).
static func panel_box(kind: String = "main", accent: Variant = null) -> StyleBox:
	var fb := flat_box(kind)
	if accent is Color:
		var a := accent as Color
		fb.border_color = Color(a, 0.7)
		fb.set_border_width_all(maxi(fb.border_width_top, 2))
	match kind:
		"main":
			return UiSkin.stylebox("panel_main", "normal", fb)
		"main_lg":
			return UiSkin.stylebox("panel_main_lg", "normal", flat_box("main"))
		"card":
			return card_box("normal", accent) if accent is Color else UiSkin.stylebox("panel_card", "normal", fb)
		"card_hi":
			return UiSkin.stylebox("panel_card", "selected", fb)
		"inset":
			return UiSkin.stylebox("panel_inset", "normal", fb)
		"hud":
			return UiSkin.stylebox("panel_hud", "normal", fb)
		"pill":
			if accent is Color:
				return UiSkin.stylebox("chip_white", "normal", {"fallback": fb, "tint": (accent as Color).darkened(0.62)})
			return UiSkin.stylebox("panel_pill", "normal", fb)
		"tooltip":
			return callout_box(accent) if accent is Color else UiSkin.stylebox("tooltip", "normal", fb)
		"tray":
			return UiSkin.stylebox("panel_tray", "normal", flat_box("hud"))
		"well":
			return UiSkin.stylebox("well", "normal", flat_box("inset"))
	return fb


## Card / tile (CampUi.card, OptionCard, class card, shop / draft / event options):
## state "normal" | "hover" | "selected" | "worn" | "on" | "craftable" | "owned" | "locked" |
## "dim"; `accent` (rarity / class / biome Color) = Thin white rim x accent (normal / hover).
static func card_box(state: String = "normal", accent: Variant = null) -> StyleBox:
	var fb := flat_box("card_hi" if state in ["selected", "worn", "on", "craftable"] else "card")
	match state:
		"hover", "owned":
			fb.bg_color = UiPalette.NAVY_3
		"on":
			fb.border_color = UiPalette.XP
		"locked":
			fb.bg_color = Color(0.06, 0.06, 0.13, 0.9)
			fb.border_color = Color(1, 1, 1, 0.06)
		"dim":
			fb.bg_color = Color(UiPalette.NAVY_2, 0.6)
	if accent is Color and state in ["normal", "hover"]:
		fb.border_color = Color(accent as Color, 0.55)
		fb.set_border_width_all(2)
		return UiSkin.stylebox("card_accent", state, {"fallback": fb, "tint": accent})
	return UiSkin.stylebox("panel_card", state, fb)


## Flat tile / card (user rule, modal pass 2026-10-01: tiles never look like buttons, only
## buttons carry the 3D lip). States: "normal", "hover" (selectable tiles only), "selected",
## "worn", "on", "craftable", "owned", "locked", "dim"; `accent` = a rim in that colour (normal /
## hover). Pieces "tile" / "tile_accent" in ui_pack.json. Use this for every content tile in a
## modal; card_box() (the 3D card) stays for screens that still want it.
static func tile_box(state: String = "normal", accent: Variant = null) -> StyleBox:
	var fb := flat_box("card_hi" if state in ["selected", "worn", "on", "craftable"] else "card")
	match state:
		"hover", "owned":
			fb.bg_color = UiPalette.NAVY_3
		"on":
			fb.border_color = UiPalette.XP
		"locked":
			fb.bg_color = Color(0.06, 0.06, 0.13, 0.9)
			fb.border_color = Color(1, 1, 1, 0.06)
		"dim":
			fb.bg_color = Color(UiPalette.NAVY_2, 0.6)
	if accent is Color and state in ["normal", "hover"]:
		fb.border_color = Color(accent as Color, 0.55)
		fb.set_border_width_all(2)
		return UiSkin.stylebox("tile_accent", state, {"fallback": fb, "tint": accent})
	return UiSkin.stylebox("tile", state, fb)


## Chip / pill / tag / badge background. `color_or_family`: a pack family name (FAMILIES:
## "red" = NEW, "purple" = EQUIPPED, "green" = level / KIT, "grey" = HUD counter,
## "yellow" = AUTO on / active tab) drawn natively, or any Color (white art x colour).
## Content margins 18/6 px; the art shrinks to the chip's height (fit).
static func chip_box(color_or_family: Variant = "grey") -> StyleBox:
	var fam := String(color_or_family) if color_or_family is String or color_or_family is StringName else ""
	var col: Color = color_or_family if color_or_family is Color else family_color(fam)
	var fb := pad(box(col, 12, 0), 10, 3)
	if fam != "" and fam in FAMILIES:
		return UiSkin.stylebox("chip_" + fam, "normal", fb)
	var o := {"fallback": fb, "tint": Color(col, 1.0)}
	if col.a < 0.999:
		o["modulate"] = Color(1, 1, 1, col.a)
	return UiSkin.stylebox("chip_white", "normal", o)


## Callout / accent tooltip (item pop, passive + biome cards, affix / meta tips): an ink box
## with a Thin rim in `rim` (the rim colour is the information). null = the plain tooltip
## (darkbrown rim).
static func callout_box(rim: Variant = null) -> StyleBox:
	if not rim is Color:
		return UiSkin.stylebox("tooltip", "normal", flat_box("tooltip"))
	var fb := pad(box(Color(0.06, 0.06, 0.14, 0.95), 22, 2, Color(rim as Color, 0.9)), 18, 14)
	return UiSkin.stylebox("callout", "normal", {"fallback": fb, "tint": rim})


## Inset / stat well (flat INK at .55).
static func inset_box() -> StyleBox:
	return UiSkin.stylebox("panel_inset", "normal", flat_box("inset"))


## Round well behind a 3D thumbnail (plan d `well`).
static func well_box() -> StyleBox:
	return UiSkin.stylebox("well", "normal", flat_box("inset"))


## Station tag (camp): ink + Thin rim in the station colour.
static func tag_box(rim: Color) -> StyleBox:
	var fb := pad(box(Color(0.03, 0.03, 0.09, 0.8), 18, 2, Color(rim, 0.7)), 14, 8)
	return UiSkin.stylebox("tag_station", "normal", {"fallback": fb, "tint": rim})


## Enemy / danger surface (encounter + boss cards): ink + Pointed frame x `rim`.
static func danger_box(rim: Color) -> StyleBox:
	var fb := pad(box(Color(0.05, 0.05, 0.12, 0.93), 26, 3, rim), 26, 18)
	return UiSkin.stylebox("frame_pointed", "normal", {"fallback": fb, "tint": rim})


## Bar kinds -> {piece, fallback fill colour}. hp = Wide red (ghost yellow), block = blue,
## xp = purple, mastery = yellow, loading = Thin green, enemy = Thin red, par = yellow ("over" red).
const BARS := {
	"hp": ["bar_hp", UiPalette.HP], "block": ["bar_block", UiPalette.BLOCK], "xp": ["bar_xp", UiPalette.XP],
	"mastery": ["bar_mastery", UiPalette.GOLD], "loading": ["bar_loading", UiPalette.HEAL],
	"enemy": ["bar_enemy", UiPalette.HP], "par": ["bar_par", UiPalette.GOLD],
}


## Track + fill boxes of a bar: {"bg", "fill", "ghost", "over"} (StyleBoxes; "ghost" = the
## delayed drain / lead segment, "over" = the par meter past par). Draw "bg" over the whole
## rect and "fill" / "ghost" over the filled part of the same rect: the fill art insets
## itself inside the track rim. `skinned` tells whether the art is in use.
static func bar_boxes(kind: String = "hp") -> Dictionary:
	var spec: Array = BARS.get(kind, BARS["mastery"])
	var piece: String = spec[0]
	var col: Color = spec[1]
	var track := box(Color(0.02, 0.02, 0.07, 0.85), 99, 2, Color(1, 1, 1, 0.06))
	var fill := box(col, 99)
	fill.expand_margin_left = -3
	fill.expand_margin_top = -3
	fill.expand_margin_right = -3
	fill.expand_margin_bottom = -3
	var ghost := fill.duplicate() as StyleBoxFlat
	ghost.bg_color = Color("ffd7a0")
	var over := fill.duplicate() as StyleBoxFlat
	over.bg_color = UiPalette.HP
	return {
		"bg": UiSkin.stylebox(piece, "background", track),
		"fill": UiSkin.stylebox(piece, "fill", fill),
		"ghost": UiSkin.stylebox(piece, "ghost", ghost) if UiSkin.has(piece, "ghost") else ghost,
		"over": UiSkin.stylebox(piece, "over", over) if UiSkin.has(piece, "over") else over,
		"skinned": UiSkin.has(piece, "background"),
	}


## Toast background (one helper: Toast.show): callout art with a rim by type:
## "reward" gold, "danger" red, "heal" green, "info" blue; or any Color.
static func toast_box(kind: Variant = "info") -> StyleBox:
	var rim: Color = kind if kind is Color else toast_color(String(kind))
	var fb := flat_box("pill")
	pad(fb, 24, 12)
	fb.border_color = Color(rim, 0.6)
	return UiSkin.stylebox("toast", "normal", {"fallback": fb, "tint": rim})


static func toast_color(kind: String) -> Color:
	match kind:
		"reward", "unlock", "gold":
			return UiPalette.GOLD
		"danger", "damage", "red":
			return UiPalette.PACK_RED
		"heal", "success", "green":
			return UiPalette.PACK_GREEN
	return UiPalette.PACK_BLUE


## Title plaque (UiModal header, minigame header): 3D square face in a pack family
## ("yellow", "red" GAME OVER, "purple" LEVEL UP, "green" VICTORY, ...) or a Color (white x colour).
static func plaque_box(color_or_family: Variant = "yellow") -> StyleBox:
	var fam := family_of(color_or_family)
	# a colour whose nearest family has no plaque art (grey: steel, silver) is the white
	# plaque x that colour; it used to resolve to the missing plaque_grey and draw nothing
	if color_or_family is Color and (fam == "white" or not UiSkin.has("plaque_" + fam)):
		return UiSkin.stylebox("plaque_white", "normal", {"fallback": StyleBoxEmpty.new(), "tint": color_or_family})
	return UiSkin.stylebox("plaque_" + fam, "normal", StyleBoxEmpty.new())


## Tab / segment of a segmented control (selected = yellow pill, else grey-darker).
static func tab_box(selected: bool, state: String = "normal") -> StyleBox:
	var fb := pad(box(UiPalette.PRIMARY if selected else UiPalette.SECONDARY, 40, 0), 18, 6)
	return UiSkin.stylebox("tab", "selected" if selected else state, fb)


## Track behind a row of tabs.
static func tab_track_box() -> StyleBox:
	return UiSkin.stylebox("tab_track", "normal", pad(box(Color(0.02, 0.02, 0.07, 0.6), 22, 0), 6, 6))


## Keyboard / gamepad focus ring for non-button controls (drawn inset, desktop only).
static func focus_box() -> StyleBox:
	var fb := box(Color.TRANSPARENT, 16, 3, UiPalette.GOLD_BRIGHT)
	fb.draw_center = false
	return UiSkin.stylebox("focus_ring", "normal", fb)


## True when a piece's art was imported (the reskin is live for it).
static func skinned(piece: String = "panel_main") -> bool:
	return UiSkin.has(piece)


## Nearest pack family of a Color (plaques, round buttons); a family name passes through.
## Colours that are not close to a native face map to "white" (tinted at use).
static func family_of(v: Variant) -> String:
	if v is String or v is StringName:
		return String(v) if String(v) in FAMILIES else "yellow"
	if not v is Color:
		return "yellow"
	var c := v as Color
	if c.s < 0.25:
		return "grey"
	var h := c.h * 360.0
	if h < 18.0 or h >= 340.0:
		return "red"
	if h < 65.0:
		return "yellow"
	if h < 160.0:
		return "green"
	if h < 250.0:
		return "blue"
	if h < 300.0:
		return "purple"
	return "pink"


## Face colour of a pack family (fallback looks, label contrast).
static func family_color(fam: String) -> Color:
	match fam:
		"yellow":
			return UiPalette.PACK_YELLOW
		"blue":
			return UiPalette.PACK_BLUE
		"red":
			return UiPalette.PACK_RED
		"green":
			return UiPalette.PACK_GREEN
		"forestgreen":
			return Color("39a845")
		"purple":
			return UiPalette.PACK_PURPLE
		"pink":
			return Color("ff6fae")
		"white":
			return Color.WHITE
	return UiPalette.SLATE


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


static func panel(kind: String = "main", accent: Variant = null) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_box(kind, accent))
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


## Phone-landscape UI boost (plan d proposal, verified by slice a's iPhone-landscape shots):
## a wide phone screen (aspect above 1.9, e.g. 874x402 pt) lays the 720x1280-based canvas
## out ~2780 logical px wide, so every label is tiny; multiplying the content scale by this
## factor (1.4) makes modals, the HUD and the camp readable without breaking layouts.
## `window_size` = the window in screen px. Desktops (even ultrawide) and tablets get 1.0:
## only touch platforms, or screenshot runs emulating a phone (--safe=), qualify.
const LANDSCAPE_BOOST := 1.4
const LANDSCAPE_ASPECT := 1.9


static func landscape_ui_boost(window_size: Vector2) -> float:
	if window_size.y <= 0.0 or window_size.x / window_size.y <= LANDSCAPE_ASPECT:
		return 1.0
	var phone := OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android") \
		or not _emulated_safe().is_empty()
	return LANDSCAPE_BOOST if phone else 1.0


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
	# Screenshot/device-matrix emulation: `--safe=top,bottom,left,right` as fractions of
	# the view (e.g. an iPhone notch + home indicator) so desktop runs lay out like phones.
	var emu := _emulated_safe()
	if not emu.is_empty():
		var v: Vector2 = node.get_viewport().get_visible_rect().size
		m.top = maxf(EDGE, emu[0] * v.y)
		m.bottom = maxf(EDGE, emu[1] * v.y)
		m.left = maxf(EDGE, emu[2] * v.x)
		m.right = maxf(EDGE, emu[3] * v.x)
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


static var _safe_emu: Array = []
static var _safe_emu_read := false

static func _emulated_safe() -> Array:
	if not _safe_emu_read:
		_safe_emu_read = true
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--safe="):
				var parts := a.substr(7).split(",")
				if parts.size() == 4:
					_safe_emu = [float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3])]
	return _safe_emu


# ---------------------------------------------------------------- responsive layout
#
# One set of rules places the HUD column, the dice tray and the bottom controls at every
# canvas size (the canvas is 720x1280-based, `expand` stretch, so desktops are ~1280 tall
# and phones ~720 wide; a UI-size setting / OS zoom shrinks the logical canvas).
#
#   portrait:  [HUD row full width] ... board ... [bottom bar] [tray full width]
#   landscape: one centred column (column_width): [HUD row + AUTO cluster] at the top,
#              [tray | side slot (ROLL / GO / Attack)] at the bottom.
# The 3D camera frames the board in whatever is left between them (measured at runtime,
# see game/camera/screen_insets.gd).

## Landscape side slot (bottom controls beside the tray): min / max width.
const SLOT_MIN_W := 420.0
const SLOT_MAX_W := 520.0


## Portrait layout = taller than wide (phones, iPad portrait).
static func is_tall(view: Vector2) -> bool:
	return view.y > view.x


## Width of the centred content column (HUD group, tray + side slot).
static func column_width(view: Vector2, safe: Margins = null) -> float:
	var avail := view.x - (safe.left + safe.right if safe else EDGE * 2.0)
	if is_tall(view):
		return avail
	return minf(avail, clampf(view.y * 1.15, 1100.0, 1560.0))


## Height of the dice-tray band at the bottom of the screen (die size follows it, so it is
## capped: portrait by the tray width, landscape by an absolute maximum).
static func tray_height(view: Vector2) -> float:
	if is_tall(view):
		return round(clampf(minf(view.y * 0.2, (view.x - 24.0) * 0.44), 190.0, 360.0))
	return round(clampf(view.y * 0.235, 170.0, 320.0))


## Width of the side slot beside the tray in landscape (0 = no room: controls go above).
static func _slot_w(view: Vector2, safe: Margins = null) -> float:
	if is_tall(view):
		return 0.0
	var col := column_width(view, safe)
	var sw := clampf(col * 0.3, SLOT_MIN_W, SLOT_MAX_W)
	return sw if col - sw - 20.0 >= tray_height(view) * 2.4 else 0.0


## Width of the dice tray: portrait nearly full width; landscape the column minus the side
## slot (wide on desktop), or a capped centred tray when there is no side slot.
static func tray_width(view: Vector2, safe: Margins = null) -> float:
	if is_tall(view):
		return view.x - 24.0
	var col := column_width(view, safe)
	var sw := _slot_w(view, safe)
	if sw > 0.0:
		return col - sw - 20.0
	return minf(col, tray_height(view) * 4.2)


## Screen rect of the dice tray (canvas px). Lifted above a home indicator.
static func tray_rect(view: Vector2, safe: Margins = null) -> Rect2:
	var th := tray_height(view)
	var tw := tray_width(view, safe)
	var lift := maxf((safe.bottom if safe else EDGE) - EDGE, 0.0) * 0.6
	var x := (view.x - tw) * 0.5
	if _slot_w(view, safe) > 0.0:
		x = (view.x - column_width(view, safe)) * 0.5
	return Rect2(round(x), view.y - th + 4.0 - lift, tw, th - 16.0)


## Landscape only: the free band right of the dice tray (inside the column), where the
## bottom HUD (ROLL / GO / Reroll / Attack) lives so the world keeps the height above the
## tray. Empty Rect2 in portrait or when the column is too narrow.
static func side_slot(view: Vector2, safe: Margins = null) -> Rect2:
	var sw := _slot_w(view, safe)
	if sw <= 0.0:
		return Rect2()
	var tr := tray_rect(view, safe)
	var x0 := tr.end.x + 20.0
	var top := tr.position.y - 40.0
	return Rect2(x0, top, sw, tr.end.y - top)


## Top edge of the bottom-controls area (canvas y) for a bar of height `bar_h`: beside the
## tray in landscape (the higher of tray top and bar top), stacked above it in portrait.
static func bottom_bar_top(view: Vector2, bar_h: float, safe: Margins = null) -> float:
	var tr := tray_rect(view, safe)
	var slot := side_slot(view, safe)
	if slot.size.x > 0.0:
		return minf(tr.position.y, slot.end.y - bar_h)
	return tr.position.y - 20.0 - bar_h


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

	# Plain Buttons (GameButton is preferred, but never show Godot grey): the pack's
	# SECONDARY (blue, ink label) when the art is in, else the flat navy look.
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
	if UiSkin.has("button_secondary"):
		for st in ["normal", "hover", "pressed", "disabled"]:
			t.set_stylebox(st, "Button", UiSkin.stylebox("button_secondary", st))
		t.set_stylebox("hover_pressed", "Button", UiSkin.stylebox("button_secondary", "pressed"))
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
			t.set_color(c, "Button", UiPalette.INK_LABEL)
	else:
		t.set_color("font_color", "Button", UiPalette.TEXT)
		t.set_color("font_hover_color", "Button", UiPalette.GOLD_BRIGHT)
		t.set_color("font_pressed_color", "Button", UiPalette.GOLD)
		t.set_color("font_disabled_color", "Button", UiPalette.TEXT_MUTED)

	t.set_stylebox("panel", "PanelContainer", panel_box("main"))
	t.set_stylebox("panel", "Panel", panel_box("main"))

	# Sliders: pack Regular track + yellow fill (30 px) and the round handle (44x51 px).
	var track := box(Color(0.02, 0.02, 0.07, 0.8), 12, 2, Color(1, 1, 1, 0.06))
	track.content_margin_top = 10
	track.content_margin_bottom = 10
	var fill := box(UiPalette.GOLD, 12)
	fill.content_margin_top = 10
	fill.content_margin_bottom = 10
	var skin_slider := UiSkin.has("slider", "track")
	t.set_stylebox("slider", "HSlider", UiSkin.stylebox("slider", "track", track) if skin_slider else track)
	var fill_sb: StyleBox = UiSkin.stylebox("slider", "fill", fill) if skin_slider else fill
	t.set_stylebox("grabber_area", "HSlider", fill_sb)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill_sb)
	var grab: Texture2D = UiSkin.texture("slider", "grabber", 51.0) if skin_slider else null
	if grab != null:
		t.set_icon("grabber", "HSlider", grab)
		t.set_icon("grabber_highlight", "HSlider", grab)
		var gd: Texture2D = UiSkin.texture("slider", "grabber_disabled", 51.0)
		t.set_icon("grabber_disabled", "HSlider", gd if gd != null else grab)
	else:
		var knob := _knob_texture(44, false)
		t.set_icon("grabber", "HSlider", knob)
		t.set_icon("grabber_highlight", "HSlider", _knob_texture(44, true))
		t.set_icon("grabber_disabled", "HSlider", knob)
	t.set_icon("tick", "HSlider", ImageTexture.new())
	t.set_constant("center_grabber", "HSlider", 1)

	# CheckBox (48 px yellow boxes) and CheckButton (pack toggle) icons, drawn bare on the
	# panel (they would otherwise inherit the Button faces) with TEXT labels.
	for type in ["CheckBox", "CheckButton"]:
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			t.set_stylebox(st, type, pad(StyleBoxEmpty.new(), 6, 20))
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			t.set_color(c, type, UiPalette.TEXT)
		t.set_color("font_disabled_color", type, UiPalette.TEXT_MUTED)
		t.set_font("font", type, body_font(600))
		t.set_font_size("font_size", type, 24)
	for pair in [["CheckBox", "checkbox", 48.0], ["CheckButton", "toggle", 88.0]]:
		for st in ["checked", "unchecked", "checked_disabled", "unchecked_disabled"]:
			var src: String = st if UiSkin.has(pair[1], st) else st.trim_suffix("_disabled")
			var ic: Texture2D = UiSkin.texture(pair[1], src, pair[2]) if UiSkin.has(pair[1], src) else null
			if ic != null:
				t.set_icon(st, pair[0], ic)

	# Scroll bars: flat, pack-coloured (spec 2.10: slate track, yellow grabber, 12 px);
	# touch platforms drag instead and hide them.
	var touch := OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android")
	var sb := box(Color(UiPalette.SLATE, 0.6), 8)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	var grab_n := box(UiPalette.PACK_YELLOW, 8)
	var grab_h := box(UiPalette.PACK_YELLOW_HOVER, 8)
	for kind in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", kind, StyleBoxEmpty.new() if touch else sb)
		t.set_stylebox("grabber", kind, StyleBoxEmpty.new() if touch else grab_n)
		t.set_stylebox("grabber_highlight", kind, StyleBoxEmpty.new() if touch else grab_h)
		t.set_stylebox("grabber_pressed", kind, StyleBoxEmpty.new() if touch else grab_h)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())

	var tip := callout_box(null)
	tip.content_margin_left = maxf(tip.content_margin_left, 14)
	t.set_stylebox("panel", "TooltipPanel", tip)
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
