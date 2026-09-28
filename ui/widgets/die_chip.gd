class_name DieChip
extends BaseButton
## Tappable card for one die of the pool: rune socket + name and all six faces as mini
## DieFaces (edited faces rimmed gold). Used by rune assign, shop die picker and forge.
##
##   var chip := DieChip.make(run.dice[2], 2)
##   chip.pressed.connect(func(): pick(chip.die_idx))

var die_idx := -1
var selected := false:
	set(v):
		selected = v
		queue_redraw()
		if is_inside_tree():
			UiTheme.pop(self, 1.05, 0.2)
var faces: Array[DieFace] = []
var _hover := false
var _compact := false


static func make(die: Die, idx: int, compact := false) -> DieChip:
	var c := DieChip.new()
	c.die_idx = idx
	c._compact = compact
	c.focus_mode = Control.FOCUS_NONE
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c._build(die)
	return c


func _build(die: Die) -> void:
	var m := UiTheme.margin(null, 14, 12, 14, 14)
	UiTheme.full_rect(m)
	add_child(m)
	var col := UiTheme.vbox(8)
	m.add_child(col)
	var head := UiTheme.hbox(8)
	col.add_child(head)
	head.add_child(RuneBadge.make(die.rune, 36))
	var kname := String(DiceKinds.def(die.kind).name)
	var name := "%s %d" % [kname if die.kind != "standard" else "Die", die_idx + 1]
	var sub := "No rune" if die.rune == "" else String(Runes.DEFS[die.rune].name)
	var names := UiTheme.vbox(-6)
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(names)
	names.add_child(UiTheme.label(name, 22, UiPalette.kind_color(die.kind).lightened(0.35) if die.kind != "standard" else UiPalette.TEXT, true, 0))
	names.add_child(UiTheme.label(sub, 18, UiPalette.rune_color(die.rune) if die.rune != "" else UiPalette.TEXT_MUTED, false, 0, false, 600))
	var grid := GridContainer.new()
	grid.columns = 6 if _compact else 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(grid)
	for i in 6:
		var f := DieFace.make(die.faces[i], die.rune, die.edited[i] == 1, 40)
		f.star = false
		f.kind = die.kind

		grid.add_child(f)
		faces.append(f)
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw())
	pressed.connect(func() -> void: UiTheme.sfx("dice_select"))
	resized.connect(func() -> void: pivot_offset = size * 0.5)


func _get_minimum_size() -> Vector2:
	var c := get_child(0) as Control if get_child_count() > 0 else null
	return c.get_combined_minimum_size() if c else Vector2(160, 120)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if selected:
		draw_style_box(UiTheme.box(Color(0, 0, 0, 0), 22, 0, Color.TRANSPARENT, 18, Color(1.0, 0.75, 0.25, 0.45), Vector2.ZERO), rect)
		draw_style_box(UiTheme.box(UiPalette.NAVY_3, 22, 4, UiPalette.GOLD_BRIGHT), rect)
	else:
		var bg := UiPalette.NAVY_2.lightened(0.06) if _hover and not disabled else UiPalette.NAVY_2
		draw_style_box(UiTheme.box(bg, 22, 2, Color(1, 1, 1, 0.1), 8, Color(0, 0, 0, 0.3), Vector2(0, 4)), rect)
	if disabled:
		draw_style_box(UiTheme.box(Color(0.02, 0.02, 0.06, 0.55), 22), rect)
