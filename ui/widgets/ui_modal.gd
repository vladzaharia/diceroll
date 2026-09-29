class_name UiModal
extends Control
## Base for modal dialogs: dimmed scrim, centred gold-rimmed panel (max width 680) with a
## ribbon title, animated in/out. Subclasses fill `body` in _build() and call refresh().
##
##   var m := DraftModal.new(); add_child(m); m.refresh(flow); m.open()

signal opened
signal closed

var title := ""
var ribbon_color: Color = UiPalette.GOLD
var max_width := UiTheme.MODAL_MAX_W
## Content column inside the panel.
var body: VBoxContainer
var panel: PanelContainer
var ribbon: Ribbon
var scrim: ColorRect
var _frame: VBoxContainer
var _center: Control
var _scroll: ScrollContainer
var _inner: MarginContainer
var _is_open := false
var _close_tween: Tween
var _relayout_queued := false


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
	_frame = UiTheme.vbox(-26)
	_center.add_child(_frame)
	ribbon = Ribbon.make(title, 38, ribbon_color)
	ribbon.z_index = 1
	_frame.add_child(ribbon)
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
	resized.connect(_layout)
	visible = false
	_build()


func _ready() -> void:
	_layout()


## Override: create the static widgets inside `body`.
func _build() -> void:
	pass


func set_title(t: String, color: Variant = null) -> void:
	title = t
	ribbon.text = t
	if color is Color:
		ribbon.color = color
	ribbon.visible = t != ""
	ribbon.queue_redraw()


func open() -> void:
	# reopened while closing (e.g. two drafts back to back): cancel the close
	if _close_tween and _close_tween.is_valid():
		_close_tween.kill()
	visible = true
	_is_open = true
	_layout()
	scrim.modulate.a = 0.0
	_frame.modulate.a = 0.0
	_frame.scale = Vector2(0.86, 0.86)
	await get_tree().process_frame
	_layout()
	_frame.pivot_offset = _frame.size * 0.5
	var target := _frame.position
	_frame.position.y += 70.0
	var t := create_tween().set_parallel(true)
	t.tween_property(scrim, "modulate:a", 1.0, 0.18)
	t.tween_property(_frame, "modulate:a", 1.0, 0.14)
	t.tween_property(_frame, "position", target, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_frame, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	UiTheme.sfx("open")
	opened.emit()


## Shows instantly (no tween) — used by screenshots and when restoring state.
func show_now() -> void:
	visible = true
	_is_open = true
	scrim.modulate.a = 1.0
	_frame.modulate.a = 1.0
	_frame.scale = Vector2.ONE
	_layout()


func close(free_after := false) -> void:
	if not _is_open:
		return
	_is_open = false
	_frame.pivot_offset = _frame.size * 0.5
	var t := create_tween().set_parallel(true)
	_close_tween = t
	t.tween_property(scrim, "modulate:a", 0.0, 0.16)
	t.tween_property(_frame, "modulate:a", 0.0, 0.14)
	t.tween_property(_frame, "scale", Vector2(0.92, 0.92), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	if _is_open:
		return
	visible = false
	closed.emit()
	if free_after:
		queue_free()


func is_open() -> bool:
	return _is_open


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
	var avail_h := view.y - safe.top - safe.bottom
	var sb := panel.get_theme_stylebox("panel")
	var chrome := sb.content_margin_top + sb.content_margin_bottom + (ribbon.get_combined_minimum_size().y - 26.0 if ribbon.visible else 0.0)
	var natural := _inner.get_combined_minimum_size().y
	_scroll.custom_minimum_size.y = minf(natural, avail_h - chrome)
	_frame.reset_size()
	_frame.size.x = w
	_frame.position = Vector2((view.x - w) * 0.5, maxf(safe.top, (view.y - _frame.size.y) * 0.5))
	_frame.pivot_offset = _frame.size * 0.5


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
