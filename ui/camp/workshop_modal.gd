class_name WorkshopModal
extends CampModal
## Dice Workshop (review §5.2): unlock packs bought with Sigils (their runes, die kinds and
## passives join the drop pools), the pool toggle (at most 25% of each pool off), the Starter
## Kit (kind of the second starting die) and the Whetstone.

const POOLS := [["runes", "Runes"], ["kinds", "Die kinds"], ["passives", "Passives"]]
const ACCENT := Color("7ad0ff")


func _build() -> void:
	set_title("DICE WORKSHOP", ACCENT)


func rebuild(p: Profile) -> void:
	body.add_child(CampModal.heading("Unlock packs", "Each pack adds a build idea to the drops: runes, die kinds and passives."))
	for id in UnlockDefs.PACK_IDS:
		body.add_child(_pack_card(p, String(id)))
	body.add_child(CampModal.heading("Drop pools", "Switch off up to 25% of each pool to steer what you find."))
	for pool in POOLS:
		body.add_child(_pool_card(p, String(pool[0]), String(pool[1])))
	body.add_child(CampModal.heading("Starting kit"))
	body.add_child(_starter_card(p))
	body.add_child(_whetstone_card(p))


func _pack_card(p: Profile, id: String) -> Control:
	var d: Dictionary = UnlockDefs.PACKS[id]
	var owned := p.owns("packs", id)
	var c := CampUi.card(false, ACCENT) if owned else CampUi.locked_card()
	var v := UiTheme.vbox(10)
	c.add_child(v)
	var head := UiTheme.hbox(10)
	v.add_child(head)
	var n := (d.runes as Array).size() + (d.kinds as Array).size() + (d.passives as Array).size()
	var tr := CampUi.title_row("dice", ACCENT if owned else UiPalette.TEXT_MUTED, String(d.name), "%d ITEMS" % n, 56)
	tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tr)
	if owned:
		head.add_child(CampUi.chip("OWNED", ACCENT.darkened(0.45), UiPalette.TEXT, 18))
	else:
		var cost := UnlockDefs.sigil_cost("packs", id)
		var b := CampUi.buy_button("UNLOCK", cost, p.can_afford(cost), 22)
		b.pressed.connect(cmd.bind(["unlock", "packs", id]))
		head.add_child(b)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(flow)
	for r in d.runes:
		flow.add_child(_item_chip(UiIcons.rune_icon(String(r)), String(Runes.DEFS[r].name), UiPalette.rune_color(String(r)), owned))
	for k in d.kinds:
		flow.add_child(_item_chip("dice", DiceKinds.label(String(k)), UiPalette.kind_color(String(k)), owned))
	for pid in d.passives:
		flow.add_child(_passive_chip(String(pid), owned))
	if not owned:
		var m := CampInfo.milestone_for("packs", id)
		if not m.is_empty():
			v.add_child(CampUi.lock_line(String(m.desc)))
	if not owned:
		c.modulate = Color(1, 1, 1, 0.92)
	return c


func _item_chip(icon: String, text: String, color: Color, on: bool) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(Color(0.03, 0.03, 0.09, 0.6), 14, 2, Color(color, 0.45 if on else 0.15)), 8, 4))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UiTheme.hbox(6)
	p.add_child(row)
	row.add_child(UiIcons.rect(icon, 24, color if on else color.darkened(0.4)))
	row.add_child(UiTheme.label(text, 18, UiPalette.TEXT if on else UiPalette.TEXT_MUTED, false, 0, false, 600))
	return p


func _passive_chip(id: String, on: bool) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(Color(0.03, 0.03, 0.09, 0.6), 14, 2, Color(1, 1, 1, 0.08)), 6, 3))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UiTheme.hbox(6)
	p.add_child(row)
	var ic := PassiveIcon.make(id, 28)
	if not on:
		ic.modulate = Color(0.6, 0.6, 0.7)
	row.add_child(ic)
	row.add_child(UiTheme.label(String(Passives.DEFS[id].name) if Passives.DEFS.has(id) else id, 18,
		UiPalette.TEXT if on else UiPalette.TEXT_MUTED, false, 0, false, 600))
	return p


