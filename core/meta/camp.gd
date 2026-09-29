class_name Camp
extends RefCounted
## Meta commands over a Profile, in the same command -> events style as GameFlow. Illegal or
## unaffordable commands return [{type:"error", msg}] and change nothing.
##
## Commands (see apply() for the replay format):
##   buy_upgrade(track, id)     Crowns upgrades: workshop whetstone|starter_kit, armory
##                              potion_belt, arcade loadout_slot (UnlockDefs.UPGRADES)
##   rank_up(group)             Armory: raise a rank group weapon|offhand|armor|trinket R0..8
##                              (Crowns, ItemDefs.RANK_COSTS; the group must be unlocked)
##   buy_pouch()                Armory: the Belt Pouch (2nd trinket slot), 400 Crowns, Trinket R5+
##   buy_item(id, currency)     Armory shop: an item for Crowns ("crowns") or Sigils ("sigils")
##   craft_variant(item, variant, currency)  craft an unlocked blueprint (Crowns or 2 Sigils)
##   equip_item(class, slot, id, variant)    equip an owned item / variant ("" empties the slot)
##   unequip_item(class, slot)  = equip_item(class, slot, "")
##   set_appearance(class, slot, value)      head: item|"own"|"hidden", body: item|"own"
##   mark_items_seen()          Armory: clears the "new" dots
##   level_gear(slot)           legacy alias: helm|blade|boots|charm -> rank_up(armor|weapon|offhand|trinket)
##   set_trait(slot, tier, id)  legacy: always an error (the traits are item rules now)
##   level_pet(id)              Pet Den: buy levels 6..10 (Crowns) once XP reached level 5
##   unlock(kind, id)           Spend Sigils to unlock early (classes, biomes, bosses,
##                              minibosses, pets, minigames, packs, gear, potions)
##   toggle_pool(kind, id, on)  Workshop pool toggle (runes|kinds|passives), <= 25% off
##   set_starter_kind(kind)     Workshop Starter Kit: kind of the 2nd starting die
##   set_loadout(minigames, pet)  up to loadout_slots() owned minigames, one owned pet or ""
##   set_class(id) / set_mode("standard"|"short") / set_ascension(n)
##   bank_run(stats)            banks a finished run (game_over.stats)
##   equip_skin(class, skin)    Wardrobe: equip an owned skin (free; prestige is a toggle)
##   buy_skin(class, skin)      Wardrobe: buy a non-prestige skin for SkinDefs.BUY_PRICE Crowns
##                              once every Crowns sink is maxed (Profile.crowns_capped())
##   set_prestige(class, on)    Wardrobe: show / hide the owned A10 prestige overlay
##   mark_skins_seen(class)     Wardrobe: clears the "new" dots of a class ("" = all)
##
## Events: crowns_changed {amount, total} · sigils_changed {amount, total} ·
##   upgrade_bought {track: "workshop"|"armory"|"arcade"|"pet_den", id, level} ·
##   trait_set {slot, tier, id} · unlocked {kind, id, source: "sigils"|"milestone"} ·
##   pool_toggled {kind, id, enabled} · starter_kind_set {kind} ·
##   loadout_changed {class, mode, minigames, pet} · ascension_changed {selected, unlocked} ·
##   milestone {id, desc, unlocks} · first {kind, id, sigils} · run_banked {crowns, sigils,
##   milestones, unlocked, ascension_unlocked, skins_unlocked} · skin_unlocked {class, skin,
##   source: "record"|"crowns"} · skin_equipped {class, skin} · prestige_set {class, on} ·
##   skins_seen {class} · error {msg}
## Armory: upgrade_bought {track: "armory", id: group | "pouch", level} · item_unlocked {id,
##   source: "crowns"|"sigils"|"milestone"|"feat"|"class"} · variant_crafted {item, variant,
##   source: "crowns"|"sigils"} · blueprint_unlocked {item, variant, source: "mastery"|"feat"} ·
##   item_equipped {class, slot, id, variant, loadout} · appearance_set {class, slot, value} ·
##   mastery_changed {item, fights, next} · items_seen {}

var profile: Profile

func _init(p: Profile = null) -> void:
	profile = p if p != null else Profile.fresh()

