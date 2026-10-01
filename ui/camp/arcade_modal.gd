class_name ArcadeModal
extends CampModal
## Arcade (review §5.4): the minigame loadout (2 slots, a 3rd bought with Crowns once its
## milestone is reached), every minigame owned or locked with its gold-tier signature reward,
## and mastery (1-5, from plays; up to +10% gold rewards).

const ACCENT := Color("ff6fd0")


func _build() -> void:
	set_title("ARCADE", ACCENT)


func rebuild(p: Profile) -> void:
	var intro := UiTheme.para("Each equipped minigame puts one tile on the board. Land on it to play for rewards. Your best tier decides the prize.",
		20, UiPalette.TEXT_DIM, 500)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(intro)
	body.add_child(CampModal.heading("Loadout"))
	body.add_child(_slots(p))
	body.add_child(CampModal.heading("Minigames"))
	for id in MinigameDefs.IDS:
		body.add_child(_game_card(p, String(id)))


func _slots(p: Profile) -> Control:
	var row := UiTheme.hbox(10)
	var mg: Array = p.loadout.get("minigames", [])
	for i in 3:
		var locked := i >= p.loadout_slots()
		if i < mg.size():
			var id := String(mg[i])
			var t := CampUi.tile(MinigameDefs.name_of(id), "Tap to remove", true, true, "", CampInfo.MINIGAME_COLOR.get(id, ACCENT))
			CampArt.tile_icon(t, CampArt.icon(String(CampInfo.MINIGAME_GLYPH.get(id, "station_arcade")), 30))
			var rest := mg.duplicate()
			rest.remove_at(i)
			t.pressed.connect(cmd.bind(["set_loadout", rest, String(p.loadout.get("pet", ""))]))
			row.add_child(t)
		elif not locked:
			var e := CampUi.tile("Empty slot", "Equip a minigame below", false, false, "", ACCENT)
			CampArt.tile_icon(e, CampArt.icon("plus", 26, UiPalette.TEXT_MUTED))
			row.add_child(e)
		else:
			row.add_child(_third_slot(p))
	return row


func _third_slot(p: Profile) -> Control:
	var d := UnlockDefs.upgrade_def("arcade", "loadout_slot")
	var box := CampUi.locked_card()
	box.size_flags_vertical = Control.SIZE_FILL
	var v := UiTheme.vbox(6)
	box.add_child(v)
	var hr := UiTheme.hbox(8)
	v.add_child(hr)
	hr.add_child(CampArt.icon("upgrade_loadout_slot", 28, null, not p.owns("features", "loadout_slot")))
	hr.add_child(UiTheme.label("3RD SLOT", 20, UiPalette.TEXT_MUTED, true, 4))
	if p.owns("features", "loadout_slot"):
		var b := CampUi.buy_button("", d.cost, p.can_afford(d.cost), 20)
		b.pressed.connect(cmd.bind(["buy_upgrade", "arcade", "loadout_slot"]))
		v.add_child(b)
	else:
		v.add_child(CampUi.lock_line(String(CampInfo.milestone_for("features", "loadout_slot").get("desc", "Locked")), 16))
	return box


func _game_card(p: Profile, id: String) -> Control:
	var d: Dictionary = MinigameDefs.DEFS[id]
	var owned := p.owns("minigames", id)
	var col: Color = CampInfo.MINIGAME_COLOR.get(id, ACCENT)
	var mg: Array = p.loadout.get("minigames", [])
	var equipped := mg.has(id)
	var c := CampUi.card(equipped, col) if owned else CampUi.locked_card()
	var v := UiTheme.vbox(10)
	c.add_child(v)
	var head := UiTheme.hbox(10)
	v.add_child(head)
	var mastery := p.mastery(id)
	var sub := "SKILL : LUCK  %s" % String(d.skill)
	if owned:
		sub += "  ·  MASTERY %d" % mastery
	var tr := CampArt.title_row(String(CampInfo.MINIGAME_GLYPH.get(id, "station_arcade")), col, String(d.name), sub, 64, not owned)
	tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tr)
	if owned:
		if equipped:
			var b := GameButton.make("EQUIPPED", "check", GameButton.Kind.SUCCESS, 20)
			b.min_height = 64
			b.pad_x = 14
			var rest := mg.duplicate()
			rest.erase(id)
			b.pressed.connect(cmd.bind(["set_loadout", rest, String(p.loadout.get("pet", ""))]))
			head.add_child(b)
		else:
			var full := mg.size() >= p.loadout_slots()
			var b := GameButton.make("SWAP IN" if full else "EQUIP", "", GameButton.Kind.PRIMARY, 22)
			b.min_height = 64
			var next := mg.duplicate()
			if full:
				next.pop_back()
			next.append(id)
			b.pressed.connect(cmd.bind(["set_loadout", next, String(p.loadout.get("pet", ""))]))
			head.add_child(b)
	else:
		var cost := UnlockDefs.sigil_cost("minigames", id)
		var b := CampUi.buy_button("UNLOCK", cost, p.can_afford(cost), 22)
		b.pressed.connect(cmd.bind(["unlock", "minigames", id]))
		head.add_child(b)
	v.add_child(UiTheme.para(String(d.desc), 19, UiPalette.TEXT_DIM if owned else UiPalette.TEXT_MUTED, 500))
	var sig := UiTheme.hbox(8)
	v.add_child(sig)
	sig.add_child(CampArt.chip("GOLD TIER", "yellow", "trophy_gold" if Icons.is_mapped("trophy_gold") else "", 16))
	var sl := UiTheme.para(String(d.signature_desc).trim_prefix("Gold: "), 19, UiPalette.TEXT if owned else UiPalette.TEXT_MUTED, 600)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sig.add_child(sl)
	if owned:
		var mrow := UiTheme.hbox(10)
		v.add_child(mrow)
		mrow.add_child(UiTheme.label("MASTERY", 16, UiPalette.GOLD, false, 0, false, 700))
		mrow.add_child(CampUi.pips(mastery, MinigameDefs.MAX_MASTERY, col))
		var plays := int(p.minigame_plays.get(id, 0))
		var nxt := "max" if mastery >= MinigameDefs.MAX_MASTERY else "%d / %d plays" % [plays, int(MinigameDefs.MASTERY_PLAYS[mastery - 1])]
		mrow.add_child(UiTheme.label("+%d%% gold  ·  %s" % [int(round((MinigameDefs.mastery_mult(mastery) - 1.0) * 100.0)), nxt], 17,
			UiPalette.TEXT_DIM, false, 0, false, 600))
	else:
		var m := CampInfo.milestone_for("minigames", id)
		if not m.is_empty():
			v.add_child(CampUi.lock_line(String(m.desc)))
	return c
