class_name WardrobeModal
extends CampModal
## Wardrobe (docs/design/2026-09-28-classes-enemies-skins.md §4.3): the class carousel (owned
## classes; locked ones as dark medallions, the secret one as "???"), the hero turning on a
## pedestal, four skin swatches (Default, Victor, Ascendant, Bossbane) and the A10 prestige
## toggle. Owned swatches equip on tap (free, instant); locked ones preview on the pedestal and
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
	set_title("WARDROBE", Color("c79bff"))
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
	body.add_child(_classes(p, unseen))
	body.add_child(_stand(p))
	body.add_child(CampModal.heading("Skins", "Cosmetic only. Win with the class to earn them."))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_child(grid)
	for s in SWATCHES:
		grid.add_child(_swatch(p, String(s)))
	body.add_child(_prestige(p))


## The class carousel: every class as a medallion (owned: tappable; NEW dot on unseen skins).
func _classes(p: Profile, unseen: Array) -> Control:
	var grid := GridContainer.new()
	grid.columns = 6
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
	_portrait.custom_minimum_size = Vector2(0, 330)
	_portrait.ring_color = UiPalette.class_color(view_class)
	_portrait.set_hero(view_class, shown, p.prestige_on(view_class), false)
	col.add_child(_portrait)
	var row := UiTheme.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	row.add_child(UiTheme.label(String(HeroDefs.DATA[view_class].name), 32, UiPalette.class_color(view_class).lightened(0.25), true, 6))
	row.add_child(UiTheme.label(String(SkinDefs.NAMES[shown]), 26, UiPalette.TEXT, true, 5))
	if not owned:
		row.add_child(CampUi.chip("PREVIEW  ·  LOCKED", Color(0.25, 0.2, 0.35), UiPalette.TEXT_DIM, 16))
	elif shown == eq:
		row.add_child(CampUi.chip("WORN", UiPalette.HEAL.darkened(0.3), UiPalette.TEXT, 16))
	return c


## One skin swatch: a small portrait, its name and status (worn / equip / lock + progress / buy).
func _swatch(p: Profile, skin: String) -> Control:
	var owned := p.owns_skin(view_class, skin)
	var worn := owned and p.equipped_skin(view_class) == skin
	var shown := (preview_skin if preview_skin != "" else p.equipped_skin(view_class)) == skin
	var is_new := _fresh.has("%s:%s" % [view_class, skin])
	var card := _Swatch.new()
	var sb: StyleBoxFlat
	if worn:
		sb = UiTheme.box(UiPalette.NAVY_3, 20, 3, UiPalette.GOLD_BRIGHT, 12, Color(0.95, 0.7, 0.2, 0.3), Vector2.ZERO)
	elif shown:
		sb = UiTheme.box(Color(0.1, 0.08, 0.2, 0.9), 20, 3, Color("c79bff"))
	else:
		sb = UiTheme.box(Color(0.03, 0.03, 0.09, 0.6), 20, 2, Color(1, 1, 1, 0.08) if not owned else Color(UiPalette.class_color(view_class), 0.4))
	UiTheme.pad(sb, 10, 10)
	card.add_theme_stylebox_override("panel", sb)
	card.size_flags_vertical = Control.SIZE_FILL
	var col := UiTheme.vbox(6)
	card.add_child(col)
	var por := HeroPortrait.new()
	por.custom_minimum_size = Vector2(0, 170)
	por.spin = 0.0
	por.zoom = 1.15
	por.ring_color = UiPalette.class_color(view_class) if owned else Color(0.35, 0.33, 0.45)
	por.set_hero(view_class, skin, false, false)
	por.silhouette = false
	if not owned:
		por.modulate = Color(0.62, 0.6, 0.7)
	col.add_child(por)
	var head := UiTheme.hbox(6)
	col.add_child(head)
	if not owned:
		var lk := CampUi.LockGlyph.new()
		lk.custom_minimum_size = Vector2(22, 22)
		lk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(lk)
	var nm := UiTheme.label(String(SkinDefs.NAMES[skin]), 24, UiPalette.GOLD_BRIGHT if worn else (UiPalette.TEXT if owned else UiPalette.TEXT_DIM), true, 4)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	if is_new:
		head.add_child(CampUi.chip("NEW", UiPalette.HP, UiPalette.TEXT, 14))
	if worn:
		col.add_child(CampUi.chip("WORN", UiPalette.HEAL.darkened(0.3), UiPalette.TEXT, 15))
	elif owned:
		col.add_child(UiTheme.label("Tap to wear", 17, UiPalette.HEAL, false, 0, false, 700))
	else:
		col.add_child(UiTheme.para(SkinDefs.cond_text(view_class, skin), 16, UiPalette.TEXT_DIM, 500))
		var prog := progress_text(p, view_class, skin)
		if prog != "":
			col.add_child(UiTheme.para(prog, 15, Color("c79bff"), 700))
		if p.crowns_capped():
			var b := CampUi.buy_button("BUY", {"crowns": SkinDefs.BUY_PRICE}, p.crowns >= SkinDefs.BUY_PRICE, 20)
			b.min_height = 60
			b.pressed.connect(cmd.bind(["buy_skin", view_class, skin]))
			col.add_child(b)
	card.pressed.connect(func() -> void:
		if owned:
			preview_skin = ""
			if not worn:
				cmd(["equip_skin", view_class, skin])
			elif _portrait:
				_portrait.cheer()
		else:
			preview_skin = skin
			show_profile(profile))
	return card