# ------------------------------------------------------------------ commands

func buy_upgrade(track: String, id: String) -> Array[Dictionary]:
	var d := UnlockDefs.upgrade_def(track, id)
	if d.is_empty():
		return _err("unknown upgrade %s/%s" % [track, id])
	if int(profile.upgrades.get(id, 0)) >= 1:
		return _err("already bought")
	if d.has("requires") and not profile.owns("features", String(d.requires)):
		return _err("not unlocked yet")
	var cost: Dictionary = d.cost
	if not profile.can_afford(cost):
		return _err("not enough Crowns")
	var ev := _pay(cost)
	profile.upgrades[id] = 1
	ev.append({"type": "upgrade_bought", "track": track, "id": id, "level": 1})
	return ev

## Legacy alias (the old Armory UI): an old gear piece levels its rank group.
func level_gear(slot: String) -> Array[Dictionary]:
	if not ItemDefs.LEGACY_GROUP.has(slot) and not ItemDefs.GROUPS.has(slot):
		return _err("unknown gear slot " + slot)
	return rank_up(String(ItemDefs.LEGACY_GROUP.get(slot, slot)))

func set_trait(_slot: String, _tier: String, _id: String) -> Array[Dictionary]:
	return _err("gear traits are item rules now: equip the item that carries it")

# ------------------------------------------------------------------ Armory

func rank_up(group: String) -> Array[Dictionary]:
	if not ItemDefs.GROUPS.has(group):
		return _err("unknown rank group " + group)
	if not profile.owns("gear", group):
		return _err("rank not unlocked yet")
	var r := profile.rank(group)
	var cost := ItemDefs.rank_cost(r)
	if cost.is_empty():
		return _err("already at max rank")
	if not profile.can_afford(cost):
		return _err("not enough Crowns")
	var ev := _pay(cost)
	profile._ranks()[group] = r + 1
	ev.append({"type": "upgrade_bought", "track": "armory", "id": group, "level": r + 1})
	return ev

func buy_pouch() -> Array[Dictionary]:
	if profile.has_pouch():
		return _err("already bought")
	if profile.rank("trinket") < ItemDefs.POUCH_RANK:
		return _err("needs Trinket rank %d" % ItemDefs.POUCH_RANK)
	var cost := {"crowns": ItemDefs.POUCH_COST}
	if not profile.can_afford(cost):
		return _err("not enough Crowns")
	var ev := _pay(cost)
	profile.armory["pouch"] = 1
	ev.append({"type": "upgrade_bought", "track": "armory", "id": "pouch", "level": 1})
	return ev

func buy_item(id: String, currency := "crowns") -> Array[Dictionary]:
	if not ItemDefs.has(id):
		return _err("unknown item " + id)
	if profile.owns_item(id):
		return _err("already owned")
	var cost := ItemDefs.price(id, profile.unlocks.get("classes", []), currency == "sigils")
	if cost.is_empty():
		return _err("not for sale: " + id)
	if not profile.can_afford(cost):
		return _err("not enough %s" % ("Sigils" if currency == "sigils" else "Crowns"))
	var ev := _pay(cost)
	profile.grant_item(id)
	ev.append({"type": "item_unlocked", "id": id, "source": "sigils" if currency == "sigils" else "crowns"})
	return ev

func craft_variant(item: String, variant: String, currency := "crowns") -> Array[Dictionary]:
	if not ItemDefs.VARIANTS.has(variant) or not ItemDefs.is_variant_of(variant, item):
		return _err("unknown variant %s/%s" % [item, variant])
	if profile.owns_variant(item, variant):
		return _err("already crafted")
	if not profile.owns_item(item):
		return _err("own the %s first" % ItemDefs.name_of(item))
	if not profile.has_blueprint(item, variant):
		return _err("blueprint locked: " + ItemDefs.unlock_text(variant))
	var cost := ItemDefs.craft_cost(variant, currency == "sigils")
	if not profile.can_afford(cost):
		return _err("not enough %s" % ("Sigils" if currency == "sigils" else "Crowns"))
	var ev := _pay(cost)
	profile.grant_variant(item, variant)
	ev.append({"type": "variant_crafted", "item": item, "variant": variant, "source": "sigils" if currency == "sigils" else "crowns"})
	return ev

