class_name PetDenModal
extends CampModal
## Pet Den (review §5.3): every familiar via PetDefs.card(id, level): role, charge trigger and
## meter size, what it fires, its board perk, the L5 / L10 behaviours, the XP bar (levels 1-5
## come from fights won with it) and the Crowns level-ups 6-10. One pet is equipped per run.

const ACCENT := Color("ffb45a")


func _build() -> void:
	set_title("PET DEN", PLAQUE_DEFAULT)


func rebuild(p: Profile) -> void:
	var intro := UiTheme.para("One familiar joins each run. It charges from your dice and acts on its own. Levels 1-5 come from fights won together; 6-10 cost Crowns.",
		20, UiPalette.TEXT_DIM, 500)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(intro)
	for id in PetDefs.IDS:
		body.add_child(_pet_card(p, String(id)))


func _pet_card(p: Profile, id: String) -> Control:
	var owned := p.owns("pets", id)
	var lvl := maxi(1, p.pet_level(id))
	var card := PetDefs.card(id, lvl)
	var col: Color = CampInfo.PET_COLOR.get(id, ACCENT)
	var equipped := owned and String(p.loadout.get("pet", "")) == id
	var c := (CampUi.card(equipped, col) if owned else CampUi.locked_card())
	var v := UiTheme.vbox(10)
	c.add_child(v)
	var head := UiTheme.hbox(10)
	v.add_child(head)
	var role := String(CampInfo.ROLE_LABEL.get(String(card.role), String(card.role))).to_upper()
	var sub := ("%s  ·  LEVEL %d" % [role, lvl]) if owned else role
	var tr := CampArt.title_row(String(CampInfo.PET_GLYPH.get(id, "station_pet_den")), col, String(card.name), sub, 72, not owned)
	tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tr)
	if owned:
		if equipped:
			# state = the purple EQUIPPED chip (as in the Armory); the action = a ghost REMOVE
			var col2 := UiTheme.vbox(6)
			col2.alignment = BoxContainer.ALIGNMENT_CENTER
			col2.add_child(CampArt.chip("EQUIPPED", "purple", "", 16))
			var b := GameButton.make("REMOVE", "", GameButton.Kind.GHOST, 20)
			b.min_height = 64
			b.pad_x = 14
			b.pressed.connect(cmd.bind(["set_loadout", (p.loadout.minigames as Array).duplicate(), ""]))
			col2.add_child(b)
			head.add_child(col2)
		else:
			var b := GameButton.make("EQUIP", "", GameButton.Kind.PRIMARY, 22)
			b.min_height = 64
			b.pressed.connect(cmd.bind(["set_loadout", (p.loadout.minigames as Array).duplicate(), id]))
			head.add_child(b)
	else:
		var cost := UnlockDefs.sigil_cost("pets", id)
		var b := CampUi.buy_button("UNLOCK", cost, p.can_afford(cost), 22)
		b.pressed.connect(cmd.bind(["unlock", "pets", id]))
		head.add_child(b)
	# charge meter
	var charge := UiTheme.hbox(8)
	v.add_child(charge)
	charge.add_child(_meter(int(card.size), col if owned else UiPalette.TEXT_MUTED))
	var ct := UiTheme.para("Fills %s" % String(CampInfo.CHARGE_TEXT.get(String(card.charge_on), "")), 19,
		UiPalette.TEXT if owned else UiPalette.TEXT_MUTED, 600)
	ct.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	charge.add_child(ct)
	v.add_child(_line("pet_charge", "Fires", String(card.fires), owned))
	v.add_child(_line("flag", "Board", String(card.perk), owned))
	v.add_child(_line("star", "L5", String(card.l5), owned and lvl >= 5))
	v.add_child(_line("crown", "L10", String(card.l10), owned and lvl >= 10))
	if not owned:
		var m := CampInfo.milestone_for("pets", id)
		if not m.is_empty():
			v.add_child(CampUi.lock_line(String(m.desc)))
		return c
	# progress: XP levels 1-5, then Crowns
	var xpb := CampInfo.pet_xp_bar(p, id)
	if int(xpb[1]) > 0 and lvl < PetDefs.XP_LEVEL_MAX:
		var row := UiTheme.hbox(10)
		v.add_child(row)
		row.add_child(CampArt.icon("pet_xp", 30))
		var xb := CampUi.bar(float(xpb[0]), float(xpb[1]), UiPalette.XP, 24)
		xb.kind = "xp"
		row.add_child(xb)
		row.add_child(UiTheme.label("%d/%d fights to L%d" % [int(xpb[0]), int(xpb[1]), lvl + 1], 18, UiPalette.TEXT_DIM, false, 0, false, 700))
	else:
		var row := UiTheme.hbox(10)
		v.add_child(row)
		row.add_child(CampUi.pips(lvl, PetDefs.MAX_LEVEL, col, [5, 10]))
		var sp := UiTheme.spacer(0, true)
		row.add_child(sp)
		var cost := PetDefs.level_cost(lvl)
		if cost.is_empty():
			row.add_child(CampArt.chip("MAX LEVEL", "yellow", "star", 18))
		else:
			var b := CampUi.buy_button("LEVEL UP", cost, p.can_afford(cost), 21)
			b.pressed.connect(cmd.bind(["level_pet", id]))
			row.add_child(b)
	return c


func _line(icon: String, tag: String, text: String, on: bool) -> Control:
	var row := UiTheme.hbox(10)
	var t := CampArt.chip(tag, "grey", icon, 16)
	t.custom_minimum_size.x = 96
	if not on:
		t.modulate = Color(1, 1, 1, 0.6)
	row.add_child(t)
	var l := UiTheme.para(text, 19, UiPalette.TEXT_DIM if on else UiPalette.TEXT_MUTED, 500)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	if not on and icon != "":
		row.modulate = Color(1, 1, 1, 0.75)
	return row


## The pet's empty charge meter (one pip per charge).
func _meter(n: int, col: Color) -> Control:
	var m := CampUi.pips(0, n, col)
	m.custom_minimum_size = Vector2(n * 16, 18)
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.inset_box(), 10, 4))
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.add_child(m)
	return holder
