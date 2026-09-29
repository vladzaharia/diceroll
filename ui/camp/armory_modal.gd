class_name ArmoryModal
extends CampModal
## The Armory (docs/design/2026-09-29-armory-items.md §8.3): per-class loadouts of real KayKit
## items. Top to bottom (landscape: the doll, look and ranks on the left, the picker on the right):
##   * class switcher (owned classes)
##   * the paper doll: the hero turning on a pedestal in the equipped items, the seven slots
##     around it (Head, Body, Back | Weapon, Off-hand, Trinket, Belt Pouch), each a 3D thumbnail
##     with its tier; tap a slot to pick for it
##   * the picker for the slot: every item as a card (3D preview, rule text at this class's tier,
##     tier / kit / 2H chips, mastery progress, NEW, how to get it when locked, buy buttons);
##     the focused item shows its variant chips, and a chip opens its detail: the secondary
##     property, the blueprint condition and progress, CRAFT (Crowns or Sigils) or EQUIP
##   * Appearance: which piece the head and body *show* (own look, hidden, any owned piece);
##     the equipped item's rules always apply
##   * Ranks: the four rank groups (tier I / II / III) with RANK UP, and the Belt Pouch
## Back items are Style only (no stats, no rank). Commands: equip_item, set_appearance, buy_item,
## craft_variant, rank_up, buy_pouch, mark_items_seen (Camp.apply). Equipping a head or body
## piece also moves the look along with it unless the player picked another look on purpose.

const ACCENT := Color("ff9a5a")
const TIER_NAMES := ["", "I", "II", "III"]
const TIER_COLORS := [Color("7d7896"), Color("c9d2e4"), Color("6fb8ff"), Color("ffc24a")]
const SLOT_NAMES := {"weapon": "Weapon", "offhand": "Off-hand", "head": "Head", "body": "Body", "trinket": "Trinket",
	"trinket2": "Belt Pouch", "back": "Back"}
const SLOT_ICONS := {"weapon": "sword", "offhand": "shield", "head": "helmet", "body": "armor", "trinket": "ring",
	"trinket2": "pouch", "back": "cape"}
const GROUP_NAMES := {"weapon": "Weapon", "offhand": "Off-hand", "armor": "Armor", "trinket": "Trinket"}
const GROUP_ICONS := {"weapon": "sword", "offhand": "shield", "armor": "armor", "trinket": "ring"}
const LEFT_SLOTS := ["head", "body", "back"]
const RIGHT_SLOTS := ["weapon", "offhand", "trinket", "trinket2"]

## The class whose loadout is shown ("" = the run loadout's class).
var view_class := ""
## The slot the picker shows.
var sel_slot := "weapon"
## The item whose variants are open in the picker ("" = the slot's equipped item).
var focus := ""
## The variant chip opened for detail ("" = none).
var chip := ""
## Item / variant ids still marked NEW this visit (cleared when the screen closes).
var _fresh: Array = []
var _portrait: HeroPortrait
var _picker_head: Control
var _scroll_to_picker := false
## Ranks at the previous rebuild: a group that just went up flashes.
var _seen_ranks: Dictionary = {}
var _ranks_now: Dictionary = {}


func _build() -> void:
	set_title("ARMORY", ACCENT)
	closed.connect(func() -> void:
		_fresh.clear()
		focus = ""
		chip = "")


func _wide() -> bool:
	var v := get_viewport_rect().size if is_inside_tree() else Vector2(720, 1280)
	return v.x > v.y * 1.25


func rebuild(p: Profile) -> void:
	if view_class == "" or not p.class_allowed(view_class):
		view_class = String(p.loadout.get("class", "knight"))
	if not p.class_allowed(view_class):
		view_class = "knight"
	var unseen: Array = p.armory.get("seen_new", [])
	if not unseen.is_empty():
		for u in unseen:
			if not _fresh.has(u):
				_fresh.append(u)
		(func() -> void: cmd(["mark_items_seen"])).call_deferred()
	if focus != "" and ItemDefs.slot_of(focus) != _slot_kind(sel_slot):
		focus = ""
		chip = ""
	_seen_ranks = _ranks_now.duplicate()
	for g in ItemDefs.GROUPS:
		_ranks_now[String(g)] = p.rank(String(g))
	_ranks_now["pouch"] = 1 if p.has_pouch() else 0
	var wide := _wide()
	max_width = 1180.0 if wide else 720.0
	body.add_child(_classes(p))
	if wide:
		var row := UiTheme.hbox(18)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_child(row)
		var left := UiTheme.vbox(16)
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.size_flags_stretch_ratio = 0.9
		row.add_child(left)
		var right := UiTheme.vbox(16)
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(right)
		left.add_child(_doll(p, true))
		if not ItemDefs.LOCKED_ARMOR.has(view_class):
			left.add_child(_appearance(p))
		left.add_child(_ranks(p))
		right.add_child(_picker(p))
	else:
		body.add_child(_doll(p, false))
		body.add_child(_picker(p))
		if not ItemDefs.LOCKED_ARMOR.has(view_class):
			body.add_child(_appearance(p))
		body.add_child(_ranks(p))
	if _scroll_to_picker:
		_scroll_to_picker = false
		_reveal_picker.call_deferred()


## After tapping a slot on a phone: scroll so the picker's heading shows.
func _reveal_picker() -> void:
	if not is_inside_tree():
		return
	for i in 3:
		await get_tree().process_frame
	if _picker_head and is_instance_valid(_picker_head) and not _wide():
		var top := _picker_head.get_global_rect().position.y - _scroll.get_global_rect().position.y
		if top > _scroll.size.y * 0.55 or top < 0.0:
			var tw := create_tween()
			tw.tween_property(_scroll, "scroll_vertical", int(_scroll.scroll_vertical + top - 12.0), 0.25) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ================================================================ class switcher

func _classes(p: Profile) -> Control:
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	for id in HeroDefs.IDS:
		var cid := String(id)
		if not p.class_allowed(cid):
			continue
		var sel := cid == view_class
		var b := _Tap.new()
		var hold := Control.new()
		hold.custom_minimum_size = Vector2(64, 64)
		hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(hold)
		var med := OptionCard.Medallion.make(UiIcons.class_icon(cid), 64 if sel else 54, UiPalette.class_color(cid),
			UiPalette.GOLD_BRIGHT if sel else Color(UiPalette.class_color(cid), 0.6))
		med.position = Vector2.ZERO if sel else Vector2(5, 5)
		med.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hold.add_child(med)
		b.tooltip_text = String(HeroDefs.DATA[cid].name)
		b.pressed.connect(func() -> void:
			if cid != view_class:
				view_class = cid
				focus = ""
				chip = ""
				show_profile(profile))
		row.add_child(b)
	return row