## Equips `id` (with `variant`, "" = its Standard) in `slot` for `class_id`; id "" empties it.
func equip_item(class_id: String, slot: String, id: String, variant := "") -> Array[Dictionary]:
	if not HeroDefs.DATA.has(class_id):
		return _err("unknown class " + class_id)
	if not ItemDefs.SLOTS.has(slot):
		return _err("unknown slot " + slot)
	var locked := String(ItemDefs.LOCKED_ARMOR.get(class_id, ""))
	if locked != "" and slot in ["head", "body"]:
		return _err("the %s is locked to this class" % ItemDefs.name_of(locked))
	if id != "":
		if not profile.owns_item(id):
			return _err("item not owned: " + id)
		if not ItemDefs.fits(id, slot):
			return _err("%s doesn't go in the %s slot" % [ItemDefs.name_of(id), slot])
		if String(ItemDefs.def(id).get("class_only", "")) not in ["", class_id]:
			return _err("%s is class-only" % ItemDefs.name_of(id))
		if variant == "":
			variant = id
		if not profile.owns_variant(id, variant):
			return _err("variant not crafted: " + variant)
		if slot == "trinket2" and not profile.has_pouch():
			return _err("buy the Belt Pouch first")
	var lo := profile.loadout_for(class_id)
	if slot in ["trinket", "trinket2"] and id != "":
		var other := "trinket2" if slot == "trinket" else "trinket"
		if String(lo[other]) == id:
			lo[other] = ""
	if slot in ["weapon", "offhand", "head"]:
		lo[slot] = {"id": id, "variant": variant if id != "" else ""}
	else:
		lo[slot] = id
	var w: Dictionary = lo.weapon
	if slot == "offhand" and id != "" and ItemDefs.hand_mount(id) and String(w.id) != "" and ItemDefs.hands(String(w.id), String(w.variant)) >= 2:
		return _err("a two-handed weapon leaves no hand for the %s" % ItemDefs.name_of(id))
	var eq: Dictionary = profile.armory.get("equipped", {})
	eq[class_id] = lo
	profile.armory["equipped"] = eq
	var now := profile.loadout_for(class_id)
	eq[class_id] = now
	return [{"type": "item_equipped", "class": class_id, "slot": slot, "id": id, "variant": variant if id != "" else "",
		"loadout": now.duplicate(true)}]

func unequip_item(class_id: String, slot: String) -> Array[Dictionary]:
	return equip_item(class_id, slot, "")

func set_appearance(class_id: String, slot: String, value: String) -> Array[Dictionary]:
	if not HeroDefs.DATA.has(class_id) or not (slot in ["head", "body"]):
		return _err("bad appearance slot")
	var ok := value == "own" or (value == "hidden" and slot == "head") or (profile.owns_item(value) and ItemDefs.fits(value, slot))
	if not ok:
		return _err("can't show %s there" % value)
	var ap: Dictionary = profile.armory.get("appearance", {})
	var row: Dictionary = ap.get(class_id, {})
	row[slot] = value
	ap[class_id] = row
	profile.armory["appearance"] = ap
	return [{"type": "appearance_set", "class": class_id, "slot": slot, "value": value}]

## The Armory's variant picker for an item: [{id, name, secondary, desc, state: "owned" | "craftable"
## | "locked", unlock (text), cost (craft cost, {} unless craftable), mastery: [fights, needed]
## (needed 0 = not a mastery blueprint)}], the Standard first.
func variant_chips(item: String) -> Array:
	var out: Array = []
	for v in ItemDefs.variants_of(item):
		var vid := String(v)
		var st := "owned" if profile.owns_variant(item, vid) else ("craftable" if profile.has_blueprint(item, vid) else "locked")
		var u: Dictionary = ItemDefs.VARIANTS.get(vid, {}).get("unlock", {})
		var need := int(u.get("mastery", u.get("or_mastery", 0)))
		out.append({"id": vid, "name": ItemDefs.name_of(vid), "secondary": ItemDefs.sec_of(vid),
			"desc": String(ItemDefs.VARIANTS.get(vid, {}).get("desc", ItemDefs.std_text(item))),
			"state": st, "unlock": ItemDefs.unlock_text(vid),
			"cost": ItemDefs.craft_cost(vid) if st == "craftable" else {},
			"mastery": [mini(profile.item_mastery(item), need), need]})
	return out

