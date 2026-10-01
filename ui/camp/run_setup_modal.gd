class_name RunSetupModal
extends CampModal
## NEW RUN (docs/design/2026-10-01-new-run-window.md): the hero (portrait, stats, mechanic, kit
## and the hero picker), the route (Standard / Short Road, the biome pool per tier, Ascension
## with its stacked rules), the loadout (pet, minigames, potion belt, dice pool: each tile opens
## its station) and START RUN in a footer that never scrolls away. Two columns when the canvas
## is wide (desktop, iPad landscape), one column on phones. Locked things are greyed and the
## hint line under their group says how to unlock the hovered / tapped one.
##
## Keys (desktop): Enter = START RUN, Esc = close (the one exit), <- / -> = previous / next
## hero, up / down = Ascension +1 / -1. Every choice is a Camp command (saved in the loadout).

signal start_pressed

const MODES := {
	"standard": {"name": "Standard", "sub": "The full journey", "icon": "flag", "laps": 15, "biomes": 3, "crowns": 100},
	"short": {"name": "Short Road", "sub": "A quick journey", "icon": "speed", "laps": 10, "biomes": 2, "crowns": 60},
}
## Two columns from this much free canvas width (logical px); the panel is at most WIDE_W.
const WIDE_MIN := 1180.0
const WIDE_W := 1320.0
const NARROW_W := 720.0
const COL_GAP := 32
const HERO_COLS := 4
## Minigame slots with the Arcade upgrade.
const MAX_MG_SLOTS := 3
## Ascension: Crowns bonus per level (UnlockDefs / Economy: +8%).
const ASC_CROWNS_PCT := 8
## Loadout tiles -> the station they open.
const LOADOUT := [
	["pet", "Pet", "pet_den"], ["minigames", "Minigames", "arcade"],
	["potions", "Potion belt", "armory"], ["dice", "Dice pool", "workshop"],
]

## START RUN (footer, outside the scroll; Enter).
var start_button: GameButton
## True while laid out in two columns.
var wide := false
## True on short canvases (phone landscape, zoomed desktops): slimmer footer and portrait.
var slim := false
## The locked hero / biome whose unlock hint shows ("" = the first locked one).
var peek_class := ""
var peek_biome := ""
var _footer: VBoxContainer
var _class_hint: Label
var _biome_hint: Label
var _locked_classes: Array = []
var _locked_biomes: Array = []


func _build() -> void:
	set_title("NEW RUN", UiPalette.GOLD)
	# the panel holds [scroll, footer]: START RUN stays visible while the body scrolls
	var holder := UiTheme.vbox(14)
	panel.remove_child(_scroll)
	panel.add_child(holder)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.add_child(_scroll)
	_footer = UiTheme.vbox(0)
	_footer.name = "Footer"
	holder.add_child(_footer)
	start_button = GameButton.make("START RUN", "", GameButton.Kind.PRIMARY, 40)
	start_button.name = "StartRun"
	start_button.min_height = 100
	start_button.shortcut_hint = "key_enter"
	start_button.pressed.connect(func() -> void: start_pressed.emit())
	_footer.add_child(start_button)
	# Enter starts the run (Esc / the corner x close the screen)
	primary_action = start_button


## The footer sits under the scroll, so it counts as chrome.
func chrome_height() -> float:
	var h := super.chrome_height()
	if _footer != null:
		h += _footer.get_combined_minimum_size().y + 14.0
	return h


func _layout() -> void:
	if _frame == null or size.x <= 0.0:
		return
	var w := _wants_wide()
	max_width = WIDE_W if w else NARROW_W
	# short canvases (phone landscape): a slimmer footer leaves the body more room
	var sl := size.y < 1000.0
	var fh := 80.0 if sl else 100.0
	if start_button.min_height != fh:
		start_button.min_height = fh
		start_button.update_minimum_size()
	if w != wide or sl != slim:
		wide = w
		slim = sl
		if profile != null:
			show_profile(profile)
			return
	super._layout()
	_fit_to_screen()


## CampModal lays out at its width and never scales: when the content is still wider than the
## safe screen (zoomed phones), shrink the frame around its centre like UiModal does.
func _fit_to_screen() -> void:
	var safe := UiTheme.safe_margins(self)
	var avail := size.x - safe.left - safe.right
	var fw := _frame.size.x
	var k := clampf(avail / fw, 0.6, 1.0) if fw > 0.0 else 1.0
	if is_equal_approx(k, _fit):
		return
	var was := _fit
	_fit = k
	if is_equal_approx(_frame.scale.x, was):
		_frame.scale = Vector2.ONE * k
	_frame.position.x = (size.x - fw) * 0.5
	_place_close()


func _wants_wide() -> bool:
	var safe := UiTheme.safe_margins(self)
	return size.x - safe.left - safe.right >= WIDE_MIN