# ================================================================ paper doll

func _doll(p: Profile, wide: bool) -> Control:
	var col := UiPalette.class_color(view_class)
	var c := CampUi.card(true, col)
	var v := UiTheme.vbox(6)
	c.add_child(v)
	var name_row := UiTheme.hbox(10)
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(name_row)
	name_row.add_child(UiTheme.label(String(HeroDefs.DATA[view_class].name), 32, col.lightened(0.25), true, 6))
	name_row.add_child(CampUi.chip("KIT +1 TIER", Color(col, 0.35), UiPalette.TEXT, 14))
	var row := UiTheme.hbox(10)
	v.add_child(row)
	var tile_px := 92 if wide else 96
	var left := UiTheme.vbox(10)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(left)
	for s in LEFT_SLOTS:
		left.add_child(_slot_tile(p, String(s), tile_px))
	_portrait = HeroPortrait.new()
	_portrait.custom_minimum_size = Vector2(150, 0)
	_portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_portrait.ring_color = col
	_portrait.zoom = 1.0
	var skin := p.equipped_skin(view_class)
	var pres := p.prestige_on(view_class)
	_portrait.set_hero(view_class, skin, pres, false, ArmoryLook.of_profile(p, view_class, skin, pres))
	# tap the hero: a preview of the equipped weapon's attack
	_portrait.mouse_filter = Control.MOUSE_FILTER_STOP
	_portrait.tooltip_text = "Tap to preview the attack"
	_portrait.gui_input.connect(func(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _portrait.hero:
			_portrait.cheer("attack"))
	row.add_child(_portrait)
	var right := UiTheme.vbox(10)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(right)
	for s in RIGHT_SLOTS:
		right.add_child(_slot_tile(p, String(s), tile_px))
	return c


## The equipped entry of a slot: [id, variant] ("" = empty).
func _equipped(p: Profile, slot: String) -> Array:
	var e: Variant = p.loadout_for(view_class).get(slot, "")
	if e is Dictionary:
		return [String(e.get("id", "")), String(e.get("variant", ""))]
	return [String(e), String(e)]


## The slot kind an item slot uses (trinket2 lists trinkets).
static func _slot_kind(slot: String) -> String:
	return "trinket" if slot == "trinket2" else slot


func _slot_tile(p: Profile, slot: String, px: int) -> Control:
	var eq := _equipped(p, slot)
	var id := String(eq[0])
	var locked_pouch := slot == "trinket2" and not p.has_pouch()
	var dino := String(ItemDefs.LOCKED_ARMOR.get(view_class, ""))
	if dino != "" and slot == "head":
		id = dino
	var t := _Tap.new()
	var sel := slot == sel_slot
	var sb: StyleBoxFlat
	if sel:
		sb = UiTheme.box(UiPalette.NAVY_3, 18, 3, UiPalette.GOLD_BRIGHT, 10, Color(0.95, 0.7, 0.2, 0.3), Vector2.ZERO)
	else:
		sb = UiTheme.box(Color(0.03, 0.03, 0.09, 0.7), 18, 2, Color(1, 1, 1, 0.1))
	UiTheme.pad(sb, 6, 6)
	t.add_theme_stylebox_override("panel", sb)
	var v := UiTheme.vbox(2)
	t.add_child(v)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(px, px)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(holder)
	if id != "" and not locked_pouch:
		var shown := ArmoryLook.shown_id(view_class, id, String(eq[1]))
		var th := ItemThumb.make(shown, px)
		th.size = Vector2(px, px)
		holder.add_child(th)
		var tier := _tier(p, id, slot)
		if tier > 0:
			var badge := _tier_badge(tier, 15)
			badge.position = Vector2(px - 30, px - 26)
			holder.add_child(badge)
		if slot in ["head", "body"] and not ItemDefs.LOCKED_ARMOR.has(view_class):
			var look := ArmoryLook.shown_look(p, view_class, slot)
			if look != id and not (look == "own" and id == ArmoryLook.kit_piece(view_class, slot)):
				var lb := PanelContainer.new()
				lb.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(Color("5a3f8a"), 10, 2, Color("c79bff")), 3, 1))
				lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
				lb.tooltip_text = "Shows another look"
				lb.add_child(UiIcons.rect("mirror", 18, Color("f0e0ff")))
				lb.position = Vector2(2, 2)
				holder.add_child(lb)
	else:
		var g := UiIcons.rect(String(SLOT_ICONS[slot]), int(px * 0.5), Color(1, 1, 1, 0.22))
		g.position = Vector2(px * 0.25, px * 0.25)
		holder.add_child(g)
		if locked_pouch:
			var lk := CampUi.LockGlyph.new()
			lk.size = Vector2(26, 26)
			lk.position = Vector2(px - 30, 4)
			holder.add_child(lk)
	if _slot_has_new(slot):
		var dot := WardrobeModal._Dot.new()
		dot.size = Vector2(18, 18)
		dot.position = Vector2(px - 16, -4)
		holder.add_child(dot)
	var cap := UiTheme.label(String(SLOT_NAMES[slot]).to_upper(), 15, UiPalette.GOLD_BRIGHT if sel else UiPalette.TEXT_DIM, false, 0, false, 800)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.custom_minimum_size.x = px
	v.add_child(cap)
	t.pressed.connect(func() -> void:
		if slot != sel_slot:
			sel_slot = slot
			focus = ""
			chip = ""
			_scroll_to_picker = true
			show_profile(profile)
		elif _portrait:
			_portrait.cheer())
	return t


func _slot_has_new(slot: String) -> bool:
	for u in _fresh:
		var base := ItemDefs.base_of(String(u))
		if base != "" and ItemDefs.fits(base, slot) and slot != "trinket2":
			return true
	return false


## Effective tier of an item in a slot for the viewed class (0 = no effect: rank 0 or Style).
func _tier(p: Profile, id: String, slot: String) -> int:
	var sl := slot if slot != "" else ItemDefs.slot_of(id)
	return ItemDefs.tier_for(id, sl, view_class, p.rank(String(ItemDefs.GROUP_OF.get(sl, "weapon"))))


