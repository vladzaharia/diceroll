class_name WardrobeModal
extends CampModal
## Wardrobe (docs/design/2026-09-28-classes-enemies-skins.md §4.3): the class carousel (owned
## classes; locked ones as dark medallions, the secret one as "???"), the hero turning on a
## pedestal, the class's skins card (a StationCard whose carousel holds Default, Victor,
## Ascendant and Bossbane; Camp stations pass, docs/design/2026-10-01-camp-stations.md) and the
## A10 prestige toggle. Owned swatches equip on tap (free, instant); locked ones preview on the pedestal and
## show their condition with live progress, plus a "250 Crowns" buy button once every Crowns sink
## is maxed (never on prestige). "NEW" chips come from profile.cosmetics.unseen; viewing a class
## sends mark_skins_seen, the chips stay up until the screen closes.
## Commands: equip_skin, buy_skin, set_prestige, mark_skins_seen (Camp.apply).

const SWATCHES := ["default", "victor", "ascendant", "bossbane"]

## The class on the pedestal ("" = the loadout class).
var view_class := ""
## The skin on the pedestal ("" = the equipped one); a locked skin is only previewed.
var preview_skin := ""
## "class:skin" still shown as NEW this visit (cleared on close).
var _fresh: Array = []
var _portrait: HeroPortrait


func _build() -> void:
	set_title("WARDROBE", PLAQUE_DEFAULT)
	closed.connect(func() -> void:
		_fresh.clear()
		preview_skin = "")


func rebuild(p: Profile) -> void:
	if view_class == "" or not p.class_allowed(view_class):
		view_class = String(p.loadout.get("class", "knight"))
	if not p.class_allowed(view_class):
		view_class = "knight"
	var unseen: Array = p.cosmetics.get("unseen", [])
	var mine := unseen.filter(func(u: Variant) -> bool: return String(u).begins_with(view_class + ":"))
	if not mine.is_empty():
		for u in mine:
			if not _fresh.has(u):
				_fresh.append(u)
		(func() -> void: cmd(["mark_skins_seen", view_class])).call_deferred()
	fit_columns()
	body.add_child(_classes(p, unseen))
	# landscape: the pedestal on the left, the skins beside it (no scrolling to see them)
	var right: VBoxContainer = body
	if is_wide():
		var row := UiTheme.hbox(UiModal.GAP_ITEM)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		body.add_child(row)
		var left := UiTheme.vbox(UiModal.GAP_ITEM)
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.size_flags_stretch_ratio = 0.8
		row.add_child(left)
		left.add_child(_stand(p))
		right = UiTheme.vbox(UiModal.GAP_ITEM)
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(right)
	else:
		body.add_child(_stand(p))
		body.add_child(CampModal.heading("Skins", "Cosmetic only. Win with the class to earn them."))
	right.add_child(skins_card(p))
	right.add_child(_prestige(p))


## Landscape screens: a shorter pedestal and swatches (more of the list fits).
func _wide() -> bool:
	var v := get_viewport_rect().size if is_inside_tree() else Vector2(720, 1280)
	return v.x > v.y * 1.1


## The class carousel: every class as a medallion (owned: tappable; NEW dot on unseen skins).
func _classes(p: Profile, unseen: Array) -> Control:
	var grid := GridContainer.new()
	grid.columns = 12 if is_wide() else 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 8)
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	for id in HeroDefs.IDS:
		var cid := String(id)
		var owned := p.class_allowed(cid)
		var secret := not owned and ClassCard.is_secret(cid)
		var has_new := unseen.any(func(u: Variant) -> bool: return String(u).begins_with(cid + ":")) or \
			_fresh.any(func(u: Variant) -> bool: return String(u).begins_with(cid + ":") and cid != view_class)
		var pick := _Pick.new()
		pick.setup(cid, owned, secret, cid == view_class, has_new)
		pick.pressed.connect(func() -> void:
			if owned and cid != view_class:
				view_class = cid
				preview_skin = ""
				show_profile(profile))
		grid.add_child(pick)
	return grid


## The pedestal: the hero turning in the previewed / equipped look.
func _stand(p: Profile) -> Control:
	var eq := p.equipped_skin(view_class)
	var shown := preview_skin if preview_skin != "" else eq
	var owned := p.owns_skin(view_class, shown)
	var c := CampUi.card(true, UiPalette.class_color(view_class))
	var col := UiTheme.vbox(4)
	c.add_child(col)
	_portrait = HeroPortrait.new()
	_portrait.custom_minimum_size = Vector2(0, 470 if is_wide() else (280 if _wide() else 330))
	_portrait.ring_color = UiPalette.class_color(view_class)
	_portrait.set_hero(view_class, shown, p.prestige_on(view_class), false)
	col.add_child(_portrait)
	var row := UiTheme.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	row.add_child(UiTheme.label(String(HeroDefs.DATA[view_class].name), 32, UiPalette.class_color(view_class).lightened(0.25), true, 6))
	row.add_child(UiTheme.label(String(SkinDefs.NAMES[shown]), 26, UiPalette.TEXT, true, 5))
	if not owned:
		row.add_child(CampArt.chip("PREVIEW", "grey", "lock", 16))
	elif shown == eq:
		row.add_child(CampArt.chip("WORN", "purple", "", 16))
	return c


