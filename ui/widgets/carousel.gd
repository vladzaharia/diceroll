class_name Carousel
extends VBoxContainer
## A horizontal strip of fixed-height tiles shown one page at a time (Camp stations pass,
## docs/design/2026-10-01-camp-stations.md): icon-only prev / next GameButtons on the sides, a
## page indicator and an "N ITEMS" count under the strip, swipe / drag on touch, and ←/→ on the
## keyboard for the focused carousel (the last one hovered or used). Its height never depends
## on how many items it holds, so cards that carry one stay the same height.
##
##   var c := Carousel.make(tiles, 132.0, 120.0, "pack:starter")
##   c.count_text = "25 ITEMS"
##   c.page_changed.connect(func(p: int) -> void: hide_tip())
##
## Tiles are any Controls; Carousel.ItemTile is the flat item tile (icon, name, a detail line)
## with a `pressed` signal. Tiles must let mouse events pass (MOUSE_FILTER_PASS) so a drag
## anywhere on the strip swipes. A carousel with a `key` remembers its page (and the keyboard
## focus) across rebuilds of its screen.

signal page_changed(page: int)

## Drag distance (canvas px) that turns a press into a swipe, and that pages on release.
const SWIPE_START := 18.0
const SWIPE_PAGE := 48.0
## Arrow buttons: drawn size (their hit rect is 88 px, GameButton's floor).
const ARROW_PX := 60.0
## Height of the strip + indicator row beyond the tiles (callers size their slot with it).
const CHROME_H := 6.0 + 88.0
## Gap between tiles.
const GAP := 12
## Page dots: at most this many (more pages show "N/M" only).
const MAX_DOTS := 6

## Remembered first visible item per carousel key, and the key of the focused carousel.
static var _first_by_key: Dictionary = {}
static var _focus_key := ""
static var _focused: WeakRef = null

var key := ""
var tile_h := 132.0
var tile_min_w := 120.0
## Most tiles on one page (0 = as many as fit).
var max_per_page := 0
var page := 0
var per_page := 1
## "25 ITEMS" under the strip (left); "" = none.
var count_text := "":
	set(v):
		count_text = v
		if _count:
			_count.text = v
var items: Array[Control] = []

var _row: HBoxContainer
var _strip: Control
var _track: HBoxContainer
var _prev: GameButton
var _next: GameButton
var _dots: _Dots
var _count: Label
var _pager: Label
var _fillers: Array[Control] = []
var _press_at := Vector2.ZERO
var _pressed := false
var _swiping := false
var _drag_dx := 0.0
var _tween: Tween


static func make(tiles: Array, p_tile_h := 132.0, p_tile_min_w := 120.0, p_key := "") -> Carousel:
	var c := Carousel.new()
	c.tile_h = p_tile_h
	c.tile_min_w = p_tile_min_w
	c.key = p_key
	c._build()
	for t in tiles:
		c.add_item(t as Control)
	if p_key != "" and _first_by_key.has(p_key):
		c._restore_first(int(_first_by_key[p_key]))
	c._apply_page(false)
	return c


func _build() -> void:
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# the strip gets the full width (more tiles per page); the arrows sit in the indicator
	# row under it: count on the left, then prev · dots (or N/M) · next on the right
	_strip = Control.new()
	_strip.name = "Strip"
	_strip.clip_contents = true
	_strip.custom_minimum_size = Vector2(tile_min_w, tile_h)
	_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_strip.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_strip)
	_track = UiTheme.hbox(GAP)
	_track.mouse_filter = Control.MOUSE_FILTER_PASS
	_strip.add_child(_track)
	_strip.resized.connect(_on_strip_resized)
	_row = UiTheme.hbox(4)
	_row.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_row)
	_count = UiTheme.label(count_text, 16, UiPalette.TEXT_MUTED, false, 0, false, 800)
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_child(_count)
	_prev = _arrow("chevron_left" if Icons.is_mapped("chevron_left") else "arrow_left", "key_left", "Previous")
	_prev.pressed.connect(func() -> void: prev_page())
	_row.add_child(_prev)
	_dots = _Dots.new()
	_dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(_dots)
	_pager = UiTheme.label("", 16, UiPalette.TEXT_DIM, false, 0, false, 800)
	_pager.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_row.add_child(_pager)
	_next = _arrow("chevron_right" if Icons.is_mapped("chevron_right") else "arrow_right", "key_right", "Next")
	_next.pressed.connect(func() -> void: next_page())
	_row.add_child(_next)
	mouse_entered.connect(_claim_focus)