## ItemDefs.rule_text, read naturally: "tier II: / tier III:" clauses carry that tier's own
## numbers (not the current tier's zero), and tier-I edge cases read as prose ("turns 1-1" ->
## "turn 1", "1 time(s)" -> "once", "1 dice" -> "1 die").
static func rule_text(id: String, tier: int, variant := "") -> String:
	var eff: Dictionary = ItemDefs.def(id).get("effect", {})
	if eff.is_empty():
		return "Style"
	var desc := String(eff.get("desc", ""))
	var re := RegEx.create_from_string("tier (III|II):")
	var out := ""
	var at := 0
	var t := maxi(1, tier)
	for m in re.search_all(desc):
		out += _fill(id, desc.substr(at, m.get_start() - at), t, variant)
		var mt := 3 if m.get_string(1) == "III" else 2
		var nxt := re.search(desc, m.get_end())
		var end := nxt.get_start() if nxt else desc.length()
		out += _fill(id, desc.substr(m.get_start(), end - m.get_start()), mt, variant)
		at = end
	out += _fill(id, desc.substr(at), t, variant)
	out = out.replace("turns 1-1", "turn 1").replace(" of 1 dice", " of 1 die").replace(", 1 dice", ", 1 die")
	out = RegEx.create_from_string("\\b1 dice\\b").sub(out, "1 die", true)
	out = RegEx.create_from_string("\\b1 time\\(s\\)").sub(out, "once", true)
	out = RegEx.create_from_string("\\b1 (\\w+)\\(s\\)").sub(out, "1 $1", true)
	out = RegEx.create_from_string("\\b(\\d+) (\\w+)\\(s\\)").sub(out, "$1 $2s", true)
	return out


## One clause of a rule with `tier`'s numbers (ItemDefs.rule_text's placeholders).
static func _fill(id: String, text: String, tier: int, variant: String) -> String:
	var eff: Dictionary = ItemDefs.def(id).get("effect", {})
	var s := text
	for key in (eff.get("n", {}) as Dictionary):
		var v := ItemDefs.num(id, String(key), tier, variant)
		s = s.replace("{%s%%}" % key, "%s%%" % ItemDefs._fmt(snappedf(v * 100.0, 0.1)))
		s = s.replace("{%s}" % key, ItemDefs._fmt(v))
	if id == "spear":
		s = s.replace("{boss_factor}", ItemDefs._fmt(ItemDefs.num(id, "factor", tier, variant) + ItemDefs.num(id, "boss", tier, variant)))
	return s


