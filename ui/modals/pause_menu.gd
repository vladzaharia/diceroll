class_name PauseMenu
extends UiModal
## Pause: Resume, Settings, Abandon run (with an inline confirm step).
## Emits resume_pressed, settings_pressed, abandon_confirmed.

signal resume_pressed
signal settings_pressed
signal abandon_confirmed

var _info: Label
var _main: VBoxContainer
var _confirm: VBoxContainer


func _build() -> void:
	set_title("PAUSED")
	max_width = 560.0
	_info = UiTheme.label("", 24, UiPalette.TEXT_DIM, false, 0, false, 600)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_info)
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
	var abandon := GameButton.make("ABANDON RUN", "flag", GameButton.Kind.DANGER, 28)
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
	_info.text = "%s  ·  Act %d  ·  Lap %d/%d  ·  Level %d" % [HeroDefs.DATA[r.class_id].name, r.act, r.lap, Balance.LAPS_PER_ACT, r.level]
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