func mark_items_seen() -> Array[Dictionary]:
	profile.armory["seen_new"] = []
	return [{"type": "items_seen"}]

func level_pet(id: String) -> Array[Dictionary]:
	if not profile.owns("pets", id):
		return _err("pet not owned")
	var lvl := profile.pet_level(id)
	if lvl < PetDefs.XP_LEVEL_MAX:
		return _err("levels 1-5 come from fights won with the pet")
	var cost := PetDefs.level_cost(lvl)
	if cost.is_empty():
		return _err("already at max level")
	if not profile.can_afford(cost):
		return _err("not enough Crowns")
	var ev := _pay(cost)
	profile.pet_bought[id] = lvl + 1
	ev.append({"type": "upgrade_bought", "track": "pet_den", "id": id, "level": lvl + 1})
	return ev

func unlock(kind: String, id: String) -> Array[Dictionary]:
	if profile.owns(kind, id):
		return _err("already unlocked")
	var cost := UnlockDefs.sigil_cost(kind, id, profile.unlocks.get("classes", []))
	if cost.is_empty():
		return _err("can't be bought: %s/%s" % [kind, id])
	if not profile.can_afford(cost):
		return _err("not enough Sigils")
	var ev := _pay(cost)
	profile.grant(kind, id)
	ev.append({"type": "unlocked", "kind": kind, "id": id, "source": "sigils"})
	return ev

func toggle_pool(kind: String, id: String, enabled: bool) -> Array[Dictionary]:
	if not ["runes", "kinds", "passives"].has(kind):
		return _err("bad pool " + kind)
	var owned := UnlockDefs.pool_from_packs(profile.unlocks.packs, kind)
	if not owned.has(id):
		return _err("not unlocked")
	var off: Array = profile.disabled.get(kind, [])
	if enabled:
		off.erase(id)
	elif not off.has(id):
		if off.size() + 1 > int(floor(owned.size() * UnlockDefs.POOL_TOGGLE_MAX)):
			return _err("at most %d%% of a pool can be off" % int(UnlockDefs.POOL_TOGGLE_MAX * 100))
		off.append(id)
	profile.disabled[kind] = off
	return [{"type": "pool_toggled", "kind": kind, "id": id, "enabled": enabled}]

func set_starter_kind(kind: String) -> Array[Dictionary]:
	if int(profile.upgrades.get("starter_kit", 0)) < 1:
		return _err("buy the Starter Kit first")
	if kind != "" and not UnlockDefs.starter_kinds(profile.pool("kinds")).has(kind):
		return _err("pick an unlocked sidegrade kind (%s)" % ", ".join(UnlockDefs.STARTER_KINDS))
	profile.starter_kind = kind
	return [{"type": "starter_kind_set", "kind": kind}]

func set_loadout(minigames: Array, pet: String) -> Array[Dictionary]:
	if minigames.size() > profile.loadout_slots():
		return _err("only %d loadout slots" % profile.loadout_slots())
	var mg: Array = []
	for m in minigames:
		var id := String(m)
		if not profile.owns("minigames", id):
			return _err("minigame not unlocked: " + id)
		if mg.has(id):
			return _err("duplicate minigame " + id)
		mg.append(id)
	if pet != "" and not profile.owns("pets", pet):
		return _err("pet not owned: " + pet)
	profile.loadout.minigames = mg
	profile.loadout.pet = pet
	return [_loadout_ev()]

func set_class(id: String) -> Array[Dictionary]:
	if not HeroDefs.DATA.has(id) or not profile.class_allowed(id):
		return _err("class locked: " + id)
	profile.loadout["class"] = id
	return [_loadout_ev()]

func set_mode(mode: String) -> Array[Dictionary]:
	if mode != "standard" and mode != "short":
		return _err("bad mode " + mode)
	profile.loadout["mode"] = mode
	return [_loadout_ev()]

