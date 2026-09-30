class_name UiModal
extends Control
## Base for modal dialogs: dimmed scrim, centred panel (the Nailed wood frame over navy, max
## width 680) with a title plaque that overlaps the frame top by half its height, animated
## in / out. Subclasses fill `body` in _build() and call refresh().
##
##   var m := DraftModal.new(); add_child(m); m.refresh(flow); m.open()
##
## One exit (spec 3.2): a `dismissible` modal gets the round red close button on the frame's
## top-right corner, and Esc / a tap on the dimmed backdrop do the same (dismiss()). Forced
## modals (drafts, events, results) leave it false: no close, no Esc, no backdrop. Confirm
## dialogs set `cancel_action` (Esc presses it) and keep their explicit cancel button.
## `primary_action` is pressed by Enter. Keys go to the top-most open modal only.

signal opened
signal closed
## The player dismissed the modal (close button, Esc or backdrop), just before it closes.
signal dismissed

var title := ""
var ribbon_color: Color = UiPalette.GOLD
var max_width := UiTheme.MODAL_MAX_W
## Content column inside the panel.
var body: VBoxContainer
var panel: PanelContainer
var ribbon: Ribbon
var scrim: ColorRect
## The header close button (round, red, on the frame's top-right corner); shown only while
## `dismissible`. Its tooltip is `close_tooltip` (+ the Esc key on desktop).
var close_button: GameButton
## Show the close button and let Esc / the backdrop dismiss (see header).
var dismissible := false:
	set(v):
		dismissible = v
		if close_button:
			close_button.visible = v
		relayout()
## Tapping the dimmed backdrop dismisses too (when `dismissible`).
var backdrop_dismiss := true
## Tooltip of the close button ("Close", "Leave shop", "Skip the forge").
var close_tooltip := "Close":
	set(v):
		close_tooltip = v
		if close_button:
			close_button.tooltip_text = v
## Pressed by Enter / keypad Enter while this modal is on top (TAKE, BUY, CONFIRM...).
var primary_action: BaseButton
## Pressed by Esc while this modal is on top and not dismissible (confirm dialogs: CANCEL).
var cancel_action: BaseButton
var _frame: VBoxContainer
## Panel scale when its content is wider / taller than the screen allows (1 = natural size).
var _fit := 1.0
## Narrowest layout width; narrower screens shrink the panel instead of squeezing it.
const MIN_W := 620.0
## Canvas size (both sides) from which the frame and plaque use their desktop scale.
const LARGE_CANVAS := 1000.0
## Close button: drawn size on phone / desktop canvases, and its gap to the plaque.
const CLOSE_PX := 64.0
const CLOSE_PX_LG := 72.0
const CLOSE_GAP := 12.0
var _center: Control
var _scroll: ScrollContainer
var _inner: MarginContainer
var _is_open := false
var _close_tween: Tween
var _relayout_queued := false
var _large := false
## Open modals, bottom first (keys go to the last one).
static var _stack: Array[UiModal] = []


func _init() -> void:
	theme = UiTheme.get_theme()
	UiTheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	scrim = ColorRect.new()
	scrim.color = UiPalette.SCRIM
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiTheme.full_rect(scrim))
	_center = Control.new()
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiTheme.full_rect(_center))
	_frame = UiTheme.vbox(-36)
	_center.add_child(_frame)
	ribbon = Ribbon.make(title, 38, ribbon_color)
	ribbon.z_index = 1
	# the title plaque straddles the panel's top edge on purpose (UiAudit frame check)
	ribbon.set_meta(UiAudit.ALLOW, true)
	_frame.add_child(ribbon)
	_frame.add_theme_constant_override("separation", -int(header_overlap()))
	panel = UiTheme.panel("main")
	_frame.add_child(panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(_scroll)
	body = UiTheme.vbox(18)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inner = UiTheme.margin(body, 0, 22, 0, 0)
	_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_inner)
	_inner.minimum_size_changed.connect(relayout)
	close_button = GameButton.round_icon("close", CLOSE_PX)
	close_button.round_family = "red"
	close_button.shortcut_hint = "key_esc"
	close_button.tooltip_text = close_tooltip
	close_button.z_index = 2
	close_button.visible = false
	# sits on the frame's corner on purpose; still checked against the safe area
	close_button.set_meta(UiAudit.ALLOW, true)
	close_button.pressed.connect(func() -> void: _request_dismiss())
	add_child(close_button)
	resized.connect(_layout)
	visible = false
	_build()


