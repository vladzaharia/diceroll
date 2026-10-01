class_name BoardHud
extends Control
## Board-phase HUD. Top: HudTop (HP, XP/level, gold, treasury, lap, passives, pause).
## Bottom (just above the dice tray): ROLL in BOARD_READY. In BOARD_ROLLED the move is
## automatic: a move pill shows the two moving dice and their sum ("5 + 5 = 10", DOUBLES!)
## over a big GO button and Reroll (n). Hidden bottom bar in every other phase.
##
## Signals carry intent only; the integration layer calls GameFlow.

signal roll_pressed
signal reroll_pressed
signal go_pressed
signal pause_pressed

var top: HudTop
var roll_btn: GameButton
var go_btn: GameButton
var reroll_btn: GameButton
var move_pill: PanelContainer
var _move_row: HBoxContainer
var _bar: HBoxContainer
var _col: VBoxContainer
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

	_col = UiTheme.vbox(14)
	add_child(_col)
	move_pill = PanelContainer.new()
	move_pill.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.panel_box("pill"), 22, 8))
	move_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	move_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_col.add_child(move_pill)
	_move_row = UiTheme.hbox(10)
	_move_row.alignment = BoxContainer.ALIGNMENT_CENTER
	move_pill.add_child(_move_row)
	_bar = UiTheme.hbox(16)
	_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_col.add_child(_bar)

	roll_btn = GameButton.make("ROLL", "dice", GameButton.Kind.PRIMARY, 54)
	roll_btn.icon_tint = UiPalette.DIE_BODY
	roll_btn.min_height = 120
	roll_btn.pad_x = 64
	roll_btn.sfx_id = "dice_shake"
	roll_btn.pressed.connect(func() -> void: roll_pressed.emit())
	_bar.add_child(roll_btn)

	reroll_btn = GameButton.make("REROLL", "reroll", GameButton.Kind.SECONDARY, 30)
	reroll_btn.icon_tint = UiPalette.GOLD_BRIGHT
	reroll_btn.min_height = 110
	reroll_btn.pad_x = 26
	reroll_btn.pressed.connect(func() -> void: reroll_pressed.emit())
	_bar.add_child(reroll_btn)

	go_btn = GameButton.make("GO", "arrow_right", GameButton.Kind.PRIMARY, 58)
	go_btn.icon_tint = UiPalette.TEXT_DARK
	go_btn.min_height = 120
	go_btn.pad_x = 70
	go_btn.sfx_id = "step"
	go_btn.pressed.connect(func() -> void: go_pressed.emit())
	_bar.add_child(go_btn)

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
	_col.reset_size()
	var h := _col.get_combined_minimum_size().y
	var slot := UiTheme.side_slot(size, safe)
	if slot.size.x > 0.0:
		# landscape: beside the tray, bottom-aligned, so the board keeps the height
		_col.size = Vector2(slot.size.x, h)
		_col.position = Vector2(slot.position.x, slot.end.y - h)
		return
	var w := minf(UiTheme.MODAL_MAX_W, size.x - safe.left - safe.right)
	# portrait: the reserved band is sized for the tallest state (move pill + GO); a
	# shorter bar (ROLL) sits centred in it so the board framing never jumps between states
	var band := bar_reserve()
	var bottom := UiTheme.tray_rect(size, safe).position.y - 20.0
	_col.size = Vector2(w, h)
	_col.position = Vector2((size.x - w) * 0.5, bottom - band + maxf(band - h, 0.0) * 0.5)


## Height reserved for the bottom controls: the tallest of the ROLL state and the rolled
## state (move pill over GO / Reroll), measured from the actual widgets.
func bar_reserve() -> float:
	var sep := float(_col.get_theme_constant("separation"))
	var roll_h := roll_btn.get_combined_minimum_size().y
	var go_h := maxf(go_btn.get_combined_minimum_size().y, reroll_btn.get_combined_minimum_size().y)
	var pill_h := maxf(move_pill.get_combined_minimum_size().y, 72.0)
	return maxf(roll_h, pill_h + sep + go_h)