func set_ascension(n: int) -> Array[Dictionary]:
	if n < 0 or n > int(profile.ascension.get("unlocked", 0)):
		return _err("ascension %d is locked" % n)
	profile.ascension.selected = n
	return [{"type": "ascension_changed", "selected": n, "unlocked": int(profile.ascension.unlocked)}]

func bank_run(stats: Dictionary) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	var res := profile.apply_run_result(stats)
	if int(res.crowns) != 0:
		ev.append({"type": "crowns_changed", "amount": int(res.crowns), "total": profile.crowns})
	for f in res.firsts:
		ev.append({"type": "first", "kind": String(f[0]), "id": String(f[1]), "sigils": int(Economy.SIGIL_FIRST.get(f[0], 0))})
	if int(res.sigils) != 0:
		ev.append({"type": "sigils_changed", "amount": int(res.sigils), "total": profile.sigils})
	for m in res.milestones:
		var md := UnlockDefs.milestone(String(m))
		ev.append({"type": "milestone", "id": String(m), "desc": String(md.desc), "unlocks": (md.unlocks as Array).duplicate(true)})
	for u in res.unlocked:
		ev.append({"type": "unlocked", "kind": String(u[0]), "id": String(u[1]), "source": "milestone"})
	if int(res.ascension_unlocked) > 0:
		ev.append({"type": "ascension_changed", "selected": int(profile.ascension.selected), "unlocked": int(profile.ascension.unlocked)})
	for sk in res.skins_unlocked:
		ev.append({"type": "skin_unlocked", "class": String(sk[0]), "skin": String(sk[1]), "source": "record"})
	for item in res.get("mastery", {}):
		var fights := int(res.mastery[item])
		var nxt := 0
		for th in ItemDefs.MASTERY:
			if fights < int(th):
				nxt = int(th)
				break
		ev.append({"type": "mastery_changed", "item": String(item), "fights": fights, "next": nxt})
	for b in res.get("blueprints", []):
		ev.append({"type": "blueprint_unlocked", "item": String(b[0]), "variant": String(b[1]), "source": String(b[2])})
	for it in res.get("items_unlocked", []):
		ev.append({"type": "item_unlocked", "id": String(it[0]), "source": String(it[1])})
	ev.append({"type": "run_banked", "crowns": int(res.crowns), "sigils": int(res.sigils), "milestones": res.milestones,
		"unlocked": res.unlocked, "ascension_unlocked": int(res.ascension_unlocked), "skins_unlocked": res.skins_unlocked,
		"blueprints": res.get("blueprints", []), "items_unlocked": res.get("items_unlocked", [])})
	return ev

func equip_skin(class_id: String, skin: String) -> Array[Dictionary]:
	if not SkinDefs.has(class_id, skin):
		return _err("unknown skin %s/%s" % [class_id, skin])
	if SkinDefs.is_prestige(skin):
		return set_prestige(class_id, true)
	if not profile.owns_skin(class_id, skin):
		return _err("skin locked: " + SkinDefs.cond_text(class_id, skin))
	var eq: Dictionary = profile.cosmetics.get("equipped", {})
	eq[class_id] = skin
	profile.cosmetics["equipped"] = eq
	return [{"type": "skin_equipped", "class": class_id, "skin": skin}]

func buy_skin(class_id: String, skin: String) -> Array[Dictionary]:
	if not SkinDefs.has(class_id, skin):
		return _err("unknown skin %s/%s" % [class_id, skin])
	if profile.owns_skin(class_id, skin):
		return _err("already owned")
	if skin == "default" or SkinDefs.is_prestige(skin):
		return _err("the prestige skin can't be bought")
	if not profile.crowns_capped():
		return _err("skins are for sale once every Crowns upgrade is maxed")
	var cost := {"crowns": SkinDefs.BUY_PRICE}
	if not profile.can_afford(cost):
		return _err("not enough Crowns")
	var ev := _pay(cost)
	profile.grant_skin(class_id, skin)
	ev.append({"type": "skin_unlocked", "class": class_id, "skin": skin, "source": "crowns"})
	return ev

