class_name BoardHud
extends Control
## Board-phase HUD. Top: HudTop (HP, XP/level, gold, treasury, act/lap, pause).
## Bottom (just above the dice tray): ROLL in BOARD_READY; "Pick a die to move" + Reroll (n)
## in BOARD_ROLLED. Hidden bottom bar in every other phase.
##
## Signals carry intent only; the integration layer calls GameFlow.

signal roll_pressed
signal reroll_pressed
signal pause_pressed

var top: HudTop
var roll_btn: GameButton
var reroll_btn: GameButton
var hint: PanelContainer
var _hint_label: Label
var _bar: HBoxContainer
var _toast_holder: Control
var _phase := -1
## True while the game plays events back: the bottom bar is hidden (input locked).
var busy := false


func _init() -> void:
	theme = UiTheme.get_theme()
	UiTheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top = HudTop.new()
	top.pause_pressed.connect(func() -> void: pause_pressed.emit())
	add_child(top)

	_bar = UiTheme.hbox(16)
	_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_bar)

	roll_btn = GameButton.make("ROLL", "dice", GameButton.Kind.PRIMARY, 54)
	roll_btn.icon_tint = UiPalette.DIE_BODY
	roll_btn.min_height = 120
	roll_btn.pad_x = 64
	roll_btn.sfx_id = "dice_shake"
	roll_btn.pressed.connect(func() -> void: roll_pressed.emit())
	_bar.add_child(roll_btn)

	hint = PanelContainer.new()
	hint.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.panel_box("pill"), 26, 14))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var hr := UiTheme.hbox(12)
	hint.add_child(hr)
	hr.add_child(UiIcons.rect("dice", 40))
	_hint_label = UiTheme.label("Pick a die to move", 30, UiPalette.TEXT, true, 0, true)
	hr.add_child(_hint_label)
	_bar.add_child(hint)

	reroll_btn = GameButton.make("REROLL", "reroll", GameButton.Kind.SECONDARY, 30)
	reroll_btn.icon_tint = UiPalette.GOLD_BRIGHT
	reroll_btn.min_height = 96
	reroll_btn.pad_x = 26
	reroll_btn.pressed.connect(func() -> void: reroll_pressed.emit())
	_bar.add_child(reroll_btn)

	_toast_holder = Control.new()
	_toast_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiTheme.full_rect(_toast_holder))
	resized.connect(_layout)


func _ready() -> void:
	_layout()


func _layout() -> void:
	if size.x <= 0.0:
		return
	var safe := UiTheme.safe_margins(self)
	var w := minf(UiTheme.MODAL_MAX_W, size.x - safe.left - safe.right)
	_bar.reset_size()
	var h := _bar.get_combined_minimum_size().y
	var bottom := size.y - UiTheme.tray_height(size) - 20.0
	_bar.size = Vector2(w, h)
	_bar.position = Vector2((size.x - w) * 0.5, bottom - h)


func refresh(flow: GameFlow) -> void:
	top.refresh(flow)
	var ph := flow.phase
	var changed := ph != _phase
	_phase = ph
	var ready := ph == GameFlow.Phase.BOARD_READY
	var rolled := ph == GameFlow.Phase.BOARD_ROLLED
	_bar.visible = (ready or rolled) and not busy
	roll_btn.visible = ready
	hint.visible = rolled
	reroll_btn.visible = rolled
	reroll_btn.sub_text = "%d left" % flow.board_rerolls_left
	reroll_btn.set_enabled(flow.board_rerolls_left > 0)
	_layout()
	if changed and _bar.visible and is_inside_tree():
		_bar.modulate.a = 0.0
		var t := create_tween()
		t.tween_property(_bar, "modulate:a", 1.0, 0.18)
		if ready:
			UiTheme.pop(roll_btn, 1.08, 0.3)
		else:
			UiTheme.pop(hint, 1.08, 0.3)


## Locks (hides) the bottom bar while events play; the next refresh() restores it.
func set_busy(on: bool) -> void:
	busy = on
	if on:
		_bar.visible = false


func on_event(ev: Dictionary, flow: GameFlow) -> void:
	top.on_event(ev, flow)
	match String(ev.get("type", "")):
		"board_rolled":
			if int(ev.get("treasury_added", 0)) > 0:
				toast("Doubles! +%d to the Treasury" % int(ev.treasury_added), "chest", UiPalette.GOLD_BRIGHT)
		"lap_completed":
			toast("Lap complete  +%d HP" % int(ev.get("healed", 0)), "flag", UiPalette.HEAL)
		"trap":
			toast("Trap dodged!" if bool(ev.dodged) else "Trap! -%d HP" % int(ev.damage), "skull",
				UiPalette.HEAL if bool(ev.dodged) else UiPalette.HP_BRIGHT)


## Floating message that pops above the bottom bar and fades.
func toast(text: String, icon := "", color: Color = UiPalette.TEXT) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.panel_box("pill"), 24, 12))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UiTheme.hbox(10)
	p.add_child(row)
	if icon != "":
		row.add_child(UiIcons.rect(icon, 36))
	row.add_child(UiTheme.label(text, 28, color, true, 0, true))
	_toast_holder.add_child(p)
	p.reset_size()
	var y := size.y - UiTheme.tray_height(size) - 180.0 - _toast_holder.get_child_count() * 70.0
	p.position = Vector2((size.x - p.size.x) * 0.5, y)
	p.pivot_offset = p.size * 0.5
	p.scale = Vector2(0.6, 0.6)
	p.modulate.a = 0.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(p, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(p, "modulate:a", 1.0, 0.15)
	t.chain().tween_interval(1.4)
	t.chain().set_parallel(true)
	t.tween_property(p, "position:y", y - 50.0, 0.4)
	t.tween_property(p, "modulate:a", 0.0, 0.4)
	t.chain().tween_callback(p.queue_free)