func rebuild(p: Profile) -> void:
	wide = _wants_wide()
	slim = size.y > 0.0 and size.y < 1000.0
	var cur := String(p.loadout.get("class", "knight"))
	if not p.class_allowed(cur):
		cur = "knight"
	var hero := _hero_section(p, cur)
	var route := _route_section(p)
	var loadout := _loadout_section(p)
	if wide:
		var cols := UiTheme.hbox(COL_GAP)
		cols.name = "Columns"
		body.add_child(cols)
		var left := UiTheme.vbox(18)
		var right := UiTheme.vbox(22)
		for c in [left, right]:
			(c as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cols.add_child(c)
		left.add_child(hero)
		right.add_child(route)
		right.add_child(loadout)
	else:
		body.add_child(hero)
		body.add_child(route)
		body.add_child(loadout)
	_update_footer(p, cur)


func _update_footer(p: Profile, cur: String) -> void:
	var bits := PackedStringArray([String(HeroDefs.DATA[cur].name), String(MODES[_mode(p)].name)])
	var sel := int(p.ascension.get("selected", 0))
	if sel > 0:
		bits.append("Ascension %d" % sel)
	start_button.sub_text = "  ·  ".join(bits)


static func _mode(p: Profile) -> String:
	var m := String(p.loadout.get("mode", "standard"))
	return m if MODES.has(m) else "standard"


# ---------------------------------------------------------------- sections

## Section header: pack icon + gold caps title + a faint rule to the edge.
static func section(title: String, icon: String) -> HBoxContainer:
	var row := UiTheme.hbox(10)
	row.name = "Section_" + title.replace(" ", "")
	var ic := CampArt.icon(icon, 30, UiPalette.GOLD)
	row.add_child(ic)
	var l := UiTheme.label(title.to_upper(), 21, UiPalette.GOLD, false, 0, false, 800)
	row.add_child(l)
	var rule := ColorRect.new()
	rule.color = UiPalette.GOLD_FAINT
	rule.custom_minimum_size = Vector2(24, 2)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rule)
	return row


func _hero_section(p: Profile, cur: String) -> VBoxContainer:
	var v := UiTheme.vbox(14)
	v.name = "Hero"
	v.add_child(section("Hero", "helmet"))
	v.add_child(hero_card(p, cur, 0.0 if wide and not slim else -1.0))
	v.add_child(_hero_grid(p, cur))
	v.add_child(_class_hint_row())
	return v


## The chosen hero: the turning portrait in its Wardrobe look, name, stat chips, mechanic
## badge and the Armory kit (with the Armory shortcut). `portrait_w` < 0 = the phone size.
func hero_card(p: Profile, id: String, portrait_w := 0.0) -> Control:
	var c := _panel("info", UiPalette.class_color(id))
	c.name = "HeroCard"
	var outer := UiTheme.vbox(12)
	c.add_child(outer)
	var row := UiTheme.hbox(16)
	outer.add_child(row)
	var por := HeroPortrait.new()
	por.custom_minimum_size = Vector2(136, 190) if portrait_w < 0.0 else Vector2(180, 220)
	por.ring_color = UiPalette.class_color(id)
	por.set_hero(id, p.equipped_skin(id), p.prestige_on(id), false, ArmoryLook.of_profile(p, id))
	row.add_child(por)
	var col := UiTheme.vbox(10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	var d: Dictionary = HeroDefs.DATA[id]
	var nm := UiTheme.label(String(d.name), 36, UiPalette.class_color(id).lightened(0.25), true, 6)
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.custom_minimum_size.x = 80
	col.add_child(nm)
	var stats := HFlowContainer.new()
	stats.add_theme_constant_override("h_separation", 8)
	stats.add_theme_constant_override("v_separation", 6)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(stats)
	stats.add_child(stat_chip("heart", "%d" % int(d.hp), "Health", UiPalette.HP_BRIGHT))
	stats.add_child(stat_chip("sword", "+%d" % int(d.atk), "Attack bonus", UiPalette.TEXT))
	stats.add_child(stat_chip("reroll", "%d" % int(d.board_rerolls), "Move rerolls per lap", UiPalette.GOLD_BRIGHT))
	stats.add_child(stat_chip("dice", "%d" % int(HeroDefs.field(id, "combat_rerolls")), "Fight rerolls", UiPalette.DIE_BODY))
	var badge := ClassDetail.mechanic_badge(id, 17)
	var mech := ClassInfo.mechanic(id)
	badge.add_theme_stylebox_override("panel", surface("inset", ClassInfo.mechanic_color(mech) if mech != "" else UiPalette.class_color(id)))
	col.add_child(badge)
	outer.add_child(_kit_row(p, id))
	return c


## Icon + value pill with a tooltip naming the stat.
static func stat_chip(icon: String, value: String, tip: String, col: Color) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.inset_box(), 10, 4))
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	pc.tooltip_text = tip
	var r := UiTheme.hbox(6)
	pc.add_child(r)
	var ic := Icons.rect(icon, 26)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(ic)
	r.add_child(UiTheme.label(value, 22, col, true, 0))
	return pc


