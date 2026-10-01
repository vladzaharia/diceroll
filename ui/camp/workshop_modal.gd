class_name WorkshopModal
extends CampModal
## Dice Workshop (review §5.2; Camp stations pass, docs/design/2026-10-01-camp-stations.md):
## unlock packs bought with Sigils (their runes, die kinds and passives join the drop pools),
## the pool toggles (at most 25% of each pool off), the Starter Kit (kind of the second
## starting die) and the Whetstone. Every pack is a StationCard of the same height: its
## contents are a Carousel of item tiles (tap one for its rule), so the 25-item Starter pack
## is no taller than a 4-item pack.

const POOLS := [["runes", "Runes"], ["kinds", "Die kinds"], ["passives", "Passives"]]
const POOL_ICON := {"runes": "rune_choice", "kinds": "dice", "passives": "trophy"}
const ACCENT := Color("7ad0ff")
## Item tiles: height and narrowest width (4 per page on a phone, 5 on a wide panel).
const TILE_H := 132.0
const TILE_W := 104.0

## Pack, pool and Starter Kit cards: one spec each (every pack card is the same height).
var pack_spec := _spec(true)
var pool_spec := _pool_spec()
var kit_spec := _spec(true)
var whet_spec := _whet_spec()


func _build() -> void:
	set_title("DICE WORKSHOP", PLAQUE_DEFAULT)


static func _carousel_h() -> float:
	# the strip only: its indicator row (arrows, dots) sits in the card's footer
	return TILE_H


static func _spec(with_footer: bool) -> StationCard.Spec:
	var s := StationCard.Spec.new()
	s.contents_h = _carousel_h()
	s.footer_h = 88.0 if with_footer else 0.0
	return s


static func _pool_spec() -> StationCard.Spec:
	var s := StationCard.Spec.new()
	s.contents_h = _carousel_h()
	s.footer_h = 88.0
	return s


static func _whet_spec() -> StationCard.Spec:
	var s := StationCard.Spec.new()
	s.contents_h = 0.0
	s.footer_h = 48.0
	return s


func rebuild(p: Profile) -> void:
	fit_columns()
	body.add_child(CampModal.heading("Unlock packs", "Each pack adds its runes, dice and passives to what you find. Tap an item for its rule."))
	var packs := card_grid()
	body.add_child(packs)
	for id in UnlockDefs.PACK_IDS:
		packs.add_child(pack_card(p, String(id)))
	body.add_child(CampModal.heading("Drop pools", "Tap to switch an item off: up to 25% of each pool, to steer what you find."))
	var pools := card_grid()
	body.add_child(pools)
	for pool in POOLS:
		pools.add_child(_pool_card(p, String(pool[0]), String(pool[1])))
	body.add_child(CampModal.heading("Starting kit"))
	var kit := card_grid()
	body.add_child(kit)
	kit.add_child(_starter_card(p))
	kit.add_child(_whetstone_card(p))


# ---------------------------------------------------------------- packs

## One pack: medallion, name, its build idea, what it adds (pills), its items (carousel),
## OWNED or UNLOCK [sigil] N, and how it unlocks / what of it is switched off.
func pack_card(p: Profile, id: String) -> StationCard:
	var d: Dictionary = UnlockDefs.PACKS[id]
	var owned := p.owns("packs", id)
	var c := StationCard.make(pack_spec, String(CampInfo.PACK_ICON.get(id, "pack")), ACCENT, String(d.name),
		String(CampInfo.PACK_BLURB.get(id, "")), "normal" if owned else "locked")
	c.name = "Pack_" + id
	var nr := (d.runes as Array).size()
	var nk := (d.kinds as Array).size()
	var np := (d.passives as Array).size()
	if nr > 0:
		c.add_pill(String(POOL_ICON.runes), _count(nr, "RUNE", "RUNES"))
	if nk > 0:
		c.add_pill(String(POOL_ICON.kinds), _count(nk, "DIE", "DICE"))
	if np > 0:
		c.add_pill(String(POOL_ICON.passives), _count(np, "PASSIVE", "PASSIVES"))
	if owned:
		c.set_state("OWNED", "green", "check")
	else:
		var cost := UnlockDefs.sigil_cost("packs", id)
		var b := CampUi.buy_button("UNLOCK", cost, p.can_afford(cost), 22)
		b.name = "Unlock"
		b.pressed.connect(cmd.bind(["unlock", "packs", id]))
		c.set_action(b)
	# contents: every item as a tile; a switched-off item says OFF
	var tiles: Array = []
	var off_n := 0
	for pool in ["runes", "kinds", "passives"]:
		var off: Array = p.disabled.get(pool, [])
		for item in d[pool]:
			var is_off := owned and off.has(item)
			if is_off:
				off_n += 1
			tiles.append(_item_tile(String(pool), String(item), "dim" if not owned else "normal", is_off))
	var car := Carousel.make(tiles, TILE_H, TILE_W, "workshop:pack:" + id)
	car.count_text = _count(tiles.size(), "ITEM", "ITEMS")
	car.page_changed.connect(func(_pg: int) -> void: hide_tip())
	c.set_carousel(car)
	# footer: in the drops (and what is off), or how to unlock it
	if owned:
		c.set_status("In your drops" + ("  ·  %d switched off" % off_n if off_n > 0 else ""), "check", UiPalette.HEAL)
	else:
		var m := CampInfo.milestone_for("packs", id)
		if m.is_empty():
			c.set_status("Unlock it with Sigils.", "lock", UiPalette.TEXT_DIM)
		else:
			var pr := CampInfo.progress(p, m.cond)
			var prog := "  (%d/%d)" % [int(pr[0]), int(pr[1])] if int(pr[1]) > 1 else ""
			c.set_status(String(m.desc) + prog, "lock", UiPalette.TEXT_DIM)
	return c


