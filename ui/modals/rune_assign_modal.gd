class_name RuneAssignModal
extends UiModal
## Pick which die receives a rune (offer {kind:"rune_assign", rune}). Shows the rune, then
## every die as a DieChip (faces + current rune). Emits rune_assign(die_idx).

signal rune_assign(die_idx: int)

var _hero: PanelContainer
var _grid: GridContainer
var _note: Label
var _bind: GameButton
var _chips: Array[DieChip] = []
var _rune := ""
var _dice: Array[Die] = []
var _choice := -1


func _build() -> void:
	ScrollFade.attach(self, _scroll, UiPalette.NAVY_2, _frame)
	_hero = PanelContainer.new()
	_hero.add_theme_stylebox_override("panel", UiTheme.panel_box("inset"))
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_hero)
	body.add_child(UiModal.section_label("Choose a die"))
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(_grid)
	_note = UiTheme.label(" ", 22, UiPalette.TEXT_DIM, false, 0, false, 600)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_note)
	body.add_child(UiModal.action_gap())
	_bind = GameButton.make("BIND RUNE", "check", GameButton.Kind.SUCCESS, 38)
	_bind.icon_tint = UiPalette.TEXT_DARK
	_bind.pressed.connect(func() -> void:
		if _choice >= 0:
			rune_assign.emit(_choice))
	body.add_child(_bind)
	# forced (spec 3.2): the core has no "discard the rune" command, so there is no close /
	# Esc; BIND RUNE is the decision (Enter)
	primary_action = _bind


func refresh(flow: GameFlow) -> void:
	_rune = String(flow.offer.get("rune", "blade"))
	_dice = flow.run.dice
	var def: Dictionary = Runes.DEFS.get(_rune, {"name": _rune, "desc": ""})
	set_title("BIND %s" % String(def.name).to_upper(), PLAQUE_DEFAULT)
	UiTheme.clear(_hero)
	# the rune card: a card with a rim in the rune's colour (spec 4.3)
	_hero.add_theme_stylebox_override("panel", UiTheme.tile_box("normal", UiPalette.rune_color(_rune)))
	var row := UiTheme.hbox(18)
	_hero.add_child(row)
	row.add_child(RuneBadge.make(_rune, 96))
	var col := UiTheme.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	var rarity := Runes.rarity(_rune) if Runes.DEFS.has(_rune) else "common"
	var nr := UiTheme.hbox(10)
	col.add_child(nr)
	nr.add_child(UiTheme.label("%s Rune" % def.name, 34, UiPalette.rune_color(_rune).lightened(0.2), true, 6))
	var tp := PanelContainer.new()
	tp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tag := UiTheme.label(rarity.to_upper(), 16, UiPalette.TEXT, false, 0, false, 700)
	tp.add_child(tag)
	OptionCard.style_tag(tp, tag, UiPalette.rarity_color(rarity))
	nr.add_child(tp)
	col.add_child(UiTheme.para(String(def.desc), 24, UiPalette.TEXT, 500))
	_grid.columns = grid_columns(3, ShopModal.DIE_CHIP_W)
	UiTheme.clear(_grid)
	_chips.clear()
	for i in _dice.size():
		var chip := DieChip.make(_dice[i], i)
		chip.pressed.connect(select.bind(i))
		_grid.add_child(chip)
		_chips.append(chip)
	_choice = -1
	_bind.set_enabled(false)
	_note.text = "Tap a die. Its current rune will be replaced."
	relayout()


func select(i: int) -> void:
	_choice = i
	for k in _chips.size():
		_chips[k].selected = k == i
	var old := _dice[i].rune
	if old == "":
		_note.text = "Die %d gets the %s rune." % [i + 1, Runes.DEFS[_rune].name]
	elif old == _rune:
		_note.text = "Die %d already has %s." % [i + 1, Runes.DEFS[_rune].name]
	else:
		_note.text = "Replaces %s on die %d." % [Runes.DEFS[old].name, i + 1]
	_bind.set_enabled(true)
