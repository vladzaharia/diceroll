class_name MinigameScreen
extends Control
## Full-screen minigame modal over the dimmed board (phase MINIGAME). Hosts one MgBoard
## (FossilBoard / BubbleBoard / ScratchBoard / ClawBoard and the Minigames 2.0 boards: ShooterBoard,
## PlinkoBoard, ShellBoard, MemoryBoard, FishingBoard, WheelBoard, LadderBoard) plus the frame
## every game shares:
## title ribbon, a one-line hint, the actions-left and score pills, a live par meter, the
## AUTO button (takes the par result) and the results beat (medal stamp, score, par meter,
## Crowns). Portrait: everything stacked; landscape: the board left, the panel right.
##
## It renders the core's public state only (flow.offer.state and event states) and never
## calls GameFlow: taps become signals that UiRoot turns into commands.
##
##   screen.open_game(ev)        minigame_started (intro)
##   await screen.play_update(ev) minigame_update
##   await screen.play_result(ev) minigame_result (then it closes)
##   screen.refresh(flow)        every idle in phase MINIGAME (UiRoot.sync)

## args for GameFlow.minigame_action.
signal action(args: Array)
## The game is over on the board (no actions left / nothing left to find): cash it in.
signal finish_requested
## AUTO: skip with the par result (GameFlow.minigame_auto).
signal auto_requested

var speed := 1.0
var game_id := ""
var board: MgBoard
var auto_btn: GameButton
var drop_btn: GameButton
var ribbon: Ribbon

var _flow: GameFlow
var _open := false
var _in_result := false
var _hint: Label
var _stats: HBoxContainer
var _act_num: Label
var _act_unit: Label
var _score_num: Label
var _status: Label
var _status_pill: PanelContainer
var _meter: MgWidgets.ParMeter
var _meter_box: VBoxContainer
var _buttons: HBoxContainer
var _board_holder: Control
var _flash: ColorRect
var _result: Control
var _content: Control
var _finish_at := -1.0
var _last_emit := -10.0
var _t := 0.0
var _skip := false
var _glow_col := Color(0.5, 0.6, 1.0)


func _init() -> void:
	name = "MinigameScreen"
	theme = UiTheme.get_theme()
	UiTheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiTheme.full_rect(_content))
	ribbon = Ribbon.make("", 42, UiPalette.GOLD)
	_content.add_child(ribbon)
	_hint = UiTheme.para("", 22, UiPalette.TEXT_DIM, 600)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(_hint)
	_stats = UiTheme.hbox(12)
	_stats.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(_stats)
	var a := _pill("DIGS", "7")
	_act_unit = a[0]
	_act_num = a[1]
	var s := _pill("SCORE", "0")
	_score_num = s[1]
	_status_pill = UiTheme.panel("pill")
	_status = UiTheme.label("", 22, UiPalette.GOLD_BRIGHT, true, 5)
	_status_pill.add_child(_status)
	_stats.add_child(_status_pill)
	_meter_box = UiTheme.vbox(0)
	_content.add_child(_meter_box)
	_meter = MgWidgets.ParMeter.new()
	_meter_box.add_child(_meter)
	_board_holder = Control.new()
	_board_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_board_holder)
	_buttons = UiTheme.hbox(16)
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(_buttons)
	auto_btn = GameButton.make("AUTO", "auto", GameButton.Kind.SECONDARY, 30)
	auto_btn.sub_text = "take par"
	auto_btn.custom_minimum_size = Vector2(190, 84)
	auto_btn.pressed.connect(func() -> void:
		if _open and not _in_result:
			auto_requested.emit())
	_buttons.add_child(auto_btn)
	drop_btn = GameButton.make("DROP!", "", GameButton.Kind.PRIMARY, 40)
	drop_btn.custom_minimum_size = Vector2(250, 84)
	drop_btn.pressed.connect(func() -> void:
		if board is ClawBoard:
			(board as ClawBoard).drop())
	_buttons.add_child(drop_btn)
	_result = Control.new()
	_result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result.visible = false
	add_child(UiTheme.full_rect(_result))
	_flash = ColorRect.new()
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	add_child(UiTheme.full_rect(_flash))
	resized.connect(_layout)


func _pill(unit: String, value: String) -> Array:
	var p := UiTheme.panel("pill")
	var row := UiTheme.hbox(8)
	p.add_child(row)
	var u := UiTheme.label(unit, 20, UiPalette.TEXT_DIM, false, 0, false, 700)
	row.add_child(u)
	var n := UiTheme.label(value, 34, UiPalette.TEXT, true, 6)
	row.add_child(n)
	_stats.add_child(p)
	return [u, n]


func is_open() -> bool:
	return _open


func in_result() -> bool:
	return _in_result


# --- lifecycle -------------------------------------------------------------------------