## The A10 prestige overlay: a toggle when owned, else its condition and the best ascension.
func _prestige(p: Profile) -> Control:
	var owned := p.owns_skin(view_class, "prestige")
	var c := CampUi.card(owned and p.prestige_on(view_class), UiPalette.GOLD)
	var row := UiTheme.hbox(12)
	c.add_child(row)
	row.add_child(OptionCard.Medallion.make("crown", 60, UiPalette.GOLD_BRIGHT if owned else UiPalette.TEXT_MUTED,
		UiPalette.GOLD if owned else Color(0.4, 0.4, 0.5)))
	var col := UiTheme.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var ov := String(SkinDefs.def(view_class, "prestige").get("overlay", "crown"))
	col.add_child(UiTheme.label("PRESTIGE  ·  %s" % String(PRESTIGE_NAMES.get(ov, "Crown")).to_upper(), 24, UiPalette.GOLD_BRIGHT if owned else UiPalette.TEXT_DIM, true, 5))
	if owned:
		col.add_child(UiTheme.para("Shown over any skin you wear.", 17, UiPalette.TEXT_DIM, 500))
		var on := p.prestige_on(view_class)
		var t := GameButton.make("ON" if on else "OFF", "check" if on else "close", GameButton.Kind.PRIMARY if on else GameButton.Kind.SECONDARY, 24)
		t.min_height = 68
		t.pad_x = 18
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		t.pressed.connect(cmd.bind(["set_prestige", view_class, not on]))
		row.add_child(t)
	else:
		col.add_child(UiTheme.para(SkinDefs.cond_text(view_class, "prestige") + " Never for sale.", 17, UiPalette.TEXT_DIM, 500))
		var prog := progress_text(p, view_class, "prestige")
		if prog != "":
			col.add_child(UiTheme.para(prog, 15, Color("c79bff"), 700))
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
		var icon := "question" if secret else UiIcons.class_icon(id)
		var med := OptionCard.Medallion.make(icon, 72 if sel else 64, col if owned else UiPalette.TEXT_MUTED,
			UiPalette.GOLD_BRIGHT if sel else (col if owned else Color(0.3, 0.3, 0.4)))
		med.position = Vector2.ZERO if sel else Vector2(4, 4)
		if not owned:
			med.modulate = Color(0.55, 0.55, 0.65, 0.8)
		holder.add_child(med)
		if has_new:
			var dot := _Dot.new()
			dot.size = Vector2(20, 20)
			dot.position = Vector2(54, 0)
			holder.add_child(dot)
		var name := "???" if secret else String(HeroDefs.DATA[id].name)
		var l := UiTheme.label(name, 15, (UiPalette.GOLD_BRIGHT if sel else UiPalette.TEXT) if owned else UiPalette.TEXT_MUTED, false, 0, false, 700)
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


## A tappable swatch card.
class _Swatch:
	extends PanelContainer
	signal pressed
	var _down := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_down = true
		elif _down:
			_down = false
			if get_global_rect().has_point(mb.global_position):
				UiTheme.sfx("click")
				UiTheme.pop(self, 1.03, 0.15)
				pressed.emit()