## KIT: the class's Armory items (tooltips name them) and the round Armory shortcut.
func _kit_row(p: Profile, id: String) -> Control:
	var v := UiTheme.vbox(4)
	v.name = "Kit"
	var row := UiTheme.hbox(10)
	v.add_child(row)
	var kc: Color = CampInfo.STATIONS.armory.color
	var l := UiTheme.label("KIT", 17, kc, false, 0, false, 800)
	row.add_child(l)
	var strip := KitStrip.of_profile(p, id, 48, 16)
	strip.alignment = FlowContainer.ALIGNMENT_BEGIN
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(strip)
	var st := CampInfo.station_state(p, "armory")
	if bool(st.locked):
		v.add_child(CampUi.lock_line("Armory: " + String(st.text), 16))
		return v
	var b := GameButton.round_icon(CampArt.resolve("station_armory"), 64)
	b.name = "ArmoryButton"
	b.round_family = "blue"
	b.tooltip_text = "Armory: forge and equip this kit"
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void: open_station.emit("armory"))
	row.add_child(b)
	var active := 0
	for e in strip.entries:
		if int(e.tier) > 0:
			active += 1
	if active == 0 and not strip.entries.is_empty():
		var hint := UiTheme.para("Forge a rank at the Armory to switch these on.", 16, UiPalette.HP_BRIGHT, 700)
		v.add_child(hint)
	return v


func _hero_grid(p: Profile, cur: String) -> GridContainer:
	var grid := GridContainer.new()
	grid.name = "HeroGrid"
	grid.columns = HERO_COLS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	_locked_classes.clear()
	for id in HeroDefs.IDS:
		var cid := String(id)
		var st := ClassCard.state_for(p, cid, cur)
		var hint := ""
		if st == ClassCard.State.LOCKED or st == ClassCard.State.SECRET:
			hint = ClassCard.unlock_text(p, cid)
			_locked_classes.append([cid, hint])
		var t := HeroTile.make(cid, st, hint)
		t.pressed.connect(cmd.bind(["set_class", cid]))
		t.peeked.connect(func() -> void: _peek_class(cid))
		grid.add_child(t)
	if peek_class != "" and not _locked_has(_locked_classes, peek_class):
		peek_class = ""
	return grid


func _class_hint_row() -> Control:
	var row := _hint_row()
	row.name = "ClassHint"
	_class_hint = row.get_meta("label")
	row.visible = not _locked_classes.is_empty()
	_update_class_hint()
	return row


func _peek_class(id: String) -> void:
	peek_class = id
	_update_class_hint()


func _update_class_hint() -> void:
	if _class_hint == null or _locked_classes.is_empty():
		return
	var e: Array = _locked_classes[0]
	for x in _locked_classes:
		if String(x[0]) == peek_class:
			e = x
	var cid := String(e[0])
	var name := "???" if ClassCard.is_secret(cid) else String(HeroDefs.DATA[cid].name)
	_class_hint.text = "%s: %s" % [name, String(e[1])]


## "Complete 20 laps in total. Or 5 Sigils." (the milestone, then the Sigil price if any).
static func unlock_text(p: Profile, kind: String, id: String) -> String:
	var m := CampInfo.milestone_for(kind, id)
	var t := String(m.get("desc", "Locked")).strip_edges()
	var cost := UnlockDefs.sigil_cost(kind, id, p.unlocks.get("classes", []) if p != null else null)
	if not cost.is_empty():
		t += " Or %d Sigils." % int(cost.sigils)
	return t


## Flat surfaces (user rule: popup tiles must not look like buttons; only real actions get the
## 3D lip). No lip, no drop shadow, no bevel. state: "normal" | "hover" (selectable tiles) |
## "selected" (yellow inner rim) | "info" (read-only card) | "inset" | "locked". `accent` = a
## thin rim colour. The shared flat tile: UiTheme.tile_box (pieces tile / tile_accent).
static func surface(state: String, accent: Variant = null) -> StyleBox:
	return UiTheme.pad(UiTheme.inset_box() if state == "inset" else UiTheme.tile_box("normal" if state == "info" else state, accent if state in ["normal", "hover", "info"] else null), 14, 12)


## A read-only PanelContainer on a flat surface (no hover).
static func _panel(state: String, accent: Variant = null) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", surface(state, accent))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


static func _locked_has(list: Array, id: String) -> bool:
	for x in list:
		if String(x[0]) == id:
			return true
	return false


