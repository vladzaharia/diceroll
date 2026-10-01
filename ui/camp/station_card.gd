class_name StationCard
extends PanelContainer
## The Camp stations' shared card (docs/design/2026-10-01-camp-stations.md): every pack, pet,
## minigame, skin and rank card is built from the same five rows, so the stations read as one
## family and every card of a station is the same height:
##
##   HEAD      medallion · name (1 line) + short description (`desc_lines`) · state / action
##   PILLS     key stats as icon pills on one line (pills that don't fit drop off the end)
##   CONTENTS  the preview (a Carousel, a meter...) in a fixed-height slot
##   FOOTER    one status line (lock hint, progress, "In your drops") + an optional action
##
## Row heights come from a Spec shared by the station (rows never grow with their content:
## text is capped at its line budget, carousels page instead of wrapping), so equal specs give
## equal cards. The one priced action sits top-right (UNLOCK / BUY) or in the footer (LEVEL UP).
##
##   var spec := StationCard.Spec.new(); spec.contents_h = 170.0
##   var c := StationCard.make(spec, "pack_storm", ACCENT, "Storm", "Rerolls that strike back.")
##   c.add_pill("rune_thunder", "1 RUNE"); c.set_action(btn); c.set_contents(carousel)
##   c.set_status("Reach lap 10 in one run.", "lock")

## Text sizes (canvas px; the 16 px floor holds everywhere).
const TITLE_PX := 26
const DESC_PX := 18
const STATUS_PX := 18
const PILL_PX := 16
## Medallion size in the head.
const MEDAL_PX := 64

## Per-station row heights (one Spec per station = one card height).
class Spec:
	extends RefCounted
	var desc_lines := 2
	## Pills row height (0 = no pills row).
	var pills_h := 34.0
	## The contents slot (0 = no contents row).
	var contents_h := 0.0
	## Footer: status line and an optional button (88 = a priced button fits).
	var footer_h := 48.0
	var footer_lines := 2
	var pad := 16.0
	var gap := 12

	func head_h() -> float:
		# the head fits a priced button (88 px hit rect) beside the text
		return maxf(UiTheme.TOUCH, StationCard.line_h(StationCard.TITLE_PX, true)
			+ StationCard.line_h(StationCard.DESC_PX) * desc_lines + 2.0)


var spec: Spec
var accent: Color = UiPalette.GOLD
var locked := false
var head: HBoxContainer
var text_col: VBoxContainer
var title_label: Label
var desc_label: Label
## Right side of the head: state chip and / or the action.
var side: VBoxContainer
var pills: _PillRow
var contents: Control
var footer: HBoxContainer
var status_label: Label
var status_box: HBoxContainer
var _col: VBoxContainer


## A card for one thing at a station. `state`: "normal" | "equipped" (the yellow rim, the
## thing in use) | "locked" (dimmed card, greyed medallion).
static func make(p_spec: Spec, icon: String, p_accent: Color, title: String, desc := "", state := "normal") -> StationCard:
	var c := StationCard.new()
	c.spec = p_spec
	c.accent = p_accent
	c.locked = state == "locked"
	c._build(icon, title, desc, state)
	return c


## One line of a label at `px` (the font's height plus LabelSettings' default line spacing),
## so a label of N lines is exactly N × line_h tall.
static func line_h(px: int, display := false) -> float:
	var f: Font = UiTheme.display_font() if display else UiTheme.body_font(600)
	return ceilf((f.get_height(px) if f else px * 1.3) + 3.0)


