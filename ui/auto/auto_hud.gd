class_name AutoHud
extends Control
## In-run AUTO / speed layer (spec §15 "Speed and AUTO"), one per UiRoot, drawn above the
## HUDs and phase modals:
##
##  * cluster: the speed pill (1× / 2× / 4×), the AUTO toggle and a small gear for the AUTO
##    settings, right-aligned just under the top HUD (hidden while a phase modal is open);
##  * ticker: a one-line "why" for the step AUTO is about to play, above the bottom bar
##    (fades in, cross-fades on a new reason, fades out when AUTO goes quiet);
##  * stop card: "AUTO PAUSED" + the reason, in the ticker slot, when AUTO hands back control;
##  * highlights: a pulsing teal ring around the control / die / tile AUTO is about to use.
##
## Signals carry intent only; the game layer (AutoPilot / GameController) acts on them.

signal auto_toggled(on: bool)
signal speed_picked(speed: float)
signal settings_requested

const ACCENT := AutoButton.ACCENT
## Seconds a reason stays up without a new step before the ticker fades.
var ticker_hold := 3.2

var ui: UiRoot
var cluster: HBoxContainer
var auto_btn: AutoButton
var speed_pill: SpeedPill
var gear_btn: GameButton
var ticker: PanelContainer
var _ticker_icon: TextureRect
var _ticker_label: Label
var _ticker_tween: Tween
var _ticker_text := ""
var _ticker_age := 0.0
var _ticker_dy := 0.0
var _stop_card: PanelContainer
var _stop_sub: Label
var _stop_tween: Tween
var _stop_age := 99.0
## [{target: Control|Rect2, t: float, dur: float, color: Color}]
var _marks: Array[Dictionary] = []


func _init() -> void:
	theme = UiTheme.get_theme()
	UiTheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	cluster = UiTheme.hbox(10)
	cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cluster)
	speed_pill = SpeedPill.new()
	speed_pill.speed_picked.connect(func(s: float) -> void: speed_picked.emit(s))
	cluster.add_child(speed_pill)
	auto_btn = AutoButton.new()
	auto_btn.toggled_by_user.connect(func(on: bool) -> void: auto_toggled.emit(on))
	auto_btn.settings_requested.connect(func() -> void: settings_requested.emit())
	cluster.add_child(auto_btn)
	gear_btn = GameButton.round_icon("gear", 64)
	gear_btn.kind = GameButton.Kind.GHOST
	gear_btn.icon_px = 30
	gear_btn.icon_tint = Color(AutoButton.ACCENT, 0.95)
	gear_btn.tooltip_text = "AUTO settings"
	gear_btn.pressed.connect(func() -> void: settings_requested.emit())
	cluster.add_child(gear_btn)

	ticker = PanelContainer.new()
	ticker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ticker.add_theme_stylebox_override("panel", UiTheme.pad(
		UiTheme.box(Color(0.03, 0.05, 0.1, 0.82), 22, 2, Color(ACCENT, 0.45), 10, Color(0, 0, 0, 0.35)), 18, 7))
	ticker.visible = false
	add_child(ticker)
	var tr := UiTheme.hbox(10)
	ticker.add_child(tr)
	_ticker_icon = UiIcons.rect("auto", 26, ACCENT)
	_ticker_icon.custom_minimum_size = Vector2(26, 26)
	_ticker_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.add_child(_ticker_icon)
	_ticker_label = UiTheme.label("", 23, UiPalette.TEXT, false, 0, false, 600)
	_ticker_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_ticker_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.add_child(_ticker_label)

	_stop_card = PanelContainer.new()
	_stop_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stop_card.add_theme_stylebox_override("panel", UiTheme.pad(
		UiTheme.box(Color(0.03, 0.05, 0.1, 0.94), 24, 3, ACCENT, 16, Color(0, 0, 0, 0.45)), 24, 12))
	_stop_card.visible = false
	add_child(_stop_card)
	var sr := UiTheme.hbox(14)
	_stop_card.add_child(sr)
	var pi := UiIcons.rect("pause", 40, ACCENT)
	pi.custom_minimum_size = Vector2(40, 40)
	pi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sr.add_child(pi)
	var sc := UiTheme.vbox(0)
	sr.add_child(sc)
	sc.add_child(UiTheme.label("AUTO PAUSED", 28, ACCENT.lightened(0.25), true, 6))
	_stop_sub = UiTheme.label("", 23, UiPalette.TEXT, false, 0, false, 600)
	sc.add_child(_stop_sub)
	resized.connect(_layout)