## Skin tiles: a portrait, the name and one state line (WORN, WEAR, progress).
const SKIN_TILE_H := 236.0
const SKIN_TILE_W := 132.0


## The class's skins as one StationCard: pills (owned count), a carousel of skin tiles (tap:
## wear an owned skin, preview a locked one on the pedestal) and, in the footer, the previewed
## skin's condition and progress, with BUY [crown] 250 once every Crowns sink is maxed.
func skins_card(p: Profile) -> StationCard:
	var col := UiPalette.class_color(view_class)
	var cname := String(HeroDefs.DATA[view_class].name)
	var spec := StationCard.Spec.new()
	spec.desc_lines = 2
	spec.contents_h = SKIN_TILE_H
	spec.footer_h = 88.0
	var eq := p.equipped_skin(view_class)
	var shown := preview_skin if preview_skin != "" else eq
	var shown_owned := p.owns_skin(view_class, shown)
	# the description is about the skin on the pedestal: how to earn it when it's locked
	var desc := "Tap a skin to wear it, or to preview a locked one." if shown_owned else \
		"%s: %s" % [String(SkinDefs.NAMES[shown]), SkinDefs.cond_text(view_class, shown)]
	var c := StationCard.make(spec, Icons.class_icon(view_class), col, "%s skins" % cname, desc)
	c.name = "Skins"
	var have := 0
	for s in SWATCHES:
		if p.owns_skin(view_class, String(s)):
			have += 1
	c.add_pill("wardrobe_hats", "%d/%d OWNED" % [have, SWATCHES.size()])
	if p.crowns_capped():
		c.add_pill("crown", "%d EACH" % SkinDefs.BUY_PRICE)
	else:
		c.add_pill("trophy", "EARNED BY WINNING")
	var tiles: Array = []
	for s in SWATCHES:
		tiles.append(_skin_tile(p, String(s)))
	var car := Carousel.make(tiles, SKIN_TILE_H, SKIN_TILE_W, "wardrobe:" + view_class)
	car.count_text = "%d SKINS" % SWATCHES.size()
	c.set_carousel(car)
	# footer: the shown skin (preview or worn): worn, or the live progress toward it
	if shown_owned:
		c.set_status("Wearing %s. Skins never change the numbers." % String(SkinDefs.NAMES[shown]) if shown == eq
			else "%s is yours: tap it to wear it." % String(SkinDefs.NAMES[shown]), "check", UiPalette.HEAL)
	else:
		var prog := progress_text(p, view_class, shown)
		c.set_status(prog if prog != "" else "Not earned yet.", "lock", Color("c79bff"))
		if p.crowns_capped():
			var b := CampUi.buy_button("BUY", {"crowns": SkinDefs.BUY_PRICE}, p.crowns >= SkinDefs.BUY_PRICE, 22)
			b.name = "BuySkin"
			b.tooltip_text = "Buy %s" % String(SkinDefs.NAMES[shown])
			b.pressed.connect(cmd.bind(["buy_skin", view_class, shown]))
			# the card's one priced action sits top-right, like every station card
			c.set_action(b)
	return c


## Short progress for a locked skin's tile ("BEST A2", "1/4 BOSSES", "WIN A RUN").
static func tile_progress(p: Profile, class_id: String, skin: String) -> String:
	var best := int((p.records.get("best_asc_by_class", {}) as Dictionary).get(class_id, -1))
	match skin:
		"victor":
			return "WIN A RUN"
		"ascendant":
			return "BEST A%d/A3" % best if best >= 0 else "WIN AT A3"
		"bossbane":
			var beaten: Array = (p.records.get("bosses_by_class", {}) as Dictionary).get(class_id, [])
			return "%d/%d BOSSES" % [beaten.size(), SkinDefs.BOSSES_FOR_BOSSBANE]
	return "LOCKED"


func _skin_tile(p: Profile, skin: String) -> Carousel.ItemTile:
	var owned := p.owns_skin(view_class, skin)
	var worn := owned and p.equipped_skin(view_class) == skin
	var shown := (preview_skin if preview_skin != "" else p.equipped_skin(view_class)) == skin
	var is_new := _fresh.has("%s:%s" % [view_class, skin])
	var por := HeroPortrait.new()
	por.custom_minimum_size = Vector2(SKIN_TILE_W - 24.0, 150)
	por.spin = 0.0
	por.zoom = 1.15
	por.ring_color = UiPalette.class_color(view_class) if owned else Color(0.35, 0.33, 0.45)
	por.set_hero(view_class, skin, false, false)
	por.silhouette = false
	if not owned:
		por.modulate = Color(0.62, 0.6, 0.7)
	var detail := "WORN" if worn else ("NEW" if is_new else ("WEAR" if owned else tile_progress(p, view_class, skin)))
	var dcol: Color = Color("c79bff") if worn else (UiPalette.HP_BRIGHT if is_new else (UiPalette.HEAL if owned else UiPalette.TEXT_MUTED))
	var state := "worn" if worn else ("on" if shown else ("normal" if owned else "dim"))
	var t := Carousel.ItemTile.make(por, String(SkinDefs.NAMES[skin]), detail, dcol, UiPalette.class_color(view_class) if owned else null, state)
	t.name = "Skin_" + skin
	t.pressed.connect(func() -> void:
		if owned:
			preview_skin = ""
			if not worn:
				cmd(["equip_skin", view_class, skin])
			elif _portrait:
				_portrait.cheer()
		else:
			preview_skin = skin
			show_profile(profile))
	return t