func _build(icon: String, title: String, desc: String, state: String) -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := UiTheme.tile_box("worn" if state == "equipped" else ("locked" if locked else "normal"),
		accent if state == "normal" else null)
	sb.content_margin_left = spec.pad
	sb.content_margin_right = spec.pad
	sb.content_margin_top = spec.pad
	sb.content_margin_bottom = spec.pad
	add_theme_stylebox_override("panel", sb)
	_col = UiTheme.vbox(spec.gap)
	_col.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_col)
	# HEAD
	head = UiTheme.hbox(14)
	head.custom_minimum_size.y = spec.head_h()
	head.mouse_filter = Control.MOUSE_FILTER_PASS
	_col.add_child(head)
	var m := CampArt.medal(icon, MEDAL_PX, accent, locked, accent)
	m.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(m)
	text_col = UiTheme.vbox(0)
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(text_col)
	title_label = UiTheme.label(title, TITLE_PX, UiPalette.TEXT_DIM if locked else UiPalette.TEXT, true, 6)
	title_label.name = "Title"
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.custom_minimum_size.x = 60
	text_col.add_child(title_label)
	desc_label = _capped(desc, DESC_PX, UiPalette.TEXT_MUTED if locked else UiPalette.TEXT_DIM, spec.desc_lines, 500)
	desc_label.name = "Desc"
	text_col.add_child(desc_label)
	side = UiTheme.vbox(6)
	side.alignment = BoxContainer.ALIGNMENT_BEGIN
	side.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	side.mouse_filter = Control.MOUSE_FILTER_PASS
	head.add_child(side)
	# PILLS
	if spec.pills_h > 0.0:
		pills = _PillRow.new()
		pills.custom_minimum_size.y = spec.pills_h
		_col.add_child(pills)
	# CONTENTS
	if spec.contents_h > 0.0:
		var slot := UiTheme.vbox(0)
		slot.name = "Contents"
		slot.custom_minimum_size.y = spec.contents_h
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		_col.add_child(slot)
		contents = slot
	# FOOTER
	if spec.footer_h > 0.0:
		footer = UiTheme.hbox(10)
		footer.custom_minimum_size.y = spec.footer_h
		footer.mouse_filter = Control.MOUSE_FILTER_PASS
		_col.add_child(footer)
		# the status line always comes first (left); carousel arrows and actions follow
		status_box = UiTheme.hbox(8)
		status_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		footer.add_child(status_box)


## A wrapped label that never takes more than `lines` lines (the rest is trimmed with an
## ellipsis) and always takes exactly that height, so the row height is fixed.
static func _capped(text: String, px: int, color: Color, lines: int, weight := 600) -> Label:
	var l := UiTheme.para(text, px, color, weight)
	l.max_lines_visible = lines
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.custom_minimum_size.y = line_h(px) * lines
	l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return l


## A key-stat pill: icon + UPPERCASE text on a flat chip.
func add_pill(icon: String, text: String, fam: Variant = "grey") -> Control:
	var p := CampArt.chip(text, fam, icon, PILL_PX)
	if locked and String(fam) == "grey":
		p.modulate = Color(1, 1, 1, 0.75)
	pills.add_child(p)
	return p


## The head's right side: a state chip ("OWNED", "EQUIPPED"...).
func set_state(text: String, fam: Variant = "green", icon := "") -> Control:
	var c := CampArt.chip(text, fam, icon, 16)
	c.size_flags_horizontal = Control.SIZE_SHRINK_END
	side.add_child(c)
	return c


## The head's right side: the card's action (UNLOCK, BUY, EQUIP...).
func set_action(b: Control) -> void:
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	side.add_child(b)


## Fills the contents slot.
func set_contents(c: Control) -> void:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_child(c)


## The footer's status line with a leading icon ("lock", "check", "pet_xp"...).
func set_status(text: String, icon := "", color: Color = UiPalette.TEXT_DIM) -> Label:
	if icon != "":
		var ic := CampArt.icon(icon, 24, color)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		status_box.add_child(ic)
	status_label = _capped(text, STATUS_PX, color, spec.footer_lines, 600)
	status_label.name = "Status"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_box.add_child(status_label)
	return status_label


## Puts a Carousel in the contents slot and its indicator row (count, arrows, dots) at the
## right of the footer, so the strip gets the slot's full height.
func set_carousel(car: Carousel) -> void:
	set_contents(car)
	var nav := car.take_nav()
	nav.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(nav)


## Anything else in the footer (a progress bar, LEVEL UP, REMOVE), after the status line.
func add_footer(c: Control) -> void:
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(c)