## An inset line with a padlock and a wrapped label (meta "label").
static func _hint_row() -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.inset_box(), 14, 8))
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := UiTheme.hbox(10)
	pc.add_child(r)
	var lk := CampArt.lock_icon(22)
	r.add_child(lk)
	var l := UiTheme.para("", 17, UiPalette.TEXT_DIM, 600)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(l)
	pc.set_meta("label", l)
	return pc


func _route_section(p: Profile) -> VBoxContainer:
	var v := UiTheme.vbox(14)
	v.name = "Route"
	v.add_child(section("Route", "flag"))
	var mrow := UiTheme.hbox(12)
	mrow.name = "Modes"
	v.add_child(mrow)
	var mode := _mode(p)
	for m in ["standard", "short"]:
		var t := ModeCard.make(String(m), mode == m)
		t.pressed.connect(cmd.bind(["set_mode", m]))
		mrow.add_child(t)
	v.add_child(_biome_pool(p, mode))
	v.add_child(_ascension(p))
	return v


## The biome pool by tier (the route draws one biome per tier; the Short Road's second biome
## comes from tiers II and III): unlocked biomes in colour, locked ones greyed.
func _biome_pool(p: Profile, mode: String) -> Control:
	var c := PanelContainer.new()
	c.name = "Biomes"
	c.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.inset_box(), 14, 10))
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	var v := UiTheme.vbox(8)
	c.add_child(v)
	var head := UiTheme.hbox(8)
	v.add_child(head)
	head.add_child(UiTheme.label("BIOMES", 16, UiPalette.TEXT_DIM, false, 0, false, 800))
	var sub := UiTheme.label("one per stage, drawn at random" if mode == "standard" else "stage 1, then one of the rest", 16, UiPalette.TEXT_MUTED, false, 0, false, 500)
	head.add_child(sub)
	var flow := HFlowContainer.new()
	flow.name = "Pool"
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 6)
	flow.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(flow)
	var groups: Array = [BiomeDefs.TIERS[0], BiomeDefs.TIERS[1], BiomeDefs.TIERS[2]]
	if mode == "short":
		groups = [BiomeDefs.TIERS[0], BiomeDefs.short_second_biomes()]
	var owned: Array = p.unlocks.get("biomes", [])
	_locked_biomes.clear()
	for gi in groups.size():
		var grp := UiTheme.hbox(4)
		flow.add_child(grp)
		for b in groups[gi]:
			var bid := String(b)
			var have := owned.has(bid)
			var hint := "" if have else unlock_text(p, "biomes", bid)
			if not have:
				_locked_biomes.append([bid, hint])
			var ic := BiomeChip.make(bid, have, hint, gi + 1)
			ic.peeked.connect(func() -> void: _peek_biome(bid))
			grp.add_child(ic)
		if gi < groups.size() - 1:
			var arrow := CampArt.icon("chevron_right", 20, UiPalette.TEXT_MUTED)
			grp.add_child(arrow)
	if peek_biome != "" and not _locked_has(_locked_biomes, peek_biome):
		peek_biome = ""
	if not _locked_biomes.is_empty():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.name = "BiomeHint"
		var lk := CampArt.lock_icon(20)
		row.add_child(lk)
		_biome_hint = UiTheme.para("", 16, UiPalette.TEXT_DIM, 600)
		_biome_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(_biome_hint)
		v.add_child(row)
		_update_biome_hint()
	else:
		_biome_hint = null
	return c


func _peek_biome(id: String) -> void:
	peek_biome = id
	_update_biome_hint()


func _update_biome_hint() -> void:
	if _biome_hint == null or _locked_biomes.is_empty():
		return
	var e: Array = _locked_biomes[0]
	for x in _locked_biomes:
		if String(x[0]) == peek_biome:
			e = x
	_biome_hint.text = "%s: %s" % [BiomeDefs.name_of(String(e[0])), String(e[1])]


