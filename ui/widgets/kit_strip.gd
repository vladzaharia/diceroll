class_name KitStrip
extends HFlowContainer
## A row of a class's Armory items as small 3D thumbnails with their tier (run setup, class
## select, pause): weapon, off-hand, head, body, trinkets, back.
##
##   body.add_child(KitStrip.of_profile(profile, "knight"))
##   body.add_child(KitStrip.of_run(flow.run))
##   body.add_child(KitStrip.of_kit("mage"))            # the signature kit (no profile)

const ORDER := ["weapon", "offhand", "head", "body", "trinket", "trinket2", "back"]
const TIER_NAMES := ["", "I", "II", "III"]
const TIER_COLORS := [Color("7d7896"), Color("c9d2e4"), Color("6fb8ff"), Color("ffc24a")]

## Entries shown: [{slot, id (base item), shown (ItemMounts id), tier, name}].
var entries: Array = []


## The class's equipped items in a profile, with this class's tiers.
static func of_profile(p: Profile, class_id: String, px := 56) -> KitStrip:
	var lo := p.loadout_for(class_id)
	var out: Array = []
	for slot in ORDER:
		var e: Variant = lo.get(slot, "")
		var id := String(e.get("id", "")) if e is Dictionary else String(e)
		var v := String(e.get("variant", id)) if e is Dictionary else id
		if id == "":
			continue
		var t := ItemDefs.tier_for(id, slot, class_id, p.rank(String(ItemDefs.GROUP_OF.get(slot, "weapon")))) if slot != "back" else 0
		out.append({"slot": slot, "id": id, "shown": ArmoryLook.shown_id(class_id, id, v), "tier": t, "name": ItemDefs.name_of(v)})
	return make(out, px)


## A run's worn items (meta.look) with the run's tiers (meta.items; 0 = inactive).
static func of_run(run: RunState, px := 56) -> KitStrip:
	var its: Dictionary = run.meta.get("items", {})
	var lo: Dictionary = run.meta.get("look", {})
	var out: Array = []
	for slot in ORDER:
		var id := ""
		var v := ""
		if lo.has(slot):
			var e: Variant = lo[slot]
			id = String(e.get("id", "")) if e is Dictionary else String(e)
			v = String(e.get("variant", id)) if e is Dictionary else id
		elif its.has(slot):
			id = String(its[slot].id)
			v = String(its[slot].get("variant", id))
		elif slot == "back":
			id = String(run.meta.get("back", ""))
			v = id
		if id == "":
			continue
		var t := int((its.get(slot, {}) as Dictionary).get("tier", 0))
		out.append({"slot": slot, "id": id, "shown": ArmoryLook.shown_id(run.class_id, id, v), "tier": t, "name": ItemDefs.name_of(v)})
	return make(out, px)


## A class's signature kit (no profile: every piece, no tiers).
static func of_kit(class_id: String, px := 56) -> KitStrip:
	var k: Dictionary = ItemDefs.KITS.get(class_id, {})
	var out: Array = []
	for slot in ["weapon", "offhand", "head", "body", "back"]:
		var e: Variant = k.get(slot, "")
		var id := String(e[0]) if e is Array else String(e)
		var v := String(e[1]) if e is Array else id
		if id != "":
			out.append({"slot": slot, "id": id, "shown": ArmoryLook.shown_id(class_id, id, v), "tier": 0, "name": ItemDefs.name_of(v)})
	return make(out, px)


static func make(p_entries: Array, px := 56) -> KitStrip:
	var s := KitStrip.new()
	s.entries = p_entries
	s.alignment = FlowContainer.ALIGNMENT_CENTER
	s.add_theme_constant_override("h_separation", 6)
	s.add_theme_constant_override("v_separation", 6)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for e in p_entries:
		s.add_child(_cell(e, px))
	return s


## Names of the entries ("Arming Sword · Round Shield · ...").
func names_text() -> String:
	var n := PackedStringArray()
	for e in entries:
		n.append(String(e.name))
	return "  ·  ".join(n)


static func _cell(e: Dictionary, px: int) -> Control:
	var well := PanelContainer.new()
	# the round well behind a 3D thumbnail (plan d `well`; flat fallback without the pack)
	var sb := UiTheme.well_box() if UiTheme.skinned("well") else UiTheme.box(Color(0.02, 0.02, 0.07, 0.75), 14, 2, Color(1, 1, 1, 0.08))
	UiTheme.pad(sb, 2, 2)
	well.add_theme_stylebox_override("panel", sb)
	well.mouse_filter = Control.MOUSE_FILTER_PASS
	well.tooltip_text = String(e.name)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(px, px)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_child(holder)
	var th := ItemThumb.make(String(e.shown), px, "trinket" if String(e.slot) == "trinket2" else String(e.slot))
	th.size = Vector2(px, px)
	holder.add_child(th)
	var t := int(e.tier)
	if t > 0:
		# the Armory's tier badge (bronze / silver / gold star + numeral), inside the cell's
		# bottom-right corner (spec 3.1: nothing hangs off a corner)
		var b := CampArt.tier_badge(t, 14)
		holder.add_child(b)
		# anchored to the corner, growing up / left: stays inside however wide the badge is
		b.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE)
		b.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		b.grow_vertical = Control.GROW_DIRECTION_BEGIN
	return well