## Moves the indicator row (count, arrows, dots) out of the carousel so a card can put it in
## its footer next to its status line; the carousel keeps working the same.
func take_nav() -> HBoxContainer:
	if _row.get_parent() == self:
		remove_child(_row)
	_count.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_row.size_flags_horizontal = Control.SIZE_SHRINK_END
	_row.mouse_entered.connect(_claim_focus)
	return _row


func _arrow(icon: String, hint: String, tip: String) -> GameButton:
	var b := GameButton.round_icon(icon, ARROW_PX)
	b.round_family = "grey"
	b.shortcut_hint = hint
	b.tooltip_text = tip
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(_claim_focus)
	return b


func add_item(t: Control) -> void:
	t.custom_minimum_size = Vector2(maxf(t.custom_minimum_size.x, 0.0), tile_h)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_stretch_ratio = 1.0
	_track.add_child(t)
	items.append(t)


func page_count() -> int:
	return maxi(1, int(ceil(float(items.size()) / float(maxi(1, per_page)))))


func set_page(p: int, animate := true) -> void:
	var np := clampi(p, 0, page_count() - 1)
	if np == page:
		_apply_page(false)
		return
	var dir := signi(np - page)
	page = np
	_remember()
	_apply_page(animate, dir)
	page_changed.emit(page)


func next_page() -> void:
	_claim_focus()
	if page < page_count() - 1:
		UiTheme.sfx("click")
		set_page(page + 1)


func prev_page() -> void:
	_claim_focus()
	if page > 0:
		UiTheme.sfx("click")
		set_page(page - 1)


## Tiles per page for a strip `w` px wide (tests and _on_strip_resized). Keeps the first
## visible item on screen.
func layout_for_width(w: float) -> void:
	var first := page * per_page
	var n := int(floor((w + GAP) / (tile_min_w + GAP)))
	if max_per_page > 0:
		n = mini(n, max_per_page)
	n = maxi(1, n)
	if n == per_page:
		_apply_page(false)
		return
	per_page = n
	page = clampi(first / per_page, 0, page_count() - 1)
	_apply_page(false)


func _restore_first(first: int) -> void:
	page = clampi(first / maxi(1, per_page), 0, page_count() - 1)


func _remember() -> void:
	if key != "":
		_first_by_key[key] = page * per_page


func _on_strip_resized() -> void:
	layout_for_width(_strip.size.x)
	if key != "" and _first_by_key.has(key):
		page = clampi(int(_first_by_key[key]) / per_page, 0, page_count() - 1)
		_apply_page(false)
	_track.position = Vector2.ZERO
	_track.size = _strip.size