## Ascension: - / + steppers around the level, pips for the unlocked levels and the stacked
## rules (the run's modifiers), the newest one highlighted. Locked until the first win.
func _ascension(p: Profile) -> Control:
	var unl := int(p.ascension.get("unlocked", 0))
	var sel := int(p.ascension.get("selected", 0))
	if unl <= 0:
		var lc := _panel("locked")
		lc.name = "Ascension"
		var row := UiTheme.hbox(14)
		lc.add_child(row)
		var m := CampArt.medal("ascension", 52, UiPalette.DANGER, true)
		m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(m)
		var col := UiTheme.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(UiTheme.label("Ascension", 24, UiPalette.TEXT_MUTED, true, 4))
		col.add_child(CampUi.lock_line("Win a run to unlock harder, richer runs.", 16))
		return lc
	var c := _panel("info", UiPalette.DANGER if sel > 0 else null)
	c.name = "Ascension"
	var v := UiTheme.vbox(10)
	c.add_child(v)
	var row := UiTheme.hbox(10)
	v.add_child(row)
	var minus := GameButton.round_icon("minus", 64)
	minus.name = "AscDown"
	minus.round_family = "grey"
	minus.shortcut_hint = "key_down"
	minus.tooltip_text = "Easier"
	minus.set_enabled(sel > 0)
	minus.pressed.connect(cmd.bind(["set_ascension", sel - 1]))
	row.add_child(minus)
	var mid := UiTheme.vbox(4)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(mid)
	var head := UiTheme.hbox(8)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_child(head)
	var t := UiTheme.label("ASCENSION %d" % sel if sel > 0 else "ASCENSION OFF", 26, UiPalette.HP_BRIGHT if sel > 0 else UiPalette.TEXT_DIM, true, 5)
	t.name = "AscLevel"
	head.add_child(t)
	# pips over the Crowns chip (stacked: a row of both is too wide for zoomed phones)
	var sub := UiTheme.vbox(6)
	sub.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_child(sub)
	var pips := CampUi.pips(sel, unl, UiPalette.HP_BRIGHT)
	pips.custom_minimum_size = Vector2(unl * 19, 20)
	pips.tooltip_text = "Unlocked up to %d of %d" % [unl, UnlockDefs.MAX_ASCENSION]
	pips.mouse_filter = Control.MOUSE_FILTER_PASS
	pips.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sub.add_child(pips)
	if sel > 0:
		sub.add_child(CampArt.chip("+%d%%" % (ASC_CROWNS_PCT * sel), "yellow", "crown", 16))
	var plus := GameButton.round_icon("plus", 64)
	plus.name = "AscUp"
	plus.round_family = "grey"
	plus.shortcut_hint = "key_up"
	plus.tooltip_text = "Harder: +%d%% Crowns" % ASC_CROWNS_PCT
	plus.set_enabled(sel < unl)
	plus.pressed.connect(cmd.bind(["set_ascension", sel + 1]))
	row.add_child(plus)
	if sel == 0:
		var l := UiTheme.para("Win at your highest level to unlock the next. Rules stack.", 16, UiPalette.TEXT_MUTED, 500)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		return c
	var rules := UiTheme.vbox(4)
	rules.name = "Rules"
	v.add_child(rules)
	for i in sel:
		var r: Dictionary = UnlockDefs.ASCENSION[i]
		rules.add_child(_rule_row(int(r.level), String(r.desc), i == sel - 1))
	return c


static func _rule_row(level: int, desc: String, newest: bool) -> HBoxContainer:
	var r := UiTheme.hbox(10)
	var n := UiTheme.label(str(level), 17, UiPalette.GOLD_BRIGHT if newest else UiPalette.TEXT_MUTED, true, 0)
	n.custom_minimum_size.x = 24
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	n.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	r.add_child(n)
	var d := UiTheme.para(desc, 16, UiPalette.TEXT if newest else UiPalette.TEXT_DIM, 600 if newest else 500)
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(d)
	return r


func _loadout_section(p: Profile) -> VBoxContainer:
	var v := UiTheme.vbox(14)
	v.name = "Loadout"
	v.add_child(section("Loadout", "pouch"))
	var grid := GridContainer.new()
	grid.name = "LoadoutGrid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(grid)
	for e in LOADOUT:
		var tile := _loadout_tile(p, String(e[0]), String(e[1]), String(e[2]))
		grid.add_child(tile)
	return v