static func _tier_badge(tier: int, font := 15) -> Control:
	var p := PanelContainer.new()
	var col: Color = TIER_COLORS[clampi(tier, 0, 3)]
	p.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(Color(0.05, 0.05, 0.12, 0.95), 10, 2, col), 6, 0))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiTheme.label(String(TIER_NAMES[clampi(tier, 0, 3)]), font, col, true, 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


# ================================================================ picker

func _picker(p: Profile) -> Control:
	var v := UiTheme.vbox(10)
	var kind := _slot_kind(sel_slot)
	var sub := ""
	match sel_slot:
		"back":
			sub = "Style only: capes, cloaks and packs change the look, never the numbers."
		"trinket2":
			sub = "A second trinket, one tier lower, without rank bonuses. It can't repeat the first."
		_:
			sub = "Tier comes from your %s rank. The %s's own kit works one tier higher." % [
				String(GROUP_NAMES[ItemDefs.GROUP_OF[sel_slot]]), String(HeroDefs.DATA[view_class].name)]
	_picker_head = CampModal.heading(String(SLOT_NAMES[sel_slot]), sub)
	v.add_child(_picker_head)
	if sel_slot != "back":
		v.add_child(_rank_card(p, String(ItemDefs.GROUP_OF[sel_slot]), true))
	var locked := String(ItemDefs.LOCKED_ARMOR.get(view_class, ""))
	if locked != "" and sel_slot in ["head", "body"]:
		var lc := CampUi.locked_card()
		lc.add_child(CampUi.lock_line("The %s's head and body are one piece: the %s." % [String(HeroDefs.DATA[view_class].name),
			ItemDefs.name_of(locked)], 19))
		v.add_child(lc)
		v.add_child(_item_card(p, locked))
		return v
	if sel_slot == "trinket2" and not p.has_pouch():
		v.add_child(_pouch_card(p))
		return v
	var eq := _equipped(p, sel_slot)
	if focus == "":
		focus = String(eq[0])
	var owned: Array = []
	var others: Array = []
	for id in ItemDefs.of_slot(kind):
		var sid := String(id)
		if String(ItemDefs.def(sid).get("class_only", "")) not in ["", view_class]:
			continue
		if sid == "dino_suit":
			continue
		if p.owns_item(sid):
			owned.append(sid)
		else:
			others.append(sid)
	# none first (every slot but the weapon), then owned items, then the rest
	if sel_slot != "weapon":
		v.add_child(_none_card(p, String(eq[0]) == ""))
	for id in owned:
		v.add_child(_item_card(p, String(id)))
	if not others.is_empty():
		v.add_child(_sub_heading("NOT OWNED YET  ·  %d" % others.size()))
		for id in others:
			v.add_child(_item_card(p, String(id)))
	return v


func _sub_heading(text: String) -> Control:
	var l := UiTheme.label(text, 17, UiPalette.TEXT_MUTED, false, 0, false, 800)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _none_card(_p: Profile, is_eq: bool) -> Control:
	var t := _Tap.new()
	t.add_theme_stylebox_override("panel", _card_box(is_eq, false))
	var row := UiTheme.hbox(12)
	t.add_child(row)
	var holder := _thumb_box(56)
	holder.add_child(UiIcons.rect("close", 30, UiPalette.TEXT_MUTED))
	row.add_child(holder)
	var nm := UiTheme.label("Nothing" if sel_slot != "back" else "No back piece", 22, UiPalette.TEXT if not is_eq else UiPalette.GOLD_BRIGHT, true, 4)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(nm)
	if is_eq:
		row.add_child(CampUi.chip("EQUIPPED", UiPalette.HEAL.darkened(0.35), UiPalette.TEXT, 15))
	t.pressed.connect(func() -> void:
		if not is_eq:
			_equip("", ""))
	return t


func _card_box(equipped: bool, is_focus: bool, owned := true) -> StyleBoxFlat:
	var sb: StyleBoxFlat
	if equipped:
		sb = UiTheme.box(UiPalette.NAVY_3, 20, 3, UiPalette.GOLD_BRIGHT, 12, Color(0.95, 0.7, 0.2, 0.25), Vector2.ZERO)
	elif is_focus:
		sb = UiTheme.box(Color(0.09, 0.07, 0.18, 0.92), 20, 3, Color(ACCENT, 0.85))
	elif owned:
		sb = UiTheme.box(Color(0.03, 0.03, 0.09, 0.62), 20, 2, Color(ACCENT, 0.3))
	else:
		sb = UiTheme.box(Color(0.03, 0.03, 0.08, 0.45), 20, 2, Color(1, 1, 1, 0.06))
	UiTheme.pad(sb, 12, 10)
	return sb


## A dark rounded well for a thumbnail.
static func _thumb_box(px: int) -> PanelContainer:
	var b := PanelContainer.new()
	var sb := UiTheme.box(Color(0.02, 0.02, 0.07, 0.8), 16, 2, Color(1, 1, 1, 0.06))
	UiTheme.pad(sb, 2, 2)
	b.add_theme_stylebox_override("panel", sb)
	b.custom_minimum_size = Vector2(px, px)
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _is_new(id: String) -> bool:
	if _fresh.has(id):
		return true
	for v in ItemDefs.variants_of(id):
		if _fresh.has(String(v)):
			return true
	return false


## One item in the picker.
func _item_card(p: Profile, id: String) -> Control:
	var owned := p.owns_item(id)
	var eq := _equipped(p, sel_slot)
	var is_eq: bool = String(eq[0]) == id or String(ItemDefs.LOCKED_ARMOR.get(view_class, "")) == id
	var is_focus := focus == id
	var cosmetic := ItemDefs.is_cosmetic(id)
	var t := _Tap.new()
	t.add_theme_stylebox_override("panel", _card_box(is_eq, is_focus, owned))
	var outer := UiTheme.vbox(10)
	t.add_child(outer)
	var row := UiTheme.hbox(12)
	outer.add_child(row)
	# thumbnail (the equipped variant's model when equipped)
	var shown := ArmoryLook.shown_id(view_class, id, String(eq[1])) if is_eq else id
	var well := _thumb_box(100)
	row.add_child(well)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(96, 96)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_child(holder)
	var th := ItemThumb.make(shown, 96)
	th.size = Vector2(96, 96)
	if not owned:
		th.modulate = Color(0.55, 0.52, 0.62, 0.85)
	holder.add_child(th)
	if not owned:
		var lk := CampUi.LockGlyph.new()
		lk.size = Vector2(26, 26)
		lk.position = Vector2(66, 66)
		holder.add_child(lk)
	if _is_new(id):
		var nw := CampUi.chip("NEW", UiPalette.HP, UiPalette.TEXT, 13)
		nw.position = Vector2(-2, -4)
		holder.add_child(nw)
	# text
	var col := UiTheme.vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var head := HFlowContainer.new()
	head.add_theme_constant_override("h_separation", 6)
	head.add_theme_constant_override("v_separation", 4)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var nm := UiTheme.label(ItemDefs.name_of(id), 25, UiPalette.GOLD_BRIGHT if is_eq else (UiPalette.TEXT if owned else UiPalette.TEXT_DIM), true, 4)
	head.add_child(nm)
	var tier := _tier(p, id, sel_slot)
	if cosmetic:
		head.add_child(CampUi.chip("STYLE", Color("5a3f8a"), UiPalette.TEXT, 14))
	elif owned or tier > 0:
		head.add_child(_tier_chip(tier))
	if ItemDefs.affinity(id, view_class):
		head.add_child(CampUi.chip("★ KIT", Color(UiPalette.class_color(view_class), 0.5), UiPalette.TEXT, 14))
	if ItemDefs.slot_of(id) == "weapon" and ItemDefs.hands(id, String(eq[1]) if is_eq else id) >= 2:
		head.add_child(CampUi.chip("2H", Color(0.25, 0.25, 0.4), UiPalette.TEXT_DIM, 14))
	if is_eq:
		head.add_child(CampUi.chip("EQUIPPED", UiPalette.HEAL.darkened(0.35), UiPalette.TEXT, 14))
	# the rule at this class's tier (tier I numbers while the rank is 0)
	if cosmetic:
		col.add_child(UiTheme.para("Style: a look to wear. No stats.", 18, Color("c79bff"), 600))
	else:
		var eff: Dictionary = ItemDefs.def(id).get("effect", {})
		var v_rule := String(eq[1]) if is_eq else id
		var rl := UiTheme.para("%s: %s" % [String(eff.get("name", "")), rule_text(id, maxi(tier, 1), v_rule)], 18,
			UiPalette.TEXT if owned else UiPalette.TEXT_DIM, 600)
		col.add_child(rl)
		if tier <= 0 and owned:
			var g := String(ItemDefs.GROUP_OF.get(_slot_kind(sel_slot), "weapon"))
			col.add_child(UiTheme.para("Inactive until %s rank 1." % String(GROUP_NAMES[g]), 17, UiPalette.HP_BRIGHT, 700))
		var lo := p.loadout_for(view_class)
		var w: Dictionary = lo.weapon
		var off: Dictionary = lo.offhand
		if sel_slot == "offhand" and ItemDefs.hand_mount(id) and String(w.id) != "" and ItemDefs.hands(String(w.id), String(w.variant)) >= 2:
			col.add_child(UiTheme.para("Needs a free hand: the %s is two-handed." % ItemDefs.name_of(String(w.variant)), 16, UiPalette.HP_BRIGHT, 700))
		elif sel_slot == "weapon" and not is_eq and ItemDefs.hands(id, id) >= 2 and ItemDefs.hand_mount(String(off.id)):
			col.add_child(UiTheme.para("Two-handed: the %s comes off." % ItemDefs.name_of(String(off.variant)), 16, Color("ffc27a"), 700))
		if sel_slot == "trinket2" and id == "compass":
			col.add_child(UiTheme.para("The board reroll only works in the first trinket slot.", 16, UiPalette.TEXT_MUTED, 600))
	# mastery / how to get it
	if owned:
		var ml := _mastery_line(p, id)
		if ml != null:
			col.add_child(ml)
	else:
		col.add_child(_acquire(p, id))
	# variants of the focused item
	var vs := ItemDefs.variants_of(id)
	if is_focus and vs.size() > 1:
		outer.add_child(_variants(p, id))
	elif vs.size() > 1:
		var have := p.owned_variants(id).size()
		var cr := 0
		for vv in vs:
			if p.has_blueprint(id, String(vv)):
				cr += 1
		var s := "%d variants" % vs.size() + ("  ·  %d owned" % have if have > 0 else "") + ("  ·  %d to craft" % cr if cr > 0 else "")
		col.add_child(UiTheme.label(s + "  ▸", 16, UiPalette.GOLD if cr > 0 else UiPalette.TEXT_MUTED, false, 0, false, 700))
	var lo2 := p.loadout_for(view_class)
	var blocked: bool = sel_slot == "offhand" and ItemDefs.hand_mount(id) and String(lo2.weapon.id) != "" \
		and ItemDefs.hands(String(lo2.weapon.id), String(lo2.weapon.variant)) >= 2
	if blocked:
		t.modulate = Color(1, 1, 1, 0.7)
	t.pressed.connect(func() -> void:
		if blocked and owned:
			UiTheme.sfx("error")
			focus = id
			show_profile(profile)
		elif owned and not is_eq and ItemDefs.LOCKED_ARMOR.get(view_class, "") != id:
			focus = id
			chip = ""
			_equip(id, id)
		elif focus != id:
			focus = id
			chip = ""
			show_profile(profile)
		elif _portrait:
			_portrait.cheer())
	return t


func _tier_chip(tier: int) -> Control:
	if tier <= 0:
		return CampUi.chip("RANK 0", Color(0.3, 0.12, 0.16), UiPalette.HP_BRIGHT, 14)
	var col: Color = TIER_COLORS[tier]
	return CampUi.chip("TIER " + String(TIER_NAMES[tier]), Color(col, 0.28), col.lightened(0.3), 14)


## "Mastery 12 fights · 3 to the Knight's Sword blueprint" with a bar (items with blueprints).
func _mastery_line(p: Profile, id: String) -> Control:
	var m := p.item_mastery(id)
	var next := 0
	var next_v := ""
	for v in ItemDefs.variants_of(id):
		var u: Dictionary = ItemDefs.VARIANTS.get(String(v), {}).get("unlock", {})
		var need := int(u.get("mastery", u.get("or_mastery", 0)))
		if need > m and (next == 0 or need < next) and not p.owns_variant(id, String(v)) and not p.has_blueprint(id, String(v)):
			next = need
			next_v = String(v)
	if next == 0:
		if m <= 0 or ItemDefs.variants_of(id).size() <= 1:
			return null if m <= 0 else UiTheme.label("Mastery: %d fights won" % m, 16, UiPalette.TEXT_MUTED, false, 0, false, 700)
		var feats := 0
		for v in ItemDefs.variants_of(id):
			if not p.owns_variant(id, String(v)) and not p.has_blueprint(id, String(v)):
				feats += 1
		if feats > 0:
			return UiTheme.label("Mastery %d  ·  %s from feats" % [m, "1 more blueprint" if feats == 1 else "%d more blueprints" % feats], 16,
				Color("e0c28a"), false, 0, false, 700)
		return UiTheme.label("Mastery %d  ·  every blueprint earned" % m, 16, UiPalette.HEAL, false, 0, false, 700)
	var box := UiTheme.vbox(2)
	var l := UiTheme.label("MASTERY %d / %d  ·  %s blueprint" % [m, next, ItemDefs.name_of(next_v)], 16, Color("e0c28a"), false, 0, false, 700)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size.x = 60
	box.add_child(l)
	var b := CampUi.bar(m, next, Color("e0a84a"), 12.0)
	box.add_child(b)
	return box


## How to get an item the profile doesn't own: buy buttons, a milestone, a kit or a feat.
func _acquire(p: Profile, id: String) -> Control:
	var box := UiTheme.vbox(6)
	var classes: Array = p.unlocks.get("classes", [])
	var cost := ItemDefs.price(id, classes)
	var why := ""
	var kc := ItemDefs.kit_class(id)
	var m := CampInfo.milestone_for("items", id)
	if not m.is_empty():
		why = String(m.desc)
	elif ItemDefs.BACK_FEATS.has(id):
		why = String(ItemDefs.FEATS.get(String(ItemDefs.BACK_FEATS[id]), {}).get("desc", ""))
	elif kc != "" and cost.is_empty():
		why = "Comes with the %s." % String(HeroDefs.DATA[kc].name)
	if kc != "" and not cost.is_empty() and not classes.has(kc):
		why = "Comes with the %s, or buy it now." % String(HeroDefs.DATA[kc].name)
	if why != "":
		box.add_child(CampUi.lock_line(why, 17))
	if not cost.is_empty():
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 8)
		row.add_theme_constant_override("v_separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(row)
		var b := CampUi.buy_button("BUY", cost, p.can_afford(cost), 20)
		b.min_height = 60
		b.pressed.connect(cmd.bind(["buy_item", id, "crowns"]))
		row.add_child(b)
		var sc := ItemDefs.price(id, classes, true)
		if not sc.is_empty():
			var bs := CampUi.buy_button("", sc, p.can_afford(sc), 20)
			bs.min_height = 60
			bs.pressed.connect(cmd.bind(["buy_item", id, "sigils"]))
			row.add_child(bs)
	elif why == "":
		box.add_child(CampUi.lock_line("Locked", 17))
	return box


# ---------------------------------------------------------------- variants

func _variants(p: Profile, id: String) -> Control:
	var box := UiTheme.vbox(8)
	var eq := _equipped(p, sel_slot)
	var worn := String(eq[1]) if String(eq[0]) == id else ""
	box.add_child(UiTheme.label("VARIANTS  ·  same rule, one extra property", 17, UiPalette.GOLD, false, 0, false, 800))
	var grid := GridContainer.new()
	grid.columns = 3 if not _wide() else 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(grid)
	var chips: Array = Camp.new(p).variant_chips(id)
	for ch in chips:
		grid.add_child(_variant_chip(p, id, ch, String(ch.id) == worn))
	if chip != "":
		for ch in chips:
			if String(ch.id) == chip:
				box.add_child(_variant_detail(p, id, ch, String(ch.id) == worn))
	return box


func _variant_chip(p: Profile, item: String, ch: Dictionary, worn: bool) -> Control:
	var vid := String(ch.id)
	var st := String(ch.state)
	var t := _Tap.new()
	var sel := chip == vid
	var sb: StyleBoxFlat
	if worn:
		sb = UiTheme.box(Color(0.12, 0.1, 0.05, 0.9), 16, 3, UiPalette.GOLD_BRIGHT)
	elif sel:
		sb = UiTheme.box(Color(0.1, 0.08, 0.2, 0.95), 16, 3, Color(ACCENT, 0.9))
	elif st == "craftable":
		sb = UiTheme.box(Color(0.1, 0.08, 0.03, 0.8), 16, 2, Color(UiPalette.GOLD, 0.7))
	elif st == "owned":
		sb = UiTheme.box(Color(0.03, 0.03, 0.09, 0.7), 16, 2, Color(ACCENT, 0.35))
	else:
		sb = UiTheme.box(Color(0.03, 0.03, 0.08, 0.5), 16, 2, Color(1, 1, 1, 0.05))
	UiTheme.pad(sb, 6, 6)
	t.add_theme_stylebox_override("panel", sb)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UiTheme.vbox(2)
	t.add_child(v)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 70)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(holder)
	var th := ItemThumb.make(ArmoryLook.shown_id(view_class, item, vid) if worn else vid, 70)
	th.set_anchors_preset(Control.PRESET_FULL_RECT)
	if st == "locked":
		th.modulate = Color(0.5, 0.48, 0.58, 0.8)
	holder.add_child(th)
	if _fresh.has(vid):
		var nw := CampUi.chip("NEW", UiPalette.HP, UiPalette.TEXT, 12)
		nw.position = Vector2(0, -2)
		holder.add_child(nw)
	var nm := UiTheme.label(String(ch.name), 18, UiPalette.GOLD_BRIGHT if worn else (UiPalette.TEXT if st != "locked" else UiPalette.TEXT_DIM), false, 0, false, 800)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.custom_minimum_size.x = 40
	v.add_child(nm)
	var line := ""
	var lc := UiPalette.TEXT_MUTED
	match st:
		"owned":
			line = "WORN" if worn else "OWNED"
			lc = UiPalette.HEAL if worn else UiPalette.TEXT_DIM
		"craftable":
			line = "CRAFT  %d" % int((ch.cost as Dictionary).get("crowns", 0))
			lc = UiPalette.GOLD_BRIGHT
		_:
			var ms: Array = ch.get("mastery", [0, 0])
			line = "%d / %d fights" % [int(ms[0]), int(ms[1])] if int(ms[1]) > 0 else "FEAT"
	var ll := UiTheme.label(line, 15, lc, false, 0, false, 800)
	ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ll)
	if st == "locked" and int((ch.get("mastery", [0, 0]) as Array)[1]) > 0:
		var ms2: Array = ch.mastery
		v.add_child(CampUi.bar(float(ms2[0]), float(ms2[1]), Color("e0a84a"), 8.0))
	t.pressed.connect(func() -> void:
		if st == "owned" and not worn:
			chip = vid
			_equip(item, vid)
		else:
			chip = "" if chip == vid else vid
			show_profile(profile))
	return t


