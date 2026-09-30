class_name PauseMenu
extends UiModal
## Pause: run info (class, biome, lap N/15, level), the run's route (three biomes with lap
## pips, mini-boss and final boss), the Armory loadout (items with their tiers), the passives
## owned, Resume, Settings, Controls, Abandon run (with an inline confirm step).
## One exit (spec 3.2): RESUME (Enter / Esc), no close button; the abandon confirm keeps its
## explicit KEEP PLAYING (Esc / Enter) next to ABANDON.
## Emits resume_pressed, settings_pressed, controls_pressed, abandon_confirmed.

signal resume_pressed
signal settings_pressed
signal abandon_confirmed
## CONTROLS (desktop): opens Settings scrolled to the Controls list.
signal controls_pressed

var _info: Label
var _track: HBoxContainer
var _passives: HFlowContainer
var _kit: VBoxContainer
var _main: VBoxContainer
var _confirm: VBoxContainer
var _resume: GameButton
var _keep: GameButton
var _controls: GameButton


func _build() -> void:
	ScrollFade.attach(self, _scroll, UiPalette.NAVY_2, _frame)
	set_title("PAUSED")
	max_width = 560.0
	_info = UiTheme.label("", 24, UiPalette.TEXT_DIM, false, 0, false, 600)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_info)
	_track = UiTheme.hbox(14)
	_track.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(_track)
	_kit = UiTheme.vbox(4)
	body.add_child(_kit)
	_passives = HFlowContainer.new()
	_passives.alignment = FlowContainer.ALIGNMENT_CENTER
	_passives.add_theme_constant_override("h_separation", 8)
	_passives.add_theme_constant_override("v_separation", 8)
	_passives.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_passives)
	_main = UiTheme.vbox(16)
	body.add_child(_main)
	# one exit (spec 3.2): RESUME is the main choice (full width, Enter / Esc); no close button
	_resume = GameButton.make("RESUME", "arrow_right", GameButton.Kind.PRIMARY, 38)
	_resume.icon_tint = UiPalette.TEXT_DARK
	_resume.pressed.connect(func() -> void: resume_pressed.emit())
	_main.add_child(_resume)
	# the rest are normal-width: SETTINGS, CONTROLS (desktop), ABANDON RUN
	var more := HFlowContainer.new()
	more.alignment = FlowContainer.ALIGNMENT_CENTER
	more.add_theme_constant_override("h_separation", 12)
	more.add_theme_constant_override("v_separation", 12)
	_main.add_child(more)
	var settings := GameButton.make("SETTINGS", "gear", GameButton.Kind.SECONDARY, 26)
	settings.min_height = 80
	settings.pad_x = 20
	settings.pressed.connect(func() -> void: settings_pressed.emit())
	more.add_child(settings)
	_controls = GameButton.make("CONTROLS", "", GameButton.Kind.SECONDARY, 26)
	_controls.min_height = 80
	_controls.pad_x = 20
	_controls.shortcut_hint = "key_f1"
	_controls.visible = InputMode.platform_default_kbm()
	_controls.pressed.connect(func() -> void: controls_pressed.emit())
	more.add_child(_controls)
	var abandon := GameButton.make("ABANDON RUN", "flag", GameButton.Kind.DANGER, 26)
	abandon.min_height = 80
	abandon.pad_x = 20
	abandon.pressed.connect(_ask)
	more.add_child(abandon)
	_confirm = UiTheme.vbox(16)
	_confirm.visible = false
	body.add_child(_confirm)
	var q := UiTheme.label("Abandon this run?", 34, UiPalette.TEXT, true, 0, true)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm.add_child(q)
	var w := UiTheme.para("Your hero falls here. The run ends and its save is deleted.", 24, UiPalette.TEXT_DIM)
	w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm.add_child(w)
	# confirm dialog (spec 3.2): no close button; KEEP PLAYING (Esc / Enter: the safe option)
	# and ABANDON are the two exits, both normal width
	var row := UiTheme.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_confirm.add_child(row)
	_keep = GameButton.make("KEEP PLAYING", "", GameButton.Kind.SECONDARY, 28)
	_keep.pressed.connect(_unask)
	row.add_child(_keep)
	var yes := GameButton.make("ABANDON", "flag", GameButton.Kind.DANGER, 28)
	yes.pressed.connect(func() -> void: abandon_confirmed.emit())
	row.add_child(yes)


func refresh(flow: GameFlow) -> void:
	var r := flow.run
	var biome := BiomeDefs.name_of(r.biome())
	_info.text = "%s  ·  %s  ·  Lap %d/%d  ·  Level %d" % [HeroDefs.DATA[r.class_id].name, biome, r.lap, Balance.TOTAL_LAPS, r.level]
	# this run's route: the three biomes with lap pips, and the two bosses ahead
	UiTheme.clear(_track)
	_track.add_child(RouteStrip.make(flow.route_info(), r.act, r.lap, true))
	UiTheme.clear(_kit)
	var strip := KitStrip.of_run(r, 58)
	if not strip.entries.is_empty():
		_kit.add_child(strip)
		var names := UiTheme.para(strip.names_text(), 16, UiPalette.TEXT_MUTED, 600)
		names.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_kit.add_child(names)
	else:
		strip.free()
	_kit.visible = _kit.get_child_count() > 0
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
	primary_action = _keep
	cancel_action = _keep
	set_title("ABANDON?", "red")
	relayout()


func _unask() -> void:
	_main.visible = true
	_confirm.visible = false
	primary_action = _resume
	cancel_action = _resume
	set_title("PAUSED", "yellow")
	relayout()