func set_prestige(class_id: String, on: bool) -> Array[Dictionary]:
	if not profile.owns_skin(class_id, "prestige"):
		return _err("skin locked: " + SkinDefs.cond_text(class_id, "prestige"))
	var pr: Dictionary = profile.cosmetics.get("prestige", {})
	pr[class_id] = on
	profile.cosmetics["prestige"] = pr
	return [{"type": "prestige_set", "class": class_id, "on": on}]

func mark_skins_seen(class_id := "") -> Array[Dictionary]:
	var keep: Array = []
	for u in profile.cosmetics.get("unseen", []):
		if class_id != "" and not String(u).begins_with(class_id + ":"):
			keep.append(u)
	profile.cosmetics["unseen"] = keep
	return [{"type": "skins_seen", "class": class_id}]

## Replays one command: [name, args...].
func apply(cmd: Array) -> Array[Dictionary]:
	match String(cmd[0]):
		"buy_upgrade": return buy_upgrade(String(cmd[1]), String(cmd[2]))
		"level_gear": return level_gear(String(cmd[1]))
		"rank_up": return rank_up(String(cmd[1]))
		"buy_pouch": return buy_pouch()
		"buy_item": return buy_item(String(cmd[1]), String(cmd[2]) if cmd.size() > 2 else "crowns")
		"craft_variant": return craft_variant(String(cmd[1]), String(cmd[2]), String(cmd[3]) if cmd.size() > 3 else "crowns")
		"equip_item": return equip_item(String(cmd[1]), String(cmd[2]), String(cmd[3]), String(cmd[4]) if cmd.size() > 4 else "")
		"unequip_item": return unequip_item(String(cmd[1]), String(cmd[2]))
		"set_appearance": return set_appearance(String(cmd[1]), String(cmd[2]), String(cmd[3]))
		"mark_items_seen": return mark_items_seen()
		"set_trait": return set_trait(String(cmd[1]), String(cmd[2]), String(cmd[3]))
		"level_pet": return level_pet(String(cmd[1]))
		"unlock": return unlock(String(cmd[1]), String(cmd[2]))
		"toggle_pool": return toggle_pool(String(cmd[1]), String(cmd[2]), bool(cmd[3]))
		"set_starter_kind": return set_starter_kind(String(cmd[1]))
		"set_loadout": return set_loadout(cmd[1], String(cmd[2]))
		"set_class": return set_class(String(cmd[1]))
		"set_mode": return set_mode(String(cmd[1]))
		"set_ascension": return set_ascension(int(cmd[1]))
		"equip_skin": return equip_skin(String(cmd[1]), String(cmd[2]))
		"buy_skin": return buy_skin(String(cmd[1]), String(cmd[2]))
		"set_prestige": return set_prestige(String(cmd[1]), bool(cmd[2]))
		"mark_skins_seen": return mark_skins_seen(String(cmd[1]) if cmd.size() > 1 else "")
	return _err("unknown command " + str(cmd[0]))

# ------------------------------------------------------------------ catalogue (UI + bot)

