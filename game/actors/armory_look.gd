class_name ArmoryLook
extends RefCounted
## The hero wearing what the Armory has equipped (docs/design/2026-09-29-armory-items.md §8):
## turns a Profile loadout (or a run's meta.look) plus the Appearance choice into a Character
## loadout for HeroLook.create / Character.equip.
##
##   var lo := ArmoryLook.of_profile(profile, "knight")          # the Armory turntable, Camp
##   var hero := HeroLook.create("knight", skin, prestige, lo)
##   var lo2 := ArmoryLook.of_meta(run.meta, run.class_id, run.skin, run.skin_prestige)
##
## Appearance (Profile.appearance_of): head = item | "own" | "hidden", body = item | "own".
## "own" is the class's own look. While the class wears its own kit piece that is exactly the kit
## look (HeroLook.loadout: the Paladin's helmet-less head, the Rogue's bare face, a helmet skin).
## Item ids show that piece (transmog); stats always come from the equipped item.

## The class's kit piece in a slot ("" = none).
static func kit_piece(class_id: String, slot: String) -> String:
	var k: Dictionary = ItemDefs.KITS.get(class_id, {})
	var e: Variant = k.get(slot, "")
	return String(e[0]) if e is Array else String(e)


## The ItemMounts id shown for an equipped item: its variant (the Standard is the item id); the
## Knight's Standard Round Shield wears its badge look.
static func shown_id(class_id: String, id: String, variant := "") -> String:
	if id == "":
		return ""
	var v := variant if variant != "" else id
	if class_id == "knight" and v == "round_shield":
		return "round_shield_badge"
	return v


## Character loadout for `class_id` from a profile (equipped items + appearance) in `skin`.
static func of_profile(p: Profile, class_id: String, skin := "", prestige := false) -> Dictionary:
	if p == null:
		return HeroLook.loadout(class_id, skin, prestige)
	var s := skin if skin != "" else p.equipped_skin(class_id)
	return build(class_id, p.loadout_for(class_id), p.appearance_of(class_id), s, prestige)


## Character loadout for a run: meta.look (the full worn loadout) when present, else the active
## items + back (older saves).
static func of_meta(meta: Dictionary, class_id: String, skin := "", prestige := false) -> Dictionary:
	if meta.is_empty():
		return HeroLook.loadout(class_id, skin, prestige)
	var lo: Dictionary = meta.get("look", {})
	if lo.is_empty():
		var its: Dictionary = meta.get("items", {})
		lo = {"back": String(meta.get("back", ""))}
		for slot in ItemDefs.STAT_SLOTS:
			var e: Dictionary = its.get(slot, {})
			var id := String(e.get("id", ""))
			if slot in ["weapon", "offhand", "head"]:
				lo[slot] = {"id": id, "variant": String(e.get("variant", id))}
			else:
				lo[slot] = id
		if not its.has("head"):
			lo["head"] = {"id": kit_piece(class_id, "head"), "variant": kit_piece(class_id, "head")}
		if not its.has("body"):
			lo["body"] = kit_piece(class_id, "body")
	return build(class_id, lo, meta.get("appearance", {}), skin, prestige)