static func _count(n: int, one: String, many: String) -> String:
	return "%d %s" % [n, one if n == 1 else many]


## A drop-pool entry as display data: {name, tag, desc, color, detail, detail_color, icon}.
static func drop_info(pool: String, id: String) -> Dictionary:
	match pool:
		"runes":
			var r: Dictionary = Runes.DEFS[id]
			var rar := String(r.rarity)
			return {"name": "%s Rune" % String(r.name), "tag": "RUNE  ·  " + rar.to_upper(), "desc": String(r.desc),
				"color": UiPalette.rune_color(id), "detail": rar.to_upper(), "detail_color": UiPalette.rarity_color(rar),
				"icon": UiIcons.rune_icon(id)}
		"kinds":
			var k: Dictionary = DiceKinds.def(id)
			var rar := String(k.rarity)
			return {"name": DiceKinds.label(id), "tag": "DIE  ·  " + rar.to_upper(), "desc": String(k.desc),
				"color": UiPalette.kind_color(id), "detail": rar.to_upper(), "detail_color": UiPalette.rarity_color(rar),
				"icon": "kind_" + id}
		"passives":
			var rar := Passives.rarity(id)
			var pd: Dictionary = Passives.DEFS.get(id, {})
			return {"name": String(pd.get("name", id)), "tag": "PASSIVE  ·  " + rar.to_upper(), "desc": String(pd.get("desc", "")),
				"color": UiPalette.passive_color(rar), "detail": rar.to_upper(), "detail_color": UiPalette.passive_color(rar),
				"icon": PassiveIcon.glyph(id)}
	return {"name": id, "tag": "", "desc": "", "color": UiPalette.GOLD, "detail": "", "detail_color": UiPalette.TEXT_MUTED, "icon": ""}


## The tile's picture: the rune / passive icon, or a die kind's six faces.
static func item_visual(pool: String, id: String, dim := false) -> Control:
	var v: Control
	match pool:
		"kinds":
			var g := GridContainer.new()
			g.columns = 3
			g.add_theme_constant_override("h_separation", 3)
			g.add_theme_constant_override("v_separation", 3)
			g.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for f in DiceKinds.faces(id):
				var face := DieFace.make(int(f), "", false, 21)
				face.kind = id
				face.mouse_filter = Control.MOUSE_FILTER_IGNORE
				g.add_child(face)
			v = g
		"passives":
			v = PassiveIcon.make(id, 44)
		_:
			v = CampArt.icon(UiIcons.rune_icon(id), 44, UiPalette.rune_color(id))
	if dim:
		v.modulate = Color(0.7, 0.7, 0.8, 0.85)
	return v


func _item_tile(pool: String, id: String, state: String, is_off: bool) -> Carousel.ItemTile:
	var info := drop_info(pool, id)
	var detail := "OFF" if is_off else String(info.detail)
	var dcol: Color = UiPalette.HP_BRIGHT if is_off else info.detail_color
	var t := Carousel.ItemTile.make(item_visual(pool, id, state == "dim" or is_off), String(info.name), detail, dcol, null,
		"dim" if is_off else state)
	t.name = "Item_" + id
	t.pressed.connect(func() -> void:
		show_tip(t, String(info.name), String(info.tag), String(info.desc) + ("\nSwitched off in the drop pools." if is_off else ""),
			info.color, String(info.icon)))
	return t


# ---------------------------------------------------------------- drop pools

