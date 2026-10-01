class_name SummaryScreen
extends UiModal
## End-of-run RESULTS (review §5.6), shown for a victory and a defeat alike: the headline,
## class and route, then the Crowns lines counted up one by one (laps -> biomes -> mini-boss ->
## final boss -> minigames -> leftover gold (capped) -> ascension / catch-up bonus -> total),
## Sigils from firsts, pet XP, unlock cards for milestones and firsts (Camp.bank_run events),
## and a "nearest goals" section with 3 progress bars. CAMP returns to the hub.
##
## The GameController banks the run before the screen opens and sets `results`:
##   {stats: game_over stats, events: Camp.bank_run() events, before: Profile.to_dict() before
##    banking, after: Profile}
## Without `results` (legacy scenarios) only the run half is shown.
## Emits new_run_pressed (= go to Camp). title_pressed is kept for callers but no longer
## has a button on this screen.

signal new_run_pressed
signal title_pressed

const ACT_NAMES := ["The Crypt", "The Hollow", "The Bone Throne"]
const LINES := {
	"laps": ["flag", "Laps"], "biomes": ["portal", "Biomes reached"], "mini-boss": ["skull", "Mini-boss slain"],
	"victory": ["trophy", "Final boss"], "minigames": ["star", "Minigames"], "gold": ["coin", "Leftover gold"],
	"bonus": ["up", "Bonus"],
}

var results: Dictionary = {}
var _hero: HBoxContainer
var _headline: Label
var _route: VBoxContainer
var _crowns_box: VBoxContainer
var _total_row: HBoxContainer
var _total_l: Label
var _extra: VBoxContainer
var _goals: VBoxContainer
var _camp_btn: GameButton
var _anim_gen := 0
## True once the cards have been revealed: a later rebuild (a results refresh, a resize) must
## show its cards at once, not leave section headings over invisible cards.
var _revealed := false
var _footer: MarginContainer
var _lines: Array = []
var _cards: Array = []


func _build() -> void:
	max_width = 700.0
	_headline = UiTheme.label("", 28, UiPalette.TEXT, true, 0, true)
	_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_headline)
	_hero = UiTheme.hbox(16)
	_hero.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(_hero)
	_route = UiTheme.vbox(0)
	body.add_child(_route)
	_crowns_box = UiTheme.vbox(6)
	body.add_child(_crowns_box)
	_extra = UiTheme.vbox(12)
	body.add_child(_extra)
	_goals = UiTheme.vbox(10)
	body.add_child(_goals)
	# the buttons sit under the panel (never scrolled away)
	var row := UiTheme.hbox(14)
	_footer = UiTheme.margin(row, 12, 38, 12, 0)
	_frame.add_child(_footer)
	# forced (spec 3.2): no close / Esc / backdrop. TO CAMP is the one exit (full width,
	# Enter). There is no round Home: the Camp has its own, and two exits to two places
	# (title vs camp) confused players (user, modal pass 2026-10-01)
	_camp_btn = GameButton.make("TO CAMP", "campfire", GameButton.Kind.PRIMARY, 38)
	_camp_btn.min_height = 100
	_camp_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camp_btn.pressed.connect(func() -> void: new_run_pressed.emit())
	row.add_child(_camp_btn)
	primary_action = _camp_btn
	ScrollFade.attach(self, _scroll, UiPalette.NAVY_2, _frame)


