class_name RunSetupModal
extends CampModal
## Run setup: class (unlocked ones; locked ones show their unlock), mode (Standard / Short
## Road), ascension (once unlocked), the loadout summary (pet + minigames, with shortcuts to the
## Pet Den and the Arcade) and START. Emits start_pressed; every choice is a Camp command so
## it is saved in the profile's loadout.

signal start_pressed

const MODES := {
	"standard": ["Standard", "15 laps  ·  3 biomes  ·  full Crowns"],
	"short": ["Short Road", "10 laps  ·  2 biomes  ·  60% Crowns"],
}


func _build() -> void:
	set_title("NEW RUN", UiPalette.GOLD)


func rebuild(p: Profile) -> void:
	body.add_child(CampModal.heading("Hero"))
	var cur := String(p.loadout.get("class", "knight"))
	if not p.class_allowed(cur):
		cur = "knight"
	body.add_child(hero_card(p, cur))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_child(grid)
	for id in HeroDefs.IDS:
		var st := ClassCard.state_for(p, String(id), cur)
		var lock := ClassCard.unlock_text(p, String(id)) if st == ClassCard.State.LOCKED or st == ClassCard.State.SECRET else ""
		var t := ClassCard.make(String(id), st, lock)
		t.size_flags_vertical = Control.SIZE_FILL
		t.pressed.connect(cmd.bind(["set_class", String(id)]))
		grid.add_child(t)
	body.add_child(CampModal.heading("Mode"))
	var mrow := UiTheme.hbox(10)
	body.add_child(mrow)
	var mode := String(p.loadout.get("mode", "standard"))
	for m in ["standard", "short"]:
		var t := CampUi.tile(String(MODES[m][0]), String(MODES[m][1]), mode == m, true, "flag" if m == "standard" else "speed", UiPalette.GOLD)
		t.pressed.connect(cmd.bind(["set_mode", m]))
		mrow.add_child(t)
	var unl := int(p.ascension.get("unlocked", 0))
	if unl > 0:
		body.add_child(CampModal.heading("Ascension", "Win at your highest level to unlock the next. +8% Crowns per level."))
		body.add_child(_ascension(p, unl))
	body.add_child(CampModal.heading("Loadout"))
	body.add_child(_loadout(p))
	body.add_child(UiTheme.spacer(4))
	var go := GameButton.make("START RUN", "arrow_right", GameButton.Kind.PRIMARY, 42)
	go.icon_tint = UiPalette.TEXT_DARK
	go.min_height = 108
	go.pressed.connect(func() -> void: start_pressed.emit())
	body.add_child(go)


## The chosen hero: a turning portrait in the equipped Wardrobe look, the mechanic badge and HP.
static func hero_card(p: Profile, id: String) -> Control:
	var c := CampUi.card(true)
	var row := UiTheme.hbox(12)
	c.add_child(row)
	var por := HeroPortrait.new()
	por.custom_minimum_size = Vector2(190, 230)
	por.ring_color = UiPalette.class_color(id)
	por.set_hero(id, p.equipped_skin(id), p.prestige_on(id), false)
	row.add_child(por)
	var col := UiTheme.vbox(8)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	var d: Dictionary = HeroDefs.DATA[id]
	var head := UiTheme.hbox(10)
	col.add_child(head)
	var nm := UiTheme.label(String(d.name), 34, UiPalette.class_color(id).lightened(0.2), true, 6)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	var hp := CampUi.amount("heart", int(d.hp), UiPalette.HP, 22)
	head.add_child(hp)
	col.add_child(ClassDetail.mechanic_badge(id, 17))
	return c