func _loadout_tile(p: Profile, what: String, label: String, station: String) -> LoadoutTile:
	var st := CampInfo.station_state(p, station)
	var locked := bool(st.locked)
	var t := LoadoutTile.make(label, CampInfo.STATIONS[station].color, not locked)
	t.name = "Tile_" + what
	t.tooltip_text = "Open the %s" % String(CampInfo.STATIONS[station].name) if not locked else ""
	t.pressed.connect(func() -> void: open_station.emit(station))
	var row := t.content
	match what:
		"pet":
			var pet := String(p.loadout.get("pet", ""))
			if locked:
				row.add_child(CampArt.medal("station_pet_den", 52, UiPalette.TEXT_MUTED, true))
				row.add_child(_wrap_lock(String(st.text)))
			elif pet == "":
				row.add_child(CampArt.medal("station_pet_den", 52, UiPalette.TEXT_MUTED, true))
				row.add_child(_tile_text("No pet", "Tap to pick one" if InputMode.is_touch() else "Click to pick one", UiPalette.TEXT_MUTED))
			else:
				var pc: Color = CampInfo.PET_COLOR.get(pet, UiPalette.GOLD)
				row.add_child(CampArt.medal(String(CampInfo.PET_GLYPH.get(pet, "station_pet_den")), 52, pc))
				var col := _tile_text(PetDefs.name_of(pet), "", UiPalette.TEXT)
				col.add_child(CampArt.chip("LV %d" % p.pet_level(pet), "green", "", 16))
				row.add_child(col)
		"minigames":
			var eq: Array = p.loadout.get("minigames", [])
			var slots := p.loadout_slots()
			t.set_count("%d / %d" % [eq.size(), slots])
			for i in maxi(slots, MAX_MG_SLOTS):
				if i < eq.size():
					var mid := String(eq[i])
					var m := CampArt.medal(String(CampInfo.MINIGAME_GLYPH.get(mid, "station_arcade")), 46, CampInfo.MINIGAME_COLOR.get(mid, UiPalette.GOLD))
					m.tooltip_text = MinigameDefs.name_of(mid)
					m.mouse_filter = Control.MOUSE_FILTER_PASS
					row.add_child(m)
				elif i < slots:
					row.add_child(_empty_slot("Empty slot"))
				else:
					row.add_child(_locked_slot(_feature_hint(p, "loadout_slot", "Arcade")))
		"potions":
			var cap := p.potion_cap()
			t.set_count("%d" % cap)
			for i in Balance.POTION_MAX_CAP:
				if i < cap:
					var ic := CampArt.icon("potion_healing", 44)
					ic.tooltip_text = "Potion slot"
					ic.mouse_filter = Control.MOUSE_FILTER_PASS
					row.add_child(ic)
				else:
					row.add_child(_locked_slot(_feature_hint(p, "potion_belt", "Armory")))
		"dice":
			var packs: Array = p.unlocks.get("packs", [])
			t.set_count("%d / %d" % [packs.size(), UnlockDefs.PACK_IDS.size()])
			var shown := 0
			for id in UnlockDefs.PACK_IDS:
				if packs.has(id) and shown < 3:
					var ic := CampArt.icon(String(CampInfo.PACK_ICON.get(String(id), "pack")), 44)
					ic.tooltip_text = String(UnlockDefs.PACKS[id].name)
					ic.mouse_filter = Control.MOUSE_FILTER_PASS
					row.add_child(ic)
					shown += 1
			if packs.size() > shown:
				row.add_child(UiTheme.label("+%d" % (packs.size() - shown), 20, UiPalette.TEXT_DIM, true, 0))
	return t


## How the locked third slot unlocks: its milestone, then the Crowns upgrade at `station`.
static func _feature_hint(p: Profile, feature: String, station: String) -> String:
	if not p.owns("features", feature):
		return unlock_text(p, "features", feature)
	var track := "arcade" if feature == "loadout_slot" else "armory"
	var cost := int((UnlockDefs.upgrade_def(track, feature).get("cost", {}) as Dictionary).get("crowns", 0))
	return "%s upgrade: %d Crowns" % [station, cost]


static func _tile_text(title: String, sub: String, col: Color) -> VBoxContainer:
	var v := UiTheme.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var t := UiTheme.label(title, 22, col, true, 4)
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.custom_minimum_size.x = 60
	v.add_child(t)
	if sub != "":
		var s := UiTheme.label(sub, 16, UiPalette.TEXT_MUTED, false, 0, false, 600)
		s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		s.custom_minimum_size.x = 60
		v.add_child(s)
	return v


static func _wrap_lock(text: String) -> Label:
	var l := UiTheme.para(text, 16, UiPalette.TEXT_MUTED, 600)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func _empty_slot(tip: String) -> Control:
	var m := CampArt.medal("plus", 46, UiPalette.TEXT_MUTED, true)
	m.modulate = Color(1, 1, 1, 0.6)
	m.tooltip_text = tip
	m.mouse_filter = Control.MOUSE_FILTER_PASS
	return m


static func _locked_slot(tip: String) -> Control:
	var m := CampArt.medal("lock", 46, UiPalette.TEXT_MUTED, true)
	m.modulate = Color(1, 1, 1, 0.75)
	m.tooltip_text = "Locked: " + tip
	m.mouse_filter = Control.MOUSE_FILTER_PASS
	return m


# ---------------------------------------------------------------- keys

func _input(event: InputEvent) -> void:
	super._input(event)
	if not is_open() or not visible or not is_top() or profile == null:
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_LEFT:
			cycle_class(-1)
		KEY_RIGHT:
			cycle_class(1)
		KEY_UP:
			step_ascension(1)
		KEY_DOWN:
			step_ascension(-1)
		_:
			return
	_handled()


## Next / previous unlocked hero (wraps).
func cycle_class(dir: int) -> void:
	var open: Array = []
	for id in HeroDefs.IDS:
		if profile.class_allowed(String(id)):
			open.append(String(id))
	if open.size() < 2:
		return
	var i := open.find(String(profile.loadout.get("class", "knight")))
	cmd(["set_class", open[posmod(i + dir, open.size())]])


func step_ascension(dir: int) -> void:
	var unl := int(profile.ascension.get("unlocked", 0))
	var sel := int(profile.ascension.get("selected", 0))
	var n := clampi(sel + dir, 0, unl)
	if n != sel:
		cmd(["set_ascension", n])


