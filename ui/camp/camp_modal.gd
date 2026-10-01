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


## Rebuilds the screen for `p` (after every command). Keeps the scroll position.
func show_profile(p: Profile) -> void:
	profile = p
	var keep := _scroll.scroll_vertical
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
