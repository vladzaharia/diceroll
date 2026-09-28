class_name PortalBanner
extends Control
## Non-blocking hint shown in the PORTAL phase: the player taps a glowing tile on the board
## (handled by game/world). Sits under the top HUD and gently pulses.

var _panel: PanelContainer
var _title: Label
var _text: Label
var _t := 0.0


func _init() -> void:
	UiTheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(Color(0.12, 0.06, 0.26, 0.92), 30, 3, Color("a56bff"), 22, Color(0.5, 0.25, 1.0, 0.45), Vector2.ZERO), 26, 16))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var row := UiTheme.hbox(16)
	_panel.add_child(row)
	row.add_child(UiIcons.rect("portal", 64))
	var col := UiTheme.vbox(0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	_title = UiTheme.label("PORTAL", 34, Color("d8c0ff"), true, 6)
	col.add_child(_title)
	_text = UiTheme.label("Tap a glowing tile to teleport", 24, UiPalette.TEXT, false, 0, false, 600)
	col.add_child(_text)
	visible = false
	resized.connect(_layout)


func refresh(flow: GameFlow) -> void:
	var on := flow.phase == GameFlow.Phase.PORTAL
	if on and not visible:
		var n := Array(flow.offer.get("tiles", [])).size()
		_text.text = "Tap a glowing tile to teleport (next %d)" % n if n > 0 else "Tap a glowing tile to teleport"
		visible = true
		_layout()
		_panel.pivot_offset = _panel.size * 0.5
		_panel.scale = Vector2(0.7, 0.7)
		var t := create_tween()
		t.tween_property(_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		UiTheme.sfx("portal")
	elif not on:
		visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_panel.self_modulate = Color(1, 1, 1).lerp(Color(1.15, 1.05, 1.3), 0.5 + 0.5 * sin(_t * 3.0))


func _layout() -> void:
	if size.x <= 0.0:
		return
	var safe := UiTheme.safe_margins(self)
	_panel.reset_size()
	var s := _panel.get_combined_minimum_size()
	_panel.size = s
	_panel.position = Vector2((size.x - s.x) * 0.5, safe.top + 170.0)
	_panel.pivot_offset = s * 0.5