func _ready() -> void:
	_layout()


## UiRoot calls this once; the HUD reads which screens are showing from it.
func setup(root: UiRoot) -> void:
	ui = root


func set_auto(on: bool) -> void:
	auto_btn.set_active(on)
	if not on:
		hide_reason()
		_marks.clear()
		queue_redraw()


func set_speed(s: float) -> void:
	speed_pill.set_speed(s, false)


# --- ticker -------------------------------------------------------------------------------

## Shows AUTO's reason for its next step. Repeats of the same text only keep it alive.
func show_reason(text: String) -> void:
	if text == "":
		return
	_ticker_age = 0.0
	if text == _ticker_text and ticker.visible and ticker.modulate.a > 0.5:
		return
	_ticker_text = text
	if _stop_card.visible:
		return
	if _ticker_tween and _ticker_tween.is_valid():
		_ticker_tween.kill()
	_ticker_tween = create_tween()
	if ticker.visible and ticker.modulate.a > 0.05:
		_ticker_tween.tween_property(ticker, "modulate:a", 0.0, 0.1)
	_ticker_tween.tween_callback(func() -> void:
		_ticker_label.text = text
		ticker.visible = true
		ticker.modulate.a = 0.0
		_ticker_dy = 10.0
		_layout())
	_ticker_tween.set_parallel(true)
	_ticker_tween.chain().tween_property(ticker, "modulate:a", 1.0, 0.16)
	_ticker_tween.tween_property(self, "_ticker_dy", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func hide_reason() -> void:
	_ticker_text = ""
	if not ticker.visible:
		return
	if _ticker_tween and _ticker_tween.is_valid():
		_ticker_tween.kill()
	_ticker_tween = create_tween()
	_ticker_tween.tween_property(ticker, "modulate:a", 0.0, 0.3)
	_ticker_tween.tween_callback(func() -> void: ticker.visible = false)


## "AUTO PAUSED · <reason>": AUTO handed control back to the player.
func show_stop(reason: String) -> void:
	hide_reason()
	_stop_sub.text = reason
	_stop_card.visible = true
	_stop_card.reset_size()
	_layout()
	_stop_card.pivot_offset = _stop_card.size * 0.5
	_stop_card.scale = Vector2(0.7, 0.7)
	_stop_card.modulate.a = 0.0
	_stop_age = 0.0
	if _stop_tween and _stop_tween.is_valid():
		_stop_tween.kill()
	_stop_tween = create_tween().set_parallel(true)
	_stop_tween.tween_property(_stop_card, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_stop_tween.tween_property(_stop_card, "modulate:a", 1.0, 0.14)
	_stop_tween.chain().tween_interval(2.6)
	_stop_tween.chain().tween_property(_stop_card, "modulate:a", 0.0, 0.35)
	_stop_tween.chain().tween_callback(func() -> void: _stop_card.visible = false)
	UiTheme.sfx("page")


# --- highlights -----------------------------------------------------------------------------

## Pulsing ring around a control (followed as it moves) or a canvas rect, for `dur` seconds.
func highlight(target: Variant, dur := 0.6, color: Color = ACCENT) -> void:
	if target == null:
		return
	if target is Control and not is_instance_valid(target):
		return
	_marks.append({"target": target, "t": 0.0, "dur": maxf(dur, 0.12), "color": color})
	if target is Control:
		UiTheme.pop(target as Control, 1.07, minf(dur, 0.3))
	queue_redraw()


func clear_highlights() -> void:
	_marks.clear()
	queue_redraw()


func _mark_rect(m: Dictionary) -> Rect2:
	var tg: Variant = m.target
	if tg is Control:
		var c := tg as Control
		if not is_instance_valid(c) or not c.is_visible_in_tree():
			return Rect2()
		var r := c.get_global_rect()
		return Rect2(r.position - global_position, r.size)
	if tg is Rect2:
		return Rect2((tg as Rect2).position - global_position, (tg as Rect2).size)
	return Rect2()


# --- per frame ------------------------------------------------------------------------------

func _process(dt: float) -> void:
	var show := _in_run() and not _phase_modal_open()
	if cluster.visible != show:
		cluster.visible = show
	if show or ticker.visible or _stop_card.visible:
		_layout()
	if ticker.visible and _ticker_text != "":
		_ticker_age += dt
		if _ticker_age > ticker_hold:
			hide_reason()
	if not _in_run() and (ticker.visible or _stop_card.visible):
		ticker.visible = false
		_stop_card.visible = false
	if not _marks.is_empty():
		for m in _marks:
			m.t += dt
		_marks = _marks.filter(func(m: Dictionary) -> bool: return float(m.t) < float(m.dur))
		queue_redraw()


func _in_run() -> bool:
	if ui == null:
		return false
	return ui.board_hud.visible or ui.combat_hud.visible or _phase_modal_open()


func _phase_modal_open() -> bool:
	if ui == null:
		return false
	for m: UiModal in [ui.draft, ui.passive, ui.rune_assign, ui.shop, ui.forge, ui.event]:
		if m.visible:
			return true
	return false


func _layout() -> void:
	var view := size
	if view.x <= 0.0:
		return
	var safe := UiTheme.safe_margins(self)
	# cluster: right-aligned under the visible top HUD
	var top: HudTop = null
	if ui:
		top = ui.combat_hud.top if ui.combat_hud.visible else ui.board_hud.top
	var w := minf(HudTop.MAX_W, view.x - safe.left - safe.right)
	var right := (view.x + w) * 0.5
	var y := (top.content_bottom() if top else safe.top + 110.0) + 14.0
	cluster.reset_size()
	cluster.position = Vector2(right - cluster.size.x, y)
	_place_ticker()
	if _stop_card.visible:
		_stop_card.reset_size()
		var s := _stop_card.get_combined_minimum_size()
		_stop_card.size = s
		_stop_card.position = Vector2((view.x - s.x) * 0.5, _slot_bottom() - s.y)
		_stop_card.pivot_offset = s * 0.5


## Bottom edge of the ticker slot: just above the bottom bar (or near the screen bottom
## while a phase modal covers the HUD).
func _slot_bottom() -> float:
	var view := size
	if ui == null:
		return view.y * 0.7
	if _phase_modal_open():
		return view.y - UiTheme.safe_margins(self).bottom - 12.0
	var ct := ui.combat_hud.content_top(view) if ui.combat_hud.visible else ui.board_hud.content_top(view)
	return ct - 14.0


func _place_ticker() -> void:
	if not ticker.visible:
		return
	var view := size
	# an ellipsis label reports ~0 min width: size it from the measured text, capped
	var ls := _ticker_label.label_settings
	var tw := ls.font.get_string_size(_ticker_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, ls.font_size).x + 4.0
	var maxw := minf(view.x - 48.0, 760.0)
	_ticker_label.custom_minimum_size.x = 0.0
	var chrome := ticker.get_combined_minimum_size().x - _ticker_label.get_minimum_size().x
	_ticker_label.custom_minimum_size.x = minf(tw, maxw - chrome)
	var s := ticker.get_combined_minimum_size()
	ticker.size = s
	ticker.position = Vector2((view.x - s.x) * 0.5, _slot_bottom() - s.y + _ticker_dy)


func _draw() -> void:
	for m in _marks:
		var r := _mark_rect(m)
		if r.size == Vector2.ZERO:
			continue
		var k := float(m.t) / float(m.dur)
		var col: Color = m.color
		var fade := clampf((1.0 - k) * 3.0, 0.0, 1.0) * clampf(float(m.t) * 12.0, 0.0, 1.0)
		var rad := int(minf(r.size.y * 0.5, 28.0))
		# steady ring
		var ring := UiTheme.box(Color.TRANSPARENT, rad + 6, 4, Color(col, 0.95 * fade))
		ring.draw_center = false
		draw_style_box(ring, r.grow(6))
		# expanding pulses
		for p in 2:
			var ph := fposmod(float(m.t) * 2.2 - p * 0.5, 1.0)
			var g := 6.0 + ph * 16.0
			var pr := UiTheme.box(Color.TRANSPARENT, int(rad + g), 3, Color(col, (1.0 - ph) * 0.6 * fade))
			pr.draw_center = false
			draw_style_box(pr, r.grow(g))
		# soft fill
		draw_style_box(UiTheme.box(Color(col, 0.10 * fade), rad + 6), r.grow(6))
