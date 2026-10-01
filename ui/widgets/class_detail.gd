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
	# a card with the mechanic-colour rim (the colour coding lives on the frame)
	p.add_theme_stylebox_override("panel", UiTheme.card_box("normal", col))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UiTheme.hbox(12)
	p.add_child(row)
	# mechanic medallion: the tinted Flat White glyph (icon_map palette:auto); classes
	# without a mechanic show their full-colour class icon
	var icon := Icons.mechanic_icon(mech) if mech != "" else Icons.class_icon(id)
	var med := Medal.make(icon, 56, col, col.lightened(0.25) if mech != "" else null)
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
	row.add_child(_stat("reroll", "%d" % int(d.board_rerolls), "MOVE REROLLS", UiPalette.GOLD_BRIGHT, font))
	row.add_child(_stat("dice", "%d" % int(HeroDefs.field(id, "combat_rerolls")), "FIGHT REROLLS", UiPalette.DIE_BODY, font))
	return row


static func _stat(icon: String, value: String, label: String, col: Color, font: int) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.inset_box(), 8, 6))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UiTheme.vbox(0)
	p.add_child(v)
	var r := UiTheme.hbox(5)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(r)
	r.add_child(Icons.rect(icon, int(font * 1.1)))
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
	p.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.inset_box(), 12, 8))
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


## Round medallion behind a class / mechanic icon (class cards, the mechanic badge): a dark
## disc with a `ring` rim and the pack icon. `tint` (Color) recolours a Flat White glyph (the
## mechanic medallions); null keeps a full-colour Outline icon. `saturation` 0 = locked.
class Medal:
	extends Control
	var icon := ""
	var ring: Color = UiPalette.GOLD
	var tint: Variant = null
	var saturation := 1.0

	static func make(p_icon: String, px: float, p_ring: Color, p_tint: Variant = null, p_sat := 1.0) -> Medal:
		var m := Medal.new()
		m.icon = p_icon
		m.ring = p_ring
		m.tint = p_tint
		m.saturation = p_sat
		m.custom_minimum_size = Vector2(px, px)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return m

	func _draw() -> void:
		var s := minf(size.x, size.y)
		var c := size * 0.5
		var r := s * 0.5
		var rim := ring if saturation >= 1.0 else Color(0.42, 0.42, 0.5)
		draw_circle(c, r, UiPalette.OUTLINE)
		draw_circle(c, r - 2.0, rim.darkened(0.1))
		var inner := r - maxf(4.0, s * 0.09)
		draw_circle(c, inner, UiPalette.INK.lerp(rim, 0.14))
		var gs := inner * 1.42
		var opts := {"saturation": saturation}
		if tint is Color:
			opts["tint"] = tint
		var tex := Icons.texture(icon, int(ceil(gs)), opts)
		if tex != null:
			var ts := tex.get_size()
			var k := gs / maxf(ts.x, ts.y)
			var d := ts * k
			draw_texture_rect(tex, Rect2(c - d * 0.5, d), false)