func refresh(flow: GameFlow) -> void:
	var r := flow.run
	# the game_over stats (with the Crowns breakdown); legacy callers fall back to the summary
	var st: Dictionary = results.get("stats", {})
	if st.is_empty():
		st = flow._summary()
	var won := flow.phase == GameFlow.Phase.VICTORY or bool(st.get("victory", false))
	set_title("VICTORY!" if won else "DEFEATED", PLAQUE_WIN if won else PLAQUE_DANGER)
	var info := flow.route_info()
	var boss_name := String(info.boss.name)
	var last := BiomeDefs.name_of(String(r.route.back())) if not r.route.is_empty() else String(ACT_NAMES[2])
	_headline.text = ("%s has fallen. %s is yours." % [boss_name, last]) if won \
		else "Fallen on lap %d of %d, in %s." % [r.lap, r.total_laps(), BiomeDefs.name_of(r.biome())]
	_headline.label_settings = UiTheme.label_settings(28, UiPalette.GOLD_BRIGHT if won else UiPalette.TEXT, true, 0, UiPalette.OUTLINE, true)
	UiTheme.clear(_hero)
	var cls: Dictionary = HeroDefs.DATA.get(r.class_id, HeroDefs.DATA.knight)
	_hero.add_child(OptionCard.Medallion.make(Icons.class_icon(r.class_id), 80, null, UiPalette.GOLD if won else UiPalette.DANGER))
	var col := UiTheme.vbox(0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_hero.add_child(col)
	col.add_child(UiTheme.label(String(cls.name), 38, UiPalette.TEXT, true, 6))
	var sub := "Level %d  ·  Lap %d/%d  ·  %d fights won" % [r.level, r.lap, r.total_laps(), int(st.get("fights_won", 0))]
	var asc := int(r.meta.get("asc", 0))
	if asc > 0:
		sub += "  ·  A%d" % asc
	col.add_child(UiTheme.label(sub, 20, UiPalette.TEXT_DIM, false, 0, false, 600))
	UiTheme.clear(_route)
	var strip := RouteStrip.make(info, 0 if won else r.act, 0, true)
	strip.beaten.boss = won
	strip.beaten.miniboss = int(st.get("minibosses_won", 0)) > 0
	strip._rebuild()
	_route.add_child(strip)
	_build_crowns(st)
	_build_extra()
	if _revealed:
		for card in _cards:
			(card as Control).modulate.a = 1.0
	_build_goals()
	relayout()


func open() -> void:
	await super.open()
	_animate()


## UiModal's layout (MIN_W floor, shrink-to-fit via _fit), with the footer's height kept free
## under the scrolling panel. Narrow canvases (iPhone at 125 % UI size: 576 px) scale the whole
## frame down instead of letting wide rows (route strip, first chips) push it off-screen.
func _layout() -> void:
	if _frame == null or _footer == null:
		super._layout()
		return
	var view := size
	if view.x <= 0.0:
		return
	_apply_scale(view)
	var safe := UiTheme.safe_margins(self)
	var avail_w := view.x - safe.left - safe.right
	var w := minf(max_width, avail_w)
	# never lay out narrower than MIN_W: shrink instead (as UiModal does)
	var lw := maxf(w, minf(MIN_W, max_width))
	_frame.custom_minimum_size.x = lw
	_frame.size = Vector2(lw, 0)
	_fit_plaque(lw)
	var k := minf(1.0, w / lw)
	var avail_h := (view.y - safe.top - safe.bottom) / k
	var chrome := chrome_height() + _footer.get_combined_minimum_size().y - header_overlap()
	var natural := _inner.get_combined_minimum_size().y
	_scroll.custom_minimum_size.y = maxf(120.0, minf(natural, avail_h - chrome))
	_frame.reset_size()
	_frame.size.x = maxf(_frame.size.x, lw)
	# content wider than the screen allows: shrink the whole frame
	k = minf(k, avail_w / maxf(_frame.size.x, 1.0))
	k = minf(k, (view.y - safe.top - safe.bottom) / maxf(_frame.size.y, 1.0))
	var was := _fit
	_fit = clampf(k, 0.6, 1.0)
	if not is_equal_approx(was, _fit) and is_equal_approx(_frame.scale.x, was):
		_frame.scale = Vector2.ONE * _fit
	var fh := _frame.size.y * _fit
	var c := Vector2(safe.left + avail_w * 0.5, maxf(safe.top, safe.top + (view.y - safe.top - safe.bottom - fh) * 0.5) + fh * 0.5)
	_frame.pivot_offset = _frame.size * 0.5
	_frame.position = c - _frame.size * 0.5


func show_now() -> void:
	super.show_now()
	_animate()


func close(free_after := false) -> void:
	_anim_gen += 1
	_revealed = false
	await super.close(free_after)


# ---------------------------------------------------------------- crowns

func _build_crowns(st: Dictionary) -> void:
	UiTheme.clear(_crowns_box)
	_lines.clear()
	var rw: Dictionary = st.get("rewards", {})
	var parts: Array = rw.get("breakdown", [])
	if parts.is_empty():
		_crowns_box.visible = false
		return
	_crowns_box.visible = true
	_crowns_box.add_child(UiModal.section_label("Crowns earned"))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.inset_box())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crowns_box.add_child(panel)
	var list := UiTheme.vbox(4)
	panel.add_child(list)
	for p in parts:
		var key := String(p[0])
		var amt := int(p[1])
		if key == "bonus" and amt == 0:
			continue
		if key in ["mini-boss", "victory"] and amt == 0:
			continue
		var row := UiTheme.hbox(12)
		list.add_child(row)
		var def: Array = LINES.get(key, ["star", key.capitalize()])
		row.add_child(Icons.rect(String(def[0]), 32))
		var lab := UiTheme.label(String(def[1]), 23, UiPalette.TEXT, false, 0, false, 600)
		row.add_child(lab)
		var det := UiTheme.label(_detail(key, amt, st), 18, UiPalette.TEXT_MUTED, false, 0, false, 600)
		det.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(det)
		var val := UiTheme.label("+0", 28, UiPalette.GOLD_BRIGHT, true, 5)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.custom_minimum_size.x = 70
		row.add_child(val)
		row.modulate.a = 0.0
		_lines.append([row, val, amt])
	var sep := ColorRect.new()
	sep.color = UiPalette.GOLD_FAINT
	sep.custom_minimum_size = Vector2(0, 2)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(sep)
	_total_row = UiTheme.hbox(12)
	list.add_child(_total_row)
	_total_row.add_child(Icons.rect("crown", 44))
	var tl := UiTheme.label("TOTAL", 30, UiPalette.TEXT, true, 6)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_total_row.add_child(tl)
	_total_l = UiTheme.label("0", 44, UiPalette.GOLD_BRIGHT, true, 8, true)
	_total_row.add_child(_total_l)
	_total_row.set_meta("total", int(rw.get("crowns", 0)))


