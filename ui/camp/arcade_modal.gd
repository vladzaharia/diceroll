class_name ArcadeModal
extends CampModal
## Arcade (review §5.4; Camp stations pass, docs/design/2026-10-01-camp-stations.md): the
## minigame loadout (2 slots, a 3rd bought with Crowns once its milestone is reached) and every
## minigame as a StationCard of one height. Pills: skill / luck, length, mastery. Contents: what
## it pays, as three tier tiles (Crowns per tier from Economy.CROWNS_MINIGAME, then the reward
## options GameFlow offers: bronze gold or a Crown, silver a potion / Face Raise / gold, gold the
## game's signature). Footer: mastery (1-5, from plays; up to +10% gold rewards) or how to
## unlock it.

const ACCENT := Color("ff6fd0")
const TIERS := ["bronze", "silver", "gold"]
const TIER_COLOR := {"bronze": Color("e0925a"), "silver": Color("d6dde9"), "gold": Color("ffc24a")}
const TIER_ICON := {"bronze": "trophy_bronze", "silver": "trophy_silver", "gold": "trophy_gold"}

var spec := _game_spec()


func _build() -> void:
	set_title("ARCADE", PLAQUE_DEFAULT)


static func _game_spec() -> StationCard.Spec:
	var s := StationCard.Spec.new()
	s.desc_lines = 2
	s.contents_h = _tile_h()
	s.footer_h = 88.0
	return s


static func _tile_h() -> float:
	return 16.0 + 24.0 + StationCard.line_h(16) * 3.0 + 2.0


func rebuild(p: Profile) -> void:
	fit_columns()
	var intro := UiTheme.para("Each equipped minigame puts one tile on the board. Land on it to play; the better you do, the better the prize.",
		19, UiPalette.TEXT_DIM, 500)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(intro)
	body.add_child(CampModal.heading("Loadout"))
	body.add_child(_slots(p))
	body.add_child(CampModal.heading("Minigames", "Tap a prize for every option of its tier."))
	var grid := card_grid()
	body.add_child(grid)
	for id in MinigameDefs.IDS:
		grid.add_child(game_card(p, String(id)))


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
		var b := CampUi.buy_button("BUY", d.cost, p.can_afford(d.cost), 20)
		b.pressed.connect(cmd.bind(["buy_upgrade", "arcade", "loadout_slot"]))
		v.add_child(b)
	else:
		v.add_child(CampUi.lock_line(String(CampInfo.milestone_for("features", "loadout_slot").get("desc", "Locked")), 16))
	return box


## What a tier pays: [short line, every option] (GameFlow._reward_options, at the Camp without
## the lap's gold scaling: gold amounts are "gold").
static func payout(id: String, tier: String) -> Array:
	match tier:
		"bronze":
			return ["Gold or +1 Crown", "Pick one: %d+ gold, or +1 Crown banked at the end of the run." % MinigameDefs.BRONZE_GOLD]
		"silver":
			return ["A potion, a Face Raise or gold", "Pick one: a Healing Draught, a Face Raise or %d+ gold." % MinigameDefs.SILVER_GOLD]
	var sig := String(MinigameDefs.DEFS[id].signature_desc).trim_prefix("Gold: ")
	sig = sig.left(1).to_upper() + sig.substr(1)
	return [sig, "Pick one: %s, a rune of your choice, or a potion and %d+ gold." % [sig.trim_suffix(".").left(1).to_lower()
		+ sig.trim_suffix(".").substr(1), MinigameDefs.GOLD_POTION_GOLD]]