func _ensure(id: String, title: String) -> void:
	if board != null and game_id == id:
		return
	if board != null:
		board.queue_free()
	game_id = id
	match id:
		"bubble_breaker": board = BubbleBoard.new()
		"scratch_off": board = ScratchBoard.new()
		"claw_machine": board = ClawBoard.new()
		"bubble_shooter": board = ShooterBoard.new()
		"plinko": board = PlinkoBoard.new()
		"shell_game": board = ShellBoard.new()
		"memory_match": board = MemoryBoard.new()
		"fishing": board = FishingBoard.new()
		"lucky_wheel": board = WheelBoard.new()
		"high_low": board = LadderBoard.new()
		_: board = FossilBoard.new()
	board.name = "Board"
	_board_holder.add_child(board)
	board.act.connect(func(args: Array) -> void: action.emit(args))
	board.kick.connect(_on_kick)
	_glow_col = MgLogic.GAME_COLORS.get(id, UiPalette.GOLD)
	ribbon.text = title.to_upper()
	ribbon.color = _glow_col.darkened(0.15)
	_hint.text = MgLogic.HINTS.get(id, "")
	_act_unit.text = MgLogic.UNITS.get(id, "MOVES")
	drop_btn.visible = id == "claw_machine"
	_layout()


## minigame_started: builds the game and plays the intro (awaitable).
func open_game(ev: Dictionary) -> void:
	_ensure(String(ev.get("id", "")), String(ev.get("name", "")))
	board.speed = speed
	board.set_state(ev.get("state", {}), true)
	_update_stats(ev.get("state", {}), false)
	_show()
	_content.modulate.a = 0.0
	var b := board
	b.pivot_offset = b.size * 0.5
	b.scale = Vector2(0.8, 0.8)
	ribbon.pivot_offset = ribbon.size * 0.5
	ribbon.scale = Vector2(1.6, 1.6)
	var t := create_tween().set_parallel(true)
	t.tween_property(_content, "modulate:a", 1.0, 0.2 / speed)
	t.tween_property(b, "scale", Vector2.ONE, 0.45 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(ribbon, "scale", Vector2.ONE, 0.35 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	MgBoard.sfx("open")
	await t.finished


## Restores the screen instantly (a run loaded in phase MINIGAME, scenarios).
func show_now(flow: GameFlow) -> void:
	var o := flow.offer
	_ensure(String(o.get("id", "")), String(o.get("name", "")))
	board.speed = speed
	board.set_state(o.get("state", {}), true)
	_update_stats(o.get("state", {}), false)
	_show()


func _show() -> void:
	visible = true
	_open = true
	_in_result = false
	_result.visible = false
	_finish_at = -1.0
	_content.modulate.a = 1.0
	auto_btn.set_enabled(true)
	_layout()


func close() -> void:
	if not _open and not visible:
		return
	_open = false
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.25 / speed)
	await t.finished
	if not _open:
		visible = false
		_result.visible = false
		_in_result = false
		modulate.a = 1.0


## Idle in phase MINIGAME: adopt the offer's state (a no-op when the board already shows it).
func refresh(flow: GameFlow) -> void:
	_flow = flow
	var o := flow.offer
	if String(o.get("kind", "")) != "minigame":
		return
	_ensure(String(o.get("id", "")), String(o.get("name", "")))
	board.speed = speed
	var st: Dictionary = o.get("state", {})
	if JSON.stringify(st) != JSON.stringify(board.state):
		board.set_state(st, true)
	else:
		board.unlock()
	_update_stats(st, false)


func play_update(ev: Dictionary) -> void:
	if board == null:
		return
	board.speed = speed
	await board.play_update(ev)
	_update_stats(ev.get("state", {}), true)


func _update_stats(st: Dictionary, animate: bool) -> void:
	var left := str(int(st.get("actions_left", 0)))
	var sc := str(int(float(st.get("score", 0.0))))
	if animate and _act_num.text != left:
		UiTheme.pop(_act_num, 1.35, 0.25)
	if animate and _score_num.text != sc:
		UiTheme.pop(_score_num, 1.4, 0.3)
	_act_num.text = left
	_act_num.label_settings = UiTheme.label_settings(34, UiPalette.HP_BRIGHT if int(left) <= 1 else UiPalette.TEXT, true, 6)
	_score_num.text = sc
	var med := float(MinigameDefs.MEDIAN.get(game_id, 1.0))
	_meter.set_value(float(st.get("score", 0.0)) / med, animate)
	var s := board.status_text() if board else ""
	_status.text = s
	_status_pill.visible = s != ""


func _process(dt: float) -> void:
	_t += dt
	if not visible:
		return
	queue_redraw()
	if board and board is ClawBoard:
		drop_btn.set_enabled(not board.locked and _open and not _in_result)
	if not _open or _in_result or board == null or _flow == null:
		return
	if _flow.phase != GameFlow.Phase.MINIGAME:
		return
	var st := board.state
	var over := bool(st.get("done", false)) or int(st.get("actions_left", 0)) <= 0
	if over and board.is_settled():
		if _finish_at < 0.0:
			_finish_at = _t + 0.8 / speed
			auto_btn.set_enabled(false)
		elif _t >= _finish_at and _t - _last_emit > 0.4:
			_last_emit = _t
			finish_requested.emit()
	else:
		_finish_at = -1.0


func _on_kick(strength: float, col: Color) -> void:
	_flash.color = Color(col.r, col.g, col.b, col.a * clampf(strength, 0.0, 1.0))
	var t := create_tween()
	t.tween_property(_flash, "color:a", 0.0, 0.35)
	if strength >= 0.5 and board:
		var b := board
		var p := b.position
		var k := create_tween()
		for i in 4:
			k.tween_property(b, "position", p + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 10.0 * strength, 0.035)
		k.tween_property(b, "position", p, 0.05)


# --- results beat ----------------------------------------------------------------------

## minigame_result: medal stamp, score, par meter and Crowns; holds, then closes.
func play_result(ev: Dictionary) -> void:
	if board == null:
		_ensure(String(ev.get("id", "")), MinigameDefs.name_of(String(ev.get("id", ""))))
	_show_if_hidden()
	_in_result = true
	auto_btn.set_enabled(false)
	var tier := String(ev.get("tier", "silver"))
	var col: Color = MgLogic.TIER_COLORS.get(tier, UiPalette.GOLD)
	var auto := bool(ev.get("auto", false))
	UiTheme.clear(_result)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_skip = true)
	_result.add_child(UiTheme.full_rect(dim))
	var vs := size
	var w := minf(560.0, vs.x - 48.0)
	var card := UiTheme.panel("main")
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size.x = w
	_result.add_child(card)
	var col_box := UiTheme.vbox(10)
	col_box.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(col_box)
	var medal := MgWidgets.Medal.new()
	medal.tier = tier
	medal.custom_minimum_size = Vector2(170, 190)
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col_box.add_child(medal)
	var title := UiTheme.label(MgLogic.tier_label(tier), 64, col, true, 12, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col_box.add_child(title)
	var game := UiTheme.label(MinigameDefs.name_of(String(ev.get("id", game_id))).to_upper(), 20, UiPalette.TEXT_MUTED, false, 0, false, 700)
	game.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col_box.add_child(game)
	var med := float(MinigameDefs.MEDIAN.get(String(ev.get("id", game_id)), 1.0))
	var score := float(ev.get("score", 0.0))
	var line := "AUTO took the par result" if auto else "Score %d   ·   Median %d" % [int(score), int(med)]
	var sub := UiTheme.label(line, 28, UiPalette.TEXT, false, 0, false, 700)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col_box.add_child(sub)
	var meter := MgWidgets.ParMeter.new()
	meter.custom_minimum_size = Vector2(w - 90.0, 62)
	meter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col_box.add_child(meter)
	var crow := UiTheme.hbox(10)
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	col_box.add_child(crow)
	crow.add_child(UiIcons.rect("crown", 40))
	var cl := UiTheme.label("+%d Crown%s" % [int(ev.get("crowns", 0)), "" if int(ev.get("crowns", 0)) == 1 else "s"], 32, UiPalette.GOLD_BRIGHT, true, 6)
	crow.add_child(cl)
	var tap := UiTheme.label("Tap to continue", 20, UiPalette.TEXT_MUTED, false, 0, false, 600)
	tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col_box.add_child(tap)
	_result.visible = true
	await get_tree().process_frame
	card.reset_size()
	card.position = (vs - card.size) * 0.5
	card.pivot_offset = card.size * 0.5
	medal.pivot_offset = medal.custom_minimum_size * 0.5
	# the beat
	_skip = false
	card.modulate.a = 0.0
	card.scale = Vector2(0.85, 0.85)
	medal.scale = Vector2(2.6, 2.6)
	medal.modulate.a = 0.0
	title.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(dim, "color:a", 0.55, 0.2 / speed)
	t.tween_property(card, "modulate:a", 1.0, 0.18 / speed)
	t.tween_property(card, "scale", Vector2.ONE, 0.3 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t.finished
	var m := create_tween().set_parallel(true)
	m.tween_property(medal, "scale", Vector2.ONE, 0.28 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	m.tween_property(medal, "modulate:a", 1.0, 0.12 / speed)
	await m.finished
	MgBoard.sfx("win" if tier == "gold" else ("coin" if tier == "silver" else "dice_select"))
	_on_kick(0.9 if tier == "gold" else 0.5, Color(col.r, col.g, col.b, 0.45))
	if tier == "gold":
		Fx.confetti(_result, card.position + Vector2(card.size.x * 0.5, 120), 34)
	var tt := create_tween()
	tt.tween_property(title, "modulate:a", 1.0, 0.15 / speed)
	UiTheme.pop(title, 1.25, 0.3)
	meter.set_value(float(ev.get("ratio", 0.0)), true, 0.7 / speed)
	UiTheme.pop(cl, 1.3, 0.35)
	var hold := float(get_meta("hold", 2.2)) / speed
	var el := 0.0
	while el < hold and not _skip and is_inside_tree():
		await get_tree().process_frame
		el += get_process_delta_time()
	await close()


func _show_if_hidden() -> void:
	if not visible or not _open:
		_show()


# --- layout ----------------------------------------------------------------------------

func _layout() -> void:
	var vs := size
	if vs.x <= 0.0:
		return
	var safe := UiTheme.safe_margins(self)
	var land := vs.x > vs.y * 1.1
	var top := safe.top + 6.0
	ribbon.reset_size()
	var rs := ribbon.get_combined_minimum_size()
	ribbon.size = rs
	var board_r: Rect2
	var side_ctl: Array[Control] = [ribbon, _hint, _stats, _meter_box, _buttons]
	if land:
		# board square on the left, the info column beside it (scaled up a notch: the
		# landscape canvas is wider); the pair is centred
		var side := minf(vs.y - top - safe.bottom - 90.0, vs.x * 0.56)
		var col_w := minf(900.0, vs.x - side - safe.left - safe.right - 80.0)
		var k := clampf(col_w / 560.0, 1.0, 1.55)
		var cw := col_w / k
		var x0 := (vs.x - side - 60.0 - col_w) * 0.5
		board_r = Rect2(Vector2(x0, (vs.y - side) * 0.5 + 6.0), Vector2(side, side))
		var cx := x0 + side + 60.0
		for ctl in side_ctl:
			ctl.scale = Vector2(k, k)
		_hint.custom_minimum_size = Vector2(cw, 0)
		_hint.size = Vector2(cw, 0)
		var hint_h := _hint.get_combined_minimum_size().y
		var total := (rs.y + 10.0 + hint_h + 24.0 + 88.0 + 100.0 + 88.0) * k
		var y := maxf(top, (vs.y - total) * 0.5)
		ribbon.position = Vector2(cx + (col_w - rs.x * k) * 0.5, y)
		y += (rs.y + 10.0) * k
		_hint.position = Vector2(cx, y)
		y += (hint_h + 24.0) * k
		_stats.position = Vector2(cx, y)
		_stats.size = Vector2(cw, 64)
		y += 88.0 * k
		_meter_box.position = Vector2(cx + 10.0 * k, y)
		_meter_box.size = Vector2(cw - 20.0, 60)
		_meter.custom_minimum_size = Vector2(cw - 20.0, 60)
		y += 100.0 * k
		_buttons.position = Vector2(cx, y)
		_buttons.size = Vector2(cw, 88)
	else:
		for ctl in side_ctl:
			ctl.scale = Vector2.ONE
		ribbon.position = Vector2((vs.x - rs.x) * 0.5, top)
		var y := top + rs.y + 2.0
		var hw := minf(vs.x - 60.0, 640.0)
		_hint.custom_minimum_size = Vector2(hw, 0)
		_hint.size = Vector2(hw, 0)
		_hint.position = Vector2((vs.x - hw) * 0.5, y)
		y += _hint.get_combined_minimum_size().y + 12.0
		_stats.position = Vector2(0, y)
		_stats.size = Vector2(vs.x, 64)
		y += 78.0
		var mw := minf(vs.x - 80.0, 560.0)
		_meter_box.position = Vector2((vs.x - mw) * 0.5, y)
		_meter_box.size = Vector2(mw, 60)
		_meter.custom_minimum_size = Vector2(mw, 60)
		y += 70.0
		var by := vs.y - safe.bottom - 100.0
		_buttons.position = Vector2(0, by)
		_buttons.size = Vector2(vs.x, 88)
		board_r = Rect2(Vector2(safe.left + 8.0, y), Vector2(vs.x - safe.left - safe.right - 16.0, by - y - 12.0))
	_board_holder.position = board_r.position
	_board_holder.size = board_r.size
	if board:
		board.position = Vector2.ZERO
		board.size = board_r.size
		board.pivot_offset = board.size * 0.5


func _draw() -> void:
	# scrim over the board + a soft glow in the game's colour behind the play area
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.07, 0.86))
	var c := _board_holder.position + _board_holder.size * 0.5
	var r := maxf(_board_holder.size.x, _board_holder.size.y) * 0.7
	for k in 8:
		var col := _glow_col
		col.a = 0.035 * (8 - k) * (0.85 + 0.15 * sin(_t * 1.5))
		draw_circle(c, r * (0.35 + k * 0.09), col)