## A Profile-shaped loadout ({weapon: {id, variant}, offhand, head, body, trinket, trinket2, back})
## + appearance -> Character loadout, on top of the class's HeroLook look (model, skin, prestige).
static func build(class_id: String, lo: Dictionary, ap: Dictionary, skin := "", prestige := false) -> Dictionary:
	var out := HeroLook.loadout(class_id, skin, prestige)
	# the Chieftain is a Rig_Large body swap with its own axe: no Medium-rig items
	if String(out.get("model", "")) == "barbarian_large":
		return out
	var kit_ap: Dictionary = out.get("appearance", {})
	var look := {}
	for slot in ["weapon", "offhand", "head"]:
		var e: Variant = lo.get(slot, {})
		var id := String(e.get("id", "")) if e is Dictionary else String(e)
		var v := String(e.get("variant", id)) if e is Dictionary else id
		out[slot] = shown_id(class_id, id, v)
	for slot in ["body", "back", "trinket", "trinket2"]:
		out[slot] = String(lo.get(slot, ""))
	if String(ItemDefs.LOCKED_ARMOR.get(class_id, "")) != "":
		out.erase("head")
	# head: "own" is the kit look while the kit piece is worn, else the class's own parts
	var head_ap := String(ap.get("head", "own"))
	var head_id := _id_of(lo.get("head", {}))
	var head_default := String((ItemDefs.APPEARANCE_DEFAULT.get(class_id, {}) as Dictionary).get("head", "own"))
	var kit_head := head_id != "" and head_id == kit_piece(class_id, "head")
	if kit_head and (head_ap == "own" or head_ap == head_default):
		if kit_ap.has("head"):
			look["head"] = String(kit_ap.head)
	elif head_ap == "own":
		look["head"] = "own"
	elif head_ap == "hidden":
		look["head"] = "hidden"
	elif ItemDefs.fits(head_ap, "head"):
		look["head"] = head_ap
	var body_ap := String(ap.get("body", "own"))
	var body_id := String(lo.get("body", ""))
	if body_ap == "own":
		if body_id == "" or body_id != kit_piece(class_id, "body"):
			look["body"] = "own"
	elif ItemDefs.fits(body_ap, "body"):
		look["body"] = body_ap
	if not look.is_empty():
		out["appearance"] = look
	elif out.has("appearance"):
		out.erase("appearance")
	# a prestige Shade hood keeps its own head
	if prestige and String(SkinDefs.def(class_id, "prestige").get("overlay", "")) == "shade":
		out.erase("head")
		(out.get("appearance", {}) as Dictionary).erase("head")
	return out


static func _id_of(e: Variant) -> String:
	return String(e.get("id", "")) if e is Dictionary else String(e)


## The id the head / body currently *shows* for a class ("" = nothing shown or the own look):
## what the Armory's Appearance row marks as worn.
static func shown_look(p: Profile, class_id: String, slot: String) -> String:
	var ap := String(p.appearance_of(class_id).get(slot, "own"))
	var lo := p.loadout_for(class_id)
	var eq := _id_of(lo.get(slot, ""))
	if ap == "own":
		return "own" if eq == "" or eq != kit_piece(class_id, slot) else eq
	return ap


## What an item effect's value counts (the callout reads "+3 Block", "+2 HP", "+5 gold").
const CALLOUT_UNITS := {
	"block": ["bulwark", "plated", "aegis", "thick_hide", "guarded", "guard", "standard", "steadfast", "rally", "wall"],
	"hp": ["reap", "vow", "blessed", "poise", "patchwork", "radiant", "bloom", "bark", "grave_magic"],
	"gold": ["gilded", "treasury_step", "cashout", "thrift"],
}


## The in-run callout of an item_triggered event: the rule's name (or the variant's secondary)
## and its amount ("Twin Edge +3", "Bulwark +5 Block", "Dominion ×2", "Ambush ready").
static func callout_text(ev: Dictionary) -> String:
	var id := String(ev.get("id", ""))
	var v := String(ev.get("variant", id))
	var eff := String(ev.get("effect", ""))
	var val := int(ev.get("value", 0))
	var rule: Dictionary = ItemDefs.def(id).get("effect", {})
	var nm := ""
	if String(rule.get("rule", "")) == eff:
		nm = String(rule.get("name", ""))
	elif ItemDefs.VARIANTS.has(v) and ItemDefs.sec_of(v) == eff:
		nm = String(ItemDefs.VARIANTS[v].get("sec_name", ""))
	elif eff == "standard":
		nm = ItemDefs.name_of(id)
	elif eff == "ambush_ready":
		return "Ambush ready"
	elif eff.ends_with("_stack"):
		var base_eff := eff.trim_suffix("_stack")
		nm = String(rule.get("name", "")) if String(rule.get("rule", "")) == base_eff else base_eff.capitalize()
		var stacks := int(ev.get("stacks", val))
		return "%s ×%d" % [nm, stacks] if stacks > 0 else nm
	else:
		nm = eff.capitalize()
	if nm == "":
		nm = ItemDefs.name_of(id)
	if val <= 0:
		return nm
	for unit in CALLOUT_UNITS:
		if (CALLOUT_UNITS[unit] as Array).has(eff):
			match String(unit):
				"block": return "%s +%d Block" % [nm, val]
				"hp": return "%s +%d HP" % [nm, val]
				"gold": return "%s +%d gold" % [nm, val]
	return "%s +%d" % [nm, val]