func _ready() -> void:
	_layout()


## Override: create the static widgets inside `body`.
func _build() -> void:
	pass


## Override to change what a dismissal does (shop: leave; forge: skip). Default: close().
func dismiss() -> void:
	close()


func set_title(t: String, color: Variant = null) -> void:
	title = t
	ribbon.text = t
	if color is Color:
		ribbon.color = color
		ribbon.family = ""
	elif color is String or color is StringName:
		ribbon.family = String(color)
	ribbon.visible = t != ""
	ribbon.queue_redraw()
	relayout()


## Plaque height (72 px phone / 84 px desktop canvases).
func plaque_height() -> float:
	return Ribbon.PLAQUE_H_LG if _large else Ribbon.PLAQUE_H


## How far the plaque overlaps the frame top: half its height (spec 2.4).
func header_overlap() -> float:
	return round(plaque_height() * 0.5) if ribbon == null or ribbon.skinned() else 26.0


## Vertical space the panel adds around its scroll area: frame margins + the plaque part
## above the frame. Subclasses with their own _layout use this instead of a constant.
func chrome_height() -> float:
	var sb := panel.get_theme_stylebox("panel")
	var head := (ribbon.get_combined_minimum_size().y - header_overlap()) if ribbon.visible else 0.0
	return sb.content_margin_top + sb.content_margin_bottom + head