## Shows the tiles of `page` (fillers keep the last page's tiles at their usual width).
func _apply_page(animate: bool, dir := 0) -> void:
	if _track == null:
		return
	var lo := page * per_page
	for i in items.size():
		items[i].visible = i >= lo and i < lo + per_page
	var shown := clampi(items.size() - lo, 0, per_page)
	# fillers keep every tile at the width of a full page (short packs, the last page)
	var need := per_page - shown
	while _fillers.size() < need:
		var f := Control.new()
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		f.custom_minimum_size.y = tile_h
		_track.add_child(f)
		_fillers.append(f)
	for i in _fillers.size():
		_fillers[i].visible = i < need
	var many := page_count() > 1
	# one page: no arrows (the strip's width never depends on them)
	_prev.visible = many
	_next.visible = many
	_prev.set_enabled(many and page > 0)
	_next.set_enabled(many and page < page_count() - 1)
	# a few pages: dots; many: "N/M" (dots would be too small to count)
	var dots := many and page_count() <= MAX_DOTS
	_dots.count = page_count() if dots else 0
	_dots.current = page
	_dots.visible = dots
	_dots.update_minimum_size()
	_dots.queue_redraw()
	_pager.text = "%d/%d" % [page + 1, page_count()] if many and not dots else ""
	_pager.visible = _pager.text != ""
	if animate and is_inside_tree():
		if _tween and _tween.is_valid():
			_tween.kill()
		_track.position.x = 36.0 * dir
		_track.modulate.a = 0.35
		_tween = create_tween().set_parallel(true)
		_tween.tween_property(_track, "position:x", 0.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_track, "modulate:a", 1.0, 0.14)


# ---------------------------------------------------------------- focus and keys

func _claim_focus() -> void:
	_focused = weakref(self)
	_focus_key = key


## True when ←/→ go to this carousel: it was used last (or, before any use, it is the first
## carousel of its screen to ask) and it is showing.
func has_key_focus() -> bool:
	var f: Variant = _focused.get_ref() if _focused != null else null
	if f == null and key != "" and key == _focus_key:
		_focused = weakref(self)
		f = self
	if f == null or not is_instance_valid(f):
		_focused = weakref(self)
		f = self
	return f == self


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not has_key_focus():
		return
	var m := _modal()
	if m != null and not m.is_top():
		return
	if handle_key(event):
		get_viewport().set_input_as_handled()


## ←/→ (or ui_left / ui_right) pages; returns true when the event was used.
func handle_key(event: InputEvent) -> bool:
	if event.is_echo() and not event is InputEventKey:
		return false
	var k := event as InputEventKey
	var left := (k != null and k.pressed and k.keycode == KEY_LEFT) or event.is_action_pressed("ui_left", true)
	var right := (k != null and k.pressed and k.keycode == KEY_RIGHT) or event.is_action_pressed("ui_right", true)
	if left:
		prev_page()
		return true
	if right:
		next_page()
		return true
	return false


func _modal() -> UiModal:
	var n := get_parent()
	while n != null:
		if n is UiModal:
			return n as UiModal
		n = n.get_parent()
	return null


# ---------------------------------------------------------------- swipe

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_claim_focus()
			_pressed = true
			_swiping = false
			_drag_dx = 0.0
			_press_at = mb.global_position
		elif _pressed:
			_pressed = false
			if _swiping:
				accept_event()
				_end_swipe()
		return
	var mm := event as InputEventMouseMotion
	if mm != null and _pressed:
		var d := mm.global_position - _press_at
		if not _swiping and absf(d.x) > SWIPE_START and absf(d.x) > absf(d.y) * 1.2:
			_swiping = true
		if _swiping:
			_drag_dx = d.x
			# the strip follows the finger a little (rubber band)
			_track.position.x = clampf(d.x * 0.4, -60.0, 60.0)
			accept_event()


## True while a press is being dragged sideways (tiles ignore that press's release).
func is_swiping() -> bool:
	return _swiping