func _pool_card(p: Profile, kind: String, label: String) -> StationCard:
	var owned := UnlockDefs.pool_from_packs(p.unlocks.get("packs", []), kind)
	var off: Array = p.disabled.get(kind, [])
	var cap := int(floor(owned.size() * UnlockDefs.POOL_TOGGLE_MAX))
	var desc := "Switch off up to %d to see the rest more often." % cap if cap > 0 else "Every %s you own is in the drops." % label.to_lower().trim_suffix("s")
	var c := StationCard.make(pool_spec, String(POOL_ICON[kind]), ACCENT, label, desc)
	c.name = "Pool_" + kind
	c.add_pill("check", "%d IN POOL" % (owned.size() - off.size()), "grey")
	c.add_pill("", "%d/%d OFF" % [off.size(), cap], "red" if off.size() >= cap and cap > 0 else "grey")
	var tiles: Array = []
	for id in owned:
		var sid := String(id)
		var is_off := off.has(sid)
		var can := is_off or off.size() < cap
		var info := drop_info(kind, sid)
		var t := Carousel.ItemTile.make(item_visual(kind, sid, is_off), String(info.name), "OFF" if is_off else "ON",
			UiPalette.HP_BRIGHT if is_off else UiPalette.HEAL, null, "dim" if is_off else "normal")
		t.name = "Toggle_" + sid
		if not can:
			t.modulate = Color(1, 1, 1, 0.6)
			t.mouse_default_cursor_shape = Control.CURSOR_ARROW
		t.pressed.connect(func() -> void:
			if can:
				cmd(["toggle_pool", kind, sid, is_off])
			else:
				UiTheme.sfx("error")
				show_tip(t, String(info.name), "POOL FULL", "Up to %d %s can be off. Switch one back on first." % [cap, label.to_lower()],
					UiPalette.HP_BRIGHT, String(info.icon)))
		tiles.append(t)
	var car := Carousel.make(tiles, TILE_H, TILE_W, "workshop:pool:" + kind)
	car.count_text = "%d ITEMS" % owned.size()
	car.page_changed.connect(func(_pg: int) -> void: hide_tip())
	c.set_carousel(car)
	if cap > 0:
		c.set_status("Tap an item to switch it off or on.", "info", UiPalette.TEXT_DIM)
	else:
		c.set_status("Unlock more packs to switch these off.", "lock", UiPalette.TEXT_DIM)
	return c


# ---------------------------------------------------------------- starting kit

func _starter_card(p: Profile) -> StationCard:
	var d := UnlockDefs.upgrade_def("workshop", "starter_kit")
	var owned := int(p.upgrades.get("starter_kit", 0)) >= 1
	var c := StationCard.make(kit_spec, "upgrade_starter_kit", ACCENT, String(d.name), String(d.desc))
	c.name = "StarterKit"
	var cur := p.starter_kind if p.starter_kind != "" else "standard"
	c.add_pill("dice", "SECOND STARTING DIE")
	if owned:
		c.set_state("OWNED", "green", "check")
	else:
		var b := CampUi.buy_button("BUY", d.cost, p.can_afford(d.cost), 22)
		b.pressed.connect(cmd.bind(["buy_upgrade", "workshop", "starter_kit"]))
		c.set_action(b)
	var tiles: Array = []
	for k in UnlockDefs.starter_kinds(p.pool("kinds")):
		var kid := String(k)
		var sel := owned and cur == kid
		var info := drop_info("kinds", kid)
		var t := Carousel.ItemTile.make(item_visual("kinds", kid, not owned), String(info.name), "IN USE" if sel else ("PICK" if owned else ""),
			UiPalette.GOLD_BRIGHT if sel else UiPalette.TEXT_MUTED, null, "selected" if sel else ("normal" if owned else "dim"))
		t.name = "Kind_" + kid
		t.pressed.connect(func() -> void:
			if owned and not sel:
				cmd(["set_starter_kind", kid])
			else:
				show_tip(t, String(info.name), String(info.tag), String(info.desc), info.color, String(info.icon)))
		tiles.append(t)
	var car := Carousel.make(tiles, TILE_H, TILE_W, "workshop:kit")
	car.count_text = _count(tiles.size(), "KIND", "KINDS")
	car.page_changed.connect(func(_pg: int) -> void: hide_tip())
	c.set_carousel(car)
	if owned:
		c.set_status("Your second die starts as a %s." % DiceKinds.label(cur), "dice", UiPalette.TEXT_DIM)
	else:
		c.set_status("Buy it to pick the kind. Packs add more kinds.", "lock", UiPalette.TEXT_DIM)
	return c


func _whetstone_card(p: Profile) -> StationCard:
	var d := UnlockDefs.upgrade_def("workshop", "whetstone")
	var owned := int(p.upgrades.get("whetstone", 0)) >= 1
	var c := StationCard.make(whet_spec, "upgrade_whetstone", ACCENT, String(d.name), String(d.desc))
	c.name = "Whetstone"
	c.add_pill("upgrade_whetstone", "1 FACE RAISE PER RUN")
	if owned:
		c.set_state("OWNED", "green", "check")
		c.set_status("Every run starts with a free Face Raise.", "check", UiPalette.HEAL)
	else:
		var b := CampUi.buy_button("BUY", d.cost, p.can_afford(d.cost), 22)
		b.pressed.connect(cmd.bind(["buy_upgrade", "workshop", "whetstone"]))
		c.set_action(b)
		var short := int((d.cost as Dictionary).get("crowns", 0)) - p.crowns
		c.set_status("%d Crowns to go." % short if short > 0 else "Ready to buy.", "crown" if short > 0 else "check",
			UiPalette.TEXT_DIM if short > 0 else UiPalette.HEAL)
	return c