## The opened variant: its property, how it is earned, and CRAFT / EQUIP.
func _variant_detail(p: Profile, item: String, ch: Dictionary, worn: bool) -> Control:
	var vid := String(ch.id)
	var st := String(ch.state)
	var c := CampUi.card(st == "craftable", UiPalette.GOLD)
	var v := UiTheme.vbox(6)
	c.add_child(v)
	var head := UiTheme.hbox(8)
	v.add_child(head)
	var nm := UiTheme.label(String(ch.name), 24, UiPalette.GOLD_BRIGHT, true, 4)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	var sec := String(ItemDefs.VARIANTS.get(vid, {}).get("sec_name", ""))
	var tag := "STANDARD" if vid == item else sec.to_upper()
	head.add_child(CampUi.chip(tag, Color(ACCENT, 0.35), UiPalette.TEXT, 13))
	v.add_child(UiTheme.para(String(ch.desc), 18, UiPalette.TEXT, 600))
	var hands := ItemDefs.hands(item, vid)
	if ItemDefs.slot_of(item) == "weapon" and hands != ItemDefs.hands(item, item):
		v.add_child(UiTheme.para("Two-handed: no shield or parrying dagger with it.", 16, UiPalette.HP_BRIGHT, 700))
	match st:
		"owned":
			if worn:
				v.add_child(CampUi.chip("WORN", UiPalette.HEAL.darkened(0.3), UiPalette.TEXT, 15))
		"craftable":
			var src := "Blueprint earned" + (": " + String(ch.unlock) if String(ch.unlock) != "" else "")
			v.add_child(UiTheme.para(src, 16, UiPalette.HEAL, 600))
			if not p.owns_item(item):
				v.add_child(CampUi.lock_line("Own the %s to craft it." % ItemDefs.name_of(item), 16))
			else:
				var row := HFlowContainer.new()
				row.add_theme_constant_override("h_separation", 8)
				row.add_theme_constant_override("v_separation", 8)
				row.mouse_filter = Control.MOUSE_FILTER_PASS
				v.add_child(row)
				var cost: Dictionary = ch.cost
				var b := CampUi.buy_button("CRAFT", cost, p.can_afford(cost), 22)
				b.pressed.connect(cmd.bind(["craft_variant", item, vid, "crowns"]))
				row.add_child(b)
				var sc := ItemDefs.craft_cost(vid, true)
				var bs := CampUi.buy_button("", sc, p.can_afford(sc), 22)
				bs.pressed.connect(cmd.bind(["craft_variant", item, vid, "sigils"]))
				row.add_child(bs)
		_:
			v.add_child(CampUi.lock_line("Blueprint: " + String(ch.unlock), 16))
			var ms: Array = ch.get("mastery", [0, 0])
			if int(ms[1]) > 0:
				v.add_child(CampUi.bar(float(ms[0]), float(ms[1]), Color("e0a84a"), 14.0))
			var cc := ItemDefs.craft_cost(vid)
			if not cc.is_empty():
				v.add_child(UiTheme.label("Then craft it for %d Crowns or %d Sigils." % [int(cc.get("crowns", 0)), ItemDefs.CRAFT_SIGILS],
					15, UiPalette.TEXT_MUTED, false, 0, false, 600))
	return c


