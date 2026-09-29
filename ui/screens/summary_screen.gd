class_name SummaryScreen
extends UiModal
## Victory / Defeat run summary: headline, class + act reached, stat tiles from
## flow.run.stats, New Run / Title. Emits new_run_pressed, title_pressed.

signal new_run_pressed
signal title_pressed

const ACT_NAMES := ["The Crypt", "The Hollow", "The Bone Throne"]

var _hero: HBoxContainer
var _grid: GridContainer
var _passive_title: Label
var _passives: HFlowContainer
var _headline: Label
var _route: VBoxContainer


func _build() -> void:
	_headline = UiTheme.label("", 28, UiPalette.TEXT, true, 0, true)
	_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_headline)
	_hero = UiTheme.hbox(16)
	_hero.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(_hero)
	_route = UiTheme.vbox(0)
	body.add_child(_route)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	body.add_child(_grid)
	_passive_title = UiModal.section_label("Passives")
	body.add_child(_passive_title)
	_passives = HFlowContainer.new()
	_passives.alignment = FlowContainer.ALIGNMENT_CENTER
	_passives.add_theme_constant_override("h_separation", 8)
	_passives.add_theme_constant_override("v_separation", 8)
	_passives.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_passives)
	body.add_child(UiTheme.spacer(4))
	var row := UiTheme.hbox(14)
	body.add_child(row)
	var title := GameButton.make("TITLE", "home", GameButton.Kind.SECONDARY, 30)
	title.icon_tint = UiPalette.GOLD
	title.pressed.connect(func() -> void: title_pressed.emit())
	row.add_child(title)
	var again := GameButton.make("NEW RUN", "dice", GameButton.Kind.PRIMARY, 36)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(func() -> void: new_run_pressed.emit())
	row.add_child(again)


func refresh(flow: GameFlow) -> void:
	var r := flow.run
	var st := r.stats
	var won := flow.phase == GameFlow.Phase.VICTORY or bool(st.get("victory", false))
	set_title("VICTORY!" if won else "DEFEATED", UiPalette.GOLD if won else UiPalette.DANGER)
	var info := flow.route_info()
	var boss_name := String(info.boss.name)
	var last := BiomeDefs.name_of(String(r.route[2])) if r.route.size() >= 3 else String(ACT_NAMES[2])
	_headline.text = ("%s has fallen. %s is yours." % [boss_name, last]) if won \
		else "Fallen on lap %d of %d, in %s." % [r.lap, Balance.TOTAL_LAPS, BiomeDefs.name_of(r.biome())]
	_headline.label_settings = UiTheme.label_settings(28, UiPalette.GOLD_BRIGHT if won else UiPalette.TEXT, true, 0, UiPalette.OUTLINE, true)
	UiTheme.clear(_hero)
	var cls: Dictionary = HeroDefs.DATA.get(r.class_id, HeroDefs.DATA.knight)
	_hero.add_child(OptionCard.Medallion.make(UiIcons.class_icon(r.class_id), 88, null, UiPalette.GOLD if won else UiPalette.DANGER))
	var col := UiTheme.vbox(0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_hero.add_child(col)
	col.add_child(UiTheme.label(String(cls.name), 40, UiPalette.TEXT, true, 6))
	col.add_child(UiTheme.label("Level %d  ·  Lap %d/%d  ·  %d dice" % [r.level, r.lap, Balance.TOTAL_LAPS, r.dice.size()], 22, UiPalette.TEXT_DIM, false, 0, false, 600))
	UiTheme.clear(_route)
	var strip := RouteStrip.make(info, 0 if won else r.act, 0, true)
	strip.beaten.boss = won
	strip._rebuild()
	_route.add_child(strip)
	UiTheme.clear(_grid)
	var best := String(st.get("best_combo", ""))
	var bm := float(st.get("best_mult", 0.0))
	var tiles := [
		["sword", "Fights won", str(int(st.get("fights_won", 0)))],
		["flame", "Damage dealt", _num(int(st.get("damage_dealt", 0)))],
		["heart", "Damage taken", _num(int(st.get("damage_taken", 0)))],
		["coin", "Gold earned", _num(int(st.get("gold_earned", 0)))],
		["star", "Best combo", ("%s ×%s" % [best, CombatHud._fmt(bm)]) if best != "" else "None"],
		["dice", "Board turns", str(int(st.get("board_turns", 0)))],
	]
	for t in tiles:
		_grid.add_child(_tile(t[0], t[1], t[2]))
	UiTheme.clear(_passives)
	for id in r.passives:
		_passives.add_child(PassiveIcon.make(String(id), 56, true))
	_passive_title.text = "PASSIVES (%d)" % r.passives.size()
	_passive_title.visible = not r.passives.is_empty()
	_passives.visible = not r.passives.is_empty()
	relayout()



static func _num(n: int) -> String:
	var s := str(n)
	if n >= 1000:
		s = "%d,%03d" % [n / 1000, n % 1000]
	return s


func _tile(icon: String, label: String, value: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(UiPalette.NAVY_2, 20, 2, Color(1, 1, 1, 0.06)), 16, 12))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UiTheme.hbox(12)
	p.add_child(row)
	row.add_child(UiIcons.rect(icon, 44))
	var col := UiTheme.vbox(-2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var v := UiTheme.label(value, 30 if value.length() < 12 else 24, UiPalette.TEXT, true, 0)
	v.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.custom_minimum_size.x = 60
	col.add_child(v)
	col.add_child(UiTheme.label(label.to_upper(), 16, UiPalette.TEXT_MUTED, false, 0, false, 700))
	return p
