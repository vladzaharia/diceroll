class_name HudTop
extends Control
## Shared top HUD: level/XP medallion, HP bar (+ hero block shield), gold, treasury,
## act/lap chip and the pause button. Anchored to the top edge inside the safe area;
## centred and width-capped in landscape.

signal pause_pressed

const MAX_W := 980.0
const ROMAN := ["I", "II", "III", "IV"]

var level_badge: LevelBadge
var hp_bar: StatBar
var gold: Counter
var treasury: Counter
var pause_btn: GameButton
var act_label: Label
var lap_pips: HBoxContainer
var block_badge: Control
var _block_label: Label
var _row: HBoxContainer
var _scrim: TextureRect
var _hp_wrap: Control
var _block := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.full_rect(self)
	_scrim = TextureRect.new()
	_scrim.texture = UiTheme.vgradient(Color(0.02, 0.02, 0.07, 0.6), Color(0.02, 0.02, 0.07, 0.0))
	_scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_scrim.stretch_mode = TextureRect.STRETCH_SCALE
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scrim)
	_row = UiTheme.hbox(14)
	add_child(_row)
	level_badge = LevelBadge.make(100)
	_row.add_child(level_badge)

	var mid := UiTheme.vbox(10)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_child(mid)
	# HP row: heart overlapping the bar's left end, block shield on the right end
	_hp_wrap = Control.new()
	_hp_wrap.custom_minimum_size = Vector2(200, 50)
	_hp_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(_hp_wrap)
	hp_bar = StatBar.make(UiPalette.HP, 44)
	hp_bar.text_size = 28
	_hp_wrap.add_child(hp_bar)
	var heart := UiIcons.rect("heart", 58)
	heart.name = "Heart"
	_hp_wrap.add_child(heart)
	block_badge = Control.new()
	block_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block_badge.custom_minimum_size = Vector2(62, 62)
	block_badge.visible = false
	_hp_wrap.add_child(block_badge)
	var sh := UiIcons.rect("shield", 62)
	block_badge.add_child(sh)
	_block_label = UiTheme.label("0", 26, UiPalette.TEXT, true, 6)
	_block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_block_label.size = Vector2(62, 56)
	block_badge.add_child(_block_label)
	_hp_wrap.resized.connect(_place_hp)

	var chips := UiTheme.hbox(10)
	mid.add_child(chips)
	gold = Counter.make("coin", 0, 28, UiPalette.TEXT)
	chips.add_child(gold)
	treasury = Counter.make("chest", 10, 22, UiPalette.GOLD_BRIGHT)
	treasury.tooltip_text = "Treasury bank: land on the Treasury corner to cash out."
	chips.add_child(treasury)

	var right := UiTheme.vbox(10)
	_row.add_child(right)
	pause_btn = GameButton.round_icon("pause", 88)
	pause_btn.icon_tint = UiPalette.TEXT
	pause_btn.kind = GameButton.Kind.GHOST
	pause_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	pause_btn.pressed.connect(func() -> void: pause_pressed.emit())
	right.add_child(pause_btn)

	var act := PanelContainer.new()
	act.add_theme_stylebox_override("panel", UiTheme.panel_box("pill"))
	act.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# act chip lives on the chips row, right aligned
	var fill := UiTheme.spacer(0, true)
	chips.add_child(fill)
	chips.add_child(act)
	var ar := UiTheme.hbox(10)
	act.add_child(ar)
	act_label = UiTheme.label("ACT I", 24, UiPalette.GOLD, true, 5)
	ar.add_child(act_label)
	lap_pips = UiTheme.hbox(5)
	lap_pips.alignment = BoxContainer.ALIGNMENT_CENTER
	ar.add_child(lap_pips)
	resized.connect(_layout)


func _ready() -> void:
	_layout()


func _layout() -> void:
	var view := size
	if view.x <= 0.0:
		return
	var safe := UiTheme.safe_margins(self)
	var w := minf(MAX_W, view.x - safe.left - safe.right)
	_row.position = Vector2((view.x - w) * 0.5, safe.top)
	_row.size = Vector2(w, 0)
	_row.reset_size()
	_row.size.x = w
	_scrim.position = Vector2.ZERO
	_scrim.size = Vector2(view.x, safe.top + _row.size.y + 90.0)


func _place_hp() -> void:
	var s := _hp_wrap.size
	hp_bar.position = Vector2(30, (s.y - 44) * 0.5)
	hp_bar.size = Vector2(s.x - 30 - (26.0 if block_badge.visible else 0.0), 44)
	var heart := _hp_wrap.get_node("Heart") as Control
	heart.position = Vector2(-4, (s.y - 58) * 0.5)
	heart.size = Vector2(58, 58)
	block_badge.position = Vector2(s.x - 62, (s.y - 62) * 0.5)
	block_badge.size = Vector2(62, 62)


## Full sync from the flow (no animation).
func refresh(flow: GameFlow, animate := false) -> void:
	var run := flow.run
	hp_bar.set_values(run.hp, run.max_hp, animate)
	gold.set_value(run.gold, animate)
	treasury.set_value(run.treasury, animate)
	var prev := Balance.xp_for_level(run.level - 1) if run.level > 1 else 0
	var need := Balance.xp_for_level(run.level)
	level_badge.set_level(run.level, float(run.xp - prev) / float(maxi(1, need - prev)), animate)
	act_label.text = "ACT " + ROMAN[clampi(run.act - 1, 0, 3)]
	_set_laps(run.lap)
	set_block(run.block if flow.phase == GameFlow.Phase.COMBAT else 0, animate)


func set_block(v: int, animate := false) -> void:
	var was := _block
	_block = v
	block_badge.visible = v > 0
	_block_label.text = str(v)
	_place_hp()
	if animate and v > was:
		UiTheme.pop(block_badge, 1.3, 0.3)


func _set_laps(lap: int) -> void:
	UiTheme.clear(lap_pips)
	for i in Balance.LAPS_PER_ACT:
		var dot := _Pip.new()
		dot.state = 2 if i + 1 < lap else (1 if i + 1 == lap else 0)
		dot.custom_minimum_size = Vector2(18, 18)
		lap_pips.add_child(dot)


## Animation hooks for gameplay events.
func on_event(ev: Dictionary, flow: GameFlow) -> void:
	match String(ev.get("type", "")):
		"gold_changed":
			gold.set_value(int(ev.total), true)
		"hp_changed":
			hp_bar.set_values(int(ev.total), int(ev.get("max_hp", flow.run.max_hp)), true)
		"damage":
			if str(ev.get("target", "")) == "hero":
				hp_bar.set_values(int(ev.get("hp", flow.run.hp)), int(ev.get("max_hp", flow.run.max_hp)), true)
				set_block(int(ev.get("block", flow.run.block)), false)
		"block_gained":
			if str(ev.get("target", "")) == "hero":
				set_block(flow.run.block, true)
		"combat_turn_started":
			set_block(0)
		"board_rolled":
			treasury.set_value(int(ev.get("treasury", flow.run.treasury)), true)
		"level_up", "combat_won":
			refresh(flow, true)
		"lap_completed", "act_started":
			refresh(flow, true)


class _Pip:
	extends Control
	## 0 = future, 1 = current, 2 = done
	var state := 0

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c, r, UiPalette.OUTLINE)
		match state:
			2:
				draw_circle(c, r - 2.5, UiPalette.GOLD)
			1:
				draw_circle(c, r - 2.5, UiPalette.GOLD_DEEP)
				draw_circle(c, r - 6.0, UiPalette.GOLD_BRIGHT)
			_:
				draw_circle(c, r - 2.5, Color(1, 1, 1, 0.12))