# ================================================================ equipping

## Equips `id` (variant) in the selected slot; a head / body look follows the new piece unless
## the player chose another look on purpose (a stored look that is neither the old piece nor the
## own look of the old kit piece).
func _equip(id: String, variant: String) -> void:
	var p := profile
	var slot := sel_slot
	var follow := slot in ["head", "body"] and not ItemDefs.LOCKED_ARMOR.has(view_class)
	var old := _equipped_of(p, view_class, slot)
	var stored: Dictionary = (p.armory.get("appearance", {}) as Dictionary).get(view_class, {})
	var cur := String(p.appearance_of(view_class).get(slot, "own"))
	var kit := ArmoryLook.kit_piece(view_class, slot)
	cmd(["equip_item", view_class, slot, id, variant])
	if not follow or not (not stored.has(slot) or cur == old or (cur == "own" and old == kit)):
		return
	var nv := id
	if id == "":
		nv = "hidden" if slot == "head" else "own"
	elif id == kit:
		nv = "own"
	if (stored.has(slot) and nv != cur) or (not stored.has(slot) and nv != "own"):
		cmd(["set_appearance", view_class, slot, nv])


static func _equipped_of(p: Profile, cls: String, slot: String) -> String:
	var e: Variant = p.loadout_for(cls).get(slot, "")
	return String(e.get("id", "")) if e is Dictionary else String(e)