func _detail(key: String, amt: int, st: Dictionary) -> String:
	match key:
		"laps":
			return "%d laps" % int(st.get("laps_completed", amt / maxi(1, Economy.CROWNS_PER_LAP)))
		"biomes":
			return "%d new" % (amt / maxi(1, Economy.CROWNS_PER_BIOME)) if amt > 0 else ""
		"minigames":
			return "%d played" % int(st.get("minigames_played", 0))
		"gold":
			return "%d gold  ·  max %d" % [int(st.get("gold", 0)), Economy.GOLD_CROWN_CAP]
		"bonus":
			var bits := PackedStringArray()
			var a := int(st.get("asc", 0))
			if a > 0:
				bits.append("Ascension +%d%%" % int(round(Economy.ASC_CROWN_BONUS * 100.0 * a)))
			if String(st.get("mode", "standard")) == "short":
				bits.append("Short Road")
			if bits.is_empty():
				bits.append("Comeback")
			return "  ·  ".join(bits)
	return ""


# ---------------------------------------------------------------- sigils, pet, unlocks

func _build_extra() -> void:
	UiTheme.clear(_extra)
	_cards.clear()
	if results.is_empty():
		return
	var evs: Array = results.get("events", [])
	var before := Profile.from_dict(results.get("before", {}))
	var after: Profile = results.get("after")
	# Sigils from firsts
	var firsts: Array = []
	for e in evs:
		if String(e.type) == "first":
			firsts.append(e)
	if not firsts.is_empty():
		_extra.add_child(UiModal.section_label("Firsts"))
		var flow := HFlowContainer.new()
		flow.alignment = FlowContainer.ALIGNMENT_CENTER
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_extra.add_child(flow)
		for e in firsts:
			var chip := _first_chip(e)
			chip.modulate.a = 0.0
			flow.add_child(chip)
			_cards.append(chip)
	# pet XP
	var pet := String(before.loadout.get("pet", ""))
	if pet != "" and after != null and after.owns("pets", pet):
		var gained := int(after.pet_xp.get(pet, 0)) - int(before.pet_xp.get(pet, 0))
		var l0 := before.pet_level(pet)
		var l1 := after.pet_level(pet)
		var row := CampUi.card(l1 > l0, CampInfo.PET_COLOR.get(pet, UiPalette.GOLD))
		var h := UiTheme.hbox(12)
		row.add_child(h)
		h.add_child(OptionCard.Medallion.make(CampInfo.glyph_of("pets", pet), 56, CampInfo.PET_COLOR.get(pet, UiPalette.GOLD), CampInfo.PET_COLOR.get(pet, UiPalette.GOLD)))
		var c := UiTheme.vbox(4)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(c)
		c.add_child(UiTheme.label("%s  +%d XP" % [PetDefs.name_of(pet), gained] + ("   LEVEL %d!" % l1 if l1 > l0 else ""), 24,
			UiPalette.GOLD_BRIGHT if l1 > l0 else UiPalette.TEXT, true, 5))
		var xb := CampInfo.pet_xp_bar(after, pet)
		if int(xb[1]) > 0:
			var br := UiTheme.hbox(8)
			c.add_child(br)
			br.add_child(CampUi.bar(float(xb[0]), float(xb[1]), UiPalette.XP, 16))
			br.add_child(UiTheme.label("%d/%d to L%d" % [int(xb[0]), int(xb[1]), l1 + 1], 17, UiPalette.TEXT_DIM, false, 0, false, 700))
		else:
			c.add_child(UiTheme.label("Level %d  ·  more levels at the Pet Den" % l1, 17, UiPalette.TEXT_DIM, false, 0, false, 700))
		row.modulate.a = 0.0
		_extra.add_child(row)
		_cards.append(row)
	# Armory: the run's items with their mastery, then new blueprints and feat items
	var items_box := _items_block(evs, before, after)
	if items_box != null:
		_extra.add_child(UiModal.section_label("Items"))
		items_box.modulate.a = 0.0
		_extra.add_child(items_box)
		_cards.append(items_box)
		for e in evs:
			var card: Control = null
			if String(e.type) == "blueprint_unlocked":
				card = _blueprint_card(String(e.item), String(e.variant), String(e.get("source", "")))
			elif String(e.type) == "item_unlocked" and String(e.get("source", "")) == "feat":
				card = _item_unlock_card(String(e.id))
			if card != null:
				card.modulate.a = 0.0
				_extra.add_child(card)
				_cards.append(card)
	# unlock cards: milestones (with their rewards) and the ascension ladder
	var ms: Array = []
	var asc_up := -1
	for e in evs:
		match String(e.type):
			"milestone":
				ms.append(e)
			"run_banked":
				asc_up = int(e.get("ascension_unlocked", -1))
	if not ms.is_empty() or asc_up > 0:
		_extra.add_child(UiModal.section_label("Unlocked"))
		for e in ms:
			for u in e.unlocks:
				var card: Control
				if String(u[0]) == "classes" and ClassCard.is_secret(String(u[1])):
					card = SecretReveal.make(String(u[1]))
				else:
					card = _unlock_card(String(u[0]), String(u[1]), String(e.desc))
				card.modulate.a = 0.0
				_extra.add_child(card)
				_cards.append(card)
		if asc_up > 0:
			var card := _asc_card(asc_up)
			card.modulate.a = 0.0
			_extra.add_child(card)
			_cards.append(card)
	# skin unlocks (records: Victor / Ascendant / Bossbane / Prestige), one toast card each
	var skins: Array = []
	for e in evs:
		if String(e.type) == "skin_unlocked":
			skins.append(e)
	if not skins.is_empty():
		_extra.add_child(UiModal.section_label("New skins"))
		for e in skins:
			var card := _skin_card(String(e["class"]), String(e.skin))
			card.modulate.a = 0.0
			_extra.add_child(card)
			_cards.append(card)