func _ascension(p: Profile, unl: int) -> Control:
	var sel := int(p.ascension.get("selected", 0))
	var c := CampUi.card(sel > 0, UiPalette.DANGER)
	var row := UiTheme.hbox(12)
	c.add_child(row)
	var minus := GameButton.round_icon("arrow_left", 68)
	minus.kind = GameButton.Kind.SECONDARY
	minus.set_enabled(sel > 0)
	minus.pressed.connect(cmd.bind(["set_ascension", sel - 1]))
	row.add_child(minus)
	var col := UiTheme.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var t := UiTheme.label("ASCENSION %d" % sel if sel > 0 else "ASCENSION OFF", 28, UiPalette.HP_BRIGHT if sel > 0 else UiPalette.TEXT, true, 5)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var desc := "Unlocked up to %d. The rules stack." % unl
	if sel > 0:
		desc = String(UnlockDefs.ASCENSION[sel - 1].desc)
	var dl := UiTheme.para(desc, 19, UiPalette.TEXT_DIM, 500)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(dl)
	var plus := GameButton.round_icon("arrow_right", 68)
	plus.kind = GameButton.Kind.SECONDARY
	plus.set_enabled(sel < unl)
	plus.pressed.connect(cmd.bind(["set_ascension", sel + 1]))
	row.add_child(plus)
	return c


func _loadout(p: Profile) -> Control:
	var col := UiTheme.vbox(10)
	# pet
	var pc := CampUi.card(false, CampInfo.STATIONS.pet_den.color)
	col.add_child(pc)
	var prow := UiTheme.hbox(12)
	pc.add_child(prow)
	var pet := String(p.loadout.get("pet", ""))
	var has_pets := not (p.unlocks.get("pets", []) as Array).is_empty()
	if pet != "":
		var lvl := p.pet_level(pet)
		var tr := CampUi.title_row(String(CampInfo.PET_ICON.get(pet, "heart")), CampInfo.PET_COLOR.get(pet, UiPalette.GOLD), PetDefs.name_of(pet),
			"PET  ·  LEVEL %d" % lvl, 56)
		tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prow.add_child(tr)
	else:
		var tr := CampUi.title_row("heart", UiPalette.TEXT_MUTED, "No pet", "EQUIP ONE IN THE PET DEN" if has_pets else "FIRST PET: " + String(CampInfo.milestone_for("pets", "pumpkin_sprite").get("desc", "")).to_upper(), 56)
		tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prow.add_child(tr)
	if has_pets:
		var b := GameButton.make("CHANGE", "", GameButton.Kind.SECONDARY, 20)
		b.min_height = 60
		b.pressed.connect(func() -> void: open_station.emit("pet_den"))
		prow.add_child(b)
	# minigames
	var mc := CampUi.card(false, CampInfo.STATIONS.arcade.color)
	col.add_child(mc)
	var mcol := UiTheme.vbox(8)
	mc.add_child(mcol)
	var mhead := UiTheme.hbox(10)
	mcol.add_child(mhead)
	var ml := UiTheme.label("MINIGAMES  %d / %d" % [(p.loadout.minigames as Array).size(), p.loadout_slots()], 20, UiPalette.GOLD, false, 0, false, 700)
	ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mhead.add_child(ml)
	var b2 := GameButton.make("CHANGE", "", GameButton.Kind.SECONDARY, 20)
	b2.min_height = 60
	b2.pressed.connect(func() -> void: open_station.emit("arcade"))
	mhead.add_child(b2)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mcol.add_child(flow)
	for id in p.loadout.minigames:
		var chip := PanelContainer.new()
		var cc: Color = CampInfo.MINIGAME_COLOR.get(String(id), UiPalette.GOLD)
		chip.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(Color(0.03, 0.03, 0.09, 0.7), 16, 2, Color(cc, 0.6)), 10, 6))
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var r := UiTheme.hbox(8)
		chip.add_child(r)
		r.add_child(UiIcons.rect(String(CampInfo.MINIGAME_ICON.get(String(id), "star")), 26, cc))
		r.add_child(UiTheme.label(MinigameDefs.name_of(String(id)), 20, UiPalette.TEXT, false, 0, false, 600))
		flow.add_child(chip)
	if (p.loadout.minigames as Array).is_empty():
		flow.add_child(UiTheme.label("None equipped", 19, UiPalette.TEXT_MUTED, false, 0, false, 600))
	return col