## Top edge (canvas y) of the bottom controls: the board must stay above it. Beside the tray
## in landscape (the tray top, or the bar top if the bar is taller than the tray).
func content_top(view: Vector2) -> float:
	return UiTheme.bottom_bar_top(view, bar_reserve(), UiTheme.safe_margins(self))


func refresh(flow: GameFlow) -> void:
	top.refresh(flow)
	var ph := flow.phase
	var changed := ph != _phase
	_phase = ph
	var ready := ph == GameFlow.Phase.BOARD_READY
	var rolled := ph == GameFlow.Phase.BOARD_ROLLED
	_col.visible = (ready or rolled) and not busy
	roll_btn.visible = ready
	# the finale's one roll into the boss fight
	roll_btn.text = "FINAL ROLL" if flow.run.finale else "ROLL"
	go_btn.visible = rolled
	reroll_btn.visible = rolled and not flow.run.finale
	move_pill.visible = rolled
	reroll_btn.sub_text = "%d left" % flow.board_rerolls_left
	reroll_btn.set_enabled(flow.board_rerolls_left > 0)
	if rolled:
		_fill_move(flow)
	_layout()
	if _col.visible and is_inside_tree() and (changed or rolled):
		_col.modulate.a = 0.0
		var t := create_tween()
		t.tween_property(_col, "modulate:a", 1.0, 0.18)
		if ready:
			UiTheme.pop(roll_btn, 1.08, 0.3)
		else:
			UiTheme.pop(go_btn, 1.1, 0.3)
			UiTheme.pop(move_pill, 1.12, 0.3)


## "[5] + [5] = 10  DOUBLES!" for the current board roll (the two auto-picked dice).
func _fill_move(flow: GameFlow) -> void:
	UiTheme.clear(_move_row)
	var ch := flow.board_choice
	for k in ch.size():
		var i := int(ch[k])
		if k > 0:
			_move_row.add_child(UiTheme.label("+", 34, UiPalette.TEXT_DIM, true, 4))
		var die: Die = flow.run.dice[i] if i < flow.run.dice.size() else null
		var f := DieFace.make(flow.board_roll[i] if i < flow.board_roll.size() else 0, die.rune if die else "", false, 56)
		f.kind = die.kind if die else "standard"
		_move_row.add_child(f)
	_move_row.add_child(UiTheme.label("=", 34, UiPalette.TEXT_DIM, true, 4))
	var steps := flow.board_move
	_move_row.add_child(UiTheme.label(str(steps), 50, UiPalette.GOLD_BRIGHT, true, 8))
	if flow.board_move == 0:
		_move_row.add_child(UiTheme.label("STAY", 26, UiPalette.TEXT_DIM, true, 4))
	elif flow.is_board_double():
		var tag := PanelContainer.new()
		tag.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(Color(UiPalette.GOLD, 0.2), 12, 2, UiPalette.GOLD_BRIGHT), 10, 2))
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var pv := flow.board_pair_value()
		tag.add_child(UiTheme.label("DOUBLES · PAIR OF %d" % pv if pv > 0 else "DOUBLES!", 22, UiPalette.GOLD_BRIGHT, true, 4))
		_move_row.add_child(tag)
	elif flow.run.finale or (flow.run.lap >= flow.run.total_laps() and flow.run.board.crosses_start(flow.run.pos, flow.board_move)):
		_move_row.add_child(UiTheme.label("BOSS!", 26, UiPalette.HP_BRIGHT, true, 4))


## Locks (hides) the bottom bar while events play; the next refresh() restores it.
func set_busy(on: bool) -> void:
	busy = on
	if on:
		_col.visible = false


func on_event(ev: Dictionary, flow: GameFlow) -> void:
	top.on_event(ev, flow)
	match String(ev.get("type", "")):
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
	var y := content_top(size) - 70.0 - _toast_holder.get_child_count() * 70.0
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