## One card listing the run's equipped items: the fights they won and the mastery toward the
## next blueprint ("Arming Sword  +22  ·  37 / 45 to Knight's Sword"). null when the run had none.
func _items_block(_evs: Array, _before: Profile, after: Profile) -> Control:
	var st: Dictionary = results.get("stats", {})
	var lo: Dictionary = st.get("loadout", {})
	if after == null or lo.is_empty():
		return null
	var fights := int(st.get("item_fights", 0))
	var c := CampUi.card(false, Color("ff9a5a"))
	var v := UiTheme.vbox(8)
	c.add_child(v)
	var seen := {}
	for slot in ItemDefs.STAT_SLOTS:
		if not lo.has(slot):
			continue
		var e: Dictionary = lo[slot]
		var id := String(e.get("id", ""))
		if id == "" or seen.has(id):
			continue
		seen[id] = true
		var row := UiTheme.hbox(10)
		v.add_child(row)
		row.add_child(ItemThumb.make(String(e.get("variant", id)), 56))
		var col := UiTheme.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var head := UiTheme.hbox(8)
		col.add_child(head)
		var nm := UiTheme.label(ItemDefs.name_of(String(e.get("variant", id))), 21, UiPalette.TEXT, true, 4)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nm.custom_minimum_size.x = 60
		head.add_child(nm)
		if fights > 0:
			head.add_child(UiTheme.label("+%d" % fights, 20, UiPalette.HEAL, true, 4))
		var m := after.item_mastery(id)
		var nxt := _next_blueprint(after, id)
		if nxt.is_empty():
			col.add_child(UiTheme.label("Mastery %d fights" % m, 16, UiPalette.TEXT_DIM, false, 0, false, 700))
		else:
			var br := UiTheme.hbox(8)
			col.add_child(br)
			br.add_child(CampUi.bar(float(m), float(nxt[1]), Color("e0a84a"), 12.0))
			var bl := UiTheme.label("%d/%d  %s" % [m, int(nxt[1]), ItemDefs.name_of(String(nxt[0]))], 16, Color("e0c28a"), false, 0, false, 700)
			br.add_child(bl)
	if v.get_child_count() == 0:
		return null
	if fights <= 0:
		v.add_child(UiTheme.para("Items count fights won once their rank group is forged.", 16, UiPalette.TEXT_MUTED, 600))
	return c


