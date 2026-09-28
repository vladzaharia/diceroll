class_name PauseMenu
extends UiModal
## Pause: run info (class, biome, lap N/15 with a 15-lap track split by biome, level, the
## passives owned), Resume, Settings, Abandon run (with an inline confirm step).
## Emits resume_pressed, settings_pressed, abandon_confirmed.

signal resume_pressed
signal settings_pressed
signal abandon_confirmed

var _info: Label
var _track: HBoxContainer
var _passives: HFlowContainer
var _main: VBoxContainer
var _confirm: VBoxContainer


func _build() -> void:
	set_title("PAUSED")
	max_width = 560.0
	_info = UiTheme.label("", 24, UiPalette.TEXT_DIM, false, 0, false, 600)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_info)
	_track = UiTheme.hbox(14)
	_track.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(_track)
	_passives = HFlowContainer.new()
	_passives.alignment = FlowContainer.ALIGNMENT_CENTER
	_passives.add_theme_constant_override("h_separation", 8)
	_passives.add_theme_constant_override("v_separation", 8)
	_passives.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_passives)
	_main = UiTheme.vbox(16)
	body.add_child(_main)
	var resume := GameButton.make("RESUME", "arrow_right", GameButton.Kind.PRIMARY, 38)
	resume.icon_tint = UiPalette.TEXT_DARK
	resume.pressed.connect(func() -> void: resume_pressed.emit())
	_main.add_child(resume)
	var settings := GameButton.make("SETTINGS", "gear", GameButton.Kind.SECONDARY, 32)
	settings.icon_tint = UiPalette.GOLD
	settings.pressed.connect(func() -> void: settings_pressed.emit())
	_main.add_child(settings)
	_main.add_child(UiTheme.spacer(6))
	var abandon := GameButton.make("ABANDON RUN", "flag", GameButton.Kind.DANGER, 26)
	abandon.min_height = 88
	abandon.icon_tint = UiPalette.TEXT
	abandon.pressed.connect(_ask)
	_main.add_child(abandon)
	_confirm = UiTheme.vbox(16)
	_confirm.visible = false
	body.add_child(_confirm)
	var q := UiTheme.label("Abandon this run?", 34, UiPalette.TEXT, true, 0, true)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm.add_child(q)
	var w := UiTheme.para("Your hero falls here. The run ends and its save is deleted.", 24, UiPalette.TEXT_DIM)
	w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm.add_child(w)
	var row := UiTheme.hbox(14)
	_confirm.add_child(row)
	var back := GameButton.make("KEEP PLAYING", "", GameButton.Kind.SECONDARY, 28)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(_unask)
	row.add_child(back)
	var yes := GameButton.make("ABANDON", "skull", GameButton.Kind.DANGER, 28)
	yes.icon_tint = UiPalette.TEXT
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.pressed.connect(func() -> void: abandon_confirmed.emit())
	row.add_child(yes)


func refresh(flow: GameFlow) -> void:
	var r := flow.run
	var biome := String(SummaryScreen.ACT_NAMES[clampi(r.act - 1, 0, 2)])
	_info.text = "%s  ·  %s  ·  Lap %d/%d  ·  Level %d" % [HeroDefs.DATA[r.class_id].name, biome, r.lap, Balance.TOTAL_LAPS, r.level]
	UiTheme.clear(_track)
	for a in Balance.ACTS:
		var group := UiTheme.vbox(4)
		_track.add_child(group)
		var pips := UiTheme.hbox(4)
		group.add_child(pips)
		var first := int(Balance.BIOME_LAPS[a])
		for k in Balance.LAPS_PER_ACT:
			var n := first + k
			var dot := HudTop._Pip.new()
			dot.state = 2 if n < r.lap else (1 if n == r.lap else 0)
			dot.color = HudTop.BIOME_COLORS[a]
			dot.boss = n == Balance.TOTAL_LAPS
			dot.custom_minimum_size = Vector2(18, 18)
			pips.add_child(dot)
		var nm := UiTheme.label(String(SummaryScreen.ACT_NAMES[a]).to_upper(), 14,
			HudTop.BIOME_COLORS[a] if a + 1 == r.act else UiPalette.TEXT_MUTED, false, 0, false, 800)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		group.add_child(nm)
	UiTheme.clear(_passives)
	for id in r.passives:
		var p := PassiveIcon.make(String(id), 48, true)
		_passives.add_child(p)
	_passives.visible = not r.passives.is_empty()
	_unask()


func open() -> void:
	_unask()
	super.open()


func _ask() -> void:
	_main.visible = false
	_confirm.visible = true
	set_title("ABANDON?", UiPalette.DANGER)
	relayout()


func _unask() -> void:
	_main.visible = true
	_confirm.visible = false
	set_title("PAUSED", UiPalette.GOLD)
	relayout()