# ---------------------------------------------------------------- widgets

## Base for the tappable tiles here: card look by state, hover look, tap -> pressed; a tap or
## hover on a locked tile -> peeked (its unlock hint shows in the group's hint line).
class Pick:
	extends PanelContainer
	signal pressed
	signal peeked
	var enabled := true
	var selected := false
	var accent: Variant = null
	var _down := false

	func _init() -> void:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_STOP
		# never a tap target under 88 canvas px (44 pt on a phone)
		custom_minimum_size.y = UiTheme.TOUCH
		mouse_entered.connect(_hover.bind(true))
		mouse_exited.connect(_hover.bind(false))

	func style(sel: bool, en: bool, p_accent: Variant = null) -> void:
		selected = sel
		enabled = en
		accent = p_accent
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if en else Control.CURSOR_ARROW
		add_theme_stylebox_override("panel", _box("selected" if sel else ("normal" if en else "locked")))

	func _box(state: String) -> StyleBox:
		return RunSetupModal.surface(state, accent if state in ["normal", "hover"] else null)

	func _hover(on: bool) -> void:
		if not enabled:
			if on:
				peeked.emit()
			return
		if not selected:
			add_theme_stylebox_override("panel", _box("hover" if on else "normal"))

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_down = true
			accept_event()
		elif _down:
			_down = false
			accept_event()
			if get_global_rect().has_point(mb.global_position):
				activate()

	## Tap / click: pressed when enabled (and not already selected), else peek + error buzz.
	func activate() -> void:
		if enabled:
			UiTheme.sfx("click")
			UiTheme.pop(self, 1.04, 0.18)
			if not selected:
				pressed.emit()
		else:
			UiTheme.sfx("error")
			UiTheme.pop(self, 1.03, 0.15)
			peeked.emit()


## A hero in the picker: medallion over the name; selected = gold rim + check, locked =
## greyed medallion + padlock, secret = "?" (the Monster Kid before its hidden milestone).
class HeroTile:
	extends Pick
	var class_id := ""
	var state: ClassCard.State = ClassCard.State.OPEN

	static func make(id: String, st: ClassCard.State, hint := "") -> HeroTile:
		var t := HeroTile.new()
		t.class_id = id
		t.state = st
		t.name = "Hero_" + id
		var open := st == ClassCard.State.OPEN or st == ClassCard.State.SELECTED
		var col := UiPalette.class_color(id)
		t.style(st == ClassCard.State.SELECTED, open, ClassInfo.mechanic_color("boo") if st == ClassCard.State.SECRET else null)
		if st == ClassCard.State.SECRET:
			# a secret stays a mystery card (purple rim), not a greyed one
			t.add_theme_stylebox_override("panel", t._box("normal"))
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.custom_minimum_size = Vector2(0, 84)
		t.add_child(holder)
		var v := UiTheme.vbox(6)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		UiTheme.full_rect(v)
		holder.add_child(v)
		var med: Control
		if st == ClassCard.State.SECRET:
			med = ClassDetail.Medal.make("question", 52, Color(0.45, 0.4, 0.6), UiPalette.TEXT_MUTED)
		else:
			med = ClassDetail.Medal.make(Icons.class_icon(id), 52, col, null, 1.0 if open else 0.0)
		med.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(med)
		var title := "???" if st == ClassCard.State.SECRET else String(HeroDefs.DATA[id].name)
		var fg := UiPalette.GOLD_BRIGHT if st == ClassCard.State.SELECTED else (UiPalette.TEXT if open else UiPalette.TEXT_MUTED)
		if st == ClassCard.State.SECRET:
			fg = Color("b9a6d8")
		var l := UiTheme.label(title, 18, fg, true, 3)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.custom_minimum_size.x = 40
		v.add_child(l)
		if st == ClassCard.State.SELECTED:
			holder.add_child(CampArt.pin(_sized(Icons.rect("check", 24, UiPalette.GOLD_BRIGHT), 24), "tr", 0.0))
		elif st == ClassCard.State.LOCKED:
			holder.add_child(CampArt.pin(_sized(CampArt.lock_icon(22), 22), "tr", 0.0))
		var mech := ClassInfo.mechanic(id)
		if open:
			var tip := String(HeroDefs.DATA[id].name)
			if mech != "":
				tip += ": " + ClassInfo.mechanic_name(mech)
			t.tooltip_text = tip + "  (← → to switch)"
		else:
			t.tooltip_text = ("???" if st == ClassCard.State.SECRET else String(HeroDefs.DATA[id].name)) + ": " + hint
		return t

	static func _sized(c: Control, px: float) -> Control:
		c.custom_minimum_size = Vector2(px, px)
		c.size = Vector2(px, px)
		return c