## [variant, fights needed] of the next mastery blueprint of `item` ([] when none is left).
static func _next_blueprint(p: Profile, item: String) -> Array:
	var best: Array = []
	for v in ItemDefs.variants_of(item):
		var u: Dictionary = ItemDefs.VARIANTS.get(String(v), {}).get("unlock", {})
		var need := int(u.get("mastery", u.get("or_mastery", 0)))
		if need <= 0 or p.owns_variant(item, String(v)) or p.has_blueprint(item, String(v)):
			continue
		if best.is_empty() or need < int(best[1]):
			best = [String(v), need]
	return best


## "New blueprint: Saber" with the variant's model, its property and the craft price.
func _blueprint_card(item: String, variant: String, source: String) -> Control:
	var c := CampUi.card(true, UiPalette.GOLD)
	var row := UiTheme.hbox(14)
	c.add_child(row)
	row.add_child(ItemThumb.make(variant, 84))
	var v := UiTheme.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	v.add_child(UiTheme.label("NEW BLUEPRINT" + ("  ·  MASTERY" if source == "mastery" else ("  ·  FEAT" if source == "feat" else "")), 16, UiPalette.GOLD, false, 0, false, 800))
	v.add_child(UiTheme.label(ItemDefs.name_of(variant), 28, UiPalette.TEXT, true, 6))
	v.add_child(UiTheme.para(String(ItemDefs.VARIANTS.get(variant, {}).get("desc", "")), 17, UiPalette.TEXT_DIM, 500))
	var cc := ItemDefs.craft_cost(variant)
	v.add_child(UiTheme.label("%s variant  ·  craft it at the Armory: %d Crowns" % [ItemDefs.name_of(item), int(cc.get("crowns", 0))],
		16, UiPalette.GOLD_BRIGHT, false, 0, false, 700))
	return c


func _item_unlock_card(id: String) -> Control:
	var c := CampUi.card(true, UiPalette.GOLD)
	var row := UiTheme.hbox(14)
	c.add_child(row)
	row.add_child(ItemThumb.make(id, 84))
	var v := UiTheme.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	v.add_child(UiTheme.label("NEW ITEM", 16, UiPalette.GOLD, false, 0, false, 800))
	v.add_child(UiTheme.label(ItemDefs.name_of(id), 28, UiPalette.TEXT, true, 6))
	var why := String(ItemDefs.FEATS.get(String(ItemDefs.BACK_FEATS.get(id, "")), {}).get("desc", ""))
	v.add_child(UiTheme.para(why if why != "" else "Equip it at the Armory.", 17, UiPalette.TEXT_DIM, 500))
	return c


