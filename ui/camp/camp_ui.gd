class_name CampUi
extends RefCounted
## Small builders shared by the Camp screens and the results screen (same look as the rest of
## the UI: navy cards, gold rims, Lilita headings, Fredoka body).

## Sigils: the pack's purple Star Gem (icon_map "sigil"; its own colours, no tint). Without
## the pack the legacy violet star is drawn (sigil_icon()).
const SIGIL_ICON := "sigil"
const SIGIL_COLOR := Color("c79bff")
const CROWN_COLOR := UiPalette.GOLD_BRIGHT


## A card panel; `hi` = the selected / equipped look.
static func card(hi := false, accent: Variant = null) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.tile_box("selected" if hi else "normal", accent))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


## A dimmed card for locked content.
static func locked_card() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.tile_box("locked"))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


## Icon + value chip ("👑 120").
static func amount(icon: String, value: int, color: Color, size := 26) -> HBoxContainer:
	var row := UiTheme.hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(Icons.rect(_icon_id(icon), int(size * 1.15), color))
	row.add_child(UiTheme.label(_num(value), size, UiPalette.TEXT, true, 5))
	return row


static func crowns(value: int, size := 26) -> HBoxContainer:
	return amount("crown", value, CROWN_COLOR, size)


static func sigils(value: int, size := 26) -> HBoxContainer:
	return amount(SIGIL_ICON, value, SIGIL_COLOR, size)


## A purchase button: "<verb>" with the price as sub text and the currency icon.
## cost: {crowns} or {sigils}. Disabled (grey) when the profile can't afford it.
static func buy_button(verb: String, cost: Dictionary, affordable: bool, font := 26) -> GameButton:
	var is_sigil := cost.has("sigils")
	var price := int(cost.get("sigils", cost.get("crowns", 0)))
	var b := GameButton.make("%s  %d" % [verb, price] if verb != "" else str(price), sigil_icon() if is_sigil else "crown",
		GameButton.Kind.PRIMARY if affordable else GameButton.Kind.SECONDARY, font)
	b.icon_tint = (SIGIL_COLOR if is_sigil else UiPalette.TEXT_DARK) if affordable else (SIGIL_COLOR if is_sigil else UiPalette.GOLD)
	b.min_height = 72
	b.pad_x = 18
	b.set_enabled(affordable)
	return b


## Small rounded label chip ("EQUIPPED", "L4", "NEW").
static func chip(text: String, bg: Color, fg: Color = UiPalette.TEXT, size := 17) -> PanelContainer:
	var p := PanelContainer.new()
	# never under 16 canvas px (about 9 pt on a phone): the old 12-15 px chips were unreadable
	var fs := maxi(size, 16)
	var skin := UiTheme.skinned("chip_white")
	p.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.chip_box(bg) if skin else UiTheme.box(bg, 12, 0),
		(12 if skin else 8) if size < 16 else (14 if skin else 10), 2 if size < 16 else 3))
	if skin:
		# pack chips are opaque colour faces: ink or TEXT, whichever reads
		fg = UiPalette.on(Color(bg, 1.0)) if bg.a > 0.6 else fg
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(UiTheme.label(text, fs, fg, false, 0, false, 700))
	return p


## A padlock line: "🔒 Reach lap 5." in muted text.
static func lock_line(text: String, size := 20) -> HBoxContainer:
	var row := UiTheme.hbox(8)
	if Icons.is_mapped("lock"):
		var ic := Icons.rect("lock", int(size * 1.1))
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
	else:
		var lk := LockGlyph.new()
		lk.custom_minimum_size = Vector2(size * 1.1, size * 1.1)
		lk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(lk)
	var l := UiTheme.para(text, size, UiPalette.TEXT_DIM, 600)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row


