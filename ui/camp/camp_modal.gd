class_name CampModal
extends UiModal
## Base for the Camp building screens (Armory, Dice Workshop, Pet Den, Arcade, Run Setup):
## the shared modal look, a close button, and a top inset so the Crowns / Sigils header of the
## CampScreen stays visible above the panel. Subclasses fill `body` in rebuild(profile).
## Commands are emitted as Camp.apply() arrays; the GameController applies them, saves the
## profile and calls show_profile() again.

signal camp_command(cmd: Array)
## Asks the CampScreen to open another station (e.g. Run Setup -> Pet Den).
signal open_station(id: String)

## Space kept free above the panel for the currency header.
var top_inset := 96.0
var profile: Profile
## Purchases ready at this station (set by the CampScreen): shown as a line at the top of the
## screen (the station tag only carries the badge).
var ready_count := 0


func _init() -> void:
	super._init()
	max_width = 720.0
	# one exit: UiModal's corner close button, Esc and the backdrop
	dismissible = true
	# an item tip follows nothing: scrolling or closing puts it away
	_scroll.get_v_scroll_bar().value_changed.connect(func(_v: float) -> void: hide_tip())
	closed.connect(hide_tip)


## Rebuilds the screen for `p` (after every command). Keeps the scroll position.
func show_profile(p: Profile) -> void:
	profile = p
	var keep := _scroll.scroll_vertical
	hide_tip()
	UiTheme.clear(body)
	if ready_count > 0:
		body.add_child(ready_line(ready_count))
	rebuild(p)
	relayout()
	if is_inside_tree():
		await get_tree().process_frame
		await get_tree().process_frame
		_scroll.scroll_vertical = keep


## Override: fill `body` for the profile.
func rebuild(_p: Profile) -> void:
	pass


func cmd(c: Array) -> void:
	camp_command.emit(c)


# ---------------------------------------------------------------- item tips (UiTooltip)

var _tip: PanelContainer
var _tip_anchor: Control


## Shows the shared tooltip (UiTooltip) for a tapped tile, under it (above when there is no
## room). Tapping the same tile again, any other tap, a page turn or a rebuild hides it.
func show_tip(anchor: Control, title_text: String, tag: String, text: String, accent: Variant = null, icon := "") -> void:
	if _tip != null and _tip.visible and _tip_anchor == anchor:
		hide_tip()
		return
	if _tip == null:
		_tip = PanelContainer.new()
		_tip.name = "StationTip"
		_tip.z_index = 20
		# a floating callout over the modal (like the plaque): it may cross the frame edge;
		# UiTooltip.place keeps it inside the safe area, which the audit still checks
		_tip.set_meta(UiAudit.ALLOW, true)
		add_child(_tip)
	var opts := {"max_w": minf(UiTooltip.MAX_W, size.x - 90.0) if size.x > 0.0 else UiTooltip.MAX_W}
	if icon != "" and Icons.exists(icon):
		opts["icon"] = icon
	UiTooltip.fill(_tip, title_text, tag, text, accent, opts)
	_tip.visible = true
	_tip_anchor = anchor
	UiTooltip.place(_tip, self, anchor.get_global_rect())


func hide_tip() -> void:
	if _tip != null:
		_tip.visible = false
	_tip_anchor = null


func tip_visible() -> bool:
	return _tip != null and _tip.visible


func _input(event: InputEvent) -> void:
	# any press outside the tip's tile closes the tip (the tile's own tap toggles it)
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and tip_visible():
		var on_anchor := _tip_anchor != null and is_instance_valid(_tip_anchor) and _tip_anchor.get_global_rect().has_point(mb.global_position)
		if not on_anchor:
			hide_tip()
	super._input(event)


func _layout() -> void:
	if _frame == null:
		return
	var view := size
	if view.x <= 0.0:
		return
	var safe := UiTheme.safe_margins(self)
	var w := minf(max_width, view.x - safe.left - safe.right)
	_frame.custom_minimum_size.x = w
	_frame.size = Vector2(w, 0)
	var top := safe.top + top_inset
	var avail_h := view.y - top - safe.bottom
	_apply_scale(view)
	_apply_spacing()
	_fit_plaque(w)
	var chrome := chrome_height()
	var natural := _inner.get_combined_minimum_size().y
	_scroll.custom_minimum_size.y = maxf(120.0, minf(natural, avail_h - chrome))
	_frame.reset_size()
	_frame.size.x = w
	_frame.position = Vector2((view.x - w) * 0.5, maxf(top, top + (avail_h - _frame.size.y) * 0.5))
	_frame.pivot_offset = _frame.size * 0.5
	_place_close()


# ---------------------------------------------------------------- shared rows

## Panel width of a station: one column of cards (portrait), two on landscape canvases.
const ONE_COL_W := 720.0
const TWO_COL_W := 1180.0


## Landscape canvases (wider than 1.25 × tall, the Armory's rule): stations lay their cards
## out in two columns.
func is_wide() -> bool:
	var v := get_viewport_rect().size if is_inside_tree() else Vector2(720, 1280)
	return v.x > v.y * 1.25


## Sets the panel width for this canvas (call at the top of rebuild()).
func fit_columns() -> void:
	max_width = TWO_COL_W if is_wide() else ONE_COL_W


## A grid for station cards: two columns on wide canvases, one otherwise. Cards of a station
## share one height, so the rows line up.
func card_grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2 if is_wide() else 1
	g.add_theme_constant_override("h_separation", UiModal.GAP_ITEM)
	g.add_theme_constant_override("v_separation", UiModal.GAP_ITEM)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.mouse_filter = Control.MOUSE_FILTER_PASS
	return g

## "3 ready to buy" under the title plaque: a green chip, centred.
static func ready_line(n: int) -> Control:
	var row := UiTheme.hbox(0)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.name = "ReadyLine"
	row.add_child(CampArt.chip("%d READY TO BUY" % n, "green", "", 18))
	return row


## Section heading inside a Camp screen.
static func heading(text: String, sub := "") -> VBoxContainer:
	var col := UiTheme.vbox(2)
	var l := UiModal.section_label(text)
	col.add_child(l)
	if sub != "":
		var s := UiTheme.para(sub, 19, UiPalette.TEXT_MUTED, 500)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(s)
	return col