func _first_chip(e: Dictionary) -> Control:
	var kind := String(e.kind)
	var id := String(e.id)
	var label := ""
	match kind:
		"biome": label = "Discovered %s" % BiomeDefs.name_of(id)
		"miniboss": label = "Slew %s" % String(EnemyDefs.def(id).get("name", id))
		"boss": label = "Defeated %s" % String(EnemyDefs.def(id).get("name", id))
		"class_win": label = "First %s win" % CampInfo.name_of("classes", id)
		"route_win": label = "New route conquered"
		"asc_clear": label = "Cleared Ascension %s" % id
		"short_win": label = "Short Road win"
		_: label = kind
	var p := PanelContainer.new()
	# a flat round chip (never the 3D card: too short for its lip); ink on the pack purple
	var skin := UiTheme.skinned("chip_purple")
	if skin:
		p.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.chip_box(Color(CampUi.SIGIL_COLOR, 1.0)), 16, 5))
	else:
		p.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(Color(0.12, 0.08, 0.22, 0.9), 18, 2, Color(CampUi.SIGIL_COLOR, 0.6)), 12, 6))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UiTheme.hbox(8)
	p.add_child(row)
	var fg := UiPalette.INK_LABEL if skin else UiPalette.TEXT
	row.add_child(UiTheme.label(label, 19, fg, false, 0, false, 700))
	row.add_child(Icons.rect(CampUi.sigil_icon(), 24))
	row.add_child(UiTheme.label(str(int(e.get("sigils", 0))), 20, fg, true, 0))
	return p


func _unlock_card(kind: String, id: String, why: String) -> Control:
	var col := CampInfo.color_of(kind, id)
	var c := CampUi.card(true)
	var row := UiTheme.hbox(14)
	c.add_child(row)
	if kind == "items":
		row.add_child(ItemThumb.make(id, 72))
	else:
		row.add_child(OptionCard.Medallion.make(CampInfo.glyph_of(kind, id), 64, null if kind == "biomes" else col, col))
	var v := UiTheme.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	v.add_child(UiTheme.label("NEW " + String(CampInfo.KIND_LABEL.get(kind, kind)).to_upper(), 16, UiPalette.GOLD, false, 0, false, 800))
	v.add_child(UiTheme.label(CampInfo.name_of(kind, id), 30, UiPalette.TEXT, true, 6))
	v.add_child(UiTheme.para(why, 18, UiPalette.TEXT_DIM, 500))
	return c


## "New skin: Knight, Victor" with the hero in that skin on a small pedestal.
func _skin_card(class_id: String, skin: String) -> Control:
	var c := CampUi.card(true, Color("c79bff"))
	var row := UiTheme.hbox(14)
	c.add_child(row)
	var por := HeroPortrait.new()
	por.custom_minimum_size = Vector2(110, 130)
	por.zoom = 1.2
	por.spin = 0.0
	por.ring_color = UiPalette.class_color(class_id)
	var prestige := SkinDefs.is_prestige(skin)
	por.set_hero(class_id, "default" if prestige else skin, prestige, false)
	row.add_child(por)
	var v := UiTheme.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(v)
	var kick := UiTheme.hbox(6)
	v.add_child(kick)
	kick.add_child(Icons.rect("wardrobe", 28))
	kick.add_child(UiTheme.label("NEW SKIN", 16, Color("c79bff"), false, 0, false, 800))
	v.add_child(UiTheme.label("%s, %s" % [CampInfo.name_of("classes", class_id), String(SkinDefs.NAMES.get(skin, skin))], 28, UiPalette.TEXT, true, 6))
	v.add_child(UiTheme.para("Wear it from the Wardrobe in the Camp.", 17, UiPalette.TEXT_DIM, 500))
	return c