# ================================================================ appearance

func _appearance(p: Profile) -> Control:
	var box := UiTheme.vbox(10)
	box.add_child(CampModal.heading("Appearance", "Wear one piece's look while the equipped item's rules apply."))
	for slot in ["head", "body"]:
		box.add_child(_look_row(p, String(slot)))
	return box


func _look_row(p: Profile, slot: String) -> Control:
	var c := CampUi.card(false, Color("c79bff"))
	var v := UiTheme.vbox(8)
	c.add_child(v)
	var eq := _equipped_of(p, view_class, slot)
	var shown := ArmoryLook.shown_look(p, view_class, slot)
	var head := UiTheme.hbox(8)
	v.add_child(head)
	var t := UiTheme.label(String(SLOT_NAMES[slot]).to_upper(), 18, Color("c79bff"), false, 0, false, 800)
	head.add_child(t)
	var what := "Own look" if shown == "own" else ("Hidden" if shown == "hidden" else ItemDefs.name_of(shown))
	var stats := ItemDefs.name_of(eq) if eq != "" else "nothing"
	var sub := UiTheme.label("Shows %s  ·  rules from %s" % [what, stats], 16, UiPalette.TEXT_DIM, false, 0, false, 700)
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub.custom_minimum_size.x = 60
	head.add_child(sub)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	flow.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(flow)
	var opts: Array = ["own"]
	if slot == "head":
		opts.append("hidden")
	for id in ItemDefs.of_slot(slot):
		if p.owns_item(String(id)) and String(id) != "dino_suit":
			opts.append(String(id))
	var model := String(Character.kit(view_class).get("model", view_class))
	for o in opts:
		var oid := String(o)
		var on := shown == oid or (oid == eq and shown == eq)
		var bad := slot == "head" and ItemDefs.has(oid) and String(ArmorBinder.head_fit(model, oid).fit) == "bad"
		flow.add_child(_look_chip(slot, oid, on, oid == eq, bad))
	return c


func _look_chip(slot: String, value: String, on: bool, is_eq: bool, bad: bool) -> Control:
	var t := _Tap.new()
	var sb: StyleBoxFlat
	if on:
		sb = UiTheme.box(Color(0.12, 0.08, 0.22, 0.95), 14, 3, Color("c79bff"))
	else:
		sb = UiTheme.box(Color(0.03, 0.03, 0.09, 0.6), 14, 2, Color(1, 1, 1, 0.08))
	UiTheme.pad(sb, 4, 4)
	t.add_theme_stylebox_override("panel", sb)
	t.tooltip_text = "Own look" if value == "own" else ("Hidden" if value == "hidden" else ItemDefs.name_of(value))
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(64, 64)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(holder)
	if value == "own":
		var m := OptionCard.Medallion.make(UiIcons.class_icon(view_class), 48, UiPalette.class_color(view_class), UiPalette.class_color(view_class))
		m.position = Vector2(8, 2)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(m)
		var l := UiTheme.label("OWN", 13, UiPalette.TEXT, false, 3, false, 800)
		l.position = Vector2(18, 46)
		holder.add_child(l)
	elif value == "hidden":
		var g := UiIcons.rect("close", 34, UiPalette.TEXT_MUTED)
		g.position = Vector2(15, 8)
		holder.add_child(g)
		var l2 := UiTheme.label("HIDE", 13, UiPalette.TEXT_DIM, false, 3, false, 800)
		l2.position = Vector2(17, 46)
		holder.add_child(l2)
	else:
		var th := ItemThumb.make(value, 64, slot)
		th.size = Vector2(64, 64)
		if bad:
			th.modulate = Color(0.6, 0.55, 0.6, 0.7)
		holder.add_child(th)
		if is_eq:
			var d := _EqDot.new()
			d.size = Vector2(14, 14)
			d.position = Vector2(48, 2)
			holder.add_child(d)
		if bad:
			var i := UiTheme.label("i", 17, UiPalette.HP_BRIGHT, true, 4)
			i.position = Vector2(4, 40)
			i.tooltip_text = "Doesn't fit this hero: shown hidden"
			holder.add_child(i)
	t.pressed.connect(func() -> void:
		if not on:
			cmd(["set_appearance", view_class, slot, value]))
	return t


# ================================================================ ranks

func _ranks(p: Profile) -> Control:
	var box := UiTheme.vbox(10)
	box.add_child(CampModal.heading("Ranks", "Tier I at rank 1, II at 4, III at 8. Each rank group powers its items."))
	for g in ItemDefs.GROUPS:
		box.add_child(_rank_card(p, String(g), false))
	box.add_child(_pouch_card(p))
	return box


func _rank_text(group: String, r: int) -> String:
	var t := ItemDefs.rank_tier(r)
	var s := "RANK %d / %d" % [r, ItemDefs.RANK_MAX]
	s += "  ·  TIER %s" % String(TIER_NAMES[t]) if t > 0 else "  ·  NOT FORGED"
	if group == "armor":
		var hp := int(ItemDefs.base_stats({"armor": r}).max_hp)
		if hp > 0:
			s += "  ·  +%d HP" % hp
	return s