func _end_swipe() -> void:
	var dx := _drag_dx
	_swiping = false
	_drag_dx = 0.0
	if dx <= -SWIPE_PAGE and page < page_count() - 1:
		set_page(page + 1)
	elif dx >= SWIPE_PAGE and page > 0:
		set_page(page - 1)
	elif is_inside_tree():
		var t := create_tween()
		t.tween_property(_track, "position:x", 0.0, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_track.position.x = 0.0


## Forgets every remembered page (tests; a new profile).
static func reset_memory() -> void:
	_first_by_key.clear()
	_focus_key = ""
	_focused = null


# ---------------------------------------------------------------- pieces

## The page dots (current = gold, others = muted).
class _Dots:
	extends Control
	var count := 0
	var current := 0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _get_minimum_size() -> Vector2:
		return Vector2(maxf(0.0, count * 18.0 - 6.0), 14.0)

	func _draw() -> void:
		for i in count:
			var c := Vector2(i * 18.0 + 6.0, size.y * 0.5)
			var on := i == current
			draw_circle(c, 6.0, UiPalette.OUTLINE)
			draw_circle(c, 4.5, UiPalette.GOLD_BRIGHT if on else Color(1, 1, 1, 0.22))


## A flat item tile (modal-pass rule: flat, hover lightens, pointer cursor): a visual on top
## (an icon, die faces...), the name (up to two lines) and a detail line. Emits `pressed` on a
## tap that isn't a swipe.
class ItemTile:
	extends PanelContainer
	signal pressed
	var accent: Variant = null
	var state := "normal"
	var _down := false
	var _at := Vector2.ZERO
	var _sb: StyleBox
	var _hov: StyleBox

	static func make(visual: Control, title: String, detail := "", detail_color: Color = UiPalette.TEXT_MUTED,
			p_accent: Variant = null, p_state := "normal", detail_icon := "") -> ItemTile:
		var t := ItemTile.new()
		t.accent = p_accent
		t.state = p_state
		t._build(visual, title, detail, detail_color, detail_icon)
		return t

	func _build(visual: Control, title: String, detail: String, detail_color: Color, detail_icon := "") -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_sb = _box(state)
		_hov = _box("hover") if state == "normal" else _sb
		add_theme_stylebox_override("panel", _sb)
		var col := UiTheme.vbox(2)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(col)
		var vh := UiTheme.hbox(0)
		vh.alignment = BoxContainer.ALIGNMENT_CENTER
		vh.custom_minimum_size.y = 48
		col.add_child(vh)
		if visual != null:
			visual.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vh.add_child(visual)
		var dim := state in ["dim", "locked"]
		var nm := UiTheme.label(title, 16, UiPalette.TEXT_DIM if dim else UiPalette.TEXT, false, 0, false, 700)
		nm.name = "Title"
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.max_lines_visible = 2
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nm.custom_minimum_size = Vector2(40, 42)
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		col.add_child(nm)
		if detail != "":
			var drow := UiTheme.hbox(4)
			drow.alignment = BoxContainer.ALIGNMENT_CENTER
			col.add_child(drow)
			if detail_icon != "":
				# a price: the currency icon, then the bare number (modal-pass convention)
				drow.add_child(CampArt.icon(detail_icon, 20, detail_color))
			var dl := UiTheme.label(detail, 16, detail_color, false, 0, false, 800)
			dl.name = "Detail"
			dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			if detail_icon == "":
				# a word: fills the tile, trimmed if it must be
				dl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				dl.custom_minimum_size.x = 30
				dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			drow.add_child(dl)
		mouse_entered.connect(func() -> void: add_theme_stylebox_override("panel", _hov))
		mouse_exited.connect(func() -> void: add_theme_stylebox_override("panel", _sb))

	func _box(st: String) -> StyleBox:
		var sb := UiTheme.tile_box(st, accent if st in ["normal", "hover"] else null)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		return sb

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_down = true
			_at = mb.global_position
		elif _down:
			_down = false
			var car: Node = get_parent()
			while car != null and not car is Carousel:
				car = car.get_parent()
			if car != null and (car as Carousel).is_swiping():
				return
			if mb.global_position.distance_to(_at) < Carousel.SWIPE_START and get_global_rect().has_point(mb.global_position):
				# the tap is this tile's: a tappable card around the carousel doesn't get it too
				if is_inside_tree():
					accept_event()
				UiTheme.sfx("click")
				pressed.emit()