## Everything that can be bought right now or later: [{cmd, track, kind, id, name, level, max,
## cost, affordable}]. Owned / maxed entries are left out; `cmd` is an apply() command.
func catalog() -> Array:
	var out: Array = []
	for g in ItemDefs.GROUPS:
		if profile.owns("gear", g):
			var r := profile.rank(g)
			_cat(out, ["rank_up", g], "armory", "", g, "%s rank" % String(g).capitalize(), r, ItemDefs.RANK_MAX, ItemDefs.rank_cost(r))
	if not profile.has_pouch() and profile.rank("trinket") >= ItemDefs.POUCH_RANK:
		_cat(out, ["buy_pouch"], "armory", "", "pouch", "Belt Pouch", 0, 1, {"crowns": ItemDefs.POUCH_COST})
	for id in ItemDefs.IDS:
		if not profile.owns_item(String(id)):
			var pc := ItemDefs.price(String(id), profile.unlocks.get("classes", []))
			_cat(out, ["buy_item", id, "crowns"], "armory", "items", String(id), ItemDefs.name_of(String(id)), 0, 1, pc)
	var bp: Dictionary = profile.armory.get("blueprints", {})
	for item in bp:
		if profile.owns_item(String(item)):
			for v in bp[item]:
				_cat(out, ["craft_variant", item, v, "crowns"], "armory", "variants", String(v), ItemDefs.name_of(String(v)), 0, 1,
					ItemDefs.craft_cost(String(v)))
	for track in UnlockDefs.UPGRADES:
		for id in UnlockDefs.UPGRADES[track]:
			var d: Dictionary = UnlockDefs.UPGRADES[track][id]
			if int(profile.upgrades.get(id, 0)) >= 1:
				continue
			if d.has("requires") and not profile.owns("features", String(d.requires)):
				continue
			_cat(out, ["buy_upgrade", track, id], track, "", id, String(d.name), 0, 1, d.cost)
	for id in profile.unlocks.pets:
		var lvl := profile.pet_level(id)
		_cat(out, ["level_pet", id], "pet_den", "", id, PetDefs.name_of(id), lvl, PetDefs.MAX_LEVEL, PetDefs.level_cost(lvl))
	for kind in UnlockDefs.SIGIL_PRICE:
		for id in UnlockDefs.all_ids(kind):
			if not profile.owns(kind, String(id)):
				_cat(out, ["unlock", kind, id], "sigils", kind, String(id), String(id), 0, 1,
					UnlockDefs.sigil_cost(kind, String(id), profile.unlocks.get("classes", [])))
	if profile.crowns_capped():
		for cid in profile.unlocks.get("classes", []):
			for s in SkinDefs.of(String(cid)):
				if bool(s.buyable) and not profile.owns_skin(String(cid), String(s.id)):
					_cat(out, ["buy_skin", cid, s.id], "wardrobe", "skins", "%s:%s" % [cid, s.id], String(s.name), 0, 1,
						{"crowns": SkinDefs.BUY_PRICE})
	return out

func _cat(out: Array, cmd: Array, track: String, kind: String, id: String, name: String, lvl: int, mx: int, cost: Dictionary) -> void:
	if cost.is_empty():
		return
	out.append({"cmd": cmd, "track": track, "kind": kind, "id": id, "name": name, "level": lvl, "max": mx,
		"cost": cost.duplicate(), "affordable": profile.can_afford(cost)})

## Crowns still needed to buy every Crowns item (the four Armory ranks to R8, the Belt Pouch,
## the Armory shop items and every variant blueprint, upgrades, pet levels 6-10 of every pet),
## assuming every feature and pet gets unlocked and every class is owned (kit pieces come free).
static func total_crowns_sink() -> int:
	var t := ItemDefs.POUCH_COST
	for g in ItemDefs.GROUPS:
		for l in ItemDefs.RANK_MAX:
			t += int(ItemDefs.RANK_COSTS[l])
	for id in ItemDefs.PRICES:
		t += int(ItemDefs.PRICES[id])
	for v in ItemDefs.VARIANTS:
		if not (ItemDefs.VARIANTS[v].unlock as Dictionary).has("class"):
			t += int(ItemDefs.craft_cost(String(v)).crowns)
	for track in UnlockDefs.UPGRADES:
		for id in UnlockDefs.UPGRADES[track]:
			t += int(UnlockDefs.UPGRADES[track][id].cost.crowns)
	for c in PetDefs.LEVEL_COSTS:
		t += int(c) * PetDefs.IDS.size()
	return t

# ------------------------------------------------------------------ helpers

func _loadout_ev() -> Dictionary:
	return {"type": "loadout_changed", "class": String(profile.loadout.get("class", "knight")),
		"mode": String(profile.loadout.get("mode", "standard")),
		"minigames": (profile.loadout.minigames as Array).duplicate(), "pet": String(profile.loadout.pet)}

func _pay(cost: Dictionary) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	var c := int(cost.get("crowns", 0))
	if c > 0:
		profile.crowns -= c
		ev.append({"type": "crowns_changed", "amount": -c, "total": profile.crowns})
	var s := int(cost.get("sigils", 0))
	if s > 0:
		profile.sigils -= s
		ev.append({"type": "sigils_changed", "amount": -s, "total": profile.sigils})
	return ev

static func _err(msg: String) -> Array[Dictionary]:
	return [{"type": "error", "msg": msg}]
