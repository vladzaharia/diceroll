class_name DieInspector
extends UiModal
## Die inspector (not a GameFlow phase; opened by tapping a die on the board): the die's kind
## (name, corner mark, description, raise cap), its rune, and all six faces laid out as an
## unfolded die. Arrows page through the pool. One exit (spec 3.2): the header close button,
## Esc or a tap on the backdrop; there is no CLOSE button.
##
##   inspector.show_die(flow, 2)

signal closed_by_player

var _flow: GameFlow
var _idx := 0
var _nav_label: Label
var _prev: GameButton
var _next: GameButton
var _head: HBoxContainer
var _net: GridContainer
var _notes: VBoxContainer


func _build() -> void:
	ScrollFade.attach(self, _scroll, UiPalette.NAVY_2, _frame)
	max_width = 600.0
	dismissible = true
	var nav := UiTheme.hbox(12)
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(nav)
	# 64 px round buttons with an 88 px hit rect (spec 4.3)
	_prev = GameButton.round_icon("arrow_left", 64)
	_prev.round_family = "grey"
	_prev.icon_tint = UiPalette.TEXT
	_prev.tooltip_text = "Previous die"
	_prev.pressed.connect(func() -> void: _page(-1))
	nav.add_child(_prev)
	_nav_label = UiTheme.label("", 22, UiPalette.TEXT_MUTED, false, 0, false, 700)
	_nav_label.custom_minimum_size.x = 150
	_nav_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav.add_child(_nav_label)
	_next = GameButton.round_icon("arrow_right", 64)
	_next.round_family = "grey"
	_next.icon_tint = UiPalette.TEXT
	_next.tooltip_text = "Next die"
	_next.pressed.connect(func() -> void: _page(1))
	nav.add_child(_next)
	_head = UiTheme.hbox(18)
	body.add_child(_head)
	body.add_child(UiModal.section_label("Faces"))
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(cc)
	_net = GridContainer.new()
	_net.columns = 4
	_net.add_theme_constant_override("h_separation", 6)
	_net.add_theme_constant_override("v_separation", 6)
	_net.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(_net)
	_notes = UiTheme.vbox(4)
	body.add_child(_notes)


func dismiss() -> void:
	close()
	closed_by_player.emit()


func show_die(flow: GameFlow, idx: int) -> void:
	_flow = flow
	_idx = clampi(idx, 0, flow.run.dice.size() - 1)
	_fill()
	if not visible or not is_open():
		open()


func _page(d: int) -> void:
	if _flow == null:
		return
	_idx = posmod(_idx + d, _flow.run.dice.size())
	_fill()


func _fill() -> void:
	var die: Die = _flow.run.dice[_idx]
	var kd := DiceKinds.def(die.kind)
	var kc := UiPalette.kind_color(die.kind)
	set_title(("DIE %d" % (_idx + 1)) if die.kind == "standard" else String(kd.name).to_upper() + " DIE", kc.lerp(UiPalette.GOLD, 0.35))
	_nav_label.text = "%d / %d" % [_idx + 1, _flow.run.dice.size()]
	_prev.visible = _flow.run.dice.size() > 1
	_next.visible = _flow.run.dice.size() > 1
	UiTheme.clear(_head)
	var best := 0
	for v in die.faces:
		best = maxi(best, v)
	var big := DieFace.make(best, die.rune, false, 116)
	big.kind = die.kind
	_head.add_child(big)
	var col := UiTheme.vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_head.add_child(col)
	var kr := UiTheme.hbox(8)
	col.add_child(kr)
	kr.add_child(UiTheme.label(DiceKinds.label(die.kind), 34, kc.lightened(0.3) if die.kind != "standard" else UiPalette.TEXT, true, 6))
	var rar := String(kd.rarity)
	var tag := PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tl := UiTheme.label(rar.to_upper(), 16, UiPalette.TEXT, false, 0, false, 800)
	tag.add_child(tl)
	OptionCard.style_tag(tag, tl, kc)
	kr.add_child(tag)
	col.add_child(UiTheme.para(String(kd.desc), 21, UiPalette.TEXT_DIM, 500))
	var rr := UiTheme.hbox(10)
	col.add_child(rr)
	rr.add_child(RuneBadge.make(die.rune, 44))
	if die.rune == "":
		rr.add_child(UiTheme.label("No rune", 22, UiPalette.TEXT_MUTED, false, 0, false, 600))
	else:
		var rd: Dictionary = Runes.DEFS[die.rune]
		var rc := UiTheme.vbox(-4)
		rc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rr.add_child(rc)
		rc.add_child(UiTheme.label("%s Rune" % rd.name, 24, UiPalette.rune_color(die.rune).lightened(0.25), true, 4))
		rc.add_child(UiTheme.para(String(rd.desc), 19, UiPalette.TEXT_DIM, 500))
	# unfolded die: up / (left, front, right, back) / down
	UiTheme.clear(_net)
	var layout := [-1, 0, -1, -1, 4, 3, 1, 2, -1, 5, -1, -1]
	for slot in layout:
		if slot < 0:
			var sp := Control.new()
			sp.custom_minimum_size = Vector2(84, 84)
			sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_net.add_child(sp)
		else:
			var f := DieFace.make(die.faces[slot], die.rune, die.edited[slot] == 1, 84)
			f.kind = die.kind
			_net.add_child(f)
	UiTheme.clear(_notes)
	var edits := 0
	for e in die.edited:
		edits += int(e)
	var sum := die.face_sum()
	var line := "Average roll %.1f  ·  Forge cap %d  ·  Pool %d/%d" % [sum / 6.0, die.raise_cap(),
		_flow.run.dice.size(), _flow.run.max_dice()]

	if edits > 0:
		line += "  ·  %d forged face%s" % [edits, "" if edits == 1 else "s"]
	var nl := UiTheme.label(line, 20, UiPalette.TEXT_MUTED, false, 0, false, 600)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notes.add_child(nl)
	if die.faces.has(0):
		var bl := UiTheme.label("Blank faces move 0 and never join a combo.", 19, UiPalette.TEXT_MUTED, false, 0, false, 500)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_notes.add_child(bl)
	relayout()
