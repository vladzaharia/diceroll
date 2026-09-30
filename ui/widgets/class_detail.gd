class_name ClassDetail
extends RefCounted
## The "about this class" block shared by the class select screen and the run setup: the
## mechanic badge with its rule, the stat chips and the starting dice with their kinds (each die
## shows its six faces; the Pretend die's ★ face is drawn as a star, never a number).


## Mechanic badge: a bordered card with the mechanic medallion, its name and the rule line.
## Classes without a mechanic show their starting runes instead.
static func mechanic_badge(id: String, font := 20) -> PanelContainer:
	var mech := ClassInfo.mechanic(id)
	var col := ClassInfo.mechanic_color(mech) if mech != "" else UiPalette.class_color(id)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(Color(col.darkened(0.8), 0.92), 18, 2, Color(col, 0.65)), 14, 10))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UiTheme.hbox(12)
	p.add_child(row)
	var icon := UiIcons.mechanic_icon(mech) if mech != "" else UiIcons.class_icon(id)
	var med := OptionCard.Medallion.make(icon, 56, col, col)
	med.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(med)
	var c := UiTheme.vbox(2)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(c)
	var name := ClassInfo.mechanic_name(mech) if mech != "" else "Starting runes"
	c.add_child(UiTheme.label(name.to_upper(), font + 4, col.lightened(0.3), true, 5))
	var rule := ClassInfo.rule(mech) if mech != "" else _runes_line(id)
	c.add_child(UiTheme.para(rule, font, UiPalette.TEXT, 500))
	return p


## "Guard: Gain Block equal to pips." per starting rune (the tagline above already says the rest).
static func _runes_line(id: String) -> String:
	var parts: Array = []
	for r in (HeroDefs.DATA[id].get("runes", []) as Array):
		if String(r) != "" and Runes.DEFS.has(String(r)):
			parts.append("%s: %s" % [String(Runes.DEFS[r].name), String(Runes.DEFS[r].desc)])
	return " ".join(parts) if not parts.is_empty() else ClassInfo.tagline(id)


## HP / ATK / rerolls chips in one row.
static func stats_row(id: String, font := 26) -> HBoxContainer:
	var d: Dictionary = HeroDefs.DATA[id]
	var row := UiTheme.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_stat("heart", "%d" % int(d.hp), "HP", UiPalette.HP, font))
	row.add_child(_stat("sword", "+%d" % int(d.atk), "ATK", UiPalette.TEXT, font))
	row.add_child(_stat("reroll", "%d" % int(d.board_rerolls), "MOVE REROLL", UiPalette.GOLD_BRIGHT, font))
	row.add_child(_stat("dice", "%d" % int(HeroDefs.field(id, "combat_rerolls")), "FIGHT REROLLS", UiPalette.DIE_BODY, font))
	return row


static func _stat(icon: String, value: String, label: String, col: Color, font: int) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(UiPalette.NAVY_2, 16, 2, Color(1, 1, 1, 0.06)), 8, 6))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UiTheme.vbox(0)
	p.add_child(v)
	var r := UiTheme.hbox(5)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(r)
	r.add_child(UiIcons.rect(icon, int(font * 1.0)))
	r.add_child(UiTheme.label(value, font, col, true, 0))
	var l := UiTheme.label(label, 16, UiPalette.TEXT_DIM, false, 0, false, 700)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	return p


## One row per starting die (and the Engineer's Turret): the die, its name and its six faces.
static func dice_rows(id: String, face_px := 30) -> VBoxContainer:
	var col := UiTheme.vbox(8)
	var runes: Array = HeroDefs.DATA[id].runes
	var kinds: Array = HeroDefs.field(id, "kinds")
	var tags: Array = HeroDefs.field(id, "tags")
	for i in runes.size():
		col.add_child(die_row(String(kinds[i]), String(runes[i]), String(tags[i]), face_px))
	if ClassInfo.mechanic(id) == "turret":
		col.add_child(die_row("standard", String(HeroDefs.DATA[id].get("turret_rune", "")), "turret", face_px))
	return col


static func die_row(kind: String, rune: String, tag: String, face_px := 30) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(Color(0.03, 0.03, 0.09, 0.45), 16), 12, 8))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UiTheme.hbox(12)
	p.add_child(row)
	var faces: Array = (DiceKinds.DEFS.get(kind, DiceKinds.DEFS.standard) as Dictionary).faces
	var big := _face(int(faces[faces.size() - 1]), rune, kind, 56.0)
	big.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(big)
	var c := UiTheme.vbox(4)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(c)
	var title := DiceKinds.label(kind)
	if not title.to_lower().ends_with("die"):
		title += " die"
	if tag == "turret":
		title = "Clockwork Turret"
	elif tag == "seed":
		title += "  ·  Seed"
	var tc := UiPalette.kind_color(kind).lightened(0.2) if kind != "standard" else UiPalette.TEXT
	if tag == "turret":
		tc = ClassInfo.mechanic_color("turret")
	var th := UiTheme.hbox(8)
	c.add_child(th)
	th.add_child(UiTheme.label(title, 22, tc, true, 0))
	if rune != "" and Runes.DEFS.has(rune):
		th.add_child(UiTheme.label("+ %s" % String(Runes.DEFS[rune].name), 20, UiPalette.rune_color(rune).lightened(0.2), true, 0))
	var strip := UiTheme.hbox(4)
	c.add_child(strip)
	for v in faces:
		strip.add_child(_face(int(v), rune, "standard", float(face_px)))
	return p


## A die face; the Pretend face (Die.PRETEND) is a star.
static func _face(v: int, rune: String, kind: String, px: float) -> DieFace:
	var pretend := v == Die.PRETEND
	var f := DieFace.make(0 if pretend else clampi(v, 0, 9), rune, false, px)
	f.star = pretend or rune == "wild"
	f.kind = kind
	return f