## A rank group: name, pips (tier steps as diamonds), what the next rank does, RANK UP.
func _rank_card(p: Profile, group: String, compact: bool) -> Control:
	var owned := p.owns("gear", group)
	var r := p.rank(group)
	var up := _seen_ranks.has(group) and r > int(_seen_ranks[group])
	var c := CampUi.card(up, ACCENT) if owned else CampUi.locked_card()
	if up:
		_flash(c, "RANK %d!" % r if ItemDefs.rank_tier(r) == ItemDefs.rank_tier(r - 1) else "TIER %s!" % String(TIER_NAMES[ItemDefs.rank_tier(r)]))
	var v := UiTheme.vbox(6)
	c.add_child(v)
	var head := UiTheme.hbox(10)
	v.add_child(head)
	var tr := CampUi.title_row(String(GROUP_ICONS[group]), ACCENT if owned else UiPalette.TEXT_MUTED,
		"%s rank" % String(GROUP_NAMES[group]), _rank_text(group, r), 48 if compact else 56)
	tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tr)
	if not owned:
		var m := CampInfo.milestone_for("gear", group)
		v.add_child(CampUi.lock_line(String(m.get("desc", "Locked")), 16))
		return c
	var cost := ItemDefs.rank_cost(r)
	if cost.is_empty():
		head.add_child(CampUi.chip("MAX", UiPalette.GOLD_DEEP, UiPalette.TEXT, 18))
	else:
		var b := CampUi.buy_button("RANK UP" if r > 0 else "FORGE", cost, p.can_afford(cost), 20)
		b.min_height = 64
		b.pad_x = 14
		b.pressed.connect(cmd.bind(["rank_up", group]))
		head.add_child(b)
	var prow := UiTheme.hbox(10)
	v.add_child(prow)
	prow.add_child(CampUi.pips(r, ItemDefs.RANK_MAX, ACCENT, [1, 4, 8]))
	var nxt := _next_text(group, r)
	if nxt != "":
		var nl := UiTheme.label(nxt, 16, UiPalette.HEAL if r < ItemDefs.RANK_MAX else UiPalette.TEXT_DIM, false, 0, false, 700)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.custom_minimum_size.x = 60
		prow.add_child(nl)
	return c


## What the next rank changes ("Next: tier II at rank 4", "+1 max HP at rank 8").
func _next_text(group: String, r: int) -> String:
	if r >= ItemDefs.RANK_MAX:
		return "Every item at its best tier"
	var parts := PackedStringArray()
	var t := ItemDefs.rank_tier(r)
	for at in range(r + 1, ItemDefs.RANK_MAX + 1):
		if ItemDefs.rank_tier(at) > t:
			parts.append("tier %s at rank %d" % [String(TIER_NAMES[ItemDefs.rank_tier(at)]), at])
			break
	if group == "armor":
		var hp := int(ItemDefs.base_stats({"armor": r}).max_hp)
		for at in range(r + 1, ItemDefs.RANK_MAX + 1):
			var h2 := int(ItemDefs.base_stats({"armor": at}).max_hp)
			if h2 > hp:
				parts.append("+%d max HP at rank %d" % [h2, at])
				break
	if group == "weapon" and ItemDefs.ATK_BONUS > 0 and r < ItemDefs.ATK_RANK:
		parts.append("+%d ATK at rank %d" % [ItemDefs.ATK_BONUS, ItemDefs.ATK_RANK])
	if group == "trinket" and r < ItemDefs.POUCH_RANK:
		parts.append("Belt Pouch at rank %d" % ItemDefs.POUCH_RANK)
	return "Next: " + ", ".join(parts) if not parts.is_empty() else ""


## The Belt Pouch: the second trinket slot.
func _pouch_card(p: Profile) -> Control:
	var owned := p.has_pouch()
	var ready := p.rank("trinket") >= ItemDefs.POUCH_RANK
	var c := CampUi.card(owned, UiPalette.GOLD) if (owned or ready) else CampUi.locked_card()
	if owned and _seen_ranks.has("pouch") and int(_seen_ranks.pouch) == 0:
		_flash(c, "NEW SLOT!")
	var v := UiTheme.vbox(6)
	c.add_child(v)
	var row := UiTheme.hbox(12)
	v.add_child(row)
	var tr := CampUi.title_row("pouch", UiPalette.GOLD if (owned or ready) else UiPalette.TEXT_MUTED, "Belt Pouch",
		"A 2ND TRINKET, ONE TIER LOWER" if not owned else "OWNED  ·  2ND TRINKET SLOT", 56)
	tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tr)
	if owned:
		row.add_child(CampUi.chip("OWNED", UiPalette.HEAL.darkened(0.35), UiPalette.TEXT, 16))
	elif ready:
		var cost := {"crowns": ItemDefs.POUCH_COST}
		var b := CampUi.buy_button("BUY", cost, p.can_afford(cost), 20)
		b.min_height = 64
		b.pressed.connect(cmd.bind(["buy_pouch"]))
		row.add_child(b)
	else:
		v.add_child(CampUi.lock_line("Needs Trinket rank %d (now %d)." % [ItemDefs.POUCH_RANK, p.rank("trinket")], 16))
	return c


# ================================================================ widgets

## A card that just changed (rank up, pouch): it pops and a gold tag rises off it.
func _flash(c: Control, text: String) -> void:
	var tag := UiTheme.label(text, 26, UiPalette.GOLD_BRIGHT, true, 6)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child.call_deferred(tag)
	(func() -> void:
		if not is_instance_valid(c) or not c.is_inside_tree():
			return
		await c.get_tree().process_frame
		if not is_instance_valid(tag):
			return
		tag.top_level = true
		tag.z_index = 5
		tag.reset_size()
		tag.global_position = c.get_global_rect().get_center() - tag.size * 0.5 + Vector2(40, -10)
		UiTheme.pop(c, 1.05, 0.3)
		var t := tag.create_tween()
		t.tween_property(tag, "global_position:y", tag.global_position.y - 40.0, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(tag, "modulate:a", 0.0, 0.5).set_delay(1.4)
		t.tween_callback(tag.queue_free)).call_deferred()


## A tappable panel (fires on release inside, with the click sound and a pop).
class _Tap:
	extends PanelContainer
	signal pressed
	var _down := false
	var _at := Vector2.ZERO

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_down = true
			_at = mb.global_position
		elif _down:
			_down = false
			if get_global_rect().has_point(mb.global_position) and mb.global_position.distance_to(_at) < 24.0:
				UiTheme.sfx("click")
				UiTheme.pop(self, 1.03, 0.15)
				pressed.emit()


## A small green "equipped" dot.
class _EqDot:
	extends Control
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.5
		draw_circle(size * 0.5, r, UiPalette.OUTLINE)
		draw_circle(size * 0.5, r - 2.0, UiPalette.HEAL)
