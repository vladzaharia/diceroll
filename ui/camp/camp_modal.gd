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
var _close_btn: GameButton


func _init() -> void:
	super._init()
	max_width = 720.0
	_close_btn = GameButton.round_icon("close", 72)
	_close_btn.kind = GameButton.Kind.SECONDARY
	_close_btn.icon_tint = UiPalette.TEXT
	_close_btn.z_index = 2
	_close_btn.pressed.connect(func() -> void: close())
	add_child(_close_btn)


## Rebuilds the screen for `p` (after every command). Keeps the scroll position.
func show_profile(p: Profile) -> void:
	profile = p
	var keep := _scroll.scroll_vertical
	UiTheme.clear(body)
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


## Tapping the dimmed backdrop closes the screen.
func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _is_open:
		if not panel.get_global_rect().has_point(mb.global_position):
			close()
			accept_event()


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
	var sb := panel.get_theme_stylebox("panel")
	var chrome := sb.content_margin_top + sb.content_margin_bottom + (ribbon.get_combined_minimum_size().y - 26.0 if ribbon.visible else 0.0)
	var natural := _inner.get_combined_minimum_size().y
	_scroll.custom_minimum_size.y = maxf(120.0, minf(natural, avail_h - chrome))
	_frame.reset_size()
	_frame.size.x = w
	_frame.position = Vector2((view.x - w) * 0.5, maxf(top, top + (avail_h - _frame.size.y) * 0.5))
	_frame.pivot_offset = _frame.size * 0.5
	if _close_btn:
		_close_btn.reset_size()
		var cs := _close_btn.get_combined_minimum_size()
		_close_btn.size = cs
		_close_btn.position = Vector2(_frame.position.x + w - cs.x * 0.7, _frame.position.y + ribbon.size.y * 0.2)


func open() -> void:
	_close_btn.visible = true
	await super.open()


func _process(_dt: float) -> void:
	# the close button follows the panel's entrance tween
	if _close_btn and visible:
		_close_btn.modulate.a = _frame.modulate.a
		_close_btn.position.y = _frame.position.y + ribbon.size.y * 0.2


# ---------------------------------------------------------------- shared rows

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