## Makes the name / description tappable: `cb(anchor)` shows the full text (a tooltip), for
## descriptions longer than their line budget.
func on_info(cb: Callable) -> void:
	text_col.mouse_filter = Control.MOUSE_FILTER_PASS
	text_col.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var at := [Vector2.ZERO]
	text_col.gui_input.connect(func(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			at[0] = mb.global_position
		elif mb.global_position.distance_to(at[0]) < Carousel.SWIPE_START:
			cb.call(text_col))


## A flat rule tile (a pet's FILLS / FIRES / L5, a minigame's BRONZE / SILVER / GOLD): a small
## header (icon + label, optionally a value) and the rule in `lines` lines. Lit = reached /
## active; dim otherwise. Emits `pressed` (show the full text).
static func rule_tile(icon: String, head_text: String, head_color: Color, text: String, lit := true, lines := 2,
		value: Control = null) -> RuleTile:
	var t := RuleTile.new()
	t.build(icon, head_text, head_color, text, lit, lines, value)
	return t


## [actual, budget] min height of each row (tests: no row ever grows past its budget).
func row_heights() -> Array:
	var out: Array = []
	var budgets := [spec.head_h(), spec.pills_h, spec.contents_h, spec.footer_h]
	var rows := [head, pills, contents, footer]
	for i in rows.size():
		if rows[i] != null:
			out.append([(rows[i] as Control).get_combined_minimum_size().y, float(budgets[i]), String((rows[i] as Control).name)])
	return out


## The card's fixed height for its spec (tests: every card of a station has this height).
func spec_height() -> float:
	var h := spec.pad * 2.0 + spec.head_h()
	var rows := 1
	if spec.pills_h > 0.0:
		h += spec.pills_h
		rows += 1
	if spec.contents_h > 0.0:
		h += spec.contents_h
		rows += 1
	if spec.footer_h > 0.0:
		h += spec.footer_h
		rows += 1
	return h + spec.gap * (rows - 1)


## One line of pills: lays them out left to right and hides the ones that don't fit (the row
## never wraps, so the card height never changes; the most important pill comes first).
class _PillRow:
	extends Container
	const SEP := 8.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL

	func _get_minimum_size() -> Vector2:
		var h := 0.0
		for c in get_children():
			if c is Control:
				h = maxf(h, (c as Control).get_combined_minimum_size().y)
		return Vector2(0, h)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_SORT_CHILDREN:
			var x := 0.0
			for c in get_children():
				var ctl := c as Control
				if ctl == null:
					continue
				var s := ctl.get_combined_minimum_size()
				var fits := x + s.x <= size.x + 0.5
				ctl.visible = fits
				if fits:
					fit_child_in_rect(ctl, Rect2(Vector2(x, (size.y - s.y) * 0.5), s))
					x += s.x + SEP


## See rule_tile().
class RuleTile:
	extends PanelContainer
	signal pressed
	var _at := Vector2.ZERO
	var _down := false

	func build(icon: String, head_text: String, head_color: Color, text: String, lit: bool, lines: int, value: Control) -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb := UiTheme.tile_box("normal" if lit else "dim")
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		add_theme_stylebox_override("panel", sb)
		var col := UiTheme.vbox(2)
		add_child(col)
		var head := UiTheme.hbox(6)
		col.add_child(head)
		if icon != "":
			var ic := CampArt.icon(icon, 22, head_color, not lit)
			head.add_child(ic)
		var hl := UiTheme.label(head_text, 16, head_color if lit else UiPalette.TEXT_MUTED, false, 0, false, 800)
		hl.name = "Head"
		head.add_child(hl)
		if value != null:
			head.add_child(value)
		var body := StationCard._capped(text, 16, UiPalette.TEXT if lit else UiPalette.TEXT_MUTED, lines, 600)
		body.name = "Rule"
		col.add_child(body)

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_down = true
			_at = mb.global_position
		elif _down:
			_down = false
			if mb.global_position.distance_to(_at) < Carousel.SWIPE_START:
				if is_inside_tree():
					accept_event()
				UiTheme.sfx("click")
				pressed.emit()