func game_card(p: Profile, id: String) -> StationCard:
	var d: Dictionary = MinigameDefs.DEFS[id]
	var owned := p.owns("minigames", id)
	var col: Color = CampInfo.MINIGAME_COLOR.get(id, ACCENT)
	var mg: Array = p.loadout.get("minigames", [])
	var equipped := owned and mg.has(id)
	var glyph := String(CampInfo.MINIGAME_GLYPH.get(id, "station_arcade"))
	var c := StationCard.make(spec, glyph, col, String(d.name), String(d.desc),
		"equipped" if equipped else ("normal" if owned else "locked"))
	c.name = "Game_" + id
	c.on_info(func(a: Control) -> void: show_tip(a, String(d.name), "HOW TO PLAY", String(d.desc), col, glyph))
	# pills: skill / luck, length, mastery
	var sk := String(d.skill).split(":")
	c.add_pill("", ("SKILL %s%%  ·  LUCK %s%%" % [sk[0], sk[1]]) if sk.size() == 2 else String(d.skill))
	var secs := int((MinigameDefs.CALIBRATION.get(id, {}) as Dictionary).get("secs", 0))
	if secs > 0:
		c.add_pill("speed", "%d S" % secs)
	var mastery := p.mastery(id)
	if owned:
		c.add_pill("mastery", "MASTERY %d/%d" % [mastery, MinigameDefs.MAX_MASTERY])
	# head: the state or the action
	var full := mg.size() >= p.loadout_slots()
	if equipped:
		c.set_state("EQUIPPED", "purple")
	elif owned:
		var b := GameButton.make("SWAP IN" if full else "EQUIP", "", GameButton.Kind.PRIMARY, 22)
		b.name = "Equip"
		b.min_height = 72
		var next := mg.duplicate()
		if full:
			next.pop_back()
			b.tooltip_text = "Replaces %s" % MinigameDefs.name_of(String(mg.back()))
		next.append(id)
		b.pressed.connect(cmd.bind(["set_loadout", next, String(p.loadout.get("pet", ""))]))
		c.set_action(b)
	else:
		var cost := UnlockDefs.sigil_cost("minigames", id)
		var b := CampUi.buy_button("UNLOCK", cost, p.can_afford(cost), 22)
		b.name = "Unlock"
		b.pressed.connect(cmd.bind(["unlock", "minigames", id]))
		c.set_action(b)
	# contents: what it pays, per tier
	var row := UiTheme.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	for tier in TIERS:
		var t: String = tier
		var pay := payout(id, t)
		var crowns := CampUi.amount("crown", int(Economy.CROWNS_MINIGAME[t]), CampUi.CROWN_COLOR, 16)
		crowns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		crowns.alignment = BoxContainer.ALIGNMENT_END
		var tile := StationCard.rule_tile(String(TIER_ICON[t]), t.to_upper(), TIER_COLOR[t], String(pay[0]), owned, 3, crowns)
		tile.custom_minimum_size.y = _tile_h()
		tile.name = "Pays_" + t
		tile.pressed.connect(func() -> void:
			show_tip(tile, "%s tier" % t.capitalize(), "+%d CROWNS" % int(Economy.CROWNS_MINIGAME[t]), String(pay[1]), TIER_COLOR[t],
				String(TIER_ICON[t])))
		row.add_child(tile)
	c.set_contents(row)
	# footer: mastery or how to unlock it; REMOVE when equipped
	if owned:
		var plays := int(p.minigame_plays.get(id, 0))
		var bonus := int(round((MinigameDefs.mastery_mult(mastery) - 1.0) * 100.0))
		var s := "+%d%% gold" % bonus
		if mastery < MinigameDefs.MAX_MASTERY:
			s += "  ·  %d/%d plays to mastery %d" % [plays, int(MinigameDefs.MASTERY_PLAYS[mastery - 1]), mastery + 1]
		else:
			s += "  ·  max mastery"
		if not equipped and full:
			s = "Replaces %s.  %s" % [MinigameDefs.name_of(String(mg.back())), s]
		c.set_status(s, "mastery", UiPalette.TEXT_DIM)
		if equipped:
			var r := GameButton.make("REMOVE", "", GameButton.Kind.GHOST, 20)
			r.name = "Remove"
			r.min_height = 72
			r.pad_x = 14
			var rest := mg.duplicate()
			rest.erase(id)
			r.pressed.connect(cmd.bind(["set_loadout", rest, String(p.loadout.get("pet", ""))]))
			c.add_footer(r)
	else:
		var m := CampInfo.milestone_for("minigames", id)
		if m.is_empty():
			c.set_status("Unlock it with Sigils.", "lock")
		else:
			var pr := CampInfo.progress(p, m.cond)
			c.set_status(String(m.desc) + ("  (%d/%d)" % [int(pr[0]), int(pr[1])] if int(pr[1]) > 1 else ""), "lock")
	return c
