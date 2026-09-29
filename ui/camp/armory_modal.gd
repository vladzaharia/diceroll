class_name ArmoryModal
extends CampModal
## Armory (review §5.1): four gear pieces levelled 1..8 with Crowns, each with a trait choice
## at L4 and L8 (free, switchable), plus the Third Potion Slot upgrade. Locked pieces show their
## milestone and the Sigil price.


func _build() -> void:
	set_title("ARMORY", Color("ff9a5a"))


func rebuild(p: Profile) -> void:
	var intro := UiTheme.para("Small, capped stats. The real choices are the traits at level 4 and 8, and you can switch them any time.",
		20, UiPalette.TEXT_DIM, 500)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(intro)
	for slot in GearDefs.SLOTS:
		body.add_child(_gear_card(p, String(slot)))
	body.add_child(CampModal.heading("Potion belt"))
	body.add_child(_belt_card(p))


func _gear_card(p: Profile, slot: String) -> Control:
	var icon := String(CampInfo.GEAR_ICON[slot])
	var col_accent := Color("ff9a5a")
	if not p.owns("gear", slot):
		var lc := CampUi.locked_card()
		var v := UiTheme.vbox(10)
		lc.add_child(v)
		var tr := CampUi.title_row(icon, UiPalette.TEXT_MUTED, GearDefs.name_of(slot), String(GearDefs.DEFS[slot].desc))
		tr.modulate = Color(1, 1, 1, 0.75)
		v.add_child(tr)
		var row := UiTheme.hbox(12)
		v.add_child(row)
		var m := CampInfo.milestone_for("gear", slot)
		var ll := CampUi.lock_line(String(m.get("desc", "Locked")))
		ll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(ll)
		var cost := UnlockDefs.sigil_cost("gear", slot)
		var b := CampUi.buy_button("UNLOCK", cost, p.can_afford(cost), 22)
		b.pressed.connect(cmd.bind(["unlock", "gear", slot]))
		row.add_child(b)
		return lc
	var lvl := p.gear_level(slot)
	var c := CampUi.card(false, col_accent)
	var v := UiTheme.vbox(12)
	c.add_child(v)
	var head := UiTheme.hbox(10)
	v.add_child(head)
	var tr := CampUi.title_row(icon, col_accent, GearDefs.name_of(slot), "LEVEL %d / %d" % [lvl, GearDefs.MAX_LEVEL] if lvl > 0 else "NOT CRAFTED YET")
	tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tr)
	var cost := GearDefs.cost(slot, lvl)
	if cost.is_empty():
		head.add_child(CampUi.chip("MAX", UiPalette.GOLD_DEEP, UiPalette.TEXT, 20))
	else:
		var b := CampUi.buy_button("CRAFT" if lvl == 0 else "LEVEL UP", cost, p.can_afford(cost), 22)
		b.pressed.connect(cmd.bind(["level_gear", slot]))
		head.add_child(b)
	v.add_child(CampUi.pips(lvl, GearDefs.MAX_LEVEL, col_accent, [4, 8]))
	# stat preview: now -> next
	var stat := UiTheme.hbox(10)
	v.add_child(stat)
	stat.add_child(UiTheme.label(CampInfo.gear_stat(slot, lvl) if lvl > 0 else "No bonus", 21, UiPalette.TEXT, false, 0, false, 700))
	if lvl < GearDefs.MAX_LEVEL:
		stat.add_child(UiIcons.rect("arrow_right", 22, UiPalette.GOLD))
		var nx := UiTheme.label(CampInfo.gear_stat(slot, lvl + 1), 21, UiPalette.HEAL, false, 0, false, 700)
		nx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nx.custom_minimum_size.x = 60
		stat.add_child(nx)
	# traits: L4 and L8, one pick each
	var t: Dictionary = p.gear_traits.get(slot, {})
	for tier in ["4", "8"]:
		var opts := GearDefs.trait_options(slot, tier)
		var open := lvl >= int(tier)
		var lab := UiTheme.label(("LEVEL %s TRAIT" % tier) + ("" if open else "  ·  unlocks at level %s" % tier), 17,
			UiPalette.GOLD if open else UiPalette.TEXT_MUTED, false, 0, false, 700)
		v.add_child(lab)
		var row := UiTheme.hbox(10)
		v.add_child(row)
		var pick := String(t.get(tier, opts[0]))
		for id in opts:
			var d: Dictionary = GearDefs.TRAIT_DEFS[id]
			var tl := CampUi.tile(String(d.name), String(d.desc), open and pick == String(id), open, "", col_accent)
			tl.pressed.connect(cmd.bind(["set_trait", slot, tier, String(id)]))
			row.add_child(tl)
	return c


func _belt_card(p: Profile) -> Control:
	var d := UnlockDefs.upgrade_def("armory", "potion_belt")
	var owned := int(p.upgrades.get("potion_belt", 0)) >= 1
	var feature := p.owns("features", "potion_belt")
	var c := CampUi.card(owned, UiPalette.HP_BRIGHT) if feature else CampUi.locked_card()
	var row := UiTheme.hbox(12)
	c.add_child(row)
	var tr := CampUi.title_row("potion", UiPalette.HP_BRIGHT if feature else UiPalette.TEXT_MUTED, String(d.name),
		"Belt holds %d potions" % p.potion_cap())
	tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tr)
	if owned:
		row.add_child(CampUi.chip("OWNED", UiPalette.HEAL.darkened(0.35), UiPalette.TEXT, 18))
	elif feature:
		var b := CampUi.buy_button("BUY", d.cost, p.can_afford(d.cost), 22)
		b.pressed.connect(cmd.bind(["buy_upgrade", "armory", "potion_belt"]))
		row.add_child(b)
	else:
		var box := UiTheme.vbox(4)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.remove_child(row)
		c.add_child(box)
		box.add_child(row)
		box.add_child(CampUi.lock_line(String(CampInfo.milestone_for("features", "potion_belt").get("desc", "Locked"))))
	return c