## The A10 prestige overlay: a toggle when owned, else its condition and the best ascension.
func _prestige(p: Profile) -> Control:
	var owned := p.owns_skin(view_class, "prestige")
	var c := CampUi.card(owned and p.prestige_on(view_class), UiPalette.GOLD)
	var row := UiTheme.hbox(12)
	c.add_child(row)
	row.add_child(CampArt.medal("skin_prestige", 60, UiPalette.GOLD, not owned, UiPalette.GOLD_BRIGHT))
	var col := UiTheme.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var ov := String(SkinDefs.def(view_class, "prestige").get("overlay", "crown"))
	col.add_child(UiTheme.label("PRESTIGE  ·  %s" % String(PRESTIGE_NAMES.get(ov, "Crown")).to_upper(), 24, UiPalette.GOLD_BRIGHT if owned else UiPalette.TEXT_DIM, true, 5))
	if owned:
		col.add_child(UiTheme.para("Shown over any skin you wear.", 17, UiPalette.TEXT_DIM, 500))
		var on := p.prestige_on(view_class)
		var t := ToggleSwitch.make(on)
		t.name = "PrestigeToggle"
		t.tooltip_text = "Prestige look on / off"
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		t.toggled.connect(func(v: bool) -> void: cmd(["set_prestige", view_class, v]))
		row.add_child(t)
	else:
		col.add_child(UiTheme.para(SkinDefs.cond_text(view_class, "prestige") + " Never for sale.", 17, UiPalette.TEXT_DIM, 500))
		var prog := progress_text(p, view_class, "prestige")
		if prog != "":
			col.add_child(UiTheme.para(prog, 16, Color("c79bff"), 700))
	return c


const PRESTIGE_NAMES := {"crown": "Gold Crown", "statue": "Golden Statue", "chieftain": "Chieftain", "shade": "Shade",
	"full_suit": "Full Suit", "gold_turret": "Gold Turret"}


## Live progress toward a skin ("Best win: A1", "Final bosses: Lich, Cinder King (2/4)").
static func progress_text(p: Profile, class_id: String, skin: String) -> String:
	var best := int((p.records.get("best_asc_by_class", {}) as Dictionary).get(class_id, -1))
	var best_s := "Best win: A%d" % best if best >= 0 else "No win yet"
	match skin:
		"victor":
			return "" if best >= 0 else "No win with this class yet"
		"ascendant", "prestige":
			return best_s
		"bossbane":
			var beaten: Array = (p.records.get("bosses_by_class", {}) as Dictionary).get(class_id, [])
			var names := PackedStringArray()
			for b in beaten:
				names.append(String(EnemyDefs.def(String(b)).get("name", String(b))))
			var s := "Final bosses: %d/%d" % [beaten.size(), SkinDefs.BOSSES_FOR_BOSSBANE]
			if not names.is_empty():
				s += " (%s)" % ", ".join(names)
			return s + "  ·  " + best_s
	return ""


## A class medallion in the carousel.
class _Pick:
	extends VBoxContainer
	signal pressed
	var _down := false

	func setup(id: String, owned: bool, secret: bool, sel: bool, has_new: bool) -> void:
		add_theme_constant_override("separation", 2)
		mouse_filter = Control.MOUSE_FILTER_STOP
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if owned else Control.CURSOR_ARROW
		var col := UiPalette.class_color(id)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(72, 72)
		holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(holder)
		var icon := "question" if secret else Icons.class_icon(id)
		var med := CampArt.medal(icon, 72 if sel else 64, UiPalette.GOLD_BRIGHT if sel else col, not owned, col)
		med.position = Vector2.ZERO if sel else Vector2(4, 4)
		if not owned:
			med.modulate = Color(1, 1, 1, 0.75)
		holder.add_child(med)
		if has_new:
			holder.add_child(CampArt.pin(CampArt.new_dot(18), "tr", 2.0))
		var name := "???" if secret else String(HeroDefs.DATA[id].name)
		var l := UiTheme.label(name, 16, (UiPalette.GOLD_BRIGHT if sel else UiPalette.TEXT) if owned else UiPalette.TEXT_MUTED, false, 0, false, 700)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.custom_minimum_size.x = 40
		add_child(l)

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
			UiTheme.sfx("click")
			pressed.emit()


## A red "new" dot.
class _Dot:
	extends Control
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.5
		draw_circle(size * 0.5, r, UiPalette.OUTLINE)
		draw_circle(size * 0.5, r - 2.5, UiPalette.HP)