func _pool_card(p: Profile, kind: String, label: String) -> Control:
	var owned := UnlockDefs.pool_from_packs(p.unlocks.get("packs", []), kind)
	var off: Array = p.disabled.get(kind, [])
	var cap := int(floor(owned.size() * UnlockDefs.POOL_TOGGLE_MAX))
	var c := CampUi.card(false, ACCENT)
	var v := UiTheme.vbox(10)
	c.add_child(v)
	var head := UiTheme.hbox(10)
	v.add_child(head)
	var hl := UiTheme.label(label.to_upper(), 24, UiPalette.TEXT, true, 5)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hl)
	head.add_child(UiTheme.label("%d / %d off" % [off.size(), cap], 19, UiPalette.GOLD if off.size() < cap else UiPalette.HP_BRIGHT, false, 0, false, 700))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	flow.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(flow)
	for id in owned:
		var is_off := off.has(id)
		var can := is_off or off.size() < cap
		var icon := ""
		var col := UiPalette.GOLD
		var name := String(id)
		match kind:
			"runes":
				icon = UiIcons.rune_icon(String(id))
				col = UiPalette.rune_color(String(id))
				name = String(Runes.DEFS[id].name)
			"kinds":
				icon = "dice"
				col = UiPalette.kind_color(String(id))
				name = DiceKinds.label(String(id))
			"passives":
				icon = PassiveIcon.glyph(String(id))
				col = UiPalette.passive_color(Passives.rarity(String(id)))
				name = String(Passives.DEFS[id].name)
		var t := _toggle(icon, name, col, not is_off, can)
		t.pressed.connect(cmd.bind(["toggle_pool", kind, String(id), is_off]))
		flow.add_child(t)
	if cap == 0:
		v.add_child(CampUi.lock_line("Unlock more packs to toggle this pool."))
	return c


func _toggle(icon: String, text: String, color: Color, on: bool, can: bool) -> CampUi.Tile:
	var t := CampUi.Tile.new()
	t.enabled = can
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	t.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can else Control.CURSOR_ARROW
	t.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var sb := UiTheme.box(Color(0.05, 0.06, 0.14, 0.9) if on else Color(0.03, 0.03, 0.07, 0.5), 16, 2,
		Color(color, 0.55) if on else Color(UiPalette.DANGER, 0.45))
	UiTheme.pad(sb, 10, 5)
	t.add_theme_stylebox_override("panel", sb)
	var row := UiTheme.hbox(6)
	t.add_child(row)
	row.add_child(UiIcons.rect(icon, 24, color if on else UiPalette.TEXT_MUTED))
	var l := UiTheme.label(text, 18, UiPalette.TEXT if on else UiPalette.TEXT_MUTED, false, 0, false, 600)
	row.add_child(l)
	if not on:
		row.add_child(UiTheme.label("OFF", 16, UiPalette.HP_BRIGHT, false, 0, false, 700))
	if not can:
		t.modulate = Color(1, 1, 1, 0.6)
	return t


func _starter_card(p: Profile) -> Control:
	var d := UnlockDefs.upgrade_def("workshop", "starter_kit")
	var owned := int(p.upgrades.get("starter_kit", 0)) >= 1
	var c := CampUi.card(owned, ACCENT)
	var v := UiTheme.vbox(10)
	c.add_child(v)
	var head := UiTheme.hbox(10)
	v.add_child(head)
	var tr := CampUi.title_row("dice", ACCENT, String(d.name), "SECOND STARTING DIE", 56)
	tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tr)
	if not owned:
		var b := CampUi.buy_button("BUY", d.cost, p.can_afford(d.cost), 22)
		b.pressed.connect(cmd.bind(["buy_upgrade", "workshop", "starter_kit"]))
		head.add_child(b)
	v.add_child(UiTheme.para(String(d.desc), 19, UiPalette.TEXT_DIM, 500))
	if owned:
		var row := UiTheme.hbox(10)
		v.add_child(row)
		var cur := p.starter_kind if p.starter_kind != "" else "standard"
		for k in UnlockDefs.starter_kinds(p.pool("kinds")):
			var dd: Dictionary = DiceKinds.def(String(k))
			var t := CampUi.tile(DiceKinds.label(String(k)), String(dd.get("desc", "")), cur == String(k), true, "dice", UiPalette.kind_color(String(k)))
			t.pressed.connect(cmd.bind(["set_starter_kind", String(k)]))
			row.add_child(t)
	return c


func _whetstone_card(p: Profile) -> Control:
	var d := UnlockDefs.upgrade_def("workshop", "whetstone")
	var owned := int(p.upgrades.get("whetstone", 0)) >= 1
	var c := CampUi.card(owned, ACCENT)
	var row := UiTheme.hbox(10)
	c.add_child(row)
	var tr := CampUi.title_row("anvil", ACCENT, String(d.name), String(d.desc).to_upper(), 56)
	tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tr)
	if owned:
		row.add_child(CampUi.chip("OWNED", ACCENT.darkened(0.45), UiPalette.TEXT, 18))
	else:
		var b := CampUi.buy_button("BUY", d.cost, p.can_afford(d.cost), 22)
		b.pressed.connect(cmd.bind(["buy_upgrade", "workshop", "whetstone"]))
		row.add_child(b)
	return c