## A thin labelled progress bar (goals, pet XP, pool budget).
static func bar(cur: float, need: float, color: Color, height := 18.0) -> ProgressPill:
	var b := ProgressPill.new()
	b.fill = color
	b.ratio = clampf(cur / maxf(need, 1.0), 0.0, 1.0)
	b.custom_minimum_size = Vector2(80, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


## Row of level pips (● filled up to `level` of `mx`), with gold markers at trait tiers.
static func pips(level: int, mx: int, color: Color, marks: Array = []) -> LevelPips:
	var p := LevelPips.new()
	p.level = level
	p.max_level = mx
	p.color = color
	p.marks = marks
	p.custom_minimum_size = Vector2(mx * 22, 20)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


static func title_row(icon: String, color: Color, title: String, sub := "", px := 64) -> HBoxContainer:
	var row := UiTheme.hbox(14)
	row.add_child(OptionCard.Medallion.make(icon, px, null if icon.begins_with("biome_") else color, color))
	var col := UiTheme.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	var t := UiTheme.label(title, 30, UiPalette.TEXT, true, 6)
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.custom_minimum_size.x = 60
	col.add_child(t)
	if sub != "":
		var s := UiTheme.label(sub, 19, color.lerp(UiPalette.TEXT_DIM, 0.35), false, 0, false, 700)
		s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		s.custom_minimum_size.x = 60
		col.add_child(s)
	return row


## Icon id for Sigils: the pack gem when mapped, else the legacy star glyph.
static func sigil_icon() -> String:
	return SIGIL_ICON if Icons.is_mapped(SIGIL_ICON) or UiIcons.exists(SIGIL_ICON) else "star"


static func _icon_id(id: String) -> String:
	return sigil_icon() if id == SIGIL_ICON else id


static func _num(n: int) -> String:
	if absi(n) >= 1000:
		return "%d,%03d" % [n / 1000, absi(n) % 1000]
	return str(n)


## A tappable choice tile (trait, mode, class, loadout slot): title + wrapped description.
## States: selected (gold rim), disabled (dimmed, not tappable).
static func tile(title: String, desc: String, selected: bool, enabled := true, icon := "", accent: Color = UiPalette.GOLD) -> Tile:
	var t := Tile.new()
	t.setup(title, desc, selected, enabled, icon, accent)
	return t


class Tile:
	extends PanelContainer
	signal pressed
	var enabled := true
	var selected := false
	var _down := false

	func setup(title: String, desc: String, sel: bool, en: bool, icon: String, accent: Color) -> void:
		selected = sel
		enabled = en
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if en else Control.CURSOR_ARROW
		var sb: StyleBox
		if UiTheme.skinned("panel_card"):
			sb = UiTheme.tile_box("selected" if sel else ("normal" if en else "dim"), accent if en and not sel else null)
			UiTheme.pad(sb, 14, 10)
			sb.content_margin_bottom = 10
		elif sel:
			sb = UiTheme.pad(UiTheme.box(UiPalette.NAVY_3, 20, 3, UiPalette.GOLD_BRIGHT, 12, Color(0.95, 0.7, 0.2, 0.3), Vector2.ZERO), 14, 10)
		elif en:
			sb = UiTheme.pad(UiTheme.box(Color(0.03, 0.03, 0.09, 0.55), 20, 2, Color(accent, 0.3)), 14, 10)
		else:
			sb = UiTheme.pad(UiTheme.box(Color(0.03, 0.03, 0.09, 0.35), 20, 2, Color(1, 1, 1, 0.04)), 14, 10)
		add_theme_stylebox_override("panel", sb)
		# selectable tile (flat, never button-like): hover lightens the face, desktop only
		if en and not sel and UiTheme.skinned("panel_card"):
			var hov := UiTheme.pad(UiTheme.tile_box("hover", accent), 14, 10)
			hov.content_margin_bottom = 10
			mouse_entered.connect(func() -> void: add_theme_stylebox_override("panel", hov))
			mouse_exited.connect(func() -> void: add_theme_stylebox_override("panel", sb))
		var col := UiTheme.vbox(2)
		add_child(col)
		var row := UiTheme.hbox(8)
		col.add_child(row)
		if icon != "":
			row.add_child(Icons.rect(CampUi._icon_id(icon), 26, accent if en else UiPalette.TEXT_MUTED))
		var tl := UiTheme.label(title, 23, (UiPalette.GOLD_BRIGHT if sel else UiPalette.TEXT) if en else UiPalette.TEXT_MUTED, true, 4)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.custom_minimum_size.x = 40
		row.add_child(tl)
		if sel:
			row.add_child(Icons.rect("check", 24, UiPalette.GOLD_BRIGHT))
		if desc != "":
			var d := UiTheme.para(desc, 18, UiPalette.TEXT_DIM if en else UiPalette.TEXT_MUTED, 500)
			col.add_child(d)

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_down = true
			accept_event()
		elif _down:
			_down = false
			accept_event()
			if enabled and get_global_rect().has_point(mb.global_position):
				UiTheme.sfx("click")
				UiTheme.pop(self, 1.04, 0.18)
				pressed.emit()


## A rounded progress track with a glossy fill.
class ProgressPill:
	extends Control
	var ratio := 0.0:
		set(v):
			ratio = clampf(v, 0.0, 1.0)
			queue_redraw()
	var fill: Color = UiPalette.GOLD

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Pack bar kind for the fill ("xp", "mastery", ...); "" = from the fill colour.
	var kind := ""

	func _draw() -> void:
		var k := kind
		if k == "":
			k = "xp" if fill == UiPalette.XP else ("hp" if fill == UiPalette.HP else "mastery")
		var bx := UiTheme.bar_boxes(k)
		if bool(bx.skinned):
			draw_style_box(bx.bg, Rect2(Vector2.ZERO, size))
			if ratio > 0.0:
				var fb: StyleBox = bx.fill
				if k == "mastery" and fill != UiPalette.GOLD and UiSkin.has("bar_mastery", "fill"):
					# any other accent: the fill art stays, tinted towards the colour
					fb = UiSkin.stylebox("bar_mastery", "fill", {"saturation": 0.0, "modulate": Color(fill.lightened(0.25), 1.0)})
				draw_style_box(fb, Rect2(0, 0, maxf(size.y, size.x * ratio), size.y))
			return
		var r := int(size.y * 0.5)
		draw_style_box(UiTheme.box(Color(0.02, 0.02, 0.07, 0.85), r, 2, Color(1, 1, 1, 0.06)), Rect2(Vector2.ZERO, size))
		if ratio <= 0.0:
			return
		var w := maxf(size.y, (size.x - 4.0) * ratio)
		var fr := Rect2(2, 2, w, size.y - 4.0)
		draw_style_box(UiTheme.box(fill, r - 2), fr)
		draw_style_box(UiTheme.box(Color(1, 1, 1, 0.22), r - 2), Rect2(fr.position + Vector2(3, 1), Vector2(maxf(0.0, fr.size.x - 6.0), fr.size.y * 0.38)))


class LevelPips:
	extends Control
	var level := 0
	var max_level := 8
	var color: Color = UiPalette.GOLD
	## Levels drawn as diamonds (trait tiers).
	var marks: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var step := size.x / float(max_level)
		var cy := size.y * 0.5
		var rad := minf(step * 0.34, size.y * 0.42)
		if Icons.is_mapped("star"):
			# spec 2.12: gold star pips (filled), greyed stars (empty), the gold tier star at
			# trait tiers; each star fits its slot, so nothing spills.
			var px := minf(step * 0.92, size.y)
			for i in max_level:
				var on := i < level
				var id := "tier_3" if marks.has(i + 1) and Icons.is_mapped("tier_3") else "star"
				var k := 1.0 if marks.has(i + 1) else 0.86
				var sz := px * k
				var t := Icons.texture(id, int(ceil(sz)), null if on else {"saturation": 0.0})
				var r := Rect2(Vector2(step * (i + 0.5), cy) - Vector2(sz, sz) * 0.5, Vector2(sz, sz))
				draw_texture_rect(t, r, false, Color.WHITE if on else Color(1, 1, 1, 0.35))
			return
		for i in max_level:
			var c := Vector2(step * (i + 0.5), cy)
			var on := i < level
			var col := color if on else Color(1, 1, 1, 0.1)
			if marks.has(i + 1):
				var d := rad * 1.25
				var pts := PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)])
				draw_colored_polygon(pts, UiPalette.OUTLINE)
				var d2 := d - 2.0
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d2), c + Vector2(d2, 0), c + Vector2(0, d2), c + Vector2(-d2, 0)]),
					UiPalette.GOLD_BRIGHT if on else Color(0.95, 0.72, 0.29, 0.25))
			else:
				draw_circle(c, rad, UiPalette.OUTLINE)
				draw_circle(c, rad - 2.0, col)
				if on:
					draw_circle(c - Vector2(0, rad * 0.3), rad * 0.4, Color(1, 1, 1, 0.3))


## A small drawn padlock.
class LockGlyph:
	extends Control
	var color: Color = UiPalette.TEXT_MUTED

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := minf(size.x, size.y)
		var o := (size - Vector2(s, s)) * 0.5
		var body := Rect2(o + Vector2(s * 0.14, s * 0.44), Vector2(s * 0.72, s * 0.52))
		draw_arc(o + Vector2(s * 0.5, s * 0.44), s * 0.24, PI, TAU, 12, color, s * 0.12, true)
		draw_style_box(UiTheme.box(color, int(s * 0.12)), body)
		draw_circle(body.get_center() - Vector2(0, s * 0.03), s * 0.07, UiPalette.INK)