## Standard / Short Road: medallion, name, line, and the laps / biomes / Crowns chips.
class ModeCard:
	extends Pick
	var mode := ""

	static func make(m: String, sel: bool) -> ModeCard:
		var t := ModeCard.new()
		t.mode = m
		t.name = "Mode_" + m
		var d: Dictionary = RunSetupModal.MODES[m]
		t.style(sel, true)
		var v := UiTheme.vbox(10)
		t.add_child(v)
		var row := UiTheme.hbox(12)
		v.add_child(row)
		var med := CampArt.medal(String(d.icon), 52, UiPalette.GOLD)
		med.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(med)
		var col := UiTheme.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(col)
		var tl := UiTheme.label(String(d.name), 25, UiPalette.GOLD_BRIGHT if sel else UiPalette.TEXT, true, 4)
		tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tl.custom_minimum_size.x = 60
		col.add_child(tl)
		var sl := UiTheme.label(String(d.sub), 16, UiPalette.TEXT_DIM, false, 0, false, 600)
		sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		sl.custom_minimum_size.x = 60
		col.add_child(sl)
		if sel:
			var ck := Icons.rect("check", 26, UiPalette.GOLD_BRIGHT)
			ck.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			row.add_child(ck)
		var chips := UiTheme.hbox(8)
		v.add_child(chips)
		chips.add_child(_stat("hourglass", str(int(d.laps)), "%d laps" % int(d.laps)))
		chips.add_child(_stat("biome_glade", str(int(d.biomes)), "%d biomes" % int(d.biomes)))
		chips.add_child(_stat("crown", "%d%%" % int(d.crowns), "Crowns earned: %d%%" % int(d.crowns)))
		return t

	static func _stat(icon: String, value: String, tip: String) -> Control:
		var r := UiTheme.hbox(4)
		r.mouse_filter = Control.MOUSE_FILTER_PASS
		r.tooltip_text = tip
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ic := CampArt.icon(icon, 24, UiPalette.GOLD)
		r.add_child(ic)
		r.add_child(UiTheme.label(value, 19, UiPalette.TEXT, true, 0))
		return r


## One biome of the pool: its icon in colour, or greyed with a padlock when locked.
class BiomeChip:
	extends Control
	signal peeked
	var biome := ""
	var owned := true

	static func make(id: String, have: bool, hint: String, stage := 1) -> BiomeChip:
		var b := BiomeChip.new()
		b.biome = id
		b.owned = have
		b.name = "Biome_" + id
		b.custom_minimum_size = Vector2(44, 44)
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.tooltip_text = "Stage %d: %s" % [stage, BiomeDefs.name_of(id)] + ("" if have else "\nLocked: " + hint)
		var ic := CampArt.icon(Icons.biome_icon(id), 40, UiPalette.biome_color(id), not have)
		UiTheme.full_rect(ic)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ic is TextureRect:
			(ic as TextureRect).expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			(ic as TextureRect).stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not have:
			ic.modulate = Color(1, 1, 1, 0.45)
		b.add_child(ic)
		if not have:
			var lk := CampArt.lock_icon(18)
			lk.custom_minimum_size = Vector2(18, 18)
			lk.size = Vector2(18, 18)
			b.add_child(CampArt.pin(lk, "br", 0.0))
		b.mouse_entered.connect(func() -> void:
			if not b.owned:
				b.peeked.emit())
		return b

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not owned:
			accept_event()
			UiTheme.sfx("error")
			peeked.emit()


## A loadout tile: caps label + count on top, a chevron (it opens its station), the content
## row underneath. Locked station = locked card, not tappable.
class LoadoutTile:
	extends Pick
	var content: HBoxContainer
	var _count: Label

	static func make(label: String, accent: Color, en: bool) -> LoadoutTile:
		var t := LoadoutTile.new()
		t.style(false, en)
		t.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var v := UiTheme.vbox(8)
		t.add_child(v)
		var head := UiTheme.hbox(8)
		v.add_child(head)
		var l := UiTheme.label(label.to_upper(), 17, accent.lerp(UiPalette.TEXT, 0.35) if en else UiPalette.TEXT_MUTED, false, 0, false, 800)
		head.add_child(l)
		t._count = UiTheme.label("", 17, UiPalette.TEXT_DIM, false, 0, false, 700)
		t._count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(t._count)
		if en:
			head.add_child(CampArt.icon("chevron_right", 22, UiPalette.TEXT_DIM))
		else:
			head.add_child(CampArt.lock_icon(20))
		t.content = UiTheme.hbox(8)
		t.content.custom_minimum_size.y = 56
		v.add_child(t.content)
		return t

	func set_count(s: String) -> void:
		_count.text = s

	func activate() -> void:
		# a tile opens its station (pressed even though tiles are never "selected")
		if enabled:
			UiTheme.sfx("click")
			UiTheme.pop(self, 1.03, 0.15)
			pressed.emit()
		else:
			UiTheme.sfx("error")
			UiTheme.pop(self, 1.03, 0.15)
