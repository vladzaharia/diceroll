class_name PetDenModal
extends CampModal
## Pet Den (review §5.3; Camp stations pass, docs/design/2026-10-01-camp-stations.md): every
## familiar as a StationCard of one height. Head: what it fires (tap for the full text) and
## EQUIP / EQUIPPED / UNLOCK. Pills: meter size, level, role. Contents: the charge rule at a
## glance plus its board perk and the L5 / L10 behaviours as rule tiles. Footer: the level
## route (XP bar for levels 1-5 from fights won with it, LEVEL UP [crown] N for 6-10).
## One pet is equipped per run.

const ACCENT := Color("ffb45a")

var spec := _pet_spec()


func _build() -> void:
	set_title("PET DEN", PLAQUE_DEFAULT)


static func _pet_spec() -> StationCard.Spec:
	var s := StationCard.Spec.new()
	s.desc_lines = 3
	# two rows of two rule tiles (head 22 + 2 lines of 16 px, 8 px padding)
	s.contents_h = 2.0 * _tile_h() + 10.0
	s.footer_h = 88.0
	return s


static func _tile_h() -> float:
	return 16.0 + 24.0 + StationCard.line_h(16) * 2.0 + 2.0


func rebuild(p: Profile) -> void:
	fit_columns()
	var intro := UiTheme.para("One familiar joins each run. It fills its meter from your dice and acts on its own. Levels 1-5 come from fights won together; 6-10 cost Crowns.",
		19, UiPalette.TEXT_DIM, 500)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(intro)
	var grid := card_grid()
	body.add_child(grid)
	for id in PetDefs.IDS:
		grid.add_child(pet_card(p, String(id)))


func pet_card(p: Profile, id: String) -> StationCard:
	var owned := p.owns("pets", id)
	var lvl := maxi(1, p.pet_level(id))
	var card := PetDefs.card(id, lvl)
	var col: Color = CampInfo.PET_COLOR.get(id, ACCENT)
	var equipped := owned and String(p.loadout.get("pet", "")) == id
	var fires := "Fires: " + String(card.fires)
	var c := StationCard.make(spec, String(CampInfo.PET_GLYPH.get(id, "station_pet_den")), col, String(card.name), fires,
		"equipped" if equipped else ("normal" if owned else "locked"))
	c.name = "Pet_" + id
	c.on_info(func(a: Control) -> void:
		show_tip(a, String(card.name), _role(card).to_upper(), String(card.fires), col, String(CampInfo.PET_GLYPH.get(id, ""))))
	# pills: meter size, level, role
	c.add_pill("pet_charge", "CHARGE %d" % int(card.size))
	if owned:
		c.add_pill("star", "LEVEL %d/%d" % [lvl, PetDefs.MAX_LEVEL])
	c.add_pill("", _role(card).to_upper())
	# head: the state or the action
	var mg: Array = (p.loadout.get("minigames", []) as Array).duplicate()
	if equipped:
		c.set_state("EQUIPPED", "purple")
	elif owned:
		var b := GameButton.make("EQUIP", "", GameButton.Kind.PRIMARY, 22)
		b.name = "Equip"
		b.min_height = 72
		b.pressed.connect(cmd.bind(["set_loadout", mg, id]))
		c.set_action(b)
	else:
		var cost := UnlockDefs.sigil_cost("pets", id)
		var b := CampUi.buy_button("UNLOCK", cost, p.can_afford(cost), 22)
		b.name = "Unlock"
		b.pressed.connect(cmd.bind(["unlock", "pets", id]))
		c.set_action(b)
	# contents: the charge rule first, then what it does on the board and at L5 / L10
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	g.mouse_filter = Control.MOUSE_FILTER_PASS
	var charge := String(CampInfo.CHARGE_TEXT.get(String(card.charge_on), "Charges from your dice"))
	var rules := [
		["pet_charge", "FILLS", UiPalette.GOLD_BRIGHT, charge.left(1).to_upper() + charge.substr(1) + ".", true],
		["flag", "ON THE BOARD", UiPalette.TEXT_DIM, String(card.perk), owned],
		["star" if lvl >= 5 and owned else "lock", "LEVEL 5", UiPalette.GOLD, String(card.l5), owned and lvl >= 5],
		["star" if lvl >= 10 and owned else "lock", "LEVEL 10", UiPalette.GOLD, String(card.l10), owned and lvl >= 10],
	]
	for r in rules:
		var t := StationCard.rule_tile(String(r[0]), String(r[1]), r[2], String(r[3]), bool(r[4]), 2)
		t.custom_minimum_size.y = _tile_h()
		var head_t := String(r[1])
		var body_t := String(r[3])
		t.pressed.connect(func() -> void: show_tip(t, String(card.name), head_t, body_t, col))
		g.add_child(t)
	c.set_contents(g)
	_footer(c, p, id, lvl, owned, equipped, mg)
	return c


static func _role(card: Dictionary) -> String:
	return String(CampInfo.ROLE_LABEL.get(String(card.role), String(card.role).capitalize()))


## The level route: XP (1-5), LEVEL UP for Crowns (6-10) or MAX; REMOVE when equipped; the
## milestone when locked.
func _footer(c: StationCard, p: Profile, id: String, lvl: int, owned: bool, equipped: bool, mg: Array) -> void:
	if not owned:
		var m := CampInfo.milestone_for("pets", id)
		if m.is_empty():
			c.set_status("Unlock it with Sigils.", "lock")
		else:
			var pr := CampInfo.progress(p, m.cond)
			c.set_status(String(m.desc) + ("  (%d/%d)" % [int(pr[0]), int(pr[1])] if int(pr[1]) > 1 else ""), "lock")
		return
	var xpb := CampInfo.pet_xp_bar(p, id)
	if lvl < PetDefs.XP_LEVEL_MAX and int(xpb[1]) > 0:
		c.set_status("%d/%d fights won together to level %d" % [int(xpb[0]), int(xpb[1]), lvl + 1], "pet_xp", UiPalette.TEXT_DIM)
		var bar := CampUi.bar(float(xpb[0]), float(xpb[1]), UiPalette.XP, 18)
		bar.kind = "xp"
		bar.custom_minimum_size.x = 96
		bar.size_flags_horizontal = Control.SIZE_SHRINK_END
		c.add_footer(bar)
	else:
		var cost := PetDefs.level_cost(lvl)
		if cost.is_empty():
			c.set_status("Max level: every perk is on.", "star", UiPalette.GOLD)
		else:
			c.set_status("Level %d: %s" % [lvl + 1, "the next perk tier" if lvl + 1 == PetDefs.MAX_LEVEL else "stronger numbers"],
				"star", UiPalette.TEXT_DIM)
			var b := CampUi.buy_button("LEVEL UP", cost, p.can_afford(cost), 20)
			b.name = "LevelUp"
			b.pressed.connect(cmd.bind(["level_pet", id]))
			c.add_footer(b)
	if equipped:
		var r := GameButton.make("REMOVE", "", GameButton.Kind.GHOST, 20)
		r.name = "Remove"
		r.min_height = 72
		r.pad_x = 14
		r.pressed.connect(cmd.bind(["set_loadout", mg, ""]))
		c.add_footer(r)