func _asc_card(level: int) -> Control:
	var c := CampUi.card(true)
	var row := UiTheme.hbox(14)
	c.add_child(row)
	row.add_child(OptionCard.Medallion.make("skull", 64, UiPalette.HP_BRIGHT, UiPalette.DANGER))
	var v := UiTheme.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	v.add_child(UiTheme.label("NEW CHALLENGE", 16, UiPalette.HP_BRIGHT, false, 0, false, 800))
	v.add_child(UiTheme.label("Ascension %d" % level, 30, UiPalette.TEXT, true, 6))
	v.add_child(UiTheme.para(String(UnlockDefs.ASCENSION[level - 1].desc), 18, UiPalette.TEXT_DIM, 500))
	return c


# ---------------------------------------------------------------- goals

func _build_goals() -> void:
	UiTheme.clear(_goals)
	var after: Profile = results.get("after")
	if after == null:
		return
	var goals := CampInfo.nearest_goals(after, 3)
	if goals.is_empty():
		return
	_goals.add_child(UiModal.section_label("Nearest goals"))
	for g in goals:
		var c := CampUi.card(false, g.color)
		var v := UiTheme.vbox(6)
		c.add_child(v)
		var head := UiTheme.hbox(10)
		v.add_child(head)
		head.add_child(Icons.rect(String(g.icon), 32, g.color))
		var t := UiTheme.label(String(g.title), 22, UiPalette.TEXT, true, 4)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		t.custom_minimum_size.x = 60
		head.add_child(t)
		head.add_child(UiTheme.label("%s / %s" % [CampUi._num(int(g.cur)), CampUi._num(int(g.need))], 18, UiPalette.TEXT_DIM, false, 0, false, 700))
		v.add_child(CampUi.bar(float(g.cur), float(g.need), g.color, 16))
		v.add_child(UiTheme.label(String(g.detail), 17, UiPalette.TEXT_MUTED, false, 0, false, 600))
		_goals.add_child(c)


# ---------------------------------------------------------------- animation

## Counts the Crowns lines up one after another, then the total, then pops the cards in.
func _animate() -> void:
	_anim_gen += 1
	var gen := _anim_gen
	if not is_inside_tree():
		return
	await get_tree().create_timer(0.25).timeout
	var total := 0
	for l in _lines:
		if gen != _anim_gen:
			return
		var row: Control = l[0]
		var val: Label = l[1]
		var amt: int = l[2]
		row.modulate.a = 1.0
		UiTheme.pop(row, 1.04, 0.2)
		var tw := val.create_tween()
		tw.tween_method(func(v: float) -> void: val.text = "+%d" % int(round(v)), 0.0, float(amt), 0.3)
		if amt > 0:
			UiTheme.sfx("coin")
		total += amt
		if _total_l:
			var from := total - amt
			var tt := _total_l.create_tween()
			tt.tween_method(func(v: float) -> void: _total_l.text = str(int(round(v))), float(from), float(total), 0.3)
		await get_tree().create_timer(0.28).timeout
	if gen != _anim_gen:
		return
	if _total_row:
		_total_l.text = str(int(_total_row.get_meta("total", total)))
		UiTheme.pop(_total_row, 1.12, 0.35)
		UiTheme.sfx("fanfare")
	# from here on a rebuild (refresh during the reveal) shows its cards at once
	_revealed = true
	for card in _cards.duplicate():
		await get_tree().create_timer(0.16).timeout
		if gen != _anim_gen:
			return
		if not is_instance_valid(card) or not _cards.has(card):
			continue
		(card as Control).modulate.a = 1.0
		if card is SecretReveal:
			_scroll.ensure_control_visible(card)
			await (card as SecretReveal).play()
			continue
		UiTheme.pop(card, 1.08, 0.3)
		UiTheme.sfx("buff")


## Skips the count-up (screenshots, tests): everything at its final value.
func finish_now() -> void:
	_anim_gen += 1
	for l in _lines:
		(l[0] as Control).modulate.a = 1.0
		(l[1] as Label).text = "+%d" % int(l[2])
	if _total_row:
		_total_l.text = str(int(_total_row.get_meta("total", 0)))
	_revealed = true
	for card in _cards:
		(card as Control).modulate.a = 1.0
		if card is SecretReveal:
			(card as SecretReveal).finish_now()