func open() -> void:
	# reopened while closing (e.g. two drafts back to back): cancel the close
	if _close_tween and _close_tween.is_valid():
		_close_tween.kill()
	visible = true
	_is_open = true
	_push()
	_layout()
	scrim.modulate.a = 0.0
	_frame.modulate.a = 0.0
	_frame.scale = Vector2(0.86, 0.86) * _fit
	await get_tree().process_frame
	_layout()
	_frame.pivot_offset = _frame.size * 0.5
	var target := _frame.position
	_frame.position.y += 70.0
	var t := create_tween().set_parallel(true)
	t.tween_property(scrim, "modulate:a", 1.0, 0.18)
	t.tween_property(_frame, "modulate:a", 1.0, 0.14)
	t.tween_property(_frame, "position", target, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_frame, "scale", Vector2.ONE * _fit, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	UiTheme.sfx("open")
	opened.emit()


## Shows instantly (no tween) — used by screenshots and when restoring state.
func show_now() -> void:
	visible = true
	_is_open = true
	_push()
	scrim.modulate.a = 1.0
	_frame.modulate.a = 1.0
	_layout()
	_frame.scale = Vector2.ONE * _fit
	_place_close()


func close(free_after := false) -> void:
	if not _is_open:
		return
	_is_open = false
	_stack.erase(self)
	if not is_inside_tree():
		visible = false
		closed.emit()
		return
	_frame.pivot_offset = _frame.size * 0.5
	var t := create_tween().set_parallel(true)
	_close_tween = t
	t.tween_property(scrim, "modulate:a", 0.0, 0.16)
	t.tween_property(_frame, "modulate:a", 0.0, 0.14)
	t.tween_property(_frame, "scale", Vector2(0.92, 0.92) * _fit, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	if _is_open:
		return
	visible = false
	closed.emit()
	if free_after:
		queue_free()


func is_open() -> bool:
	return _is_open


## True when this is the top-most open modal (it gets Esc / Enter).
func is_top() -> bool:
	for i in range(_stack.size() - 1, -1, -1):
		var m := _stack[i]
		if is_instance_valid(m) and m._is_open and (m.is_visible_in_tree() if m.is_inside_tree() else m.visible):
			return m == self
	return false


func _push() -> void:
	_stack.erase(self)
	_stack.append(self)


func _exit_tree() -> void:
	_stack.erase(self)


func _request_dismiss() -> void:
	if not dismissible or not _is_open:
		return
	dismissed.emit()
	dismiss()


# ---------------------------------------------------------------- input (one exit)

func _input(event: InputEvent) -> void:
	if not _is_open or not visible or not is_top():
		return
	if _is_back(event):
		if dismissible:
			_handled()
			_request_dismiss()
		elif cancel_action != null and _usable(cancel_action):
			_handled()
			cancel_action.emit_signal("pressed")
	elif _is_confirm(event):
		if primary_action != null and _usable(primary_action):
			_handled()
			primary_action.emit_signal("pressed")


## Esc / the rebindable "menu_back" action (defined by the boot code when present).
static func _is_back(e: InputEvent) -> bool:
	if InputMap.has_action("menu_back"):
		return e.is_action_pressed("menu_back", false, true)
	var k := e as InputEventKey
	return k != null and k.pressed and not k.echo and k.keycode == KEY_ESCAPE


## Enter / keypad Enter / the rebindable "menu_confirm" action.
static func _is_confirm(e: InputEvent) -> bool:
	if InputMap.has_action("menu_confirm"):
		return e.is_action_pressed("menu_confirm", false, true)
	var k := e as InputEventKey
	return k != null and k.pressed and not k.echo and (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER)


static func _usable(b: BaseButton) -> bool:
	return is_instance_valid(b) and (b.is_visible_in_tree() if b.is_inside_tree() else b.visible) and not b.disabled


func _handled() -> void:
	if is_inside_tree():
		get_viewport().set_input_as_handled()


## Tapping the dimmed backdrop (outside the panel) dismisses a dismissible modal.
func _gui_input(event: InputEvent) -> void:
	if not dismissible or not backdrop_dismiss or not _is_open:
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		if not panel.get_global_rect().has_point(mb.global_position) \
				and not ribbon.get_global_rect().has_point(mb.global_position):
			accept_event()
			_request_dismiss()


# ---------------------------------------------------------------- layout

func _layout() -> void:
	if _frame == null:
		return
	var view := size
	if view.x <= 0.0:
		return
	_apply_scale(view)
	var safe := UiTheme.safe_margins(self)
	var avail_w := view.x - safe.left - safe.right
	var w := minf(max_width, avail_w)
	# never lay out narrower than MIN_W (cards would wrap word by word): shrink instead
	var lw := maxf(w, minf(MIN_W, max_width))
	_frame.custom_minimum_size.x = lw
	_frame.size = Vector2(lw, 0)
	_fit_plaque(lw)
	var avail_h := view.y - safe.top - safe.bottom - _close_headroom()
	var chrome := chrome_height()
	var natural := _inner.get_combined_minimum_size().y
	# a little too tall (short landscape, big UI size): shrink up to ~20% when that avoids
	# scrolling; content that would scroll anyway scrolls at full size instead of shrinking too
	var kh := avail_h / maxf(natural + chrome, 1.0)
	var k := minf(w / lw, kh if kh >= 0.8 and kh < 1.0 else 1.0)
	_scroll.custom_minimum_size.y = minf(natural, avail_h / k - chrome)
	_update_gutter(natural > _scroll.custom_minimum_size.y + 0.5)
	_frame.reset_size()
	_frame.size.x = lw
	# content wider than the screen allows: shrink the whole panel
	k = minf(k, avail_w / maxf(_frame.size.x, 1.0))
	var was := _fit
	_fit = clampf(k, 0.6, 1.0)
	if not is_equal_approx(was, _fit) and is_equal_approx(_frame.scale.x, was):
		_frame.scale = Vector2.ONE * _fit
	var fh := _frame.size.y * _fit
	var top := safe.top + _close_headroom()
	var c := Vector2(view.x * 0.5, maxf(top, (view.y - fh) * 0.5) + fh * 0.5)
	_frame.pivot_offset = _frame.size * 0.5
	_frame.position = c - _frame.size * 0.5
	_place_close()


## Frame + plaque scale by canvas size (phone 0.75 frame / 72 px plaque; >= 1000 both ways:
## 1.0 frame / 84 px plaque).
func _apply_scale(view: Vector2) -> void:
	var lg := view.x >= LARGE_CANVAS and view.y >= LARGE_CANVAS
	if lg == _large and panel.has_theme_stylebox_override("panel"):
		return
	_large = lg
	ribbon.large = lg
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box("main_lg" if lg else "main"))
	_frame.add_theme_constant_override("separation", -int(header_overlap()))
	close_button.min_height = CLOSE_PX_LG if lg else CLOSE_PX
	close_button.icon_px = int(close_button.min_height * 0.46)
	close_button.icon_name = "close"


## The plaque never reaches the close button: at most the panel width minus the corner
## button on both sides (it stays centred).
func _fit_plaque(frame_w: float) -> void:
	var cb := (close_button.min_height + CLOSE_GAP) * 2.0 + 24.0 if dismissible else 48.0
	ribbon.max_width = maxf(160.0, frame_w - cb)


## Extra room above the frame when a dismissible modal has no plaque (the close button
## pokes above the frame top and must stay inside the safe area).
func _close_headroom() -> float:
	if not dismissible or ribbon.visible:
		return 0.0
	return maxf(0.0, UiTheme.TOUCH * 0.5 - 10.0)


## Places the close button on the frame's top-right corner: the drawn circle's centre 10 px
## inside the corner, the 88 px hit rect clamped inside the safe area (spec 2.4).
func _place_close() -> void:
	if close_button == null:
		return
	close_button.visible = dismissible and _is_open
	if not close_button.visible or not panel.is_inside_tree():
		return
	close_button.reset_size()
	var cs := close_button.get_combined_minimum_size()
	close_button.size = cs
	var k := _frame.scale.x
	close_button.scale = Vector2.ONE * k
	close_button.pivot_offset = Vector2.ZERO
	var pr := panel.get_global_rect()
	var inv := get_global_transform().affine_inverse()
	var p0 := inv * pr.position
	var p1 := inv * pr.end
	var centre := Vector2(p1.x - 10.0 * k, p0.y + 10.0 * k)
	var pos := centre - cs * k * 0.5
	var safe := UiTheme.safe_margins(self)
	var view := size
	pos.x = clampf(pos.x, safe.left, view.x - safe.right - cs.x * k)
	pos.y = clampf(pos.y, safe.top, view.y - safe.bottom - cs.y * k)
	close_button.position = pos
	close_button.modulate.a = _frame.modulate.a


func _process(_dt: float) -> void:
	# the close button follows the panel's open / close tweens
	if dismissible and visible and close_button:
		_place_close()


## Re-layout after content changed (call at the end of refresh()). Coalesced per frame.
func relayout() -> void:
	if is_inside_tree() and not _relayout_queued:
		_relayout_queued = true
		_deferred_layout.call_deferred()


func _deferred_layout() -> void:
	_relayout_queued = false
	_layout()


# ---------------------------------------------------------------- small shared builders

static func section_label(text: String) -> Label:
	var l := UiTheme.label(text.to_upper(), 20, UiPalette.GOLD, false, 0, false, 700)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## While the body scrolls, keep content clear of the vertical scrollbar (right-aligned values
## would otherwise sit under it); no gutter when everything fits.
func _update_gutter(scrolls: bool) -> void:
	var bar := _scroll.get_v_scroll_bar()
	var gutter := 0
	if scrolls and bar != null:
		gutter = int(ceil(bar.get_combined_minimum_size().x)) + 8
	if _inner.get_theme_constant("margin_right") != gutter:
		_inner.add_theme_constant_override("margin_right", gutter)
